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

    func loadSettings() throws -> AppSettingsRecord {
        if let settings = try fetchDefault() {
            return settings
        }

        return try saveSettings(SeedData.defaultSettings)
    }

    func saveSettings(_ settings: AppSettingsRecord) throws -> AppSettingsRecord {
        let normalized = AppSettingsValidation.normalized(settings)

        try database.writer.write { db in
            if let existing = try AppSettingsRecord.fetchOne(db, key: AppSettingsRecord.defaultID) {
                var updated = normalized
                updated.id = AppSettingsRecord.defaultID
                updated.createdAt = existing.createdAt
                updated.updatedAt = Date()
                try updated.update(db)
            } else {
                var inserted = normalized
                inserted.id = AppSettingsRecord.defaultID
                try inserted.insert(db)
            }
        }

        return try loadSettings()
    }

    @discardableResult
    func resetToDefaults() throws -> AppSettingsRecord {
        try saveSettings(SeedData.defaultSettings)
    }

    @discardableResult
    func ensureDefaultSettingsExist() throws -> AppSettingsRecord {
        try loadSettings()
    }

    func deleteAll() throws {
        try database.writer.write { db in
            _ = try AppSettingsRecord.deleteAll(db)
        }
    }
}
