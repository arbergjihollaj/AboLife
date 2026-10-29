import SwiftUI

private struct PlannerEditorFrame<Content: View>: View {
    let title: String
    let content: Content
    init(_ title: String, @ViewBuilder content: () -> Content) { self.title = title; self.content = content() }
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(title).font(AboLifeTypography.sectionTitle).foregroundStyle(AboLifeColors.primaryText)
            content
        }
        .padding(22).frame(width: 580)
        .background(AboLifeColors.premiumBackgroundGradient).preferredColorScheme(.dark)
    }
}

struct PlannerEventEditor: View {
    @Environment(\.dismiss) private var dismiss
    @State var event: PlannerEvent
    @ObservedObject var store: CalendarPlannerStore
    @State private var hasEnd = false
    @State private var semesterEnd = Date().addingTimeInterval(120 * 86400)
    private let locations = ["home", "university", "gym"]
    var body: some View {
        PlannerEditorFrame("Termin & Stundenplan") {
            Form {
                TextField("Titel", text: $event.title)
                Picker("Art", selection: $event.kind) { ForEach(PlannerEventKind.allCases) { Text($0.title).tag($0) } }
                DatePicker("Beginn", selection: $event.start)
                DatePicker("Ende", selection: $event.end)
                Picker("Ort", selection: Binding(get: { locations.contains(event.location) ? event.location : "custom" }, set: { event.location = $0 == "custom" ? "Anderer Ort" : $0 })) {
                    ForEach(locations, id: \.self) { Text(PlannerDate.locationName($0)).tag($0) }
                    Text("Anderer Ort").tag("custom")
                }
                if !locations.contains(event.location) { TextField("Bezeichnung des Ortes", text: $event.location) }
                Toggle("Wöchentlich wiederholen", isOn: $event.weekly)
                if event.weekly {
                    Text("Die Uhrzeiten gelten in \(event.timeZoneID). Änderungen betreffen die ganze Serie.").font(.caption).foregroundStyle(.secondary)
                    HStack {
                        ForEach(0..<7, id: \.self) { offset in
                            let weekday = offset == 6 ? 1 : offset + 2
                            Toggle(store.workspace.preferences.calendar.veryShortStandaloneWeekdaySymbols[weekday - 1], isOn: weekdayBinding(weekday)).toggleStyle(.button)
                        }
                    }
                    Toggle("Bis zum Semesterende", isOn: $hasEnd)
                    if hasEnd { DatePicker("Letzter Tag", selection: $semesterEnd, displayedComponents: .date) }
                }
            }.formStyle(.grouped).frame(height: event.weekly ? 400 : 270)
            if let error = store.errorMessage { Text(error).font(.caption).foregroundStyle(AboLifeColors.habits) }
            HStack {
                Button("Abbrechen") { dismiss() }.keyboardShortcut(.cancelAction)
                Spacer()
                Button("Speichern") { save() }.buttonStyle(.borderedProminent).tint(AboLifeColors.review).keyboardShortcut(.defaultAction)
            }
        }
        .onAppear {
            hasEnd = event.repeatUntil != nil
            semesterEnd = event.repeatUntil ?? semesterEnd
        }
        .onChange(of: event.kind) { _, kind in event.location = kind.suggestedLocation }
    }
    private func weekdayBinding(_ weekday: Int) -> Binding<Bool> {
        Binding(get: {
            let values = event.repeatWeekdays.isEmpty ? Set([store.workspace.preferences.calendar.component(.weekday, from: event.start)]) : event.repeatWeekdays
            return values.contains(weekday)
        }, set: { enabled in
            if event.repeatWeekdays.isEmpty { event.repeatWeekdays = [store.workspace.preferences.calendar.component(.weekday, from: event.start)] }
            if enabled { event.repeatWeekdays.insert(weekday) }
            else if event.repeatWeekdays.count > 1 { event.repeatWeekdays.remove(weekday) }
        })
    }
    private func save() {
        var value = event
        value.title = value.title.trimmingCharacters(in: .whitespacesAndNewlines)
        value.location = PlannerDate.locationID(value.location)
        if value.location.isEmpty { value.location = "home" }
        if value.weekly && hasEnd {
            var calendar = store.workspace.preferences.calendar
            calendar.timeZone = TimeZone(identifier: value.timeZoneID) ?? calendar.timeZone
            value.repeatUntil = calendar.date(byAdding: .second, value: -1, to: calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: semesterEnd))!)
            guard value.repeatUntil! >= value.start else { store.errorMessage = "Das Semesterende muss nach dem ersten Termin liegen."; return }
        } else { value.repeatUntil = nil }
        if !value.weekly { value.repeatWeekdays = []; value.recurrenceCount = nil }
        if store.saveEvent(value) { dismiss() }
    }
}

