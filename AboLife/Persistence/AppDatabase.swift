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

    static func makeDefault() throws -> AppDatabase {
        let databaseURL = try DatabaseConfiguration.applicationDatabaseURL()
        try bootstrapCalendarCopyIfNeeded(destination: databaseURL)
        return try AppDatabase(path: databaseURL.path)
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
    var errorDescription: String? { "Version 0.2 benötigt eine eigene Datenbank. Der Pfad verweist auf die Daten von Version 0.1." }
}
