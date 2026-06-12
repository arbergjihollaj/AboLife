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

    func monthSpending(for date: Date = Date(), calendar: Calendar = .current) throws -> Double {
        let entries = try fetch(in: DateIntervals.month(containing: date, calendar: calendar))
        return entries.reduce(0) { $0 + $1.amount }
    }

    func deleteAll() throws {
        try database.writer.write { db in
            _ = try FinanceEntryRecord.deleteAll(db)
        }
    }
}
