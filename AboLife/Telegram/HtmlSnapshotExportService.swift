import Foundation

struct HtmlSnapshotFile: Equatable {
    let url: URL
    let html: String
}

enum HtmlSnapshotDeliveryError: Error, Equatable {
    case creation
    case sending
}

struct HtmlSnapshotExportService {
    let database: AppDatabase
    var calendar: Calendar = .current
    var now: () -> Date = Date.init
    var temporaryDirectory: URL = FileManager.default.temporaryDirectory
    var fileManager: FileManager = .default
    var uniqueIdentifier: () -> String = { UUID().uuidString.lowercased() }
    var cleanupFailureLogger: (String) -> Void = { message in
        NSLog("%@", message)
    }

    func makeSnapshotFile() throws -> HtmlSnapshotFile {
        let date = now()
        let html = try renderHTML(for: date)
        try fileManager.createDirectory(
            at: temporaryDirectory,
            withIntermediateDirectories: true
        )
        let fileURL = temporaryDirectory
            .appendingPathComponent(fileName(for: date), isDirectory: false)
        let fileExistedBeforeWrite = fileManager.fileExists(atPath: fileURL.path)
        do {
            try html.write(to: fileURL, atomically: true, encoding: .utf8)
        } catch {
            if !fileExistedBeforeWrite {
                try? fileManager.removeItem(at: fileURL)
            }
            throw error
        }
        return HtmlSnapshotFile(url: fileURL, html: html)
    }

    func sendSnapshot(
        using client: TelegramDocumentClient,
        chatId: Int64,
        caption: String = "AboLife Snapshot"
    ) async throws {
        let file: HtmlSnapshotFile
        do {
            file = try makeSnapshotFile()
        } catch {
            throw HtmlSnapshotDeliveryError.creation
        }

        defer {
            if fileManager.fileExists(atPath: file.url.path) {
                do {
                    try fileManager.removeItem(at: file.url)
                } catch {
                    cleanupFailureLogger("Temporärer Telegram-HTML-Snapshot konnte nicht gelöscht werden.")
                }
            }
        }

        do {
            try await client.sendDocument(
                chatId: chatId,
                fileURL: file.url,
                caption: caption
            )
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            throw HtmlSnapshotDeliveryError.sending
        }
    }

    func renderHTML(for date: Date? = nil) throws -> String {
        let date = date ?? now()
        let snapshot = try makeSnapshot(for: date)
        return HtmlSnapshotHTMLRenderer(calendar: calendar).render(snapshot)
    }

    private func fileName(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = Locale(identifier: "de_DE")
        formatter.dateFormat = "yyyy-MM-dd_HH-mm"
        return "abolife_snapshot_\(formatter.string(from: date))_\(safeIdentifier()).html"
    }

