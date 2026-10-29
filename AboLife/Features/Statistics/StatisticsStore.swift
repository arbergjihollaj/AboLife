import Foundation

final class StatisticsStore: ObservableObject {
    @Published private(set) var insights: [StatisticInsight] = []
    @Published private(set) var errorMessage: String?

    private let database: AppDatabase?
    private let calendar: Calendar

    init(database: AppDatabase?, calendar: Calendar = .current) {
        self.database = database
        self.calendar = calendar
        reload()
    }

    func reload() {
        guard let database else {
            insights = []
            errorMessage = nil
            return
        }

        do {
            let settings = try SettingsRepository(database: database).fetchDefault() ?? SeedData.defaultSettings
            let weekInterval = DateIntervals.week(weekStartsOn: settings.weekStartsOn, calendar: calendar)

            let workoutSummary = try WorkoutRepository(database: database).weeklySummary(
                forDate: Date(),
                weekStartsOn: settings.weekStartsOn,
                calendar: calendar
            )
            let habitSummary = try HabitRepository(database: database).weeklySummary(
                in: weekInterval,
                habitKeys: FixedHabit.defaults.map(\.key),
                days: 7,
                calendar: calendar
            )
            let financeRepository = FinanceRepository(database: database)
            let financeWeekly = try financeRepository.weeklySummary(in: weekInterval)
            let financeMonthly = try financeRepository.monthlyAnalysis(
                forDate: Date(),
                monthlyBudget: settings.monthlyBudget,
                currency: settings.defaultCurrency,
                calendar: calendar
            )
            let weightSummary = try WeightRepository(database: database).summary(days: 30)
            let activeDays = try Self.activeDays(database: database, calendar: calendar)

            insights = [
                StatisticInsight(
                    title: "Training diese Woche",
                    value: "\(workoutSummary.completedWorkouts)",
                    detail: trainingDetail(workoutSummary, target: settings.weeklyWorkoutTarget),
                    systemImage: "figure.strengthtraining.traditional",
                    tintRole: .training
                ),
                StatisticInsight(
                    title: "Trainingsdetails",
                    value: workoutSummary.totalSets > 0 ? "\(workoutSummary.totalSets)" : "-",
                    detail: workoutSummary.totalSets > 0 ? "\(workoutSummary.totalReps) Wiederholungen, häufigste Übung: \(workoutSummary.topExerciseName ?? "noch offen")." : "Noch nicht genug Satzdaten für Übungstrends.",
                    systemImage: "list.bullet.clipboard",
                    tintRole: .training
                ),
                StatisticInsight(
                    title: "Habit-Erfüllung",
                    value: "\(Int((habitSummary.progress * 100).rounded()))%",
                    detail: habitSummary.total == 0 ? "Noch keine Habits für diese Woche." : "\(habitSummary.completed) von \(habitSummary.total) möglichen Habit-Tagen erledigt.",
                    systemImage: "checkmark.seal",
                    tintRole: .habits
                ),
            ] + financeInsights(weekly: financeWeekly, monthly: financeMonthly) + [
                weightInsight(weightSummary),
                StatisticInsight(
                    title: "Aktive Tage",
                    value: "\(activeDays)",
                    detail: activeDays == 0 ? "Noch keine lokalen Aktivitätstage." : "Tage mit Einträgen in AboLife.",
                    systemImage: "calendar.badge.checkmark",
                    tintRole: .review
                )
            ]
            errorMessage = nil
        } catch {
            errorMessage = "Statistiken konnten nicht geladen werden."
        }
    }



    private func trainingDetail(_ summary: WorkoutWeeklySummary, target: Int) -> String {
        if summary.completedWorkouts == 0 {
            return "Noch kein Training diese Woche."
        }
        let base = "\(summary.completedWorkouts) von \(target) Einheiten abgeschlossen."
        let progress = summary.progressText.map { " \($0)" } ?? ""
        let minimum = summary.minimumWorkouts > 0 ? " \(summary.minimumWorkouts)x Minimum statt ausfallen." : ""
        return base + progress + minimum
    }

