import Foundation

struct PlannerIssue: Identifiable, Equatable {
    var id: String { message }
    var message: String
}
struct StudyFreeWindow: Equatable {
    var interval: DateInterval
    var location: String
}
struct StudyPlanResult {
    var sessions: [StudySession]
    var issues: [PlannerIssue]
    var unplaced: [String: String]
}

struct PlannerJourney: Identifiable, Equatable {
    var start: Date
    var end: Date
    var from: String
    var to: String
    var estimatedReturn: Bool
    var id: String { "journey/\(from)/\(to)/\(start.timeIntervalSince1970)/\(end.timeIntervalSince1970)" }
    var interval: DateInterval { DateInterval(start: start, end: end) }
    var title: String {
        if to == "home" { return "Rückfahrt nach Hause" }
        if to == "university" { return from == "home" ? "Hinfahrt zur Uni" : "Weiterfahrt zur Uni" }
        if to == "gym" { return from == "home" ? "Hinfahrt zum Training" : "Weiterfahrt zum Training" }
        return "Fahrt nach \(PlannerDate.locationName(to))"
    }
}

enum StudyPlannerEngine {
    static func overlaps(_ a: DateInterval, _ b: DateInterval) -> Bool {
        a.start < b.end && b.start < a.end
    }
    static func subtract(_ block: DateInterval, from windows: [StudyFreeWindow]) -> [StudyFreeWindow] {
        windows.flatMap { w -> [StudyFreeWindow] in
            guard overlaps(w.interval, block) else { return [w] }
            var result: [StudyFreeWindow] = []
            if w.interval.start < block.start { result.append(StudyFreeWindow(interval: DateInterval(start: w.interval.start, end: min(block.start, w.interval.end)), location: w.location)) }
            if block.end < w.interval.end { result.append(StudyFreeWindow(interval: DateInterval(start: max(block.end, w.interval.start), end: w.interval.end), location: w.location)) }
            return result
        }
    }

