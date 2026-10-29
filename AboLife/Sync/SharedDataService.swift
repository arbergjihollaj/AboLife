import Foundation
import GRDB
import CryptoKit
import Security
import Combine

/// Versioned document shared by the native app and the personal web server.
/// Nutrition archives, credentials, and generated files never leave this Mac.
struct SharedDocument: Codable, Equatable {
    var schemaVersion = 1
    var tables: [String: [[String: SharedValue]]]
    var calendar: CalendarWorkspace
    var workoutPlan: [SharedWorkoutDay]? = nil
    static let tableNames = ["app_settings", "finance_categories", "finance_entries", "finance_category_budgets", "finance_fixed_costs", "finance_savings_goals", "habit_entries", "weight_entries", "body_metric_entries", "workout_sessions", "workout_exercises", "workout_sets", "weekly_reviews", "news_state"]
    var digest: String {
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
        let encoded = (try? encoder.encode(self)) ?? Data()
        let object = (try? JSONSerialization.jsonObject(with: encoded)) ?? [:]
        func normalize(_ value: Any, key: String = "") -> Any {
            if let map = value as? [String: Any] { return map.reduce(into: [String: Any]()) { out, pair in out[pair.key] = normalize(pair.value, key: pair.key) } }
            if let array = value as? [Any] {
                let normalized = array.map { normalize($0) }
                if ["weekdays", "learningLocations", "repeatWeekdays", "excludedDays"].contains(key) {
                    return normalized.sorted { String(describing: $0) < String(describing: $1) }
                }
                if normalized.allSatisfy({ ($0 as? [String: Any])?["id"] is String }) {
                    return normalized.sorted { (($0 as! [String: Any])["id"] as! String) < (($1 as! [String: Any])["id"] as! String) }
                }
                return normalized
            }
            return value
        }
        let data = (try? JSONSerialization.data(withJSONObject: normalize(object), options: [.sortedKeys])) ?? encoded
        return SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }
}
struct SharedWorkoutDay: Codable, Equatable {
    var id: String
    var weekday: Int
    var name: String
    var variants: [String: [SharedWorkoutExercise]]
    static var current: [SharedWorkoutDay] {
        HomeWorkoutPlanProvider.plan.days.map { day in
            SharedWorkoutDay(id: day.id, weekday: day.weekday, name: day.name, variants: Dictionary(uniqueKeysWithValues: HomeWorkoutIntensity.allCases.map { intensity in
                (intensity.rawValue, day.exercises(for: intensity).map { SharedWorkoutExercise(name: $0.name, prescription: $0.prescription, sets: $0.suggestedSets, reps: $0.suggestedReps, seconds: $0.suggestedDurationSec) })
            }))
        }
    }
}
struct SharedWorkoutExercise: Codable, Equatable {
    var name: String
    var prescription: String
    var sets: Int
    var reps: Int?
    var seconds: Int?
}

