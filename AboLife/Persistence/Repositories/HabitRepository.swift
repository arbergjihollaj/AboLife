import Foundation
import GRDB

struct HabitRepository {
    private let database: AppDatabase

    init(database: AppDatabase) {
        self.database = database
    }

    func insert(_ entry: HabitEntryRecord) throws {
        try database.writer.write { db in
            try entry.insert(db)
        }
    }

    func fetchAll() throws -> [HabitEntryRecord] {
        try database.writer.read { db in
            try HabitEntryRecord
                .order(Column("date").desc, Column("habit_key"))
                .fetchAll(db)
        }
    }

    func fetch(for date: String) throws -> [HabitEntryRecord] {
        try database.writer.read { db in
            try HabitEntryRecord
                .filter(Column("date") == date)
                .order(Column("habit_key"))
                .fetchAll(db)
        }
    }

    func upsertCompletion(habitKey: String, date: String, isCompleted: Bool) throws {
        let now = Date()

        try database.writer.write { db in
            if var existing = try HabitEntryRecord
                .filter(Column("habit_key") == habitKey && Column("date") == date)
                .fetchOne(db) {
                existing.isCompleted = isCompleted
                existing.updatedAt = now
                try existing.update(db)
            } else {
                let entry = HabitEntryRecord(
                    habitKey: habitKey,
                    date: date,
                    isCompleted: isCompleted,
                    createdAt: now,
                    updatedAt: now
                )
                try entry.insert(db)
            }
        }
    }

    func completedCount(for date: String) throws -> Int {
        try database.writer.read { db in
            try HabitEntryRecord
                .filter(Column("date") == date)
                .filter(Column("is_completed") == true)
                .fetchCount(db)
        }
    }

    func deleteAll() throws {
        try database.writer.write { db in
            _ = try HabitEntryRecord.deleteAll(db)
        }
    }
}
