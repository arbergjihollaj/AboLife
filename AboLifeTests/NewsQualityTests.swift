import GRDB
import XCTest

@testable import AboLife

@MainActor
final class NewsQualityTests: XCTestCase {
    func testFeedResourceLimitsAndDoctypeAreEnforced() throws {
        let source = NewsSource.defaults[0]
        let doctype = "<?xml version=\"1.0\"?><!DOCTYPE rss [<!ENTITY x \"test\">]><rss/>"
        XCTAssertThrowsError(try NewsFeedParser.parse(Data(doctype.utf8), source: source))
        XCTAssertThrowsError(try NewsFeedParser.parse(try XCTUnwrap(doctype.data(using: .utf16)), source: source))
        XCTAssertThrowsError(try NewsFeedParser.parse(Data(repeating: 65, count: 2_000_001), source: source))
        let deep = String(repeating: "<x>", count: 65) + String(repeating: "</x>", count: 65)
        XCTAssertThrowsError(try NewsFeedParser.parse(Data(deep.utf8), source: source))
        let longTitle = "<rss><item><title>" + String(repeating: "x", count: 16_385) + "</title></item></rss>"
        XCTAssertThrowsError(try NewsFeedParser.parse(Data(longTitle.utf8), source: source))
        let item = "<item><title>Test</title><link>https://example.org/article</link></item>"
        let tooMany = "<rss>" + String(repeating: item, count: 2001) + "</rss>"
        XCTAssertThrowsError(try NewsFeedParser.parse(Data(tooMany.utf8), source: source))
    }

    func testAtomKeepsPublicationDateSeparateFromUpdatedDate() throws {
        let xml = """
            <feed xmlns="http://www.w3.org/2005/Atom"><entry><title>Ein <b>wichtiger</b> Titel</title><link href="https://example.com/article"/><published>2026-11-01T10:00:00Z</published><updated>2026-11-03T12:00:00Z</updated></entry></feed>
            """
        let article = try XCTUnwrap(NewsFeedParser.parse(Data(xml.utf8), source: NewsSource.defaults[0]).first)
        XCTAssertEqual(article.title, "Ein wichtiger Titel")
        XCTAssertEqual(article.publishedAt, ISO8601DateFormatter().date(from: "2026-11-01T10:00:00Z"))
    }

    func testUnreadablePreferencesAreNeverOverwritten() throws {
        let database = try AppDatabase.makeTemporary()
        try database.writer.write {
            try $0.execute(sql: "INSERT INTO news_state(id,payload) VALUES ('main','invalid existing data')")
        }
        let store = NewsStore(database: database)
        store.savePreferences()
        XCTAssertFalse(store.preferencesAvailable)
        let value = try database.writer.read {
            try String.fetchOne($0, sql: "SELECT payload FROM news_state WHERE id='main'")
        }
        XCTAssertEqual(value, "invalid existing data")
    }

    func testDisabledSourceCannotReappearAfterAnOlderRequestFinishes() async {
        let gate = NewsTestGate()
        let store = NewsStore(database: nil) { source in
            if source.id == "world" { await gate.waitForRelease() }
            return [
                NewsArticle(
                    title: source.title, url: URL(string: "https://example.com/\(source.id)")!, source: source.title,
                    category: source.category, publishedAt: nil)
            ]
        }
        store.preferences.enabledSources = ["world"]
        let old = Task { await store.refresh(force: true) }
        await gate.waitForStart()
        store.preferences.enabledSources = ["tech"]
        await store.refresh(force: true)
        await gate.release()
        await old.value
        XCTAssertEqual(store.articles.map(\.source), ["heise"])
        XCTAssertFalse(store.isLoading)
    }

    func testCancellingARefreshDoesNotPublishPartialResultsOrAnError() async {
        let gate = NewsTestGate()
        let store = NewsStore(database: nil) { source in
            await gate.waitForRelease()
            return [
                NewsArticle(
                    title: "Test", url: URL(string: "https://example.com")!, source: source.title,
                    category: source.category, publishedAt: nil)
            ]
        }
        store.preferences.enabledSources = ["world"]
        let request = Task { await store.refresh(force: true) }
        await gate.waitForStart()
        request.cancel()
        await gate.release()
        await request.value
        XCTAssertTrue(store.articles.isEmpty)
        XCTAssertNil(store.message)
        XCTAssertFalse(store.isLoading)
    }

    func testNoSourcesClearsPreviousArticlesAndExplainsEmptyState() async {
        let store = NewsStore(database: nil) { source in
            [
                NewsArticle(
                    title: source.title, url: URL(string: "https://example.com/\(source.id)")!, source: source.title,
                    category: source.category, publishedAt: nil)
            ]
        }
        await store.refresh(force: true)
        XCTAssertEqual(store.articles.count, 4)
        store.preferences.enabledSources = []
        await store.refresh(force: true)
        XCTAssertTrue(store.articles.isEmpty)
        XCTAssertNil(store.message)
    }
}

private actor NewsTestGate {
    private var started = false
    private var startWaiter: CheckedContinuation<Void, Never>?
    private var releaseWaiter: CheckedContinuation<Void, Never>?
    func waitForRelease() async {
        await withCheckedContinuation { continuation in
            releaseWaiter = continuation
            started = true
            startWaiter?.resume()
            startWaiter = nil
        }
    }
    func waitForStart() async {
        if started { return }
        await withCheckedContinuation { startWaiter = $0 }
    }
    func release() {
        releaseWaiter?.resume()
        releaseWaiter = nil
    }
}