enum SharedValue: Codable, Equatable {
    case null, string(String), integer(Int64), number(Double)
    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if c.decodeNil() { self = .null }
        else if let v = try? c.decode(Int64.self) { self = .integer(v) }
        else if let v = try? c.decode(Double.self) { self = .number(v) }
        else { self = .string(try c.decode(String.self)) }
    }
    func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        switch self { case .null: try c.encodeNil(); case .string(let v): try c.encode(v); case .integer(let v): try c.encode(v); case .number(let v): try c.encode(v) }
    }
    var databaseValue: DatabaseValue {
        switch self { case .null: return .null; case .string(let v): return v.databaseValue; case .integer(let v): return v.databaseValue; case .number(let v): return v.databaseValue }
    }
}
struct SharedEnvelope: Codable { var revision: Int; var document: SharedDocument? }
struct SharedBaseline: Codable { var revision: Int; var digest: String; var document: SharedDocument? = nil }
enum SharedDataError: LocalizedError {
    case invalidDocument, conflict, changedDuringTransfer, insecureURL, noCredential
    var errorDescription: String? {
        switch self {
        case .invalidDocument: return "Der Server hat ein unbekanntes oder ungültiges Datenformat geliefert."
        case .conflict: return "Mac und Server wurden geändert. Beide Stände bleiben erhalten. Wähle nach Prüfung, welchen Stand du übernehmen möchtest."
        case .changedDuringTransfer: return "Während der Übertragung wurden lokale Daten geändert. Bitte erneut synchronisieren."
        case .insecureURL: return "Bitte eine HTTPS-Adresse verwenden. HTTP ist nur für localhost zugelassen."
        case .noCredential: return "Bitte das Serverpasswort eingeben."
        }
    }
}
struct SharedDataRepository {
    let database: AppDatabase
    func document() throws -> SharedDocument { try database.writer.read { try document(in: $0) } }
    private func document(in db: Database) throws -> SharedDocument {
        var tables: [String: [[String: SharedValue]]] = [:]
        for table in SharedDocument.tableNames {
            tables[table] = try Row.fetchAll(db, sql: "SELECT * FROM \"\(table)\" ORDER BY id").map { row in
                var result: [String: SharedValue] = [:]
                for (column, value) in row {
                    switch value.storage {
                    case .null: result[column] = .null
                    case .int64(let v): result[column] = .integer(v)
                    case .double(let v): result[column] = .number(v)
                    case .string(let v): result[column] = .string(v)
                    case .blob: throw SharedDataError.invalidDocument
                    }
                }
                return result
            }
        }
        // Old nutrition-related habit rows are archival and never synced.
        tables["habit_entries"] = tables["habit_entries"]?.filter { row in
            if case .string(let key) = row["habit_key"] { return FixedHabit.defaults.contains { $0.key == key } }
            return false
        }
        let calendar: CalendarWorkspace
        if let data = try Data.fetchOne(db, sql: "SELECT payload FROM calendar_workspace WHERE id='main'") {
            calendar = try JSONDecoder().decode(CalendarWorkspace.self, from: data)
        } else { calendar = CalendarWorkspace() }
        return SharedDocument(tables: tables, calendar: calendar, workoutPlan: SharedWorkoutDay.current)
    }
    func baseline(for server: String) throws -> SharedBaseline? {
        try database.writer.read { db in
            guard let text = try String.fetchOne(db, sql: "SELECT payload FROM sync_metadata WHERE id=?", arguments: [server]) else { return nil }
            return try JSONDecoder().decode(SharedBaseline.self, from: Data(text.utf8))
        }
    }
    func mark(_ envelope: SharedEnvelope, document: SharedDocument, server: String) throws {
        let value = String(decoding: try JSONEncoder().encode(SharedBaseline(revision: envelope.revision, digest: document.digest, document: document)), as: UTF8.self)
        try database.writer.write { try $0.execute(sql: "INSERT INTO sync_metadata(id,payload) VALUES (?,?) ON CONFLICT(id) DO UPDATE SET payload=excluded.payload", arguments: [server,value]) }
    }
    func apply(_ incoming: SharedDocument, expectedDigest: String) throws {
        guard incoming.schemaVersion == 1, Set(incoming.tables.keys) == Set(SharedDocument.tableNames) else { throw SharedDataError.invalidDocument }
        try database.writer.write { db in
            guard try document(in: db).digest == expectedDigest else { throw SharedDataError.changedDuringTransfer }
            // Validate columns before deleting anything. A transaction rolls back all tables on any error.
            for table in SharedDocument.tableNames {
                let columns = Set(try db.columns(in: table).map(\.name))
                guard incoming.tables[table]!.allSatisfy({ Set($0.keys) == columns }) else { throw SharedDataError.invalidDocument }
            }
            for table in SharedDocument.tableNames.reversed() {
                if table == "habit_entries" {
                    let placeholders = FixedHabit.defaults.map { _ in "?" }.joined(separator: ",")
                    try db.execute(sql: "DELETE FROM habit_entries WHERE habit_key IN (\(placeholders))", arguments: StatementArguments(FixedHabit.defaults.map(\.key)))
                } else { try db.execute(sql: "DELETE FROM \"\(table)\"") }
            }
            for table in SharedDocument.tableNames {
                for row in incoming.tables[table]! {
                    let columns = row.keys.sorted()
                    let quoted = columns.map { "\"\($0)\"" }.joined(separator: ",")
                    let marks = columns.map { _ in "?" }.joined(separator: ",")
                    try db.execute(sql: "INSERT INTO \"\(table)\" (\(quoted)) VALUES (\(marks))", arguments: StatementArguments(columns.map { row[$0]!.databaseValue }))
                }
            }
            let payload = try JSONEncoder().encode(incoming.calendar)
            try db.execute(sql: "INSERT INTO calendar_workspace(id,payload) VALUES ('main',?) ON CONFLICT(id) DO UPDATE SET payload=excluded.payload", arguments: [payload])
        }
    }
}

