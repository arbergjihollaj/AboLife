import XCTest
import GRDB
@testable import AboLife

final class CalendarPlannerTests: XCTestCase {
    private var calendar: Calendar {
        var c = Calendar(identifier: .gregorian); c.timeZone = TimeZone(identifier: "Europe/Berlin")!; c.firstWeekday = 2; return c
    }
    private func date(_ value: String) -> Date {
        let f = DateFormatter(); f.locale = Locale(identifier: "en_US_POSIX"); f.timeZone = calendar.timeZone; f.dateFormat = "yyyy-MM-dd HH:mm"; return f.date(from: value)!
    }
    private var now: Date { date("2026-10-26 08:00") }
    private func event(_ title: String, _ start: String, _ end: String, place: String = "university") -> PlannerEvent {
        PlannerEvent(title: title, kind: place == "university" ? .university : (place == "gym" ? .training : .personal), start: date(start), end: date(end), location: place, timeZoneID: calendar.timeZone.identifier)
    }
    private func topic(_ title: String = "Thema", minutes: Int = 25) -> StudyTopic {
        StudyTopic(title: title, course: "Mathematik", durationMinutes: minutes, nextReview: now)
    }
    private func preferences() -> PlannerPreferences {
        var p = PlannerPreferences(); p.assumeSymmetricReturn = false; p.automaticModulePlanning = false; p.timeZoneID = calendar.timeZone.identifier; p.weekdays = Set(1...7); return p
    }
    private var day: DateInterval { DateInterval(start: calendar.startOfDay(for: now), end: calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: now))!) }
    private func ics(_ event: String) -> Data { Data(("BEGIN:VCALENDAR\r\nVERSION:2.0\r\n" + event + "\r\nEND:VCALENDAR").utf8) }
    private var sampleICS: String { "BEGIN:VEVENT\r\nUID:lecture-1\r\nSUMMARY:Analysis\r\nDTSTART;TZID=Europe/Berlin:20261026T090000\r\nDTEND;TZID=Europe/Berlin:20261026T103000\r\nRRULE:FREQ=WEEKLY;UNTIL=20261231T235959Z\r\nEND:VEVENT" }

    func testCalendarMigrationRoundTripsWorkspace() throws {
        let db = try AppDatabase.makeTemporary()
        var w = CalendarWorkspace(); w.preferences = preferences(); w.events = [event("Uni", "2026-10-26 09:00", "2026-10-26 12:00")]; w.topics = [topic()]
        try CalendarRepository(database: db).save(w)
        XCTAssertEqual(try CalendarRepository(database: db).load(), w)
    }
    func testVersionBootstrapNeverMigratesOrOverwritesLegacyData() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let legacy = directory.appendingPathComponent("legacy.sqlite"), destination = directory.appendingPathComponent("preview.sqlite")
        let queue = try DatabaseQueue(path: legacy.path)
        try DatabaseMigrationPlan.migrator.migrate(queue, upTo: "v11_create_workout_detail_tables")
        try queue.write { db in try NutritionEntryRecord(title: "Vorhanden", caloriesKcal: 100, proteinG: 10).insert(db) }
        try queue.close()
        let before = try Data(contentsOf: legacy)
        try AppDatabase.bootstrapCalendarCopyIfNeeded(destination: destination, legacyURL: legacy)
        let preview = try AppDatabase(path: destination.path)
        var workspace = CalendarWorkspace(); workspace.topics = [topic()]
        try CalendarRepository(database: preview).save(workspace)
        XCTAssertEqual(try NutritionRepository(database: preview).fetchAll().first?.title, "Vorhanden")
        XCTAssertEqual(try Data(contentsOf: legacy), before)
        try AppDatabase.bootstrapCalendarCopyIfNeeded(destination: destination, legacyURL: legacy)
        XCTAssertEqual(try CalendarRepository(database: preview).load().topics.count, 1)
        var config = Configuration(); config.readonly = true
        let original = try DatabaseQueue(path: legacy.path, configuration: config)
        XCTAssertEqual(try original.read { try Int.fetchOne($0, sql: "SELECT COUNT(*) FROM sqlite_master WHERE name = 'calendar_workspace'") }, 0)
        XCTAssertEqual(DatabaseConfiguration.applicationSupportFolderName, "AboLife-Main")
    }
    func testMainVersionPrefersPreviewAndNeverOverwritesAnExistingMain() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let previewURL = dir.appendingPathComponent("preview.sqlite"), legacyURL = dir.appendingPathComponent("legacy.sqlite"), mainURL = dir.appendingPathComponent("main.sqlite")
        let preview = try AppDatabase(path: previewURL.path), legacy = try AppDatabase(path: legacyURL.path)
        try WeightRepository(database: preview).upsert(dayKey: "2026-10-29", weightKg: 81)
        try WeightRepository(database: legacy).upsert(dayKey: "2026-10-29", weightKg: 79)
        try AppDatabase.bootstrapMainCopyIfNeeded(destination: mainURL, previewURL: previewURL, legacyURL: legacyURL)
        let main = try AppDatabase(path: mainURL.path)
        XCTAssertEqual(try WeightRepository(database: main).latest()?.weightKg, 81)
        try WeightRepository(database: main).upsert(dayKey: "2026-10-29", weightKg: 82)
        try AppDatabase.bootstrapMainCopyIfNeeded(destination: mainURL, previewURL: previewURL, legacyURL: legacyURL)
        XCTAssertEqual(try WeightRepository(database: main).latest()?.weightKg, 82)
        XCTAssertEqual(try WeightRepository(database: preview).latest()?.weightKg, 81)
        XCTAssertEqual(try WeightRepository(database: legacy).latest()?.weightKg, 79)
    }
    func testMainVersionFallsBackToLegacyWhenNoPreviewExists() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let legacyURL = dir.appendingPathComponent("legacy.sqlite"), mainURL = dir.appendingPathComponent("main.sqlite")
        let legacy = try AppDatabase(path: legacyURL.path)
        try WeightRepository(database: legacy).upsert(dayKey: "2026-10-29", weightKg: 79)
        try AppDatabase.bootstrapMainCopyIfNeeded(destination: mainURL, previewURL: dir.appendingPathComponent("missing.sqlite"), legacyURL: legacyURL)
        XCTAssertEqual(try WeightRepository(database: AppDatabase(path: mainURL.path)).latest()?.weightKg, 79)
    }
    func testUniversityCommuteAndReturnBlockLearning() {
        var p = preferences(); p.travelMinutes["university>home"] = 60
        let result = StudyPlannerEngine.availability(events: [event("Uni", "2026-10-26 09:00", "2026-10-26 12:00")], preferences: p, horizon: day)
        XCTAssertTrue(result.issues.isEmpty)
        XCTAssertEqual(result.windows.first?.interval.start, date("2026-10-26 13:00"))
        XCTAssertEqual(result.windows.last?.interval.end, date("2026-10-26 21:00"))
    }
    func testUnknownReturnDoesNotInventAvailableTime() {
        let result = StudyPlannerEngine.availability(events: [event("Uni", "2026-10-26 09:00", "2026-10-26 12:00")], preferences: preferences(), horizon: day)
        XCTAssertTrue(result.windows.isEmpty)
        XCTAssertTrue(result.issues.contains { $0.message.contains("Rückfahrt") })
    }
    func testUniversityDayEndsAtHomeBeforeLaterTrainingEvenWithKnownDirectRoute() {
        var p = preferences(); p.travelMinutes["university>gym"] = 30; p.travelMinutes["gym>home"] = 15; p.travelMinutes["university>home"] = 60
        let events = [event("Uni", "2026-10-26 09:00", "2026-10-26 12:00"), event("Sport", "2026-10-26 18:00", "2026-10-26 19:00", place: "gym")]
        let result = StudyPlannerEngine.availability(events: events, preferences: p, horizon: day)
        XCTAssertTrue(result.issues.isEmpty)
        XCTAssertEqual(result.windows.first?.location, "home")
        XCTAssertEqual(result.windows.first?.interval, DateInterval(start: date("2026-10-26 13:00"), end: date("2026-10-26 17:45")))
        XCTAssertEqual(result.windows.last?.interval.start, date("2026-10-26 19:15"))
    }
    func testImpossibleFixedTransferIsReported() {
        var p = preferences(); p.travelMinutes["university>gym"] = 30; p.travelMinutes["gym>home"] = 15; p.travelMinutes["university>home"] = 60
        let events = [event("Uni", "2026-10-26 09:00", "2026-10-26 17:55"), event("Sport", "2026-10-26 18:00", "2026-10-26 19:00", place: "gym")]
        let result = StudyPlannerEngine.availability(events: events, preferences: p, horizon: day)
        XCTAssertTrue(result.issues.contains { $0.message.contains("Zu wenig Fahrtzeit") })
        XCTAssertFalse(result.windows.contains { $0.interval.contains(date("2026-10-26 17:57")) })
    }
    func testHomeWorkoutNeedsNoGymTravel() {
        let result = StudyPlannerEngine.availability(events: [event("Home", "2026-10-26 10:00", "2026-10-26 11:00", place: "home")], preferences: preferences(), horizon: day)
        XCTAssertTrue(result.issues.isEmpty)
        XCTAssertEqual(result.windows.map(\.interval), [DateInterval(start: now, end: date("2026-10-26 10:00")), DateInterval(start: date("2026-10-26 11:00"), end: date("2026-10-26 21:00"))])
    }
    func testDailyLimitBreaksAndDeterminism() {
        var w = CalendarWorkspace(); w.preferences = preferences(); w.topics = [topic("A", minutes: 60), topic("B", minutes: 60), topic("C", minutes: 60)]
        let result = StudyPlannerEngine.plan(w, now: now)
        let monday = result.sessions.filter { calendar.isDate($0.start, inSameDayAs: now) }
        XCTAssertEqual(monday.count, 2)
        XCTAssertGreaterThanOrEqual(monday[1].start.timeIntervalSince(monday[0].end), 600)
        XCTAssertEqual(monday.reduce(0) { $0 + $1.minutes }, 120)
        XCTAssertEqual(StudyPlannerEngine.plan(w, now: now).sessions, result.sessions)
        w.sessions = result.sessions
        XCTAssertEqual(StudyPlannerEngine.plan(w, now: now).sessions, result.sessions)
    }
    func testChangedEventReschedulesSuggestionsButPreservesPinsAndReportsConflict() {
        var w = CalendarWorkspace(); w.preferences = preferences(); w.topics = [topic()]
        let initial = StudyPlannerEngine.plan(w, now: now).sessions[0]
        w.sessions = [initial]
        w.events = [event("Blockiert", "2026-10-26 08:00", "2026-10-26 09:00", place: "home")]
        let replanned = StudyPlannerEngine.plan(w, now: now)
        XCTAssertGreaterThanOrEqual(replanned.sessions[0].start, date("2026-10-26 09:00"))
        w.sessions[0].pinned = true
        let pinned = StudyPlannerEngine.plan(w, now: now)
        XCTAssertEqual(pinned.sessions[0].start, initial.start)
        XCTAssertTrue(pinned.issues.contains { $0.message.contains("Fixierter/laufender") })
    }
    func testFullCalendarLeavesTopicsUnplaced() {
        var w = CalendarWorkspace(); w.preferences = preferences(); w.topics = [topic()]
        var full = event("Belegt", "2026-10-26 00:00", "2026-10-27 00:00", place: "home")
        full.weekly = true; full.repeatWeekdays = Set(1...7)
        w.events = [full]
        let result = StudyPlannerEngine.plan(w, now: now)
        XCTAssertTrue(result.sessions.isEmpty)
        XCTAssertNotNil(result.unplaced[w.topics[0].id])
    }
    func testPlannerHonorsFutureDueDateAndExamDeadline() {
        var w = CalendarWorkspace(); w.preferences = preferences()
        var t = topic(); t.nextReview = date("2026-10-28 12:00"); t.examDate = date("2026-10-28 12:10"); w.topics = [t]
        let result = StudyPlannerEngine.plan(w, now: now)
        XCTAssertTrue(result.sessions.isEmpty)
        XCTAssertNotNil(result.unplaced[t.id])
        w.topics[0].examDate = date("2026-10-28 14:00")
        let session = StudyPlannerEngine.plan(w, now: now).sessions.first!
        XCTAssertGreaterThanOrEqual(session.start, t.nextReview)
        XCTAssertLessThanOrEqual(session.end, w.topics[0].examDate!)
    }
    func testReviewFeedbackChangesIntervalsAndDurationEstimate() {
        var easy = topic(), hard = topic(), again = topic()
        StudyReviewPolicy.apply(.easy, to: &easy, at: now, actualMinutes: 40, calendar: calendar)
        StudyReviewPolicy.apply(.hard, to: &hard, at: now, actualMinutes: 25, calendar: calendar)
        StudyReviewPolicy.apply(.again, to: &again, at: now, actualMinutes: 10, calendar: calendar)
        XCTAssertGreaterThan(easy.nextReview, hard.nextReview)
        XCTAssertEqual(again.intervalDays, 1)
        XCTAssertEqual(easy.estimatedMinutes, 40)
        XCTAssertEqual(easy.reviewCount, 1)
    }
    func testWeeklyRecurrencePreservesLocalClockAcrossDSTAndExceptions() {
        var e = event("Vorlesung", "2026-10-19 09:00", "2026-10-19 10:00")
        e.weekly = true; e.excludedDays = ["2026-11-02"]
        let values = e.occurrences(in: DateInterval(start: date("2026-10-18 00:00"), end: date("2026-11-10 00:00")))
        XCTAssertEqual(values.count, 3)
        XCTAssertTrue(values.allSatisfy { calendar.component(.hour, from: $0.start) == 9 })
        XCTAssertEqual(values[1].start.timeIntervalSince(values[0].start), 7 * 86400 + 3600)
    }
    func testICSWeeklyCountIncludesOccurrencesBeforeVisibleHorizon() throws {
        let value = sampleICS.replacingOccurrences(of: "UNTIL=20261231T235959Z", with: "COUNT=2")
        let draft = try ICSImporter.parse(data: ics(value), sourceID: "uni", sourceName: "Uni")
        XCTAssertTrue(draft.warnings.isEmpty)
        let values = draft.events[0].occurrences(in: DateInterval(start: date("2026-11-02 00:00"), end: date("2026-11-20 00:00")))
        XCTAssertEqual(values.count, 1)
    }
    func testICSUnfoldingUTCExceptionsAndMultiWeekdays() throws {
        let value = sampleICS.replacingOccurrences(of: "SUMMARY:Analysis", with: "SUMMARY:Analysis\\,\r\n  Grundlagen").replacingOccurrences(of: "UNTIL=20261231T235959Z", with: "BYDAY=MO,WE;COUNT=4").replacingOccurrences(of: "END:VEVENT", with: "EXDATE;TZID=Europe/Berlin:20261028T090000\r\nEND:VEVENT")
        let draft = try ICSImporter.parse(data: ics(value), sourceID: "uni", sourceName: "Uni")
        XCTAssertTrue(draft.warnings.isEmpty)
        XCTAssertEqual(draft.events[0].title, "Analysis, Grundlagen")
        let values = draft.events[0].occurrences(in: DateInterval(start: now, end: date("2026-11-10 00:00")))
        XCTAssertEqual(values.count, 3)
        XCTAssertEqual(values.map(\.dayKey), ["2026-10-26", "2026-11-02", "2026-11-04"])
    }
    func testICSRejectsUnsupportedSeriesAndMovedOccurrencesInsteadOfMisimporting() throws {
        let daily = sampleICS.replacingOccurrences(of: "FREQ=WEEKLY", with: "FREQ=DAILY")
        let rejected = try ICSImporter.parse(data: ics(daily), sourceID: "uni", sourceName: "Uni")
        XCTAssertTrue(rejected.events.isEmpty); XCTAssertFalse(rejected.warnings.isEmpty)
        let moved = sampleICS.replacingOccurrences(of: "BEGIN:VEVENT", with: "BEGIN:VEVENT\r\nRECURRENCE-ID;TZID=Europe/Berlin:20261102T090000")
        let draft = try ICSImporter.parse(data: ics(sampleICS + "\r\n" + moved), sourceID: "uni", sourceName: "Uni")
        XCTAssertTrue(draft.events.isEmpty); XCTAssertFalse(draft.warnings.isEmpty)
    }
    func testICSInvalidTimezoneOrMissingTimedEndIsRejected() throws {
        let badZone = sampleICS.replacingOccurrences(of: "Europe/Berlin", with: "Not/AZone")
        XCTAssertTrue(try ICSImporter.parse(data: ics(badZone), sourceID: "uni", sourceName: "Uni").events.isEmpty)
        let noEnd = sampleICS.replacingOccurrences(of: "DTEND;TZID=Europe/Berlin:20261026T103000\r\n", with: "")
        XCTAssertTrue(try ICSImporter.parse(data: ics(noEnd), sourceID: "uni", sourceName: "Uni").events.isEmpty)
        XCTAssertThrowsError(try ICSImporter.parse(data: Data("hello".utf8), sourceID: "uni", sourceName: "Uni"))
    }
    @MainActor
    func testStoreReimportIsIdempotentProtectsLocalEditsAndRequiresFullSourceForDeletion() throws {
        let db = try AppDatabase.makeTemporary(), store = CalendarPlannerStore(database: db, now: { self.now })
        let draft = try ICSImporter.parse(data: ics(sampleICS), sourceID: "uni", sourceName: "Uni")
        store.importChanges(draft, overwriteLocal: false, removeMissing: false)
        store.importChanges(draft, overwriteLocal: false, removeMissing: false)
        XCTAssertEqual(store.workspace.events.count, 1)
        var event = store.workspace.events[0]; event.title = "Meine Änderung"
        XCTAssertTrue(store.saveEvent(event))
        store.importChanges(draft, overwriteLocal: false, removeMissing: false)
        XCTAssertEqual(store.workspace.events[0].title, "Meine Änderung")
        store.importChanges(draft, overwriteLocal: true, removeMissing: false)
        XCTAssertEqual(store.workspace.events[0].title, "Analysis")
        let empty = CalendarImportDraft(events: [], warnings: [], sourceID: "uni", sourceName: "Uni")
        store.importChanges(empty, overwriteLocal: false, removeMissing: false)
        XCTAssertFalse(store.workspace.events[0].cancelled)
        var warning = empty; warning.warnings = ["Unvollständig"]
        store.importChanges(warning, overwriteLocal: false, removeMissing: true)
        XCTAssertFalse(store.workspace.events[0].cancelled)
        store.importChanges(empty, overwriteLocal: false, removeMissing: true)
        XCTAssertTrue(store.workspace.events[0].cancelled)
    }
    @MainActor
    func testReviewAndSkipPersistAndDoNotDoubleReview() throws {
        let db = try AppDatabase.makeTemporary(), store = CalendarPlannerStore(database: db, now: { self.now })
        XCTAssertTrue(store.saveTopic(topic()))
        let id = store.workspace.sessions.first!.id
        XCTAssertTrue(store.review(id, rating: .good, actualMinutes: 35))
        XCTAssertEqual(store.workspace.topics[0].reviewCount, 1)
        _ = store.review(id, rating: .easy, actualMinutes: 35)
        XCTAssertEqual(store.workspace.topics[0].reviewCount, 1)
        XCTAssertEqual(try CalendarRepository(database: db).load().topics[0].estimatedMinutes, 35)
        let next = store.workspace.sessions.first { $0.status == .planned }!
        store.skip(next.id)
        XCTAssertTrue(store.workspace.sessions.contains { $0.id == next.id && $0.status == .skipped })
    }
}

