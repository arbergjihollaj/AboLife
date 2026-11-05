import SwiftUI

struct HabitsPlaceholderView: View {
    @Environment(\.aboLifeStyle) private var designStyle
    @Environment(\.appDatabase) private var appDatabase

    var body: some View {
        HabitsView(database: appDatabase)
    }
}
