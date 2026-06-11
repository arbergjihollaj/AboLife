import SwiftUI

struct TrainingPlaceholderView: View {
    var body: some View {
        PlaceholderFeatureView(
            title: "Training",
            systemImage: "figure.strengthtraining.traditional",
            message: "Noch kein Training für heute eingetragen. Details und echte Sessions folgen später."
        )
    }
}
