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

/// Optional, isolated presentation data. Never reads or copies a personal database.
enum DemoData {
    static var isEnabled: Bool {
        ProcessInfo.processInfo.environment["ABOLIFE_DEMO"] == "1" || Bundle.main.bundleIdentifier?.hasSuffix(".demo") == true
    }
    static func populate(_ database: AppDatabase, now: Date = Date()) throws {
        var settings = SeedData.defaultSettings
        settings.monthlyBudget = 600; settings.weeklyWorkoutTarget = 3
        try SettingsRepository(database: database).saveSettings(settings)
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Berlin")!
        let today = calendar.startOfDay(for: now)
        let habits = HabitRepository(database: database)
        for offset in -5...0 {
            let day = calendar.date(byAdding: .day, value: offset, to: today)!
            let key = DateIntervals.dayKey(for: day, calendar: calendar)
            try habits.setValue(habitKey: "water", date: key, value: offset == 0 ? 1.75 : 2.5, target: 3, unit: "Liter")
            try habits.setValue(habitKey: "learning", date: key, value: offset == 0 ? 30 : 60, target: 60, unit: "Min.")
            try habits.setValue(habitKey: "sleep", date: key, value: 1, target: 1, unit: "")
            try WeightRepository(database: database).upsert(dayKey: key, weightKg: 80 + Double(offset) * 0.1)
        }
        for (index, title) in ["Mittagessen", "Fachbuch", "Fahrkarte"].enumerated() {
            try FinanceRepository(database: database).insert(FinanceEntryRecord(occurredAt: calendar.date(byAdding: .day, value: -index, to: now)!, title: title, amount: [8.5, 24.9, 12.0][index], category: ["Essen unterwegs", "Lernen", "Transport"][index]))
        }
        try WorkoutRepository(database: database).insert(WorkoutSessionRecord(occurredAt: calendar.date(byAdding: .day, value: -1, to: now)!, workoutType: "Full Body", durationMin: 30, status: "done"))
        var workspace = CalendarWorkspace()
        workspace.preferences.timeZoneID = "Europe/Berlin"
        workspace.preferences.weekdays = Set(1...7)
        workspace.events = [PlannerEvent(title: "Softwareentwicklung", kind: .university, start: today.addingTimeInterval(9 * 3600), end: today.addingTimeInterval(11 * 3600), location: "university", timeZoneID: "Europe/Berlin", weekly: true)]
        workspace.topics = [StudyTopic(title: "Datenstrukturen wiederholen", course: "Informatik", nextReview: now), StudyTopic(title: "Übungsaufgaben", course: "Mathematik", nextReview: now)]
        let plan = StudyPlannerEngine.plan(workspace, now: now)
        workspace.topics = plan.topics; workspace.sessions = plan.sessions
        try CalendarRepository(database: database).save(workspace)
    }
}
