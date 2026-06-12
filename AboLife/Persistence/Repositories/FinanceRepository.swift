import Foundation
import GRDB

struct FinanceRepository {
    private let database: AppDatabase

    init(database: AppDatabase) {
        self.database = database
    }

    func insert(_ entry: FinanceEntryRecord) throws {
        try database.writer.write { db in
            try entry.insert(db)
        }
    }

    func fetchAll() throws -> [FinanceEntryRecord] {
        try database.writer.read { db in
            try FinanceEntryRecord
                .order(Column("occurred_at").desc)
                .fetchAll(db)
        }
    }

    func fetch(in interval: DateInterval) throws -> [FinanceEntryRecord] {
        try database.writer.read { db in
            try FinanceEntryRecord
                .filter(Column("occurred_at") >= interval.start && Column("occurred_at") < interval.end)
                .order(Column("occurred_at").desc)
                .fetchAll(db)
        }
    }

    func fetchEntries(forMonthContaining date: Date = Date(), calendar: Calendar = .current) throws -> [FinanceEntryRecord] {
        try fetchEntries(in: DateIntervals.month(containing: date, calendar: calendar))
    }

    func fetchEntries(in interval: DateInterval) throws -> [FinanceEntryRecord] {
        try fetch(in: interval)
    }

    func fetchEntries(forWeekContaining date: Date = Date(), weekStartsOn: Int = 2, calendar: Calendar = .current) throws -> [FinanceEntryRecord] {
        try fetchEntries(in: DateIntervals.week(containing: date, weekStartsOn: weekStartsOn, calendar: calendar))
    }

    func monthSpending(for date: Date = Date(), calendar: Calendar = .current) throws -> Double {
        let entries = try fetchEntries(forMonthContaining: date, calendar: calendar)
        return entries.reduce(0) { $0 + $1.amount }
    }

    func monthlySummary(forDate date: Date = Date(), calendar: Calendar = .current) throws -> FinanceMonthlySummary {
        let entries = try fetchEntries(forMonthContaining: date, calendar: calendar)

        return FinanceMonthlySummary(
            spent: entries.reduce(0) { $0 + $1.amount },
            entryCount: entries.count
        )
    }

    func weeklySummary(in interval: DateInterval) throws -> FinanceWeeklySummary {
        let entries = try fetchEntries(in: interval)

        return FinanceWeeklySummary(
            spent: entries.reduce(0) { $0 + $1.amount },
            entryCount: entries.count
        )
    }

    func weeklySummary(forDate date: Date = Date(), weekStartsOn: Int = 2, calendar: Calendar = .current) throws -> FinanceWeeklySummary {
        try weeklySummary(in: DateIntervals.week(containing: date, weekStartsOn: weekStartsOn, calendar: calendar))
    }

    func delete(id: String) throws {
        try database.writer.write { db in
            _ = try FinanceEntryRecord.deleteOne(db, key: id)
        }
    }

    func deleteAll() throws {
        try database.writer.write { db in
            _ = try FinanceEntryRecord.deleteAll(db)
        }
    }
}

struct FinanceMonthlySummary: Equatable {
    let spent: Double
    let entryCount: Int
}

struct FinanceWeeklySummary: Equatable {
    let spent: Double
    let entryCount: Int
}
