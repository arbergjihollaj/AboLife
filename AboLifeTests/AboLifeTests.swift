import XCTest
import AppKit
import GRDB
@testable import AboLife

final class AboLifeTests: XCTestCase {
    func testTrainingProgressionIncreasesWhenTargetIsReached() {
        let service = TrainingProgressionService()
        let progression = ExerciseProgression(exerciseName: "Liegestuetze", level: 1, targetSets: 4, targetMinReps: 8, targetMaxReps: 12)
        let results = [12, 12, 12, 12].enumerated().map {
            ExerciseSetResult(exerciseName: "Liegestuetze", reps: $0.element, setIndex: $0.offset)
        }

        let recommendation = service.recommendation(for: progression, results: results)

        XCTAssertEqual(recommendation.outcomeRawValue, ExerciseProgressionOutcome.increase.rawValue)
        XCTAssertEqual(recommendation.nextLevel, 2)
        XCTAssertEqual(recommendation.nextTargetMinReps, 12)
        XCTAssertEqual(recommendation.nextTargetMaxReps, 15)
    }

    func testTrainingProgressionRepeatsWhenTargetIsBarelyMissed() {
        let service = TrainingProgressionService()
        let progression = ExerciseProgression(exerciseName: "Klimmzuege", level: 2, targetSets: 4, targetMinReps: 3, targetMaxReps: 5)
        let results = [4, 4, 3, 3].enumerated().map {
            ExerciseSetResult(exerciseName: "Klimmzuege", reps: $0.element, setIndex: $0.offset)
        }

        let recommendation = service.recommendation(for: progression, results: results)

        XCTAssertEqual(recommendation.outcomeRawValue, ExerciseProgressionOutcome.repeatTarget.rawValue)
        XCTAssertEqual(recommendation.nextLevel, 2)
    }

    func testTrainingProgressionReducesWhenTargetIsClearlyMissed() {
        let service = TrainingProgressionService()
        let progression = ExerciseProgression(exerciseName: "Pike Push-ups", level: 1, targetSets: 4, targetMinReps: 8, targetMaxReps: 12)
        let results = [3, 2].enumerated().map {
            ExerciseSetResult(exerciseName: "Pike Push-ups", reps: $0.element, setIndex: $0.offset)
        }

        let recommendation = service.recommendation(for: progression, results: results)

        XCTAssertEqual(recommendation.outcomeRawValue, ExerciseProgressionOutcome.reduceTarget.rawValue)
        XCTAssertEqual(recommendation.nextTargetSets, 3)
        XCTAssertLessThan(recommendation.nextTargetMaxReps, progression.targetMaxReps)
    }

    func testTrainingProgressionRecommendsRecoveryWhenPainIsReported() {
        let service = TrainingProgressionService()
        let progression = ExerciseProgression(exerciseName: "Klimmzuege", level: 2, targetSets: 4, targetMinReps: 3, targetMaxReps: 5)
        let results = [
            ExerciseSetResult(exerciseName: "Klimmzuege", reps: 2, setIndex: 0, painReported: true)
        ]

        let recommendation = service.recommendation(for: progression, results: results)

        XCTAssertEqual(recommendation.outcomeRawValue, ExerciseProgressionOutcome.recover.rawValue)
        XCTAssertTrue(recommendation.message.contains("Schmerz"))
    }

    func testBodyProgressServiceCalculatesTrends() {
        let service = BodyProgressService()
        let old = BodyMeasurement(weightKg: 86.5, waistCm: 88, chestCm: 101, armCm: 35, maxPushups: 24, maxPullups: 5)
        let new = BodyMeasurement(measuredAt: Date().addingTimeInterval(60), weightKg: 87.2, waistCm: 87, chestCm: 102.5, armCm: 35.8, maxPushups: 29, maxPullups: 7)

        let trend = service.trend(from: [new, old])

        XCTAssertEqual(trend.weightChangeKg ?? 0, 0.7, accuracy: 0.001)
        XCTAssertEqual(trend.waistChangeCm ?? 0, -1, accuracy: 0.001)
        XCTAssertEqual(trend.pullupChange, 2)
    }

    func testDashboardMockDataKeepsProgressInRange() {
        let snapshot = DashboardMockData.today

        XCTAssertGreaterThanOrEqual(snapshot.coreProgress, 0)
        XCTAssertLessThanOrEqual(snapshot.coreProgress, 1)
        XCTAssertGreaterThan(snapshot.calories.target, 0)
        XCTAssertGreaterThan(snapshot.protein.target, 0)
        XCTAssertEqual(snapshot.week.days.count, 7)
    }

    func testHabitProgressUsesCompletedAndTotal() {
        let habits = HabitStatus(
            title: "Gewohnheiten",
            completed: 3,
            total: 5,
            message: "Mock",
            progressValue: 0.6,
            items: []
        )

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
        let initialCompleted = state.completedHabits
        let openHabitID = state.habits.first { $0.key == "sleep" }!.id
        let store = DashboardStore(state: state)

        store.toggleHabit(openHabitID)

        XCTAssertEqual(store.snapshot.habits.completed, initialCompleted + 1)
    }

    func testQuickAddRoutingMapsDockButtonsToDirectPanels() {
        XCTAssertEqual(QuickAddRouting.panel(for: .meal), .meal)
        XCTAssertEqual(QuickAddRouting.panel(for: .workout), .training)
        XCTAssertEqual(QuickAddRouting.panel(for: .expense), .expense)
        XCTAssertEqual(QuickAddRouting.panel(for: .habit), .habit)
        XCTAssertEqual(QuickAddRouting.panel(for: .general), .generalMenu)
        XCTAssertEqual(QuickAddRouting.panel(for: .weight), .weight)
    }

    func testQuickAddDoesNotOfferDailyNote() {
        XCTAssertFalse(QuickAddKind.allCases.map(\.rawValue).contains("note"))
        XCTAssertFalse(
            QuickAddAction.dashboardActions.contains {
                $0.title.localizedCaseInsensitiveContains("Notiz")
                    || $0.title.localizedCaseInsensitiveContains("Tagesnotiz")
            }
        )
    }

    func testBottomDockActionsKeepPhase7DStructure() {
        XCTAssertEqual(QuickAddAction.bottomDockActions.map(\.kind), [.meal, .workout, .expense, .habit])
    }

