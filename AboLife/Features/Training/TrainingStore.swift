import Foundation

final class TrainingStore: ObservableObject {
    @Published var selectedDate: Date {
        didSet {
            guard !calendar.isDate(selectedDate, equalTo: oldValue, toGranularity: .weekOfYear) else { return }
            reload()
        }
    }
    @Published private(set) var sessions: [WorkoutSessionRecord] = []
    @Published private(set) var weeklyWorkoutTarget: Int
    @Published private(set) var errorMessage: String?
    @Published private(set) var completionMessage: String?
    @Published private(set) var isSavingPlanWorkout = false

    private let database: AppDatabase?
    private let calendar: Calendar
    private var weekStartsOn: Int
    private let homeWorkoutPlan: HomeWorkoutPlan
    private let now: () -> Date

    init(
        database: AppDatabase?,
        selectedDate: Date = Date(),
        calendar: Calendar = .current,
        weeklyWorkoutTarget: Int = SeedData.defaultSettings.weeklyWorkoutTarget,
        homeWorkoutPlan: HomeWorkoutPlan = HomeWorkoutPlanProvider.plan,
        now: @escaping () -> Date = Date.init
    ) {
        self.database = database
        self.selectedDate = selectedDate
        self.calendar = calendar
        self.weekStartsOn = SeedData.defaultSettings.weekStartsOn
        self.weeklyWorkoutTarget = weeklyWorkoutTarget
        self.homeWorkoutPlan = homeWorkoutPlan
        self.now = now
        reload()
    }

    var completedWorkoutsThisWeek: Int {
        completedSessions.count
    }

    var totalDurationThisWeek: Int {
        completedSessions.reduce(0) { $0 + $1.durationMin }
    }

    var lastWorkout: WorkoutSessionRecord? {
        completedSessions.max { $0.occurredAt < $1.occurredAt }
    }

    var progress: Double {
        Self.progress(current: Double(completedWorkoutsThisWeek), target: Double(weeklyWorkoutTarget))
    }

    var isCurrentWeek: Bool {
        calendar.isDate(selectedDate, equalTo: now(), toGranularity: .weekOfYear)
    }

    var weekSubtitle: String {
        let interval = weekInterval
        let start = interval.start.formatted(.dateTime.day().month(.abbreviated))
        let endDate = calendar.date(byAdding: .day, value: -1, to: interval.end) ?? interval.end
        let end = endDate.formatted(.dateTime.day().month(.abbreviated))
        return "\(start) - \(end)"
    }

    var statusMessage: String {
        let remaining = max(weeklyWorkoutTarget - completedWorkoutsThisWeek, 0)

        if completedWorkoutsThisWeek == 0 {
            return "Noch kein Training diese Woche."
        }

        if remaining == 0 {
            return "Wochenziel erreicht."
        }

        return remaining == 1 ? "Noch eine Einheit offen." : "Noch \(remaining) Einheiten offen."
    }

    var dayStates: [TrainingWeekDayState] {
        let interval = weekInterval
        return (0..<7).compactMap { offset in
            guard let date = calendar.date(byAdding: .day, value: offset, to: interval.start) else {
                return nil
            }

            return TrainingWeekDayState(
                id: DateIntervals.dayKey(for: date, calendar: calendar),
                weekday: Self.weekdayFormatter.string(from: date),
                hasWorkout: completedSessions.contains { calendar.isDate($0.occurredAt, inSameDayAs: date) }
            )
        }
    }

    var scheduledHomeWorkout: ScheduledHomeWorkout {
        homeWorkoutPlan.workout(for: now(), calendar: calendar)
    }

    func homeWorkoutExercises(for intensity: HomeWorkoutIntensity) -> [HomeWorkoutExercise] {
        scheduledHomeWorkout.day.exercises(for: intensity)
    }

    func selectCurrentWeek() {
        selectedDate = now()
        reload()
    }

    func reload() {
        guard let database else {
            sessions = []
            weeklyWorkoutTarget = SeedData.defaultSettings.weeklyWorkoutTarget
            errorMessage = nil
            return
        }

        do {
            let settings = try SettingsRepository(database: database).fetchDefault() ?? SeedData.defaultSettings
            let repository = WorkoutRepository(database: database)
            weekStartsOn = settings.weekStartsOn
            weeklyWorkoutTarget = settings.weeklyWorkoutTarget
            sessions = try repository.fetchSessions(forWeekContaining: selectedDate, weekStartsOn: settings.weekStartsOn, calendar: calendar)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func completeHomeWorkout(intensity: HomeWorkoutIntensity, completedExerciseIDs: Set<HomeWorkoutExercise.ID>) {
        isSavingPlanWorkout = true
        completionMessage = nil

        let scheduledWorkout = scheduledHomeWorkout
        let session = homeWorkoutPlan.makeWorkoutSession(
            for: scheduledWorkout,
            intensity: intensity,
            completedExerciseCount: completedExerciseIDs.count,
            occurredAt: now()
        )

        guard let database else {
            sessions.insert(session, at: 0)
            completionMessage = "Workout gespeichert"
            isSavingPlanWorkout = false
            return
        }

        do {
            try WorkoutRepository(database: database).insert(session)
            completionMessage = "Workout gespeichert"
            errorMessage = nil
            reload()
        } catch {
            errorMessage = error.localizedDescription
        }

        isSavingPlanWorkout = false
    }

    func clearCompletionMessage() {
        completionMessage = nil
    }

    func deleteSession(id: WorkoutSessionRecord.ID) {
        guard let database else { return }

        do {
            try WorkoutRepository(database: database).delete(id: id)
            reload()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    static func progress(current: Double, target: Double) -> Double {
        guard target > 0 else { return 0 }
        return min(max(current / target, 0), 1)
    }

    private var completedSessions: [WorkoutSessionRecord] {
        sessions.filter { $0.status == "done" }
    }

    private var weekInterval: DateInterval {
        DateIntervals.week(containing: selectedDate, weekStartsOn: weekStartsOn, calendar: calendar)
    }

    private static let weekdayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "de_DE")
        formatter.dateFormat = "E"
        return formatter
    }()
}

struct TrainingWeekDayState: Identifiable, Equatable {
    let id: String
    let weekday: String
    let hasWorkout: Bool
}
