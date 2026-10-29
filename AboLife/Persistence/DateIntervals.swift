import Foundation

enum DateIntervals {
    static func day(containing date: Date = Date(), calendar: Calendar = .current) -> DateInterval {
        let start = calendar.startOfDay(for: date)
        let end = calendar.date(byAdding: .day, value: 1, to: start) ?? start
        return DateInterval(start: start, end: end)
    }

    static func week(containing date: Date = Date(), weekStartsOn: Int = 2, calendar: Calendar = .current) -> DateInterval {
        var calendar = calendar
        calendar.firstWeekday = weekStartsOn
        return calendar.dateInterval(of: .weekOfYear, for: date) ?? day(containing: date, calendar: calendar)
    }

    static func month(containing date: Date = Date(), calendar: Calendar = .current) -> DateInterval {
        calendar.dateInterval(of: .month, for: date) ?? day(containing: date, calendar: calendar)
    }

    static func dayKey(for date: Date = Date(), calendar: Calendar = .current) -> String {
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        return String(
            format: "%04d-%02d-%02d",
            components.year ?? 0,
            components.month ?? 0,
            components.day ?? 0
        )
    }
}
