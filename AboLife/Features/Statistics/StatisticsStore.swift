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
            let nutritionSummary = try NutritionRepository(database: database).weeklySummary(in: weekInterval, days: 7)
            let financeWeekly = try FinanceRepository(database: database).weeklySummary(in: weekInterval)
            let financeMonthly = try FinanceRepository(database: database).monthlyTrend(forDate: Date(), calendar: calendar)
            let weightSummary = try WeightRepository(database: database).summary(days: 30)
            let activeDays = try Self.activeDays(database: database, calendar: calendar)

            insights = [
                StatisticInsight(
                    title: "Training diese Woche",
                    value: "\(workoutSummary.completedWorkouts)",
                    detail: workoutSummary.completedWorkouts == 1 ? "1 Einheit abgeschlossen." : "\(workoutSummary.completedWorkouts) Einheiten abgeschlossen.",
                    systemImage: "figure.strengthtraining.traditional",
                    tintRole: .training
                ),
                StatisticInsight(
                    title: "Habit-Erfüllung",
                    value: "\(Int((habitSummary.progress * 100).rounded()))%",
                    detail: habitSummary.total == 0 ? "Noch keine Habits für diese Woche." : "\(habitSummary.completed) von \(habitSummary.total) möglichen Habit-Tagen erledigt.",
                    systemImage: "checkmark.seal",
                    tintRole: .habits
                ),
                nutritionInsight(nutritionSummary),
                financeInsight(weekly: financeWeekly, monthly: financeMonthly),
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

    private func nutritionInsight(_ summary: NutritionWeeklySummary) -> StatisticInsight {
        guard summary.entryCount >= 3 else {
            return StatisticInsight(
                title: "Ernährung",
                value: "-",
                detail: "Noch nicht genug Ernährungsdaten für einen Trend.",
                systemImage: "fork.knife",
                tintRole: .nutrition
            )
        }

        return StatisticInsight(
            title: "Ernährung im Schnitt",
            value: "\(Int(summary.averageCaloriesPerDay.rounded())) kcal",
            detail: "\(Int(summary.averageProteinGPerDay.rounded())) g Protein pro Tag bei \(summary.entryCount) Einträgen.",
            systemImage: "fork.knife",
            tintRole: .nutrition
        )
    }

    private func financeInsight(weekly: FinanceWeeklySummary, monthly: FinanceMonthlyTrend) -> StatisticInsight {
        guard monthly.entryCount >= 3 else {
            return StatisticInsight(
                title: "Finanzen",
                value: "-",
                detail: "Noch nicht genug Finanzdaten für eine Monatsauswertung.",
                systemImage: "eurosign.circle",
                tintRole: .finance
            )
        }

        return StatisticInsight(
            title: "Ausgaben",
            value: "\(Int(monthly.spent.rounded())) EUR",
            detail: "Ø \(Int(monthly.averageDailySpend.rounded())) EUR/Tag, Prognose \(Int(monthly.projectedSpend.rounded())) EUR. Voriger Monat: \(Int(monthly.previousSpent.rounded())) EUR.",
            systemImage: "eurosign.circle",
            tintRole: .finance
        )
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
            let nutritionDates = try Date.fetchAll(db, sql: "SELECT occurred_at FROM nutrition_entries")
            let workoutDates = try Date.fetchAll(db, sql: "SELECT occurred_at FROM workout_sessions")
            let financeDates = try Date.fetchAll(db, sql: "SELECT occurred_at FROM finance_entries")
            let habitDays = try String.fetchAll(db, sql: "SELECT date FROM habit_entries")
            let weightDays = try String.fetchAll(db, sql: "SELECT date FROM weight_entries")

            (nutritionDates + workoutDates + financeDates).forEach {
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
    case nutrition
    case training
    case finance
    case habits
    case review
}
