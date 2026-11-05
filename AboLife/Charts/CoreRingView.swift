import SwiftUI

struct CoreRingView: View {
    let progress: Double
    let lineWidth: CGFloat
    let tint: Color
    var valueText: String? = nil
    var labelText: String = "Daily Core"
    var showsScale = false

    private var clampedProgress: Double {
        progress.isFinite ? min(max(progress, 0), 1) : 0
    }

    private var resolvedValueText: String {
        valueText ?? "\(Int(clampedProgress * 100))%"
    }

    var body: some View {
        ZStack {
            Circle()
                .strokeBorder(AboLifeColors.subtleFill, lineWidth: lineWidth)

            Circle()
                .inset(by: lineWidth / 2)
                .trim(from: 0, to: clampedProgress)
                .stroke(tint, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .opacity(clampedProgress > 0 ? 1 : 0)
                .aboLifeMotion(value: clampedProgress)

            if showsScale {
                Circle()
                    .inset(by: lineWidth + 7)
                    .strokeBorder(
                        AboLifeColors.glassStroke,
                        style: StrokeStyle(lineWidth: 4, dash: [1, 5])
                    )
            }

            VStack(spacing: 4) {
                Text(resolvedValueText)
                    .font(showsScale ? AboLifeTypography.heroNumber : .system(size: 42, weight: .semibold))
                    .monospacedDigit()
                    .aboLifeNumericTransition(value: resolvedValueText)
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
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(labelText) \(resolvedValueText)")
    }
}
