import SwiftUI

struct AboLifePremiumBackground: View {
    @Environment(\.aboLifeStyle) private var designStyle
    var body: some View {
        designStyle.colors.pageBackground
            .ignoresSafeArea()
    }
}

extension View {
    func aboLifePage() -> some View {
        frame(maxWidth: 1320, alignment: .leading)
            .padding(AboLifeSpacing.page)
            .frame(maxWidth: .infinity)
    }
}
