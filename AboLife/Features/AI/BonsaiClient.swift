// Shared connector contract. Keep AboLife's copy in sync with Scripts/sync-connector.py.
import Foundation

public struct BonsaiConnection: Codable, Sendable {
    public var version: Int = 1
    public var endpoint: URL
    public var clientID: UUID
    public var clientName: String
    public var apiKey: String
    public init(endpoint: URL, clientID: UUID, clientName: String, apiKey: String) {
        self.endpoint = endpoint; self.clientID = clientID; self.clientName = clientName; self.apiKey = apiKey
    }
    public func validate() throws {
        guard version == 1, endpoint.scheme == "http", ["127.0.0.1", "localhost"].contains(endpoint.host?.lowercased() ?? ""),
              endpoint.port != nil, endpoint.user == nil, endpoint.password == nil, endpoint.query == nil, endpoint.fragment == nil,
              ["", "/"].contains(endpoint.path), (20...128).contains(apiKey.utf8.count) else { throw BonsaiConnectionError.invalidConfiguration }
    }
}
public struct AIWireMessage: Codable, Sendable {
    public var role: String
    public var content: String
    public init(role: String, content: String) { self.role = role; self.content = content }
}
public struct BonsaiStatus: Decodable, Sendable {
    public let state: String
    public let model: String
    public let context_size: Int
}
public enum BonsaiConnectionError: LocalizedError {
    case invalidConfiguration, unavailable, unauthorized, busy, contextTooLarge, outputLimit, server(String), incomplete
    public var errorDescription: String? {
        switch self {
        case .invalidConfiguration: return "Bitte eine gültige lokale BonsaiBar-Verbindungsdatei importieren."
        case .unavailable: return "BonsaiBar ist nicht erreichbar. Bitte BonsaiBar öffnen und die lokale API aktivieren. AboLife bleibt ohne KI benutzbar."
        case .unauthorized: return "Der BonsaiBar-Clientschlüssel ist ungültig oder widerrufen. Bitte neu verbinden."
        case .busy: return "Die lokale KI ist ausgelastet. Bitte kurz warten und erneut versuchen."
        case .contextTooLarge: return "Der freigegebene Kontext ist zu lang. Bitte weniger Daten oder einen neuen KI-Chat verwenden."
        case .outputLimit: return "Das Ausgabelimit wurde erreicht. Bitte Denken ausschalten oder die Frage eingrenzen. Empfangener Text bleibt erhalten."
        case .server(let message): return message
        case .incomplete: return "Die lokale Verbindung wurde unterbrochen. Empfangener Text bleibt erhalten."
        }
    }
}
private final class BonsaiNoRedirect: NSObject, URLSessionTaskDelegate, @unchecked Sendable {
    func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse,
                    newRequest request: URLRequest, completionHandler: @escaping (URLRequest?) -> Void) { completionHandler(nil) }
}