struct SyncCredentialStore {
    static func read(server: String) -> String? {
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: "AboLife.SharedServer", kSecAttrAccount as String: server, kSecReturnData as String: true]
        var result: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess, let data = result as? Data else { return nil }
        return String(decoding: data, as: UTF8.self)
    }
    static func save(_ password: String, server: String) throws {
        let key: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: "AboLife.SharedServer", kSecAttrAccount as String: server]
        let data = Data(password.utf8)
        let status = SecItemUpdate(key as CFDictionary, [kSecValueData as String: data] as CFDictionary)
        if status == errSecItemNotFound {
            var entry = key; entry[kSecValueData as String] = data; entry[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
            guard SecItemAdd(entry as CFDictionary, nil) == errSecSuccess else { throw SharedDataError.noCredential }
        } else if status != errSecSuccess { throw SharedDataError.noCredential }
    }
}
@MainActor
final class SharedSyncCoordinator: ObservableObject {
    @Published var serverAddress: String
    @Published var password = ""
    @Published var autoSync: Bool { didSet { defaults.set(autoSync, forKey: "shared.autoSync") } }
    @Published private(set) var status = "Noch nicht verbunden. Deine Daten bleiben lokal."
    @Published private(set) var busy = false
    @Published private(set) var hasConflict = false
    @Published private(set) var lastSynced: Date?
    private var sessionToken: String?
    private var sessionServer: String?
    private var sessionExpires = Date.distantPast
    private let database: AppDatabase?
    private let defaults: UserDefaults
    init(database: AppDatabase?, defaults: UserDefaults = .standard) {
        self.database = database; self.defaults = defaults
        serverAddress = defaults.string(forKey: "shared.server") ?? ""
        autoSync = defaults.bool(forKey: "shared.autoSync")
    }
    private func baseURL() throws -> URL {
        guard let url = URL(string: serverAddress.trimmingCharacters(in: .whitespacesAndNewlines)), let host = url.host,
              url.user == nil, url.password == nil, url.query == nil, url.fragment == nil,
              url.path.isEmpty || url.path == "/",
              url.scheme == "https" || (url.scheme == "http" && ["localhost", "127.0.0.1", "::1"].contains(host)) else { throw SharedDataError.insecureURL }
        return url
    }
    private func request<T: Decodable>(_ base: URL, path: String, method: String = "GET", body: Data? = nil, token: String? = nil) async throws -> T {
        var r = URLRequest(url: base.appendingPathComponent(path)); r.httpMethod = method; r.httpBody = body; r.timeoutInterval = 25
        r.setValue("application/json", forHTTPHeaderField: "Content-Type")
        r.setValue("1", forHTTPHeaderField: "X-AboLife-Request")
        if let token { r.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization") }
        let (data, response) = try await URLSession.shared.data(for: r)
        guard let http = response as? HTTPURLResponse else { throw URLError(.badServerResponse) }
        if http.statusCode == 409 { throw SharedDataError.conflict }
        guard (200..<300).contains(http.statusCode) else { throw URLError(http.statusCode == 401 ? .userAuthenticationRequired : .badServerResponse) }
        return try JSONDecoder().decode(T.self, from: data)
    }
    func synchronize(resolution: String? = nil) async {
        guard !busy, let database else { return }
        busy = true; defer { busy = false }
        do {
            let base = try baseURL(); let server = base.absoluteString.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            let secret = password.isEmpty ? SyncCredentialStore.read(server: server) ?? "" : password
            guard !secret.isEmpty else { throw SharedDataError.noCredential }
            if sessionServer != server || sessionExpires < Date() || !password.isEmpty { sessionToken = nil }
            if sessionToken == nil {
                struct Login: Decodable { let token: String }
                let login: Login = try await request(base, path: "api/login", method: "POST", body: JSONSerialization.data(withJSONObject: ["password": secret]))
                sessionToken = login.token; sessionServer = server; sessionExpires = Date().addingTimeInterval(6 * 86400)
                try SyncCredentialStore.save(secret, server: server); password = ""
            }
            let token = sessionToken!
            defaults.set(server, forKey: "shared.server")
            let repo = SharedDataRepository(database: database)
            let local = try repo.document()
            let remote: SharedEnvelope = try await request(base, path: "api/state", token: token)
            let baseline = try repo.baseline(for: server)
            if let remoteDocument = remote.document, local.digest == remoteDocument.digest {
                try repo.mark(remote, document: local, server: server)
            } else if resolution == "server" {
                guard let incoming = remote.document else { throw SharedDataError.invalidDocument }
                // Keep an openable backup before replacing a local workspace.
                _ = try BackupService(database: database).createSQLiteBackup()
                try repo.apply(incoming, expectedDigest: local.digest)
                try repo.mark(remote, document: incoming, server: server)
            } else if remote.document == nil || resolution == "mac" || (baseline?.revision == remote.revision && baseline?.digest != local.digest) {
                if resolution == "mac" { _ = try BackupService(database: database).createSQLiteBackup() }
                let upload = SharedEnvelope(revision: remote.revision, document: local)
                let saved: SharedEnvelope = try await request(base, path: "api/state", method: "PUT", body: JSONEncoder().encode(upload), token: token)
                let acknowledged = saved.document ?? local
                if acknowledged.digest != local.digest { try repo.apply(acknowledged, expectedDigest: local.digest) }
                try repo.mark(saved, document: acknowledged, server: server)
            } else if baseline?.digest == local.digest, let incoming = remote.document {
                try repo.apply(incoming, expectedDigest: local.digest)
                try repo.mark(remote, document: incoming, server: server)
            } else if let ancestor = baseline?.document, let incoming = remote.document {
                let merged = try SharedDocumentMerge.merge(base: ancestor, local: local, remote: incoming)
                guard try repo.document().digest == local.digest else { throw SharedDataError.changedDuringTransfer }
                let saved: SharedEnvelope = try await request(base, path: "api/state", method: "PUT", body: JSONEncoder().encode(SharedEnvelope(revision: remote.revision, document: merged)), token: token)
                let acknowledged = saved.document ?? merged
                try repo.apply(acknowledged, expectedDigest: local.digest)
                try repo.mark(saved, document: acknowledged, server: server)
            } else { throw SharedDataError.conflict }
            hasConflict = false; lastSynced = Date(); status = "Mac und Web sind auf demselben Stand."
        } catch {
            hasConflict = (error as? SharedDataError) == .conflict
            if (error as? URLError)?.code == .userAuthenticationRequired { sessionToken = nil }
            status = error.localizedDescription
        }
    }
}
extension SharedDataError: Equatable {}


/// Three-way merge: unrelated records and fields combine; conflicting edits never win silently.
enum SharedDocumentMerge {
    static func merge(base: SharedDocument, local: SharedDocument, remote: SharedDocument) throws -> SharedDocument {
        let encoder = JSONEncoder()
        func object(_ document: SharedDocument) throws -> Any { try JSONSerialization.jsonObject(with: encoder.encode(document)) }
        let merged = try mergeValue(base: object(base), local: object(local), remote: object(remote))
        let result = try JSONDecoder().decode(SharedDocument.self, from: JSONSerialization.data(withJSONObject: merged!))
        // Different devices may create the same logical daily record with distinct UUIDs.
        for (table, columns) in [("habit_entries", ["habit_key", "date"]), ("weight_entries", ["date"]), ("weekly_reviews", ["week_start_date"]), ("finance_category_budgets", ["month_key", "category"]), ("finance_categories", ["kind", "normalized_key"])] {
            let keys = (result.tables[table] ?? []).map { row in columns.map { String(describing: row[$0]) }.joined(separator: "|") }
            guard Set(keys).count == keys.count else { throw SharedDataError.conflict }
        }
        for (child, foreignKey, parent) in [("workout_exercises", "session_id", "workout_sessions"), ("workout_sets", "exercise_id", "workout_exercises")] {
            let ids = Set((result.tables[parent] ?? []).compactMap { row -> String? in if case .string(let id) = row["id"] { return id }; return nil })
            guard (result.tables[child] ?? []).allSatisfy({ row in if case .string(let id) = row[foreignKey] { return ids.contains(id) }; return false }) else { throw SharedDataError.conflict }
        }
        return result
    }

