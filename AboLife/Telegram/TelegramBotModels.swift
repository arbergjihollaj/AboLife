import Foundation

enum TelegramCallbackID {
    static let mainMenu = "menu.main"
    static let addMenu = "menu.add"
    static let today = "menu.today"
    static let exportMenu = "menu.export"
    static let help = "menu.help"

    static let addWeight = "add.weight"
    static let addExpense = "add.expense"
    static let addMeal = "add.meal"
    static let addTemplate = "add.template"
    static let addWorkout = "add.workout"
    static let addHabit = "add.habit"

    static let save = "dialog.save"
    static let cancel = "dialog.cancel"
    static let exportSnapshot = "export.snapshot"
    static let exportData = "export.data"

    static func canonical(_ callbackData: String) -> String {
        switch callbackData {
        case "flow.weight":
            return addWeight
        case "flow.expense":
            return addExpense
        case "flow.meal":
            return addMeal
        case "flow.template":
            return addTemplate
        case "flow.workout":
            return addWorkout
        case "flow.habit":
            return addHabit
        case "confirm.save":
            return save
        case "confirm.cancel", "flow.cancel":
            return cancel
        default:
            return callbackData
        }
    }
}

struct TelegramBotConfiguration: Equatable {
    let token: String?
    let allowedChatId: Int64?
    let isEnabled: Bool

    static func load(
        environment: [String: String] = ProcessInfo.processInfo.environment,
        localFileURL: URL? = nil
    ) -> TelegramBotConfiguration {
        let environmentAllowedChatId = sanitizedInt64(environment["ABOLIFE_TELEGRAM_ALLOWED_CHAT_ID"])

        if let token = sanitizedToken(environment["ABOLIFE_TELEGRAM_BOT_TOKEN"]) {
            return TelegramBotConfiguration(token: token, allowedChatId: environmentAllowedChatId, isEnabled: true)
        }

        guard let localFileURL,
              let content = try? String(contentsOf: localFileURL, encoding: .utf8),
              let token = token(fromLocalFile: content) else {
            return TelegramBotConfiguration(token: nil, allowedChatId: environmentAllowedChatId, isEnabled: false)
        }

        return TelegramBotConfiguration(
            token: token,
            allowedChatId: environmentAllowedChatId ?? allowedChatId(fromLocalFile: content),
            isEnabled: true
        )
    }

    private static func token(fromLocalFile content: String) -> String? {
        value(for: "ABOLIFE_TELEGRAM_BOT_TOKEN", in: content).flatMap(sanitizedToken)
    }

    private static func allowedChatId(fromLocalFile content: String) -> Int64? {
        value(for: "ABOLIFE_TELEGRAM_ALLOWED_CHAT_ID", in: content).flatMap(sanitizedInt64)
    }

    private static func value(for key: String, in content: String) -> String? {
        for line in content.split(separator: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.hasPrefix("#") else { continue }
            let parts = trimmed.split(separator: "=", maxSplits: 1).map(String.init)
            guard parts.count == 2, parts[0] == key else { continue }
            return parts[1]
        }
        return nil
    }

    private static func sanitizedToken(_ value: String?) -> String? {
        let trimmed = (value ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private static func sanitizedInt64(_ value: String?) -> Int64? {
        let trimmed = (value ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return Int64(trimmed)
    }
}

struct TelegramUpdate: Equatable {
    let updateId: Int
    let message: TelegramMessage?
    let callback: TelegramCallbackAction?
}

struct TelegramMessage: Equatable {
    let chatId: Int64
    let userId: Int64
    let text: String?
    let photos: [TelegramPhotoSize]

    init(chatId: Int64, userId: Int64, text: String? = nil, photos: [TelegramPhotoSize] = []) {
        self.chatId = chatId
        self.userId = userId
        self.text = text
        self.photos = photos
    }
}

struct TelegramCallbackAction: Equatable {
    let chatId: Int64
    let userId: Int64
    let callbackQueryId: String?
    let data: String

    init(chatId: Int64, userId: Int64, callbackQueryId: String? = nil, data: String) {
        self.chatId = chatId
        self.userId = userId
        self.callbackQueryId = callbackQueryId
        self.data = data
    }
}

struct TelegramKeyboard: Equatable {
    struct Button: Equatable {
        let label: String
        let callbackData: String
    }

    let rows: [[Button]]
}

struct TelegramResponse: Equatable {
    let chatId: Int64
    let text: String
    let keyboard: TelegramKeyboard?
}

struct TelegramPhotoSize: Equatable {
    let fileId: String
    let width: Int
    let height: Int
    let fileSize: Int?

    var pixelArea: Int {
        width * height
    }
}

struct TelegramFile: Equatable {
    let fileId: String
    let fileUniqueId: String?
    let fileSize: Int?
    let filePath: String
}

protocol TelegramBotClient {
    func send(_ response: TelegramResponse) async throws
}

protocol TelegramDocumentClient {
    func sendDocument(chatId: Int64, fileURL: URL, caption: String?) async throws
}

final class FakeTelegramBotClient: TelegramBotClient {
    private(set) var sentResponses: [TelegramResponse] = []

    func send(_ response: TelegramResponse) async throws {
        sentResponses.append(response)
    }
}

enum TelegramClientError: LocalizedError, Equatable {
    case missingToken
    case invalidURL
    case api(String)
    case network

    var errorDescription: String? {
        switch self {
        case .missingToken:
            return "Telegram ist nicht konfiguriert."
        case .invalidURL:
            return "Telegram konnte nicht vorbereitet werden."
        case let .api(message):
            return message.isEmpty ? "Telegram hat die Anfrage abgelehnt." : message
        case .network:
            return "Telegram ist gerade nicht erreichbar."
        }
    }
}
