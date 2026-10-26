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
        PlannerEvent(title: title, kind: .university, start: date(start), end: date(end), location: place, timeZoneID: calendar.timeZone.identifier)
    }
    private func topic(_ title: String = "Thema", minutes: Int = 25) -> StudyTopic {
        StudyTopic(title: title, course: "Mathematik", durationMinutes: minutes, nextReview: now)
    }
    private func preferences() -> PlannerPreferences {
        var p = PlannerPreferences(); p.timeZoneID = calendar.timeZone.identifier; p.weekdays = Set(1...7); return p
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
        XCTAssertEqual(DatabaseConfiguration.applicationSupportFolderName, "AboLife-Calendar-Preview")
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
    func testDirectCampusGymTransferAllowsCampusLearningWithoutDoubleCommute() {
        var p = preferences(); p.travelMinutes["university>gym"] = 30; p.travelMinutes["gym>home"] = 15
        let events = [event("Uni", "2026-10-26 09:00", "2026-10-26 12:00"), event("Sport", "2026-10-26 18:00", "2026-10-26 19:00", place: "gym")]
        let result = StudyPlannerEngine.availability(events: events, preferences: p, horizon: day)
        XCTAssertTrue(result.issues.isEmpty)
        XCTAssertEqual(result.windows.first?.location, "university")
        XCTAssertEqual(result.windows.first?.interval, DateInterval(start: date("2026-10-26 12:00"), end: date("2026-10-26 17:30")))
        XCTAssertEqual(result.windows.last?.interval.start, date("2026-10-26 19:15"))
    }
    func testImpossibleFixedTransferIsReported() {
        var p = preferences(); p.travelMinutes["university>gym"] = 30; p.travelMinutes["gym>home"] = 15
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
        XCTAssertTrue(result.issues.contains { $0.message.contains("Fahrtzeit Uni") })
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
    func testDirectGymToCampusUsesCampusGapWithoutAssumingHomeReturn() {
        var p = preferences(); p.travelMinutes["gym>university"] = 15; p.travelMinutes["university>home"] = 60
        let events = [event("Sport", "2026-10-26 08:00", "2026-10-26 09:00", place: "gym"), event("Uni", "2026-10-26 11:00", "2026-10-26 12:00")]
        let result = StudyPlannerEngine.availability(events: events, preferences: p, horizon: day)
        XCTAssertTrue(result.issues.isEmpty)
        XCTAssertTrue(result.windows.contains { $0.location == "university" && $0.interval == DateInterval(start: date("2026-10-26 09:15"), end: date("2026-10-26 11:00")) })
    }
    func testImpossibleDirectGymToCampusIsAConflictRatherThanUnknownRoute() {
        var p = preferences(); p.travelMinutes["gym>university"] = 30; p.travelMinutes["university>home"] = 60
        let events = [event("Sport", "2026-10-26 08:00", "2026-10-26 10:50", place: "gym"), event("Uni", "2026-10-26 11:00", "2026-10-26 12:00")]
        let result = StudyPlannerEngine.availability(events: events, preferences: p, horizon: day)
        XCTAssertTrue(result.issues.contains { $0.message.contains("Zu wenig Zeit") })
        XCTAssertFalse(result.windows.contains { $0.interval.contains(date("2026-10-26 10:55")) })
    }
}
