import Foundation

final class HabitsStore: ObservableObject {
    @Published var selectedDate: Date {
        didSet {
            guard !calendar.isDate(selectedDate, inSameDayAs: oldValue) else { return }
            reload()
        }
    }
    @Published private(set) var entriesByKey: [String: HabitEntryRecord] = [:]
    @Published private(set) var weekHistoryByKey: [String: [HabitDayProgress]] = [:]
    @Published private(set) var weeklyDayProgress: [HabitDayProgress] = []
    @Published private(set) var errorMessage: String?

    let habits: [FixedHabit]

    private let database: AppDatabase?
    private let calendar: Calendar

    init(
        database: AppDatabase?,
        selectedDate: Date = Date(),
        calendar: Calendar = .current,
        habits: [FixedHabit] = FixedHabit.defaults
    ) {
        self.database = database
        self.selectedDate = selectedDate
        self.calendar = calendar
        self.habits = habits
        reload()
    }

    var completedHabits: Int {
        habits.filter { progress(for: $0) >= 1 }.count
    }

    var totalHabits: Int {
        habits.count
    }

    var progress: Double {
        dailyProgressPercent
    }

    var dailyProgressPercent: Double {
        Self.averageProgress(habits.map { progress(for: $0) })
    }

    var weeklyProgressPercent: Double {
        Self.averageProgress(weeklyDayProgress.map(\.progress))
    }

    var weeklyCompletedScore: Int {
        weeklyDayProgress.reduce(0) { result, day in
            result + Int((day.progress * Double(totalHabits)).rounded(.down))
        }
    }

    var weeklyTotalScore: Int {
        weeklyDayProgress.count * totalHabits
    }

    var isToday: Bool {
        calendar.isDateInToday(selectedDate)
    }

    var dateSubtitle: String {
        if isToday {
            return "Heute, \(selectedDate.formatted(.dateTime.day().month(.wide).year()))"
        }

        return selectedDate.formatted(.dateTime.weekday(.wide).day().month(.wide).year())
    }

    var missingHabitTitles: [String] {
        habits.filter { progress(for: $0) < 1 }.map(\.title)
    }

    var statusMessage: String {
        if completedHabits == 0 && dailyProgressPercent == 0 {
            return "Noch nichts gestartet. Ein kleiner Schritt reicht."
        }

        if completedHabits == totalHabits {
            return "Alle Ziele für heute erreicht."
        }

        let missing = missingHabitTitles.prefix(2).joined(separator: " und ")
        return missing.isEmpty ? "Der Tag nimmt Form an." : "\(missing) sind noch offen."
    }

    var focusHabits: [FixedHabit] {
        habits
            .filter { progress(for: $0) < 1 }
            .sorted { progress(for: $0) < progress(for: $1) }
            .prefix(2)
            .map { $0 }
    }

    func selectToday() {
        selectedDate = Date()
        reload()
    }

