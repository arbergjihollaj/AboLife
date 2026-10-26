import Foundation

enum TodayTrainingStatus: Equatable {
    case completed
    case paused
    case open
    case notScheduled

    var title: String {
        switch self {
        case .completed:
            return "Training erledigt"
        case .paused:
            return "Training pausiert"
        case .open:
            return "Training offen"
        case .notScheduled:
            return "Heute kein Training geplant"
        }
    }
}

struct TodayOpenStatus: Equatable {
    let caloriesRemaining: Int
    let caloriesOverTarget: Int
    let proteinRemainingG: Double
    let training: TodayTrainingStatus
    let openHabitTitles: [String]
    let isMedicationOpen: Bool
    let isProteinShakeOpen: Bool
    let dailyBudgetRemaining: Double

    var summary: String {
        let items = summaryItems
        guard !items.isEmpty else {
            return "Guter Stand. Für heute ist nichts Wesentliches mehr offen."
        }

        let details = Self.join(items: Array(items.prefix(3)))
        if training == .completed {
            return "Training ist erledigt. Offen sind noch \(details)."
        }
        if items.count == 1 {
            return "Guter Stand. Heute fehlt nur noch \(details)."
        }
        return "Noch offen: \(details)."
    }

    var nextStep: String? {
        if proteinRemainingG > 0 {
            return "Eine proteinreiche Mahlzeit oder dein Proteinshake wäre ein ruhiger nächster Schritt."
        }
        if isMedicationOpen {
            return "Wenn es für dich passt, kannst du als Nächstes deine Medikamente abhaken."
        }
        if training == .open {
            return "Das geplante Training ist der nächste sinnvolle Schritt."
        }
        if let habit = openHabitTitles.first {
            return "\(habit) ist ein guter kleiner nächster Schritt."
        }
        if isProteinShakeOpen {
            return "Dein Proteinshake ist der letzte kleine offene Punkt."
        }
        return nil
    }

    static func calculate(
        caloriesConsumed: Int,
        caloriesTarget: Int,
        proteinConsumedG: Double,
        proteinTargetG: Double,
        workoutCompletedToday: Bool,
        trainingPausedToday: Bool,
        trainingScheduledToday: Bool,
        habitValues: [String: Double],
        medicationDone: Bool,
        proteinShakeDone: Bool,
        dailyBudgetRemaining: Double
    ) -> TodayOpenStatus {
        let calorieDifference = caloriesTarget - caloriesConsumed
        let training: TodayTrainingStatus
        if workoutCompletedToday {
            training = .completed
        } else if trainingPausedToday {
            training = .paused
        } else if trainingScheduledToday {
            training = .open
        } else {
            training = .notScheduled
        }

        let openHabits = FixedHabit.defaults.compactMap { habit -> String? in
            guard habit.key != "training" else { return nil }
            let value = max(habitValues[habit.key] ?? 0, 0)
            return habit.progress(for: value) < 1 ? habit.title : nil
        }

        return TodayOpenStatus(
            caloriesRemaining: max(calorieDifference, 0),
            caloriesOverTarget: max(-calorieDifference, 0),
            proteinRemainingG: max(proteinTargetG - proteinConsumedG, 0),
            training: training,
            openHabitTitles: openHabits,
            isMedicationOpen: !medicationDone,
            isProteinShakeOpen: !proteinShakeDone,
            dailyBudgetRemaining: max(dailyBudgetRemaining, 0)
        )
    }

    private var summaryItems: [String] {
        var items: [String] = []
        if proteinRemainingG > 0 {
            items.append("\(Int(proteinRemainingG.rounded())) g Protein")
        }
        if training == .open {
            items.append("dein Training")
        }
        if isMedicationOpen {
            items.append("Medikamente")
        }
        if isProteinShakeOpen {
            items.append("dein Proteinshake")
        }
        items.append(contentsOf: openHabitTitles)
        return items
    }

    private static func join(items: [String]) -> String {
        guard let last = items.last else { return "" }
        guard items.count > 1 else { return last }
        return items.dropLast().joined(separator: ", ") + " und " + last
    }
}

struct TodaySnapshot: Equatable {
    let date: Date
    let settings: AppSettingsRecord
    let nutritionSummary: NutritionDaySummary
    let financeEntriesToday: [FinanceEntryRecord]
    let monthlySpent: Double
    let weekInterval: DateInterval
    let weeklyWorkoutCompleted: Int
    let latestWorkoutThisWeek: WorkoutSessionRecord?
    let workoutCompletedToday: Bool
    let trainingScheduledToday: Bool
    let habitEntriesByKey: [String: HabitEntryRecord]
    let latestWeight: WeightEntryRecord?
    let latestWeightChangeKg: Double?

