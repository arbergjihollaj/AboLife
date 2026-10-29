import Foundation

final class TrainingViewModel: ObservableObject {
    @Published var selectedDate: Date {
        didSet {
            guard !Self.isSameWeek(selectedDate, oldValue, weekStartsOn: weekStartsOn, calendar: calendar) else { return }
            reload()
        }
    }
    @Published private(set) var sessions: [WorkoutSessionRecord] = []
    @Published private(set) var weeklyWorkoutTarget: Int
    @Published private(set) var errorMessage: String?
    @Published private(set) var completionMessage: String?
    @Published private(set) var isSavingPlanWorkout = false
    @Published private(set) var exerciseProgressions: [ExerciseProgression]
    @Published private(set) var recommendations: [WorkoutRecommendation]
    @Published private(set) var bodyTrend: BodyProgressTrend
    @Published private(set) var trainingStatistics: TrainingStatistics
    @Published private(set) var motivationCards: [MotivationCard]
    @Published private(set) var exerciseProgressStatuses: [ExerciseProgressStatus]

    private let database: AppDatabase?
    private let calendar: Calendar
    private var weekStartsOn: Int
    private let homeWorkoutPlan: HomeWorkoutPlan
    private let now: () -> Date
    private let progressionService: TrainingProgressionService
    private let bodyProgressService: BodyProgressService

    init(
        database: AppDatabase?,
        selectedDate: Date = Date(),
        calendar: Calendar = .current,
        weeklyWorkoutTarget: Int = SeedData.defaultSettings.weeklyWorkoutTarget,
        homeWorkoutPlan: HomeWorkoutPlan = TrainingPlanSeeder.weeklyPlan,
        now: @escaping () -> Date = Date.init
    ) {
        self.database = database
        self.selectedDate = selectedDate
        self.calendar = calendar
        self.weekStartsOn = SeedData.defaultSettings.weekStartsOn
        self.weeklyWorkoutTarget = weeklyWorkoutTarget
        self.homeWorkoutPlan = homeWorkoutPlan
        self.now = now
        self.progressionService = TrainingProgressionService()
        self.bodyProgressService = BodyProgressService()
        self.exerciseProgressions = TrainingPlanSeeder.defaultProgressions
        self.recommendations = []
        self.bodyTrend = bodyProgressService.trend(from: TrainingPlanSeeder.sampleMeasurements)
        self.trainingStatistics = TrainingStatistics(
            trainingsThisWeek: 0,
            currentStreak: 0,
            totalVolume: 0,
            pushVolume: 0,
            pullVolume: 0,
            legVolume: 0,
            strongestWeek: 0,
            trainingRate: 0,
            averageSetsPerTraining: 0,
            minimumWorkouts: 0,
            normalWorkouts: 0,
            strongWorkouts: 0,
            pausedWorkouts: 0,
            mostFrequentExercise: nil
        )
        self.motivationCards = []
        self.exerciseProgressStatuses = []
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
        Self.isSameWeek(selectedDate, now(), weekStartsOn: weekStartsOn, calendar: calendar)
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
            refreshIntelligence()
            return
        }

        do {
            let settings = try SettingsRepository(database: database).fetchDefault() ?? SeedData.defaultSettings
            let repository = WorkoutRepository(database: database)
            weekStartsOn = settings.weekStartsOn
            weeklyWorkoutTarget = settings.weeklyWorkoutTarget
            sessions = try repository.fetchSessions(forWeekContaining: selectedDate, weekStartsOn: settings.weekStartsOn, calendar: calendar)
            refreshIntelligence()
            errorMessage = nil
        } catch {
            errorMessage = "Trainingsdaten konnten nicht geladen werden."
            refreshIntelligence()
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
            errorMessage = "Workout konnte nicht gespeichert werden."
        }

