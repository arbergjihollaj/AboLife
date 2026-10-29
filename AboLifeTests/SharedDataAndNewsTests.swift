import XCTest
import GRDB
@testable import AboLife

final class SharedDataAndNewsTests: XCTestCase {
    func testSharedDocumentRoundTripAndExcludesNutritionArchive() throws {
        let db = try AppDatabase.makeTemporary()
        try FinanceRepository(database: db).insert(FinanceEntryRecord(title: "Testbuch", amount: 12.5, category: "Uni"))
        try NutritionRepository(database: db).insert(NutritionEntryRecord(title: "Archiv", caloriesKcal: 123, proteinG: 4))
        try HabitRepository(database: db).insert(HabitEntryRecord(habitKey: "nutrition", date: "2026-10-27", isCompleted: true))
        let preferences = String(decoding: try JSONEncoder().encode(NewsPreferences()), as: UTF8.self)
        try db.writer.write { try $0.execute(sql: "INSERT INTO news_state(id,payload) VALUES ('main',?)", arguments: [preferences]) }
        let backupFolder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: backupFolder) }
        let export = try BackupService(database: db, backupDirectory: backupFolder).createJSONExport()
        let exported = try JSONSerialization.jsonObject(with: Data(contentsOf: export)) as! [String: Any]
        XCTAssertEqual(exported["newsPreferences"] as? String, preferences)
        let repo = SharedDataRepository(database: db)
        let document = try repo.document()
        XCTAssertNil(document.tables["nutrition_entries"])
        XCTAssertEqual(document.tables["finance_entries"]?.count, 1)
        XCTAssertFalse(document.tables["habit_entries"]!.contains { $0["habit_key"] == .string("nutrition") })
        let empty = try AppDatabase.makeTemporary()
        let target = SharedDataRepository(database: empty)
        try target.apply(document, expectedDigest: target.document().digest)
        XCTAssertEqual(try target.document().digest, document.digest)
        XCTAssertEqual(try FinanceRepository(database: empty).fetch(in: DateIntervals.month()).first?.amount, 12.5)
    }
    func testSharedImportRollsBackOnUnknownColumnsAndConcurrentChanges() throws {
        let db = try AppDatabase.makeTemporary(); let repo = SharedDataRepository(database: db)
        let original = try repo.document()
        var bad = original; bad.tables["finance_entries"] = [["id": .string("bad"), "unknown_column": .string("bad")]]
        XCTAssertThrowsError(try repo.apply(bad, expectedDigest: original.digest))
        XCTAssertEqual(try repo.document().digest, original.digest)
        try FinanceRepository(database: db).insert(FinanceEntryRecord(title: "Parallel", amount: 5, category: "Uni"))
        XCTAssertThrowsError(try repo.apply(original, expectedDigest: original.digest)) { XCTAssertEqual($0 as? SharedDataError, .changedDuringTransfer) }
        XCTAssertEqual(try repo.document().tables["finance_entries"]?.count, 1)
    }
    func testSharedImportRetainsArchivedHabitAndStableDigestAfterDecoding() throws {
        let db = try AppDatabase.makeTemporary(); let repo = SharedDataRepository(database: db)
        try HabitRepository(database: db).insert(HabitEntryRecord(habitKey: "nutrition", date: "2026-10-27", isCompleted: true))
        var document = try repo.document()
        document.calendar.events = [PlannerEvent(title: "Testuni", kind: .university, start: Date(), end: Date().addingTimeInterval(3600))]
        for _ in 0..<20 {
            let decoded = try JSONDecoder().decode(SharedDocument.self, from: JSONEncoder().encode(document))
            XCTAssertEqual(document.digest, decoded.digest)
        }
        try repo.apply(document, expectedDigest: repo.document().digest)
        XCTAssertEqual(try HabitRepository(database: db).fetch(for: "2026-10-27").count, 1)
    }
    func testExportSyntheticNativeContractForWebChecks() throws {
        let db = try AppDatabase.makeTemporary()
        try SettingsRepository(database: db).saveSettings(SeedData.defaultSettings)
        try FinanceRepository(database: db).insert(FinanceEntryRecord(title: "Fixture", amount: 2, category: "Uni"))
        let document = try SharedDataRepository(database: db).document()
        if let path = ProcessInfo.processInfo.environment["ABOLIFE_NATIVE_FIXTURE"] {
            let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
            try encoder.encode(document).write(to: URL(fileURLWithPath: path), options: .atomic)
        }
        if let path = ProcessInfo.processInfo.environment["ABOLIFE_SCHEMA_FIXTURE"] {
            let columns: [String: Any] = try db.writer.read { database in
                var schema: [String: Any] = [:]
                for table in SharedDocument.tableNames {
                    schema[table] = try database.columns(in: table).map { ["name": $0.name, "type": $0.type, "required": $0.isNotNull] as [String: Any] }
                }
                return schema
            }
            try JSONSerialization.data(withJSONObject: columns, options: [.prettyPrinted, .sortedKeys]).write(to: URL(fileURLWithPath: path), options: .atomic)
        }
        XCTAssertEqual(document.schemaVersion, 1)
    }
    func testWebContractImportsAllNewRowTypes() throws {
        guard let path = ProcessInfo.processInfo.environment["ABOLIFE_WEB_FIXTURE"] else { throw XCTSkip("Optionaler Node→Swift-Vertragstest; scripts/check-native.sh richtet die Fixture ein.") }
        let incoming = try JSONDecoder().decode(SharedDocument.self, from: Data(contentsOf: URL(fileURLWithPath: path)))
        let db = try AppDatabase.makeTemporary(); let repo = SharedDataRepository(database: db)
        try repo.apply(incoming, expectedDigest: repo.document().digest)
        XCTAssertEqual(try repo.document().tables["workout_sessions"]?.count, 1)
        XCTAssertEqual(try repo.document().tables["weight_entries"]?.count, 1)
        XCTAssertEqual(try repo.document().tables["habit_entries"]?.count, 1)
        XCTAssertEqual(try CalendarRepository(database: db).load().events.count, 1)
    }
    func testRSSAndAtomRejectUnsafeURLsAndKeepDates() throws {
        let source = NewsSource.defaults[0]
        let rss = Data("<rss><channel><item><title><![CDATA[Neue Forschung]]></title><link>https://example.org/news</link><pubDate>Tue, 27 Oct 2026 09:00:00 +0100</pubDate></item><item><title>Unsafe</title><link>javascript:alert(1)</link></item></channel></rss>".utf8)
        let items = try NewsFeedParser.parse(rss, source: source)
        XCTAssertEqual(items.count, 1); XCTAssertNotNil(items[0].publishedAt)
        let atom = Data("<feed><entry><title>Atom</title><link href='https://example.org/atom'/><updated>2026-10-27T08:00:00Z</updated></entry></feed>".utf8)
        XCTAssertEqual(try NewsFeedParser.parse(atom, source: source).first?.url.absoluteString, "https://example.org/atom")
        XCTAssertThrowsError(try NewsFeedParser.parse(Data("<rss>".utf8), source: source))
    }
    @MainActor
    func testRemovedNutritionDoesNotAffectCoreAndReviewRejectsMissingBlock() throws {
        XCTAssertFalse(AppSection.allCases.map(\.rawValue).contains("nutrition"))
        XCTAssertFalse(FixedHabit.defaults.map(\.key).contains("nutrition"))
        XCTAssertFalse(QuickAddKind.allCases.map(\.rawValue).contains("meal"))
        let db = try AppDatabase.makeTemporary()
        let store = CalendarPlannerStore(database: db)
        XCTAssertFalse(store.review("missing", rating: .good, actualMinutes: 20))
        XCTAssertNotNil(store.errorMessage)
    }
    func testThreeWayMergePreservesIndependentRowsAndFieldChanges() throws {
        let db = try AppDatabase.makeTemporary()
        let base = try SharedDataRepository(database: db).document()
        var local = base, remote = base
        let localEvent = PlannerEvent(title: "Mac", kind: .personal, start: Date(), end: Date().addingTimeInterval(3600))
        let remoteEvent = PlannerEvent(title: "Handy", kind: .personal, start: Date(), end: Date().addingTimeInterval(3600))
        local.calendar.events.append(localEvent)
        remote.calendar.events.append(remoteEvent)
        let merged = try SharedDocumentMerge.merge(base: base, local: local, remote: remote)
        XCTAssertEqual(Set(merged.calendar.events.map(\.id)), Set([localEvent.id, remoteEvent.id]))
        var left = merged, right = merged
        left.calendar.events[0].title = "Neuer Titel"
        right.calendar.events[0].location = "gym"
        let combined = try SharedDocumentMerge.merge(base: merged, local: left, remote: right)
        XCTAssertEqual(combined.calendar.events[0].title, "Neuer Titel")
        XCTAssertEqual(combined.calendar.events[0].location, "gym")
    }
    func testThreeWayMergeRejectsConflictingEditsAndDeleteVersusEdit() throws {
        let db = try AppDatabase.makeTemporary()
        var base = try SharedDataRepository(database: db).document()
        base.calendar.events = [PlannerEvent(title: "Alt", kind: .personal, start: Date(), end: Date().addingTimeInterval(3600))]
        var local = base, remote = base
        local.calendar.events[0].title = "Mac"
        remote.calendar.events[0].title = "Handy"
        XCTAssertThrowsError(try SharedDocumentMerge.merge(base: base, local: local, remote: remote))
        local.calendar.events = []
        XCTAssertThrowsError(try SharedDocumentMerge.merge(base: base, local: local, remote: remote))
        XCTAssertEqual(try SharedDocumentMerge.merge(base: base, local: local, remote: base).calendar.events.count, 0)
    }
    func testThreeWayMergeRejectsDifferentUUIDsForSameDailyRecord() throws {
        let db = try AppDatabase.makeTemporary()
        let base = try SharedDataRepository(database: db).document()
        try WeightRepository(database: db).upsert(dayKey: "2026-10-28", weightKg: 80)
        let local = try SharedDataRepository(database: db).document()
        var remote = local
        remote.tables["weight_entries"]![0]["id"] = .string(UUID().uuidString)
        XCTAssertThrowsError(try SharedDocumentMerge.merge(base: base, local: local, remote: remote))
    }

    func testDailyPurchasesReduceTodaysAllocationByTheirFullAmount() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Berlin")!
        let date = ISO8601DateFormatter().date(from: "2026-10-28T12:00:00Z")!
        let before = FinanceStore.dailyBudgetRemaining(spent: 100, budget: 300, date: date, calendar: calendar)
        let after = FinanceStore.dailyBudgetRemaining(spent: 110, budget: 300, date: date, calendar: calendar, spentToday: 10)
        XCTAssertEqual(before - after, 10, accuracy: 0.001)
        XCTAssertEqual(FinanceStore.dailyBudgetRemaining(spent: 310, budget: 300, date: date, calendar: calendar, spentToday: 210), 0)
    }
    func testJSONAndCSVRestoreRoundTripAndPreRestoreBackup() throws {
        let db = try AppDatabase.makeTemporary()
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let service = BackupService(database: db, backupDirectory: folder)
        try FinanceRepository(database: db).insert(FinanceEntryRecord(title: "Vorher", amount: 4, category: "Uni"))
        let json = try service.createJSONExport()
        let csv = try service.createCSVExport()
        let snapshot = try service.prepareRestore(from: json)
        XCTAssertEqual(try service.prepareRestore(from: csv).financeEntries.count, 1)
        try FinanceRepository(database: db).insert(FinanceEntryRecord(title: "Später", amount: 9, category: "Uni"))
        let backup = try service.restore(snapshot)
        XCTAssertTrue(FileManager.default.fileExists(atPath: backup.path))
        XCTAssertEqual(try service.makeExportPayload().financeEntries.count, 1)
        XCTAssertEqual(try service.prepareRestore(from: backup).financeEntries.count, 2)
    }
    func testInvalidRestoreRollsBackAndPreservesCurrentRows() throws {
        let db = try AppDatabase.makeTemporary()
        let service = BackupService(database: db, backupDirectory: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString))
        try FinanceRepository(database: db).insert(FinanceEntryRecord(title: "Bleibt", amount: 4, category: "Uni"))
        let exported = try service.createJSONExport()
        var object = try JSONSerialization.jsonObject(with: Data(contentsOf: exported)) as! [String: Any]
        let rows = object["financeEntries"] as! [[String: Any]]
        object["financeEntries"] = rows + rows
        let invalid = exported.deletingLastPathComponent().appendingPathComponent("invalid.json")
        try JSONSerialization.data(withJSONObject: object).write(to: invalid)
        XCTAssertThrowsError(try service.prepareRestore(from: invalid))
        XCTAssertEqual(try service.makeExportPayload().financeEntries.first?.title, "Bleibt")
    }

    func testMobilePlannedWorkoutImportsExercisesAndSets() throws {
        guard let path = ProcessInfo.processInfo.environment["ABOLIFE_PLAN_FIXTURE"] else { throw XCTSkip("Optionale Web-Workout-Fixture") }
        let incoming = try JSONDecoder().decode(SharedDocument.self, from: Data(contentsOf: URL(fileURLWithPath: path)))
        let db = try AppDatabase.makeTemporary()
        let repo = SharedDataRepository(database: db)
        try repo.apply(incoming, expectedDigest: repo.document().digest)
        XCTAssertEqual(try repo.document().tables["workout_exercises"]?.count, 2)
        XCTAssertEqual(try repo.document().tables["workout_sets"]?.count, 3)
    }

    func testDemoFixtureUsesOnlySyntheticDataInATemporaryDatabase() throws {
        let db = try AppDatabase.makeTemporary()
        try DemoData.populate(db)
        XCTAssertEqual(try SettingsRepository(database: db).loadSettings().monthlyBudget, 600)
        XCTAssertEqual(try SharedDataRepository(database: db).document().tables["finance_entries"]?.count, 3)
        XCTAssertEqual(try CalendarRepository(database: db).load().events.first?.title, "Softwareentwicklung")
    }

}
