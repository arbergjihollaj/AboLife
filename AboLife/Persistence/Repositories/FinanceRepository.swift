import Foundation
import GRDB

struct FinanceRepository {
    private let database: AppDatabase

    init(database: AppDatabase) {
        self.database = database
    }

    func insert(_ entry: FinanceEntryRecord) throws {
        try database.writer.write { db in
            try entry.insert(db)
        }
    }

    func fetchAll() throws -> [FinanceEntryRecord] {
        try database.writer.read { db in
            try FinanceEntryRecord
                .order(Column("occurred_at").desc)
                .fetchAll(db)
        }
    }

    func fetch(in interval: DateInterval) throws -> [FinanceEntryRecord] {
        try database.writer.read { db in
            try FinanceEntryRecord
                .filter(Column("occurred_at") >= interval.start && Column("occurred_at") < interval.end)
                .order(Column("occurred_at").desc)
                .fetchAll(db)
        }
    }

    func fetchEntries(forMonthContaining date: Date = Date(), calendar: Calendar = .current) throws -> [FinanceEntryRecord] {
        try fetchEntries(in: DateIntervals.month(containing: date, calendar: calendar))
    }

    func fetchEntries(in interval: DateInterval) throws -> [FinanceEntryRecord] {
        try fetch(in: interval)
    }

    func fetchEntries(forWeekContaining date: Date = Date(), weekStartsOn: Int = 2, calendar: Calendar = .current) throws -> [FinanceEntryRecord] {
        try fetchEntries(in: DateIntervals.week(containing: date, weekStartsOn: weekStartsOn, calendar: calendar))
    }

    func monthSpending(for date: Date = Date(), calendar: Calendar = .current) throws -> Double {
        let entries = try fetchEntries(forMonthContaining: date, calendar: calendar)
        return Self.expenseTotal(entries)
    }

    func monthlySummary(forDate date: Date = Date(), calendar: Calendar = .current) throws -> FinanceMonthlySummary {
        let entries = try fetchEntries(forMonthContaining: date, calendar: calendar)

        return FinanceMonthlySummary(
            spent: Self.expenseTotal(entries),
            income: Self.incomeTotal(entries),
            entryCount: entries.count
        )
    }

    func monthlyTrend(forDate date: Date = Date(), calendar: Calendar = .current) throws -> FinanceMonthlyTrend {
        let currentInterval = DateIntervals.month(containing: date, calendar: calendar)
        let previousMonthDate = calendar.date(byAdding: .month, value: -1, to: currentInterval.start) ?? date
        let previousInterval = DateIntervals.month(containing: previousMonthDate, calendar: calendar)
        let currentEntries = try fetchEntries(in: currentInterval)
        let previousEntries = try fetchEntries(in: previousInterval)
        return Self.monthlyTrend(
            currentEntries: currentEntries,
            previousEntries: previousEntries,
            monthInterval: currentInterval,
            referenceDate: date,
            calendar: calendar
        )
    }

    func weeklySummary(in interval: DateInterval) throws -> FinanceWeeklySummary {
        let entries = try fetchEntries(in: interval)

        return FinanceWeeklySummary(
            spent: Self.expenseTotal(entries),
            income: Self.incomeTotal(entries),
            entryCount: entries.count,
            topCategory: Self.categorySummaries(entries: entries, budgets: []).first?.category
        )
    }

    func weeklySummary(forDate date: Date = Date(), weekStartsOn: Int = 2, calendar: Calendar = .current) throws -> FinanceWeeklySummary {
        try weeklySummary(in: DateIntervals.week(containing: date, weekStartsOn: weekStartsOn, calendar: calendar))
    }

    func delete(id: String) throws {
        try database.writer.write { db in
            _ = try FinanceEntryRecord.deleteOne(db, key: id)
        }
    }

    func deleteAll() throws {
        try database.writer.write { db in
            _ = try FinanceEntryRecord.deleteAll(db)
        }
    }

    func fetchCategoryBudgets(monthKey: String) throws -> [FinanceCategoryBudgetRecord] {
        try database.writer.read { db in
            try FinanceCategoryBudgetRecord
                .filter(Column("month_key") == monthKey)
                .order(Column("category"))
                .fetchAll(db)
        }
    }

