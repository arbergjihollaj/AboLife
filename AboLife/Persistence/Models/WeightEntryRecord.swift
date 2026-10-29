import Foundation
import GRDB

struct WeightEntryRecord: Codable, FetchableRecord, PersistableRecord, Identifiable, Equatable {
    static let databaseTableName = "weight_entries"

    var id: String
    var date: String
    var weightKg: Double
    var createdAt: Date
    var updatedAt: Date

    init(
        id: String = UUID().uuidString,
        date: String = DateIntervals.dayKey(),
        weightKg: Double,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.date = date
        self.weightKg = weightKg
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    enum CodingKeys: String, CodingKey {
        case id
        case date
        case weightKg = "weight_kg"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

struct WeightTrendSummary: Equatable {
    let entries: [WeightEntryRecord]

    var latest: WeightEntryRecord? {
        entries.max { $0.date < $1.date }
    }

    var previous: WeightEntryRecord? {
        entries.sorted { $0.date > $1.date }.dropFirst().first
    }

    var changeFromPreviousKg: Double? {
        guard let latest, let previous else { return nil }
        return latest.weightKg - previous.weightKg
    }

    var firstToLastChangeKg: Double? {
        let sorted = entries.sorted { $0.date < $1.date }
        guard let first = sorted.first, let last = sorted.last, first.id != last.id else { return nil }
        return last.weightKg - first.weightKg
    }
}
