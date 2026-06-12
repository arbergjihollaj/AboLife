import Foundation
import SwiftUI

struct DashboardSnapshot {
    let greeting: String
    let dateLine: String
    let coreProgress: Double
    let coreMessage: String
    let nextStep: String
    let calories: ProgressMetric
    let protein: ProgressMetric
    let training: TrainingToday
    let finance: FinanceStatus
    let habits: HabitStatus
    let week: WeekStatus
    let bodyWeight: Double?
    let dailyNote: String?
    let recentActions: [DashboardActivityItem]
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
}

struct TrainingToday {
    let title: String
    let status: String
    let weeklyProgress: String
    let progress: Double
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

    var weeklyStatusItem: WeeklyStatusItem {
        WeeklyStatusItem(shortName: shortName, completion: completion, tint: tint)
    }
}

enum DashboardMockData {
    static let today = snapshot(from: .default)

    static func snapshot(from state: DashboardMockState) -> DashboardSnapshot {
        let coreProgress = DashboardStore.dailyCoreProgress(for: state)
        let completedHabitTitles = state.habits.filter(\.isCompleted).map(\.title)
        let openHabitTitles = state.habits.filter { !$0.isCompleted }.map(\.title)
        let trainingProgress = progress(current: Double(state.weeklyWorkoutCompleted), target: Double(state.weeklyWorkoutTarget))

        return DashboardSnapshot(
            greeting: "Guten Abend, Arber",
            dateLine: formattedDateLine(),
            coreProgress: coreProgress,
            coreMessage: coreMessage(for: state, coreProgress: coreProgress),
            nextStep: nextStep(for: state),
            calories: ProgressMetric(
                title: "Kalorien",
                current: Double(state.caloriesConsumed),
                target: Double(state.caloriesTarget),
                unit: "kcal",
                message: caloriesMessage(for: state),
                trend: updatedTrend(base: [0.54, 0.62, 0.58, 0.70, 0.65, 0.72], current: progress(current: Double(state.caloriesConsumed), target: Double(state.caloriesTarget)))
            ),
            protein: ProgressMetric(
                title: "Protein",
                current: state.proteinConsumed,
                target: state.proteinTarget,
                unit: "g",
                message: proteinMessage(for: state),
                trend: updatedTrend(base: [0.42, 0.51, 0.49, 0.56, 0.60, 0.63], current: progress(current: state.proteinConsumed, target: state.proteinTarget))
            ),
            training: TrainingToday(
                title: "Training heute",
                status: trainingStatus(for: state),
                weeklyProgress: "\(state.weeklyWorkoutCompleted) / \(state.weeklyWorkoutTarget) Einheiten diese Woche",
                progress: trainingProgress,
                isDone: state.weeklyWorkoutCompleted >= state.weeklyWorkoutTarget
            ),
            finance: FinanceStatus(
                title: "Finanzen",
                remainingToday: state.dailyBudgetRemaining,
                spentThisMonth: state.monthlySpent,
                monthlyBudget: state.monthlyBudget,
                message: financeMessage(for: state)
            ),
            habits: HabitStatus(
                title: "Gewohnheiten",
                completed: state.completedHabits,
                total: state.totalHabits,
                message: habitMessage(completed: completedHabitTitles, open: openHabitTitles)
            ),
            week: WeekStatus(
                title: "7-Tage-Wochenstatus",
                message: "Heute reagiert live auf deine lokalen Einträge.",
                days: weekDays(todayCompletion: coreProgress)
            ),
            bodyWeight: state.bodyWeight,
            dailyNote: state.dailyNote,
            recentActions: state.recentActions
        )
    }

    private static func formattedDateLine() -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "de_DE")
        formatter.dateFormat = "EEEE, d. MMMM"
        return formatter.string(from: Date())
    }

    private static func progress(current: Double, target: Double) -> Double {
        guard target > 0 else { return 0 }
        return min(max(current / target, 0), 1)
    }

    private static func updatedTrend(base: [Double], current: Double) -> [Double] {
        base + [min(max(current, 0), 1)]
    }

    private static func coreMessage(for state: DashboardMockState, coreProgress: Double) -> String {
        if coreProgress >= 0.80 {
            return "Der Tag steht sehr solide. Ernährung, Training und Habits ziehen gemeinsam nach oben."
        }

        if state.weeklyWorkoutCompleted < state.weeklyWorkoutTarget {
            return "Der Tag ist stabil. Protein und Habits helfen, Training ist noch der größte Hebel."
        }

        return "Der Tag bewegt sich. Ein kleiner Eintrag reicht, damit das Dashboard direkt reagiert."
    }

    private static func nextStep(for state: DashboardMockState) -> String {
        if state.proteinConsumed < state.proteinTarget {
            return "Nächster sinnvoller Schritt: proteinreiche Mahlzeit erfassen."
        }

        if state.weeklyWorkoutCompleted < state.weeklyWorkoutTarget {
            return "Nächster sinnvoller Schritt: Training abschließen."
        }

        if state.completedHabits < state.totalHabits {
            return "Nächster sinnvoller Schritt: eine offene Gewohnheit abhaken."
        }

        return "Nächster sinnvoller Schritt: kurze Tagesnotiz festhalten."
    }

    private static func caloriesMessage(for state: DashboardMockState) -> String {
        let remaining = state.caloriesTarget - state.caloriesConsumed
        if remaining > 0 {
            return "Noch \(remaining) kcal im Tagesrahmen."
        }

        return "\(abs(remaining)) kcal über dem Tagesziel."
    }

    private static func proteinMessage(for state: DashboardMockState) -> String {
        let remaining = Int(max(state.proteinTarget - state.proteinConsumed, 0))
        if remaining > 0 {
            return "Noch \(remaining) g Protein bis zum Tagesziel."
        }

        return "Proteinziel für heute erreicht."
    }

    private static func trainingStatus(for state: DashboardMockState) -> String {
        if let type = state.lastWorkoutType, let duration = state.lastWorkoutDurationMinutes {
            return "\(type) erledigt · \(duration) Min"
        }

        return state.weeklyWorkoutCompleted >= state.weeklyWorkoutTarget ? "Wochentraining erledigt" : "Push Day offen"
    }

    private static func financeMessage(for state: DashboardMockState) -> String {
        let remaining = state.monthlyBudget - state.monthlySpent
        if remaining >= 0 {
            return "\(Int(remaining)) EUR bleiben im Monatsbudget."
        }

        return "\(Int(abs(remaining))) EUR über Monatsbudget."
    }

    private static func habitMessage(completed: [String], open: [String]) -> String {
        if open.isEmpty {
            return "Alle Gewohnheiten für heute erledigt."
        }

        return "\(open.prefix(2).joined(separator: " und ")) fehlen noch."
    }

    private static func weekDays(todayCompletion: Double) -> [DashboardDayStatus] {
        [
            DashboardDayStatus(shortName: "Mo", completion: 0.82, tint: AboLifeColors.review),
            DashboardDayStatus(shortName: "Di", completion: 0.70, tint: AboLifeColors.review),
            DashboardDayStatus(shortName: "Mi", completion: 0.88, tint: AboLifeColors.review),
            DashboardDayStatus(shortName: "Do", completion: todayCompletion, tint: AboLifeColors.review),
            DashboardDayStatus(shortName: "Fr", completion: 0.35, tint: AboLifeColors.review),
            DashboardDayStatus(shortName: "Sa", completion: 0.18, tint: AboLifeColors.review),
            DashboardDayStatus(shortName: "So", completion: 0.10, tint: AboLifeColors.review)
        ]
    }
}
