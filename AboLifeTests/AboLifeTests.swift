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
        XCTAssertTrue(tableNames.contains("weekly_reviews"))

        let appSettingsColumns: Set<String> = try database.writer.read { db in
            let rows = try Row.fetchAll(db, sql: "PRAGMA table_info(app_settings)")
            return Set(rows.compactMap { row in row["name"] as String? })
        }

        let habitEntryColumns: Set<String> = try database.writer.read { db in
            let rows = try Row.fetchAll(db, sql: "PRAGMA table_info(habit_entries)")
            return Set(rows.compactMap { row in row["name"] as String? })
        }

        XCTAssertTrue(appSettingsColumns.contains("weekly_workout_target"))
        XCTAssertTrue(habitEntryColumns.contains("value"))
        XCTAssertTrue(habitEntryColumns.contains("target_value"))
        XCTAssertTrue(habitEntryColumns.contains("unit"))
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
        XCTAssertEqual(allSettings.first?.weeklyWorkoutTarget, 3)
        XCTAssertEqual(allSettings.first?.monthlyBudget ?? 0, 1200, accuracy: 0.001)
    }

    func testSettingsRepositoryLoadsDefaultsWhenMissing() throws {
        let database = try AppDatabase.makeTemporary()
        let repository = SettingsRepository(database: database)

        let settings = try repository.loadSettings()
        let loadedAgain = try repository.fetchDefault()

        XCTAssertEqual(settings.caloriesTarget, SeedData.defaultSettings.caloriesTarget)
        XCTAssertEqual(settings.proteinTargetG, SeedData.defaultSettings.proteinTargetG, accuracy: 0.001)
        XCTAssertEqual(settings.weeklyWorkoutTarget, SeedData.defaultSettings.weeklyWorkoutTarget)
        XCTAssertEqual(settings.monthlyBudget, SeedData.defaultSettings.monthlyBudget, accuracy: 0.001)
        XCTAssertEqual(settings.defaultCurrency, SeedData.defaultSettings.defaultCurrency)
        XCTAssertEqual(settings.weekStartsOn, SeedData.defaultSettings.weekStartsOn)
        XCTAssertEqual(loadedAgain?.weeklyWorkoutTarget, SeedData.defaultSettings.weeklyWorkoutTarget)
    }

    func testSettingsRepositorySaveLoadAndReset() throws {
        let database = try AppDatabase.makeTemporary()
        let repository = SettingsRepository(database: database)
        let customSettings = AppSettingsRecord(
            caloriesTarget: 2500,
            proteinTargetG: 180,
            weeklyWorkoutTarget: 5,
            monthlyBudget: 1500,
            defaultCurrency: "EUR",
            weekStartsOn: 2
        )

        let saved = try repository.saveSettings(customSettings)
        let loaded = try repository.loadSettings()

        XCTAssertEqual(saved.caloriesTarget, 2500)
        XCTAssertEqual(loaded.weeklyWorkoutTarget, 5)
        XCTAssertEqual(loaded.monthlyBudget, 1500, accuracy: 0.001)

        let reset = try repository.resetToDefaults()
        XCTAssertEqual(reset.caloriesTarget, SeedData.defaultSettings.caloriesTarget)
        XCTAssertEqual(reset.proteinTargetG, SeedData.defaultSettings.proteinTargetG, accuracy: 0.001)
        XCTAssertEqual(reset.weeklyWorkoutTarget, SeedData.defaultSettings.weeklyWorkoutTarget)
        XCTAssertEqual(reset.monthlyBudget, SeedData.defaultSettings.monthlyBudget, accuracy: 0.001)
    }

    func testSettingsValidationNormalizesUnsafeValues() {
        let normalized = SettingsStore.normalized(
            caloriesTarget: 100,
            proteinTargetG: 999,
            weeklyWorkoutTarget: 30,
            monthlyBudget: -50,
            currencyCode: "USD",
            weekStartsOn: 1
        )

        XCTAssertEqual(normalized.caloriesTarget, 800)
        XCTAssertEqual(normalized.proteinTargetG, 400, accuracy: 0.001)
        XCTAssertEqual(normalized.weeklyWorkoutTarget, 14)
        XCTAssertEqual(normalized.monthlyBudget, 0, accuracy: 0.001)
        XCTAssertEqual(normalized.defaultCurrency, "EUR")
        XCTAssertEqual(normalized.weekStartsOn, 2)
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

    func testNutritionRepositoryFetchesEntriesForSelectedDayNewestFirst() throws {
        let database = try AppDatabase.makeTemporary()
        let repository = NutritionRepository(database: database)
        let calendar = Calendar(identifier: .gregorian)
        let breakfast = DateComponents(calendar: calendar, year: 2026, month: 6, day: 12, hour: 8).date!
        let lunch = DateComponents(calendar: calendar, year: 2026, month: 6, day: 12, hour: 13).date!
        let yesterday = DateComponents(calendar: calendar, year: 2026, month: 6, day: 11, hour: 20).date!

        try repository.insert(NutritionEntryRecord(occurredAt: breakfast, title: "Skyr", caloriesKcal: 300, proteinG: 35))
        try repository.insert(NutritionEntryRecord(occurredAt: lunch, title: "Lunch", caloriesKcal: 650, proteinG: 42))
        try repository.insert(NutritionEntryRecord(occurredAt: yesterday, title: "Old meal", caloriesKcal: 900, proteinG: 60))

        let entries = try repository.fetchEntries(forDay: breakfast, calendar: calendar)

        XCTAssertEqual(entries.map(\.title), ["Lunch", "Skyr"])
    }

    func testNutritionRepositoryDeletesSingleEntry() throws {
        let database = try AppDatabase.makeTemporary()
        let repository = NutritionRepository(database: database)
        let entryToDelete = NutritionEntryRecord(title: "Skyr", caloriesKcal: 300, proteinG: 35)
        let entryToKeep = NutritionEntryRecord(title: "Lunch", caloriesKcal: 650, proteinG: 42)

        try repository.insert(entryToDelete)
        try repository.insert(entryToKeep)
        try repository.delete(id: entryToDelete.id)
        try repository.delete(id: "missing-id")

        let entries = try repository.fetchAll()
        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries.first?.id, entryToKeep.id)
    }

    func testNutritionRepositorySummaryReflectsDeleteAndEmptyDay() throws {
        let database = try AppDatabase.makeTemporary()
        let repository = NutritionRepository(database: database)
        let calendar = Calendar(identifier: .gregorian)
        let selectedDay = DateComponents(calendar: calendar, year: 2026, month: 6, day: 12, hour: 12).date!
        let emptyDay = DateComponents(calendar: calendar, year: 2026, month: 6, day: 13, hour: 12).date!
        let entry = NutritionEntryRecord(occurredAt: selectedDay, title: "Lunch", caloriesKcal: 650, proteinG: 42)

        try repository.insert(entry)
        XCTAssertEqual(try repository.daySummary(for: selectedDay, calendar: calendar).caloriesKcal, 650)

        try repository.delete(id: entry.id)

        let summary = try repository.daySummary(for: selectedDay, calendar: calendar)
        let emptySummary = try repository.daySummary(for: emptyDay, calendar: calendar)
        XCTAssertEqual(summary.caloriesKcal, 0)
        XCTAssertEqual(summary.proteinG, 0, accuracy: 0.001)
        XCTAssertEqual(emptySummary.caloriesKcal, 0)
        XCTAssertEqual(emptySummary.proteinG, 0, accuracy: 0.001)
    }

    func testNutritionProgressClampsNormalOverTargetAndZeroTarget() {
        XCTAssertEqual(NutritionStore.progress(current: 550, target: 2200), 0.25, accuracy: 0.001)
        XCTAssertEqual(NutritionStore.progress(current: 2600, target: 2200), 1, accuracy: 0.001)
        XCTAssertEqual(NutritionStore.progress(current: 500, target: 0), 0, accuracy: 0.001)
        XCTAssertEqual(NutritionStore.progress(current: -100, target: 2200), 0, accuracy: 0.001)
    }

    func testNutritionRepositoryWeeklySummaryUsesWeekInterval() throws {
        let database = try AppDatabase.makeTemporary()
        let repository = NutritionRepository(database: database)
        let calendar = Calendar(identifier: .gregorian)
        let monday = DateComponents(calendar: calendar, year: 2026, month: 6, day: 8, hour: 0).date!
        let friday = DateComponents(calendar: calendar, year: 2026, month: 6, day: 12, hour: 13).date!
        let sundayBefore = DateComponents(calendar: calendar, year: 2026, month: 6, day: 7, hour: 23).date!
        let nextMonday = DateComponents(calendar: calendar, year: 2026, month: 6, day: 15, hour: 0).date!

        try repository.insert(NutritionEntryRecord(occurredAt: monday, title: "Breakfast", caloriesKcal: 400, proteinG: 30))
        try repository.insert(NutritionEntryRecord(occurredAt: friday, title: "Lunch", caloriesKcal: 600, proteinG: 45))
        try repository.insert(NutritionEntryRecord(occurredAt: sundayBefore, title: "Old", caloriesKcal: 900, proteinG: 70))
        try repository.insert(NutritionEntryRecord(occurredAt: nextMonday, title: "Next", caloriesKcal: 800, proteinG: 60))

        let summary = try repository.weeklySummary(forDate: friday, weekStartsOn: 2, calendar: calendar)

        XCTAssertEqual(summary.totalCaloriesKcal, 1000)
        XCTAssertEqual(summary.averageCaloriesPerDay, 1000.0 / 7.0, accuracy: 0.001)
        XCTAssertEqual(summary.totalProteinG, 75, accuracy: 0.001)
        XCTAssertEqual(summary.averageProteinGPerDay, 75.0 / 7.0, accuracy: 0.001)
        XCTAssertEqual(summary.entryCount, 2)
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

    func testFinanceRepositoryFetchesEntriesForSelectedMonthNewestFirst() throws {
        let database = try AppDatabase.makeTemporary()
        let repository = FinanceRepository(database: database)
        let calendar = Calendar(identifier: .gregorian)
        let earlyJune = DateComponents(calendar: calendar, year: 2026, month: 6, day: 3, hour: 9).date!
        let lateJune = DateComponents(calendar: calendar, year: 2026, month: 6, day: 20, hour: 18).date!
        let july = DateComponents(calendar: calendar, year: 2026, month: 7, day: 1, hour: 12).date!

        try repository.insert(FinanceEntryRecord(occurredAt: earlyJune, title: "Coffee", amount: 4, category: "Essen"))
        try repository.insert(FinanceEntryRecord(occurredAt: lateJune, title: "Groceries", amount: 42, category: "Haushalt"))
        try repository.insert(FinanceEntryRecord(occurredAt: july, title: "July", amount: 30, category: "Sonstiges"))

        let entries = try repository.fetchEntries(forMonthContaining: earlyJune, calendar: calendar)

        XCTAssertEqual(entries.map(\.title), ["Groceries", "Coffee"])
    }

    func testFinanceRepositoryMonthlySummaryCountsEntriesAndSpent() throws {
        let database = try AppDatabase.makeTemporary()
        let repository = FinanceRepository(database: database)
        let calendar = Calendar(identifier: .gregorian)
        let selectedMonth = DateComponents(calendar: calendar, year: 2026, month: 6, day: 12, hour: 12).date!
        let firstExpense = DateComponents(calendar: calendar, year: 2026, month: 6, day: 2, hour: 10).date!
        let secondExpense = DateComponents(calendar: calendar, year: 2026, month: 6, day: 22, hour: 20).date!
        let previousMonth = DateComponents(calendar: calendar, year: 2026, month: 5, day: 30, hour: 12).date!

        try repository.insert(FinanceEntryRecord(occurredAt: firstExpense, title: "Lunch", amount: 12.5, category: "Essen"))
        try repository.insert(FinanceEntryRecord(occurredAt: secondExpense, title: "Groceries", amount: 40, category: "Haushalt"))
        try repository.insert(FinanceEntryRecord(occurredAt: previousMonth, title: "Old", amount: 100, category: "Sonstiges"))

        let summary = try repository.monthlySummary(forDate: selectedMonth, calendar: calendar)

        XCTAssertEqual(summary.spent, 52.5, accuracy: 0.001)
        XCTAssertEqual(summary.entryCount, 2)
    }

    func testFinanceRepositoryDeleteRemovesEntryAndSummaryReflectsChange() throws {
        let database = try AppDatabase.makeTemporary()
        let repository = FinanceRepository(database: database)
        let calendar = Calendar(identifier: .gregorian)
        let selectedMonth = DateComponents(calendar: calendar, year: 2026, month: 6, day: 12, hour: 12).date!
        let entryToDelete = FinanceEntryRecord(occurredAt: selectedMonth, title: "Lunch", amount: 12.5, category: "Essen")
        let entryToKeep = FinanceEntryRecord(occurredAt: selectedMonth, title: "Groceries", amount: 40, category: "Haushalt")

        try repository.insert(entryToDelete)
        try repository.insert(entryToKeep)
        try repository.delete(id: entryToDelete.id)
        try repository.delete(id: "missing-id")

        let entries = try repository.fetchEntries(forMonthContaining: selectedMonth, calendar: calendar)
        let summary = try repository.monthlySummary(forDate: selectedMonth, calendar: calendar)

        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries.first?.id, entryToKeep.id)
        XCTAssertEqual(summary.spent, 40, accuracy: 0.001)
        XCTAssertEqual(summary.entryCount, 1)
    }

    func testFinanceRemainingBudgetAndProgress() {
        XCTAssertEqual(FinanceStore.remainingBudget(spent: 684, budget: 1200), 516, accuracy: 0.001)
        XCTAssertEqual(FinanceStore.remainingBudget(spent: 1300, budget: 1200), 0, accuracy: 0.001)
        XCTAssertEqual(FinanceStore.progress(spent: 300, budget: 1200), 0.25, accuracy: 0.001)
        XCTAssertEqual(FinanceStore.progress(spent: 1500, budget: 1200), 1, accuracy: 0.001)
        XCTAssertEqual(FinanceStore.progress(spent: 300, budget: 0), 0, accuracy: 0.001)
    }

    func testFinanceRepositoryWeeklySummaryCanCrossMonthBoundary() throws {
        let database = try AppDatabase.makeTemporary()
        let repository = FinanceRepository(database: database)
        let calendar = Calendar(identifier: .gregorian)
        let monday = DateComponents(calendar: calendar, year: 2026, month: 6, day: 29, hour: 10).date!
        let wednesday = DateComponents(calendar: calendar, year: 2026, month: 7, day: 1, hour: 12).date!
        let nextMonday = DateComponents(calendar: calendar, year: 2026, month: 7, day: 6, hour: 9).date!

        try repository.insert(FinanceEntryRecord(occurredAt: monday, title: "Coffee", amount: 4, category: "Essen"))
        try repository.insert(FinanceEntryRecord(occurredAt: wednesday, title: "Groceries", amount: 42, category: "Haushalt"))
        try repository.insert(FinanceEntryRecord(occurredAt: nextMonday, title: "Next", amount: 30, category: "Sonstiges"))

        let summary = try repository.weeklySummary(forDate: wednesday, weekStartsOn: 2, calendar: calendar)

        XCTAssertEqual(summary.spent, 46, accuracy: 0.001)
        XCTAssertEqual(summary.entryCount, 2)
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

    func testWorkoutRepositoryFetchesSessionsForSelectedWeekNewestFirst() throws {
        let database = try AppDatabase.makeTemporary()
        let repository = WorkoutRepository(database: database)
        let calendar = Calendar(identifier: .gregorian)
        let monday = DateComponents(calendar: calendar, year: 2026, month: 6, day: 8, hour: 18).date!
        let wednesday = DateComponents(calendar: calendar, year: 2026, month: 6, day: 10, hour: 19).date!
        let nextWeek = DateComponents(calendar: calendar, year: 2026, month: 6, day: 15, hour: 18).date!

        try repository.insert(WorkoutSessionRecord(occurredAt: monday, workoutType: "Push Day", durationMin: 45, status: "done"))
        try repository.insert(WorkoutSessionRecord(occurredAt: wednesday, workoutType: "Pull Day", durationMin: 50, status: "done"))
        try repository.insert(WorkoutSessionRecord(occurredAt: nextWeek, workoutType: "Leg Day", durationMin: 55, status: "done"))

        let sessions = try repository.fetchSessions(forWeekContaining: monday, weekStartsOn: 2, calendar: calendar)

        XCTAssertEqual(sessions.map(\.workoutType), ["Pull Day", "Push Day"])
    }

    func testWorkoutRepositoryWeeklySummaryCountsDoneSessionsAndDuration() throws {
        let database = try AppDatabase.makeTemporary()
        let repository = WorkoutRepository(database: database)
        let calendar = Calendar(identifier: .gregorian)
        let selectedDay = DateComponents(calendar: calendar, year: 2026, month: 6, day: 12, hour: 12).date!
        let earlier = DateComponents(calendar: calendar, year: 2026, month: 6, day: 9, hour: 18).date!
        let later = DateComponents(calendar: calendar, year: 2026, month: 6, day: 11, hour: 19).date!
        let planned = DateComponents(calendar: calendar, year: 2026, month: 6, day: 12, hour: 20).date!
        let previousWeek = DateComponents(calendar: calendar, year: 2026, month: 6, day: 5, hour: 18).date!

        try repository.insert(WorkoutSessionRecord(occurredAt: earlier, workoutType: "Push Day", durationMin: 45, status: "done"))
        try repository.insert(WorkoutSessionRecord(occurredAt: later, workoutType: "Pull Day", durationMin: 50, status: "done"))
        try repository.insert(WorkoutSessionRecord(occurredAt: planned, workoutType: "Cardio", durationMin: 30, status: "planned"))
        try repository.insert(WorkoutSessionRecord(occurredAt: previousWeek, workoutType: "Leg Day", durationMin: 55, status: "done"))

        let summary = try repository.weeklySummary(forDate: selectedDay, weekStartsOn: 2, calendar: calendar)

        XCTAssertEqual(summary.completedWorkouts, 2)
        XCTAssertEqual(summary.totalDurationMin, 95)
        XCTAssertEqual(summary.lastWorkout?.workoutType, "Pull Day")
    }

    func testWorkoutRepositoryDeleteRemovesSessionAndSummaryReflectsChange() throws {
        let database = try AppDatabase.makeTemporary()
        let repository = WorkoutRepository(database: database)
        let calendar = Calendar(identifier: .gregorian)
        let selectedDay = DateComponents(calendar: calendar, year: 2026, month: 6, day: 12, hour: 12).date!
        let sessionToDelete = WorkoutSessionRecord(occurredAt: selectedDay, workoutType: "Push Day", durationMin: 45, status: "done")
        let sessionToKeep = WorkoutSessionRecord(occurredAt: selectedDay, workoutType: "Pull Day", durationMin: 50, status: "done")

        try repository.insert(sessionToDelete)
        try repository.insert(sessionToKeep)
        try repository.delete(id: sessionToDelete.id)
        try repository.delete(id: "missing-id")

        let sessions = try repository.fetchSessions(forWeekContaining: selectedDay, weekStartsOn: 2, calendar: calendar)
        let summary = try repository.weeklySummary(forDate: selectedDay, weekStartsOn: 2, calendar: calendar)

        XCTAssertEqual(sessions.count, 1)
        XCTAssertEqual(sessions.first?.id, sessionToKeep.id)
        XCTAssertEqual(summary.completedWorkouts, 1)
        XCTAssertEqual(summary.totalDurationMin, 50)
        XCTAssertEqual(summary.lastWorkout?.id, sessionToKeep.id)
    }

    func testTrainingStoreUsesPersistedWeeklyWorkoutTarget() throws {
        let database = try AppDatabase.makeTemporary()
        try SettingsRepository(database: database).saveSettings(
            AppSettingsRecord(
                caloriesTarget: 2200,
                proteinTargetG: 150,
                weeklyWorkoutTarget: 5,
                monthlyBudget: 1200,
                defaultCurrency: "EUR",
                weekStartsOn: 2
            )
        )

        let store = TrainingStore(database: database)

        XCTAssertEqual(store.weeklyWorkoutTarget, 5)
    }

    func testHomeWorkoutPlanReturnsPullCoreOnMonday() {
        let calendar = Calendar(identifier: .gregorian)
        let monday = DateComponents(calendar: calendar, year: 2026, month: 6, day: 8, hour: 12).date!

        let scheduled = HomeWorkoutPlanProvider.plan.workout(for: monday, calendar: calendar)

        XCTAssertTrue(scheduled.isToday)
        XCTAssertEqual(scheduled.day.name, "Pull + Core")
    }

    func testHomeWorkoutPlanReturnsPushLegsOnWednesday() {
        let calendar = Calendar(identifier: .gregorian)
        let wednesday = DateComponents(calendar: calendar, year: 2026, month: 6, day: 10, hour: 12).date!

        let scheduled = HomeWorkoutPlanProvider.plan.workout(for: wednesday, calendar: calendar)

        XCTAssertTrue(scheduled.isToday)
        XCTAssertEqual(scheduled.day.name, "Push + Legs")
    }

    func testHomeWorkoutPlanReturnsFullBodyOnFriday() {
        let calendar = Calendar(identifier: .gregorian)
        let friday = DateComponents(calendar: calendar, year: 2026, month: 6, day: 12, hour: 12).date!

        let scheduled = HomeWorkoutPlanProvider.plan.workout(for: friday, calendar: calendar)

        XCTAssertTrue(scheduled.isToday)
        XCTAssertEqual(scheduled.day.name, "Full Body")
    }

    func testHomeWorkoutPlanShowsWednesdayAfterTuesday() {
        let calendar = Calendar(identifier: .gregorian)
        let tuesday = DateComponents(calendar: calendar, year: 2026, month: 6, day: 9, hour: 12).date!

        let scheduled = HomeWorkoutPlanProvider.plan.workout(for: tuesday, calendar: calendar)

        XCTAssertFalse(scheduled.isToday)
        XCTAssertEqual(scheduled.day.name, "Push + Legs")
        XCTAssertEqual(scheduled.day.weekdayName, "Mittwoch")
    }

    func testHomeWorkoutPlanShowsMondayAfterSaturday() {
        let calendar = Calendar(identifier: .gregorian)
        let saturday = DateComponents(calendar: calendar, year: 2026, month: 6, day: 13, hour: 12).date!

        let scheduled = HomeWorkoutPlanProvider.plan.workout(for: saturday, calendar: calendar)

        XCTAssertFalse(scheduled.isToday)
        XCTAssertEqual(scheduled.day.name, "Pull + Core")
        XCTAssertEqual(scheduled.day.weekdayName, "Montag")
    }

    func testHomeWorkoutIntensityDurations() {
        XCTAssertEqual(HomeWorkoutIntensity.minimum.durationMinutes, 15)
        XCTAssertEqual(HomeWorkoutIntensity.normal.durationMinutes, 30)
        XCTAssertEqual(HomeWorkoutIntensity.strong.durationMinutes, 45)
    }

    func testTrainingDoubleRingWeeklyProgressUsesCompletedAndTarget() {
        XCTAssertEqual(TrainingDoubleProgressRing.progress(current: 2, target: 3), 2.0 / 3.0, accuracy: 0.001)
        XCTAssertEqual(TrainingDoubleProgressRing.progress(current: 4, target: 3), 1, accuracy: 0.001)
        XCTAssertEqual(TrainingDoubleProgressRing.progress(current: 1, target: 0), 0, accuracy: 0.001)
    }

    func testHomeWorkoutDailyProgressUsesCheckedAndTotalExercises() {
        XCTAssertEqual(HomeWorkoutChecklistState.progress(checkedExercises: 3, totalExercises: 5), 0.6, accuracy: 0.001)
    }

    func testHomeWorkoutDailyProgressIsZeroWhenNoExercisesChecked() {
        XCTAssertEqual(HomeWorkoutChecklistState.progress(checkedExercises: 0, totalExercises: 5), 0, accuracy: 0.001)
        XCTAssertEqual(HomeWorkoutChecklistState.progress(checkedExercises: 0, totalExercises: 0), 0, accuracy: 0.001)
    }

    func testHomeWorkoutDailyProgressIsOneWhenAllExercisesChecked() {
        XCTAssertEqual(HomeWorkoutChecklistState.progress(checkedExercises: 5, totalExercises: 5), 1, accuracy: 0.001)
        XCTAssertEqual(HomeWorkoutChecklistState.progress(checkedExercises: 7, totalExercises: 5), 1, accuracy: 0.001)
    }

    func testHomeWorkoutIntensityChangeResetsCheckedExercises() {
        let exercise = HomeWorkoutExercise(name: "Plank", prescription: "2 x 30 Sekunden")
        var state = HomeWorkoutChecklistState()

        state.setExercise(exercise.id, isCompleted: true)
        state.setIntensity(.strong)

        XCTAssertEqual(state.selectedIntensity, .strong)
        XCTAssertTrue(state.completedExerciseIDs.isEmpty)
        XCTAssertEqual(state.checkedExerciseCount, 0)
    }

    func testHomeWorkoutCompletionCreatesPersistedWorkoutSession() throws {
        let database = try AppDatabase.makeTemporary()
        let calendar = Calendar(identifier: .gregorian)
        let wednesday = DateComponents(calendar: calendar, year: 2026, month: 6, day: 10, hour: 19).date!
        let store = TrainingStore(database: database, calendar: calendar, now: { wednesday })
        let exercises = store.homeWorkoutExercises(for: .normal)
        let completedIDs = Set(exercises.prefix(3).map(\.id))

        store.completeHomeWorkout(intensity: .normal, completedExerciseIDs: completedIDs)

        let sessions = try WorkoutRepository(database: database).fetchAll()
        XCTAssertEqual(sessions.count, 1)
        XCTAssertEqual(sessions.first?.workoutType, "Home Plan: Push + Legs")
        XCTAssertEqual(sessions.first?.durationMin, 30)
        XCTAssertEqual(sessions.first?.status, "done")
        XCTAssertEqual(sessions.first?.note?.contains("Intensität: Normal"), true)
        XCTAssertEqual(sessions.first?.note?.contains("Erledigt: 3/5"), true)
        XCTAssertEqual(sessions.first?.note?.contains("Pike Push-ups"), true)
        XCTAssertEqual(store.completedWorkoutsThisWeek, 1)
        XCTAssertEqual(store.progress, 1.0 / 3.0, accuracy: 0.001)
    }

    func testHomeWorkoutPlanContainsNoUnsuitableBarExercises() {
        let forbiddenTerms = [
            "hanging leg raises",
            "toes-to-bar",
            "muscle-up",
            "dips an der stange"
        ]
        let exerciseNames = HomeWorkoutPlanProvider.plan.allExercises
            .map(\.name)
            .joined(separator: " ")
            .lowercased()

        for term in forbiddenTerms {
            XCTAssertFalse(exerciseNames.contains(term), "\(term) should not be in the home workout plan")
        }
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

    func testHabitRepositoryFetchesEntriesForSelectedDay() throws {
        let database = try AppDatabase.makeTemporary()
        let repository = HabitRepository(database: database)
        let selectedDay = "2026-06-12"
        let otherDay = "2026-06-13"

        try repository.insert(HabitEntryRecord(habitKey: "water", date: selectedDay, isCompleted: true))
        try repository.insert(HabitEntryRecord(habitKey: "sleep", date: selectedDay, isCompleted: false))
        try repository.insert(HabitEntryRecord(habitKey: "learning", date: otherDay, isCompleted: true))

        let entries = try repository.fetchEntries(forDay: selectedDay)

        XCTAssertEqual(entries.map(\.habitKey), ["sleep", "water"])
    }

    func testHabitRepositoryFetchesSingleEntry() throws {
        let database = try AppDatabase.makeTemporary()
        let repository = HabitRepository(database: database)
        let date = "2026-06-12"

        try repository.insert(HabitEntryRecord(habitKey: "water", date: date, isCompleted: true))

        let entry = try repository.fetchEntry(habitKey: "water", date: date)
        let missing = try repository.fetchEntry(habitKey: "sleep", date: date)

        XCTAssertEqual(entry?.habitKey, "water")
        XCTAssertEqual(entry?.isCompleted, true)
        XCTAssertNil(missing)
    }

    func testHabitRepositoryDeleteAndClearCompletion() throws {
        let database = try AppDatabase.makeTemporary()
        let repository = HabitRepository(database: database)
        let date = "2026-06-12"
        let entryToDelete = HabitEntryRecord(habitKey: "water", date: date, isCompleted: true)
        let entryToClear = HabitEntryRecord(habitKey: "sleep", date: date, isCompleted: true)

        try repository.insert(entryToDelete)
        try repository.insert(entryToClear)
        try repository.delete(id: entryToDelete.id)
        try repository.delete(id: "missing-id")
        try repository.clearCompletion(habitKey: "sleep", date: date)

        let entries = try repository.fetchEntries(forDay: date)
        XCTAssertTrue(entries.isEmpty)
    }

    func testHabitRepositoryDailySummaryUsesFixedHabitKeys() throws {
        let database = try AppDatabase.makeTemporary()
        let repository = HabitRepository(database: database)
        let date = "2026-06-12"
        let habitKeys = FixedHabit.defaults.map(\.key)

        try repository.insert(HabitEntryRecord(habitKey: "water", date: date, isCompleted: true))
        try repository.insert(HabitEntryRecord(habitKey: "movement", date: date, isCompleted: true))
        try repository.insert(HabitEntryRecord(habitKey: "legacy", date: date, isCompleted: true))
        try repository.insert(HabitEntryRecord(habitKey: "sleep", date: date, isCompleted: false))

        let summary = try repository.dailySummary(forDay: date, habitKeys: habitKeys)

        XCTAssertEqual(summary.completed, 2)
        XCTAssertEqual(summary.total, 5)
        XCTAssertEqual(summary.progress, 0.4, accuracy: 0.001)
    }

    func testHabitsStoreProgressClampsNormalAndZeroTotal() {
        XCTAssertEqual(HabitsStore.progress(completed: 3, total: 5), 0.6, accuracy: 0.001)
        XCTAssertEqual(HabitsStore.progress(completed: 8, total: 5), 1, accuracy: 0.001)
        XCTAssertEqual(HabitsStore.progress(completed: -1, total: 5), 0, accuracy: 0.001)
        XCTAssertEqual(HabitsStore.progress(completed: 1, total: 0), 0, accuracy: 0.001)
    }

    func testMeasurableHabitProgressClampsValues() {
        XCTAssertEqual(FixedHabit.progress(value: 1.5, target: 3.0), 0.5, accuracy: 0.001)
        XCTAssertEqual(FixedHabit.progress(value: 15, target: 60), 0.25, accuracy: 0.001)
        XCTAssertEqual(FixedHabit.progress(value: 90, target: 60), 1, accuracy: 0.001)
        XCTAssertEqual(FixedHabit.progress(value: 1, target: 0), 0, accuracy: 0.001)
    }

    func testHabitRepositoryIncrementAndDecrementMeasuredValues() throws {
        let database = try AppDatabase.makeTemporary()
        let repository = HabitRepository(database: database)
        let date = "2026-06-12"
        let water = FixedHabit.defaultDefinition(for: "water")!

        try repository.incrementValue(
            habitKey: water.key,
            date: date,
            amount: 1.5,
            target: water.targetValue,
            unit: water.unit
        )
        try repository.decrementValue(
            habitKey: water.key,
            date: date,
            amount: 0.5,
            target: water.targetValue,
            unit: water.unit
        )

        let entry = try repository.fetchEntry(habitKey: "water", date: date)
        XCTAssertEqual(entry?.value ?? 0, 1.0, accuracy: 0.001)
        XCTAssertEqual(entry?.targetValue ?? 0, 3.0, accuracy: 0.001)
        XCTAssertEqual(entry?.unit, "Liter")
        XCTAssertEqual(entry?.isCompleted, false)
    }

    func testHabitRepositoryDecrementDoesNotGoBelowZero() throws {
        let database = try AppDatabase.makeTemporary()
        let repository = HabitRepository(database: database)
        let date = "2026-06-12"
        let learning = FixedHabit.defaultDefinition(for: "learning")!

        try repository.setValue(
            habitKey: learning.key,
            date: date,
            value: 10,
            target: learning.targetValue,
            unit: learning.unit
        )
        try repository.decrementValue(
            habitKey: learning.key,
            date: date,
            amount: 30,
            target: learning.targetValue,
            unit: learning.unit
        )

        XCTAssertEqual(try repository.fetchEntry(habitKey: "learning", date: date)?.value ?? -1, 0, accuracy: 0.001)
    }

    func testHabitRepositoryBooleanSleepRoutineToggles() throws {
        let database = try AppDatabase.makeTemporary()
        let repository = HabitRepository(database: database)
        let date = "2026-06-12"

        try repository.toggleBooleanHabit(habitKey: "sleep", date: date)
        XCTAssertEqual(try repository.fetchEntry(habitKey: "sleep", date: date)?.value ?? 0, 1, accuracy: 0.001)
        XCTAssertEqual(try repository.fetchEntry(habitKey: "sleep", date: date)?.isCompleted, true)

        try repository.toggleBooleanHabit(habitKey: "sleep", date: date)
        XCTAssertEqual(try repository.fetchEntry(habitKey: "sleep", date: date)?.value ?? -1, 0, accuracy: 0.001)
        XCTAssertEqual(try repository.fetchEntry(habitKey: "sleep", date: date)?.isCompleted, false)
    }

    func testHabitsStoreToggleOpenDoneOpenPersists() throws {
        let database = try AppDatabase.makeTemporary()
        let store = HabitsStore(database: database)
        let todayKey = DateIntervals.dayKey()

        store.toggleHabit(key: "water")
        XCTAssertTrue(store.isCompleted("water"))
        XCTAssertEqual(try HabitRepository(database: database).fetchEntry(habitKey: "water", date: todayKey)?.isCompleted, true)

        store.toggleHabit(key: "water")
        XCTAssertFalse(store.isCompleted("water"))
        XCTAssertEqual(try HabitRepository(database: database).fetchEntry(habitKey: "water", date: todayKey)?.isCompleted, false)
    }

    func testHabitsStoreDailyProgressAveragesMeasuredHabitProgress() throws {
        let database = try AppDatabase.makeTemporary()
        let repository = HabitRepository(database: database)
        let calendar = Calendar(identifier: .gregorian)
        let selectedDay = DateComponents(calendar: calendar, year: 2026, month: 6, day: 12, hour: 12).date!
        let date = "2026-06-12"

        try repository.setValue(habitKey: "water", date: date, value: 1.5, target: 3, unit: "Liter")
        try repository.setValue(habitKey: "movement", date: date, value: 60, target: 60, unit: "Min.")
        try repository.setValue(habitKey: "nutrition", date: date, value: 1, target: 3, unit: "Mahlzeiten")
        try repository.setValue(habitKey: "learning", date: date, value: 15, target: 60, unit: "Min.")
        try repository.setValue(habitKey: "sleep", date: date, value: 0, target: 1, unit: "")

        let store = HabitsStore(database: database, selectedDate: selectedDay, calendar: calendar)

        let expected = (0.5 + 1 + (1.0 / 3.0) + 0.25 + 0) / 5.0
        XCTAssertEqual(store.dailyProgressPercent, expected, accuracy: 0.001)
        XCTAssertEqual(store.completedHabits, 1)
    }

    func testHabitsStoreWeekHistoryAlwaysBuildsSevenDaysWithEmptyDays() throws {
        let database = try AppDatabase.makeTemporary()
        let repository = HabitRepository(database: database)
        let calendar = Calendar(identifier: .gregorian)
        let selectedDay = DateComponents(calendar: calendar, year: 2026, month: 6, day: 12, hour: 12).date!

        try repository.setValue(habitKey: "water", date: "2026-06-08", value: 3, target: 3, unit: "Liter")
        try repository.setValue(habitKey: "water", date: "2026-06-10", value: 1.5, target: 3, unit: "Liter")

        let store = HabitsStore(database: database, selectedDate: selectedDay, calendar: calendar)
        let history = store.weekHistory(for: FixedHabit.defaultDefinition(for: "water")!)

        XCTAssertEqual(history.count, 7)
        XCTAssertEqual(history.map(\.progress), [1, 0, 0.5, 0, 0, 0, 0])
    }

    func testHabitRepositoryWeeklySummaryUsesFixedHabitKeysAndDays() throws {
        let database = try AppDatabase.makeTemporary()
        let repository = HabitRepository(database: database)
        let calendar = Calendar(identifier: .gregorian)
        let selectedDay = DateComponents(calendar: calendar, year: 2026, month: 6, day: 12, hour: 12).date!
        let mondayKey = "2026-06-08"
        let tuesdayKey = "2026-06-09"
        let nextMondayKey = "2026-06-15"
        let habitKeys = FixedHabit.defaults.map(\.key)

        try repository.insert(HabitEntryRecord(habitKey: "water", date: mondayKey, isCompleted: true))
        try repository.insert(HabitEntryRecord(habitKey: "movement", date: mondayKey, isCompleted: true))
        try repository.insert(HabitEntryRecord(habitKey: "water", date: mondayKey, isCompleted: true))
        try repository.insert(HabitEntryRecord(habitKey: "legacy", date: mondayKey, isCompleted: true))
        try repository.insert(HabitEntryRecord(habitKey: "sleep", date: tuesdayKey, isCompleted: false))
        try repository.insert(HabitEntryRecord(habitKey: "learning", date: nextMondayKey, isCompleted: true))

        let summary = try repository.weeklySummary(forDate: selectedDay, weekStartsOn: 2, habitKeys: habitKeys, days: 7, calendar: calendar)

        XCTAssertEqual(summary.completed, 2)
        XCTAssertEqual(summary.total, 35)
        XCTAssertEqual(summary.progress, 2.0 / 35.0, accuracy: 0.001)
    }

    func testWeeklyReviewStoreDaysConsideredForCurrentWeek() {
        let calendar = Calendar(identifier: .gregorian)
        let selectedDay = DateComponents(calendar: calendar, year: 2026, month: 6, day: 12, hour: 12).date!
        let interval = DateIntervals.week(containing: selectedDay, weekStartsOn: 2, calendar: calendar)

        XCTAssertEqual(WeeklyReviewStore.daysConsidered(in: interval, referenceDate: selectedDay, calendar: calendar), 5)
    }

    func testWeeklyReviewRepositoryUpsertsAndLoadsReview() throws {
        let database = try AppDatabase.makeTemporary()
        let repository = WeeklyReviewRepository(database: database)
        let weekStart = "2026-06-08"

        let first = try repository.upsert(
            weekStartDate: weekStart,
            winsText: "Training erledigt",
            challengesText: "Schlaf war schwierig",
            nextWeekFocusText: "Frueher schlafen"
        )
        let second = try repository.upsert(
            weekStartDate: weekStart,
            winsText: "Mehr gekocht",
            challengesText: "Uni war voll",
            nextWeekFocusText: "Ruhiger planen"
        )

        let loaded = try repository.fetch(weekStartDate: weekStart)

        XCTAssertEqual(first.id, second.id)
        XCTAssertEqual(loaded?.winsText, "Mehr gekocht")
        XCTAssertEqual(loaded?.challengesText, "Uni war voll")
        XCTAssertEqual(loaded?.nextWeekFocusText, "Ruhiger planen")
    }

    func testWeeklyReviewTrendsAlwaysBuildsSevenDaysMondayToSunday() {
        let fixture = makeWeeklyReviewTrendsFixture()
        let keys = fixture.trends.caloriesByDay.map { DateIntervals.dayKey(for: $0.date, calendar: fixture.calendar) }

        XCTAssertEqual(fixture.trends.caloriesByDay.count, 7)
        XCTAssertEqual(fixture.trends.proteinByDay.count, 7)
        XCTAssertEqual(fixture.trends.spendingByDay.count, 7)
        XCTAssertEqual(fixture.trends.trainingMinutesByDay.count, 7)
        XCTAssertEqual(fixture.trends.habitCompletionByDay.count, 7)
        XCTAssertEqual(keys, [
            "2026-06-08",
            "2026-06-09",
            "2026-06-10",
            "2026-06-11",
            "2026-06-12",
            "2026-06-13",
            "2026-06-14"
        ])
    }

    func testWeeklyReviewTrendsSumsNutritionFinanceAndTrainingByDay() {
        let trends = makeWeeklyReviewTrendsFixture().trends

        XCTAssertEqual(trends.caloriesByDay.map(\.value), [1000, 0, 800, 0, 0, 0, 0])
        XCTAssertEqual(trends.proteinByDay.map(\.value), [70, 0, 55, 0, 0, 0, 0])
        XCTAssertEqual(trends.spendingByDay.map(\.value), [0, 20, 0, 0, 0, 0, 0])
        XCTAssertEqual(trends.trainingMinutesByDay.map(\.value), [45, 0, 0, 0, 50, 0, 0])
    }

    func testWeeklyReviewTrendsCalculatesHabitCompletionPercentages() {
        let trends = makeWeeklyReviewTrendsFixture().trends

        XCTAssertEqual(trends.habitCompletionByDay[0].value, 40, accuracy: 0.001)
        XCTAssertEqual(trends.habitCompletionByDay[1].value, 0, accuracy: 0.001)
        XCTAssertEqual(trends.habitCompletionByDay[2].value, 20, accuracy: 0.001)
        XCTAssertTrue(trends.habitCompletionByDay.allSatisfy { (0...100).contains($0.value) })
    }

    func testWeeklyReviewTrendsEmptyWeekKeepsZeroValues() {
        let fixture = makeWeeklyReviewTrendsFixture()
        let empty = WeeklyReviewTrends.empty(for: fixture.interval, calendar: fixture.calendar)

        XCTAssertFalse(empty.hasAnyData)
        XCTAssertEqual(empty.caloriesByDay.count, 7)
        XCTAssertTrue(empty.caloriesByDay.allSatisfy { $0.value == 0 })
        XCTAssertTrue(empty.proteinByDay.allSatisfy { $0.value == 0 })
        XCTAssertTrue(empty.spendingByDay.allSatisfy { $0.value == 0 })
        XCTAssertTrue(empty.trainingMinutesByDay.allSatisfy { $0.value == 0 })
        XCTAssertTrue(empty.habitCompletionByDay.allSatisfy { (0...100).contains($0.value) && $0.value == 0 })
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

    func testDashboardStoreUsesPersistedSettingsTargets() throws {
        let database = try AppDatabase.makeTemporary()
        try SettingsRepository(database: database).saveSettings(
            AppSettingsRecord(
                caloriesTarget: 2400,
                proteinTargetG: 170,
                weeklyWorkoutTarget: 4,
                monthlyBudget: 1800,
                defaultCurrency: "EUR",
                weekStartsOn: 2
            )
        )

        let store = DashboardStore(database: database)

        XCTAssertEqual(store.state.caloriesTarget, 2400)
        XCTAssertEqual(store.state.proteinTarget, 170, accuracy: 0.001)
        XCTAssertEqual(store.state.weeklyWorkoutTarget, 4)
        XCTAssertEqual(store.state.monthlyBudget, 1800, accuracy: 0.001)
    }

    func testBackupDirectoryIsCreated() throws {
        let database = try AppDatabase.makeTemporary()
        let backupDirectory = makeTemporaryBackupDirectory().appendingPathComponent("Backups", isDirectory: true)
        let service = BackupService(database: database, backupDirectory: backupDirectory)

        let createdDirectory = try service.backupDirectoryURL()

        var isDirectory: ObjCBool = false
        XCTAssertTrue(FileManager.default.fileExists(atPath: createdDirectory.path, isDirectory: &isDirectory))
        XCTAssertTrue(isDirectory.boolValue)
    }

    func testSQLiteBackupCreatesOpenableDatabaseFile() throws {
        let database = try AppDatabase.makeTemporary()
        try NutritionRepository(database: database).insert(NutritionEntryRecord(title: "Skyr", caloriesKcal: 300, proteinG: 35))
        let service = BackupService(database: database, backupDirectory: makeTemporaryBackupDirectory())

        let backupURL = try service.createSQLiteBackup()

        XCTAssertTrue(FileManager.default.fileExists(atPath: backupURL.path))
        XCTAssertTrue(backupURL.lastPathComponent.hasPrefix("AboLife-backup-"))
        XCTAssertTrue(backupURL.lastPathComponent.hasSuffix(".sqlite"))

        let backupQueue = try DatabaseQueue(path: backupURL.path, configuration: DatabaseConfiguration.makeConfiguration())
        let count = try backupQueue.read { db in
            try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM nutrition_entries")
        }
        XCTAssertEqual(count, 1)
    }

    func testJSONExportCreatesValidFileWithExpectedTopLevelFields() throws {
        let database = try AppDatabase.makeTemporary()
        try seedExportData(in: database)
        let fixedDate = Date(timeIntervalSince1970: 1_780_000_000)
        let service = BackupService(database: database, backupDirectory: makeTemporaryBackupDirectory(), now: { fixedDate })

        let exportURL = try service.createJSONExport()
        let data = try Data(contentsOf: exportURL)
        let object = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let payload = try JSONDecoder.abolifeExportDecoder.decode(AboLifeExportPayload.self, from: data)

        XCTAssertTrue(FileManager.default.fileExists(atPath: exportURL.path))
        XCTAssertTrue(exportURL.lastPathComponent.hasPrefix("AboLife-export-"))
        XCTAssertTrue(exportURL.lastPathComponent.hasSuffix(".json"))
        XCTAssertEqual(object?["exportVersion"] as? Int, 1)
        XCTAssertNotNil(object?["createdAt"])
        XCTAssertEqual(payload.exportVersion, 1)
        XCTAssertEqual(payload.appName, "AboLife")
        XCTAssertEqual(payload.nutritionEntries.count, 1)
        XCTAssertEqual(payload.workoutSessions.count, 1)
        XCTAssertEqual(payload.financeEntries.count, 1)
        XCTAssertEqual(payload.habitEntries.count, 1)
        XCTAssertEqual(payload.bodyMetricEntries.count, 1)
        XCTAssertEqual(payload.weeklyReviews.count, 1)
        XCTAssertEqual(payload.settings.count, 1)
    }

    func testJSONExportPayloadContainsSettingsAndTableArraysWhenEmpty() throws {
        let database = try AppDatabase.makeTemporary()
        let service = BackupService(database: database, backupDirectory: makeTemporaryBackupDirectory())

        let payload = try service.makeExportPayload()

        XCTAssertEqual(payload.exportVersion, 1)
        XCTAssertEqual(payload.appName, "AboLife")
        XCTAssertEqual(payload.nutritionEntries, [])
        XCTAssertEqual(payload.workoutSessions, [])
        XCTAssertEqual(payload.financeEntries, [])
        XCTAssertEqual(payload.habitEntries, [])
        XCTAssertEqual(payload.bodyMetricEntries, [])
        XCTAssertEqual(payload.weeklyReviews, [])
        XCTAssertEqual(payload.settings, [])
    }

    private func makeTemporaryBackupDirectory() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
    }

    private func makeWeeklyReviewTrendsFixture() -> (
        trends: WeeklyReviewTrends,
        interval: DateInterval,
        calendar: Calendar
    ) {
        let calendar = Calendar(identifier: .gregorian)
        let selectedDay = DateComponents(calendar: calendar, year: 2026, month: 6, day: 12, hour: 12).date!
        let interval = DateIntervals.week(containing: selectedDay, weekStartsOn: 2, calendar: calendar)
        let habitKeys = FixedHabit.defaults.map(\.key)
        let monday = DateComponents(calendar: calendar, year: 2026, month: 6, day: 8, hour: 9).date!
        let tuesday = DateComponents(calendar: calendar, year: 2026, month: 6, day: 9, hour: 12).date!
        let wednesday = DateComponents(calendar: calendar, year: 2026, month: 6, day: 10, hour: 18).date!
        let friday = DateComponents(calendar: calendar, year: 2026, month: 6, day: 12, hour: 19).date!

        let trends = WeeklyReviewTrends.make(
            interval: interval,
            nutritionEntries: [
                NutritionEntryRecord(occurredAt: monday, title: "Fruehstueck", caloriesKcal: 400, proteinG: 30),
                NutritionEntryRecord(occurredAt: monday, title: "Lunch", caloriesKcal: 600, proteinG: 40),
                NutritionEntryRecord(occurredAt: wednesday, title: "Dinner", caloriesKcal: 800, proteinG: 55)
            ],
            financeEntries: [
                FinanceEntryRecord(occurredAt: tuesday, title: "Lunch", amount: 12.5, category: "Essen"),
                FinanceEntryRecord(occurredAt: tuesday, title: "Cafe", amount: 7.5, category: "Freizeit")
            ],
            workoutSessions: [
                WorkoutSessionRecord(occurredAt: monday, workoutType: "Home Plan: Pull + Core", durationMin: 45, status: "done"),
                WorkoutSessionRecord(occurredAt: tuesday, workoutType: "Geplant", durationMin: 30, status: "planned"),
                WorkoutSessionRecord(occurredAt: friday, workoutType: "Home Plan: Full Body", durationMin: 50, status: "done")
            ],
            habitEntries: [
                HabitEntryRecord(habitKey: "water", date: "2026-06-08", isCompleted: true),
                HabitEntryRecord(habitKey: "movement", date: "2026-06-08", isCompleted: true),
                HabitEntryRecord(habitKey: "sleep", date: "2026-06-08", isCompleted: false),
                HabitEntryRecord(habitKey: "legacy", date: "2026-06-08", isCompleted: true),
                HabitEntryRecord(habitKey: "water", date: "2026-06-10", isCompleted: true)
            ],
            habitKeys: habitKeys,
            calendar: calendar
        )

        return (trends, interval, calendar)
    }

    private func seedExportData(in database: AppDatabase) throws {
        try NutritionRepository(database: database).insert(NutritionEntryRecord(title: "Skyr", caloriesKcal: 300, proteinG: 35))
        try WorkoutRepository(database: database).insert(WorkoutSessionRecord(workoutType: "push", durationMin: 45, status: "done"))
        try FinanceRepository(database: database).insert(FinanceEntryRecord(title: "Lunch", amount: 12.5, category: "Essen"))
        try HabitRepository(database: database).insert(HabitEntryRecord(habitKey: "water", date: "2026-06-12", isCompleted: true))
        try BodyMetricRepository(database: database).insert(BodyMetricEntryRecord(weightKg: 82.1))
        _ = try WeeklyReviewRepository(database: database).upsert(
            weekStartDate: "2026-06-08",
            winsText: "Training erledigt",
            challengesText: "Schlaf war schwierig",
            nextWeekFocusText: "Ruhiger planen"
        )
        _ = try SettingsRepository(database: database).saveSettings(SeedData.defaultSettings)
    }
}

private extension JSONDecoder {
    static var abolifeExportDecoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}
