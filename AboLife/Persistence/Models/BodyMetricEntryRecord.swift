import Foundation
import GRDB

struct BodyMetricEntryRecord: Codable, FetchableRecord, PersistableRecord, Identifiable, Equatable {
    static let databaseTableName = "body_metric_entries"

    var id: String
    var occurredAt: Date
    var weightKg: Double?
    var dayRating: Int?
    var note: String?
    var createdAt: Date
    var updatedAt: Date

    init(
        id: String = UUID().uuidString,
        occurredAt: Date = Date(),
        weightKg: Double? = nil,
        dayRating: Int? = nil,
        note: String? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.occurredAt = occurredAt
        self.weightKg = weightKg
        self.dayRating = dayRating
        self.note = note
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    enum CodingKeys: String, CodingKey {
        case id
        case occurredAt = "occurred_at"
        case weightKg = "weight_kg"
        case dayRating = "day_rating"
        case note
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}
