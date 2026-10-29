import Foundation
import GRDB

struct FinanceEntryRecord: Codable, FetchableRecord, PersistableRecord, Identifiable, Equatable {
    static let databaseTableName = "finance_entries"

    var id: String
    var occurredAt: Date
    var title: String
    var amount: Double
    var currency: String
    var category: String
    var note: String?
    var createdAt: Date
    var updatedAt: Date

    init(
        id: String = UUID().uuidString,
        occurredAt: Date = Date(),
        title: String,
        amount: Double,
        currency: String = "EUR",
        category: String,
        note: String? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.occurredAt = occurredAt
        self.title = title
        self.amount = amount
        self.currency = currency
        self.category = category
        self.note = note
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    enum CodingKeys: String, CodingKey {
        case id
        case occurredAt = "occurred_at"
        case title
        case amount
        case currency
        case category
        case note
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}
