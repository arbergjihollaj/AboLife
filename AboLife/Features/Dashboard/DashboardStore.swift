import Foundation
import Combine

final class DashboardStore: ObservableObject {
    @Published private(set) var snapshot: DashboardSnapshot
    @Published private(set) var state: DashboardMockState

    private let database: AppDatabase?
    private let calendar: Calendar

    init(state: DashboardMockState = .default) {
        self.state = state
        self.snapshot = DashboardMockData.snapshot(from: state)
        self.database = nil
        self.calendar = .current
    }

    init(database: AppDatabase?, calendar: Calendar = .current) {
        let initialState: DashboardMockState = database == nil ? .default : .persistedDefault
        self.state = initialState
        self.snapshot = DashboardMockData.snapshot(from: initialState)
        self.database = database
        self.calendar = calendar
        loadDashboardData()
    }

    convenience init(snapshot: DashboardSnapshot) {
        self.init(state: .default)
        self.snapshot = snapshot
    }

    func addMeal(name: String, calories: Int, protein: Double) {
        let mealName = trimmedOrDefault(name, defaultValue: "Mahlzeit")
        let normalizedCalories = max(calories, 0)
        let normalizedProtein = max(protein, 0)

        guard let database else {
            state.caloriesConsumed += normalizedCalories
            state.proteinConsumed += normalizedProtein
            addActivity(title: "Mahlzeit hinzugefügt", detail: "\(mealName) · \(normalizedCalories) kcal · \(Int(normalizedProtein)) g Protein")
            refreshSnapshot()
            return
        }

        do {
            try NutritionRepository(database: database).insert(
                NutritionEntryRecord(
                    title: mealName,
                    caloriesKcal: normalizedCalories,
                    proteinG: normalizedProtein
                )
            )
            addActivity(title: "Mahlzeit gespeichert", detail: "\(mealName) · \(normalizedCalories) kcal · \(Int(normalizedProtein)) g Protein")
            loadDashboardData()
        } catch {
            addActivity(title: "Mahlzeit nicht gespeichert", detail: error.localizedDescription)
            refreshSnapshot()
        }
    }

    func completeWorkout(type: String, durationMinutes: Int) {
        let workoutType = trimmedOrDefault(type, defaultValue: "Training")
        let normalizedDuration = max(durationMinutes, 0)

        guard let database else {
            if state.weeklyWorkoutCompleted < state.weeklyWorkoutTarget {
                state.weeklyWorkoutCompleted += 1
            }
            state.lastWorkoutType = workoutType
            state.lastWorkoutDurationMinutes = normalizedDuration
            addActivity(title: "Training abgeschlossen", detail: "\(workoutType) · \(normalizedDuration) Min")
            refreshSnapshot()
            return
        }

        do {
            try WorkoutRepository(database: database).insert(
                WorkoutSessionRecord(
                    workoutType: workoutType,
                    durationMin: normalizedDuration,
                    status: "done"
                )
            )
            addActivity(title: "Training gespeichert", detail: "\(workoutType) · \(normalizedDuration) Min")
            loadDashboardData()
        } catch {
            addActivity(title: "Training nicht gespeichert", detail: error.localizedDescription)
            refreshSnapshot()
        }
    }

    func addExpense(title: String, amount: Double, category: String?) {
        let expenseTitle = trimmedOrDefault(title, defaultValue: "Ausgabe")
        let normalizedAmount = max(amount, 0)
        let categoryText = trimmedOrDefault(category ?? "", defaultValue: "Sonstiges")

        guard let database else {
            state.monthlySpent += normalizedAmount
            addActivity(title: "Ausgabe hinzugefügt", detail: "\(expenseTitle) · \(Int(normalizedAmount)) EUR · \(categoryText)")
            refreshSnapshot()
            return
        }

        do {
            let currency = try SettingsRepository(database: database).fetchDefault()?.defaultCurrency ?? SeedData.defaultSettings.defaultCurrency
            try FinanceRepository(database: database).insert(
                FinanceEntryRecord(
                    title: expenseTitle,
                    amount: normalizedAmount,
                    currency: currency,
                    category: categoryText
                )
            )
            addActivity(title: "Ausgabe gespeichert", detail: "\(expenseTitle) · \(Int(normalizedAmount)) \(currency) · \(categoryText)")
            loadDashboardData()
        } catch {
            addActivity(title: "Ausgabe nicht gespeichert", detail: error.localizedDescription)
            refreshSnapshot()
        }
    }

