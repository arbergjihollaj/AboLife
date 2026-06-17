import Foundation

struct HtmlSnapshotFile: Equatable {
    let url: URL
    let html: String
}

struct HtmlSnapshotExportService {
    let database: AppDatabase
    var calendar: Calendar = .current
    var now: () -> Date = Date.init
    var temporaryDirectory: URL = FileManager.default.temporaryDirectory

    func makeSnapshotFile() throws -> HtmlSnapshotFile {
        let date = now()
        let html = try renderHTML(for: date)
        let fileURL = temporaryDirectory
            .appendingPathComponent(fileName(for: date), isDirectory: false)
        try html.write(to: fileURL, atomically: true, encoding: .utf8)
        return HtmlSnapshotFile(url: fileURL, html: html)
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
        return "abolife_snapshot_\(formatter.string(from: date)).html"
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
        let todayWorkouts = try workoutRepository.fetch(in: dayInterval)
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
            workoutWeek: workoutWeek,
            trainingPlanName: TrainingPlanSeeder.weeklyPlan.workout(for: date, calendar: calendar).day.name,
            financeToday: todayFinance,
            financeMonth: financeMonth,
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
    let workoutWeek: WorkoutWeeklySummary
    let trainingPlanName: String
    let financeToday: [FinanceEntryRecord]
    let financeMonth: FinanceMonthlySummary
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
        let budgetRemaining = max(snapshot.settings.monthlyBudget - snapshot.financeMonth.spent, 0)
        let trainingDoneToday = snapshot.workoutsToday.contains { $0.status == "done" }
        let trainingStatus = snapshot.workoutsToday.isEmpty ? "offen" : (trainingDoneToday ? "erledigt" : "offen")
        let nextSteps = nextSteps(snapshot: snapshot, caloriesRemaining: caloriesRemaining, proteinRemaining: proteinRemaining, trainingDoneToday: trainingDoneToday, budgetRemaining: budgetRemaining)

        return """
        <!doctype html>
        <html lang="de">
        <head>
        <meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <title>AboLife Snapshot</title>
        <style>
        :root{color-scheme:dark;--bg:#0d1117;--panel:#151b24;--panel2:#101720;--text:#f1f5f9;--muted:#93a4b8;--line:#263241;--green:#62d394;--cyan:#73d7f7;--gold:#ffd166;--red:#ff7b7b}
        *{box-sizing:border-box}body{margin:0;background:radial-gradient(circle at top,#17202c,#0d1117 44%);color:var(--text);font:16px/1.45 -apple-system,BlinkMacSystemFont,"Segoe UI",sans-serif}
        main{width:min(760px,100%);margin:0 auto;padding:22px 14px 34px}.hero{padding:22px 4px 12px}h1{font-size:34px;line-height:1.05;margin:0 0 8px}h2{font-size:19px;margin:0 0 14px}.muted{color:var(--muted)}.grid{display:grid;gap:12px}.card{background:linear-gradient(180deg,var(--panel),var(--panel2));border:1px solid var(--line);border-radius:8px;padding:16px;box-shadow:0 10px 30px rgba(0,0,0,.22)}
        .stats{display:grid;grid-template-columns:repeat(2,minmax(0,1fr));gap:10px}.stat{background:#0c131c;border:1px solid #223041;border-radius:8px;padding:12px}.label{display:block;color:var(--muted);font-size:12px;text-transform:uppercase;letter-spacing:.04em}.value{display:block;font-size:22px;font-weight:750;margin-top:2px}.bar{height:9px;background:#222b36;border-radius:999px;overflow:hidden;margin-top:10px}.fill{height:100%;width:var(--p);background:linear-gradient(90deg,var(--cyan),var(--green));border-radius:999px}
        ul{list-style:none;margin:0;padding:0;display:grid;gap:8px}.row{display:flex;justify-content:space-between;gap:12px;border-top:1px solid var(--line);padding-top:8px}.row:first-child{border-top:0;padding-top:0}.pill{display:inline-flex;align-items:center;border:1px solid var(--line);border-radius:999px;padding:4px 9px;color:var(--muted);font-size:13px}.empty{color:var(--muted);border:1px dashed #314053;border-radius:8px;padding:12px;background:#0b121a}.ok{color:var(--green)}.warn{color:var(--gold)}
        @media (max-width:520px){main{padding:18px 12px 28px}h1{font-size:30px}.stats{grid-template-columns:1fr}.value{font-size:20px}.row{display:grid;gap:2px}}
        </style>
        </head>
        <body><main>
        <section class="hero">
        <h1>AboLife Snapshot</h1>
        <p class="muted">Erstellt am \(html(dateTime(snapshot.generatedAt))). Aktueller Stand deines Tages.</p>
        </section>
        \(card("Heute", """
        <div class="stats">
        \(stat("Datum", snapshot.todayKey))
        \(stat("Tagesstatus", dayStatus(snapshot)))
        </div>
        <p class="muted">\(html(summary(snapshot)))</p>
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
        """))
        \(card("Finanzen", """
        <div class="stats">
        \(stat("Heute", money(spentToday, snapshot.settings.defaultCurrency)))
        \(stat("Monat", money(snapshot.financeMonth.spent, snapshot.settings.defaultCurrency)))
        \(stat("Monatsbudget", money(snapshot.settings.monthlyBudget, snapshot.settings.defaultCurrency)))
        \(stat("Verbleibend", money(budgetRemaining, snapshot.settings.defaultCurrency)))
        </div>
        \(entryList(snapshot.financeToday, empty: "Heute wurden noch keine Ausgaben eingetragen.") { entry in
            row(entry.title, "\(money(entry.amount, entry.currency)) · \(entry.category)")
        })
        """))
        \(card("Habits", """
        <div class="stats">
        \(progressStat("Heute", "\(snapshot.habitDay.completed) / \(snapshot.habitDay.total)", current: Double(snapshot.habitDay.completed), target: Double(max(snapshot.habitDay.total, 1))))
        \(stat("Fortschritt", "\(percent(snapshot.habitDay.progress)) %"))
        </div>
        \(habitList(snapshot.habitsToday))
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
        \(card("Nächste Schritte", nextStepsHTML(nextSteps)))
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
    private func habitList(_ entries: [HabitEntryRecord]) -> String {
        guard !entries.isEmpty else { return "<p class=\"empty\">Heute wurden noch keine Habits markiert.</p>" }
        return "<ul>\(entries.map { entry in row(FixedHabit.defaultDefinition(for: entry.habitKey)?.title ?? entry.habitKey, entry.isCompleted ? "erledigt" : "offen") }.joined())</ul>"
    }
    private func weightHTML(_ snapshot: HtmlSnapshot) -> String {
        guard let latest = snapshot.latestWeight else { return "<p class=\"empty\">Noch kein Gewicht eingetragen.</p>" }
        let change = snapshot.weightChange.map { value in value == 0 ? "unverändert" : "\(value > 0 ? "+" : "")\(number(value)) kg" } ?? "kein Vergleichswert"
        return "<div class=\"stats\">\(stat("Aktuell", "\(number(latest.weightKg)) kg"))\(stat("Letzter Eintrag", latest.date))\(stat("Trend", change))</div>"
    }
    private func reviewHTML(_ review: WeeklyReviewRecord?) -> String {
        guard let review else { return "<p class=\"empty\">Für diese Woche gibt es noch keine Review-Zusammenfassung.</p>" }
        let parts = [review.winsText, review.challengesText, review.nextWeekFocusText].filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        return parts.isEmpty ? "<p class=\"empty\">Review ist angelegt, aber noch ohne Text.</p>" : "<p class=\"muted\">\(html(parts.joined(separator: " · ")))</p>"
    }
    private func nextStepsHTML(_ steps: [String]) -> String {
        guard !steps.isEmpty else { return "<p class=\"empty\">Aktuell ist nichts Dringendes offen.</p>" }
        return "<ul>\(steps.map { "<li class=\"row\"><span>\(html($0))</span></li>" }.joined())</ul>"
    }
    private func nextSteps(snapshot: HtmlSnapshot, caloriesRemaining: Int, proteinRemaining: Double, trainingDoneToday: Bool, budgetRemaining: Double) -> [String] {
        var steps: [String] = []
        if snapshot.dailySummary.isProteinShakeOpen || proteinRemaining >= 25 { steps.append("Proteinshake noch offen") }
        if !trainingDoneToday && !snapshot.trainingPlanName.isEmpty { steps.append("Training heute noch offen") }
        if budgetRemaining <= snapshot.settings.monthlyBudget * 0.2 { steps.append("Budget heute im Blick behalten") }
        if caloriesRemaining > 600 && snapshot.nutritionEntries.isEmpty { steps.append("Mahlzeiten heute noch tracken") }
        return steps
    }
    private func dayStatus(_ snapshot: HtmlSnapshot) -> String { snapshot.habitDay.progress >= 0.8 ? "stabil" : "im Aufbau" }
    private func summary(_ snapshot: HtmlSnapshot) -> String { "\(snapshot.nutritionDay.caloriesKcal) kcal, \(number(snapshot.nutritionDay.proteinG)) g Protein, \(snapshot.workoutsToday.count) Trainingseinträge und \(snapshot.financeToday.count) Ausgaben heute." }
    private func dateTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = Locale(identifier: "de_DE")
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    private func number(_ value: Double) -> String { value.formatted(.number.locale(Locale(identifier: "de_DE")).precision(.fractionLength(0...1))) }
    private func money(_ value: Double, _ currency: String) -> String { "\(number(value)) \(currency)" }
    private func percent(_ value: Double) -> Int { Int((min(max(value, 0), 1) * 100).rounded()) }
    private func html(_ value: String) -> String {
        value
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&#39;")
    }
}