    private func safeIdentifier() -> String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_"))
        let sanitized = uniqueIdentifier()
            .unicodeScalars
            .filter { allowed.contains($0) }
            .map(String.init)
            .joined()
        return sanitized.isEmpty ? UUID().uuidString.lowercased() : String(sanitized.prefix(64))
    }

    private func makeSnapshot(for date: Date) throws -> HtmlSnapshot {
        let settings = try SettingsRepository(database: database).loadSettings()
        let nutritionRepository = NutritionRepository(database: database)
        let financeRepository = FinanceRepository(database: database)
        let workoutRepository = WorkoutRepository(database: database)
        let habitRepository = HabitRepository(database: database)
        let weightRepository = WeightRepository(database: database)

        let dayInterval = DateIntervals.day(containing: date, calendar: calendar)
        let weekInterval = DateIntervals.week(containing: date, weekStartsOn: settings.weekStartsOn, calendar: calendar)
        let todayKey = DateIntervals.dayKey(for: date, calendar: calendar)
        let todayNutrition = try nutritionRepository.fetchEntries(in: dayInterval)
        let nutritionDay = try nutritionRepository.daySummary(for: date, calendar: calendar)
        let nutritionWeek = try nutritionRepository.weeklySummary(in: weekInterval)
        let todayFinance = try financeRepository.fetchEntries(in: dayInterval)
        let financeMonth = try financeRepository.monthlySummary(forDate: date, calendar: calendar)
        let financePlan = try financeRepository.monthPlan(
            for: date,
            monthlyBudget: settings.monthlyBudget,
            currency: settings.defaultCurrency,
            calendar: calendar
        )
        let financeTrend = try financeRepository.monthlyTrend(forDate: date, calendar: calendar)
        let fixedCosts = try financeRepository.fetchFixedCosts(activeOnly: true)
        let todayWorkouts = try workoutRepository.fetch(in: dayInterval)
        let todayExerciseHistory = try workoutRepository.fetchAllExerciseSummaries(in: dayInterval)
        let workoutWeek = try workoutRepository.weeklySummary(forDate: date, weekStartsOn: settings.weekStartsOn, calendar: calendar)
        let todayHabits = try habitRepository.fetchEntries(forDay: todayKey)
        let habitKeys = FixedHabit.defaults.map(\.key)
        let habitDay = try habitRepository.dailySummary(forDay: todayKey, habitKeys: habitKeys)
        let habitWeek = try habitRepository.weeklySummary(in: weekInterval, habitKeys: habitKeys, days: 7, calendar: calendar)
        let latestWeight = try weightRepository.latest()
        let weightChange = try latestWeight.flatMap { try weightRepository.changeFromPrevious(for: $0) }
        let weekStartKey = DateIntervals.dayKey(for: weekInterval.start, calendar: calendar)
        let review = try WeeklyReviewRepository(database: database).fetch(weekStartDate: weekStartKey)
        let dailySummary = try DailySummaryService(database: database, calendar: calendar).snapshot(for: date)

        return HtmlSnapshot(
            generatedAt: date,
            settings: settings,
            todayKey: todayKey,
            nutritionDay: nutritionDay,
            nutritionEntries: todayNutrition,
            nutritionWeek: nutritionWeek,
            workoutsToday: todayWorkouts,
            workoutExercisesToday: todayExerciseHistory,
            workoutWeek: workoutWeek,
            trainingPlanName: TrainingPlanSeeder.weeklyPlan.workout(for: date, calendar: calendar).day.name,
            financeToday: todayFinance,
            financeMonth: financeMonth,
            financePlan: financePlan,
            financeTrend: financeTrend,
            fixedCosts: fixedCosts,
            habitsToday: todayHabits,
            habitDay: habitDay,
            habitWeek: habitWeek,
            latestWeight: latestWeight,
            weightChange: weightChange,
            weeklyReview: review,
            dailySummary: dailySummary
        )
    }
}

private struct HtmlSnapshot {
    let generatedAt: Date
    let settings: AppSettingsRecord
    let todayKey: String
    let nutritionDay: NutritionDaySummary
    let nutritionEntries: [NutritionEntryRecord]
    let nutritionWeek: NutritionWeeklySummary
    let workoutsToday: [WorkoutSessionRecord]
    let workoutExercisesToday: [WorkoutExerciseHistoryEntry]
    let workoutWeek: WorkoutWeeklySummary
    let trainingPlanName: String
    let financeToday: [FinanceEntryRecord]
    let financeMonth: FinanceMonthlySummary
    let financePlan: FinanceMonthPlan
    let financeTrend: FinanceMonthlyTrend
    let fixedCosts: [FinanceFixedCostRecord]
    let habitsToday: [HabitEntryRecord]
    let habitDay: HabitDailySummary
    let habitWeek: HabitWeeklySummary
    let latestWeight: WeightEntryRecord?
    let weightChange: Double?
    let weeklyReview: WeeklyReviewRecord?
    let dailySummary: DailySummarySnapshot
}

private struct HtmlSnapshotHTMLRenderer {
    let calendar: Calendar

