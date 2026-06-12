import Foundation
import GRDB

struct HabitRepository {
    private let database: AppDatabase

    init(database: AppDatabase) {
        self.database = database
    }

    func insert(_ entry: HabitEntryRecord) throws {
        try database.writer.write { db in
            try entry.insert(db)
        }
    }

    func fetchAll() throws -> [HabitEntryRecord] {
        try database.writer.read { db in
            try HabitEntryRecord
                .order(Column("date").desc, Column("habit_key"))
                .fetchAll(db)
        }
    }

    func fetch(for date: String) throws -> [HabitEntryRecord] {
        try database.writer.read { db in
            try HabitEntryRecord
                .filter(Column("date") == date)
                .order(Column("habit_key"))
                .fetchAll(db)
        }
    }

    func fetchEntries(forDay date: String) throws -> [HabitEntryRecord] {
        try fetch(for: date)
    }

    func fetchEntries(forDay date: Date = Date(), calendar: Calendar = .current) throws -> [HabitEntryRecord] {
        try fetchEntries(forDay: DateIntervals.dayKey(for: date, calendar: calendar))
    }

    func fetchEntries(inWeekContaining date: Date = Date(), weekStartsOn: Int = 2, calendar: Calendar = .current) throws -> [HabitEntryRecord] {
        try fetchEntries(in: DateIntervals.week(containing: date, weekStartsOn: weekStartsOn, calendar: calendar), calendar: calendar)
    }

    func fetchEntries(in interval: DateInterval, calendar: Calendar = .current) throws -> [HabitEntryRecord] {
        let startKey = DateIntervals.dayKey(for: interval.start, calendar: calendar)
        let inclusiveEnd = calendar.date(byAdding: .day, value: -1, to: interval.end) ?? interval.end
        let endKey = DateIntervals.dayKey(for: inclusiveEnd, calendar: calendar)

        return try database.writer.read { db in
            try HabitEntryRecord
                .filter(Column("date") >= startKey && Column("date") <= endKey)
                .order(Column("date").desc, Column("habit_key"))
                .fetchAll(db)
        }
    }

    func fetchEntry(habitKey: String, date: String) throws -> HabitEntryRecord? {
        try database.writer.read { db in
            try HabitEntryRecord
                .filter(Column("habit_key") == habitKey && Column("date") == date)
                .fetchOne(db)
        }
    }

    func upsertCompletion(habitKey: String, date: String, isCompleted: Bool) throws {
        let now = Date()
        let definition = FixedHabit.defaultDefinition(for: habitKey)
        let target = definition?.targetValue ?? 1
        let unit = definition?.unit ?? ""
        let value = FixedHabit.value(isCompleted: isCompleted, target: target)

        try database.writer.write { db in
            if var existing = try HabitEntryRecord
                .filter(Column("habit_key") == habitKey && Column("date") == date)
                .fetchOne(db) {
                existing.isCompleted = isCompleted
                existing.value = value
                existing.targetValue = target
                existing.unit = unit
                existing.updatedAt = now
                try existing.update(db)
            } else {
                let entry = HabitEntryRecord(
                    habitKey: habitKey,
                    date: date,
                    isCompleted: isCompleted,
                    value: value,
                    targetValue: target,
                    unit: unit,
                    createdAt: now,
                    updatedAt: now
                )
                try entry.insert(db)
            }
        }
    }

    func setValue(habitKey: String, date: String, value: Double, target: Double, unit: String) throws {
        try upsertMeasurement(
            habitKey: habitKey,
            date: date,
            value: max(value, 0),
            target: target,
            unit: unit
        )
    }

    func incrementValue(habitKey: String, date: String, amount: Double, target: Double, unit: String) throws {
        let currentValue = try measuredValue(habitKey: habitKey, date: date)
        try setValue(habitKey: habitKey, date: date, value: currentValue + amount, target: target, unit: unit)
    }

    func decrementValue(habitKey: String, date: String, amount: Double, target: Double, unit: String) throws {
        let currentValue = try measuredValue(habitKey: habitKey, date: date)
        try setValue(habitKey: habitKey, date: date, value: max(currentValue - amount, 0), target: target, unit: unit)
    }

    func toggleBooleanHabit(habitKey: String, date: String) throws {
        let nextValue = !(try fetchEntry(habitKey: habitKey, date: date)?.isCompleted ?? false)
        try upsertCompletion(habitKey: habitKey, date: date, isCompleted: nextValue)
    }

