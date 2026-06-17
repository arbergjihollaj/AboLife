import SwiftUI

enum HabitKind: String, Codable, Equatable {
    case numeric
    case count
    case boolean
    case derived
}

struct FixedHabit: Identifiable {
    let key: String
    let title: String
    let systemImage: String
    let kind: HabitKind
    let targetValue: Double
    let unit: String
    let stepValue: Double
    let accent: Color

    var id: String { key }

    var isBoolean: Bool {
        kind == .boolean
    }

    var isDerived: Bool {
        kind == .derived
    }

    func progress(for value: Double) -> Double {
        Self.progress(value: value, target: targetValue)
    }

    func displayValue(_ value: Double) -> String {
        switch key {
        case "water":
            return "\(Self.decimalFormatter.string(from: NSNumber(value: value)) ?? "0") / \(Self.decimalFormatter.string(from: NSNumber(value: targetValue)) ?? "0") \(unit)"
        case "training":
            return "\(Int(value.rounded())) / \(Int(targetValue.rounded()))"
        case "learning":
            return "\(Int(value.rounded())) / \(Int(targetValue.rounded())) \(unit)"
        case "nutrition":
            return "\(Int(value.rounded())) / \(Int(targetValue.rounded())) \(unit)"
        default:
            return "\(Int(value.rounded())) / \(Int(targetValue.rounded()))"
        }
    }

    static func progress(value: Double, target: Double) -> Double {
        guard target > 0 else { return 0 }
        return min(max(value / target, 0), 1)
    }

    static func value(isCompleted: Bool, target: Double) -> Double {
        isCompleted ? max(target, 1) : 0
    }

    static func defaultDefinition(for key: String) -> FixedHabit? {
        defaults.first { $0.key == key }
    }

    static let defaults: [FixedHabit] = [
        FixedHabit(
            key: "water",
            title: "Wasser",
            systemImage: "drop.fill",
            kind: .numeric,
            targetValue: 3.0,
            unit: "Liter",
            stepValue: 0.25,
            accent: Color(red: 0.36, green: 0.70, blue: 0.95)
        ),
        FixedHabit(
            key: "training",
            title: "Trainieren",
            systemImage: "figure.strengthtraining.traditional",
            kind: .derived,
            targetValue: 1,
            unit: "",
            stepValue: 0,
            accent: AboLifeColors.training
        ),
        FixedHabit(
            key: "nutrition",
            title: "Ernährung getrackt",
            systemImage: "fork.knife",
            kind: .count,
            targetValue: 3,
            unit: "Mahlzeiten",
            stepValue: 1,
            accent: AboLifeColors.nutrition
        ),
        FixedHabit(
            key: "learning",
            title: "Lernen",
            systemImage: "book.fill",
            kind: .numeric,
            targetValue: 60,
            unit: "Min.",
            stepValue: 15,
            accent: Color(red: 0.64, green: 0.55, blue: 0.92)
        ),
        FixedHabit(
            key: "sleep",
            title: "Schlafroutine",
            systemImage: "moon.stars.fill",
            kind: .boolean,
            targetValue: 1,
            unit: "",
            stepValue: 1,
            accent: Color(red: 0.96, green: 0.75, blue: 0.36)
        )
    ]

    private static let decimalFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "de_DE")
        formatter.minimumFractionDigits = 1
        formatter.maximumFractionDigits = 2
        return formatter
    }()
}

struct HabitDayProgress: Identifiable, Equatable {
    let date: Date
    let label: String
    let progress: Double
    let isToday: Bool

    var id: String {
        DateIntervals.dayKey(for: date)
    }
}