    private func financeInsights(weekly: FinanceWeeklySummary, monthly: FinanceMonthlyAnalysis) -> [StatisticInsight] {
        guard monthly.entryCount >= 3 else {
            return [
                StatisticInsight(
                    title: "Finanzen",
                    value: "-",
                    detail: "Noch nicht genug Finanzdaten für eine verlässliche Monatsauswertung.",
                    systemImage: "eurosign.circle",
                    tintRole: .finance
                )
            ]
        }

        let previousText = monthly.previousMonthSpent.map {
            "Vormonat \(Int($0.rounded())) \(monthly.currency)."
        } ?? "Für den Vormonat fehlen noch Vergleichsdaten."
        let trendText = monthly.trailingThreeMonthAverageSpent.map {
            "3-Monats-Schnitt \(Int($0.rounded())) \(monthly.currency)."
        } ?? "Für einen 3-Monats-Trend braucht es noch mehr Daten."
        let savingsText = monthly.savingsRate.map {
            "Sparquote \(Int(($0 * 100).rounded()))%."
        } ?? "Eine Sparquote erscheint, sobald Einnahmen vorhanden sind."
        let topCategories = monthly.categoryTrends.prefix(3).map(\.category).joined(separator: ", ")

        return [
            StatisticInsight(
                title: "Monatsausgaben",
                value: "\(Int(monthly.spent.rounded())) \(monthly.currency)",
                detail: "Ø \(Int(monthly.averageDailySpend.rounded())) \(monthly.currency)/Tag, Prognose \(Int(monthly.projectedSpend.rounded())) \(monthly.currency). \(previousText)",
                systemImage: "eurosign.circle",
                tintRole: .finance
            ),
            StatisticInsight(
                title: "Finanztrend",
                value: monthly.balance >= 0 ? "+\(Int(monthly.balance.rounded())) \(monthly.currency)" : "\(Int(monthly.balance.rounded())) \(monthly.currency)",
                detail: "\(savingsText) \(trendText) Top-Kategorien: \(topCategories.isEmpty ? weekly.topCategory ?? "noch offen" : topCategories).",
                systemImage: "chart.line.uptrend.xyaxis",
                tintRole: .finance
            )
        ]
    }

    private func weightInsight(_ summary: WeightTrendSummary) -> StatisticInsight {
        guard let latest = summary.latest else {
            return StatisticInsight(
                title: "Gewichtstrend",
                value: "-",
                detail: "Noch kein Gewicht eingetragen.",
                systemImage: "scalemass",
                tintRole: .review
            )
        }

        guard let change = summary.firstToLastChangeKg else {
            return StatisticInsight(
                title: "Gewichtstrend",
                value: WeightStore.formatWeight(latest.weightKg),
                detail: "Ein Eintrag vorhanden. Für einen Trend braucht es mindestens zwei Werte.",
                systemImage: "scalemass",
                tintRole: .review
            )
        }

        let sevenAverage = Self.average(summary.entries.suffix(7).map(\.weightKg))
        let thirtyAverage = Self.average(summary.entries.map(\.weightKg))
        return StatisticInsight(
            title: "Gewichtstrend",
            value: WeightStore.formatWeight(latest.weightKg),
            detail: "7-Tage-Schnitt \(sevenAverage.map(WeightStore.formatWeight) ?? "-"), 30-Tage-Schnitt \(thirtyAverage.map(WeightStore.formatWeight) ?? "-"). Veränderung: \(WeightStore.formatChange(change)).",
            systemImage: "scalemass",
            tintRole: .review
        )
    }

    private static func average(_ values: [Double]) -> Double? {
        guard !values.isEmpty else { return nil }
        return values.reduce(0, +) / Double(values.count)
    }

    private static func activeDays(database: AppDatabase, calendar: Calendar) throws -> Int {
        try database.writer.read { db in
            var days = Set<String>()
            let workoutDates = try Date.fetchAll(db, sql: "SELECT occurred_at FROM workout_sessions")
            let financeDates = try Date.fetchAll(db, sql: "SELECT occurred_at FROM finance_entries")
            let habitDays = try String.fetchAll(db, sql: "SELECT date FROM habit_entries")
            let weightDays = try String.fetchAll(db, sql: "SELECT date FROM weight_entries")

            (workoutDates + financeDates).forEach {
                days.insert(DateIntervals.dayKey(for: $0, calendar: calendar))
            }
            habitDays.forEach { days.insert($0) }
            weightDays.forEach { days.insert($0) }
            return days.count
        }
    }
}

struct StatisticInsight: Identifiable, Equatable {
    let id = UUID()
    let title: String
    let value: String
    let detail: String
    let systemImage: String
    let tintRole: StatisticTintRole
}

enum StatisticTintRole: Equatable {
    case training
    case finance
    case habits
    case review
}