    static func availability(events: [PlannerEvent], preferences p: PlannerPreferences, horizon: DateInterval) -> (windows: [StudyFreeWindow], issues: [PlannerIssue], journeys: [PlannerJourney]) {
        let calendar = p.calendar
        let expanded: [PlannerOccurrence] = events.flatMap { event in event.occurrences(in: horizon) }
        let occurrences: [PlannerOccurrence] = expanded.sorted { (a: PlannerOccurrence, b: PlannerOccurrence) in
            if a.start == b.start { return a.id < b.id }
            return a.start < b.start
        }
        var windows: [StudyFreeWindow] = []
        var issues: [PlannerIssue] = []
        var journeys: [PlannerJourney] = []
        var day = calendar.startOfDay(for: horizon.start)
        while day < horizon.end {
            defer { day = calendar.date(byAdding: .day, value: 1, to: day)! }
            let nextDay = calendar.date(byAdding: .day, value: 1, to: day)!
            let dayEvents = occurrences.filter { $0.start < nextDay && $0.end > day }
            let lastCampusEnd = dayEvents.filter { $0.location == "university" }.map(\.end).max()
            let allowedStart = PlannerDate.atMinute(p.dayStartMinute, on: day, calendar: calendar)
            let allowedEnd = PlannerDate.atMinute(p.dayEndMinute, on: day, calendar: calendar)
            let canLearn = p.weekdays.contains(calendar.component(.weekday, from: day)) && allowedEnd > allowedStart
            let dayLabel = day.formatted(.dateTime.locale(Locale(identifier: "de_DE")).day().month())
            var cursor = day
            var location = "home"
            var previousTitle: String?
            func addWindow(_ start: Date, _ end: Date, place: String) {
                let a = max(start, allowedStart, horizon.start)
                let b = min(end, allowedEnd, horizon.end)
                if canLearn && b > a { windows.append(StudyFreeWindow(interval: DateInterval(start: a, end: b), location: place)) }
            }
            func addJourney(_ start: Date, _ end: Date, from: String, to: String) {
                guard from != to, end > start, end > horizon.start, start < horizon.end else { return }
                journeys.append(PlannerJourney(start: start, end: end, from: from, to: to, estimatedReturn: p.returnIsEstimated(from: from, to: to)))
            }
            for event in dayEvents {
                if let previousTitle, event.start < cursor {
                    issues.append(PlannerIssue(message: "\(dayLabel): \(previousTitle) und \(event.title) überschneiden sich."))
                }
                if event.start >= cursor {
                    var missingHomeRoute = false
                    // University breaks form one campus stay. Once the last campus
                    // appointment ends, go home before any later out-of-home activity.
                    if location == "university", event.location != "university", event.location != "home",
                       let lastCampusEnd, cursor >= lastCampusEnd {
                        if let home = p.travel(from: location, to: "home"), let outbound = p.travel(from: "home", to: event.location) {
                            let arrivalHome = cursor.addingTimeInterval(Double(home) * 60)
                            let leaveHome = event.start.addingTimeInterval(-Double(outbound) * 60)
                            if arrivalHome <= leaveHome {
                                addJourney(cursor, arrivalHome, from: location, to: "home")
                                cursor = arrivalHome
                                location = "home"
                            } else {
                                issues.append(PlannerIssue(message: "\(dayLabel): Nach der Uni reicht die Zeit nicht für den Heimweg und die anschließende Hinfahrt zu „\(event.title)“. Eine direkte Weiterfahrt ist nur mit bekannter passender Fahrtzeit möglich."))
                            }
                        } else {
                            missingHomeRoute = true
                            issues.append(PlannerIssue(message: "\(dayLabel): Für den Heimweg nach der Uni und den späteren Termin „\(event.title)“ fehlt die Rückfahrt oder die Hinfahrt von Zuhause. Diese Lücke bleibt frei."))
                        }
                    }
                    if missingHomeRoute {
                        // No guessed duration or campus study after a requested return.
                    } else if location == event.location {
                        // One stay at the same place, even during long breaks or when
                        // campus learning is disabled. Never add an automatic home detour.
                        if p.learningLocations.contains(location) { addWindow(cursor, event.start, place: location) }
                    } else if let travel = p.travel(from: location, to: event.location) {
                        let duration = Double(travel) * 60
                        let departure = event.start.addingTimeInterval(-duration)
                        if previousTitle != nil && departure < cursor {
                            issues.append(PlannerIssue(message: "\(dayLabel): Zu wenig Fahrtzeit. Zu wenig Zeit für den Ortswechsel vor „\(event.title)“."))
                        } else if p.learningLocations.contains(location) {
                            addWindow(cursor, departure, place: location)
                            addJourney(departure, event.start, from: location, to: event.location)
                        } else if p.learningLocations.contains(event.location) {
                            // Travel directly to campus and use the remaining break there.
                            let arrival = cursor.addingTimeInterval(duration)
                            addJourney(cursor, arrival, from: location, to: event.location)
                            addWindow(arrival, event.start, place: event.location)
                        } else {
                            addJourney(departure, event.start, from: location, to: event.location)
                        }
                    } else {
                        issues.append(PlannerIssue(message: "\(dayLabel): Fahrtzeit \(PlannerDate.locationName(location)) → \(PlannerDate.locationName(event.location)) fehlt. Diese Lücke bleibt frei."))
                    }
                }
                // Overlapping fixed events remain visible conflicts; block their union.
                if event.end >= cursor { cursor = event.end; location = event.location; previousTitle = event.title }
            }
            if cursor < nextDay {
                if let home = p.travel(from: location, to: "home") {
                    let arrival = cursor.addingTimeInterval(Double(home) * 60)
                    addJourney(cursor, arrival, from: location, to: "home")
                    addWindow(arrival, nextDay, place: "home")
                } else {
                    issues.append(PlannerIssue(message: "\(dayLabel): Rückfahrt von \(PlannerDate.locationName(location)) fehlt. Danach wird noch kein Lernen geplant."))
                }
            }
        }
        // The displayed journeys and the planner use exactly the same reservations.
        for journey in journeys { windows = subtract(journey.interval, from: windows) }
        return (windows, Array(Set(issues.map(\.message))).sorted().map { PlannerIssue(message: $0) }, journeys)
    }

