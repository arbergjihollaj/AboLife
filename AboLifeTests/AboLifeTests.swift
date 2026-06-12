import XCTest
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
}
