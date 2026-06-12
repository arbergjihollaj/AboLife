import Foundation

final class NutritionStore: ObservableObject {
    @Published var selectedDate: Date {
        didSet {
            guard !calendar.isDate(selectedDate, inSameDayAs: oldValue) else { return }
            reload()
        }
    }
    @Published private(set) var entries: [NutritionEntryRecord] = []
    @Published private(set) var caloriesTarget: Int
    @Published private(set) var proteinTarget: Double
    @Published private(set) var errorMessage: String?

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
            caloriesTarget = SeedData.defaultSettings.caloriesTarget
            proteinTarget = SeedData.defaultSettings.proteinTargetG
            errorMessage = nil
            return
        }

        do {
            let settings = try SettingsRepository(database: database).fetchDefault() ?? SeedData.defaultSettings
            let repository = NutritionRepository(database: database)
            caloriesTarget = settings.caloriesTarget
            proteinTarget = settings.proteinTargetG
            entries = try repository.fetchEntries(forDay: selectedDate, calendar: calendar)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func deleteEntry(id: NutritionEntryRecord.ID) {
        guard let database else { return }

        do {
            try NutritionRepository(database: database).delete(id: id)
            reload()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    static func progress(current: Double, target: Double) -> Double {
        guard target > 0 else { return 0 }
        return min(max(current / target, 0), 1)
    }
}
