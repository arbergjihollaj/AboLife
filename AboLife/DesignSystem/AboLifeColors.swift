import SwiftUI

enum AboLifeColors {
    static let pageBackground = Color(red: 0.035, green: 0.041, blue: 0.057)
    static let cardBackground = Color.white.opacity(0.040)
    static let elevatedCardBackground = Color.white.opacity(0.070)
    static let subtleFill = Color.white.opacity(0.080)
    static let quietFill = Color.white.opacity(0.034)
    static let primaryText = Color.white.opacity(0.94)
    static let secondaryText = Color.white.opacity(0.62)
    static let tertiaryText = Color.white.opacity(0.42)
    static let glassStroke = Color.white.opacity(0.16)
    static let glassStrokeMuted = Color.white.opacity(0.070)
    static let glassHighlight = Color.white.opacity(0.16)
    static let shadow = Color.black.opacity(0.28)

    static let nutrition = Color(red: 0.34, green: 0.82, blue: 0.47)
    static let protein = Color(red: 0.38, green: 0.78, blue: 0.90)
    static let training = Color(red: 0.58, green: 0.54, blue: 0.92)
    static let finance = Color(red: 0.35, green: 0.80, blue: 0.72)
    static let habits = Color(red: 0.95, green: 0.63, blue: 0.33)
    static let review = Color(red: 0.47, green: 0.66, blue: 0.95)

    static let backgroundGlowA = Color(red: 0.12, green: 0.18, blue: 0.27)
    static let backgroundGlowB = Color(red: 0.14, green: 0.10, blue: 0.18)
    static let backgroundGlowC = Color(red: 0.08, green: 0.22, blue: 0.23)

    static var premiumBackgroundGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color(red: 0.055, green: 0.064, blue: 0.086),
                Color(red: 0.032, green: 0.037, blue: 0.052),
                Color(red: 0.020, green: 0.023, blue: 0.032)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    static var glassSurfaceGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color.white.opacity(0.066),
                Color.white.opacity(0.020),
                Color.white.opacity(0.004)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    static var glassHighlightGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color.white.opacity(0.18),
                Color.white.opacity(0.030),
                Color.white.opacity(0.0)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    static var liquidGlassEdgeGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color.white.opacity(0.36),
                Color.white.opacity(0.085),
                Color.white.opacity(0.010)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    static var liquidSpecularGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color.white.opacity(0.28),
                Color.white.opacity(0.052),
                Color.white.opacity(0.0)
            ],
            startPoint: .topLeading,
            endPoint: UnitPoint(x: 0.64, y: 0.52)
        )
    }

    static var sidebarSelectionGradient: LinearGradient {
        LinearGradient(
            colors: [
                review.opacity(0.92),
                Color(red: 0.19, green: 0.40, blue: 0.88).opacity(0.82)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    static func premiumGradient(for tint: Color) -> LinearGradient {
        LinearGradient(
            colors: [
                tint.opacity(0.88),
                tint.opacity(0.66),
                tint.opacity(0.38)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}