    func render(_ snapshot: HtmlSnapshot) -> String {
        let caloriesRemaining = max(snapshot.settings.caloriesTarget - snapshot.nutritionDay.caloriesKcal, 0)
        let proteinRemaining = max(snapshot.settings.proteinTargetG - snapshot.nutritionDay.proteinG, 0)
        let spentToday = snapshot.financeToday.reduce(0) { $0 + $1.amount }
        let budgetRemaining = snapshot.financePlan.remainingBudget
        let trainingDoneToday = snapshot.workoutsToday.contains { $0.status == "done" }
        let trainingPausedToday = habitCompleted(TelegramReminderHabit.trainingPausedKey, in: snapshot)
        let trainingStatus = trainingDoneToday ? "erledigt" : (trainingPausedToday ? "pausiert" : "offen")
        let nextSteps = nextSteps(snapshot: snapshot, caloriesRemaining: caloriesRemaining, proteinRemaining: proteinRemaining, trainingDoneToday: trainingDoneToday, budgetRemaining: budgetRemaining)
        let openSummary = todayOpenSummary(
            snapshot: snapshot,
            caloriesRemaining: caloriesRemaining,
            proteinRemaining: proteinRemaining,
            trainingDoneToday: trainingDoneToday,
            trainingPausedToday: trainingPausedToday
        )

        return """
        <!doctype html>
        <html lang="de">
        <head>
        <meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <meta http-equiv="Content-Security-Policy" content="default-src 'none'; style-src 'unsafe-inline'; img-src data:">
        <meta name="referrer" content="no-referrer">
        <title>AboLife Snapshot</title>
        <style>
        :root{color-scheme:dark;--bg:#090d13;--panel:#131a24;--panel2:#0f151e;--text:#f2f5f8;--muted:#94a2b4;--line:#263141;--green:#72d6a0;--cyan:#78d5ed;--gold:#e8c875;--soft:#182332}
        *{box-sizing:border-box}body{margin:0;background:radial-gradient(circle at 50% -10%,#1b2939 0,#0c121a 38%,var(--bg) 72%);color:var(--text);font:15px/1.5 -apple-system,BlinkMacSystemFont,"Segoe UI",sans-serif;-webkit-font-smoothing:antialiased}
        main{width:min(760px,100%);margin:0 auto;padding:24px 14px 40px}.hero{padding:24px 5px 14px}.eyebrow{color:var(--cyan);font-size:12px;font-weight:700;letter-spacing:.14em;text-transform:uppercase}h1{font-size:34px;line-height:1.08;margin:5px 0 8px;letter-spacing:-.03em}h2{font-size:18px;margin:0 0 14px;letter-spacing:-.01em}.muted{color:var(--muted)}.stack{display:grid;gap:12px}.card{background:linear-gradient(155deg,rgba(21,30,42,.98),rgba(13,19,28,.98));border:1px solid var(--line);border-radius:18px;padding:17px;box-shadow:0 14px 38px rgba(0,0,0,.2)}.focus{border-color:#355069;background:linear-gradient(145deg,#172535,#101923)}
        .focus p{font-size:18px;line-height:1.45;margin:0}.stats{display:grid;grid-template-columns:repeat(2,minmax(0,1fr));gap:10px}.stat{background:rgba(8,14,21,.66);border:1px solid #223041;border-radius:13px;padding:12px}.label{display:block;color:var(--muted);font-size:11px;text-transform:uppercase;letter-spacing:.08em}.value{display:block;font-size:21px;font-weight:720;margin-top:3px;overflow-wrap:anywhere}.bar{height:7px;background:#222b36;border-radius:999px;overflow:hidden;margin-top:10px}.fill{height:100%;width:var(--p);background:linear-gradient(90deg,var(--cyan),var(--green));border-radius:999px}
        ul{list-style:none;margin:0;padding:0;display:grid;gap:9px}.row{display:flex;justify-content:space-between;align-items:baseline;gap:14px;border-top:1px solid var(--line);padding-top:9px}.row:first-child{border-top:0;padding-top:0}.status{display:inline-flex;align-items:center;border:1px solid var(--line);background:var(--soft);border-radius:999px;padding:3px 9px;color:var(--muted);font-size:12px;white-space:nowrap}.status.ok{color:var(--green);border-color:#28553e}.status.open{color:var(--gold);border-color:#5a4b27}.empty{color:var(--muted);border:1px dashed #314053;border-radius:13px;padding:12px;background:#0b121a}.section-note{margin:12px 0 0}.footer{text-align:center;color:var(--muted);font-size:12px;padding:8px}
        @media (max-width:520px){main{padding:17px 11px 30px}.hero{padding:19px 4px 12px}h1{font-size:30px}.card{border-radius:16px;padding:15px}.stats{grid-template-columns:1fr 1fr}.value{font-size:18px}.row{gap:9px}.row>span:first-child{min-width:0}}
        </style>
        </head>
        <body><main>
        <section class="hero">
        <div class="eyebrow">Private Tagesübersicht</div>
        <h1>AboLife Snapshot</h1>
        <p class="muted">\(html(dateTime(snapshot.generatedAt))) · lokal erstellt · offline lesbar</p>
        </section>
        <div class="stack">
        <section class="card focus">
        <h2>Heute noch offen</h2>
        <p>\(html(openSummary))</p>
        </section>
        \(card("Heute", """
        <div class="stats">
        \(stat("Datum", snapshot.todayKey))
        \(stat("Tagesstatus", dayStatus(snapshot)))
        \(stat("Training", trainingStatus))
        \(stat("Tagesbudget", snapshot.dailySummary.dailyBudgetText))
        </div>
        <p class="muted section-note">\(html(summary(snapshot)))</p>
        """))
        \(card("Ernährung", """
        <div class="stats">
        \(progressStat("Kalorien heute", "\(snapshot.nutritionDay.caloriesKcal) kcal", current: Double(snapshot.nutritionDay.caloriesKcal), target: Double(snapshot.settings.caloriesTarget)))
        \(progressStat("Protein heute", "\(number(snapshot.nutritionDay.proteinG)) g", current: snapshot.nutritionDay.proteinG, target: snapshot.settings.proteinTargetG))
        \(stat("Kalorienziel", "\(snapshot.settings.caloriesTarget) kcal"))
        \(stat("Verbleibend", "\(caloriesRemaining) kcal"))
        \(stat("Proteinziel", "\(number(snapshot.settings.proteinTargetG)) g"))
        \(stat("Protein offen", "\(number(proteinRemaining)) g"))
        </div>
        \(entryList(snapshot.nutritionEntries, empty: "Heute wurden noch keine Mahlzeiten eingetragen.") { entry in
            row(entry.title, "\(entry.caloriesKcal) kcal · \(number(entry.proteinG)) g Protein")
        })
        """))
        \(card("Training", """
        <div class="stats">
        \(stat("Plan heute", snapshot.trainingPlanName))
        \(stat("Status", trainingStatus))
        </div>
        \(entryList(snapshot.workoutsToday, empty: "Heute gibt es noch keinen Trainingseintrag.") { workout in
            row(workout.workoutType, "\(workout.durationMin) Min. · \(workout.status)")
        })
        \(workoutDetails(snapshot))
        """))
        \(card("Finanzen", """
        <div class="stats">
        \(stat("Heute", money(spentToday, snapshot.settings.defaultCurrency)))
        \(stat("Monat", money(snapshot.financeMonth.spent, snapshot.settings.defaultCurrency)))
        \(stat("Monatsbudget", money(snapshot.settings.monthlyBudget, snapshot.settings.defaultCurrency)))
        \(stat("Verbleibend", money(budgetRemaining, snapshot.settings.defaultCurrency)))
        \(stat("Prognose", money(snapshot.financePlan.forecastSpend, snapshot.settings.defaultCurrency)))
        \(stat("Fixkosten offen", money(snapshot.financePlan.remainingFixedCosts, snapshot.settings.defaultCurrency)))
        </div>
        <p class="muted section-note">\(html(financeStatus(snapshot)))</p>
        \(categoryTrendList(snapshot))
        \(entryList(snapshot.financeToday, empty: "Heute wurden noch keine Ausgaben eingetragen.") { entry in
            row(entry.title, "\(money(entry.amount, entry.currency)) · \(entry.category)")
        })
        """))
        \(card("Habits", """
        <div class="stats">
        \(progressStat("Heute", "\(snapshot.habitDay.completed) / \(snapshot.habitDay.total)", current: Double(snapshot.habitDay.completed), target: Double(max(snapshot.habitDay.total, 1))))
        \(stat("Fortschritt", "\(percent(snapshot.habitDay.progress)) %"))
        \(stat("Medikamente", snapshot.dailySummary.isMedicationOpen ? "offen" : "erledigt"))
        \(stat("Proteinshake", snapshot.dailySummary.isProteinShakeOpen ? "offen" : "erledigt"))
        </div>
        \(habitList(snapshot))
        """))
        \(card("Gewicht", weightHTML(snapshot)))
        \(card("Wochenstatus", """
        <div class="stats">
        \(stat("Trainings", "\(snapshot.workoutWeek.completedWorkouts) / \(snapshot.settings.weeklyWorkoutTarget)"))
        \(stat("Kalorien Ø", "\(Int(snapshot.nutritionWeek.averageCaloriesPerDay.rounded())) kcal"))
        \(stat("Protein Ø", "\(number(snapshot.nutritionWeek.averageProteinGPerDay)) g"))
        \(stat("Habit-Woche", "\(percent(snapshot.habitWeek.progress)) %"))
        </div>
        \(reviewHTML(snapshot.weeklyReview))
        """))
        \(card("Letzte Aktivitäten", activityList(snapshot)))
        \(card("Ein ruhiger nächster Schritt", nextStepsHTML(nextSteps)))
        <div class="footer">AboLife · nur für dich · keine externen Inhalte</div>
        </div>
        </main></body></html>
        """
    }

