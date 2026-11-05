import Combine
import Foundation
import GRDB

@MainActor
final class NewsStore: ObservableObject {
    typealias Fetch = @Sendable (NewsSource) async throws -> [NewsArticle]
    @Published private(set) var articles: [NewsArticle] = []
    @Published var preferences = NewsPreferences()
    @Published var category = "Alle"
    @Published var search = ""
    @Published var onlySaved = false
    @Published var hideRead = false
    @Published private(set) var isLoading = false
    @Published private(set) var message: String?
    @Published private(set) var loadedAt: Date?
    @Published private(set) var preferencesAvailable = true
    private let database: AppDatabase?
    private let fetch: Fetch
    private var refreshID: UUID?

    init(database: AppDatabase?, fetch: @escaping Fetch = { source in try await NewsFeedLoader.fetch(source) }) {
        self.database = database
        self.fetch = fetch
        reloadPreferences()
    }

    func reloadPreferences() {
        do {
            if let text = try database?.writer.read({
                try String.fetchOne($0, sql: "SELECT payload FROM news_state WHERE id = 'main'")
            }) {
                preferences = try JSONDecoder().decode(NewsPreferences.self, from: Data(text.utf8))
            }
            preferencesAvailable = true
        } catch {
            preferencesAvailable = false
            message = "News-Einstellungen sind nicht lesbar. Der gespeicherte Stand wird nicht überschrieben."
        }
    }

    func savePreferences() {
        guard preferencesAvailable else { return }
        do {
            let text = String(decoding: try JSONEncoder().encode(preferences), as: UTF8.self)
            try database?.writer.write {
                try $0.execute(
                    sql:
                        "INSERT INTO news_state(id,payload) VALUES ('main',?) ON CONFLICT(id) DO UPDATE SET payload = excluded.payload",
                    arguments: [text])
            }
        } catch { message = "News-Einstellungen konnten nicht gespeichert werden. Bitte erneut versuchen." }
    }

    var visible: [NewsArticle] {
        let excluded = preferences.excludedWords.split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces).lowercased() }.filter { !$0.isEmpty }
        return articles.filter { article in
            (category == "Alle" || article.category == category)
                && (!onlySaved || preferences.saved.contains(article.id))
                && (!hideRead || !preferences.read.contains(article.id))
                && (search.isEmpty || article.title.localizedCaseInsensitiveContains(search))
                && !excluded.contains(where: { article.title.lowercased().contains($0) })
        }
    }

    func toggleRead(_ item: NewsArticle) {
        if !preferences.read.insert(item.id).inserted { preferences.read.remove(item.id) }
        savePreferences()
    }
    func toggleSaved(_ item: NewsArticle) {
        if !preferences.saved.insert(item.id).inserted { preferences.saved.remove(item.id) }
        savePreferences()
    }

    func refresh(force: Bool = false) async {
        guard preferencesAvailable, force || loadedAt.map({ Date().timeIntervalSince($0) > 1800 }) ?? true else {
            return
        }
        let id = UUID()
        let enabled = preferences.enabledSources
        refreshID = id
        isLoading = true
        defer { if refreshID == id { isLoading = false } }
        let sources = NewsSource.defaults.filter { enabled.contains($0.id) }
        let fetch = self.fetch
        let results = await withTaskGroup(of: NewsFeedResult.self) { group in
            for source in sources {
                group.addTask {
                    do {
                        try Task.checkCancellation()
                        return NewsFeedResult(source: source, articles: try await fetch(source), failed: false)
                    } catch { return NewsFeedResult(source: source, articles: [], failed: true) }
                }
            }
            var results: [NewsFeedResult] = []
            for await result in group { results.append(result) }
            return results
        }
        guard !Task.isCancelled, refreshID == id, preferences.enabledSources == enabled else { return }
        let failed = results.filter(\.failed).map { $0.source.title }.sorted()
        let retained = articles.filter { failed.contains($0.source) }
        let collected = results.flatMap(\.articles) + retained
        var seen = Set<String>()
        var titles = Set<String>()
        articles = collected.sorted {
            let left = $0.publishedAt ?? .distantPast, right = $1.publishedAt ?? .distantPast
            return left == right ? $0.id < $1.id : left > right
        }.filter {
            seen.insert($0.id).inserted
                && titles.insert(
                    $0.title.folding(
                        options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "de_DE"))
                ).inserted
        }
        if failed.count < sources.count || sources.isEmpty { loadedAt = Date() }
        message =
            failed.isEmpty
            ? nil
            : "Nicht erreichbar: " + failed.joined(separator: ", ")
                + ". Vorhandene Meldungen dieser Quellen bleiben sichtbar."
    }
}

private struct NewsFeedResult: Sendable {
    let source: NewsSource
    let articles: [NewsArticle]
    let failed: Bool
}