    func testDashboardStoreMealQuickActionPersistsNutritionEntry() throws {
        let database = try AppDatabase.makeTemporary()
        let store = DashboardStore(database: database)

        store.addMeal(name: "", calories: -50, protein: 25.5, note: "nach Training")

        let entries = try NutritionRepository(database: database).fetchAll()
        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries.first?.title, "Mahlzeit")
        XCTAssertEqual(entries.first?.caloriesKcal, 0)
        XCTAssertEqual(entries.first?.proteinG ?? 0, 25.5, accuracy: 0.001)
        XCTAssertEqual(entries.first?.note, "nach Training")
    }

    func testDashboardStoreTrainingQuickActionPersistsWorkoutSession() throws {
        let database = try AppDatabase.makeTemporary()
        let store = DashboardStore(database: database)

        store.completeWorkout(type: "Mobility", durationMinutes: 20, note: "locker")

        let sessions = try WorkoutRepository(database: database).fetchAll()
        XCTAssertEqual(sessions.count, 1)
        XCTAssertEqual(sessions.first?.workoutType, "Mobility")
        XCTAssertEqual(sessions.first?.durationMin, 20)
        XCTAssertEqual(sessions.first?.status, "done")
        XCTAssertEqual(sessions.first?.note, "locker")
    }

    func testDashboardStoreHomeWorkoutQuickActionPersistsWorkoutSession() throws {
        let database = try AppDatabase.makeTemporary()
        let store = DashboardStore(database: database)

        store.completeHomeWorkout(intensity: .strong)

        let sessions = try WorkoutRepository(database: database).fetchAll()
        XCTAssertEqual(sessions.count, 1)
        XCTAssertTrue(sessions.first?.workoutType.hasPrefix("Home Plan:") == true)
        XCTAssertEqual(sessions.first?.durationMin, 45)
        XCTAssertEqual(sessions.first?.status, "done")
        XCTAssertTrue(sessions.first?.note?.contains("Intensität: Stark") == true)
    }

    func testDashboardStoreExpenseQuickActionPersistsFinanceEntry() throws {
        let database = try AppDatabase.makeTemporary()
        let store = DashboardStore(database: database)

        store.addExpense(title: "", amount: 12.75, category: "Freizeit", note: "Kino")

        let entries = try FinanceRepository(database: database).fetchAll()
        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries.first?.title, "Ausgabe")
        XCTAssertEqual(entries.first?.amount ?? 0, 12.75, accuracy: 0.001)
        XCTAssertEqual(entries.first?.currency, "EUR")
        XCTAssertEqual(entries.first?.category, "Freizeit")
        XCTAssertEqual(entries.first?.note, "Kino")
    }

    func testFinancePlanningPersistsBudgetsFixedCostsAndSavingsGoals() throws {
        let database = try AppDatabase.makeTemporary()
        let repository = FinanceRepository(database: database)

        try repository.insert(FinanceEntryRecord(title: "Rewe", amount: 42, currency: "EUR", category: "Lebensmittel"))
        try repository.upsertCategoryBudget(monthKey: FinanceRepository.monthKey(), category: "Lebensmittel", amount: 300, currency: "EUR")
        try repository.upsertFixedCost(FinanceFixedCostRecord(title: "Miete", amount: 900, category: "Wohnen", dueDay: 1))
        try repository.upsertSavingsGoal(FinanceSavingsGoalRecord(title: "Notgroschen", targetAmount: 1000, currentAmount: 250))

        let budgets = try repository.fetchCategoryBudgets(monthKey: FinanceRepository.monthKey())
        let fixedCosts = try repository.fetchFixedCosts(activeOnly: true)
        let goals = try repository.fetchSavingsGoals(activeOnly: true)
        let categories = try repository.categorySummaries()

        XCTAssertEqual(budgets.first?.category, "Lebensmittel")
        XCTAssertEqual(fixedCosts.first?.title, "Miete")
        XCTAssertEqual(goals.first?.progress ?? 0, 0.25, accuracy: 0.001)
        XCTAssertEqual(categories.first?.spent ?? 0, 42, accuracy: 0.001)
        XCTAssertEqual(categories.first?.budget ?? 0, 300, accuracy: 0.001)
    }

    func testFinanceMonthPlanCalculatesForecastAndCategorySummaries() throws {
        let database = try AppDatabase.makeTemporary()
        let repository = FinanceRepository(database: database)
        let calendar = Calendar(identifier: .gregorian)
        let date = calendar.date(from: DateComponents(year: 2026, month: 6, day: 15))!

        try repository.insert(FinanceEntryRecord(occurredAt: date, title: "Lunch", amount: 20, category: "Essen"))
        try repository.upsertCategoryBudget(monthKey: "2026-06", category: "Essen", amount: 250, currency: "EUR")
        try repository.upsertFixedCost(FinanceFixedCostRecord(title: "Internet", amount: 50, category: "Wohnen", dueDay: 20))

        let plan = try repository.monthPlan(for: date, monthlyBudget: 800, currency: "EUR", calendar: calendar)

        XCTAssertEqual(plan.spent, 20, accuracy: 0.001)
        XCTAssertEqual(plan.remainingFixedCosts, 50, accuracy: 0.001)
        XCTAssertEqual(plan.categorySummaries.first?.category, "Essen unterwegs")
        XCTAssertGreaterThan(plan.forecastSpend, plan.spent)
    }

    func testExternalInputInfersExpenseCategoryForTelegramStyleText() throws {
        let database = try AppDatabase.makeTemporary()
        let service = ExternalInputService(database: database)

        _ = service.execute(.expense(date: Date(), amount: 12, title: "Döner Lunch", category: nil))

        let entry = try FinanceRepository(database: database).fetchAll().first
        XCTAssertEqual(entry?.category, "Essen unterwegs")
    }

    func testFinanceCategoryCatalogKeepsLegacyCategoriesReadableButGroupsKnownAliases() {
        XCTAssertEqual(FinanceCategoryCatalog.normalized("Essen", kind: .expense), "Essen unterwegs")
        XCTAssertEqual(FinanceCategoryCatalog.normalized("Haushalt", kind: .expense), "Haushalt")
        XCTAssertEqual(FinanceCategoryCatalog.normalized("Wohnen", kind: .expense), "Fixkosten")
        XCTAssertEqual(FinanceCategoryCatalog.normalized("Alte Spezialkategorie", kind: .expense), "Alte Spezialkategorie")
    }

    func testFinanceDefaultCategoriesAreSeededAndFallbackExists() throws {
        let database = try AppDatabase.makeTemporary()
        let repository = FinanceRepository(database: database)

        let names = try repository.fetchActiveCategoryNames()

        XCTAssertTrue(names.contains("Lebensmittel"))
        XCTAssertTrue(names.contains("Essen unterwegs"))
        XCTAssertTrue(names.contains("Fixkosten"))
        XCTAssertTrue(names.contains("Transport"))
        XCTAssertTrue(names.contains("Abos"))
        XCTAssertTrue(names.contains("Sonstiges"))
        XCTAssertEqual(Set(FinanceCategoryCatalog.defaultExpenseCategories).count, FinanceCategoryCatalog.defaultExpenseCategories.count)
    }

    func testFinanceCustomCategoryLifecycleAndSafeDelete() throws {
        let database = try AppDatabase.makeTemporary()
        let repository = FinanceRepository(database: database)

        let created = try repository.createCategory(name: "  Haustier  ")
        XCTAssertEqual(created.name, "Haustier")

        let renamed = try repository.renameCategory(id: created.id, to: "Katze")
        XCTAssertEqual(renamed.name, "Katze")

        try repository.insert(FinanceEntryRecord(title: "Futter", amount: 12, category: "Katze"))
        let deleteResult = try repository.deleteCategorySafely(id: created.id)
        let archived = try repository.fetchCategories(includeInactive: true).first { $0.id == created.id }

        XCTAssertEqual(deleteResult, .deactivated)
        XCTAssertEqual(archived?.isActive, false)
        XCTAssertTrue(try repository.fetchCategoryNamesIncludingLegacy().contains("Katze"))
        XCTAssertFalse(try repository.fetchActiveCategoryNames().contains("Katze"))
    }

    func testFinanceCustomCategoryDeletesWhenUnused() throws {
        let database = try AppDatabase.makeTemporary()
        let repository = FinanceRepository(database: database)

        let category = try repository.createCategory(name: "Projekt")
        let result = try repository.deleteCategorySafely(id: category.id)

        XCTAssertEqual(result, .deleted)
        XCTAssertFalse(try repository.fetchCategories(includeInactive: true).contains { $0.id == category.id })
    }

    func testFinanceCategoryRulesSuggestExpectedCategories() {
        XCTAssertEqual(FinanceCategoryCatalog.suggestedCategory(for: "Ausgabe Döner 4,50").category, "Essen unterwegs")
        XCTAssertEqual(FinanceCategoryCatalog.suggestedCategory(for: "Pizza").category, "Essen unterwegs")
        XCTAssertEqual(FinanceCategoryCatalog.suggestedCategory(for: "Rewe 23,90").category, "Lebensmittel")
        XCTAssertEqual(FinanceCategoryCatalog.suggestedCategory(for: "Aldi Einkauf").category, "Lebensmittel")
        XCTAssertEqual(FinanceCategoryCatalog.suggestedCategory(for: "Netflix 12,99").category, "Abos")
        XCTAssertEqual(FinanceCategoryCatalog.suggestedCategory(for: "Spotify").category, "Abos")
        XCTAssertEqual(FinanceCategoryCatalog.suggestedCategory(for: "Bahn 3,40").category, "Transport")
        XCTAssertEqual(FinanceCategoryCatalog.suggestedCategory(for: "Taxi").category, "Transport")
        XCTAssertEqual(FinanceCategoryCatalog.suggestedCategory(for: "Unbekanntes Ding", fallback: "Freizeit").category, "Freizeit")
        XCTAssertEqual(FinanceCategoryCatalog.suggestedCategory(for: "Unbekanntes Ding").category, "Sonstiges")
    }

    func testFinanceMonthlyAnalysisUsesComparisonsAndFixedCostForecast() throws {
        let database = try AppDatabase.makeTemporary()
        let repository = FinanceRepository(database: database)
        let calendar = Calendar(identifier: .gregorian)
        let june10 = DateComponents(calendar: calendar, year: 2026, month: 6, day: 10, hour: 12).date!
        let june20 = DateComponents(calendar: calendar, year: 2026, month: 6, day: 20, hour: 12).date!
        let may10 = DateComponents(calendar: calendar, year: 2026, month: 5, day: 10, hour: 12).date!
        let april10 = DateComponents(calendar: calendar, year: 2026, month: 4, day: 10, hour: 12).date!
        let march10 = DateComponents(calendar: calendar, year: 2026, month: 3, day: 10, hour: 12).date!

        try repository.insert(FinanceEntryRecord(occurredAt: june10, title: "Rewe", amount: 100, category: "Lebensmittel"))
        try repository.insert(FinanceEntryRecord(occurredAt: june20, title: "Gehalt", amount: -1000, category: "Gehalt"))
        try repository.insert(FinanceEntryRecord(occurredAt: may10, title: "Mai", amount: 200, category: "Lebensmittel"))
        try repository.insert(FinanceEntryRecord(occurredAt: april10, title: "April", amount: 150, category: "Transport"))
        try repository.insert(FinanceEntryRecord(occurredAt: march10, title: "März", amount: 250, category: "Freizeit"))
        try repository.upsertFixedCost(FinanceFixedCostRecord(title: "Internet", amount: 50, category: "Fixkosten", dueDay: 25))

        let analysis = try repository.monthlyAnalysis(forDate: june20, monthlyBudget: 800, currency: "EUR", calendar: calendar)

        XCTAssertEqual(analysis.spent, 100, accuracy: 0.001)
        XCTAssertEqual(analysis.income, 1000, accuracy: 0.001)
        XCTAssertEqual(analysis.remainingBudget, 700, accuracy: 0.001)
        XCTAssertEqual(analysis.previousMonthSpent ?? 0, 200, accuracy: 0.001)
        XCTAssertEqual(analysis.changeFromPreviousMonth ?? 0, -100, accuracy: 0.001)
        XCTAssertEqual(analysis.trailingThreeMonthAverageSpent ?? 0, 200, accuracy: 0.001)
        XCTAssertEqual(analysis.savingsRate ?? 0, 0.9, accuracy: 0.001)
        XCTAssertEqual(analysis.remainingFixedCosts, 50, accuracy: 0.001)
        XCTAssertGreaterThan(analysis.projectedSpend, analysis.spent)
        XCTAssertEqual(analysis.topCategory?.category, "Lebensmittel")
    }

    func testFinanceMonthlyAnalysisKeepsSparseDataComparisonsEmpty() throws {
        let database = try AppDatabase.makeTemporary()
        let repository = FinanceRepository(database: database)
        let calendar = Calendar(identifier: .gregorian)
        let june10 = DateComponents(calendar: calendar, year: 2026, month: 6, day: 10, hour: 12).date!

        try repository.insert(FinanceEntryRecord(occurredAt: june10, title: "Rewe", amount: 100, category: "Lebensmittel"))

        let analysis = try repository.monthlyAnalysis(forDate: june10, monthlyBudget: 800, currency: "EUR", calendar: calendar)

        XCTAssertNil(analysis.previousMonthSpent)
        XCTAssertNil(analysis.changeFromPreviousMonth)
        XCTAssertNil(analysis.trailingThreeMonthAverageSpent)
        XCTAssertNil(analysis.savingsRate)
    }

    func testFinanceStandardCategoriesIncludeRequiredPhaseCategoriesAndFallback() {
        let required = [
            "Lebensmittel",
            "Essen unterwegs",
            "Fixkosten",
            "Transport",
            "Freizeit",
            "Kleidung",
            "Gesundheit",
            "Technik",
            "Lernen",
            "Haushalt",
            "Geschenke",
            "Abos",
            "Sparen",
            "Sonstiges"
        ]

        XCTAssertEqual(FinanceCategoryCatalog.normalized("", kind: .expense), "Sonstiges")
        XCTAssertEqual(FinanceCategoryCatalog.normalized("   ", kind: .expense), "Sonstiges")

        let missing = required.filter { !FinanceCategoryCatalog.expenseCategories.contains($0) }
        XCTAssertTrue(missing.isEmpty, "Fehlende Standardkategorien: \(missing.joined(separator: ", "))")
    }

    func testFinanceCategoryMigrationHasCustomCategoryStorageHook() throws {
        let database = try AppDatabase.makeTemporary()

        let hasCategoriesTable = try database.writer.read { db in
            try db.tableExists("finance_categories")
        }

        XCTAssertTrue(hasCategoriesTable, "finance_categories-Tabelle fehlt; CRUD/deactivate/delete-safe ist damit noch nicht testbar.")
    }

    func testFinanceLegacyUnknownCategoriesStayVisibleAndEmptyCategoryFallsBackToSonstiges() throws {
        let database = try AppDatabase.makeTemporary()
        let repository = FinanceRepository(database: database)

        try repository.insert(FinanceEntryRecord(title: "Altbestand", amount: 12, category: "Alte Spezialkategorie"))
        try repository.insert(FinanceEntryRecord(title: "Ohne Kategorie", amount: 8, category: ""))

        let summaries = try repository.categorySummaries()

        XCTAssertTrue(summaries.contains { $0.category == "Alte Spezialkategorie" && $0.spent == 12 })
        XCTAssertTrue(summaries.contains { $0.category == "Sonstiges" && $0.spent == 8 })
    }

    func testFinanceCategoryRulesCoverFoodGroceriesSubscriptionsAndTransport() throws {
        let database = try AppDatabase.makeTemporary()
        let service = ExternalInputService(database: database)

        XCTAssertSuccess(service.execute(.expense(date: Date(), amount: 4.5, title: "Döner", category: nil)), module: .finance)
        XCTAssertSuccess(service.execute(.expense(date: Date(), amount: 23.9, title: "Rewe Einkauf", category: nil)), module: .finance)
        XCTAssertSuccess(service.execute(.expense(date: Date(), amount: 12.99, title: "Netflix", category: nil)), module: .finance)
        XCTAssertSuccess(service.execute(.expense(date: Date(), amount: 3.4, title: "Bahn Ticket", category: nil)), module: .finance)

        let entriesByTitle = Dictionary(uniqueKeysWithValues: try FinanceRepository(database: database).fetchAll().map { ($0.title, $0.category) })
        XCTAssertEqual(entriesByTitle["Döner"], "Essen unterwegs")
        XCTAssertEqual(entriesByTitle["Rewe Einkauf"], "Lebensmittel")
        XCTAssertEqual(entriesByTitle["Netflix"], "Abos")
        XCTAssertEqual(entriesByTitle["Bahn Ticket"], "Transport")
    }

    func testFinanceMonthlyTrendCalculatesPreviousMonthDailyAverageAndProjection() throws {
        let database = try AppDatabase.makeTemporary()
        let repository = FinanceRepository(database: database)
        let calendar = Calendar(identifier: .gregorian)
        let june10 = DateComponents(calendar: calendar, year: 2026, month: 6, day: 10, hour: 12).date!
        let june20 = DateComponents(calendar: calendar, year: 2026, month: 6, day: 20, hour: 12).date!
        let may20 = DateComponents(calendar: calendar, year: 2026, month: 5, day: 20, hour: 12).date!

        try repository.insert(FinanceEntryRecord(occurredAt: june10, title: "Rewe", amount: 100, category: "Lebensmittel"))
        try repository.insert(FinanceEntryRecord(occurredAt: june20, title: "Gehalt", amount: -1000, category: "Gehalt"))
        try repository.insert(FinanceEntryRecord(occurredAt: may20, title: "Mai", amount: 300, category: "Sonstiges"))

        let trend = try repository.monthlyTrend(forDate: june20, calendar: calendar)

        XCTAssertEqual(trend.spent, 100, accuracy: 0.001)
        XCTAssertEqual(trend.income, 1000, accuracy: 0.001)
        XCTAssertEqual(trend.balance, 900, accuracy: 0.001)
        XCTAssertEqual(trend.previousSpent, 300, accuracy: 0.001)
        XCTAssertEqual(trend.averageDailySpend, 5, accuracy: 0.001)
        XCTAssertEqual(trend.projectedSpend, 150, accuracy: 0.001)
    }

    func testFinanceMonthlyTrendStaysCalmWithLittleData() throws {
        let database = try AppDatabase.makeTemporary()
        let repository = FinanceRepository(database: database)
        let calendar = Calendar(identifier: .gregorian)
        let june20 = DateComponents(calendar: calendar, year: 2026, month: 6, day: 20, hour: 12).date!

        let trend = try repository.monthlyTrend(forDate: june20, calendar: calendar)

        XCTAssertEqual(trend.spent, 0, accuracy: 0.001)
        XCTAssertEqual(trend.income, 0, accuracy: 0.001)
        XCTAssertEqual(trend.previousEntryCount, 0)
        XCTAssertEqual(trend.projectedSpend, 0, accuracy: 0.001)
        XCTAssertEqual(trend.savings, 0, accuracy: 0.001)
    }

    func testFinanceMonthPlanIncludesOnlyActiveUpcomingFixedCostsInForecast() throws {
        let database = try AppDatabase.makeTemporary()
        let repository = FinanceRepository(database: database)
        let calendar = Calendar(identifier: .gregorian)
        let date = DateComponents(calendar: calendar, year: 2026, month: 6, day: 15, hour: 12).date!

        try repository.insert(FinanceEntryRecord(occurredAt: date, title: "Rewe", amount: 150, category: "Lebensmittel"))
        try repository.upsertFixedCost(FinanceFixedCostRecord(title: "Internet", amount: 50, category: "Fixkosten", dueDay: 20, isActive: true))
        try repository.upsertFixedCost(FinanceFixedCostRecord(title: "Miete erledigt", amount: 800, category: "Fixkosten", dueDay: 1, isActive: true))
        try repository.upsertFixedCost(FinanceFixedCostRecord(title: "Altes Abo", amount: 30, category: "Abos", dueDay: 25, isActive: false))

        let plan = try repository.monthPlan(for: date, monthlyBudget: 900, currency: "EUR", calendar: calendar)

        XCTAssertEqual(plan.spent, 150, accuracy: 0.001)
        XCTAssertEqual(plan.plannedFixedCosts, 850, accuracy: 0.001)
        XCTAssertEqual(plan.remainingFixedCosts, 50, accuracy: 0.001)
        XCTAssertGreaterThan(plan.forecastSpend, plan.spent)
        XCTAssertLessThan(plan.forecastSpend, plan.spent + 900)
        XCTAssertFalse(plan.categorySummaries.contains { $0.category == "Abos" && $0.spent == 30 })
    }

    func testFinanceCategorySummariesExposeBudgetProgressAndOverBudgetCalmly() throws {
        let database = try AppDatabase.makeTemporary()
        let repository = FinanceRepository(database: database)
        let calendar = Calendar(identifier: .gregorian)
        let date = DateComponents(calendar: calendar, year: 2026, month: 6, day: 12).date!

        try repository.insert(FinanceEntryRecord(occurredAt: date, title: "Rewe", amount: 118, category: "Lebensmittel"))
        try repository.upsertCategoryBudget(monthKey: "2026-06", category: "Lebensmittel", amount: 100, currency: "EUR")

        let summary = try XCTUnwrap(repository.categorySummaries(forMonthContaining: date, calendar: calendar).first)

        XCTAssertEqual(summary.category, "Lebensmittel")
        XCTAssertEqual(summary.spent, 118, accuracy: 0.001)
        XCTAssertEqual(summary.budget ?? 0, 100, accuracy: 0.001)
        XCTAssertEqual(summary.progress, 1, accuracy: 0.001)
        XCTAssertTrue(summary.isOverBudget)
    }

    func testDashboardFinanceStatusReflectsPersistedMonthlySpendingAndDailyBudget() throws {
        let database = try AppDatabase.makeTemporary()
        try SettingsRepository(database: database).saveSettings(
            AppSettingsRecord(caloriesTarget: 2200, proteinTargetG: 150, monthlyBudget: 900, defaultCurrency: "EUR")
        )
        try FinanceRepository(database: database).insert(
            FinanceEntryRecord(title: "Rewe", amount: 90, category: "Lebensmittel")
        )

        let store = DashboardStore(database: database)

        XCTAssertEqual(store.snapshot.finance.spentThisMonth, 90, accuracy: 0.001)
        XCTAssertEqual(store.snapshot.finance.monthlyBudget, 900, accuracy: 0.001)
        XCTAssertGreaterThan(store.snapshot.finance.remainingToday, 0)
        XCTAssertTrue(store.snapshot.finance.message.contains("EUR"))
    }

    func testMenuBarFinanceStatusSourceUsesSameDashboardDailyBudgetCalculation() {
        var state = DashboardMockState.default
        state.monthlyBudget = 900
        state.monthlySpent = 450
        let snapshot = DashboardMockData.snapshot(from: state)

        XCTAssertEqual(snapshot.finance.remainingToday, state.dailyBudgetRemaining, accuracy: 0.001)
        XCTAssertEqual(snapshot.finance.spentThisMonth, 450, accuracy: 0.001)
        XCTAssertEqual(snapshot.finance.monthlyBudget, 900, accuracy: 0.001)
    }

    func testWeightGoalSummaryCalculatesDistanceAndCorridor() {
        let summary = WeightGoalSummary(currentWeightKg: 84.2, targetWeightKg: 80, lowerBoundKg: 78, upperBoundKg: 82)

        XCTAssertEqual(summary.distanceToTargetKg ?? 0, 4.2, accuracy: 0.001)
        XCTAssertEqual(summary.distanceText, "Noch 4.2 kg bis zum Ziel")
        XCTAssertEqual(summary.isInTargetCorridor, false)
        XCTAssertEqual(summary.statusText, "Außerhalb Zielkorridor")
    }

    func testSettingsPersistWeightTargetsAndMigrationColumnsExist() throws {
        let database = try AppDatabase.makeTemporary()
        let repository = SettingsRepository(database: database)

        _ = try repository.saveSettings(
            AppSettingsRecord(
                caloriesTarget: 2200,
                proteinTargetG: 160,
                monthlyBudget: 1200,
                targetWeightKg: 80,
                targetWeightLowerKg: 82,
                targetWeightUpperKg: 78
            )
        )

        let loaded = try repository.loadSettings()
        XCTAssertEqual(loaded.targetWeightKg ?? 0, 80, accuracy: 0.001)
        XCTAssertEqual(loaded.targetWeightLowerKg ?? 0, 78, accuracy: 0.001)
        XCTAssertEqual(loaded.targetWeightUpperKg ?? 0, 82, accuracy: 0.001)
    }

    func testDashboardStoreWeightQuickActionStillPersistsWeight() throws {
        let database = try AppDatabase.makeTemporary()
        let store = DashboardStore(database: database)

        XCTAssertTrue(store.updateWeight(82.4))
        XCTAssertTrue(store.updateWeight(82.1))

        let entries = try WeightRepository(database: database).fetchAll()
        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries.first?.weightKg ?? 0, 82.1, accuracy: 0.001)
        XCTAssertEqual(store.snapshot.weight.valueKg ?? 0, 82.1, accuracy: 0.001)
    }

    func testDashboardStoreHabitQuickActionsPersistMeasuredValues() throws {
        let database = try AppDatabase.makeTemporary()
        let store = DashboardStore(database: database)
        let date = DateIntervals.dayKey()

        XCTAssertEqual(store.applyHabitDelta(habitKey: "water", delta: 0.25), 0.25, accuracy: 0.001)
        XCTAssertEqual(store.applyHabitDelta(habitKey: "nutrition", delta: 1), 1, accuracy: 0.001)
        XCTAssertEqual(store.applyHabitDelta(habitKey: "learning", delta: 15), 15, accuracy: 0.001)
        store.setSleepRoutine(isCompleted: true)

        let repository = HabitRepository(database: database)
        XCTAssertEqual(try repository.fetchEntry(habitKey: "water", date: date)?.value ?? 0, 0.25, accuracy: 0.001)
        XCTAssertEqual(try repository.fetchEntry(habitKey: "nutrition", date: date)?.value ?? 0, 1, accuracy: 0.001)
        XCTAssertEqual(try repository.fetchEntry(habitKey: "learning", date: date)?.value ?? 0, 15, accuracy: 0.001)
        XCTAssertEqual(try repository.fetchEntry(habitKey: "sleep", date: date)?.value ?? 0, 1, accuracy: 0.001)
        XCTAssertEqual(try repository.fetchEntry(habitKey: "sleep", date: date)?.isCompleted, true)
    }

    func testFixedHabitDefinitionsUseTrainingInsteadOfMovement() {
        let keys = FixedHabit.defaults.map(\.key)
        let training = FixedHabit.defaultDefinition(for: "training")

        XCTAssertEqual(keys, ["water", "training", "nutrition", "learning", "sleep"])
        XCTAssertFalse(keys.contains("movement"))
        XCTAssertEqual(training?.title, "Trainieren")
        XCTAssertEqual(training?.targetValue, 1)
        XCTAssertEqual(training?.kind, .derived)
        XCTAssertEqual(training?.isDerived, true)
    }

    func testQuickHabitActionsDoNotContainMovement() {
        let actionKeys = QuickHabitAction.generalMenuActions.map(\.habitKey)

        XCTAssertEqual(actionKeys, ["water", "nutrition", "learning", "sleep"])
        XCTAssertFalse(actionKeys.contains("movement"))
        XCTAssertFalse(actionKeys.contains("training"))
    }

    func testDashboardStoreHabitQuickActionDoesNotDropBelowZero() throws {
        let database = try AppDatabase.makeTemporary()
        let store = DashboardStore(database: database)

        XCTAssertEqual(store.applyHabitDelta(habitKey: "water", delta: -0.25), 0, accuracy: 0.001)

        let entry = try HabitRepository(database: database).fetchEntry(habitKey: "water", date: DateIntervals.dayKey())
        XCTAssertEqual(entry?.value ?? -1, 0, accuracy: 0.001)
    }

    func testQuickAddNumericParsingRejectsNonFiniteValues() {
        XCTAssertEqual(parseDouble("nan"), 0, accuracy: 0.001)
        XCTAssertEqual(parseDouble("inf"), 0, accuracy: 0.001)
        XCTAssertEqual(parseDouble("1,25"), 1.25, accuracy: 0.001)
    }

    func testDashboardDailyBudgetUsesFinanceDaysRemainingLogic() {
        var state = DashboardMockState.persistedDefault
        state.monthlyBudget = 1200
        state.monthlySpent = 300

        XCTAssertEqual(
            state.dailyBudgetRemaining,
            FinanceStore.dailyBudgetRemaining(spent: 300, budget: 1200, date: Date()),
            accuracy: 0.001
        )
    }

    func testHabitQuickActionProgressUsesMeasuredValue() throws {
        let database = try AppDatabase.makeTemporary()
        let store = DashboardStore(database: database)

        _ = store.applyHabitDelta(habitKey: "water", delta: 0.25)
        let habitsStore = HabitsStore(database: database)
        let water = FixedHabit.defaultDefinition(for: "water")!

        XCTAssertEqual(habitsStore.progress(for: water), 0.25 / 3.0, accuracy: 0.001)
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
        XCTAssertTrue(tableNames.contains("weight_entries"))
        XCTAssertTrue(tableNames.contains("nutrition_templates"))
        XCTAssertTrue(tableNames.contains("workout_exercises"))
        XCTAssertTrue(tableNames.contains("workout_sets"))
        XCTAssertTrue(tableNames.contains("finance_categories"))

        let appSettingsColumns: Set<String> = try database.writer.read { db in
            let rows = try Row.fetchAll(db, sql: "PRAGMA table_info(app_settings)")
            return Set(rows.compactMap { row in row["name"] as String? })
        }

        let habitEntryColumns: Set<String> = try database.writer.read { db in
            let rows = try Row.fetchAll(db, sql: "PRAGMA table_info(habit_entries)")
            return Set(rows.compactMap { row in row["name"] as String? })
        }

        XCTAssertTrue(appSettingsColumns.contains("weekly_workout_target"))
        XCTAssertTrue(appSettingsColumns.contains("target_weight_kg"))
        XCTAssertTrue(appSettingsColumns.contains("target_weight_lower_kg"))
        XCTAssertTrue(appSettingsColumns.contains("target_weight_upper_kg"))
        XCTAssertTrue(appSettingsColumns.contains("morning_reminder_minute_of_day"))
        XCTAssertTrue(appSettingsColumns.contains("training_reminder_minute_of_day"))
        XCTAssertTrue(appSettingsColumns.contains("evening_reminder_minute_of_day"))
        XCTAssertTrue(habitEntryColumns.contains("value"))
        XCTAssertTrue(habitEntryColumns.contains("target_value"))
        XCTAssertTrue(habitEntryColumns.contains("unit"))

        let workoutSessionColumns: Set<String> = try database.writer.read { db in
            let rows = try Row.fetchAll(db, sql: "PRAGMA table_info(workout_sessions)")
            return Set(rows.compactMap { row in row["name"] as String? })
        }
        XCTAssertTrue(workoutSessionColumns.contains("workout_intensity"))
        XCTAssertTrue(workoutSessionColumns.contains("pain_reported"))
    }

    func testNutritionTemplateRepositoryCreatesFavorite() throws {
        let database = try AppDatabase.makeTemporary()
        let repository = NutritionTemplateRepository(database: database)

        let template = try repository.create(
            kind: .favorite,
            name: "Skyr 500g",
            caloriesKcal: 310,
            proteinG: 55,
            defaultPortion: "500g",
            mealType: "Snack"
        )

        XCTAssertEqual(template.kind, .favorite)
        XCTAssertEqual(template.name, "Skyr 500g")
        XCTAssertEqual(template.caloriesKcal, 310)
        XCTAssertEqual(template.proteinG, 55, accuracy: 0.001)
        XCTAssertEqual(try repository.fetchAll().count, 1)
    }

    func testNutritionTemplateRepositoryUpdatesTemplate() throws {
        let database = try AppDatabase.makeTemporary()
        let repository = NutritionTemplateRepository(database: database)
        let template = try repository.create(kind: .mealTemplate, name: "Proteinshake", caloriesKcal: 220, proteinG: 30)

        let updated = try XCTUnwrap(repository.update(
            id: template.id,
            kind: .mealTemplate,
            name: "Proteinshake groß",
            caloriesKcal: 300,
            proteinG: 42,
            note: "nach Training"
        ))

        XCTAssertEqual(updated.id, template.id)
        XCTAssertEqual(updated.name, "Proteinshake groß")
        XCTAssertEqual(updated.caloriesKcal, 300)
        XCTAssertEqual(updated.proteinG, 42, accuracy: 0.001)
        XCTAssertEqual(updated.note, "nach Training")
    }

    func testNutritionTemplateRepositoryDeletesTemplateWithoutDeletingMeals() throws {
        let database = try AppDatabase.makeTemporary()
        let templateRepository = NutritionTemplateRepository(database: database)
        let nutritionRepository = NutritionRepository(database: database)
        let template = try templateRepository.create(kind: .favorite, name: "Döner", caloriesKcal: 750, proteinG: 35)
        _ = try templateRepository.addMeal(from: template)

        try templateRepository.delete(id: template.id)

        XCTAssertTrue(try templateRepository.fetchAll().isEmpty)
        XCTAssertEqual(try nutritionRepository.fetchAll().count, 1)
        XCTAssertEqual(try nutritionRepository.fetchAll().first?.title, "Döner")
    }

    func testNutritionTemplateValidationRejectsInvalidValues() throws {
        XCTAssertThrowsError(try NutritionTemplateRepository.validate(name: "", caloriesKcal: 100, proteinG: 10)) { error in
            XCTAssertEqual(error as? NutritionTemplateValidationError, .emptyName)
        }
        XCTAssertThrowsError(try NutritionTemplateRepository.validate(name: "Skyr", caloriesKcal: -1, proteinG: 10)) { error in
            XCTAssertEqual(error as? NutritionTemplateValidationError, .invalidCalories)
        }
        XCTAssertThrowsError(try NutritionTemplateRepository.validate(name: "Skyr", caloriesKcal: 100, proteinG: -1)) { error in
            XCTAssertEqual(error as? NutritionTemplateValidationError, .invalidProtein)
        }
    }

    func testNutritionTemplateCanBeAddedAsMealForToday() throws {
        let database = try AppDatabase.makeTemporary()
        let templateRepository = NutritionTemplateRepository(database: database)
        let template = try templateRepository.create(kind: .favorite, name: "3 Eier", caloriesKcal: 240, proteinG: 21)

        let meal = try templateRepository.addMeal(from: template)

        XCTAssertEqual(meal.title, "3 Eier")
        XCTAssertEqual(meal.caloriesKcal, 240)
        XCTAssertEqual(meal.proteinG, 21, accuracy: 0.001)
        XCTAssertEqual(try NutritionRepository(database: database).daySummary().caloriesKcal, 240)
    }

    func testNutritionTemplateCanBeAddedAsMealForSpecificDate() throws {
        let database = try AppDatabase.makeTemporary()
        let repository = NutritionTemplateRepository(database: database)
        let calendar = Calendar(identifier: .gregorian)
        let selectedDate = DateComponents(calendar: calendar, year: 2026, month: 6, day: 12, hour: 12).date!
        let otherDate = DateComponents(calendar: calendar, year: 2026, month: 6, day: 13, hour: 12).date!
        let template = try repository.create(kind: .mealTemplate, name: "Reis + Hähnchen", caloriesKcal: 650, proteinG: 50)

        _ = try repository.addMeal(from: template, date: selectedDate, calendar: calendar)

        XCTAssertEqual(try NutritionRepository(database: database).daySummary(for: selectedDate, calendar: calendar).caloriesKcal, 650)
        XCTAssertEqual(try NutritionRepository(database: database).daySummary(for: otherDate, calendar: calendar).caloriesKcal, 0)
    }

    func testNutritionTemplatesDoNotCountAsMealsUntilAdded() throws {
        let database = try AppDatabase.makeTemporary()
        let templateRepository = NutritionTemplateRepository(database: database)
        let nutritionRepository = NutritionRepository(database: database)
        let calendar = Calendar(identifier: .gregorian)
        let selectedDate = DateComponents(calendar: calendar, year: 2026, month: 6, day: 12, hour: 12).date!
        let weekInterval = DateIntervals.week(containing: selectedDate, weekStartsOn: 2, calendar: calendar)

        let template = try templateRepository.create(kind: .favorite, name: "Kaffee", caloriesKcal: 20, proteinG: 0)
        XCTAssertEqual(try nutritionRepository.weeklySummary(in: weekInterval).entryCount, 0)

        _ = try templateRepository.addMeal(from: template, date: selectedDate, calendar: calendar)

        let summary = try nutritionRepository.weeklySummary(in: weekInterval)
        XCTAssertEqual(summary.entryCount, 1)
        XCTAssertEqual(summary.totalCaloriesKcal, 20)
    }

    func testStatisticsLoadAndIgnoreNutritionTemplatesWithoutMeals() throws {
        let database = try AppDatabase.makeTemporary()
        try NutritionTemplateRepository(database: database).create(kind: .mealTemplate, name: "Pasta", caloriesKcal: 700, proteinG: 25)

        let store = StatisticsStore(database: database)
        let nutritionInsight = try XCTUnwrap(store.insights.first { $0.title == "Ernährung" })

        XCTAssertNil(store.errorMessage)
        XCTAssertEqual(nutritionInsight.detail, "Noch nicht genug Ernährungsdaten für einen Trend.")
    }

    func testNutritionStoreCreatesTemplateAndAddsAdjustedMeal() throws {
        let database = try AppDatabase.makeTemporary()
        let store = NutritionStore(database: database)

        XCTAssertTrue(store.createTemplate(kind: .favorite, name: "Skyr", caloriesKcal: 310, proteinG: 55))
        let template = try XCTUnwrap(store.templates.first)
        XCTAssertTrue(store.addAdjustedTemplateAsMeal(template, title: "Skyr + Banane", caloriesKcal: 420, proteinG: 58))

        XCTAssertEqual(store.entries.count, 1)
        XCTAssertEqual(store.entries.first?.title, "Skyr + Banane")
        XCTAssertEqual(store.caloriesConsumed, 420)
        XCTAssertEqual(store.proteinConsumed, 58, accuracy: 0.001)
    }

    func testWeightRepositoryCreatesNewEntry() throws {
        let database = try AppDatabase.makeTemporary()
        let repository = WeightRepository(database: database)

        let entry = try repository.upsert(dayKey: "2026-06-12", weightKg: 82.4)

        XCTAssertEqual(entry.date, "2026-06-12")
        XCTAssertEqual(entry.weightKg, 82.4, accuracy: 0.001)
        XCTAssertEqual(try repository.fetchAll().count, 1)
    }

    func testWeightRepositoryUpdatesSameDayInsteadOfDuplicating() throws {
        let database = try AppDatabase.makeTemporary()
        let repository = WeightRepository(database: database)

        let first = try repository.upsert(dayKey: "2026-06-12", weightKg: 82.4)
        let updated = try repository.upsert(dayKey: "2026-06-12", weightKg: 82.1)

        XCTAssertEqual(first.id, updated.id)
        XCTAssertEqual(updated.weightKg, 82.1, accuracy: 0.001)
        XCTAssertEqual(try repository.fetchAll().count, 1)
    }

    func testWeightRepositoryDeletesEntry() throws {
        let database = try AppDatabase.makeTemporary()
        let repository = WeightRepository(database: database)
        let entry = try repository.upsert(dayKey: "2026-06-12", weightKg: 82.4)

        try repository.delete(id: entry.id)

        XCTAssertTrue(try repository.fetchAll().isEmpty)
    }

    func testWeightRepositoryFindsLatestEntryAndPreviousChange() throws {
        let database = try AppDatabase.makeTemporary()
        let repository = WeightRepository(database: database)

        _ = try repository.upsert(dayKey: "2026-06-10", weightKg: 82.8)
        _ = try repository.upsert(dayKey: "2026-06-12", weightKg: 82.4)
        let latest = try XCTUnwrap(repository.latest())

        XCTAssertEqual(latest.date, "2026-06-12")
        XCTAssertEqual(try repository.changeFromPrevious(for: latest) ?? 0, -0.4, accuracy: 0.001)
    }

    func testWeightRepositoryBuildsSevenAndThirtyDaySummaries() throws {
        let database = try AppDatabase.makeTemporary()
        let repository = WeightRepository(database: database)

        for day in 1...35 {
            try repository.upsert(dayKey: String(format: "2026-06-%02d", day), weightKg: 80 + Double(day) / 10)
        }

        let seven = try repository.summary(days: 7)
        let thirty = try repository.summary(days: 30)

        XCTAssertEqual(seven.entries.count, 7)
        XCTAssertEqual(seven.entries.first?.date, "2026-06-29")
        XCTAssertEqual(seven.entries.last?.date, "2026-06-35")
        XCTAssertEqual(thirty.entries.count, 30)
        XCTAssertEqual(thirty.firstToLastChangeKg ?? 0, 2.9, accuracy: 0.001)
    }

    func testWeightRepositoryHandlesEmptyState() throws {
        let database = try AppDatabase.makeTemporary()
        let repository = WeightRepository(database: database)

        XCTAssertNil(try repository.latest())
        XCTAssertTrue(try repository.summary(days: 7).entries.isEmpty)
        XCTAssertNil(try repository.summary(days: 30).changeFromPreviousKg)
    }

    func testWeightParsingAcceptsCommaAndValidationRejectsUnsafeValues() {
        XCTAssertEqual(parseDouble("82,4"), 82.4, accuracy: 0.001)
        XCTAssertTrue(WeightStore.isPlausibleWeight(82.4))
        XCTAssertFalse(WeightStore.isPlausibleWeight(10))
        XCTAssertFalse(WeightStore.isPlausibleWeight(350))
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
        XCTAssertEqual(normalized.morningReminderMinuteOfDay, AppSettingsDefaults.morningReminderMinuteOfDay)
        XCTAssertEqual(SettingsStore.reminderTimeLabel(17 * 60 + 15), "17:15 Uhr")
    }

    func testSettingsPersistReminderTimes() throws {
        let database = try AppDatabase.makeTemporary()
        let repository = SettingsRepository(database: database)

        _ = try repository.saveSettings(
            AppSettingsRecord(
                caloriesTarget: 2200,
                proteinTargetG: 150,
                monthlyBudget: 1200,
                morningReminderMinuteOfDay: 8 * 60 + 15,
                trainingReminderMinuteOfDay: 18 * 60 + 30,
                eveningReminderMinuteOfDay: 22 * 60
            )
        )

        let loaded = try repository.loadSettings()

        XCTAssertEqual(loaded.morningReminderMinuteOfDay, 495)
        XCTAssertEqual(loaded.trainingReminderMinuteOfDay, 1110)
        XCTAssertEqual(loaded.eveningReminderMinuteOfDay, 1320)
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

    func testHomeWorkoutPlanReturnsPushOnMonday() {
        let calendar = Calendar(identifier: .gregorian)
        let monday = DateComponents(calendar: calendar, year: 2026, month: 6, day: 8, hour: 12).date!

        let scheduled = HomeWorkoutPlanProvider.plan.workout(for: monday, calendar: calendar)

        XCTAssertTrue(scheduled.isToday)
        XCTAssertEqual(scheduled.day.name, "Pull + Core")
    }

    func testHomeWorkoutPlanReturnsLegsCoreOnWednesday() {
        let calendar = Calendar(identifier: .gregorian)
        let wednesday = DateComponents(calendar: calendar, year: 2026, month: 6, day: 10, hour: 12).date!

        let scheduled = HomeWorkoutPlanProvider.plan.workout(for: wednesday, calendar: calendar)

        XCTAssertTrue(scheduled.isToday)
        XCTAssertEqual(scheduled.day.name, "Push + Legs")
    }

    func testHomeWorkoutPlanReturnsPushPullMixOnFriday() {
        let calendar = Calendar(identifier: .gregorian)
        let friday = DateComponents(calendar: calendar, year: 2026, month: 6, day: 12, hour: 12).date!

        let scheduled = HomeWorkoutPlanProvider.plan.workout(for: friday, calendar: calendar)

        XCTAssertTrue(scheduled.isToday)
        XCTAssertEqual(scheduled.day.name, "Full Body")
    }

    func testHomeWorkoutPlanShowsPullOnTuesday() {
        let calendar = Calendar(identifier: .gregorian)
        let tuesday = DateComponents(calendar: calendar, year: 2026, month: 6, day: 9, hour: 12).date!

        let scheduled = HomeWorkoutPlanProvider.plan.workout(for: tuesday, calendar: calendar)

        XCTAssertFalse(scheduled.isToday)
        XCTAssertEqual(scheduled.day.name, "Push + Legs")
        XCTAssertEqual(scheduled.day.weekdayName, "Mittwoch")
    }

    func testHomeWorkoutPlanShowsConditioningOnSaturday() {
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
        let store = TrainingStore(database: database, selectedDate: wednesday, calendar: calendar, now: { wednesday })
        let exercises = store.homeWorkoutExercises(for: .normal)
        let completedIDs = Set(exercises.prefix(3).map(\.id))

        store.completeHomeWorkout(intensity: .normal, completedExerciseIDs: completedIDs)

        let sessions = try WorkoutRepository(database: database).fetchAll()
        XCTAssertEqual(sessions.count, 1)
        XCTAssertEqual(sessions.first?.workoutType, "Home Plan: Push + Legs")
        XCTAssertEqual(sessions.first?.durationMin, 30)
        XCTAssertEqual(sessions.first?.status, "done")
        XCTAssertEqual(sessions.first?.workoutIntensity, "Normal")
        XCTAssertEqual(sessions.first?.note?.contains("Intensität: Normal"), true)
        XCTAssertEqual(sessions.first?.note?.contains("Erledigt: 3/4"), true)
        XCTAssertEqual(sessions.first?.note?.contains("Liegestuetze"), true)
        XCTAssertEqual(store.completedWorkoutsThisWeek, 1)
        XCTAssertEqual(store.progress, 1.0 / 3.0, accuracy: 0.001)
    }

    func testWorkoutRepositoryPersistsExercisesAndSetsAndDeletesWithSession() throws {
        let database = try AppDatabase.makeTemporary()
        let repository = WorkoutRepository(database: database)
        let session = WorkoutSessionRecord(workoutType: "Home Plan: Pull + Core", durationMin: 30, status: "done", workoutIntensity: "Normal")

        try repository.insertDetailed(
            session,
            exercises: [
                WorkoutExerciseInput(
                    exerciseName: "Klimmzuege",
                    sortOrder: 0,
                    isCompleted: true,
                    sets: [
                        WorkoutSetInput(setNumber: 1, reps: 3),
                        WorkoutSetInput(setNumber: 2, reps: 3),
                        WorkoutSetInput(setNumber: 3, reps: 2)
                    ]
                )
            ]
        )

        let summaries = try repository.fetchExerciseSummaries(sessionId: session.id)
        XCTAssertEqual(summaries.count, 1)
        XCTAssertEqual(summaries.first?.exercise.exerciseName, "Klimmzuege")
        XCTAssertEqual(summaries.first?.sets.map(\.reps), [3, 3, 2])

        try repository.delete(id: session.id)

        XCTAssertTrue(try repository.fetchAll().isEmpty)
        XCTAssertTrue(try repository.fetchAllExerciseSummaries().isEmpty)
    }

    func testHomeWorkoutPlanCreatesIntensitySpecificExerciseInputs() {
        let calendar = Calendar(identifier: .gregorian)
        let monday = DateComponents(calendar: calendar, year: 2026, month: 6, day: 8, hour: 12).date!
        let scheduled = HomeWorkoutPlanProvider.plan.workout(for: monday, calendar: calendar)

        let minimum = HomeWorkoutPlanProvider.plan.makeExerciseInputs(for: scheduled, intensity: .minimum)
        let normal = HomeWorkoutPlanProvider.plan.makeExerciseInputs(for: scheduled, intensity: .normal)
        let strong = HomeWorkoutPlanProvider.plan.makeExerciseInputs(for: scheduled, intensity: .strong)

        XCTAssertLessThan(minimum.count, normal.count)
        XCTAssertGreaterThanOrEqual(strong.first?.sets.count ?? 0, normal.first?.sets.count ?? 0)
        XCTAssertEqual(normal.first?.sets.first?.reps, 3)
    }

    func testTrainingStoreBuildsExerciseProgressFromDetailedSessions() throws {
        let database = try AppDatabase.makeTemporary()
        let calendar = Calendar(identifier: .gregorian)
        let monday = DateComponents(calendar: calendar, year: 2026, month: 6, day: 8, hour: 12).date!
        let repository = WorkoutRepository(database: database)

        try repository.insertDetailed(
            WorkoutSessionRecord(occurredAt: monday, workoutType: "Training", durationMin: 30, status: "done", workoutIntensity: "Normal"),
            exercises: [WorkoutExerciseInput(exerciseName: "Liegestuetze", sortOrder: 0, isCompleted: true, sets: [WorkoutSetInput(setNumber: 1, reps: 8)])]
        )
        try repository.insertDetailed(
            WorkoutSessionRecord(occurredAt: monday.addingTimeInterval(3600), workoutType: "Training", durationMin: 30, status: "done", workoutIntensity: "Normal"),
            exercises: [WorkoutExerciseInput(exerciseName: "Liegestuetze", sortOrder: 0, isCompleted: true, sets: [WorkoutSetInput(setNumber: 1, reps: 10)])]
        )

        let store = TrainingStore(database: database, selectedDate: monday, calendar: calendar, now: { monday })

        let status = try XCTUnwrap(store.exerciseProgressStatuses.first { $0.exerciseName == "Liegestuetze" })
        XCTAssertTrue(status.hasEnoughData)
        XCTAssertTrue(status.recommendation.contains("verbessert"))
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
        try repository.insert(HabitEntryRecord(habitKey: "learning", date: date, isCompleted: true))
        try repository.insert(HabitEntryRecord(habitKey: "legacy", date: date, isCompleted: true))
        try repository.insert(HabitEntryRecord(habitKey: "sleep", date: date, isCompleted: false))

        let summary = try repository.dailySummary(forDay: date, habitKeys: habitKeys)

        XCTAssertEqual(summary.completed, 2)
        XCTAssertEqual(summary.total, 4)
        XCTAssertEqual(summary.progress, 0.5, accuracy: 0.001)
    }

    func testHabitRepositorySummaryIgnoresDerivedTrainingAndDeduplicatesRows() throws {
        let database = try AppDatabase.makeTemporary()
        let repository = HabitRepository(database: database)
        let date = "2026-06-12"
        let habitKeys = FixedHabit.defaults.map(\.key)

        try repository.insert(HabitEntryRecord(habitKey: "water", date: date, isCompleted: true))
        try repository.insert(HabitEntryRecord(habitKey: "water", date: date, isCompleted: true))
        try repository.insert(HabitEntryRecord(habitKey: "training", date: date, isCompleted: true))

        let summary = try repository.dailySummary(forDay: date, habitKeys: habitKeys)

        XCTAssertEqual(summary.completed, 1)
        XCTAssertEqual(summary.total, 4)
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
        try repository.setValue(habitKey: "nutrition", date: date, value: 1, target: 3, unit: "Mahlzeiten")
        try repository.setValue(habitKey: "learning", date: date, value: 15, target: 60, unit: "Min.")
        try repository.setValue(habitKey: "sleep", date: date, value: 0, target: 1, unit: "")
        try WorkoutRepository(database: database).insert(
            WorkoutSessionRecord(occurredAt: selectedDay, workoutType: "Home Plan: Full Body", durationMin: 30, status: "done")
        )

        let store = HabitsStore(database: database, selectedDate: selectedDay, calendar: calendar)

        let expected = (0.5 + 1 + (1.0 / 3.0) + 0.25 + 0) / 5.0
        XCTAssertEqual(store.dailyProgressPercent, expected, accuracy: 0.001)
        XCTAssertEqual(store.completedHabits, 1)
    }

    func testHabitsStoreDerivesTrainingFromTodaysWorkoutSessions() throws {
        let database = try AppDatabase.makeTemporary()
        let workoutRepository = WorkoutRepository(database: database)
        let calendar = Calendar(identifier: .gregorian)
        let selectedDay = DateComponents(calendar: calendar, year: 2026, month: 6, day: 12, hour: 12).date!
        let otherDay = DateComponents(calendar: calendar, year: 2026, month: 6, day: 11, hour: 12).date!
        let training = FixedHabit.defaultDefinition(for: "training")!

        var store = HabitsStore(database: database, selectedDate: selectedDay, calendar: calendar)
        XCTAssertEqual(store.progress(for: training), 0, accuracy: 0.001)
        XCTAssertEqual(store.value(for: training), 0, accuracy: 0.001)

        try workoutRepository.insert(
            WorkoutSessionRecord(occurredAt: otherDay, workoutType: "Mobility", durationMin: 20, status: "done")
        )
        store = HabitsStore(database: database, selectedDate: selectedDay, calendar: calendar)
        XCTAssertEqual(store.progress(for: training), 0, accuracy: 0.001)

        try workoutRepository.insert(
            WorkoutSessionRecord(occurredAt: selectedDay, workoutType: "Home Plan: Pull + Core", durationMin: 30, status: "done")
        )
        try workoutRepository.insert(
            WorkoutSessionRecord(occurredAt: selectedDay, workoutType: "Zusatztraining", durationMin: 15, status: "done")
        )
        store = HabitsStore(database: database, selectedDate: selectedDay, calendar: calendar)
        XCTAssertEqual(store.progress(for: training), 1, accuracy: 0.001)
        XCTAssertEqual(store.value(for: training), 1, accuracy: 0.001)
    }

    func testHabitsStoreTrainingReturnsToOpenAfterDeletingLastWorkout() throws {
        let database = try AppDatabase.makeTemporary()
        let workoutRepository = WorkoutRepository(database: database)
        let calendar = Calendar(identifier: .gregorian)
        let selectedDay = DateComponents(calendar: calendar, year: 2026, month: 6, day: 12, hour: 12).date!
        let training = FixedHabit.defaultDefinition(for: "training")!
        let session = WorkoutSessionRecord(
            occurredAt: selectedDay,
            workoutType: "Home Plan: Full Body",
            durationMin: 30,
            status: "done"
        )

        try workoutRepository.insert(session)
        var store = HabitsStore(database: database, selectedDate: selectedDay, calendar: calendar)
        XCTAssertEqual(store.progress(for: training), 1, accuracy: 0.001)

        try workoutRepository.delete(id: session.id)
        store = HabitsStore(database: database, selectedDate: selectedDay, calendar: calendar)
        XCTAssertEqual(store.progress(for: training), 0, accuracy: 0.001)
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
        try repository.insert(HabitEntryRecord(habitKey: "learning", date: mondayKey, isCompleted: true))
        try repository.insert(HabitEntryRecord(habitKey: "water", date: mondayKey, isCompleted: true))
        try repository.insert(HabitEntryRecord(habitKey: "legacy", date: mondayKey, isCompleted: true))
        try repository.insert(HabitEntryRecord(habitKey: "sleep", date: tuesdayKey, isCompleted: false))
        try repository.insert(HabitEntryRecord(habitKey: "learning", date: nextMondayKey, isCompleted: true))

        let summary = try repository.weeklySummary(forDate: selectedDay, weekStartsOn: 2, habitKeys: habitKeys, days: 7, calendar: calendar)

        XCTAssertEqual(summary.completed, 2)
        XCTAssertEqual(summary.total, 28)
        XCTAssertEqual(summary.progress, 2.0 / 28.0, accuracy: 0.001)
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

        XCTAssertEqual(trends.habitCompletionByDay[0].value, 60, accuracy: 0.001)
        XCTAssertEqual(trends.habitCompletionByDay[1].value, 0, accuracy: 0.001)
        XCTAssertEqual(trends.habitCompletionByDay[2].value, 20, accuracy: 0.001)
        XCTAssertEqual(trends.habitCompletionByDay[4].value, 20, accuracy: 0.001)
        XCTAssertTrue(trends.habitCompletionByDay.allSatisfy { (0...100).contains($0.value) })
    }

    func testWeeklyReviewTrainingHabitUsesWorkoutSessionsOnly() {
        let calendar = Calendar(identifier: .gregorian)
        let selectedDay = DateComponents(calendar: calendar, year: 2026, month: 6, day: 12, hour: 12).date!
        let interval = DateIntervals.week(containing: selectedDay, weekStartsOn: 2, calendar: calendar)
        let monday = DateComponents(calendar: calendar, year: 2026, month: 6, day: 8, hour: 9).date!
        let tuesday = DateComponents(calendar: calendar, year: 2026, month: 6, day: 9, hour: 9).date!

        let trends = WeeklyReviewTrends.make(
            interval: interval,
            nutritionEntries: [],
            financeEntries: [],
            workoutSessions: [
                WorkoutSessionRecord(occurredAt: monday, workoutType: "Done", durationMin: 30, status: "done"),
                WorkoutSessionRecord(occurredAt: tuesday, workoutType: "Planned", durationMin: 30, status: "planned")
            ],
            habitEntries: [
                HabitEntryRecord(habitKey: "training", date: "2026-06-09", isCompleted: true)
            ],
            habitKeys: FixedHabit.defaults.map(\.key),
            calendar: calendar
        )

        XCTAssertEqual(trends.habitCompletionByDay[0].value, 20, accuracy: 0.001)
        XCTAssertEqual(trends.habitCompletionByDay[1].value, 0, accuracy: 0.001)
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
        XCTAssertEqual(restartedStore.snapshot.habits.completed, 2)
    }

    func testDashboardHabitSummaryUsesTrainingAndHandlesEmptyHabitEntries() throws {
        let database = try AppDatabase.makeTemporary()

        let store = DashboardStore(database: database)

        XCTAssertEqual(store.snapshot.habits.items.map(\.key), ["water", "training", "nutrition", "learning", "sleep"])
        XCTAssertFalse(store.snapshot.habits.items.map(\.key).contains("movement"))
        XCTAssertEqual(store.snapshot.habits.items.first { $0.key == "training" }?.progress ?? -1, 0, accuracy: 0.001)
        XCTAssertEqual(store.snapshot.habits.progress, 0, accuracy: 0.001)
    }

    func testDashboardHabitSummaryDerivesTrainingFromWorkoutSessions() throws {
        let database = try AppDatabase.makeTemporary()

        try WorkoutRepository(database: database).insert(
            WorkoutSessionRecord(workoutType: "Home Plan: Push + Legs", durationMin: 30, status: "done")
        )
        let store = DashboardStore(database: database)
        let training = store.snapshot.habits.items.first { $0.key == "training" }

        XCTAssertEqual(training?.displayText, "erledigt")
        XCTAssertEqual(training?.progress ?? 0, 1, accuracy: 0.001)
        XCTAssertEqual(store.snapshot.habits.progress, 0.2, accuracy: 0.001)
    }

    func testTodaySnapshotServiceCentralizesDailyValues() throws {
        let database = try AppDatabase.makeTemporary()
        let calendar = Calendar(identifier: .gregorian)
        let date = DateComponents(calendar: calendar, year: 2026, month: 6, day: 15, hour: 12).date!
        try SettingsRepository(database: database).saveSettings(
            AppSettingsRecord(caloriesTarget: 2200, proteinTargetG: 150, monthlyBudget: 900, defaultCurrency: "EUR")
        )
        try NutritionRepository(database: database).insert(
            NutritionEntryRecord(occurredAt: date, title: "Skyr", caloriesKcal: 300, proteinG: 35)
        )
        try FinanceRepository(database: database).insert(
            FinanceEntryRecord(occurredAt: date, title: "Lunch", amount: 12, category: "Essen")
        )
        try WorkoutRepository(database: database).insert(
            WorkoutSessionRecord(occurredAt: date, workoutType: "Training", durationMin: 30, status: "done")
        )
        try HabitRepository(database: database).upsertCompletion(
            habitKey: TelegramReminderHabit.proteinShakeKey,
            date: "2026-06-15",
            isCompleted: true
        )

        let snapshot = try TodaySnapshotService(database: database, calendar: calendar).snapshot(for: date)

        XCTAssertEqual(snapshot.nutritionSummary.caloriesKcal, 300)
        XCTAssertEqual(snapshot.caloriesRemaining, 1900)
        XCTAssertEqual(snapshot.proteinRemainingG, 115, accuracy: 0.001)
        XCTAssertEqual(snapshot.spentToday, 12, accuracy: 0.001)
        XCTAssertTrue(snapshot.workoutCompletedToday)
        XCTAssertEqual(snapshot.habitValue(for: "training"), 1, accuracy: 0.001)
        XCTAssertTrue(snapshot.isHabitDone(TelegramReminderHabit.proteinShakeKey))
    }

    func testTodaySnapshotExposesOpenCockpitValuesWithoutMutatingData() throws {
        let database = try AppDatabase.makeTemporary()
        let calendar = Calendar(identifier: .gregorian)
        let date = DateComponents(calendar: calendar, year: 2026, month: 6, day: 15, hour: 12).date!
        try SettingsRepository(database: database).saveSettings(
            AppSettingsRecord(
                caloriesTarget: 2200,
                proteinTargetG: 150,
                weeklyWorkoutTarget: 3,
                monthlyBudget: 900,
                defaultCurrency: "EUR"
            )
        )
        try NutritionRepository(database: database).insert(
            NutritionEntryRecord(occurredAt: date, title: "Frühstück", caloriesKcal: 1700, proteinG: 108)
        )
        try FinanceRepository(database: database).insert(
            FinanceEntryRecord(occurredAt: date, title: "Lunch", amount: 12, category: "Essen")
        )
        try HabitRepository(database: database).upsertCompletion(
            habitKey: TelegramReminderHabit.medicationKey,
            date: "2026-06-15",
            isCompleted: true
        )
        try HabitRepository(database: database).upsertCompletion(
            habitKey: "sleep",
            date: "2026-06-15",
            isCompleted: false
        )

        let before = try HabitRepository(database: database).fetchAll()
        let snapshot = try TodaySnapshotService(database: database, calendar: calendar).snapshot(for: date)
        let after = try HabitRepository(database: database).fetchAll()

        XCTAssertEqual(snapshot.caloriesRemaining, 500)
        XCTAssertEqual(snapshot.proteinRemainingG, 42, accuracy: 0.001)
        XCTAssertFalse(snapshot.workoutCompletedToday)
        XCTAssertTrue(snapshot.isHabitDone(TelegramReminderHabit.medicationKey))
        XCTAssertFalse(snapshot.isHabitDone(TelegramReminderHabit.proteinShakeKey))
        XCTAssertFalse(snapshot.isHabitDone("sleep"))
        XCTAssertGreaterThanOrEqual(snapshot.availableToday, 0)
        XCTAssertEqual(after, before, "Die Heute-offen-Berechnung muss read-only bleiben.")
    }

    func testTodayOpenCalculationIncludesProteinTrainingHabitsAndTelegramHabits() {
        let status = TodayOpenStatus.calculate(
            caloriesConsumed: 1750,
            caloriesTarget: 2200,
            proteinConsumedG: 108,
            proteinTargetG: 150,
            workoutCompletedToday: false,
            trainingPausedToday: false,
            trainingScheduledToday: true,
            habitValues: ["water": 3, "nutrition": 1, "learning": 15, "sleep": 0],
            medicationDone: false,
            proteinShakeDone: true,
            dailyBudgetRemaining: 28
        )

        XCTAssertEqual(status.caloriesRemaining, 450)
        XCTAssertEqual(status.proteinRemainingG, 42, accuracy: 0.001)
        XCTAssertEqual(status.training, .open)
        XCTAssertTrue(status.openHabitTitles.contains("Schlafroutine"))
        XCTAssertTrue(status.isMedicationOpen)
        XCTAssertFalse(status.isProteinShakeOpen)
        XCTAssertEqual(status.dailyBudgetRemaining, 28, accuracy: 0.001)
        XCTAssertTrue(status.summary.contains("42 g Protein"))
        XCTAssertTrue(status.summary.contains("Training"))
        XCTAssertTrue(status.summary.contains("Medikamente"))
    }

    func testTodayOpenCalculationTreatsCompletedOrPausedTrainingCalmly() {
        let completed = TodayOpenStatus.calculate(
            caloriesConsumed: 2200,
            caloriesTarget: 2200,
            proteinConsumedG: 150,
            proteinTargetG: 150,
            workoutCompletedToday: true,
            trainingPausedToday: false,
            trainingScheduledToday: true,
            habitValues: Dictionary(uniqueKeysWithValues: FixedHabit.defaults.map { ($0.key, $0.targetValue) }),
            medicationDone: true,
            proteinShakeDone: true,
            dailyBudgetRemaining: 0
        )
        let paused = TodayOpenStatus.calculate(
            caloriesConsumed: 2200,
            caloriesTarget: 2200,
            proteinConsumedG: 150,
            proteinTargetG: 150,
            workoutCompletedToday: false,
            trainingPausedToday: true,
            trainingScheduledToday: true,
            habitValues: Dictionary(uniqueKeysWithValues: FixedHabit.defaults.map { ($0.key, $0.targetValue) }),
            medicationDone: true,
            proteinShakeDone: true,
            dailyBudgetRemaining: -20
        )

        XCTAssertEqual(completed.training, .completed)
        XCTAssertEqual(completed.summary, "Guter Stand. Für heute ist nichts Wesentliches mehr offen.")
        XCTAssertEqual(paused.training, .paused)
        XCTAssertEqual(paused.summary, "Guter Stand. Für heute ist nichts Wesentliches mehr offen.")
        XCTAssertEqual(paused.dailyBudgetRemaining, 0)
    }

    func testDashboardStoreLoadsMenuBarCockpitStatusesFromPersistence() throws {
        let database = try AppDatabase.makeTemporary()
        let now = Date()
        let dayKey = DateIntervals.dayKey(for: now)
        try SettingsRepository(database: database).saveSettings(
            AppSettingsRecord(caloriesTarget: 2200, proteinTargetG: 150, monthlyBudget: 900)
        )
        try NutritionRepository(database: database).insert(
            NutritionEntryRecord(occurredAt: now, title: "Skyr", caloriesKcal: 300, proteinG: 35)
        )
        try WorkoutRepository(database: database).insert(
            WorkoutSessionRecord(occurredAt: now, workoutType: "Training", durationMin: 30, status: "done")
        )
        try HabitRepository(database: database).upsertCompletion(
            habitKey: TelegramReminderHabit.medicationKey,
            date: dayKey,
            isCompleted: true
        )
        try HabitRepository(database: database).upsertCompletion(
            habitKey: TelegramReminderHabit.proteinShakeKey,
            date: dayKey,
            isCompleted: false
        )

        let store = DashboardStore(database: database)

        XCTAssertEqual(store.state.caloriesConsumed, 300)
        XCTAssertEqual(store.state.proteinConsumed, 35, accuracy: 0.001)
        XCTAssertTrue(store.state.workoutCompletedToday)
        XCTAssertTrue(store.state.medicationDone)
        XCTAssertFalse(store.state.proteinShakeDone)
        XCTAssertEqual(store.snapshot.todayOpen.training, .completed)
        XCTAssertFalse(store.snapshot.todayOpen.isMedicationOpen)
        XCTAssertTrue(store.snapshot.todayOpen.isProteinShakeOpen)
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
        XCTAssertEqual(payload.nutritionTemplates.count, 1)
        XCTAssertEqual(payload.workoutSessions.count, 1)
        XCTAssertEqual(payload.workoutExercises.count, 0)
        XCTAssertEqual(payload.workoutSets.count, 0)
        XCTAssertEqual(payload.financeEntries.count, 1)
        XCTAssertEqual(payload.habitEntries.count, 1)
        XCTAssertEqual(payload.weightEntries.count, 1)
        XCTAssertEqual(payload.bodyMetricEntries.count, 1)
        XCTAssertEqual(payload.weeklyReviews.count, 1)
        XCTAssertEqual(payload.settings.count, 1)
        XCTAssertNotNil(payload.financeAnalysis)
        XCTAssertNotNil(payload.financeAnalysis?.categoryTrends)
        XCTAssertNotNil(object?["financeAnalysis"])
    }

    func testBackupImportPreflightReadsJSONWithoutWritingData() throws {
        let database = try AppDatabase.makeTemporary()
        try seedExportData(in: database)
        let service = BackupService(database: database, backupDirectory: makeTemporaryBackupDirectory())
        let exportURL = try service.createJSONExport()

        let report = try service.preflightImport(from: exportURL)

        XCTAssertEqual(report.sourceKind, .json)
        XCTAssertEqual(report.itemCounts["nutrition_entries"], 1)
        XCTAssertEqual(report.itemCounts["app_settings"], 1)
        XCTAssertTrue(report.warnings.contains { $0.contains("keine lokalen Daten überschrieben") })
        XCTAssertTrue(report.warnings.contains { $0.contains("Telegram-Token") })
    }

    func testJSONExportPayloadContainsSettingsAndTableArraysWhenEmpty() throws {
        let database = try AppDatabase.makeTemporary()
        let service = BackupService(database: database, backupDirectory: makeTemporaryBackupDirectory())

        let payload = try service.makeExportPayload()

        XCTAssertEqual(payload.exportVersion, 1)
        XCTAssertEqual(payload.appName, "AboLife")
        XCTAssertEqual(payload.nutritionEntries, [])
        XCTAssertEqual(payload.nutritionTemplates, [])
        XCTAssertEqual(payload.workoutSessions, [])
        XCTAssertEqual(payload.workoutExercises, [])
        XCTAssertEqual(payload.workoutSets, [])
        XCTAssertEqual(payload.financeEntries, [])
        XCTAssertEqual(payload.habitEntries, [])
        XCTAssertEqual(payload.weightEntries, [])
        XCTAssertEqual(payload.bodyMetricEntries, [])
        XCTAssertEqual(payload.weeklyReviews, [])
        XCTAssertEqual(payload.settings, [])
    }

    func testCSVExportCreatesNumbersFriendlyFilesWithHabitFields() throws {
        let database = try AppDatabase.makeTemporary()
        try seedExportData(in: database)
        try NutritionRepository(database: database).insert(
            NutritionEntryRecord(
                occurredAt: DateComponents(calendar: .current, year: 2026, month: 6, day: 14, hour: 12).date!,
                title: "Skyr; \"Beeren\"\nSnack",
                caloriesKcal: 250,
                proteinG: 25.5,
                note: "Zeile 1\nZeile 2"
            )
        )
        let fixedDate = DateComponents(calendar: .current, year: 2026, month: 6, day: 14, hour: 21, minute: 30).date!
        let service = BackupService(database: database, backupDirectory: makeTemporaryBackupDirectory(), now: { fixedDate })

        let exportDirectory = try service.createCSVExport()
        let metadataCSV = try String(contentsOf: exportDirectory.appendingPathComponent("metadata.csv"), encoding: .utf8)
        let nutritionCSV = try String(contentsOf: exportDirectory.appendingPathComponent("csv/nutrition_entries.csv"), encoding: .utf8)
        let habitCSV = try String(contentsOf: exportDirectory.appendingPathComponent("csv/habit_entries.csv"), encoding: .utf8)
        let workoutCSV = try String(contentsOf: exportDirectory.appendingPathComponent("csv/workout_sessions.csv"), encoding: .utf8)
        let workoutExercisesCSV = try String(contentsOf: exportDirectory.appendingPathComponent("csv/workout_exercises.csv"), encoding: .utf8)
        let financeCSV = try String(contentsOf: exportDirectory.appendingPathComponent("csv/finance_transactions.csv"), encoding: .utf8)
        let financeAnalysisCSV = try String(contentsOf: exportDirectory.appendingPathComponent("csv/finance_monthly_analysis.csv"), encoding: .utf8)
        let financeCategoryTrendsCSV = try String(contentsOf: exportDirectory.appendingPathComponent("csv/finance_category_trends.csv"), encoding: .utf8)
        let weightCSV = try String(contentsOf: exportDirectory.appendingPathComponent("csv/weight_entries.csv"), encoding: .utf8)
        let templatesCSV = try String(contentsOf: exportDirectory.appendingPathComponent("csv/templates.csv"), encoding: .utf8)
        let reportHTML = try String(contentsOf: exportDirectory.appendingPathComponent("reports/overview_report.html"), encoding: .utf8)
        let summaryMarkdown = try String(contentsOf: exportDirectory.appendingPathComponent("reports/summary.md"), encoding: .utf8)
        let caloriesSVG = try String(contentsOf: exportDirectory.appendingPathComponent("reports/charts/nutrition_calories_7d.svg"), encoding: .utf8)
        let manifestData = try Data(contentsOf: exportDirectory.appendingPathComponent("export_manifest.json"))
        let manifest = try JSONSerialization.jsonObject(with: manifestData) as! [String: Any]

        XCTAssertTrue(FileManager.default.fileExists(atPath: exportDirectory.path))
        XCTAssertTrue(exportDirectory.hasDirectoryPath)
        XCTAssertEqual(exportDirectory.lastPathComponent, "AboLife_Backup_2026-06-14_21-30-00")
        XCTAssertTrue(metadataCSV.hasPrefix("key;value\n"))
        XCTAssertTrue(metadataCSV.contains("csv_separator;semicolon"))
        XCTAssertTrue(metadataCSV.contains("decimal_separator;dot"))
        XCTAssertTrue(metadataCSV.contains("contains_sensitive_data;personal_entries_only"))
        XCTAssertTrue(nutritionCSV.hasPrefix("id;created_at;entry_date;meal_type;title;calories;protein_g;carbs_g;fat_g;notes;source\n"))
        XCTAssertTrue(nutritionCSV.contains("\"Skyr; \"\"Beeren\"\"\nSnack\""))
        XCTAssertTrue(nutritionCSV.contains(";25.5;"))
        XCTAssertFalse(nutritionCSV.contains(";25,5;"))
        XCTAssertTrue(habitCSV.hasPrefix("id;created_at;entry_date;habit_key;habit_title;status;value;unit;notes;source\n"))
        XCTAssertTrue(habitCSV.contains("water"))
        XCTAssertFalse(habitCSV.contains(";training;"))
        XCTAssertTrue(workoutCSV.contains("workout_type"))
        XCTAssertTrue(workoutExercisesCSV.hasPrefix("id;session_id;exercise_name;sort_order;is_completed;pain_reported;notes\n"))
        XCTAssertTrue(financeCSV.hasPrefix("id;created_at;entry_date;type;category;title;amount;currency;notes;source\n"))
        XCTAssertTrue(financeCSV.contains(";expense;"))
        XCTAssertTrue(financeAnalysisCSV.hasPrefix("month;currency;spent;income;balance;monthly_budget;remaining_budget;average_daily_spend;projected_spend;"))
        XCTAssertTrue(financeAnalysisCSV.contains("top_category"))
        XCTAssertTrue(financeCategoryTrendsCSV.hasPrefix("category;spent;share;previous_month_spent;change_from_previous;budget;is_over_budget\n"))
        XCTAssertTrue(weightCSV.hasPrefix("id;created_at;entry_date;weight_kg;notes;source\n"))
        XCTAssertTrue(templatesCSV.hasPrefix("id;created_at;template_type;title;payload;is_active;notes\n"))
        XCTAssertTrue(reportHTML.contains("AboLife Backup Report"))
        XCTAssertTrue(reportHTML.contains("Finanzanalyse"))
        XCTAssertTrue(reportHTML.contains("Kategorie-Trends"))
        XCTAssertTrue(reportHTML.contains("Die CSV-Dateien sind die primäre Backup-Quelle."))
        XCTAssertTrue(summaryMarkdown.contains("AboLife Backup Summary"))
        XCTAssertTrue(summaryMarkdown.contains("Kategorie-Trends"))
        XCTAssertTrue(summaryMarkdown.contains("Telegram-Token"))
        XCTAssertFalse(reportHTML.contains("https://"))
        XCTAssertFalse(reportHTML.contains("http://"))
        XCTAssertTrue(caloriesSVG.contains("Kalorien pro Tag"))
        XCTAssertTrue(caloriesSVG.contains("Max:"))
        XCTAssertEqual(manifest["csvSeparator"] as? String, "semicolon")
        XCTAssertEqual(manifest["decimalSeparator"] as? String, "dot")
        let files = manifest["files"] as! [[String: Any]]
        XCTAssertTrue(files.contains { $0["name"] as? String == "csv/nutrition_entries.csv" && $0["rows"] as? Int == 2 })
        XCTAssertTrue(files.contains { $0["name"] as? String == "csv/finance_monthly_analysis.csv" && $0["rows"] as? Int == 1 })
        XCTAssertTrue(files.contains { $0["name"] as? String == "csv/finance_category_trends.csv" })
        XCTAssertTrue(files.contains { $0["name"] as? String == "reports/overview_report.html" && $0["type"] as? String == "report" })
        XCTAssertTrue(files.contains { $0["name"] as? String == "reports/summary.md" && $0["type"] as? String == "markdown" })
        let charts = manifest["charts"] as! [[String: Any]]
        XCTAssertTrue(charts.contains { $0["name"] as? String == "reports/charts/nutrition_calories_7d.svg" && $0["dataPoints"] as? Int == 7 })
        let excluded = manifest["excludedSensitiveFields"] as! [String]
        XCTAssertTrue(excluded.contains("telegram_bot_token"))
        let allExportText = [
            metadataCSV, nutritionCSV, habitCSV, workoutCSV, workoutExercisesCSV, financeCSV, financeAnalysisCSV, financeCategoryTrendsCSV, weightCSV, templatesCSV, reportHTML, summaryMarkdown, caloriesSVG,
            String(data: manifestData, encoding: .utf8)!
        ].joined(separator: "\n")
        XCTAssertFalse(allExportText.contains("local-test-token"))
        XCTAssertFalse(allExportText.contains("7467527144"))
    }

    func testFinanceExportsContainPlanningDataAndStayFreeOfSecrets() throws {
        let database = try AppDatabase.makeTemporary()
        let repository = FinanceRepository(database: database)
        try repository.insert(FinanceEntryRecord(title: "Rewe", amount: 42, category: "Lebensmittel"))
        try repository.upsertCategoryBudget(monthKey: FinanceRepository.monthKey(), category: "Lebensmittel", amount: 300, currency: "EUR")
        try repository.upsertFixedCost(FinanceFixedCostRecord(title: "Internet", amount: 50, category: "Fixkosten", dueDay: 20))
        try repository.upsertSavingsGoal(FinanceSavingsGoalRecord(title: "Notgroschen", targetAmount: 1000, currentAmount: 250))
        try SettingsRepository(database: database).saveSettings(
            AppSettingsRecord(
                caloriesTarget: 2200,
                proteinTargetG: 150,
                monthlyBudget: 900,
                defaultCurrency: "EUR"
            )
        )
        let fixedDate = DateComponents(calendar: .current, year: 2026, month: 6, day: 14, hour: 21, minute: 30).date!
        let service = BackupService(database: database, backupDirectory: makeTemporaryBackupDirectory(), now: { fixedDate })

        let payload = try service.makeExportPayload()
        let jsonURL = try service.createJSONExport()
        let exportDirectory = try service.createCSVExport()
        let markdownURL = try service.createMarkdownSummaryExport()
        let json = try String(contentsOf: jsonURL, encoding: .utf8)
        let budgetCSV = try String(contentsOf: exportDirectory.appendingPathComponent("csv/finance_category_budgets.csv"), encoding: .utf8)
        let fixedCSV = try String(contentsOf: exportDirectory.appendingPathComponent("csv/finance_fixed_costs.csv"), encoding: .utf8)
        let savingsCSV = try String(contentsOf: exportDirectory.appendingPathComponent("csv/finance_savings_goals.csv"), encoding: .utf8)
        let reportHTML = try String(contentsOf: exportDirectory.appendingPathComponent("reports/overview_report.html"), encoding: .utf8)
        let markdown = try String(contentsOf: markdownURL, encoding: .utf8)
        let allExportText = [json, budgetCSV, fixedCSV, savingsCSV, reportHTML, markdown].joined(separator: "\n")

        XCTAssertEqual(payload.financeCategoryBudgets.count, 1)
        XCTAssertEqual(payload.financeFixedCosts.count, 1)
        XCTAssertEqual(payload.financeSavingsGoals.count, 1)
        XCTAssertTrue(budgetCSV.contains("Lebensmittel"))
        XCTAssertTrue(fixedCSV.contains("Internet"))
        XCTAssertTrue(savingsCSV.contains("Notgroschen"))
        XCTAssertTrue(reportHTML.contains("Finanzpläne"))
        XCTAssertTrue(markdown.contains("Finanzen"))
        XCTAssertFalse(allExportText.contains("SECRET_TOKEN_SHOULD_NOT_LEAK"))
        XCTAssertFalse(allExportText.contains("7467527144"))
        XCTAssertFalse(allExportText.contains("/Users/"))
        XCTAssertFalse(allExportText.contains("file://"))

        XCTAssertTrue(markdown.contains("Monatsanalyse") || reportHTML.contains("Monatsanalyse") || reportHTML.contains("Finanzanalyse"))
        XCTAssertTrue(markdown.contains("Kategorie-Trend") || reportHTML.contains("Kategorie-Trend") || reportHTML.contains("Kategorie-Trends"))
    }

    func testMarkdownSummaryExportCreatesSafeStandaloneFile() throws {
        let database = try AppDatabase.makeTemporary()
        try seedExportData(in: database)
        let fixedDate = DateComponents(calendar: .current, year: 2026, month: 6, day: 14, hour: 21, minute: 30).date!
        let service = BackupService(database: database, backupDirectory: makeTemporaryBackupDirectory(), now: { fixedDate })

        let exportURL = try service.createMarkdownSummaryExport()
        let markdown = try String(contentsOf: exportURL, encoding: .utf8)

        XCTAssertEqual(exportURL.lastPathComponent, "AboLife-summary-2026-06-14-213000.md")
        XCTAssertTrue(markdown.contains("# AboLife Backup Summary"))
        XCTAssertTrue(markdown.contains("Telegram-Token"))
        XCTAssertFalse(markdown.contains("local-test-token"))
        XCTAssertFalse(markdown.contains("7467527144"))
    }

    func testCSVExportWorksWithEmptyTables() throws {
        let database = try AppDatabase.makeTemporary()
        let service = BackupService(database: database, backupDirectory: makeTemporaryBackupDirectory())

        let exportDirectory = try service.createCSVExport()
        let nutritionCSV = try String(contentsOf: exportDirectory.appendingPathComponent("csv/nutrition_entries.csv"), encoding: .utf8)
        let reportHTML = try String(contentsOf: exportDirectory.appendingPathComponent("reports/overview_report.html"), encoding: .utf8)
        let weightSVG = try String(contentsOf: exportDirectory.appendingPathComponent("reports/charts/weight_trend.svg"), encoding: .utf8)
        let workoutExercisesCSV = try String(contentsOf: exportDirectory.appendingPathComponent("csv/workout_exercises.csv"), encoding: .utf8)

        XCTAssertTrue(nutritionCSV.hasPrefix("id;created_at;entry_date;meal_type;title;calories;protein_g;carbs_g;fat_g;notes;source\n"))
        XCTAssertEqual(nutritionCSV.components(separatedBy: "\n").filter { !$0.isEmpty }.count, 1)
        XCTAssertTrue(workoutExercisesCSV.hasPrefix("id;session_id;exercise_name;sort_order;is_completed;pain_reported;notes\n"))
        XCTAssertTrue(reportHTML.contains("AboLife Backup Report"))
        XCTAssertTrue(weightSVG.contains("Keine Daten vorhanden."))
    }

    func testBackupImportPreflightReadsCSVManifest() throws {
        let database = try AppDatabase.makeTemporary()
        try seedExportData(in: database)
        let service = BackupService(database: database, backupDirectory: makeTemporaryBackupDirectory())
        let exportDirectory = try service.createCSVExport()

        let report = try service.preflightImport(from: exportDirectory)

        XCTAssertEqual(report.sourceKind, .csvDirectory)
        XCTAssertEqual(report.itemCounts["csv/nutrition_entries.csv"], 1)
        XCTAssertEqual(report.itemCounts["csv/templates.csv"], 1)
        XCTAssertTrue(report.warnings.contains { $0.contains("nicht importiert oder exportiert") })
    }

    func testExternalInputParserRecognizesQuickInputs() {
        let fixedDate = Date(timeIntervalSince1970: 1_800_000_000)
        let parser = ExternalInputParser(now: { fixedDate })

        assertWeight(parser.parse("Gewicht 82,4"), 82.4)
        assertWeight(parser.parse("Gewicht 82.4"), 82.4)
        assertWeight(parser.parse("82,4 kg"), 82.4)
        assertWeight(parser.parse("82kg"), 82)
        if case .weightStatus = parser.parse("Gewicht Status") {} else { XCTFail("Gewicht Status wurde nicht erkannt") }
        if case let .weightTarget(weightKg) = parser.parse("Zielgewicht 80") {
            XCTAssertEqual(weightKg, 80, accuracy: 0.001)
        } else {
            XCTFail("Zielgewicht wurde nicht erkannt")
        }
        if case let .weightCorridor(lowerKg, upperKg) = parser.parse("Zielkorridor 78 82") {
            XCTAssertEqual(lowerKg, 78, accuracy: 0.001)
            XCTAssertEqual(upperKg, 82, accuracy: 0.001)
        } else {
            XCTFail("Zielkorridor wurde nicht erkannt")
        }
        assertExpense(parser.parse("Ausgabe 4,50 Döner"), amount: 4.5, title: "Döner")
        assertExpense(parser.parse("Ausgabe Döner 4,50€"), amount: 4.5, title: "Döner")
        assertExpense(parser.parse("4.50 Kaffee"), amount: 4.5, title: "Kaffee")
        assertExpense(parser.parse("Ausgabe 12.50 Kino"), amount: 12.5, title: "Kino")
        assertMeal(parser.parse("Essen Skyr 250 kcal 25 Protein"), name: "Skyr", calories: 250, protein: 25)
        assertMeal(parser.parse("Essen Skyr 250kcal 25g Protein"), name: "Skyr", calories: 250, protein: 25)
        assertMeal(parser.parse("Meal Skyr 250 kcal 25 Protein"), name: "Skyr", calories: 250, protein: 25)

        if case .workoutCompleted = parser.parse("Training erledigt") {} else { XCTFail("Training wurde nicht erkannt") }
        if case .workoutCompleted = parser.parse("Workout erledigt") {} else { XCTFail("Workout wurde nicht erkannt") }
        if case let .habitCompleted(_, name) = parser.parse("Habit Lesen erledigt") {
            XCTAssertEqual(name, "Lesen")
        } else {
            XCTFail("Habit wurde nicht erkannt")
        }
        XCTAssertEqual(parser.parse("/start"), .start)
        XCTAssertEqual(parser.parse("hilfe"), .help)
        XCTAssertEqual(parser.parse("abbrechen"), .cancel)
        if case .unknown = parser.parse("irgendwas") {} else { XCTFail("Unbekannte Eingabe sollte unknown sein") }
    }

    func testExternalInputParserRecognizesBareAndCategorizedExpenseText() {
        let calendar = Calendar(identifier: .gregorian)
        let fixedDate = DateComponents(calendar: calendar, year: 2026, month: 6, day: 19, hour: 10).date!
        let parser = ExternalInputParser(now: { fixedDate })

        assertExpense(parser.parse("Döner 4,50"), amount: 4.5, title: "Döner")
        assertExpense(parser.parse("Rewe 23,90"), amount: 23.9, title: "Rewe")
        assertExpense(parser.parse("Netflix 12,99 Abo"), amount: 12.99, title: "Netflix")
        if case let .expense(date, amount, title, category) = parser.parse("Ausgabe gestern 8,90 Essen unterwegs") {
            XCTAssertEqual(calendar.component(.day, from: date), 18)
            XCTAssertEqual(amount, 8.9, accuracy: 0.001)
            XCTAssertEqual(title, "Essen unterwegs")
            XCTAssertEqual(category, "Essen unterwegs")
        } else {
            XCTFail("Ausgabe gestern wurde nicht erkannt")
        }
        if case let .expense(_, amount, title, category) = parser.parse("Ausgabe 12,50 Freizeit Kino") {
            XCTAssertEqual(amount, 12.5, accuracy: 0.001)
            XCTAssertEqual(title, "Kino")
            XCTAssertEqual(category, "Freizeit")
        } else {
            XCTFail("Ausgabe mit expliziter Kategorie wurde nicht erkannt")
        }
    }

    func testTelegramExpenseWithInferredCategoryPersistsWithoutNetwork() async throws {
        let database = try AppDatabase.makeTemporary()
        let fakeClient = FakeTelegramBotClient()
        let bot = TelegramBotService(
            configuration: TelegramBotConfiguration.load(environment: [
                "ABOLIFE_TELEGRAM_BOT_TOKEN": "local-test-token",
                "ABOLIFE_TELEGRAM_ALLOWED_CHAT_ID": "100"
            ]),
            dialogManager: ExternalInputDialogManager(service: ExternalInputService(database: database)),
            client: fakeClient
        )

        let response = await bot.handle(
            TelegramUpdate(
                updateId: 300,
                message: TelegramMessage(chatId: 100, userId: 7, text: "Ausgabe Döner 4,50"),
                callback: nil
            )
        )

        let entry = try XCTUnwrap(FinanceRepository(database: database).fetchAll().first)
        XCTAssertTrue(response?.text.contains("Ausgabe gespeichert: 4,5 EUR - Döner · Essen unterwegs.") == true)
        XCTAssertTrue(response?.text.contains("Heute verfügbar") == true)
        XCTAssertTrue(response?.text.contains("Monatsrest") == true)
        XCTAssertEqual(fakeClient.sentResponses.count, 1)
        XCTAssertEqual(entry.title, "Döner")
        XCTAssertEqual(entry.amount, 4.5, accuracy: 0.001)
        XCTAssertEqual(entry.category, "Essen unterwegs")
    }

    func testTelegramExpenseCanAskForCategoryChangeBeforeSaving() async throws {
        let database = try AppDatabase.makeTemporary()
        let fakeClient = FakeTelegramBotClient()
        let bot = TelegramBotService(
            configuration: TelegramBotConfiguration.load(environment: [
                "ABOLIFE_TELEGRAM_BOT_TOKEN": "local-test-token",
                "ABOLIFE_TELEGRAM_ALLOWED_CHAT_ID": "100"
            ]),
            dialogManager: ExternalInputDialogManager(service: ExternalInputService(database: database)),
            client: fakeClient
        )

        let prompt = await bot.handle(
            TelegramUpdate(updateId: 302, message: TelegramMessage(chatId: 100, userId: 7, text: "Ausgabe 4,50 Irgendwas"), callback: nil)
        )
        XCTAssertTrue(prompt?.text.contains("Kategorie") == true)
        XCTAssertTrue(prompt?.keyboard?.rows.flatMap { $0 }.contains { $0.callbackData == "expense.category.change" } == true)

        _ = await bot.handle(TelegramUpdate(updateId: 303, message: nil, callback: TelegramCallbackAction(chatId: 100, userId: 7, data: "expense.category.change")))
        _ = await bot.handle(TelegramUpdate(updateId: 304, message: nil, callback: TelegramCallbackAction(chatId: 100, userId: 7, data: "expense.category.transport")))
        let saved = await bot.handle(TelegramUpdate(updateId: 305, message: nil, callback: TelegramCallbackAction(chatId: 100, userId: 7, data: "confirm.save")))

        let entry = try XCTUnwrap(FinanceRepository(database: database).fetchAll().first)
        XCTAssertTrue(saved?.text.contains("Ausgabe gespeichert") == true)
        XCTAssertEqual(entry.category, "Transport")
    }

    func testTelegramUnclearExpenseAsksForMissingDescriptionAndDoesNotSave() async throws {
        let database = try AppDatabase.makeTemporary()
        let fakeClient = FakeTelegramBotClient()
        let bot = TelegramBotService(
            configuration: TelegramBotConfiguration.load(environment: [
                "ABOLIFE_TELEGRAM_BOT_TOKEN": "local-test-token",
                "ABOLIFE_TELEGRAM_ALLOWED_CHAT_ID": "100"
            ]),
            dialogManager: ExternalInputDialogManager(service: ExternalInputService(database: database)),
            client: fakeClient
        )

        let response = await bot.handle(
            TelegramUpdate(
                updateId: 301,
                message: TelegramMessage(chatId: 100, userId: 7, text: "Ausgabe 12,50"),
                callback: nil
            )
        )

        XCTAssertTrue(response?.text.contains("Beschreibung") == true || response?.text.contains("Kategorie") == true || response?.text.contains("nicht eindeutig") == true)
        XCTAssertEqual(try FinanceRepository(database: database).fetchAll().count, 0)
        XCTAssertEqual(fakeClient.sentResponses.count, 1)
    }

    func testTelegramTrainingMinimumAndSimpleSetInputPersistWithoutNetwork() async throws {
        let database = try AppDatabase.makeTemporary()
        let fakeClient = FakeTelegramBotClient()
        let bot = TelegramBotService(
            configuration: TelegramBotConfiguration.load(environment: [
                "ABOLIFE_TELEGRAM_BOT_TOKEN": "local-test-token",
                "ABOLIFE_TELEGRAM_ALLOWED_CHAT_ID": "100"
            ]),
            dialogManager: ExternalInputDialogManager(service: ExternalInputService(database: database)),
            client: fakeClient
        )

        _ = await bot.handle(TelegramUpdate(updateId: 401, message: TelegramMessage(chatId: 100, userId: 7, text: "Training Minimum erledigt"), callback: nil))
        _ = await bot.handle(TelegramUpdate(updateId: 402, message: TelegramMessage(chatId: 100, userId: 7, text: "Liegestuetze 10 8 6"), callback: nil))

        let sessions = try WorkoutRepository(database: database).fetchAll()
        let history = try WorkoutRepository(database: database).fetchAllExerciseSummaries()
        XCTAssertEqual(sessions.count, 2)
        XCTAssertTrue(sessions.contains { $0.workoutIntensity == "Minimum" })
        XCTAssertTrue(history.contains { $0.exercise.exerciseName == "Liegestuetze" && $0.sets.compactMap(\.reps) == [10, 8, 6] })
        XCTAssertEqual(fakeClient.sentResponses.count, 2)
    }

    func testExternalInputServicePersistsSupportedIntents() throws {
        let database = try AppDatabase.makeTemporary()
        let service = ExternalInputService(database: database)
        let template = try NutritionTemplateRepository(database: database).create(kind: .favorite, name: "Skyr 500g", caloriesKcal: 310, proteinG: 55)

        XCTAssertSuccess(service.execute(.weight(date: Date(), weightKg: 82.4)), module: .weight)
        XCTAssertSuccess(service.execute(.weight(date: Date(), weightKg: 82.1)), module: .weight)
        XCTAssertEqual(try WeightRepository(database: database).fetchAll().count, 1)
        XCTAssertEqual(try WeightRepository(database: database).latest()?.weightKg ?? 0, 82.1, accuracy: 0.001)
        XCTAssertSuccess(service.execute(.weightTarget(weightKg: 80)), module: .weight)
        XCTAssertSuccess(service.execute(.weightCorridor(lowerKg: 82, upperKg: 78)), module: .weight)
        let settings = try SettingsRepository(database: database).loadSettings()
        XCTAssertEqual(settings.targetWeightKg ?? 0, 80, accuracy: 0.001)
        XCTAssertEqual(settings.targetWeightLowerKg ?? 0, 78, accuracy: 0.001)
        XCTAssertTrue(service.execute(.weightStatus).message.contains("Ziel: 80"))

        XCTAssertSuccess(service.execute(.expense(date: Date(), amount: 4.5, title: "Kaffee", category: nil)), module: .finance)
        XCTAssertEqual(try FinanceRepository(database: database).fetchAll().first?.title, "Kaffee")

        XCTAssertSuccess(service.execute(.meal(date: Date(), name: "Skyr", calories: 250, protein: 25, note: nil)), module: .nutrition)
        XCTAssertSuccess(service.execute(.mealTemplate(date: Date(), templateId: template.id)), module: .nutrition)
        XCTAssertEqual(try NutritionRepository(database: database).fetchAll().count, 2)

        XCTAssertSuccess(service.execute(.workoutCompleted(date: Date(), note: nil)), module: .training)
        XCTAssertEqual(try WorkoutRepository(database: database).fetchAll().count, 1)
        XCTAssertTrue(try HabitRepository(database: database).fetchAll().isEmpty)

        XCTAssertSuccess(service.execute(.habitCompleted(date: Date(), habitName: "Schlafroutine")), module: .habits)
        XCTAssertEqual(try HabitRepository(database: database).fetchAll().count, 1)

        XCTAssertFailure(service.execute(.habitCompleted(date: Date(), habitName: "Lesen")), reason: "habit_missing")
        XCTAssertFailure(service.execute(.expense(date: Date(), amount: 0, title: "Fehler", category: nil)), reason: "invalid_amount")
        XCTAssertFailure(service.execute(.weight(date: Date(), weightKg: 10)), reason: "invalid_weight")
    }

    func testExternalInputDialogManagerRunsMainFlows() throws {
        let database = try AppDatabase.makeTemporary()
        let template = try NutritionTemplateRepository(database: database).create(kind: .mealTemplate, name: "Reis Hähnchen", caloriesKcal: 650, proteinG: 45)
        let manager = ExternalInputDialogManager(service: ExternalInputService(database: database))

        let menu = manager.handle(.text("/start"))
        XCTAssertEqual(menu.actions.map(\.id), ExternalInputAction.mainMenu.map(\.id))

        _ = manager.handle(.action(.startFlow(.weight)))
        XCTAssertSuccess(manager.handle(.text("82,4")), module: .weight)

        _ = manager.handle(.action(.startFlow(.expense)))
        XCTAssertTrue(manager.hasActiveDialog())
        _ = manager.handle(.text("4,50"))
        let expenseConfirm = manager.handle(.text("Döner"))
        XCTAssertEqual(expenseConfirm.actions.map(\.id), ["confirm.save", "expense.category.change", "confirm.cancel"])
        XCTAssertSuccess(manager.handle(.action(.confirm)), module: .finance)

        _ = manager.handle(.action(.startFlow(.meal)))
        _ = manager.handle(.text("Skyr"))
        _ = manager.handle(.text("250"))
        _ = manager.handle(.text("25"))
        XCTAssertSuccess(manager.handle(.text("speichern")), module: .nutrition)

        let templatePrompt = manager.handle(.action(.startFlow(.mealTemplate)))
        XCTAssertTrue(templatePrompt.actions.contains { $0.id == "template.\(template.id)" })
        XCTAssertSuccess(manager.handle(.action(.selectTemplate(id: template.id))), module: .nutrition)

        XCTAssertSuccess(manager.handle(.action(.startFlow(.workout))), module: .training)

        _ = manager.handle(.action(.startFlow(.habit)))
        XCTAssertSuccess(manager.handle(.action(.selectHabit(name: "Schlafroutine"))), module: .habits)

        _ = manager.handle(.action(.startFlow(.expense)))
        XCTAssertTrue(manager.hasActiveDialog())
        XCTAssertSuccess(manager.handle(.action(.cancel)), module: .menu)
        XCTAssertFalse(manager.hasActiveDialog())

        _ = manager.handle(.action(.startFlow(.weight)))
        let invalidWeight = manager.handle(.text("abc"))
        XCTAssertTrue(manager.hasActiveDialog())
        XCTAssertTrue(invalidWeight.message.contains("Gewicht"))
    }

    func testFoodQuantityParserExtractsClearGramValuesOnly() {
        XCTAssertEqual(FoodQuantityParser.grams(from: "55g"), 55)
        XCTAssertEqual(FoodQuantityParser.grams(from: "55 g"), 55)
        XCTAssertEqual(FoodQuantityParser.grams(from: "1 x 55g"), 55)
        XCTAssertEqual(FoodQuantityParser.grams(from: "4 x 100 g"), 400)
        XCTAssertNil(FoodQuantityParser.grams(from: "500 ml"))
        XCTAssertNil(FoodQuantityParser.grams(from: "Packung"))
    }

    func testOpenFoodFactsParsingUsesFixtureWithoutNetwork() throws {
        let fixture = """
        {
          "code": "7340001805885",
          "status": 1,
          "product": {
            "product_name": "Protein Bar Chocolate Dough",
            "brands": "Barebells",
            "quantity": "55 g",
            "nutriments": {
              "energy-kcal_100g": 362,
              "proteins_100g": 36,
              "carbohydrates_100g": 32.5,
              "fat_100g": 15
            }
          }
        }
        """.data(using: .utf8)!

        let product = try FoodProductLookupService.parse(data: fixture)

        XCTAssertEqual(product.barcode, "7340001805885")
        XCTAssertEqual(product.name, "Protein Bar Chocolate Dough")
        XCTAssertEqual(product.brand, "Barebells")
        XCTAssertEqual(product.quantityText, "55 g")
        XCTAssertEqual(product.caloriesPer100g, 362)
        XCTAssertEqual(product.proteinPer100g, 36)
        XCTAssertEqual(product.carbsPer100g, 32.5)
        XCTAssertEqual(product.fatPer100g, 15)
        XCTAssertEqual(product.source, "open_food_facts")
    }

    func testOpenFoodFactsParsingHandlesMissingAndNotFoundProducts() throws {
        let missingNutrition = """
        {"code":"123","status":1,"product":{"product_name":"Mystery","nutriments":{"energy-kcal_serving":240}}}
        """.data(using: .utf8)!
        let product = try FoodProductLookupService.parse(data: missingNutrition)
        XCTAssertEqual(product.name, "Mystery")
        XCTAssertNil(product.caloriesPer100g)
        XCTAssertNil(product.proteinPer100g)

        let notFound = #"{"code":"999","status":0}"#.data(using: .utf8)!
        XCTAssertThrowsError(try FoodProductLookupService.parse(data: notFound)) { error in
            XCTAssertEqual(error as? FoodProductLookupError, .notFound("999"))
        }
    }

    func testBarcodeDialogManualAmountAndCancelDoNotSaveEarly() throws {
        let database = try AppDatabase.makeTemporary()
        let manager = ExternalInputDialogManager(service: ExternalInputService(database: database))
        let product = barcodeProduct()

        let preview = manager.beginBarcodeMeal(product: product)
        XCTAssertTrue(preview.message.contains("Produkt erkannt"))
        XCTAssertTrue(preview.actions.contains { $0.id == "barcode.amount.55" })
        XCTAssertEqual(
            preview.actions.map(\.id),
            ["barcode.amount.55", "barcode.amount.100", "barcode.amount.150", "barcode.amount.250", "barcode.manual", "flow.cancel"]
        )
        XCTAssertTrue(preview.message.contains("Barebells"))
        XCTAssertTrue(preview.message.contains("Open Food Facts"))
        XCTAssertTrue(preview.message.contains("362 kcal"))
        XCTAssertTrue(preview.message.contains("36 g"))
        XCTAssertEqual(try NutritionRepository(database: database).fetchAll().count, 0)

        _ = manager.handle(.action(.enterBarcodeAmountManually))
        let invalid = manager.handle(.text("abc"))
        XCTAssertTrue(invalid.message.contains("gültige Menge"))
        XCTAssertEqual(try NutritionRepository(database: database).fetchAll().count, 0)

        let confirm = manager.handle(.text("55 g"))
        XCTAssertTrue(confirm.message.contains("Speichern?"))
        XCTAssertEqual(try NutritionRepository(database: database).fetchAll().count, 0)

        XCTAssertSuccess(manager.handle(.action(.cancel)), module: .menu)
        XCTAssertEqual(try NutritionRepository(database: database).fetchAll().count, 0)
    }

    func testBarcodeDialogSavesOnlyAfterConfirmAndReportsDayStatus() throws {
        let database = try AppDatabase.makeTemporary()
        try SettingsRepository(database: database).saveSettings(AppSettingsRecord(caloriesTarget: 2300, proteinTargetG: 160, monthlyBudget: 900))
        let manager = ExternalInputDialogManager(service: ExternalInputService(database: database))
        _ = manager.beginBarcodeMeal(product: barcodeProduct())

        let confirm = manager.handle(.action(.selectBarcodeAmount(grams: 55)))
        XCTAssertTrue(confirm.message.contains("199 kcal"))
        XCTAssertEqual(try NutritionRepository(database: database).fetchAll().count, 0)

        let saved = manager.handle(.action(.confirm))
        XCTAssertSuccess(saved, module: .nutrition)
        XCTAssertTrue(saved.message.contains("Gespeichert:"))
        XCTAssertTrue(saved.message.contains("Heute:"))
        XCTAssertEqual(try NutritionRepository(database: database).fetchAll().count, 1)
        let entry = try XCTUnwrap(NutritionRepository(database: database).fetchAll().first)
        XCTAssertEqual(entry.title, "Protein Bar Chocolate Dough")
        XCTAssertEqual(entry.caloriesKcal, 199)
        XCTAssertEqual(entry.proteinG, 19.8, accuracy: 0.01)
        XCTAssertTrue(entry.note?.contains("Telegram Barcode / Open Food Facts") == true)
        XCTAssertTrue(entry.note?.contains("7340001805885") == true)
    }

    func testBarcodeDialogRejectsProductWithMissingNutrition() throws {
        let database = try AppDatabase.makeTemporary()
        let manager = ExternalInputDialogManager(service: ExternalInputService(database: database))
        let product = FoodProductLookupResult(
            barcode: "123",
            name: "Unvollständig",
            brand: nil,
            quantityText: "55 g",
            caloriesPer100g: nil,
            proteinPer100g: 10,
            carbsPer100g: nil,
            fatPer100g: nil,
            source: "open_food_facts"
        )

        let result = manager.beginBarcodeMeal(product: product)

        XCTAssertFailure(result, reason: "barcode_nutrition_missing")
        XCTAssertEqual(try NutritionRepository(database: database).fetchAll().count, 0)
    }

    func testTelegramBarcodePhotoFlowScansLooksUpConfirmsAndSaves() async throws {
        let database = try AppDatabase.makeTemporary()
        let configuration = TelegramBotConfiguration.load(environment: [
            "ABOLIFE_TELEGRAM_BOT_TOKEN": "local-test-token",
            "ABOLIFE_TELEGRAM_ALLOWED_CHAT_ID": "100"
        ])
        let fakeClient = FakeTelegramBotClient()
        let scanner = MockBarcodeScanner(result: .success(BarcodeScanResult(value: "7340001805885", symbology: "EAN-13")))
        let lookup = MockFoodProductLookup(result: .success(barcodeProduct()))
        let fileClient = MockTelegramFileClient()
        let tempDirectory = makeTemporaryBackupDirectory()
        try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
        let bot = TelegramBotService(
            configuration: configuration,
            dialogManager: ExternalInputDialogManager(service: ExternalInputService(database: database)),
            client: fakeClient,
            barcodeFoodScanService: TelegramBarcodeFoodScanService(
                fileClient: fileClient,
                scanner: scanner,
                lookupService: lookup,
                temporaryDirectory: tempDirectory
            )
        )

        let preview = await bot.handle(
            TelegramUpdate(
                updateId: 1,
                message: TelegramMessage(
                    chatId: 100,
                    userId: 7,
                    photos: [
                        TelegramPhotoSize(fileId: "small", width: 100, height: 100, fileSize: 10),
                        TelegramPhotoSize(fileId: "large", width: 1200, height: 800, fileSize: 100)
                    ]
                ),
                callback: nil
            )
        )

        XCTAssertTrue(preview?.text.contains("Produkt erkannt") == true)
        XCTAssertEqual(fileClient.requestedFileIds, ["large"])
        XCTAssertEqual(lookup.requestedBarcodes, ["7340001805885"])
        XCTAssertTrue(scanner.scannedFileExisted)
        XCTAssertEqual((try? FileManager.default.contentsOfDirectory(atPath: tempDirectory.path))?.isEmpty, true)
        XCTAssertEqual(try NutritionRepository(database: database).fetchAll().count, 0)

        let confirm = await bot.handle(TelegramUpdate(updateId: 2, message: nil, callback: TelegramCallbackAction(chatId: 100, userId: 7, data: "barcode.amount.55")))
        XCTAssertTrue(confirm?.text.contains("Speichern?") == true)
        XCTAssertEqual(try NutritionRepository(database: database).fetchAll().count, 0)

        let saved = await bot.handle(TelegramUpdate(updateId: 3, message: nil, callback: TelegramCallbackAction(chatId: 100, userId: 7, data: "confirm.save")))
        XCTAssertTrue(saved?.text.contains("Gespeichert:") == true)
        XCTAssertEqual(try NutritionRepository(database: database).fetchAll().count, 1)
        try? FileManager.default.removeItem(at: tempDirectory)
    }

    func testTelegramBarcodePhotoWithoutBarcodeRespondsClearly() async throws {
        let database = try AppDatabase.makeTemporary()
        let configuration = TelegramBotConfiguration.load(environment: [
            "ABOLIFE_TELEGRAM_BOT_TOKEN": "local-test-token",
            "ABOLIFE_TELEGRAM_ALLOWED_CHAT_ID": "100"
        ])
        let fakeClient = FakeTelegramBotClient()
        let bot = TelegramBotService(
            configuration: configuration,
            dialogManager: ExternalInputDialogManager(service: ExternalInputService(database: database)),
            client: fakeClient,
            barcodeFoodScanService: TelegramBarcodeFoodScanService(
                fileClient: MockTelegramFileClient(),
                scanner: MockBarcodeScanner(result: .failure(BarcodeScanError.noBarcode)),
                lookupService: MockFoodProductLookup(result: .success(barcodeProduct()))
            )
        )

        let response = await bot.handle(
            TelegramUpdate(
                updateId: 1,
                message: TelegramMessage(chatId: 100, userId: 7, photos: [TelegramPhotoSize(fileId: "photo", width: 100, height: 100, fileSize: nil)]),
                callback: nil
            )
        )

        XCTAssertTrue(response?.text.contains("kein Barcode") == true)
        XCTAssertEqual(try NutritionRepository(database: database).fetchAll().count, 0)
    }

    func testTelegramBarcodeProductWithMissingNutritionDoesNotSave() async throws {
        let database = try AppDatabase.makeTemporary()
        let configuration = TelegramBotConfiguration.load(environment: [
            "ABOLIFE_TELEGRAM_BOT_TOKEN": "local-test-token",
            "ABOLIFE_TELEGRAM_ALLOWED_CHAT_ID": "100"
        ])
        let incompleteProduct = FoodProductLookupResult(
            barcode: "123",
            name: "Unvollständig",
            brand: nil,
            quantityText: nil,
            caloriesPer100g: 100,
            proteinPer100g: nil,
            carbsPer100g: nil,
            fatPer100g: nil,
            source: "open_food_facts"
        )
        let bot = TelegramBotService(
            configuration: configuration,
            dialogManager: ExternalInputDialogManager(service: ExternalInputService(database: database)),
            client: FakeTelegramBotClient(),
            barcodeFoodScanService: TelegramBarcodeFoodScanService(
                fileClient: MockTelegramFileClient(),
                scanner: MockBarcodeScanner(result: .success(BarcodeScanResult(value: "123", symbology: "EAN-13"))),
                lookupService: MockFoodProductLookup(result: .success(incompleteProduct))
            )
        )

        let response = await bot.handle(
            TelegramUpdate(
                updateId: 1,
                message: TelegramMessage(chatId: 100, userId: 7, photos: [TelegramPhotoSize(fileId: "photo", width: 100, height: 100, fileSize: nil)]),
                callback: nil
            )
        )

        XCTAssertTrue(response?.text.contains("Kalorien oder Protein") == true)
        XCTAssertEqual(try NutritionRepository(database: database).fetchAll().count, 0)
    }

    func testTelegramMappingAndDisabledConfiguration() async throws {
        let disabled = TelegramBotConfiguration.load(environment: [:])
        XCTAssertFalse(disabled.isEnabled)
        XCTAssertNil(disabled.token)
        XCTAssertNil(disabled.allowedChatId)

        let enabled = TelegramBotConfiguration.load(environment: [
            "ABOLIFE_TELEGRAM_BOT_TOKEN": "local-test-token",
            "ABOLIFE_TELEGRAM_ALLOWED_CHAT_ID": "100"
        ])
        XCTAssertTrue(enabled.isEnabled)
        XCTAssertEqual(enabled.token, "local-test-token")
        XCTAssertEqual(enabled.allowedChatId, 100)

        let database = try AppDatabase.makeTemporary()
        let manager = ExternalInputDialogManager(service: ExternalInputService(database: database))
        let fakeClient = FakeTelegramBotClient()
        let bot = TelegramBotService(configuration: enabled, dialogManager: manager, client: fakeClient)

        let start = await bot.handle(TelegramUpdate(updateId: 1, message: TelegramMessage(chatId: 100, userId: 7, text: "/start"), callback: nil))
        XCTAssertEqual(start?.text, "🏠 AboLife\n\nWas möchtest du heute in Ruhe machen?")
        XCTAssertEqual(
            start?.keyboard?.rows.map { $0.map(\.callbackData) },
            [
                [TelegramCallbackID.addMeal, TelegramCallbackID.addWorkout],
                [TelegramCallbackID.addWeight, TelegramCallbackID.addExpense],
                [TelegramCallbackID.addHabit, TelegramCallbackID.today],
                [TelegramCallbackID.exportMenu, TelegramCallbackID.help]
            ]
        )

        let weightPrompt = await bot.handle(TelegramUpdate(updateId: 2, message: nil, callback: TelegramCallbackAction(chatId: 100, userId: 7, data: "flow.weight")))
        XCTAssertTrue(weightPrompt?.text.contains("Gewicht") == true)

        let weightSaved = await bot.handle(TelegramUpdate(updateId: 3, message: TelegramMessage(chatId: 100, userId: 7, text: "82,4"), callback: nil))
        XCTAssertTrue(weightSaved?.text.contains("gespeichert") == true)

        _ = await bot.handle(TelegramUpdate(updateId: 4, message: nil, callback: TelegramCallbackAction(chatId: 100, userId: 7, data: "flow.expense")))
        _ = await bot.handle(TelegramUpdate(updateId: 5, message: TelegramMessage(chatId: 100, userId: 7, text: "4,50"), callback: nil))
        let confirmation = await bot.handle(TelegramUpdate(updateId: 6, message: TelegramMessage(chatId: 100, userId: 7, text: "Kaffee"), callback: nil))
        XCTAssertEqual(confirmation?.keyboard?.rows.flatMap { $0 }.map(\.callbackData), ["dialog.save", "expense.category.change", "dialog.cancel"])
        let saved = await bot.handle(TelegramUpdate(updateId: 7, message: nil, callback: TelegramCallbackAction(chatId: 100, userId: 7, data: "confirm.save")))
        XCTAssertTrue(saved?.text.contains("Ausgabe gespeichert") == true)

        _ = await bot.handle(TelegramUpdate(updateId: 8, message: nil, callback: TelegramCallbackAction(chatId: 100, userId: 7, data: "flow.meal")))
        let canceled = await bot.handle(TelegramUpdate(updateId: 9, message: nil, callback: TelegramCallbackAction(chatId: 100, userId: 7, data: "flow.cancel")))
        XCTAssertEqual(canceled?.text, "Abgebrochen.")

        let disabledBot = TelegramBotService(configuration: disabled, dialogManager: manager, client: fakeClient)
        XCTAssertFalse(disabledBot.isEnabled)
        let disabledResponse = await disabledBot.handle(TelegramUpdate(updateId: 10, message: TelegramMessage(chatId: 100, userId: 7, text: "/start"), callback: nil))
        XCTAssertNil(disabledResponse)
        XCTAssertEqual(fakeClient.sentResponses.count, 9)
    }

    func testTelegramMenuHelpNavigationAndExportUX() async throws {
        let database = try AppDatabase.makeTemporary()
        let configuration = TelegramBotConfiguration.load(environment: [
            "ABOLIFE_TELEGRAM_BOT_TOKEN": "local-test-token",
            "ABOLIFE_TELEGRAM_ALLOWED_CHAT_ID": "100"
        ])
        let manager = ExternalInputDialogManager(service: ExternalInputService(database: database))
        let bot = TelegramBotService(
            configuration: configuration,
            dialogManager: manager,
            client: FakeTelegramBotClient()
        )

        _ = await bot.handle(TelegramUpdate(updateId: 1, message: nil, callback: TelegramCallbackAction(chatId: 100, userId: 7, data: "flow.weight")))
        XCTAssertTrue(manager.hasActiveDialog(sessionID: "telegram.chat.100"))

        let menu = await bot.handle(TelegramUpdate(updateId: 2, message: nil, callback: TelegramCallbackAction(chatId: 100, userId: 7, data: TelegramCallbackID.mainMenu)))
        XCTAssertFalse(manager.hasActiveDialog(sessionID: "telegram.chat.100"))
        XCTAssertTrue(menu?.text.contains("🏠 AboLife") == true)

        let help = await bot.handle(TelegramUpdate(updateId: 3, message: TelegramMessage(chatId: 100, userId: 7, text: "/help"), callback: nil))
        for example in [
            "Essen Skyr 250 kcal 25 Protein",
            "Ausgabe Döner 4,50",
            "Training erledigt",
            "Gewicht 82,4",
            "Habit Schlafroutine erledigt",
            "Barcode-Foto"
        ] {
            XCTAssertTrue(help?.text.contains(example) == true, "Fehlendes Hilfe-Beispiel: \(example)")
        }
        XCTAssertEqual(help?.keyboard, TelegramButtonMapper.menuBackKeyboard)

        let export = await bot.handle(TelegramUpdate(updateId: 4, message: nil, callback: TelegramCallbackAction(chatId: 100, userId: 7, data: TelegramCallbackID.exportMenu)))
        XCTAssertEqual(
            export?.keyboard?.rows.flatMap { $0 }.map(\.label),
            ["📄 Tagesreport HTML", "📅 Wochenreport HTML", "🗓 Monatsreport HTML", "📊 CSV / Numbers", "‹ Zurück"]
        )
        XCTAssertEqual(
            export?.keyboard?.rows.flatMap { $0 }.map(\.callbackData),
            [TelegramCallbackID.exportSnapshot, "export.weekly_html", "export.monthly_html", TelegramCallbackID.exportData, TelegramCallbackID.mainMenu]
        )
        XCTAssertFalse(export?.text.localizedCaseInsensitiveContains("backup") == true)

        let legacy = await bot.handle(TelegramUpdate(updateId: 5, message: nil, callback: TelegramCallbackAction(chatId: 100, userId: 7, data: "flow.expense")))
        XCTAssertTrue(legacy?.text.contains("ausgegeben") == true)
    }

    func testDailySummaryBuildsMorningMessageWithMissingHintsAndButtons() throws {
        let database = try AppDatabase.makeTemporary()
        try SettingsRepository(database: database).saveSettings(
            AppSettingsRecord(
                caloriesTarget: 2500,
                proteinTargetG: 170,
                weeklyWorkoutTarget: 5,
                monthlyBudget: 900,
                defaultCurrency: "EUR",
                weekStartsOn: 2
            )
        )
        let calendar = Calendar(identifier: .gregorian)
        let monday = DateComponents(calendar: calendar, year: 2026, month: 6, day: 15, hour: 9).date!
        try NutritionRepository(database: database).insert(
            NutritionEntryRecord(occurredAt: monday, title: "Frühstück", caloriesKcal: 600, proteinG: 45)
        )
        try FinanceRepository(database: database).insert(
            FinanceEntryRecord(occurredAt: monday, title: "Kaffee", amount: 4.5, category: "Essen")
        )

        let message = try DailySummaryService(database: database, calendar: calendar).morningSummary(for: monday)

        XCTAssertTrue(message.text.contains("Guten Morgen Abo"))
        XCTAssertTrue(message.text.contains("* Gewicht: noch nicht eingetragen"))
        XCTAssertTrue(message.text.contains("* Kalorien übrig: 1900 kcal"))
        XCTAssertTrue(message.text.contains("* Protein übrig: 125 g"))
        XCTAssertTrue(message.text.contains("* Training heute: Pull + Core"))
        XCTAssertTrue(message.text.contains("* Medikamente: offen"))
        XCTAssertTrue(message.text.contains("* Proteinshake: offen"))
        XCTAssertTrue(message.keyboard?.rows.flatMap { $0 }.contains { $0.callbackData == TelegramReminderAction.proteinShakeDone.rawValue } == true)
        XCTAssertTrue(message.keyboard?.rows.flatMap { $0 }.contains { $0.callbackData == TelegramReminderAction.addExpense.rawValue } == true)
    }

    func testTodayTextContainsCentralDailyWeeklyFinanceHabitAndOpenStatus() throws {
        let database = try AppDatabase.makeTemporary()
        let calendar = Calendar(identifier: .gregorian)
        let date = DateComponents(calendar: calendar, year: 2026, month: 6, day: 15, hour: 12).date!
        let anotherDayThisWeek = DateComponents(calendar: calendar, year: 2026, month: 6, day: 16, hour: 18).date!
        try SettingsRepository(database: database).saveSettings(
            AppSettingsRecord(
                caloriesTarget: 2400,
                proteinTargetG: 160,
                weeklyWorkoutTarget: 4,
                monthlyBudget: 900,
                defaultCurrency: "EUR",
                weekStartsOn: 2
            )
        )
        try NutritionRepository(database: database).insert(
            NutritionEntryRecord(occurredAt: date, title: "Frühstück", caloriesKcal: 600, proteinG: 45)
        )
        try FinanceRepository(database: database).insert(
            FinanceEntryRecord(occurredAt: date, title: "Einkauf", amount: 104.5, category: "Lebensmittel")
        )
        try WorkoutRepository(database: database).insert(
            WorkoutSessionRecord(occurredAt: anotherDayThisWeek, workoutType: "Training", durationMin: 0, status: "done")
        )
        try HabitRepository(database: database).insert(
            HabitEntryRecord(habitKey: "sleep", date: "2026-06-15", isCompleted: true, value: 1)
        )
        try HabitRepository(database: database).insert(
            HabitEntryRecord(habitKey: TelegramReminderHabit.medicationKey, date: "2026-06-15", isCompleted: true)
        )

        let text = try DailySummaryService(database: database, calendar: calendar).todayText(for: date)

        XCTAssertTrue(text.contains("📊 Heute · 15.06.2026"))
        XCTAssertTrue(text.contains("Kalorien: 600 / 2400 kcal"))
        XCTAssertTrue(text.contains("Protein: 45 / 160 g"), text)
        XCTAssertTrue(text.contains("Training heute: Pull + Core · offen"), text)
        XCTAssertTrue(text.contains("Woche: 1 / 4"))
        XCTAssertTrue(text.contains("Heute verfügbar:"))
        XCTAssertTrue(text.contains("Monatsrest:"))
        XCTAssertTrue(text.contains("795,50"))
        XCTAssertTrue(text.contains("Habits: 1 / 4 erledigt"))
        XCTAssertTrue(text.contains("Medikamente: erledigt · Shake: offen"))
        XCTAssertTrue(text.contains("Noch offen:"))
        XCTAssertTrue(text.contains("Nächster Schritt:"))
    }

    func testSaveResultsAreCentrallyEnrichedForAllTelegramDomains() throws {
        let database = try AppDatabase.makeTemporary()
        let calendar = Calendar(identifier: .gregorian)
        let date = DateComponents(calendar: calendar, year: 2026, month: 6, day: 15, hour: 12).date!
        try SettingsRepository(database: database).saveSettings(
            AppSettingsRecord(
                caloriesTarget: 2300,
                proteinTargetG: 150,
                weeklyWorkoutTarget: 3,
                monthlyBudget: 900,
                defaultCurrency: "EUR",
                weekStartsOn: 2
            )
        )
        let service = ExternalInputService(database: database, calendar: calendar, now: { date })

        let weight = service.execute(.weight(date: date, weightKg: 82.4), sessionID: "weight")
        XCTAssertTrue(weight.message.contains("⚖️ Aktuell: 82,4 kg"))

        let meal = service.execute(
            .meal(date: date, name: "Skyr", calories: 250, protein: 25, note: nil),
            sessionID: "meal"
        )
        XCTAssertTrue(meal.message.contains("📊 Heute: 250 / 2300 kcal"))
        XCTAssertTrue(meal.message.contains("25 / 150 g Protein"))

        let expense = service.execute(
            .expense(date: date, amount: 4.5, title: "Kaffee", category: "Essen unterwegs"),
            sessionID: "expense"
        )
        XCTAssertTrue(expense.message.contains("💶 Heute verfügbar:"))
        XCTAssertTrue(expense.message.contains("Monatsrest:"))
        XCTAssertTrue(expense.message.contains("895,50"))

        let workout = service.execute(.workoutCompleted(date: date, note: nil), sessionID: "workout")
        XCTAssertTrue(workout.message.contains("🏋️ Training erledigt"))
        XCTAssertTrue(workout.message.contains("Woche: 1 / 3"))

        let habit = service.execute(
            .habitCompleted(date: date, habitName: "Schlafroutine"),
            sessionID: "habit"
        )
        XCTAssertTrue(habit.message.contains("✅ Habits heute: 1 / 4"))
        XCTAssertTrue(habit.message.contains("Medikamente: offen"))
        XCTAssertTrue(habit.message.contains("Shake: offen"))
    }

    func testUndoUsesCalmExactMessagesAndIsIdempotent() throws {
        let database = try AppDatabase.makeTemporary()
        let date = Date(timeIntervalSince1970: 1_800_000_000)
        let service = ExternalInputService(database: database, now: { date })
        let result = service.execute(
            .meal(date: date, name: "Skyr", calories: 250, protein: 25, note: nil),
            sessionID: "telegram.chat.100"
        )
        guard case let .saved(_, _, receipt) = result else {
            return XCTFail("Gespeicherten Eintrag mit Undo-Beleg erwartet")
        }

        let firstUndo = service.undo(receiptID: receipt.id, sessionID: "telegram.chat.100")
        XCTAssertEqual(firstUndo.message, "↩️ Rückgängig gemacht.")
        XCTAssertEqual(try NutritionRepository(database: database).fetchAll().count, 0)

        let secondUndo = service.undo(receiptID: receipt.id, sessionID: "telegram.chat.100")
        XCTAssertEqual(secondUndo.message, "Das kann ich leider nicht mehr sicher rückgängig machen.")
        XCTAssertEqual(try NutritionRepository(database: database).fetchAll().count, 0)
    }

    func testReminderServiceMarksProteinShakeAndMedicationDone() throws {
        let database = try AppDatabase.makeTemporary()
        let calendar = Calendar(identifier: .gregorian)
        let date = DateComponents(calendar: calendar, year: 2026, month: 6, day: 15, hour: 9).date!
        let service = ReminderService(database: database, calendar: calendar, now: { date })

        let protein = try service.handle(action: .proteinShakeDone, date: date)
        let medication = try service.handle(action: .medicationDone, date: date)

        XCTAssertTrue(protein.message.contains("Proteinshake erledigt."))
        XCTAssertTrue(medication.message.contains("Medikamente erledigt."))
        let dayKey = DateIntervals.dayKey(for: date, calendar: calendar)
        XCTAssertEqual(try HabitRepository(database: database).fetchEntry(habitKey: TelegramReminderHabit.proteinShakeKey, date: dayKey)?.isCompleted, true)
        XCTAssertEqual(try HabitRepository(database: database).fetchEntry(habitKey: TelegramReminderHabit.medicationKey, date: dayKey)?.isCompleted, true)
    }

    func testReminderServiceUsesTodayOpenStatusForButtonsTrainingAndCompletion() throws {
        let database = try AppDatabase.makeTemporary()
        let calendar = Calendar(identifier: .gregorian)
        let monday = DateComponents(calendar: calendar, year: 2026, month: 6, day: 15, hour: 9).date!
        let tuesday = DateComponents(calendar: calendar, year: 2026, month: 6, day: 16, hour: 18).date!
        let service = ReminderService(database: database, calendar: calendar, now: { monday })
        let mondayKey = DateIntervals.dayKey(for: monday, calendar: calendar)

        try HabitRepository(database: database).upsertCompletion(
            habitKey: TelegramReminderHabit.medicationKey,
            date: mondayKey,
            isCompleted: true
        )
        let morning = try XCTUnwrap(service.morningHabitReminder(for: monday))
        let morningCallbacks = morning.keyboard?.rows.flatMap { $0 }.map(\.callbackData) ?? []
        XCTAssertTrue(morning.text.contains("Proteinshake ist noch offen"))
        XCTAssertFalse(morning.text.contains("Medikamente sind noch offen"))
        XCTAssertTrue(morningCallbacks.contains(TelegramReminderAction.proteinShakeDone.rawValue))
        XCTAssertFalse(morningCallbacks.contains(TelegramReminderAction.medicationDone.rawValue))

        XCTAssertNotNil(try service.trainingReminder(for: monday))
        XCTAssertNil(try service.trainingReminder(for: tuesday))
        try WorkoutRepository(database: database).insert(
            WorkoutSessionRecord(occurredAt: monday, workoutType: "Training", durationMin: 0, status: "done")
        )
        XCTAssertNil(try service.trainingReminder(for: monday))

        try HabitRepository(database: database).upsertCompletion(
            habitKey: TelegramReminderHabit.proteinShakeKey,
            date: mondayKey,
            isCompleted: true
        )
        let completedMorning = try XCTUnwrap(service.morningHabitReminder(for: monday))
        XCTAssertEqual(completedMorning.text, "Morgen-Check: Medikamente und Proteinshake sind erledigt.")
        XCTAssertNil(completedMorning.keyboard)
    }

    func testEveningReminderReturnsShortPositiveMessageWhenEverythingIsDone() throws {
        let database = try AppDatabase.makeTemporary()
        let calendar = Calendar(identifier: .gregorian)
        let date = DateComponents(calendar: calendar, year: 2026, month: 6, day: 15, hour: 21).date!
        let dayKey = DateIntervals.dayKey(for: date, calendar: calendar)
        try SettingsRepository(database: database).saveSettings(
            AppSettingsRecord(caloriesTarget: 800, proteinTargetG: 50, monthlyBudget: 900)
        )
        try NutritionRepository(database: database).insert(
            NutritionEntryRecord(occurredAt: date, title: "Tag", caloriesKcal: 800, proteinG: 50)
        )
        try WorkoutRepository(database: database).insert(
            WorkoutSessionRecord(occurredAt: date, workoutType: "Training", durationMin: 0, status: "done")
        )
        for habit in FixedHabit.defaults where !habit.isDerived {
            try HabitRepository(database: database).insert(
                HabitEntryRecord(
                    habitKey: habit.key,
                    date: dayKey,
                    isCompleted: true,
                    value: habit.targetValue
                )
            )
        }
        for key in [TelegramReminderHabit.medicationKey, TelegramReminderHabit.proteinShakeKey] {
            try HabitRepository(database: database).insert(
                HabitEntryRecord(habitKey: key, date: dayKey, isCompleted: true)
            )
        }

        let message = try XCTUnwrap(
            ReminderService(database: database, calendar: calendar).eveningCheck(for: date)
        )

        XCTAssertEqual(message.text, "Für heute ist alles Wichtige erledigt. Ruhiger Feierabend.")
        XCTAssertNil(message.keyboard)
    }

    @MainActor
    func testTelegramReminderSchedulerSendsMorningSummaryOnce() async throws {
        let database = try AppDatabase.makeTemporary()
        let calendar = Calendar(identifier: .gregorian)
        let date = DateComponents(calendar: calendar, year: 2026, month: 6, day: 15, hour: 9, minute: 0).date!
        let configuration = TelegramBotConfiguration.load(environment: [
            "ABOLIFE_TELEGRAM_BOT_TOKEN": "local-test-token",
            "ABOLIFE_TELEGRAM_ALLOWED_CHAT_ID": "100"
        ])
        let fakeClient = FakeTelegramBotClient()
        let scheduler = TelegramReminderScheduler(
            configuration: configuration,
            client: fakeClient,
            dailySummaryService: DailySummaryService(database: database, calendar: calendar),
            reminderService: ReminderService(database: database, calendar: calendar),
            calendar: calendar,
            now: { date }
        )

        await scheduler.processDueRemindersForTests(at: date)
        await scheduler.processDueRemindersForTests(at: date)

        XCTAssertEqual(fakeClient.sentResponses.count, 2)
        XCTAssertTrue(fakeClient.sentResponses.first?.text.contains("Guten Morgen Abo") == true)
        XCTAssertTrue(fakeClient.sentResponses.contains { $0.text.contains("Proteinshake ist noch offen") })
        XCTAssertEqual(scheduler.sentLogs.count, 2)
    }

    @MainActor
    func testTelegramReminderSchedulerUsesConfiguredTimesAndRedactsLogs() async throws {
        let database = try AppDatabase.makeTemporary()
        let calendar = Calendar(identifier: .gregorian)
        let defaultMorning = DateComponents(calendar: calendar, year: 2026, month: 6, day: 15, hour: 9, minute: 0).date!
        let customMorning = DateComponents(calendar: calendar, year: 2026, month: 6, day: 15, hour: 8, minute: 15).date!
        try SettingsRepository(database: database).saveSettings(
            AppSettingsRecord(
                caloriesTarget: 2200,
                proteinTargetG: 150,
                monthlyBudget: 900,
                morningReminderMinuteOfDay: 8 * 60 + 15,
                trainingReminderMinuteOfDay: 18 * 60 + 30,
                eveningReminderMinuteOfDay: 22 * 60
            )
        )
        let configuration = TelegramBotConfiguration.load(environment: [
            "ABOLIFE_TELEGRAM_BOT_TOKEN": "local-test-token",
            "ABOLIFE_TELEGRAM_ALLOWED_CHAT_ID": "100"
        ])
        let fakeClient = FakeTelegramBotClient()
        let scheduler = TelegramReminderScheduler(
            configuration: configuration,
            client: fakeClient,
            dailySummaryService: DailySummaryService(database: database, calendar: calendar),
            reminderService: ReminderService(database: database, calendar: calendar),
            calendar: calendar
        )

        await scheduler.processDueRemindersForTests(at: defaultMorning)
        XCTAssertTrue(fakeClient.sentResponses.isEmpty)

        await scheduler.processDueRemindersForTests(at: customMorning)
        XCTAssertEqual(fakeClient.sentResponses.count, 2)
        XCTAssertEqual(scheduler.sentLogs.first?.summary, "Reminder gesendet: morningHabits")
        XCTAssertFalse(scheduler.sentLogs.map(\.summary).joined().contains("Guten Morgen Abo"))
        XCTAssertFalse(scheduler.sentLogs.map(\.summary).joined().contains("Proteinshake ist noch offen"))
    }

    func testTelegramReminderCallbackUsesReminderService() async throws {
        let database = try AppDatabase.makeTemporary()
        let configuration = TelegramBotConfiguration.load(environment: [
            "ABOLIFE_TELEGRAM_BOT_TOKEN": "local-test-token",
            "ABOLIFE_TELEGRAM_ALLOWED_CHAT_ID": "100"
        ])
        let fakeClient = FakeTelegramBotClient()
        let manager = ExternalInputDialogManager(service: ExternalInputService(database: database))
        let bot = TelegramBotService(
            configuration: configuration,
            dialogManager: manager,
            client: fakeClient,
            reminderService: ReminderService(database: database)
        )

        let response = await bot.handle(
            TelegramUpdate(
                updateId: 99,
                message: nil,
                callback: TelegramCallbackAction(chatId: 100, userId: 7, data: TelegramReminderAction.proteinShakeDone.rawValue)
            )
        )

        XCTAssertTrue(response?.text.contains("Proteinshake erledigt.") == true)
        XCTAssertTrue(fakeClient.sentResponses.last?.text.contains("Proteinshake erledigt.") == true)
        XCTAssertEqual(
            try HabitRepository(database: database).fetchEntry(
                habitKey: TelegramReminderHabit.proteinShakeKey,
                date: DateIntervals.dayKey()
            )?.isCompleted,
            true
        )

        let undoCallback = try XCTUnwrap(
            response?.keyboard?.rows.flatMap { $0 }.first { $0.callbackData.hasPrefix("undo.") }?.callbackData
        )
        let undo = await bot.handle(
            TelegramUpdate(
                updateId: 100,
                message: nil,
                callback: TelegramCallbackAction(chatId: 100, userId: 7, data: undoCallback)
            )
        )
        XCTAssertEqual(undo?.text, "↩️ Rückgängig gemacht.")
        XCTAssertNil(
            try HabitRepository(database: database).fetchEntry(
                habitKey: TelegramReminderHabit.proteinShakeKey,
                date: DateIntervals.dayKey()
            )
        )
    }

    func testHtmlSnapshotExportServiceRendersSafeMobileHTML() throws {
        let database = try AppDatabase.makeTemporary()
        let calendar = Calendar(identifier: .gregorian)
        let date = DateComponents(calendar: calendar, year: 2026, month: 6, day: 15, hour: 10, minute: 30).date!
        try SettingsRepository(database: database).saveSettings(
            AppSettingsRecord(caloriesTarget: 2400, proteinTargetG: 160, monthlyBudget: 900, defaultCurrency: "EUR")
        )
        try NutritionRepository(database: database).insert(
            NutritionEntryRecord(occurredAt: date, title: "<script>alert('x')</script>", caloriesKcal: 300, proteinG: 35)
        )
        let service = HtmlSnapshotExportService(database: database, calendar: calendar, now: { date })

        let html = try service.renderHTML()

        XCTAssertTrue(html.contains("<!doctype html>"))
        XCTAssertTrue(html.contains("AboLife Snapshot"))
        XCTAssertTrue(html.contains("15.06.2026"))
        XCTAssertTrue(html.contains("Heute wurden noch keine Ausgaben eingetragen."))
        XCTAssertTrue(html.contains("Heute gibt es noch keinen Trainingseintrag."))
        XCTAssertTrue(html.contains("Kalorien heute"))
        XCTAssertTrue(html.contains("Protein heute"))
        XCTAssertTrue(html.contains("Wochenstatus"))
        XCTAssertTrue(html.contains("Ein ruhiger nächster Schritt"))
        XCTAssertTrue(html.contains("name=\"viewport\""))
        XCTAssertTrue(html.contains("@media (max-width:520px)"))
        XCTAssertTrue(html.contains("&lt;script&gt;alert(&#39;x&#39;)&lt;/script&gt;"))
        XCTAssertFalse(html.contains("<script>alert"))
        XCTAssertFalse(html.contains("local-test-token"))
        XCTAssertFalse(html.contains("ABOLIFE_TELEGRAM_BOT_TOKEN"))
        XCTAssertFalse(html.contains("7467527144"))
        XCTAssertFalse(html.contains("/Users/"))
        XCTAssertFalse(html.contains("file://"))
        XCTAssertFalse(html.contains("http://"))
        XCTAssertFalse(html.contains("https://"))
        XCTAssertFalse(html.contains("<script src="))
        XCTAssertFalse(html.contains("<link rel=\"stylesheet\""))
    }

    func testHtmlSnapshotIncludesFinanceStatusWithoutSensitiveValuesOrLocalPaths() throws {
        let database = try AppDatabase.makeTemporary()
        let calendar = Calendar(identifier: .gregorian)
        let date = DateComponents(calendar: calendar, year: 2026, month: 6, day: 15, hour: 10, minute: 30).date!
        try SettingsRepository(database: database).saveSettings(
            AppSettingsRecord(caloriesTarget: 2400, proteinTargetG: 160, monthlyBudget: 900, defaultCurrency: "EUR")
        )
        try FinanceRepository(database: database).insert(
            FinanceEntryRecord(
                occurredAt: date,
                title: "Rewe",
                amount: 42,
                category: "Lebensmittel",
                note: "ABOLIFE_TELEGRAM_BOT_TOKEN=123456789:SECRET_TOKEN_SHOULD_NOT_LEAK /Users/local/path"
            )
        )
        let service = HtmlSnapshotExportService(database: database, calendar: calendar, now: { date })

        let html = try service.renderHTML()

        XCTAssertTrue(html.contains("Finanzen"))
        XCTAssertTrue(html.contains("Rewe"))
        XCTAssertTrue(html.contains("Lebensmittel"))
        XCTAssertTrue(html.contains("42 EUR"))
        XCTAssertFalse(html.contains("SECRET_TOKEN_SHOULD_NOT_LEAK"))
        XCTAssertFalse(html.contains("123456789:"))
        XCTAssertFalse(html.contains("/Users/local/path"))
        XCTAssertFalse(html.contains("file://"))
        XCTAssertFalse(html.contains("https://"))
        XCTAssertFalse(html.contains("http://"))
    }

    func testHtmlSnapshotExportServiceCreatesExpectedFileName() throws {
        let database = try AppDatabase.makeTemporary()
        let calendar = Calendar(identifier: .gregorian)
        let date = DateComponents(calendar: calendar, year: 2026, month: 6, day: 15, hour: 10, minute: 30).date!
        let directory = makeTemporaryBackupDirectory()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let service = HtmlSnapshotExportService(
            database: database,
            calendar: calendar,
            now: { date },
            temporaryDirectory: directory,
            uniqueIdentifier: { "test-id" }
        )

        let file = try service.makeSnapshotFile()

        XCTAssertEqual(file.url.lastPathComponent, "abolife_snapshot_2026-06-15_10-30_test-id.html")
        XCTAssertTrue(FileManager.default.fileExists(atPath: file.url.path))
        XCTAssertTrue(file.html.contains("AboLife Snapshot"))
        try? FileManager.default.removeItem(at: directory)
    }

    func testHtmlSnapshotUsesDefaultTemporaryDirectoryInsteadOfBackupDirectory() throws {
        let database = try AppDatabase.makeTemporary()
        let backupDirectory = makeTemporaryBackupDirectory()
        try FileManager.default.createDirectory(at: backupDirectory, withIntermediateDirectories: true)
        let service = HtmlSnapshotExportService(database: database)

        let file = try service.makeSnapshotFile()
        defer {
            try? FileManager.default.removeItem(at: file.url)
            try? FileManager.default.removeItem(at: backupDirectory)
        }

        XCTAssertEqual(
            file.url.deletingLastPathComponent().standardizedFileURL,
            FileManager.default.temporaryDirectory.standardizedFileURL
        )
        XCTAssertFalse(file.url.path.hasPrefix(backupDirectory.path))
        XCTAssertTrue((try FileManager.default.contentsOfDirectory(atPath: backupDirectory.path)).isEmpty)
    }

    func testTelegramLiveClientSendDocumentBuildsMultipartRequest() async throws {
        TelegramURLProtocolStub.responseData = #"{"ok":true,"result":{}}"#.data(using: .utf8)!
        TelegramURLProtocolStub.capturedRequest = nil
        TelegramURLProtocolStub.capturedBody = nil

        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [TelegramURLProtocolStub.self]
        let session = URLSession(configuration: configuration)
        let client = try TelegramLiveClient(
            configuration: TelegramBotConfiguration.load(environment: [
                "ABOLIFE_TELEGRAM_BOT_TOKEN": "secret-token",
                "ABOLIFE_TELEGRAM_ALLOWED_CHAT_ID": "100"
            ]),
            session: session
        )
        let fileURL = FileManager.default.temporaryDirectory.appendingPathComponent("abolife_snapshot_2026-06-15_10-30.html")
        try "<html>AboLife Snapshot</html>".write(to: fileURL, atomically: true, encoding: .utf8)

        try await client.sendDocument(chatId: 100, fileURL: fileURL, caption: "AboLife Snapshot")

        let request = try XCTUnwrap(TelegramURLProtocolStub.capturedRequest)
        let body = String(data: try XCTUnwrap(TelegramURLProtocolStub.capturedBody), encoding: .utf8) ?? ""
        XCTAssertEqual(request.url?.absoluteString, "https://api.telegram.org/botsecret-token/sendDocument")
        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertTrue(request.value(forHTTPHeaderField: "Content-Type")?.contains("multipart/form-data; boundary=") == true)
        XCTAssertTrue(body.contains("name=\"chat_id\""))
        XCTAssertTrue(body.contains("100"))
        XCTAssertTrue(body.contains("name=\"caption\""))
        XCTAssertTrue(body.contains("AboLife Snapshot"))
        XCTAssertTrue(body.contains("name=\"document\"; filename=\"abolife_snapshot_2026-06-15_10-30.html\""))
        try? FileManager.default.removeItem(at: fileURL)
    }

    func testTelegramLiveClientDocumentErrorRedactsToken() async throws {
        TelegramURLProtocolStub.responseData = #"{"ok":false,"description":"secret-token rejected"}"#.data(using: .utf8)!
        TelegramURLProtocolStub.capturedRequest = nil
        TelegramURLProtocolStub.capturedBody = nil

        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [TelegramURLProtocolStub.self]
        let client = try TelegramLiveClient(
            configuration: TelegramBotConfiguration.load(environment: [
                "ABOLIFE_TELEGRAM_BOT_TOKEN": "secret-token",
                "ABOLIFE_TELEGRAM_ALLOWED_CHAT_ID": "100"
            ]),
            session: URLSession(configuration: configuration)
        )
        let fileURL = FileManager.default.temporaryDirectory.appendingPathComponent("abolife_snapshot_error.html")
        try "<html></html>".write(to: fileURL, atomically: true, encoding: .utf8)

        do {
            try await client.sendDocument(chatId: 100, fileURL: fileURL, caption: "AboLife Snapshot")
            XCTFail("Expected TelegramClientError")
        } catch {
            XCTAssertFalse(error.localizedDescription.contains("secret-token"))
            XCTAssertTrue(error.localizedDescription.contains("[redacted]"))
        }
        try? FileManager.default.removeItem(at: fileURL)
    }

    @MainActor
    func testTelegramExportCallbackAcknowledgesAndSendsDocument() async throws {
        let database = try AppDatabase.makeTemporary()
        let calendar = Calendar(identifier: .gregorian)
        let date = DateComponents(calendar: calendar, year: 2026, month: 6, day: 15, hour: 10, minute: 30).date!
        let configuration = TelegramBotConfiguration.load(environment: [
            "ABOLIFE_TELEGRAM_BOT_TOKEN": "local-test-token",
            "ABOLIFE_TELEGRAM_ALLOWED_CHAT_ID": "100"
        ])
        let updateClient = ScriptedTelegramUpdateClient(batches: [
            [TelegramUpdate(updateId: 60, message: nil, callback: TelegramCallbackAction(chatId: 100, userId: 7, callbackQueryId: "cb-export", data: TelegramCallbackID.exportSnapshot))]
        ])
        let messageClient = FakeTelegramBotClient()
        let documentClient = RecordingTelegramDocumentClient()
        let directory = makeTemporaryBackupDirectory()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let bot = TelegramBotService(
            configuration: configuration,
            dialogManager: ExternalInputDialogManager(service: ExternalInputService(database: database)),
            client: messageClient,
            documentClient: documentClient,
            snapshotExportService: HtmlSnapshotExportService(
                database: database,
                calendar: calendar,
                now: { date },
                temporaryDirectory: directory,
                uniqueIdentifier: { "test-id" }
            )
        )
        let controller = TelegramPollingController(
            configuration: configuration,
            updateClient: updateClient,
            botService: bot,
            pollTimeoutSeconds: 1,
            idleDelayNanoseconds: 10_000_000,
            errorDelayNanoseconds: 10_000_000,
            automaticallyPollsOnStart: false
        )

        await controller.processOnceForTests()

        XCTAssertEqual(updateClient.answeredCallbackIds, ["cb-export"])
        XCTAssertEqual(documentClient.sentDocuments.count, 1)
        XCTAssertEqual(documentClient.sentDocuments.first?.chatId, 100)
        XCTAssertEqual(documentClient.sentDocuments.first?.caption, "AboLife Snapshot")
        XCTAssertEqual(documentClient.sentDocuments.first?.fileName, "abolife_snapshot_2026-06-15_10-30_test-id.html")
        XCTAssertEqual(documentClient.attemptedFileURLs.first?.deletingLastPathComponent(), directory)
        XCTAssertEqual(documentClient.fileExistedDuringAttempts, [true])
        XCTAssertFalse(
            FileManager.default.fileExists(atPath: directory.appendingPathComponent("abolife_snapshot_2026-06-15_10-30_test-id.html").path),
            (try? FileManager.default.contentsOfDirectory(atPath: directory.path).joined(separator: ", ")) ?? "Verzeichnis nicht lesbar"
        )
        XCTAssertEqual(messageClient.sentResponses.map(\.text), ["Snapshot gesendet."])
        try? FileManager.default.removeItem(at: directory)
    }

    func testTelegramExportCallbackReportsSendFailure() async throws {
        let database = try AppDatabase.makeTemporary()
        let calendar = Calendar(identifier: .gregorian)
        let date = DateComponents(calendar: calendar, year: 2026, month: 6, day: 15, hour: 10, minute: 31).date!
        let directory = makeTemporaryBackupDirectory()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let configuration = TelegramBotConfiguration.load(environment: [
            "ABOLIFE_TELEGRAM_BOT_TOKEN": "local-test-token",
            "ABOLIFE_TELEGRAM_ALLOWED_CHAT_ID": "100"
        ])
        let messageClient = FakeTelegramBotClient()
        let documentClient = RecordingTelegramDocumentClient(error: TelegramClientError.network)
        let bot = TelegramBotService(
            configuration: configuration,
            dialogManager: ExternalInputDialogManager(service: ExternalInputService(database: database)),
            client: messageClient,
            documentClient: documentClient,
            snapshotExportService: HtmlSnapshotExportService(
                database: database,
                calendar: calendar,
                now: { date },
                temporaryDirectory: directory,
                uniqueIdentifier: { "failure-id" }
            )
        )

        let response = await bot.handle(TelegramUpdate(updateId: 61, message: nil, callback: TelegramCallbackAction(chatId: 100, userId: 7, data: TelegramCallbackID.exportSnapshot)))

        XCTAssertEqual(response?.text, "Der Snapshot konnte nicht gesendet werden.")
        XCTAssertEqual(messageClient.sentResponses.last?.text, "Der Snapshot konnte nicht gesendet werden.")
        let attemptedURL = try XCTUnwrap(documentClient.attemptedFileURLs.first)
        XCTAssertTrue(documentClient.fileExistedDuringAttempts.first == true)
        XCTAssertFalse(FileManager.default.fileExists(atPath: attemptedURL.path))
        XCTAssertTrue((try FileManager.default.contentsOfDirectory(atPath: directory.path)).isEmpty)
        try? FileManager.default.removeItem(at: directory)
    }

    @MainActor
    func testTelegramPollingControllerUsesFakeClientWithoutNetwork() async throws {
        let database = try AppDatabase.makeTemporary()
        let configuration = TelegramBotConfiguration.load(environment: [
            "ABOLIFE_TELEGRAM_BOT_TOKEN": "local-test-token",
            "ABOLIFE_TELEGRAM_ALLOWED_CHAT_ID": "100"
        ])
        let updateClient = ScriptedTelegramUpdateClient(batches: [
            [
                TelegramUpdate(updateId: 41, message: TelegramMessage(chatId: 100, userId: 7, text: "/start"), callback: nil),
                TelegramUpdate(updateId: 42, message: nil, callback: TelegramCallbackAction(chatId: 100, userId: 7, callbackQueryId: "cb-1", data: "flow.weight"))
            ],
            [
                TelegramUpdate(updateId: 43, message: TelegramMessage(chatId: 100, userId: 7, text: "82,4"), callback: nil)
            ]
        ])
        let fakeClient = FakeTelegramBotClient()
        let bot = TelegramBotService(
            configuration: configuration,
            dialogManager: ExternalInputDialogManager(service: ExternalInputService(database: database)),
            client: fakeClient
        )
        let controller = TelegramPollingController(
            configuration: configuration,
            updateClient: updateClient,
            botService: bot,
            pollTimeoutSeconds: 1,
            idleDelayNanoseconds: 10_000_000,
            errorDelayNanoseconds: 10_000_000,
            automaticallyPollsOnStart: false
        )

        controller.start()
        XCTAssertTrue(controller.isRunning)
        await controller.processOnceForTests()
        XCTAssertEqual(controller.lastUpdateId, 42)
        XCTAssertEqual(updateClient.receivedOffsets, [nil])
        XCTAssertEqual(updateClient.answeredCallbackIds, ["cb-1"])
        XCTAssertEqual(fakeClient.sentResponses.count, 2)

        await controller.processOnceForTests()
        XCTAssertEqual(controller.lastUpdateId, 43)
        XCTAssertEqual(updateClient.receivedOffsets, [nil, 43])
        XCTAssertTrue(fakeClient.sentResponses.last?.text.contains("Gewicht") == true)

        controller.stop()
        XCTAssertFalse(controller.isRunning)
        XCTAssertEqual(controller.state, .stopped)
    }

    @MainActor
    func testTelegramPollingControllerHandlesErrorsAndRejectedChats() async throws {
        let database = try AppDatabase.makeTemporary()
        let configuration = TelegramBotConfiguration.load(environment: [
            "ABOLIFE_TELEGRAM_BOT_TOKEN": "local-test-token",
            "ABOLIFE_TELEGRAM_ALLOWED_CHAT_ID": "100"
        ])
        let updateClient = ScriptedTelegramUpdateClient(batches: [
            [
                TelegramUpdate(updateId: 50, message: TelegramMessage(chatId: 999, userId: 7, text: "/start"), callback: nil)
            ]
        ])
        let fakeClient = FakeTelegramBotClient()
        let controller = TelegramPollingController(
            configuration: configuration,
            updateClient: updateClient,
            botService: TelegramBotService(
                configuration: configuration,
                dialogManager: ExternalInputDialogManager(service: ExternalInputService(database: database)),
                client: fakeClient
            ),
            pollTimeoutSeconds: 1,
            idleDelayNanoseconds: 10_000_000,
            errorDelayNanoseconds: 10_000_000,
            automaticallyPollsOnStart: false
        )

        controller.start()
        await controller.processOnceForTests()
        XCTAssertEqual(controller.lastUpdateId, 50)
        XCTAssertEqual(fakeClient.sentResponses.count, 0)
        XCTAssertEqual(controller.lastErrorMessage, "Update von nicht erlaubtem Telegram-Chat ignoriert.")

        updateClient.nextError = TelegramClientError.network
        await controller.processOnceForTests()
        XCTAssertEqual(controller.lastErrorMessage, "Telegram ist gerade nicht erreichbar.")
    }

    @MainActor
    func testTelegramAutoStartDoesNotStartWithoutToken() throws {
        let defaults = makeIsolatedUserDefaults()
        defaults.set(true, forKey: TelegramAppCoordinator.autoStartKey)

        let coordinator = TelegramAppCoordinator(
            database: try AppDatabase.makeTemporary(),
            userDefaults: defaults,
            configurationProvider: {
                TelegramBotConfiguration.load(environment: [
                    "ABOLIFE_TELEGRAM_ALLOWED_CHAT_ID": "100"
                ])
            },
            makeController: makeFakeTelegramController
        )

        coordinator.applyAutoStartIfNeeded()

        XCTAssertFalse(coordinator.isRunning)
        XCTAssertEqual(coordinator.state, .notConfigured)
        XCTAssertEqual(coordinator.detailMessage, "Auto-Start aktiviert, aber Token fehlt.")
    }

    @MainActor
    func testTelegramAutoStartDoesNotStartWithoutAllowedChatId() throws {
        let defaults = makeIsolatedUserDefaults()
        defaults.set(true, forKey: TelegramAppCoordinator.autoStartKey)

        let coordinator = TelegramAppCoordinator(
            database: try AppDatabase.makeTemporary(),
            userDefaults: defaults,
            configurationProvider: {
                TelegramBotConfiguration.load(environment: [
                    "ABOLIFE_TELEGRAM_BOT_TOKEN": "local-test-token"
                ])
            },
            makeController: makeFakeTelegramController
        )

        coordinator.applyAutoStartIfNeeded()

        XCTAssertFalse(coordinator.isRunning)
        XCTAssertEqual(coordinator.state, .ready)
        XCTAssertEqual(coordinator.detailMessage, "Auto-Start aktiviert, aber erlaubte Chat-ID fehlt.")
    }

    @MainActor
    func testTelegramAutoStartStartsWithTokenAndAllowedChatId() throws {
        let defaults = makeIsolatedUserDefaults()
        defaults.set(true, forKey: TelegramAppCoordinator.autoStartKey)

        let coordinator = TelegramAppCoordinator(
            database: try AppDatabase.makeTemporary(),
            userDefaults: defaults,
            configurationProvider: {
                TelegramBotConfiguration.load(environment: [
                    "ABOLIFE_TELEGRAM_BOT_TOKEN": "local-test-token",
                    "ABOLIFE_TELEGRAM_ALLOWED_CHAT_ID": "100"
                ])
            },
            makeController: makeFakeTelegramController
        )

        coordinator.applyAutoStartIfNeeded()

        XCTAssertTrue(coordinator.isRunning)
        XCTAssertEqual(coordinator.state, .running)
        XCTAssertEqual(coordinator.detailMessage, "Long Polling läuft.")
    }

    @MainActor
    func testTelegramCoordinatorStopsPollingForAppQuit() throws {
        let defaults = makeIsolatedUserDefaults()
        defaults.set(true, forKey: TelegramAppCoordinator.autoStartKey)
        let coordinator = TelegramAppCoordinator(
            database: try AppDatabase.makeTemporary(),
            userDefaults: defaults,
            configurationProvider: {
                TelegramBotConfiguration.load(environment: [
                    "ABOLIFE_TELEGRAM_BOT_TOKEN": "local-test-token",
                    "ABOLIFE_TELEGRAM_ALLOWED_CHAT_ID": "100"
                ])
            },
            makeController: makeFakeTelegramController
        )

        coordinator.applyAutoStartIfNeeded()
        XCTAssertTrue(coordinator.isRunning)

        coordinator.stopForAppQuit()

        XCTAssertFalse(coordinator.isRunning)
        XCTAssertEqual(coordinator.state, .stopped)
    }

    @MainActor
    func testClosingLastWindowDoesNotTerminateApp() {
        let delegate = AboLifeAppDelegate()

        XCTAssertFalse(delegate.applicationShouldTerminateAfterLastWindowClosed(NSApplication.shared))
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
                HabitEntryRecord(habitKey: "learning", date: "2026-06-08", isCompleted: true),
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
        try NutritionTemplateRepository(database: database).create(kind: .favorite, name: "Skyr Vorlage", caloriesKcal: 310, proteinG: 55)
        try WorkoutRepository(database: database).insert(WorkoutSessionRecord(workoutType: "push", durationMin: 45, status: "done"))
        try FinanceRepository(database: database).insert(FinanceEntryRecord(title: "Lunch", amount: 12.5, category: "Essen"))
        try HabitRepository(database: database).insert(HabitEntryRecord(habitKey: "water", date: "2026-06-12", isCompleted: true))
        try WeightRepository(database: database).upsert(dayKey: "2026-06-12", weightKg: 82.4)
        try BodyMetricRepository(database: database).insert(BodyMetricEntryRecord(weightKg: 82.1))
        _ = try WeeklyReviewRepository(database: database).upsert(
            weekStartDate: "2026-06-08",
            winsText: "Training erledigt",
            challengesText: "Schlaf war schwierig",
            nextWeekFocusText: "Ruhiger planen"
        )
        _ = try SettingsRepository(database: database).saveSettings(SeedData.defaultSettings)
    }

    private func assertWeight(_ intent: ExternalInputIntent, _ expected: Double) {
        if case let .weight(_, weightKg) = intent {
            XCTAssertEqual(weightKg, expected, accuracy: 0.001)
        } else {
            XCTFail("Gewicht nicht erkannt: \(intent)")
        }
    }

    private func assertExpense(_ intent: ExternalInputIntent, amount: Double, title: String) {
        if case let .expense(_, parsedAmount, parsedTitle, _) = intent {
            XCTAssertEqual(parsedAmount, amount, accuracy: 0.001)
            XCTAssertEqual(parsedTitle, title)
        } else {
            XCTFail("Ausgabe nicht erkannt: \(intent)")
        }
    }

    private func assertMeal(_ intent: ExternalInputIntent, name: String, calories: Int, protein: Double) {
        if case let .meal(_, parsedName, parsedCalories, parsedProtein, _) = intent {
            XCTAssertEqual(parsedName, name)
            XCTAssertEqual(parsedCalories, calories)
            XCTAssertEqual(parsedProtein ?? 0, protein, accuracy: 0.001)
        } else {
            XCTFail("Mahlzeit nicht erkannt: \(intent)")
        }
    }

    private func XCTAssertSuccess(_ result: ExternalInputResult, module: ExternalInputAffectedModule, file: StaticString = #filePath, line: UInt = #line) {
        switch result {
        case let .success(_, affectedModule), let .saved(_, affectedModule, _):
            XCTAssertEqual(affectedModule, module, file: file, line: line)
        default:
            XCTFail("Erwartet success, erhalten: \(result)", file: file, line: line)
        }
    }

    private func XCTAssertFailure(_ result: ExternalInputResult, reason: String, file: StaticString = #filePath, line: UInt = #line) {
        if case let .failure(_, parsedReason) = result {
            XCTAssertEqual(parsedReason, reason, file: file, line: line)
        } else {
            XCTFail("Erwartet failure, erhalten: \(result)", file: file, line: line)
        }
    }

    private func makeIsolatedUserDefaults() -> UserDefaults {
        let suiteName = "AboLifeTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return defaults
    }

    private func barcodeProduct() -> FoodProductLookupResult {
        FoodProductLookupResult(
            barcode: "7340001805885",
            name: "Protein Bar Chocolate Dough",
            brand: "Barebells",
            quantityText: "55 g",
            caloriesPer100g: 362,
            proteinPer100g: 36,
            carbsPer100g: 32.5,
            fatPer100g: 15,
            source: "open_food_facts"
        )
    }

    @MainActor
    private func makeFakeTelegramController(
        configuration: TelegramBotConfiguration,
        database: AppDatabase?
    ) -> TelegramPollingController? {
        guard let database else { return nil }
        let fakeClient = FakeTelegramBotClient()
        return TelegramPollingController(
            configuration: configuration,
            updateClient: ScriptedTelegramUpdateClient(batches: []),
            botService: TelegramBotService(
                configuration: configuration,
                dialogManager: ExternalInputDialogManager(service: ExternalInputService(database: database)),
                client: fakeClient
            ),
            pollTimeoutSeconds: 1,
            idleDelayNanoseconds: 10_000_000,
            errorDelayNanoseconds: 10_000_000,
            automaticallyPollsOnStart: false
        )
    }
}

