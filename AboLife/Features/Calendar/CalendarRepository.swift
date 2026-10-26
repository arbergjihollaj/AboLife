import Foundation
import GRDB

struct CalendarRepository {
    let database: AppDatabase
    func load() throws -> CalendarWorkspace {
        try database.writer.read { db in
            guard let data = try Data.fetchOne(db, sql: "SELECT payload FROM calendar_workspace WHERE id = ?", arguments: ["main"]) else { return CalendarWorkspace() }
            return try JSONDecoder().decode(CalendarWorkspace.self, from: data)
        }
    }
    func save(_ workspace: CalendarWorkspace) throws {
        let data = try JSONEncoder().encode(workspace)
        try database.writer.write { db in
            try db.execute(sql: "INSERT INTO calendar_workspace (id, payload) VALUES (?, ?) ON CONFLICT(id) DO UPDATE SET payload = excluded.payload", arguments: ["main", data])
        }
    }
}
