import Foundation

enum HomeWorkoutIntensity: String, CaseIterable, Identifiable {
    case minimum = "Minimum"
    case normal = "Normal"
    case strong = "Stark"

    var id: String { rawValue }

    var durationMinutes: Int {
        switch self {
        case .minimum:
            return 15
        case .normal:
            return 30
        case .strong:
            return 45
        }
    }

    var timeRange: String {
        switch self {
        case .minimum:
            return "10-15 Minuten"
        case .normal:
            return "25-35 Minuten"
        case .strong:
            return "40-50 Minuten"
        }
    }
}

struct HomeWorkoutExercise: Identifiable, Equatable {
    let id: String
    let name: String
    let prescription: String

    init(name: String, prescription: String) {
        self.id = "\(name)-\(prescription)"
        self.name = name
        self.prescription = prescription
    }
}

struct HomeWorkoutDay: Identifiable, Equatable {
    let id: String
    let weekday: Int
    let weekdayName: String
    let name: String
    let focusAreas: [String]
    let variants: [HomeWorkoutIntensity: [HomeWorkoutExercise]]

    var focusText: String {
        focusAreas.joined(separator: " · ")
    }

    func exercises(for intensity: HomeWorkoutIntensity) -> [HomeWorkoutExercise] {
        variants[intensity] ?? []
    }
}

struct ScheduledHomeWorkout: Equatable {
    let day: HomeWorkoutDay
    let scheduledDate: Date
    let isToday: Bool

    var headline: String {
        isToday ? "Heute geplant" : "Nächstes Workout"
    }
}

struct HomeWorkoutChecklistState: Equatable {
    var selectedIntensity: HomeWorkoutIntensity = .normal
    var completedExerciseIDs: Set<HomeWorkoutExercise.ID> = []

    var checkedExerciseCount: Int {
        completedExerciseIDs.count
    }

    mutating func setIntensity(_ intensity: HomeWorkoutIntensity) {
        selectedIntensity = intensity
        completedExerciseIDs = []
    }

    mutating func setExercise(_ id: HomeWorkoutExercise.ID, isCompleted: Bool) {
        if isCompleted {
            completedExerciseIDs.insert(id)
        } else {
            completedExerciseIDs.remove(id)
        }
    }

    mutating func resetCompletedExercises() {
        completedExerciseIDs = []
    }

    static func progress(checkedExercises: Int, totalExercises: Int) -> Double {
        guard totalExercises > 0 else { return 0 }
        return min(max(Double(checkedExercises) / Double(totalExercises), 0), 1)
    }
}

enum HomeWorkoutPlanProvider {
    static let plan = TrainingPlanSeeder.weeklyPlan

