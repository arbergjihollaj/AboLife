import Foundation
import Combine

final class DashboardStore: ObservableObject {
    @Published private(set) var snapshot: DashboardSnapshot
    @Published private(set) var state: DashboardMockState

    init(state: DashboardMockState = .default) {
        self.state = state
        self.snapshot = DashboardMockData.snapshot(from: state)
    }

    convenience init(snapshot: DashboardSnapshot) {
        self.init(state: .default)
        self.snapshot = snapshot
    }

    func addMeal(name: String, calories: Int, protein: Double) {
        let mealName = trimmedOrDefault(name, defaultValue: "Mahlzeit")
        state.caloriesConsumed += max(calories, 0)
        state.proteinConsumed += max(protein, 0)
        addActivity(title: "Mahlzeit hinzugefügt", detail: "\(mealName) · \(max(calories, 0)) kcal · \(Int(max(protein, 0))) g Protein")
        refreshSnapshot()
    }

    func completeWorkout(type: String, durationMinutes: Int) {
        let workoutType = trimmedOrDefault(type, defaultValue: "Training")
        if state.weeklyWorkoutCompleted < state.weeklyWorkoutTarget {
            state.weeklyWorkoutCompleted += 1
        }
        state.lastWorkoutType = workoutType
        state.lastWorkoutDurationMinutes = max(durationMinutes, 0)
        addActivity(title: "Training abgeschlossen", detail: "\(workoutType) · \(max(durationMinutes, 0)) Min")
        refreshSnapshot()
    }

    func addExpense(title: String, amount: Double, category: String?) {
        let expenseTitle = trimmedOrDefault(title, defaultValue: "Ausgabe")
        let normalizedAmount = max(amount, 0)
        state.monthlySpent += normalizedAmount

        let categoryText = trimmedOrDefault(category ?? "", defaultValue: "Sonstiges")
        addActivity(title: "Ausgabe hinzugefügt", detail: "\(expenseTitle) · \(Int(normalizedAmount)) EUR · \(categoryText)")
        refreshSnapshot()
    }

    func toggleHabit(_ habitID: DashboardHabit.ID) {
        guard let index = state.habits.firstIndex(where: { $0.id == habitID }) else { return }
        state.habits[index].isCompleted.toggle()

        let habit = state.habits[index]
        let status = habit.isCompleted ? "abgehakt" : "wieder geöffnet"
        addActivity(title: "Gewohnheit aktualisiert", detail: "\(habit.title) \(status)")
        refreshSnapshot()
    }

    func updateWeight(_ weight: Double) {
        state.bodyWeight = max(weight, 0)
        addActivity(title: "Gewicht erfasst", detail: "\(String(format: "%.1f", max(weight, 0))) kg")
        refreshSnapshot()
    }

    func updateDailyNote(_ note: String) {
        let trimmed = note.trimmingCharacters(in: .whitespacesAndNewlines)
        state.dailyNote = trimmed.isEmpty ? nil : trimmed
        addActivity(title: "Notiz gespeichert", detail: trimmed.isEmpty ? "Tagesnotiz geleert" : trimmed)
        refreshSnapshot()
    }

    static func dailyCoreProgress(for state: DashboardMockState) -> Double {
        let calories = progress(current: Double(state.caloriesConsumed), target: Double(state.caloriesTarget))
        let protein = progress(current: state.proteinConsumed, target: state.proteinTarget)
        let training = progress(current: Double(state.weeklyWorkoutCompleted), target: Double(state.weeklyWorkoutTarget))
        let habits = progress(current: Double(state.completedHabits), target: Double(state.totalHabits))
        let budget = budgetScore(spent: state.monthlySpent, budget: state.monthlyBudget)

        return clamp((calories + protein + training + habits + budget) / 5)
    }

    private func refreshSnapshot() {
        snapshot = DashboardMockData.snapshot(from: state)
    }

    private func addActivity(title: String, detail: String) {
        state.recentActions.insert(
            DashboardActivityItem(title: title, detail: detail, createdAt: Date()),
            at: 0
        )
        state.recentActions = Array(state.recentActions.prefix(5))
    }

    private func trimmedOrDefault(_ value: String, defaultValue: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? defaultValue : trimmed
    }

    private static func progress(current: Double, target: Double) -> Double {
        guard target > 0 else { return 0 }
        return clamp(current / target)
    }

    private static func budgetScore(spent: Double, budget: Double) -> Double {
        guard budget > 0 else { return 1 }
        return clamp(1 - (spent / budget))
    }

    private static func clamp(_ value: Double) -> Double {
        min(max(value, 0), 1)
    }
}

struct DashboardMockState {
    var caloriesConsumed: Int
    var caloriesTarget: Int
    var proteinConsumed: Double
    var proteinTarget: Double
    var weeklyWorkoutCompleted: Int
    var weeklyWorkoutTarget: Int
    var monthlySpent: Double
    var monthlyBudget: Double
    var habits: [DashboardHabit]
    var bodyWeight: Double?
    var dailyNote: String?
    var recentActions: [DashboardActivityItem]
    var lastWorkoutType: String?
    var lastWorkoutDurationMinutes: Int?

    var completedHabits: Int {
        habits.filter(\.isCompleted).count
    }

    var totalHabits: Int {
        habits.count
    }

    var dailyBudgetRemaining: Double {
        max((monthlyBudget - monthlySpent) / 18, 0)
    }

    static let `default` = DashboardMockState(
        caloriesConsumed: 1450,
        caloriesTarget: 2200,
        proteinConsumed: 95,
        proteinTarget: 160,
        weeklyWorkoutCompleted: 2,
        weeklyWorkoutTarget: 3,
        monthlySpent: 684,
        monthlyBudget: 1200,
        habits: [
            DashboardHabit(key: "morning_water", title: "Wasser", isCompleted: false),
            DashboardHabit(key: "walk", title: "10 Minuten gehen", isCompleted: true),
            DashboardHabit(key: "protein", title: "Protein priorisieren", isCompleted: true),
            DashboardHabit(key: "reading", title: "Lesen", isCompleted: false),
            DashboardHabit(key: "budget_check", title: "Budget checken", isCompleted: true)
        ],
        bodyWeight: nil,
        dailyNote: nil,
        recentActions: [
            DashboardActivityItem(title: "Mock-Tag geladen", detail: "Alle Werte sind nur In-Memory.", createdAt: Date())
        ],
        lastWorkoutType: nil,
        lastWorkoutDurationMinutes: nil
    )
}

struct DashboardHabit: Identifiable, Equatable {
    let id: UUID
    let key: String
    let title: String
    var isCompleted: Bool

    init(id: UUID = UUID(), key: String, title: String, isCompleted: Bool) {
        self.id = id
        self.key = key
        self.title = title
        self.isCompleted = isCompleted
    }
}

struct DashboardActivityItem: Identifiable, Equatable {
    let id: UUID
    let title: String
    let detail: String
    let createdAt: Date

    init(id: UUID = UUID(), title: String, detail: String, createdAt: Date) {
        self.id = id
        self.title = title
        self.detail = detail
        self.createdAt = createdAt
    }
}
