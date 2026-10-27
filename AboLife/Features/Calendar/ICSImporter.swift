import Foundation

struct CalendarImportDraft: Identifiable {
    var id: String { sourceID }
    var events: [PlannerEvent]
    var warnings: [String]
    var sourceID: String
    var sourceName: String
}

enum ICSImportError: LocalizedError {
    case invalidFile, tooLarge
    var errorDescription: String? {
        switch self { case .invalidFile: return "Keine gültige UTF-8-iCalendar-Datei (.ics)."; case .tooLarge: return "Die Datei ist zu groß. Bitte höchstens 5 MB importieren." }
    }
}

enum ICSImporter {
    private struct Property {
        var name: String
        var parameters: [String: String]
        var value: String
    }
    private static func property(_ line: String) -> Property? {
        guard let colon = line.firstIndex(of: ":") else { return nil }
        let parts = line[..<colon].split(separator: ";", omittingEmptySubsequences: false).map(String.init)
        guard let name = parts.first, !name.isEmpty else { return nil }
        var parameters: [String: String] = [:]
        for part in parts.dropFirst() {
            let pair = part.split(separator: "=", maxSplits: 1).map(String.init)
            if pair.count == 2 { parameters[pair[0].uppercased()] = pair[1].trimmingCharacters(in: CharacterSet(charactersIn: "\"")) }
        }
        return Property(name: name.uppercased(), parameters: parameters, value: String(line[line.index(after: colon)...]))
    }
    private static func text(_ raw: String) -> String {
        var result = "", escaping = false
        for char in raw {
            if escaping { result.append(char == "n" || char == "N" ? "\n" : char); escaping = false }
            else if char == "\\" { escaping = true }
            else { result.append(char) }
        }
        return result
    }
    private static func zone(_ identifier: String?, fallback: TimeZone) -> TimeZone? {
        guard let identifier else { return fallback }
        if let zone = TimeZone(identifier: identifier) { return zone }
        let suffix = identifier.split(separator: "/").suffix(2).joined(separator: "/")
        return TimeZone(identifier: suffix)
    }
    private static func date(_ p: Property, fallback: TimeZone) -> (Date, TimeZone)? {
        let value = p.value
        guard let tz = value.hasSuffix("Z") ? TimeZone(secondsFromGMT: 0) : zone(p.parameters["TZID"], fallback: fallback) else { return nil }
        let format: String
        switch value.count {
        case 8: format = "yyyyMMdd"
        case 13: format = "yyyyMMdd'T'HHmm"
        case 15: format = "yyyyMMdd'T'HHmmss"
        case 16 where value.hasSuffix("Z"): format = "yyyyMMdd'T'HHmmss'Z'"
        default: return nil
        }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = tz
        formatter.dateFormat = format
        formatter.isLenient = false
        guard let parsed = formatter.date(from: value), formatter.string(from: parsed) == value else { return nil }
        return (parsed, tz)
    }

