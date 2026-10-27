import Foundation

enum ExternalInputAffectedModule: String, Equatable {
    case weight
    case finance
    case nutrition
    case training
    case habits
    case menu
    case unknown
}

enum ExternalInputIntent: Equatable {
    case weight(date: Date, weightKg: Double)
    case weightStatus
    case weightTarget(weightKg: Double)
    case weightCorridor(lowerKg: Double, upperKg: Double)
    case expense(date: Date, amount: Double, title: String, category: String?)
    case meal(date: Date, name: String, calories: Int?, protein: Double?, note: String?)
    case mealTemplate(date: Date, templateId: String)
    case workoutCompleted(date: Date, note: String?)
    case homeWorkoutCompleted(date: Date, workoutName: String?, intensity: HomeWorkoutIntensity, note: String?)
    case workoutExerciseSets(date: Date, exerciseName: String, reps: [Int])
    case workoutPaused(date: Date)
    case habitCompleted(date: Date, habitName: String)
    case start
    case help
    case cancel
    case unknown(rawText: String, reason: String)
}

struct ExternalInputAction: Equatable, Identifiable {
    enum Kind: Equatable {
        case startFlow(ExternalInputDialogFlow)
        case selectTemplate(id: String)
        case selectHabit(name: String)
        case selectExpenseCategory(name: String)
        case changeExpenseCategory
        case selectBarcodeAmount(grams: Double)
        case enterBarcodeAmountManually
        case undo(receiptID: String)
        case confirm
        case cancel
    }

    let id: String
    let label: String
    let kind: Kind
}

enum ExternalInputResult: Equatable {
    case success(message: String, affectedModule: ExternalInputAffectedModule)
    case saved(message: String, affectedModule: ExternalInputAffectedModule, receipt: ExternalInputSaveReceipt)
    case failure(message: String, reason: String)
    case needsClarification(message: String, options: [ExternalInputAction])
    case menu(message: String, actions: [ExternalInputAction])

    var message: String {
        switch self {
        case let .success(message, _),
             let .saved(message, _, _),
             let .failure(message, _),
             let .needsClarification(message, _),
             let .menu(message, _):
            return message
        }
    }

    var actions: [ExternalInputAction] {
        switch self {
        case let .needsClarification(_, options), let .menu(_, options):
            return options
        case let .saved(_, _, receipt):
            return receipt.isUndoAvailable ? [.undo(receiptID: receipt.id)] : []
        case .success, .failure:
            return []
        }
    }

    var isSuccessfulSave: Bool {
        if case .saved = self {
            return true
        }
        return false
    }

    func replacingMessage(_ message: String) -> ExternalInputResult {
        switch self {
        case let .success(_, affectedModule):
            return .success(message: message, affectedModule: affectedModule)
        case let .saved(_, affectedModule, receipt):
            return .saved(message: message, affectedModule: affectedModule, receipt: receipt)
        case let .failure(_, reason):
            return .failure(message: message, reason: reason)
        case let .needsClarification(_, options):
            return .needsClarification(message: message, options: options)
        case let .menu(_, actions):
            return .menu(message: message, actions: actions)
        }
    }
}

enum ExternalInputUndoAvailability: Equatable {
    case available
    case unavailable(reason: String)
}

struct ExternalInputSaveReceipt: Equatable, Identifiable {
    let id: String
    let expiresAt: Date
    let undoAvailability: ExternalInputUndoAvailability

    var isUndoAvailable: Bool {
        if case .available = undoAvailability {
            return true
        }
        return false
    }
}

enum ExternalInputUndoOutcome: Equatable {
    case undone
    case alreadyUndone
    case expired
    case superseded
    case unavailable(reason: String)
    case unknown
}

final class ExternalInputUndoStore {
    static let shared = ExternalInputUndoStore()

    private enum State {
        case available
        case undone
        case superseded
    }

    private struct Entry {
        let sessionID: String
        let expiresAt: Date
        let unavailableReason: String?
        let operation: (() throws -> Void)?
        var state: State
    }

