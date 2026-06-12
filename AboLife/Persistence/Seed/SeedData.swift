import Foundation

enum SeedData {
    static let defaultSettings = AppSettingsRecord(
        caloriesTarget: AppSettingsDefaults.caloriesTarget,
        proteinTargetG: Double(AppSettingsDefaults.proteinTargetG),
        weeklyWorkoutTarget: AppSettingsDefaults.weeklyWorkoutTarget,
        monthlyBudget: AppSettingsDefaults.monthlyBudget,
        defaultCurrency: AppSettingsDefaults.defaultCurrency,
        weekStartsOn: AppSettingsDefaults.weekStartsOn
    )
}
