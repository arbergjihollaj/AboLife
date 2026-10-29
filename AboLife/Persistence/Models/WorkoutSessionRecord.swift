import Foundation
import GRDB

struct WorkoutSessionRecord: Codable, FetchableRecord, PersistableRecord, Identifiable, Equatable {
    static let databaseTableName = "workout_sessions"

    var id: String
    var occurredAt: Date
    var workoutType: String
    var durationMin: Int
    var status: String
    var workoutIntensity: String?
    var painReported: Bool
    var note: String?
    var createdAt: Date
    var updatedAt: Date

    init(
        id: String = UUID().uuidString,
        occurredAt: Date = Date(),
        workoutType: String,
        durationMin: Int,
        status: String,
        workoutIntensity: String? = nil,
        painReported: Bool = false,
        note: String? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.occurredAt = occurredAt
        self.workoutType = workoutType
        self.durationMin = durationMin
        self.status = status
        self.workoutIntensity = workoutIntensity
        self.painReported = painReported
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
        case workoutIntensity = "workout_intensity"
        case painReported = "pain_reported"
        case note
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

struct WorkoutExerciseRecord: Codable, FetchableRecord, PersistableRecord, Identifiable, Equatable {
    static let databaseTableName = "workout_exercises"

    var id: String
    var sessionId: String
    var exerciseName: String
    var sortOrder: Int
    var isCompleted: Bool
    var note: String?
    var painReported: Bool
    var createdAt: Date
    var updatedAt: Date

    init(
        id: String = UUID().uuidString,
        sessionId: String,
        exerciseName: String,
        sortOrder: Int,
        isCompleted: Bool = false,
        note: String? = nil,
        painReported: Bool = false,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.sessionId = sessionId
        self.exerciseName = exerciseName
        self.sortOrder = sortOrder
        self.isCompleted = isCompleted
        self.note = note
        self.painReported = painReported
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    enum CodingKeys: String, CodingKey {
        case id
        case sessionId = "session_id"
        case exerciseName = "exercise_name"
        case sortOrder = "sort_order"
        case isCompleted = "is_completed"
        case note
        case painReported = "pain_reported"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

struct WorkoutSetRecord: Codable, FetchableRecord, PersistableRecord, Identifiable, Equatable {
    static let databaseTableName = "workout_sets"

    var id: String
    var exerciseId: String
    var setNumber: Int
    var reps: Int?
    var weightKg: Double?
    var durationSec: Int?
    var rpe: Double?
    var note: String?
    var painReported: Bool
    var createdAt: Date
    var updatedAt: Date

    init(
        id: String = UUID().uuidString,
        exerciseId: String,
        setNumber: Int,
        reps: Int? = nil,
        weightKg: Double? = nil,
        durationSec: Int? = nil,
        rpe: Double? = nil,
        note: String? = nil,
        painReported: Bool = false,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.exerciseId = exerciseId
        self.setNumber = setNumber
        self.reps = reps
        self.weightKg = weightKg
        self.durationSec = durationSec
        self.rpe = rpe
        self.note = note
        self.painReported = painReported
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    enum CodingKeys: String, CodingKey {
        case id
        case exerciseId = "exercise_id"
        case setNumber = "set_number"
        case reps
        case weightKg = "weight_kg"
        case durationSec = "duration_sec"
        case rpe
        case note
        case painReported = "pain_reported"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}
