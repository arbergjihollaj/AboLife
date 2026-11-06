import SwiftUI

enum AboLifeSpacing {
    static let small: CGFloat = 8
    static let medium: CGFloat = 12
    static let section: CGFloat = 16
    static let page: CGFloat = 24
    static let generous: CGFloat = 32
}

enum AboLifeRadius {
    static let control: CGFloat = 8
    static let card: CGFloat = 12
    static let prominent: CGFloat = 16
}

enum AboLifeMotion {
    enum Kind {
        case interaction, navigation, metric, liquid
    }

    static func animation(for kind: Kind, reduceMotion: Bool) -> Animation? {
        guard !reduceMotion else { return nil }
        switch kind {
        case .interaction: return .easeOut(duration: 0.12)
        case .navigation: return .easeInOut(duration: 0.18)
        case .metric: return .smooth(duration: 0.35, extraBounce: 0)
        case .liquid: return .spring(response: 0.38, dampingFraction: 0.72)
        }
    }
}

private struct AboLifeMotionModifier<Value: Equatable>: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let value: Value
    let kind: AboLifeMotion.Kind

    func body(content: Content) -> some View {
        content.animation(AboLifeMotion.animation(for: kind, reduceMotion: reduceMotion), value: value)
    }
}

extension View {
    func aboLifeAppearance() -> some View {
        modifier(AboLifeAppearanceModifier())
    }

    func aboLifeMotion<Value: Equatable>(value: Value, kind: AboLifeMotion.Kind = .metric) -> some View {
        modifier(AboLifeMotionModifier(value: value, kind: kind))
    }

    func aboLifeNumericTransition<Value: Equatable>(value: Value) -> some View {
        contentTransition(.numericText())
            .aboLifeMotion(value: value)
    }
}

enum AboLifeAppearance: String, CaseIterable {
    case system, light, dark

    var title: String {
        switch self {
        case .system: return "System"
        case .light: return "Hell"
        case .dark: return "Dunkel"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}

private struct AboLifeAppearanceModifier: ViewModifier {
    @AppStorage("abolife.appearance") private var appearance = AboLifeAppearance.system.rawValue

    func body(content: Content) -> some View {
        content.preferredColorScheme(AboLifeAppearance(rawValue: appearance)?.colorScheme)
    }
}
