import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var sync: SharedSyncCoordinator
    @State private var conflictResolution: String?
    @StateObject private var store: SettingsStore

    init(database: AppDatabase?) {
        _store = StateObject(wrappedValue: SettingsStore(database: database))
    }

    var body: some View {
        ZStack {
            AboLifePremiumBackground()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    header
                    weightCard
                    trainingCard
                    financeCard
                    syncCard
                    generalCard
                    backupExportCard
                    actions
                }
                .padding(22)
                .frame(maxWidth: 920, alignment: .leading)
            }
        }
        .navigationTitle("Einstellungen")
        .confirmationDialog("Lokalen Datenstand durch dieses Backup ersetzen?", isPresented: Binding(get: { store.pendingRestore != nil }, set: { if !$0 { store.pendingRestore = nil } })) {
            Button("Backup wiederherstellen", role: .destructive) { store.confirmRestore() }
            Button("Abbrechen", role: .cancel) { store.pendingRestore = nil }
        } message: { Text(store.restoreSummary) }
        .onAppear {
            store.reload()
        }
    }

    private var syncCard: some View {
        settingsCard(title: "Mac & Web verbinden", systemImage: "arrow.triangle.2.circlepath", tint: AboLifeColors.review) {
            Text("Dein Homelab speichert den gemeinsamen Stand. Mac und iPhone verbinden sich über dieselbe private HTTPS-Adresse; auf beiden Geräten muss Tailscale aktiv sein.")
                .font(.caption).foregroundStyle(.secondary)
            TextField("Serveradresse (https://…)", text: $sync.serverAddress)
            SecureField("Serverpasswort · wird im Schlüsselbund gespeichert", text: $sync.password)
            Toggle("Alle 30 Sekunden synchronisieren, solange AboLife geöffnet ist", isOn: $sync.autoSync)
            Text(sync.status).font(.caption).foregroundStyle(.secondary).textSelection(.enabled)
            Button(sync.busy ? "Synchronisiert …" : "Jetzt verbinden / synchronisieren") { Task { await sync.synchronize() } }.disabled(sync.busy)
            if let last = sync.lastSynced {
                Text("Zuletzt abgeglichen: \(last.formatted(date: .abbreviated, time: .shortened))").font(.caption).foregroundStyle(.secondary)
            }
            if let url = URL(string: sync.serverAddress), url.scheme == "https" {
                Link("Mobile Weboberfläche öffnen ↗", destination: url)
            }
            if sync.hasConflict {
                Text("Beide Geräte haben Änderungen. Vor dem Ersetzen wird eine lokale Sicherung erstellt; der Server behält frühere Versionen.").font(.caption)
                HStack {
                    Button("Serverstand übernehmen …") { conflictResolution = "server" }
                    Button("Macstand senden …") { conflictResolution = "mac" }
                }.disabled(sync.busy)
            }
        }
        .confirmationDialog("Welcher Datenstand soll übernommen werden? Der andere Stand wird ersetzt und bleibt als Sicherung erhalten.", isPresented: Binding(get: { conflictResolution != nil }, set: { if !$0 { conflictResolution = nil } })) {
            Button("Datenstand übernehmen", role: .destructive) { let choice = conflictResolution; conflictResolution = nil; Task { await sync.synchronize(resolution: choice) } }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Einstellungen")
                .font(AboLifeTypography.dashboardTitle)
                .foregroundStyle(AboLifeColors.primaryText)

            Text("Persönliche Ziele und lokale App-Werte")
                .font(AboLifeTypography.body)
                .foregroundStyle(AboLifeColors.secondaryText)
        }
    }



    private var trainingCard: some View {
        settingsCard(title: "Trainingsziel", systemImage: "figure.strengthtraining.traditional", tint: AboLifeColors.training) {
            stepperRow(
                title: "Workouts pro Woche",
                value: $store.weeklyWorkoutTarget,
                range: 0...14,
                step: 1,
                unit: "Workouts"
            )
        }
    }

    private var weightCard: some View {
        settingsCard(title: "Gewichtsziel", systemImage: "scalemass", tint: AboLifeColors.review) {
            weightStepperRow(
                title: "Zielgewicht",
                value: $store.targetWeightKg,
                unit: "kg"
            )
            weightStepperRow(
                title: "Korridor unten",
                value: $store.targetWeightLowerKg,
                unit: "kg"
            )
            weightStepperRow(
                title: "Korridor oben",
                value: $store.targetWeightUpperKg,
                unit: "kg"
            )

            Text("0 kg bedeutet: noch nicht gesetzt. Der Zielkorridor bleibt optional.")
                .font(AboLifeTypography.micro)
                .foregroundStyle(AboLifeColors.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var financeCard: some View {
        settingsCard(title: "Finanzziele", systemImage: "eurosign.circle", tint: AboLifeColors.finance) {
            Stepper(value: $store.monthlyBudget, in: 0...100_000, step: 50) {
                valueRow(title: "Monatsbudget", value: "\(Int(store.monthlyBudget.rounded())) \(store.currencyCode)")
            }

            HStack {
                Text("Währung")
                    .font(AboLifeTypography.body)
                    .foregroundStyle(AboLifeColors.primaryText)

                Spacer()

                Picker("", selection: $store.currencyCode) {
                    Text("EUR").tag("EUR")
                }
                .labelsHidden()
                .frame(width: 96)
            }
        }
    }

    private var generalCard: some View {
        settingsCard(title: "Allgemein", systemImage: "calendar", tint: AboLifeColors.review) {
            HStack {
                Text("Woche startet am")
                    .font(AboLifeTypography.body)
                    .foregroundStyle(AboLifeColors.primaryText)

                Spacer()

                Text(store.weekStartsOnLabel)
                    .font(AboLifeTypography.caption.weight(.semibold))
                    .foregroundStyle(AboLifeColors.secondaryText)
            }

            Divider().opacity(0.18)

            Label("Deine Mac-Daten werden lokal gespeichert. Eine eingerichtete Webverbindung gleicht die aktiven Bereiche mit deinem Server ab.", systemImage: "internaldrive")
                .font(AboLifeTypography.caption)
                .foregroundStyle(AboLifeColors.secondaryText)
        }
    }

    private var backupExportCard: some View {
        settingsCard(title: "Backup & Export", systemImage: "externaldrive", tint: AboLifeColors.review) {
            VStack(alignment: .leading, spacing: 8) {
                Label("Deine Mac-Daten werden lokal gespeichert. Eine eingerichtete Webverbindung gleicht die aktiven Bereiche mit deinem Server ab.", systemImage: "lock")
                    .font(AboLifeTypography.caption)
                    .foregroundStyle(AboLifeColors.secondaryText)

                Label("Du kannst ein SQLite-Backup, einen JSON-Export oder ein CSV-Backup mit Offline-Report erstellen.", systemImage: "doc.text")
                    .font(AboLifeTypography.caption)
                    .foregroundStyle(AboLifeColors.secondaryText)

                Label("JSON, SQLite und neue CSV-Backup-Ordner lassen sich nach Vorprüfung wiederherstellen. Vor dem Ersetzen wird der aktuelle lokale Stand gesichert.", systemImage: "arrow.down.doc")
                    .font(AboLifeTypography.caption)
                    .foregroundStyle(AboLifeColors.secondaryText)
            }

            Divider().opacity(0.18)

            VStack(alignment: .leading, spacing: 10) {
                Button {
                    store.createSQLiteBackup()
                } label: {
                    Label("SQLite-Backup erstellen", systemImage: "externaldrive.badge.plus")
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.bordered)
                .disabled(store.isBackingUp || store.isExporting)

                Button {
                    store.createJSONExport()
                } label: {
                    Label("JSON-Export erstellen", systemImage: "square.and.arrow.up")
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.bordered)
                .disabled(store.isBackingUp || store.isExporting)

                Button {
                    store.createCSVExport()
                } label: {
                    Label("CSV-Backup exportieren", systemImage: "tablecells")
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.bordered)
                .disabled(store.isBackingUp || store.isExporting)

                Button {
                    store.createMarkdownSummaryExport()
                } label: {
                    Label("Markdown-Zusammenfassung erstellen", systemImage: "doc.plaintext")
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.bordered)
                .disabled(store.isBackingUp || store.isExporting)

                Button {
                    store.chooseRestore()
                } label: {
                    Label("Backup wiederherstellen …", systemImage: "arrow.down.doc")
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.bordered)
                .disabled(store.isBackingUp || store.isExporting)

                Button {
                    store.openBackupFolder()
                } label: {
                    Label("Backup-Ordner öffnen", systemImage: "folder")
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.bordered)
            }

            backupStatus
        }
    }





    private var actions: some View {
        AboLifeCard {
            HStack(spacing: 12) {
                if let errorMessage = store.errorMessage {
                    Text(errorMessage)
                        .font(AboLifeTypography.caption)
                        .foregroundStyle(AboLifeColors.habits)
                        .fixedSize(horizontal: false, vertical: true)
                } else if let statusMessage = store.statusMessage {
                    Text(statusMessage)
                        .font(AboLifeTypography.caption)
                        .foregroundStyle(AboLifeColors.review)
                } else {
                    Text("Änderungen werden lokal gespeichert.")
                        .font(AboLifeTypography.caption)
                        .foregroundStyle(AboLifeColors.secondaryText)
                }

                Spacer()

                Button {
                    store.resetToDefaults()
                } label: {
                    Label("Defaults", systemImage: "arrow.counterclockwise")
                }
                .buttonStyle(.bordered)

                Button {
                    store.save()
                } label: {
                    Label("Speichern", systemImage: "checkmark")
                }
                .buttonStyle(.borderedProminent)
                .tint(AboLifeColors.review)
            }
        }
    }

    @ViewBuilder
    private var backupStatus: some View {
        if let backupErrorMessage = store.backupErrorMessage {
            Label(backupErrorMessage, systemImage: "exclamationmark.circle")
                .font(AboLifeTypography.caption)
                .foregroundStyle(AboLifeColors.habits)
                .fixedSize(horizontal: false, vertical: true)
        } else if let backupStatusMessage = store.backupStatusMessage {
            VStack(alignment: .leading, spacing: 4) {
                Label(backupStatusMessage, systemImage: "checkmark.circle")
                    .font(AboLifeTypography.caption)
                    .foregroundStyle(AboLifeColors.review)

                if let lastExportPath = store.lastExportPath {
                    Text(lastExportPath)
                        .font(AboLifeTypography.micro)
                        .foregroundStyle(AboLifeColors.secondaryText)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            }
            .fixedSize(horizontal: false, vertical: true)
        } else {
            Text("Noch kein Backup oder Export erstellt.")
                .font(AboLifeTypography.caption)
                .foregroundStyle(AboLifeColors.secondaryText)
        }
    }

    private func settingsCard<Content: View>(
        title: String,
        systemImage: String,
        tint: Color,
        @ViewBuilder content: () -> Content
    ) -> some View {
        AboLifeCard(isProminent: true) {
            VStack(alignment: .leading, spacing: 14) {
                Label(title, systemImage: systemImage)
                    .font(AboLifeTypography.cardTitle)
                    .foregroundStyle(AboLifeColors.primaryText)

                VStack(spacing: 12) {
                    content()
                }
                .padding(.top, 2)
            }
        }
    }

    private func stepperRow(
        title: String,
        value: Binding<Int>,
        range: ClosedRange<Int>,
        step: Int,
        unit: String
    ) -> some View {
        Stepper(value: value, in: range, step: step) {
            valueRow(title: title, value: "\(value.wrappedValue) \(unit)")
        }
    }

    private func weightStepperRow(title: String, value: Binding<Double>, unit: String) -> some View {
        Stepper(value: value, in: 0...300, step: 0.5) {
            valueRow(title: title, value: value.wrappedValue > 0 ? "\(String(format: "%.1f", value.wrappedValue)) \(unit)" : "nicht gesetzt")
        }
    }



    private func valueRow(title: String, value: String) -> some View {
        HStack {
            Text(title)
                .font(AboLifeTypography.body)
                .foregroundStyle(AboLifeColors.primaryText)

            Spacer()

            Text(value)
                .font(AboLifeTypography.caption.weight(.semibold))
                .foregroundStyle(AboLifeColors.secondaryText)
                .monospacedDigit()
        }
    }




}

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView(database: nil)
            .environmentObject(SharedSyncCoordinator(database: nil))
            .frame(width: 980, height: 760)
    }
}
