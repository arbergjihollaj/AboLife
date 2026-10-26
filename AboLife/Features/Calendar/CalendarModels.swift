import Foundation

// Entries and review history are the truth; suggestions are regenerated from them.
struct CalendarWorkspace: Codable, Equatable {
    var events: [PlannerEvent] = []
    var topics: [StudyTopic] = []
    var sessions: [StudySession] = []
    var preferences = PlannerPreferences()
    var importSources: [PlannerImportSource] = []
}

struct PlannerImportSource: Codable, Identifiable, Equatable {
    var id: String = UUID().uuidString
    var name: String
}

enum PlannerEventKind: String, Codable, CaseIterable, Identifiable {
    case university, training, personal
    var id: String { rawValue }
    var title: String {
        switch self { case .university: return "Uni"; case .training: return "Training"; case .personal: return "Privat" }
    }
    var suggestedLocation: String {
        switch self { case .university: return "university"; case .training: return "gym"; case .personal: return "home" }
    }
}

struct PlannerEvent: Codable, Equatable, Identifiable {
    var id: String = UUID().uuidString
    var title: String
    var kind: PlannerEventKind
    var start: Date
    var end: Date
    var location = "home"
    var timeZoneID = TimeZone.current.identifier
    var weekly = false
    var repeatUntil: Date?
    var repeatWeekdays: Set<Int> = []
    var recurrenceCount: Int?
    var excludedDays: Set<String> = []
    var sourceID: String?
    var sourceUID: String?
    var locallyModified = false
    var cancelled = false

    func occurrences(in interval: DateInterval) -> [PlannerOccurrence] {
        guard !cancelled, end > start else { return [] }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: timeZoneID) ?? .current
        if !weekly {
            guard end > interval.start, start < interval.end,
                  !excludedDays.contains(PlannerDate.dayKey(start, calendar: calendar)) else { return [] }
            return [PlannerOccurrence(eventID: id, title: title, kind: kind, start: start, end: end, location: location, dayKey: PlannerDate.dayKey(start, calendar: calendar))]
        }
        let startParts = calendar.dateComponents([.weekday, .hour, .minute, .second], from: start)
        let endParts = calendar.dateComponents([.hour, .minute, .second], from: end)
        let dayOffset = calendar.dateComponents([.day], from: calendar.startOfDay(for: start), to: calendar.startOfDay(for: end)).day ?? 0
        // Include the previous days for overnight occurrences intersecting the horizon.
        var day = recurrenceCount == nil ? calendar.date(byAdding: .day, value: -max(dayOffset, 1), to: calendar.startOfDay(for: interval.start))! : calendar.startOfDay(for: start)
        var occurrenceCount = 0
        let weekdays = repeatWeekdays.isEmpty ? Set([startParts.weekday!]) : repeatWeekdays
        var result: [PlannerOccurrence] = []
        while day < interval.end {
            defer { day = calendar.date(byAdding: .day, value: 1, to: day)! }
            guard weekdays.contains(calendar.component(.weekday, from: day)),
                  let occurrenceStart = calendar.date(bySettingHour: startParts.hour!, minute: startParts.minute!, second: startParts.second ?? 0, of: day),
                  occurrenceStart >= start,
                  repeatUntil.map({ occurrenceStart <= $0 }) ?? true,
                  let endDay = calendar.date(byAdding: .day, value: dayOffset, to: day),
                  let occurrenceEnd = calendar.date(bySettingHour: endParts.hour!, minute: endParts.minute!, second: endParts.second ?? 0, of: endDay),
                  occurrenceEnd > occurrenceStart else { continue }
            occurrenceCount += 1
            if let limit = recurrenceCount, occurrenceCount > limit { break }
            guard occurrenceEnd > interval.start, occurrenceStart < interval.end,
                  !excludedDays.contains(PlannerDate.dayKey(occurrenceStart, calendar: calendar)) else { continue }
            result.append(PlannerOccurrence(eventID: id, title: title, kind: kind, start: occurrenceStart, end: occurrenceEnd, location: location, dayKey: PlannerDate.dayKey(occurrenceStart, calendar: calendar)))
        }
        return result
    }
}

struct PlannerOccurrence: Identifiable, Equatable {
    var eventID: String
    var title: String
    var kind: PlannerEventKind
    var start: Date
    var end: Date
    var location: String
    var dayKey: String
    var id: String { eventID + "/" + dayKey }
    var interval: DateInterval { DateInterval(start: start, end: end) }
}

struct StudyTopic: Codable, Identifiable, Equatable {
    var id: String = UUID().uuidString
    var title: String
    var course: String
    var durationMinutes = 25
    var nextReview = Date()
    var examDate: Date?
    var intervalDays = 0.0
    var ease = 2.3
    var reviewCount = 0
    var actualDurations: [Int] = []
    var archived = false
    var estimatedMinutes: Int {
        let recent = actualDurations.suffix(5).sorted()
        return recent.isEmpty ? durationMinutes : recent[recent.count / 2]
    }
}