extension CalendarPlannerTests {
    @MainActor
    func testSkippingFutureSuggestionDoesNotRecreateSameSlotOrDuplicateIdentity() throws {
        let store = CalendarPlannerStore(database: try AppDatabase.makeTemporary(), now: { self.now })
        var t = topic(); t.nextReview = date("2026-10-28 08:00")
        XCTAssertTrue(store.saveTopic(t))
        let original = store.workspace.sessions.first!
        store.skip(original.id)
        let next = store.workspace.sessions.first { $0.status == .planned }!
        XCTAssertGreaterThanOrEqual(next.start, date("2026-10-29 00:00"))
        XCTAssertNotEqual(next.id, original.id)
        XCTAssertEqual(Set(store.workspace.sessions.map(\.id)).count, store.workspace.sessions.count)
    }
    @MainActor
    func testUnreadableWorkspaceIsNeverOverwrittenByAnEdit() throws {
        let db = try AppDatabase.makeTemporary()
        let corrupt = Data("not json".utf8)
        try db.writer.write { try $0.execute(sql: "INSERT INTO calendar_workspace (id, payload) VALUES (?, ?)", arguments: ["main", corrupt]) }
        let store = CalendarPlannerStore(database: db, now: { self.now })
        XCTAssertNotNil(store.errorMessage)
        XCTAssertFalse(store.saveTopic(topic()))
        XCTAssertEqual(try db.writer.read { try Data.fetchOne($0, sql: "SELECT payload FROM calendar_workspace WHERE id = 'main'") }, corrupt)
    }
    @MainActor
    func testManualMoveHonorsDailyLimitAndDoesNotDamageExistingSession() throws {
        let store = CalendarPlannerStore(database: try AppDatabase.makeTemporary(), now: { self.now })
        XCTAssertTrue(store.saveTopic(topic("A", minutes: 120)))
        XCTAssertTrue(store.saveTopic(topic("B", minutes: 25)))
        let later = store.workspace.sessions.first { $0.minutes == 25 }!
        XCTAssertFalse(store.moveSession(later.id, start: date("2026-10-26 15:00")))
        XCTAssertEqual(store.workspace.sessions.first { $0.id == later.id }?.start, later.start)
    }
    func testUnknownDirectTransferLeavesEntireGapUnscheduled() {
        var p = preferences(); p.travelMinutes["gym>home"] = 15
        let values = [event("Uni", "2026-10-26 09:00", "2026-10-26 12:00"), event("Gym", "2026-10-26 18:00", "2026-10-26 19:00", place: "gym")]
        let result = StudyPlannerEngine.availability(events: values, preferences: p, horizon: day)
        XCTAssertFalse(result.windows.contains { $0.interval.contains(date("2026-10-26 14:00")) })
        XCTAssertTrue(result.issues.contains { $0.message.contains("Rückfahrt") })
    }
    @MainActor
    func testCancelledOccurrencePersistsAndDoesNotCancelWholeSeries() throws {
        let store = CalendarPlannerStore(database: try AppDatabase.makeTemporary(), now: { self.now })
        var e = event("Uni", "2026-10-26 09:00", "2026-10-26 10:00"); e.weekly = true
        XCTAssertTrue(store.saveEvent(e))
        let range = DateInterval(start: now, end: date("2026-11-10 00:00"))
        store.cancel(e.occurrences(in: range)[0])
        let remaining = store.workspace.events[0].occurrences(in: range)
        XCTAssertEqual(remaining.map(\.dayKey), ["2026-11-02", "2026-11-09"])
        XCTAssertEqual(store.workspace.events[0].cancelled, false)
    }
}

