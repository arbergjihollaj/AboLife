import SwiftUI

struct AboLifePremiumBackground: View {
    var body: some View {
        ZStack {
            AboLifeColors.premiumBackgroundGradient

            RadialGradient(
                colors: [
                    AboLifeColors.backgroundGlowA.opacity(0.44),
                    AboLifeColors.backgroundGlowA.opacity(0.0)
                ],
                center: .topLeading,
                startRadius: 40,
                endRadius: 560
            )

            RadialGradient(
                colors: [
                    AboLifeColors.backgroundGlowB.opacity(0.34),
                    AboLifeColors.backgroundGlowB.opacity(0.0)
                ],
                center: .bottomTrailing,
                startRadius: 90,
                endRadius: 680
            )

            RadialGradient(
                colors: [
                    AboLifeColors.backgroundGlowC.opacity(0.20),
                    AboLifeColors.backgroundGlowC.opacity(0.0)
                ],
                center: UnitPoint(x: 0.56, y: 0.18),
                startRadius: 30,
                endRadius: 520
            )

            LinearGradient(
                colors: [
                    Color.white.opacity(0.030),
                    Color.clear,
                    Color.black.opacity(0.10)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
        .ignoresSafeArea()
    }
}
