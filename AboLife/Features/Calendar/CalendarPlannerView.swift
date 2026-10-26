import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct CalendarPlannerView: View {
    @StateObject private var store: CalendarPlannerStore
    @State private var selectedDay = Date()
    @State private var tab = "Woche"
    @State private var editingEvent: PlannerEvent?
    @State private var editingTopic: StudyTopic?
    @State private var reviewingSession: StudySession?
    @State private var movingSession: StudySession?
    @State private var showPreferences = false
    @State private var importDraft: CalendarImportDraft?
    @State private var sourceID = ""
    @State private var sourceName = "Uni-Stundenplan"
    @State private var showAllIssues = false

    init(database: AppDatabase?) { _store = StateObject(wrappedValue: CalendarPlannerStore(database: database)) }
    private var calendar: Calendar { store.workspace.preferences.calendar }
    private var weekStart: Date { calendar.dateInterval(of: .weekOfYear, for: selectedDay)!.start }
    private var weekEnd: Date { calendar.date(byAdding: .day, value: 7, to: weekStart)! }
    private var occurrences: [PlannerOccurrence] { store.workspace.events.flatMap { $0.occurrences(in: DateInterval(start: weekStart, end: weekEnd)) } }
    private var selectedEvents: [PlannerOccurrence] { occurrences.filter { calendar.isDate($0.start, inSameDayAs: selectedDay) || ($0.start < calendar.startOfDay(for: selectedDay) && $0.end > calendar.startOfDay(for: selectedDay)) }.sorted { $0.start < $1.start } }
    private var selectedJourneys: [PlannerJourney] {
        let day = calendar.startOfDay(for: selectedDay)
        let horizon = DateInterval(start: day, end: calendar.date(byAdding: .day, value: 1, to: day)!)
        return StudyPlannerEngine.availability(events: store.workspace.events, preferences: store.workspace.preferences, horizon: horizon).journeys
    }
    private var selectedSessions: [StudySession] { store.workspace.sessions.filter { calendar.isDate($0.start, inSameDayAs: selectedDay) } }

    var body: some View {
        ZStack {
            AboLifePremiumBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    header
                    Picker("Ansicht", selection: $tab) {
                        Text("Woche").tag("Woche")
                        Text("Lernthemen").tag("Lernthemen")
                        Text("Stundenplan").tag("Stundenplan")
                    }.pickerStyle(.segmented).labelsHidden().frame(maxWidth: 440)
                    if let error = store.errorMessage { Label(error, systemImage: "exclamationmark.circle").foregroundStyle(AboLifeColors.habits).textSelection(.enabled) }
                    if !store.issues.isEmpty { issueCard }
                    switch tab {
                    case "Lernthemen": topics
                    case "Stundenplan": timetable
                    default: weekStrip; dayAgenda
                    }
                }
                .padding(22)
            }
        }
        .preferredColorScheme(.dark)
        .sheet(item: $editingEvent) { PlannerEventEditor(event: $0, store: store) }
        .sheet(item: $editingTopic) { PlannerTopicEditor(topic: $0, store: store) }
        .sheet(item: $reviewingSession) { PlannerReviewSheet(session: $0, store: store) }
        .sheet(item: $movingSession) { PlannerMoveSheet(session: $0, store: store) }
        .sheet(isPresented: $showPreferences) { PlannerPreferencesEditor(preferences: store.workspace.preferences, store: store) }
        .sheet(item: $importDraft) { draft in
            PlannerImportPreview(draft: draft, store: store)
                .onDisappear {
                    if store.workspace.importSources.contains(where: { $0.id == draft.sourceID }) { sourceID = draft.sourceID }
                }
        }
        .onAppear { store.reload() }
        .onReceive(Timer.publish(every: 60, on: .main, in: .common).autoconnect()) { _ in store.reload() }
        .environment(\.timeZone, calendar.timeZone)
        .environment(\.locale, Locale(identifier: "de_DE"))
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Kalender").font(AboLifeTypography.dashboardTitle).foregroundStyle(AboLifeColors.primaryText)
                Text("Uni, Training und Lernen · nächste 14 Tage automatisch planen")
                    .font(AboLifeTypography.body).foregroundStyle(AboLifeColors.secondaryText)
            }
            Spacer()
            Button { showPreferences = true } label: { Label("Planungszeiten", systemImage: "slider.horizontal.3") }.buttonStyle(.bordered)
            Button { addEvent() } label: { Label("Termin", systemImage: "plus") }.buttonStyle(.borderedProminent).tint(AboLifeColors.review)
        }
    }
    private var issueCard: some View {
        AboLifeCard {
            VStack(alignment: .leading, spacing: 8) {
                Label("\(store.issues.count) Hinweise zur Planung", systemImage: "exclamationmark.circle").font(AboLifeTypography.cardTitle).foregroundStyle(AboLifeColors.habits)
                ForEach(Array(store.issues.prefix(showAllIssues ? store.issues.count : 2))) { issue in
                    Text(issue.message).font(AboLifeTypography.caption).foregroundStyle(AboLifeColors.secondaryText).fixedSize(horizontal: false, vertical: true)
                }
                if store.issues.count > 2 { Button(showAllIssues ? "Weniger anzeigen" : "Alle Hinweise") { showAllIssues.toggle() }.buttonStyle(.plain).foregroundStyle(AboLifeColors.review) }
            }
        }
    }
    private var weekStrip: some View {
        VStack(spacing: 12) {
            HStack {
                Button { selectedDay = calendar.date(byAdding: .day, value: -7, to: selectedDay)! } label: { Image(systemName: "chevron.left") }.help("Vorherige Woche")
                Text("\(weekStart.formatted(.dateTime.locale(Locale(identifier: "de_DE")).day().month())) – \(calendar.date(byAdding: .day, value: -1, to: weekEnd)!.formatted(.dateTime.locale(Locale(identifier: "de_DE")).day().month().year()))").font(AboLifeTypography.cardTitle).foregroundStyle(AboLifeColors.primaryText)
                Button { selectedDay = calendar.date(byAdding: .day, value: 7, to: selectedDay)! } label: { Image(systemName: "chevron.right") }.help("Nächste Woche")
                Spacer()
                Button("Heute") { selectedDay = Date() }
            }.buttonStyle(.bordered)
            HStack(spacing: 8) {
                ForEach(0..<7, id: \.self) { offset in
                    let day = calendar.date(byAdding: .day, value: offset, to: weekStart)!
                    let selected = calendar.isDate(day, inSameDayAs: selectedDay)
                    Button { selectedDay = day } label: {
                        VStack(spacing: 6) {
                            Text(day.formatted(.dateTime.locale(Locale(identifier: "de_DE")).weekday(.abbreviated))).font(AboLifeTypography.micro)
                            Text(day.formatted(.dateTime.locale(Locale(identifier: "de_DE")).day())).font(.system(size: 21, weight: .semibold, design: .rounded))
                            let fixed = occurrences.filter { calendar.isDate($0.start, inSameDayAs: day) }.count
                            let learning = store.workspace.sessions.filter { $0.status == .planned && calendar.isDate($0.start, inSameDayAs: day) }.count
                            HStack(spacing: 5) {
                                if fixed > 0 { Circle().fill(AboLifeColors.review).frame(width: 5, height: 5) }
                                if learning > 0 { Circle().fill(AboLifeColors.nutrition).frame(width: 5, height: 5) }
                            }.frame(height: 6)
                        }
                        .foregroundStyle(selected ? AboLifeColors.primaryText : AboLifeColors.secondaryText)
                        .frame(maxWidth: .infinity).padding(.vertical, 12)
                        .background(selected ? AboLifeColors.review.opacity(0.22) : AboLifeColors.elevatedCardBackground, in: RoundedRectangle(cornerRadius: 12))
                    }.buttonStyle(.plain).accessibilityLabel(day.formatted(date: .complete, time: .omitted))
                }
            }
        }
    }
    private var dayAgenda: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(selectedDay.formatted(.dateTime.locale(Locale(identifier: "de_DE")).weekday(.wide).day().month())).font(AboLifeTypography.sectionTitle).foregroundStyle(AboLifeColors.primaryText)
                Spacer()
                Button("Lernthema hinzufügen") { addTopic() }.buttonStyle(.bordered)
            }
            if selectedEvents.isEmpty && selectedSessions.isEmpty && selectedJourneys.isEmpty {
                AboLifeCard {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Dein Tag ist noch frei", systemImage: "calendar").font(AboLifeTypography.cardTitle).foregroundStyle(AboLifeColors.primaryText)
                        Text("Trage deinen Stundenplan und Trainingszeiten ein. Füge dann Lernthemen hinzu – die App sucht passende freie Zeitfenster.")
                            .font(AboLifeTypography.body).foregroundStyle(AboLifeColors.secondaryText)
                    }
                }
            }
            // One chronological agenda for fixed events and learning.
            let times = Array(Set(selectedEvents.map(\.start) + selectedSessions.map(\.start) + selectedJourneys.map(\.start))).sorted()
            ForEach(times, id: \.self) { time in
                ForEach(selectedJourneys.filter { $0.start == time }) { journey in journeyRow(journey) }
                ForEach(selectedEvents.filter { $0.start == time }) { occurrence in eventRow(occurrence) }
                ForEach(selectedSessions.filter { $0.start == time }) { session in sessionRow(session) }
            }
            Text("Blau: feste Termine · Grün: Lernen. Fahrten werden automatisch berechnet. In Uni-Pausen bleibst du vor Ort.")
                .font(AboLifeTypography.micro).foregroundStyle(AboLifeColors.secondaryText)
        }
    }
    private func journeyRow(_ journey: PlannerJourney) -> some View {
        HStack(alignment: .top, spacing: 16) {
            timeLabel(journey.start, journey.end)
            Image(systemName: "arrow.triangle.turn.up.right.diamond").foregroundStyle(AboLifeColors.secondaryText)
            VStack(alignment: .leading, spacing: 4) {
                Text(journey.title).font(AboLifeTypography.body).foregroundStyle(AboLifeColors.primaryText)
                Text("Automatisch · \(Int(journey.end.timeIntervalSince(journey.start) / 60)) Min.\(journey.estimatedReturn ? " · Rückweg wie Hinfahrt" : "")")
                    .font(AboLifeTypography.micro).foregroundStyle(AboLifeColors.secondaryText)
            }
            Spacer()
        }.padding(.horizontal, 16).padding(.vertical, 8)
    }
    private func eventRow(_ occurrence: PlannerOccurrence) -> some View {
        AboLifeCard {
            HStack(alignment: .top, spacing: 16) {
                timeLabel(occurrence.start, occurrence.end)
                VStack(alignment: .leading, spacing: 5) {
                    Text(occurrence.title).font(AboLifeTypography.cardTitle).foregroundStyle(AboLifeColors.primaryText)
                    Text("\(occurrence.kind.title) · \(PlannerDate.locationName(occurrence.location))").font(AboLifeTypography.caption).foregroundStyle(AboLifeColors.review)
                }
                Spacer()
                Menu {
                    Button("Bearbeiten (ganze Serie)") { editingEvent = store.workspace.events.first { $0.id == occurrence.eventID } }
                    Button("Diesen Termin absagen", role: .destructive) { store.cancel(occurrence) }
                    Button("Termin / ganze Serie entfernen", role: .destructive) { store.removeEvent(occurrence.eventID) }
                } label: { Image(systemName: "ellipsis") }.menuStyle(.borderlessButton).frame(width: 24)
            }
        }
    }
    private func sessionRow(_ session: StudySession) -> some View {
        let topic = store.workspace.topics.first { $0.id == session.topicID }
        return AboLifeCard {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top, spacing: 16) {
                    timeLabel(session.start, session.end)
                    VStack(alignment: .leading, spacing: 5) {
                        Text(topic.map { "\($0.course) · \($0.title)" } ?? "Lerneinheit").font(AboLifeTypography.cardTitle).foregroundStyle(AboLifeColors.primaryText)
                        Text(sessionLabel(session)).font(AboLifeTypography.caption).foregroundStyle(AboLifeColors.nutrition)
                        Text(session.reason).font(AboLifeTypography.micro).foregroundStyle(AboLifeColors.secondaryText).fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer()
                    if session.status == .planned {
                        Button { store.togglePin(session.id) } label: { Image(systemName: session.pinned ? "lock.fill" : "lock.open") }.help(session.pinned ? "Fixierung lösen" : "Diesen Vorschlag fixieren")
                    }
                }
                if session.status == .planned {
                    HStack {
                        Button("Erledigt / bewerten") { reviewingSession = session }.buttonStyle(.borderedProminent).tint(AboLifeColors.nutrition)
                        Button("Verschieben") { movingSession = session }.buttonStyle(.bordered)
                        Button("Auslassen") { store.skip(session.id) }.buttonStyle(.bordered)
                    }.controlSize(.small)
                }
            }
        }
    }
    private func sessionLabel(_ s: StudySession) -> String {
        switch s.status {
        case .completed: return "Erledigt · \(s.rating?.title ?? "") · \(s.actualMinutes ?? s.minutes) Min."
        case .skipped: return "Ausgelassen · wird erneut eingeplant"
        case .planned: return "\(s.end < Date() ? "Verpasst" : s.pinned ? "Fixiert" : "Lernvorschlag") · \(PlannerDate.locationName(s.location))"
        }
    }
    private func timeLabel(_ start: Date, _ end: Date) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(start.formatted(date: .omitted, time: .shortened)).font(AboLifeTypography.cardTitle)
            Text(end.formatted(date: .omitted, time: .shortened)).font(AboLifeTypography.micro)
        }.monospacedDigit().foregroundStyle(AboLifeColors.secondaryText).frame(width: 48, alignment: .leading)
    }
    private var topics: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Was möchtest du wiederholen?").font(AboLifeTypography.sectionTitle).foregroundStyle(AboLifeColors.primaryText)
                Spacer()
                Button("Lernthema hinzufügen") { addTopic() }.buttonStyle(.borderedProminent).tint(AboLifeColors.nutrition)
            }
            Text("Nach jeder Einheit bewertest du den Abruf. Daraus werden die nächste Fälligkeit und aus deiner tatsächlichen Dauer passendere Zeitblöcke abgeleitet. Die Startregeln sind eine Lernhilfe, kein gemessenes Gedächtnismodell.")
                .font(AboLifeTypography.caption).foregroundStyle(AboLifeColors.secondaryText)
            if store.workspace.topics.allSatisfy(\.archived) {
                Text("Noch keine Lernthemen. Beginne mit einem Fach und einem konkreten Thema.").foregroundStyle(AboLifeColors.secondaryText).padding(.vertical)
            }
            ForEach(store.workspace.topics.filter { !$0.archived }.sorted { $0.nextReview < $1.nextReview }) { topic in
                AboLifeCard {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(topic.title).font(AboLifeTypography.cardTitle).foregroundStyle(AboLifeColors.primaryText)
                            Text("\(topic.course) · ca. \(topic.estimatedMinutes) Min. · \(topic.reviewCount) Wiederholungen").font(AboLifeTypography.caption).foregroundStyle(AboLifeColors.secondaryText)
                            Text("Fällig: \(topic.nextReview.formatted(date: .abbreviated, time: .shortened))").font(AboLifeTypography.caption).foregroundStyle(AboLifeColors.nutrition)
                            if let exam = topic.examDate { Text("Prüfung: \(exam.formatted(date: .abbreviated, time: .omitted))").font(AboLifeTypography.micro).foregroundStyle(AboLifeColors.review) }
                            if let reason = store.unplaced[topic.id] { Label(reason, systemImage: "clock.badge.exclamationmark").font(AboLifeTypography.caption).foregroundStyle(AboLifeColors.habits) }
                        }
                        Spacer()
                        Button("Bearbeiten") { editingTopic = topic }.buttonStyle(.bordered)
                        Button { store.archiveTopic(topic.id) } label: { Image(systemName: "archivebox") }.help("Thema archivieren")
                    }
                }
            }
        }
    }
    private var timetable: some View {
        VStack(alignment: .leading, spacing: 14) {
            AboLifeCard {
                VStack(alignment: .leading, spacing: 12) {
                    Label("Stundenplan importieren", systemImage: "square.and.arrow.down").font(AboLifeTypography.sectionTitle).foregroundStyle(AboLifeColors.primaryText)
                    Text("Importiere eine lokale .ics-Datei. Du prüfst alle Termine vor der Übernahme. Wähle beim erneuten Import dieselbe Quelle, damit keine Duplikate entstehen.").font(AboLifeTypography.caption).foregroundStyle(AboLifeColors.secondaryText)
                    HStack {
                        Picker("Quelle", selection: $sourceID) {
                            Text("Neue Quelle").tag("")
                            ForEach(store.workspace.importSources) { Text($0.name).tag($0.id) }
                        }.frame(maxWidth: 300)
                        if sourceID.isEmpty { TextField("Name, z. B. Wintersemester", text: $sourceName).textFieldStyle(.roundedBorder) }
                        Button("ICS-Datei wählen") { chooseICS() }.buttonStyle(.borderedProminent).tint(AboLifeColors.review)
                    }
                }
            }
            HStack {
                Text("Feste Termine & Serien").font(AboLifeTypography.sectionTitle).foregroundStyle(AboLifeColors.primaryText)
                Spacer()
                Button("Termin hinzufügen") { addEvent() }.buttonStyle(.bordered)
            }
            ForEach(store.workspace.events.filter { !$0.cancelled }.sorted { $0.start < $1.start }) { event in
                AboLifeCard {
                    HStack {
                        VStack(alignment: .leading, spacing: 5) {
                            Text(event.title).font(AboLifeTypography.cardTitle).foregroundStyle(AboLifeColors.primaryText)
                            Text("\(event.kind.title) · \(event.weekly ? "Wöchentlich" : "Einmalig") · \(event.start.formatted(date: .abbreviated, time: .shortened)) · \(PlannerDate.locationName(event.location))").font(AboLifeTypography.caption).foregroundStyle(AboLifeColors.secondaryText)
                            if event.locallyModified { Text("Lokal angepasst · beim Import geschützt").font(AboLifeTypography.micro).foregroundStyle(AboLifeColors.review) }
                            if !event.excludedDays.isEmpty { Text("\(event.excludedDays.count) einzelne Termine abgesagt").font(AboLifeTypography.micro).foregroundStyle(AboLifeColors.secondaryText) }
                        }
                        Spacer()
                        Button("Bearbeiten") { editingEvent = event }.buttonStyle(.bordered)
                        Button { store.removeEvent(event.id) } label: { Image(systemName: "trash") }.help("Termin oder Serie entfernen")
                    }
                }
            }
        }
    }
    private func addEvent() {
        let start = PlannerDate.atMinute(9 * 60, on: selectedDay, calendar: calendar)
        editingEvent = PlannerEvent(title: "", kind: .university, start: start, end: start.addingTimeInterval(90 * 60), location: "university", timeZoneID: calendar.timeZone.identifier)
    }
    private func addTopic() { editingTopic = StudyTopic(title: "", course: "") }
    private func chooseICS() {
        let panel = NSOpenPanel(); panel.allowedContentTypes = [UTType(filenameExtension: "ics") ?? .data]
        panel.allowsMultipleSelection = false; panel.canChooseDirectories = false
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            guard (try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0) <= 5_000_000 else { throw ICSImportError.tooLarge }
            let name = sourceID.isEmpty ? sourceName.trimmingCharacters(in: .whitespacesAndNewlines) : store.workspace.importSources.first { $0.id == sourceID }?.name ?? sourceName
            guard !name.isEmpty else { store.errorMessage = "Bitte einen Namen für die Importquelle eintragen."; return }
            importDraft = try ICSImporter.parse(data: Data(contentsOf: url), sourceID: sourceID.isEmpty ? UUID().uuidString : sourceID, sourceName: name, fallbackZone: calendar.timeZone)
        } catch { store.errorMessage = error.localizedDescription }
    }
}

struct CalendarPlannerView_Previews: PreviewProvider {
    static var previews: some View { CalendarPlannerView(database: nil).frame(width: 1000, height: 760) }
}
