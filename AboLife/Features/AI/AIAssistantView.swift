import SwiftUI
import AppKit

struct AIAssistantView: View {
    @Environment(\.aboLifeStyle) private var designStyle
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var store: AIAssistantStore
    var body: some View {
        HSplitView {
            sidebar
            VStack(spacing: 0) {
                if let error = store.errorMessage {
                    HStack(alignment: .top) {
                        Image(systemName: "exclamationmark.triangle").foregroundStyle(.orange)
                        Text(error).font(.callout).textSelection(.enabled)
                        Spacer()
                        Button { store.errorMessage = nil } label: { Image(systemName: "xmark") }.buttonStyle(.plain)
                    }.padding(16).background(Color.orange.opacity(0.1))
                }
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 24) {
                            if store.selected?.turns.isEmpty != false {
                                ContentUnavailableView("Was möchtest du klären?", systemImage: "bubble.left.and.text.bubble.right", description: Text("Bereich wählen, gewünschten Kontext freigeben und eine Frage stellen."))
                                ForEach(store.purpose.suggestions, id: \.self) { prompt in
                                    Button(prompt) { store.draft = prompt }.buttonStyle(.bordered)
                                }
                            }
                            ForEach(store.selected?.turns ?? []) { turn in
                                VStack(alignment: .leading, spacing: 8) {
                                    HStack {
                                        Text(turn.role == "user" ? "Du" : "AboLife AI").font(.headline)
                                        Spacer()
                                        if !turn.content.isEmpty {
                                            Button { NSPasteboard.general.clearContents(); NSPasteboard.general.setString(turn.content, forType: .string) } label: { Image(systemName: "doc.on.doc") }.buttonStyle(.plain).help("Antwort kopieren")
                                        }
                                    }
                                    if !turn.reasoning.isEmpty {
                                        DisclosureGroup(turn.status == "streaming" ? "Denkt nach …" : "Gedankengang") {
                                            Text(turn.reasoning).font(.callout).foregroundStyle(.secondary).textSelection(.enabled)
                                        }.font(.caption)
                                    }
                                    if turn.status == "streaming" {
                                        Text(turn.content).textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading)
                                    } else {
                                        Text((try? AttributedString(markdown: turn.content, options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace))) ?? AttributedString(turn.content))
                                            .textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading)
                                    }
                                    if turn.status == "streaming", turn.content.isEmpty { ProgressView().controlSize(.small) }
                                    if ["failed", "cancelled"].contains(turn.status) { Text("Antwort unterbrochen").font(.caption).foregroundStyle(.secondary) }
                                }.padding(16).background(turn.role == "user" ? designStyle.colors.elevatedCardBackground : designStyle.colors.cardBackground, in: RoundedRectangle(cornerRadius: 12))
                            }
                            Color.clear.frame(height: 1).id("bottom")
                        }.padding(24)
                    }.onChange(of: store.selected?.turns.last?.content) { _, _ in proxy.scrollTo("bottom", anchor: .bottom) }
                }
                Divider()
                VStack(spacing: 8) {
                    HStack {
                        Menu("Aktion vorschlagen") {
                            Button("Lernaufgabe hinzufügen") { store.propose(.createStudyTask) }.disabled(!store.granted.contains(.learning))
                            Button("Lernblock planen") { store.propose(.createStudyBlock) }.disabled(!store.granted.contains(.learning) || !store.granted.contains(.calendar))
                            Button("Wochenreview ergänzen") { store.propose(.saveWeeklyReview) }.disabled(!store.granted.contains(.review))
                            Button("Budgetanalyse speichern") { store.propose(.saveBudgetAnalysis) }.disabled(!store.granted.contains(.finance))
                        }.disabled(store.busy || store.connector == nil)
                        Spacer()
                        Button("Aktionsvorschlag prüfen …") { store.previewLastAction() }
                            .disabled(store.busy || store.selected?.turns.last?.role != "assistant")
                    }.font(.caption)
                    TextEditor(text: $store.draft).font(.body).frame(minHeight: 55, maxHeight: 110)
                        .scrollContentBackground(.hidden)
                        .padding(8)
                        .background {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(designStyle.colors.cardBackground)
                                .strokeBorder(designStyle.colors.glassStroke)
                        }
                        .accessibilityLabel("Frage an AboLife AI")
                    HStack {
                        Toggle("Denken", isOn: $store.reasoningEnabled).toggleStyle(.checkbox).font(.caption).disabled(store.busy)
                        Text("Änderungen nur nach Bestätigung.").font(.caption2).foregroundStyle(.secondary)
                        Spacer()
                        if store.busy { Button("Abbrechen") { store.cancel() }.keyboardShortcut(".") }
                        else { Button("Senden") { store.send() }.buttonStyle(.borderedProminent).tint(designStyle.colors.action).keyboardShortcut(.return, modifiers: .command).disabled(store.draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || store.connector == nil) }
                    }
                }.padding(16)
            }.frame(minWidth: 450, idealWidth: 600)
        }
        .frame(minWidth: 800, idealWidth: 1040, minHeight: 600, idealHeight: 740)
        .background(designStyle.colors.pageBackground)
        .tint(designStyle.colors.review)
        .onAppear { store.refreshPreview() }
        .onChange(of: store.purpose) { old, new in if old != new, store.selected?.purpose != new { store.newChat() }; store.refreshPreview() }
        .sheet(item: $store.actionPreview) { preview in
            VStack(alignment: .leading, spacing: 16) {
                Label("Änderung prüfen", systemImage: "checkmark.shield").font(.title2.weight(.semibold))
                ScrollView { Text(preview.summary).textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading) }.frame(maxHeight: 320)
                Text("Erst „Änderung übernehmen“ schreibt diese konkrete Aktion in AboLife. Der aktuelle Datenstand und deine Berechtigungen werden erneut geprüft.").font(.callout).foregroundStyle(.secondary)
                HStack {
                    Button("Ablehnen", role: .cancel) { store.actionPreview = nil }
                    Spacer()
                    Button("Änderung übernehmen") { store.confirmAction() }
                        .buttonStyle(.borderedProminent)
                        .tint(designStyle.colors.action)
                }
            }.padding(24).frame(width: 550)
        }
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Label("AboLife AI", systemImage: "bubble.left.and.text.bubble.right").font(.title2.weight(.semibold))
                Spacer()
                Button("Neuer Chat") { store.newChat() }.disabled(store.busy)
                Button { store.cancel(); dismiss() } label: { Image(systemName: "xmark") }
                    .buttonStyle(.plain).help("Assistenten schließen").accessibilityLabel("Assistenten schließen").keyboardShortcut(.cancelAction)
            }
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 12) {
                    Picker("Bereich", selection: $store.purpose) {
                        ForEach(AIPurpose.allCases) { Text($0.title).tag($0) }
                    }.disabled(store.busy)
                    if store.connectionName == nil {
                        Text("In BonsaiBar die lokale API aktivieren, einen Client anlegen und die Verbindungsdatei hier importieren.").font(.callout).foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                        Button("Mit BonsaiBar verbinden …") { store.importConnection() }
                    } else {
                        HStack {
                            Text(store.connectionName ?? "").font(.caption)
                            Spacer()
                            Button("Prüfen") { Task { await store.checkConnection() } }.disabled(store.busy)
                            Button("Trennen") { store.disconnect() }.disabled(store.busy)
                        }
                    }
                    Text(store.status).font(.caption).foregroundStyle(.secondary).textSelection(.enabled)
                    Divider()
                    Text("Für diese Anfrage freigeben").font(.headline)
                    ForEach(store.scopesForPurpose) { scope in
                        Toggle(scope.title, isOn: Binding(get: { store.granted.contains(scope) }, set: {
                            if $0 { store.granted.insert(scope) } else { store.granted.remove(scope) }
                            store.refreshPreview()
                        })).toggleStyle(.checkbox).font(.callout).disabled(store.busy)
                    }
                    if store.purpose.scopes.contains(.calendar), !store.granted.contains(.calendar) {
                        Text("Aktiviere die Kalenderfreigabe, wenn du nach deinen Terminen fragst.")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    Text("Nur ausgewählte, zum Bereich passende Daten gehen an das lokale Modell. Eine andere Bereichswahl beginnt einen neuen Chat.").font(.caption).foregroundStyle(.secondary)
                    DisclosureGroup("Kontext vor dem Senden ansehen") {
                        ScrollView {
                            if let snapshot = store.contextPreview, !snapshot.sections.isEmpty {
                                VStack(alignment: .leading, spacing: 8) {
                                    ForEach(snapshot.sections, id: \.scope) { section in
                                        Text(section.scope.title).font(.caption.weight(.semibold))
                                        ForEach(Array(section.facts.enumerated()), id: \.offset) { _, fact in Text(fact).font(.caption).textSelection(.enabled) }
                                    }
                                }.frame(maxWidth: .infinity, alignment: .leading)
                            } else { Text("Keine persönlichen Daten freigegeben.").font(.caption).foregroundStyle(.secondary) }
                        }.frame(maxHeight: 220)
                    }
                    Divider()
                    Text("Gespeicherte KI-Chats").font(.caption).foregroundStyle(.secondary)
                    ForEach(store.chats) { chat in
                        Button { store.selectChat(chat.id) } label: {
                            Label("\(chat.purpose.title) · \(chat.title)",
                                  systemImage: chat.id == store.selectedID ? "bubble.left.fill" : "bubble.left")
                                .lineLimit(1)
                                .frame(maxWidth: .infinity, minHeight: 28, alignment: .leading)
                        }
                        .buttonStyle(.plain)
                        .font(.caption)
                        .disabled(store.busy)
                        .accessibilityAddTraits(chat.id == store.selectedID ? .isSelected : [])
                    }
                    if !store.savedAnalyses.isEmpty {
                        DisclosureGroup("Gespeicherte Budgetanalysen") {
                            ScrollView {
                                ForEach(store.savedAnalyses) { note in
                                    VStack(alignment: .leading) { Text(note.title).font(.caption.weight(.semibold)); Text(note.content).font(.caption).textSelection(.enabled) }.padding(.vertical, 4)
                                }
                            }.frame(maxHeight: 160)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            Label("Lokal über BonsaiBar", systemImage: "lock.shield").font(.caption).foregroundStyle(.secondary)
        }.padding(24).frame(minWidth: 280, idealWidth: 320, maxWidth: 380)
            .background(designStyle.colors.sidebarBackground)
    }
}
