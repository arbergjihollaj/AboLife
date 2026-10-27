import Foundation
import GRDB

struct WorkoutRepository {
    private let database: AppDatabase

    init(database: AppDatabase) {
        self.database = database
    }

    func insert(_ session: WorkoutSessionRecord) throws {
        try database.writer.write { db in
            try session.insert(db)
        }
    }

    func insertDetailed(_ session: WorkoutSessionRecord, exercises: [WorkoutExerciseInput]) throws {
        try database.writer.write { db in
            try session.insert(db)
            for (index, input) in exercises.enumerated() {
                var exercise = WorkoutExerciseRecord(
                    sessionId: session.id,
                    exerciseName: input.exerciseName,
                    sortOrder: input.sortOrder ?? index,
                    isCompleted: input.isCompleted || !input.sets.isEmpty,
                    note: input.note,
                    painReported: input.painReported
                )
                try exercise.insert(db)

                for (setIndex, setInput) in input.sets.enumerated() {
                    let set = WorkoutSetRecord(
                        exerciseId: exercise.id,
                        setNumber: setInput.setNumber ?? setIndex + 1,
                        reps: setInput.reps,
                        weightKg: setInput.weightKg,
                        durationSec: setInput.durationSec,
                        rpe: setInput.rpe,
                        note: setInput.note,
                        painReported: setInput.painReported
                    )
                    try set.insert(db)
                }
            }
        }
    }

    func fetchAll() throws -> [WorkoutSessionRecord] {
        try database.writer.read { db in
            try WorkoutSessionRecord
                .order(Column("occurred_at").desc)
                .fetchAll(db)
        }
    }

    func fetch(in interval: DateInterval) throws -> [WorkoutSessionRecord] {
        try database.writer.read { db in
            try WorkoutSessionRecord
                .filter(Column("occurred_at") >= interval.start && Column("occurred_at") < interval.end)
                .order(Column("occurred_at").desc)
                .fetchAll(db)
        }
    }

    func fetchSessions(forWeekContaining date: Date = Date(), weekStartsOn: Int = 2, calendar: Calendar = .current) throws -> [WorkoutSessionRecord] {
        try fetchSessions(in: DateIntervals.week(containing: date, weekStartsOn: weekStartsOn, calendar: calendar))
    }

    func fetchSessions(in interval: DateInterval) throws -> [WorkoutSessionRecord] {
        try fetch(in: interval)
    }

    func fetchExercises(sessionId: String) throws -> [WorkoutExerciseRecord] {
        try database.writer.read { db in
            try WorkoutExerciseRecord
                .filter(Column("session_id") == sessionId)
                .order(Column("sort_order").asc, Column("created_at").asc)
                .fetchAll(db)
        }
    }

    func fetchSets(exerciseId: String) throws -> [WorkoutSetRecord] {
        try database.writer.read { db in
            try WorkoutSetRecord
                .filter(Column("exercise_id") == exerciseId)
                .order(Column("set_number").asc, Column("created_at").asc)
                .fetchAll(db)
        }
    }

    func fetchExerciseSummaries(sessionId: String) throws -> [WorkoutExerciseSummary] {
        let exercises = try fetchExercises(sessionId: sessionId)
        return try exercises.map { exercise in
            WorkoutExerciseSummary(exercise: exercise, sets: try fetchSets(exerciseId: exercise.id))
        }
    }

    func fetchAllExerciseSummaries(in interval: DateInterval? = nil) throws -> [WorkoutExerciseHistoryEntry] {
        try database.writer.read { db in
            let rows: [Row]
            if let interval {
                rows = try Row.fetchAll(db, sql: """
                    SELECT
                        ws.id AS session_id,
                        ws.occurred_at,
                        ws.workout_type,
                        we.id AS exercise_id,
                        we.exercise_name,
                        we.sort_order,
                        we.is_completed,
                        we.note AS exercise_note,
                        we.pain_reported AS exercise_pain_reported,
                        wset.id AS set_id,
                        wset.set_number,
                        wset.reps,
                        wset.weight_kg,
                        wset.duration_sec,
                        wset.rpe,
                        wset.note AS set_note,
                        wset.pain_reported AS set_pain_reported
                    FROM workout_sessions ws
                    JOIN workout_exercises we ON we.session_id = ws.id
                    LEFT JOIN workout_sets wset ON wset.exercise_id = we.id
                    WHERE ws.occurred_at >= ? AND ws.occurred_at < ?
                    ORDER BY ws.occurred_at DESC, we.sort_order ASC, wset.set_number ASC
                    """, arguments: [interval.start, interval.end])
            } else {
                rows = try Row.fetchAll(db, sql: """
                    SELECT
                        ws.id AS session_id,
                        ws.occurred_at,
                        ws.workout_type,
                        we.id AS exercise_id,
                        we.exercise_name,
                        we.sort_order,
                        we.is_completed,
                        we.note AS exercise_note,
                        we.pain_reported AS exercise_pain_reported,
                        wset.id AS set_id,
                        wset.set_number,
                        wset.reps,
                        wset.weight_kg,
                        wset.duration_sec,
                        wset.rpe,
                        wset.note AS set_note,
                        wset.pain_reported AS set_pain_reported
                    FROM workout_sessions ws
                    JOIN workout_exercises we ON we.session_id = ws.id
                    LEFT JOIN workout_sets wset ON wset.exercise_id = we.id
                    ORDER BY ws.occurred_at DESC, we.sort_order ASC, wset.set_number ASC
                    """)
            }
            return Self.groupHistoryRows(rows)
        }
    }

