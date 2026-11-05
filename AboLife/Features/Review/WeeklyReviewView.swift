import SwiftUI

struct WeeklyReviewView: View {
    @Environment(\.aboLifeStyle) private var designStyle
    @StateObject private var store: WeeklyReviewStore
    @State private var pendingDate: Date?
    @State private var showUnsavedConfirmation = false

    init(database: AppDatabase?) {
        _store = StateObject(wrappedValue: WeeklyReviewStore(database: database))
    }

    init(store: WeeklyReviewStore) {
        _store = StateObject(wrappedValue: store)
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
                .aboLifePage()
            }
        }
        .navigationTitle("")
        .onAppear {
            if !store.hasUnsavedChanges { store.reload() }
        }
        .confirmationDialog("Ungespeicherter Wochenrückblick", isPresented: $showUnsavedConfirmation) {
            Button("Speichern und fortfahren") {
                if store.saveReview() { applyPendingNavigation() }
            }
            Button("Änderungen verwerfen", role: .destructive, action: applyPendingNavigation)
            Button("Abbrechen", role: .cancel) { pendingDate = nil }
        } message: {
            Text("Deine Eingaben sind noch nicht gespeichert. Speichere sie vor dem Wechsel oder bleibe in dieser Woche.")
        }
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Wochenreview")
                    .accessibilityIdentifier("page.weeklyReview")
                    .font(AboLifeTypography.dashboardTitle)
                    .foregroundStyle(designStyle.colors.primaryText)

                Text(store.weekSubtitle)
                    .font(AboLifeTypography.body)
                    .foregroundStyle(designStyle.colors.secondaryText)
            }

            Spacer()

            AboLifePeriodControl(
                title: store.weekSubtitle,
                previousLabel: "Vorherige Reviewwoche", nextLabel: "Nächste Reviewwoche", canGoForward: !store.isCurrentWeek,
                previous: { requestNavigation(to: store.dateMovingWeek(by: -1)) },
                next: { requestNavigation(to: store.dateMovingWeek(by: 1)) }
            )

            Button {
                requestNavigation(to: Date())
            } label: {
                Image(systemName: "calendar")
                    .font(.system(size: 16, weight: .medium))
            }
            .buttonStyle(.bordered)
            .help("Diese Woche").accessibilityLabel("Diese Woche")
            .disabled(store.isCurrentWeek)

            Button {
                requestNavigation(to: nil)
            } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 16, weight: .medium))
            }
            .buttonStyle(.bordered)
            .help("Neu laden").accessibilityLabel("Neu laden")
        }
    }

    private var heroCard: some View {
        AboLifeCard(isProminent: true) {
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .center, spacing: 24) {
                    heroCopy
                    Spacer(minLength: 0)
                    reviewRing(size: 152, lineWidth: 8)
                }

                VStack(alignment: .leading, spacing: 16) {
                    heroCopy
                    reviewRing(size: 136, lineWidth: 8)
                }
            }
        }
    }

    private func reviewRing(size: CGFloat, lineWidth: CGFloat) -> some View {
        CoreRingView(
            progress: store.habitSummary.progress,
            lineWidth: lineWidth,
            tint: designStyle.colors.review,
            valueText: "\(Int(store.habitSummary.progress * 100))%",
            labelText: "Gewohnheiten"
        )
        .frame(width: size, height: size)
    }

    private var heroCopy: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Label(store.isCurrentWeek ? "Diese Woche" : "Ausgewählte Woche", systemImage: "calendar.badge.clock")
                    .font(AboLifeTypography.cardTitle)
                    .foregroundStyle(designStyle.colors.primaryText)

                AboLifeGlassCapsule {
                    Text("\(store.reviewedDaysCount) Tage")
                        .font(AboLifeTypography.micro)
                        .foregroundStyle(designStyle.colors.review)
                        .monospacedDigit()
                }
            }

            Text(store.hasMeaningfulData ? "Deine Woche im Rückblick" : "Noch wenig Daten")
                .font(AboLifeTypography.heroMessage)
                .foregroundStyle(designStyle.colors.primaryText)

            Text(store.statusMessage)
                .font(AboLifeTypography.body)
                .foregroundStyle(designStyle.colors.secondaryText)
                .fixedSize(horizontal: false, vertical: true)

            if let errorMessage = store.errorMessage {
                inlineError(errorMessage)
            }
        }
        .frame(maxWidth: 620, alignment: .leading)
    }

    private func inlineError(_ message: String) -> some View {
        HStack(alignment: .center, spacing: 10) {
            Label(message, systemImage: "exclamationmark.circle")
                .font(AboLifeTypography.caption)
                .foregroundStyle(designStyle.colors.habits)
                .fixedSize(horizontal: false, vertical: true)

            Button {
                requestNavigation(to: nil)
            } label: {
                Label("Erneut versuchen", systemImage: "arrow.clockwise")
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
    }

    private var summaryGrid: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 230), spacing: 12)], spacing: 12) {

            ReviewSummaryCard(
                title: "Training",
                systemImage: "figure.strengthtraining.traditional",
                tint: designStyle.colors.training,
                primary: "\(store.trainingSummary.completedWorkouts) / \(store.weeklyWorkoutTarget) Workouts",
                secondary: "\(store.trainingSummary.totalDurationMin) Min. diese Woche",
                progress: store.trainingProgress
            )

            ReviewSummaryCard(
                title: "Finanzen",
                systemImage: "eurosign.circle",
                tint: designStyle.colors.finance,
                primary: "\(store.formatAmount(store.financeSummary.spent)) diese Woche",
                secondary: store.financeAnalysis,
                progress: store.financeProgress
            )

            ReviewSummaryCard(
                title: "Gewohnheiten",
                systemImage: "checkmark.seal",
                tint: designStyle.colors.habits,
                primary: "\(Int((store.habitSummary.progress * 100).rounded()))% Habit-Fortschritt",
                secondary: "inkl. Trainieren aus Workouts",
                progress: store.habitSummary.progress
            )
        }
    }

    private func requestNavigation(to date: Date?) {
        pendingDate = date
        if store.hasUnsavedChanges { showUnsavedConfirmation = true }
        else { applyPendingNavigation() }
    }

    private func applyPendingNavigation() {
        if let date = pendingDate {
            let previousWeek = store.weekStartKey
            store.selectedDate = date
            if previousWeek == store.weekStartKey { store.reload() }
        }
        else { store.reload() }
        pendingDate = nil
    }

    private var trendsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Trends dieser Woche")
                        .font(AboLifeTypography.sectionTitle)
                        .foregroundStyle(designStyle.colors.primaryText)

                    Text("Deine wichtigsten Werte pro Tag")
                        .font(AboLifeTypography.body)
                        .foregroundStyle(designStyle.colors.secondaryText)
                }

                Spacer()

                if !store.trends.hasAnyData {
                    AboLifeGlassCapsule {
                        Text("Noch keine Daten für diese Woche.")
                            .font(AboLifeTypography.micro)
                            .foregroundStyle(designStyle.colors.secondaryText)
                    }
                }
            }

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 220), spacing: 12)], spacing: 12) {


                WeeklyTrendCard(
                    title: "Ausgaben",
                    systemImage: "eurosign.circle",
                    tint: designStyle.colors.finance,
                    primary: store.formatCurrencyAmount(store.trends.spendingByDay.totalValue),
                    secondary: "Diese Woche",
                    points: store.trends.spendingByDay
                )

                WeeklyTrendCard(
                    title: "Training",
                    systemImage: "figure.strengthtraining.traditional",
                    tint: designStyle.colors.training,
                    primary: "\(Int(store.trends.trainingMinutesByDay.totalValue.rounded())) Min.",
                    secondary: "\(store.trainingSummary.completedWorkouts) Workouts",
                    points: store.trends.trainingMinutesByDay
                )

                WeeklyTrendCard(
                    title: "Gewohnheiten",
                    systemImage: "checkmark.seal",
                    tint: designStyle.colors.habits,
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
                        .foregroundStyle(designStyle.colors.primaryText)

                    Spacer()

                    if let saveMessage = store.saveMessage {
                        AboLifeGlassCapsule {
                            Text(saveMessage)
                                .font(AboLifeTypography.micro)
                                .foregroundStyle(designStyle.colors.review)
                        }
                    }
                }

                ReviewTextEditor(title: "Was lief gut?", text: $store.winsText)
                ReviewTextEditor(title: "Was war schwierig?", text: $store.challengesText)
                ReviewTextEditor(title: "Fokus für nächste Woche", text: $store.nextWeekFocusText)

                HStack {
                    Text("Ein Review pro Woche wird lokal gespeichert.")
                        .font(AboLifeTypography.caption)
                        .foregroundStyle(designStyle.colors.secondaryText)

                    Spacer()

                    Button {
                        store.saveReview()
                    } label: {
                        Label("Speichern", systemImage: "checkmark")
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(designStyle.colors.action)
                }
            }
        }
    }
}

