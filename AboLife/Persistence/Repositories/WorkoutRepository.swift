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

        return WorkoutWeeklySummary(
            completedWorkouts: completedSessions.count,
            totalDurationMin: completedSessions.reduce(0) { $0 + $1.durationMin },
            lastWorkout: completedSessions.max { $0.occurredAt < $1.occurredAt }
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
}

struct WorkoutWeeklySummary: Equatable {
    let completedWorkouts: Int
    let totalDurationMin: Int
    let lastWorkout: WorkoutSessionRecord?
}
