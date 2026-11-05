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
        XCTAssertEqual(QuickAddAction.bottomDockActions.map(\.kind), [.workout, .expense, .habit])
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
            FinanceEntryRecord(title: "Rewe", amount: 9, category: "Lebensmittel")
        )

        let store = DashboardStore(database: database)

        XCTAssertEqual(store.snapshot.finance.spentThisMonth, 9, accuracy: 0.001)
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
        XCTAssertEqual(store.applyHabitDelta(habitKey: "learning", delta: 15), 15, accuracy: 0.001)
        store.setSleepRoutine(isCompleted: true)

        let repository = HabitRepository(database: database)
        XCTAssertEqual(try repository.fetchEntry(habitKey: "water", date: date)?.value ?? 0, 0.25, accuracy: 0.001)
        XCTAssertEqual(try repository.fetchEntry(habitKey: "learning", date: date)?.value ?? 0, 15, accuracy: 0.001)
        XCTAssertEqual(try repository.fetchEntry(habitKey: "sleep", date: date)?.value ?? 0, 1, accuracy: 0.001)
        XCTAssertEqual(try repository.fetchEntry(habitKey: "sleep", date: date)?.isCompleted, true)
    }

    func testFixedHabitDefinitionsUseTrainingInsteadOfMovement() {
        let keys = FixedHabit.defaults.map(\.key)
        let training = FixedHabit.defaultDefinition(for: "training")

        XCTAssertEqual(keys, ["water", "training", "learning", "sleep"])
        XCTAssertFalse(keys.contains("movement"))
        XCTAssertEqual(training?.title, "Trainieren")
        XCTAssertEqual(training?.targetValue, 1)
        XCTAssertEqual(training?.kind, .derived)
        XCTAssertEqual(training?.isDerived, true)
    }

    func testQuickHabitActionsDoNotContainMovement() {
        let actionKeys = QuickHabitAction.generalMenuActions.map(\.habitKey)

        XCTAssertEqual(actionKeys, ["water", "learning", "sleep"])
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
        let nutritionInsight = store.insights.first { $0.title == "Ernährung" }

        XCTAssertNil(store.errorMessage)
        XCTAssertNil(nutritionInsight)
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
        XCTAssertEqual(summary.total, 3)
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

        let expected = (0.5 + 1 + 0.25 + 0) / 4.0
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
        XCTAssertEqual(summary.total, 21)
        XCTAssertEqual(summary.progress, 2.0 / 21.0, accuracy: 0.001)
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

        XCTAssertEqual(fixture.trends.spendingByDay.count, 7)
        XCTAssertEqual(fixture.trends.trainingMinutesByDay.count, 7)
        XCTAssertEqual(fixture.trends.habitCompletionByDay.count, 7)
        XCTAssertEqual(fixture.trends.spendingByDay.map { DateIntervals.dayKey(for: $0.date, calendar: fixture.calendar) }, [
            "2026-06-08",
            "2026-06-09",
            "2026-06-10",
            "2026-06-11",
            "2026-06-12",
            "2026-06-13",
            "2026-06-14"
        ])
    }

    func testWeeklyReviewTrendsSumsFinanceAndTrainingByDay() {
        let trends = makeWeeklyReviewTrendsFixture().trends

        XCTAssertEqual(trends.spendingByDay.map(\.value), [0, 20, 0, 0, 0, 0, 0])
        XCTAssertEqual(trends.trainingMinutesByDay.map(\.value), [45, 0, 0, 0, 50, 0, 0])
    }

    func testWeeklyReviewTrendsCalculatesHabitCompletionPercentages() {
        let trends = makeWeeklyReviewTrendsFixture().trends

        XCTAssertEqual(trends.habitCompletionByDay[0].value, 75, accuracy: 0.001)
        XCTAssertEqual(trends.habitCompletionByDay[1].value, 0, accuracy: 0.001)
        XCTAssertEqual(trends.habitCompletionByDay[2].value, 25, accuracy: 0.001)
        XCTAssertEqual(trends.habitCompletionByDay[4].value, 25, accuracy: 0.001)
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

        XCTAssertEqual(trends.habitCompletionByDay[0].value, 25, accuracy: 0.001)
        XCTAssertEqual(trends.habitCompletionByDay[1].value, 0, accuracy: 0.001)
    }

    func testWeeklyReviewTrendsEmptyWeekKeepsZeroValues() {
        let fixture = makeWeeklyReviewTrendsFixture()
        let empty = WeeklyReviewTrends.empty(for: fixture.interval, calendar: fixture.calendar)

        XCTAssertFalse(empty.hasAnyData)
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

        store.addExpense(title: "Lunch", amount: 12, category: "Essen")
        store.completeWorkout(type: "Push Day", durationMinutes: 45)

        let waterHabitID = store.state.habits.first { $0.key == "water" }!.id
        store.toggleHabit(waterHabitID)

        let restartedStore = DashboardStore(database: database)

        XCTAssertEqual(restartedStore.snapshot.finance.spentThisMonth, 12, accuracy: 0.001)
        XCTAssertEqual(restartedStore.state.weeklyWorkoutCompleted, 1)
        XCTAssertEqual(restartedStore.snapshot.habits.completed, 2)
    }

    func testDashboardHabitSummaryUsesTrainingAndHandlesEmptyHabitEntries() throws {
        let database = try AppDatabase.makeTemporary()

        let store = DashboardStore(database: database)

        XCTAssertEqual(store.snapshot.habits.items.map(\.key), ["water", "training", "learning", "sleep"])
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
        XCTAssertEqual(store.snapshot.habits.progress, 0.25, accuracy: 0.001)
    }

    func testTodaySnapshotServiceCentralizesDailyValues() throws {
        let db = try AppDatabase.makeTemporary()
        try FinanceRepository(database: db).insert(FinanceEntryRecord(title: "Buch", amount: 12, category: "Uni"))
        try WorkoutRepository(database: db).insert(WorkoutSessionRecord(workoutType: "Training", durationMin: 30, status: "done"))
        let snapshot = try TodaySnapshotService(database: db).snapshot()
        XCTAssertEqual(snapshot.spentToday, 12)
        XCTAssertTrue(snapshot.workoutCompletedToday)
        XCTAssertEqual(snapshot.habitValue(for: "training"), 1)
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
        XCTAssertTrue(report.warnings.contains { $0.contains("Zugangsdaten") })
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
        let caloriesSVG = ""
        XCTAssertFalse(FileManager.default.fileExists(atPath: exportDirectory.appendingPathComponent("reports/charts/nutrition_calories_7d.svg").path))
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
        XCTAssertTrue(summaryMarkdown.contains("Zugangsdaten"))
        XCTAssertFalse(reportHTML.contains("https://"))
        XCTAssertFalse(reportHTML.contains("http://"))
        XCTAssertTrue(caloriesSVG.isEmpty)

        XCTAssertEqual(manifest["csvSeparator"] as? String, "semicolon")
        XCTAssertEqual(manifest["decimalSeparator"] as? String, "dot")
        let files = manifest["files"] as! [[String: Any]]
        XCTAssertTrue(files.contains { $0["name"] as? String == "csv/nutrition_entries.csv" && $0["rows"] as? Int == 2 })
        XCTAssertTrue(files.contains { $0["name"] as? String == "csv/finance_monthly_analysis.csv" && $0["rows"] as? Int == 1 })
        XCTAssertTrue(files.contains { $0["name"] as? String == "csv/finance_category_trends.csv" })
        XCTAssertTrue(files.contains { $0["name"] as? String == "reports/overview_report.html" && $0["type"] as? String == "report" })
        XCTAssertTrue(files.contains { $0["name"] as? String == "reports/summary.md" && $0["type"] as? String == "markdown" })
        let charts = manifest["charts"] as! [[String: Any]]
        XCTAssertFalse(charts.contains { $0["name"] as? String == "reports/charts/nutrition_calories_7d.svg" })
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
        XCTAssertTrue(markdown.contains("Zugangsdaten"))
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











    private func makeIsolatedUserDefaults() -> UserDefaults {
        let suiteName = "AboLifeTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return defaults
    }




}

private extension JSONDecoder {
    static var abolifeExportDecoder: JSONDecoder {
        let decoder = JSONDecoder(); decoder.dateDecodingStrategy = .iso8601; return decoder
    }
}