enum StudyRating: String, Codable, CaseIterable, Identifiable {
    case again, hard, good, easy
    var id: String { rawValue }
    var title: String {
        switch self { case .again: return "Vergessen"; case .hard: return "Schwer"; case .good: return "Gut"; case .easy: return "Leicht" }
    }
}

enum StudySessionStatus: String, Codable { case planned, completed, skipped }

struct StudySession: Codable, Equatable, Identifiable {
    var id: String = UUID().uuidString
    var topicID: String
    var start: Date
    var end: Date
    var location = "home"
    var pinned = false
    var status: StudySessionStatus = .planned
    var rating: StudyRating?
    var actualMinutes: Int?
    var reviewedAt: Date?
    var reason = ""
    var minutes: Int { max(Int(end.timeIntervalSince(start) / 60), 0) }
    var interval: DateInterval { DateInterval(start: start, end: end) }
}

struct PlannerPreferences: Codable, Equatable {
    var dayStartMinute = 8 * 60
    var dayEndMinute = 21 * 60
    var weekdays: Set<Int> = [2, 3, 4, 5, 6]
    var dailyLimitMinutes = 120
    var minimumBlockMinutes = 25
    var breakMinutes = 10
    var timeZoneID = TimeZone.current.identifier
    // Optional for backwards compatibility with saved 0.2 workspaces.
    // Unless explicitly disabled, a missing return duration follows the outbound route.
    var assumeSymmetricReturn: Bool?
    var usesSymmetricReturn: Bool { assumeSymmetricReturn != false }
    var travelMinutes: [String: Int] = ["home>university": 60, "home>gym": 15]
    var learningLocations: Set<String> = ["home", "university"]
    func travel(from: String, to: String) -> Int? {
        if from == to { return 0 }
        if let explicit = travelMinutes[from + ">" + to] { return explicit }
        if to == "home" && usesSymmetricReturn { return travelMinutes["home>" + from] }
        return nil
    }
    func returnIsEstimated(from: String, to: String) -> Bool {
        from != to && to == "home" && travelMinutes[from + ">" + to] == nil && usesSymmetricReturn && travelMinutes["home>" + from] != nil
    }
    var calendar: Calendar {
        var value = Calendar(identifier: .gregorian)
        value.timeZone = TimeZone(identifier: timeZoneID) ?? .current
        value.locale = Locale(identifier: "de_DE")
        value.firstWeekday = 2
        return value
    }
}

enum PlannerDate {
    static func dayKey(_ date: Date, calendar: Calendar) -> String {
        let p = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", p.year!, p.month!, p.day!)
    }
    static func locationID(_ label: String) -> String {
        switch label.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "zuhause", "home": return "home"
        case "uni", "university": return "university"
        case "training", "training außer haus", "gym": return "gym"
        default: return label.trimmingCharacters(in: .whitespacesAndNewlines)
        }
    }
    static func locationName(_ location: String) -> String {
        switch location { case "home": return "Zuhause"; case "university": return "Uni"; case "gym": return "Training außer Haus"; default: return location }
    }
    static func atMinute(_ minute: Int, on day: Date, calendar: Calendar) -> Date {
        calendar.date(bySettingHour: minute / 60, minute: minute % 60, second: 0, of: day)!
    }
}

/// Version 1 of an explicit heuristic for topic blocks, not a fitted memory model.
enum StudyReviewPolicy {
    static func apply(_ rating: StudyRating, to topic: inout StudyTopic, at date: Date, actualMinutes: Int, calendar: Calendar) {
        switch rating {
        case .again: topic.intervalDays = 1; topic.ease = max(1.3, topic.ease - 0.3)
        case .hard: topic.intervalDays = max(1, topic.intervalDays * 0.8); topic.ease = max(1.3, topic.ease - 0.15)
        case .good: topic.intervalDays = topic.reviewCount == 0 ? 2 : max(1, topic.intervalDays * topic.ease)
        case .easy: topic.intervalDays = topic.reviewCount == 0 ? 4 : max(3, topic.intervalDays * (topic.ease + 0.4)); topic.ease = min(3, topic.ease + 0.15)
        }
        topic.intervalDays = min(topic.intervalDays, 90)
        topic.nextReview = calendar.date(byAdding: .day, value: Int(topic.intervalDays.rounded()), to: date)!
        topic.reviewCount += 1
        topic.actualDurations = Array((topic.actualDurations + [min(max(actualMinutes, 5), 180)]).suffix(5))
    }
}