    func upsertCategoryBudget(monthKey: String, category: String, amount: Double, currency: String) throws {
        let cleanCategory = FinanceCategoryCatalog.normalized(category, kind: .expense)
        let safeAmount = max(amount.isFinite ? amount : 0, 0)
        let now = Date()

        try database.writer.write { db in
            if var existing = try FinanceCategoryBudgetRecord
                .filter(Column("month_key") == monthKey && Column("category") == cleanCategory)
                .fetchOne(db) {
                existing.budgetAmount = safeAmount
                existing.currency = currency
                existing.updatedAt = now
                try existing.update(db)
            } else {
                try FinanceCategoryBudgetRecord(
                    monthKey: monthKey,
                    category: cleanCategory,
                    budgetAmount: safeAmount,
                    currency: currency,
                    createdAt: now,
                    updatedAt: now
                ).insert(db)
            }
        }
    }

    func deleteCategoryBudget(id: String) throws {
        try database.writer.write { db in
            _ = try FinanceCategoryBudgetRecord.deleteOne(db, key: id)
        }
    }

    func fetchFixedCosts(activeOnly: Bool = false) throws -> [FinanceFixedCostRecord] {
        try database.writer.read { db in
            var request = FinanceFixedCostRecord.order(Column("due_day"), Column("title"))
            if activeOnly {
                request = request.filter(Column("is_active") == true)
            }
            return try request.fetchAll(db)
        }
    }

    func upsertFixedCost(_ fixedCost: FinanceFixedCostRecord) throws {
        var normalized = fixedCost
        normalized.title = Self.trimmedOrDefault(normalized.title, defaultValue: "Fixkosten")
        normalized.category = FinanceCategoryCatalog.normalized(normalized.category, kind: .expense)
        normalized.amount = max(normalized.amount.isFinite ? normalized.amount : 0, 0)
        normalized.dueDay = min(max(normalized.dueDay, 1), 31)
        normalized.updatedAt = Date()

        try database.writer.write { db in
            try normalized.save(db)
        }
    }

    func deleteFixedCost(id: String) throws {
        try database.writer.write { db in
            _ = try FinanceFixedCostRecord.deleteOne(db, key: id)
        }
    }

    func fetchSavingsGoals(activeOnly: Bool = false) throws -> [FinanceSavingsGoalRecord] {
        try database.writer.read { db in
            var request = FinanceSavingsGoalRecord.order(Column("is_active").desc, Column("target_date"), Column("title"))
            if activeOnly {
                request = request.filter(Column("is_active") == true)
            }
            return try request.fetchAll(db)
        }
    }

    func upsertSavingsGoal(_ goal: FinanceSavingsGoalRecord) throws {
        var normalized = goal
        normalized.title = Self.trimmedOrDefault(normalized.title, defaultValue: "Sparziel")
        normalized.targetAmount = max(normalized.targetAmount.isFinite ? normalized.targetAmount : 0, 0)
        normalized.currentAmount = max(normalized.currentAmount.isFinite ? normalized.currentAmount : 0, 0)
        normalized.updatedAt = Date()

        try database.writer.write { db in
            try normalized.save(db)
        }
    }

    func deleteSavingsGoal(id: String) throws {
        try database.writer.write { db in
            _ = try FinanceSavingsGoalRecord.deleteOne(db, key: id)
        }
    }

    func categorySummaries(forMonthContaining date: Date = Date(), calendar: Calendar = .current) throws -> [FinanceCategorySummary] {
        let entries = try fetchEntries(forMonthContaining: date, calendar: calendar)
        let budgets = try fetchCategoryBudgets(monthKey: Self.monthKey(for: date, calendar: calendar))
        return Self.categorySummaries(entries: entries, budgets: budgets)
    }

    func monthPlan(for date: Date = Date(), monthlyBudget: Double, currency: String, calendar: Calendar = .current) throws -> FinanceMonthPlan {
        let interval = DateIntervals.month(containing: date, calendar: calendar)
        let entries = try fetchEntries(in: interval)
        let fixedCosts = try fetchFixedCosts(activeOnly: true)
        let budgets = try fetchCategoryBudgets(monthKey: Self.monthKey(for: date, calendar: calendar))
        let summaries = Self.categorySummaries(entries: entries, budgets: budgets)
        let spent = Self.expenseTotal(entries)
        let income = Self.incomeTotal(entries)
        let plannedFixedCosts = fixedCosts.reduce(0) { $0 + $1.amount }
        let remainingFixedCosts = Self.remainingFixedCosts(fixedCosts, in: interval, referenceDate: date, calendar: calendar)
        let forecast = Self.forecast(entries: entries, fixedCostsRemaining: remainingFixedCosts, interval: interval, referenceDate: date, calendar: calendar)

        return FinanceMonthPlan(
            spent: spent,
            income: income,
            monthlyBudget: monthlyBudget,
            currency: currency,
            plannedFixedCosts: plannedFixedCosts,
            remainingFixedCosts: remainingFixedCosts,
            forecastSpend: forecast,
            categorySummaries: summaries
        )
    }

