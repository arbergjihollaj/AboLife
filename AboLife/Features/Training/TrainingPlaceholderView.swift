import SwiftUI

struct TrainingPlaceholderView: View {
    @Environment(\.aboLifeStyle) private var designStyle
    @Environment(\.appDatabase) private var appDatabase

    var body: some View {
        TrainingView(database: appDatabase)
    }
}
