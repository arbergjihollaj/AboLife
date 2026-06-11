import SwiftUI

struct CoreRingView: View {
    let progress: Double
    let lineWidth: CGFloat
    let tint: Color

    var body: some View {
        ZStack {
            Circle()
                .stroke(AboLifeColors.subtleFill, lineWidth: lineWidth)

            Circle()
                .trim(from: 0, to: min(max(progress, 0), 1))
                .stroke(
                    tint,
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))

            VStack(spacing: 2) {
                Text("\(Int(progress * 100))%")
                    .font(AboLifeTypography.heroNumber)
                    .monospacedDigit()
                Text("Daily Core")
                    .font(AboLifeTypography.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .accessibilityLabel("Daily Core \(Int(progress * 100)) Prozent")
    }
}