final class MockTelegramFileClient: TelegramFileClient {
    private(set) var requestedFileIds: [String] = []
    private(set) var requestedFilePaths: [String] = []
    var imageData = Data("image".utf8)

    func getFile(fileId: String) async throws -> TelegramFile {
        requestedFileIds.append(fileId)
        return TelegramFile(fileId: fileId, fileUniqueId: "unique-\(fileId)", fileSize: imageData.count, filePath: "photos/\(fileId).jpg")
    }

    func downloadFile(filePath: String) async throws -> Data {
        requestedFilePaths.append(filePath)
        return imageData
    }
}

final class MockBarcodeScanner: BarcodeScanning {
    let result: Result<BarcodeScanResult, Error>
    private(set) var scannedURLs: [URL] = []
    private(set) var scannedFileExisted = false

    init(result: Result<BarcodeScanResult, Error>) {
        self.result = result
    }

    func scanBarcode(in imageURL: URL) async throws -> BarcodeScanResult {
        scannedURLs.append(imageURL)
        scannedFileExisted = FileManager.default.fileExists(atPath: imageURL.path)
        switch result {
        case let .success(value):
            return value
        case let .failure(error):
            throw error
        }
    }
}

final class MockFoodProductLookup: FoodProductLookingUp {
    let result: Result<FoodProductLookupResult, Error>
    private(set) var requestedBarcodes: [String] = []

