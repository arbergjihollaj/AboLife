import Foundation

private enum TelegramExportCallback {
    static let weeklyHTML = "export.weekly_html"
    static let monthlyHTML = "export.monthly_html"
    static let csvNumbers = TelegramCallbackID.exportData
}

struct TelegramButtonMapper {
    func action(for callbackData: String) -> ExternalInputAction.Kind? {
        switch TelegramCallbackID.canonical(callbackData) {
        case TelegramCallbackID.addWeight:
            return .startFlow(.weight)
        case TelegramCallbackID.addExpense:
            return .startFlow(.expense)
        case TelegramCallbackID.addMeal:
            return .startFlow(.meal)
        case TelegramCallbackID.addTemplate:
            return .startFlow(.mealTemplate)
        case TelegramCallbackID.addWorkout:
            return .startFlow(.workout)
        case TelegramCallbackID.addHabit:
            return .startFlow(.habit)
        case TelegramCallbackID.save:
            return .confirm
        case TelegramCallbackID.cancel:
            return .cancel
        case "expense.category.change":
            return .changeExpenseCategory
        case "barcode.manual":
            return .enterBarcodeAmountManually
        default:
            if callbackData.hasPrefix("expense.category.") {
                let safe = String(callbackData.dropFirst("expense.category.".count))
                if let category = FinanceExpenseInputService.suggestedExpenseCategories.first(where: {
                    $0.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "de_DE"))
                        .lowercased()
                        .replacingOccurrences(of: " ", with: "_")
                        .replacingOccurrences(of: "/", with: "_") == safe
                }) {
                    return .selectExpenseCategory(name: category)
                }
            }
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
            if callbackData.hasPrefix("undo.") {
                let receiptID = String(callbackData.dropFirst("undo.".count))
                if !receiptID.isEmpty {
                    return .undo(receiptID: receiptID)
                }
            }
            return nil
        }
    }

    func keyboard(for result: ExternalInputResult) -> TelegramKeyboard? {
        let actions = result.actions
        guard !actions.isEmpty else { return nil }
        if actions.map(\.id) == ExternalInputAction.mainMenu.map(\.id) {
            return Self.mainMenuKeyboard
        }
        let buttons = actions.map { action in
            let callbackData: String
            switch action.kind {
            case .confirm:
                callbackData = TelegramCallbackID.save
            case .cancel:
                callbackData = TelegramCallbackID.cancel
            case let .undo(receiptID):
                callbackData = "undo.\(receiptID)"
            default:
                callbackData = TelegramCallbackID.canonical(action.id)
            }
            return TelegramKeyboard.Button(label: action.label, callbackData: callbackData)
        }
        let rows = stride(from: 0, to: buttons.count, by: 2).map {
            Array(buttons[$0..<min($0 + 2, buttons.count)])
        }
        return TelegramKeyboard(rows: rows)
    }

    static let mainMenuKeyboard = TelegramKeyboard(rows: [
        [
            TelegramKeyboard.Button(label: "🍽 Mahlzeit", callbackData: TelegramCallbackID.addMeal),
            TelegramKeyboard.Button(label: "🏋️ Training", callbackData: TelegramCallbackID.addWorkout)
        ],
        [
            TelegramKeyboard.Button(label: "⚖️ Gewicht", callbackData: TelegramCallbackID.addWeight),
            TelegramKeyboard.Button(label: "💶 Ausgabe", callbackData: TelegramCallbackID.addExpense)
        ],
        [
            TelegramKeyboard.Button(label: "✅ Habits", callbackData: TelegramCallbackID.addHabit),
            TelegramKeyboard.Button(label: "📊 Heute", callbackData: TelegramCallbackID.today)
        ],
        [
            TelegramKeyboard.Button(label: "📤 Export", callbackData: TelegramCallbackID.exportMenu),
            TelegramKeyboard.Button(label: "❓ Hilfe", callbackData: TelegramCallbackID.help)
        ]
    ])

    static let addMenuKeyboard = TelegramKeyboard(rows: [
        [
            TelegramKeyboard.Button(label: "⚖️ Gewicht", callbackData: TelegramCallbackID.addWeight),
            TelegramKeyboard.Button(label: "💶 Ausgabe", callbackData: TelegramCallbackID.addExpense)
        ],
        [
            TelegramKeyboard.Button(label: "🍽 Mahlzeit", callbackData: TelegramCallbackID.addMeal),
            TelegramKeyboard.Button(label: "⭐ Vorlage", callbackData: TelegramCallbackID.addTemplate)
        ],
        [
            TelegramKeyboard.Button(label: "🏋️ Training", callbackData: TelegramCallbackID.addWorkout),
            TelegramKeyboard.Button(label: "✅ Habit", callbackData: TelegramCallbackID.addHabit)
        ],
        [TelegramKeyboard.Button(label: "‹ Menü", callbackData: TelegramCallbackID.mainMenu)]
    ])

    static let exportMenuKeyboard = TelegramKeyboard(rows: [
        [TelegramKeyboard.Button(label: "📄 Tagesreport HTML", callbackData: TelegramCallbackID.exportSnapshot)],
        [TelegramKeyboard.Button(label: "📅 Wochenreport HTML", callbackData: TelegramExportCallback.weeklyHTML)],
        [TelegramKeyboard.Button(label: "🗓 Monatsreport HTML", callbackData: TelegramExportCallback.monthlyHTML)],
        [TelegramKeyboard.Button(label: "📊 CSV / Numbers", callbackData: TelegramExportCallback.csvNumbers)],
        [TelegramKeyboard.Button(label: "‹ Zurück", callbackData: TelegramCallbackID.mainMenu)]
    ])

    static let menuBackKeyboard = TelegramKeyboard(rows: [
        [TelegramKeyboard.Button(label: "‹ Menü", callbackData: TelegramCallbackID.mainMenu)]
    ])
}

