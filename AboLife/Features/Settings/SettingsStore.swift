import AppKit
import Combine
import Foundation

final class SettingsStore: ObservableObject {
    @Published var caloriesTarget: Int = AppSettingsDefaults.caloriesTarget
    @Published var proteinTargetG: Int = AppSettingsDefaults.proteinTargetG
    @Published var weeklyWorkoutTarget: Int = AppSettingsDefaults.weeklyWorkoutTarget
    @Published var monthlyBudget: Double = AppSettingsDefaults.monthlyBudget
    @Published var currencyCode: String = AppSettingsDefaults.defaultCurrency
    @Published var weekStartsOn: Int = AppSettingsDefaults.weekStartsOn
    @Published var targetWeightKg: Double = 0
    @Published var targetWeightLowerKg: Double = 0
    @Published var targetWeightUpperKg: Double = 0
    @Published var morningReminderMinuteOfDay: Int = AppSettingsDefaults.morningReminderMinuteOfDay
    @Published var trainingReminderMinuteOfDay: Int = AppSettingsDefaults.trainingReminderMinuteOfDay
    @Published var eveningReminderMinuteOfDay: Int = AppSettingsDefaults.eveningReminderMinuteOfDay
    @Published private(set) var statusMessage: String?
    @Published private(set) var errorMessage: String?
    @Published private(set) var backupStatusMessage: String?
    @Published private(set) var backupErrorMessage: String?
    @Published private(set) var lastExportPath: String?
    @Published private(set) var isBackingUp = false
    @Published private(set) var isExporting = false

    private let database: AppDatabase?
    private let backupServiceFactory: (AppDatabase) -> BackupService

    init(database: AppDatabase?, backupServiceFactory: @escaping (AppDatabase) -> BackupService = { BackupService(database: $0) }) {
        self.database = database
        self.backupServiceFactory = backupServiceFactory
        reload()
    }

    var weekStartsOnLabel: String {
        weekStartsOn == 2 ? "Montag" : "Montag"
    }

    func reload() {
        guard let database else {
            apply(SeedData.defaultSettings)
            statusMessage = nil
            errorMessage = nil
            return
        }

        do {
            let settings = try SettingsRepository(database: database).loadSettings()
            apply(settings)
            statusMessage = nil
            errorMessage = nil
        } catch {
            errorMessage = "Einstellungen konnten nicht geladen werden."
        }
    }

    func save() {
        guard let database else {
            apply(AppSettingsValidation.normalized(currentSettings()))
            statusMessage = "Gespeichert"
            return
        }

        do {
            let saved = try SettingsRepository(database: database).saveSettings(currentSettings())
            apply(saved)
            statusMessage = "Gespeichert"
            errorMessage = nil
        } catch {
            errorMessage = "Einstellungen konnten nicht gespeichert werden."
        }
    }

    func resetToDefaults() {
        guard let database else {
            apply(SeedData.defaultSettings)
            statusMessage = "Standardwerte gesetzt"
            errorMessage = nil
            return
        }

        do {
            let defaults = try SettingsRepository(database: database).resetToDefaults()
            apply(defaults)
            statusMessage = "Standardwerte gesetzt"
            errorMessage = nil
        } catch {
            errorMessage = "Standardwerte konnten nicht gesetzt werden."
        }
    }

