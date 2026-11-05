import XCTest
import GRDB
@testable import AboLife

@MainActor final class AIAssistantTests: XCTestCase {
    func fixture() throws -> AppDatabase {
        let db = try AppDatabase.makeTemporary()
        try SettingsRepository(database: db).saveSettings(AppSettingsRecord(caloriesTarget: 2000, proteinTargetG: 100, monthlyBudget: 900))
        try FinanceRepository(database: db).insert(FinanceEntryRecord(title: "Private Ausgabe", amount: 10, category: "Freizeit"))
        var workspace = CalendarWorkspace()
        workspace.topics = [StudyTopic(id: "known-topic", title: "Private Lernaufgabe", course: "Informatik")]
        try CalendarRepository(database: db).save(workspace)
        return db
    }
    func testNoPermissionMeansNoPersonalContext() throws {
        let db = try fixture()
        let result = try AIContextBuilder(database: db).make(purpose: .daily, granted: [])
        XCTAssertTrue(result.sections.isEmpty)
        XCTAssertFalse(result.json.contains("Private"))
        XCTAssertTrue(result.calendarInstruction.contains("nicht freigegeben"))
    }
    func testCalendarContextUsesPlannerDayAndIncludesScheduledLearning() throws {
        let db = try fixture()
        let repository = CalendarRepository(database: db)
        var workspace = try repository.load()
        workspace.preferences.timeZoneID = "Asia/Tokyo"
        let now = ISO8601DateFormatter().date(from: "2026-11-02T16:00:00Z")!
        let calendar = workspace.preferences.calendar
        let today = calendar.startOfDay(for: now)
        let classStart = calendar.date(byAdding: .hour, value: 9, to: today)!
        let learningStart = calendar.date(byAdding: .hour, value: 14, to: today)!
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: classStart)!
        workspace.events = [
            PlannerEvent(title: "Seminar", kind: .university, start: classStart, end: classStart.addingTimeInterval(3600), location: "university"),
            PlannerEvent(title: "Morgiger Termin", kind: .personal, start: tomorrow, end: tomorrow.addingTimeInterval(3600)),
            PlannerEvent(title: "Abgesagt", kind: .personal, start: classStart, end: classStart.addingTimeInterval(3600), cancelled: true)
        ]
        workspace.sessions = [.init(topicID: "known-topic", start: learningStart, end: learningStart.addingTimeInterval(1800))]
        try repository.save(workspace)

