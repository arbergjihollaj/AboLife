import SwiftUI

struct DashboardView: View {
    @StateObject var store: DashboardStore
    @State private var showsQuickAdd = false

    private let columns = [
        GridItem(.flexible(minimum: 260), spacing: 16),
        GridItem(.flexible(minimum: 260), spacing: 16)
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                header
                heroCard

                LazyVGrid(columns: columns, alignment: .leading, spacing: 16) {
                    metricCard(store.snapshot.calories, tint: AboLifeColors.nutrition)
                    metricCard(store.snapshot.protein, tint: AboLifeColors.protein)
                    trainingCard
                    financeCard
                    habitsCard
                    weekCard
                }
            }
            .padding(28)
        }
        .background(AboLifeColors.pageBackground)
        .navigationTitle("Dashboard")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showsQuickAdd = true
                } label: {
                    Label("Quick Add", systemImage: "plus.circle.fill")
                }
            }
        }
        .sheet(isPresented: $showsQuickAdd) {
            QuickAddPlaceholderSheet()
        }
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 4) {
                Text(store.snapshot.greeting)
                    .font(AboLifeTypography.dashboardTitle)
                Text(store.snapshot.dateLine)
                    .font(AboLifeTypography.body)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button {
                showsQuickAdd = true
            } label: {
                Label("Quick Add", systemImage: "plus")
                    .font(.system(size: 14, weight: .semibold))
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
    }

    private var heroCard: some View {
        AboLifeCard {
            HStack(spacing: 28) {
                CoreRingView(
                    progress: store.snapshot.coreProgress,
                    lineWidth: 16,
                    tint: AboLifeColors.review
                )
                .frame(width: 190, height: 190)

                VStack(alignment: .leading, spacing: 14) {
                    Text("Daily Core")
                        .font(AboLifeTypography.sectionTitle)
                    Text(store.snapshot.coreMessage)
                        .font(.system(size: 22, weight: .medium))
                        .foregroundStyle(.primary)
                        .fixedSize(horizontal: false, vertical: true)
                    Text("Nächster sinnvoller Schritt: Training einplanen oder proteinreiche Mahlzeit erfassen.")
                        .font(AboLifeTypography.body)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)
            }
        }
    }

    private func metricCard(_ metric: ProgressMetric, tint: Color) -> some View {
        AboLifeCard {
            VStack(alignment: .leading, spacing: 14) {
                cardTitle(metric.title, systemImage: metric.title == "Kalorien" ? "flame" : "bolt.heart", tint: tint)

                Text(metric.valueText)
                    .font(AboLifeTypography.metric)
                    .monospacedDigit()

                MetricProgressView(progress: metric.progress, tint: tint)

                MiniTrendChart(values: metric.trend, tint: tint)

                Text(metric.message)
                    .font(AboLifeTypography.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var trainingCard: some View {
        AboLifeCard {
            VStack(alignment: .leading, spacing: 14) {
                cardTitle(store.snapshot.training.title, systemImage: "figure.strengthtraining.traditional", tint: AboLifeColors.training)

                Text(store.snapshot.training.status)
                    .font(AboLifeTypography.metric)

                Label(store.snapshot.training.weeklyProgress, systemImage: "calendar")
                    .font(AboLifeTypography.body)
                    .foregroundStyle(.secondary)

                MetricProgressView(progress: 2.0 / 3.0, tint: AboLifeColors.training)
            }
        }
    }

    private var financeCard: some View {
        AboLifeCard {
            VStack(alignment: .leading, spacing: 14) {
                cardTitle(store.snapshot.finance.title, systemImage: "eurosign.circle", tint: AboLifeColors.finance)

                Text("\(Int(store.snapshot.finance.remainingToday)) EUR Tagesbudget")
                    .font(AboLifeTypography.metric)
                    .monospacedDigit()

                BudgetProgressBar(
                    spent: store.snapshot.finance.spentThisMonth,
                    budget: store.snapshot.finance.monthlyBudget
                )

                Text(store.snapshot.finance.message)
                    .font(AboLifeTypography.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var habitsCard: some View {
        AboLifeCard {
            VStack(alignment: .leading, spacing: 14) {
                cardTitle(store.snapshot.habits.title, systemImage: "checkmark.seal", tint: AboLifeColors.habits)

                Text(store.snapshot.habits.valueText)
                    .font(AboLifeTypography.metric)
                    .monospacedDigit()

                MetricProgressView(progress: store.snapshot.habits.progress, tint: AboLifeColors.habits)

                Text(store.snapshot.habits.message)
                    .font(AboLifeTypography.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var weekCard: some View {
        AboLifeCard {
            VStack(alignment: .leading, spacing: 16) {
                cardTitle(store.snapshot.week.title, systemImage: "calendar.badge.clock", tint: AboLifeColors.review)

                WeeklyStatusStrip(days: store.snapshot.week.days)

                Text(store.snapshot.week.message)
                    .font(AboLifeTypography.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func cardTitle(_ title: String, systemImage: String, tint: Color) -> some View {
        Label {
            Text(title)
                .font(AboLifeTypography.cardTitle)
                .foregroundStyle(.primary)
        } icon: {
            Image(systemName: systemImage)
                .foregroundStyle(tint)
        }
    }
}

private struct QuickAddPlaceholderSheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                Text("Quick Add")
                    .font(AboLifeTypography.dashboardTitle)
                Spacer()
                Button {
                    dismiss()
                } label: {
                    Label("Schließen", systemImage: "xmark.circle.fill")
                        .labelStyle(.iconOnly)
                }
                .buttonStyle(.plain)
            }

            Text("Phase 1 zeigt hier nur die spätere Erfassung für Mahlzeit, Training, Ausgabe, Gewicht, Habit und Notiz.")
                .font(AboLifeTypography.body)
                .foregroundStyle(.secondary)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                quickAddTile("Mahlzeit", systemImage: "fork.knife")
                quickAddTile("Training", systemImage: "figure.strengthtraining.traditional")
                quickAddTile("Ausgabe", systemImage: "eurosign.circle")
                quickAddTile("Gewicht", systemImage: "scalemass")
                quickAddTile("Habit", systemImage: "checkmark.seal")
                quickAddTile("Notiz", systemImage: "note.text")
            }
        }
        .padding(24)
        .frame(width: 460)
        .background(AboLifeColors.pageBackground)
    }

    private func quickAddTile(_ title: String, systemImage: String) -> some View {
        Button {} label: {
            Label(title, systemImage: systemImage)
                .frame(maxWidth: .infinity, minHeight: 52)
        }
        .buttonStyle(.bordered)
    }
}

struct DashboardView_Previews: PreviewProvider {
    static var previews: some View {
        DashboardView(store: DashboardStore())
            .frame(width: 1000, height: 760)
    }
}
