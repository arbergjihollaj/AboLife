import Foundation
import GRDB

struct WorkoutSessionRecord: Codable, FetchableRecord, PersistableRecord, Identifiable, Equatable {
    static let databaseTableName = "workout_sessions"

    var id: String
    var occurredAt: Date
    var workoutType: String
    var durationMin: Int
    var status: String
    var note: String?
    var createdAt: Date
    var updatedAt: Date

    init(
        id: String = UUID().uuidString,
        occurredAt: Date = Date(),
        workoutType: String,
        durationMin: Int,
        status: String,
        note: String? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.occurredAt = occurredAt
        self.workoutType = workoutType
        self.durationMin = durationMin
        self.status = status
        self.note = note
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    enum CodingKeys: String, CodingKey {
        case id
        case occurredAt = "occurred_at"
        case workoutType = "workout_type"
        case durationMin = "duration_min"
        case status
        case note
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}
