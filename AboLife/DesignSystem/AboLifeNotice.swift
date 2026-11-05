import SwiftUI

struct AboLifeNotice: View {
    let title: String
    let message: String
    var systemImage = "exclamationmark.circle"
    var retry: (() -> Void)?

    var body: some View {
        HStack(alignment: .top, spacing: AboLifeSpacing.medium) {
            Image(systemName: systemImage)
                .foregroundStyle(AboLifeColors.habits)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(AboLifeTypography.cardTitle)
                Text(message)
                    .font(AboLifeTypography.caption)
                    .foregroundStyle(AboLifeColors.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
                if let retry {
                    Button("Erneut versuchen", systemImage: "arrow.clockwise", action: retry)
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                }
            }
            Spacer(minLength: 0)
        }
        .foregroundStyle(AboLifeColors.primaryText)
        .padding(AboLifeSpacing.section)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AboLifeColors.quietFill, in: .rect(cornerRadius: AboLifeRadius.card))
        .accessibilityElement(children: .contain)
    }
}
