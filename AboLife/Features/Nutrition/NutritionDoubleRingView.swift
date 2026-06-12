import SwiftUI

struct NutritionDoubleRingView: View {
    let caloriesConsumed: Int
    let caloriesTarget: Int
    let proteinConsumed: Double
    let proteinTarget: Double
    let caloriesProgress: Double
    let proteinProgress: Double

    var body: some View {
        ZStack {
            ring(progress: caloriesProgress, tint: AboLifeColors.nutrition, lineWidth: 18)
                .frame(width: 250, height: 250)

            ring(progress: proteinProgress, tint: AboLifeColors.protein, lineWidth: 13)
                .frame(width: 178, height: 178)

            VStack(spacing: 6) {
                Text("\(caloriesConsumed)")
                    .font(.system(size: 44, weight: .semibold, design: .rounded))
                    .foregroundStyle(AboLifeColors.primaryText)
                    .monospacedDigit()

                Text("kcal")
                    .font(AboLifeTypography.caption)
                    .foregroundStyle(AboLifeColors.secondaryText)

                Text("\(Int(proteinConsumed)) g Protein")
                    .font(AboLifeTypography.caption.weight(.semibold))
                    .foregroundStyle(AboLifeColors.protein)
                    .monospacedDigit()
            }
            .accessibilityHidden(true)
        }
        .frame(width: 274, height: 274)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            "Kalorien \(caloriesConsumed) von \(caloriesTarget), Protein \(Int(proteinConsumed)) von \(Int(proteinTarget)) Gramm"
        )
    }

    private func ring(progress: Double, tint: Color, lineWidth: CGFloat) -> some View {
        let clampedProgress = min(max(progress, 0), 1)

        return ZStack {
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
                            tint.opacity(0.42),
                            tint.opacity(0.86),
                            tint.opacity(0.68),
                            tint.opacity(0.48)
                        ],
                        center: .center
                    ),
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .shadow(color: tint.opacity(0.12), radius: 7, x: 0, y: 0)

            Circle()
                .trim(from: 0, to: clampedProgress)
                .stroke(
                    Color.white.opacity(0.10),
                    style: StrokeStyle(lineWidth: max(1, lineWidth * 0.18), lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .padding(lineWidth * 0.34)
        }
        .aspectRatio(1, contentMode: .fit)
    }
}

struct NutritionDoubleRingView_Previews: PreviewProvider {
    static var previews: some View {
        ZStack {
            AboLifePremiumBackground()
            NutritionDoubleRingView(
                caloriesConsumed: 1650,
                caloriesTarget: 2200,
                proteinConsumed: 118,
                proteinTarget: 160,
                caloriesProgress: 0.75,
                proteinProgress: 0.74
            )
        }
        .frame(width: 420, height: 420)
    }
}