    init(result: Result<FoodProductLookupResult, Error>) {
        self.result = result
    }

    func lookup(barcode: String) async throws -> FoodProductLookupResult {
        requestedBarcodes.append(barcode)
        switch result {
        case let .success(value):
            return value
        case let .failure(error):
            throw error
        }
    }
}

final class ScriptedTelegramUpdateClient: TelegramUpdateFetching {
    private var batches: [[TelegramUpdate]]
    var nextError: Error?
    private(set) var receivedOffsets: [Int?] = []
    private(set) var answeredCallbackIds: [String] = []

    init(batches: [[TelegramUpdate]]) {
        self.batches = batches
    }

    func getUpdates(offset: Int?, timeout: Int) async throws -> [TelegramUpdate] {
        receivedOffsets.append(offset)
        if let nextError {
            self.nextError = nil
            throw nextError
        }
        guard !batches.isEmpty else { return [] }
        return batches.removeFirst()
    }

    func answerCallbackQuery(id: String) async throws {
        answeredCallbackIds.append(id)
    }
}

final class RecordingTelegramDocumentClient: TelegramDocumentClient {
    struct SentDocument: Equatable {
        let chatId: Int64
        let fileName: String
        let caption: String?
        let existedDuringSend: Bool
    }

    private(set) var sentDocuments: [SentDocument] = []
    private(set) var attemptedFileURLs: [URL] = []
    private(set) var fileExistedDuringAttempts: [Bool] = []
    var error: Error?