extension CalendarPlannerTests {
    func testExistingBackupFormatsIncludeCalendarAndReviewData() throws {
        let db = try AppDatabase.makeTemporary()
        var w = CalendarWorkspace(); w.topics = [topic()]; w.preferences = preferences()
        try CalendarRepository(database: db).save(w)
        let destination = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let service = BackupService(database: db, backupDirectory: destination, now: { self.now })
        XCTAssertEqual(try service.makeExportPayload().calendarWorkspace?.topics.first?.id, w.topics.first?.id)
        let json = try service.createJSONExport()
        let object = try JSONSerialization.jsonObject(with: Data(contentsOf: json)) as! [String: Any]
        XCTAssertNotNil(object["calendarWorkspace"])
        let csv = try service.createCSVExport()
        XCTAssertTrue(FileManager.default.fileExists(atPath: csv.appendingPathComponent("calendar_workspace.json").path))
    }
}

extension CalendarPlannerTests {
    func testBootstrapRejectsSharedPathAndSymlinkAliasBeforeAnyMigration() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let legacy = directory.appendingPathComponent("legacy.sqlite")
        try Data("unchanged".utf8).write(to: legacy)
        XCTAssertThrowsError(try AppDatabase.bootstrapCalendarCopyIfNeeded(destination: legacy, legacyURL: legacy))
        let alias = directory.appendingPathComponent("alias.sqlite")
        try FileManager.default.createSymbolicLink(at: alias, withDestinationURL: legacy)
        XCTAssertThrowsError(try AppDatabase.bootstrapCalendarCopyIfNeeded(destination: alias, legacyURL: legacy))
        XCTAssertEqual(try Data(contentsOf: legacy), Data("unchanged".utf8))
    }
    func testLoweredLimitAndEarlierExamReportPinnedConflictsWithoutMovingThem() {
        var w = CalendarWorkspace(); w.preferences = preferences(); w.preferences.dailyLimitMinutes = 30
        var t = topic(minutes: 60); t.examDate = date("2026-10-26 08:30"); w.topics = [t]
        let pinned = StudySession(topicID: t.id, start: date("2026-10-26 09:00"), end: date("2026-10-26 10:00"), pinned: true)
        w.sessions = [pinned]
        let result = StudyPlannerEngine.plan(w, now: now)
        XCTAssertEqual(result.sessions.first?.start, pinned.start)
        XCTAssertTrue(result.issues.contains { $0.message.contains("Tagesgrenze") })
        XCTAssertTrue(result.issues.contains { $0.message.contains("Prüfungstermin") })
    }
}

