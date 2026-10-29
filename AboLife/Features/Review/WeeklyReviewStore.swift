import Foundation

final class WeeklyReviewStore: ObservableObject {
    @Published var selectedDate: Date {
        didSet {
            guard !Self.isSameWeek(selectedDate, oldValue, weekStartsOn: weekStartsOn, calendar: calendar) else { return }
            reload()
        }
    }
    @Published private(set) var trainingSummary = WorkoutWeeklySummary.empty
    @Published private(set) var financeSummary = FinanceWeeklySummary.empty
    @Published private(set) var previousFinanceSummary = FinanceWeeklySummary.empty
    @Published private(set) var financeMonthPlan: FinanceMonthPlan?
    @Published private(set) var habitSummary = HabitWeeklySummary.empty
    @Published private(set) var trends = WeeklyReviewTrends.empty(
        for: DateIntervals.week(weekStartsOn: SeedData.defaultSettings.weekStartsOn)
    )
    @Published private(set) var weeklyWorkoutTarget = SeedData.defaultSettings.weeklyWorkoutTarget
    @Published private(set) var monthlyBudget = SeedData.defaultSettings.monthlyBudget
    @Published private(set) var currencyCode = SeedData.defaultSettings.defaultCurrency
    @Published var winsText = ""
    @Published var challengesText = ""
    @Published var nextWeekFocusText = ""
    @Published private(set) var saveMessage: String?
    @Published private(set) var errorMessage: String?

    private let database: AppDatabase?
    private let calendar: Calendar
    private var weekStartsOn: Int
    private let habitKeys: [String]

    init(
        database: AppDatabase?,
        selectedDate: Date = Date(),
        calendar: Calendar = .current,
        habitKeys: [String] = FixedHabit.defaults.map(\.key)
    ) {
        self.database = database
        self.selectedDate = selectedDate
        self.calendar = calendar
        self.weekStartsOn = SeedData.defaultSettings.weekStartsOn
        self.habitKeys = habitKeys
        reload()
    }

    var weekInterval: DateInterval {
        DateIntervals.week(containing: selectedDate, weekStartsOn: weekStartsOn, calendar: calendar)
    }

    var weekStartKey: String {
        DateIntervals.dayKey(for: weekInterval.start, calendar: calendar)
    }

