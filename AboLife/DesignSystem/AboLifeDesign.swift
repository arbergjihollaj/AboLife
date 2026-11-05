import SwiftUI

/// Presentation-only preferences. Never part of the shared database or sync contract.
enum AboLifeDesign: String, CaseIterable, Identifiable {
    case spatial, bento, fieldnotes
    var id: String { rawValue }
    var title: String {
        switch self {
        case .spatial: return "Spatial"
        case .bento: return "Bento"
        case .fieldnotes: return "Fieldnotes"
        }
    }
    var subtitle: String {
        switch self {
        case .spatial: return "Räumlicher Tageskern und schwebendes Dock"
        case .bento: return "Dein Arbeitsplatz mit anpassbaren Widgets"
        case .fieldnotes: return "Ein ruhiges Journal für deinen Alltag"
        }
    }
    var symbol: String {
        switch self {
        case .spatial: return "circle.hexagongrid"
        case .bento: return "square.grid.2x2"
        case .fieldnotes: return "book.closed"
        }
    }
}

enum AboLifeAccent: String, CaseIterable, Identifiable {
    case original, blue, violet, amber
    var id: String { rawValue }
    var title: String {
        switch self {
        case .original: return "Original"
        case .blue: return "Blau"
        case .violet: return "Violett"
        case .amber: return "Bernstein"
        }
    }
}

enum DashboardWidget: String, CaseIterable, Identifiable, Codable {
    case finance, training, habits, activity, week
    var id: String { rawValue }
    var title: String {
        switch self {
        case .finance: return "Budget"
        case .training: return "Training"
        case .habits: return "Gewohnheiten"
        case .activity: return "Aktivitäten"
        case .week: return "Wochenübersicht"
        }
    }
}

struct AboLifeStyle: Equatable {
    var design: AboLifeDesign = .spatial
    var accent: AboLifeAccent = .original
    var colors: AboLifePalette { AboLifePalette(style: self) }
}

private struct AboLifeWidgetsKey: EnvironmentKey {
    static let defaultValue = DashboardWidget.allCases
}

private struct AboLifeStyleKey: EnvironmentKey {
    static let defaultValue = AboLifeStyle()
}

extension EnvironmentValues {
    var aboLifeWidgets: [DashboardWidget] {
        get { self[AboLifeWidgetsKey.self] }
        set { self[AboLifeWidgetsKey.self] = newValue }
    }
    var aboLifeStyle: AboLifeStyle {
        get { self[AboLifeStyleKey.self] }
        set { self[AboLifeStyleKey.self] = newValue }
    }
}

@MainActor
final class AboLifeDesignStore: ObservableObject {
    static let designKey = "abolife.design"
    static let accentKey = "abolife.design.accent"
    static let widgetsKey = "abolife.design.widgets"
    @Published var design: AboLifeDesign { didSet { defaults.set(design.rawValue, forKey: Self.designKey) } }
    @Published var accent: AboLifeAccent { didSet { defaults.set(accent.rawValue, forKey: Self.accentKey) } }
    @Published private(set) var widgets: [DashboardWidget]
    private let defaults: UserDefaults
    var style: AboLifeStyle { AboLifeStyle(design: design, accent: accent) }

    init(defaults: UserDefaults) {
        self.defaults = defaults
        design = AboLifeDesign(rawValue: defaults.string(forKey: Self.designKey) ?? "") ?? .spatial
        accent = AboLifeAccent(rawValue: defaults.string(forKey: Self.accentKey) ?? "") ?? .original
        widgets = Self.normalizedWidgets(defaults.stringArray(forKey: Self.widgetsKey) ?? [])
    }

    static func normalizedWidgets(_ ids: [String]) -> [DashboardWidget] {
        var seen = Set<DashboardWidget>()
        return (ids.compactMap(DashboardWidget.init(rawValue:)) + DashboardWidget.allCases).filter {
            seen.insert($0).inserted
        }
    }

    func move(_ widget: DashboardWidget, to target: DashboardWidget) {
        guard let from = widgets.firstIndex(of: widget), let to = widgets.firstIndex(of: target), from != to else {
            return
        }
        var order = widgets
        order.remove(at: from)
        order.insert(widget, at: to)
        widgets = order
        defaults.set(order.map(\.rawValue), forKey: Self.widgetsKey)
    }

