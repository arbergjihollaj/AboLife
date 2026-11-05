import SwiftUI

enum AppSection: String, CaseIterable, Identifiable {
    case dashboard
    case calendar
    case news
    case training
    case weight
    case finance
    case habits
    case statistics
    case weeklyReview

    var id: String { rawValue }

    var isHealthSection: Bool {
        switch self {
        case .training, .weight:
            return true
        default:
            return false
        }
    }

    var title: String {
        switch self {
        case .news: return "Nachrichten"
        case .calendar:
            return "Kalender"
        case .dashboard:
            return "Dashboard"
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
        case .news: return "newspaper"
        case .calendar:
            return "calendar"
        case .dashboard:
            return "gauge.with.dots.needle.67percent"
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

/// Layout changes keep the content's semantic identity and existing feature stores.
struct AppRouter: View {
    @Environment(\.appDatabase) private var appDatabase
    @Environment(\.openSettings) private var openSettings
    @Environment(\.aboLifeStyle) private var style
    @EnvironmentObject private var ai: AIAssistantStore
    @EnvironmentObject private var navigation: AppNavigationCoordinator
    @StateObject private var reviewStore: WeeklyReviewStore

    private enum Slot: String, Identifiable {
        case navigation, content
        var id: String { rawValue }
    }
    init(database: AppDatabase? = nil) {
        _reviewStore = StateObject(wrappedValue: WeeklyReviewStore(database: database))
    }
    private var layout: AnyLayout {
        style.design == .bento ? AnyLayout(HStackLayout(spacing: 0)) : AnyLayout(VStackLayout(spacing: 0))
    }
    private var slots: [Slot] {
        style.design == .spatial ? [.content, .navigation] : [.navigation, .content]
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            layout {
                ForEach(slots) { slot in
                    switch slot {
                    case .navigation: designNavigation
                    case .content:
                        detail
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .frame(minWidth: 620, minHeight: 440)
                    }
                }
            }
        }
        .background(style.colors.pageBackground)
        .sheet(isPresented: $ai.showAssistant) { AIAssistantView(store: ai) }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("AboLife AI", systemImage: "bubble.left.and.text.bubble.right") {
                    ai.open(for: navigation.selectedSection ?? .dashboard)
                }
                .help("Bestehenden lokalen Assistenten öffnen")
            }
        }
    }

    private var header: some View {
        HStack(spacing: 14) {
            AboLifeBrandMark()
            Text("AboLife").font(.system(size: 20, weight: .semibold))
            if style.design == .fieldnotes {
                Text("Ein persönlicher Begleiter.").font(.callout).italic().foregroundStyle(.secondary)
            }
            Spacer(minLength: 4)
            Button("AboLife AI", systemImage: "bubble.left.and.text.bubble.right") {
                ai.open(for: navigation.selectedSection ?? .dashboard)
            }
            .accessibilityIdentifier("navigation.ai")
            Button("Einstellungen", systemImage: "slider.horizontal.3") { openSettings() }
                .labelStyle(.iconOnly)
                .help("Design, Widgets und Einstellungen")
        }
        .padding(.horizontal, 22).padding(.vertical, 14)
        .background(style.colors.cardBackground.opacity(style.design == .spatial ? 0.8 : 1))
    }

    @ViewBuilder
    private var designNavigation: some View {
        if style.design == .bento {
            ScrollView {
                VStack(spacing: 8) {
                    ForEach(AppSection.allCases) { section in navigationButton(section, stacked: true) }
                    Divider().padding(.vertical, 8)
                    Button {
                        ai.open(for: navigation.selectedSection ?? .dashboard)
                    } label: {
                        Label("AboLife AI", systemImage: "bubble.left.and.text.bubble.right")
                            .font(.caption).frame(maxWidth: .infinity)
                    }.buttonStyle(.plain).padding(8)
                }.padding(10)
            }
            .frame(width: 112)
            .background(style.colors.cardBackground)
        } else {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: style.design == .spatial ? 6 : 14) {
                    ForEach(AppSection.allCases) { section in
                        navigationButton(section, stacked: style.design == .spatial)
                    }
                }
                .padding(10)
            }
            .background(
                style.design == .spatial
                    ? AnyShapeStyle(.ultraThinMaterial) : AnyShapeStyle(style.colors.cardBackground)
            )
            .clipShape(RoundedRectangle(cornerRadius: style.design == .spatial ? 20 : 0))
            .padding(.horizontal, style.design == .spatial ? 24 : 0)
            .padding(.bottom, style.design == .spatial ? 12 : 0)
        }
    }

    private func navigationButton(_ section: AppSection, stacked: Bool) -> some View {
        let selected = (navigation.selectedSection ?? .dashboard) == section
        return Button {
            navigation.select(section)
        } label: {
            let layout = stacked ? AnyLayout(VStackLayout(spacing: 6)) : AnyLayout(HStackLayout(spacing: 8))
            layout {
                Image(systemName: section.systemImage).font(.system(size: 17))
                Text(section.title).font(.system(size: stacked ? 10 : 12, weight: selected ? .semibold : .regular))
            }
            .frame(minWidth: stacked ? 68 : 0, minHeight: stacked ? 42 : 28)
            .padding(7)
            .background(selected ? style.colors.subtleFill : .clear, in: RoundedRectangle(cornerRadius: 12))
            .foregroundStyle(selected ? style.colors.action : style.colors.secondaryText)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("navigation.\(section.rawValue)")
        .accessibilityAddTraits(selected ? .isSelected : [])
        .aboLifeMotion(value: selected, kind: .navigation)
    }

    @ViewBuilder
    private var detail: some View {
        switch navigation.selectedSection ?? .dashboard {
        case .news: NewsView(database: appDatabase) { articles in ai.open(for: .news, news: articles) }
        case .calendar: CalendarPlannerView(database: appDatabase)
        case .dashboard: DashboardView(store: DashboardStore(database: appDatabase))
        case .training: TrainingView(database: appDatabase)
        case .weight: WeightView(database: appDatabase)
        case .finance: FinanceView(database: appDatabase)
        case .habits: HabitsView(database: appDatabase)
        case .statistics: StatisticsView(database: appDatabase)
        case .weeklyReview: WeeklyReviewView(store: reviewStore)
        }
    }
}
