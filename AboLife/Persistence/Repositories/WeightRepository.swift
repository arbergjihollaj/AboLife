import Foundation
import GRDB

struct WeightRepository {
    private let database: AppDatabase

    init(database: AppDatabase) {
        self.database = database
    }

    @discardableResult
    func upsert(date: Date = Date(), weightKg: Double, calendar: Calendar = .current) throws -> WeightEntryRecord {
        try upsert(dayKey: DateIntervals.dayKey(for: date, calendar: calendar), weightKg: weightKg)
    }

    @discardableResult
    func upsert(dayKey: String, weightKg: Double) throws -> WeightEntryRecord {
        let now = Date()
        let normalizedWeight = Self.normalizedWeight(weightKg)

        return try database.writer.write { db in
            if var existing = try WeightEntryRecord
                .filter(Column("date") == dayKey)
                .fetchOne(db) {
                existing.weightKg = normalizedWeight
                existing.updatedAt = now
                try existing.update(db)
                return existing
            }

            let entry = WeightEntryRecord(
                date: dayKey,
                weightKg: normalizedWeight,
                createdAt: now,
                updatedAt: now
            )
            try entry.insert(db)
            return entry
        }
    }

    func fetchAll() throws -> [WeightEntryRecord] {
        try database.writer.read { db in
            try WeightEntryRecord
                .order(Column("date").desc)
                .fetchAll(db)
        }
    }

    func fetchEntry(for date: Date = Date(), calendar: Calendar = .current) throws -> WeightEntryRecord? {
        try fetchEntry(dayKey: DateIntervals.dayKey(for: date, calendar: calendar))
    }

    func fetchEntry(dayKey: String) throws -> WeightEntryRecord? {
        try database.writer.read { db in
            try WeightEntryRecord
                .filter(Column("date") == dayKey)
                .fetchOne(db)
        }
    }

    func latest() throws -> WeightEntryRecord? {
        try database.writer.read { db in
            try WeightEntryRecord
                .order(Column("date").desc)
                .fetchOne(db)
        }
    }

    func previous(before entry: WeightEntryRecord) throws -> WeightEntryRecord? {
        try database.writer.read { db in
            try WeightEntryRecord
                .filter(Column("date") < entry.date)
                .order(Column("date").desc)
                .fetchOne(db)
        }
    }

    func changeFromPrevious(for entry: WeightEntryRecord) throws -> Double? {
        guard let previous = try previous(before: entry) else { return nil }
        return entry.weightKg - previous.weightKg
    }

    func recent(limit: Int) throws -> [WeightEntryRecord] {
        try database.writer.read { db in
            try WeightEntryRecord
                .order(Column("date").desc)
                .limit(max(limit, 0))
                .fetchAll(db)
        }
        .sorted { $0.date < $1.date }
    }

    func summary(days: Int) throws -> WeightTrendSummary {
        WeightTrendSummary(entries: try recent(limit: days))
    }

    func delete(id: String) throws {
        try database.writer.write { db in
            _ = try WeightEntryRecord.deleteOne(db, key: id)
        }
    }

    func delete(dayKey: String) throws {
        try database.writer.write { db in
            _ = try WeightEntryRecord
                .filter(Column("date") == dayKey)
                .deleteAll(db)
        }
    }

    func deleteAll() throws {
        try database.writer.write { db in
            _ = try WeightEntryRecord.deleteAll(db)
        }
    }

    static func normalizedWeight(_ value: Double) -> Double {
        guard value.isFinite else { return 0 }
        return min(max(value, 0), 500)
    }
}
