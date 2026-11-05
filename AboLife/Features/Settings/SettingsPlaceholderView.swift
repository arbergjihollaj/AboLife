import SwiftUI

struct SettingsPlaceholderView: View {
    @Environment(\.aboLifeStyle) private var designStyle
    @Environment(\.appDatabase) private var appDatabase

    var body: some View {
        SettingsView(database: appDatabase)
    }
}