struct PlannerTopicEditor: View {
    @Environment(\.dismiss) private var dismiss
    @State var topic: StudyTopic
    @ObservedObject var store: CalendarPlannerStore
    @State private var hasExam = false
    @State private var exam = Date().addingTimeInterval(60 * 86400)
    var body: some View {
        PlannerEditorFrame("Lernthema") {
            Form {
                TextField("Fach", text: $topic.course)
                TextField("Konkretes Thema", text: $topic.title)
                Stepper("Start-Schätzwert: \(topic.durationMinutes) Minuten", value: $topic.durationMinutes, in: 5...180, step: 5)
                DatePicker("Nächste Wiederholung ab", selection: $topic.nextReview)
                Toggle("Prüfungstermin berücksichtigen", isOn: $hasExam)
                if hasExam { DatePicker("Prüfung", selection: $exam, displayedComponents: .date) }
            }.formStyle(.grouped).frame(height: 270)
            Text("Beginne mit einem überschaubaren Thema. Nach Bewertungen passt sich die Fälligkeit an; erledigte Einheiten helfen, die benötigte Dauer besser einzuschätzen.").font(.caption).foregroundStyle(AboLifeColors.secondaryText)
            if let error = store.errorMessage { Text(error).font(.caption).foregroundStyle(AboLifeColors.habits) }
            HStack {
                Button("Abbrechen") { dismiss() }.keyboardShortcut(.cancelAction)
                Spacer()
                Button("Speichern & planen") {
                    var value = topic
                    value.examDate = hasExam ? store.workspace.preferences.calendar.date(byAdding: .second, value: -1, to: store.workspace.preferences.calendar.date(byAdding: .day, value: 1, to: store.workspace.preferences.calendar.startOfDay(for: exam))!) : nil
                    if store.saveTopic(value) { dismiss() }
                }.buttonStyle(.borderedProminent).tint(AboLifeColors.accentGreen).keyboardShortcut(.defaultAction)
            }
        }.onAppear { hasExam = topic.examDate != nil; exam = topic.examDate ?? exam }
    }
}

struct PlannerReviewSheet: View {
    @Environment(\.dismiss) private var dismiss
    let session: StudySession
    @ObservedObject var store: CalendarPlannerStore
    @State private var rating: StudyRating = .good
    @State private var minutes = 25
    private var automaticPhase: ModuleStudyPhase? { store.workspace.topics.first { $0.id == session.topicID }?.automaticTask?.phase }
    var body: some View {
        PlannerEditorFrame(automaticPhase != nil ? "Lernphase abschließen" : "Wiederholung abschließen") {
            Text(automaticPhase == .preparation ? "Wie gut fühlst du dich auf die Veranstaltung vorbereitet?" : "Wie gut konntest du den Stoff bearbeiten bzw. aus dem Gedächtnis abrufen?").foregroundStyle(AboLifeColors.primaryText)
            Picker("Abruf", selection: $rating) { ForEach(StudyRating.allCases) { Text(automaticPhase == .preparation && $0 == .again ? "Noch unklar" : $0.title).tag($0) } }.pickerStyle(.segmented)
            Text(automaticPhase != nil ? "Deine Rückmeldung wird gespeichert. Die tatsächliche Dauer hilft bei weiteren Phasen dieses Moduls; ihre Zeitfenster richten sich nach deinem Stundenplan." : "„Schwer“ bedeutet: noch richtig erinnert, aber mit Mühe. Wenn du es nicht mehr wusstest, wähle „Vergessen“.").font(.caption).foregroundStyle(AboLifeColors.secondaryText)
            Stepper("Tatsächliche Lerndauer: \(minutes) Minuten", value: $minutes, in: 5...180, step: 5)
            if let error = store.errorMessage { Text(error).font(.caption).foregroundStyle(AboLifeColors.habits) }
            HStack {
                Button("Abbrechen") { dismiss() }.keyboardShortcut(.cancelAction)
                Spacer()
                Button("Bewertung speichern") { if store.review(session.id, rating: rating, actualMinutes: minutes) { dismiss() } }.buttonStyle(.borderedProminent).tint(AboLifeColors.accentGreen)
            }
        }.onAppear { minutes = min(max(session.minutes, 5), 180) }
    }
}

