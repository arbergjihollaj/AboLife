import SwiftUI

struct FinancePlaceholderView: View {
    var body: some View {
        PlaceholderFeatureView(
            title: "Finanzen",
            systemImage: "eurosign.circle",
            message: "Noch keine Ausgaben diesen Monat erfasst. Phase 1 zeigt nur den Dashboard-Prototyp."
        )
    }
}
