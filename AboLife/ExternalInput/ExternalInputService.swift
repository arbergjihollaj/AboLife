import Foundation

struct ExternalInputService {
    let database: AppDatabase
    var calendar: Calendar = .current
    var now: () -> Date = Date.init

    func execute(_ intent: ExternalInputIntent) -> ExternalInputResult {
        do {
            switch intent {
            case let .weight(date, weightKg):
                return try saveWeight(date: date, weightKg: weightKg)
            case .weightStatus:
                return try weightStatus()
            case let .weightTarget(weightKg):
                return try saveWeightTarget(weightKg: weightKg)
            case let .weightCorridor(lowerKg, upperKg):
                return try saveWeightCorridor(lowerKg: lowerKg, upperKg: upperKg)
            case let .expense(date, amount, title, category):
                return try saveExpense(date: date, amount: amount, title: title, category: category)
            case let .meal(date, name, calories, protein, note):
                return try saveMeal(date: date, name: name, calories: calories, protein: protein, note: note)
            case let .mealTemplate(date, templateId):
                return try saveTemplateMeal(date: date, templateId: templateId)
            case let .workoutCompleted(date, note):
                return try saveWorkout(date: date, note: note)
            case let .habitCompleted(date, habitName):
                return try saveHabit(date: date, habitName: habitName)
            case .start, .help:
                return .menu(message: "Was möchtest du eintragen?", actions: ExternalInputAction.mainMenu)
            case .cancel:
                return .success(message: "Abgebrochen.", affectedModule: .menu)
            case let .unknown(_, reason):
                return .failure(message: reason, reason: "unknown")
            }
        } catch {
            return .failure(message: "Das konnte nicht gespeichert werden. Bitte prüfe die Eingabe und versuche es erneut.", reason: "persistence")
        }
    }

    func templates(limit: Int = 10) -> [ExternalInputAction] {
        let rows = (try? NutritionTemplateRepository(database: database).fetchAll()) ?? []
        return rows.prefix(limit).map { template in
            ExternalInputAction(
                id: "template.\(template.id)",
                label: Self.shortLabel(template.name),
                kind: .selectTemplate(id: template.id)
            )
        }
    }

    func habits(limit: Int = 10) -> [ExternalInputAction] {
        FixedHabit.defaults
            .filter { !$0.isDerived }
            .prefix(limit)
            .map { habit in
                ExternalInputAction(
                    id: "habit.\(habit.key)",
                    label: Self.shortLabel(habit.title),
                    kind: .selectHabit(name: habit.title)
                )
            }
    }

    func nutritionDayStatus(for date: Date = Date()) -> String {
        do {
            let settings = try SettingsRepository(database: database).loadSettings()
            let summary = try NutritionRepository(database: database).daySummary(for: date, calendar: calendar)
            return """
            Heute:
            \(summary.caloriesKcal) / \(settings.caloriesTarget) kcal
            \(ExternalInputFormatting.decimal(summary.proteinG, maximumFractionDigits: 0)) / \(ExternalInputFormatting.decimal(settings.proteinTargetG, maximumFractionDigits: 0)) g Protein
            """
        } catch {
            return ""
        }
    }

    private func saveWeight(date: Date, weightKg: Double) throws -> ExternalInputResult {
        guard weightKg.isFinite, weightKg >= 20, weightKg <= 300 else {
            return .failure(message: "Bitte gib ein plausibles Gewicht zwischen 20 und 300 kg ein.", reason: "invalid_weight")
        }
        _ = try WeightRepository(database: database).upsert(date: date, weightKg: weightKg, calendar: calendar)
        return .success(
            message: "Gewicht für heute gespeichert: \(ExternalInputFormatting.decimal(weightKg, maximumFractionDigits: 1)) kg.",
            affectedModule: .weight
        )
    }

