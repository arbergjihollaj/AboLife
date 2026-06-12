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
        return try AppDatabase(path: databaseURL.path)
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
