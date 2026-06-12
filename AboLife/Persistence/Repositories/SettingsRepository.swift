import Foundation
import GRDB

struct SettingsRepository {
    private let database: AppDatabase

    init(database: AppDatabase) {
        self.database = database
    }

    func insert(_ settings: AppSettingsRecord) throws {
        try database.writer.write { db in
            try settings.insert(db)
        }
    }

    func fetchAll() throws -> [AppSettingsRecord] {
        try database.writer.read { db in
            try AppSettingsRecord.fetchAll(db)
        }
    }

    func fetchDefault() throws -> AppSettingsRecord? {
        try database.writer.read { db in
            try AppSettingsRecord.fetchOne(db, key: AppSettingsRecord.defaultID)
        }
    }

    func deleteAll() throws {
        try database.writer.write { db in
            _ = try AppSettingsRecord.deleteAll(db)
        }
    }
}
