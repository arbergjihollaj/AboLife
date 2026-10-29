import SwiftUI

enum QuickAddKind: String, Identifiable, CaseIterable {
    case general
    case workout
    case expense
    case habit
    case weight

    var id: String { rawValue }
}

struct QuickAddAction: Identifiable {
    let kind: QuickAddKind
    let title: String
    let systemImage: String
    let tint: Color

    var id: QuickAddKind { kind }

    static let dashboardActions: [QuickAddAction] = [
        QuickAddAction(kind: .workout, title: "Training", systemImage: "figure.strengthtraining.traditional", tint: AboLifeColors.training),
        QuickAddAction(kind: .expense, title: "Ausgabe", systemImage: "eurosign.circle", tint: AboLifeColors.finance),
        QuickAddAction(kind: .weight, title: "Gewicht", systemImage: "scalemass", tint: AboLifeColors.review),
        QuickAddAction(kind: .habit, title: "Gewohnheit", systemImage: "checkmark.seal", tint: AboLifeColors.habits)
    ]

    static let bottomDockActions: [QuickAddAction] = [
        QuickAddAction(kind: .workout, title: "Training", systemImage: "figure.strengthtraining.traditional", tint: AboLifeColors.training),
        QuickAddAction(kind: .expense, title: "Ausgabe", systemImage: "eurosign.circle", tint: AboLifeColors.finance),
        QuickAddAction(kind: .habit, title: "Gewohnheit", systemImage: "checkmark.seal", tint: AboLifeColors.habits)
    ]
}

enum QuickAddPanel: Equatable {
    case generalMenu
    case training
    case expense
    case habit
    case weight
}

enum QuickAddRouting {
    static func panel(for kind: QuickAddKind) -> QuickAddPanel {
        switch kind {
        case .general:
            return .generalMenu
        case .workout:
            return .training
        case .expense:
            return .expense
        case .habit:
            return .habit
        case .weight:
            return .weight
        }
    }
}
