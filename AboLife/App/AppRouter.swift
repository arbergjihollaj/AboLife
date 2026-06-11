import SwiftUI

enum AppSection: String, CaseIterable, Identifiable {
    case dashboard
    case nutrition
    case training
    case finance
    case habits
    case weeklyReview
    case settings

    var id: String { rawValue }

    var title: String {
        switch self {
        case .dashboard:
            return "Dashboard"
        case .nutrition:
            return "Ernährung"
        case .training:
            return "Training"
        case .finance:
            return "Finanzen"
        case .habits:
            return "Gewohnheiten"
        case .weeklyReview:
            return "Wochenreview"
        case .settings:
            return "Einstellungen"
        }
    }

    var systemImage: String {
        switch self {
        case .dashboard:
            return "gauge.with.dots.needle.67percent"
        case .nutrition:
            return "fork.knife"
        case .training:
            return "figure.strengthtraining.traditional"
        case .finance:
            return "eurosign.circle"
        case .habits:
            return "checkmark.seal"
        case .weeklyReview:
            return "calendar.badge.clock"
        case .settings:
            return "gearshape"
        }
    }
}

struct AppRouter: View {
    @State private var selection: AppSection? = .dashboard

    var body: some View {
        NavigationSplitView {
            List(AppSection.allCases, selection: $selection) { section in
                Label(section.title, systemImage: section.systemImage)
                    .tag(section)
            }
            .navigationSplitViewColumnWidth(min: 210, ideal: 230)
        } detail: {
            Group {
                switch selection ?? .dashboard {
                case .dashboard:
                    DashboardView(store: DashboardStore())
                case .nutrition:
                    NutritionPlaceholderView()
                case .training:
                    TrainingPlaceholderView()
                case .finance:
                    FinancePlaceholderView()
                case .habits:
                    HabitsPlaceholderView()
                case .weeklyReview:
                    WeeklyReviewPlaceholderView()
                case .settings:
                    SettingsPlaceholderView()
                }
            }
            .frame(minWidth: 860, minHeight: 640)
        }
    }
}

struct AppRouter_Previews: PreviewProvider {
    static var previews: some View {
        AppRouter()
    }
}