    static func plan(_ workspace: CalendarWorkspace, now: Date, days: Int = 14) -> StudyPlanResult {
        let p = workspace.preferences, calendar = p.calendar
        let start = calendar.startOfDay(for: now)
        let end = calendar.date(byAdding: .day, value: days, to: start)!
        let horizon = DateInterval(start: start, end: end)
        let base = availability(events: workspace.events, preferences: p, horizon: horizon)
        var windows = base.windows
        var issues = base.issues
        var retained: [StudySession] = []
        var used: [String: Int] = [:]
        var placed: Set<String> = []
        let topics = Dictionary(uniqueKeysWithValues: workspace.topics.map { ($0.id, $0) })
        func consume(_ session: StudySession) {
            let padding = Double(p.breakMinutes) * 60
            windows = subtract(DateInterval(start: session.start.addingTimeInterval(-padding), end: session.end.addingTimeInterval(padding)), from: windows)
            used[PlannerDate.dayKey(session.start, calendar: calendar), default: 0] += session.minutes
        }
        // Preserve history, running sessions and explicit pins. Never silently move them.
        for session in workspace.sessions.sorted(by: { $0.start < $1.start }) {
            if session.status != .planned || session.start < now || session.pinned {
                retained.append(session)
                guard session.status != .skipped, session.end > start, session.start < end else { continue }
                if session.end > now {
                    let valid = windows.contains { $0.location == session.location && $0.interval.start <= session.start && $0.interval.end >= session.end }
                    if !valid {
                        issues.append(PlannerIssue(message: "Fixierter/laufender Lernblock am \(session.start.formatted(date: .abbreviated, time: .shortened)) hat einen Termin-, Wege- oder Verfügbarkeitskonflikt. Bitte selbst auflösen."))
                    }
                    if session.status == .planned { placed.insert(session.topicID) }
                }
                consume(session)
                if used[PlannerDate.dayKey(session.start, calendar: calendar), default: 0] > p.dailyLimitMinutes {
                    issues.append(PlannerIssue(message: "Am \(session.start.formatted(date: .abbreviated, time: .omitted)) überschreiten erledigte oder fixierte Einheiten deine Tagesgrenze."))
                }
                if session.status == .planned, let exam = topics[session.topicID]?.examDate, session.end > exam {
                    issues.append(PlannerIssue(message: "Eine fixierte Lerneinheit liegt nach ihrem Prüfungstermin. Bitte die Fixierung oder den Termin anpassen."))
                }
            }
        }
        // Retain valid suggestions to avoid calendar jitter after unrelated changes.
        for session in workspace.sessions.filter({ $0.status == .planned && !$0.pinned && $0.start >= now }).sorted(by: { $0.start == $1.start ? $0.id < $1.id : $0.start < $1.start }) {
            guard let topic = topics[session.topicID], !topic.archived,
                  !placed.contains(topic.id), session.start >= topic.nextReview,
                  topic.examDate.map({ session.end <= $0 }) ?? true,
                  session.minutes == max(p.minimumBlockMinutes, topic.estimatedMinutes),
                  windows.contains(where: { $0.location == session.location && $0.interval.start <= session.start && $0.interval.end >= session.end }),
                  used[PlannerDate.dayKey(session.start, calendar: calendar), default: 0] + session.minutes <= p.dailyLimitMinutes else { continue }
            retained.append(session); placed.insert(topic.id); consume(session)
        }
        let ordered = workspace.topics.filter { !$0.archived && $0.nextReview < end }.sorted { a, b in
            func priority(_ t: StudyTopic) -> Double {
                let overdue = max(now.timeIntervalSince(t.nextReview) / 86400, 0) * 2
                return overdue + (t.examDate.map { max(14 - $0.timeIntervalSince(now) / 86400, 0) } ?? 0)
            }
            return priority(a) == priority(b) ? (a.nextReview == b.nextReview ? a.id < b.id : a.nextReview < b.nextReview) : priority(a) > priority(b)
        }
        var unplaced: [String: String] = [:]
        for topic in ordered where !placed.contains(topic.id) {
            let duration = max(p.minimumBlockMinutes, min(topic.estimatedMinutes, 180))
            var found: StudySession?
            for window in windows.sorted(by: { $0.interval.start < $1.interval.start }) {
                let earliest = max(window.interval.start, now, topic.nextReview)
                let rounded = Date(timeIntervalSince1970: ceil(earliest.timeIntervalSince1970 / 300) * 300)
                let finish = rounded.addingTimeInterval(Double(duration) * 60)
                guard finish <= window.interval.end,
                      topic.examDate.map({ finish <= $0 }) ?? true,
                      used[PlannerDate.dayKey(rounded, calendar: calendar), default: 0] + duration <= p.dailyLimitMinutes else { continue }
                found = StudySession(id: "plan/\(topic.id)/\(Int(rounded.timeIntervalSince1970))", topicID: topic.id, start: rounded, end: finish, location: window.location,
                                     reason: "Wiederholung fällig · \(duration) Min. frei in \(PlannerDate.locationName(window.location)); Termine, Wege und Pausen berücksichtigt.")
                break
            }
            if let session = found { retained.append(session); placed.insert(topic.id); consume(session) }
            else { unplaced[topic.id] = topic.examDate.map { $0 < now } == true ? "Prüfungstermin liegt bereits zurück." : "Kein passendes freies Zeitfenster innerhalb der nächsten \(days) Tage und deiner Tagesgrenze." }
        }
        return StudyPlanResult(sessions: retained.sorted { $0.start == $1.start ? $0.id < $1.id : $0.start < $1.start }, issues: issues, unplaced: unplaced)
    }
}
