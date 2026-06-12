import Foundation

final class FinanceStore: ObservableObject {
    @Published var selectedDate: Date {
        didSet {
            guard !calendar.isDate(selectedDate, equalTo: oldValue, toGranularity: .month) else { return }
            reload()
        }
    }
    @Published private(set) var entries: [FinanceEntryRecord] = []
    @Published private(set) var monthlyBudget: Double
    @Published private(set) var currency: String
    @Published private(set) var errorMessage: String?

    private let database: AppDatabase?
    private let calendar: Calendar

    init(
        database: AppDatabase?,
        selectedDate: Date = Date(),
        calendar: Calendar = .current,
        monthlyBudget: Double = SeedData.defaultSettings.monthlyBudget,
        currency: String = SeedData.defaultSettings.defaultCurrency
    ) {
        self.database = database
        self.selectedDate = selectedDate
        self.calendar = calendar
        self.monthlyBudget = monthlyBudget
        self.currency = currency
        reload()
    }

    var monthlySpent: Double {
        entries.reduce(0) { $0 + $1.amount }
    }

    var remainingBudget: Double {
        Self.remainingBudget(spent: monthlySpent, budget: monthlyBudget)
    }

    var dailyBudgetRemaining: Double {
        guard remainingBudget > 0 else { return 0 }
        return remainingBudget / Double(max(daysRemainingInMonth, 1))
    }

    var budgetProgress: Double {
        Self.progress(spent: monthlySpent, budget: monthlyBudget)
    }

    var isOverBudget: Bool {
        monthlyBudget > 0 && monthlySpent > monthlyBudget
    }

    var isCurrentMonth: Bool {
        calendar.isDate(selectedDate, equalTo: Date(), toGranularity: .month)
    }

    var monthSubtitle: String {
        if isCurrentMonth {
            return "Dieser Monat"
        }

        return selectedDate.formatted(.dateTime.month(.wide).year())
    }

    var statusMessage: String {
        if entries.isEmpty {
            return "Noch keine Ausgaben in diesem Monat."
        }

        if isOverBudget {
            return "\(formatAmount(monthlySpent - monthlyBudget)) über Budget."
        }

        return "Monat bleibt im Rahmen."
    }

    func selectCurrentMonth() {
        selectedDate = Date()
        reload()
    }

    func reload() {
        guard let database else {
            entries = []
            monthlyBudget = SeedData.defaultSettings.monthlyBudget
            currency = SeedData.defaultSettings.defaultCurrency
            errorMessage = nil
            return
        }

        do {
            let settings = try SettingsRepository(database: database).fetchDefault() ?? SeedData.defaultSettings
            let repository = FinanceRepository(database: database)
            monthlyBudget = settings.monthlyBudget
            currency = settings.defaultCurrency
            entries = try repository.fetchEntries(forMonthContaining: selectedDate, calendar: calendar)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func deleteEntry(id: FinanceEntryRecord.ID) {
        guard let database else { return }

        do {
            try FinanceRepository(database: database).delete(id: id)
            reload()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func formatAmount(_ amount: Double) -> String {
        "\(Int(amount.rounded())) \(currency)"
    }

    static func remainingBudget(spent: Double, budget: Double) -> Double {
        max(budget - spent, 0)
    }

    static func progress(spent: Double, budget: Double) -> Double {
        guard budget > 0 else { return 0 }
        return min(max(spent / budget, 0), 1)
    }

    private var daysRemainingInMonth: Int {
        guard let interval = calendar.dateInterval(of: .month, for: selectedDate) else { return 1 }
        let referenceDate = isCurrentMonth ? Date() : interval.start
        let start = calendar.startOfDay(for: referenceDate)
        let end = calendar.date(byAdding: .day, value: -1, to: interval.end) ?? interval.end
        let days = calendar.dateComponents([.day], from: start, to: end).day ?? 0
        return max(days + 1, 1)
    }
}
