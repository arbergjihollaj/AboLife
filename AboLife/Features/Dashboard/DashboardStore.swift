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
        let initialState: DashboardMockState = .persistedDefault
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

    func addMeal(name: String, calories: Int, protein: Double, note: String? = nil) {
        let mealName = trimmedOrDefault(name, defaultValue: "Mahlzeit")
        let normalizedCalories = max(calories, 0)
        let normalizedProtein = Self.nonNegativeFinite(protein)
        let trimmedNote = optionalTrimmed(note)

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
                    proteinG: normalizedProtein,
                    note: trimmedNote
                )
            )
            addActivity(title: "Mahlzeit gespeichert", detail: "\(mealName) · \(normalizedCalories) kcal · \(Int(normalizedProtein)) g Protein")
            loadDashboardData()
        } catch {
            addActivity(title: "Mahlzeit nicht gespeichert", detail: "Bitte Eingabe prüfen und erneut versuchen.")
            refreshSnapshot()
        }
    }

    func completeWorkout(type: String, durationMinutes: Int, note: String? = nil) {
        let workoutType = trimmedOrDefault(type, defaultValue: "Training")
        let normalizedDuration = max(durationMinutes, 0)
        let trimmedNote = optionalTrimmed(note)

        guard let database else {
            if state.weeklyWorkoutCompleted < state.weeklyWorkoutTarget {
                state.weeklyWorkoutCompleted += 1
            }
            state.workoutCompletedToday = true
            state.trainingPausedToday = false
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
                    status: "done",
                    note: trimmedNote
                )
            )
            addActivity(title: "Training gespeichert", detail: "\(workoutType) · \(normalizedDuration) Min")
            loadDashboardData()
        } catch {
            addActivity(title: "Training nicht gespeichert", detail: "Bitte erneut versuchen.")
            refreshSnapshot()
        }
    }

    func addExpense(title: String, amount: Double, category: String?, note: String? = nil) {
        let expenseTitle = trimmedOrDefault(title, defaultValue: "Ausgabe")
        let normalizedAmount = Self.nonNegativeFinite(amount)
        let categoryText = FinanceCategoryCatalog.normalized(category ?? "", kind: .expense)
        let trimmedNote = optionalTrimmed(note)

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
                    category: categoryText,
                    note: trimmedNote
                )
            )
            addActivity(title: "Ausgabe gespeichert", detail: "\(expenseTitle) · \(Int(normalizedAmount)) \(currency) · \(categoryText)")
            loadDashboardData()
        } catch {
            addActivity(title: "Ausgabe nicht gespeichert", detail: "Bitte Betrag und Kategorie prüfen.")
            refreshSnapshot()
        }
    }

    func toggleHabit(_ habitID: DashboardHabit.ID) {
        guard let index = state.habits.firstIndex(where: { $0.id == habitID }) else { return }
        let habit = state.habits[index]
        guard let definition = FixedHabit.defaultDefinition(for: habit.key), !definition.isDerived else { return }

        let nextValue = habit.isCompleted ? 0 : definition.targetValue
        state.habits[index].value = nextValue
        state.habits[index].displayText = Self.dashboardDisplayText(for: definition, value: nextValue)
        let status = state.habits[index].isCompleted ? "abgehakt" : "wieder geöffnet"

        guard let database else {
            addActivity(title: "Gewohnheit aktualisiert", detail: "\(habit.title) \(status)")
            refreshSnapshot()
            return
        }

        do {
            try HabitRepository(database: database).upsertCompletion(
                habitKey: habit.key,
                date: DateIntervals.dayKey(calendar: calendar),
                isCompleted: state.habits[index].isCompleted
            )
            addActivity(title: "Gewohnheit gespeichert", detail: "\(habit.title) \(status)")
            loadDashboardData()
        } catch {
            state.habits[index].value = habit.value
            state.habits[index].displayText = habit.displayText
            addActivity(title: "Gewohnheit nicht gespeichert", detail: "Bitte erneut versuchen.")
            refreshSnapshot()
        }
    }

    func completeHomeWorkout(intensity: HomeWorkoutIntensity, completedExerciseCount: Int? = nil) {
        let plan = HomeWorkoutPlanProvider.plan
        let scheduledWorkout = plan.workout(for: Date(), calendar: calendar)
        let exerciseCount = completedExerciseCount ?? scheduledWorkout.day.exercises(for: intensity).count
        let session = plan.makeWorkoutSession(
            for: scheduledWorkout,
            intensity: intensity,
            completedExerciseCount: exerciseCount
        )

        guard let database else {
            if state.weeklyWorkoutCompleted < state.weeklyWorkoutTarget {
                state.weeklyWorkoutCompleted += 1
            }
            state.workoutCompletedToday = true
            state.trainingPausedToday = false
            state.lastWorkoutType = session.workoutType
            state.lastWorkoutDurationMinutes = session.durationMin
            addActivity(title: "Training abgeschlossen", detail: "\(session.workoutType) · \(session.durationMin) Min")
            refreshSnapshot()
            return
        }

        do {
            try WorkoutRepository(database: database).insert(session)
            addActivity(title: "Training gespeichert", detail: "\(session.workoutType) · \(session.durationMin) Min")
            loadDashboardData()
        } catch {
            addActivity(title: "Training nicht gespeichert", detail: "Bitte erneut versuchen.")
            refreshSnapshot()
        }
    }

    func quickHabitValues() -> [String: Double] {
        guard let database else {
            return Dictionary(uniqueKeysWithValues: FixedHabit.defaults.map { habit in
                let completed = state.habits.first { $0.key == habit.key }?.isCompleted ?? false
                return (habit.key, completed ? habit.targetValue : 0)
            })
        }

        do {
            let entries = try HabitRepository(database: database).fetch(for: DateIntervals.dayKey(calendar: calendar))
            let workoutCompletedToday = try WorkoutRepository(database: database).completedCount(forDay: Date(), calendar: calendar) > 0
            return Dictionary(uniqueKeysWithValues: FixedHabit.defaults.map { habit in
                if habit.key == "training" {
                    return (habit.key, workoutCompletedToday ? 1 : 0)
                }
                let entry = entries.first { $0.habitKey == habit.key }
                let value = entry?.value ?? (entry?.isCompleted == true ? habit.targetValue : 0)
                return (habit.key, max(value, 0))
            })
        } catch {
            addActivity(title: "Gewohnheiten nicht geladen", detail: "Bitte später erneut versuchen.")
            refreshSnapshot()
            return [:]
        }
    }

    @discardableResult
    func applyHabitDelta(habitKey: String, delta: Double) -> Double {
        guard let habit = FixedHabit.defaultDefinition(for: habitKey) else { return 0 }
        guard !habit.isDerived else { return quickHabitValues()[habitKey] ?? 0 }
        let current = quickHabitValues()[habitKey] ?? 0
        let nextValue = max(current + delta, 0)
        setHabitValue(habit, value: nextValue)
        return nextValue
    }

    func setSleepRoutine(isCompleted: Bool) {
        guard let sleep = FixedHabit.defaultDefinition(for: "sleep") else { return }
        setHabitValue(sleep, value: isCompleted ? 1 : 0)
    }

    @discardableResult
    func completeHabit(habitKey: String) -> Bool {
        guard let database else {
            if let habit = FixedHabit.defaultDefinition(for: habitKey), !habit.isDerived,
               let index = state.habits.firstIndex(where: { $0.key == habitKey }) {
                state.habits[index].value = habit.targetValue
                state.habits[index].displayText = Self.dashboardDisplayText(for: habit, value: habit.targetValue)
            } else if habitKey == TelegramReminderHabit.medicationKey {
                state.medicationDone = true
            } else if habitKey == TelegramReminderHabit.proteinShakeKey {
                state.proteinShakeDone = true
            } else {
                return false
            }
            addActivity(title: "Gewohnheit gespeichert", detail: Self.habitTitle(for: habitKey))
            refreshSnapshot()
            return true
        }

        let result = ExternalInputService(database: database, calendar: calendar)
            .completeHabit(habitKey: habitKey)
        guard case .success = result else {
            addActivity(title: "Gewohnheit nicht gespeichert", detail: "Bitte erneut versuchen.")
            refreshSnapshot()
            return false
        }

        addActivity(title: "Gewohnheit gespeichert", detail: Self.habitTitle(for: habitKey))
        loadDashboardData()
        return true
    }

    @discardableResult
    func updateWeight(_ weight: Double) -> Bool {
        guard Self.isPlausibleWeight(weight) else {
            addActivity(title: "Gewicht nicht gespeichert", detail: "Bitte gib einen Wert zwischen 20 und 300 kg ein.")
            refreshSnapshot()
            return false
        }

        let normalizedWeight = WeightRepository.normalizedWeight(weight)
        let todayKey = DateIntervals.dayKey(calendar: calendar)

        guard let database else {
            state.bodyWeight = normalizedWeight
            state.bodyWeightDate = todayKey
            state.bodyWeightChange = nil
            addActivity(title: "Gewicht erfasst", detail: "\(String(format: "%.1f", normalizedWeight)) kg")
            refreshSnapshot()
            return true
        }

        do {
            let repository = WeightRepository(database: database)
            let entry = try repository.upsert(dayKey: todayKey, weightKg: normalizedWeight)
            let change = try repository.changeFromPrevious(for: entry)
            addActivity(title: "Gewicht gespeichert", detail: "\(String(format: "%.1f", normalizedWeight)) kg")
            state.bodyWeight = entry.weightKg
            state.bodyWeightDate = entry.date
            state.bodyWeightChange = change
            loadDashboardData()
            return true
        } catch {
            addActivity(title: "Gewicht nicht gespeichert", detail: "Bitte Eingabe prüfen und erneut versuchen.")
            refreshSnapshot()
            return false
        }
    }

    static func dailyCoreProgress(for state: DashboardMockState) -> Double {
        let calories = progress(current: Double(state.caloriesConsumed), target: Double(state.caloriesTarget))
        let protein = progress(current: state.proteinConsumed, target: state.proteinTarget)
        let training = progress(current: Double(state.weeklyWorkoutCompleted), target: Double(state.weeklyWorkoutTarget))
        let habits = state.habitProgress
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
            let today = try TodaySnapshotService(database: database, calendar: calendar).snapshot()
            let settings = today.settings

            state.caloriesTarget = settings.caloriesTarget
            state.proteinTarget = settings.proteinTargetG
            state.monthlyBudget = settings.monthlyBudget
            state.caloriesConsumed = today.nutritionSummary.caloriesKcal
            state.proteinConsumed = today.nutritionSummary.proteinG
            state.monthlySpent = today.monthlySpent
            state.weeklyWorkoutCompleted = today.weeklyWorkoutCompleted
            state.weeklyWorkoutTarget = settings.weeklyWorkoutTarget
            state.lastWorkoutType = today.latestWorkoutThisWeek?.workoutType
            state.lastWorkoutDurationMinutes = today.latestWorkoutThisWeek?.durationMin
            state.bodyWeight = today.latestWeight?.weightKg
            state.bodyWeightDate = today.latestWeight?.date
            state.bodyWeightChange = today.latestWeightChangeKg
            state.bodyWeightTarget = settings.targetWeightKg
            state.bodyWeightLowerBound = settings.targetWeightLowerKg
            state.bodyWeightUpperBound = settings.targetWeightUpperKg
            state.habits = Self.makeDashboardHabits(
                entriesByKey: today.habitEntriesByKey,
                workoutCompletedToday: today.workoutCompletedToday
            )
            state.workoutCompletedToday = today.workoutCompletedToday
            state.trainingScheduledToday = today.trainingScheduledToday
            state.trainingPausedToday = today.isHabitDone(TelegramReminderHabit.trainingPausedKey)
            state.medicationDone = today.isHabitDone(TelegramReminderHabit.medicationKey)
            state.proteinShakeDone = today.isHabitDone(TelegramReminderHabit.proteinShakeKey)

            refreshSnapshot()
        } catch {
            addActivity(title: "Lokale Daten nicht geladen", detail: "Bitte später erneut versuchen.")
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

    private func optionalTrimmed(_ value: String?) -> String? {
        let trimmed = (value ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private func setHabitValue(_ habit: FixedHabit, value: Double) {
        guard !habit.isDerived else { return }
        let normalizedValue = Self.nonNegativeFinite(value)

        guard let database else {
            if let index = state.habits.firstIndex(where: { $0.key == habit.key }) {
                state.habits[index].value = normalizedValue
                state.habits[index].displayText = Self.dashboardDisplayText(for: habit, value: normalizedValue)
            }
            addActivity(title: "Gewohnheit aktualisiert", detail: "\(habit.title) \(habit.displayValue(normalizedValue))")
            refreshSnapshot()
            return
        }

        do {
            try HabitRepository(database: database).setValue(
                habitKey: habit.key,
                date: DateIntervals.dayKey(calendar: calendar),
                value: normalizedValue,
                target: habit.targetValue,
                unit: habit.unit
            )
            addActivity(title: "Gewohnheit gespeichert", detail: "\(habit.title) \(habit.displayValue(normalizedValue))")
            loadDashboardData()
        } catch {
            addActivity(title: "Gewohnheit nicht gespeichert", detail: "Bitte erneut versuchen.")
            refreshSnapshot()
        }
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

    private static func nonNegativeFinite(_ value: Double) -> Double {
        value.isFinite ? max(value, 0) : 0
    }

    private static func isPlausibleWeight(_ value: Double) -> Bool {
        value.isFinite && value >= 20 && value <= 300
    }

    private static func habitTitle(for key: String) -> String {
        if key == TelegramReminderHabit.medicationKey {
            return "Medikamente erledigt"
        }
        if key == TelegramReminderHabit.proteinShakeKey {
            return "Proteinshake erledigt"
        }
        return FixedHabit.defaultDefinition(for: key)?.title ?? "Gewohnheit erledigt"
    }
}

private extension DashboardStore {
    static func makeDashboardHabits(entriesByKey: [String: HabitEntryRecord], workoutCompletedToday: Bool) -> [DashboardHabit] {
        FixedHabit.defaults.map { habit in
            let value: Double
            if habit.key == "training" {
                value = workoutCompletedToday ? 1 : 0
            } else if let entry = entriesByKey[habit.key] {
                value = entry.value ?? (entry.isCompleted ? habit.targetValue : 0)
            } else {
                value = 0
            }

            return DashboardHabit(
                key: habit.key,
                title: habit.title,
                value: max(value, 0),
                targetValue: habit.targetValue,
                displayText: Self.dashboardDisplayText(for: habit, value: value)
            )
        }
    }

    static func dashboardDisplayText(for habit: FixedHabit, value: Double) -> String {
        if habit.key == "training" {
            return value >= 1 ? "erledigt" : "offen"
        }
        if habit.isBoolean {
            return value >= 1 ? "erledigt" : "offen"
        }
        if habit.key == "water" {
            return habit.displayValue(value).replacingOccurrences(of: "Liter", with: "L")
        }
        return habit.displayValue(value)
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
    var bodyWeightDate: String?
    var bodyWeightChange: Double?
    var bodyWeightTarget: Double?
    var bodyWeightLowerBound: Double?
    var bodyWeightUpperBound: Double?
    var workoutCompletedToday: Bool
    var trainingScheduledToday: Bool
    var trainingPausedToday: Bool
    var medicationDone: Bool
    var proteinShakeDone: Bool
    var recentActions: [DashboardActivityItem]
    var lastWorkoutType: String?
    var lastWorkoutDurationMinutes: Int?

    var completedHabits: Int {
        habits.filter { $0.progress >= 1 }.count
    }

    var totalHabits: Int {
        habits.count
    }

    var dailyBudgetRemaining: Double {
        FinanceStore.dailyBudgetRemaining(
            spent: monthlySpent,
            budget: monthlyBudget,
            date: Date()
        )
    }

    var habitProgress: Double {
        guard !habits.isEmpty else { return 0 }
        let clamped = habits.map { min(max($0.progress, 0), 1) }
        return clamped.reduce(0, +) / Double(clamped.count)
    }

    static var `default`: DashboardMockState {
        DashboardMockState(
            caloriesConsumed: 1450,
            caloriesTarget: 2200,
            proteinConsumed: 95,
            proteinTarget: 160,
            weeklyWorkoutCompleted: 2,
            weeklyWorkoutTarget: 3,
            monthlySpent: 684,
            monthlyBudget: 1200,
            habits: [
                DashboardHabit(key: "water", title: "Wasser", value: 1.5, targetValue: 3, displayText: "1,5 / 3,0 L"),
                DashboardHabit(key: "training", title: "Trainieren", value: 1, targetValue: 1, displayText: "erledigt"),
                DashboardHabit(key: "nutrition", title: "Ernährung", value: 2, targetValue: 3, displayText: "2 / 3 Mahlzeiten"),
                DashboardHabit(key: "learning", title: "Lernen", value: 15, targetValue: 60, displayText: "15 / 60 Min."),
                DashboardHabit(key: "sleep", title: "Schlaf", value: 0, targetValue: 1, displayText: "offen")
            ],
            bodyWeight: nil,
            bodyWeightDate: nil,
            bodyWeightChange: nil,
            bodyWeightTarget: nil,
            bodyWeightLowerBound: nil,
            bodyWeightUpperBound: nil,
            workoutCompletedToday: true,
            trainingScheduledToday: true,
            trainingPausedToday: false,
            medicationDone: false,
            proteinShakeDone: false,
            recentActions: [
                DashboardActivityItem(title: "Beispieldaten geladen", detail: "Vorschauwerte für das Dashboard.", createdAt: Date())
            ],
            lastWorkoutType: nil,
            lastWorkoutDurationMinutes: nil
        )
    }

    static var persistedHabits: [DashboardHabit] {
        [
            DashboardHabit(key: "water", title: "Wasser", value: 0, targetValue: 3, displayText: "0 / 3,0 L"),
            DashboardHabit(key: "training", title: "Trainieren", value: 0, targetValue: 1, displayText: "offen"),
            DashboardHabit(key: "nutrition", title: "Ernährung", value: 0, targetValue: 3, displayText: "0 / 3 Mahlzeiten"),
            DashboardHabit(key: "learning", title: "Lernen", value: 0, targetValue: 60, displayText: "0 / 60 Min."),
            DashboardHabit(key: "sleep", title: "Schlaf", value: 0, targetValue: 1, displayText: "offen")
        ]
    }

    static var persistedDefault: DashboardMockState {
        DashboardMockState(
            caloriesConsumed: 0,
            caloriesTarget: SeedData.defaultSettings.caloriesTarget,
            proteinConsumed: 0,
            proteinTarget: SeedData.defaultSettings.proteinTargetG,
            weeklyWorkoutCompleted: 0,
            weeklyWorkoutTarget: SeedData.defaultSettings.weeklyWorkoutTarget,
            monthlySpent: 0,
            monthlyBudget: SeedData.defaultSettings.monthlyBudget,
            habits: persistedHabits,
            bodyWeight: nil,
            bodyWeightDate: nil,
            bodyWeightChange: nil,
            bodyWeightTarget: nil,
            bodyWeightLowerBound: nil,
            bodyWeightUpperBound: nil,
            workoutCompletedToday: false,
            trainingScheduledToday: HomeWorkoutPlanProvider.plan.workout(for: Date()).isToday,
            trainingPausedToday: false,
            medicationDone: false,
            proteinShakeDone: false,
            recentActions: [],
            lastWorkoutType: nil,
            lastWorkoutDurationMinutes: nil
        )
    }
}

struct DashboardHabit: Identifiable, Equatable {
    let id: UUID
    let key: String
    let title: String
    var value: Double
    var targetValue: Double
    var displayText: String

    var progress: Double {
        guard targetValue > 0 else { return 0 }
        return min(max(value / targetValue, 0), 1)
    }

    var isCompleted: Bool {
        progress >= 1
    }

    init(id: UUID = UUID(), key: String, title: String, value: Double, targetValue: Double, displayText: String) {
        self.id = id
        self.key = key
        self.title = title
        self.value = value
        self.targetValue = targetValue
        self.displayText = displayText
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
