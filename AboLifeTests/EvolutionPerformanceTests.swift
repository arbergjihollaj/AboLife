import Combine
import GRDB
import XCTest

@testable import AboLife

@MainActor
final class EvolutionPerformanceTests: XCTestCase {
    func testRepresentativeStorePerformance() throws {
        guard let path = ProcessInfo.processInfo.environment["ABOLIFE_PERFORMANCE_REPORT"] else {
            throw XCTSkip("Set ABOLIFE_PERFORMANCE_REPORT to measure isolated stores")
        }
        let database = try AppDatabase.makeTemporary()
        _ = try SettingsRepository(database: database).saveSettings(SeedData.defaultSettings)
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        try database.writer.write { db in
            for index in 0..<5000 {
                let date = calendar.date(byAdding: .day, value: -(index % 180), to: today)!
                try FinanceEntryRecord(
                    occurredAt: date, title: "Fiktiver Eintrag", amount: Double(index % 50 + 1), category: "Freizeit"
                ).insert(db)
            }
            for index in 0..<120 {
                let date = calendar.date(byAdding: .day, value: -index, to: today)!
                try WorkoutSessionRecord(occurredAt: date, workoutType: "Test", durationMin: 30, status: "done").insert(
                    db)
            }
        }
        let dashboard = DashboardStore(database: database)
        let finance = FinanceStore(database: database)
        let statistics = StatisticsStore(database: database)
        func measure(_ operation: () -> Void) -> [String: Double] {
            var values: [Double] = []
            for _ in 0..<20 {
                let start = DispatchTime.now().uptimeNanoseconds
                operation()
                values.append(Double(DispatchTime.now().uptimeNanoseconds - start) / 1_000_000)
            }
            values.sort()
            return ["median_ms": values[10], "p95_ms": values[18], "max_ms": values[19]]
        }
        var publications = 0
        let observation = dashboard.$state.dropFirst().sink { _ in publications += 1 }
        dashboard.refreshFromPersistence()
        observation.cancel()
        let dashboardMetrics = measure(dashboard.refreshFromPersistence)
        let financeMetrics = measure(finance.reload)
        let statisticsMetrics = measure(statistics.reload)
        let result: [String: Any] = [
            "fixture": "5000 finance entries, 120 workouts, temporary SQLite",
            "iterations": 20,
            "dashboard": dashboardMetrics,
            "finance": financeMetrics,
            "statistics": statisticsMetrics,
            "dashboard_state_publications_per_reload": publications,
        ]
        let url = URL(fileURLWithPath: path)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try JSONSerialization.data(withJSONObject: result, options: [.prettyPrinted, .sortedKeys]).write(to: url)
        XCTAssertLessThan(try XCTUnwrap(dashboardMetrics["p95_ms"]), 100)
        XCTAssertLessThan(try XCTUnwrap(financeMetrics["p95_ms"]), 100)
        XCTAssertLessThan(try XCTUnwrap(statisticsMetrics["p95_ms"]), 200)
    }
}