final class TelegramBotService {
    private let configuration: TelegramBotConfiguration
    private let dialogManager: ExternalInputDialogManager
    private let client: TelegramBotClient
    private let documentClient: TelegramDocumentClient?
    private let barcodeFoodScanService: TelegramBarcodeFoodScanService?
    private let snapshotExportService: HtmlSnapshotExportService?
    private let reminderService: ReminderService?
    private let dailySummaryService: DailySummaryService?
    private let mapper = TelegramButtonMapper()

    init(
        configuration: TelegramBotConfiguration,
        dialogManager: ExternalInputDialogManager,
        client: TelegramBotClient,
        documentClient: TelegramDocumentClient? = nil,
        barcodeFoodScanService: TelegramBarcodeFoodScanService? = nil,
        snapshotExportService: HtmlSnapshotExportService? = nil,
        reminderService: ReminderService? = nil,
        dailySummaryService: DailySummaryService? = nil
    ) {
        self.configuration = configuration
        self.dialogManager = dialogManager
        self.client = client
        self.documentClient = documentClient
        self.barcodeFoodScanService = barcodeFoodScanService
        self.snapshotExportService = snapshotExportService
        self.reminderService = reminderService
        self.dailySummaryService = dailySummaryService ?? reminderService.map {
            DailySummaryService(database: $0.database, calendar: $0.calendar)
        }
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
            if let navigationResponse = handleNavigationText(text, chatId: message.chatId) {
                try? await client.send(navigationResponse)
                return navigationResponse
            }
            let result = dialogManager.handle(.text(text), sessionID: sessionID(chatId: message.chatId))
            let response = response(chatId: message.chatId, result: result)
            try? await client.send(response)
            return response
        }

