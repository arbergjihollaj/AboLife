import Foundation

struct NewsSource: Identifiable, Sendable {
    let id: String
    let title: String
    let category: String
    let address: String
    static let defaults = [
        NewsSource(
            id: "world", title: "tagesschau", category: "Welt", address: "https://www.tagesschau.de/index~rss2.xml"),
        NewsSource(id: "tech", title: "heise", category: "Technik", address: "https://www.heise.de/rss/heise-atom.xml"),
        NewsSource(
            id: "science", title: "tagesschau Wissen", category: "Wissen",
            address: "https://www.tagesschau.de/wissen/index~rss2.xml"),
        NewsSource(
            id: "sport", title: "Sportschau", category: "Sport", address: "https://www.sportschau.de/index~rss2.xml"),
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
