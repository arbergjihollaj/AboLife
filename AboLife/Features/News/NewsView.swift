import SwiftUI
import Foundation
import GRDB

struct NewsSource: Identifiable, Sendable {
    let id: String
    let title: String
    let category: String
    let address: String
    static let defaults = [
        NewsSource(id: "world", title: "tagesschau", category: "Welt", address: "https://www.tagesschau.de/index~rss2.xml"),
        NewsSource(id: "tech", title: "heise", category: "Technik", address: "https://www.heise.de/rss/heise-atom.xml"),
        NewsSource(id: "science", title: "tagesschau Wissen", category: "Wissen", address: "https://www.tagesschau.de/wissen/index~rss2.xml"),
        NewsSource(id: "sport", title: "Sportschau", category: "Sport", address: "https://www.sportschau.de/index~rss2.xml")
    ]
}
struct NewsArticle: Identifiable, Equatable, Sendable {
    var id: String { url.absoluteString }
    let title: String
    let url: URL
    let source: String
    let category: String
    let publishedAt: Date?
}
struct NewsPreferences: Codable {
    var enabledSources = Set(NewsSource.defaults.map(\.id))
    var read = Set<String>()
    var saved = Set<String>()
    var excludedWords = ""
    enum CodingKeys: String, CodingKey { case enabledSources, read, saved, excludedWords }
    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(enabledSources.sorted(), forKey: .enabledSources)
        try c.encode(read.sorted(), forKey: .read)
        try c.encode(saved.sorted(), forKey: .saved)
        try c.encode(excludedWords, forKey: .excludedWords)
    }
}
final class NewsFeedParser: NSObject, XMLParserDelegate {
    private var items: [NewsArticle] = []
    private var inside = false
    private var field = ""
    private var title = ""
    private var link = ""
    private var date = ""
    private let source: NewsSource
    init(source: NewsSource) { self.source = source }
    static func parse(_ data: Data, source: NewsSource) throws -> [NewsArticle] {
        guard data.count <= 2_000_000 else { throw URLError(.dataLengthExceedsMaximum) }
        guard String(data: data, encoding: .utf8)?.range(of: "<!DOCTYPE", options: .caseInsensitive) == nil else { throw URLError(.cannotParseResponse) }
        let delegate = NewsFeedParser(source: source)
        let parser = XMLParser(data: data)
        parser.shouldResolveExternalEntities = false
        parser.delegate = delegate
        guard parser.parse() else { throw parser.parserError ?? URLError(.cannotParseResponse) }
        return delegate.items
    }
    func parser(_ parser: XMLParser, didStartElement name: String, namespaceURI: String?, qualifiedName: String?, attributes: [String: String]) {
        if name == "item" || name == "entry" { inside = true; title = ""; link = ""; date = "" }
        field = name
        if inside && name == "link", let href = attributes["href"], attributes["rel"] == nil || attributes["rel"] == "alternate" { link = href }
    }
    func parser(_ parser: XMLParser, foundCharacters text: String) {
        guard inside else { return }
        switch field { case "title": title += text; case "link": link += text; case "pubDate", "published", "updated", "dc:date": date += text; default: break }
    }
    func parser(_ parser: XMLParser, foundCDATA data: Data) { self.parser(parser, foundCharacters: String(decoding: data, as: UTF8.self)) }
    func parser(_ parser: XMLParser, didEndElement name: String, namespaceURI: String?, qualifiedName: String?) {
        if name == "item" || name == "entry" {
            defer { inside = false }
            guard let url = URL(string: link.trimmingCharacters(in: .whitespacesAndNewlines)), ["https", "http"].contains(url.scheme?.lowercased() ?? ""), !title.isEmpty else { return }
            let formatter = DateFormatter(); formatter.locale = Locale(identifier: "en_US_POSIX"); formatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss Z"
            let text = date.trimmingCharacters(in: .whitespacesAndNewlines)
            let published = ISO8601DateFormatter().date(from: text) ?? formatter.date(from: text)
            let clean = title.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression).trimmingCharacters(in: .whitespacesAndNewlines)
            items.append(NewsArticle(title: clean, url: url, source: source.title, category: source.category, publishedAt: published))
        }
        field = ""
    }
}
@MainActor
final class NewsStore: ObservableObject {
    @Published private(set) var articles: [NewsArticle] = []
    @Published var preferences = NewsPreferences()
    @Published var category = "Alle"
    @Published var search = ""
    @Published var onlySaved = false
    @Published var hideRead = false
    @Published private(set) var isLoading = false
    @Published private(set) var message: String?
    @Published private(set) var loadedAt: Date?
    private let database: AppDatabase?
    init(database: AppDatabase?) { self.database = database; reloadPreferences() }
    func reloadPreferences() {
        do {
            if let data = try database?.writer.read({ try String.fetchOne($0, sql: "SELECT payload FROM news_state WHERE id = 'main'") })?.data(using: .utf8) {
                preferences = try JSONDecoder().decode(NewsPreferences.self, from: data)
            }
        } catch { message = "News-Einstellungen konnten nicht geladen werden." }
    }
    func savePreferences() {
        do {
            let data = try JSONEncoder().encode(preferences)
            let text = String(decoding: data, as: UTF8.self)
            try database?.writer.write { try $0.execute(sql: "INSERT INTO news_state(id,payload) VALUES ('main',?) ON CONFLICT(id) DO UPDATE SET payload = excluded.payload", arguments: [text]) }
        } catch { message = "News-Einstellungen konnten nicht gespeichert werden." }
    }
    var visible: [NewsArticle] {
        let excluded = preferences.excludedWords.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces).lowercased() }.filter { !$0.isEmpty }
        return articles.filter { article in
            (category == "Alle" || article.category == category) && (!onlySaved || preferences.saved.contains(article.id)) && (!hideRead || !preferences.read.contains(article.id)) && (search.isEmpty || article.title.localizedCaseInsensitiveContains(search)) && !excluded.contains(where: { article.title.lowercased().contains($0) })
        }
    }
    func toggleRead(_ item: NewsArticle) { if !preferences.read.insert(item.id).inserted { preferences.read.remove(item.id) }; savePreferences() }
    func toggleSaved(_ item: NewsArticle) { if !preferences.saved.insert(item.id).inserted { preferences.saved.remove(item.id) }; savePreferences() }
    func refresh(force: Bool = false) async {
        guard !isLoading, force || loadedAt.map({ Date().timeIntervalSince($0) > 1800 }) ?? true else { return }
        isLoading = true; defer { isLoading = false }
        var collected: [NewsArticle] = []; var failed: [String] = []
        for source in NewsSource.defaults where preferences.enabledSources.contains(source.id) {
            do {
                var request = URLRequest(url: URL(string: source.address)!); request.timeoutInterval = 15
                request.setValue("AboLife/0.3 Private RSS Reader", forHTTPHeaderField: "User-Agent")
                let (data, response) = try await URLSession.shared.data(for: request)
                guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw URLError(.badServerResponse) }
                collected += try NewsFeedParser.parse(data, source: source)
            } catch { failed.append(source.title) }
        }
        if !collected.isEmpty || failed.isEmpty {
            collected += articles.filter { failed.contains($0.source) }
            var seen = Set<String>(); var titles = Set<String>()
            articles = collected.sorted { ($0.publishedAt ?? .distantPast) > ($1.publishedAt ?? .distantPast) }.filter {
                seen.insert($0.id).inserted && titles.insert($0.title.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "de_DE"))).inserted
            }
            loadedAt = Date()
        }
        message = failed.isEmpty ? nil : "Nicht erreichbar: " + failed.joined(separator: ", ") + ". Vorhandene Meldungen bleiben sichtbar."
    }
}
struct NewsView: View {
    @StateObject private var store: NewsStore
    init(database: AppDatabase?) { _store = StateObject(wrappedValue: NewsStore(database: database)) }
    var body: some View {
        ZStack {
            AboLifePremiumBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    HStack { Text("Dein Lesestoff.").font(AboLifeTypography.dashboardTitle); Spacer(); Button("Aktualisieren") { Task { await store.refresh(force: true) } }.disabled(store.isLoading) }
                    Text("Eine ruhige Auswahl aus Welt, Technik, Wissen und Sport.").foregroundStyle(.secondary)
                    if let loaded = store.loadedAt { Text("Stand: \(loaded.formatted(date: .abbreviated, time: .shortened))").font(.caption).foregroundStyle(.secondary) }
                    HStack {
                        Picker("Thema", selection: $store.category) { ForEach(["Alle", "Welt", "Technik", "Wissen", "Sport"], id: \.self) { Text($0) } }.frame(width: 200)
                        TextField("Schlagzeilen durchsuchen", text: $store.search)
                        Toggle("Merkliste", isOn: $store.onlySaved)
                        Toggle("Ungelesen", isOn: $store.hideRead)
                    }
                    DisclosureGroup("Quellen & Filter") {
                        VStack(alignment: .leading) {
                            ForEach(NewsSource.defaults) { source in
                                Toggle(source.title, isOn: Binding(get: { store.preferences.enabledSources.contains(source.id) }, set: { enabled in
                                    if enabled { store.preferences.enabledSources.insert(source.id) } else { store.preferences.enabledSources.remove(source.id) }
                                    store.savePreferences(); Task { await store.refresh(force: true) }
                                }))
                            }
                            TextField("Ausblenden: Wörter mit Komma trennen", text: $store.preferences.excludedWords).onSubmit { store.savePreferences() }
                        }.padding(.top, 10)
                    }
                    if store.isLoading { ProgressView("Meldungen laden …") }
                    if let message = store.message { Label(message, systemImage: "wifi.exclamationmark").foregroundStyle(.secondary) }
                    if !store.isLoading && store.visible.isEmpty { ContentUnavailableView("Keine passenden Meldungen", systemImage: "newspaper", description: Text("Filter ändern oder Quellen aktualisieren.")) }
                    ForEach(Array(store.visible.prefix(50))) { item in
                        AboLifeCard {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("\(item.source) · \(item.category)" + (item.publishedAt.map { " · " + $0.formatted(date: .abbreviated, time: .shortened) } ?? "")).font(.caption).foregroundStyle(.secondary)
                                Link(item.title, destination: item.url).font(.title3.weight(.semibold)).foregroundStyle(AboLifeColors.primaryText)
                                HStack {
                                    Button(store.preferences.read.contains(item.id) ? "Gelesen ✓" : "Als gelesen markieren") { store.toggleRead(item) }
                                    Button(store.preferences.saved.contains(item.id) ? "Gemerkt ★" : "Merken") { store.toggleSaved(item) }
                                    Spacer(); Link("Beim Anbieter lesen ↗", destination: item.url)
                                }.font(.caption).buttonStyle(.borderless)
                            }.frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    Text("Privater RSS-Reader. Vollständige Artikel öffnen bei der jeweiligen Quelle.").font(.caption).foregroundStyle(.secondary)
                }.padding(28)
            }
        }.task { await store.refresh() }.onDisappear { store.savePreferences() }
    }
}
