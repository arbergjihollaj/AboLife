import Foundation
import CryptoKit
import GRDB

enum AIActionKind: String, Codable, CaseIterable { case createStudyTask, createStudyBlock, saveWeeklyReview, saveBudgetAnalysis }
struct AIActionProposal: Codable, Identifiable, Equatable {
    var id: String
    var kind: AIActionKind
    var title: String
    var course: String?
    var topicID: String?
    var start: Date?
    var durationMinutes: Int?
    var text: String?
    var wins: String?
    var challenges: String?
    var focus: String?
    var scope: AIScope {
        switch kind { case .createStudyTask, .createStudyBlock: return .learning; case .saveWeeklyReview: return .review; case .saveBudgetAnalysis: return .finance }
    }
    static func schema(kind: AIActionKind, id: String, courses: [String] = [], topicIDs: [String] = []) throws -> Data {
        var properties: [String: Any] = [
            "id": ["type": "string", "const": id], "kind": ["type": "string", "const": kind.rawValue],
            "title": ["type": "string", "minLength": 1, "maxLength": 160]
        ]
        switch kind {
        case .createStudyTask:
            properties["course"] = courses.isEmpty ? ["type": "string", "minLength": 1, "maxLength": 100] : ["type": "string", "enum": Array(Set(courses)).sorted().prefix(16).map { $0 }]
            properties["durationMinutes"] = ["type": "integer", "minimum": 5, "maximum": 180]
        case .createStudyBlock:
            properties["topicID"] = topicIDs.isEmpty ? ["type": "string", "minLength": 1, "maxLength": 160] : ["type": "string", "enum": Array(Set(topicIDs.filter { $0.count <= 160 })).sorted().prefix(16).map { $0 }]
            properties["start"] = ["type": "string", "format": "date-time"]
            properties["durationMinutes"] = ["type": "integer", "minimum": 5, "maximum": 180]
        case .saveWeeklyReview:
            for key in ["wins", "challenges", "focus"] { properties[key] = ["type": "string", "maxLength": 4000] }
        case .saveBudgetAnalysis:
            properties["text"] = ["type": "string", "minLength": 1, "maxLength": 4000]
        }
        return try JSONSerialization.data(withJSONObject: ["type": "object", "properties": properties, "required": properties.keys.sorted(), "additionalProperties": false], options: .sortedKeys)
    }
    static func parse(_ text: String) throws -> AIActionProposal {
        guard text.utf8.count <= 16_000 else { throw AIActionError.invalid }
        var source = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if source.hasPrefix("```") {
            guard let firstNewline = source.firstIndex(of: "\n"), source.hasSuffix("```") else { throw AIActionError.invalid }
            source = String(source[source.index(after: firstNewline)...].dropLast(3)).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        let data = Data(source.utf8)
        guard !source.isEmpty, let object = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
              Set(object.keys).isSubset(of: ["id", "kind", "title", "course", "topicID", "start", "durationMinutes", "text", "wins", "challenges", "focus"]) else { throw AIActionError.invalid }
        let decoder = JSONDecoder(); decoder.dateDecodingStrategy = .iso8601
        let result = try decoder.decode(AIActionProposal.self, from: data)
        guard UUID(uuidString: result.id) != nil, !result.title.isEmpty, result.title.count <= 160,
              [result.text, result.wins, result.challenges, result.focus].allSatisfy({ ($0?.count ?? 0) <= 4000 }) else { throw AIActionError.invalid }
        return result
    }
}
enum AIActionError: LocalizedError {
    case invalid, permission, confirmation, conflict, duplicate, unavailable
    var errorDescription: String? {
        switch self {
        case .invalid: return "Der Aktionsvorschlag ist ungültig oder verletzt Planungsregeln."
        case .permission: return "Für diese Aktion fehlt die ausdrückliche Bereichsfreigabe."
        case .confirmation: return "Änderungen benötigen deine ausdrückliche Bestätigung der Vorschau."
        case .conflict: return "Der Datenstand hat sich seit der Vorschau geändert. Bitte den Vorschlag erneut prüfen."
        case .duplicate: return "Dieser Vorschlag wurde bereits übernommen."
        case .unavailable: return "Die lokale Datenbank ist nicht verfügbar."
        }
    }
}
struct AIActionPreview: Identifiable {
    var id: String { proposal.id }
    let proposal: AIActionProposal
    let summary: String
    fileprivate let fingerprint: String
}

struct AIActionExecutor {
    let database: AppDatabase
    func preview(_ proposal: AIActionProposal, granted: Set<AIScope>, now: Date = Date()) throws -> AIActionPreview {
        guard granted.contains(proposal.scope) else { throw AIActionError.permission }
        return try database.writer.read { db in
            let workspace = try workspace(db)
            try validate(proposal, workspace: workspace, now: now)
            let summary: String
            switch proposal.kind {
            case .createStudyTask: summary = "Neue Lernaufgabe: \(proposal.title)\nFach: \(proposal.course ?? "")\nGeschätzte Dauer: \(proposal.durationMinutes ?? 25) Minuten"
            case .createStudyBlock:
                summary = "Fixierter Lernblock: \(proposal.title)\n\(proposal.start!.formatted(date: .abbreviated, time: .shortened)) · \(proposal.durationMinutes!) Minuten\nThema: \(proposal.topicID!)"
            case .saveWeeklyReview: summary = "Wochenreview ergänzen, vorhandene Notizen bleiben erhalten:\n\(proposal.wins ?? "")\n\(proposal.challenges ?? "")\n\(proposal.focus ?? "")"
            case .saveBudgetAnalysis: summary = "Lokale Budgetanalyse speichern:\n\(proposal.title)\n\(proposal.text ?? "")"
            }
            return AIActionPreview(proposal: proposal, summary: summary, fingerprint: try fingerprint(db))
        }
    }
    func execute(_ preview: AIActionPreview, confirmed: Bool, granted: Set<AIScope>, now: Date = Date()) throws {
        guard confirmed else { throw AIActionError.confirmation }
        let p = preview.proposal
        guard granted.contains(p.scope) else { throw AIActionError.permission }
        try database.writer.write { db in
            guard try String.fetchOne(db, sql: "SELECT id FROM ai_action_receipts WHERE id=?", arguments: [p.id]) == nil else { throw AIActionError.duplicate }
            guard try fingerprint(db) == preview.fingerprint else { throw AIActionError.conflict }
            var workspace = try workspace(db)
            try validate(p, workspace: workspace, now: now)
            switch p.kind {
            case .createStudyTask:
                workspace.topics.append(StudyTopic(id: "ai/\(p.id)", title: p.title, course: p.course!, durationMinutes: p.durationMinutes ?? 25, nextReview: now))
                try save(workspace, db: db)
            case .createStudyBlock:
                workspace.sessions.append(StudySession(id: "ai/\(p.id)", topicID: p.topicID!, start: p.start!, end: p.start!.addingTimeInterval(Double(p.durationMinutes! * 60)), pinned: true, reason: "AboLife AI · ausdrücklich bestätigt"))
                try save(workspace, db: db)
            case .saveWeeklyReview:
                let start = DateIntervals.week(containing: now, weekStartsOn: 2, calendar: .current).start
                let key = DateIntervals.dayKey(for: start, calendar: .current)
                var review = try WeeklyReviewRecord.filter(Column("week_start_date") == key).fetchOne(db) ?? WeeklyReviewRecord(weekStartDate: key)
                func append(_ previous: String, _ addition: String?) -> String {
                    guard let addition, !addition.isEmpty else { return previous }
                    return previous.isEmpty ? addition : previous + "\n\nKI-Vorschlag (bestätigt):\n" + addition
                }
                review.winsText = append(review.winsText, p.wins); review.challengesText = append(review.challengesText, p.challenges)
                review.nextWeekFocusText = append(review.nextWeekFocusText, p.focus); review.updatedAt = now
                try review.save(db)
            case .saveBudgetAnalysis:
                try db.execute(sql: "INSERT INTO ai_saved_notes(id,title,content,created_at) VALUES (?,?,?,?)", arguments: [p.id, p.title, p.text!, now])
            }
            try db.execute(sql: "INSERT INTO ai_action_receipts(id,kind,confirmed_at) VALUES (?,?,?)", arguments: [p.id, p.kind.rawValue, now])
        }
    }
    private func validate(_ p: AIActionProposal, workspace: CalendarWorkspace, now: Date) throws {
        guard UUID(uuidString: p.id) != nil, !p.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, p.title.count <= 160 else { throw AIActionError.invalid }
        switch p.kind {
        case .createStudyTask:
            guard let course = p.course, !course.isEmpty, course.count <= 100, workspace.topics.contains(where: { !$0.archived && $0.course == course }), (5...180).contains(p.durationMinutes ?? 25) else { throw AIActionError.invalid }
        case .createStudyBlock:
            guard let topicID = p.topicID, workspace.topics.contains(where: { $0.id == topicID && !$0.archived }),
                  let start = p.start, let minutes = p.durationMinutes, (5...180).contains(minutes), minutes >= workspace.preferences.minimumBlockMinutes, start > now,
                  start < now.addingTimeInterval(30 * 86400) else { throw AIActionError.invalid }
            let interval = DateInterval(start: start, duration: Double(minutes * 60))
            let free = StudyPlannerEngine.availability(events: workspace.events, preferences: workspace.preferences, horizon: interval)
            guard free.issues.isEmpty, free.windows.contains(where: { $0.location == "home" && $0.interval.start <= interval.start && $0.interval.end >= interval.end }),
                  !workspace.sessions.contains(where: { $0.status == .planned && StudyPlannerEngine.overlaps($0.interval, interval) }) else { throw AIActionError.invalid }
            let cal = workspace.preferences.calendar
            let occupied = workspace.sessions.filter { $0.status == .planned && cal.isDate($0.start, inSameDayAs: start) }.reduce(0) { $0 + $1.minutes }
            guard occupied + minutes <= workspace.preferences.dailyLimitMinutes else { throw AIActionError.invalid }
        case .saveWeeklyReview:
            guard [p.wins, p.challenges, p.focus].contains(where: { !($0 ?? "").isEmpty }), [p.wins, p.challenges, p.focus].allSatisfy({ ($0?.count ?? 0) <= 4000 }) else { throw AIActionError.invalid }
        case .saveBudgetAnalysis:
            guard let text = p.text, !text.isEmpty, text.count <= 4000 else { throw AIActionError.invalid }
        }
    }
    private func workspace(_ db: Database) throws -> CalendarWorkspace {
        guard let data = try Data.fetchOne(db, sql: "SELECT payload FROM calendar_workspace WHERE id='main'") else { return CalendarWorkspace() }
        return try JSONDecoder().decode(CalendarWorkspace.self, from: data)
    }
    private func save(_ workspace: CalendarWorkspace, db: Database) throws {
        let data = try JSONEncoder().encode(workspace)
        try db.execute(sql: "INSERT INTO calendar_workspace(id,payload) VALUES ('main',?) ON CONFLICT(id) DO UPDATE SET payload=excluded.payload", arguments: [data])
    }
    private func fingerprint(_ db: Database) throws -> String {
        let encoder = JSONEncoder(); encoder.outputFormatting = .sortedKeys
        var data = try Data.fetchOne(db, sql: "SELECT payload FROM calendar_workspace WHERE id='main'") ?? Data()
        data.append(try encoder.encode(WeeklyReviewRecord.order(Column("id")).fetchAll(db)))
        return SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }
}
