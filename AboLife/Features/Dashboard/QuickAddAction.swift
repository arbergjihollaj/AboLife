import SwiftUI

enum QuickAddKind: String, Identifiable, CaseIterable {
    case general
    case meal
    case workout
    case expense
    case habit
    case weight
    case note

    var id: String { rawValue }
}

struct QuickAddAction: Identifiable {
    let kind: QuickAddKind
    let title: String
    let systemImage: String
    let tint: Color

    var id: QuickAddKind { kind }

    static let dashboardActions: [QuickAddAction] = [
        QuickAddAction(kind: .meal, title: "Mahlzeit", systemImage: "fork.knife", tint: AboLifeColors.nutrition),
        QuickAddAction(kind: .workout, title: "Training", systemImage: "figure.strengthtraining.traditional", tint: AboLifeColors.training),
        QuickAddAction(kind: .expense, title: "Ausgabe", systemImage: "eurosign.circle", tint: AboLifeColors.finance),
        QuickAddAction(kind: .weight, title: "Gewicht", systemImage: "scalemass", tint: AboLifeColors.review),
        QuickAddAction(kind: .habit, title: "Gewohnheit", systemImage: "checkmark.seal", tint: AboLifeColors.habits),
        QuickAddAction(kind: .note, title: "Notiz", systemImage: "note.text", tint: AboLifeColors.protein)
    ]

    static let bottomDockActions: [QuickAddAction] = [
        QuickAddAction(kind: .meal, title: "Mahlzeit", systemImage: "fork.knife", tint: AboLifeColors.nutrition),
        QuickAddAction(kind: .workout, title: "Training", systemImage: "figure.strengthtraining.traditional", tint: AboLifeColors.training),
        QuickAddAction(kind: .expense, title: "Ausgabe", systemImage: "eurosign.circle", tint: AboLifeColors.finance),
        QuickAddAction(kind: .habit, title: "Gewohnheit", systemImage: "checkmark.seal", tint: AboLifeColors.habits)
    ]
}

enum QuickAddPanel: Equatable {
    case generalMenu
    case meal
    case training
    case expense
    case habit
    case weight
    case note
}

enum QuickAddRouting {
    static func panel(for kind: QuickAddKind) -> QuickAddPanel {
        switch kind {
        case .general:
            return .generalMenu
        case .meal:
            return .meal
        case .workout:
            return .training
        case .expense:
            return .expense
        case .habit:
            return .habit
        case .weight:
            return .weight
        case .note:
            return .note
        }
    }
}
