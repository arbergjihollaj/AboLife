import Foundation
import GRDB
import SwiftUI

final class AppDatabase {
    let writer: DatabaseQueue

    init(writer: DatabaseQueue) throws {
        self.writer = writer
        try DatabaseMigrationPlan.migrator.migrate(writer)
    }

    convenience init(path: String, configuration: Configuration = DatabaseConfiguration.makeConfiguration()) throws {
        try self.init(writer: DatabaseQueue(path: path, configuration: configuration))
    }

    /// Hosted XCTest launches instantiate the App before the tests run. Keep that
    /// UI host out of the user's live database, just like individual test fixtures.
    static func makeForApplication(environment: [String: String] = ProcessInfo.processInfo.environment) throws -> AppDatabase {
        if environment["XCTestConfigurationFilePath"] != nil || environment["XCTestBundlePath"] != nil || NSClassFromString("XCTestCase") != nil {
            return try makeTemporary()
        }
        if environment["ABOLIFE_DEMO"] == "1" || DemoData.isEnabled {
            let db = try makeTemporary()
            try DemoData.populate(db)
            return db
        }
        return try makeDefault()
    }

    static func makeDefault() throws -> AppDatabase {
        let databaseURL = try DatabaseConfiguration.applicationDatabaseURL()
        try bootstrapMainCopyIfNeeded(destination: databaseURL)
        try backupBeforeLocalAIMigration(at: databaseURL)
        return try AppDatabase(path: databaseURL.path)
    }

    /// Consistent read-only source backup before adding local-AI receipt/note tables.
    static func backupBeforeLocalAIMigration(at url: URL) throws {
        guard FileManager.default.fileExists(atPath: url.path) else { return }
        var configuration = DatabaseConfiguration.makeConfiguration(); configuration.readonly = true
        let source = try DatabaseQueue(path: url.path, configuration: configuration)
        defer { try? source.close() }
        let alreadyMigrated = try source.read { db in
            guard try db.tableExists("grdb_migrations") else { return false }
            return try String.fetchOne(db, sql: "SELECT identifier FROM grdb_migrations WHERE identifier=?", arguments: ["v14_local_ai_actions"]) != nil
        }
        guard !alreadyMigrated else { return }
        let directory = url.deletingLastPathComponent().appendingPathComponent("Backups", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
        let target = directory.appendingPathComponent("AboLife-before-local-AI.sqlite")
        guard !FileManager.default.fileExists(atPath: target.path) else { return }
        let temporary = directory.appendingPathComponent("backup-\(UUID()).sqlite")
        defer { try? FileManager.default.removeItem(at: temporary) }
        let copy = try DatabaseQueue(path: temporary.path)
        try source.backup(to: copy); try copy.close()
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: temporary.path)
        try FileManager.default.moveItem(at: temporary, to: target)
    }

    /// Prefer the latest preview, fall back to 0.1; copy only once into the stable main app.
    static func bootstrapMainCopyIfNeeded(destination: URL, previewURL: URL? = nil, legacyURL: URL? = nil) throws {
        let support = try FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: false)
        let preview = previewURL ?? support.appendingPathComponent("AboLife-Calendar-Preview/AboLife.sqlite")
        let legacy = legacyURL ?? support.appendingPathComponent("AboLife/AboLife.sqlite")
        let target = destination.resolvingSymlinksInPath().standardizedFileURL
        guard target != preview.resolvingSymlinksInPath().standardizedFileURL,
              target != legacy.resolvingSymlinksInPath().standardizedFileURL else { throw CalendarDatabaseIsolationError.sharedDatabase }
        guard !FileManager.default.fileExists(atPath: destination.path) else { return }
        let source = FileManager.default.fileExists(atPath: preview.path) ? preview : legacy
        try bootstrapCalendarCopyIfNeeded(destination: destination, legacyURL: source)
    }

    /// Read-only legacy access: migrate only the new version's copied database.
    static func bootstrapCalendarCopyIfNeeded(destination: URL, legacyURL: URL? = nil) throws {
        let legacy = try legacyURL ?? FileManager.default.url(
            for: .applicationSupportDirectory, in: .userDomainMask,
            appropriateFor: nil, create: false
        ).appendingPathComponent("AboLife/AboLife.sqlite")
        guard legacy.resolvingSymlinksInPath().standardizedFileURL != destination.resolvingSymlinksInPath().standardizedFileURL else {
            throw CalendarDatabaseIsolationError.sharedDatabase
        }
        guard !FileManager.default.fileExists(atPath: destination.path),
              FileManager.default.fileExists(atPath: legacy.path) else { return }
        let temporary = destination.deletingLastPathComponent().appendingPathComponent("bootstrap-\(UUID().uuidString).sqlite")
        defer { try? FileManager.default.removeItem(at: temporary) }
        var configuration = DatabaseConfiguration.makeConfiguration()
        configuration.readonly = true
        let source = try DatabaseQueue(path: legacy.path, configuration: configuration)
        let copy = try DatabaseQueue(path: temporary.path)
        try source.backup(to: copy)
        try copy.close()
        try source.close()
        try FileManager.default.moveItem(at: temporary, to: destination)
    }

    static func makeTemporary() throws -> AppDatabase {
        let temporaryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
            .appendingPathComponent(DatabaseConfiguration.databaseFileName, isDirectory: false)

        try FileManager.default.createDirectory(
            at: temporaryURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )

        return try AppDatabase(path: temporaryURL.path)
    }
}

private struct AppDatabaseEnvironmentKey: EnvironmentKey {
    static let defaultValue: AppDatabase? = nil
}

extension EnvironmentValues {
    var appDatabase: AppDatabase? {
        get { self[AppDatabaseEnvironmentKey.self] }
        set { self[AppDatabaseEnvironmentKey.self] = newValue }
    }
}

enum CalendarDatabaseIsolationError: LocalizedError {
    case sharedDatabase
    var errorDescription: String? { "Die Datenübernahme benötigt getrennte Quell- und Zielpfade. Bestehende Daten werden nicht überschrieben." }
}
