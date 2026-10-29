import SwiftUI

struct TrainingPlaceholderView: View {
    @Environment(\.appDatabase) private var appDatabase

    var body: some View {
        TrainingView(database: appDatabase)
    }
}
