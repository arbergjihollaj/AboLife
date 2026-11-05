import Foundation

enum AIScope: String, Codable, CaseIterable, Identifiable {
    case calendar, learning, finance, training, habits, news, review
    var id: String { rawValue }
    var title: String {
        switch self {
        case .review: return "Wochenreview-Notizen"
        case .calendar: return "Kalender · Termine, Lernblöcke und Fahrten"
        case .learning: return "Lernthemen & Sitzungen · 7 Tage"
        case .finance: return "Budget & Monatssummen"
        case .training: return "Training · letzte 7 Tage"
        case .habits: return "Gewohnheiten · letzte 7 Tage"
        case .news: return "Bereits geladene RSS-Schlagzeilen"
        }
    }
}
enum AIPurpose: String, Codable, CaseIterable, Identifiable {
    case daily, finance, learning, training, review, news
    var id: String { rawValue }
    var title: String {
        switch self {
        case .daily: return "Mein Tag"
        case .finance: return "Finanzen"
        case .learning: return "Lernen"
        case .training: return "Training & Gewohnheiten"
        case .review: return "Wochenreview"
        case .news: return "News"
        }
    }
    var scopes: Set<AIScope> {
        switch self {
        case .daily: return [.calendar, .learning, .training, .habits]
        case .finance: return [.finance]
        case .learning: return [.calendar, .learning]
        case .training: return [.training, .habits, .calendar]
        case .review: return [.calendar, .learning, .finance, .training, .habits, .review]
        case .news: return [.news]
        }
    }
    var suggestions: [String] {
        switch self {
        case .daily: return ["Was steht heute an?", "Was sollte ich heute priorisieren?"]
        case .finance: return ["Wie viel kann ich heute noch ausgeben?", "Wie hat sich mein Budget verändert?"]
        case .learning: return ["Welche Lernaufgaben haben Priorität?", "Schlage einen passenden Lernblock für morgen vor."]
        case .training: return ["Fasse mein Training der letzten Woche zusammen.", "Welche Gewohnheiten sind noch offen?"]
        case .review: return ["Erstelle einen Wochenrückblick auf Basis der freigegebenen Daten."]
        case .news: return ["Ordne die geladenen Schlagzeilen ein. Kennzeichne fehlende Artikelinhalte."]
        }
    }
}
struct AIContextSection: Codable, Equatable {
    var scope: AIScope
    var facts: [String]
}
struct AIContextSnapshot: Codable, Equatable {
    var purpose: AIPurpose
    var generatedAt: Date
    var timeZone: String
    var sections: [AIContextSection]
    var calendarInstruction: String {
        if sections.contains(where: { $0.scope == .calendar }) {
            return "Verwende für Kalenderfragen den aktuellen Kalenderkontext. Beziehe heute auf das dort angegebene Datum und die Kalenderzeitzone. Der aktuelle Kontext hat Vorrang vor früheren Chatantworten."
        }
        return "Der AboLife-Kalender ist für diese Anfrage nicht freigegeben. Sage bei einer Kalenderfrage, dass der Kalender hier nicht einsehbar ist. Behaupte nicht, dass der Kalender leer ist."
    }
    var json: String {
        let encoder = JSONEncoder(); encoder.dateEncodingStrategy = .iso8601; encoder.outputFormatting = [.sortedKeys]
        return (try? String(decoding: encoder.encode(self), as: UTF8.self)) ?? "{}"
    }
    func compact(calendarFacts: Int, otherFacts: Int) -> AIContextSnapshot {
        var snapshot = self
        snapshot.sections = sections.map { section in
            let limit = section.scope == .calendar ? calendarFacts : otherFacts
            let facts = section.facts.prefix(limit).map { fact in
                fact.count > 240 ? String(fact.prefix(240)) + " …" : fact
            }
            let notice = facts.count < section.facts.count ? ["Weitere Einträge wegen der Kontextgrenze ausgelassen."] : []
            return AIContextSection(scope: section.scope, facts: facts + notice)
        }
        return snapshot
    }
}

