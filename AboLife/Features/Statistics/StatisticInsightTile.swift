import SwiftUI

struct StatisticInsightTile: View {
    @Environment(\.aboLifeStyle) private var designStyle
    let insight: StatisticInsight

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 9) {
                Image(systemName: insight.systemImage)
                    .foregroundStyle(tint)
                    .frame(width: 20)

                Text(insight.title)
                    .font(AboLifeTypography.caption.weight(.semibold))
                    .foregroundStyle(designStyle.colors.primaryText)
                    .lineLimit(1)
            }

            Text(insight.value)
                .font(AboLifeTypography.metric)
                .foregroundStyle(designStyle.colors.primaryText)
                .monospacedDigit()
                .aboLifeNumericTransition(value: insight.value)
                .lineLimit(1)
                .minimumScaleFactor(0.72)

            Text(insight.detail)
                .font(AboLifeTypography.caption)
                .foregroundStyle(designStyle.colors.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .frame(maxWidth: .infinity, minHeight: 136, alignment: .topLeading)
        .background(designStyle.colors.quietFill, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(designStyle.colors.glassStrokeMuted, lineWidth: 0.7)
        }
    }

    private var tint: Color {
        switch insight.tintRole {
        case .training: return designStyle.colors.training
        case .finance: return designStyle.colors.finance
        case .habits: return designStyle.colors.habits
        case .review: return designStyle.colors.review
        }
    }

}