extension CalendarPlannerTests {
    func testDirectGymToCampusLeavesNoCampusLearningGap() {
        var p = preferences(); p.travelMinutes["gym>university"] = 15; p.travelMinutes["university>home"] = 60
        let events = [event("Sport", "2026-10-26 08:00", "2026-10-26 09:00", place: "gym"), event("Uni", "2026-10-26 11:00", "2026-10-26 12:00")]
        let result = StudyPlannerEngine.availability(events: events, preferences: p, horizon: day)
        XCTAssertTrue(result.issues.isEmpty)
        XCTAssertFalse(result.windows.contains { $0.location == "university" })
        XCTAssertTrue(result.journeys.contains { $0.from == "gym" && $0.to == "university" && $0.start == date("2026-10-26 10:45") })
    }
    func testImpossibleDirectGymToCampusIsAConflictRatherThanUnknownRoute() {
        var p = preferences(); p.travelMinutes["gym>university"] = 30; p.travelMinutes["university>home"] = 60
        let events = [event("Sport", "2026-10-26 08:00", "2026-10-26 10:50", place: "gym"), event("Uni", "2026-10-26 11:00", "2026-10-26 12:00")]
        let result = StudyPlannerEngine.availability(events: events, preferences: p, horizon: day)
        XCTAssertTrue(result.issues.contains { $0.message.contains("Zu wenig Zeit") })
        XCTAssertFalse(result.windows.contains { $0.interval.contains(date("2026-10-26 10:55")) })
    }
}

extension CalendarPlannerTests {
    func testTwoHourCampusBreakNeverCreatesHomeDetourEvenWhenCampusLearningDisabled() {
        var p = preferences(); p.assumeSymmetricReturn = true; p.learningLocations.remove("university")
        let events = [event("Vormittag", "2026-10-26 09:00", "2026-10-26 12:00"), event("Nachmittag", "2026-10-26 14:00", "2026-10-26 16:00")]
        let result = StudyPlannerEngine.availability(events: events, preferences: p, horizon: day)
        XCTAssertTrue(result.issues.isEmpty)
        XCTAssertEqual(result.journeys.count, 2)
        XCTAssertEqual(result.journeys.map(\.from), ["home", "university"])
        XCTAssertEqual(result.journeys.map(\.to), ["university", "home"])
        XCTAssertEqual(result.journeys.last?.start, date("2026-10-26 16:00"))
        XCTAssertFalse(result.windows.contains { $0.interval.contains(date("2026-10-26 13:00")) })
    }
    func testImportedTuesdayPatternLeavesBreakOnCampusAndReturnsAfterLastLecture() {
        var p = preferences(); p.assumeSymmetricReturn = true
        let events = [event("A", "2026-10-27 08:00", "2026-10-27 09:30"), event("B", "2026-10-27 09:45", "2026-10-27 11:15"), event("C", "2026-10-27 11:30", "2026-10-27 13:00"), event("D", "2026-10-27 13:00", "2026-10-27 14:00"), event("E", "2026-10-27 15:45", "2026-10-27 17:15"), event("F", "2026-10-27 17:30", "2026-10-27 19:00")]
        let horizon = DateInterval(start: date("2026-10-27 00:00"), end: date("2026-10-28 00:00"))
        let result = StudyPlannerEngine.availability(events: events, preferences: p, horizon: horizon)
        XCTAssertTrue(result.issues.isEmpty)
        XCTAssertEqual(result.journeys.count, 2)
        XCTAssertEqual(result.journeys.first?.start, date("2026-10-27 07:00"))
        XCTAssertEqual(result.journeys.first?.end, date("2026-10-27 08:00"))
        XCTAssertEqual(result.journeys.last?.start, date("2026-10-27 19:00"))
        XCTAssertEqual(result.journeys.last?.end, date("2026-10-27 20:00"))
        XCTAssertEqual(result.journeys.last?.estimatedReturn, true)
        XCTAssertFalse(result.windows.contains { $0.location == "university" })
        XCTAssertFalse(result.windows.contains { $0.location == "home" && $0.interval.start < date("2026-10-27 20:00") })
    }
    func testLegacyPreferencesInferReturnButExplicitDurationAndOptOutWin() throws {
        let data = try JSONEncoder().encode(PlannerPreferences())
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        object.removeValue(forKey: "assumeSymmetricReturn")
        var p = try JSONDecoder().decode(PlannerPreferences.self, from: JSONSerialization.data(withJSONObject: object))
        XCTAssertEqual(p.travel(from: "university", to: "home"), 60)
        XCTAssertTrue(p.returnIsEstimated(from: "university", to: "home"))
        p.travelMinutes["university>home"] = 45
        XCTAssertEqual(p.travel(from: "university", to: "home"), 45)
        XCTAssertFalse(p.returnIsEstimated(from: "university", to: "home"))
        p.travelMinutes.removeValue(forKey: "university>home"); p.assumeSymmetricReturn = false
        XCTAssertNil(p.travel(from: "university", to: "home"))
        XCTAssertNil(p.travel(from: "university", to: "gym"))
    }
    func testFootballAfterUniversityStartsFromHomeWithInferredReturnDuration() {
        var p = preferences(); p.assumeSymmetricReturn = true; p.travelMinutes["university>gym"] = 30
        let events = [event("Uni", "2026-10-26 09:00", "2026-10-26 12:00"), event("Fußball", "2026-10-26 18:00", "2026-10-26 19:30", place: "gym")]
        let result = StudyPlannerEngine.availability(events: events, preferences: p, horizon: day)
        XCTAssertTrue(result.issues.isEmpty)
        XCTAssertEqual(result.journeys.count, 4)
        XCTAssertEqual(result.journeys[1].from, "university")
        XCTAssertEqual(result.journeys[1].to, "home")
        XCTAssertEqual(result.journeys[1].start, date("2026-10-26 12:00"))
        XCTAssertEqual(result.journeys[2].from, "home")
        XCTAssertEqual(result.journeys[2].to, "gym")
        XCTAssertEqual(result.journeys[2].start, date("2026-10-26 17:45"))
        XCTAssertEqual(result.journeys.last?.start, date("2026-10-26 19:30"))
    }
    func testPreferredHomeRouteDoesNotRequireDirectCampusToTrainingDuration() {
        var p = preferences(); p.assumeSymmetricReturn = true; p.learningLocations.remove("university")
        let events = [event("Uni", "2026-10-26 09:00", "2026-10-26 12:00"), event("Fußball", "2026-10-26 14:00", "2026-10-26 15:00", place: "gym")]
        let result = StudyPlannerEngine.availability(events: events, preferences: p, horizon: day)
        XCTAssertTrue(result.issues.isEmpty)
        XCTAssertEqual(result.journeys.count, 4)
        XCTAssertEqual(result.journeys[1].to, "home")
        XCTAssertEqual(result.journeys[2].from, "home")
        XCTAssertTrue(result.windows.contains { $0.location == "home" && $0.interval.contains(date("2026-10-26 13:30")) })
    }
    func testJourneysOutsideLearningHoursAndOnNonLearningDayRemainVisible() {
        var p = preferences(); p.assumeSymmetricReturn = true; p.weekdays = [3]
        let events = [event("Uni", "2026-10-26 08:00", "2026-10-26 12:00")]
        let result = StudyPlannerEngine.availability(events: events, preferences: p, horizon: day)
        XCTAssertTrue(result.windows.isEmpty)
        XCTAssertEqual(result.journeys.first?.start, date("2026-10-26 07:00"))
        XCTAssertEqual(result.journeys.count, 2)
    }
    func testCancellingLastLectureRecomputesReturnWithoutPersistingExtraEvents() throws {
        var p = preferences(); p.assumeSymmetricReturn = true
        var events = [event("Früh", "2026-10-26 09:00", "2026-10-26 12:00"), event("Spät", "2026-10-26 14:00", "2026-10-26 16:00")]
        let first = StudyPlannerEngine.availability(events: events, preferences: p, horizon: day)
        XCTAssertEqual(first.journeys.last?.start, date("2026-10-26 16:00"))
        events[1].excludedDays.insert("2026-10-26")
        let second = StudyPlannerEngine.availability(events: events, preferences: p, horizon: day)
        XCTAssertEqual(second.journeys.last?.start, date("2026-10-26 12:00"))
        XCTAssertEqual(second.journeys, StudyPlannerEngine.availability(events: events, preferences: p, horizon: day).journeys)
        let db = try AppDatabase.makeTemporary(); var workspace = CalendarWorkspace(); workspace.events = events; workspace.preferences = p
        try CalendarRepository(database: db).save(workspace)
        XCTAssertEqual(try CalendarRepository(database: db).load().events.count, 2)
    }
}

