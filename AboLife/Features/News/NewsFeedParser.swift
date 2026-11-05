import Foundation

final class NewsFeedParser: NSObject, XMLParserDelegate {
    private var items: [NewsArticle] = []
    private var depth = 0
    private var entryDepth: Int?
    private var field: String?
    private var fieldDepth = 0
    private var values: [String: String] = [:]
    private let source: NewsSource
    private let rssDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss Z"
        return formatter
    }()
    private let isoDateFormatter = ISO8601DateFormatter()
    private let fractionalDateFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    init(source: NewsSource) { self.source = source }

    static func parse(_ data: Data, source: NewsSource) throws -> [NewsArticle] {
        guard data.count <= 2_000_000 else { throw URLError(.dataLengthExceedsMaximum) }
        guard let text = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .utf16),
            text.range(of: "<!DOCTYPE", options: .caseInsensitive) == nil
        else { throw URLError(.cannotParseResponse) }
        let delegate = NewsFeedParser(source: source)
        let parser = XMLParser(data: data)
        parser.shouldResolveExternalEntities = false
        parser.delegate = delegate
        guard parser.parse() else { throw parser.parserError ?? URLError(.cannotParseResponse) }
        return delegate.items
    }

    func parser(
        _ parser: XMLParser, didStartElement name: String, namespaceURI: String?, qualifiedName: String?,
        attributes: [String: String]
    ) {
        depth += 1
        guard depth <= 64 else { parser.abortParsing(); return }
        let name = name.split(separator: ":").last.map(String.init) ?? name
        if name == "item" || name == "entry" {
            entryDepth = depth
            values = [:]
        }
        guard let entryDepth, depth == entryDepth + 1 else { return }
        if name == "link", let href = attributes["href"], attributes["rel"] == nil || attributes["rel"] == "alternate" {
            values["link"] = href
        } else if ["title", "link", "pubDate", "published", "updated", "date"].contains(name) {
            field = name
            fieldDepth = depth
        }
    }

    func parser(_ parser: XMLParser, foundCharacters text: String) {
        guard let field else { return }
        values[field, default: ""] += text
        if (values[field]?.utf8.count ?? 0) > 16_384 { parser.abortParsing() }
    }

    func parser(_ parser: XMLParser, foundCDATA data: Data) {
        self.parser(parser, foundCharacters: String(decoding: data, as: UTF8.self))
    }

    func parser(_ parser: XMLParser, didEndElement name: String, namespaceURI: String?, qualifiedName: String?) {
        if depth == fieldDepth { field = nil }
        if depth == entryDepth {
            appendArticle()
            entryDepth = nil
            field = nil
            if items.count > 2000 { parser.abortParsing() }
        }
        depth -= 1
    }

    private func appendArticle() {
        let title = (values["title"] ?? "").replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty,
            let url = URL(string: (values["link"] ?? "").trimmingCharacters(in: .whitespacesAndNewlines)),
            ["https", "http"].contains(url.scheme?.lowercased() ?? ""), url.host != nil
        else { return }
        let published = ["pubDate", "published", "date", "updated"].compactMap { key -> Date? in
            guard let text = values[key]?.trimmingCharacters(in: .whitespacesAndNewlines) else { return nil }
            return isoDateFormatter.date(from: text) ?? fractionalDateFormatter.date(from: text)
                ?? rssDateFormatter.date(from: text)
        }.first
        items.append(
            NewsArticle(title: title, url: url, source: source.title, category: source.category, publishedAt: published)
        )
    }
}
