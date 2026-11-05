import Foundation

enum NewsFeedLoader {
    /// Runs outside the main actor in the store's structured task group.
    static func fetch(_ source: NewsSource) async throws -> [NewsArticle] {
        guard let url = URL(string: source.address) else { throw URLError(.badURL) }
        var request = URLRequest(url: url)
        request.timeoutInterval = 15
        request.setValue("AboLife/0.4.1 Private RSS Reader", forHTTPHeaderField: "User-Agent")
        let (bytes, response) = try await URLSession.shared.bytes(for: request)
        guard let response = response as? HTTPURLResponse, response.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
        guard response.expectedContentLength <= 2_000_000 else { throw URLError(.dataLengthExceedsMaximum) }
        var data = Data()
        for try await byte in bytes {
            guard data.count < 2_000_000 else { throw URLError(.dataLengthExceedsMaximum) }
            data.append(byte)
            if data.count.isMultiple(of: 4096) { try Task.checkCancellation() }
        }
        try Task.checkCancellation()
        return try NewsFeedParser.parse(data, source: source)
    }
}
