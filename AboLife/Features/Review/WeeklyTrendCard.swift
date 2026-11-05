import SwiftUI

struct WeeklyTrendCard: View {
    @Environment(\.aboLifeStyle) private var designStyle
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
                        .foregroundStyle(designStyle.colors.secondaryText)
                        .frame(width: 18)

                    Text(title)
                        .font(AboLifeTypography.cardTitle)
                        .foregroundStyle(designStyle.colors.primaryText)
                        .lineLimit(1)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(primary)
                        .font(AboLifeTypography.metric)
                        .foregroundStyle(designStyle.colors.primaryText)
                        .monospacedDigit()
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)

                    Text(secondary)
                        .font(AboLifeTypography.caption)
                        .foregroundStyle(designStyle.colors.secondaryText)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }

                WeeklySparklineView(values: chartValues, tint: tint)
                    .frame(height: 46)

                HStack {
                    ForEach(points) { point in
                        Text(point.weekdayLabel.prefix(2))
                            .font(AboLifeTypography.micro)
                            .foregroundStyle(designStyle.colors.tertiaryText)
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
    @Environment(\.aboLifeStyle) private var designStyle
    let values: [Double]
    let tint: Color

    var body: some View {
        ZStack {
            if values.contains(where: { $0 > 0 }) {
                MiniTrendChart(values: values, tint: tint)
                    .frame(height: 42)
            } else {
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .fill(designStyle.colors.glassStrokeMuted.opacity(0.55))
                    .frame(height: 2)
                    .frame(maxHeight: .infinity)
            }
        }
        .frame(maxWidth: .infinity)
        .accessibilityHidden(true)
    }
}
