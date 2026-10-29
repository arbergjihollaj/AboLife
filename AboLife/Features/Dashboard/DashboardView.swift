import SwiftUI

struct DashboardView: View {
    @StateObject var store: DashboardStore
    @State private var selectedQuickAddKind: QuickAddKind?

    private let twoColumnGrid = [
        GridItem(.flexible(minimum: 220), spacing: 12),
        GridItem(.flexible(minimum: 220), spacing: 12)
    ]

    var body: some View {
        ZStack(alignment: .bottom) {
            AboLifePremiumBackground()

            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    header
                    heroCard
                    openTodayCard

                    dashboardGrid
                }
                .padding(22)
                .padding(.bottom, 86)
            }

            FloatingQuickAddBar(actions: quickAddActions) { kind in
                selectedQuickAddKind = kind
            }
            .padding(.horizontal, 22)
            .padding(.bottom, 18)
        }
        .navigationTitle("")
        .onAppear {
            store.refreshFromPersistence()
        }
        .task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(30))
                if !Task.isCancelled && selectedQuickAddKind == nil { store.refreshFromPersistence() }
            }
        }
        .sheet(item: $selectedQuickAddKind) { kind in
            QuickAddPlaceholderSheet(store: store, initialKind: kind)
        }
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text(store.snapshot.greeting)
                    .font(AboLifeTypography.dashboardTitle)
                    .foregroundStyle(AboLifeColors.primaryText)
                Text(store.snapshot.dateLine)
                    .font(AboLifeTypography.body)
                    .foregroundStyle(AboLifeColors.secondaryText)
            }

            Spacer()

            AboLifeGlassCapsule {
                HStack(spacing: 8) {
                    Circle()
                        .fill(AboLifeColors.accentGreen)
                        .frame(width: 7, height: 7)
                    Text("Lokal")
                        .font(AboLifeTypography.caption)
                        .foregroundStyle(AboLifeColors.secondaryText)
                }
            }

            Button {
                selectedQuickAddKind = .general
            } label: {
                Label("Quick Add", systemImage: "plus.circle.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(AboLifeColors.primaryText)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.regular)
            .tint(AboLifeColors.review)
        }
    }

    private var heroCard: some View {
        AboLifeCard(isProminent: true) {
            ViewThatFits(in: .horizontal) {
                heroContent(isCompact: false)
                heroContent(isCompact: true)
            }
        }
    }

    private func heroContent(isCompact: Bool) -> some View {
        Group {
            if isCompact {
                VStack(alignment: .leading, spacing: 16) {
                    heroRing(size: 138, lineWidth: 12)
                    heroCopy
                }
            } else {
                HStack(alignment: .center, spacing: 24) {
                    heroRing(size: 166, lineWidth: 14)
                    heroCopy
                    Spacer(minLength: 0)
                }
            }
        }
    }

    private func heroRing(size: CGFloat, lineWidth: CGFloat) -> some View {
        CoreRingView(
            progress: store.snapshot.coreProgress,
            lineWidth: lineWidth,
            tint: AboLifeColors.review
        )
        .frame(width: size, height: size)
    }

    private var heroCopy: some View {
        VStack(alignment: .leading, spacing: 11) {
            HStack(spacing: 10) {
                cardTitle("Daily Core", systemImage: "circle.hexagongrid.fill", tint: AboLifeColors.review)

                AboLifeGlassCapsule {
                    Text("\(Int(store.snapshot.coreProgress * 100))% stabil")
                        .font(AboLifeTypography.micro)
                        .foregroundStyle(AboLifeColors.review)
                        .monospacedDigit()
                }
            }

            Text(store.snapshot.coreMessage)
                .font(AboLifeTypography.heroMessage)
                .foregroundStyle(AboLifeColors.primaryText)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: 620, alignment: .leading)

            Text(store.snapshot.nextStep)
                .font(AboLifeTypography.body)
                .foregroundStyle(AboLifeColors.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: 620, alignment: .leading)

            PremiumProgressBar(progress: store.snapshot.coreProgress, tint: AboLifeColors.review, height: 7)
                .frame(maxWidth: 420)

            weightStatusLine
        }
    }

    private var weightStatusLine: some View {
        HStack(spacing: 9) {
            Image(systemName: "scalemass")
                .foregroundStyle(AboLifeColors.review)

            Text(store.snapshot.weight.valueText)
                .font(AboLifeTypography.caption.weight(.semibold))
                .foregroundStyle(AboLifeColors.primaryText)
                .monospacedDigit()

            Text(store.snapshot.weight.dateText)
                .font(AboLifeTypography.caption)
                .foregroundStyle(AboLifeColors.secondaryText)

            if let change = store.snapshot.weight.changeText {
                Text(change)
                    .font(AboLifeTypography.caption.weight(.semibold))
                    .foregroundStyle(change.hasPrefix("-") ? AboLifeColors.finance : AboLifeColors.habits)
                    .monospacedDigit()
            }
        }
        .lineLimit(1)
        .minimumScaleFactor(0.82)
    }

    private var quickAddActions: [QuickAddAction] {
        QuickAddAction.bottomDockActions
    }

    private var openTodayCard: some View {
        AboLifeCard {
            HStack(alignment: .top, spacing: 14) {
                Image(systemName: hasOpenItems ? "moon.stars.fill" : "checkmark.circle.fill")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(hasOpenItems ? AboLifeColors.review : AboLifeColors.positive)
                    .frame(width: 34, height: 34)
                    .background(AboLifeColors.quietFill, in: Circle())

                VStack(alignment: .leading, spacing: 5) {
                    Text("Heute noch offen")
                        .font(AboLifeTypography.cardTitle)
                        .foregroundStyle(AboLifeColors.primaryText)

                    Text(store.snapshot.todayOpen.summary)
                        .font(AboLifeTypography.body)
                        .foregroundStyle(AboLifeColors.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 12)

                if store.state.dailyBudgetRemaining > 0 {
                    AboLifeGlassCapsule {
                        Label(
                            "\(Int(store.state.dailyBudgetRemaining.rounded())) EUR Tagesbudget",
                            systemImage: "wallet.pass"
                        )
                        .font(AboLifeTypography.micro)
                        .foregroundStyle(AboLifeColors.finance)
                        .monospacedDigit()
                    }
                }
            }
        }
    }

    private var dashboardGrid: some View {
        ViewThatFits(in: .horizontal) {
            wideDashboardGrid
            mediumDashboardGrid
            compactDashboardGrid
        }
    }

    private var wideDashboardGrid: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                trainingCard
                    .frame(minWidth: 190, maxWidth: .infinity)
                financeCard
                    .frame(minWidth: 190, maxWidth: .infinity)
            }

            HStack(alignment: .top, spacing: 12) {
                habitsCard
                    .frame(minWidth: 230, maxWidth: .infinity)
                activityCard
                    .frame(minWidth: 230, maxWidth: .infinity)
                weekCard
                    .frame(minWidth: 300, maxWidth: .infinity)
            }
        }
    }

    private var mediumDashboardGrid: some View {
        LazyVGrid(columns: twoColumnGrid, alignment: .leading, spacing: 12) {
            trainingCard
            financeCard
            habitsCard
            activityCard
            weekCard
        }
        .frame(minWidth: 452)
    }

    private var compactDashboardGrid: some View {
        VStack(alignment: .leading, spacing: 12) {
            trainingCard
            financeCard
            habitsCard
            activityCard
            weekCard
        }
    }

    private var trainingCard: some View {
        AboLifeCard(minHeight: 154) {
            VStack(alignment: .leading, spacing: 8) {
                cardTitle(store.snapshot.training.title, systemImage: "figure.strengthtraining.traditional", tint: AboLifeColors.training)

                Text(store.snapshot.training.status)
                    .font(AboLifeTypography.metric)
                    .foregroundStyle(AboLifeColors.primaryText)

                Label(store.snapshot.training.weeklyProgress, systemImage: "calendar")
                    .font(AboLifeTypography.body)
                    .foregroundStyle(AboLifeColors.secondaryText)

                Text("Nächstes: \(store.snapshot.training.nextWorkout)")
                    .font(AboLifeTypography.micro)
                    .foregroundStyle(AboLifeColors.secondaryText)
                    .lineLimit(1)

                if let detail = store.snapshot.training.progressDetail {
                    Text(detail)
                        .font(AboLifeTypography.micro)
                        .foregroundStyle(AboLifeColors.tertiaryText)
                        .lineLimit(1)
                }

                MetricProgressView(progress: store.snapshot.training.progress, tint: AboLifeColors.training)

                Text(store.snapshot.training.calmMessage)
                    .font(AboLifeTypography.caption)
                    .foregroundStyle(AboLifeColors.secondaryText)
                    .lineLimit(2)

                Spacer(minLength: 0)
            }
        }
    }

    private var financeCard: some View {
        AboLifeCard(minHeight: 154) {
            VStack(alignment: .leading, spacing: 9) {
                cardTitle(store.snapshot.finance.title, systemImage: "eurosign.circle", tint: AboLifeColors.finance)

                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text("\(Int(store.snapshot.finance.remainingToday.rounded()))")
                        .font(AboLifeTypography.metric)
                        .foregroundStyle(AboLifeColors.primaryText)
                        .monospacedDigit()
                    Text("EUR heute frei")
                        .font(AboLifeTypography.metricUnit)
                        .foregroundStyle(AboLifeColors.secondaryText)
                        .lineLimit(1)
                        .minimumScaleFactor(0.78)
                }

                BudgetProgressBar(
                    spent: store.snapshot.finance.spentThisMonth,
                    budget: store.snapshot.finance.monthlyBudget
                )

                HStack(spacing: 7) {
                    miniFinancePill(
                        "Monat",
                        "\(Int(financeMonthRemaining.rounded())) EUR",
                        AboLifeColors.review
                    )
                    miniFinancePill(
                        "Ausgaben",
                        "\(Int(store.snapshot.finance.spentThisMonth.rounded())) EUR",
                        AboLifeColors.finance
                    )
                }

                Text(financeStatusSentence)
                    .font(AboLifeTypography.caption)
                    .foregroundStyle(AboLifeColors.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var habitsCard: some View {
        AboLifeCard(minHeight: 154) {
            VStack(alignment: .leading, spacing: 8) {
                cardTitle(store.snapshot.habits.title, systemImage: "checkmark.seal", tint: AboLifeColors.habits)

                kpiValue("\(Int((store.snapshot.habits.progress * 100).rounded()))", suffix: "% heute")

                MetricProgressView(progress: store.snapshot.habits.progress, tint: AboLifeColors.habits)

                VStack(alignment: .leading, spacing: 5) {
                    ForEach(store.snapshot.habits.items.prefix(5)) { habit in
                        HStack(spacing: 6) {
                            Circle()
                                .fill(habit.progress >= 1 ? AboLifeColors.habits : AboLifeColors.glassStrokeMuted)
                                .frame(width: 6, height: 6)

                            Text(habit.title)
                                .font(AboLifeTypography.micro.weight(.medium))
                                .foregroundStyle(AboLifeColors.primaryText)
                                .lineLimit(1)

                            Spacer(minLength: 4)

                            Text(habit.displayText)
                                .font(AboLifeTypography.micro)
                                .foregroundStyle(AboLifeColors.secondaryText)
                                .lineLimit(1)
                        }
                    }
                }

                Text(store.snapshot.habits.message)
                    .font(AboLifeTypography.caption)
                    .foregroundStyle(AboLifeColors.secondaryText)
            }
        }
    }

    private var weekCard: some View {
        AboLifeCard(minHeight: 154) {
            VStack(alignment: .leading, spacing: 10) {
                VStack(alignment: .leading, spacing: 5) {
                    cardTitle(store.snapshot.week.title, systemImage: "calendar.badge.clock", tint: AboLifeColors.review)
                    Text(store.snapshot.week.message)
                        .font(AboLifeTypography.caption)
                        .foregroundStyle(AboLifeColors.secondaryText)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }

                WeeklyStatusStrip(days: store.snapshot.week.days.map(\.weeklyStatusItem))
            }
        }
    }

    private var activityCard: some View {
        AboLifeCard(minHeight: 154) {
            VStack(alignment: .leading, spacing: 9) {
                cardTitle("Recent Activity", systemImage: "clock.arrow.circlepath", tint: AboLifeColors.review)

                if store.snapshot.recentActions.isEmpty {
                    Text("Noch keine Aktion erfasst.")
                        .font(AboLifeTypography.caption)
                        .foregroundStyle(AboLifeColors.secondaryText)
                } else {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(store.snapshot.recentActions.prefix(3)) { action in
                            VStack(alignment: .leading, spacing: 2) {
                                Text(action.title)
                                    .font(AboLifeTypography.caption.weight(.semibold))
                                    .foregroundStyle(AboLifeColors.primaryText)
                                    .lineLimit(1)

                                Text(action.detail)
                                    .font(AboLifeTypography.micro)
                                    .foregroundStyle(AboLifeColors.secondaryText)
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
                .font(AboLifeTypography.metric)
                .monospacedDigit()
            Text(suffix)
                .font(AboLifeTypography.metricUnit)
                .foregroundStyle(AboLifeColors.secondaryText)
                .monospacedDigit()
        }
        .lineLimit(1)
        .minimumScaleFactor(0.82)
    }

    private func cardTitle(_ title: String, systemImage: String, tint: Color) -> some View {
        Label {
            Text(title)
                .font(AboLifeTypography.cardTitle)
                .foregroundStyle(AboLifeColors.primaryText)
        } icon: {
            Image(systemName: systemImage)
                .foregroundStyle(tint)
        }
    }

    private func miniFinancePill(_ title: String, _ value: String, _ tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(title)
                .font(AboLifeTypography.micro)
                .foregroundStyle(AboLifeColors.secondaryText)
            Text(value)
                .font(AboLifeTypography.micro.weight(.semibold))
                .foregroundStyle(tint)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.78)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AboLifeColors.quietFill, in: RoundedRectangle(cornerRadius: 7, style: .continuous))
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
        if store.snapshot.finance.spentThisMonth <= 0 {
            return "Noch keine Monatsausgaben. Das Budget ist ruhig bereit."
        }
        if financeProjectedSpend > store.snapshot.finance.monthlyBudget {
            return "Die Prognose liegt leicht über dem Monatsbudget."
        }
        if store.snapshot.finance.remainingToday > 0 {
            return "Du bist aktuell im Budget. Heute sind noch ca. \(Int(store.snapshot.finance.remainingToday.rounded())) EUR frei."
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
            .frame(width: 1000, height: 760)
    }
}