    var weekSubtitle: String {
        let endDate = calendar.date(byAdding: .day, value: -1, to: weekInterval.end) ?? weekInterval.end
        let start = weekInterval.start.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated))
        let end = endDate.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated))
        return "\(start) - \(end)"
    }

    var isCurrentWeek: Bool {
        Self.isSameWeek(selectedDate, Date(), weekStartsOn: weekStartsOn, calendar: calendar)
    }

    var reviewedDaysCount: Int {
        Self.daysConsidered(in: weekInterval, referenceDate: Date(), calendar: calendar)
    }

    var hasMeaningfulData: Bool {
            trainingSummary.completedWorkouts > 0 ||
            financeSummary.entryCount > 0 ||
            habitSummary.completed > 0
    }

    var statusMessage: String {
        hasMeaningfulData
            ? "Ein ruhiger Blick auf die wichtigsten Signale dieser Woche."
            : "Sammle ein paar Tage Daten, damit dein Review aussagekräftiger wird."
    }

    func selectCurrentWeek() {
        selectedDate = Date()
        reload()
    }

    func reload() {
        guard let database else {
            trainingSummary = .empty
            financeSummary = .empty
            previousFinanceSummary = .empty
            financeMonthPlan = nil
            habitSummary = .empty
            trends = WeeklyReviewTrends.empty(for: weekInterval, calendar: calendar)
            weeklyWorkoutTarget = SeedData.defaultSettings.weeklyWorkoutTarget
            monthlyBudget = SeedData.defaultSettings.monthlyBudget
            currencyCode = SeedData.defaultSettings.defaultCurrency
            winsText = ""
            challengesText = ""
            nextWeekFocusText = ""
            saveMessage = nil
            errorMessage = nil
            return
        }

        do {
            let settings = try SettingsRepository(database: database).fetchDefault() ?? SeedData.defaultSettings
            weekStartsOn = settings.weekStartsOn
            weeklyWorkoutTarget = settings.weeklyWorkoutTarget
            monthlyBudget = settings.monthlyBudget
            currencyCode = settings.defaultCurrency
            let interval = weekInterval
            let days = reviewedDaysCount

            let workoutRepository = WorkoutRepository(database: database)
            let financeRepository = FinanceRepository(database: database)
            let habitRepository = HabitRepository(database: database)
            let workoutSessions = try workoutRepository.fetchSessions(in: interval)
            let financeEntries = try financeRepository.fetchEntries(in: interval)
            let habitEntries = try habitRepository.fetchEntries(in: interval, calendar: calendar)

            trainingSummary = try workoutRepository.weeklySummary(
                forDate: selectedDate,
                weekStartsOn: settings.weekStartsOn,
                calendar: calendar
            )
            financeSummary = try financeRepository.weeklySummary(in: interval)
            let previousInterval = DateInterval(
                start: calendar.date(byAdding: .day, value: -7, to: interval.start) ?? interval.start,
                end: interval.start
            )
            previousFinanceSummary = try financeRepository.weeklySummary(in: previousInterval)
            financeMonthPlan = try financeRepository.monthPlan(
                for: selectedDate,
                monthlyBudget: settings.monthlyBudget,
                currency: settings.defaultCurrency,
                calendar: calendar
            )
            let weeklyTrends = WeeklyReviewTrends.make(
                interval: interval,
                financeEntries: financeEntries,
                workoutSessions: workoutSessions,
                habitEntries: habitEntries,
                habitKeys: habitKeys,
                calendar: calendar
            )
            let reviewedHabitProgress = Array(weeklyTrends.habitCompletionByDay.prefix(days)).map { $0.value / 100 }
            let completedScore = reviewedHabitProgress.reduce(0) { result, progress in
                result + Int((progress * Double(habitKeys.count)).rounded(.down))
            }

            habitSummary = HabitWeeklySummary(
                completed: completedScore,
                total: max(days, 0) * habitKeys.count,
                progressValue: HabitsStore.averageProgress(reviewedHabitProgress)
            )
            trends = weeklyTrends

            if let review = try WeeklyReviewRepository(database: database).fetch(weekStartDate: weekStartKey) {
                winsText = review.winsText
                challengesText = review.challengesText
                nextWeekFocusText = review.nextWeekFocusText
            } else {
                winsText = ""
                challengesText = ""
                nextWeekFocusText = ""
            }

            saveMessage = nil
            errorMessage = nil
        } catch {
            errorMessage = "Wochenreview konnte nicht geladen werden."
        }
    }

    func saveReview() {
        guard let database else { return }

        do {
            _ = try WeeklyReviewRepository(database: database).upsert(
                weekStartDate: weekStartKey,
                winsText: winsText,
                challengesText: challengesText,
                nextWeekFocusText: nextWeekFocusText
            )
            saveMessage = "Gespeichert"
            errorMessage = nil
        } catch {
            errorMessage = "Wochenreview konnte nicht gespeichert werden."
        }
    }



    var trainingProgress: Double {
        TrainingStore.progress(current: Double(trainingSummary.completedWorkouts), target: Double(weeklyWorkoutTarget))
    }

    var trainingReviewText: String {
        if trainingSummary.completedWorkouts == 0 {
            return "Diese Woche gab es noch kein gespeichertes Training."
        }
        let goal = "Diese Woche hast du \(trainingSummary.completedWorkouts) von \(weeklyWorkoutTarget) Trainings geschafft."
        if let progress = trainingSummary.progressText {
            return "\(goal) \(progress)"
        }
        if trainingSummary.minimumWorkouts > 0 {
            return "\(goal) Du hast \(trainingSummary.minimumWorkouts)x Minimum trainiert statt komplett ausfallen zu lassen."
        }
        if let top = trainingSummary.topExerciseName {
            return "\(goal) Häufigste Übung: \(top)."
        }
        return goal
    }

    var financeProgress: Double {
        guard monthlyBudget > 0 else { return 0 }
        return min(max(financeSummary.spent / (monthlyBudget / 4.0), 0), 1)
    }

    var financeAnalysis: String {
        guard financeSummary.entryCount > 0 else {
            return "Für diese Woche gibt es noch nicht genug Finanzdaten."
        }

        let topCategory = financeSummary.topCategory
            ?? financeMonthPlan?.categorySummaries.first?.category
            ?? "keine klare Top-Kategorie"
        let comparison: String
        if previousFinanceSummary.entryCount == 0 {
            comparison = "Für den Vergleich zur Vorwoche fehlen noch Daten."
        } else if financeSummary.spent < previousFinanceSummary.spent {
            comparison = "Deine Ausgaben lagen niedriger als letzte Woche."
        } else if financeSummary.spent > previousFinanceSummary.spent {
            comparison = "Deine Ausgaben lagen höher als letzte Woche."
        } else {
            comparison = "Deine Ausgaben lagen auf dem Niveau der Vorwoche."
        }

        return "Diese Woche war \(topCategory) die größte Kategorie. \(comparison)"
    }

    func formatAmount(_ amount: Double, currency: String? = nil) -> String {
        let resolvedCurrency = currency ?? currencyCode
        return "\(Int(amount.rounded())) \(resolvedCurrency)"
    }

    func formatCurrencyAmount(_ amount: Double, currency: String? = nil) -> String {
        let resolvedCurrency = currency ?? currencyCode
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = resolvedCurrency
        formatter.maximumFractionDigits = 2
        formatter.minimumFractionDigits = 2
        formatter.locale = resolvedCurrency == "EUR" ? Locale(identifier: "de_DE") : .current
        return formatter.string(from: NSNumber(value: amount)) ?? "\(String(format: "%.2f", amount)) \(resolvedCurrency)"
    }

    static func daysConsidered(in interval: DateInterval, referenceDate: Date, calendar: Calendar = .current) -> Int {
        let weekLength = max(calendar.dateComponents([.day], from: interval.start, to: interval.end).day ?? 7, 1)
        guard referenceDate >= interval.start && referenceDate < interval.end else { return weekLength }

        let start = calendar.startOfDay(for: interval.start)
        let referenceDay = calendar.startOfDay(for: referenceDate)
        let elapsed = (calendar.dateComponents([.day], from: start, to: referenceDay).day ?? 0) + 1
        return min(max(elapsed, 1), weekLength)
    }

    private static func isSameWeek(_ lhs: Date, _ rhs: Date, weekStartsOn: Int, calendar: Calendar) -> Bool {
        DateIntervals.week(containing: lhs, weekStartsOn: weekStartsOn, calendar: calendar).start ==
            DateIntervals.week(containing: rhs, weekStartsOn: weekStartsOn, calendar: calendar).start
    }
}



extension WorkoutWeeklySummary {
    static let empty = WorkoutWeeklySummary(completedWorkouts: 0, totalDurationMin: 0, lastWorkout: nil)
}

extension FinanceWeeklySummary {
    static let empty = FinanceWeeklySummary(spent: 0, income: 0, entryCount: 0, topCategory: nil)
}

extension HabitWeeklySummary {
    static let empty = HabitWeeklySummary(completed: 0, total: 0)
}
