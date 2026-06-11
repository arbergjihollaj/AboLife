import Foundation
import SwiftUI

struct DashboardSnapshot {
    let greeting: String
    let dateLine: String
    let coreProgress: Double
    let coreMessage: String
    let calories: ProgressMetric
    let protein: ProgressMetric
    let training: TrainingToday
    let finance: FinanceStatus
    let habits: HabitStatus
    let week: WeekStatus
}

struct ProgressMetric {
    let title: String
    let current: Double
    let target: Double
    let unit: String
    let message: String
    let trend: [Double]

    var progress: Double {
        guard target > 0 else { return 0 }
        return min(max(current / target, 0), 1)
    }

    var valueText: String {
        "\(Int(current)) / \(Int(target)) \(unit)"
    }
}

struct TrainingToday {
    let title: String
    let status: String
    let weeklyProgress: String
    let isDone: Bool
}

struct FinanceStatus {
    let title: String
    let remainingToday: Double
    let spentThisMonth: Double
    let monthlyBudget: Double
    let message: String
}

struct HabitStatus {
    let title: String
    let completed: Int
    let total: Int
    let message: String

    var progress: Double {
        guard total > 0 else { return 0 }
        return Double(completed) / Double(total)
    }

    var valueText: String {
        "\(completed) / \(total)"
    }
}

struct WeekStatus {
    let title: String
    let message: String
    let days: [DashboardDayStatus]
}

struct DashboardDayStatus: Identifiable {
    let id = UUID()
    let shortName: String
    let completion: Double
    let tint: Color
}

enum DashboardMockData {
    static let today = DashboardSnapshot(
        greeting: "Guten Abend, Arber",
        dateLine: "Donnerstag, 11. Juni",
        coreProgress: 0.72,
        coreMessage: "Der Tag ist stabil. Protein und Habits halten die Linie, Training ist noch offen.",
        calories: ProgressMetric(
            title: "Kalorien",
            current: 1450,
            target: 2200,
            unit: "kcal",
            message: "Noch 750 kcal im Tagesrahmen.",
            trend: [0.54, 0.62, 0.58, 0.70, 0.65, 0.72, 0.66]
        ),
        protein: ProgressMetric(
            title: "Protein",
            current: 95,
            target: 160,
            unit: "g",
            message: "Eine proteinreiche Mahlzeit fehlt noch.",
            trend: [0.42, 0.51, 0.49, 0.56, 0.60, 0.63, 0.59]
        ),
        training: TrainingToday(
            title: "Training heute",
            status: "Push Day offen",
            weeklyProgress: "2 / 3 Einheiten diese Woche",
            isDone: false
        ),
        finance: FinanceStatus(
            title: "Finanzen",
            remainingToday: 42,
            spentThisMonth: 684,
            monthlyBudget: 1200,
            message: "Monat bleibt ruhig im Rahmen."
        ),
        habits: HabitStatus(
            title: "Gewohnheiten",
            completed: 3,
            total: 5,
            message: "Wasser und Lesen fehlen noch."
        ),
        week: WeekStatus(
            title: "7-Tage-Wochenstatus",
            message: "Solides Momentum mit Luft nach oben am Wochenende.",
            days: [
                DashboardDayStatus(shortName: "Mo", completion: 0.82, tint: AboLifeColors.review),
                DashboardDayStatus(shortName: "Di", completion: 0.70, tint: AboLifeColors.review),
                DashboardDayStatus(shortName: "Mi", completion: 0.88, tint: AboLifeColors.review),
                DashboardDayStatus(shortName: "Do", completion: 0.72, tint: AboLifeColors.review),
                DashboardDayStatus(shortName: "Fr", completion: 0.35, tint: AboLifeColors.review),
                DashboardDayStatus(shortName: "Sa", completion: 0.18, tint: AboLifeColors.review),
                DashboardDayStatus(shortName: "So", completion: 0.10, tint: AboLifeColors.review)
            ]
        )
    )
}
