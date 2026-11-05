import Foundation

enum TrainingPlanSeeder {
    static let weeklyPlan = HomeWorkoutPlan(days: [
        HomeWorkoutDay(
            id: "pull-core",
            weekday: 2,
            weekdayName: "Montag",
            name: "Pull + Core",
            focusAreas: ["Ruecken", "Bizeps", "Griffkraft", "Core"],
            variants: [
                .minimum: [
                    HomeWorkoutExercise(name: "Negative Klimmzuege", prescription: "2 x 3", suggestedSets: 2, suggestedReps: 3),
                    HomeWorkoutExercise(name: "Rucksack-Rudern", prescription: "2 x 8", suggestedSets: 2, suggestedReps: 8),
                    HomeWorkoutExercise(name: "Plank", prescription: "2 x 30 Sekunden", suggestedSets: 2, suggestedDurationSec: 30)
                ],
                .normal: [
                    HomeWorkoutExercise(name: "Klimmzuege oder Negative Klimmzuege", prescription: "3 x 3-5", suggestedSets: 3, suggestedReps: 3),
                    HomeWorkoutExercise(name: "Rucksack-Rudern", prescription: "3 x 10", suggestedSets: 3, suggestedReps: 10),
                    HomeWorkoutExercise(name: "Plank", prescription: "3 x 40 Sekunden", suggestedSets: 3, suggestedDurationSec: 40),
                    HomeWorkoutExercise(name: "Beinheben oder Crunches", prescription: "3 x 10", suggestedSets: 3, suggestedReps: 10)
                ],
                .strong: [
                    HomeWorkoutExercise(name: "Klimmzuege oder Chin-ups", prescription: "4 x 3-6", suggestedSets: 4, suggestedReps: 4),
                    HomeWorkoutExercise(name: "Rucksack-Rudern", prescription: "4 x 12", suggestedSets: 4, suggestedReps: 12),
                    HomeWorkoutExercise(name: "Plank", prescription: "4 x 45 Sekunden", suggestedSets: 4, suggestedDurationSec: 45),
                    HomeWorkoutExercise(name: "Beinheben oder Crunches", prescription: "4 x 12", suggestedSets: 4, suggestedReps: 12)
                ]
            ]
        ),
        HomeWorkoutDay(
            id: "push-legs",
            weekday: 4,
            weekdayName: "Mittwoch",
            name: "Push + Legs",
            focusAreas: ["Brust", "Schultern", "Trizeps", "Beine"],
            variants: [
                .minimum: [
                    HomeWorkoutExercise(name: "Liegestuetze", prescription: "2 x 6-8", suggestedSets: 2, suggestedReps: 6),
                    HomeWorkoutExercise(name: "Kniebeugen", prescription: "2 x 12", suggestedSets: 2, suggestedReps: 12),
                    HomeWorkoutExercise(name: "Ausfallschritte", prescription: "2 x 8 pro Seite", suggestedSets: 2, suggestedReps: 8)
                ],
                .normal: [
                    HomeWorkoutExercise(name: "Liegestuetze", prescription: "3 x 8-12", suggestedSets: 3, suggestedReps: 8),
                    HomeWorkoutExercise(name: "Pike Push-ups oder Schulteruebung", prescription: "3 x 6-8", suggestedSets: 3, suggestedReps: 6),
                    HomeWorkoutExercise(name: "Kniebeugen", prescription: "3 x 15", suggestedSets: 3, suggestedReps: 15),
                    HomeWorkoutExercise(name: "Ausfallschritte", prescription: "3 x 10 pro Seite", suggestedSets: 3, suggestedReps: 10)
                ],
                .strong: [
                    HomeWorkoutExercise(name: "Liegestuetze", prescription: "4 x 10-15", suggestedSets: 4, suggestedReps: 10),
                    HomeWorkoutExercise(name: "Pike Push-ups oder Schulteruebung", prescription: "4 x 8", suggestedSets: 4, suggestedReps: 8),
                    HomeWorkoutExercise(name: "Kniebeugen", prescription: "4 x 18", suggestedSets: 4, suggestedReps: 18),
                    HomeWorkoutExercise(name: "Ausfallschritte", prescription: "4 x 12 pro Seite", suggestedSets: 4, suggestedReps: 12)
                ]
            ]
        ),
        HomeWorkoutDay(
            id: "full-body",
            weekday: 6,
            weekdayName: "Freitag",
            name: "Full Body",
            focusAreas: ["Ganzkoerper", "Grundroutine", "Core"],
            variants: [
                .minimum: [
                    HomeWorkoutExercise(name: "Klimmzugvariante", prescription: "2 x 3", suggestedSets: 2, suggestedReps: 3),
                    HomeWorkoutExercise(name: "Liegestuetze", prescription: "2 x 6-8", suggestedSets: 2, suggestedReps: 6),
                    HomeWorkoutExercise(name: "Kniebeugen", prescription: "2 x 12", suggestedSets: 2, suggestedReps: 12)
                ],
                .normal: [
                    HomeWorkoutExercise(name: "Klimmzugvariante", prescription: "3 x 3-5", suggestedSets: 3, suggestedReps: 3),
                    HomeWorkoutExercise(name: "Liegestuetze", prescription: "3 x 8-12", suggestedSets: 3, suggestedReps: 8),
                    HomeWorkoutExercise(name: "Kniebeugen", prescription: "3 x 15", suggestedSets: 3, suggestedReps: 15),
                    HomeWorkoutExercise(name: "Core-Uebung", prescription: "3 x 40 Sekunden", suggestedSets: 3, suggestedDurationSec: 40)
                ],
                .strong: [
                    HomeWorkoutExercise(name: "Klimmzugvariante", prescription: "4 x 3-6", suggestedSets: 4, suggestedReps: 4),
                    HomeWorkoutExercise(name: "Liegestuetze", prescription: "4 x 10-15", suggestedSets: 4, suggestedReps: 10),
                    HomeWorkoutExercise(name: "Kniebeugen", prescription: "4 x 18", suggestedSets: 4, suggestedReps: 18),
                    HomeWorkoutExercise(name: "Core-Uebung", prescription: "4 x 45 Sekunden", suggestedSets: 4, suggestedDurationSec: 45)
                ]
            ]
        )
    ])

    static let defaultProgressions: [ExerciseProgression] = [
        ExerciseProgression(exerciseName: "Liegestuetze", level: 1, targetSets: 4, targetMinReps: 8, targetMaxReps: 12, personalRecord: 0),
        ExerciseProgression(exerciseName: "Klimmzuege", level: 1, targetSets: 4, targetMinReps: 3, targetMaxReps: 5, personalRecord: 0),
        ExerciseProgression(exerciseName: "Pike Push-ups", level: 1, targetSets: 4, targetMinReps: 6, targetMaxReps: 10, personalRecord: 0)
    ]

}
