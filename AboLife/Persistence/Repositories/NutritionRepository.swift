import Foundation
import GRDB

struct NutritionRepository {
    private let database: AppDatabase

    init(database: AppDatabase) {
        self.database = database
    }

    func insert(_ entry: NutritionEntryRecord) throws {
        try database.writer.write { db in
            try entry.insert(db)
        }
    }

    func fetchAll() throws -> [NutritionEntryRecord] {
        try database.writer.read { db in
            try NutritionEntryRecord
                .order(Column("occurred_at").desc)
                .fetchAll(db)
        }
    }

    func fetch(in interval: DateInterval) throws -> [NutritionEntryRecord] {
        try database.writer.read { db in
            try NutritionEntryRecord
                .filter(Column("occurred_at") >= interval.start && Column("occurred_at") < interval.end)
                .order(Column("occurred_at").desc)
                .fetchAll(db)
        }
    }

    func fetchEntries(forDay date: Date = Date(), calendar: Calendar = .current) throws -> [NutritionEntryRecord] {
        try fetchEntries(in: DateIntervals.day(containing: date, calendar: calendar))
    }

    func fetchEntries(in interval: DateInterval) throws -> [NutritionEntryRecord] {
        try fetch(in: interval)
    }

    func daySummary(for date: Date = Date(), calendar: Calendar = .current) throws -> NutritionDaySummary {
        let entries = try fetchEntries(forDay: date, calendar: calendar)
        return NutritionDaySummary(
            caloriesKcal: entries.reduce(0) { $0 + $1.caloriesKcal },
            proteinG: entries.reduce(0) { $0 + $1.proteinG }
        )
    }

    func delete(id: String) throws {
        try database.writer.write { db in
            _ = try NutritionEntryRecord.deleteOne(db, key: id)
        }
    }

    func deleteAll() throws {
        try database.writer.write { db in
            _ = try NutritionEntryRecord.deleteAll(db)
        }
    }
}

struct NutritionDaySummary: Equatable {
    let caloriesKcal: Int
    let proteinG: Double
}