    func reload() {
        guard let database else {
            entriesByKey = [:]
            weekHistoryByKey = emptyWeekHistory()
            weeklyDayProgress = makeWeeklyDayProgress(entries: [])
            errorMessage = nil
            return
        }

        do {
            let repository = HabitRepository(database: database)
            let dayEntries = try repository.fetchEntries(forDay: selectedDayKey)
            let weekEntries = try repository.fetchEntries(in: weekInterval, calendar: calendar)

            entriesByKey = dayEntries.reduce(into: [String: HabitEntryRecord]()) { result, entry in
                result[entry.habitKey] = entry
            }
            weekHistoryByKey = makeWeekHistory(entries: weekEntries)
            weeklyDayProgress = makeWeeklyDayProgress(entries: weekEntries)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func incrementValue(for habit: FixedHabit) {
        setValue(for: habit, value: value(for: habit) + habit.stepValue)
    }

    func decrementValue(for habit: FixedHabit) {
        setValue(for: habit, value: max(value(for: habit) - habit.stepValue, 0))
    }

    func setValue(for habit: FixedHabit, value: Double) {
        guard habits.contains(where: { $0.key == habit.key }), let database else { return }

        do {
            try HabitRepository(database: database).setValue(
                habitKey: habit.key,
                date: selectedDayKey,
                value: max(value, 0),
                target: habit.targetValue,
                unit: habit.unit
            )
            reload()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func toggleHabit(key: String) {
        guard let habit = habits.first(where: { $0.key == key }) else { return }

        if habit.isBoolean {
            toggleBooleanHabit(habit)
        } else if progress(for: habit) >= 1 {
            setValue(for: habit, value: 0)
        } else {
            setValue(for: habit, value: habit.targetValue)
        }
    }

    func toggleBooleanHabit(_ habit: FixedHabit) {
        guard habit.isBoolean, let database else { return }

        do {
            try HabitRepository(database: database).toggleBooleanHabit(
                habitKey: habit.key,
                date: selectedDayKey
            )
            reload()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func isCompleted(_ key: String) -> Bool {
        guard let habit = habits.first(where: { $0.key == key }) else {
            return entriesByKey[key]?.isCompleted ?? false
        }
        return progress(for: habit) >= 1
    }

    func value(for habit: FixedHabit) -> Double {
        guard let entry = entriesByKey[habit.key] else { return 0 }
        if let value = entry.value {
            return max(value, 0)
        }
        return entry.isCompleted ? habit.targetValue : 0
    }

    func progress(for habit: FixedHabit) -> Double {
        habit.progress(for: value(for: habit))
    }

    func weekHistory(for habit: FixedHabit) -> [HabitDayProgress] {
        weekHistoryByKey[habit.key] ?? []
    }

    static func progress(completed: Int, total: Int) -> Double {
        guard total > 0 else { return 0 }
        return min(max(Double(completed) / Double(total), 0), 1)
    }

    static func averageProgress(_ values: [Double]) -> Double {
        guard !values.isEmpty else { return 0 }
        let clampedValues = values.map { min(max($0, 0), 1) }
        return clampedValues.reduce(0, +) / Double(clampedValues.count)
    }

    private var selectedDayKey: String {
        DateIntervals.dayKey(for: selectedDate, calendar: calendar)
    }

    private var weekInterval: DateInterval {
        DateIntervals.week(containing: selectedDate, weekStartsOn: 2, calendar: calendar)
    }

    private func emptyWeekHistory() -> [String: [HabitDayProgress]] {
        Dictionary(uniqueKeysWithValues: habits.map { ($0.key, makeWeekHistory(for: $0, entriesByDate: [:])) })
    }

    private func makeWeekHistory(entries: [HabitEntryRecord]) -> [String: [HabitDayProgress]] {
        let entriesByHabitAndDate = entries.reduce(into: [String: [String: HabitEntryRecord]]()) { result, entry in
            result[entry.habitKey, default: [:]][entry.date] = entry
        }

        return Dictionary(uniqueKeysWithValues: habits.map { habit in
            (habit.key, makeWeekHistory(for: habit, entriesByDate: entriesByHabitAndDate[habit.key] ?? [:]))
        })
    }

    private func makeWeekHistory(for habit: FixedHabit, entriesByDate: [String: HabitEntryRecord]) -> [HabitDayProgress] {
        weekDays().map { day in
            let key = DateIntervals.dayKey(for: day, calendar: calendar)
            let entry = entriesByDate[key]
            let value = entry?.value ?? (entry?.isCompleted == true ? habit.targetValue : 0)
            return HabitDayProgress(
                date: day,
                label: Self.weekdayFormatter.string(from: day),
                progress: habit.progress(for: value),
                isToday: calendar.isDate(day, inSameDayAs: selectedDate)
            )
        }
    }

    private func makeWeeklyDayProgress(entries: [HabitEntryRecord]) -> [HabitDayProgress] {
        let entriesByDateAndHabit = entries.reduce(into: [String: [String: HabitEntryRecord]]()) { result, entry in
            result[entry.date, default: [:]][entry.habitKey] = entry
        }

        return weekDays().map { day in
            let key = DateIntervals.dayKey(for: day, calendar: calendar)
            let entriesByHabit = entriesByDateAndHabit[key] ?? [:]
            let progressValues = habits.map { habit -> Double in
                guard let entry = entriesByHabit[habit.key] else { return 0 }
                let value = entry.value ?? (entry.isCompleted ? habit.targetValue : 0)
                return habit.progress(for: value)
            }
            return HabitDayProgress(
                date: day,
                label: Self.weekdayFormatter.string(from: day),
                progress: Self.averageProgress(progressValues),
                isToday: calendar.isDate(day, inSameDayAs: selectedDate)
            )
        }
    }

    private func weekDays() -> [Date] {
        (0..<7).compactMap { offset in
            calendar.date(byAdding: .day, value: offset, to: calendar.startOfDay(for: weekInterval.start))
        }
    }

    private static let weekdayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "de_DE")
        formatter.dateFormat = "E"
        return formatter
    }()
}
