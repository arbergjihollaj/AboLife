import SwiftUI

struct WeeklyReviewView: View {
    @StateObject private var store: WeeklyReviewStore

    init(database: AppDatabase?) {
        _store = StateObject(wrappedValue: WeeklyReviewStore(database: database))
    }

    var body: some View {
        ZStack {
            AboLifePremiumBackground()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    header
                    heroCard
                    summaryGrid
                    trendsSection
                    reviewForm
                }
                .padding(22)
            }
        }
        .navigationTitle("")
        .onAppear {
            store.reload()
        }
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Wochenreview")
                    .font(AboLifeTypography.dashboardTitle)
                    .foregroundStyle(AboLifeColors.primaryText)

                Text(store.weekSubtitle)
                    .font(AboLifeTypography.body)
                    .foregroundStyle(AboLifeColors.secondaryText)
            }

            Spacer()

            Button {
                store.selectCurrentWeek()
            } label: {
                Image(systemName: "calendar")
                    .font(.system(size: 14, weight: .semibold))
            }
            .buttonStyle(.bordered)
            .help("Diese Woche")
            .disabled(store.isCurrentWeek)

            Button {
                store.reload()
            } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 14, weight: .semibold))
            }
            .buttonStyle(.bordered)
            .help("Neu laden")
        }
    }

    private var heroCard: some View {
        AboLifeCard(isProminent: true) {
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .center, spacing: 24) {
                    reviewRing(size: 150, lineWidth: 13)
                    heroCopy
                    Spacer(minLength: 0)
                }

                VStack(alignment: .leading, spacing: 18) {
                    reviewRing(size: 136, lineWidth: 12)
                    heroCopy
                }
            }
        }
    }

    private func reviewRing(size: CGFloat, lineWidth: CGFloat) -> some View {
        CoreRingView(
            progress: store.habitSummary.progress,
            lineWidth: lineWidth,
            tint: AboLifeColors.review,
            valueText: "\(Int(store.habitSummary.progress * 100))%",
            labelText: "Habits"
        )
        .frame(width: size, height: size)
    }

    private var heroCopy: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Label("Diese Woche", systemImage: "calendar.badge.clock")
                    .font(AboLifeTypography.cardTitle)
                    .foregroundStyle(AboLifeColors.primaryText)

                AboLifeGlassCapsule {
                    Text("\(store.reviewedDaysCount) Tage")
                        .font(AboLifeTypography.micro)
                        .foregroundStyle(AboLifeColors.review)
                        .monospacedDigit()
                }
            }

            Text(store.hasMeaningfulData ? "Review bereit" : "Noch wenig Daten")
                .font(AboLifeTypography.heroMessage)
                .foregroundStyle(AboLifeColors.primaryText)

            Text(store.statusMessage)
                .font(AboLifeTypography.body)
                .foregroundStyle(AboLifeColors.secondaryText)
                .fixedSize(horizontal: false, vertical: true)

            if let errorMessage = store.errorMessage {
                Text(errorMessage)
                    .font(AboLifeTypography.caption)
                    .foregroundStyle(AboLifeColors.habits)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: 620, alignment: .leading)
    }

    private var summaryGrid: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 230), spacing: 12)], spacing: 12) {
            ReviewSummaryCard(
                title: "Ernährung",
                systemImage: "fork.knife",
                tint: AboLifeColors.nutrition,
                primary: "Ø \(Int(store.nutritionSummary.averageCaloriesPerDay.rounded())) kcal / Tag",
                secondary: "Ø \(Int(store.nutritionSummary.averageProteinGPerDay.rounded())) g Protein",
                progress: store.nutritionProgress
            )

            ReviewSummaryCard(
                title: "Training",
                systemImage: "figure.strengthtraining.traditional",
                tint: AboLifeColors.training,
                primary: "\(store.trainingSummary.completedWorkouts) / \(store.weeklyWorkoutTarget) Workouts",
                secondary: "\(store.trainingSummary.totalDurationMin) Min. diese Woche",
                progress: store.trainingProgress
            )

            ReviewSummaryCard(
                title: "Finanzen",
                systemImage: "eurosign.circle",
                tint: AboLifeColors.finance,
                primary: "\(store.formatAmount(store.financeSummary.spent)) diese Woche",
                secondary: "\(store.financeSummary.entryCount) Ausgaben erfasst",
                progress: store.financeProgress
            )

            ReviewSummaryCard(
                title: "Gewohnheiten",
                systemImage: "checkmark.seal",
                tint: AboLifeColors.habits,
                primary: "\(store.habitSummary.completed) / \(store.habitSummary.total) erledigt",
                secondary: "\(Int(store.habitSummary.progress * 100))% Completion",
                progress: store.habitSummary.progress
            )
        }
    }

    private var trendsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Trends dieser Woche")
                        .font(AboLifeTypography.sectionTitle)
                        .foregroundStyle(AboLifeColors.primaryText)

                    Text("Deine wichtigsten Werte pro Tag")
                        .font(AboLifeTypography.body)
                        .foregroundStyle(AboLifeColors.secondaryText)
                }

                Spacer()

                if !store.trends.hasAnyData {
                    AboLifeGlassCapsule {
                        Text("Noch keine Daten für diese Woche.")
                            .font(AboLifeTypography.micro)
                            .foregroundStyle(AboLifeColors.secondaryText)
                    }
                }
            }

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 220), spacing: 12)], spacing: 12) {
                WeeklyTrendCard(
                    title: "Kalorien",
                    systemImage: "flame",
                    tint: AboLifeColors.nutrition,
                    primary: "\(Int(store.trends.caloriesByDay.totalValue.rounded())) kcal",
                    secondary: "Ø \(Int(store.trends.caloriesByDay.averageValue.rounded())) / Tag",
                    points: store.trends.caloriesByDay
                )

                WeeklyTrendCard(
                    title: "Protein",
                    systemImage: "bolt.heart",
                    tint: AboLifeColors.protein,
                    primary: "\(Int(store.trends.proteinByDay.totalValue.rounded())) g",
                    secondary: "Ø \(Int(store.trends.proteinByDay.averageValue.rounded())) g / Tag",
                    points: store.trends.proteinByDay
                )

                WeeklyTrendCard(
                    title: "Ausgaben",
                    systemImage: "eurosign.circle",
                    tint: AboLifeColors.finance,
                    primary: store.formatCurrencyAmount(store.trends.spendingByDay.totalValue),
                    secondary: "Diese Woche",
                    points: store.trends.spendingByDay
                )

                WeeklyTrendCard(
                    title: "Training",
                    systemImage: "figure.strengthtraining.traditional",
                    tint: AboLifeColors.training,
                    primary: "\(Int(store.trends.trainingMinutesByDay.totalValue.rounded())) Min.",
                    secondary: "\(store.trainingSummary.completedWorkouts) Workouts",
                    points: store.trends.trainingMinutesByDay
                )

                WeeklyTrendCard(
                    title: "Gewohnheiten",
                    systemImage: "checkmark.seal",
                    tint: AboLifeColors.habits,
                    primary: "\(Int(store.trends.habitCompletionByDay.averageValue.rounded())) %",
                    secondary: "Wochenschnitt",
                    points: store.trends.habitCompletionByDay
                )
            }
        }
    }

    private var reviewForm: some View {
        AboLifeCard(isProminent: true) {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Label("Persönlicher Rückblick", systemImage: "square.and.pencil")
                        .font(AboLifeTypography.cardTitle)
                        .foregroundStyle(AboLifeColors.primaryText)

                    Spacer()

                    if let saveMessage = store.saveMessage {
                        AboLifeGlassCapsule {
                            Text(saveMessage)
                                .font(AboLifeTypography.micro)
                                .foregroundStyle(AboLifeColors.review)
                        }
                    }
                }

                ReviewTextEditor(title: "Was lief gut?", text: $store.winsText)
                ReviewTextEditor(title: "Was war schwierig?", text: $store.challengesText)
                ReviewTextEditor(title: "Fokus für nächste Woche", text: $store.nextWeekFocusText)

                HStack {
                    Text("Ein Review pro Woche wird lokal gespeichert.")
                        .font(AboLifeTypography.caption)
                        .foregroundStyle(AboLifeColors.secondaryText)

                    Spacer()

                    Button {
                        store.saveReview()
                    } label: {
                        Label("Speichern", systemImage: "checkmark")
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(AboLifeColors.review)
                }
            }
        }
    }
}

