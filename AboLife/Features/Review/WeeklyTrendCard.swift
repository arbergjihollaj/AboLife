import SwiftUI

struct WeeklyTrendCard: View {
    let title: String
    let systemImage: String
    let tint: Color
    let primary: String
    let secondary: String
    let points: [WeeklyTrendPoint]

    private var chartValues: [Double] {
        points.map(\.value)
    }

    var body: some View {
        AboLifeCard(minHeight: 168) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    Image(systemName: systemImage)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(tint)
                        .frame(width: 18)

                    Text(title)
                        .font(AboLifeTypography.cardTitle)
                        .foregroundStyle(AboLifeColors.primaryText)
                        .lineLimit(1)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(primary)
                        .font(AboLifeTypography.metric)
                        .foregroundStyle(AboLifeColors.primaryText)
                        .monospacedDigit()
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)

                    Text(secondary)
                        .font(AboLifeTypography.caption)
                        .foregroundStyle(AboLifeColors.secondaryText)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }

                WeeklySparklineView(values: chartValues, tint: tint)
                    .frame(height: 46)

                HStack {
                    ForEach(points) { point in
                        Text(point.weekdayLabel.prefix(2).uppercased())
                            .font(AboLifeTypography.micro)
                            .foregroundStyle(AboLifeColors.tertiaryText)
                            .frame(maxWidth: .infinity)
                    }
                }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title): \(primary), \(secondary)")
    }
}

private struct WeeklySparklineView: View {
    let values: [Double]
    let tint: Color

    var body: some View {
        ZStack {
            if values.contains(where: { $0 > 0 }) {
                MiniTrendChart(values: values, tint: tint)
                    .frame(height: 42)
            } else {
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .fill(AboLifeColors.glassStrokeMuted.opacity(0.55))
                    .frame(height: 2)
                    .frame(maxHeight: .infinity)
            }
        }
        .frame(maxWidth: .infinity)
        .accessibilityHidden(true)
    }
}
