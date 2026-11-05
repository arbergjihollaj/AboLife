import SwiftUI

struct MetricProgressView: View {
    let progress: Double
    let tint: Color

    private var clampedProgress: Double {
        progress.isFinite ? min(max(progress, 0), 1) : 0
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
        progress.isFinite ? min(max(progress, 0), 1) : 0
    }

    var body: some View {
        GeometryReader { proxy in
            let fillWidth = proxy.size.width * CGFloat(clampedProgress)

            ZStack(alignment: .leading) {
                Capsule().fill(AboLifeColors.subtleFill)
                Capsule().fill(tint).frame(width: fillWidth)
                    .aboLifeMotion(value: clampedProgress)
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
                        .foregroundStyle(day.completion == nil ? AboLifeColors.secondaryText : day.tint)
                        .frame(height: 12)

                    GeometryReader { proxy in
                        let clamped = min(max(day.completion ?? 0, 0), 1)
                        let fillHeight = proxy.size.height * CGFloat(clamped)

                        ZStack(alignment: .bottom) {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(AboLifeColors.subtleFill)

                            RoundedRectangle(cornerRadius: 4)
                                .fill(day.tint.opacity(0.85))
                                .frame(height: fillHeight)
                                .aboLifeMotion(value: clamped)
                        }
                    }
                    .frame(width: 20, height: 44)
                }
                .frame(maxWidth: .infinity)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("\(day.shortName), \(day.statusText)")
            }
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Wochenstatus")
    }
}

struct WeeklyStatusItem: Identifiable {
    var id: String { shortName }

    let shortName: String
    let completion: Double?
    let tint: Color

    var statusText: String {
        guard let completion else { return "Kein Tagesstand" }
        return "\(Int(min(max(completion, 0), 1) * 100)) Prozent"
    }
}
