import Foundation

enum TelegramReminderAction: String, CaseIterable {
    case proteinShakeDone = "reminder.protein.done"
    case medicationDone = "reminder.medication.done"
    case startTraining = "reminder.training.start"
    case addMeal = "flow.meal"
    case addExpense = "flow.expense"
    case remindLater = "reminder.later"
    case trainingLater = "reminder.training.later"
    case trainingPauseToday = "reminder.training.pause_today"
    case trainingYes = "reminder.training.yes"

    var label: String {
        switch self {
        case .proteinShakeDone:
            return "Proteinshake erledigt"
        case .medicationDone:
            return "Medikamente erledigt"
        case .startTraining:
            return "Training starten"
        case .addMeal:
            return "Mahlzeit eintragen"
        case .addExpense:
            return "Ausgabe eintragen"
        case .remindLater:
            return "Später erinnern"
        case .trainingLater:
            return "Später erinnern"
        case .trainingPauseToday:
            return "Heute pausieren"
        case .trainingYes:
            return "Ja"
        }
    }
}

enum TelegramReminderKind: String, Equatable {
    case morningSummary
    case morningHabits
    case training
    case eveningCheck
    case snooze
}

struct TelegramReminderLogEntry: Identifiable, Equatable {
    let id: String
    let kind: TelegramReminderKind
    let sentAt: Date
    let chatId: Int64
    let summary: String

    init(id: String = UUID().uuidString, kind: TelegramReminderKind, sentAt: Date, chatId: Int64, summary: String) {
        self.id = id
        self.kind = kind
        self.sentAt = sentAt
        self.chatId = chatId
        self.summary = summary
    }
}

struct TelegramReminderMessage: Equatable {
    let kind: TelegramReminderKind
    let text: String
    let keyboard: TelegramKeyboard?
}

enum TelegramReminderHabit {
    static let proteinShakeKey = "protein_shake"
    static let medicationKey = "medication"
    static let trainingPausedKey = "training_paused"
}