    func upsertMeasurement(habitKey: String, date: String, value: Double, target: Double, unit: String) throws {
        let now = Date()
        let normalizedValue = max(value, 0)
        let normalizedTarget = max(target, 0)
        let isCompleted = normalizedTarget > 0 && normalizedValue >= normalizedTarget

        try database.writer.write { db in
            if var existing = try HabitEntryRecord
                .filter(Column("habit_key") == habitKey && Column("date") == date)
                .fetchOne(db) {
                existing.value = normalizedValue
                existing.targetValue = normalizedTarget
                existing.unit = unit
                existing.isCompleted = isCompleted
                existing.updatedAt = now
                try existing.update(db)
            } else {
                let entry = HabitEntryRecord(
                    habitKey: habitKey,
                    date: date,
                    isCompleted: isCompleted,
                    value: normalizedValue,
                    targetValue: normalizedTarget,
                    unit: unit,
                    createdAt: now,
                    updatedAt: now
                )
                try entry.insert(db)
            }
        }
    }

    func clearCompletion(habitKey: String, date: String) throws {
        try database.writer.write { db in
            _ = try HabitEntryRecord
                .filter(Column("habit_key") == habitKey && Column("date") == date)
                .deleteAll(db)
        }
    }

    func delete(id: String) throws {
        try database.writer.write { db in
            _ = try HabitEntryRecord.deleteOne(db, key: id)
        }
    }

    func completedCount(for date: String) throws -> Int {
        try fetchEntries(forDay: date).filter { isEffectivelyCompleted($0) }.count
    }

    func dailySummary(forDay date: String, totalHabits: Int) throws -> HabitDailySummary {
        HabitDailySummary(
            completed: try completedCount(for: date),
            total: totalHabits
        )
    }

    func dailySummary(forDay date: String, habitKeys: [String]) throws -> HabitDailySummary {
        let entries = try fetchEntries(forDay: date)
        let allowedKeys = Set(habitKeys)
        let completed = entries.filter { allowedKeys.contains($0.habitKey) && isEffectivelyCompleted($0) }.count

        return HabitDailySummary(
            completed: completed,
            total: habitKeys.count
        )
    }

    func weeklySummary(in interval: DateInterval, habitKeys: [String], days: Int, calendar: Calendar = .current) throws -> HabitWeeklySummary {
        let entries = try fetchEntries(in: interval, calendar: calendar)
        let allowedKeys = Set(habitKeys)
        let completedKeys = Set(entries.compactMap { entry -> String? in
            guard allowedKeys.contains(entry.habitKey), isEffectivelyCompleted(entry) else { return nil }
            return "\(entry.date)-\(entry.habitKey)"
        })

        return HabitWeeklySummary(
            completed: completedKeys.count,
            total: max(days, 0) * habitKeys.count
        )
    }

    func weeklySummary(forDate date: Date = Date(), weekStartsOn: Int = 2, habitKeys: [String], days: Int = 7, calendar: Calendar = .current) throws -> HabitWeeklySummary {
        try weeklySummary(
            in: DateIntervals.week(containing: date, weekStartsOn: weekStartsOn, calendar: calendar),
            habitKeys: habitKeys,
            days: days,
            calendar: calendar
        )
    }

    func deleteAll() throws {
        try database.writer.write { db in
            _ = try HabitEntryRecord.deleteAll(db)
        }
    }

    private func measuredValue(habitKey: String, date: String) throws -> Double {
        guard let entry = try fetchEntry(habitKey: habitKey, date: date) else { return 0 }
        if let value = entry.value {
            return value
        }
        let target = entry.targetValue ?? FixedHabit.defaultDefinition(for: habitKey)?.targetValue ?? 1
        return entry.isCompleted ? target : 0
    }

    private func isEffectivelyCompleted(_ entry: HabitEntryRecord) -> Bool {
        if let value = entry.value, let target = entry.targetValue, target > 0 {
            return value >= target
        }
        return entry.isCompleted
    }
}

struct HabitDailySummary: Equatable {
    let completed: Int
    let total: Int

    var progress: Double {
        guard total > 0 else { return 0 }
        return min(max(Double(completed) / Double(total), 0), 1)
    }
}

struct HabitWeeklySummary: Equatable {
    let completed: Int
    let total: Int

    var progress: Double {
        guard total > 0 else { return 0 }
        return min(max(Double(completed) / Double(total), 0), 1)
    }
}