    private func weightStatus() throws -> ExternalInputResult {
        let settings = try SettingsRepository(database: database).loadSettings()
        let latest = try WeightRepository(database: database).latest()
        let summary = WeightGoalSummary(
            currentWeightKg: latest?.weightKg,
            targetWeightKg: settings.targetWeightKg,
            lowerBoundKg: settings.targetWeightLowerKg,
            upperBoundKg: settings.targetWeightUpperKg
        )
        let current = latest.map { "Aktuell: \(ExternalInputFormatting.decimal($0.weightKg, maximumFractionDigits: 1)) kg" } ?? "Aktuell: noch kein Gewicht"
        let target = settings.targetWeightKg.map { "Ziel: \(ExternalInputFormatting.decimal($0, maximumFractionDigits: 1)) kg" } ?? "Ziel: noch nicht gesetzt"
        return .success(
            message: [current, target, summary.distanceText, summary.statusText].joined(separator: "\n"),
            affectedModule: .weight
        )
    }

    private func saveWeightTarget(weightKg: Double) throws -> ExternalInputResult {
        guard weightKg.isFinite, weightKg >= 20, weightKg <= 300 else {
            return .failure(message: "Bitte gib ein plausibles Zielgewicht zwischen 20 und 300 kg ein.", reason: "invalid_weight_target")
        }
        var settings = try SettingsRepository(database: database).loadSettings()
        settings.targetWeightKg = weightKg
        _ = try SettingsRepository(database: database).saveSettings(settings)
        return .success(
            message: "Zielgewicht gespeichert: \(ExternalInputFormatting.decimal(weightKg, maximumFractionDigits: 1)) kg.",
            affectedModule: .weight
        )
    }

    private func saveWeightCorridor(lowerKg: Double, upperKg: Double) throws -> ExternalInputResult {
        guard lowerKg.isFinite, upperKg.isFinite, lowerKg >= 20, upperKg >= 20, lowerKg <= 300, upperKg <= 300 else {
            return .failure(message: "Bitte gib zwei plausible Grenzen zwischen 20 und 300 kg ein.", reason: "invalid_weight_corridor")
        }
        var settings = try SettingsRepository(database: database).loadSettings()
        settings.targetWeightLowerKg = min(lowerKg, upperKg)
        settings.targetWeightUpperKg = max(lowerKg, upperKg)
        _ = try SettingsRepository(database: database).saveSettings(settings)
        return .success(
            message: "Zielkorridor gespeichert: \(ExternalInputFormatting.decimal(min(lowerKg, upperKg), maximumFractionDigits: 1)) bis \(ExternalInputFormatting.decimal(max(lowerKg, upperKg), maximumFractionDigits: 1)) kg.",
            affectedModule: .weight
        )
    }

    private func saveExpense(date: Date, amount: Double, title: String, category: String?) throws -> ExternalInputResult {
        let cleanTitle = Self.trimmedOrDefault(title, defaultValue: "Ausgabe")
        guard amount.isFinite, amount > 0, amount <= 100_000 else {
            return .failure(message: "Bitte gib einen gültigen Betrag größer als 0 ein.", reason: "invalid_amount")
        }
        let settings = try SettingsRepository(database: database).loadSettings()
        let entry = FinanceEntryRecord(
            occurredAt: occurredAt(on: date),
            title: cleanTitle,
            amount: amount,
            currency: settings.defaultCurrency,
            category: FinanceCategoryCatalog.normalized(category ?? Self.inferredExpenseCategory(from: cleanTitle), kind: .expense)
        )
        try FinanceRepository(database: database).insert(entry)
        return .success(
            message: "Ausgabe gespeichert: \(ExternalInputFormatting.euro(amount)) - \(cleanTitle).",
            affectedModule: .finance
        )
    }

    private func saveMeal(date: Date, name: String, calories: Int?, protein: Double?, note: String?) throws -> ExternalInputResult {
        let cleanName = Self.trimmedOrDefault(name, defaultValue: "Mahlzeit")
        let safeCalories = max(calories ?? 0, 0)
        let safeProtein = max(protein ?? 0, 0)
        guard safeCalories <= 5_000, safeProtein.isFinite, safeProtein <= 400 else {
            return .failure(message: "Bitte prüfe Kalorien und Protein. Einer der Werte wirkt zu hoch.", reason: "invalid_meal")
        }
        try NutritionRepository(database: database).insert(
            NutritionEntryRecord(
                occurredAt: occurredAt(on: date),
                title: cleanName,
                caloriesKcal: safeCalories,
                proteinG: safeProtein,
                note: Self.optionalTrimmed(note)
            )
        )
        return .success(
            message: "Mahlzeit gespeichert: \(cleanName) - \(safeCalories) kcal, \(ExternalInputFormatting.decimal(safeProtein)) g Protein.",
            affectedModule: .nutrition
        )
    }

