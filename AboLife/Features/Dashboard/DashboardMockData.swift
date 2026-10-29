import Foundation
import SwiftUI

struct DashboardSnapshot {
    let greeting: String
    let dateLine: String
    let coreProgress: Double
    let coreMessage: String
    let nextStep: String
    let training: TrainingToday
    let finance: FinanceStatus
    let habits: HabitStatus
    let week: WeekStatus
    let weight: WeightDashboardStatus
    let todayOpen: TodayOpenStatus
    let recentActions: [DashboardActivityItem]
}



struct TrainingToday {
    let title: String
    let status: String
    let weeklyProgress: String
    let todayStatus: TodayTrainingStatus
    let nextWorkout: String
    let progressDetail: String?
    let calmMessage: String
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
    let progressValue: Double
    let items: [DashboardHabit]

    var progress: Double {
        progressValue
    }
}

struct WeekStatus {
    let title: String
    let message: String
    let days: [DashboardDayStatus]
}

struct WeightDashboardStatus {
    let valueKg: Double?
    let date: String?
    let changeKg: Double?

    var hasValue: Bool {
        valueKg != nil
    }

    var valueText: String {
        guard let valueKg else { return "Noch kein Gewicht" }
        return String(format: "%.1f kg", valueKg)
    }

    var dateText: String {
        guard let date else { return "Nicht erfasst" }
        if date == DateIntervals.dayKey() {
            return "Heute"
        }
        return "Letzter Wert: \(Self.formattedDay(date))"
    }

    var changeText: String? {
        guard let changeKg else { return nil }
        if abs(changeKg) < 0.05 {
            return "+/-0.0 kg"
        }
        return String(format: "%+.1f kg", changeKg)
    }

    private static func formattedDay(_ dayKey: String) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "de_DE")
        formatter.dateFormat = "yyyy-MM-dd"
        guard let date = formatter.date(from: dayKey) else { return dayKey }
        return date.formatted(.dateTime.day().month(.abbreviated))
    }
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
        let todayWorkout = HomeWorkoutPlanProvider.plan.workout(for: Date())
        let todayOpen = TodayOpenStatus.calculate(
            workoutCompletedToday: state.workoutCompletedToday,
            trainingPausedToday: state.trainingPausedToday,
            trainingScheduledToday: state.trainingScheduledToday,
            habitValues: Dictionary(uniqueKeysWithValues: state.habits.map { ($0.key, $0.value) }),
            dailyBudgetRemaining: state.dailyBudgetRemaining
        )

        return DashboardSnapshot(
            greeting: Calendar.current.component(.hour, from: Date()) < 11 ? "Guten Morgen, \(DemoData.isEnabled ? "Alex" : "Arber")" : Calendar.current.component(.hour, from: Date()) < 18 ? "Hallo, \(DemoData.isEnabled ? "Alex" : "Arber")" : "Guten Abend, \(DemoData.isEnabled ? "Alex" : "Arber")",
            dateLine: formattedDateLine(),
            coreProgress: coreProgress,
            coreMessage: coreMessage(for: state, coreProgress: coreProgress),
            nextStep: todayOpen.nextStep ?? "Der Tag steht gut. Du kannst ihn ruhig ausklingen lassen.",
            training: TrainingToday(
                title: "Training heute",
                status: trainingStatus(for: state),
                weeklyProgress: "\(state.weeklyWorkoutCompleted) / \(state.weeklyWorkoutTarget) Einheiten diese Woche",
                todayStatus: todayOpen.training,
                nextWorkout: todayWorkout.isToday ? todayWorkout.day.name : "\(todayWorkout.day.name) am \(todayWorkout.day.weekdayName)",
                progressDetail: state.lastWorkoutType.map { "Letztes Training: \($0)." },
                calmMessage: calmTrainingMessage(for: state, todayOpen: todayOpen),
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
                message: habitMessage(completed: completedHabitTitles, open: openHabitTitles),
                progressValue: state.habitProgress,
                items: state.habits
            ),
            week: WeekStatus(
                title: "7-Tage-Wochenstatus",
                message: "Heute reagiert live auf deine lokalen Einträge.",
                days: weekDays(todayCompletion: coreProgress)
            ),
            weight: WeightDashboardStatus(
                valueKg: state.bodyWeight,
                date: state.bodyWeightDate,
                changeKg: state.bodyWeightChange
            ),
            todayOpen: todayOpen,
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



    private static func coreMessage(for state: DashboardMockState, coreProgress: Double) -> String {
        if coreProgress >= 0.80 {
            return "Der Tag steht sehr solide. Deine Gewohnheiten und dein Budget sind auf Kurs."
        }

        if state.weeklyWorkoutCompleted < state.weeklyWorkoutTarget {
            return "Der Tag ist stabil. Deine Gewohnheiten geben dem Tag Struktur."
        }

        return "Der Tag bewegt sich. Ein kleiner Eintrag reicht, damit das Dashboard direkt reagiert."
    }





    private static func trainingStatus(for state: DashboardMockState) -> String {
        if state.trainingPausedToday {
            return "Heute pausiert"
        }
        if let type = state.lastWorkoutType, let duration = state.lastWorkoutDurationMinutes {
            return "\(type) erledigt · \(duration) Min"
        }

        let scheduled = HomeWorkoutPlanProvider.plan.workout(for: Date())
        if scheduled.isToday {
            return "\(scheduled.day.name) offen"
        }
        return state.weeklyWorkoutCompleted >= state.weeklyWorkoutTarget ? "Wochentraining erledigt" : "Heute kein Plantraining"
    }

    private static func calmTrainingMessage(for state: DashboardMockState, todayOpen: TodayOpenStatus) -> String {
        if todayOpen.training == .paused {
            return "Pause ist okay. Morgen wieder sauber einsteigen reicht."
        }
        if todayOpen.training == .open {
            return "Heute reicht auch die Minimum-Variante."
        }
        if state.weeklyWorkoutCompleted >= state.weeklyWorkoutTarget {
            return "Wochenziel erreicht. Jetzt geht es um Erholung."
        }
        return "Diese Woche \(state.weeklyWorkoutCompleted) von \(state.weeklyWorkoutTarget) Trainings erledigt."
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

        return "Noch offen: \(open.joined(separator: ", "))."
    }

    private static func weekDays(todayCompletion: Double) -> [DashboardDayStatus] {
        let calendar = Calendar.current
        let interval = DateIntervals.week(weekStartsOn: SeedData.defaultSettings.weekStartsOn, calendar: calendar)
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "de_DE")
        formatter.dateFormat = "E"

        return (0..<7).compactMap { offset in
            guard let date = calendar.date(byAdding: .day, value: offset, to: interval.start) else { return nil }
            return DashboardDayStatus(
                shortName: formatter.string(from: date),
                completion: calendar.isDateInToday(date) ? todayCompletion : 0,
                tint: AboLifeColors.review
            )
        }
    }
}
