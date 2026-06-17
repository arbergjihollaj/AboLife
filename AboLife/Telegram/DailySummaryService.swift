import Foundation

struct DailySummarySnapshot: Equatable {
    let weightText: String
    let caloriesRemainingText: String
    let proteinRemainingText: String
    let trainingText: String
    let medicationText: String
    let proteinShakeText: String
    let dailyBudgetText: String
    let spentText: String
    let availableTodayText: String
    let isProteinShakeOpen: Bool
    let isMedicationOpen: Bool
}

struct DailySummaryService {
    let database: AppDatabase
    var calendar: Calendar = .current

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

        return TelegramReminderMessage(
            kind: .morningSummary,
            text: text,
            keyboard: actionKeyboard([
                .proteinShakeDone,
                .medicationDone,
                .startTraining,
                .addMeal,
                .addExpense,
                .remindLater
            ])
        )
    }

    func snapshot(for date: Date = Date()) throws -> DailySummarySnapshot {
        let settings = try SettingsRepository(database: database).loadSettings()
        let nutrition = try NutritionRepository(database: database).daySummary(for: date, calendar: calendar)
        let todayFinance = try FinanceRepository(database: database).fetch(in: DateIntervals.day(containing: date, calendar: calendar))
        let monthlySpent = try FinanceRepository(database: database).monthSpending(for: date, calendar: calendar)
        let weight = try WeightRepository(database: database).fetchEntry(for: date, calendar: calendar) ?? WeightRepository(database: database).latest()
        let dayKey = DateIntervals.dayKey(for: date, calendar: calendar)
        let proteinShakeDone = try isHabitDone(TelegramReminderHabit.proteinShakeKey, dayKey: dayKey)
        let medicationDone = try isHabitDone(TelegramReminderHabit.medicationKey, dayKey: dayKey)

        let caloriesRemaining = max(settings.caloriesTarget - nutrition.caloriesKcal, 0)
        let proteinRemaining = max(settings.proteinTargetG - nutrition.proteinG, 0)
        let spentToday = todayFinance.reduce(0) { $0 + $1.amount }
        let dailyBudget = FinanceStore.dailyBudgetRemaining(spent: monthlySpent, budget: settings.monthlyBudget, date: date, calendar: calendar)
        let availableToday = max(dailyBudget - spentToday, 0)

        return DailySummarySnapshot(
            weightText: weight.map { WeightStore.formatWeight($0.weightKg) } ?? "noch nicht eingetragen",
            caloriesRemainingText: "\(caloriesRemaining) kcal",
            proteinRemainingText: "\(Int(proteinRemaining.rounded())) g",
            trainingText: TrainingPlanSeeder.weeklyPlan.workout(for: date, calendar: calendar).day.name,
            medicationText: medicationDone ? "erledigt" : "offen",
            proteinShakeText: proteinShakeDone ? "erledigt" : "offen",
            dailyBudgetText: euro(dailyBudget, currency: settings.defaultCurrency),
            spentText: euro(spentToday, currency: settings.defaultCurrency),
            availableTodayText: euro(availableToday, currency: settings.defaultCurrency),
            isProteinShakeOpen: !proteinShakeDone,
            isMedicationOpen: !medicationDone
        )
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

    private func euro(_ value: Double, currency: String) -> String {
        "\(Int(value.rounded())) \(currency)"
    }
}
