import Foundation
import GRDB

struct WeeklyReviewRecord: Codable, FetchableRecord, PersistableRecord, Identifiable, Equatable {
    static let databaseTableName = "weekly_reviews"

    var id: String
    var weekStartDate: String
    var winsText: String
    var challengesText: String
    var nextWeekFocusText: String
    var rating: Int?
    var createdAt: Date
    var updatedAt: Date

    init(
        id: String = UUID().uuidString,
        weekStartDate: String,
        winsText: String = "",
        challengesText: String = "",
        nextWeekFocusText: String = "",
        rating: Int? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.weekStartDate = weekStartDate
        self.winsText = winsText
        self.challengesText = challengesText
        self.nextWeekFocusText = nextWeekFocusText
        self.rating = rating
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    enum CodingKeys: String, CodingKey {
        case id
        case weekStartDate = "week_start_date"
        case winsText = "wins_text"
        case challengesText = "challenges_text"
        case nextWeekFocusText = "next_week_focus_text"
        case rating
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}