        isSavingPlanWorkout = false
    }

    func makeDetailedHomeWorkoutExercises(intensity: HomeWorkoutIntensity) -> [WorkoutExerciseInput] {
        homeWorkoutPlan.makeExerciseInputs(for: scheduledHomeWorkout, intensity: intensity)
    }

    func completeDetailedHomeWorkout(
        intensity: HomeWorkoutIntensity,
        exercises: [WorkoutExerciseInput],
        note: String?,
        painReported: Bool
    ) {
        isSavingPlanWorkout = true
        completionMessage = nil

        let detailed = homeWorkoutPlan.makeDetailedWorkoutSession(
            for: scheduledHomeWorkout,
            intensity: intensity,
            exercises: exercises,
            note: note,
            painReported: painReported,
            occurredAt: now()
        )

        guard let database else {
            sessions.insert(detailed.session, at: 0)
            completionMessage = "Workout mit Details gespeichert"
            isSavingPlanWorkout = false
            return
        }

        do {
            try WorkoutRepository(database: database).insertDetailed(detailed.session, exercises: detailed.exercises)
            completionMessage = "Workout mit Details gespeichert"
            errorMessage = nil
            reload()
        } catch {
            errorMessage = "Workout konnte nicht gespeichert werden."
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
            errorMessage = "Workout konnte nicht gelöscht werden."
        }
    }

    static func progress(current: Double, target: Double) -> Double {
        guard target > 0 else { return 0 }
        return min(max(current / target, 0), 1)
    }

    private var completedSessions: [WorkoutSessionRecord] {
        sessions.filter { $0.status == "done" }
    }

    private func refreshIntelligence() {


        let history = database.flatMap { try? WorkoutRepository(database: $0).fetchAllExerciseSummaries() } ?? []
        exerciseProgressStatuses = makeExerciseProgressStatuses(from: history)

        recommendations = exerciseProgressions.map { progression in
            let results = exerciseResults(for: progression, history: history)
            return progressionService.recommendation(
                for: progression,
                results: results.isEmpty ? sampleResults(for: progression) : results
            )
        }

        bodyTrend = bodyProgressService.trend(from: TrainingPlanSeeder.sampleMeasurements)
        trainingStatistics = makeTrainingStatistics()
        motivationCards = makeMotivationCards()
    }

    private func sampleResults(for progression: ExerciseProgression) -> [ExerciseSetResult] {
        switch progression.exerciseName.lowercased() {
        case let name where name.contains("klimm"):
            return [4, 4, 3, 3].enumerated().map {
                ExerciseSetResult(exerciseName: progression.exerciseName, reps: $0.element, setIndex: $0.offset)
            }
        case let name where name.contains("pike"):
            return [10, 9, 8, 7].enumerated().map {
                ExerciseSetResult(exerciseName: progression.exerciseName, reps: $0.element, setIndex: $0.offset)
            }
        default:
            return [12, 12, 12, 12].enumerated().map {
                ExerciseSetResult(exerciseName: progression.exerciseName, reps: $0.element, setIndex: $0.offset)
            }
        }
    }

    private func makeTrainingStatistics() -> TrainingStatistics {
        let completed = completedSessions
        let pushVolume = volume(for: completed, matching: ["push", "liegest", "pike", "diamond", "brust"])
        let pullVolume = volume(for: completed, matching: ["pull", "klimm", "negative", "ruecken"])
        let legVolume = volume(for: completed, matching: ["leg", "squat", "kniebeuge", "ausfallschritt", "split"])
        let totalVolume = max(pushVolume + pullVolume + legVolume, completed.reduce(0) { $0 + $1.durationMin })

        return TrainingStatistics(
            trainingsThisWeek: completed.count,
            currentStreak: currentStreak(from: completed),
            totalVolume: totalVolume,
            pushVolume: pushVolume,
            pullVolume: pullVolume,
            legVolume: legVolume,
            strongestWeek: max(completed.count, weeklyWorkoutTarget),
            trainingRate: Self.progress(current: Double(completed.count), target: Double(weeklyWorkoutTarget)),
            averageSetsPerTraining: averageSetsPerTraining(for: completed),
            minimumWorkouts: completed.filter { $0.workoutIntensity == HomeWorkoutIntensity.minimum.rawValue }.count,
            normalWorkouts: completed.filter { $0.workoutIntensity == HomeWorkoutIntensity.normal.rawValue }.count,
            strongWorkouts: completed.filter { $0.workoutIntensity == HomeWorkoutIntensity.strong.rawValue }.count,
            pausedWorkouts: sessions.filter { $0.status == "paused" }.count,
            mostFrequentExercise: exerciseProgressStatuses.first?.exerciseName
        )
    }

    private func averageSetsPerTraining(for completed: [WorkoutSessionRecord]) -> Double {
        guard let database, !completed.isEmpty else { return 0 }
        let history = (try? WorkoutRepository(database: database).fetchAllExerciseSummaries(in: weekInterval)) ?? []
        guard !history.isEmpty else { return 0 }
        return Double(history.reduce(0) { $0 + $1.sets.count }) / Double(completed.count)
    }

    private func exerciseResults(for progression: ExerciseProgression, history: [WorkoutExerciseHistoryEntry]) -> [ExerciseSetResult] {
        let target = WorkoutRepository.normalizedExerciseName(progression.exerciseName)
        return history
            .filter { WorkoutRepository.normalizedExerciseName($0.exercise.exerciseName).contains(target) || target.contains(WorkoutRepository.normalizedExerciseName($0.exercise.exerciseName)) }
            .flatMap { entry in
                entry.sets.enumerated().compactMap { index, set in
                    set.reps.map {
                        ExerciseSetResult(
                            exerciseName: progression.exerciseName,
                            reps: $0,
                            setIndex: index,
                            painReported: set.painReported || entry.exercise.painReported
                        )
                    }
                }
            }
    }

    private func makeExerciseProgressStatuses(from history: [WorkoutExerciseHistoryEntry]) -> [ExerciseProgressStatus] {
        let grouped = Dictionary(grouping: history) {
            WorkoutRepository.normalizedExerciseName($0.exercise.exerciseName)
        }

        return grouped.values.compactMap { entries -> ExerciseProgressStatus? in
            let ordered = entries.sorted { $0.occurredAt > $1.occurredAt }
            guard let latest = ordered.first else { return nil }
            let totals = Array(ordered.prefix(4).map(\.totalReps))
            let lastSets = latest.sets.compactMap(\.reps)
            let best = entries.map(\.bestSetReps).max()
            let recommendation: String
            if latest.exercise.painReported || latest.sets.contains(where: \.painReported) {
                recommendation = "Wenn sich etwas nicht gut anfühlt, ist die Minimum-Variante heute sinnvoll."
            } else if totals.count < 2 {
                recommendation = "Noch nicht genug Daten für einen Trend. Ruhig weiter sammeln."
            } else if totals[0] > totals[1] {
                recommendation = "Letztes Mal leicht verbessert. Heute stabil bleiben reicht völlig."
            } else if let firstSet = latest.sets.compactMap(\.reps).first {
                recommendation = "Heute könntest du versuchen, im ersten Satz \(firstSet + 1) Wiederholungen zu schaffen."
            } else {
                recommendation = "Stabil bleiben: gleiche Wiederholungen wie letztes Mal sind völlig okay."
            }

            return ExerciseProgressStatus(
                id: latest.exercise.exerciseName,
                exerciseName: latest.exercise.exerciseName,
                lastSetsText: lastSets.isEmpty ? nil : lastSets.map(String.init).joined(separator: " / "),
                bestSetReps: best == 0 ? nil : best,
                recentTotalReps: totals,
                recommendation: recommendation
            )
        }
        .sorted { lhs, rhs in
            if lhs.hasEnoughData != rhs.hasEnoughData {
                return lhs.hasEnoughData && !rhs.hasEnoughData
            }
            return lhs.exerciseName < rhs.exerciseName
        }
    }

    private func volume(for sessions: [WorkoutSessionRecord], matching keywords: [String]) -> Int {
        sessions.reduce(0) { total, session in
            let haystack = "\(session.workoutType) \(session.note ?? "")".lowercased()
            return keywords.contains { haystack.contains($0) } ? total + max(session.durationMin, 1) : total
        }
    }

    private func currentStreak(from sessions: [WorkoutSessionRecord]) -> Int {
        let dayKeys = Set(sessions.map { DateIntervals.dayKey(for: $0.occurredAt, calendar: calendar) })
        var streak = 0
        var date = calendar.startOfDay(for: now())

        while dayKeys.contains(DateIntervals.dayKey(for: date, calendar: calendar)) {
            streak += 1
            guard let previous = calendar.date(byAdding: .day, value: -1, to: date) else { break }
            date = previous
        }

        return streak
    }

    private func makeMotivationCards() -> [MotivationCard] {
        let pullupRecord = exerciseProgressions.first { $0.exerciseName.lowercased().contains("klimm") }?.personalRecord ?? 5
        let pushupRecord = exerciseProgressions.first { $0.exerciseName.lowercased().contains("liegest") }?.personalRecord ?? 24

        return [
            MotivationCard(id: "pushup-pr", title: "Neuer Rekord", detail: "\(pushupRecord) Liegestuetze", systemImage: "trophy.fill"),
            MotivationCard(id: "pullup-goal", title: "Erstes Ziel erreicht", detail: "\(pullupRecord) Klimmzuege", systemImage: "flag.checkered"),
            MotivationCard(id: "weekly-streak", title: "Wochenziel", detail: statusMessage, systemImage: "flame.fill")
        ]
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

    private static func isSameWeek(_ lhs: Date, _ rhs: Date, weekStartsOn: Int, calendar: Calendar) -> Bool {
        DateIntervals.week(containing: lhs, weekStartsOn: weekStartsOn, calendar: calendar).start ==
            DateIntervals.week(containing: rhs, weekStartsOn: weekStartsOn, calendar: calendar).start
    }
}

typealias TrainingStore = TrainingViewModel

struct TrainingWeekDayState: Identifiable, Equatable {
    let id: String
    let weekday: String
    let hasWorkout: Bool
}
