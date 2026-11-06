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

/// A rounded surface whose edges briefly swell; labels and hit targets keep their shape.
struct AboLifeLiquidBulgeShape: Shape {
    var amount: CGFloat
    var animatableData: CGFloat {
        get { amount }
        set { amount = newValue }
    }

    func path(in rect: CGRect) -> Path {
        let radius = min(12, min(rect.width, rect.height) / 2)
        let bulge = min(max(amount, 0), 1) * min(6, min(rect.width, rect.height) * 0.12)
        let left = rect.minX, right = rect.maxX, top = rect.minY, bottom = rect.maxY
        var path = Path()
        path.move(to: CGPoint(x: left + radius, y: top))
        path.addCurve(
            to: CGPoint(x: right - radius, y: top),
            control1: CGPoint(x: left + rect.width * 0.35, y: top - bulge),
            control2: CGPoint(x: left + rect.width * 0.65, y: top - bulge))
        path.addQuadCurve(to: CGPoint(x: right, y: top + radius), control: CGPoint(x: right, y: top))
        path.addCurve(
            to: CGPoint(x: right, y: bottom - radius),
            control1: CGPoint(x: right + bulge, y: top + rect.height * 0.35),
            control2: CGPoint(x: right + bulge, y: top + rect.height * 0.65))
        path.addQuadCurve(to: CGPoint(x: right - radius, y: bottom), control: CGPoint(x: right, y: bottom))
        path.addCurve(
            to: CGPoint(x: left + radius, y: bottom),
            control1: CGPoint(x: left + rect.width * 0.65, y: bottom + bulge),
            control2: CGPoint(x: left + rect.width * 0.35, y: bottom + bulge))
        path.addQuadCurve(to: CGPoint(x: left, y: bottom - radius), control: CGPoint(x: left, y: bottom))
        path.addCurve(
            to: CGPoint(x: left, y: top + radius),
            control1: CGPoint(x: left - bulge, y: top + rect.height * 0.65),
            control2: CGPoint(x: left - bulge, y: top + rect.height * 0.35))
        path.addQuadCurve(to: CGPoint(x: left + radius, y: top), control: CGPoint(x: left, y: top))
        path.closeSubpath()
        return path
    }
}

struct AboLifeLiquidSelection: View {
    let isSelected: Bool
    let namespace: Namespace.ID
    var enabled = true
    @Environment(\.aboLifeStyle) private var style
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Color.clear
            .keyframeAnimator(initialValue: CGFloat.zero, trigger: isSelected) { base, amount in
                base.overlay {
                    if isSelected {
                        let shape = AboLifeLiquidBulgeShape(amount: enabled && !reduceMotion ? amount : 0)
                        shape.fill(style.colors.subtleFill)
                            .overlay { shape.stroke(style.colors.action.opacity(0.18), lineWidth: 0.7) }
                            .matchedGeometryEffect(id: "active-tab", in: namespace)
                    }
                }
            } keyframes: { _ in
                CubicKeyframe(CGFloat(1), duration: 0.12)
                CubicKeyframe(CGFloat.zero, duration: 0.28)
            }
            .allowsHitTesting(false)
    }
}

struct AboLifeLiquidTabStyle: ButtonStyle {
    var enabled = true
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .contentShape(Rectangle())
            .scaleEffect(configuration.isPressed && enabled && !reduceMotion ? 0.96 : 1)
            .opacity(configuration.isPressed ? 0.85 : 1)
            .animation(
                AboLifeMotion.animation(for: .liquid, reduceMotion: reduceMotion),
                value: configuration.isPressed)
    }
}
