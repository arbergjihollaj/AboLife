import Foundation

protocol TelegramUpdateFetching {
    func getUpdates(offset: Int?, timeout: Int) async throws -> [TelegramUpdate]
    func answerCallbackQuery(id: String) async throws
}

final class TelegramLiveClient: TelegramBotClient, TelegramDocumentClient, TelegramFileClient, TelegramUpdateFetching {
    private let token: String
    private let session: URLSession
    private let decoder: JSONDecoder

    init(configuration: TelegramBotConfiguration, session: URLSession = .shared) throws {
        guard let token = configuration.token else { throw TelegramClientError.missingToken }
        self.token = token
        self.session = session
        self.decoder = JSONDecoder()
    }

    func getUpdates(offset: Int?, timeout: Int = 25) async throws -> [TelegramUpdate] {
        var queryItems = [
            URLQueryItem(name: "timeout", value: "\(timeout)"),
            URLQueryItem(name: "allowed_updates", value: #"["message","callback_query"]"#)
        ]
        if let offset {
            queryItems.append(URLQueryItem(name: "offset", value: "\(offset)"))
        }

        let updates: [TelegramAPIUpdate] = try await request("getUpdates", queryItems: queryItems)
        return updates.compactMap(TelegramUpdate.init(apiUpdate:))
    }

    func send(_ response: TelegramResponse) async throws {
        try await sendMessage(response)
    }

    func sendMessage(_ response: TelegramResponse) async throws {
        var body: [String: EncodableValue] = [
            "chat_id": .int64(response.chatId),
            "text": .string(response.text)
        ]
        if let keyboard = response.keyboard {
            body["reply_markup"] = .keyboard(keyboard)
        }
        let _: TelegramEmptyResponse = try await request("sendMessage", body: body)
    }

    func answerCallbackQuery(id: String) async throws {
        let _: TelegramEmptyResponse = try await request(
            "answerCallbackQuery",
            body: ["callback_query_id": .string(id)]
        )
    }

    func getFile(fileId: String) async throws -> TelegramFile {
        let file: TelegramAPIFile = try await request(
            "getFile",
            body: ["file_id": .string(fileId)]
        )
        return TelegramFile(
            fileId: file.fileId,
            fileUniqueId: file.fileUniqueId,
            fileSize: file.fileSize,
            filePath: file.filePath
        )
    }

    func downloadFile(filePath: String) async throws -> Data {
        guard let encodedPath = filePath.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed),
              let url = URL(string: "https://api.telegram.org/file/bot\(token)/\(encodedPath)") else {
            throw TelegramClientError.invalidURL
        }
        do {
            let (data, response) = try await session.data(from: url)
            if let httpResponse = response as? HTTPURLResponse,
               !(200..<300).contains(httpResponse.statusCode) {
                throw TelegramClientError.network
            }
            return data
        } catch let error as TelegramClientError {
            throw error
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            throw TelegramClientError.network
        }
    }

    func sendDocument(chatId: Int64, fileURL: URL, caption: String? = nil) async throws {
        guard var components = URLComponents(string: "https://api.telegram.org/bot\(token)/sendDocument"),
              let url = components.url else {
            throw TelegramClientError.invalidURL
        }
        components.queryItems = nil

        let boundary = "AboLife-\(UUID().uuidString)"
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 60
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.httpBody = try multipartDocumentBody(
            boundary: boundary,
            chatId: chatId,
            fileURL: fileURL,
            caption: caption
        )

        do {
            let (data, _) = try await session.data(for: request)
            let envelope = try decoder.decode(TelegramAPIEnvelope<TelegramEmptyResponse>.self, from: data)
            guard envelope.ok else {
                throw TelegramClientError.api(sanitizedErrorDescription(envelope.description))
            }
        } catch let error as TelegramClientError {
            throw error
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            throw TelegramClientError.network
        }
    }

    private func request<Response: Decodable>(
        _ method: String,
        queryItems: [URLQueryItem] = [],
        body: [String: EncodableValue]? = nil
    ) async throws -> Response {
        guard var components = URLComponents(string: "https://api.telegram.org/bot\(token)/\(method)") else {
            throw TelegramClientError.invalidURL
        }
        components.queryItems = queryItems.isEmpty ? nil : queryItems
        guard let url = components.url else { throw TelegramClientError.invalidURL }

        var request = URLRequest(url: url)
        request.timeoutInterval = TimeInterval(max(10, (queryItems.first { $0.name == "timeout" }?.value).flatMap(Int.init) ?? 10) + 10)
        if let body {
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONEncoder().encode(EncodableDictionary(body))
        }

        do {
            let (data, _) = try await session.data(for: request)
            let envelope = try decoder.decode(TelegramAPIEnvelope<Response>.self, from: data)
            guard envelope.ok, let result = envelope.result else {
                throw TelegramClientError.api(sanitizedErrorDescription(envelope.description))
            }
            return result
        } catch let error as TelegramClientError {
            throw error
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            throw TelegramClientError.network
        }
    }