struct PlannerMoveSheet: View {
    @Environment(\.dismiss) private var dismiss
    let session: StudySession
    @ObservedObject var store: CalendarPlannerStore
    @State private var start = Date()
    var body: some View {
        PlannerEditorFrame("Lernen verschieben") {
            DatePicker("Neuer Beginn", selection: $start)
            Text("\(session.minutes) Minuten. Der Termin wird fixiert; Termine, Wege, Pausen und Lernzeiten werden geprüft.").font(.caption).foregroundStyle(AboLifeColors.secondaryText)
            if let error = store.errorMessage { Text(error).font(.caption).foregroundStyle(AboLifeColors.habits) }
            HStack {
                Button("Abbrechen") { dismiss() }
                Spacer()
                Button("Verschieben & fixieren") { if store.moveSession(session.id, start: start) { dismiss() } }.buttonStyle(.borderedProminent).tint(AboLifeColors.review)
            }
        }.onAppear { start = max(session.start, Date()) }
    }
}

struct PlannerPreferencesEditor: View {
    @Environment(\.dismiss) private var dismiss
    @State var preferences: PlannerPreferences
    @ObservedObject var store: CalendarPlannerStore
    @State private var routeFrom = "Zuhause"
    @State private var routeTo = "Uni"
    @State private var routeMinutes = 60
    private var routeKeys: [String] { Array(Set(["home>university", "university>home", "home>gym", "gym>home", "university>gym", "gym>university"] + preferences.travelMinutes.keys)).sorted() }
    var body: some View {
        PlannerEditorFrame("Lernzeiten & Wege") {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    GroupBox("Verfügbarkeit") {
                        VStack(alignment: .leading, spacing: 12) {
                            Toggle("Vor- und Nacharbeit automatisch aus Uni-Modulen planen", isOn: Binding(get: { preferences.modulePlanningEnabled }, set: { preferences.automaticModulePlanning = $0 }))
                            DatePicker("Lernen ab", selection: timeBinding(\.dayStartMinute), displayedComponents: .hourAndMinute)
                            DatePicker("Lernen bis", selection: timeBinding(\.dayEndMinute), displayedComponents: .hourAndMinute)
                            HStack {
                                ForEach(0..<7, id: \.self) { offset in
                                    let weekday = offset == 6 ? 1 : offset + 2
                                    Toggle(preferences.calendar.shortStandaloneWeekdaySymbols[weekday - 1], isOn: Binding(get: { preferences.weekdays.contains(weekday) }, set: { if $0 { preferences.weekdays.insert(weekday) } else { preferences.weekdays.remove(weekday) } })).toggleStyle(.button)
                                }
                            }
                            Stepper("Höchstens \(preferences.dailyLimitMinutes) Minuten Lernen pro Tag", value: $preferences.dailyLimitMinutes, in: 15...480, step: 15)
                            Stepper("Kleinster Lernblock: \(preferences.minimumBlockMinutes) Minuten", value: $preferences.minimumBlockMinutes, in: 5...120, step: 5)
                            Stepper("Pause zwischen Lernblöcken: \(preferences.breakMinutes) Minuten", value: $preferences.breakMinutes, in: 0...60, step: 5)
                            Text("An Uni-Tagen erst nach dem letzten Uni-Termin und der Rückfahrt nach Hause lernen. Vormittage vor der Uni und Uni-Pausen bleiben lernfrei.").font(.caption).foregroundStyle(.secondary)
                            Text("Zeitzone: \(preferences.timeZoneID)").font(.caption).foregroundStyle(.secondary)
                        }.padding(8)
                    }
                    GroupBox("Fahrtzeiten pro Richtung") {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Nach dem letzten Uni-Termin zuerst nach Hause, vor einem späteren Training von Zuhause losfahren. Uni-Pausen bleiben vor Ort. Wenn der Heimweg zeitlich nicht passt, erscheint ein Hinweis.").font(.caption).foregroundStyle(.secondary)
                            Toggle("Rückfahrt zunächst wie Hinfahrt berechnen", isOn: Binding(get: { preferences.usesSymmetricReturn }, set: { preferences.assumeSymmetricReturn = $0 }))
                            Text("Gilt nur ohne eigene Rückfahrtdauer. Automatisch übernommene Zeiten sind als „wie Hinfahrt“ gekennzeichnet.").font(.caption).foregroundStyle(.secondary)
                            ForEach(routeKeys, id: \.self) { key in routeRow(key) }
                            Divider()
                            Text("Weitere Verbindung").font(.caption.weight(.semibold))
                            HStack {
                                TextField("Von", text: $routeFrom).textFieldStyle(.roundedBorder)
                                Image(systemName: "arrow.right")
                                TextField("Nach", text: $routeTo).textFieldStyle(.roundedBorder)
                            }
                            Text("Für eigene Orte dieselbe Bezeichnung wie beim Termin verwenden. Jede Richtung wird getrennt eingetragen.").font(.caption).foregroundStyle(.secondary)
                            HStack {
                                Stepper("\(routeMinutes) Minuten", value: $routeMinutes, in: 0...300, step: 5)
                                Button("Verbindung hinzufügen") {
                                    let a = PlannerDate.locationID(routeFrom), b = PlannerDate.locationID(routeTo)
                                    if !a.isEmpty && !b.isEmpty && a != b && !a.contains(">") && !b.contains(">") { preferences.travelMinutes[a + ">" + b] = routeMinutes }
                                }
                            }
                        }.padding(8)
                    }
                }
            }.frame(height: 480)
            if let error = store.errorMessage { Text(error).font(.caption).foregroundStyle(AboLifeColors.habits) }
            HStack {
                Button("Abbrechen") { dismiss() }
                Spacer()
                Button("Speichern & neu planen") { if store.savePreferences(preferences) { dismiss() } }.buttonStyle(.borderedProminent).tint(AboLifeColors.review)
            }
        }
    }
    private func timeBinding(_ key: WritableKeyPath<PlannerPreferences, Int>) -> Binding<Date> {
        Binding(get: { PlannerDate.atMinute(preferences[keyPath: key], on: Date(), calendar: preferences.calendar) }, set: {
            preferences[keyPath: key] = preferences.calendar.component(.hour, from: $0) * 60 + preferences.calendar.component(.minute, from: $0)
        })
    }
    private func routeRow(_ key: String) -> some View {
        let parts = key.components(separatedBy: ">")
        return HStack {
            Text(parts.count == 2 ? "\(PlannerDate.locationName(parts[0])) → \(PlannerDate.locationName(parts[1]))" : key).font(.caption)
            Spacer()
            if let minutes = preferences.travelMinutes[key] {
                Stepper("\(minutes) Min.", value: Binding(get: { preferences.travelMinutes[key] ?? 0 }, set: { preferences.travelMinutes[key] = $0 }), in: 0...300, step: 5).frame(width: 130)
                Button { preferences.travelMinutes.removeValue(forKey: key) } label: { Image(systemName: "minus.circle") }.help("Eigene Dauer entfernen")
            } else if parts.count == 2, let minutes = preferences.travel(from: parts[0], to: parts[1]) {
                Text("\(minutes) Min. · wie Hinfahrt").font(.caption).foregroundStyle(.secondary)
                Button("Anpassen") { preferences.travelMinutes[key] = minutes }
            } else {
                Text("Noch offen").font(.caption).foregroundStyle(AboLifeColors.habits)
                Button("Eintragen") { preferences.travelMinutes[key] = key.contains("university") ? 60 : 15 }
            }
        }
    }
}

