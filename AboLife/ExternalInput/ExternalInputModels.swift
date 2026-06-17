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
        case selectBarcodeAmount(grams: Double)
        case enterBarcodeAmountManually
        case confirm
        case cancel
    }

    let id: String
    let label: String
    let kind: Kind
}

enum ExternalInputResult: Equatable {
    case success(message: String, affectedModule: ExternalInputAffectedModule)
    case failure(message: String, reason: String)
    case needsClarification(message: String, options: [ExternalInputAction])
    case menu(message: String, actions: [ExternalInputAction])

    var message: String {
        switch self {
        case let .success(message, _),
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
        case .success, .failure:
            return []
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
}

extension ExternalInputAction {
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