    private func card(_ title: String, _ body: String) -> String { "<section class=\"card\"><h2>\(html(title))</h2>\(body)</section>" }
    private func stat(_ label: String, _ value: String) -> String { "<div class=\"stat\"><span class=\"label\">\(html(label))</span><span class=\"value\">\(html(value))</span></div>" }
    private func progressStat(_ label: String, _ value: String, current: Double, target: Double) -> String {
        let progress = target > 0 ? min(max(current / target, 0), 1) : 0
        return "<div class=\"stat\"><span class=\"label\">\(html(label))</span><span class=\"value\">\(html(value))</span><div class=\"bar\"><div class=\"fill\" style=\"--p:\(Int(progress * 100))%\"></div></div></div>"
    }
    private func row(_ title: String, _ detail: String) -> String { "<li class=\"row\"><span>\(html(title))</span><span class=\"muted\">\(html(detail))</span></li>" }
    private func entryList<T>(_ entries: [T], empty: String, rowBuilder: (T) -> String) -> String { entries.isEmpty ? "<p class=\"empty\">\(html(empty))</p>" : "<ul>\(entries.prefix(5).map(rowBuilder).joined())</ul>" }
    private func habitList(_ snapshot: HtmlSnapshot) -> String {
        let entriesByKey = snapshot.habitsToday.reduce(into: [String: HabitEntryRecord]()) {
            $0[$1.habitKey] = $1
        }
        let regularHabits = FixedHabit.defaults
            .filter { !$0.isDerived }
            .map { habit in
                let entry = entriesByKey[habit.key]
                let value = entry?.value ?? (entry?.isCompleted == true ? habit.targetValue : 0)
                let completed = entry?.isCompleted == true || value >= habit.targetValue
                let detail = habit.isBoolean
                    ? statusPill(completed ? "erledigt" : "offen", completed: completed)
                    : "\(html(habit.displayValue(value))) · \(statusPill(completed ? "erledigt" : "offen", completed: completed))"
                return "<li class=\"row\"><span>\(html(habit.title))</span><span>\(detail)</span></li>"
            }
        let telegramHabits = [
            habitStatusRow("Medikamente", completed: !snapshot.dailySummary.isMedicationOpen),
            habitStatusRow("Proteinshake", completed: !snapshot.dailySummary.isProteinShakeOpen)
        ]
        return "<ul>\((regularHabits + telegramHabits).joined())</ul>"
    }
    private func weightHTML(_ snapshot: HtmlSnapshot) -> String {
        guard let latest = snapshot.latestWeight else { return "<p class=\"empty\">Noch kein Gewicht eingetragen.</p>" }
        let change = snapshot.weightChange.map { value in value == 0 ? "unverändert" : "\(value > 0 ? "+" : "")\(number(value)) kg" } ?? "kein Vergleichswert"
        return "<div class=\"stats\">\(stat("Aktuell", "\(number(latest.weightKg)) kg"))\(stat("Letzter Eintrag", latest.date))\(stat("Trend", change))</div>"
    }
    private func workoutDetails(_ snapshot: HtmlSnapshot) -> String {
        guard !snapshot.workoutExercisesToday.isEmpty else { return "" }
        let rows = snapshot.workoutExercisesToday.prefix(8).map { entry in
            let sets = entry.sets.compactMap(\.reps).isEmpty
                ? "\(entry.sets.count) Sätze"
                : entry.sets.compactMap(\.reps).map(String.init).joined(separator: " / ")
            return row(entry.exercise.exerciseName, sets)
        }.joined()
        return "<h2>Übungen</h2><ul>\(rows)</ul>"
    }
    private func reviewHTML(_ review: WeeklyReviewRecord?) -> String {
        guard let review else { return "<p class=\"empty\">Für diese Woche gibt es noch keine Review-Zusammenfassung.</p>" }
        let parts = [review.winsText, review.challengesText, review.nextWeekFocusText].filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        return parts.isEmpty ? "<p class=\"empty\">Review ist angelegt, aber noch ohne Text.</p>" : "<p class=\"muted\">\(html(parts.joined(separator: " · ")))</p>"
    }
    private func nextStepsHTML(_ steps: [String]) -> String {
        guard !steps.isEmpty else { return "<p class=\"empty\">Guter Stand. Für heute ist nichts Wesentliches mehr offen.</p>" }
        return "<ul>\(steps.map { "<li class=\"row\"><span>\(html($0))</span></li>" }.joined())</ul>"
    }
    private func nextSteps(snapshot: HtmlSnapshot, caloriesRemaining: Int, proteinRemaining: Double, trainingDoneToday: Bool, budgetRemaining: Double) -> [String] {
        var steps: [String] = []
        if proteinRemaining >= 10 {
            steps.append("Plane in Ruhe noch \(number(proteinRemaining)) g Protein ein.")
        } else if snapshot.dailySummary.isProteinShakeOpen {
            steps.append("Wenn es für dich passt, fehlt nur noch dein Proteinshake.")
        }
        if !trainingDoneToday && !habitCompleted(TelegramReminderHabit.trainingPausedKey, in: snapshot) {
            steps.append("Dein Training ist noch offen; eine kurze Einheit zählt genauso.")
        }
        if budgetRemaining <= snapshot.settings.monthlyBudget * 0.2 {
            steps.append("Das Monatsbudget ist weit genutzt. Behalte den heutigen Rahmen entspannt im Blick.")
        }
        if caloriesRemaining > 600 && snapshot.nutritionEntries.isEmpty {
            steps.append("Trage deine erste Mahlzeit ein, sobald es gerade gut passt.")
        }
        return Array(steps.prefix(3))
    }

    private func todayOpenSummary(
        snapshot: HtmlSnapshot,
        caloriesRemaining: Int,
        proteinRemaining: Double,
        trainingDoneToday: Bool,
        trainingPausedToday: Bool
    ) -> String {
        var openItems: [String] = []
        if proteinRemaining >= 1 {
            openItems.append("\(number(proteinRemaining)) g Protein")
        }
        if snapshot.dailySummary.isMedicationOpen {
            openItems.append("Medikamente")
        }
        if snapshot.dailySummary.isProteinShakeOpen {
            openItems.append("Proteinshake")
        }

        let completedHabitKeys = Set(snapshot.habitsToday.filter(\.isCompleted).map(\.habitKey))
        let openHabitTitles = FixedHabit.defaults
            .filter { !$0.isDerived && !completedHabitKeys.contains($0.key) }
            .map(\.title)
        openItems.append(contentsOf: openHabitTitles.prefix(2))

        if !trainingDoneToday && !trainingPausedToday {
            openItems.append("Training")
        }

        if openItems.isEmpty {
            return "Guter Stand. Für heute ist nichts Wesentliches mehr offen."
        }
        if openItems.count == 1 {
            return "Guter Stand. Heute fehlt nur noch \(openItems[0])."
        }

        let visible = Array(openItems.prefix(4))
        let joined = visible.dropLast().joined(separator: ", ") + " und " + (visible.last ?? "")
        let budgetNote = caloriesRemaining == 0
            ? " Dein Kalorienrahmen ist erreicht."
            : " \(caloriesRemaining) kcal bleiben in deinem heutigen Rahmen."
        return "Noch offen: \(joined).\(budgetNote)"
    }

    private func activityList(_ snapshot: HtmlSnapshot) -> String {
        struct Activity {
            let date: Date
            let title: String
            let detail: String
        }

        var activities = snapshot.nutritionEntries.map {
            Activity(date: $0.occurredAt, title: $0.title, detail: "\(time($0.occurredAt)) · \($0.caloriesKcal) kcal")
        }
        activities += snapshot.workoutsToday.map {
            Activity(date: $0.occurredAt, title: $0.workoutType, detail: "\(time($0.occurredAt)) · \($0.durationMin) Min. Training")
        }
        activities += snapshot.financeToday.map {
            Activity(date: $0.occurredAt, title: $0.title, detail: "\(time($0.occurredAt)) · \(money($0.amount, $0.currency))")
        }
        let latest = activities.sorted { $0.date > $1.date }.prefix(6)
        guard !latest.isEmpty else {
            return "<p class=\"empty\">Heute gibt es noch keine protokollierten Aktivitäten.</p>"
        }
        return "<ul>\(latest.map { row($0.title, $0.detail) }.joined())</ul>"
    }

    private func habitCompleted(_ key: String, in snapshot: HtmlSnapshot) -> Bool {
        snapshot.habitsToday.first { $0.habitKey == key }?.isCompleted == true
    }

    private func habitStatusRow(_ title: String, completed: Bool) -> String {
        "<li class=\"row\"><span>\(html(title))</span>\(statusPill(completed ? "erledigt" : "offen", completed: completed))</li>"
    }

    private func statusPill(_ text: String, completed: Bool) -> String {
        "<span class=\"status \(completed ? "ok" : "open")\">\(html(text))</span>"
    }

    private func dayStatus(_ snapshot: HtmlSnapshot) -> String { snapshot.habitDay.progress >= 0.8 ? "guter Stand" : "ruhig im Aufbau" }
    private func summary(_ snapshot: HtmlSnapshot) -> String { "\(snapshot.nutritionDay.caloriesKcal) kcal, \(number(snapshot.nutritionDay.proteinG)) g Protein, \(snapshot.workoutsToday.count) Trainingseinträge und \(snapshot.financeToday.count) Ausgaben heute." }
    private func financeStatus(_ snapshot: HtmlSnapshot) -> String {
        if snapshot.financeMonth.entryCount == 0 {
            return "Noch keine Finanzdaten in diesem Monat. Sobald ein paar Einträge da sind, wird die Prognose aussagekräftiger."
        }
        if snapshot.financePlan.isForecastOverBudget {
            return "Die Prognose liegt leicht über dem Monatsbudget. Ruhig im Blick behalten."
        }
        if snapshot.financePlan.remainingFixedCosts > 0 {
            return "Es sind noch \(money(snapshot.financePlan.remainingFixedCosts, snapshot.settings.defaultCurrency)) Fixkosten für diesen Monat offen."
        }
        return "Der Monat liegt aktuell im Budget."
    }

    private func categoryTrendList(_ snapshot: HtmlSnapshot) -> String {
        let rows = snapshot.financePlan.categorySummaries.prefix(4).map { summary in
            var detail = money(summary.spent, snapshot.settings.defaultCurrency)
            if let budget = summary.budget {
                detail += summary.isOverBudget
                    ? " · \(money(summary.spent - budget, snapshot.settings.defaultCurrency)) über Budget"
                    : " · Budget \(money(budget, snapshot.settings.defaultCurrency))"
            }
            return row(summary.category, detail)
        }
        guard !rows.isEmpty else { return "" }
        return "<ul>\(rows.joined())</ul>"
    }
    private func dateTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = Locale(identifier: "de_DE")
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    private func time(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = Locale(identifier: "de_DE")
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }
    private func number(_ value: Double) -> String { value.formatted(.number.locale(Locale(identifier: "de_DE")).precision(.fractionLength(0...1))) }
    private func money(_ value: Double, _ currency: String) -> String { "\(number(value)) \(currency)" }
    private func percent(_ value: Double) -> Int { Int((min(max(value, 0), 1) * 100).rounded()) }
    private func html(_ value: String) -> String {
        redactedSensitiveText(value)
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&#39;")
    }

    private func redactedSensitiveText(_ value: String) -> String {
        let patterns = [
            #"(?i)\bABOLIFE_TELEGRAM_(?:BOT_TOKEN|ALLOWED_CHAT_ID)\b\s*[:=]?\s*\S*"#,
            #"(?i)\b(?:chat[_ -]?id|chatId)\b\s*[:=]\s*-?\d+"#,
            #"(?i)\b(?:bot[_ -]?token|bearer)\b\s*[:=]?\s*[A-Za-z0-9._:-]{12,}"#,
            #"\b\d{6,12}:[A-Za-z0-9_-]{20,}\b"#,
            #"(?i)\bhttps?://[^\s<>"']+"#,
            #"file://\S+"#,
            #"/Users/\S+"#,
            #"/private/var/\S+"#,
            #"/var/folders/\S+"#
        ]
        return patterns.reduce(value) { result, pattern in
            result.replacingOccurrences(
                of: pattern,
                with: "[aus Datenschutzgründen entfernt]",
                options: .regularExpression
            )
        }
    }
}
