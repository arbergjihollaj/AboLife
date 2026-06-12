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

    func fetchEntries(forWeekContaining date: Date = Date(), weekStartsOn: Int = 2, calendar: Calendar = .current) throws -> [NutritionEntryRecord] {
        try fetchEntries(in: DateIntervals.week(containing: date, weekStartsOn: weekStartsOn, calendar: calendar))
    }

    func daySummary(for date: Date = Date(), calendar: Calendar = .current) throws -> NutritionDaySummary {
        let entries = try fetchEntries(forDay: date, calendar: calendar)
        return NutritionDaySummary(
            caloriesKcal: entries.reduce(0) { $0 + $1.caloriesKcal },
            proteinG: entries.reduce(0) { $0 + $1.proteinG }
        )
    }

    func weeklySummary(in interval: DateInterval, days: Int = 7) throws -> NutritionWeeklySummary {
        let entries = try fetchEntries(in: interval)
        let safeDays = max(days, 1)
        let totalCalories = entries.reduce(0) { $0 + $1.caloriesKcal }
        let totalProtein = entries.reduce(0) { $0 + $1.proteinG }

        return NutritionWeeklySummary(
            totalCaloriesKcal: totalCalories,
            averageCaloriesPerDay: Double(totalCalories) / Double(safeDays),
            totalProteinG: totalProtein,
            averageProteinGPerDay: totalProtein / Double(safeDays),
            entryCount: entries.count
        )
    }

    func weeklySummary(forDate date: Date = Date(), weekStartsOn: Int = 2, calendar: Calendar = .current, days: Int = 7) throws -> NutritionWeeklySummary {
        try weeklySummary(
            in: DateIntervals.week(containing: date, weekStartsOn: weekStartsOn, calendar: calendar),
            days: days
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

struct NutritionWeeklySummary: Equatable {
    let totalCaloriesKcal: Int
    let averageCaloriesPerDay: Double
    let totalProteinG: Double
    let averageProteinGPerDay: Double
    let entryCount: Int
}
