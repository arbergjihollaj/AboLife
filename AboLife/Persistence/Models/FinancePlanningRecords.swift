import Foundation
import GRDB

struct FinanceCategoryBudgetRecord: Codable, FetchableRecord, PersistableRecord, Identifiable, Equatable {
    static let databaseTableName = "finance_category_budgets"

    var id: String
    var monthKey: String
    var category: String
    var budgetAmount: Double
    var currency: String
    var createdAt: Date
    var updatedAt: Date

    init(
        id: String = UUID().uuidString,
        monthKey: String,
        category: String,
        budgetAmount: Double,
        currency: String = "EUR",
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.monthKey = monthKey
        self.category = category
        self.budgetAmount = budgetAmount
        self.currency = currency
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    enum CodingKeys: String, CodingKey {
        case id
        case monthKey = "month_key"
        case category
        case budgetAmount = "budget_amount"
        case currency
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

struct FinanceFixedCostRecord: Codable, FetchableRecord, PersistableRecord, Identifiable, Equatable {
    static let databaseTableName = "finance_fixed_costs"

    var id: String
    var title: String
    var amount: Double
    var currency: String
    var category: String
    var dueDay: Int
    var isActive: Bool
    var note: String?
    var createdAt: Date
    var updatedAt: Date

    init(
        id: String = UUID().uuidString,
        title: String,
        amount: Double,
        currency: String = "EUR",
        category: String = "Fixkosten",
        dueDay: Int = 1,
        isActive: Bool = true,
        note: String? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.amount = amount
        self.currency = currency
        self.category = category
        self.dueDay = dueDay
        self.isActive = isActive
        self.note = note
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    enum CodingKeys: String, CodingKey {
        case id
        case title
        case amount
        case currency
        case category
        case dueDay = "due_day"
        case isActive = "is_active"
        case note
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

struct FinanceSavingsGoalRecord: Codable, FetchableRecord, PersistableRecord, Identifiable, Equatable {
    static let databaseTableName = "finance_savings_goals"

    var id: String
    var title: String
    var targetAmount: Double
    var currentAmount: Double
    var currency: String
    var targetDate: Date?
    var isActive: Bool
    var note: String?
    var createdAt: Date
    var updatedAt: Date

    init(
        id: String = UUID().uuidString,
        title: String,
        targetAmount: Double,
        currentAmount: Double = 0,
        currency: String = "EUR",
        targetDate: Date? = nil,
        isActive: Bool = true,
        note: String? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.targetAmount = targetAmount
        self.currentAmount = currentAmount
        self.currency = currency
        self.targetDate = targetDate
        self.isActive = isActive
        self.note = note
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    var progress: Double {
        guard targetAmount > 0 else { return 0 }
        return min(max(currentAmount / targetAmount, 0), 1)
    }

    enum CodingKeys: String, CodingKey {
        case id
        case title
        case targetAmount = "target_amount"
        case currentAmount = "current_amount"
        case currency
        case targetDate = "target_date"
        case isActive = "is_active"
        case note
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}
