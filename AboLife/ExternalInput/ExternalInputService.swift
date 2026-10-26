import Foundation

struct ExternalInputService {
    let database: AppDatabase
    var calendar: Calendar = .current
    var now: () -> Date = Date.init
    private let undoStore: ExternalInputUndoStore
    private let undoValidity: TimeInterval

    init(
        database: AppDatabase,
        calendar: Calendar = .current,
        now: @escaping () -> Date = Date.init,
        undoValidity: TimeInterval = 10 * 60
    ) {
        self.database = database
        self.calendar = calendar
        self.now = now
        self.undoStore = .shared
        self.undoValidity = max(undoValidity, 0)
    }

    func execute(_ intent: ExternalInputIntent, sessionID: String = "local") -> ExternalInputResult {
        do {
            switch intent {
            case let .weight(date, weightKg):
                return try saveWeight(date: date, weightKg: weightKg, sessionID: sessionID)
            case .weightStatus:
                return try weightStatus()
            case let .weightTarget(weightKg):
                return try saveWeightTarget(weightKg: weightKg)
            case let .weightCorridor(lowerKg, upperKg):
                return try saveWeightCorridor(lowerKg: lowerKg, upperKg: upperKg)
            case let .expense(date, amount, title, category):
                return try saveExpense(date: date, amount: amount, title: title, category: category, sessionID: sessionID)
            case let .meal(date, name, calories, protein, note):
                return try saveMeal(date: date, name: name, calories: calories, protein: protein, note: note, sessionID: sessionID)
            case let .mealTemplate(date, templateId):
                return try saveTemplateMeal(date: date, templateId: templateId, sessionID: sessionID)
            case let .workoutCompleted(date, note):
                return try saveWorkout(date: date, note: note, sessionID: sessionID)
            case let .homeWorkoutCompleted(date, workoutName, intensity, note):
                return try saveHomeWorkout(date: date, workoutName: workoutName, intensity: intensity, note: note, sessionID: sessionID)
            case let .workoutExerciseSets(date, exerciseName, reps):
                return try saveWorkoutSets(date: date, exerciseName: exerciseName, reps: reps, sessionID: sessionID)
            case let .workoutPaused(date):
                return try pauseWorkout(date: date, sessionID: sessionID)
            case let .habitCompleted(date, habitName):
                return try saveHabit(date: date, habitName: habitName, sessionID: sessionID)
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

    func completeHabit(habitKey: String, date: Date? = nil) -> ExternalInputResult {
        completeHabitLegacy(habitKey: habitKey, date: date)
    }

    func completeHabit(habitKey: String, date: Date? = nil, sessionID: String) -> ExternalInputResult {
        do {
            guard Self.isSupportedHabitKey(habitKey) else {
                return .failure(message: "Diesen Habit habe ich nicht gefunden.", reason: "habit_missing")
            }
            guard FixedHabit.defaultDefinition(for: habitKey)?.isDerived != true else {
                return .failure(message: "Training wird als Training gespeichert, nicht als Habit.", reason: "derived_habit")
            }
            let repository = HabitRepository(database: database)
            let effectiveDate = date ?? now()
            let dayKey = DateIntervals.dayKey(for: effectiveDate, calendar: calendar)
            let previous = try repository.fetchEntry(habitKey: habitKey, date: dayKey)
            try repository.upsertCompletion(
                habitKey: habitKey,
                date: dayKey,
                isCompleted: true
            )
            guard let saved = try repository.fetchEntry(habitKey: habitKey, date: dayKey) else {
                return .failure(message: "Das konnte nicht gespeichert werden. Bitte versuche es erneut.", reason: "persistence")
            }
            return savedResult(
                message: "\(Self.habitTitle(for: habitKey)) erledigt.",
                affectedModule: .habits,
                sessionID: sessionID,
                statusDate: effectiveDate
            ) {
                let current = try repository.fetchEntry(habitKey: habitKey, date: dayKey)
                guard current?.id == saved.id, current?.updatedAt == saved.updatedAt else {
                    throw ExternalInputServiceError.changedSinceSave
                }
                try repository.clearCompletion(habitKey: habitKey, date: dayKey)
                if let previous {
                    try repository.insert(previous)
                }
            }
        } catch {
            return .failure(message: "Das konnte nicht gespeichert werden. Bitte versuche es erneut.", reason: "persistence")
        }
    }

    func undo(receiptID: String, sessionID: String = "local") -> ExternalInputResult {
        do {
            switch try undoStore.undo(receiptID: receiptID, sessionID: sessionID, now: now()) {
            case .undone:
                return .success(message: "↩️ Rückgängig gemacht.", affectedModule: .unknown)
            case .alreadyUndone:
                return undoUnavailable(reason: "undo_already_done")
            case .expired:
                return undoUnavailable(reason: "undo_expired")
            case .superseded:
                return undoUnavailable(reason: "undo_not_latest")
            case .unavailable:
                return undoUnavailable(reason: "undo_unavailable")
            case .unknown:
                return undoUnavailable(reason: "undo_unknown")
            }
        } catch ExternalInputServiceError.changedSinceSave {
            return undoUnavailable(reason: "undo_conflict")
        } catch {
            return undoUnavailable(reason: "undo_persistence")
        }
    }

    func nutritionDayStatus(for date: Date = Date()) -> String {
        saveStatus(for: .nutrition, date: date)
    }

    func saveStatus(for affectedModule: ExternalInputAffectedModule, date: Date = Date()) -> String {
        do {
            let snapshot = try TodaySnapshotService(database: database, calendar: calendar).snapshot(for: date)
            switch affectedModule {
            case .nutrition:
                return "📊 Heute: \(snapshot.nutritionSummary.caloriesKcal) / \(snapshot.settings.caloriesTarget) kcal · \(ExternalInputFormatting.decimal(snapshot.nutritionSummary.proteinG, maximumFractionDigits: 0)) / \(ExternalInputFormatting.decimal(snapshot.settings.proteinTargetG, maximumFractionDigits: 0)) g Protein"
            case .finance:
                let currency = snapshot.settings.defaultCurrency
                let monthRemaining = max(snapshot.settings.monthlyBudget - snapshot.monthlySpent, 0)
                return "💶 Heute verfügbar: \(ExternalInputFormatting.currency(snapshot.availableToday, currencyCode: currency)) · Monatsrest: \(ExternalInputFormatting.currency(monthRemaining, currencyCode: currency))"
            case .training:
                return "🏋️ \(snapshot.todayOpenStatus.training.title) · Woche: \(snapshot.weeklyWorkoutCompleted) / \(snapshot.settings.weeklyWorkoutTarget)"
            case .weight:
                guard let weight = snapshot.latestWeight else { return "" }
                let change = snapshot.latestWeightChangeKg.map {
                    let prefix = $0 > 0 ? "+" : ""
                    return " · Änderung: \(prefix)\(ExternalInputFormatting.decimal($0, maximumFractionDigits: 1)) kg"
                } ?? ""
                return "⚖️ Aktuell: \(ExternalInputFormatting.decimal(weight.weightKg, maximumFractionDigits: 1)) kg\(change)"
            case .habits:
                let habits = FixedHabit.defaults.filter { !$0.isDerived }
                let completed = habits.filter { snapshot.habitValue(for: $0.key) >= $0.targetValue }.count
                let medication = snapshot.todayOpenStatus.isMedicationOpen ? "offen" : "erledigt"
                let shake = snapshot.todayOpenStatus.isProteinShakeOpen ? "offen" : "erledigt"
                return "✅ Habits heute: \(completed) / \(habits.count) · Medikamente: \(medication) · Shake: \(shake)"
            case .menu, .unknown:
                return ""
            }
        } catch {
            return ""
        }
    }

    private func saveWeight(date: Date, weightKg: Double, sessionID: String) throws -> ExternalInputResult {
        guard weightKg.isFinite, weightKg >= 20, weightKg <= 300 else {
            return .failure(message: "Bitte gib ein plausibles Gewicht zwischen 20 und 300 kg ein.", reason: "invalid_weight")
        }
        let repository = WeightRepository(database: database)
        let dayKey = DateIntervals.dayKey(for: date, calendar: calendar)
        let previous = try repository.fetchEntry(dayKey: dayKey)
        let saved = try repository.upsert(dayKey: dayKey, weightKg: weightKg)
        let message = "Gewicht für heute gespeichert: \(ExternalInputFormatting.decimal(weightKg, maximumFractionDigits: 1)) kg."
        guard let previous else {
            return savedResult(
                message: "\(message) Rückgängig ist nicht verfügbar, weil kein vorheriger Tageswert bekannt ist.",
                affectedModule: .weight,
                sessionID: sessionID,
                statusDate: date,
                unavailableReason: "Kein vorheriger Tageswert bekannt; das Gewicht kann nicht sicher wiederhergestellt werden."
            )
        }
        return savedResult(
            message: "Gewicht für heute gespeichert: \(ExternalInputFormatting.decimal(weightKg, maximumFractionDigits: 1)) kg.",
            affectedModule: .weight,
            sessionID: sessionID,
            statusDate: date
        ) {
            let current = try repository.fetchEntry(dayKey: dayKey)
            guard current?.id == saved.id, current?.updatedAt == saved.updatedAt else {
                throw ExternalInputServiceError.changedSinceSave
            }
            _ = try repository.upsert(dayKey: previous.date, weightKg: previous.weightKg)
        }
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

    private func saveExpense(date: Date, amount: Double, title: String, category: String?, sessionID: String) throws -> ExternalInputResult {
        let input = FinanceExpenseInputService(calendar: calendar, now: now)
        let draft = input.draft(date: date, amount: amount, title: title, category: category, explicitCategory: category != nil)
        guard amount.isFinite, amount > 0, amount <= 100_000 else {
            return .failure(message: "Bitte gib einen gültigen Betrag größer als 0 ein.", reason: "invalid_amount")
        }
        let settings = try SettingsRepository(database: database).loadSettings()
        let entry = FinanceEntryRecord(
            occurredAt: occurredAt(on: draft.date),
            title: draft.title,
            amount: draft.amount,
            currency: settings.defaultCurrency,
            category: draft.category,
            note: draft.note
        )
        let repository = FinanceRepository(database: database)
        try repository.insert(entry)
        guard let saved = try repository.fetchAll().first(where: { $0.id == entry.id }) else {
            throw ExternalInputServiceError.missingSavedRecord
        }
        return savedResult(
            message: "Ausgabe gespeichert: \(ExternalInputFormatting.euro(amount)) - \(draft.title) · \(draft.category).",
            affectedModule: .finance,
            sessionID: sessionID,
            statusDate: date
        ) {
            if let current = try repository.fetchAll().first(where: { $0.id == saved.id }),
               current.updatedAt != saved.updatedAt {
                throw ExternalInputServiceError.changedSinceSave
            }
            try repository.delete(id: saved.id)
        }
    }

    private func saveMeal(date: Date, name: String, calories: Int?, protein: Double?, note: String?, sessionID: String) throws -> ExternalInputResult {
        let cleanName = Self.trimmedOrDefault(name, defaultValue: "Mahlzeit")
        let safeCalories = max(calories ?? 0, 0)
        let safeProtein = max(protein ?? 0, 0)
        guard safeCalories <= 5_000, safeProtein.isFinite, safeProtein <= 400 else {
            return .failure(message: "Bitte prüfe Kalorien und Protein. Einer der Werte wirkt zu hoch.", reason: "invalid_meal")
        }
        let entry = NutritionEntryRecord(
            occurredAt: occurredAt(on: date),
            title: cleanName,
            caloriesKcal: safeCalories,
            proteinG: safeProtein,
            note: Self.optionalTrimmed(note)
        )
        let repository = NutritionRepository(database: database)
        try repository.insert(entry)
        guard let saved = try repository.fetchAll().first(where: { $0.id == entry.id }) else {
            throw ExternalInputServiceError.missingSavedRecord
        }
        return savedResult(
            message: "Mahlzeit gespeichert: \(cleanName) - \(safeCalories) kcal, \(ExternalInputFormatting.decimal(safeProtein)) g Protein.",
            affectedModule: .nutrition,
            sessionID: sessionID,
            statusDate: date
        ) {
            if let current = try repository.fetchAll().first(where: { $0.id == saved.id }),
               current.updatedAt != saved.updatedAt {
                throw ExternalInputServiceError.changedSinceSave
            }
            try repository.delete(id: saved.id)
        }
    }

    private func saveTemplateMeal(date: Date, templateId: String, sessionID: String) throws -> ExternalInputResult {
        guard let meal = try NutritionTemplateRepository(database: database).addMeal(templateID: templateId, date: date, calendar: calendar) else {
            return .failure(message: "Diese Vorlage wurde nicht gefunden.", reason: "template_missing")
        }
        let repository = NutritionRepository(database: database)
        return savedResult(
            message: "Vorlage als Mahlzeit gespeichert: \(meal.title).",
            affectedModule: .nutrition,
            sessionID: sessionID,
            statusDate: date
        ) {
            if let current = try repository.fetchAll().first(where: { $0.id == meal.id }),
               current.updatedAt != meal.updatedAt {
                throw ExternalInputServiceError.changedSinceSave
            }
            try repository.delete(id: meal.id)
        }
    }

    private func saveWorkout(date: Date, note: String?, sessionID: String) throws -> ExternalInputResult {
        let session = WorkoutSessionRecord(
            occurredAt: occurredAt(on: date),
            workoutType: "Training",
            durationMin: 0,
            status: "done",
            workoutIntensity: HomeWorkoutIntensity.normal.rawValue,
            note: Self.optionalTrimmed(note)
        )
        let repository = WorkoutRepository(database: database)
        try repository.insert(session)
        return savedResult(
            message: "Training für heute gespeichert.",
            affectedModule: .training,
            sessionID: sessionID,
            statusDate: date
        ) {
            if let current = try repository.fetchAll().first(where: { $0.id == session.id }),
               current.updatedAt != session.updatedAt {
                throw ExternalInputServiceError.changedSinceSave
            }
            try repository.delete(id: session.id)
        }
    }

    private func saveHomeWorkout(date: Date, workoutName: String?, intensity: HomeWorkoutIntensity, note: String?, sessionID: String) throws -> ExternalInputResult {
        let plan = HomeWorkoutPlanProvider.plan
        let scheduled = scheduledWorkout(named: workoutName, date: date, plan: plan)
        let exercises = scheduled.day.exercises(for: intensity)
        let session = plan.makeWorkoutSession(
            for: scheduled,
            intensity: intensity,
            completedExerciseCount: exercises.count,
            occurredAt: occurredAt(on: date)
        )
        let inputs = exercises.enumerated().map { index, exercise in
            WorkoutExerciseInput(exerciseName: exercise.name, sortOrder: index, isCompleted: true, sets: [])
        }
        var sessionWithNote = session
        if let note = Self.optionalTrimmed(note) {
            sessionWithNote.note = [session.note, note].compactMap { $0 }.joined(separator: " ")
        }
        let repository = WorkoutRepository(database: database)
        try repository.insertDetailed(sessionWithNote, exercises: inputs)
        return savedResult(
            message: "\(scheduled.day.name) \(intensity.rawValue) gespeichert.",
            affectedModule: .training,
            sessionID: sessionID,
            statusDate: date
        ) {
            if let current = try repository.fetchAll().first(where: { $0.id == sessionWithNote.id }),
               current.updatedAt != sessionWithNote.updatedAt {
                throw ExternalInputServiceError.changedSinceSave
            }
            try repository.delete(id: sessionWithNote.id)
        }
    }

    private func saveWorkoutSets(date: Date, exerciseName: String, reps: [Int], sessionID: String) throws -> ExternalInputResult {
        let cleanName = Self.trimmedOrDefault(exerciseName, defaultValue: "Übung")
        let sets = reps.enumerated().map { index, reps in
            WorkoutSetInput(setNumber: index + 1, reps: reps)
        }
        let session = WorkoutSessionRecord(
            occurredAt: occurredAt(on: date),
            workoutType: "Training: \(cleanName)",
            durationMin: 0,
            status: "done",
            workoutIntensity: HomeWorkoutIntensity.normal.rawValue,
            note: "Telegram Satzangabe"
        )
        let repository = WorkoutRepository(database: database)
        try repository.insertDetailed(
            session,
            exercises: [WorkoutExerciseInput(exerciseName: cleanName, sortOrder: 0, isCompleted: true, sets: sets)]
        )
        return savedResult(
            message: "\(cleanName): \(reps.map(String.init).joined(separator: " / ")) gespeichert.",
            affectedModule: .training,
            sessionID: sessionID,
            statusDate: date
        ) {
            if let current = try repository.fetchAll().first(where: { $0.id == session.id }),
               current.updatedAt != session.updatedAt {
                throw ExternalInputServiceError.changedSinceSave
            }
            try repository.delete(id: session.id)
        }
    }

    private func pauseWorkout(date: Date, sessionID: String) throws -> ExternalInputResult {
        let habitRepository = HabitRepository(database: database)
        let workoutRepository = WorkoutRepository(database: database)
        let dayKey = DateIntervals.dayKey(for: date, calendar: calendar)
        let previousPause = try habitRepository.fetchEntry(
            habitKey: TelegramReminderHabit.trainingPausedKey,
            date: dayKey
        )
        try habitRepository.upsertCompletion(
            habitKey: TelegramReminderHabit.trainingPausedKey,
            date: dayKey,
            isCompleted: true
        )
        guard let savedPause = try habitRepository.fetchEntry(
            habitKey: TelegramReminderHabit.trainingPausedKey,
            date: dayKey
        ) else {
            throw ExternalInputServiceError.missingSavedRecord
        }
        let session = WorkoutSessionRecord(
            occurredAt: occurredAt(on: date),
            workoutType: "Training",
            durationMin: 0,
            status: "paused",
            workoutIntensity: HomeWorkoutIntensity.minimum.rawValue,
            note: "Pause ist okay. Morgen wieder sauber einsteigen."
        )
        try workoutRepository.insert(session)
        return savedResult(
            message: "Training für heute pausiert. Pause ist okay.",
            affectedModule: .training,
            sessionID: sessionID,
            statusDate: date
        ) {
            let currentPause = try habitRepository.fetchEntry(
                habitKey: TelegramReminderHabit.trainingPausedKey,
                date: dayKey
            )
            guard currentPause?.id == savedPause.id, currentPause?.updatedAt == savedPause.updatedAt else {
                throw ExternalInputServiceError.changedSinceSave
            }
            if let currentSession = try workoutRepository.fetchAll().first(where: { $0.id == session.id }),
               currentSession.updatedAt != session.updatedAt {
                throw ExternalInputServiceError.changedSinceSave
            }
            try workoutRepository.delete(id: session.id)
            try habitRepository.clearCompletion(habitKey: TelegramReminderHabit.trainingPausedKey, date: dayKey)
            if let previousPause {
                try habitRepository.insert(previousPause)
            }
        }
    }

    private func scheduledWorkout(named workoutName: String?, date: Date, plan: HomeWorkoutPlan) -> ScheduledHomeWorkout {
        guard let workoutName = workoutName.map(Self.normalize),
              let day = plan.days.first(where: { Self.normalize($0.name) == workoutName }) else {
            return plan.workout(for: date, calendar: calendar)
        }
        return ScheduledHomeWorkout(day: day, scheduledDate: DateIntervals.day(containing: date, calendar: calendar).start, isToday: true)
    }

    private func saveHabit(date: Date, habitName: String, sessionID: String) throws -> ExternalInputResult {
        guard let habit = Self.matchHabit(named: habitName) else {
            return .failure(message: "Diesen Habit habe ich nicht gefunden.", reason: "habit_missing")
        }
        return completeHabit(habitKey: habit.key, date: date, sessionID: sessionID)
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

    private func completeHabitLegacy(habitKey: String, date: Date?) -> ExternalInputResult {
        do {
            guard Self.isSupportedHabitKey(habitKey) else {
                return .failure(message: "Diesen Habit habe ich nicht gefunden.", reason: "habit_missing")
            }
            guard FixedHabit.defaultDefinition(for: habitKey)?.isDerived != true else {
                return .failure(message: "Training wird als Training gespeichert, nicht als Habit.", reason: "derived_habit")
            }
            try HabitRepository(database: database).upsertCompletion(
                habitKey: habitKey,
                date: DateIntervals.dayKey(for: date ?? now(), calendar: calendar),
                isCompleted: true
            )
            return .success(message: "\(Self.habitTitle(for: habitKey)) erledigt.", affectedModule: .habits)
        } catch {
            return .failure(message: "Das konnte nicht gespeichert werden. Bitte versuche es erneut.", reason: "persistence")
        }
    }

    private func savedResult(
        message: String,
        affectedModule: ExternalInputAffectedModule,
        sessionID: String,
        statusDate: Date? = nil,
        unavailableReason: String? = nil,
        operation: (() throws -> Void)? = nil
    ) -> ExternalInputResult {
        let receipt = undoStore.register(
            sessionID: sessionID,
            expiresAt: now().addingTimeInterval(undoValidity),
            unavailableReason: unavailableReason,
            operation: operation
        )
        let status = saveStatus(for: affectedModule, date: statusDate ?? now())
        let enrichedMessage = status.isEmpty ? message : "\(message)\n\(status)"
        return .saved(message: enrichedMessage, affectedModule: affectedModule, receipt: receipt)
    }

    private func undoUnavailable(reason: String) -> ExternalInputResult {
        .failure(
            message: "Das kann ich leider nicht mehr sicher rückgängig machen.",
            reason: reason
        )
    }

    private static func matchHabit(named name: String) -> FixedHabit? {
        let normalized = normalize(name)
        return FixedHabit.defaults.first { habit in
            normalize(habit.key) == normalized || normalize(habit.title) == normalized
        }
    }

    private static func isSupportedHabitKey(_ key: String) -> Bool {
        FixedHabit.defaultDefinition(for: key) != nil
            || key == TelegramReminderHabit.proteinShakeKey
            || key == TelegramReminderHabit.medicationKey
            || key == TelegramReminderHabit.trainingPausedKey
    }

    private static func habitTitle(for key: String) -> String {
        switch key {
        case TelegramReminderHabit.proteinShakeKey:
            return "Proteinshake"
        case TelegramReminderHabit.medicationKey:
            return "Medikamente"
        case TelegramReminderHabit.trainingPausedKey:
            return "Training für heute pausiert"
        default:
            return FixedHabit.defaultDefinition(for: key)?.title ?? "Habit"
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

}

private enum ExternalInputServiceError: Error {
    case changedSinceSave
    case missingSavedRecord
}
