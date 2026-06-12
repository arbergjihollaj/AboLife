import Foundation
import GRDB

struct AppSettingsRecord: Codable, FetchableRecord, PersistableRecord, Identifiable, Equatable {
    static let databaseTableName = "app_settings"
    static let defaultID = "settings"

    var id: String
    var caloriesTarget: Int
    var proteinTargetG: Double
    var weeklyWorkoutTarget: Int
    var monthlyBudget: Double
    var defaultCurrency: String
    var weekStartsOn: Int
    var createdAt: Date
    var updatedAt: Date

    init(
        id: String = AppSettingsRecord.defaultID,
        caloriesTarget: Int,
        proteinTargetG: Double,
        weeklyWorkoutTarget: Int = 3,
        monthlyBudget: Double,
        defaultCurrency: String = "EUR",
        weekStartsOn: Int = 2,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.caloriesTarget = caloriesTarget
        self.proteinTargetG = proteinTargetG
        self.weeklyWorkoutTarget = weeklyWorkoutTarget
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
        case weeklyWorkoutTarget = "weekly_workout_target"
        case monthlyBudget = "monthly_budget"
        case defaultCurrency = "default_currency"
        case weekStartsOn = "week_starts_on"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

enum AppSettingsDefaults {
    static let caloriesTarget = 2200
    static let proteinTargetG = 150
    static let weeklyWorkoutTarget = 3
    static let monthlyBudget: Double = 1200
    static let defaultCurrency = "EUR"
    static let weekStartsOn = 2
}

enum AppSettingsValidation {
    static func normalized(_ settings: AppSettingsRecord) -> AppSettingsRecord {
        AppSettingsRecord(
            id: AppSettingsRecord.defaultID,
            caloriesTarget: clamp(settings.caloriesTarget, min: 800, max: 6000),
            proteinTargetG: Double(clamp(Int(settings.proteinTargetG.rounded()), min: 20, max: 400)),
            weeklyWorkoutTarget: clamp(settings.weeklyWorkoutTarget, min: 0, max: 14),
            monthlyBudget: min(max(settings.monthlyBudget, 0), 100_000),
            defaultCurrency: AppSettingsDefaults.defaultCurrency,
            weekStartsOn: AppSettingsDefaults.weekStartsOn,
            createdAt: settings.createdAt,
            updatedAt: settings.updatedAt
        )
    }

    private static func clamp(_ value: Int, min minimum: Int, max maximum: Int) -> Int {
        Swift.min(Swift.max(value, minimum), maximum)
    }
}
