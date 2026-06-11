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
        XCTAssertEqual(habits.valueText, "3 / 5")
    }
}
