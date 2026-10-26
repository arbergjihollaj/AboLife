import Foundation

struct ReminderService {
    let database: AppDatabase
    var calendar: Calendar = .current
    var now: () -> Date = Date.init

    func morningHabitReminder(for date: Date = Date()) throws -> TelegramReminderMessage? {
        let status = try todaySnapshot(for: date).todayOpenStatus
        let proteinOpen = status.isProteinShakeOpen
        let medicationOpen = status.isMedicationOpen
        guard proteinOpen || medicationOpen else {
            return TelegramReminderMessage(
                kind: .morningHabits,
                text: "Morgen-Check: Medikamente und Proteinshake sind erledigt.",
                keyboard: nil
            )
        }

        var lines = ["Kurzer Morgen-Check:"]
        var actions: [TelegramReminderAction] = []
        if proteinOpen {
            lines.append("* Proteinshake ist noch offen.")
            actions.append(.proteinShakeDone)
        }
        if medicationOpen {
            lines.append("* Medikamente sind noch offen.")
            actions.append(.medicationDone)
        }
        actions.append(.remindLater)

        return TelegramReminderMessage(
            kind: .morningHabits,
            text: lines.joined(separator: "\n"),
            keyboard: actionKeyboard(actions)
        )
    }

    func trainingReminder(for date: Date = Date()) throws -> TelegramReminderMessage? {
        let snapshot = try todaySnapshot(for: date)
        guard snapshot.todayOpenStatus.training == .open else { return nil }
        let workout = HomeWorkoutPlanProvider.plan.workout(for: date, calendar: calendar)

        return TelegramReminderMessage(
            kind: .training,
            text: "\(workout.day.name) ist heute geplant und noch offen. Passt das Training später?",
            keyboard: actionKeyboard([.trainingYes, .trainingLater, .trainingPauseToday])
        )
    }

    func eveningCheck(for date: Date = Date()) throws -> TelegramReminderMessage? {
        let status = try todaySnapshot(for: date).todayOpenStatus
        let isComplete = status.caloriesRemaining == 0
            && status.proteinRemainingG == 0
            && status.training != .open
            && status.openHabitTitles.isEmpty
            && !status.isMedicationOpen
            && !status.isProteinShakeOpen
        if isComplete {
            return TelegramReminderMessage(
                kind: .eveningCheck,
                text: "Für heute ist alles Wichtige erledigt. Ruhiger Feierabend.",
                keyboard: nil
            )
        }

        var lines = ["Sanfter Tagescheck:", status.summary]
        if status.caloriesRemaining > 0 {
            lines.append("\(status.caloriesRemaining) kcal sind im heutigen Rahmen noch offen.")
        }
        if let nextStep = status.nextStep {
            lines.append(nextStep)
        }

        var actions: [TelegramReminderAction] = []
        if status.caloriesRemaining > 0 || status.proteinRemainingG > 0 {
            actions.append(.addMeal)
        }
        if status.training == .open {
            actions.append(.startTraining)
        }
        if status.isProteinShakeOpen {
            actions.append(.proteinShakeDone)
        }
        if status.isMedicationOpen {
            actions.append(.medicationDone)
        }
        actions.append(.remindLater)

        return TelegramReminderMessage(
            kind: .eveningCheck,
            text: lines.joined(separator: "\n"),
            keyboard: actionKeyboard(actions)
        )
    }

    func handle(
        action: TelegramReminderAction,
        date: Date = Date(),
        sessionID: String = "local"
    ) throws -> ExternalInputResult {
        let service = ExternalInputService(database: database, calendar: calendar, now: now)
        switch action {
        case .proteinShakeDone:
            return service.completeHabit(
                habitKey: TelegramReminderHabit.proteinShakeKey,
                date: date,
                sessionID: sessionID
            )
        case .medicationDone:
            return service.completeHabit(
                habitKey: TelegramReminderHabit.medicationKey,
                date: date,
                sessionID: sessionID
            )
        case .startTraining, .trainingYes:
            return service.execute(
                .workoutCompleted(date: date, note: "Telegram Reminder"),
                sessionID: sessionID
            )
        case .trainingPauseToday:
            return service.execute(.workoutPaused(date: date), sessionID: sessionID)
        case .remindLater, .trainingLater:
            return .success(message: "Alles klar, ich erinnere dich später nochmal.", affectedModule: .menu)
        case .addMeal, .addExpense:
            return .failure(message: "Diese Aktion startet einen Dialog.", reason: "dialog_action")
        }
    }

    private func todaySnapshot(for date: Date) throws -> TodaySnapshot {
        try TodaySnapshotService(database: database, calendar: calendar).snapshot(for: date)
    }

    private func actionKeyboard(_ actions: [TelegramReminderAction]) -> TelegramKeyboard {
        let buttons = actions.map { TelegramKeyboard.Button(label: $0.label, callbackData: $0.rawValue) }
        return TelegramKeyboard(rows: stride(from: 0, to: buttons.count, by: 2).map {
            Array(buttons[$0..<min($0 + 2, buttons.count)])
        })
    }
}