    func createSQLiteBackup() {
        guard let service = makeBackupService() else { return }

        isBackingUp = true

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let result = Result { try service.createSQLiteBackup() }

            DispatchQueue.main.async {
                guard let self else { return }
                self.isBackingUp = false

                switch result {
                case .success(let url):
                    self.lastExportPath = url.path
                    self.backupStatusMessage = "Backup erstellt: \(url.lastPathComponent)"
                    self.backupErrorMessage = nil
                case .failure:
                    self.backupStatusMessage = nil
                    self.backupErrorMessage = "Backup konnte nicht erstellt werden."
                }
            }
        }
    }

    func createJSONExport() {
        guard let service = makeBackupService() else { return }

        isExporting = true

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let result = Result { try service.createJSONExport() }

            DispatchQueue.main.async {
                guard let self else { return }
                self.isExporting = false

                switch result {
                case .success(let url):
                    self.lastExportPath = url.path
                    self.backupStatusMessage = "JSON-Export erstellt: \(url.lastPathComponent)"
                    self.backupErrorMessage = nil
                case .failure:
                    self.backupStatusMessage = nil
                    self.backupErrorMessage = "JSON-Export konnte nicht erstellt werden."
                }
            }
        }
    }

    func createCSVExport() {
        guard let service = makeBackupService() else { return }

        isExporting = true

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let result = Result { try service.createCSVExport() }

            DispatchQueue.main.async {
                guard let self else { return }
                self.isExporting = false

                switch result {
                case .success(let url):
                    self.lastExportPath = url.path
                    self.backupStatusMessage = "CSV-Backup erstellt: \(url.lastPathComponent)"
                    self.backupErrorMessage = nil
                case .failure:
                    self.backupStatusMessage = nil
                    self.backupErrorMessage = "CSV-Backup konnte nicht erstellt werden."
                }
            }
        }
    }

    func createMarkdownSummaryExport() {
        guard let service = makeBackupService() else { return }

        isExporting = true

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let result = Result { try service.createMarkdownSummaryExport() }

            DispatchQueue.main.async {
                guard let self else { return }
                self.isExporting = false

                switch result {
                case .success(let url):
                    self.lastExportPath = url.path
                    self.backupStatusMessage = "Markdown-Zusammenfassung erstellt: \(url.lastPathComponent)"
                    self.backupErrorMessage = nil
                case .failure:
                    self.backupStatusMessage = nil
                    self.backupErrorMessage = "Markdown-Zusammenfassung konnte nicht erstellt werden."
                }
            }
        }
    }

    func openBackupFolder() {
        guard let service = makeBackupService() else { return }

        do {
            let url = try service.backupDirectoryURL()
            NSWorkspace.shared.open(url)
            backupStatusMessage = "Backup-Ordner geöffnet."
            backupErrorMessage = nil
        } catch {
            backupStatusMessage = nil
            backupErrorMessage = "Backup-Ordner konnte nicht geöffnet werden."
        }
    }

    static func normalized(
        caloriesTarget: Int,
        proteinTargetG: Int,
        weeklyWorkoutTarget: Int,
        monthlyBudget: Double,
        currencyCode: String,
        weekStartsOn: Int
    ) -> AppSettingsRecord {
        normalized(
            caloriesTarget: caloriesTarget,
            proteinTargetG: proteinTargetG,
            weeklyWorkoutTarget: weeklyWorkoutTarget,
            monthlyBudget: monthlyBudget,
            currencyCode: currencyCode,
            weekStartsOn: weekStartsOn,
            targetWeightKg: nil,
            targetWeightLowerKg: nil,
            targetWeightUpperKg: nil
        )
    }

    static func normalized(
        caloriesTarget: Int,
        proteinTargetG: Int,
        weeklyWorkoutTarget: Int,
        monthlyBudget: Double,
        currencyCode: String,
        weekStartsOn: Int,
        targetWeightKg: Double?,
        targetWeightLowerKg: Double?,
        targetWeightUpperKg: Double?,
        morningReminderMinuteOfDay: Int = AppSettingsDefaults.morningReminderMinuteOfDay,
        trainingReminderMinuteOfDay: Int = AppSettingsDefaults.trainingReminderMinuteOfDay,
        eveningReminderMinuteOfDay: Int = AppSettingsDefaults.eveningReminderMinuteOfDay
    ) -> AppSettingsRecord {
        AppSettingsValidation.normalized(
            AppSettingsRecord(
                caloriesTarget: caloriesTarget,
                proteinTargetG: Double(proteinTargetG),
                weeklyWorkoutTarget: weeklyWorkoutTarget,
                monthlyBudget: monthlyBudget,
                defaultCurrency: currencyCode,
                weekStartsOn: weekStartsOn,
                targetWeightKg: targetWeightKg,
                targetWeightLowerKg: targetWeightLowerKg,
                targetWeightUpperKg: targetWeightUpperKg,
                morningReminderMinuteOfDay: morningReminderMinuteOfDay,
                trainingReminderMinuteOfDay: trainingReminderMinuteOfDay,
                eveningReminderMinuteOfDay: eveningReminderMinuteOfDay
            )
        )
    }

    private func currentSettings() -> AppSettingsRecord {
        Self.normalized(
            caloriesTarget: caloriesTarget,
            proteinTargetG: proteinTargetG,
            weeklyWorkoutTarget: weeklyWorkoutTarget,
            monthlyBudget: monthlyBudget,
            currencyCode: currencyCode,
            weekStartsOn: weekStartsOn,
            targetWeightKg: positiveWeightOrNil(targetWeightKg),
            targetWeightLowerKg: positiveWeightOrNil(targetWeightLowerKg),
            targetWeightUpperKg: positiveWeightOrNil(targetWeightUpperKg),
            morningReminderMinuteOfDay: morningReminderMinuteOfDay,
            trainingReminderMinuteOfDay: trainingReminderMinuteOfDay,
            eveningReminderMinuteOfDay: eveningReminderMinuteOfDay
        )
    }

    private func apply(_ settings: AppSettingsRecord) {
        let normalized = AppSettingsValidation.normalized(settings)
        caloriesTarget = normalized.caloriesTarget
        proteinTargetG = Int(normalized.proteinTargetG.rounded())
        weeklyWorkoutTarget = normalized.weeklyWorkoutTarget
        monthlyBudget = normalized.monthlyBudget
        currencyCode = normalized.defaultCurrency
        weekStartsOn = normalized.weekStartsOn
        targetWeightKg = normalized.targetWeightKg ?? 0
        targetWeightLowerKg = normalized.targetWeightLowerKg ?? 0
        targetWeightUpperKg = normalized.targetWeightUpperKg ?? 0
        morningReminderMinuteOfDay = normalized.morningReminderMinuteOfDay
        trainingReminderMinuteOfDay = normalized.trainingReminderMinuteOfDay
        eveningReminderMinuteOfDay = normalized.eveningReminderMinuteOfDay
    }

    private func makeBackupService() -> BackupService? {
        guard let database else {
            backupStatusMessage = nil
            backupErrorMessage = "Backup ist ohne lokale Datenbank nicht verfügbar."
            return nil
        }

        return backupServiceFactory(database)
    }

    private func positiveWeightOrNil(_ value: Double) -> Double? {
        value > 0 ? value : nil
    }
}

extension SettingsStore {
    static func reminderTimeLabel(_ minuteOfDay: Int) -> String {
        let normalized = (0..<24 * 60).contains(minuteOfDay) ? minuteOfDay : 0
        return String(format: "%02d:%02d Uhr", normalized / 60, normalized % 60)
    }
}
