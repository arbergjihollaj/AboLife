import Foundation

enum TrainingPlanSeeder {
    static let weeklyPlan = HomeWorkoutPlan(days: [
        HomeWorkoutDay(
            id: "monday-push",
            weekday: 2,
            weekdayName: "Montag",
            name: "Push",
            focusAreas: ["Brust", "Schultern", "Trizeps", "Core"],
            variants: Self.variants([
                ("Liegestuetze", "4 x 8-12"),
                ("Pike Push-ups", "4 x 6-10"),
                ("Enge Liegestuetze", "3 x 8-12"),
                ("Diamond Push-ups", "3 x 6-10"),
                ("Plank", "3 x 45 Sekunden")
            ])
        ),
        HomeWorkoutDay(
            id: "tuesday-pull",
            weekday: 3,
            weekdayName: "Dienstag",
            name: "Pull",
            focusAreas: ["Ruecken", "Bizeps", "Griffkraft", "Core"],
            variants: Self.variants([
                ("Klimmzuege", "4 Saetze"),
                ("Negative Klimmzuege", "4 x 3-5"),
                ("Scapular Pull-ups", "3 x 8"),
                ("Superman Hold", "3 x 30 Sekunden"),
                ("Hollow Hold", "3 x 30 Sekunden")
            ])
        ),
        HomeWorkoutDay(
            id: "wednesday-legs-core",
            weekday: 4,
            weekdayName: "Mittwoch",
            name: "Legs + Core",
            focusAreas: ["Beine", "Gesaess", "Core"],
            variants: Self.variants([
                ("Kniebeugen", "4 x 15-20"),
                ("Bulgarische Split Squats", "4 x 8-12 pro Seite"),
                ("Ausfallschritte", "3 x 10 pro Seite"),
                ("Glute Bridge", "4 x 12-18"),
                ("Beinheben", "3 x 8-12"),
                ("Plank", "3 x 45 Sekunden")
            ])
        ),
        HomeWorkoutDay(
            id: "thursday-cardio-mobility",
            weekday: 5,
            weekdayName: "Donnerstag",
            name: "Cardio + Mobility",
            focusAreas: ["Ausdauer", "Mobility", "Regeneration"],
            variants: Self.variants([
                ("Laufband", "30-40 Minuten"),
                ("Dehnen", "12 Minuten"),
                ("Mobility", "10 Minuten")
            ])
        ),
        HomeWorkoutDay(
            id: "friday-push-pull",
            weekday: 6,
            weekdayName: "Freitag",
            name: "Push + Pull Mix",
            focusAreas: ["Brust", "Ruecken", "Schultern", "Core"],
            variants: Self.variants([
                ("Liegestuetze", "4 x 10-15"),
                ("Klimmzuege", "4 Saetze"),
                ("Pike Push-ups", "3 x 6-10"),
                ("Negative Klimmzuege", "3 x 3-5"),
                ("Side Plank", "3 x 30 Sekunden pro Seite")
            ])
        ),
        HomeWorkoutDay(
            id: "saturday-conditioning",
            weekday: 7,
            weekdayName: "Samstag",
            name: "Conditioning",
            focusAreas: ["Kondition", "Beine", "Core"],
            variants: Self.variants([
                ("Laufband", "20-30 Minuten"),
                ("Kniebeugen", "4 x 20"),
                ("Ausfallschritte", "3 x 12 pro Seite"),
                ("Core Circuit", "4 Runden")
            ])
        ),
        HomeWorkoutDay(
            id: "sunday-recovery",
            weekday: 1,
            weekdayName: "Sonntag",
            name: "Recovery",
            focusAreas: ["Spaziergang", "Mobility", "Stretching"],
            variants: Self.variants([
                ("Spaziergang", "30-60 Minuten"),
                ("Mobility", "12 Minuten"),
                ("Stretching", "12 Minuten")
            ])
        )
    ])

    static let defaultProgressions: [ExerciseProgression] = [
        ExerciseProgression(exerciseName: "Liegestuetze", level: 1, targetSets: 4, targetMinReps: 8, targetMaxReps: 12, personalRecord: 24),
        ExerciseProgression(exerciseName: "Klimmzuege", level: 1, targetSets: 4, targetMinReps: 3, targetMaxReps: 5, personalRecord: 5),
        ExerciseProgression(exerciseName: "Pike Push-ups", level: 1, targetSets: 4, targetMinReps: 6, targetMaxReps: 10, personalRecord: 12)
    ]

    static let sampleMeasurements: [BodyMeasurement] = [
        BodyMeasurement(weightKg: 86.5, waistCm: 88, chestCm: 101, armCm: 35, maxPushups: 24, maxPullups: 5),
        BodyMeasurement(measuredAt: Date().addingTimeInterval(60 * 60 * 24 * 14), weightKg: 87.2, waistCm: 87, chestCm: 102.5, armCm: 35.8, maxPushups: 29, maxPullups: 7)
    ]

    private static func variants(_ normal: [(String, String)]) -> [HomeWorkoutIntensity: [HomeWorkoutExercise]] {
        [
            .minimum: normal.prefix(max(3, min(normal.count, 4))).map { HomeWorkoutExercise(name: $0.0, prescription: $0.1) },
            .normal: normal.map { HomeWorkoutExercise(name: $0.0, prescription: $0.1) },
            .strong: normal.map { HomeWorkoutExercise(name: $0.0, prescription: stronger($0.1)) }
        ]
    }

    private static func stronger(_ prescription: String) -> String {
        if prescription.contains("Minuten") || prescription.contains("Sekunden") {
            return prescription
        }

        return "\(prescription) + 1 Satz"
    }
}
