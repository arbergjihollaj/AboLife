import SwiftUI

struct NutritionPlaceholderView: View {
    @Environment(\.appDatabase) private var appDatabase

    var body: some View {
        NutritionView(database: appDatabase)
    }
}