    private let lock = NSLock()
    private var entries: [String: Entry] = [:]
    private var latestReceiptBySession: [String: String] = [:]

    private init() {}

    func register(
        sessionID: String,
        expiresAt: Date,
        unavailableReason: String? = nil,
        operation: (() throws -> Void)?
    ) -> ExternalInputSaveReceipt {
        lock.lock()
        defer { lock.unlock() }

        cleanup(referenceDate: Date())
        if let previousID = latestReceiptBySession[sessionID],
           var previous = entries[previousID],
           case .available = previous.state {
            previous.state = .superseded
            entries[previousID] = previous
        }

        let receiptID = UUID().uuidString.lowercased()
        entries[receiptID] = Entry(
            sessionID: sessionID,
            expiresAt: expiresAt,
            unavailableReason: unavailableReason,
            operation: operation,
            state: .available
        )
        latestReceiptBySession[sessionID] = receiptID

        return ExternalInputSaveReceipt(
            id: receiptID,
            expiresAt: expiresAt,
            undoAvailability: operation == nil
                ? .unavailable(reason: unavailableReason ?? "Diese Änderung kann nicht rückgängig gemacht werden.")
                : .available
        )
    }

    func undo(receiptID: String, sessionID: String, now: Date = Date()) throws -> ExternalInputUndoOutcome {
        lock.lock()
        defer { lock.unlock() }

        guard var entry = entries[receiptID], entry.sessionID == sessionID else {
            return .unknown
        }
        if case .undone = entry.state {
            return .alreadyUndone
        }
        guard latestReceiptBySession[sessionID] == receiptID else {
            return .superseded
        }
        if case .superseded = entry.state {
            return .superseded
        }
        guard now <= entry.expiresAt else {
            return .expired
        }
        guard let operation = entry.operation else {
            return .unavailable(reason: entry.unavailableReason ?? "Diese Änderung kann nicht rückgängig gemacht werden.")
        }

        try operation()
        entry.state = .undone
        entries[receiptID] = entry
        return .undone
    }

    private func cleanup(referenceDate: Date) {
        let retentionLimit = referenceDate.addingTimeInterval(-86_400)
        entries = entries.filter { _, entry in
            entry.expiresAt >= retentionLimit
        }
        latestReceiptBySession = latestReceiptBySession.filter { _, receiptID in
            entries[receiptID] != nil
        }
    }
}

enum ExternalInputDialogFlow: String, Equatable {
    case weight
    case expense
    case meal
    case mealTemplate
    case workout
    case habit
}

enum ExternalInputDialogInput: Equatable {
    case text(String)
    case action(ExternalInputAction.Kind)
}

enum ExternalInputFormatting {
    static func decimal(_ value: Double, maximumFractionDigits: Int = 2) -> String {
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "de_DE")
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = maximumFractionDigits
        return formatter.string(from: NSNumber(value: value)) ?? String(format: "%.2f", value)
    }

    static func euro(_ value: Double) -> String {
        "\(decimal(value, maximumFractionDigits: 2)) EUR"
    }

    static func currency(_ value: Double, currencyCode: String) -> String {
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "de_DE")
        formatter.numberStyle = .currency
        formatter.currencyCode = currencyCode
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        return formatter.string(from: NSNumber(value: value))
            ?? "\(decimal(value, maximumFractionDigits: 2)) \(currencyCode)"
    }
}

extension ExternalInputAction {
    static func undo(receiptID: String) -> ExternalInputAction {
        ExternalInputAction(
            id: "undo.\(receiptID)",
            label: "Rückgängig",
            kind: .undo(receiptID: receiptID)
        )
    }

    static let mainMenu: [ExternalInputAction] = [
        ExternalInputAction(id: "flow.weight", label: "Gewicht", kind: .startFlow(.weight)),
        ExternalInputAction(id: "flow.expense", label: "Ausgabe", kind: .startFlow(.expense)),
        ExternalInputAction(id: "flow.meal", label: "Mahlzeit", kind: .startFlow(.meal)),
        ExternalInputAction(id: "flow.template", label: "Vorlage", kind: .startFlow(.mealTemplate)),
        ExternalInputAction(id: "flow.workout", label: "Training", kind: .startFlow(.workout)),
        ExternalInputAction(id: "flow.habit", label: "Habit", kind: .startFlow(.habit)),
        ExternalInputAction(id: "flow.cancel", label: "Abbrechen", kind: .cancel)
    ]

