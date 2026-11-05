import Foundation

final class FinanceStore: ObservableObject {
    @Published var selectedDate: Date {
        didSet {
            guard !calendar.isDate(selectedDate, equalTo: oldValue, toGranularity: .month) else { return }
            reload()
        }
    }
    @Published private(set) var entries: [FinanceEntryRecord] = []
    @Published private(set) var categories: [FinanceCategoryRecord] = []
    @Published private(set) var activeCategoryNames: [String] = FinanceCategoryCatalog.expenseCategories
    @Published private(set) var visibleCategoryNames: [String] = FinanceCategoryCatalog.expenseCategories
    @Published private(set) var categoryBudgets: [FinanceCategoryBudgetRecord] = []
    @Published private(set) var fixedCosts: [FinanceFixedCostRecord] = []
    @Published private(set) var savingsGoals: [FinanceSavingsGoalRecord] = []
    @Published private(set) var categorySummaries: [FinanceCategorySummary] = []
    @Published private(set) var categoryTrends: [FinanceCategoryTrend] = []
    @Published private(set) var monthPlan: FinanceMonthPlan?
    @Published private(set) var monthlyAnalysis = FinanceMonthlyAnalysis.empty
    @Published private(set) var monthlyTrend = FinanceMonthlyTrend.empty
    @Published private(set) var weeklySummary = FinanceWeeklySummary.empty
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
        FinanceRepository.expenseTotal(entries)
    }

    var monthlyIncome: Double {
        FinanceRepository.incomeTotal(entries)
    }

    var monthlyBalance: Double {
        monthlyIncome - monthlySpent
    }

    var remainingBudget: Double {
        Self.remainingBudget(spent: monthlySpent, budget: monthlyBudget)
    }

    var dailyBudgetRemaining: Double {
        guard remainingBudget > 0 else { return 0 }
        let todaySpent = entries.filter { calendar.isDate($0.occurredAt, inSameDayAs: Date()) && $0.amount > 0 }.reduce(
            0
        ) { $0 + $1.amount }
        let reference = isCurrentMonth ? Date() : selectedDate
        return Self.dailyBudgetRemaining(
            spent: monthlySpent, budget: monthlyBudget, date: reference, calendar: calendar,
            spentToday: isCurrentMonth ? todaySpent : 0)
    }

    var budgetProgress: Double {
        Self.progress(spent: monthlySpent, budget: monthlyBudget)
    }

    var isOverBudget: Bool {
        monthlyBudget > 0 && monthlySpent > monthlyBudget
    }

    var forecastSpend: Double {
        guard isCurrentMonth else { return monthlySpent }
        return max(monthPlan?.forecastSpend ?? monthlyTrend.projectedSpend, monthlySpent)
    }

    var forecastMessage: String {
        guard isCurrentMonth else { return "Abgeschlossener Monat · keine Hochrechnung." }
        guard let monthPlan else { return "Noch keine Prognose verfügbar." }
        if monthPlan.isForecastOverBudget {
            return "Prognose: \(formatAmount(monthPlan.forecastDelta)) über Monatsbudget."
        }
        return "Prognose: \(formatAmount(abs(monthPlan.forecastDelta))) Puffer bis Monatsende."
    }

    var plannedFixedCosts: Double {
        monthPlan?.plannedFixedCosts ?? fixedCosts.filter(\.isActive).reduce(0) { $0 + $1.amount }
    }

    var remainingFixedCosts: Double {
        monthPlan?.remainingFixedCosts ?? 0
    }

    var weeklySpent: Double {
        weeklySummary.spent
    }

    var savingsProgress: Double {
        let activeGoals = savingsGoals.filter(\.isActive)
        guard !activeGoals.isEmpty else { return 0 }
        return activeGoals.reduce(0) { $0 + $1.progress } / Double(activeGoals.count)
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

    func moveMonth(by offset: Int) {
        guard let month = calendar.dateInterval(of: .month, for: selectedDate)?.start,
            let date = calendar.date(byAdding: .month, value: offset, to: month)
        else { return }
        selectedDate = date
    }

    func selectCurrentMonth() {
        selectedDate = Date()
        reload()
    }

    func reload() {
        guard let database else {
            entries = []
            categories = []
            activeCategoryNames = FinanceCategoryCatalog.expenseCategories
            visibleCategoryNames = FinanceCategoryCatalog.expenseCategories
            monthlyBudget = SeedData.defaultSettings.monthlyBudget
            currency = SeedData.defaultSettings.defaultCurrency
            categoryTrends = []
            monthlyAnalysis = .empty
            errorMessage = nil
            return
        }

        do {
            let settings = try SettingsRepository(database: database).fetchDefault() ?? SeedData.defaultSettings
            let repository = FinanceRepository(database: database)
            let monthKey = FinanceRepository.monthKey(for: selectedDate, calendar: calendar)
            let analysisDate = DateIntervals.analysisReference(forMonthContaining: selectedDate, calendar: calendar)
            monthlyBudget = settings.monthlyBudget
            currency = settings.defaultCurrency
            categories = try repository.fetchCategories(includeInactive: true)
            activeCategoryNames = FinanceCategoryCatalog.mergedCategoryNames(
                primary: categories.filter(\.isActive).map(\.name), fallback: FinanceCategoryCatalog.expenseCategories)
            visibleCategoryNames = try repository.fetchCategoryNamesIncludingLegacy()
            entries = try repository.fetchEntries(forMonthContaining: selectedDate, calendar: calendar)
            categoryBudgets = try repository.fetchCategoryBudgets(monthKey: monthKey)
            fixedCosts = try repository.fetchFixedCosts()
            savingsGoals = try repository.fetchSavingsGoals()
            monthlyTrend = try repository.monthlyTrend(forDate: analysisDate, calendar: calendar)
            monthlyAnalysis = try repository.monthlyAnalysis(
                forDate: analysisDate,
                monthlyBudget: monthlyBudget,
                currency: currency,
                calendar: calendar
            )
            monthPlan = try repository.monthPlan(
                for: analysisDate,
                monthlyBudget: monthlyBudget,
                currency: currency,
                calendar: calendar
            )
            categoryTrends = monthlyAnalysis.categoryTrends
            categorySummaries = monthPlan?.categorySummaries ?? []
            weeklySummary = try repository.weeklySummary(
                forDate: selectedDate, weekStartsOn: settings.weekStartsOn, calendar: calendar)
            errorMessage = nil
        } catch {
            errorMessage = "Finanzdaten konnten nicht geladen werden."
        }
    }

    @discardableResult
    func createCategory(name: String) -> FinanceCategoryRecord? {
        guard let database else { return nil }

        do {
            let category = try FinanceRepository(database: database).createCategory(name: name)
            reload()
            return category
        } catch FinanceCategoryMutationError.duplicateName {
            errorMessage = "Diese Kategorie gibt es bereits."
            return nil
        } catch {
            errorMessage = "Kategorie konnte nicht erstellt werden."
            return nil
        }
    }

    @discardableResult
    func renameCategory(id: String, to newName: String) -> FinanceCategoryRecord? {
        guard let database else { return nil }

        do {
            let category = try FinanceRepository(database: database).renameCategory(id: id, to: newName)
            reload()
            return category
        } catch FinanceCategoryMutationError.duplicateName {
            errorMessage = "Diese Kategorie gibt es bereits."
            return nil
        } catch {
            errorMessage = "Kategorie konnte nicht umbenannt werden."
            return nil
        }
    }

    func deactivateCategory(id: String) {
        guard let database else { return }

        do {
            try FinanceRepository(database: database).deactivateCategory(id: id)
            reload()
        } catch {
            errorMessage = "Kategorie konnte nicht deaktiviert werden."
        }
    }

    @discardableResult
    func deleteCategorySafely(id: String) -> FinanceCategoryDeletionResult? {
        guard let database else { return nil }

        do {
            let result = try FinanceRepository(database: database).deleteCategorySafely(id: id)
            reload()
            return result
        } catch {
            errorMessage = "Kategorie konnte nicht gelöscht werden."
            return nil
        }
    }

    func suggestedCategory(for text: String) -> FinanceCategorySuggestion {
        FinanceCategoryCatalog.suggestedCategory(for: text, fallback: entries.first?.category)
    }

    func deleteEntry(id: FinanceEntryRecord.ID) {
        guard let database else { return }

        do {
            try FinanceRepository(database: database).delete(id: id)
            reload()
        } catch {
            errorMessage = "Ausgabe konnte nicht gelöscht werden."
        }
    }

    @discardableResult
    func saveCategoryBudget(category: String, amount: Double) -> Bool {
        guard let database else { return false }

        guard amount.isFinite, amount > 0, !category.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            errorMessage = "Bitte Kategorie und einen positiven Budgetbetrag eingeben."
            return false
        }
        do {
            try FinanceRepository(database: database).upsertCategoryBudget(
                monthKey: FinanceRepository.monthKey(for: selectedDate, calendar: calendar),
                category: category,
                amount: amount,
                currency: currency
            )
            reload()
            return true
        } catch {
            errorMessage = "Kategorie-Budget konnte nicht gespeichert werden."
            return false
        }
    }

    func deleteCategoryBudget(id: String) {
        guard let database else { return }

        do {
            try FinanceRepository(database: database).deleteCategoryBudget(id: id)
            reload()
        } catch {
            errorMessage = "Kategorie-Budget konnte nicht gelöscht werden."
        }
    }

    @discardableResult
    func saveFixedCost(title: String, amount: Double, category: String, dueDay: Int) -> Bool {
        guard let database else { return false }

        guard amount.isFinite, amount > 0, !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            errorMessage = "Bitte Titel und einen positiven Fixkostenbetrag eingeben."
            return false
        }
        do {
            try FinanceRepository(database: database).upsertFixedCost(
                FinanceFixedCostRecord(
                    title: title,
                    amount: amount,
                    currency: currency,
                    category: category,
                    dueDay: dueDay
                )
            )
            reload()
            return true
        } catch {
            errorMessage = "Fixkosten konnten nicht gespeichert werden."
            return false
        }
    }

    func toggleFixedCost(_ fixedCost: FinanceFixedCostRecord) {
        guard let database else { return }

        do {
            var updated = fixedCost
            updated.isActive.toggle()
            try FinanceRepository(database: database).upsertFixedCost(updated)
            reload()
        } catch {
            errorMessage = "Fixkosten konnten nicht aktualisiert werden."
        }
    }

    func deleteFixedCost(id: String) {
        guard let database else { return }

        do {
            try FinanceRepository(database: database).deleteFixedCost(id: id)
            reload()
        } catch {
            errorMessage = "Fixkosten konnten nicht gelöscht werden."
        }
    }

    @discardableResult
    func saveSavingsGoal(title: String, targetAmount: Double, currentAmount: Double) -> Bool {
        guard let database else { return false }

        guard targetAmount.isFinite, targetAmount > 0, currentAmount.isFinite, currentAmount >= 0,
            !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        else {
            errorMessage = "Bitte Zielname, positives Sparziel und einen gültigen aktuellen Betrag eingeben."
            return false
        }
        do {
            try FinanceRepository(database: database).upsertSavingsGoal(
                FinanceSavingsGoalRecord(
                    title: title,
                    targetAmount: targetAmount,
                    currentAmount: currentAmount,
                    currency: currency
                )
            )
            reload()
            return true
        } catch {
            errorMessage = "Sparziel konnte nicht gespeichert werden."
            return false
        }
    }

    func updateSavingsGoal(_ goal: FinanceSavingsGoalRecord, currentAmount: Double) {
        guard let database else { return }

        do {
            var updated = goal
            updated.currentAmount = currentAmount
            try FinanceRepository(database: database).upsertSavingsGoal(updated)
            reload()
        } catch {
            errorMessage = "Sparziel konnte nicht aktualisiert werden."
        }
    }

    func deleteSavingsGoal(id: String) {
        guard let database else { return }

        do {
            try FinanceRepository(database: database).deleteSavingsGoal(id: id)
            reload()
        } catch {
            errorMessage = "Sparziel konnte nicht gelöscht werden."
        }
    }

    func formatAmount(_ amount: Double) -> String {
        let safeAmount = amount.isFinite ? amount : 0
        return "\(Int(safeAmount.rounded())) \(currency)"
    }

    var previousMonthText: String {
        guard monthlyTrend.previousEntryCount > 0 else { return "keine Daten" }
        return formatAmount(monthlyTrend.previousSpent)
    }

    var spentChangeText: String {
        guard monthlyTrend.previousEntryCount > 0 else { return "kein Vergleich" }
        let change = monthlyTrend.spentChangeFromPrevious
        if abs(change) < 0.5 { return "+/-0 \(currency)" }
        let prefix = change > 0 ? "+" : "-"
        return "\(prefix)\(formatAmount(abs(change)))"
    }

    static func remainingBudget(spent: Double, budget: Double) -> Double {
        max(budget - spent, 0)
    }

    static func progress(spent: Double, budget: Double) -> Double {
        guard budget > 0 else { return 0 }
        return min(max(spent / budget, 0), 1)
    }

    static func dailyBudgetRemaining(
        spent: Double, budget: Double, date: Date = Date(), calendar: Calendar = .current, spentToday: Double = 0
    ) -> Double {
        let today = max(spentToday, 0)
        let allocation =
            max(budget - spent + today, 0) / Double(max(daysRemainingInMonth(for: date, calendar: calendar), 1))
        return max(allocation - today, 0)
    }

    private var daysRemainingInMonth: Int {
        let referenceDate = isCurrentMonth ? Date() : selectedDate
        return Self.daysRemainingInMonth(for: referenceDate, calendar: calendar)
    }

    private static func daysRemainingInMonth(for date: Date, calendar: Calendar = .current) -> Int {
        guard let interval = calendar.dateInterval(of: .month, for: date) else { return 1 }
        let referenceDate = date
        let start = calendar.startOfDay(for: referenceDate)
        let end = calendar.date(byAdding: .day, value: -1, to: interval.end) ?? interval.end
        let days = calendar.dateComponents([.day], from: start, to: end).day ?? 0
        return max(days + 1, 1)
    }
}