struct AIContextBuilder {
    let database: AppDatabase
    func make(purpose: AIPurpose, granted: Set<AIScope>, news: [NewsArticle] = [], now: Date = Date()) throws -> AIContextSnapshot {
        let allowed = granted.intersection(purpose.scopes)
        let calendar = Calendar.current
        let past = DateInterval(start: calendar.date(byAdding: .day, value: -6, to: calendar.startOfDay(for: now))!, end: calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: now))!)
        let iso = ISO8601DateFormatter()
        var sections: [AIContextSection] = []
        var workspace: CalendarWorkspace?
        if !allowed.intersection([.calendar, .learning]).isEmpty { workspace = try CalendarRepository(database: database).load() }
        let plannerCalendar = workspace?.preferences.calendar ?? calendar
        let dayStart = plannerCalendar.startOfDay(for: now)
        let tomorrow = plannerCalendar.date(byAdding: .day, value: 1, to: dayStart)!
        let future = DateInterval(start: dayStart, end: plannerCalendar.date(byAdding: .day, value: 7, to: dayStart)!)
        let plannerISO = ISO8601DateFormatter()
        plannerISO.timeZone = plannerCalendar.timeZone
        let availability = workspace.flatMap { workspace in
            allowed.contains(.calendar) ? StudyPlannerEngine.availability(events: workspace.events, preferences: workspace.preferences, horizon: future) : nil
        }
        if allowed.contains(.calendar), let workspace {
            let events = workspace.events.flatMap { $0.occurrences(in: future) }.map {
                (start: $0.start, end: $0.end, label: "\($0.title) (\($0.kind.title))")
            }
            let blocks = workspace.sessions.filter { $0.status == .planned && $0.start < future.end && $0.end > future.start && $0.end > $0.start }.map {
                (start: $0.start, end: $0.end, label: "Geplanter Lernblock")
            }
            let journeys = (availability?.journeys ?? []).map {
                (start: $0.start, end: $0.end, label: "\($0.title) (\($0.estimatedReturn ? "geschätzt" : "geplant"))")
            }
            let entries = (events + blocks + journeys).sorted { $0.start < $1.start }
            let todayCount = entries.filter { $0.start < tomorrow }.count
            let date = PlannerDate.dayKey(now, calendar: plannerCalendar)
            var facts = ["Heute (\(date), \(plannerCalendar.timeZone.identifier)): \(todayCount) Kalendereinträge."]
            facts += entries.prefix(16).map { entry in
                let day = entry.start < tomorrow ? "Heute" : PlannerDate.dayKey(entry.start, calendar: plannerCalendar)
                return "\(day) · \(plannerISO.string(from: entry.start)) bis \(plannerISO.string(from: entry.end)): \(entry.label)"
            }
            if entries.count > 16 {
                facts.append("Vorschau enthält 16 von \(entries.count) Kalendereinträgen. Heute sind \(min(16, todayCount)) von \(todayCount) Einträgen enthalten.")
            }
            sections.append(.init(scope: .calendar, facts: facts))
        }
        if allowed.contains(.learning), let workspace {
            var facts = workspace.topics.filter { !$0.archived }.sorted { $0.nextReview < $1.nextReview }.prefix(12).map {
                "Thema-ID \($0.id): \($0.course) / \($0.title), fällig \(plannerISO.string(from: $0.nextReview)), geschätzt \($0.estimatedMinutes) Minuten, Wiederholungen \($0.reviewCount)"
            }
            let upcoming = workspace.sessions.filter { $0.start < future.end && $0.end > future.start && $0.status == .planned }.sorted { $0.start < $1.start }
            facts += upcoming.prefix(10).map { "Geplant: \(plannerISO.string(from: $0.start)) bis \(plannerISO.string(from: $0.end)), Thema \($0.topicID), fixiert \($0.pinned)" }
            let completed = workspace.sessions.filter { $0.start >= past.start && $0.start < past.end && $0.status == .completed }
            facts.append("Letzte 7 Tage: \(completed.count) erledigte Lerneinheiten, \(completed.reduce(0) { $0 + ($1.actualMinutes ?? $1.minutes) }) Minuten.")
            if let availability {
                let free = availability.windows.flatMap { window in
                    workspace.sessions.filter { $0.status == .planned }.reduce([window]) { windows, session in windows.flatMap { StudyPlannerEngine.subtract(session.interval, from: [$0]) } }
                }.compactMap { window -> StudyFreeWindow? in
                    let start = max(now, window.interval.start)
                    guard window.interval.end.timeIntervalSince(start) >= Double(workspace.preferences.minimumBlockMinutes * 60) else { return nil }
                    return StudyFreeWindow(interval: DateInterval(start: start, end: window.interval.end), location: window.location)
                }
                facts += free.prefix(10).map { "Freies Lernfenster: \(plannerISO.string(from: $0.interval.start)) bis \(plannerISO.string(from: $0.interval.end)) in \($0.location)." }
            } else {
                facts.append("Freie Zeitfenster sind nicht freigegeben. Dafür wird zusätzlich die Termine-Freigabe benötigt.")
            }
            sections.append(.init(scope: .learning, facts: facts))
        }
        if allowed.contains(.finance) {
            let repository = FinanceRepository(database: database)
            let settings = try SettingsRepository(database: database).loadSettings()
            let month = DateIntervals.month(containing: now, calendar: calendar)
            let entries = try repository.fetch(in: month)
            let spent = FinanceRepository.expenseTotal(entries)
            let today = try repository.fetch(in: DateIntervals.day(containing: now, calendar: calendar))
            let todaySpent = FinanceRepository.expenseTotal(today)
            let remaining = FinanceStore.dailyBudgetRemaining(spent: spent, budget: settings.monthlyBudget, date: now, calendar: calendar, spentToday: todaySpent)
            let previousDate = calendar.date(byAdding: .month, value: -1, to: now)!
            let previous = try repository.monthSpending(for: previousDate, calendar: calendar)
            func money(_ amount: Double) -> String { String(format: "%.2f %@", amount, settings.defaultCurrency) }
            var facts = ["Deterministisch berechnet, Bezugsdatum \(iso.string(from: now)).",
                "Monatsbudget: \(money(settings.monthlyBudget)); Ausgaben aktueller Monat: \(money(spent)); Einnahmen: \(money(FinanceRepository.incomeTotal(entries))).",
                "Restbudget Monat: \(money(max(settings.monthlyBudget - spent, 0))); heute ausgegeben: \(money(todaySpent)); heute noch verfügbar: \(money(remaining)).",
                "Vorheriger vollständiger Monat, nicht gleicher Tageszeitraum: \(money(previous)) Ausgaben."]
            let groups = Dictionary(grouping: entries.filter { $0.amount > 0 }, by: \.category)
            facts += groups.keys.sorted().prefix(10).map { "Kategorie \($0): \(money(FinanceRepository.expenseTotal(groups[$0]!)))." }
            sections.append(.init(scope: .finance, facts: facts))
        }
        if allowed.contains(.training) {
            let workouts = try WorkoutRepository(database: database).fetch(in: past)
            let done = workouts.filter { $0.status == "done" }
            let facts = ["Letzte 7 Tage: \(done.count) abgeschlossene Einheiten, \(done.reduce(0) { $0 + $1.durationMin }) Minuten."] + workouts.prefix(10).map { "\(iso.string(from: $0.occurredAt)): \($0.workoutType), \($0.durationMin) Minuten, Status \($0.status)." }
            sections.append(.init(scope: .training, facts: facts))
        }
        if allowed.contains(.habits) {
            let repository = HabitRepository(database: database)
            let definitions = FixedHabit.defaults.filter { !$0.isDerived }
            let today = try repository.fetch(for: DateIntervals.dayKey(for: now, calendar: calendar))
            let summary = try repository.weeklySummary(in: past, habitKeys: definitions.map(\.key), days: 7, calendar: calendar)
            let facts = definitions.map { habit -> String in
                let entry = today.first { $0.habitKey == habit.key }
                let value = entry?.value ?? ((entry?.isCompleted ?? false) ? habit.targetValue : 0)
                return "Heute \(habit.title): \(habit.displayValue(value)); Ziel erreicht: \(value >= habit.targetValue)."
            } + ["Letzte 7 Tage: \(summary.completed) erledigte Gewohnheitstage von \(summary.total). Abgeleitetes Training ist separat freizugeben."]
            sections.append(.init(scope: .habits, facts: facts))
        }
        if allowed.contains(.review) {
            let start = DateIntervals.week(containing: now, weekStartsOn: 2, calendar: calendar).start
            let key = DateIntervals.dayKey(for: start, calendar: calendar)
            let review = try WeeklyReviewRepository(database: database).fetch(weekStartDate: key)
            let facts = review.map { ["Aktuelle Wochenreview: Erfolge: \($0.winsText.prefix(1500)); Schwierigkeiten: \($0.challengesText.prefix(1500)); Fokus: \($0.nextWeekFocusText.prefix(1500))."] } ?? ["Noch keine Wochenreview gespeichert."]
            sections.append(.init(scope: .review, facts: facts))
        }
        if allowed.contains(.news) {
            let facts = ["Nur bereits geladene RSS-Schlagzeilen. Artikelvolltexte und externe Fakten wurden nicht abgerufen."] + news.prefix(12).map { "\($0.source): \($0.title) — \($0.url.absoluteString)" }
            sections.append(.init(scope: .news, facts: facts))
        }
        return AIContextSnapshot(purpose: purpose, generatedAt: now, timeZone: plannerCalendar.timeZone.identifier, sections: sections)
    }
}
