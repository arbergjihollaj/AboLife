import Foundation
import GRDB

struct HabitEntryRecord: Codable, FetchableRecord, PersistableRecord, Identifiable, Equatable {
    static let databaseTableName = "habit_entries"

    var id: String
    var habitKey: String
    var date: String
    var isCompleted: Bool
    var value: Double?
    var targetValue: Double?
    var unit: String?
    var note: String?
    var createdAt: Date
    var updatedAt: Date

    init(
        id: String = UUID().uuidString,
        habitKey: String,
        date: String,
        isCompleted: Bool,
        value: Double? = nil,
        targetValue: Double? = nil,
        unit: String? = nil,
        note: String? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.habitKey = habitKey
        self.date = date
        self.isCompleted = isCompleted
        self.value = value
        self.targetValue = targetValue
        self.unit = unit
        self.note = note
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    enum CodingKeys: String, CodingKey {
        case id
        case habitKey = "habit_key"
        case date
        case isCompleted = "is_completed"
        case value
        case targetValue = "target_value"
        case unit
        case note
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}
