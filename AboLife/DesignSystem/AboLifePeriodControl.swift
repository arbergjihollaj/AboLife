import SwiftUI

struct AboLifePeriodControl: View {
    let title: String
    let previousLabel: String
    let nextLabel: String
    var canGoForward = true
    let previous: () -> Void
    let next: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Button(previousLabel, systemImage: "chevron.left", action: previous)
                .labelStyle(.iconOnly)
            Text(title)
                .font(AboLifeTypography.caption)
                .foregroundStyle(AboLifeColors.secondaryText)
                .monospacedDigit()
                .lineLimit(1)
            Button(nextLabel, systemImage: "chevron.right", action: next)
                .labelStyle(.iconOnly)
                .disabled(!canGoForward)
        }
        .buttonStyle(.bordered)
        .accessibilityElement(children: .contain)
    }
}