    private func multipartDocumentBody(
        boundary: String,
        chatId: Int64,
        fileURL: URL,
        caption: String?
    ) throws -> Data {
        var body = Data()
        appendField(name: "chat_id", value: "\(chatId)", boundary: boundary, to: &body)
        if let caption, !caption.isEmpty {
            appendField(name: "caption", value: caption, boundary: boundary, to: &body)
        }

        let filename = fileURL.lastPathComponent
        let fileData = try Data(contentsOf: fileURL)
        body.appendString("--\(boundary)\r\n")
        body.appendString("Content-Disposition: form-data; name=\"document\"; filename=\"\(filename)\"\r\n")
        body.appendString("Content-Type: text/html; charset=utf-8\r\n\r\n")
        body.append(fileData)
        body.appendString("\r\n")
        body.appendString("--\(boundary)--\r\n")
        return body
    }

    private func appendField(name: String, value: String, boundary: String, to body: inout Data) {
        body.appendString("--\(boundary)\r\n")
        body.appendString("Content-Disposition: form-data; name=\"\(name)\"\r\n\r\n")
        body.appendString("\(value)\r\n")
    }

    private func sanitizedErrorDescription(_ description: String?) -> String {
        (description ?? "").replacingOccurrences(of: token, with: "[redacted]")
    }
}

private struct TelegramAPIEnvelope<Result: Decodable>: Decodable {
    let ok: Bool
    let result: Result?
    let description: String?
}

private struct TelegramEmptyResponse: Decodable {}

private struct TelegramAPIUpdate: Decodable {
    let updateId: Int
    let message: TelegramAPIMessage?
    let callbackQuery: TelegramAPICallbackQuery?

    enum CodingKeys: String, CodingKey {
        case updateId = "update_id"
        case message
        case callbackQuery = "callback_query"
    }
}

private struct TelegramAPIMessage: Decodable {
    let chat: TelegramAPIChat
    let from: TelegramAPIUser?
    let text: String?
    let photo: [TelegramAPIPhotoSize]?
}

private struct TelegramAPICallbackQuery: Decodable {
    let id: String
    let from: TelegramAPIUser
    let message: TelegramAPIMessage?
    let data: String?
}

private struct TelegramAPIChat: Decodable {
    let id: Int64
}

private struct TelegramAPIUser: Decodable {
    let id: Int64
}

private struct TelegramAPIPhotoSize: Decodable {
    let fileId: String
    let width: Int
    let height: Int
    let fileSize: Int?

    enum CodingKeys: String, CodingKey {
        case fileId = "file_id"
        case width
        case height
        case fileSize = "file_size"
    }
}

private struct TelegramAPIFile: Decodable {
    let fileId: String
    let fileUniqueId: String?
    let fileSize: Int?
    let filePath: String

    enum CodingKeys: String, CodingKey {
        case fileId = "file_id"
        case fileUniqueId = "file_unique_id"
        case fileSize = "file_size"
        case filePath = "file_path"
    }
}

private extension TelegramUpdate {
    init?(apiUpdate: TelegramAPIUpdate) {
        if let message = apiUpdate.message, message.text != nil || !(message.photo ?? []).isEmpty {
            self.init(
                updateId: apiUpdate.updateId,
                message: TelegramMessage(
                    chatId: message.chat.id,
                    userId: message.from?.id ?? message.chat.id,
                    text: message.text,
                    photos: (message.photo ?? []).map {
                        TelegramPhotoSize(fileId: $0.fileId, width: $0.width, height: $0.height, fileSize: $0.fileSize)
                    }
                ),
                callback: nil
            )
            return
        }

        if let callbackQuery = apiUpdate.callbackQuery,
           let message = callbackQuery.message,
           let data = callbackQuery.data {
            self.init(
                updateId: apiUpdate.updateId,
                message: nil,
                callback: TelegramCallbackAction(
                    chatId: message.chat.id,
                    userId: callbackQuery.from.id,
                    callbackQueryId: callbackQuery.id,
                    data: data
                )
            )
            return
        }

        return nil
    }
}

private enum EncodableValue: Encodable {
    case string(String)
    case int64(Int64)
    case keyboard(TelegramKeyboard)

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case let .string(value):
            try container.encode(value)
        case let .int64(value):
            try container.encode(value)
        case let .keyboard(keyboard):
            try container.encode(TelegramReplyMarkup(keyboard: keyboard))
        }
    }
}

private struct EncodableDictionary: Encodable {
    let values: [String: EncodableValue]

    init(_ values: [String: EncodableValue]) {
        self.values = values
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: DynamicCodingKey.self)
        for (key, value) in values {
            try container.encode(value, forKey: DynamicCodingKey(stringValue: key))
        }
    }
}

private struct DynamicCodingKey: CodingKey {
    let stringValue: String
    let intValue: Int? = nil

    init(stringValue: String) {
        self.stringValue = stringValue
    }

    init?(intValue: Int) {
        return nil
    }
}

private struct TelegramReplyMarkup: Encodable {
    let inlineKeyboard: [[TelegramInlineButton]]

    init(keyboard: TelegramKeyboard) {
        inlineKeyboard = keyboard.rows.map { row in
            row.map { TelegramInlineButton(text: $0.label, callbackData: $0.callbackData) }
        }
    }

    enum CodingKeys: String, CodingKey {
        case inlineKeyboard = "inline_keyboard"
    }
}

private struct TelegramInlineButton: Encodable {
    let text: String
    let callbackData: String

    enum CodingKeys: String, CodingKey {
        case text
        case callbackData = "callback_data"
    }
}

private extension Data {
    mutating func appendString(_ string: String) {
        append(Data(string.utf8))
    }
}
