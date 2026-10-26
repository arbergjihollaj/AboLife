import Foundation
import Combine

@MainActor
final class CalendarPlannerStore: ObservableObject {
    @Published private(set) var workspace = CalendarWorkspace()
    @Published private(set) var issues: [PlannerIssue] = []
    @Published private(set) var unplaced: [String: String] = [:]
    @Published var errorMessage: String?
    @Published var notice: String?
    private let repository: CalendarRepository?
    private let now: () -> Date
    private var loadedSuccessfully = false

    init(database: AppDatabase?, now: @escaping () -> Date = Date.init) {
        repository = database.map(CalendarRepository.init)
        self.now = now
        reload()
    }
    func reload() {
        do {
            if let repository { workspace = try repository.load() }
            let result = StudyPlannerEngine.plan(workspace, now: now())
            if workspace.sessions != result.sessions {
                workspace.sessions = result.sessions
                try repository?.save(workspace)
            }
            issues = result.issues; unplaced = result.unplaced
            loadedSuccessfully = true
        } catch {
            loadedSuccessfully = false
            errorMessage = "Kalender konnte nicht geladen werden: \(error.localizedDescription)"
        }
    }
    @discardableResult
    private func change(_ edit: (inout CalendarWorkspace) -> Void) -> Bool {
        guard loadedSuccessfully else { errorMessage = "Die Kalenderdaten konnten nicht gelesen werden. Bitte zuerst den Ladefehler beheben; vorhandene Daten werden nicht überschrieben."; return false }
        var candidate = workspace
        edit(&candidate)
        let result = StudyPlannerEngine.plan(candidate, now: now())
        candidate.sessions = result.sessions
        do {
            try repository?.save(candidate)
            workspace = candidate; issues = result.issues; unplaced = result.unplaced
            errorMessage = nil
            return true
        } catch { errorMessage = "Änderung konnte nicht gespeichert werden: \(error.localizedDescription)"; return false }
    }
    @discardableResult
    func saveEvent(_ event: PlannerEvent) -> Bool {
        guard !event.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, event.end > event.start,
              event.end.timeIntervalSince(event.start) <= 7 * 86400 else { errorMessage = "Bitte Titel und einen gültigen Zeitraum von höchstens sieben Tagen eintragen."; return false }
        return change { workspace in
            if let index = workspace.events.firstIndex(where: { $0.id == event.id }) {
                var modified = event
                if modified.sourceID != nil { modified.locallyModified = true }
                workspace.events[index] = modified
            } else { workspace.events.append(event) }
        }
    }
    func cancel(_ occurrence: PlannerOccurrence) {
        _ = change { workspace in
            guard let index = workspace.events.firstIndex(where: { $0.id == occurrence.eventID }) else { return }
            workspace.events[index].excludedDays.insert(occurrence.dayKey)
            if workspace.events[index].sourceID != nil { workspace.events[index].locallyModified = true }
        }
    }
    func removeEvent(_ id: String) {
        _ = change { workspace in
            guard let index = workspace.events.firstIndex(where: { $0.id == id }) else { return }
            if workspace.events[index].sourceID != nil {
                workspace.events[index].cancelled = true; workspace.events[index].locallyModified = true
            } else { workspace.events.remove(at: index) }
        }
    }
    @discardableResult
    func saveTopic(_ topic: StudyTopic) -> Bool {
        guard !topic.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              !topic.course.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              (5...180).contains(topic.durationMinutes) else { errorMessage = "Bitte Fach, Thema und eine Dauer von 5 bis 180 Minuten eintragen."; return false }
        return change { workspace in
            if let index = workspace.topics.firstIndex(where: { $0.id == topic.id }) { workspace.topics[index] = topic }
            else { workspace.topics.append(topic) }
        }
    }
    func archiveTopic(_ id: String) {
        _ = change { workspace in
            if let index = workspace.topics.firstIndex(where: { $0.id == id }) { workspace.topics[index].archived = true }
            workspace.sessions.removeAll { $0.topicID == id && $0.status == .planned && $0.start > now() }
        }
    }
    func togglePin(_ id: String) {
        _ = change { workspace in
            guard let index = workspace.sessions.firstIndex(where: { $0.id == id }) else { return }
            workspace.sessions[index].pinned.toggle()
        }
    }
    func skip(_ id: String) {
        _ = change { workspace in
            guard let index = workspace.sessions.firstIndex(where: { $0.id == id }), workspace.sessions[index].status == .planned else { return }
            workspace.sessions[index].status = .skipped
            // Do not immediately recreate the declined slot; retry no earlier than tomorrow.
            if let t = workspace.topics.firstIndex(where: { $0.id == workspace.sessions[index].topicID }) {
                workspace.topics[t].nextReview = max(workspace.topics[t].nextReview, workspace.preferences.calendar.date(byAdding: .day, value: 1, to: workspace.preferences.calendar.startOfDay(for: max(now(), workspace.sessions[index].start)))!)
            }
        }
    }
    @discardableResult
    func review(_ id: String, rating: StudyRating, actualMinutes: Int) -> Bool {
        guard (5...180).contains(actualMinutes) else { errorMessage = "Die tatsächliche Lerndauer muss zwischen 5 und 180 Minuten liegen."; return false }
        return change { workspace in
            guard let index = workspace.sessions.firstIndex(where: { $0.id == id }), workspace.sessions[index].status == .planned,
                  let t = workspace.topics.firstIndex(where: { $0.id == workspace.sessions[index].topicID }) else { return }
            workspace.sessions[index].status = .completed
            workspace.sessions[index].rating = rating
            workspace.sessions[index].actualMinutes = actualMinutes
            workspace.sessions[index].reviewedAt = now()
            workspace.sessions[index].reason = "Von dir bewertet; die nächste Wiederholung wurde neu geplant."
            workspace.sessions[index].end = now()
            workspace.sessions[index].start = now().addingTimeInterval(-Double(actualMinutes) * 60)
            StudyReviewPolicy.apply(rating, to: &workspace.topics[t], at: now(), actualMinutes: actualMinutes, calendar: workspace.preferences.calendar)
        }
    }
    @discardableResult
    func moveSession(_ id: String, start: Date) -> Bool {
        guard let original = workspace.sessions.first(where: { $0.id == id && $0.status == .planned }), start >= now() else { errorMessage = "Bitte einen zukünftigen Lerntermin auswählen."; return false }
        let end = start.addingTimeInterval(Double(original.minutes) * 60)
        let calendar = workspace.preferences.calendar
        let used = workspace.sessions.filter { $0.id != id && $0.status != .skipped && calendar.isDate($0.start, inSameDayAs: start) }.reduce(0) { $0 + $1.minutes }
        guard used + original.minutes <= workspace.preferences.dailyLimitMinutes else { errorMessage = "Die Tagesgrenze für Lernen wäre überschritten."; return false }
        if let exam = workspace.topics.first(where: { $0.id == original.topicID })?.examDate, end > exam {
            errorMessage = "Der Lerntermin würde nach der Prüfung enden."; return false
        }
        var candidate = workspace
        candidate.sessions.removeAll { $0.id == id }
        let day = candidate.preferences.calendar.startOfDay(for: start)
        let base = StudyPlannerEngine.availability(events: candidate.events, preferences: candidate.preferences,
             horizon: DateInterval(start: day, end: candidate.preferences.calendar.date(byAdding: .day, value: 1, to: day)!))
        guard let window = base.windows.first(where: { $0.interval.start <= start && $0.interval.end >= end }),
              !candidate.sessions.contains(where: { $0.status != .skipped && StudyPlannerEngine.overlaps($0.interval, DateInterval(start: start.addingTimeInterval(-Double(candidate.preferences.breakMinutes) * 60), end: end.addingTimeInterval(Double(candidate.preferences.breakMinutes) * 60))) }) else {
            errorMessage = "Dieser Termin kollidiert mit Lernen, Pausen, Fahrtzeiten oder deiner Verfügbarkeit."; return false
        }
        return change { workspace in
            if let index = workspace.sessions.firstIndex(where: { $0.id == id }) {
                workspace.sessions[index].start = start; workspace.sessions[index].end = end
                workspace.sessions[index].pinned = true; workspace.sessions[index].location = window.location
                workspace.sessions[index].reason = "Von dir verschoben und fixiert."
            }
        }
    }
    @discardableResult
    func savePreferences(_ value: PlannerPreferences) -> Bool {
        guard value.dayStartMinute >= 0, value.dayEndMinute < 1440, value.dayEndMinute > value.dayStartMinute,
              (15...480).contains(value.dailyLimitMinutes), (5...120).contains(value.minimumBlockMinutes),
              (0...60).contains(value.breakMinutes), value.travelMinutes.values.allSatisfy({ (0...300).contains($0) }),
              value.dailyLimitMinutes >= value.minimumBlockMinutes, !value.weekdays.isEmpty else { errorMessage = "Bitte gültige Lernzeiten, mindestens einen Lerntag und Fahrtzeiten zwischen 0 und 300 Minuten wählen."; return false }
        return change { $0.preferences = value }
    }
    func importChanges(_ draft: CalendarImportDraft, overwriteLocal: Bool, removeMissing: Bool) {
        _ = change { workspace in
            if !workspace.importSources.contains(where: { $0.id == draft.sourceID }) {
                workspace.importSources.append(PlannerImportSource(id: draft.sourceID, name: draft.sourceName))
            }
            let incomingUIDs = Set(draft.events.compactMap(\.sourceUID))
            for incoming in draft.events {
                if let index = workspace.events.firstIndex(where: { $0.sourceID == draft.sourceID && $0.sourceUID == incoming.sourceUID }) {
                    guard !workspace.events[index].locallyModified || overwriteLocal else { continue }
                    var event = incoming; event.id = workspace.events[index].id
                    workspace.events[index] = event
                } else { workspace.events.append(incoming) }
            }
            // A parse with warnings is never treated as a complete authoritative source.
            if removeMissing && draft.warnings.isEmpty {
                for index in workspace.events.indices where workspace.events[index].sourceID == draft.sourceID && !incomingUIDs.contains(workspace.events[index].sourceUID ?? "") {
                    if !workspace.events[index].locallyModified || overwriteLocal { workspace.events[index].cancelled = true }
                }
            }
        }
    }
}
