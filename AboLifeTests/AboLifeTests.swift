import XCTest
import GRDB
@testable import AboLife

final class AboLifeTests: XCTestCase {
    func testDashboardMockDataKeepsProgressInRange() {
        let snapshot = DashboardMockData.today

        XCTAssertGreaterThanOrEqual(snapshot.coreProgress, 0)
        XCTAssertLessThanOrEqual(snapshot.coreProgress, 1)
        XCTAssertGreaterThan(snapshot.calories.target, 0)
        XCTAssertGreaterThan(snapshot.protein.target, 0)
        XCTAssertEqual(snapshot.week.days.count, 7)
    }

    func testHabitProgressUsesCompletedAndTotal() {
        let habits = HabitStatus(title: "Gewohnheiten", completed: 3, total: 5, message: "Mock")

        XCTAssertEqual(habits.progress, 0.6, accuracy: 0.001)
    }

    func testAddMealUpdatesCaloriesProteinAndActivity() {
        let store = DashboardStore(state: .default)

        store.addMeal(name: "Skyr", calories: 300, protein: 35)

        XCTAssertEqual(store.snapshot.calories.current, 1750)
        XCTAssertEqual(store.snapshot.protein.current, 130, accuracy: 0.001)
        XCTAssertEqual(store.snapshot.recentActions.first?.title, "Mahlzeit hinzugefügt")
    }

    func testCompleteWorkoutCapsWeeklyProgressAtTarget() {
        var state = DashboardMockState.default
        state.weeklyWorkoutCompleted = 2
        state.weeklyWorkoutTarget = 3
        let store = DashboardStore(state: state)

        store.completeWorkout(type: "Push Day", durationMinutes: 45)
        store.completeWorkout(type: "Pull Day", durationMinutes: 50)

        XCTAssertEqual(store.snapshot.training.weeklyProgress, "3 / 3 Einheiten diese Woche")
        XCTAssertEqual(store.state.weeklyWorkoutCompleted, 3)
    }

    func testAddExpenseUpdatesMonthlySpentAndDailyBudget() {
        let store = DashboardStore(state: .default)
        let previousDailyBudget = store.snapshot.finance.remainingToday

        store.addExpense(title: "Lunch", amount: 18, category: "Essen")

        XCTAssertEqual(store.snapshot.finance.spentThisMonth, 702, accuracy: 0.001)
        XCTAssertLessThan(store.snapshot.finance.remainingToday, previousDailyBudget)
    }

    func testToggleHabitUpdatesCompletedCount() {
        var state = DashboardMockState.default
        let openHabitID = state.habits.first { !$0.isCompleted }!.id
        let store = DashboardStore(state: state)

        store.toggleHabit(openHabitID)

        XCTAssertEqual(store.snapshot.habits.completed, 4)
    }

    func testDailyCoreCalculationStaysInRange() {
        var state = DashboardMockState.default
        state.caloriesConsumed = 4000
        state.proteinConsumed = 300
        state.weeklyWorkoutCompleted = 10
        state.monthlySpent = 2400

        let coreProgress = DashboardStore.dailyCoreProgress(for: state)

        XCTAssertGreaterThanOrEqual(coreProgress, 0)
        XCTAssertLessThanOrEqual(coreProgress, 1)
    }

    func testTemporaryDatabaseInitializesAndMigrates() throws {
        let database = try AppDatabase.makeTemporary()

        let tableNames: Set<String> = try database.writer.read { db in
            let rows = try String.fetchAll(
                db,
                sql: "SELECT name FROM sqlite_master WHERE type = 'table'"
            )
            return Set(rows)
        }

        XCTAssertTrue(tableNames.contains("nutrition_entries"))
        XCTAssertTrue(tableNames.contains("workout_sessions"))
        XCTAssertTrue(tableNames.contains("finance_entries"))
        XCTAssertTrue(tableNames.contains("habit_entries"))
        XCTAssertTrue(tableNames.contains("body_metric_entries"))
        XCTAssertTrue(tableNames.contains("app_settings"))
    }