struct PlannerImportPreview: View {
    @Environment(\.dismiss) private var dismiss
    let draft: CalendarImportDraft
    @ObservedObject var store: CalendarPlannerStore
    @State private var overwriteLocal = false
    @State private var removeMissing = false
    private var conflicts: [PlannerEvent] { store.workspace.events.filter { existing in existing.sourceID == draft.sourceID && existing.locallyModified && draft.events.contains(where: { $0.sourceUID == existing.sourceUID }) } }
    private var missing: [PlannerEvent] {
        let incoming = Set(draft.events.compactMap(\.sourceUID))
        return store.workspace.events.filter { $0.sourceID == draft.sourceID && !$0.cancelled && !incoming.contains($0.sourceUID ?? "") }
    }
    var body: some View {
        PlannerEditorFrame("Import prüfen · \(draft.sourceName)") {
            Text("\(draft.events.count) Termine / Serien gelesen. Noch wurde nichts übernommen.").foregroundStyle(AboLifeColors.primaryText)
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(draft.warnings, id: \.self) { Label($0, systemImage: "exclamationmark.circle").font(.caption).foregroundStyle(AboLifeColors.habits) }
                    ForEach(draft.events) { event in
                        VStack(alignment: .leading, spacing: 3) {
                            Text(event.title).font(AboLifeTypography.cardTitle)
                            Text("\(event.start.formatted(date: .abbreviated, time: .shortened)) – \(event.end.formatted(date: .omitted, time: .shortened))\(event.weekly ? " · wöchentlich" : "")").font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    if !conflicts.isEmpty {
                        Divider()
                        Text("\(conflicts.count) bestehende Einträge sind lokal angepasst und bleiben standardmäßig erhalten.").font(.caption).foregroundStyle(AboLifeColors.habits)
                        ForEach(conflicts) { Text($0.title).font(.caption) }
                        Toggle("Diese lokalen Änderungen ausdrücklich überschreiben", isOn: $overwriteLocal)
                    }
                    if !missing.isEmpty {
                        Divider()
                        Text("Diese bestehenden Einträge fehlen in der Datei:").font(.caption)
                        ForEach(missing) { Text($0.title).font(.caption).foregroundStyle(.secondary) }
                        Toggle("Vollständiger Wiederimport: fehlende Einträge entfernen", isOn: $removeMissing).disabled(!draft.warnings.isEmpty)
                        Text("Bei Teilimporten ausgeschaltet lassen. Bei Importwarnungen ist Entfernen gesperrt. Lokale Änderungen bleiben geschützt, solange du sie nicht ausdrücklich überschreibst.").font(.caption).foregroundStyle(.secondary)
                    }
                }
            }.frame(height: 340)
            if let error = store.errorMessage { Text(error).font(.caption).foregroundStyle(AboLifeColors.habits) }
            HStack {
                Button("Abbrechen") { dismiss() }
                Spacer()
                Button("Übernehmen & planen") {
                    store.importChanges(draft, overwriteLocal: overwriteLocal, removeMissing: removeMissing)
                    if store.errorMessage == nil { dismiss() }
                }.buttonStyle(.borderedProminent).tint(AboLifeColors.review).disabled(draft.events.isEmpty && !(removeMissing && draft.warnings.isEmpty && !missing.isEmpty))
            }
        }
    }
}
