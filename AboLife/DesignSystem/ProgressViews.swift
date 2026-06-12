import SwiftUI

struct MetricProgressView: View {
    let progress: Double
    let tint: Color

    private var clampedProgress: Double {
        min(max(progress, 0), 1)
    }

    var body: some View {
        PremiumProgressBar(progress: clampedProgress, tint: tint, height: 8)
            .accessibilityLabel("Fortschritt \(Int(clampedProgress * 100)) Prozent")
    }
}

struct PremiumProgressBar: View {
    let progress: Double
    let tint: Color
    var height: CGFloat = 8

    private var clampedProgress: Double {
        min(max(progress, 0), 1)
    }

    var body: some View {
        GeometryReader { proxy in
            let fillWidth = max(clampedProgress > 0 ? height : 0, proxy.size.width * CGFloat(clampedProgress))

            ZStack(alignment: .leading) {
                Capsule()
                    .fill(AboLifeColors.quietFill)
                    .overlay {
                        Capsule()
                            .strokeBorder(AboLifeColors.glassStrokeMuted, lineWidth: 0.55)
                    }

                Capsule()
                    .fill(AboLifeColors.premiumGradient(for: tint))
                    .frame(width: fillWidth)
                    .overlay(alignment: .top) {
                        Capsule()
                            .fill(Color.white.opacity(0.12))
                            .frame(height: max(1, height * 0.20))
                            .padding(.horizontal, 2)
                            .padding(.top, 1)
                    }
                    .shadow(color: tint.opacity(0.13), radius: 5, x: 0, y: 0)
            }
        }
        .frame(height: height)
    }
}

struct WeeklyStatusStrip: View {
    let days: [WeeklyStatusItem]

    var body: some View {
        HStack(spacing: 8) {
            ForEach(days) { day in
                VStack(spacing: 6) {
                    Text(day.shortName)
                        .font(AboLifeTypography.micro)
                        .foregroundStyle(AboLifeColors.secondaryText)
                        .frame(height: 12)

                    GeometryReader { proxy in
                        let clamped = min(max(day.completion, 0), 1)
                        let fillHeight = max(clamped > 0 ? 8 : 0, proxy.size.height * CGFloat(clamped))

                        ZStack(alignment: .bottom) {
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(AboLifeColors.quietFill)
                                .overlay {
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .strokeBorder(AboLifeColors.glassStrokeMuted, lineWidth: 0.55)
                                }

                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(AboLifeColors.premiumGradient(for: day.tint))
                                .frame(height: fillHeight)
                                .overlay(alignment: .top) {
                                    Capsule()
                                        .fill(Color.white.opacity(0.11))
                                        .frame(height: 1.5)
                                        .padding(.horizontal, 5)
                                        .padding(.top, 4)
                                }
                                .shadow(color: day.tint.opacity(0.10), radius: 5, x: 0, y: 0)
                        }
                    }
                    .frame(width: 34, height: 48)

                    Circle()
                        .fill(day.completion >= 0.66 ? day.tint.opacity(0.70) : AboLifeColors.tertiaryText)
                        .frame(width: 3.5, height: 3.5)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Wochenstatus")
    }
}

struct WeeklyStatusItem: Identifiable {
    var id: String { shortName }

    let shortName: String
    let completion: Double
    let tint: Color
}
