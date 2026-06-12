import SwiftUI

struct HabitsPlaceholderView: View {
    @Environment(\.appDatabase) private var appDatabase

    var body: some View {
        HabitsView(database: appDatabase)
    }
}