extension CalendarPlannerTests {
    func testThursdayTrainingReturnsHomeAfterLastUniversityAndLeavesFromHomeLater() {
        var p = preferences(); p.assumeSymmetricReturn = true
        let events = [event("Uni", "2026-10-29 08:00", "2026-10-29 09:30"), event("Fußball", "2026-10-29 19:00", "2026-10-29 21:30", place: "gym")]
        let horizon = DateInterval(start: date("2026-10-29 00:00"), end: date("2026-10-30 00:00"))
        let result = StudyPlannerEngine.availability(events: events, preferences: p, horizon: horizon)
        XCTAssertTrue(result.issues.isEmpty)
        XCTAssertEqual(result.journeys.count, 4)
        XCTAssertEqual(result.journeys[1].interval, DateInterval(start: date("2026-10-29 09:30"), end: date("2026-10-29 10:30")))
        XCTAssertEqual(result.journeys[2].interval, DateInterval(start: date("2026-10-29 18:45"), end: date("2026-10-29 19:00")))
        XCTAssertEqual(result.journeys.last?.end, date("2026-10-29 21:45"))
        XCTAssertTrue(result.windows.contains { $0.location == "home" && $0.interval == DateInterval(start: date("2026-10-29 10:30"), end: date("2026-10-29 18:45")) })
        XCTAssertFalse(result.windows.contains { $0.location == "university" })
    }
    func testShortGapReportsImpossibleHomeReturnAndUsesOnlyFeasibleKnownDirectRoute() {
        var p = preferences(); p.assumeSymmetricReturn = true; p.travelMinutes["university>gym"] = 10
        let events = [event("Uni", "2026-10-26 09:00", "2026-10-26 17:30"), event("Fußball", "2026-10-26 18:00", "2026-10-26 19:00", place: "gym")]
        let result = StudyPlannerEngine.availability(events: events, preferences: p, horizon: day)
        XCTAssertTrue(result.issues.contains { $0.message.contains("Heimweg") })
        XCTAssertEqual(result.journeys[1].from, "university")
        XCTAssertEqual(result.journeys[1].to, "gym")
        XCTAssertEqual(result.journeys[1].start, date("2026-10-26 17:50"))
        XCTAssertFalse(result.journeys.contains { $0.to == "home" && $0.start < date("2026-10-26 19:00") })
    }
    func testTrainingBetweenCampusAppointmentsDoesNotEndTheUniversityDayEarly() {
        var p = preferences(); p.assumeSymmetricReturn = true; p.travelMinutes["university>gym"] = 15; p.travelMinutes["gym>university"] = 15
        let events = [event("Uni", "2026-10-26 09:00", "2026-10-26 12:00"), event("Sport", "2026-10-26 14:00", "2026-10-26 15:00", place: "gym"), event("Uni spät", "2026-10-26 16:00", "2026-10-26 17:00")]
        let result = StudyPlannerEngine.availability(events: events, preferences: p, horizon: day)
        XCTAssertTrue(result.issues.isEmpty)
        XCTAssertEqual(result.journeys.count, 4)
        XCTAssertFalse(result.journeys.contains { $0.to == "home" && $0.start < date("2026-10-26 17:00") })
    }
    func testOldCampusSuggestionMovesHomeAfterUniversityReturnWithoutChangingPinnedHistory() {
        var w = CalendarWorkspace(); w.preferences = preferences(); w.preferences.assumeSymmetricReturn = true
        w.events = [event("Uni", "2026-10-26 09:00", "2026-10-26 12:00"), event("Sport", "2026-10-26 18:00", "2026-10-26 19:00", place: "gym")]
        var t = topic(); t.nextReview = date("2026-10-26 13:30"); w.topics = [t]
        let old = StudySession(topicID: t.id, start: date("2026-10-26 13:30"), end: date("2026-10-26 13:55"), location: "university")
        w.sessions = [old]
        let result = StudyPlannerEngine.plan(w, now: now)
        XCTAssertEqual(result.sessions.first?.location, "home")
        XCTAssertFalse(result.sessions.contains { $0.location == "university" })
        w.sessions[0].pinned = true
        let pinned = StudyPlannerEngine.plan(w, now: now)
        XCTAssertEqual(pinned.sessions.first?.location, "university")
        XCTAssertTrue(pinned.issues.contains { $0.message.contains("Fixierter/laufender") })
    }
}

extension CalendarPlannerTests {
    func testOutboundJourneyToNextHorizonDayReservesPreviousEvening() {
        var w = CalendarWorkspace(); w.preferences = preferences(); w.preferences.dayStartMinute = 22 * 60; w.preferences.dayEndMinute = 1439
        w.events = [event("Nachttermin", "2026-11-09 00:15", "2026-11-09 00:45")]
        var t = topic(minutes: 90); t.nextReview = date("2026-11-08 22:00"); w.topics = [t]
        let result = StudyPlannerEngine.plan(w, now: now)
        XCTAssertTrue(result.sessions.isEmpty)
        XCTAssertNotNil(result.unplaced[t.id])
        let horizon = DateInterval(start: date("2026-11-08 00:00"), end: date("2026-11-09 00:00"))
        let availability = StudyPlannerEngine.availability(events: w.events, preferences: w.preferences, horizon: horizon)
        XCTAssertEqual(availability.journeys.first?.start, date("2026-11-08 23:15"))
        XCTAssertFalse(availability.windows.contains { $0.interval.contains(date("2026-11-08 23:20")) })
    }
    func testReturnJourneyFromPreviousDayReservesStartOfRequestedDay() {
        var p = preferences(); p.dayStartMinute = 0; p.travelMinutes["university>home"] = 60
        let events = [event("Spättermin", "2026-10-25 22:30", "2026-10-25 23:45")]
        let result = StudyPlannerEngine.availability(events: events, preferences: p, horizon: day)
        XCTAssertEqual(result.journeys.first?.end, date("2026-10-26 00:45"))
        XCTAssertFalse(result.windows.contains { $0.interval.contains(date("2026-10-26 00:15")) })
        XCTAssertEqual(result.windows.first?.interval.start, date("2026-10-26 00:45"))
    }
    @MainActor
    func testManualMoveRejectsJourneyToAppointmentOutsideSelectedDay() throws {
        let db = try AppDatabase.makeTemporary(); var w = CalendarWorkspace(); w.preferences = preferences()
        w.preferences.dayStartMinute = 22 * 60; w.preferences.dayEndMinute = 1439
        w.events = [event("Nachttermin", "2026-11-09 00:15", "2026-11-09 00:45")]
        var t = topic(minutes: 90); t.nextReview = date("2026-11-07 22:00"); w.topics = [t]
        let existing = StudySession(topicID: t.id, start: date("2026-11-07 22:00"), end: date("2026-11-07 23:30"))
        w.sessions = [existing]; try CalendarRepository(database: db).save(w)
        let store = CalendarPlannerStore(database: db, now: { self.now })
        XCTAssertFalse(store.moveSession(existing.id, start: date("2026-11-08 22:00")))
        XCTAssertEqual(store.workspace.sessions.first?.start, existing.start)
    }
}

extension CalendarPlannerTests {
    func testMalformedICSPropertyNameProducesWarningWithoutCrashing() throws {
        let malformed = sampleICS.replacingOccurrences(of: "UID:lecture-1", with: "UID:lecture-1\r\n:oops\r\n;VALUE=TEXT:broken")
        let draft = try ICSImporter.parse(data: ics(malformed), sourceID: "test", sourceName: "Beispiel")
        XCTAssertEqual(draft.events.count, 1)
        XCTAssertTrue(draft.warnings.contains { $0.contains("unlesbare Kalenderfelder") })
    }
    @MainActor
    func testReviewUsesOneTimestampForDurationAndFeedbackEvenWhenClockAdvances() throws {
        let db = try AppDatabase.makeTemporary(); var tick = now
        let store = CalendarPlannerStore(database: db, now: { tick = tick.addingTimeInterval(0.125); return tick })
        XCTAssertTrue(store.saveTopic(topic()))
        let id = try XCTUnwrap(store.workspace.sessions.first?.id)
        XCTAssertTrue(store.review(id, rating: .good, actualMinutes: 25))
        let completed = try XCTUnwrap(store.workspace.sessions.first { $0.id == id })
        XCTAssertEqual(completed.minutes, 25)
        XCTAssertEqual(completed.end.timeIntervalSince(completed.start), 1500)
        XCTAssertEqual(completed.reviewedAt, completed.end)
    }
}