    static func monthKey(for date: Date = Date(), calendar: Calendar = .current) -> String {
        String(DateIntervals.dayKey(for: date, calendar: calendar).prefix(7))
    }

    static func expenseTotal(_ entries: [FinanceEntryRecord]) -> Double {
        entries.filter { $0.amount >= 0 }.reduce(0) { $0 + $1.amount }
    }

    static func incomeTotal(_ entries: [FinanceEntryRecord]) -> Double {
        entries.filter { $0.amount < 0 }.reduce(0) { $0 + abs($1.amount) }
    }

    static func categorySummaries(entries: [FinanceEntryRecord], budgets: [FinanceCategoryBudgetRecord]) -> [FinanceCategorySummary] {
        let expenses = entries.filter { $0.amount >= 0 }
        let spentByCategory = Dictionary(grouping: expenses, by: { FinanceCategoryCatalog.normalized($0.category, kind: .expense) })
            .mapValues { $0.reduce(0) { $0 + $1.amount } }
        let budgetByCategory = Dictionary(uniqueKeysWithValues: budgets.map { (FinanceCategoryCatalog.normalized($0.category, kind: .expense), $0.budgetAmount) })
        let categories = Set(spentByCategory.keys).union(budgetByCategory.keys)

        return categories.map { category in
            FinanceCategorySummary(
                category: FinanceCategoryCatalog.normalized(category, kind: .expense),
                spent: spentByCategory[category] ?? 0,
                budget: budgetByCategory[category],
                entryCount: expenses.filter { trimmedOrDefault($0.category, defaultValue: "Sonstiges") == category }.count
            )
        }
        .sorted { lhs, rhs in
            if lhs.spent == rhs.spent { return lhs.category < rhs.category }
            return lhs.spent > rhs.spent
        }
    }

    private static func forecast(
        entries: [FinanceEntryRecord],
        fixedCostsRemaining: Double,
        interval: DateInterval,
        referenceDate: Date,
        calendar: Calendar
    ) -> Double {
        let spent = expenseTotal(entries)
        let today = calendar.startOfDay(for: referenceDate)
        let elapsed = max((calendar.dateComponents([.day], from: interval.start, to: today).day ?? 0) + 1, 1)
        let monthDays = max(calendar.dateComponents([.day], from: interval.start, to: interval.end).day ?? elapsed, elapsed)
        let remainingDays = max(monthDays - elapsed, 0)
        let avgDaily = spent / Double(elapsed)
        return spent + fixedCostsRemaining + avgDaily * Double(remainingDays)
    }

    static func monthlyTrend(
        currentEntries: [FinanceEntryRecord],
        previousEntries: [FinanceEntryRecord],
        monthInterval: DateInterval,
        referenceDate: Date,
        calendar: Calendar
    ) -> FinanceMonthlyTrend {
        let spent = expenseTotal(currentEntries)
        let income = incomeTotal(currentEntries)
        let previousSpent = expenseTotal(previousEntries)
        let previousIncome = incomeTotal(previousEntries)
        let elapsedDays = elapsedDays(in: monthInterval, referenceDate: referenceDate, calendar: calendar)
        let totalDays = max(calendar.dateComponents([.day], from: monthInterval.start, to: monthInterval.end).day ?? elapsedDays, elapsedDays)
        let averageDailySpend = spent / Double(max(elapsedDays, 1))
        let projectedSpend = averageDailySpend * Double(totalDays)

        return FinanceMonthlyTrend(
            spent: spent,
            income: income,
            balance: income - spent,
            savings: max(income - spent, 0),
            previousSpent: previousSpent,
            previousIncome: previousIncome,
            averageDailySpend: averageDailySpend,
            projectedSpend: projectedSpend,
            entryCount: currentEntries.count,
            previousEntryCount: previousEntries.count
        )
    }

