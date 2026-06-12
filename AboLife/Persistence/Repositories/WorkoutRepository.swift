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

    func completedCount(in interval: DateInterval) throws -> Int {
        try database.writer.read { db in
            try WorkoutSessionRecord
                .filter(Column("occurred_at") >= interval.start && Column("occurred_at") < interval.end)
                .filter(Column("status") == "done")
                .fetchCount(db)
        }
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

    func deleteAll() throws {
        try database.writer.write { db in
            _ = try WorkoutSessionRecord.deleteAll(db)
        }
    }
}
