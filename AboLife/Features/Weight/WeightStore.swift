import Foundation

final class WeightStore: ObservableObject {
    @Published var selectedDate: Date {
        didSet {
            guard !calendar.isDate(selectedDate, inSameDayAs: oldValue) else { return }
            reload()
        }
    }
    @Published var weightInput = ""
    @Published var targetWeightInput = ""
    @Published var targetLowerInput = ""
    @Published var targetUpperInput = ""
    @Published private(set) var entries: [WeightEntryRecord] = []
    @Published private(set) var settings: AppSettingsRecord = SeedData.defaultSettings
    @Published private(set) var errorMessage: String?

    private let database: AppDatabase?
    private let calendar: Calendar

    init(database: AppDatabase?, selectedDate: Date = Date(), calendar: Calendar = .current) {
        self.database = database
        self.selectedDate = selectedDate
        self.calendar = calendar
        reload()
    }

    var latestEntry: WeightEntryRecord? {
        entries.first
    }

    var previousEntry: WeightEntryRecord? {
        guard let latestEntry else { return nil }
        return entries.first { $0.date < latestEntry.date }
    }

    var selectedEntry: WeightEntryRecord? {
        entries.first { $0.date == DateIntervals.dayKey(for: selectedDate, calendar: calendar) }
    }

    var changeFromPreviousKg: Double? {
        guard let latestEntry, let previousEntry else { return nil }
        return latestEntry.weightKg - previousEntry.weightKg
    }

    var goalSummary: WeightGoalSummary {
        WeightGoalSummary(
            currentWeightKg: latestEntry?.weightKg,
            targetWeightKg: settings.targetWeightKg,
            lowerBoundKg: settings.targetWeightLowerKg,
            upperBoundKg: settings.targetWeightUpperKg
        )
    }

    var sevenDayEntries: [WeightEntryRecord] {
        Array(entries.prefix(7)).sorted { $0.date < $1.date }
    }

    var thirtyDayEntries: [WeightEntryRecord] {
        Array(entries.prefix(30)).sorted { $0.date < $1.date }
    }

    var dateSubtitle: String {
        calendar.isDateInToday(selectedDate) ? "Heute" : selectedDate.formatted(.dateTime.weekday(.wide).day().month(.wide))
    }

    var latestValueText: String {
        guard let latestEntry else { return "Noch kein Gewicht" }
        return Self.formatWeight(latestEntry.weightKg)
    }

    func selectToday() {
        selectedDate = Date()
        reload()
    }

    func reload() {
        guard let database else {
            entries = []
            weightInput = ""
            settings = SeedData.defaultSettings
            targetWeightInput = ""
            targetLowerInput = ""
            targetUpperInput = ""
            errorMessage = nil
            return
        }

        do {
            settings = try SettingsRepository(database: database).loadSettings()
            entries = try WeightRepository(database: database).fetchAll()
            weightInput = selectedEntry.map { Self.formatInput($0.weightKg) } ?? ""
            targetWeightInput = settings.targetWeightKg.map(Self.formatInput) ?? ""
            targetLowerInput = settings.targetWeightLowerKg.map(Self.formatInput) ?? ""
            targetUpperInput = settings.targetWeightUpperKg.map(Self.formatInput) ?? ""
            errorMessage = nil
        } catch {
            errorMessage = "Gewichtsdaten konnten nicht geladen werden."
        }
    }

    @discardableResult
    func saveGoals() -> Bool {
        guard let database else { return false }

        let target = optionalWeight(targetWeightInput)
        let lower = optionalWeight(targetLowerInput)
        let upper = optionalWeight(targetUpperInput)
        guard target != nil, lower != nil, upper != nil else {
            errorMessage = "Bitte Zielwerte zwischen 20 und 300 kg eintragen oder leer lassen."
            return false
        }

        var updated = settings
        updated.targetWeightKg = target!
        updated.targetWeightLowerKg = lower!
        updated.targetWeightUpperKg = upper!

        do {
            settings = try SettingsRepository(database: database).saveSettings(updated)
            reload()
            return true
        } catch {
            errorMessage = "Gewichtsziele konnten nicht gespeichert werden."
            return false
        }
    }

    @discardableResult
    func saveSelectedWeight() -> Bool {
        let value = parseDouble(weightInput)
        guard Self.isPlausibleWeight(value) else {
            errorMessage = "Bitte gib ein Gewicht zwischen 20 und 300 kg ein."
            return false
        }

        guard let database else { return false }

        do {
            try WeightRepository(database: database).upsert(date: selectedDate, weightKg: value, calendar: calendar)
            reload()
            return true
        } catch {
            errorMessage = "Gewicht konnte nicht gespeichert werden."
            return false
        }
    }

    func edit(_ entry: WeightEntryRecord) {
        selectedDate = Self.date(from: entry.date) ?? selectedDate
        weightInput = Self.formatInput(entry.weightKg)
    }

    func delete(id: WeightEntryRecord.ID) {
        guard let database else { return }

        do {
            try WeightRepository(database: database).delete(id: id)
            reload()
        } catch {
            errorMessage = "Gewicht konnte nicht gelöscht werden."
        }
    }

    static func formatWeight(_ value: Double) -> String {
        String(format: "%.1f kg", value)
    }

    static func formatChange(_ value: Double?) -> String {
        guard let value else { return "Noch kein Vergleich" }
        if abs(value) < 0.05 {
            return "+/-0.0 kg"
        }
        return String(format: "%+.1f kg", value)
    }

    static func isPlausibleWeight(_ value: Double) -> Bool {
        value.isFinite && value >= 20 && value <= 300
    }

    private static func formatInput(_ value: Double) -> String {
        String(format: "%.1f", value)
    }

    private static func date(from dayKey: String) -> Date? {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "de_DE")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: dayKey)
    }

    private func optionalWeight(_ text: String) -> Double?? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return .some(nil) }
        let value = parseDouble(trimmed)
        guard Self.isPlausibleWeight(value) else { return nil }
        return .some((value * 10).rounded() / 10)
    }
}

struct WeightGoalSummary: Equatable {
    let currentWeightKg: Double?
    let targetWeightKg: Double?
    let lowerBoundKg: Double?
    let upperBoundKg: Double?

    var distanceToTargetKg: Double? {
        guard let currentWeightKg, let targetWeightKg else { return nil }
        return currentWeightKg - targetWeightKg
    }

    var isInTargetCorridor: Bool? {
        guard let currentWeightKg, let lowerBoundKg, let upperBoundKg else { return nil }
        return currentWeightKg >= min(lowerBoundKg, upperBoundKg) && currentWeightKg <= max(lowerBoundKg, upperBoundKg)
    }

    var statusText: String {
        guard currentWeightKg != nil else { return "Noch kein Gewicht eingetragen." }
        guard lowerBoundKg != nil, upperBoundKg != nil else { return "Zielkorridor noch nicht gesetzt." }
        return isInTargetCorridor == true ? "Im Zielkorridor" : "Außerhalb Zielkorridor"
    }

    var distanceText: String {
        guard let distanceToTargetKg else { return "Zielgewicht noch nicht gesetzt." }
        if abs(distanceToTargetKg) < 0.05 { return "Zielgewicht erreicht" }
        return String(format: "Noch %.1f kg bis zum Ziel", abs(distanceToTargetKg))
    }
}
