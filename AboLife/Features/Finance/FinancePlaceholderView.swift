import SwiftUI

struct FinancePlaceholderView: View {
    @Environment(\.appDatabase) private var appDatabase

    var body: some View {
        FinanceView(database: appDatabase)
    }
}
