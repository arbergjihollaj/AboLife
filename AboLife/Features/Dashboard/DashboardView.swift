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
                        .fill(AboLifeColors.nutrition)
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
                metricCard(store.snapshot.calories, systemImage: "flame", tint: AboLifeColors.nutrition)
                    .frame(minWidth: 190, maxWidth: .infinity)
                metricCard(store.snapshot.protein, systemImage: "bolt.heart", tint: AboLifeColors.protein)
                    .frame(minWidth: 190, maxWidth: .infinity)
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
            metricCard(store.snapshot.calories, systemImage: "flame", tint: AboLifeColors.nutrition)
            metricCard(store.snapshot.protein, systemImage: "bolt.heart", tint: AboLifeColors.protein)
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
            metricCard(store.snapshot.calories, systemImage: "flame", tint: AboLifeColors.nutrition)
            metricCard(store.snapshot.protein, systemImage: "bolt.heart", tint: AboLifeColors.protein)
            trainingCard
            financeCard
            habitsCard
            activityCard
            weekCard
        }
    }

    private func metricCard(_ metric: ProgressMetric, systemImage: String, tint: Color) -> some View {
        AboLifeCard(minHeight: 154) {
            VStack(alignment: .leading, spacing: 8) {
                cardTitle(metric.title, systemImage: systemImage, tint: tint)

                metricValue(current: metric.current, target: metric.target, unit: metric.unit)

                MetricProgressView(progress: metric.progress, tint: tint)

                MiniTrendChart(values: metric.trend, tint: tint)

                Text(metric.message)
                    .font(AboLifeTypography.caption)
                    .foregroundStyle(AboLifeColors.secondaryText)
            }
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

                MetricProgressView(progress: store.snapshot.training.progress, tint: AboLifeColors.training)

                Spacer(minLength: 0)
            }
        }
    }

    private var financeCard: some View {
        AboLifeCard(minHeight: 154) {
            VStack(alignment: .leading, spacing: 8) {
                cardTitle(store.snapshot.finance.title, systemImage: "eurosign.circle", tint: AboLifeColors.finance)

                kpiValue("\(Int(store.snapshot.finance.remainingToday))", suffix: "EUR Tagesbudget")

                BudgetProgressBar(
                    spent: store.snapshot.finance.spentThisMonth,
                    budget: store.snapshot.finance.monthlyBudget
                )

                Text(store.snapshot.finance.message)
                    .font(AboLifeTypography.caption)
                    .foregroundStyle(AboLifeColors.secondaryText)
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

    private func metricValue(current: Double, target: Double, unit: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Text("\(Int(current))")
                .font(AboLifeTypography.metric)
                .monospacedDigit()
            Text("/ \(Int(target)) \(unit)")
                .font(AboLifeTypography.metricUnit)
                .foregroundStyle(AboLifeColors.secondaryText)
                .monospacedDigit()
        }
        .lineLimit(1)
        .minimumScaleFactor(0.85)
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
}

struct DashboardView_Previews: PreviewProvider {
    static var previews: some View {
        DashboardView(store: DashboardStore())
            .frame(width: 1000, height: 760)
    }
}