        let builder = AIContextBuilder(database: db)
        let context = try builder.make(purpose: .daily, granted: [.calendar], now: now)
        let facts = try XCTUnwrap(context.sections.first?.facts)
        XCTAssertEqual(context.timeZone, "Asia/Tokyo")
        XCTAssertTrue(facts.contains { $0.contains("Heute") && $0.contains("2026-11-03T09:00:00+09:00") && $0.contains("Seminar") })
        XCTAssertTrue(facts.contains { $0.contains("Heute") && $0.contains("Lernblock") })
        XCTAssertTrue(facts.contains { $0.contains("Heute") && $0.contains("Hinfahrt zur Uni") })
        XCTAssertTrue(facts.contains { $0.contains("Morgiger Termin") && !$0.contains("Heute") })
        XCTAssertFalse(context.json.contains("Abgesagt"))
        XCTAssertFalse(context.json.contains("Private Lernaufgabe"))
        XCTAssertTrue(try builder.make(purpose: .daily, granted: [], now: now).sections.isEmpty)
    }
    func testPurposeFiltersEvenGrantedOtherDomains() throws {
        let db = try fixture()
        let result = try AIContextBuilder(database: db).make(purpose: .finance, granted: [.finance, .learning, .calendar, .training])
        XCTAssertEqual(result.sections.map(\.scope), [.finance])
        XCTAssertTrue(result.json.contains("900.00 EUR"))
        XCTAssertTrue(result.json.contains("10.00 EUR"))
        XCTAssertFalse(result.json.contains("Private Lernaufgabe"))
        XCTAssertFalse(result.json.contains("Private Ausgabe")) // only aggregates, no transaction descriptions
    }
    func testLearningContextDoesNotIncludeFinances() throws {
        let db = try fixture()
        let result = try AIContextBuilder(database: db).make(purpose: .learning, granted: [.learning, .finance])
        XCTAssertEqual(result.sections.map(\.scope), [.learning])
        XCTAssertTrue(result.json.contains("known-topic"))
        XCTAssertFalse(result.json.contains("900.00"))
        XCTAssertFalse(result.json.contains("Freies Lernfenster:"))
        XCTAssertTrue(result.json.contains("zusätzlich die Termine-Freigabe"))
    }
    func testNewsNeverClaimsFullArticleLoaded() throws {
        let db = try fixture()
        let result = try AIContextBuilder(database: db).make(purpose: .news, granted: [.news], news: [NewsArticle(title: "Geladene Überschrift", url: URL(string: "https://example.com/article")!, source: "Quelle", category: "Wissen", publishedAt: nil)])
        XCTAssertTrue(result.json.contains("Geladene Überschrift"))
        XCTAssertTrue(result.json.contains("Artikelvolltexte und externe Fakten wurden nicht abgerufen"))
    }
    func proposal(kind: AIActionKind = .createStudyTask) -> AIActionProposal {
        AIActionProposal(id: UUID().uuidString, kind: kind, title: "Bäume verstehen", course: "Informatik", durationMinutes: 25)
    }
    func testMissingActionPermissionRejected() throws {
        let executor = AIActionExecutor(database: try fixture())
        XCTAssertThrowsError(try executor.preview(proposal(), granted: []))
    }
    func testConfirmationRequiredAndConfirmedTaskIsSavedOnce() throws {
        let db = try fixture(); let executor = AIActionExecutor(database: db)
        let before = try CalendarRepository(database: db).load()
        let preview = try executor.preview(proposal(), granted: [.learning])
        XCTAssertThrowsError(try executor.execute(preview, confirmed: false, granted: [.learning]))
        XCTAssertEqual(try CalendarRepository(database: db).load(), before)
        try executor.execute(preview, confirmed: true, granted: [.learning])
        XCTAssertEqual(try CalendarRepository(database: db).load().topics.count, 2)
        XCTAssertThrowsError(try executor.execute(preview, confirmed: true, granted: [.learning]))
        XCTAssertEqual(try CalendarRepository(database: db).load().topics.count, 2)
    }
    func testPermissionRevocationBetweenPreviewAndConfirm() throws {
        let db = try fixture(); let executor = AIActionExecutor(database: db)
        let preview = try executor.preview(proposal(), granted: [.learning])
        XCTAssertThrowsError(try executor.execute(preview, confirmed: true, granted: []))
        XCTAssertEqual(try CalendarRepository(database: db).load().topics.count, 1)
    }
    func testStalePreviewCannotOverwriteCurrentData() throws {
        let db = try fixture(); let executor = AIActionExecutor(database: db)
        let preview = try executor.preview(proposal(), granted: [.learning])
        var workspace = try CalendarRepository(database: db).load()
        workspace.topics[0].title = "Zwischenzeitlich bearbeitet"
        try CalendarRepository(database: db).save(workspace)
        XCTAssertThrowsError(try executor.execute(preview, confirmed: true, granted: [.learning]))
        XCTAssertEqual(try CalendarRepository(database: db).load().topics[0].title, "Zwischenzeitlich bearbeitet")
    }
    func testUnknownCourseIsRejectedBeforeWriting() throws {
        let db = try fixture(); let executor = AIActionExecutor(database: db)
        var p = proposal(); p.course = "module/technical-id"
        XCTAssertThrowsError(try executor.preview(p, granted: [.learning]))
        XCTAssertEqual(try CalendarRepository(database: db).load().topics.count, 1)
    }
    func testUnknownTopicAndOverlappingStudyBlockRejected() throws {
        let db = try fixture(); let executor = AIActionExecutor(database: db)
        var workspace = try CalendarRepository(database: db).load()
        let cal = Calendar.current
        let day = cal.date(byAdding: .day, value: 1, to: cal.startOfDay(for: Date()))!
        let start = cal.date(bySettingHour: 12, minute: 0, second: 0, of: day)!
        workspace.preferences.weekdays = Set(1...7)
        workspace.events = [PlannerEvent(title: "Belegt", kind: .personal, start: start, end: start.addingTimeInterval(3600))]
        try CalendarRepository(database: db).save(workspace)
        var p = proposal(kind: .createStudyBlock); p.start = start; p.topicID = "missing"
        XCTAssertThrowsError(try executor.preview(p, granted: [.learning]))
        p.topicID = "known-topic"
        XCTAssertThrowsError(try executor.preview(p, granted: [.learning]))
    }
    func testValidFreeStudyBlockRequiresAndHonorsConfirmation() throws {
        let db = try fixture(); let executor = AIActionExecutor(database: db)
        var workspace = try CalendarRepository(database: db).load(); workspace.preferences.weekdays = Set(1...7)
        try CalendarRepository(database: db).save(workspace)
        let cal = Calendar.current; let day = cal.date(byAdding: .day, value: 1, to: cal.startOfDay(for: Date()))!
        let start = cal.date(bySettingHour: 12, minute: 0, second: 0, of: day)!
        var p = proposal(kind: .createStudyBlock); p.start = start; p.topicID = "known-topic"
        let preview = try executor.preview(p, granted: [.learning])
        XCTAssertTrue(try CalendarRepository(database: db).load().sessions.isEmpty)
        try executor.execute(preview, confirmed: true, granted: [.learning])
        let sessions = try CalendarRepository(database: db).load().sessions
        XCTAssertEqual(sessions.count, 1); XCTAssertTrue(sessions[0].pinned); XCTAssertEqual(sessions[0].topicID, "known-topic")
    }
    func testMaliciousAndUnknownActionFieldsRejected() throws {
        let id = UUID().uuidString
        XCTAssertThrowsError(try AIActionProposal.parse("{\"id\":\"\(id)\",\"kind\":\"shell\",\"title\":\"bad\"}"))
        XCTAssertThrowsError(try AIActionProposal.parse("{\"id\":\"\(id)\",\"kind\":\"createStudyTask\",\"title\":\"bad\",\"sql\":\"DROP TABLE finance_entries\"}"))
        XCTAssertThrowsError(try AIActionProposal.parse("{\"id\":\"bad\",\"kind\":\"createStudyTask\",\"title\":\"bad\"}"))
    }
    func testWeeklyReviewAppendsAndPreservesExistingNotes() throws {
        let db = try fixture(); let executor = AIActionExecutor(database: db)
        let key = DateIntervals.dayKey(for: DateIntervals.week(containing: Date(), weekStartsOn: 2, calendar: .current).start, calendar: .current)
        _ = try WeeklyReviewRepository(database: db).upsert(weekStartDate: key, winsText: "Meine Notiz", challengesText: "", nextWeekFocusText: "")
        var p = proposal(kind: .saveWeeklyReview); p.wins = "Bestätigte Ergänzung"
        let preview = try executor.preview(p, granted: [.review])
        try executor.execute(preview, confirmed: true, granted: [.review])
        let review = try XCTUnwrap(WeeklyReviewRepository(database: db).fetch(weekStartDate: key))
        XCTAssertTrue(review.winsText.contains("Meine Notiz")); XCTAssertTrue(review.winsText.contains("Bestätigte Ergänzung"))
    }
    func testBudgetAnalysisStoresOnlyAfterConfirmation() throws {
        let db = try fixture(); let executor = AIActionExecutor(database: db)
        var p = proposal(kind: .saveBudgetAnalysis); p.text = "Eine ausdrücklich bestätigte Erklärung."
        let preview = try executor.preview(p, granted: [.finance])
        XCTAssertThrowsError(try executor.execute(preview, confirmed: false, granted: [.finance]))
        XCTAssertEqual(try db.writer.read { try Int.fetchOne($0, sql: "SELECT COUNT(*) FROM ai_saved_notes") }, 0)
        try executor.execute(preview, confirmed: true, granted: [.finance])
        XCTAssertEqual(try db.writer.read { try Int.fetchOne($0, sql: "SELECT COUNT(*) FROM ai_saved_notes") }, 1)
    }
    func testLocalAIMigrationLeavesFinanceAndCalendarDataIntact() throws {
        let db = try fixture()
        XCTAssertEqual(try FinanceRepository(database: db).fetchAll().count, 1)
        XCTAssertEqual(try CalendarRepository(database: db).load().topics.count, 1)
        XCTAssertTrue(try db.writer.read { try $0.tableExists("ai_action_receipts") })
        XCTAssertFalse(SharedDocument.tableNames.contains("ai_action_receipts"))
        XCTAssertFalse(SharedDocument.tableNames.contains("ai_saved_notes"))
    }
    func testHistoryRecoveryDoesNotOverwriteUnreadableFile() throws {
        let db = try fixture()
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("ai-history-\(UUID()).json")
        defer { try? FileManager.default.removeItem(at: url) }
        try Data("corrupt".utf8).write(to: url)
        let store = AIAssistantStore(database: db, historyURL: url, loadCredentials: false)
        store.newChat()
        XCTAssertEqual(try String(contentsOf: url, encoding: .utf8), "corrupt")
        XCTAssertNotNil(store.errorMessage)
    }
    func testHistoricalDateBudgetUsesTheRequestedDayRatherThanCurrentClock() {
        var cal = Calendar(identifier: .gregorian); cal.timeZone = TimeZone(secondsFromGMT: 0)!
        let day = DateComponents(calendar: cal, year: 2025, month: 2, day: 19).date!
        // Ten days remaining including Feb 19: 100/10 = 10 before, 10-7 = 3 after.
        XCTAssertEqual(FinanceStore.dailyBudgetRemaining(spent: 100, budget: 200, date: day, calendar: cal), 10, accuracy: 0.001)
        XCTAssertEqual(FinanceStore.dailyBudgetRemaining(spent: 107, budget: 200, date: day, calendar: cal, spentToday: 7), 3, accuracy: 0.001)
    }

    func testRealBonsaiConnectorWithExplicitFictitiousContext() async throws {
        guard let path = ProcessInfo.processInfo.environment["ABOLIFE_BONSAI_LIVE_CONNECTION"] else {
            throw XCTSkip("Optional live model test: no explicit fixture connection provided.")
        }
        let db = try fixture()
        let context = try AIContextBuilder(database: db).make(purpose: .finance, granted: [.finance])
        let connection = try JSONDecoder().decode(BonsaiConnection.self, from: Data(contentsOf: URL(fileURLWithPath: path)))
        let connector = try AboLifeAIConnector(connection: connection)
        let status = try await connector.status()
        let finance = context.sections.first!.facts.joined(separator: "\n")
        var answer = ""
        try await connector.stream(model: status.model, messages: [
            .init(role: "system", content: AIAssistantStore.systemPrompt),
            .init(role: "user", content: "Wiederhole kurz den vorhandenen Wert heute noch verfügbar, rechne nichts neu.\n" + finance)
        ], reasoningEnabled: false) { answer += $0 }
        XCTAssertFalse(answer.isEmpty); XCTAssertTrue(answer.contains("EUR") || answer.contains("€"))
        if let range = finance.range(of: #"heute noch verfügbar: [0-9.]+"#, options: .regularExpression) {
            let amount = finance[range].replacingOccurrences(of: "heute noch verfügbar: ", with: "")
            XCTAssertTrue(answer.replacingOccurrences(of: ",", with: ".").contains(amount), "The model must preserve AboLife's deterministically computed amount.")
        } else { XCTFail("No computed amount in finance context") }
        XCTAssertEqual(try FinanceRepository(database: db).fetchAll().count, 1)
        print("REAL_ABOLIFE_CONNECTOR_PASS fictitious_finance=true database_writes=false")
    }

    func testRealDailyQuestionUsesGrantedCalendar() async throws {
        guard let path = ProcessInfo.processInfo.environment["ABOLIFE_BONSAI_LIVE_CONNECTION"] else {
            throw XCTSkip("Optional calendar test requires an explicit fixture connection.")
        }
        let db = try fixture()
        let repository = CalendarRepository(database: db)
        var workspace = try repository.load()
        let calendar = workspace.preferences.calendar
        let start = calendar.date(bySettingHour: 14, minute: 0, second: 0, of: Date())!
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: start)!
        workspace.events = [
            PlannerEvent(title: "Keramikatelier", kind: .university, start: start, end: start.addingTimeInterval(3600)),
            PlannerEvent(title: "Klavierprobe", kind: .university, start: tomorrow, end: tomorrow.addingTimeInterval(3600))
        ]
        try repository.save(workspace)
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("ai-calendar-history-\(UUID())")
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = AIAssistantStore(database: db, historyURL: directory.appendingPathComponent("Conversations.json"), loadCredentials: false)
        let connection = try JSONDecoder().decode(BonsaiConnection.self, from: Data(contentsOf: URL(fileURLWithPath: path)))
        try store.configure(connection, persist: false)
        store.granted = [.calendar, .learning, .training, .habits]
        store.chats[0].scopes = store.granted
        store.chats[0].turns = [
            AITurn(role: "user", content: "Wie kann ich mich auf ein Seminar vorbereiten?"),
            AITurn(role: "assistant", content: String(repeating: "Eine gute Vorbereitung umfasst Planung, Wiederholung und genügend Pausen. ", count: 320))
        ]
        store.draft = "Was habe ich heute für Module?"
        store.send()
        let deadline = Date().addingTimeInterval(60)
        while store.busy, Date() < deadline { try await Task.sleep(for: .milliseconds(100)) }
        if store.busy { store.cancel() }
        let answer = try XCTUnwrap(store.selected?.turns.last)
        XCTAssertEqual(answer.status, "complete", store.errorMessage ?? "")
        XCTAssertTrue(answer.content.localizedCaseInsensitiveContains("Keramikatelier"), answer.content)
        XCTAssertFalse(answer.content.localizedCaseInsensitiveContains("Klavierprobe"), answer.content)
    }

    func testPreAIMigrationCreatesConsistentBackupAndKeepsUserEntries() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("AboLife-migration-\(UUID())")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("AboLife.sqlite")
        let original = try AppDatabase(path: url.path)
        try FinanceRepository(database: original).insert(FinanceEntryRecord(title: "Erhalten", amount: 17, category: "Freizeit"))
        try original.writer.write { db in
            try db.execute(sql: "DROP TABLE ai_saved_notes; DROP TABLE ai_action_receipts; DELETE FROM grdb_migrations WHERE identifier='v14_local_ai_actions'")
        }
        try original.writer.close()
        try AppDatabase.backupBeforeLocalAIMigration(at: url)
        let backupURL = directory.appendingPathComponent("Backups/AboLife-before-local-AI.sqlite")
        let backup = try DatabaseQueue(path: backupURL.path)
        XCTAssertEqual(try backup.read { try Int.fetchOne($0, sql: "SELECT COUNT(*) FROM finance_entries") }, 1)
        XCTAssertFalse(try backup.read { try $0.tableExists("ai_action_receipts") })
        try backup.close()
        let migrated = try AppDatabase(path: url.path)
        XCTAssertEqual(try FinanceRepository(database: migrated).fetchAll().first?.title, "Erhalten")
        XCTAssertTrue(try migrated.writer.read { try $0.tableExists("ai_action_receipts") })
    }
    func testRealLocalActionProposalStillRequiresConfirmationOnTemporaryData() async throws {
        guard let path = ProcessInfo.processInfo.environment["ABOLIFE_BONSAI_LIVE_CONNECTION"] else { throw XCTSkip("Optional real-model action test requires explicit fixture connection.") }
        let db = try fixture()
        let connection = try JSONDecoder().decode(BonsaiConnection.self, from: Data(contentsOf: URL(fileURLWithPath: path)))
        let connector = try AboLifeAIConnector(connection: connection)
        let state = try await connector.status()
        let id = UUID().uuidString
        var answer = ""
        try await connector.stream(model: state.model, messages: [
            .init(role: "system", content: AIAssistantStore.systemPrompt),
            .init(role: "user", content: "Schlage eine Lernaufgabe zum Thema Graphen vor. Antworte ausschließlich mit einem JSON-Objekt mit diesen Feldern: id=\(id), kind=createStudyTask, title=kurzer Aufgabenname, course=Informatik, durationMinutes=25. Keine weiteren Felder, kein Begleittext.")
        ], reasoningEnabled: false, responseSchema: try AIActionProposal.schema(kind: .createStudyTask, id: id, courses: ["Informatik"])) { answer += $0 }
        let proposal = try AIActionProposal.parse(answer)
        let executor = AIActionExecutor(database: db)
        let preview = try executor.preview(proposal, granted: [.learning])
        XCTAssertThrowsError(try executor.execute(preview, confirmed: false, granted: [.learning]))
        XCTAssertEqual(try CalendarRepository(database: db).load().topics.count, 1)
        try executor.execute(preview, confirmed: true, granted: [.learning])
        XCTAssertEqual(try CalendarRepository(database: db).load().topics.count, 2)
        print("REAL_AI_ACTION_PASS temporary_data=true explicit_confirmation=true")
    }

}