@MainActor public final class AboLifeAIConnector {
    public let connection: BonsaiConnection
    private let session: URLSession
    public init(connection: BonsaiConnection) throws {
        try connection.validate(); self.connection = connection
        let configuration = URLSessionConfiguration.ephemeral
        configuration.connectionProxyDictionary = [:]
        configuration.timeoutIntervalForRequest = 180
        configuration.timeoutIntervalForResource = 1800
        session = URLSession(configuration: configuration, delegate: BonsaiNoRedirect(), delegateQueue: nil)
    }
    private func request(_ path: String, body: Data? = nil, id: UUID? = nil) -> URLRequest {
        var request = URLRequest(url: connection.endpoint.appendingPathComponent(path))
        request.httpMethod = body == nil ? "GET" : "POST"; request.httpBody = body
        request.setValue("Bearer \(connection.apiKey)", forHTTPHeaderField: "Authorization")
        if body != nil { request.setValue("application/json", forHTTPHeaderField: "Content-Type") }
        if let id { request.setValue(id.uuidString, forHTTPHeaderField: "X-Request-ID") }
        return request
    }
    private func validate(_ response: URLResponse) throws {
        guard let http = response as? HTTPURLResponse else { throw BonsaiConnectionError.unavailable }
        switch http.statusCode {
        case 200...299: return
        case 401,403: throw BonsaiConnectionError.unauthorized
        case 429: throw BonsaiConnectionError.busy
        case 409: throw BonsaiConnectionError.server("Bitte das angefragte Modell in BonsaiBar auswählen.")
        case 400: throw BonsaiConnectionError.contextTooLarge
        default: throw BonsaiConnectionError.server("BonsaiBar meldet HTTP \(http.statusCode). Bitte Modell und Einrichtung prüfen.")
        }
    }
    public func status() async throws -> BonsaiStatus {
        do {
            var probe = request("v1/status"); probe.timeoutInterval = 3
            let (data, response) = try await session.data(for: probe); try validate(response)
            return try JSONDecoder().decode(BonsaiStatus.self, from: data)
        } catch let error as URLError where error.code != .cancelled { throw BonsaiConnectionError.unavailable }
    }
    public func startModel() async throws {
        let (data, response) = try await session.data(for: request("v1/model/start", body: Data("{}".utf8)))
        _ = data; try validate(response)
    }
    public func cancel(_ id: UUID) async {
        _ = try? await session.data(for: request("v1/requests/cancel", body: try? JSONSerialization.data(withJSONObject: ["request_id": id.uuidString])))
    }
    public func stream(model: String, messages: [AIWireMessage], id: UUID = UUID(), maxTokens: Int = 2048, reasoningEnabled: Bool = true, responseSchema: Data? = nil,
                       onText: @escaping @MainActor (String) -> Void,
                       onReasoning: @escaping @MainActor (String) -> Void = { _ in }) async throws {
        let messageObjects = messages.map { ["role": $0.role, "content": $0.content] }
        var object: [String: Any] = ["model": model, "messages": messageObjects, "stream": true, "max_tokens": maxTokens, "reasoning_effort": reasoningEnabled ? "medium" : "none"]
        if let responseSchema { object["response_format"] = ["type": "json_object", "schema": try JSONSerialization.jsonObject(with: responseSchema)] }
        let body = try JSONSerialization.data(withJSONObject: object)
        do {
            let (bytes, response) = try await session.bytes(for: request("v1/chat/completions", body: body, id: id))
            try validate(response)
            var line = Data(), payloads: [String] = [], finished = false
            for try await byte in bytes {
                try Task.checkCancellation()
                if byte != 10 {
                    line.append(byte); guard line.count < 1_048_576 else { throw BonsaiConnectionError.incomplete }; continue
                }
                let text = String(decoding: line, as: UTF8.self).trimmingCharacters(in: .newlines)
                line.removeAll(keepingCapacity: true)
                if text.hasPrefix("data:") { payloads.append(String(text.dropFirst(5)).trimmingCharacters(in: .whitespaces)) }
                if text.isEmpty, !payloads.isEmpty {
                    let payload = payloads.joined(separator: "\n"); payloads.removeAll(keepingCapacity: true)
                    if payload == "[DONE]" { finished = true; break }
                    guard let data = payload.data(using: .utf8), let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else { throw BonsaiConnectionError.incomplete }
                    if let error = json["error"] as? [String: Any] {
                        if error["code"] as? String == "context_length_exceeded" { throw BonsaiConnectionError.contextTooLarge }
                        throw BonsaiConnectionError.server(error["message"] as? String ?? "Die lokale KI-Anfrage ist fehlgeschlagen.")
                    }
                    for choice in json["choices"] as? [[String: Any]] ?? [] {
                        if choice["finish_reason"] as? String == "length" { throw BonsaiConnectionError.outputLimit }
                        let delta = choice["delta"] as? [String: Any] ?? [:]
                        if let text = delta["content"] as? String { onText(text) }
                        if let text = delta["reasoning_content"] as? String { onReasoning(text) }
                    }
                }
            }
            guard finished else { throw BonsaiConnectionError.incomplete }
        } catch let error as URLError where error.code != .cancelled { throw BonsaiConnectionError.unavailable }
    }
}