private struct ReviewSummaryCard: View {
    let title: String
    let systemImage: String
    let tint: Color
    let primary: String
    let secondary: String
    let progress: Double

    var body: some View {
        AboLifeCard(minHeight: 150) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    Image(systemName: systemImage)
                        .foregroundStyle(tint)
                        .frame(width: 18)

                    Text(title)
                        .font(AboLifeTypography.cardTitle)
                        .foregroundStyle(AboLifeColors.primaryText)
                }

                Text(primary)
                    .font(AboLifeTypography.metric)
                    .foregroundStyle(AboLifeColors.primaryText)
                    .lineLimit(2)
                    .minimumScaleFactor(0.78)

                Text(secondary)
                    .font(AboLifeTypography.caption)
                    .foregroundStyle(AboLifeColors.secondaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)

                PremiumProgressBar(progress: progress, tint: tint, height: 7)
            }
        }
    }
}

private struct ReviewTextEditor: View {
    let title: String
    @Binding var text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(title)
                .font(AboLifeTypography.caption)
                .foregroundStyle(AboLifeColors.secondaryText)

            TextEditor(text: $text)
                .font(AboLifeTypography.body)
                .foregroundStyle(AboLifeColors.primaryText)
                .scrollContentBackground(.hidden)
                .frame(minHeight: 74)
                .padding(8)
                .background {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(AboLifeColors.quietFill)
                        .overlay {
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .strokeBorder(AboLifeColors.glassStrokeMuted, lineWidth: 0.7)
                        }
                }
        }
    }
}

struct WeeklyReviewView_Previews: PreviewProvider {
    static var previews: some View {
        WeeklyReviewView(database: nil)
            .frame(width: 1000, height: 780)
    }
}
