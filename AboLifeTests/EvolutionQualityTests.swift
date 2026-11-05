import Combine
import GRDB
import SwiftUI
import XCTest

@testable import AboLife

final class EvolutionQualityTests: XCTestCase {
    func testDashboardDoesNotPresentAnEarlierWorkoutAsTodaysCompletion() {
        var state = DashboardMockState.persistedDefault
        state.lastWorkoutType = "Gestern-Workout"
        state.lastWorkoutDurationMinutes = 30
        state.weeklyWorkoutCompleted = 1
        state.workoutCompletedToday = false
        state.trainingScheduledToday = false
        let snapshot = DashboardMockData.snapshot(from: state)
        XCTAssertEqual(snapshot.training.todayStatus, .notScheduled)
        XCTAssertFalse(snapshot.training.status.contains("erledigt"))
        XCTAssertTrue(snapshot.training.progressDetail?.contains("Gestern-Workout") == true)

        state.weeklyWorkoutCompleted = state.weeklyWorkoutTarget
        XCTAssertEqual(DashboardMockData.snapshot(from: state).training.status, "Heute kein Plantraining")
        state.trainingScheduledToday = true
        XCTAssertEqual(DashboardMockData.snapshot(from: state).training.status, "Training heute offen")
        state.trainingPausedToday = true
        XCTAssertEqual(DashboardMockData.snapshot(from: state).training.status, "Heute pausiert")
        state.workoutCompletedToday = true
        state.lastWorkoutType = "Heute-Workout"
        XCTAssertEqual(DashboardMockData.snapshot(from: state).training.status, "Heute-Workout erledigt · 30 Min")
    }

    @MainActor
    func testDatabaseOpenFailureIsRecoverableAndTestingPreferencesAreIsolated() throws {
        let database = try AppDatabase.makeTemporary()
        var attempts = 0
        let session = AppSession {
            attempts += 1
            if attempts == 1 { throw URLError(.cannotOpenFile) }
            return database
        }
        XCTAssertTrue(session.failedToOpenDatabase)
        XCTAssertNil(session.database)
        XCTAssertFalse(session.preferences === UserDefaults.standard)
        XCTAssertTrue(session.sync.serverAddress.isEmpty)
        XCTAssertFalse(session.sync.autoSync)
        session.openDatabase()
        XCTAssertFalse(session.failedToOpenDatabase)
        XCTAssertTrue(session.database === database)
    }

    func testDashboardRefreshPublishesOneCoherentState() throws {
        let store = DashboardStore(database: try AppDatabase.makeTemporary())
        let before = store.state.habits.map(\.id)
        var count = 0
        let observation = store.$state.dropFirst().sink { _ in count += 1 }
        store.refreshFromPersistence()
        observation.cancel()
        XCTAssertEqual(count, 1)
        XCTAssertEqual(store.state.habits.map(\.id), before)
    }

    func testFailedMutationsKeepTheirErrorAndDoNotChangeValues() throws {
        let database = try AppDatabase.makeTemporary()
        let store = DashboardStore(database: database)
        try database.writer.write { db in
            for table in ["finance_entries", "workout_sessions", "habit_entries", "weight_entries"] {
                try db.execute(
                    sql:
                        "CREATE TRIGGER reject_\(table) BEFORE INSERT ON \(table) BEGIN SELECT RAISE(ABORT, 'test write rejected'); END"
                )
            }
        }
        XCTAssertFalse(store.addExpense(title: "Test", amount: 15, category: "Freizeit"))
        XCTAssertNotNil(store.errorMessage)
        XCTAssertFalse(store.completeWorkout(type: "Test", durationMinutes: 30))
        XCTAssertFalse(store.completeHomeWorkout(intensity: .normal))
        XCTAssertEqual(store.applyHabitDelta(habitKey: "water", delta: 0.25), 0)
        XCTAssertNotNil(store.errorMessage)
        XCTAssertFalse(store.setSleepRoutine(isCompleted: true))
        XCTAssertFalse(store.updateWeight(80))
        XCTAssertTrue(try FinanceRepository(database: database).fetchAll().isEmpty)
    }