    static let legacyPlan = HomeWorkoutPlan(days: [
        HomeWorkoutDay(
            id: "pull-core",
            weekday: 2,
            weekdayName: "Montag",
            name: "Pull + Core",
            focusAreas: ["Rücken", "Bizeps", "Griffkraft", "Core"],
            variants: [
                .minimum: [
                    HomeWorkoutExercise(name: "Dead Hang", prescription: "3 x 20 Sekunden"),
                    HomeWorkoutExercise(name: "Negative Klimmzüge", prescription: "3 x 3 Wiederholungen"),
                    HomeWorkoutExercise(name: "Plank", prescription: "2 x 30 Sekunden")
                ],
                .normal: [
                    HomeWorkoutExercise(name: "Klimmzüge oder Negative Klimmzüge", prescription: "4 Sätze"),
                    HomeWorkoutExercise(name: "Scapula Pull-ups", prescription: "3 x 6 Wiederholungen"),
                    HomeWorkoutExercise(name: "Rucksack-Rudern", prescription: "3 x 10 Wiederholungen"),
                    HomeWorkoutExercise(name: "Plank", prescription: "3 x 40 Sekunden")
                ],
                .strong: [
                    HomeWorkoutExercise(name: "Klimmzüge oder Chin-ups", prescription: "5 Sätze"),
                    HomeWorkoutExercise(name: "Negative Klimmzüge", prescription: "3 x 4 Wiederholungen"),
                    HomeWorkoutExercise(name: "Scapula Pull-ups", prescription: "3 x 8 Wiederholungen"),
                    HomeWorkoutExercise(name: "Rucksack-Rudern", prescription: "4 x 12 Wiederholungen"),
                    HomeWorkoutExercise(name: "Side Plank", prescription: "3 x 30 Sekunden pro Seite")
                ]
            ]
        ),
        HomeWorkoutDay(
            id: "push-legs",
            weekday: 4,
            weekdayName: "Mittwoch",
            name: "Push + Legs",
            focusAreas: ["Brust", "Schulter", "Trizeps", "Beine"],
            variants: [
                .minimum: [
                    HomeWorkoutExercise(name: "Liegestütze", prescription: "3 Sätze"),
                    HomeWorkoutExercise(name: "Kniebeugen", prescription: "3 x 12 Wiederholungen"),
                    HomeWorkoutExercise(name: "Plank", prescription: "2 x 30 Sekunden")
                ],
                .normal: [
                    HomeWorkoutExercise(name: "Liegestütze", prescription: "4 Sätze"),
                    HomeWorkoutExercise(name: "Pike Push-ups", prescription: "3 x 6 Wiederholungen"),
                    HomeWorkoutExercise(name: "Bulgarian Split Squats", prescription: "3 x 8 pro Seite"),
                    HomeWorkoutExercise(name: "Glute Bridge", prescription: "3 x 12 Wiederholungen"),
                    HomeWorkoutExercise(name: "Plank", prescription: "3 x 40 Sekunden")
                ],
                .strong: [
                    HomeWorkoutExercise(name: "Liegestütze Variation", prescription: "5 Sätze"),
                    HomeWorkoutExercise(name: "Pike Push-ups", prescription: "4 x 8 Wiederholungen"),
                    HomeWorkoutExercise(name: "Bulgarian Split Squats", prescription: "4 x 10 pro Seite"),
                    HomeWorkoutExercise(name: "Wall Sit", prescription: "3 x 45 Sekunden"),
                    HomeWorkoutExercise(name: "Core Finisher", prescription: "3 Runden")
                ]
            ]
        ),
        HomeWorkoutDay(
            id: "full-body",
            weekday: 6,
            weekdayName: "Freitag",
            name: "Full Body",
            focusAreas: ["Ganzkörper", "Grundroutine", "Kondition"],
            variants: [
                .minimum: [
                    HomeWorkoutExercise(name: "Negative Klimmzüge", prescription: "3 x 3 Wiederholungen"),
                    HomeWorkoutExercise(name: "Liegestütze", prescription: "3 Sätze"),
                    HomeWorkoutExercise(name: "Kniebeugen", prescription: "3 x 12 Wiederholungen")
                ],
                .normal: [
                    HomeWorkoutExercise(name: "Klimmzüge oder Negative Klimmzüge", prescription: "4 Sätze"),
                    HomeWorkoutExercise(name: "Liegestütze", prescription: "4 Sätze"),
                    HomeWorkoutExercise(name: "Ausfallschritte", prescription: "3 x 10 pro Seite"),
                    HomeWorkoutExercise(name: "Mountain Climbers", prescription: "3 x 30 Sekunden"),
                    HomeWorkoutExercise(name: "Plank", prescription: "3 x 40 Sekunden")
                ],
                .strong: [
                    HomeWorkoutExercise(name: "Klimmzüge oder Chin-ups", prescription: "5 Sätze"),
                    HomeWorkoutExercise(name: "Liegestütze", prescription: "5 Sätze"),
                    HomeWorkoutExercise(name: "Bulgarian Split Squats", prescription: "4 x 10 pro Seite"),
                    HomeWorkoutExercise(name: "Burpees", prescription: "3 Runden"),
                    HomeWorkoutExercise(name: "Side Plank", prescription: "3 x 30 Sekunden pro Seite")
                ]
            ]
        )
    ])
}

struct HomeWorkoutPlan: Equatable {
    let days: [HomeWorkoutDay]

    var allExercises: [HomeWorkoutExercise] {
        days.flatMap { day in
            HomeWorkoutIntensity.allCases.flatMap { day.exercises(for: $0) }
        }
    }

    func workout(for date: Date, calendar: Calendar = .current) -> ScheduledHomeWorkout {
        let weekday = calendar.component(.weekday, from: date)

        if let today = days.first(where: { $0.weekday == weekday }) {
            return ScheduledHomeWorkout(day: today, scheduledDate: calendar.startOfDay(for: date), isToday: true)
        }

        return nextWorkout(after: date, calendar: calendar)
    }

    func nextWorkout(after date: Date, calendar: Calendar = .current) -> ScheduledHomeWorkout {
        let startOfDay = calendar.startOfDay(for: date)

        for offset in 1...7 {
            guard let candidate = calendar.date(byAdding: .day, value: offset, to: startOfDay) else {
                continue
            }

            let weekday = calendar.component(.weekday, from: candidate)
            if let day = days.first(where: { $0.weekday == weekday }) {
                return ScheduledHomeWorkout(day: day, scheduledDate: candidate, isToday: false)
            }
        }

        let fallback = days[0]
        return ScheduledHomeWorkout(day: fallback, scheduledDate: startOfDay, isToday: false)
    }

    func makeWorkoutSession(
        for scheduledWorkout: ScheduledHomeWorkout,
        intensity: HomeWorkoutIntensity,
        completedExerciseCount: Int,
        occurredAt: Date = Date()
    ) -> WorkoutSessionRecord {
        let exercises = scheduledWorkout.day.exercises(for: intensity)
        let exerciseNames = exercises.map(\.name).joined(separator: ", ")
        let note = "Intensität: \(intensity.rawValue). Erledigt: \(completedExerciseCount)/\(exercises.count). Übungen: \(exerciseNames)."

        return WorkoutSessionRecord(
            occurredAt: occurredAt,
            workoutType: "Home Plan: \(scheduledWorkout.day.name)",
            durationMin: intensity.durationMinutes,
            status: "done",
            note: note
        )
    }
}
