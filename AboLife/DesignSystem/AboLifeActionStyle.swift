import SwiftUI

/// Restrained feedback for custom quick actions; standard forms retain native button styles.
struct AboLifeActionStyle: ButtonStyle {
    @Environment(\.aboLifeStyle) private var designStyle
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isHovered = false

    var isProminent = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(AboLifeTypography.cardTitle)
            .foregroundStyle(
                isProminent ? (colorScheme == .dark ? Color.black : Color.white) : designStyle.colors.primaryText
            )
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .background {
                RoundedRectangle(cornerRadius: AboLifeRadius.control)
                    .fill(
                        isProminent ? designStyle.colors.action : (isHovered ? designStyle.colors.subtleFill : .clear))
            }
            .contentShape(.rect(cornerRadius: AboLifeRadius.control))
            .opacity(isEnabled ? (configuration.isPressed ? 0.8 : 1) : 0.45)
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.98 : 1)
            .animation(
                AboLifeMotion.animation(for: .interaction, reduceMotion: reduceMotion), value: configuration.isPressed
            )
            .animation(AboLifeMotion.animation(for: .interaction, reduceMotion: reduceMotion), value: isHovered)
            .onHover { isHovered = $0 }
    }
}

struct AboLifeSidebarStyle: ButtonStyle {
    @Environment(\.aboLifeStyle) private var designStyle
    @State private var isHovered = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(
                isHovered ? designStyle.colors.quietFill : .clear, in: .rect(cornerRadius: AboLifeRadius.control)
            )
            .opacity(configuration.isPressed ? 0.8 : 1)
            .aboLifeMotion(value: isHovered, kind: .interaction)
            .onHover { isHovered = $0 }
    }
}
