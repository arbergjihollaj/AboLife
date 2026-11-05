import SwiftUI

struct WeeklyReviewPlaceholderView: View {
    @Environment(\.aboLifeStyle) private var designStyle
    @Environment(\.appDatabase) private var appDatabase

    var body: some View {
        WeeklyReviewView(database: appDatabase)
    }
}
