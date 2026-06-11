import SwiftUI

struct NutritionPlaceholderView: View {
    var body: some View {
        PlaceholderFeatureView(
            title: "Ernährung",
            systemImage: "fork.knife",
            message: "Heute noch keine Mahlzeit erfasst. Die echte Erfassung kommt nach dem Phase-1-Prototyp."
        )
    }
}