        if let callback = update.callback {
            let callbackData = TelegramCallbackID.canonical(callback.data)

            switch callbackData {
            case TelegramCallbackID.mainMenu:
                return await sendMainMenu(chatId: callback.chatId, clearDialog: true)
            case TelegramCallbackID.addMenu:
                return await send(
                    TelegramResponse(chatId: callback.chatId, text: "Was möchtest du eintragen?", keyboard: TelegramButtonMapper.addMenuKeyboard)
                )
            case TelegramCallbackID.today:
                return await sendToday(chatId: callback.chatId)
            case TelegramCallbackID.exportMenu:
                return await send(
                    TelegramResponse(chatId: callback.chatId, text: "Welchen Export möchtest du?", keyboard: TelegramButtonMapper.exportMenuKeyboard)
                )
            case TelegramCallbackID.help:
                return await send(helpResponse(chatId: callback.chatId))
            case TelegramExportCallback.weeklyHTML:
                return await send(
                    TelegramResponse(
                        chatId: callback.chatId,
                        text: "Der Wochenreport als HTML kommt später.",
                        keyboard: TelegramButtonMapper.exportMenuKeyboard
                    )
                )
            case TelegramExportCallback.monthlyHTML:
                return await send(
                    TelegramResponse(
                        chatId: callback.chatId,
                        text: "Der Monatsreport als HTML kommt später.",
                        keyboard: TelegramButtonMapper.exportMenuKeyboard
                    )
                )
            case TelegramExportCallback.csvNumbers:
                return await send(
                    TelegramResponse(
                        chatId: callback.chatId,
                        text: "Der CSV-/Numbers-Export kommt später.",
                        keyboard: TelegramButtonMapper.exportMenuKeyboard
                    )
                )
            case TelegramCallbackID.exportSnapshot:
                return await exportSnapshot(chatId: callback.chatId)
            default:
                break
            }

            if let action = TelegramReminderAction(rawValue: callback.data) {
                let response = await reminderResponse(chatId: callback.chatId, action: action)
                try? await client.send(response)
                return response
            }

            guard let action = mapper.action(for: callbackData) else {
                let response = TelegramResponse(
                    chatId: callback.chatId,
                    text: "Diese Auswahl ist nicht mehr verfügbar.",
                    keyboard: TelegramButtonMapper.mainMenuKeyboard
                )
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
        let keyboard: TelegramKeyboard?
        switch result {
        case .success:
            keyboard = TelegramButtonMapper.mainMenuKeyboard
        case .saved:
            let undoKeyboard = mapper.keyboard(for: result)
            keyboard = TelegramKeyboard(rows: (undoKeyboard?.rows ?? []) + [
                [TelegramKeyboard.Button(label: "‹ Menü", callbackData: TelegramCallbackID.mainMenu)]
            ])
        case .failure:
            keyboard = mapper.keyboard(for: result) ?? TelegramKeyboard(rows: [
                [TelegramKeyboard.Button(label: "‹ Menü", callbackData: TelegramCallbackID.mainMenu)]
            ])
        case .needsClarification, .menu:
            keyboard = mapper.keyboard(for: result)
        }
        return TelegramResponse(
            chatId: chatId,
            text: result.message,
            keyboard: keyboard
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

    private func handleNavigationText(_ text: String, chatId: Int64) -> TelegramResponse? {
        let command = text
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .split(separator: "@", maxSplits: 1)
            .first
            .map(String.init)

        switch command {
        case "/start", "/menu", "menü", "menu":
            _ = dialogManager.handle(.action(.cancel), sessionID: sessionID(chatId: chatId))
            return mainMenuResponse(chatId: chatId, greeting: command == "/start")
        case "/help", "hilfe", "help":
            return helpResponse(chatId: chatId)
        default:
            return nil
        }
    }

    private func mainMenuResponse(chatId: Int64, greeting: Bool = false) -> TelegramResponse {
        TelegramResponse(
            chatId: chatId,
            text: greeting
                ? "🏠 AboLife\n\nWas möchtest du heute in Ruhe machen?"
                : "🏠 AboLife\n\nWas möchtest du machen?",
            keyboard: TelegramButtonMapper.mainMenuKeyboard
        )
    }

    private func helpResponse(chatId: Int64) -> TelegramResponse {
        TelegramResponse(
            chatId: chatId,
            text: """
            ❓ Kurze Beispiele

            🍽 Essen Skyr 250 kcal 25 Protein
            💶 Ausgabe Döner 4,50
            🏋️ Training erledigt
            ⚖️ Gewicht 82,4
            ✅ Habit Schlafroutine erledigt
            📷 Oder sende ein nahes, scharfes Barcode-Foto.

            Mit /menu kommst du jederzeit zurück.
            """,
            keyboard: TelegramButtonMapper.menuBackKeyboard
        )
    }

    private func sendMainMenu(chatId: Int64, clearDialog: Bool) async -> TelegramResponse {
        if clearDialog {
            _ = dialogManager.handle(.action(.cancel), sessionID: sessionID(chatId: chatId))
        }
        return await send(mainMenuResponse(chatId: chatId))
    }

    private func sendToday(chatId: Int64) async -> TelegramResponse {
        guard let dailySummaryService else {
            return await send(
                TelegramResponse(
                    chatId: chatId,
                    text: "Der Tagesstand ist gerade nicht verfügbar.",
                    keyboard: TelegramButtonMapper.mainMenuKeyboard
                )
            )
        }
        do {
            return await send(
                TelegramResponse(
                    chatId: chatId,
                    text: try dailySummaryService.todayText(),
                    keyboard: TelegramButtonMapper.mainMenuKeyboard
                )
            )
        } catch {
            return await send(
                TelegramResponse(
                    chatId: chatId,
                    text: "Der Tagesstand konnte nicht geladen werden.",
                    keyboard: TelegramButtonMapper.mainMenuKeyboard
                )
            )
        }
    }

    private func send(_ response: TelegramResponse) async -> TelegramResponse {
        try? await client.send(response)
        return response
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
                result = try reminderService.handle(
                    action: action,
                    sessionID: sessionID(chatId: chatId)
                )
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
            let response = TelegramResponse(
                chatId: chatId,
                text: "Der Snapshot ist gerade nicht verfügbar.",
                keyboard: TelegramButtonMapper.exportMenuKeyboard
            )
            try? await client.send(response)
            return response
        }
        guard let documentClient else {
            let response = TelegramResponse(
                chatId: chatId,
                text: "Der Snapshot kann gerade nicht gesendet werden.",
                keyboard: TelegramButtonMapper.exportMenuKeyboard
            )
            try? await client.send(response)
            return response
        }

        do {
            try await snapshotExportService.sendSnapshot(
                using: documentClient,
                chatId: chatId,
                caption: "AboLife Snapshot"
            )
            return await send(
                TelegramResponse(
                    chatId: chatId,
                    text: "Snapshot gesendet.",
                    keyboard: TelegramButtonMapper.mainMenuKeyboard
                )
            )
        } catch HtmlSnapshotDeliveryError.creation {
            let response = TelegramResponse(
                chatId: chatId,
                text: "Der Snapshot konnte nicht erstellt werden.",
                keyboard: TelegramButtonMapper.exportMenuKeyboard
            )
            try? await client.send(response)
            return response
        } catch {
            let response = TelegramResponse(
                chatId: chatId,
                text: "Der Snapshot konnte nicht gesendet werden.",
                keyboard: TelegramButtonMapper.exportMenuKeyboard
            )
            try? await client.send(response)
            return response
        }
    }
}