    func completedCount(in interval: DateInterval) throws -> Int {
        try database.writer.read { db in
            try WorkoutSessionRecord
                .filter(Column("occurred_at") >= interval.start && Column("occurred_at") < interval.end)
                .filter(Column("status") == "done")
                .fetchCount(db)
        }
    }

    func completedCount(forDay date: Date = Date(), calendar: Calendar = .current) throws -> Int {
        try completedCount(in: DateIntervals.day(containing: date, calendar: calendar))
    }

    func latestCompleted(in interval: DateInterval) throws -> WorkoutSessionRecord? {
        try database.writer.read { db in
            try WorkoutSessionRecord
                .filter(Column("occurred_at") >= interval.start && Column("occurred_at") < interval.end)
                .filter(Column("status") == "done")
                .order(Column("occurred_at").desc)
                .fetchOne(db)
        }
    }

    func weeklySummary(forDate date: Date = Date(), weekStartsOn: Int = 2, calendar: Calendar = .current) throws -> WorkoutWeeklySummary {
        let sessions = try fetchSessions(forWeekContaining: date, weekStartsOn: weekStartsOn, calendar: calendar)
        let completedSessions = sessions.filter { $0.status == "done" }
        let interval = DateIntervals.week(containing: date, weekStartsOn: weekStartsOn, calendar: calendar)
        let history = try fetchAllExerciseSummaries(in: interval)

        return WorkoutWeeklySummary(
            completedWorkouts: completedSessions.count,
            totalDurationMin: completedSessions.reduce(0) { $0 + $1.durationMin },
            lastWorkout: completedSessions.max { $0.occurredAt < $1.occurredAt },
            completedExerciseCount: history.filter(\.exercise.isCompleted).count,
            totalSets: history.reduce(0) { $0 + $1.sets.count },
            totalReps: history.reduce(0) { $0 + $1.totalReps },
            minimumWorkouts: completedSessions.filter { $0.workoutIntensity == HomeWorkoutIntensity.minimum.rawValue }.count,
            normalWorkouts: completedSessions.filter { $0.workoutIntensity == HomeWorkoutIntensity.normal.rawValue }.count,
            strongWorkouts: completedSessions.filter { $0.workoutIntensity == HomeWorkoutIntensity.strong.rawValue }.count,
            pausedWorkouts: sessions.filter { $0.status == "paused" }.count,
            topExerciseName: Self.topExerciseName(history),
            progressText: Self.progressText(history)
        )
    }

    func delete(id: String) throws {
        try database.writer.write { db in
            _ = try WorkoutSessionRecord.deleteOne(db, key: id)
        }
    }

    func deleteAll() throws {
        try database.writer.write { db in
            _ = try WorkoutSessionRecord.deleteAll(db)
        }
    }

    private static func groupHistoryRows(_ rows: [Row]) -> [WorkoutExerciseHistoryEntry] {
        var order: [String] = []
        var grouped: [String: WorkoutExerciseHistoryEntry] = [:]

        for row in rows {
            let exerciseId: String = row["exercise_id"]
            if grouped[exerciseId] == nil {
                order.append(exerciseId)
                let exercise = WorkoutExerciseRecord(
                    id: exerciseId,
                    sessionId: row["session_id"],
                    exerciseName: row["exercise_name"],
                    sortOrder: row["sort_order"],
                    isCompleted: row["is_completed"],
                    note: row["exercise_note"],
                    painReported: row["exercise_pain_reported"]
                )
                grouped[exerciseId] = WorkoutExerciseHistoryEntry(
                    sessionId: row["session_id"],
                    occurredAt: row["occurred_at"],
                    workoutType: row["workout_type"],
                    exercise: exercise,
                    sets: []
                )
            }

            guard let setId: String = row["set_id"] else { continue }
            let set = WorkoutSetRecord(
                id: setId,
                exerciseId: exerciseId,
                setNumber: row["set_number"],
                reps: row["reps"],
                weightKg: row["weight_kg"],
                durationSec: row["duration_sec"],
                rpe: row["rpe"],
                note: row["set_note"],
                painReported: row["set_pain_reported"]
            )
            grouped[exerciseId]?.sets.append(set)
        }

        return order.compactMap { grouped[$0] }
    }

