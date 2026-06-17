import Foundation

struct BodyProgressTrend: Equatable {
    let latestWeightKg: Double?
    let weightChangeKg: Double?
    let waistChangeCm: Double?
    let chestChangeCm: Double?
    let armChangeCm: Double?
    let pushupChange: Int?
    let pullupChange: Int?

    var summary: String {
        guard let latestWeightKg else {
            return "Noch keine Koerpermessung gespeichert."
        }

        let weightText = weightChangeKg.map { String(format: "%+.1f kg", $0) } ?? "neu"
        return String(format: "%.1f kg · %@", latestWeightKg, weightText)
    }
}

struct BodyProgressService {
    func trend(from measurements: [BodyMeasurement]) -> BodyProgressTrend {
        let sorted = measurements.sorted { $0.measuredAt < $1.measuredAt }
        guard let latest = sorted.last else {
            return BodyProgressTrend(
                latestWeightKg: nil,
                weightChangeKg: nil,
                waistChangeCm: nil,
                chestChangeCm: nil,
                armChangeCm: nil,
                pushupChange: nil,
                pullupChange: nil
            )
        }

        guard let first = sorted.first, first !== latest else {
            return BodyProgressTrend(
                latestWeightKg: latest.weightKg,
                weightChangeKg: nil,
                waistChangeCm: nil,
                chestChangeCm: nil,
                armChangeCm: nil,
                pushupChange: nil,
                pullupChange: nil
            )
        }

        return BodyProgressTrend(
            latestWeightKg: latest.weightKg,
            weightChangeKg: latest.weightKg - first.weightKg,
            waistChangeCm: latest.waistCm - first.waistCm,
            chestChangeCm: latest.chestCm - first.chestCm,
            armChangeCm: latest.armCm - first.armCm,
            pushupChange: latest.maxPushups - first.maxPushups,
            pullupChange: latest.maxPullups - first.maxPullups
        )
    }
}
