import Foundation
import GRDB

struct NutritionEntryRecord: Codable, FetchableRecord, PersistableRecord, Identifiable, Equatable {
    static let databaseTableName = "nutrition_entries"

    var id: String
    var occurredAt: Date
    var title: String
    var caloriesKcal: Int
    var proteinG: Double
    var note: String?
    var createdAt: Date
    var updatedAt: Date

    init(
        id: String = UUID().uuidString,
        occurredAt: Date = Date(),
        title: String,
        caloriesKcal: Int,
        proteinG: Double,
        note: String? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.occurredAt = occurredAt
        self.title = title
        self.caloriesKcal = caloriesKcal
        self.proteinG = proteinG
        self.note = note
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    enum CodingKeys: String, CodingKey {
        case id
        case occurredAt = "occurred_at"
        case title
        case caloriesKcal = "calories_kcal"
        case proteinG = "protein_g"
        case note
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}
