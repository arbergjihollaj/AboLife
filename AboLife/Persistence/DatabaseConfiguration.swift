import Foundation
import GRDB

struct DatabaseConfiguration {
    static let databaseFileName = "AboLife.sqlite"
    // Stable location for the main app. Legacy 0.1 and calendar previews remain untouched.
    static let applicationSupportFolderName = "AboLife-Main"

    static func makeConfiguration() -> Configuration {
        var configuration = Configuration()
        configuration.prepareDatabase { db in
            try db.execute(sql: "PRAGMA foreign_keys = ON")
        }
        return configuration
    }

    static func applicationDatabaseURL(fileManager: FileManager = .default) throws -> URL {
        let applicationSupportURL = try fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )

        let appFolderURL = applicationSupportURL.appendingPathComponent(applicationSupportFolderName, isDirectory: true)
        try fileManager.createDirectory(at: appFolderURL, withIntermediateDirectories: true)
        return appFolderURL.appendingPathComponent(databaseFileName, isDirectory: false)
    }
}
