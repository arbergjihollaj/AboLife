import Foundation
import GRDB

struct AppSettingsRecord: Codable, FetchableRecord, PersistableRecord, Identifiable, Equatable {
    static let databaseTableName = "app_settings"
    static let defaultID = "settings"

    var id: String
    var caloriesTarget: Int
    var proteinTargetG: Double
    var monthlyBudget: Double
    var defaultCurrency: String
    var weekStartsOn: Int
    var createdAt: Date
    var updatedAt: Date

    init(
        id: String = AppSettingsRecord.defaultID,
        caloriesTarget: Int,
        proteinTargetG: Double,
        monthlyBudget: Double,
        defaultCurrency: String = "EUR",
        weekStartsOn: Int = 2,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.caloriesTarget = caloriesTarget
        self.proteinTargetG = proteinTargetG
        self.monthlyBudget = monthlyBudget
        self.defaultCurrency = defaultCurrency
        self.weekStartsOn = weekStartsOn
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    enum CodingKeys: String, CodingKey {
        case id
        case caloriesTarget = "calories_target"
        case proteinTargetG = "protein_target_g"
        case monthlyBudget = "monthly_budget"
        case defaultCurrency = "default_currency"
        case weekStartsOn = "week_starts_on"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}
