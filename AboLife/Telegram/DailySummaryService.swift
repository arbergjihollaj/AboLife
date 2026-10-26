import Foundation

struct DailySummarySnapshot: Equatable {
    let dateText: String
    let weightText: String
    let caloriesText: String
    let proteinText: String
    let caloriesRemainingText: String
    let proteinRemainingText: String
    let trainingText: String
    let trainingWeekText: String
    let habitText: String
    let medicationText: String
    let proteinShakeText: String
    let dailyBudgetText: String
    let monthlyBudgetRemainingText: String
    let spentText: String
    let availableTodayText: String
    let openStatusText: String
    let nextStepText: String?
    let isProteinShakeOpen: Bool
    let isMedicationOpen: Bool
}

struct DailySummaryService {
    let database: AppDatabase
    var calendar: Calendar = .current

    func todayText(for date: Date = Date()) throws -> String {
        let snapshot = try snapshot(for: date)
        var lines = [
            "📊 Heute · \(snapshot.dateText)",
            "",
            "🍽 Kalorien: \(snapshot.caloriesText)",
            "🥛 Protein: \(snapshot.proteinText)",
            "🏋️ Training heute: \(snapshot.trainingText)",
            "Woche: \(snapshot.trainingWeekText)",
            "💶 Heute verfügbar: \(snapshot.availableTodayText)",
            "Monatsrest: \(snapshot.monthlyBudgetRemainingText)",
            "✅ Habits: \(snapshot.habitText)",
            "💊 Medikamente: \(snapshot.medicationText) · Shake: \(snapshot.proteinShakeText)",
            "",
            snapshot.openStatusText
        ]
        if let nextStep = snapshot.nextStepText {
            lines.append("Nächster Schritt: \(nextStep)")
        }

        return lines.joined(separator: "\n")
    }

    func morningSummary(for date: Date = Date()) throws -> TelegramReminderMessage {
        let snapshot = try snapshot(for: date)
        let text = """
        Guten Morgen Abo

        Heute:

        * Gewicht: \(snapshot.weightText)
        * Kalorien übrig: \(snapshot.caloriesRemainingText)
        * Protein übrig: \(snapshot.proteinRemainingText)
        * Training heute: \(snapshot.trainingText)
        * Medikamente: \(snapshot.medicationText)
        * Proteinshake: \(snapshot.proteinShakeText)
        * Tagesbudget: \(snapshot.dailyBudgetText)
        * Bereits ausgegeben: \(snapshot.spentText)
        * Verfügbar heute: \(snapshot.availableTodayText)
        """

        var actions: [TelegramReminderAction] = []
        if snapshot.isProteinShakeOpen {
            actions.append(.proteinShakeDone)
        }
        if snapshot.isMedicationOpen {
            actions.append(.medicationDone)
        }
        let today = try TodaySnapshotService(database: database, calendar: calendar).snapshot(for: date)
        if today.todayOpenStatus.training == .open {
            actions.append(.startTraining)
        }
        actions.append(contentsOf: [.addMeal, .addExpense, .remindLater])

        return TelegramReminderMessage(
            kind: .morningSummary,
            text: text,
            keyboard: actionKeyboard(actions)
        )
    }

    func snapshot(for date: Date = Date()) throws -> DailySummarySnapshot {
        let today = try TodaySnapshotService(database: database, calendar: calendar).snapshot(for: date)
        let proteinShakeDone = today.isHabitDone(TelegramReminderHabit.proteinShakeKey)
        let medicationDone = today.isHabitDone(TelegramReminderHabit.medicationKey)
        let openStatus = today.todayOpenStatus
        let scheduledWorkout = HomeWorkoutPlanProvider.plan.workout(for: date, calendar: calendar)
        let trainingText: String
        switch openStatus.training {
        case .completed:
            trainingText = "\(scheduledWorkout.day.name) · erledigt"
        case .paused:
            trainingText = "\(scheduledWorkout.day.name) · pausiert"
        case .open:
            trainingText = "\(scheduledWorkout.day.name) · offen"
        case .notScheduled:
            trainingText = "Heute kein Training geplant"
        }
        let regularHabits = FixedHabit.defaults.filter { !$0.isDerived }
        let completedHabits = regularHabits.filter { today.habitValue(for: $0.key) >= $0.targetValue }.count

        return DailySummarySnapshot(
            dateText: formattedDate(date),
            weightText: today.latestWeight.map { WeightStore.formatWeight($0.weightKg) } ?? "noch nicht eingetragen",
            caloriesText: "\(today.nutritionSummary.caloriesKcal) / \(today.settings.caloriesTarget) kcal",
            proteinText: "\(Int(today.nutritionSummary.proteinG.rounded())) / \(Int(today.settings.proteinTargetG.rounded())) g",
            caloriesRemainingText: "\(today.caloriesRemaining) kcal",
            proteinRemainingText: "\(Int(today.proteinRemainingG.rounded())) g",
            trainingText: trainingText,
            trainingWeekText: "\(today.weeklyWorkoutCompleted) / \(today.settings.weeklyWorkoutTarget)",
            habitText: "\(completedHabits) / \(regularHabits.count) erledigt",
            medicationText: medicationDone ? "erledigt" : "offen",
            proteinShakeText: proteinShakeDone ? "erledigt" : "offen",
            dailyBudgetText: money(today.dailyBudgetRemaining, currency: today.settings.defaultCurrency),
            monthlyBudgetRemainingText: money(
                max(today.settings.monthlyBudget - today.monthlySpent, 0),
                currency: today.settings.defaultCurrency
            ),
            spentText: money(today.spentToday, currency: today.settings.defaultCurrency),
            availableTodayText: money(today.availableToday, currency: today.settings.defaultCurrency),
            openStatusText: openStatus.summary,
            nextStepText: openStatus.nextStep,
            isProteinShakeOpen: !proteinShakeDone,
            isMedicationOpen: !medicationDone
        )
    }

    private func actionKeyboard(_ actions: [TelegramReminderAction]) -> TelegramKeyboard {
        let buttons = actions.map { TelegramKeyboard.Button(label: $0.label, callbackData: $0.rawValue) }
        return TelegramKeyboard(rows: stride(from: 0, to: buttons.count, by: 2).map {
            Array(buttons[$0..<min($0 + 2, buttons.count)])
        })
    }

    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = Locale(identifier: "de_DE")
        formatter.dateFormat = "dd.MM.yyyy"
        return formatter.string(from: date)
    }

    private func money(_ value: Double, currency: String) -> String {
        ExternalInputFormatting.currency(value, currencyCode: currency)
    }
}