    private static func topExerciseName(_ history: [WorkoutExerciseHistoryEntry]) -> String? {
        let counts = Dictionary(grouping: history, by: { $0.exercise.exerciseName }).mapValues(\.count)
        return counts.max { lhs, rhs in lhs.value < rhs.value }?.key
    }

    private static func progressText(_ history: [WorkoutExerciseHistoryEntry]) -> String? {
        let byName = Dictionary(grouping: history, by: { normalizedExerciseName($0.exercise.exerciseName) })
        for entries in byName.values {
            let ordered = entries.sorted { $0.occurredAt > $1.occurredAt }
            guard ordered.count >= 2 else { continue }
            let latest = ordered[0]
            let previous = ordered[1]
            if latest.totalReps > previous.totalReps {
                return "\(latest.exercise.exerciseName): kleine Verbesserung gegenüber letztem Mal."
            }
        }
        return nil
    }

    static func normalizedExerciseName(_ value: String) -> String {
        value
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "de_DE"))
            .lowercased()
            .replacingOccurrences(of: "oder", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

struct WorkoutWeeklySummary: Equatable {
    let completedWorkouts: Int
    let totalDurationMin: Int
    let lastWorkout: WorkoutSessionRecord?
    let completedExerciseCount: Int
    let totalSets: Int
    let totalReps: Int
    let minimumWorkouts: Int
    let normalWorkouts: Int
    let strongWorkouts: Int
    let pausedWorkouts: Int
    let topExerciseName: String?
    let progressText: String?

    init(
        completedWorkouts: Int,
        totalDurationMin: Int,
        lastWorkout: WorkoutSessionRecord?,
        completedExerciseCount: Int = 0,
        totalSets: Int = 0,
        totalReps: Int = 0,
        minimumWorkouts: Int = 0,
        normalWorkouts: Int = 0,
        strongWorkouts: Int = 0,
        pausedWorkouts: Int = 0,
        topExerciseName: String? = nil,
        progressText: String? = nil
    ) {
        self.completedWorkouts = completedWorkouts
        self.totalDurationMin = totalDurationMin
        self.lastWorkout = lastWorkout
        self.completedExerciseCount = completedExerciseCount
        self.totalSets = totalSets
        self.totalReps = totalReps
        self.minimumWorkouts = minimumWorkouts
        self.normalWorkouts = normalWorkouts
        self.strongWorkouts = strongWorkouts
        self.pausedWorkouts = pausedWorkouts
        self.topExerciseName = topExerciseName
        self.progressText = progressText
    }
}

struct WorkoutExerciseInput: Equatable {
    var exerciseName: String
    var sortOrder: Int?
    var isCompleted: Bool
    var note: String?
    var painReported: Bool
    var sets: [WorkoutSetInput]

    init(
        exerciseName: String,
        sortOrder: Int? = nil,
        isCompleted: Bool = false,
        note: String? = nil,
        painReported: Bool = false,
        sets: [WorkoutSetInput] = []
    ) {
        self.exerciseName = exerciseName
        self.sortOrder = sortOrder
        self.isCompleted = isCompleted
        self.note = note
        self.painReported = painReported
        self.sets = sets
    }
}

struct WorkoutSetInput: Equatable, Identifiable {
    var id = UUID()
    var setNumber: Int?
    var reps: Int?
    var weightKg: Double?
    var durationSec: Int?
    var rpe: Double?
    var note: String?
    var painReported: Bool

    init(
        setNumber: Int? = nil,
        reps: Int? = nil,
        weightKg: Double? = nil,
        durationSec: Int? = nil,
        rpe: Double? = nil,
        note: String? = nil,
        painReported: Bool = false
    ) {
        self.setNumber = setNumber
        self.reps = reps
        self.weightKg = weightKg
        self.durationSec = durationSec
        self.rpe = rpe
        self.note = note
        self.painReported = painReported
    }
}

struct WorkoutExerciseSummary: Equatable {
    let exercise: WorkoutExerciseRecord
    let sets: [WorkoutSetRecord]

    var setText: String {
        let reps = sets.compactMap(\.reps)
        if !reps.isEmpty {
            return reps.map(String.init).joined(separator: " / ")
        }
        let durations = sets.compactMap(\.durationSec)
        if !durations.isEmpty {
            return durations.map { "\($0)s" }.joined(separator: " / ")
        }
        return sets.isEmpty ? "erledigt" : "\(sets.count) Sätze"
    }
}

struct WorkoutExerciseHistoryEntry: Equatable {
    let sessionId: String
    let occurredAt: Date
    let workoutType: String
    let exercise: WorkoutExerciseRecord
    var sets: [WorkoutSetRecord]

    var totalReps: Int {
        sets.reduce(0) { $0 + ($1.reps ?? 0) }
    }

    var bestSetReps: Int {
        sets.compactMap(\.reps).max() ?? 0
    }
}