extension CalendarPlannerTests {
    private func automaticWorkspace() -> CalendarWorkspace {
        var w = CalendarWorkspace(); w.preferences = preferences(); w.preferences.automaticModulePlanning = true; w.preferences.assumeSymmetricReturn = true
        return w
    }
    func testModulesAreCreatedWithoutManualTopicsAndSameDayLecturesAreGrouped() {
        var w = automaticWorkspace()
        w.events = [event("Mathematik (33-12345)", "2026-10-27 09:00", "2026-10-27 10:30"), event("Mathematik (33-12345)", "2026-10-27 12:00", "2026-10-27 13:30")]
        let result = StudyPlannerEngine.plan(w, now: now)
        XCTAssertEqual(result.topics.count, 2)
        XCTAssertEqual(Set(result.topics.compactMap { $0.automaticTask?.phase }), [.preparation, .followUp])
        XCTAssertTrue(result.topics.allSatisfy { $0.course == "Mathematik" })
        XCTAssertEqual(result.sessions.count, 2)
        let byID = Dictionary(uniqueKeysWithValues: result.topics.map { ($0.id, $0) })
        for session in result.sessions {
            let task = byID[session.topicID]!.automaticTask!
            XCTAssertGreaterThanOrEqual(session.start, task.earliestStart)
            XCTAssertLessThanOrEqual(session.end, task.latestEnd)
            if task.phase == .followUp { XCTAssertGreaterThanOrEqual(session.start, date("2026-10-27 13:30")) }
        }
    }
    func testPreparationPrefersPriorDayAndFollowUpWaitsForHomeJourney() {
        var w = automaticWorkspace(); w.events = [event("Analysis", "2026-10-27 09:00", "2026-10-27 12:00")]
        let result = StudyPlannerEngine.plan(w, now: now)
        let prep = result.topics.first { $0.automaticTask?.phase == .preparation }!
        let follow = result.topics.first { $0.automaticTask?.phase == .followUp }!
        XCTAssertEqual(result.sessions.first { $0.topicID == prep.id }?.start, date("2026-10-26 09:00"))
        let session = result.sessions.first { $0.topicID == follow.id }!
        XCTAssertGreaterThanOrEqual(session.start, date("2026-10-27 13:00"))
        XCTAssertEqual(session.location, "home")
    }
    func testAutomaticModuleBlocksRespectLimitBreaksAndTraining() {
        var w = automaticWorkspace(); w.preferences.dailyLimitMinutes = 50
        w.events = [event("Mathe", "2026-10-27 09:00", "2026-10-27 12:00"), event("Physik", "2026-10-27 13:00", "2026-10-27 14:00"), PlannerEvent(title: "Fußball", kind: .training, start: date("2026-10-27 18:00"), end: date("2026-10-27 20:00"), location: "gym")]
        let result = StudyPlannerEngine.plan(w, now: now)
        let availability = StudyPlannerEngine.availability(events: w.events, preferences: w.preferences, horizon: DateInterval(start: date("2026-10-26 00:00"), end: date("2026-11-09 00:00")))
        for session in result.sessions {
            XCTAssertTrue(availability.windows.contains { $0.location == session.location && $0.interval.start <= session.start && session.end <= $0.interval.end })
        }
        let days = Dictionary(grouping: result.sessions, by: { PlannerDate.dayKey($0.start, calendar: calendar) })
        for values in days.values {
            XCTAssertLessThanOrEqual(values.reduce(0) { $0 + $1.minutes }, 50)
            let sorted = values.sorted { $0.start < $1.start }
            for pair in zip(sorted, sorted.dropFirst()) { XCTAssertGreaterThanOrEqual(pair.1.start.timeIntervalSince(pair.0.end), 600) }
        }
    }
    func testOnlyUniversityEventsGenerateModuleTasksAndNoPastPreparationIsInvented() {
        var w = automaticWorkspace()
        w.events = [event("Analysis", "2026-10-26 07:00", "2026-10-26 09:00"), PlannerEvent(title: "Training", kind: .training, start: date("2026-10-27 18:00"), end: date("2026-10-27 19:00"), location: "gym"), PlannerEvent(title: "Privat", kind: .personal, start: date("2026-10-27 14:00"), end: date("2026-10-27 15:00"))]
        let result = StudyPlannerEngine.plan(w, now: now)
        XCTAssertEqual(result.topics.count, 1)
        XCTAssertEqual(result.topics.first?.automaticTask?.phase, .followUp)
    }
    func testChangingLectureTimesUpdatesDeadlinesWithStableTaskIdentity() {
        var w = automaticWorkspace(); w.events = [event("Analysis", "2026-10-27 09:00", "2026-10-27 12:00")]
        let first = StudyPlannerEngine.plan(w, now: now); w.topics = first.topics; w.sessions = first.sessions
        let ids = Set(first.topics.map(\.id))
        w.events[0].start = date("2026-10-27 10:00"); w.events[0].end = date("2026-10-27 14:00")
        let changed = StudyPlannerEngine.plan(w, now: now)
        XCTAssertEqual(Set(changed.topics.map(\.id)), ids)
        let followID = changed.topics.first { $0.automaticTask?.phase == .followUp }!.id
        XCTAssertGreaterThanOrEqual(changed.sessions.first { $0.topicID == followID }!.start, date("2026-10-27 15:00"))
    }
    func testCancelledLectureRemovesFlexibleModulePhasesButPreservesPinnedConflict() {
        var w = automaticWorkspace(); w.events = [event("Analysis", "2026-10-27 09:00", "2026-10-27 12:00")]
        let first = StudyPlannerEngine.plan(w, now: now); w.topics = first.topics; w.sessions = first.sessions
        w.events[0].cancelled = true
        XCTAssertTrue(StudyPlannerEngine.plan(w, now: now).sessions.isEmpty)
        w.sessions[0].pinned = true
        let pinned = StudyPlannerEngine.plan(w, now: now)
        XCTAssertEqual(pinned.sessions.count, 1)
        XCTAssertTrue(pinned.issues.contains { $0.message.contains("keinen aktiven") })
    }
    func testModuleNormalizationUsesCourseCodeWithoutMergingDifferentCodes() {
        XCTAssertEqual(ModuleStudyPlanner.module(for: "Analysis (33-12345)")?.key, ModuleStudyPlanner.module(for: "Analysis Übung (33-12345)")?.key)
        XCTAssertNotEqual(ModuleStudyPlanner.module(for: "Seminar (33-12345)")?.key, ModuleStudyPlanner.module(for: "Seminar (33-67890)")?.key)
        XCTAssertEqual(ModuleStudyPlanner.module(for: "  MATHE  ")?.key, ModuleStudyPlanner.module(for: "Mathe")?.key)
        XCTAssertNil(ModuleStudyPlanner.module(for: "Ohne Titel"))
    }
    func testAutomaticModulesAreDeterministicAndCompletedTaskIsNotRecreated() {
        var w = automaticWorkspace(); w.events = [event("Analysis", "2026-10-27 09:00", "2026-10-27 12:00")]
        let first = StudyPlannerEngine.plan(w, now: now)
        XCTAssertEqual(first.sessions, StudyPlannerEngine.plan(w, now: now).sessions)
        w.topics = first.topics; w.sessions = first.sessions
        let id = w.sessions[0].topicID; w.sessions[0].status = .completed; w.sessions[0].actualMinutes = 40; w.sessions[0].reviewedAt = now
        let next = StudyPlannerEngine.plan(w, now: now)
        XCTAssertFalse(next.sessions.contains { $0.status == .planned && $0.topicID == id })
        XCTAssertEqual(next.topics.first { $0.id == id }?.archived, true)
    }
    @MainActor
    func testImportAndNewCalendarEventsAutomaticallyRegenerateModulesWithoutManualSetup() throws {
        let db = try AppDatabase.makeTemporary(); let store = CalendarPlannerStore(database: db, now: { self.now })
        let draft = try ICSImporter.parse(data: ics(sampleICS), sourceID: "s", sourceName: "Uni")
        store.importChanges(draft, overwriteLocal: false, removeMissing: false)
        XCTAssertFalse(store.workspace.topics.isEmpty)
        XCTAssertTrue(store.workspace.topics.allSatisfy { $0.automaticTask != nil })
        let ids = Set(store.workspace.topics.map(\.id))
        store.importChanges(draft, overwriteLocal: false, removeMissing: false)
        XCTAssertEqual(Set(store.workspace.topics.map(\.id)), ids)
        let before = store.workspace.sessions
        XCTAssertTrue(store.saveEvent(PlannerEvent(title: "Neu belegt", kind: .personal, start: before[0].start, end: before[0].end)))
        XCTAssertNotEqual(store.workspace.sessions, before)
        XCTAssertEqual(try CalendarRepository(database: db).load().topics, store.workspace.topics)
    }
    func testLegacyWorkspaceDefaultsToAutomaticModulePlanningAndCanOptOut() throws {
        var w = automaticWorkspace(); w.events = [event("Mathe", "2026-10-27 09:00", "2026-10-27 12:00")]
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(w)) as? [String: Any])
        var prefs = try XCTUnwrap(object["preferences"] as? [String: Any]); prefs.removeValue(forKey: "automaticModulePlanning"); object["preferences"] = prefs
        let decoded = try JSONDecoder().decode(CalendarWorkspace.self, from: JSONSerialization.data(withJSONObject: object))
        XCTAssertTrue(decoded.preferences.modulePlanningEnabled)
        XCTAssertEqual(StudyPlannerEngine.plan(decoded, now: now).topics.count, 2)
        w.preferences.automaticModulePlanning = false
        XCTAssertTrue(StudyPlannerEngine.plan(w, now: now).topics.isEmpty)
    }
    @MainActor
    func testCompletedAutomaticPhasePersistsWithoutGeneratingUnrelatedReviewAndLearnsDuration() throws {
        let store = CalendarPlannerStore(database: try AppDatabase.makeTemporary(), now: { self.now })
        XCTAssertTrue(store.saveEvent(event("Analysis", "2026-10-27 09:00", "2026-10-27 12:00")))
        let session = store.workspace.sessions.first!
        XCTAssertTrue(store.review(session.id, rating: .good, actualMinutes: 40))
        XCTAssertFalse(store.workspace.sessions.contains { $0.status == .planned && $0.topicID == session.topicID })
        XCTAssertTrue(store.saveEvent(event("Analysis", "2026-11-03 09:00", "2026-11-03 12:00")))
        let completedPhase = store.workspace.topics.first { $0.id == session.topicID }!.automaticTask!.phase
        let next = store.workspace.topics.first { $0.automaticTask?.phase == completedPhase && $0.automaticTask?.teachingDay == "2026-11-03" }!
        XCTAssertEqual(next.estimatedMinutes, 40)
    }
}

