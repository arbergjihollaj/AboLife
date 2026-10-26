import Foundation
import SwiftData

enum TrainingMuscleGroup: String, Codable, CaseIterable {
    case push = "Push"
    case pull = "Pull"
    case legs = "Beine"
    case core = "Core"
    case cardio = "Cardio"
    case mobility = "Mobility"
    case recovery = "Recovery"
}

enum ExerciseProgressionOutcome: String, Codable, Equatable {
    case increase
    case repeatTarget
    case reduceTarget
    case recover
}

@Model
final class TrainingPlan {
    var id: String
    var name: String
    var goal: String
    var createdAt: Date

    init(id: String = UUID().uuidString, name: String, goal: String, createdAt: Date = Date()) {
        self.id = id
        self.name = name
        self.goal = goal
        self.createdAt = createdAt
    }
}

@Model
final class WorkoutDay {
    var id: String
    var weekday: Int
    var name: String
    var focus: String
    var durationMinutes: Int

    init(id: String = UUID().uuidString, weekday: Int, name: String, focus: String, durationMinutes: Int) {
        self.id = id
        self.weekday = weekday
        self.name = name
        self.focus = focus
        self.durationMinutes = durationMinutes
    }
}

@Model
final class WorkoutSession {
    var id: String
    var occurredAt: Date
    var workoutName: String
    var durationMinutes: Int
    var completed: Bool

    init(id: String = UUID().uuidString, occurredAt: Date = Date(), workoutName: String, durationMinutes: Int, completed: Bool = true) {
        self.id = id
        self.occurredAt = occurredAt
        self.workoutName = workoutName
        self.durationMinutes = durationMinutes
        self.completed = completed
    }
}

@Model
final class ExerciseDefinition {
    var id: String
    var name: String
    var muscleGroupRawValue: String
    var equipment: String

    init(id: String = UUID().uuidString, name: String, muscleGroup: TrainingMuscleGroup, equipment: String) {
        self.id = id
        self.name = name
        self.muscleGroupRawValue = muscleGroup.rawValue
        self.equipment = equipment
    }
}

@Model
final class ExerciseProgression {
    var id: String
    var exerciseName: String
    var level: Int
    var targetSets: Int
    var targetMinReps: Int
    var targetMaxReps: Int
    var personalRecord: Int
    var updatedAt: Date

    init(
        id: String = UUID().uuidString,
        exerciseName: String,
        level: Int,
        targetSets: Int,
        targetMinReps: Int,
        targetMaxReps: Int,
        personalRecord: Int = 0,
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.exerciseName = exerciseName
        self.level = level
        self.targetSets = targetSets
        self.targetMinReps = targetMinReps
        self.targetMaxReps = targetMaxReps
        self.personalRecord = personalRecord
        self.updatedAt = updatedAt
    }
}

@Model
final class ExerciseSetResult {
    var id: String
    var exerciseName: String
    var reps: Int
    var setIndex: Int
    var painReported: Bool
    var createdAt: Date

    init(
        id: String = UUID().uuidString,
        exerciseName: String,
        reps: Int,
        setIndex: Int,
        painReported: Bool = false,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.exerciseName = exerciseName
        self.reps = reps
        self.setIndex = setIndex
        self.painReported = painReported
        self.createdAt = createdAt
    }
}

@Model
final class WorkoutRecommendation {
    var id: String
    var exerciseName: String
    var outcomeRawValue: String
    var message: String
    var nextLevel: Int
    var nextTargetSets: Int
    var nextTargetMinReps: Int
    var nextTargetMaxReps: Int
    var createdAt: Date

    init(
        id: String = UUID().uuidString,
        exerciseName: String,
        outcome: ExerciseProgressionOutcome,
        message: String,
        nextLevel: Int,
        nextTargetSets: Int,
        nextTargetMinReps: Int,
        nextTargetMaxReps: Int,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.exerciseName = exerciseName
        self.outcomeRawValue = outcome.rawValue
        self.message = message
        self.nextLevel = nextLevel
        self.nextTargetSets = nextTargetSets
        self.nextTargetMinReps = nextTargetMinReps
        self.nextTargetMaxReps = nextTargetMaxReps
        self.createdAt = createdAt
    }
}

@Model
final class BodyMeasurement {
    var id: String
    var measuredAt: Date
    var weightKg: Double
    var waistCm: Double
    var chestCm: Double
    var armCm: Double
    var maxPushups: Int
    var maxPullups: Int

    init(
        id: String = UUID().uuidString,
        measuredAt: Date = Date(),
        weightKg: Double,
        waistCm: Double,
        chestCm: Double,
        armCm: Double,
        maxPushups: Int,
        maxPullups: Int
    ) {
        self.id = id
        self.measuredAt = measuredAt
        self.weightKg = weightKg
        self.waistCm = waistCm
        self.chestCm = chestCm
        self.armCm = armCm
        self.maxPushups = maxPushups
        self.maxPullups = maxPullups
    }
}

@Model
final class BodyProgressPhoto {
    var id: String
    var capturedAt: Date
    var fileName: String
    var note: String?

    init(id: String = UUID().uuidString, capturedAt: Date = Date(), fileName: String, note: String? = nil) {
        self.id = id
        self.capturedAt = capturedAt
        self.fileName = fileName
        self.note = note
    }
}

struct ExerciseLevelPrescription: Identifiable, Equatable {
    let id: String
    let level: Int
    let title: String
    let targetSets: Int
    let minReps: Int
    let maxReps: Int
}

struct TrainingStatistics: Equatable {
    let trainingsThisWeek: Int
    let currentStreak: Int
    let totalVolume: Int
    let pushVolume: Int
    let pullVolume: Int
    let legVolume: Int
    let strongestWeek: Int
    let trainingRate: Double
    let averageSetsPerTraining: Double
    let minimumWorkouts: Int
    let normalWorkouts: Int
    let strongWorkouts: Int
    let pausedWorkouts: Int
    let mostFrequentExercise: String?
}

struct ExerciseProgressStatus: Identifiable, Equatable {
    let id: String
    let exerciseName: String
    let lastSetsText: String?
    let bestSetReps: Int?
    let recentTotalReps: [Int]
    let recommendation: String

    var hasEnoughData: Bool {
        recentTotalReps.count >= 2
    }
}

struct NutritionTrainingStatus: Equatable {
    let proteinTargetG: Double
    let caloriesTargetRange: ClosedRange<Int>
    let currentProteinG: Double
    let currentCalories: Int

    var proteinRemainingG: Double {
        max(proteinTargetG - currentProteinG, 0)
    }

    var message: String {
        if proteinRemainingG > 0 {
            return "Heute fehlen noch \(Int(proteinRemainingG.rounded())) g Protein."
        }

        return "Proteinziel erreicht. Starkes Fundament fuer Muskelaufbau."
    }
}

struct MotivationCard: Identifiable, Equatable {
    let id: String
    let title: String
    let detail: String
    let systemImage: String
}