    private static func elapsedDays(in interval: DateInterval, referenceDate: Date, calendar: Calendar) -> Int {
        let clampedReference = min(max(referenceDate, interval.start), calendar.date(byAdding: .second, value: -1, to: interval.end) ?? referenceDate)
        let today = calendar.startOfDay(for: clampedReference)
        return max((calendar.dateComponents([.day], from: interval.start, to: today).day ?? 0) + 1, 1)
    }

    private static func remainingFixedCosts(
        _ fixedCosts: [FinanceFixedCostRecord],
        in interval: DateInterval,
        referenceDate: Date,
        calendar: Calendar
    ) -> Double {
        let currentDay = calendar.component(.day, from: referenceDate)
        return fixedCosts.reduce(0) { result, cost in
            let dueDay = min(max(cost.dueDay, 1), 31)
            guard dueDay >= currentDay else { return result }
            return result + cost.amount
        }
    }

    private static func trimmedOrDefault(_ value: String, defaultValue: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? defaultValue : trimmed
    }
}

enum FinanceCategoryKind {
    case expense
    case income
}

enum FinanceCategoryCatalog {
    static let expenseCategories = [
        "Lebensmittel",
        "Essen unterwegs",
        "Fixkosten",
        "Miete/Wohnen",
        "Transport",
        "Gesundheit",
        "Training/Fitness",
        "Kleidung",
        "Freizeit",
        "Abos",
        "Technik",
        "Sonstiges"
    ]

    static let incomeCategories = [
        "Gehalt",
        "Nebenjob",
        "Rückzahlung",
        "Geschenk",
        "Sonstiges"
    ]

    static func normalized(_ category: String, kind: FinanceCategoryKind) -> String {
        let trimmed = category.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "Sonstiges" }
        let normalized = trimmed.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "de_DE")).lowercased()
        let aliases: [String: String] = [
            "essen": "Essen unterwegs",
            "restaurant": "Essen unterwegs",
            "einkauf": "Lebensmittel",
            "haushalt": "Lebensmittel",
            "wohnen": "Miete/Wohnen",
            "miete": "Miete/Wohnen",
            "fitness": "Training/Fitness",
            "sport": "Training/Fitness",
            "quick panel": "Sonstiges",
            "rueckzahlung": "Rückzahlung"
        ]
        if let mapped = aliases[normalized] {
            return mapped
        }
        let categories = kind == .expense ? expenseCategories : incomeCategories
        return categories.first { $0.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "de_DE")).lowercased() == normalized } ?? trimmed
    }
}

struct FinanceMonthlySummary: Equatable {
    let spent: Double
    let income: Double
    let entryCount: Int
}

struct FinanceMonthlyTrend: Equatable {
    let spent: Double
    let income: Double
    let balance: Double
    let savings: Double
    let previousSpent: Double
    let previousIncome: Double
    let averageDailySpend: Double
    let projectedSpend: Double
    let entryCount: Int
    let previousEntryCount: Int

    var spentChangeFromPrevious: Double {
        spent - previousSpent
    }

    static let empty = FinanceMonthlyTrend(
        spent: 0,
        income: 0,
        balance: 0,
        savings: 0,
        previousSpent: 0,
        previousIncome: 0,
        averageDailySpend: 0,
        projectedSpend: 0,
        entryCount: 0,
        previousEntryCount: 0
    )
}

struct FinanceWeeklySummary: Equatable {
    let spent: Double
    let income: Double
    let entryCount: Int
    let topCategory: String?
}

struct FinanceCategorySummary: Identifiable, Equatable {
    var id: String { category }
    let category: String
    let spent: Double
    let budget: Double?
    let entryCount: Int

    var progress: Double {
        guard let budget, budget > 0 else { return 0 }
        return min(max(spent / budget, 0), 1)
    }

    var isOverBudget: Bool {
        guard let budget else { return false }
        return spent > budget
    }
}

struct FinanceMonthPlan: Equatable {
    let spent: Double
    let income: Double
    let monthlyBudget: Double
    let currency: String
    let plannedFixedCosts: Double
    let remainingFixedCosts: Double
    let forecastSpend: Double
    let categorySummaries: [FinanceCategorySummary]

    var remainingBudget: Double {
        max(monthlyBudget - spent, 0)
    }

    var forecastDelta: Double {
        forecastSpend - monthlyBudget
    }

    var isForecastOverBudget: Bool {
        monthlyBudget > 0 && forecastSpend > monthlyBudget
    }
}
