import Foundation
import GRDB

struct AboLifeExportPayload: Codable, Equatable {
    let exportVersion: Int
    let createdAt: Date
    let appName: String
    let nutritionEntries: [NutritionEntryRecord]
    let workoutSessions: [WorkoutSessionRecord]
    let financeEntries: [FinanceEntryRecord]
    let habitEntries: [HabitEntryRecord]
    let bodyMetricEntries: [BodyMetricEntryRecord]
    let weeklyReviews: [WeeklyReviewRecord]
    let settings: [AppSettingsRecord]
}

enum BackupServiceError: LocalizedError, Equatable {
    case databaseUnavailable
    case databaseFileMissing
    case backupDirectoryUnavailable
    case backupIntegrityCheckFailed(String)

    var errorDescription: String? {
        switch self {
        case .databaseUnavailable:
            return "Die Datenbank ist nicht verfügbar."
        case .databaseFileMissing:
            return "Die Datenbankdatei wurde nicht gefunden."
        case .backupDirectoryUnavailable:
            return "Der Backup-Ordner konnte nicht erstellt werden."
        case .backupIntegrityCheckFailed:
            return "Das Backup konnte nicht geprüft werden."
        }
    }
}

struct BackupService {
    private let database: AppDatabase
    private let fileManager: FileManager
    private let backupDirectoryOverride: URL?
    private let now: () -> Date

    init(
        database: AppDatabase,
        fileManager: FileManager = .default,
        backupDirectory: URL? = nil,
        now: @escaping () -> Date = Date.init
    ) {
        self.database = database
        self.fileManager = fileManager
        self.backupDirectoryOverride = backupDirectory
        self.now = now
    }

    func backupDirectoryURL() throws -> URL {
        let directory: URL
        if let backupDirectoryOverride {
            directory = backupDirectoryOverride
        } else {
            directory = try defaultBackupDirectoryURL()
        }

        do {
            try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
            return directory
        } catch {
            throw BackupServiceError.backupDirectoryUnavailable
        }
    }

    func createSQLiteBackup() throws -> URL {
        let sourceURL = try activeDatabaseURL()
        guard fileManager.fileExists(atPath: sourceURL.path) else {
            throw BackupServiceError.databaseFileMissing
        }

        let directory = try backupDirectoryURL()
        let fileURL = directory.appendingPathComponent("AboLife-backup-\(timestamp()).sqlite", isDirectory: false)
        let temporaryURL = directory.appendingPathComponent(".\(fileURL.lastPathComponent).tmp", isDirectory: false)

        if fileManager.fileExists(atPath: temporaryURL.path) {
            try fileManager.removeItem(at: temporaryURL)
        }

        do {
            let destination = try DatabaseQueue(path: temporaryURL.path, configuration: DatabaseConfiguration.makeConfiguration())
            try database.writer.backup(to: destination)
        }
        try verifyBackupIntegrity(at: temporaryURL)

        if fileManager.fileExists(atPath: fileURL.path) {
            try fileManager.removeItem(at: fileURL)
        }
        try fileManager.moveItem(at: temporaryURL, to: fileURL)

        return fileURL
    }

    func createJSONExport() throws -> URL {
        let directory = try backupDirectoryURL()
        let fileURL = directory.appendingPathComponent("AboLife-export-\(timestamp()).json", isDirectory: false)
        let payload = try makeExportPayload()
        let data = try Self.jsonEncoder.encode(payload)
        try data.write(to: fileURL, options: [.atomic])
        return fileURL
    }

    func makeExportPayload() throws -> AboLifeExportPayload {
        let createdAt = now()

        return try database.writer.read { db in
            AboLifeExportPayload(
                exportVersion: 1,
                createdAt: createdAt,
                appName: "AboLife",
                nutritionEntries: try fetchIfTableExists(NutritionEntryRecord.self, table: "nutrition_entries", db: db, orderSQL: "occurred_at ASC, id ASC"),
                workoutSessions: try fetchIfTableExists(WorkoutSessionRecord.self, table: "workout_sessions", db: db, orderSQL: "occurred_at ASC, id ASC"),
                financeEntries: try fetchIfTableExists(FinanceEntryRecord.self, table: "finance_entries", db: db, orderSQL: "occurred_at ASC, id ASC"),
                habitEntries: try fetchIfTableExists(HabitEntryRecord.self, table: "habit_entries", db: db, orderSQL: "date ASC, habit_key ASC, id ASC"),
                bodyMetricEntries: try fetchIfTableExists(BodyMetricEntryRecord.self, table: "body_metric_entries", db: db, orderSQL: "occurred_at ASC, id ASC"),
                weeklyReviews: try fetchIfTableExists(WeeklyReviewRecord.self, table: "weekly_reviews", db: db, orderSQL: "week_start_date ASC, id ASC"),
                settings: try fetchIfTableExists(AppSettingsRecord.self, table: "app_settings", db: db, orderSQL: "id ASC")
            )
        }
    }

    private func defaultBackupDirectoryURL() throws -> URL {
        let applicationSupportURL = try fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )

        return applicationSupportURL
            .appendingPathComponent(DatabaseConfiguration.applicationSupportFolderName, isDirectory: true)
            .appendingPathComponent("Backups", isDirectory: true)
    }

    private func verifyBackupIntegrity(at fileURL: URL) throws {
        let queue = try DatabaseQueue(path: fileURL.path, configuration: DatabaseConfiguration.makeConfiguration())
        let result: String = try queue.read { db in
            try String.fetchOne(db, sql: "PRAGMA integrity_check") ?? "missing"
        }

        guard result == "ok" else {
            throw BackupServiceError.backupIntegrityCheckFailed(result)
        }
    }

    private func activeDatabaseURL() throws -> URL {
        try database.writer.read { db in
            guard let row = try Row.fetchOne(db, sql: "PRAGMA database_list"),
                  let path: String = row["file"],
                  !path.isEmpty else {
                throw BackupServiceError.databaseUnavailable
            }
            return URL(fileURLWithPath: path)
        }
    }

    private func fetchIfTableExists<Record: FetchableRecord>(
        _ type: Record.Type,
        table: String,
        db: Database,
        orderSQL: String
    ) throws -> [Record] {
        guard try tableExists(table, db: db) else { return [] }
        return try Record.fetchAll(db, sql: "SELECT * FROM \(table) ORDER BY \(orderSQL)")
    }

    private func tableExists(_ table: String, db: Database) throws -> Bool {
        try String.fetchOne(
            db,
            sql: "SELECT name FROM sqlite_master WHERE type = 'table' AND name = ?",
            arguments: [table]
        ) != nil
    }

    private func timestamp() -> String {
        Self.fileNameFormatter.string(from: now())
    }

    private static let fileNameFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy-MM-dd-HHmmss"
        return formatter
    }()

    static let jsonEncoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }()
}