    static let confirmation: [ExternalInputAction] = [
        ExternalInputAction(id: "confirm.save", label: "Speichern", kind: .confirm),
        ExternalInputAction(id: "confirm.cancel", label: "Abbrechen", kind: .cancel)
    ]
}

struct FinanceExpenseDraft: Equatable {
    let date: Date
    let amount: Double
    let title: String
    let category: String
    let note: String?
    let needsConfirmation: Bool
}

struct ExternalFinanceCategorySuggestion: Equatable {
    let category: String
    let confidence: Double
    let reason: String

    var isConfident: Bool {
        confidence >= 0.75
    }
}

struct FinanceExpenseInputService {
    var calendar: Calendar = .current
    var now: () -> Date = Date.init

    func draft(date: Date, amount: Double, title: String, category: String?, note: String? = nil, explicitCategory: Bool = false) -> FinanceExpenseDraft {
        let cleanTitle = trimmedOrDefault(title, defaultValue: "Ausgabe")
        let cleanCategory = category.flatMap(Self.optionalTrimmed)
        let suggestion = suggestCategory(title: cleanTitle, explicitCategory: cleanCategory)
        let normalizedCategory = FinanceCategoryCatalog.normalized(suggestion.category, kind: .expense)
        return FinanceExpenseDraft(
            date: date,
            amount: amount,
            title: cleanTitle,
            category: normalizedCategory,
            note: Self.optionalTrimmed(note),
            needsConfirmation: !explicitCategory && !suggestion.isConfident
        )
    }

    func suggestCategory(title: String, explicitCategory: String? = nil) -> ExternalFinanceCategorySuggestion {
        if let explicitCategory = explicitCategory.flatMap(Self.optionalTrimmed) {
            return ExternalFinanceCategorySuggestion(
                category: FinanceCategoryCatalog.normalized(explicitCategory, kind: .expense),
                confidence: 1,
                reason: "manuell gewählt"
            )
        }

        let suggestion = FinanceCategoryCatalog.suggestedCategory(for: title)
        return ExternalFinanceCategorySuggestion(
            category: suggestion.category,
            confidence: suggestion.confidence == .rule ? 0.9 : 0.45,
            reason: suggestion.reason
        )
    }

    static var suggestedExpenseCategories: [String] {
        FinanceCategoryCatalog.expenseCategories
    }

    static func categoryActions(limit: Int = 8) -> [ExternalInputAction] {
        suggestedExpenseCategories.prefix(limit).map { category in
            ExternalInputAction(
                id: "expense.category.\(callbackSafe(category))",
                label: ExternalInputService.shortLabel(category, limit: 22),
                kind: .selectExpenseCategory(name: category)
            )
        } + [
            ExternalInputAction(id: "confirm.cancel", label: "Abbrechen", kind: .cancel)
        ]
    }

    static func confirmationActions(category: String) -> [ExternalInputAction] {
        [
            ExternalInputAction(id: "confirm.save", label: "Speichern", kind: .confirm),
            ExternalInputAction(id: "expense.category.change", label: "Kategorie ändern", kind: .changeExpenseCategory),
            ExternalInputAction(id: "confirm.cancel", label: "Abbrechen", kind: .cancel)
        ]
    }

    private static func callbackSafe(_ category: String) -> String {
        category
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "de_DE"))
            .lowercased()
            .replacingOccurrences(of: " ", with: "_")
            .replacingOccurrences(of: "/", with: "_")
    }

    private static func optionalTrimmed(_ value: String?) -> String? {
        let trimmed = (value ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private func trimmedOrDefault(_ value: String, defaultValue: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? defaultValue : trimmed
    }
}