    func move(_ widget: DashboardWidget, offset: Int) {
        guard let from = widgets.firstIndex(of: widget), widgets.indices.contains(from + offset) else { return }
        move(widget, to: widgets[from + offset])
    }
}

struct AboLifePalette {
    let style: AboLifeStyle
    var pageBackground: Color {
        switch style.design {
        case .spatial: return adaptive(0xEDF4F5, 0x111D29)
        case .bento: return adaptive(0xF0EFF6, 0x191722)
        case .fieldnotes: return adaptive(0xF6F2E9, 0x222820)
        }
    }
    var sidebarBackground: Color { pageBackground }
    var cardBackground: Color {
        switch style.design {
        case .spatial: return adaptive(0xFFFFFF, 0x1C303B)
        case .bento: return adaptive(0xFFFFFF, 0x282436)
        case .fieldnotes: return adaptive(0xFCFAF4, 0x2B3329)
        }
    }
    var elevatedCardBackground: Color { cardBackground }
    var action: Color {
        switch style.accent {
        case .blue: return adaptive(0x285C99, 0x9EDBFF)
        case .violet: return adaptive(0x6B4298, 0xD3B5FF)
        case .amber: return adaptive(0x87561D, 0xFFCE89)
        case .original:
            switch style.design {
            case .spatial: return adaptive(0x206550, 0x8CF5D4)
            case .bento: return adaptive(0x6955B8, 0xBAA8FF)
            case .fieldnotes: return adaptive(0x496C55, 0xB5CBA2)
            }
        }
    }
    var review: Color { action }
    var primaryText: Color { .primary }
    var secondaryText: Color { .secondary }
    var tertiaryText: Color { .secondary }
    var subtleFill: Color { action.opacity(0.12) }
    var quietFill: Color { action.opacity(0.06) }
    var glassStroke: Color { Color.primary.opacity(0.2) }
    var glassStrokeMuted: Color { Color.primary.opacity(0.1) }
    var accentGreen: Color { AboLifeColors.accentGreen }
    var positive: Color { AboLifeColors.positive }
    var training: Color { AboLifeColors.training }
    var finance: Color { AboLifeColors.finance }
    var habits: Color { AboLifeColors.habits }

    private func adaptive(_ light: UInt32, _ dark: UInt32) -> Color {
        Color(
            nsColor: NSColor(name: nil) { appearance in
                let value = appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua ? dark : light
                return NSColor(
                    red: Double((value >> 16) & 255) / 255,
                    green: Double((value >> 8) & 255) / 255,
                    blue: Double(value & 255) / 255, alpha: 1)
            })
    }
}

private struct AboLifeDesignModifier: ViewModifier {
    @ObservedObject var store: AboLifeDesignStore
    func body(content: Content) -> some View {
        content
            .environmentObject(store)
            .environment(\.aboLifeStyle, store.style)
            .environment(\.aboLifeWidgets, store.widgets)
            .fontDesign(store.design == .fieldnotes ? .serif : .default)
            .tint(store.style.colors.action)
    }
}

extension View {
    func aboLifeDesign(_ store: AboLifeDesignStore) -> some View {
        modifier(AboLifeDesignModifier(store: store))
    }
}

/// The lowercase a-dot mark from the approved prototypes, adapted to each presentation.
struct AboLifeBrandMark: View {
    @Environment(\.aboLifeStyle) private var style
    @Environment(\.colorScheme) private var colorScheme
    var size: CGFloat = 28

    private var fill: Color {
        style.design == .spatial && style.accent == .original
            ? Color(red: 140 / 255, green: 245 / 255, blue: 212 / 255) : style.colors.action
    }
    private var ink: Color {
        if style.design == .fieldnotes { return style.colors.action }
        if (style.design == .spatial && style.accent == .original) || colorScheme == .dark {
            return Color(red: 19 / 255, green: 44 / 255, blue: 43 / 255)
        }
        return .white
    }

    var body: some View {
        Text("a.")
            .font(
                .system(
                    size: size * 0.82, weight: .semibold,
                    design: style.design == .fieldnotes ? .serif : .default)
            )
            .kerning(-size * 0.025)
            .foregroundStyle(ink)
            .frame(width: size, height: size)
            .background {
                if style.design == .spatial { Circle().fill(fill) }
                if style.design == .bento {
                    RoundedRectangle(cornerRadius: size * 0.3).fill(fill)
                }
            }
            .accessibilityHidden(true)
    }
}