    func testNutritionEntryCanBeInsertedAndRead() throws {
        let database = try AppDatabase.makeTemporary()
        let repository = NutritionRepository(database: database)
        let entry = NutritionEntryRecord(title: "Skyr", caloriesKcal: 300, proteinG: 35)

        try repository.insert(entry)

        let entries = try repository.fetchAll()
        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries.first?.id, entry.id)
        XCTAssertEqual(entries.first?.title, "Skyr")
        XCTAssertEqual(entries.first?.caloriesKcal, 300)
        XCTAssertEqual(entries.first?.proteinG ?? 0, 35, accuracy: 0.001)
    }

    func testFinanceEntryCanBeInsertedAndRead() throws {
        let database = try AppDatabase.makeTemporary()
        let repository = FinanceRepository(database: database)
        let entry = FinanceEntryRecord(title: "Lunch", amount: 12.5, currency: "EUR", category: "Essen")

        try repository.insert(entry)

        let entries = try repository.fetchAll()
        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries.first?.id, entry.id)
        XCTAssertEqual(entries.first?.title, "Lunch")
        XCTAssertEqual(entries.first?.amount ?? 0, 12.5, accuracy: 0.001)
        XCTAssertEqual(entries.first?.currency, "EUR")
    }

    func testHabitEntryCanBeInsertedAndRead() throws {
        let database = try AppDatabase.makeTemporary()
        let repository = HabitRepository(database: database)
        let entry = HabitEntryRecord(habitKey: "water", date: "2026-06-12", isCompleted: true)

        try repository.insert(entry)

        let entries = try repository.fetchAll()
        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries.first?.id, entry.id)
        XCTAssertEqual(entries.first?.habitKey, "water")
        XCTAssertEqual(entries.first?.date, "2026-06-12")
        XCTAssertEqual(entries.first?.isCompleted, true)
    }

    func testSettingsCanBeInsertedAndRead() throws {
        let database = try AppDatabase.makeTemporary()
        let repository = SettingsRepository(database: database)
        let settings = AppSettingsRecord(
            caloriesTarget: 2200,
            proteinTargetG: 160,
            monthlyBudget: 1200,
            defaultCurrency: "EUR",
            weekStartsOn: 2
        )

        try repository.insert(settings)

        let allSettings = try repository.fetchAll()
        XCTAssertEqual(allSettings.count, 1)
        XCTAssertEqual(allSettings.first?.id, AppSettingsRecord.defaultID)
        XCTAssertEqual(allSettings.first?.caloriesTarget, 2200)
        XCTAssertEqual(allSettings.first?.proteinTargetG ?? 0, 160, accuracy: 0.001)
        XCTAssertEqual(allSettings.first?.monthlyBudget ?? 0, 1200, accuracy: 0.001)
    }

    func testNutritionRepositoryBuildsDaySummary() throws {
        let database = try AppDatabase.makeTemporary()
        let repository = NutritionRepository(database: database)
        let now = Date()
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: now)!

        try repository.insert(NutritionEntryRecord(occurredAt: now, title: "Skyr", caloriesKcal: 300, proteinG: 35))
        try repository.insert(NutritionEntryRecord(occurredAt: now, title: "Eggs", caloriesKcal: 220, proteinG: 18))
        try repository.insert(NutritionEntryRecord(occurredAt: yesterday, title: "Old meal", caloriesKcal: 900, proteinG: 60))

        let summary = try repository.daySummary(for: now)

        XCTAssertEqual(summary.caloriesKcal, 520)
        XCTAssertEqual(summary.proteinG, 53, accuracy: 0.001)
    }

    func testFinanceRepositoryBuildsMonthSummary() throws {
        let database = try AppDatabase.makeTemporary()
        let repository = FinanceRepository(database: database)
        let now = Date()
        let previousMonth = Calendar.current.date(byAdding: .month, value: -1, to: now)!

        try repository.insert(FinanceEntryRecord(occurredAt: now, title: "Lunch", amount: 12.5, category: "Essen"))
        try repository.insert(FinanceEntryRecord(occurredAt: now, title: "Groceries", amount: 40, category: "Haushalt"))
        try repository.insert(FinanceEntryRecord(occurredAt: previousMonth, title: "Old", amount: 100, category: "Sonstiges"))

        let spentThisMonth = try repository.monthSpending(for: now)

        XCTAssertEqual(spentThisMonth, 52.5, accuracy: 0.001)
    }

    func testWorkoutRepositoryCountsCompletedWorkoutsThisWeek() throws {
        let database = try AppDatabase.makeTemporary()
        let repository = WorkoutRepository(database: database)
        let now = Date()
        let lastWeek = Calendar.current.date(byAdding: .day, value: -8, to: now)!
        let weekInterval = DateIntervals.week(containing: now, weekStartsOn: 2)

        try repository.insert(WorkoutSessionRecord(occurredAt: now, workoutType: "Push Day", durationMin: 45, status: "done"))
        try repository.insert(WorkoutSessionRecord(occurredAt: now, workoutType: "Pull Day", durationMin: 40, status: "planned"))
        try repository.insert(WorkoutSessionRecord(occurredAt: lastWeek, workoutType: "Leg Day", durationMin: 50, status: "done"))

        let completedThisWeek = try repository.completedCount(in: weekInterval)

        XCTAssertEqual(completedThisWeek, 1)
        XCTAssertEqual(try repository.latestCompleted(in: weekInterval)?.workoutType, "Push Day")
    }

    func testHabitRepositoryUpsertsDayCompletion() throws {
        let database = try AppDatabase.makeTemporary()
        let repository = HabitRepository(database: database)
        let todayKey = DateIntervals.dayKey()

        try repository.upsertCompletion(habitKey: "water", date: todayKey, isCompleted: true)
        try repository.upsertCompletion(habitKey: "learning", date: todayKey, isCompleted: true)
        try repository.upsertCompletion(habitKey: "water", date: todayKey, isCompleted: false)

        let entries = try repository.fetch(for: todayKey)

        XCTAssertEqual(entries.count, 2)
        XCTAssertEqual(try repository.completedCount(for: todayKey), 1)
        XCTAssertEqual(entries.first { $0.habitKey == "water" }?.isCompleted, false)
        XCTAssertEqual(entries.first { $0.habitKey == "learning" }?.isCompleted, true)
    }

    func testBodyMetricRepositoryStoresLatestWeight() throws {
        let database = try AppDatabase.makeTemporary()
        let repository = BodyMetricRepository(database: database)
        let older = Calendar.current.date(byAdding: .day, value: -1, to: Date())!

        try repository.insert(BodyMetricEntryRecord(occurredAt: older, weightKg: 81.4))
        try repository.insert(BodyMetricEntryRecord(weightKg: 82.1))

        XCTAssertEqual(try repository.latest()?.weightKg ?? 0, 82.1, accuracy: 0.001)
    }

    func testDashboardStoreLoadsPersistedSummariesAndKeepsDataAfterNewStore() throws {
        let database = try AppDatabase.makeTemporary()
        let settingsRepository = SettingsRepository(database: database)
        try settingsRepository.insert(SeedData.defaultSettings)

        let store = DashboardStore(database: database)

        store.addMeal(name: "Skyr", calories: 300, protein: 35)
        store.addExpense(title: "Lunch", amount: 12, category: "Essen")
        store.completeWorkout(type: "Push Day", durationMinutes: 45)

        let waterHabitID = store.state.habits.first { $0.key == "water" }!.id
        store.toggleHabit(waterHabitID)

        let restartedStore = DashboardStore(database: database)

        XCTAssertEqual(restartedStore.snapshot.calories.current, 300, accuracy: 0.001)
        XCTAssertEqual(restartedStore.snapshot.protein.current, 35, accuracy: 0.001)
        XCTAssertEqual(restartedStore.snapshot.finance.spentThisMonth, 12, accuracy: 0.001)
        XCTAssertEqual(restartedStore.state.weeklyWorkoutCompleted, 1)
        XCTAssertEqual(restartedStore.snapshot.habits.completed, 1)
    }
}