    func toggleHabit(_ habitID: DashboardHabit.ID) {
        guard let index = state.habits.firstIndex(where: { $0.id == habitID }) else { return }
        state.habits[index].isCompleted.toggle()

        let habit = state.habits[index]
        let status = habit.isCompleted ? "abgehakt" : "wieder geöffnet"

        guard let database else {
            addActivity(title: "Gewohnheit aktualisiert", detail: "\(habit.title) \(status)")
            refreshSnapshot()
            return
        }

        do {
            try HabitRepository(database: database).upsertCompletion(
                habitKey: habit.key,
                date: DateIntervals.dayKey(calendar: calendar),
                isCompleted: habit.isCompleted
            )
            addActivity(title: "Gewohnheit gespeichert", detail: "\(habit.title) \(status)")
            loadDashboardData()
        } catch {
            state.habits[index].isCompleted.toggle()
            addActivity(title: "Gewohnheit nicht gespeichert", detail: error.localizedDescription)
            refreshSnapshot()
        }
    }

    func updateWeight(_ weight: Double) {
        let normalizedWeight = max(weight, 0)

        guard let database else {
            state.bodyWeight = normalizedWeight
            addActivity(title: "Gewicht erfasst", detail: "\(String(format: "%.1f", normalizedWeight)) kg")
            refreshSnapshot()
            return
        }

        do {
            try BodyMetricRepository(database: database).insert(
                BodyMetricEntryRecord(weightKg: normalizedWeight)
            )
            addActivity(title: "Gewicht gespeichert", detail: "\(String(format: "%.1f", normalizedWeight)) kg")
            loadDashboardData()
        } catch {
            addActivity(title: "Gewicht nicht gespeichert", detail: error.localizedDescription)
            refreshSnapshot()
        }
    }

    func updateDailyNote(_ note: String) {
        let trimmed = note.trimmingCharacters(in: .whitespacesAndNewlines)
        state.dailyNote = trimmed.isEmpty ? nil : trimmed
        addActivity(title: "Notiz gespeichert", detail: trimmed.isEmpty ? "Tagesnotiz geleert" : trimmed)
        refreshSnapshot()
    }

    static func dailyCoreProgress(for state: DashboardMockState) -> Double {
        let calories = progress(current: Double(state.caloriesConsumed), target: Double(state.caloriesTarget))
        let protein = progress(current: state.proteinConsumed, target: state.proteinTarget)
        let training = progress(current: Double(state.weeklyWorkoutCompleted), target: Double(state.weeklyWorkoutTarget))
        let habits = progress(current: Double(state.completedHabits), target: Double(state.totalHabits))
        let budget = budgetScore(spent: state.monthlySpent, budget: state.monthlyBudget)

        return clamp((calories + protein + training + habits + budget) / 5)
    }

    func refreshFromPersistence() {
        loadDashboardData()
    }

    private func refreshSnapshot() {
        snapshot = DashboardMockData.snapshot(from: state)
    }

    private func loadDashboardData() {
        guard let database else {
            refreshSnapshot()
            return
        }

        do {
            let settings = try SettingsRepository(database: database).fetchDefault() ?? SeedData.defaultSettings
            let nutritionSummary = try NutritionRepository(database: database).daySummary(calendar: calendar)
            let financeSpent = try FinanceRepository(database: database).monthSpending(calendar: calendar)
            let weekInterval = DateIntervals.week(weekStartsOn: settings.weekStartsOn, calendar: calendar)
            let workoutRepository = WorkoutRepository(database: database)
            let workoutCount = try workoutRepository.completedCount(in: weekInterval)
            let latestWorkout = try workoutRepository.latestCompleted(in: weekInterval)
            let habitEntries = try HabitRepository(database: database).fetch(for: DateIntervals.dayKey(calendar: calendar))
            let habitCompletionByKey = Dictionary(uniqueKeysWithValues: habitEntries.map { ($0.habitKey, $0.isCompleted) })
            let latestBodyMetric = try BodyMetricRepository(database: database).latest()

            state.caloriesTarget = settings.caloriesTarget
            state.proteinTarget = settings.proteinTargetG
            state.monthlyBudget = settings.monthlyBudget
            state.caloriesConsumed = nutritionSummary.caloriesKcal
            state.proteinConsumed = nutritionSummary.proteinG
            state.monthlySpent = financeSpent
            state.weeklyWorkoutCompleted = workoutCount
            state.weeklyWorkoutTarget = 3
            state.lastWorkoutType = latestWorkout?.workoutType
            state.lastWorkoutDurationMinutes = latestWorkout?.durationMin
            state.bodyWeight = latestBodyMetric?.weightKg
            state.habits = DashboardMockState.persistedHabits.map { habit in
                DashboardHabit(
                    id: habit.id,
                    key: habit.key,
                    title: habit.title,
                    isCompleted: habitCompletionByKey[habit.key] ?? false
                )
            }

            if state.recentActions.isEmpty {
                addActivity(title: "Lokale Daten geladen", detail: "SQLite-Summaries sind aktiv.")
            }

            refreshSnapshot()
        } catch {
            addActivity(title: "Lokale Daten nicht geladen", detail: error.localizedDescription)
            refreshSnapshot()
        }
    }