    func testCustomCategoriesAndCurrencyReachQuickAdd() throws {
        let database = try AppDatabase.makeTemporary()
        var settings = SeedData.defaultSettings
        settings.defaultCurrency = "USD"
        try SettingsRepository(database: database).insert(settings)
        _ = try FinanceRepository(database: database).createCategory(name: "Instrumente")
        let store = DashboardStore(database: database)
        XCTAssertTrue(store.quickExpenseCategories().contains("Instrumente"))
        XCTAssertEqual(store.currency, "USD")
        XCTAssertTrue(store.addExpense(title: "Test", amount: 10.25, category: "Instrumente"))
        XCTAssertEqual(try FinanceRepository(database: database).fetchAll().first?.currency, "USD")
    }

    func testReviewDirtyStateAndSavedHistoryRemainDistinct() throws {
        let database = try AppDatabase.makeTemporary()
        let store = WeeklyReviewStore(database: database)
        let originalWeek = store.weekStartKey
        store.winsText = "Mein eigener Rückblick"
        XCTAssertTrue(store.hasUnsavedChanges)
        XCTAssertTrue(store.saveReview())
        XCTAssertFalse(store.hasUnsavedChanges)
        store.selectedDate = store.dateMovingWeek(by: -1)
        XCTAssertEqual(store.winsText, "")
        XCTAssertEqual(
            try WeeklyReviewRepository(database: database).fetch(weekStartDate: originalWeek)?.winsText,
            "Mein eigener Rückblick")
    }

    func testFinanceMonthNavigationDoesNotSkipFebruary() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let january = calendar.date(from: DateComponents(year: 2028, month: 1, day: 31))!
        let store = FinanceStore(database: try AppDatabase.makeTemporary(), selectedDate: january, calendar: calendar)
        store.moveMonth(by: 1)
        XCTAssertEqual(calendar.component(.month, from: store.selectedDate), 2)
        XCTAssertEqual(calendar.component(.day, from: store.selectedDate), 1)
        let lastDay = calendar.date(from: DateComponents(year: 2028, month: 2, day: 29))!
        XCTAssertEqual(
            FinanceStore.dailyBudgetRemaining(
                spent: 70, budget: 100, date: lastDay, calendar: calendar, spentToday: 20), 30)
    }

    func testTrailingCalendarDaysRespectDaylightSaving() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Berlin")!
        let date = calendar.date(from: DateComponents(year: 2026, month: 10, day: 25, hour: 12))!
        let interval = DateIntervals.trailingDays(7, endingAt: date, calendar: calendar)
        XCTAssertEqual(calendar.dateComponents([.day], from: interval.start, to: interval.end).day, 7)
        XCTAssertEqual(interval.duration, 169 * 3600)
    }

    func testReduceMotionDisablesEveryAnimationCategory() {
        for kind in [AboLifeMotion.Kind.interaction, .navigation, .metric] {
            XCTAssertNil(AboLifeMotion.animation(for: kind, reduceMotion: true))
            XCTAssertNotNil(AboLifeMotion.animation(for: kind, reduceMotion: false))
        }
    }

    func testEmptyTrainingDoesNotInventPersonalResults() throws {
        let database = try AppDatabase.makeTemporary()
        let store = TrainingViewModel(database: database)
        XCTAssertTrue(store.recommendations.isEmpty, "No recorded sets means no performance recommendation")
        XCTAssertNil(store.bodyTrend.latestWeightKg, "Example measurements are not personal history")
        XCTAssertFalse(
            store.motivationCards.contains { $0.title == "Neuer Rekord" || $0.title == "Erstes Ziel erreicht" })
        XCTAssertEqual(store.trainingStatistics.trainingsThisWeek, 0)
    }

    func testDetailedWorkoutFailureKeepsTheDraftOpenable() throws {
        let database = try AppDatabase.makeTemporary()
        let store = TrainingViewModel(database: database)
        try database.writer.write {
            try $0.execute(
                sql:
                    "CREATE TRIGGER reject_workout BEFORE INSERT ON workout_sessions BEGIN SELECT RAISE(ABORT, 'test rejected'); END"
            )
        }
        XCTAssertFalse(
            store.completeDetailedHomeWorkout(intensity: .normal, exercises: [], note: "Draft", painReported: false))
        XCTAssertNotNil(store.errorMessage)
        XCTAssertFalse(store.isSavingPlanWorkout)
        XCTAssertNil(store.completionMessage)
    }

    func testHistoricFinanceUsesTheFullMonthAndDoesNotProjectItAgain() throws {
        let database = try AppDatabase.makeTemporary()
        let calendar = Calendar.current
        let month = calendar.date(byAdding: .month, value: -1, to: Date())!
        let interval = DateIntervals.month(containing: month, calendar: calendar)
        try FinanceRepository(database: database).insert(
            FinanceEntryRecord(occurredAt: interval.start, title: "Test", amount: 300, category: "Freizeit"))
        let store = FinanceStore(database: database, selectedDate: interval.start, calendar: calendar)
        let days = calendar.dateComponents([.day], from: interval.start, to: interval.end).day!
        XCTAssertEqual(store.monthlyTrend.averageDailySpend, 300 / Double(days), accuracy: 0.0001)
        XCTAssertEqual(store.forecastSpend, 300)
    }

    func testInvalidExpenseIsNotSilentlySavedAsZero() throws {
        let database = try AppDatabase.makeTemporary()
        let store = DashboardStore(database: database)
        store.addExpense(title: "Ungültig", amount: .nan, category: "Freizeit")
        store.addExpense(title: "Negativ", amount: -10, category: "Freizeit")
        store.addExpense(title: "Leer", amount: 0, category: "Freizeit")
        XCTAssertTrue(try FinanceRepository(database: database).fetchAll().isEmpty)
    }

    func testWeightWindowsUseCalendarDaysInsteadOfMeasurementCounts() throws {
        let database = try AppDatabase.makeTemporary()
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let today = calendar.startOfDay(for: Date())
        let repository = WeightRepository(database: database)
        for offset in [0, -6, -7, -29, -30, -90, 1] {
            try repository.upsert(
                date: calendar.date(byAdding: .day, value: offset, to: today)!, weightKg: 80 + Double(offset) / 100,
                calendar: calendar)
        }
        let store = WeightStore(database: database, selectedDate: today, calendar: calendar)
        XCTAssertEqual(store.sevenDayEntries.count, 2)
        XCTAssertEqual(store.thirtyDayEntries.count, 4)
        XCTAssertFalse(
            store.sevenDayEntries.contains { $0.date > DateIntervals.dayKey(for: today, calendar: calendar) })
    }
}

