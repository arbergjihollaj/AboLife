import SwiftUI

struct WeeklyReviewPlaceholderView: View {
    @Environment(\.appDatabase) private var appDatabase

    var body: some View {
        WeeklyReviewView(database: appDatabase)
    }
}
