import Foundation
import GRDB

struct WeeklyReviewRepository {
    private let database: AppDatabase

    init(database: AppDatabase) {
        self.database = database
    }

    func fetch(weekStartDate: String) throws -> WeeklyReviewRecord? {
        try database.writer.read { db in
            try WeeklyReviewRecord
                .filter(Column("week_start_date") == weekStartDate)
                .fetchOne(db)
        }
    }

    func upsert(
        weekStartDate: String,
        winsText: String,
        challengesText: String,
        nextWeekFocusText: String,
        rating: Int? = nil
    ) throws -> WeeklyReviewRecord {
        let now = Date()

        return try database.writer.write { db in
            if var existing = try WeeklyReviewRecord
                .filter(Column("week_start_date") == weekStartDate)
                .fetchOne(db) {
                existing.winsText = winsText
                existing.challengesText = challengesText
                existing.nextWeekFocusText = nextWeekFocusText
                existing.rating = rating
                existing.updatedAt = now
                try existing.update(db)
                return existing
            }

            let review = WeeklyReviewRecord(
                weekStartDate: weekStartDate,
                winsText: winsText,
                challengesText: challengesText,
                nextWeekFocusText: nextWeekFocusText,
                rating: rating,
                createdAt: now,
                updatedAt: now
            )
            try review.insert(db)
            return review
        }
    }

    func deleteAll() throws {
        try database.writer.write { db in
            _ = try WeeklyReviewRecord.deleteAll(db)
        }
    }
}