private struct ReviewSummaryCard: View {
    @Environment(\.aboLifeStyle) private var designStyle
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
                        .foregroundStyle(designStyle.colors.primaryText)
                }

                Text(primary)
                    .font(AboLifeTypography.metric)
                    .foregroundStyle(designStyle.colors.primaryText)
                    .lineLimit(2)
                    .minimumScaleFactor(0.78)

                Text(secondary)
                    .font(AboLifeTypography.caption)
                    .foregroundStyle(designStyle.colors.secondaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)

                PremiumProgressBar(progress: progress, tint: tint, height: 7)
            }
        }
    }
}

private struct ReviewTextEditor: View {
    @Environment(\.aboLifeStyle) private var designStyle
    let title: String
    @Binding var text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(title)
                .font(AboLifeTypography.caption)
                .foregroundStyle(designStyle.colors.secondaryText)

            TextEditor(text: $text)
                .accessibilityLabel(title)
                .font(AboLifeTypography.body)
                .foregroundStyle(designStyle.colors.primaryText)
                .scrollContentBackground(.hidden)
                .frame(minHeight: 74)
                .padding(8)
                .background {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(designStyle.colors.quietFill)
                        .overlay {
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .strokeBorder(designStyle.colors.glassStrokeMuted, lineWidth: 0.7)
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