/// Optional, isolated SwiftUI render artifacts. These do not launch the personal app.
@MainActor
final class EvolutionRenderingTests: XCTestCase {
    func testRenderReferenceStates() throws {
        guard let path = ProcessInfo.processInfo.environment["ABOLIFE_RENDER_DIR"] else {
            throw XCTSkip("Set ABOLIFE_RENDER_DIR to export isolated SwiftUI reference images")
        }
        let directory = URL(fileURLWithPath: path, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        var overBudget = DashboardMockState.default
        overBudget.monthlySpent = 1500
        overBudget.spentToday = 55
        var longText = DashboardMockState.default
        longText.habits = longText.habits.map {
            DashboardHabit(
                key: $0.key, title: "\($0.title) mit einer bewusst langen Bezeichnung",
                value: $0.value, targetValue: $0.targetValue, displayText: $0.displayText)
        }
        let states: [(String, DashboardMockState)] = [
            ("dashboard", .default), ("empty", .persistedDefault), ("over-budget", overBudget), ("long-text", longText),
        ]
        for (scenario, state) in states {
            for (name, scheme) in [("dark", ColorScheme.dark), ("light", ColorScheme.light)] {
                for width in [760.0, 1100.0] {
                    let view = DashboardView(store: DashboardStore(state: state))
                        .overview
                        .environmentObject(AIAssistantStore.previewStore())
                        .environmentObject(AppNavigationCoordinator())
                        .padding(24)
                        .frame(width: width, alignment: .top)
                        .fixedSize(horizontal: false, vertical: true)
                        .background(AboLifeColors.pageBackground)
                        .environment(\.colorScheme, scheme)
                    let renderer = ImageRenderer(content: view)
                    renderer.scale = 1
                    let image = try XCTUnwrap(renderer.cgImage)
                    XCTAssertEqual(image.width, Int(width))
                    XCTAssertGreaterThan(image.height, 400)
                    XCTAssertLessThan(image.height, 3000)
                    let bitmap = NSBitmapImageRep(cgImage: image)
                    let png = try XCTUnwrap(bitmap.representation(using: .png, properties: [:]))
                    try png.write(to: directory.appendingPathComponent("\(scenario)-\(name)-\(Int(width)).png"))
                }
            }
        }
    }
}
