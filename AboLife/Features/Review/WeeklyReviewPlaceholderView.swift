import SwiftUI

struct WeeklyReviewPlaceholderView: View {
    var body: some View {
        PlaceholderFeatureView(
            title: "Wochenreview",
            systemImage: "calendar.badge.clock",
            message: "Noch kein Wochenreview gespeichert. Dieser Bereich bleibt in Phase 1 ein Empty State."
        )
    }
}
