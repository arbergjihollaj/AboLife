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
    var targetWeightKg: Double?
    var targetWeightLowerKg: Double?
    var targetWeightUpperKg: Double?
    var morningReminderMinuteOfDay: Int
    var trainingReminderMinuteOfDay: Int
    var eveningReminderMinuteOfDay: Int
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
        targetWeightKg: Double? = nil,
        targetWeightLowerKg: Double? = nil,
        targetWeightUpperKg: Double? = nil,
        morningReminderMinuteOfDay: Int = AppSettingsDefaults.morningReminderMinuteOfDay,
        trainingReminderMinuteOfDay: Int = AppSettingsDefaults.trainingReminderMinuteOfDay,
        eveningReminderMinuteOfDay: Int = AppSettingsDefaults.eveningReminderMinuteOfDay,
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
        self.targetWeightKg = targetWeightKg
        self.targetWeightLowerKg = targetWeightLowerKg
        self.targetWeightUpperKg = targetWeightUpperKg
        self.morningReminderMinuteOfDay = morningReminderMinuteOfDay
        self.trainingReminderMinuteOfDay = trainingReminderMinuteOfDay
        self.eveningReminderMinuteOfDay = eveningReminderMinuteOfDay
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
        case targetWeightKg = "target_weight_kg"
        case targetWeightLowerKg = "target_weight_lower_kg"
        case targetWeightUpperKg = "target_weight_upper_kg"
        case morningReminderMinuteOfDay = "morning_reminder_minute_of_day"
        case trainingReminderMinuteOfDay = "training_reminder_minute_of_day"
        case eveningReminderMinuteOfDay = "evening_reminder_minute_of_day"
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
    static let morningReminderMinuteOfDay = 9 * 60
    static let trainingReminderMinuteOfDay = 17 * 60
    static let eveningReminderMinuteOfDay = 21 * 60
}

enum AppSettingsValidation {
    static func normalized(_ settings: AppSettingsRecord) -> AppSettingsRecord {
        AppSettingsRecord(
            id: AppSettingsRecord.defaultID,
            caloriesTarget: clamp(settings.caloriesTarget, min: 800, max: 6000),
            proteinTargetG: Double(clamp(Int(settings.proteinTargetG.rounded()), min: 20, max: 400)),
            weeklyWorkoutTarget: clamp(settings.weeklyWorkoutTarget, min: 0, max: 14),
            monthlyBudget: settings.monthlyBudget.isFinite ? min(max(settings.monthlyBudget, 0), 100_000) : 0,
            defaultCurrency: AppSettingsDefaults.defaultCurrency,
            weekStartsOn: AppSettingsDefaults.weekStartsOn,
            targetWeightKg: normalizedWeight(settings.targetWeightKg),
            targetWeightLowerKg: normalizedWeight(settings.targetWeightLowerKg),
            targetWeightUpperKg: normalizedWeight(settings.targetWeightUpperKg),
            morningReminderMinuteOfDay: normalizedMinuteOfDay(settings.morningReminderMinuteOfDay, defaultValue: AppSettingsDefaults.morningReminderMinuteOfDay),
            trainingReminderMinuteOfDay: normalizedMinuteOfDay(settings.trainingReminderMinuteOfDay, defaultValue: AppSettingsDefaults.trainingReminderMinuteOfDay),
            eveningReminderMinuteOfDay: normalizedMinuteOfDay(settings.eveningReminderMinuteOfDay, defaultValue: AppSettingsDefaults.eveningReminderMinuteOfDay),
            createdAt: settings.createdAt,
            updatedAt: settings.updatedAt
        ).normalizedWeightCorridor()
    }

    private static func clamp(_ value: Int, min minimum: Int, max maximum: Int) -> Int {
        Swift.min(Swift.max(value, minimum), maximum)
    }

    private static func normalizedWeight(_ value: Double?) -> Double? {
        guard let value, value.isFinite, value >= 20, value <= 300 else { return nil }
        return (value * 10).rounded() / 10
    }

    private static func normalizedMinuteOfDay(_ value: Int, defaultValue: Int) -> Int {
        (0..<24 * 60).contains(value) ? value : defaultValue
    }
}

private extension AppSettingsRecord {
    func normalizedWeightCorridor() -> AppSettingsRecord {
        var copy = self
        if let lower = copy.targetWeightLowerKg,
           let upper = copy.targetWeightUpperKg,
           lower > upper {
            copy.targetWeightLowerKg = upper
            copy.targetWeightUpperKg = lower
        }
        return copy
    }
}
