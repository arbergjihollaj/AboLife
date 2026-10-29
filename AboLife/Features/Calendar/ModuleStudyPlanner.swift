import Foundation

/// Derived module tasks. Lecture-day identity is stable across reimport and time edits.
enum ModuleStudyPlanner {
    private struct TeachingDay {
        var key: String
        var course: String
        var day: String
        var first: Date
        var last: Date
    }

    static func module(for title: String) -> (key: String, title: String)? {
        let trimmed = title.split(whereSeparator: \.isWhitespace).joined(separator: " ")
        guard !trimmed.isEmpty, trimmed.lowercased() != "ohne titel" else { return nil }
        if let code = trimmed.range(of: #"\([0-9]{2}-[0-9]{4,}\)\s*$"#, options: .regularExpression) {
            let name = String(trimmed[..<code.lowerBound]).trimmingCharacters(in: .whitespaces)
            return ("code:" + trimmed[code].trimmingCharacters(in: CharacterSet(charactersIn: "() ")), name.isEmpty ? trimmed : name)
        }
        let key = trimmed.precomposedStringWithCanonicalMapping.lowercased(with: Locale(identifier: "de_DE"))
        return ("title:" + key, trimmed)
    }

    static func synchronize(_ workspace: inout CalendarWorkspace, now: Date, days: Int) {
        let calendar = workspace.preferences.calendar
        let begin = calendar.startOfDay(for: now)
        let end = calendar.date(byAdding: .day, value: days, to: begin)!
        let context = DateInterval(start: calendar.date(byAdding: .day, value: -14, to: begin)!, end: calendar.date(byAdding: .day, value: 14, to: end)!)
        let oldTopics = Dictionary(workspace.topics.map { ($0.id, $0) }, uniquingKeysWith: { first, last in last.automaticTask != nil ? last : first })
        let completed = Set(workspace.sessions.filter { $0.status == .completed }.map(\.topicID))
        let protected = Set(workspace.sessions.filter { $0.status != .planned || $0.pinned || $0.start < now }.map(\.topicID))
        var groups: [String: TeachingDay] = [:]
        if workspace.preferences.modulePlanningEnabled {
            for event in workspace.events where event.kind == .university {
                guard let module = module(for: event.title) else { continue }
                for occurrence in event.occurrences(in: context) {
                    let day = PlannerDate.dayKey(occurrence.start, calendar: calendar)
                    let key = module.key + "/" + day
                    if var group = groups[key] {
                        group.first = min(group.first, occurrence.start); group.last = max(group.last, occurrence.end)
                        groups[key] = group
                    } else { groups[key] = TeachingDay(key: module.key, course: module.title, day: day, first: occurrence.start, last: occurrence.end) }
                }
            }
        }
        let teachingDays = groups.values.sorted { $0.first == $1.first ? $0.key < $1.key : $0.first < $1.first }
        var previousEnd: [String: Date] = [:]
        var generated: [StudyTopic] = []
        for group in teachingDays {
            let pause = Double(workspace.preferences.breakMinutes) * 60
            // Keep two allowed learning days available for preparation. Consecutive
            // days off must not force all Monday–Wednesday modules onto Sunday.
            let previousLearningDays = (1...14).compactMap { calendar.date(byAdding: .day, value: -$0, to: group.first) }.filter { workspace.preferences.weekdays.contains(calendar.component(.weekday, from: $0)) }.prefix(2)
            let previousLearningDay = previousLearningDays.first ?? calendar.date(byAdding: .day, value: -1, to: group.first)!
            let nextLearningDay = (1...7).compactMap { calendar.date(byAdding: .day, value: $0, to: group.last) }.first { workspace.preferences.weekdays.contains(calendar.component(.weekday, from: $0)) } ?? calendar.date(byAdding: .day, value: 1, to: group.last)!
            let earliestPreparationDay = calendar.startOfDay(for: previousLearningDays.last ?? previousLearningDay)
            let preparationStart = max(earliestPreparationDay, previousEnd[group.key]?.addingTimeInterval(pause) ?? .distantPast)
            previousEnd[group.key] = group.last
            for phase in ModuleStudyPhase.allCases {
                let earliest = phase == .preparation ? preparationStart : group.last.addingTimeInterval(pause)
                let deadline = phase == .preparation ? group.first : PlannerDate.atMinute(workspace.preferences.dayEndMinute, on: nextLearningDay, calendar: calendar)
                guard deadline > now, earliest < end else { continue }
                let encoded = Data(group.key.utf8).base64EncodedString().replacingOccurrences(of: "/", with: "_").replacingOccurrences(of: "+", with: "-")
                let id = "module/\(encoded)/\(group.day)/\(phase.rawValue)"
                let old = oldTopics[id]
                let preferred = phase == .preparation ? previousLearningDay : earliest
                var task = AutomaticModuleTask(moduleKey: group.key, phase: phase, teachingDay: group.day, firstLesson: group.first, lastLesson: group.last, earliestStart: earliest, preferredStart: preferred, latestEnd: deadline)
                task.deferredUntil = old?.automaticTask?.deferredUntil
                var topic = old ?? StudyTopic(id: id, title: phase.title, course: group.course)
                topic.title = phase.title; topic.course = group.course; topic.automaticTask = task
                topic.nextReview = max(earliest, task.deferredUntil ?? .distantPast)
                topic.archived = completed.contains(id)
                let durations = workspace.sessions.filter { session in
                    guard session.status == .completed, let metadata = oldTopics[session.topicID]?.automaticTask else { return false }
                    return metadata.moduleKey == group.key && metadata.phase == phase && session.actualMinutes != nil
                }.sorted { ($0.reviewedAt ?? $0.end) < ($1.reviewedAt ?? $1.end) }.suffix(5).compactMap(\.actualMinutes)
                topic.actualDurations = durations
                generated.append(topic)
            }
        }
        let generatedIDs = Set(generated.map(\.id))
        let removedIDs = Set(workspace.topics.filter { ($0.automaticTask != nil || $0.id.hasPrefix("module/")) && !generatedIDs.contains($0.id) }.map(\.id))
        // Retain labels/history and explicitly fixed/running blocks when the source disappears.
        let historical = workspace.topics.filter { removedIDs.contains($0.id) && protected.contains($0.id) }.map { topic -> StudyTopic in
            var value = topic; value.archived = true; return value
        }
        workspace.sessions.removeAll { removedIDs.contains($0.topicID) && $0.status == .planned && !$0.pinned && $0.start >= now }
        workspace.topics = workspace.topics.filter { $0.automaticTask == nil && !$0.id.hasPrefix("module/") } + generated.sorted { $0.id < $1.id } + historical
    }
}
