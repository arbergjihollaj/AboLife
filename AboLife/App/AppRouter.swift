import SwiftUI

enum AppSection: String, CaseIterable, Identifiable {
    case dashboard
    case calendar
    case nutrition
    case training
    case weight
    case finance
    case habits
    case statistics
    case weeklyReview

    var id: String { rawValue }

    var isHealthSection: Bool {
        switch self {
        case .nutrition, .training, .weight:
            return true
        default:
            return false
        }
    }

    var title: String {
        switch self {
        case .calendar:
            return "Kalender"
        case .dashboard:
            return "Dashboard"
        case .nutrition:
            return "Ernährung"
        case .training:
            return "Training"
        case .weight:
            return "Gewicht"
        case .finance:
            return "Finanzen"
        case .habits:
            return "Gewohnheiten"
        case .statistics:
            return "Statistiken"
        case .weeklyReview:
            return "Wochenreview"
        }
    }

    var systemImage: String {
        switch self {
        case .calendar:
            return "calendar"
        case .dashboard:
            return "gauge.with.dots.needle.67percent"
        case .nutrition:
            return "fork.knife"
        case .training:
            return "figure.strengthtraining.traditional"
        case .weight:
            return "scalemass"
        case .finance:
            return "eurosign.circle"
        case .habits:
            return "checkmark.seal"
        case .statistics:
            return "chart.bar.xaxis"
        case .weeklyReview:
            return "calendar.badge.clock"
        }
    }
}

struct AppRouter: View {
    @Environment(\.appDatabase) private var appDatabase
    @EnvironmentObject private var navigation: AppNavigationCoordinator
    @State private var isHealthExpanded = false

    var body: some View {
        NavigationSplitView {
            ZStack {
                AboLifePremiumBackground()

                VStack(alignment: .leading, spacing: 18) {
                    sidebarHeader

                    List {
                        sidebarButton(.dashboard)
                        sidebarButton(.calendar)

                        healthCategory

                        if isHealthExpanded {
                            ForEach(AppSection.allCases.filter(\.isHealthSection)) { section in
                                sidebarButton(section)
                                    .padding(.leading, 12)
                            }
                        }

                        ForEach(AppSection.allCases.filter { $0 != .dashboard && $0 != .calendar && !$0.isHealthSection }) { section in
                            sidebarButton(section)
                        }
                    }
                    .scrollContentBackground(.hidden)
                    .listStyle(.sidebar)

                    Spacer(minLength: 18)

                    sidebarProfile
                }
                .padding(18)
            }
            .navigationSplitViewColumnWidth(min: 240, ideal: 250)
        } detail: {
            Group {
                switch navigation.selectedSection ?? .dashboard {
                case .calendar:
                    CalendarPlannerView(database: appDatabase)
                case .dashboard:
                    DashboardView(store: DashboardStore(database: appDatabase))
                case .nutrition:
                    NutritionView(database: appDatabase)
                case .training:
                    TrainingView(database: appDatabase)
                case .weight:
                    WeightView(database: appDatabase)
                case .finance:
                    FinanceView(database: appDatabase)
                case .habits:
                    HabitsView(database: appDatabase)
                case .statistics:
                    StatisticsView(database: appDatabase)
                case .weeklyReview:
                    WeeklyReviewView(database: appDatabase)
                }
            }
            .frame(minWidth: 860, minHeight: 640)
        }
        .onAppear {
            if navigation.selectedSection?.isHealthSection == true {
                isHealthExpanded = true
            }
        }
        .onChange(of: navigation.selectedSection) { _, section in
            if section?.isHealthSection == true {
                isHealthExpanded = true
            }
        }
    }

    private var healthCategory: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.16)) {
                isHealthExpanded.toggle()
            }
        } label: {
            sidebarLabel(
                title: "Gesundheit",
                systemImage: "heart",
                isSelected: navigation.selectedSection?.isHealthSection == true && !isHealthExpanded
            )
            .overlay(alignment: .trailing) {
                Image(systemName: isHealthExpanded ? "chevron.down" : "chevron.right")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(AboLifeColors.secondaryText)
                    .padding(.trailing, 10)
            }
            .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Gesundheit")
        .accessibilityValue(isHealthExpanded ? "Ausgeklappt" : "Eingeklappt")
        .selectionDisabled()
        .listRowInsets(EdgeInsets(top: 3, leading: 0, bottom: 3, trailing: 0))
        .listRowSeparator(.hidden)
        .listRowBackground(Color.clear)
    }

    private func sidebarButton(_ section: AppSection) -> some View {
        Button {
            navigation.select(section)
        } label: {
            sidebarRow(section)
                .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits((navigation.selectedSection ?? .dashboard) == section ? .isSelected : [])
        // The row already draws its own selection surface.
        .selectionDisabled()
        .listRowInsets(EdgeInsets(top: 3, leading: 0, bottom: 3, trailing: 0))
        .listRowSeparator(.hidden)
        .listRowBackground(Color.clear)
    }

    private func sidebarRow(_ section: AppSection) -> some View {
        let isSelected = (navigation.selectedSection ?? .dashboard) == section
        return sidebarLabel(title: section.title, systemImage: section.systemImage, isSelected: isSelected)
    }

    private func sidebarLabel(title: String, systemImage: String, isSelected: Bool) -> some View {
        return HStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(isSelected ? AboLifeColors.primaryText : AboLifeColors.secondaryText)
                .frame(width: 24)

            Text(title)
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
                    Text("AboLife 0.2")
                        .font(.system(size: 18, weight: .semibold, design: .rounded))
                        .foregroundStyle(AboLifeColors.primaryText)
                    Text("Daily cockpit")
                        .font(AboLifeTypography.caption)
                        .foregroundStyle(AboLifeColors.secondaryText)
                }
            }

            AboLifeGlassCapsule {
                Label("Lokal mit SQLite", systemImage: "internaldrive")
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
            .environmentObject(AppNavigationCoordinator())
    }
}