    private static func equal(_ a: Any?, _ b: Any?) -> Bool {
        switch (a, b) {
        case (nil, nil): return true
        case let (a?, b?): return NSDictionary(dictionary: ["value": a]).isEqual(to: ["value": b])
        default: return false
        }
    }

    private static func mergeValue(base: Any?, local: Any?, remote: Any?, key: String = "") throws -> Any? {
        if equal(local, remote) { return local }
        if equal(base, local) { return remote }
        if equal(base, remote) { return local }
        // Deletion versus modification requires an explicit decision.
        guard let local, let remote else { throw SharedDataError.conflict }
        if let l = local as? [String: Any], let r = remote as? [String: Any], let b = base as? [String: Any] {
            var result: [String: Any] = [:]
            for field in Set(b.keys).union(l.keys).union(r.keys) {
                // Timestamps follow the substantive merged fields; they are not user conflicts.
                if field == "updated_at", let left = l[field] as? String, let right = r[field] as? String {
                    result[field] = max(left, right)
                } else { result[field] = try mergeValue(base: b[field], local: l[field], remote: r[field], key: field) }
            }
            return result
        }
        if let l = local as? [[String: Any]], let r = remote as? [[String: Any]], let b = base as? [[String: Any]],
           (l + r + b).allSatisfy({ $0["id"] is String }) {
            func indexed(_ rows: [[String: Any]]) throws -> [String: [String: Any]] {
                var result: [String: [String: Any]] = [:]
                for row in rows { let id = row["id"] as! String; guard result[id] == nil else { throw SharedDataError.invalidDocument }; result[id] = row }
                return result
            }
            let bm = try indexed(b), lm = try indexed(l), rm = try indexed(r)
            return try Set(bm.keys).union(lm.keys).union(rm.keys).sorted().compactMap { id in
                try mergeValue(base: bm[id], local: lm[id], remote: rm[id])
            }
        }
        if ["weekdays", "learningLocations", "repeatWeekdays", "excludedDays"].contains(key),
           let b = base as? [AnyHashable], let l = local as? [AnyHashable], let r = remote as? [AnyHashable] {
            let bs = Set(b), ls = Set(l), rs = Set(r)
            return Array(bs.subtracting(bs.subtracting(ls).union(bs.subtracting(rs))).union(ls.subtracting(bs)).union(rs.subtracting(bs)))
        }
        throw SharedDataError.conflict
    }
}
