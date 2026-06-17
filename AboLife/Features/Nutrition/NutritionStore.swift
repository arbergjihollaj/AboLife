import Foundation

final class NutritionStore: ObservableObject {
    @Published var selectedDate: Date {
        didSet {
            guard !calendar.isDate(selectedDate, inSameDayAs: oldValue) else { return }
            reload()
        }
    }
    @Published private(set) var entries: [NutritionEntryRecord] = []
    @Published private(set) var templates: [NutritionTemplateRecord] = []
    @Published private(set) var caloriesTarget: Int
    @Published private(set) var proteinTarget: Double
    @Published private(set) var errorMessage: String?
    @Published private(set) var templateMessage: String?

    private let database: AppDatabase?
    private let calendar: Calendar

    init(
        database: AppDatabase?,
        selectedDate: Date = Date(),
        calendar: Calendar = .current,
        caloriesTarget: Int = SeedData.defaultSettings.caloriesTarget,
        proteinTarget: Double = SeedData.defaultSettings.proteinTargetG
    ) {
        self.database = database
        self.selectedDate = selectedDate
        self.calendar = calendar
        self.caloriesTarget = caloriesTarget
        self.proteinTarget = proteinTarget
        reload()
    }

    var caloriesConsumed: Int {
        entries.reduce(0) { $0 + $1.caloriesKcal }
    }

    var proteinConsumed: Double {
        entries.reduce(0) { $0 + $1.proteinG }
    }

    var caloriesRemaining: Int {
        max(caloriesTarget - caloriesConsumed, 0)
    }

    var caloriesProgress: Double {
        Self.progress(current: Double(caloriesConsumed), target: Double(caloriesTarget))
    }

    var proteinProgress: Double {
        Self.progress(current: proteinConsumed, target: proteinTarget)
    }

    var isToday: Bool {
        calendar.isDateInToday(selectedDate)
    }

    var dateSubtitle: String {
        if isToday {
            return "Heute"
        }

        return selectedDate.formatted(.dateTime.weekday(.wide).day().month(.wide))
    }

    func selectToday() {
        selectedDate = Date()
        reload()
    }

    func reload() {
        guard let database else {
            entries = []
            templates = []
            caloriesTarget = SeedData.defaultSettings.caloriesTarget
            proteinTarget = SeedData.defaultSettings.proteinTargetG
            errorMessage = nil
            templateMessage = nil
            return
        }

        do {
            let settings = try SettingsRepository(database: database).fetchDefault() ?? SeedData.defaultSettings
            let repository = NutritionRepository(database: database)
            caloriesTarget = settings.caloriesTarget
            proteinTarget = settings.proteinTargetG
            entries = try repository.fetchEntries(forDay: selectedDate, calendar: calendar)
            templates = try NutritionTemplateRepository(database: database).fetchAll()
            errorMessage = nil
        } catch {
            errorMessage = "Ernährungsdaten konnten nicht geladen werden."
        }
    }

    func deleteEntry(id: NutritionEntryRecord.ID) {
        guard let database else { return }

        do {
            try NutritionRepository(database: database).delete(id: id)
            reload()
        } catch {
            errorMessage = "Mahlzeit konnte nicht gelöscht werden."
        }
    }

    @discardableResult
    func createTemplate(
        kind: NutritionTemplateKind,
        name: String,
        caloriesKcal: Int,
        proteinG: Double,
        defaultPortion: String? = nil,
        mealType: String? = nil,
        note: String? = nil
    ) -> Bool {
        guard let database else { return false }

        do {
            try NutritionTemplateRepository(database: database).create(
                kind: kind,
                name: name,
                caloriesKcal: caloriesKcal,
                proteinG: proteinG,
                defaultPortion: defaultPortion,
                mealType: mealType,
                note: note
            )
            reload()
            templateMessage = "Vorlage gespeichert."
            return true
        } catch {
            templateMessage = Self.message(for: error, fallback: "Vorlage konnte nicht gespeichert werden.")
            return false
        }
    }

    @discardableResult
    func updateTemplate(
        id: NutritionTemplateRecord.ID,
        kind: NutritionTemplateKind,
        name: String,
        caloriesKcal: Int,
        proteinG: Double,
        defaultPortion: String? = nil,
        mealType: String? = nil,
        note: String? = nil
    ) -> Bool {
        guard let database else { return false }

        do {
            _ = try NutritionTemplateRepository(database: database).update(
                id: id,
                kind: kind,
                name: name,
                caloriesKcal: caloriesKcal,
                proteinG: proteinG,
                defaultPortion: defaultPortion,
                mealType: mealType,
                note: note
            )
            reload()
            templateMessage = "Vorlage aktualisiert."
            return true
        } catch {
            templateMessage = Self.message(for: error, fallback: "Vorlage konnte nicht aktualisiert werden.")
            return false
        }
    }

    func deleteTemplate(id: NutritionTemplateRecord.ID) {
        guard let database else { return }

        do {
            try NutritionTemplateRepository(database: database).delete(id: id)
            reload()
            templateMessage = "Vorlage gelöscht."
        } catch {
            templateMessage = "Vorlage konnte nicht gelöscht werden."
        }
    }

    @discardableResult
    func addTemplateAsMeal(_ template: NutritionTemplateRecord, date: Date = Date()) -> Bool {
        guard let database else { return false }

        do {
            try NutritionTemplateRepository(database: database).addMeal(from: template, date: date, calendar: calendar)
            reload()
            templateMessage = "Mahlzeit hinzugefügt."
            return true
        } catch {
            templateMessage = "Mahlzeit konnte nicht hinzugefügt werden."
            return false
        }
    }

    @discardableResult
    func addAdjustedTemplateAsMeal(
        _ template: NutritionTemplateRecord,
        title: String,
        caloriesKcal: Int,
        proteinG: Double,
        note: String? = nil,
        date: Date = Date()
    ) -> Bool {
        guard let database else { return false }

        do {
            try NutritionTemplateRepository(database: database).addMeal(
                from: template,
                date: date,
                title: title,
                caloriesKcal: caloriesKcal,
                proteinG: proteinG,
                note: note,
                calendar: calendar
            )
            reload()
            templateMessage = "Mahlzeit hinzugefügt."
            return true
        } catch {
            templateMessage = Self.message(for: error, fallback: "Mahlzeit konnte nicht hinzugefügt werden.")
            return false
        }
    }

    static func progress(current: Double, target: Double) -> Double {
        guard target > 0 else { return 0 }
        return min(max(current / target, 0), 1)
    }

    static func normalizedCalories(_ value: Double) -> Int {
        guard value.isFinite else { return -1 }
        return Int(value.rounded())
    }

    private static func message(for error: Error, fallback: String) -> String {
        (error as? LocalizedError)?.errorDescription ?? fallback
    }
}
