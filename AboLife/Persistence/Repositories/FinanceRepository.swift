import Foundation
import GRDB

struct FinanceRepository {
    private let database: AppDatabase

    init(database: AppDatabase) {
        self.database = database
    }

    func insert(_ entry: FinanceEntryRecord) throws {
        var normalized = entry
        normalized.title = Self.trimmedOrDefault(normalized.title, defaultValue: "Ausgabe")
        normalized.amount = normalized.amount.isFinite ? normalized.amount : 0
        normalized.category = FinanceCategoryCatalog.normalized(normalized.category, kind: normalized.amount < 0 ? .income : .expense)
        normalized.updatedAt = Date()

        try database.writer.write { db in
            try normalized.insert(db)
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

    func monthlyAnalysis(forDate date: Date = Date(), monthlyBudget: Double, currency: String, calendar: Calendar = .current) throws -> FinanceMonthlyAnalysis {
        let currentInterval = DateIntervals.month(containing: date, calendar: calendar)
        let previousMonthDate = calendar.date(byAdding: .month, value: -1, to: currentInterval.start) ?? date
        let previousInterval = DateIntervals.month(containing: previousMonthDate, calendar: calendar)
        let previous2Date = calendar.date(byAdding: .month, value: -2, to: currentInterval.start) ?? date
        let previous3Date = calendar.date(byAdding: .month, value: -3, to: currentInterval.start) ?? date
        let currentEntries = try fetchEntries(in: currentInterval)
        let previousEntries = try fetchEntries(in: previousInterval)
        let previous2Entries = try fetchEntries(in: DateIntervals.month(containing: previous2Date, calendar: calendar))
        let previous3Entries = try fetchEntries(in: DateIntervals.month(containing: previous3Date, calendar: calendar))
        let fixedCosts = try fetchFixedCosts(activeOnly: true)
        let budgets = try fetchCategoryBudgets(monthKey: Self.monthKey(for: date, calendar: calendar))

        return Self.monthlyAnalysis(
            currentEntries: currentEntries,
            previousEntries: previousEntries,
            trailingMonthEntries: [previousEntries, previous2Entries, previous3Entries],
            fixedCosts: fixedCosts,
            budgets: budgets,
            monthlyBudget: monthlyBudget,
            currency: currency,
            monthInterval: currentInterval,
            referenceDate: date,
            calendar: calendar
        )
    }

    func categoryTrends(forDate date: Date = Date(), monthlyBudget _: Double = 0, calendar: Calendar = .current) throws -> [FinanceCategoryTrend] {
        let currentInterval = DateIntervals.month(containing: date, calendar: calendar)
        let previousMonthDate = calendar.date(byAdding: .month, value: -1, to: currentInterval.start) ?? date
        let previous2Date = calendar.date(byAdding: .month, value: -2, to: currentInterval.start) ?? date
        let previous3Date = calendar.date(byAdding: .month, value: -3, to: currentInterval.start) ?? date
        let currentEntries = try fetchEntries(in: currentInterval)
        let previousEntries = try fetchEntries(in: DateIntervals.month(containing: previousMonthDate, calendar: calendar))
        let previous2Entries = try fetchEntries(in: DateIntervals.month(containing: previous2Date, calendar: calendar))
        let previous3Entries = try fetchEntries(in: DateIntervals.month(containing: previous3Date, calendar: calendar))
        let budgets = try fetchCategoryBudgets(monthKey: Self.monthKey(for: date, calendar: calendar))
        return Self.categoryTrends(
            currentEntries: currentEntries,
            previousEntries: previousEntries,
            trailingMonthEntries: [previousEntries, previous2Entries, previous3Entries],
            budgets: budgets
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

    func fetchCategories(includeInactive: Bool = true, kind: FinanceCategoryKind = .expense) throws -> [FinanceCategoryRecord] {
        try database.writer.read { db in
            var request = FinanceCategoryRecord
                .filter(Column("kind") == kind.rawValue)
                .order(Column("is_active").desc, Column("sort_order"), Column("name"))
            if !includeInactive {
                request = request.filter(Column("is_active") == true)
            }
            return try request.fetchAll(db)
        }
    }

    func fetchActiveCategoryNames(kind: FinanceCategoryKind = .expense) throws -> [String] {
        let stored = try fetchCategories(includeInactive: false, kind: kind).map(\.name)
        return FinanceCategoryCatalog.mergedCategoryNames(primary: stored, fallback: FinanceCategoryCatalog.defaults(for: kind))
    }

    func fetchCategoryNamesIncludingLegacy(kind: FinanceCategoryKind = .expense) throws -> [String] {
        try database.writer.read { db in
            let stored = try FinanceCategoryRecord
                .filter(Column("kind") == kind.rawValue)
                .order(Column("is_active").desc, Column("sort_order"), Column("name"))
                .fetchAll(db)
                .map(\.name)
            let entryCategories = try String.fetchAll(db, sql: "SELECT DISTINCT category FROM finance_entries WHERE category IS NOT NULL AND TRIM(category) <> ''")
            let budgetCategories = try String.fetchAll(db, sql: "SELECT DISTINCT category FROM finance_category_budgets WHERE category IS NOT NULL AND TRIM(category) <> ''")
            let fixedCostCategories = try String.fetchAll(db, sql: "SELECT DISTINCT category FROM finance_fixed_costs WHERE category IS NOT NULL AND TRIM(category) <> ''")
            return FinanceCategoryCatalog.mergedCategoryNames(
                primary: stored + entryCategories + budgetCategories + fixedCostCategories,
                fallback: FinanceCategoryCatalog.defaults(for: kind)
            )
        }
    }

    @discardableResult
    func createCategory(name: String, kind: FinanceCategoryKind = .expense) throws -> FinanceCategoryRecord {
        let cleanName = FinanceCategoryCatalog.displayName(name)
        let key = FinanceCategoryCatalog.key(for: cleanName)
        let now = Date()

        return try database.writer.write { db in
            if var existing = try FinanceCategoryRecord
                .filter(Column("kind") == kind.rawValue && Column("normalized_key") == key)
                .fetchOne(db) {
                existing.name = cleanName
                existing.isActive = true
                existing.updatedAt = now
                try existing.update(db)
                return existing
            }

            let nextSortOrder = (try Int.fetchOne(db, sql: "SELECT COALESCE(MAX(sort_order), -1) + 1 FROM finance_categories WHERE kind = ?", arguments: [kind.rawValue]) ?? 0)
            let record = FinanceCategoryRecord(
                name: cleanName,
                normalizedKey: key,
                kind: kind.rawValue,
                isDefault: FinanceCategoryCatalog.isDefault(cleanName, kind: kind),
                isActive: true,
                sortOrder: nextSortOrder,
                createdAt: now,
                updatedAt: now
            )
            try record.insert(db)
            return record
        }
    }

    @discardableResult
    func renameCategory(id: String, to newName: String) throws -> FinanceCategoryRecord {
        let cleanName = FinanceCategoryCatalog.displayName(newName)
        let key = FinanceCategoryCatalog.key(for: cleanName)
        let now = Date()

        return try database.writer.write { db in
            guard var category = try FinanceCategoryRecord.fetchOne(db, key: id) else {
                throw FinanceCategoryMutationError.notFound
            }
            if let duplicate = try FinanceCategoryRecord
                .filter(Column("kind") == category.kind && Column("normalized_key") == key && Column("id") != id)
                .fetchOne(db) {
                guard duplicate.isActive else {
                    var updatedDuplicate = duplicate
                    updatedDuplicate.isActive = true
                    updatedDuplicate.updatedAt = now
                    try updatedDuplicate.update(db)
                    return updatedDuplicate
                }
                throw FinanceCategoryMutationError.duplicateName
            }
            category.name = cleanName
            category.normalizedKey = key
            category.isDefault = FinanceCategoryCatalog.isDefault(cleanName, kind: FinanceCategoryKind(rawValue: category.kind) ?? .expense)
            category.updatedAt = now
            try category.update(db)
            return category
        }
    }

    func deactivateCategory(id: String) throws {
        try database.writer.write { db in
            guard var category = try FinanceCategoryRecord.fetchOne(db, key: id) else {
                throw FinanceCategoryMutationError.notFound
            }
            category.isActive = false
            category.updatedAt = Date()
            try category.update(db)
        }
    }

    @discardableResult
    func deleteCategorySafely(id: String) throws -> FinanceCategoryDeletionResult {
        try database.writer.write { db in
            guard let category = try FinanceCategoryRecord.fetchOne(db, key: id) else {
                throw FinanceCategoryMutationError.notFound
            }
            let names = FinanceCategoryCatalog.matchingNames(for: category.name)
            let hasReferences = try Self.categoryHasReferences(names: names, db: db)
            if hasReferences {
                var archived = category
                archived.isActive = false
                archived.updatedAt = Date()
                try archived.update(db)
                return .deactivated
            }
            _ = try FinanceCategoryRecord.deleteOne(db, key: id)
            return .deleted
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
                entryCount: expenses.filter { FinanceCategoryCatalog.normalized($0.category, kind: .expense) == category }.count
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

    private static func categoryHasReferences(names: [String], db: Database) throws -> Bool {
        let normalizedNames = names.map { FinanceCategoryCatalog.normalized($0, kind: .expense) }
        let entryCategories = try String.fetchAll(db, sql: "SELECT category FROM finance_entries")
        let budgetCategories = try String.fetchAll(db, sql: "SELECT category FROM finance_category_budgets")
        let fixedCostCategories = try String.fetchAll(db, sql: "SELECT category FROM finance_fixed_costs")
        return (entryCategories + budgetCategories + fixedCostCategories).contains {
            normalizedNames.contains(FinanceCategoryCatalog.normalized($0, kind: .expense))
        }
    }

    static func monthlyAnalysis(
        currentEntries: [FinanceEntryRecord],
        previousEntries: [FinanceEntryRecord],
        trailingMonthEntries: [[FinanceEntryRecord]],
        fixedCosts: [FinanceFixedCostRecord],
        budgets: [FinanceCategoryBudgetRecord],
        monthlyBudget: Double,
        currency: String,
        monthInterval: DateInterval,
        referenceDate: Date,
        calendar: Calendar
    ) -> FinanceMonthlyAnalysis {
        let spent = expenseTotal(currentEntries)
        let income = incomeTotal(currentEntries)
        let previousSpent = expenseTotal(previousEntries)
        let elapsed = elapsedDays(in: monthInterval, referenceDate: referenceDate, calendar: calendar)
        let totalDays = max(calendar.dateComponents([.day], from: monthInterval.start, to: monthInterval.end).day ?? elapsed, elapsed)
        let daysRemaining = max(totalDays - elapsed, 0)
        let averageDailySpend = spent / Double(max(elapsed, 1))
        let remainingBudget = max(monthlyBudget - spent, 0)
        let availableDailySpend = remainingBudget / Double(max(daysRemaining + 1, 1))
        let remainingFixed = remainingFixedCosts(fixedCosts.filter(\.isActive), in: monthInterval, referenceDate: referenceDate, calendar: calendar)
        let projectedSpend = spent + remainingFixed + averageDailySpend * Double(daysRemaining)
        let activeExpenseDays = Set(currentEntries.filter { $0.amount >= 0 }.map { DateIntervals.dayKey(for: $0.occurredAt, calendar: calendar) }).count
        let categorySummaries = categorySummaries(entries: currentEntries, budgets: budgets)
        let topCategory = categorySummaries.first
        let largestExpense = currentEntries.filter { $0.amount >= 0 }.max { $0.amount < $1.amount }
        let categoryTrends = categoryTrends(currentEntries: currentEntries, previousEntries: previousEntries, trailingMonthEntries: trailingMonthEntries, budgets: budgets)
        let strongestIncrease = categoryTrends
            .filter { $0.previousSpent != nil && $0.changeFromPrevious > 0.5 }
            .max { $0.changeFromPrevious < $1.changeFromPrevious }
        let trailingExpenses = trailingMonthEntries.map(expenseTotal)
        let monthsWithData = trailingMonthEntries.filter { !$0.isEmpty }.count
        let trailingAverage = monthsWithData >= 3 ? trailingExpenses.reduce(0, +) / Double(trailingExpenses.count) : nil
        let savingsRate = income > 0 ? max((income - spent) / income, 0) : nil

        return FinanceMonthlyAnalysis(
            spent: spent,
            income: income,
            balance: income - spent,
            monthlyBudget: monthlyBudget,
            remainingBudget: remainingBudget,
            averageDailySpend: averageDailySpend,
            availableDailySpendUntilMonthEnd: availableDailySpend,
            projectedSpend: projectedSpend,
            previousMonthSpent: previousEntries.isEmpty ? nil : previousSpent,
            changeFromPreviousMonth: previousEntries.isEmpty ? nil : spent - previousSpent,
            trailingThreeMonthAverageSpent: trailingAverage,
            savingsRate: savingsRate,
            topCategory: topCategory,
            largestExpense: largestExpense,
            strongestCategoryIncrease: strongestIncrease,
            activeExpenseDays: activeExpenseDays,
            remainingFixedCosts: remainingFixed,
            categoryTrends: categoryTrends,
            entryCount: currentEntries.count,
            currency: currency
        )
    }

    static func categoryTrends(
        currentEntries: [FinanceEntryRecord],
        previousEntries: [FinanceEntryRecord],
        trailingMonthEntries: [[FinanceEntryRecord]],
        budgets: [FinanceCategoryBudgetRecord]
    ) -> [FinanceCategoryTrend] {
        let current = expensesByCategory(currentEntries)
        let previous = expensesByCategory(previousEntries)
        let trailing = trailingMonthEntries.map(expensesByCategory)
        let budgetByCategory = Dictionary(uniqueKeysWithValues: budgets.map { (FinanceCategoryCatalog.normalized($0.category, kind: .expense), $0.budgetAmount) })
        let total = max(current.values.reduce(0, +), 0)
        let categories = Set(current.keys)
            .union(previous.keys)
            .union(budgetByCategory.keys)

        return categories.map { category in
            let spent = current[category] ?? 0
            let previousSpent = previousEntries.isEmpty ? nil : previous[category] ?? 0
            let trailingValues = trailing.map { $0[category] ?? 0 }
            let trailingAverage = trailingMonthEntries.filter { !$0.isEmpty }.count >= 3 ? trailingValues.reduce(0, +) / Double(trailingValues.count) : nil
            let budget = budgetByCategory[category]
            return FinanceCategoryTrend(
                category: category,
                spent: spent,
                share: total > 0 ? spent / total : 0,
                previousSpent: previousSpent,
                trailingThreeMonthAverage: trailingAverage,
                budget: budget,
                entryCount: currentEntries.filter { FinanceCategoryCatalog.normalized($0.category, kind: .expense) == category && $0.amount >= 0 }.count
            )
        }
        .sorted { lhs, rhs in
            if lhs.spent == rhs.spent { return lhs.category < rhs.category }
            return lhs.spent > rhs.spent
        }
    }

    private static func expensesByCategory(_ entries: [FinanceEntryRecord]) -> [String: Double] {
        Dictionary(grouping: entries.filter { $0.amount >= 0 }, by: { FinanceCategoryCatalog.normalized($0.category, kind: .expense) })
            .mapValues { $0.reduce(0) { $0 + $1.amount } }
    }

    private static func trimmedOrDefault(_ value: String, defaultValue: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? defaultValue : trimmed
    }
}

enum FinanceCategoryKind: String {
    case expense
    case income
}

enum FinanceCategoryCatalog {
    static let defaultExpenseCategories = [
        "Lebensmittel",
        "Essen unterwegs",
        "Fixkosten",
        "Transport",
        "Freizeit",
        "Kleidung",
        "Gesundheit",
        "Technik",
        "Lernen",
        "Haushalt",
        "Geschenke",
        "Abos",
        "Sparen",
        "Sonstiges"
    ]

    static var expenseCategories: [String] { defaultExpenseCategories }

    static let defaultIncomeCategories = [
        "Gehalt",
        "Nebenjob",
        "Rückzahlung",
        "Geschenk",
        "Sonstiges"
    ]

    static var incomeCategories: [String] { defaultIncomeCategories }

    static func defaults(for kind: FinanceCategoryKind) -> [String] {
        kind == .expense ? defaultExpenseCategories : defaultIncomeCategories
    }

    static func normalized(_ category: String, kind: FinanceCategoryKind) -> String {
        let trimmed = displayName(category)
        guard !trimmed.isEmpty else { return "Sonstiges" }
        let normalized = key(for: trimmed)
        let aliases: [String: String] = [
            "essen": "Essen unterwegs",
            "restaurant": "Essen unterwegs",
            "essen unterwegs": "Essen unterwegs",
            "einkauf": "Lebensmittel",
            "supermarkt": "Lebensmittel",
            "lebensmittel": "Lebensmittel",
            "wohnen": "Fixkosten",
            "miete": "Fixkosten",
            "miete/wohnen": "Fixkosten",
            "miete wohnen": "Fixkosten",
            "training/fitness": "Gesundheit",
            "training fitness": "Gesundheit",
            "fitness": "Gesundheit",
            "sport": "Gesundheit",
            "abo": "Abos",
            "quick panel": "Sonstiges",
            "rueckzahlung": "Rückzahlung"
        ]
        if let mapped = aliases[normalized] {
            return mapped
        }
        let categories = defaults(for: kind)
        return categories.first { key(for: $0) == normalized } ?? trimmed
    }

    static func suggestedCategory(for text: String, fallback: String? = nil) -> FinanceCategorySuggestion {
        let cleanText = text.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "de_DE")).lowercased()
        let rules: [(category: String, keywords: [String])] = [
            ("Essen unterwegs", ["doner", "doener", "döner", "pizza", "burger", "restaurant", "imbiss", "kebab", "cafe", "kaffee"]),
            ("Lebensmittel", ["rewe", "edeka", "aldi", "lidl", "netto", "kaufland", "supermarkt", "dm", "rossmann"]),
            ("Fixkosten", ["miete", "strom", "internet", "handy", "versicherung", "rundfunk", "gez"]),
            ("Transport", ["bahn", "bus", "uber", "taxi", "benzin", "tanken", "db", "deutsche bahn", "ticket"]),
            ("Gesundheit", ["gym", "apotheke", "arzt", "zahnarzt", "medikament", "physio"]),
            ("Abos", ["netflix", "spotify", "notion", "abo", "subscription", "prime", "disney", "icloud"]),
            ("Technik", ["amazon", "apple", "hardware", "software", "mac", "iphone", "ipad"]),
            ("Lernen", ["buch", "kurs", "udemy", "coursera", "lernen", "fortbildung"])
        ]

        for rule in rules where rule.keywords.contains(where: { cleanText.contains($0) }) {
            return FinanceCategorySuggestion(category: rule.category, confidence: .rule, reason: "Lokale Regel")
        }

        if let fallback, !fallback.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return FinanceCategorySuggestion(category: normalized(fallback, kind: .expense), confidence: .fallback, reason: "Zuletzt verwendete Kategorie")
        }

        return FinanceCategorySuggestion(category: "Sonstiges", confidence: .fallback, reason: "Keine passende lokale Regel")
    }

    static func key(for value: String) -> String {
        value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "de_DE"))
            .lowercased()
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
    }

    static func displayName(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func isDefault(_ category: String, kind: FinanceCategoryKind) -> Bool {
        let categoryKey = key(for: category)
        return defaults(for: kind).contains { key(for: $0) == categoryKey }
    }

    static func matchingNames(for category: String) -> [String] {
        let normalizedName = normalized(category, kind: .expense)
        return Array(Set([category, normalizedName]))
    }

    static func mergedCategoryNames(primary: [String], fallback: [String]) -> [String] {
        var seen: Set<String> = []
        var result: [String] = []
        for name in primary + fallback {
            let clean = displayName(name)
            guard !clean.isEmpty else { continue }
            let key = key(for: clean)
            guard !seen.contains(key) else { continue }
            seen.insert(key)
            result.append(clean)
        }
        if !seen.contains(key(for: "Sonstiges")) {
            result.append("Sonstiges")
        }
        return result
    }
}

struct FinanceCategorySuggestion: Equatable {
    enum Confidence: Equatable {
        case rule
        case fallback
    }

    let category: String
    let confidence: Confidence
    let reason: String
}

enum FinanceCategoryMutationError: Error, Equatable {
    case notFound
    case duplicateName
}

enum FinanceCategoryDeletionResult: Equatable {
    case deleted
    case deactivated
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

struct FinanceCategoryTrend: Identifiable, Equatable {
    var id: String { category }
    let category: String
    let spent: Double
    let share: Double
    let previousSpent: Double?
    let trailingThreeMonthAverage: Double?
    let budget: Double?
    let entryCount: Int

    var changeFromPrevious: Double {
        spent - (previousSpent ?? 0)
    }

    var isOverBudget: Bool {
        guard let budget else { return false }
        return spent > budget
    }

    var hasPreviousComparison: Bool {
        previousSpent != nil
    }

    var hasThreeMonthTrend: Bool {
        trailingThreeMonthAverage != nil
    }
}

struct FinanceMonthlyAnalysis: Equatable {
    let spent: Double
    let income: Double
    let balance: Double
    let monthlyBudget: Double
    let remainingBudget: Double
    let averageDailySpend: Double
    let availableDailySpendUntilMonthEnd: Double
    let projectedSpend: Double
    let previousMonthSpent: Double?
    let changeFromPreviousMonth: Double?
    let trailingThreeMonthAverageSpent: Double?
    let savingsRate: Double?
    let topCategory: FinanceCategorySummary?
    let largestExpense: FinanceEntryRecord?
    let strongestCategoryIncrease: FinanceCategoryTrend?
    let activeExpenseDays: Int
    let remainingFixedCosts: Double
    let categoryTrends: [FinanceCategoryTrend]
    let entryCount: Int
    let currency: String

    var isForecastOverBudget: Bool {
        monthlyBudget > 0 && projectedSpend > monthlyBudget
    }

    var hasEnoughDataForPreviousMonthComparison: Bool {
        previousMonthSpent != nil
    }

    var hasEnoughDataForThreeMonthTrend: Bool {
        trailingThreeMonthAverageSpent != nil
    }

    static let empty = FinanceMonthlyAnalysis(
        spent: 0,
        income: 0,
        balance: 0,
        monthlyBudget: 0,
        remainingBudget: 0,
        averageDailySpend: 0,
        availableDailySpendUntilMonthEnd: 0,
        projectedSpend: 0,
        previousMonthSpent: nil,
        changeFromPreviousMonth: nil,
        trailingThreeMonthAverageSpent: nil,
        savingsRate: nil,
        topCategory: nil,
        largestExpense: nil,
        strongestCategoryIncrease: nil,
        activeExpenseDays: 0,
        remainingFixedCosts: 0,
        categoryTrends: [],
        entryCount: 0,
        currency: "EUR"
    )
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