    var caloriesRemaining: Int {
        max(settings.caloriesTarget - nutritionSummary.caloriesKcal, 0)
    }

    var proteinRemainingG: Double {
        max(settings.proteinTargetG - nutritionSummary.proteinG, 0)
    }

    var spentToday: Double {
        financeEntriesToday.reduce(0) { $0 + $1.amount }
    }

    var dailyBudgetRemaining: Double {
        FinanceStore.dailyBudgetRemaining(
            spent: monthlySpent,
            budget: settings.monthlyBudget,
            date: date
        )
    }

    var availableToday: Double {
        dailyBudgetRemaining
    }

    var todayOpenStatus: TodayOpenStatus {
        TodayOpenStatus.calculate(
            caloriesConsumed: nutritionSummary.caloriesKcal,
            caloriesTarget: settings.caloriesTarget,
            proteinConsumedG: nutritionSummary.proteinG,
            proteinTargetG: settings.proteinTargetG,
            workoutCompletedToday: workoutCompletedToday,
            trainingPausedToday: isHabitDone(TelegramReminderHabit.trainingPausedKey),
            trainingScheduledToday: trainingScheduledToday,
            habitValues: Dictionary(uniqueKeysWithValues: FixedHabit.defaults.map { ($0.key, habitValue(for: $0.key)) }),
            medicationDone: isHabitDone(TelegramReminderHabit.medicationKey),
            proteinShakeDone: isHabitDone(TelegramReminderHabit.proteinShakeKey),
            dailyBudgetRemaining: dailyBudgetRemaining
        )
    }

    func habitValue(for key: String) -> Double {
        if key == "training" {
            return workoutCompletedToday ? 1 : 0
        }
        guard let habit = FixedHabit.defaultDefinition(for: key) else { return 0 }
        guard let entry = habitEntriesByKey[key] else { return 0 }
        return max(entry.value ?? (entry.isCompleted ? habit.targetValue : 0), 0)
    }

    func isHabitDone(_ key: String) -> Bool {
        habitEntriesByKey[key]?.isCompleted == true
    }
}

struct TodaySnapshotService {
    let database: AppDatabase
    var calendar: Calendar = .current

    func snapshot(for date: Date = Date()) throws -> TodaySnapshot {
        let settings = try SettingsRepository(database: database).loadSettings()
        let nutrition = try NutritionRepository(database: database).daySummary(for: date, calendar: calendar)
        let financeRepository = FinanceRepository(database: database)
        let financeToday = try financeRepository.fetch(in: DateIntervals.day(containing: date, calendar: calendar))
        let monthlySpent = try financeRepository.monthSpending(for: date, calendar: calendar)
        let weekInterval = DateIntervals.week(containing: date, weekStartsOn: settings.weekStartsOn, calendar: calendar)
        let workoutRepository = WorkoutRepository(database: database)
        let weeklyWorkoutCount = try workoutRepository.completedCount(in: weekInterval)
        let latestWorkout = try workoutRepository.latestCompleted(in: weekInterval)
        let workoutCompletedToday = try workoutRepository.completedCount(forDay: date, calendar: calendar) > 0
        let trainingScheduledToday = HomeWorkoutPlanProvider.plan.workout(for: date, calendar: calendar).isToday
        let dayKey = DateIntervals.dayKey(for: date, calendar: calendar)
        let habitEntries = try HabitRepository(database: database).fetch(for: dayKey)
        let habitEntriesByKey = habitEntries.reduce(into: [String: HabitEntryRecord]()) { result, entry in
            result[entry.habitKey] = entry
        }
        let weightRepository = WeightRepository(database: database)
        let latestWeight = try weightRepository.fetchEntry(for: date, calendar: calendar) ?? weightRepository.latest()

        return TodaySnapshot(
            date: date,
            settings: settings,
            nutritionSummary: nutrition,
            financeEntriesToday: financeToday,
            monthlySpent: monthlySpent,
            weekInterval: weekInterval,
            weeklyWorkoutCompleted: weeklyWorkoutCount,
            latestWorkoutThisWeek: latestWorkout,
            workoutCompletedToday: workoutCompletedToday,
            trainingScheduledToday: trainingScheduledToday,
            habitEntriesByKey: habitEntriesByKey,
            latestWeight: latestWeight,
            latestWeightChangeKg: try latestWeight.flatMap { try weightRepository.changeFromPrevious(for: $0) }
        )
    }
}
