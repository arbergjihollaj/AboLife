import Foundation

enum TelegramExportAction {
    static let callbackData = "export.snapshot"
    static let label = "📤 Export"
}

struct TelegramButtonMapper {
    func action(for callbackData: String) -> ExternalInputAction.Kind? {
        switch callbackData {
        case "flow.weight":
            return .startFlow(.weight)
        case "flow.expense":
            return .startFlow(.expense)
        case "flow.meal":
            return .startFlow(.meal)
        case "flow.template":
            return .startFlow(.mealTemplate)
        case "flow.workout":
            return .startFlow(.workout)
        case "flow.habit":
            return .startFlow(.habit)
        case "confirm.save":
            return .confirm
        case "confirm.cancel", "flow.cancel":
            return .cancel
        case "barcode.manual":
            return .enterBarcodeAmountManually
        default:
            if callbackData.hasPrefix("template.") {
                return .selectTemplate(id: String(callbackData.dropFirst("template.".count)))
            }
            if callbackData.hasPrefix("habit.") {
                return .selectHabit(name: String(callbackData.dropFirst("habit.".count)))
            }
            if callbackData.hasPrefix("barcode.amount.") {
                let rawValue = String(callbackData.dropFirst("barcode.amount.".count))
                if let grams = Double(rawValue), grams > 0 {
                    return .selectBarcodeAmount(grams: grams)
                }
            }
            return nil
        }
    }

    func keyboard(for result: ExternalInputResult) -> TelegramKeyboard? {
        let actions = result.actions
        guard !actions.isEmpty else { return nil }
        let buttons = actions.map { action in
            TelegramKeyboard.Button(label: action.label, callbackData: action.id)
        }
        var rows = stride(from: 0, to: buttons.count, by: 2).map {
            Array(buttons[$0..<min($0 + 2, buttons.count)])
        }
        if actions.map(\.id) == ExternalInputAction.mainMenu.map(\.id) {
            rows.append([TelegramKeyboard.Button(label: TelegramExportAction.label, callbackData: TelegramExportAction.callbackData)])
        }
        return TelegramKeyboard(rows: rows)
    }
}

final class TelegramBotService {
    private let configuration: TelegramBotConfiguration
    private let dialogManager: ExternalInputDialogManager
    private let client: TelegramBotClient
    private let documentClient: TelegramDocumentClient?
    private let barcodeFoodScanService: TelegramBarcodeFoodScanService?
    private let snapshotExportService: HtmlSnapshotExportService?
    private let reminderService: ReminderService?
    private let mapper = TelegramButtonMapper()

    init(
        configuration: TelegramBotConfiguration,
        dialogManager: ExternalInputDialogManager,
        client: TelegramBotClient,
        documentClient: TelegramDocumentClient? = nil,
        barcodeFoodScanService: TelegramBarcodeFoodScanService? = nil,
        snapshotExportService: HtmlSnapshotExportService? = nil,
        reminderService: ReminderService? = nil
    ) {
        self.configuration = configuration
        self.dialogManager = dialogManager
        self.client = client
        self.documentClient = documentClient
        self.barcodeFoodScanService = barcodeFoodScanService
        self.snapshotExportService = snapshotExportService
        self.reminderService = reminderService
    }

    var isEnabled: Bool {
        configuration.isEnabled
    }

    @discardableResult
    func handle(_ update: TelegramUpdate) async -> TelegramResponse? {
        guard configuration.isEnabled else { return nil }
        guard isAllowed(update) else {
            return nil
        }

        if let message = update.message {
            if !message.photos.isEmpty {
                return await handleBarcodePhoto(message)
            }
            guard let text = message.text else { return nil }
            let result = dialogManager.handle(.text(text), sessionID: sessionID(chatId: message.chatId))
            let response = response(chatId: message.chatId, result: result)
            try? await client.send(response)
            return response
        }

        if let callback = update.callback {
            if callback.data == TelegramExportAction.callbackData {
                return await exportSnapshot(chatId: callback.chatId)
            }

            if let action = TelegramReminderAction(rawValue: callback.data) {
                let response = await reminderResponse(chatId: callback.chatId, action: action)
                try? await client.send(response)
                return response
            }

            guard let action = mapper.action(for: callback.data) else {
                let response = TelegramResponse(chatId: callback.chatId, text: "Diese Aktion kenne ich noch nicht.", keyboard: nil)
                try? await client.send(response)
                return response
            }
            let result = dialogManager.handle(.action(action), sessionID: sessionID(chatId: callback.chatId))
            let response = response(chatId: callback.chatId, result: result)
            try? await client.send(response)
            return response
        }

        return nil
    }