extension CalendarPlannerTests {
    @MainActor
    func testSkippingAutomaticPreparationDefersItAndDoesNotRecreateDeclinedSlot() throws {
        let store = CalendarPlannerStore(database: try AppDatabase.makeTemporary(), now: { self.now })
        XCTAssertTrue(store.saveEvent(event("Analysis", "2026-10-28 12:00", "2026-10-28 14:00")))
        let task = store.workspace.topics.first { $0.automaticTask?.phase == .preparation }!
        let old = store.workspace.sessions.first { $0.topicID == task.id }!
        store.skip(old.id)
        let next = store.workspace.sessions.first { $0.topicID == task.id && $0.status == .planned }
        XCTAssertNotEqual(next?.id, old.id)
        if let next { XCTAssertGreaterThan(next.start, calendar.startOfDay(for: old.start).addingTimeInterval(86400 - 1)) }
        XCTAssertNotNil(store.workspace.topics.first { $0.id == task.id }?.automaticTask?.deferredUntil)
    }
    @MainActor
    func testFollowUpCannotBeCompletedBeforeItsLecture() throws {
        let store = CalendarPlannerStore(database: try AppDatabase.makeTemporary(), now: { self.now })
        XCTAssertTrue(store.saveEvent(event("Analysis", "2026-10-27 09:00", "2026-10-27 12:00")))
        let follow = store.workspace.topics.first { $0.automaticTask?.phase == .followUp }!
        let session = store.workspace.sessions.first { $0.topicID == follow.id }!
        XCTAssertFalse(store.review(session.id, rating: .good, actualMinutes: 25))
        XCTAssertEqual(store.workspace.sessions.first { $0.id == session.id }?.status, .planned)
    }
    func testPreparationCannotPrecedePreviousTeachingDayOfSameModule() {
        var w = automaticWorkspace(); w.events = [event("Analysis", "2026-10-27 09:00", "2026-10-27 12:00"), event("Analysis", "2026-10-28 10:00", "2026-10-28 12:00")]
        let result = StudyPlannerEngine.plan(w, now: now)
        let prep = result.topics.first { $0.automaticTask?.phase == .preparation && $0.automaticTask?.teachingDay == "2026-10-28" }!
        XCTAssertGreaterThanOrEqual(prep.nextReview, date("2026-10-27 12:10"))
    }
    func testOverloadedAutomaticModulesRemainUnplacedRatherThanExceedingDailyLimit() {
        var w = automaticWorkspace(); w.preferences.dailyLimitMinutes = 25
        w.events = (0..<10).map { index in event("Modul \(index)", "2026-10-27 09:00", "2026-10-27 12:00") }
        let result = StudyPlannerEngine.plan(w, now: now)
        XCTAssertFalse(result.unplaced.isEmpty)
        let groups = Dictionary(grouping: result.sessions, by: { PlannerDate.dayKey($0.start, calendar: calendar) })
        XCTAssertTrue(groups.values.allSatisfy { $0.reduce(0) { $0 + $1.minutes } <= 25 })
    }
}

extension CalendarPlannerTests {
    func testFridayFollowUpCarriesOverToNextAllowedMonday() {
        var w = automaticWorkspace(); w.preferences.weekdays = Set(2...6)
        w.events = [event("Analysis", "2026-10-23 17:00", "2026-10-23 20:00")]
        let result = StudyPlannerEngine.plan(w, now: now)
        let follow = result.topics.first { $0.automaticTask?.phase == .followUp }!
        let session = result.sessions.first { $0.topicID == follow.id }!
        XCTAssertTrue(calendar.isDate(session.start, inSameDayAs: now))
        XCTAssertEqual(follow.planningDeadline, date("2026-10-26 21:00"))
    }
    func testMondayPreparationUsesPreviousAllowedFridayInsteadOfDisabledWeekend() {
        var w = automaticWorkspace(); w.preferences.weekdays = Set(2...6)
        w.events = [event("Analysis", "2026-11-02 09:00", "2026-11-02 12:00")]
        let result = StudyPlannerEngine.plan(w, now: now)
        let prep = result.topics.first { $0.automaticTask?.phase == .preparation }!
        XCTAssertEqual(result.sessions.first { $0.topicID == prep.id }?.start, date("2026-10-30 09:00"))
    }
}

extension CalendarPlannerTests {
    func testReconstructsAutomaticIdentityIfOlderAppIgnoredNewOptionalMetadata() {
        var w = automaticWorkspace(); w.events = [event("Analysis", "2026-10-27 09:00", "2026-10-27 12:00")]
        let first = StudyPlannerEngine.plan(w, now: now); w.sessions = first.sessions
        w.topics = first.topics.map { topic in var value = topic; value.automaticTask = nil; return value }
        let result = StudyPlannerEngine.plan(w, now: now)
        XCTAssertEqual(result.topics.count, 2)
        XCTAssertEqual(Set(result.topics.map(\.id)).count, 2)
        XCTAssertTrue(result.topics.allSatisfy { $0.automaticTask != nil })
    }
    func testApplicationTestHostFactoryDoesNotOpenUserDataFolder() throws {
        let db = try AppDatabase.makeForApplication(environment: ["XCTestConfigurationFilePath": "fixture.xctestconfiguration"])
        let path = try db.writer.read { db in try Row.fetchOne(db, sql: "PRAGMA database_list")?["file"] as String? }
        XCTAssertNotNil(path)
        XCTAssertFalse(path!.contains("Application Support/AboLife"))
        XCTAssertTrue(path!.contains("T/") || path!.contains("tmp"))
    }
}


