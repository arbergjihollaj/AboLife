import AppKit
import SwiftUI

enum AboLifeColors {
    static let pageBackground = adaptive(light: 0.96, dark: 0.08)
    static let sidebarBackground = adaptive(light: 0.93, dark: 0.065)
    static let cardBackground = adaptive(light: 0.995, dark: 0.11)
    static let elevatedCardBackground = adaptive(light: 1, dark: 0.145)
    static let subtleFill = Color.primary.opacity(0.08)
    static let quietFill = Color.primary.opacity(0.034)
    static let primaryText = Color.primary
    static let secondaryText = Color(nsColor: .secondaryLabelColor)
    static let tertiaryText = Color(nsColor: .secondaryLabelColor)
    static let glassStroke = Color.primary.opacity(0.16)
    static let glassStrokeMuted = Color.primary.opacity(0.09)

    static let accentGreen = adaptive(
        light: NSColor(red: 0.12, green: 0.46, blue: 0.24, alpha: 1),
        dark: NSColor(red: 0.34, green: 0.82, blue: 0.47, alpha: 1))
    static let positive = adaptive(
        light: NSColor(red: 0.06, green: 0.42, blue: 0.52, alpha: 1),
        dark: NSColor(red: 0.38, green: 0.78, blue: 0.90, alpha: 1))
    static let training = adaptive(
        light: NSColor(red: 0.39, green: 0.32, blue: 0.70, alpha: 1),
        dark: NSColor(red: 0.58, green: 0.54, blue: 0.92, alpha: 1))
    static let finance = adaptive(
        light: NSColor(red: 0.08, green: 0.44, blue: 0.36, alpha: 1),
        dark: NSColor(red: 0.35, green: 0.80, blue: 0.72, alpha: 1))
    static let habits = adaptive(
        light: NSColor(red: 0.60, green: 0.32, blue: 0.10, alpha: 1),
        dark: NSColor(red: 0.95, green: 0.63, blue: 0.33, alpha: 1))
    static let action = Color(red: 0.20, green: 0.37, blue: 0.62)
    static let review = adaptive(
        light: NSColor(red: 0.20, green: 0.39, blue: 0.68, alpha: 1),
        dark: NSColor(red: 0.58, green: 0.72, blue: 0.96, alpha: 1))

    private static func adaptive(light: CGFloat, dark: CGFloat) -> Color {
        adaptive(light: NSColor(white: light, alpha: 1), dark: NSColor(white: dark, alpha: 1))
    }

    private static func adaptive(light: NSColor, dark: NSColor) -> Color {
        Color(
            nsColor: NSColor(name: nil) { appearance in
                appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua ? dark : light
            })
    }
}