    func response(chatId: Int64, result: ExternalInputResult) -> TelegramResponse {
        TelegramResponse(
            chatId: chatId,
            text: result.message,
            keyboard: mapper.keyboard(for: result)
        )
    }

    private func isAllowed(_ update: TelegramUpdate) -> Bool {
        guard let allowedChatId = configuration.allowedChatId else { return false }
        let chatId = update.message?.chatId ?? update.callback?.chatId
        return chatId == allowedChatId
    }

    private func sessionID(chatId: Int64) -> String {
        "telegram.chat.\(chatId)"
    }

    private func reminderResponse(chatId: Int64, action: TelegramReminderAction) async -> TelegramResponse {
        switch action {
        case .addMeal:
            return response(chatId: chatId, result: dialogManager.handle(.action(.startFlow(.meal)), sessionID: sessionID(chatId: chatId)))
        case .addExpense:
            return response(chatId: chatId, result: dialogManager.handle(.action(.startFlow(.expense)), sessionID: sessionID(chatId: chatId)))
        default:
            guard let reminderService else {
                return TelegramResponse(chatId: chatId, text: "Reminder-Aktion ist gerade nicht verfügbar.", keyboard: nil)
            }
            let result: ExternalInputResult
            do {
                result = try reminderService.handle(action: action)
            } catch {
                result = .failure(message: "Das konnte nicht gespeichert werden.", reason: "reminder_action_failed")
            }
            return response(chatId: chatId, result: result)
        }
    }

    private func handleBarcodePhoto(_ message: TelegramMessage) async -> TelegramResponse {
        guard let barcodeFoodScanService else {
            let response = TelegramResponse(
                chatId: message.chatId,
                text: "Barcode-Scan ist gerade nicht verfügbar.",
                keyboard: nil
            )
            try? await client.send(response)
            return response
        }

        let result = await barcodeFoodScanService.scan(photoSizes: message.photos)
        let response: TelegramResponse
        switch result {
        case let .success(product):
            let dialogResult = dialogManager.beginBarcodeMeal(product: product, sessionID: sessionID(chatId: message.chatId))
            response = self.response(chatId: message.chatId, result: dialogResult)
        case let .failure(failure):
            response = TelegramResponse(chatId: message.chatId, text: failure.message, keyboard: nil)
        }
        try? await client.send(response)
        return response
    }

    private func exportSnapshot(chatId: Int64) async -> TelegramResponse {
        guard let snapshotExportService else {
            let response = TelegramResponse(chatId: chatId, text: "Export konnte nicht erstellt werden.", keyboard: nil)
            try? await client.send(response)
            return response
        }
        guard let documentClient else {
            let response = TelegramResponse(chatId: chatId, text: "Export konnte nicht gesendet werden.", keyboard: nil)
            try? await client.send(response)
            return response
        }

        let file: HtmlSnapshotFile
        do {
            file = try snapshotExportService.makeSnapshotFile()
        } catch {
            let response = TelegramResponse(chatId: chatId, text: "Export konnte nicht erstellt werden.", keyboard: nil)
            try? await client.send(response)
            return response
        }

        defer {
            try? FileManager.default.removeItem(at: file.url)
        }

        do {
            try await documentClient.sendDocument(
                chatId: chatId,
                fileURL: file.url,
                caption: "AboLife Snapshot"
            )
            return TelegramResponse(chatId: chatId, text: "Export gesendet.", keyboard: nil)
        } catch {
            let response = TelegramResponse(chatId: chatId, text: "Export konnte nicht gesendet werden.", keyboard: nil)
            try? await client.send(response)
            return response
        }
    }
}
