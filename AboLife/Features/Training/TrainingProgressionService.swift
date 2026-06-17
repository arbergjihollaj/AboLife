import Foundation

struct TrainingProgressionService {
    func recommendation(for progression: ExerciseProgression, results: [ExerciseSetResult]) -> WorkoutRecommendation {
        let matchingResults = results
            .filter { $0.exerciseName == progression.exerciseName }
            .sorted { $0.setIndex < $1.setIndex }

        if matchingResults.contains(where: \.painReported) {
            return WorkoutRecommendation(
                exerciseName: progression.exerciseName,
                outcome: .recover,
                message: "Schmerz angegeben: naechste Einheit regenerativ planen und Technik pruefen.",
                nextLevel: progression.level,
                nextTargetSets: max(progression.targetSets - 1, 2),
                nextTargetMinReps: max(progression.targetMinReps - 2, 1),
                nextTargetMaxReps: max(progression.targetMaxReps - 2, 3)
            )
        }

        let completedTargetSets = matchingResults.prefix(progression.targetSets)
        let totalReps = completedTargetSets.reduce(0) { $0 + $1.reps }
        let targetVolume = progression.targetSets * progression.targetMaxReps
        let minimumVolume = progression.targetSets * progression.targetMinReps
        let bestSet = matchingResults.map(\.reps).max() ?? progression.personalRecord

        if completedTargetSets.count >= progression.targetSets && totalReps >= targetVolume {
            let next = nextProgression(after: progression)
            return WorkoutRecommendation(
                exerciseName: progression.exerciseName,
                outcome: .increase,
                message: "Ziel erreicht: Level \(next.level) ist freigeschaltet.",
                nextLevel: next.level,
                nextTargetSets: next.targetSets,
                nextTargetMinReps: next.targetMinReps,
                nextTargetMaxReps: next.targetMaxReps
            )
        }

        if completedTargetSets.count >= max(progression.targetSets - 1, 1) && totalReps >= Int(Double(minimumVolume) * 0.82) {
            return WorkoutRecommendation(
                exerciseName: progression.exerciseName,
                outcome: .repeatTarget,
                message: "Knapp verfehlt: gleiches Ziel wiederholen und saubere Wiederholungen sammeln.",
                nextLevel: progression.level,
                nextTargetSets: progression.targetSets,
                nextTargetMinReps: progression.targetMinReps,
                nextTargetMaxReps: progression.targetMaxReps
            )
        }

        return WorkoutRecommendation(
            exerciseName: progression.exerciseName,
            outcome: .reduceTarget,
            message: "Deutlich verfehlt: Ziel leicht reduzieren und Volumen stabilisieren.",
            nextLevel: progression.level,
            nextTargetSets: max(progression.targetSets - 1, 2),
            nextTargetMinReps: max(min(bestSet - 1, progression.targetMinReps), 1),
            nextTargetMaxReps: max(progression.targetMinReps, progression.targetMaxReps - 2)
        )
    }

    func nextProgression(after progression: ExerciseProgression) -> ExerciseProgression {
        let prescriptions = prescriptionLadder(for: progression.exerciseName)
        guard let next = prescriptions.first(where: { $0.level == progression.level + 1 }) else {
            return ExerciseProgression(
                exerciseName: progression.exerciseName,
                level: progression.level,
                targetSets: progression.targetSets,
                targetMinReps: progression.targetMinReps + 1,
                targetMaxReps: progression.targetMaxReps + 1,
                personalRecord: progression.personalRecord
            )
        }

        return ExerciseProgression(
            exerciseName: progression.exerciseName,
            level: next.level,
            targetSets: next.targetSets,
            targetMinReps: next.minReps,
            targetMaxReps: next.maxReps,
            personalRecord: progression.personalRecord
        )
    }

    func prescriptionLadder(for exerciseName: String) -> [ExerciseLevelPrescription] {
        switch exerciseName.lowercased() {
        case let name where name.contains("klimm"):
            return [
                ExerciseLevelPrescription(id: "pullup-1", level: 1, title: "Negative Klimmzuege", targetSets: 4, minReps: 3, maxReps: 5),
                ExerciseLevelPrescription(id: "pullup-2", level: 2, title: "Normale Klimmzuege", targetSets: 4, minReps: 3, maxReps: 5),
                ExerciseLevelPrescription(id: "pullup-3", level: 3, title: "Normale Klimmzuege", targetSets: 4, minReps: 5, maxReps: 8),
                ExerciseLevelPrescription(id: "pullup-4", level: 4, title: "Normale Klimmzuege", targetSets: 4, minReps: 8, maxReps: 12)
            ]
        default:
            return [
                ExerciseLevelPrescription(id: "pushup-1", level: 1, title: "Liegestuetze", targetSets: 4, minReps: 8, maxReps: 12),
                ExerciseLevelPrescription(id: "pushup-2", level: 2, title: "Liegestuetze", targetSets: 4, minReps: 12, maxReps: 15),
                ExerciseLevelPrescription(id: "pushup-3", level: 3, title: "Langsame Liegestuetze", targetSets: 4, minReps: 8, maxReps: 12),
                ExerciseLevelPrescription(id: "pushup-4", level: 4, title: "Fuesse erhoeht", targetSets: 4, minReps: 8, maxReps: 12),
                ExerciseLevelPrescription(id: "pushup-5", level: 5, title: "Diamond Push-ups", targetSets: 4, minReps: 6, maxReps: 10)
            ]
        }
    }
}