    private func addActivity(title: String, detail: String) {
        state.recentActions.insert(
            DashboardActivityItem(title: title, detail: detail, createdAt: Date()),
            at: 0
        )
        state.recentActions = Array(state.recentActions.prefix(5))
    }

    private func trimmedOrDefault(_ value: String, defaultValue: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? defaultValue : trimmed
    }

    private static func progress(current: Double, target: Double) -> Double {
        guard target > 0 else { return 0 }
        return clamp(current / target)
    }

    private static func budgetScore(spent: Double, budget: Double) -> Double {
        guard budget > 0 else { return 1 }
        return clamp(1 - (spent / budget))
    }

    private static func clamp(_ value: Double) -> Double {
        min(max(value, 0), 1)
    }
}

struct DashboardMockState {
    var caloriesConsumed: Int
    var caloriesTarget: Int
    var proteinConsumed: Double
    var proteinTarget: Double
    var weeklyWorkoutCompleted: Int
    var weeklyWorkoutTarget: Int
    var monthlySpent: Double
    var monthlyBudget: Double
    var habits: [DashboardHabit]
    var bodyWeight: Double?
    var dailyNote: String?
    var recentActions: [DashboardActivityItem]
    var lastWorkoutType: String?
    var lastWorkoutDurationMinutes: Int?

    var completedHabits: Int {
        habits.filter(\.isCompleted).count
    }

    var totalHabits: Int {
        habits.count
    }

    var dailyBudgetRemaining: Double {
        max((monthlyBudget - monthlySpent) / 18, 0)
    }

    static let `default` = DashboardMockState(
        caloriesConsumed: 1450,
        caloriesTarget: 2200,
        proteinConsumed: 95,
        proteinTarget: 160,
        weeklyWorkoutCompleted: 2,
        weeklyWorkoutTarget: 3,
        monthlySpent: 684,
        monthlyBudget: 1200,
        habits: [
            DashboardHabit(key: "morning_water", title: "Wasser", isCompleted: false),
            DashboardHabit(key: "walk", title: "10 Minuten gehen", isCompleted: true),
            DashboardHabit(key: "protein", title: "Protein priorisieren", isCompleted: true),
            DashboardHabit(key: "reading", title: "Lesen", isCompleted: false),
            DashboardHabit(key: "budget_check", title: "Budget checken", isCompleted: true)
        ],
        bodyWeight: nil,
        dailyNote: nil,
        recentActions: [
            DashboardActivityItem(title: "Mock-Tag geladen", detail: "Alle Werte sind nur In-Memory.", createdAt: Date())
        ],
        lastWorkoutType: nil,
        lastWorkoutDurationMinutes: nil
    )

    static let persistedHabits: [DashboardHabit] = [
        DashboardHabit(key: "water", title: "Wasser", isCompleted: false),
        DashboardHabit(key: "movement", title: "Bewegung", isCompleted: false),
        DashboardHabit(key: "nutrition", title: "Ernährung", isCompleted: false),
        DashboardHabit(key: "learning", title: "Lernen", isCompleted: false),
        DashboardHabit(key: "sleep", title: "Schlaf", isCompleted: false)
    ]

    static let persistedDefault = DashboardMockState(
        caloriesConsumed: 0,
        caloriesTarget: SeedData.defaultSettings.caloriesTarget,
        proteinConsumed: 0,
        proteinTarget: SeedData.defaultSettings.proteinTargetG,
        weeklyWorkoutCompleted: 0,
        weeklyWorkoutTarget: 3,
        monthlySpent: 0,
        monthlyBudget: SeedData.defaultSettings.monthlyBudget,
        habits: persistedHabits,
        bodyWeight: nil,
        dailyNote: nil,
        recentActions: [],
        lastWorkoutType: nil,
        lastWorkoutDurationMinutes: nil
    )
}

struct DashboardHabit: Identifiable, Equatable {
    let id: UUID
    let key: String
    let title: String
    var isCompleted: Bool

    init(id: UUID = UUID(), key: String, title: String, isCompleted: Bool) {
        self.id = id
        self.key = key
        self.title = title
        self.isCompleted = isCompleted
    }
}

struct DashboardActivityItem: Identifiable, Equatable {
    let id: UUID
    let title: String
    let detail: String
    let createdAt: Date

    init(id: UUID = UUID(), title: String, detail: String, createdAt: Date) {
        self.id = id
        self.title = title
        self.detail = detail
        self.createdAt = createdAt
    }
}
