import SwiftUI

struct SettingsView: View {
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
                    nutritionCard
                    trainingCard
                    financeCard
                    generalCard
                    backupExportCard
                    actions
                }
                .padding(22)
                .frame(maxWidth: 920, alignment: .leading)
            }
        }
        .navigationTitle("")
        .onAppear {
            store.reload()
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

    private var nutritionCard: some View {
        settingsCard(title: "Ernährungsziele", systemImage: "fork.knife", tint: AboLifeColors.nutrition) {
            stepperRow(
                title: "Kalorienziel pro Tag",
                value: $store.caloriesTarget,
                range: 800...6000,
                step: 50,
                unit: "kcal"
            )
            stepperRow(
                title: "Proteinziel pro Tag",
                value: $store.proteinTargetG,
                range: 20...400,
                step: 5,
                unit: "g"
            )
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

            Label("Alle Daten werden lokal auf diesem Mac gespeichert.", systemImage: "internaldrive")
                .font(AboLifeTypography.caption)
                .foregroundStyle(AboLifeColors.secondaryText)
        }
    }

    private var backupExportCard: some View {
        settingsCard(title: "Backup & Export", systemImage: "externaldrive", tint: AboLifeColors.review) {
            VStack(alignment: .leading, spacing: 8) {
                Label("Alle Daten werden lokal auf diesem Mac gespeichert.", systemImage: "lock")
                    .font(AboLifeTypography.caption)
                    .foregroundStyle(AboLifeColors.secondaryText)

                Label("Du kannst ein Backup der SQLite-Datenbank oder einen JSON-Export erstellen.", systemImage: "doc.text")
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
            .frame(width: 980, height: 760)
    }
}
