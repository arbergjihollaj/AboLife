import Foundation

struct ReminderService {
    let database: AppDatabase
    var calendar: Calendar = .current
    var now: () -> Date = Date.init

    func morningHabitReminder(for date: Date = Date()) throws -> TelegramReminderMessage? {
        let dayKey = DateIntervals.dayKey(for: date, calendar: calendar)
        let proteinOpen = try !isHabitDone(TelegramReminderHabit.proteinShakeKey, dayKey: dayKey)
        let medicationOpen = try !isHabitDone(TelegramReminderHabit.medicationKey, dayKey: dayKey)
        guard proteinOpen || medicationOpen else { return nil }

        var lines = ["Kurzer Morgen-Check:"]
        if proteinOpen {
            lines.append("* Proteinshake ist noch offen.")
        }
        if medicationOpen {
            lines.append("* Medikamente sind noch offen.")
        }

        return TelegramReminderMessage(
            kind: .morningHabits,
            text: lines.joined(separator: "\n"),
            keyboard: actionKeyboard([.proteinShakeDone, .medicationDone, .remindLater])
        )
    }

    func trainingReminder(for date: Date = Date()) throws -> TelegramReminderMessage? {
        let dayKey = DateIntervals.dayKey(for: date, calendar: calendar)
        guard try !isHabitDone(TelegramReminderHabit.trainingPausedKey, dayKey: dayKey) else { return nil }
        let completed = try WorkoutRepository(database: database).completedCount(forDay: date, calendar: calendar)
        guard completed == 0 else { return nil }

        return TelegramReminderMessage(
            kind: .training,
            text: "Du hast heute noch kein Training eingetragen. Trainierst du später noch?",
            keyboard: actionKeyboard([.trainingYes, .trainingLater, .trainingPauseToday])
        )
    }

    func eveningCheck(for date: Date = Date()) throws -> TelegramReminderMessage? {
        let settings = try SettingsRepository(database: database).loadSettings()
        let nutrition = try NutritionRepository(database: database).daySummary(for: date, calendar: calendar)
        let completedWorkouts = try WorkoutRepository(database: database).completedCount(forDay: date, calendar: calendar)

        let caloriesLow = nutrition.caloriesKcal < Int(Double(settings.caloriesTarget) * 0.72)
        let proteinLow = nutrition.proteinG < settings.proteinTargetG * 0.72
        let trainingOpen = completedWorkouts == 0
        guard caloriesLow || proteinLow || trainingOpen else { return nil }

        var lines = ["Sanfter Tagescheck:"]
        if caloriesLow {
            lines.append("* Kalorien liegen noch deutlich unter Ziel.")
        }
        if proteinLow {
            lines.append("* Protein ist noch deutlich unter Ziel.")
        }
        if trainingOpen {
            lines.append("* Training wurde heute noch nicht eingetragen.")
        }
        lines.append("Ein kleiner Abschluss reicht. Morgen zählt wieder frisch.")

        return TelegramReminderMessage(
            kind: .eveningCheck,
            text: lines.joined(separator: "\n"),
            keyboard: actionKeyboard([.addMeal, .startTraining, .remindLater])
        )
    }

    func handle(action: TelegramReminderAction, date: Date = Date()) throws -> ExternalInputResult {
        let dayKey = DateIntervals.dayKey(for: date, calendar: calendar)
        switch action {
        case .proteinShakeDone:
            try HabitRepository(database: database).upsertCompletion(habitKey: TelegramReminderHabit.proteinShakeKey, date: dayKey, isCompleted: true)
            return .success(message: "Proteinshake erledigt.", affectedModule: .habits)
        case .medicationDone:
            try HabitRepository(database: database).upsertCompletion(habitKey: TelegramReminderHabit.medicationKey, date: dayKey, isCompleted: true)
            return .success(message: "Medikamente erledigt.", affectedModule: .habits)
        case .startTraining, .trainingYes:
            return ExternalInputService(database: database, calendar: calendar, now: now).execute(.workoutCompleted(date: date, note: "Telegram Reminder"))
        case .trainingPauseToday:
            try HabitRepository(database: database).upsertCompletion(habitKey: TelegramReminderHabit.trainingPausedKey, date: dayKey, isCompleted: true)
            return .success(message: "Training für heute pausiert.", affectedModule: .habits)
        case .remindLater, .trainingLater:
            return .success(message: "Alles klar, ich erinnere dich später nochmal.", affectedModule: .menu)
        case .addMeal, .addExpense:
            return .failure(message: "Diese Aktion startet einen Dialog.", reason: "dialog_action")
        }
    }

    private func isHabitDone(_ key: String, dayKey: String) throws -> Bool {
        try HabitRepository(database: database).fetchEntry(habitKey: key, date: dayKey)?.isCompleted == true
    }

    private func actionKeyboard(_ actions: [TelegramReminderAction]) -> TelegramKeyboard {
        let buttons = actions.map { TelegramKeyboard.Button(label: $0.label, callbackData: $0.rawValue) }
        return TelegramKeyboard(rows: stride(from: 0, to: buttons.count, by: 2).map {
            Array(buttons[$0..<min($0 + 2, buttons.count)])
        })
    }
}
