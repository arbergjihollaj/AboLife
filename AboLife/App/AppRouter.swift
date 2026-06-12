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
            ZStack {
                AboLifePremiumBackground()

                VStack(alignment: .leading, spacing: 18) {
                    sidebarHeader

                    List(AppSection.allCases, selection: $selection) { section in
                        sidebarRow(section)
                            .tag(section)
                            .listRowInsets(EdgeInsets(top: 3, leading: 0, bottom: 3, trailing: 0))
                            .listRowSeparator(.hidden)
                            .listRowBackground(Color.clear)
                    }
                    .scrollContentBackground(.hidden)
                    .listStyle(.sidebar)

                    Spacer(minLength: 18)

                    sidebarProfile
                }
                .padding(18)
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

    private func sidebarRow(_ section: AppSection) -> some View {
        let isSelected = (selection ?? .dashboard) == section

        return HStack(spacing: 12) {
            Image(systemName: section.systemImage)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(isSelected ? AboLifeColors.primaryText : AboLifeColors.secondaryText)
                .frame(width: 24)

            Text(section.title)
                .font(.system(size: 14, weight: isSelected ? .semibold : .medium, design: .rounded))
                .foregroundStyle(isSelected ? AboLifeColors.primaryText : AboLifeColors.secondaryText)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 13)
        .frame(maxWidth: .infinity, minHeight: 42, alignment: .leading)
        .background {
            if isSelected {
                AboLifeLiquidGlassSurface(
                    shape: RoundedRectangle(cornerRadius: 14, style: .continuous),
                    tint: AboLifeColors.review.opacity(0.16),
                    isProminent: false,
                    isInteractive: true
                )
                    .overlay {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(AboLifeColors.sidebarSelectionGradient.opacity(0.46))
                            .blendMode(.screen)
                    }
                    .overlay {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .strokeBorder(AboLifeColors.glassStroke, lineWidth: 0.9)
                    }
                    .shadow(color: AboLifeColors.review.opacity(0.18), radius: 10, x: 0, y: 5)
            }
        }
    }

    private var sidebarHeader: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: "sparkles")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(AboLifeColors.review)
                    .frame(width: 32, height: 32)
                    .background(AboLifeColors.elevatedCardBackground, in: Circle())
                    .overlay {
                        Circle()
                            .strokeBorder(AboLifeColors.glassStrokeMuted, lineWidth: 1)
                    }

                VStack(alignment: .leading, spacing: 1) {
                    Text("AboLife")
                        .font(.system(size: 18, weight: .semibold, design: .rounded))
                        .foregroundStyle(AboLifeColors.primaryText)
                    Text("Daily cockpit")
                        .font(AboLifeTypography.caption)
                        .foregroundStyle(AboLifeColors.secondaryText)
                }
            }

            AboLifeGlassCapsule {
                Label("Phase 1.5 UI Mock", systemImage: "wand.and.stars")
                    .font(AboLifeTypography.micro)
                    .foregroundStyle(AboLifeColors.secondaryText)
            }
        }
        .padding(.bottom, 6)
    }

    private var sidebarProfile: some View {
        AboLifeCard {
            HStack(spacing: 12) {
                Text("A")
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(AboLifeColors.primaryText)
                    .frame(width: 34, height: 34)
                    .background(AboLifeColors.quietFill, in: Circle())
                    .overlay {
                        Circle()
                            .strokeBorder(AboLifeColors.glassStrokeMuted, lineWidth: 1)
                    }

                VStack(alignment: .leading, spacing: 2) {
                    Text("Arber")
                        .font(AboLifeTypography.cardTitle)
                        .foregroundStyle(AboLifeColors.primaryText)
                    Text("AboLife lokal")
                        .font(AboLifeTypography.caption)
                        .foregroundStyle(AboLifeColors.secondaryText)
                }

                Spacer(minLength: 0)
            }
        }
    }
}

struct AppRouter_Previews: PreviewProvider {
    static var previews: some View {
        AppRouter()
    }
}