    private func saveTemplateMeal(date: Date, templateId: String) throws -> ExternalInputResult {
        guard let meal = try NutritionTemplateRepository(database: database).addMeal(templateID: templateId, date: date, calendar: calendar) else {
            return .failure(message: "Diese Vorlage wurde nicht gefunden.", reason: "template_missing")
        }
        return .success(
            message: "Vorlage als Mahlzeit gespeichert: \(meal.title).",
            affectedModule: .nutrition
        )
    }

    private func saveWorkout(date: Date, note: String?) throws -> ExternalInputResult {
        try WorkoutRepository(database: database).insert(
            WorkoutSessionRecord(
                occurredAt: occurredAt(on: date),
                workoutType: "Training",
                durationMin: 0,
                status: "done",
                note: Self.optionalTrimmed(note)
            )
        )
        return .success(message: "Training für heute gespeichert.", affectedModule: .training)
    }

    private func saveHabit(date: Date, habitName: String) throws -> ExternalInputResult {
        guard let habit = Self.matchHabit(named: habitName) else {
            return .failure(message: "Diesen Habit habe ich nicht gefunden.", reason: "habit_missing")
        }
        guard !habit.isDerived else {
            return .failure(message: "Training wird als Training gespeichert, nicht als Habit.", reason: "derived_habit")
        }
        try HabitRepository(database: database).upsertCompletion(
            habitKey: habit.key,
            date: DateIntervals.dayKey(for: date, calendar: calendar),
            isCompleted: true
        )
        return .success(message: "Habit erledigt: \(habit.title).", affectedModule: .habits)
    }

    private func occurredAt(on date: Date) -> Date {
        let day = DateIntervals.day(containing: date, calendar: calendar).start
        return calendar.date(
            bySettingHour: calendar.component(.hour, from: now()),
            minute: calendar.component(.minute, from: now()),
            second: 0,
            of: day
        ) ?? date
    }

    private static func matchHabit(named name: String) -> FixedHabit? {
        let normalized = normalize(name)
        return FixedHabit.defaults.first { habit in
            normalize(habit.key) == normalized || normalize(habit.title) == normalized
        }
    }

    static func shortLabel(_ value: String, limit: Int = 28) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count > limit else { return trimmed }
        return String(trimmed.prefix(max(limit - 1, 1))) + "..."
    }

    private static func normalize(_ value: String) -> String {
        value
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "de_DE"))
            .lowercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func trimmedOrDefault(_ value: String, defaultValue: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? defaultValue : trimmed
    }

    private static func optionalTrimmed(_ value: String?) -> String? {
        let trimmed = (value ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private static func inferredExpenseCategory(from title: String) -> String {
        let normalized = normalize(title)
        let rules: [(String, [String])] = [
            ("Lebensmittel", ["rewe", "edeka", "aldi", "lidl", "kaufland", "supermarkt", "lebensmittel"]),
            ("Essen unterwegs", ["essen", "restaurant", "lunch", "mittag", "dinner", "doener", "döner", "pizza", "cafe", "kaffee"]),
            ("Transport", ["bahn", "bus", "ticket", "uber", "taxi", "benzin", "tanken"]),
            ("Miete/Wohnen", ["miete", "strom", "gas", "internet", "wohnung"]),
            ("Gesundheit", ["apotheke", "arzt", "medikament", "medikamente"]),
            ("Freizeit", ["kino", "spiel", "game", "bar"]),
            ("Abos", ["abo", "netflix", "spotify"])
        ]
        return rules.first { _, keywords in
            keywords.contains { normalized.contains(normalize($0)) }
        }?.0 ?? "Sonstiges"
    }
}
