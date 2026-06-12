import Foundation

struct WeeklyTrendPoint: Identifiable, Equatable {
    let date: Date
    let weekdayLabel: String
    let value: Double

    var id: String {
        DateIntervals.dayKey(for: date)
    }
}

struct WeeklyReviewTrends: Equatable {
    let caloriesByDay: [WeeklyTrendPoint]
    let proteinByDay: [WeeklyTrendPoint]
    let spendingByDay: [WeeklyTrendPoint]
    let trainingMinutesByDay: [WeeklyTrendPoint]
    let habitCompletionByDay: [WeeklyTrendPoint]

    var hasAnyData: Bool {
        caloriesByDay.containsData ||
            proteinByDay.containsData ||
            spendingByDay.containsData ||
            trainingMinutesByDay.containsData ||
            habitCompletionByDay.containsData
    }

    static func empty(for interval: DateInterval, calendar: Calendar = .current) -> WeeklyReviewTrends {
        make(
            interval: interval,
            nutritionEntries: [],
            financeEntries: [],
            workoutSessions: [],
            habitEntries: [],
            habitKeys: [],
            calendar: calendar
        )
    }

    static func make(
        interval: DateInterval,
        nutritionEntries: [NutritionEntryRecord],
        financeEntries: [FinanceEntryRecord],
        workoutSessions: [WorkoutSessionRecord],
        habitEntries: [HabitEntryRecord],
        habitKeys: [String],
        calendar: Calendar = .current
    ) -> WeeklyReviewTrends {
        let days = weekDays(in: interval, calendar: calendar)
        let dayKeys = days.map { DateIntervals.dayKey(for: $0, calendar: calendar) }
        let allowedHabitKeys = Set(habitKeys)

        var caloriesByKey = Dictionary(uniqueKeysWithValues: dayKeys.map { ($0, 0.0) })
        var proteinByKey = Dictionary(uniqueKeysWithValues: dayKeys.map { ($0, 0.0) })
        var spendingByKey = Dictionary(uniqueKeysWithValues: dayKeys.map { ($0, 0.0) })
        var trainingMinutesByKey = Dictionary(uniqueKeysWithValues: dayKeys.map { ($0, 0.0) })
        var completedHabitIDsByKey = Dictionary(uniqueKeysWithValues: dayKeys.map { ($0, Set<String>()) })

        for entry in nutritionEntries {
            let key = DateIntervals.dayKey(for: entry.occurredAt, calendar: calendar)
            caloriesByKey[key, default: 0] += Double(entry.caloriesKcal)
            proteinByKey[key, default: 0] += entry.proteinG
        }

        for entry in financeEntries {
            let key = DateIntervals.dayKey(for: entry.occurredAt, calendar: calendar)
            spendingByKey[key, default: 0] += entry.amount
        }

        for session in workoutSessions where session.status == "done" {
            let key = DateIntervals.dayKey(for: session.occurredAt, calendar: calendar)
            trainingMinutesByKey[key, default: 0] += Double(session.durationMin)
        }

        for entry in habitEntries where allowedHabitKeys.contains(entry.habitKey) && isHabitComplete(entry) {
            completedHabitIDsByKey[entry.date, default: []].insert(entry.habitKey)
        }

        return WeeklyReviewTrends(
            caloriesByDay: points(days: days, valuesByKey: caloriesByKey, calendar: calendar),
            proteinByDay: points(days: days, valuesByKey: proteinByKey, calendar: calendar),
            spendingByDay: points(days: days, valuesByKey: spendingByKey, calendar: calendar),
            trainingMinutesByDay: points(days: days, valuesByKey: trainingMinutesByKey, calendar: calendar),
            habitCompletionByDay: days.map { day in
                let key = DateIntervals.dayKey(for: day, calendar: calendar)
                let completed = completedHabitIDsByKey[key]?.count ?? 0
                let percent = habitKeys.isEmpty ? 0 : (Double(completed) / Double(habitKeys.count)) * 100
                return WeeklyTrendPoint(
                    date: day,
                    weekdayLabel: weekdayLabel(for: day),
                    value: min(max(percent, 0), 100)
                )
            }
        )
    }

    static func weekDays(in interval: DateInterval, calendar: Calendar = .current) -> [Date] {
        (0..<7).compactMap { offset in
            calendar.date(byAdding: .day, value: offset, to: calendar.startOfDay(for: interval.start))
        }
    }

    private static func points(days: [Date], valuesByKey: [String: Double], calendar: Calendar) -> [WeeklyTrendPoint] {
        days.map { day in
            WeeklyTrendPoint(
                date: day,
                weekdayLabel: weekdayLabel(for: day),
                value: valuesByKey[DateIntervals.dayKey(for: day, calendar: calendar)] ?? 0
            )
        }
    }

    private static func weekdayLabel(for date: Date) -> String {
        weekdayFormatter.string(from: date)
    }

    private static func isHabitComplete(_ entry: HabitEntryRecord) -> Bool {
        if let value = entry.value, let targetValue = entry.targetValue, targetValue > 0 {
            return value >= targetValue
        }
        return entry.isCompleted
    }

    private static let weekdayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "de_DE")
        formatter.dateFormat = "E"
        return formatter
    }()
}

extension Array where Element == WeeklyTrendPoint {
    var totalValue: Double {
        reduce(0) { $0 + $1.value }
    }

    var averageValue: Double {
        isEmpty ? 0 : totalValue / Double(count)
    }

    var containsData: Bool {
        contains { $0.value > 0 }
    }
}
