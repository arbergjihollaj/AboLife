import SwiftUI

struct FinancePlaceholderView: View {
    @Environment(\.aboLifeStyle) private var designStyle
    @Environment(\.appDatabase) private var appDatabase

    var body: some View {
        FinanceView(database: appDatabase)
    }
}
