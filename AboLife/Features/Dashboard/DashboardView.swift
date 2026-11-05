import SwiftUI

struct DashboardView: View {
    @Environment(\.aboLifeStyle) private var designStyle
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.aboLifeWidgets) private var widgets
    @State private var hasAppeared = false
    @EnvironmentObject private var navigation: AppNavigationCoordinator
    @EnvironmentObject private var ai: AIAssistantStore
    @StateObject var store: DashboardStore
    @State private var selectedQuickAddKind: QuickAddKind?

    var rendersOverviewOnly = false

    var body: some View {
        Group {
            if rendersOverviewOnly { overview } else { appBody }
        }
    }

    private var appBody: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header
                if let error = store.errorMessage {
                    AboLifeNotice(title: "Datenstand prüfen", message: error, retry: store.refreshFromPersistence)
                }
                overview
            }
            .aboLifePage()
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            FloatingQuickAddBar(actions: QuickAddAction.bottomDockActions) { kind in
                selectedQuickAddKind = kind
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity)
            .background(designStyle.colors.pageBackground)
        }
        .background {
            AboLifePremiumBackground()
        }
        .navigationTitle("")
        .onAppear {
            store.refreshFromPersistence()
            withAnimation(AboLifeMotion.animation(for: .navigation, reduceMotion: reduceMotion)) { hasAppeared = true }
        }
        .opacity(reduceMotion || hasAppeared ? 1 : 0)
        .task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(30))
                if !Task.isCancelled && selectedQuickAddKind == nil { store.refreshFromPersistence() }
            }
        }
        .sheet(item: $selectedQuickAddKind) { kind in
            QuickAddSheet(store: store, initialKind: kind)
        }
    }

    /// Shared dashboard composition; can also be rendered without a platform scroll view.
    @ViewBuilder
    var overview: some View {
        switch designStyle.design {
        case .spatial: spatialOverview
        case .bento:
            VStack(alignment: .leading, spacing: 16) {
                heroCard
                openTodayCard
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 280), alignment: .top)], spacing: 16) {
                    ForEach(widgets) { widget in dashboardWidget(widget) }
                }
            }
        case .fieldnotes:
            VStack(alignment: .leading, spacing: 24) {
                HStack(alignment: .top, spacing: 24) {
                    heroCopy
                    Spacer(minLength: 0)
                    heroRing.frame(width: 160)
                }
                openTodayCard
                financeCard
                habitsCard
                DisclosureGroup("Weitere Einblicke · Training und Woche") {
                    VStack(spacing: 16) { trainingCard; activityCard; weekCard }.padding(.top, 16)
                }
                .font(AboLifeTypography.sectionTitle)
            }
        }
    }

    private var spatialOverview: some View {
        VStack(spacing: 18) {
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .center, spacing: 18) {
                    VStack(spacing: 16) { financeCard; habitsCard }.frame(minWidth: 210)
                    VStack(spacing: 24) { heroRing; heroCopy }.frame(minWidth: 220, maxWidth: 300)
                    VStack(spacing: 16) { trainingCard; openTodayCard }.frame(minWidth: 210)
                }
                VStack(spacing: 16) { heroCard; openTodayCard; financeCard; trainingCard; habitsCard }
            }
            HStack(alignment: .top, spacing: 16) { activityCard; weekCard }
        }
    }

    @ViewBuilder
    private func dashboardWidget(_ widget: DashboardWidget) -> some View {
        switch widget {
        case .finance: financeCard
        case .training: trainingCard
        case .habits: habitsCard
        case .activity: activityCard
        case .week: weekCard
        }
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Heute")
                    .accessibilityIdentifier("page.dashboard")
                    .font(AboLifeTypography.dashboardTitle)
                    .foregroundStyle(designStyle.colors.primaryText)
                Text(store.snapshot.dateLine)
                    .font(AboLifeTypography.body)
                    .foregroundStyle(designStyle.colors.secondaryText)
            }

            Spacer()

            HStack(spacing: 8) {
                Circle()
                    .fill(designStyle.colors.accentGreen)
                    .frame(width: 6, height: 6)
                    .accessibilityHidden(true)
                Text("Lokal")
                    .font(AboLifeTypography.caption)
                    .foregroundStyle(designStyle.colors.secondaryText)
            }
            .padding(.trailing, 4)

            Button {
                ai.open(for: .dashboard)
            } label: {
                Label("AboLife AI", systemImage: "bubble.left.and.text.bubble.right")
                    .labelStyle(.iconOnly)
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
            .tint(designStyle.colors.secondaryText)
            .help("AboLife AI · Tagesassistent")
        }
    }

    private var heroCard: some View {
        AboLifeCard(isProminent: true) {
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .center, spacing: 32) {
                    heroCopy
                    Spacer(minLength: 0)
                    heroRing
                }

                VStack(alignment: .leading, spacing: 24) {
                    heroCopy
                    heroRing
                }
            }
        }
    }

    private var heroRing: some View {
        CoreRingView(
            progress: store.snapshot.coreProgress,
            lineWidth: 8,
            tint: designStyle.colors.review,
            showsScale: true
        )
        .frame(width: 160, height: 160)
    }

    private var heroCopy: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Tagesstand")
                .font(AboLifeTypography.cardTitle)
                .foregroundStyle(designStyle.colors.secondaryText)

            Text(store.snapshot.coreMessage)
                .font(AboLifeTypography.heroMessage)
                .foregroundStyle(designStyle.colors.primaryText)
                .fixedSize(horizontal: false, vertical: true)

            Text(store.snapshot.nextStep)
                .font(AboLifeTypography.body)
                .foregroundStyle(designStyle.colors.secondaryText)
                .fixedSize(horizontal: false, vertical: true)

            Rectangle()
                .fill(designStyle.colors.glassStrokeMuted)
                .frame(height: 1)
                .accessibilityHidden(true)

            weightStatusLine
        }
        .frame(maxWidth: 520, alignment: .leading)
    }

    private var weightStatusLine: some View {
        HStack(spacing: 8) {
            Image(systemName: "scalemass")
                .foregroundStyle(designStyle.colors.secondaryText)
                .accessibilityHidden(true)

            Text(store.snapshot.weight.valueText)
                .font(AboLifeTypography.caption.weight(.semibold))
                .foregroundStyle(designStyle.colors.primaryText)
                .monospacedDigit()

            Text(store.snapshot.weight.dateText)
                .font(AboLifeTypography.caption)
                .foregroundStyle(designStyle.colors.secondaryText)

            if let change = store.snapshot.weight.changeText {
                Text(change)
                    .font(AboLifeTypography.caption.weight(.semibold))
                    .foregroundStyle(change.hasPrefix("-") ? designStyle.colors.finance : designStyle.colors.habits)
                    .monospacedDigit()
            }
        }
        .lineLimit(1)
        .minimumScaleFactor(0.82)
    }

    private var openTodayCard: some View {
        AboLifeCard {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: hasOpenItems ? "checklist" : "checkmark.circle")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(hasOpenItems ? designStyle.colors.secondaryText : designStyle.colors.accentGreen)
                    .frame(width: 20)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Offene Punkte")
                        .font(AboLifeTypography.cardTitle)
                        .foregroundStyle(designStyle.colors.primaryText)

                    Text(store.snapshot.todayOpen.summary)
                        .font(AboLifeTypography.body)
                        .foregroundStyle(designStyle.colors.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private var trainingCard: some View {
        AboLifeCard(minHeight: 156) {
            VStack(alignment: .leading, spacing: 8) {
                cardTitle(store.snapshot.training.title, systemImage: "figure.strengthtraining.traditional")

                Text(store.snapshot.training.status)
                    .font(AboLifeTypography.metric)
                    .foregroundStyle(designStyle.colors.primaryText)

                Label(store.snapshot.training.weeklyProgress, systemImage: "calendar")
                    .font(AboLifeTypography.body)
                    .foregroundStyle(designStyle.colors.secondaryText)

                Text("Nächstes: \(store.snapshot.training.nextWorkout)")
                    .font(AboLifeTypography.micro)
                    .foregroundStyle(designStyle.colors.secondaryText)
                    .lineLimit(1)

                if let detail = store.snapshot.training.progressDetail {
                    Text(detail)
                        .font(AboLifeTypography.micro)
                        .foregroundStyle(designStyle.colors.tertiaryText)
                        .lineLimit(1)
                }

                MetricProgressView(progress: store.snapshot.training.progress, tint: designStyle.colors.training)

                Text(store.snapshot.training.calmMessage)
                    .font(AboLifeTypography.caption)
                    .foregroundStyle(designStyle.colors.secondaryText)
                    .lineLimit(2)

                Spacer(minLength: 0)
            }
        }
    }

    private var financeCard: some View {
        AboLifeCard(minHeight: 156) {
            VStack(alignment: .leading, spacing: 8) {
                cardTitle(store.snapshot.finance.title, systemImage: "eurosign.circle")

                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text("\(Int(store.snapshot.finance.remainingToday.rounded()))")
                        .aboLifeNumericTransition(value: store.snapshot.finance.remainingToday)
                        .font(AboLifeTypography.metric)
                        .foregroundStyle(designStyle.colors.primaryText)
                        .monospacedDigit()
                    Text("\(store.currency) heute frei")
                        .font(AboLifeTypography.metricUnit)
                        .foregroundStyle(designStyle.colors.secondaryText)
                        .lineLimit(1)
                        .minimumScaleFactor(0.78)
                }

                BudgetProgressBar(
                    spent: store.snapshot.finance.spentThisMonth,
                    budget: store.snapshot.finance.monthlyBudget,
                    currency: store.currency
                )

                HStack(spacing: 4) {
                    Text("Monat übrig")
                        .foregroundStyle(designStyle.colors.secondaryText)
                    Text("\(Int(financeMonthRemaining.rounded())) \(store.currency)")
                        .fontWeight(.semibold)
                        .foregroundStyle(designStyle.colors.primaryText)
                        .monospacedDigit()
                }
                .font(AboLifeTypography.caption)

                Text(financeStatusSentence)
                    .font(AboLifeTypography.caption)
                    .foregroundStyle(designStyle.colors.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var habitsCard: some View {
        AboLifeCard(minHeight: 156) {
            VStack(alignment: .leading, spacing: 8) {
                cardTitle(store.snapshot.habits.title, systemImage: "checkmark.seal")

                kpiValue("\(Int((store.snapshot.habits.progress * 100).rounded()))", suffix: "% heute")

                MetricProgressView(progress: store.snapshot.habits.progress, tint: designStyle.colors.habits)

                VStack(alignment: .leading, spacing: 4) {
                    ForEach(store.snapshot.habits.items.prefix(5)) { habit in
                        HStack(spacing: 6) {
                            Circle()
                                .fill(habit.progress >= 1 ? designStyle.colors.habits : designStyle.colors.glassStrokeMuted)
                                .frame(width: 6, height: 6)

                            Text(habit.title)
                                .font(AboLifeTypography.micro.weight(.medium))
                                .foregroundStyle(designStyle.colors.primaryText)
                                .lineLimit(1)

                            Spacer(minLength: 4)

                            Text(habit.displayText)
                                .font(AboLifeTypography.micro)
                                .foregroundStyle(designStyle.colors.secondaryText)
                                .lineLimit(1)
                        }
                    }
                }

                Text(store.snapshot.habits.message)
                    .font(AboLifeTypography.caption)
                    .foregroundStyle(designStyle.colors.secondaryText)
            }
        }
    }

    private var weekCard: some View {
        AboLifeCard(minHeight: 156) {
            VStack(alignment: .leading, spacing: 8) {
                VStack(alignment: .leading, spacing: 4) {
                    cardTitle(store.snapshot.week.title, systemImage: "calendar.badge.clock")
                    Text(store.snapshot.week.message)
                        .font(AboLifeTypography.caption)
                        .foregroundStyle(designStyle.colors.secondaryText)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }

                WeeklyStatusStrip(days: store.snapshot.week.days.map(\.weeklyStatusItem))
            }
        }
    }

    private var activityCard: some View {
        AboLifeCard(minHeight: 156) {
            VStack(alignment: .leading, spacing: 8) {
                cardTitle("Letzte Aktivitäten", systemImage: "clock.arrow.circlepath")

                if store.snapshot.recentActions.isEmpty {
                    Text("Hier erscheinen neue Einträge für Training, Ausgaben und Gewohnheiten.")
                        .font(AboLifeTypography.caption)
                        .foregroundStyle(designStyle.colors.secondaryText)
                } else {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(store.snapshot.recentActions.prefix(3)) { action in
                            VStack(alignment: .leading, spacing: 2) {
                                Text(action.title)
                                    .font(AboLifeTypography.caption.weight(.semibold))
                                    .foregroundStyle(designStyle.colors.primaryText)
                                    .lineLimit(1)

                                Text(action.detail)
                                    .font(AboLifeTypography.micro)
                                    .foregroundStyle(designStyle.colors.secondaryText)
                                    .lineLimit(1)
                            }
                        }
                    }
                }

                Spacer(minLength: 0)
            }
        }
    }

    private func kpiValue(_ value: String, suffix: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Text(value)
                .aboLifeNumericTransition(value: value)
                .font(AboLifeTypography.metric)
                .monospacedDigit()
            Text(suffix)
                .font(AboLifeTypography.metricUnit)
                .foregroundStyle(designStyle.colors.secondaryText)
                .monospacedDigit()
        }
        .lineLimit(1)
        .minimumScaleFactor(0.82)
    }

    private func cardTitle(_ title: String, systemImage: String) -> some View {
        HStack {
            Label {
            Text(title)
                .font(AboLifeTypography.cardTitle)
                .foregroundStyle(designStyle.colors.primaryText)
        } icon: {
            Image(systemName: systemImage)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(designStyle.colors.secondaryText)
                .accessibilityHidden(true)
            }
            Spacer(minLength: 0)
            if let section = destination(for: systemImage) {
                Button("\(section.title) öffnen", systemImage: "chevron.right") {
                    navigation.select(section)
                }
                .labelStyle(.iconOnly)
                .buttonStyle(.plain)
                .foregroundStyle(designStyle.colors.secondaryText)
                .help("\(section.title) öffnen")
            }
        }
    }

    private func destination(for symbol: String) -> AppSection? {
        switch symbol {
        case "figure.strengthtraining.traditional": return .training
        case "eurosign.circle": return .finance
        case "checkmark.seal": return .habits
        case "calendar.badge.clock": return .weeklyReview
        default: return nil
        }
    }

    private var financeMonthRemaining: Double {
        max(store.snapshot.finance.monthlyBudget - store.snapshot.finance.spentThisMonth, 0)
    }

    private var financeProjectedSpend: Double {
        let spent = store.snapshot.finance.spentThisMonth
        guard spent > 0 else { return 0 }
        let calendar = Calendar.current
        let today = Date()
        let elapsedDay = max(calendar.component(.day, from: today), 1)
        let range = calendar.range(of: .day, in: .month, for: today)
        let daysInMonth = max(range?.count ?? elapsedDay, elapsedDay)
        return spent / Double(elapsedDay) * Double(daysInMonth)
    }

    private var financeStatusSentence: String {
        if store.snapshot.finance.spentThisMonth > store.snapshot.finance.monthlyBudget {
            let difference = store.snapshot.finance.spentThisMonth - store.snapshot.finance.monthlyBudget
            return "\(Int(difference.rounded())) \(store.currency) über dem Monatsbudget."
        }
        if store.snapshot.finance.spentThisMonth <= 0 {
            return "Diesen Monat sind noch keine Ausgaben erfasst."
        }
        if financeProjectedSpend > store.snapshot.finance.monthlyBudget {
            return "Bei diesem Tempo liegen die Ausgaben über dem Monatsbudget."
        }
        if store.snapshot.finance.remainingToday > 0 {
            return "Deine Ausgaben liegen im Monatsbudget."
        }
        return store.snapshot.finance.message
    }

    private var hasOpenItems: Bool {
        let status = store.snapshot.todayOpen
        return status.training == .open || !status.openHabitTitles.isEmpty
    }
}

struct DashboardView_Previews: PreviewProvider {
    static var previews: some View {
        DashboardView(store: DashboardStore())
            .environmentObject(AIAssistantStore.previewStore())
            .environmentObject(AppNavigationCoordinator())
            .frame(width: 1000, height: 760)
    }
}
