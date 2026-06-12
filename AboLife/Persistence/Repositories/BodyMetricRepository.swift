import Foundation
import GRDB

struct BodyMetricRepository {
    private let database: AppDatabase

    init(database: AppDatabase) {
        self.database = database
    }

    func insert(_ entry: BodyMetricEntryRecord) throws {
        try database.writer.write { db in
            try entry.insert(db)
        }
    }

    func fetchAll() throws -> [BodyMetricEntryRecord] {
        try database.writer.read { db in
            try BodyMetricEntryRecord
                .order(Column("occurred_at").desc)
                .fetchAll(db)
        }
    }

    func latest() throws -> BodyMetricEntryRecord? {
        try database.writer.read { db in
            try BodyMetricEntryRecord
                .order(Column("occurred_at").desc)
                .fetchOne(db)
        }
    }

    func deleteAll() throws {
        try database.writer.write { db in
            _ = try BodyMetricEntryRecord.deleteAll(db)
        }
    }
}
