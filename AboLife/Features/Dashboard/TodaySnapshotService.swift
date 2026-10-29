import Foundation

enum TodayTrainingStatus: Equatable {
    case completed, paused, open, notScheduled
    var title: String {
        switch self {
        case .completed: return "Training erledigt"
        case .paused: return "Training pausiert"
        case .open: return "Training offen"
        case .notScheduled: return "Heute kein Training geplant"
        }
    }
}

struct TodayOpenStatus: Equatable {
    let training: TodayTrainingStatus
    let openHabitTitles: [String]
    let dailyBudgetRemaining: Double
    var summary: String {
        let items = (training == .open ? ["dein Training"] : []) + openHabitTitles
        return items.isEmpty ? "Für heute ist alles erledigt." : "Noch offen: " + items.joined(separator: ", ") + "."
    }
    var nextStep: String? {
        if let habit = openHabitTitles.first { return "\(habit) ist ein guter nächster Schritt." }
        if training == .open { return "Heute reicht auch eine kurze Trainingseinheit." }
        return nil
    }
    static func calculate(workoutCompletedToday: Bool, trainingPausedToday: Bool, trainingScheduledToday: Bool,
                          habitValues: [String: Double], dailyBudgetRemaining: Double) -> TodayOpenStatus {
        let training: TodayTrainingStatus = workoutCompletedToday ? .completed : trainingPausedToday ? .paused : trainingScheduledToday ? .open : .notScheduled
        return TodayOpenStatus(training: training, openHabitTitles: FixedHabit.defaults.filter { $0.key != "training" && $0.progress(for: habitValues[$0.key] ?? 0) < 1 }.map(\.title), dailyBudgetRemaining: max(dailyBudgetRemaining, 0))
    }
}

struct TodaySnapshot: Equatable {
    let date: Date
    let settings: AppSettingsRecord
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
    var spentToday: Double { financeEntriesToday.reduce(0) { $0 + $1.amount } }
    var dailyBudgetRemaining: Double { FinanceStore.dailyBudgetRemaining(spent: monthlySpent, budget: settings.monthlyBudget, date: date, spentToday: financeEntriesToday.filter { $0.amount > 0 }.reduce(0) { $0 + $1.amount }) }
    var availableToday: Double { dailyBudgetRemaining }
    var todayOpenStatus: TodayOpenStatus {
        .calculate(workoutCompletedToday: workoutCompletedToday, trainingPausedToday: false, trainingScheduledToday: trainingScheduledToday,
                   habitValues: Dictionary(uniqueKeysWithValues: FixedHabit.defaults.map { ($0.key, habitValue(for: $0.key)) }), dailyBudgetRemaining: dailyBudgetRemaining)
    }
    func habitValue(for key: String) -> Double {
        if key == "training" { return workoutCompletedToday ? 1 : 0 }
        guard let habit = FixedHabit.defaultDefinition(for: key), let entry = habitEntriesByKey[key] else { return 0 }
        return max(entry.value ?? (entry.isCompleted ? habit.targetValue : 0), 0)
    }
    func isHabitDone(_ key: String) -> Bool { habitEntriesByKey[key]?.isCompleted == true }
}
struct TodaySnapshotService {
    let database: AppDatabase
    var calendar: Calendar = .current
    func snapshot(for date: Date = Date()) throws -> TodaySnapshot {
        let settings = try SettingsRepository(database: database).loadSettings()
        let finance = FinanceRepository(database: database)
        let workout = WorkoutRepository(database: database)
        let week = DateIntervals.week(containing: date, weekStartsOn: settings.weekStartsOn, calendar: calendar)
        let habits = try HabitRepository(database: database).fetch(for: DateIntervals.dayKey(for: date, calendar: calendar))
        let weights = WeightRepository(database: database)
        let weight = try weights.fetchEntry(for: date, calendar: calendar) ?? weights.latest()
        return TodaySnapshot(date: date, settings: settings,
            financeEntriesToday: try finance.fetch(in: DateIntervals.day(containing: date, calendar: calendar)),
            monthlySpent: try finance.monthSpending(for: date, calendar: calendar), weekInterval: week,
            weeklyWorkoutCompleted: try workout.completedCount(in: week), latestWorkoutThisWeek: try workout.latestCompleted(in: week),
            workoutCompletedToday: try workout.completedCount(forDay: date, calendar: calendar) > 0,
            trainingScheduledToday: HomeWorkoutPlanProvider.plan.workout(for: date, calendar: calendar).isToday,
            habitEntriesByKey: habits.reduce(into: [:]) { $0[$1.habitKey] = $1 }, latestWeight: weight,
            latestWeightChangeKg: try weight.flatMap { try weights.changeFromPrevious(for: $0) })
    }
}