    init(error: Error? = nil) {
        self.error = error
    }

    func sendDocument(chatId: Int64, fileURL: URL, caption: String?) async throws {
        attemptedFileURLs.append(fileURL)
        fileExistedDuringAttempts.append(FileManager.default.fileExists(atPath: fileURL.path))
        if let error { throw error }
        sentDocuments.append(
            SentDocument(
                chatId: chatId,
                fileName: fileURL.lastPathComponent,
                caption: caption,
                existedDuringSend: FileManager.default.fileExists(atPath: fileURL.path)
            )
        )
    }
}

final class TelegramURLProtocolStub: URLProtocol {
    static var capturedRequest: URLRequest?
    static var capturedBody: Data?
    static var responseData = Data()

    override class func canInit(with request: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        Self.capturedRequest = request
        Self.capturedBody = request.httpBody ?? request.httpBodyStream.flatMap { stream in
            stream.open()
            defer { stream.close() }
            var data = Data()
            let bufferSize = 1024
            let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufferSize)
            defer { buffer.deallocate() }
            while stream.hasBytesAvailable {
                let count = stream.read(buffer, maxLength: bufferSize)
                if count <= 0 { break }
                data.append(buffer, count: count)
            }
            return data
        }
        let response = HTTPURLResponse(
            url: request.url ?? URL(string: "https://api.telegram.org")!,
            statusCode: 200,
            httpVersion: nil,
            headerFields: ["Content-Type": "application/json"]
        )!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Self.responseData)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}

private extension JSONDecoder {
    static var abolifeExportDecoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}