extension CalendarPlannerTests {
    func testLateUniversityDayBlocksMorningAndAllCampusBreaksEvenWithLegacyPreference() {
        var p = preferences(); p.assumeSymmetricReturn = true; p.learningLocations.insert("university")
        let events = [event("A", "2026-10-26 12:00", "2026-10-26 13:00"), event("B", "2026-10-26 15:00", "2026-10-26 16:00")]
        let result = StudyPlannerEngine.availability(events: events, preferences: p, horizon: day)
        XCTAssertTrue(result.issues.isEmpty)
        XCTAssertEqual(result.windows, [StudyFreeWindow(interval: DateInterval(start: date("2026-10-26 17:00"), end: date("2026-10-26 21:00")), location: "home")])
        XCTAssertEqual(result.journeys.map(\.start), [date("2026-10-26 11:00"), date("2026-10-26 16:00")])
    }
    func testNonUniversityDayAndCancelledLectureKeepMorningAvailable() {
        var lecture = event("Abgesagt", "2026-10-26 12:00", "2026-10-26 14:00"); lecture.cancelled = true
        let result = StudyPlannerEngine.availability(events: [lecture], preferences: preferences(), horizon: day)
        XCTAssertEqual(result.windows.first?.interval.start, now)
        XCTAssertTrue(result.universityDays.isEmpty)
    }
    func testUnknownHomeReturnDoesNotAllowLearningBeforeLateUniversity() {
        let result = StudyPlannerEngine.availability(events: [event("Uni", "2026-10-26 14:00", "2026-10-26 16:00")], preferences: preferences(), horizon: day)
        XCTAssertTrue(result.windows.isEmpty)
        XCTAssertTrue(result.issues.contains { $0.message.contains("Rückfahrt") })
    }
    func testOnlineUniversityAtHomeAlsoBlocksMorningUntilLastClass() {
        var online = event("Online", "2026-10-26 12:00", "2026-10-26 14:00", place: "home"); online.kind = .university
        let result = StudyPlannerEngine.availability(events: [online], preferences: preferences(), horizon: day)
        XCTAssertTrue(result.journeys.isEmpty)
        XCTAssertEqual(result.windows.first?.interval.start, date("2026-10-26 14:00"))
    }
    func testAutomaticPreparationUsesPreviousDayAfterItsUniversityReturn() throws {
        var w = automaticWorkspace()
        w.events = [event("Montagsmodul", "2026-10-26 09:00", "2026-10-26 12:00"), event("Dienstagsmodul", "2026-10-27 14:00", "2026-10-27 16:00")]
        let result = StudyPlannerEngine.plan(w, now: now)
        let prep = try XCTUnwrap(result.topics.first { $0.course == "Dienstagsmodul" && $0.automaticTask?.phase == .preparation })
        let block = try XCTUnwrap(result.sessions.first { $0.topicID == prep.id })
        XCTAssertTrue(calendar.isDate(block.start, inSameDayAs: now))
        XCTAssertGreaterThanOrEqual(block.start, date("2026-10-26 13:00"))
        XCTAssertEqual(block.location, "home")
        let tooLate = try XCTUnwrap(result.topics.first { $0.course == "Montagsmodul" && $0.automaticTask?.phase == .preparation })
        XCTAssertNotNil(result.unplaced[tooLate.id])
        XCTAssertTrue(result.sessions.filter { calendar.isDate($0.start, inSameDayAs: now) }.allSatisfy { $0.start >= date("2026-10-26 13:00") })
    }
    func testUnconfirmedRunningCampusSuggestionMovesButCompletedHistoryRemains() throws {
        var w = CalendarWorkspace(); w.preferences = preferences(); w.preferences.assumeSymmetricReturn = true
        w.events = [event("Uni", "2026-10-26 09:00", "2026-10-26 12:00")]; w.topics = [topic("Lernen"), topic("Vergangenheit")]
        let old = StudySession(topicID: w.topics[0].id, start: date("2026-10-26 10:00"), end: date("2026-10-26 10:25"), location: "university")
        var completed = StudySession(topicID: w.topics[1].id, start: date("2026-10-26 09:15"), end: date("2026-10-26 09:40"), location: "university"); completed.status = .completed
        w.topics[1].archived = true; w.sessions = [old, completed]
        let result = StudyPlannerEngine.plan(w, now: date("2026-10-26 10:10"))
        XCTAssertEqual(result.sessions.first { $0.id == completed.id }, completed)
        XCTAssertFalse(result.sessions.contains { $0.id == old.id })
        let replacement = try XCTUnwrap(result.sessions.first { $0.topicID == old.topicID })
        XCTAssertEqual(replacement.location, "home")
        XCTAssertGreaterThanOrEqual(replacement.start, date("2026-10-26 13:00"))
    }
    @MainActor
    func testAddingLateUniversityReplansMorningAndManualMoveCannotRestoreIt() throws {
        let store = CalendarPlannerStore(database: try AppDatabase.makeTemporary(), now: { self.now })
        var p = preferences(); p.assumeSymmetricReturn = true
        XCTAssertTrue(store.savePreferences(p)); XCTAssertTrue(store.saveTopic(topic()))
        XCTAssertEqual(store.workspace.sessions.first?.start, now)
        XCTAssertTrue(store.saveEvent(event("Uni", "2026-10-26 12:00", "2026-10-26 16:00")))
        let session = try XCTUnwrap(store.workspace.sessions.first)
        XCTAssertGreaterThanOrEqual(session.start, date("2026-10-26 17:00"))
        XCTAssertFalse(store.moveSession(session.id, start: date("2026-10-26 09:00")))
        XCTAssertEqual(store.workspace.sessions.first, session)
    }
    func testDirectTrainingAfterUniversityDoesNotUnlockLearningUntilHomeArrival() {
        var p = preferences(); p.assumeSymmetricReturn = true; p.travelMinutes["university>gym"] = 10
        let result = StudyPlannerEngine.availability(events: [event("Uni", "2026-10-26 14:00", "2026-10-26 17:30"), event("Sport", "2026-10-26 18:00", "2026-10-26 19:00", place: "gym")], preferences: p, horizon: day)
        XCTAssertEqual(result.windows.first?.interval.start, date("2026-10-26 19:15"))
        XCTAssertTrue(result.windows.allSatisfy { $0.location == "home" })
    }
}


extension CalendarPlannerTests {
    func testPreparationSpreadsAcrossWeekendWhenMondayAndTuesdayAreDisabled() throws {
        var w = automaticWorkspace(); w.preferences.weekdays = [1, 4, 5, 6, 7]; w.preferences.dailyLimitMinutes = 100
        w.events = [event("A", "2026-11-02 09:00", "2026-11-02 10:00"), event("B", "2026-11-02 11:00", "2026-11-02 12:00"), event("C", "2026-11-03 09:00", "2026-11-03 10:00"), event("D", "2026-11-03 11:00", "2026-11-03 12:00"), event("E", "2026-11-04 09:00", "2026-11-04 10:00"), event("F", "2026-11-04 11:00", "2026-11-04 12:00")]
        let result = StudyPlannerEngine.plan(w, now: now)
        let prepIDs = Set(result.topics.filter { $0.automaticTask?.phase == .preparation }.map(\.id))
        let prep = result.sessions.filter { prepIDs.contains($0.topicID) }
        XCTAssertEqual(prep.count, 6)
        XCTAssertEqual(Set(prep.map { calendar.component(.weekday, from: $0.start) }), [1, 7])
        XCTAssertFalse(result.sessions.contains { [2, 3].contains(calendar.component(.weekday, from: $0.start)) })
        let groups = Dictionary(grouping: result.sessions, by: { PlannerDate.dayKey($0.start, calendar: calendar) })
        XCTAssertTrue(groups.values.allSatisfy { $0.reduce(0) { $0 + $1.minutes } <= 100 })
        for session in prep {
            let task = try XCTUnwrap(result.topics.first { $0.id == session.topicID }?.automaticTask)
            XCTAssertLessThanOrEqual(session.end, task.firstLesson)
        }
    }
    func testTwoAllowedPreparationDaysCanSpanTwoWeeksForSparseLearningSchedule() throws {
        var w = automaticWorkspace(); w.preferences.weekdays = [4]
        w.events = [event("Analysis", "2026-11-06 09:00", "2026-11-06 12:00"), event("Ganztägig belegt", "2026-11-04 00:00", "2026-11-05 00:00", place: "home")]
        let result = StudyPlannerEngine.plan(w, now: now)
        let prep = try XCTUnwrap(result.topics.first { $0.automaticTask?.phase == .preparation })
        let session = try XCTUnwrap(result.sessions.first { $0.topicID == prep.id })
        XCTAssertTrue(calendar.isDate(session.start, inSameDayAs: date("2026-10-28 00:00")))
        XCTAssertEqual(prep.automaticTask?.earliestStart, date("2026-10-28 00:00"))
    }
}
