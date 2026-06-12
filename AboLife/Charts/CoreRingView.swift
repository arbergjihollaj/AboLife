import SwiftUI

struct CoreRingView: View {
    let progress: Double
    let lineWidth: CGFloat
    let tint: Color

    private var clampedProgress: Double {
        min(max(progress, 0), 1)
    }

    var body: some View {
        ZStack {
            Circle()
                .stroke(AboLifeColors.quietFill, lineWidth: lineWidth)
                .overlay {
                    Circle()
                        .stroke(AboLifeColors.glassStrokeMuted, lineWidth: 0.7)
                }

            Circle()
                .trim(from: 0, to: clampedProgress)
                .stroke(
                    AngularGradient(
                        colors: [
                            tint.opacity(0.44),
                            tint.opacity(0.88),
                            tint.opacity(0.70),
                            tint.opacity(0.52)
                        ],
                        center: .center
                    ),
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .shadow(color: tint.opacity(0.14), radius: 8, x: 0, y: 0)

            VStack(spacing: 3) {
                Text("\(Int(clampedProgress * 100))%")
                    .font(AboLifeTypography.heroNumber)
                    .monospacedDigit()
                    .foregroundStyle(AboLifeColors.primaryText)
                Text("Daily Core")
                    .font(AboLifeTypography.caption)
                    .foregroundStyle(AboLifeColors.secondaryText)
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .accessibilityLabel("Daily Core \(Int(clampedProgress * 100)) Prozent")
    }
}