    static func parse(data: Data, sourceID: String, sourceName: String, fallbackZone: TimeZone = .current, kind: PlannerEventKind = .university) throws -> CalendarImportDraft {
        guard data.count <= 5_000_000 else { throw ICSImportError.tooLarge }
        guard let raw = String(data: data, encoding: .utf8), raw.uppercased().contains("BEGIN:VCALENDAR"), raw.uppercased().contains("END:VCALENDAR") else { throw ICSImportError.invalidFile }
        var lines: [String] = []
        for line in raw.replacingOccurrences(of: "\r\n", with: "\n").replacingOccurrences(of: "\r", with: "\n").components(separatedBy: "\n") {
            if (line.hasPrefix(" ") || line.hasPrefix("\t")), !lines.isEmpty { lines[lines.count - 1] += line.dropFirst() }
            else { lines.append(line) }
        }
        var groups: [[Property]] = [], current: [Property]?, nestedDepth = 0, malformedProperties = 0
        for line in lines {
            let upper = line.uppercased()
            if upper == "BEGIN:VEVENT" { current = []; nestedDepth = 0 }
            else if upper == "END:VEVENT" { if let current { groups.append(current) }; current = nil }
            else if current != nil {
                if upper.hasPrefix("BEGIN:") { nestedDepth += 1 }
                else if upper.hasPrefix("END:") { nestedDepth -= 1 }
                else if nestedDepth == 0 {
                    if let value = property(line) { current!.append(value) }
                    else if !line.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { malformedProperties += 1 }
                }
            }
        }
        var warnings: [String] = malformedProperties > 0 ? ["\(malformedProperties) unlesbare Kalenderfelder wurden ignoriert. Bitte die Vorschau prüfen."] : []
        var unsupportedUIDs: Set<String> = []
        for group in groups where group.contains(where: { $0.name == "RECURRENCE-ID" }) {
            if let uid = group.first(where: { $0.name == "UID" })?.value { unsupportedUIDs.insert(uid) }
        }
        var events: [PlannerEvent] = []
        var seen: Set<String> = []
        let weekdayCodes = ["SU": 1, "MO": 2, "TU": 3, "WE": 4, "TH": 5, "FR": 6, "SA": 7]
        for group in groups {
            func first(_ name: String) -> Property? { group.first { $0.name == name } }
            let title = text(first("SUMMARY")?.value ?? "Ohne Titel")
            guard let uid = first("UID")?.value, !uid.isEmpty else { warnings.append("\(title): Kalenderkennung fehlt, nicht übernommen."); continue }
            guard !unsupportedUIDs.contains(uid) else { warnings.append("\(title): Verschobene Serienvorkommen (RECURRENCE-ID) werden noch nicht unterstützt. Die betroffene Serie bleibt unverändert."); continue }
            guard let begin = first("DTSTART"), let (start, timezone) = date(begin, fallback: fallbackZone) else { warnings.append("\(title): Beginn oder Zeitzone konnte nicht gelesen werden."); continue }
            var calendar = Calendar(identifier: .gregorian); calendar.timeZone = timezone
            let finish = first("DTEND").flatMap { date($0, fallback: timezone)?.0 } ?? (begin.value.count == 8 ? calendar.date(byAdding: .day, value: 1, to: start) : nil)
            guard let end = finish, end > start, end.timeIntervalSince(start) <= 7 * 86400 else { warnings.append("\(title): Ein gültiges Ende fehlt. Bitte manuell ergänzen."); continue }
            var event = PlannerEvent(title: title, kind: kind, start: start, end: end)
            event.timeZoneID = timezone.identifier
            event.location = kind.suggestedLocation
            if let location = first("LOCATION"), kind == .personal { event.location = text(location.value).isEmpty ? "home" : text(location.value) }
            event.sourceID = sourceID; event.sourceUID = uid
            event.cancelled = first("STATUS")?.value.uppercased() == "CANCELLED"
            if let rule = first("RRULE") {
                var values: [String: String] = [:]
                for token in rule.value.uppercased().split(separator: ";") {
                    let pair = token.split(separator: "=", maxSplits: 1).map(String.init)
                    if pair.count == 2 { values[pair[0]] = pair[1] }
                }
                let allowed: Set<String> = ["FREQ", "INTERVAL", "BYDAY", "UNTIL", "COUNT", "WKST"]
                guard values["FREQ"] == "WEEKLY", values["INTERVAL"].map({ $0 == "1" }) ?? true,
                      Set(values.keys).isSubset(of: allowed), !(values["UNTIL"] != nil && values["COUNT"] != nil) else {
                    warnings.append("\(title): Nur wöchentliche Serien mit Intervall 1 werden unterstützt. Nicht übernommen."); continue
                }
                event.weekly = true
                if let byDay = values["BYDAY"] {
                    let days = byDay.split(separator: ",").map(String.init)
                    guard !days.isEmpty, days.allSatisfy({ weekdayCodes[$0] != nil }) else { warnings.append("\(title): BYDAY-Regel nicht unterstützt."); continue }
                    event.repeatWeekdays = Set(days.compactMap { weekdayCodes[$0] })
                }
                if let until = values["UNTIL"] {
                    guard let parsed = date(Property(name: "UNTIL", parameters: [:], value: until), fallback: timezone)?.0 else { warnings.append("\(title): Serienende unlesbar."); continue }
                    event.repeatUntil = parsed
                }
                if let count = values["COUNT"] {
                    guard let value = Int(count), (1...10000).contains(value) else { warnings.append("\(title): Ungültige Anzahl Wiederholungen."); continue }
                    event.recurrenceCount = value
                }
            }
            if first("RDATE") != nil { warnings.append("\(title): Zusätzliche Serientermine (RDATE) werden noch nicht unterstützt. Nicht übernommen."); continue }
            var badException = false
            for exception in group.filter({ $0.name == "EXDATE" }) {
                for value in exception.value.split(separator: ",") {
                    var p = exception; p.value = String(value)
                    guard let excluded = date(p, fallback: timezone)?.0 else { badException = true; continue }
                    event.excludedDays.insert(PlannerDate.dayKey(excluded, calendar: calendar))
                }
            }
            guard !badException else { warnings.append("\(title): Ausnahmedatum unlesbar. Nicht übernommen."); continue }
            guard seen.insert(uid).inserted else { warnings.append("\(title): Doppelte Kalenderkennung in dieser Datei. Nur das erste Vorkommen wird übernommen."); continue }
            events.append(event)
        }
        return CalendarImportDraft(events: events, warnings: Array(Set(warnings)).sorted(), sourceID: sourceID, sourceName: sourceName)
    }
}
