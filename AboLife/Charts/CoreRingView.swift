import SwiftUI

struct CoreRingView: View {
    let progress: Double
    let lineWidth: CGFloat
    let tint: Color
    var valueText: String? = nil
    var labelText: String = "Daily Core"

    private var clampedProgress: Double {
        min(max(progress, 0), 1)
    }

    private var resolvedValueText: String {
        valueText ?? "\(Int(clampedProgress * 100))%"
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

            VStack(spacing: 8) {
                Text(resolvedValueText)
                    .font(.system(size: 42, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(AboLifeColors.primaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)

                Text(labelText)
                    .font(AboLifeTypography.caption)
                    .foregroundStyle(AboLifeColors.secondaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)
            }
            .padding(.horizontal, lineWidth + 10)
        }
        .aspectRatio(1, contentMode: .fit)
        .accessibilityLabel("\(labelText) \(resolvedValueText)")
    }
}
