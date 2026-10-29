import SwiftUI

struct StatisticsView: View {
    @StateObject private var store: StatisticsStore

    init(database: AppDatabase?) {
        _store = StateObject(wrappedValue: StatisticsStore(database: database))
    }

    var body: some View {
        ZStack {
            AboLifePremiumBackground()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    header
                    insightGrid
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
                Text("Statistiken")
                    .font(AboLifeTypography.dashboardTitle)
                    .foregroundStyle(AboLifeColors.primaryText)

                Text("Diese Woche und aktueller Monat")
                    .font(AboLifeTypography.body)
                    .foregroundStyle(AboLifeColors.secondaryText)
            }

            Spacer()

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

    private var insightGrid: some View {
        AboLifeCard(isProminent: true) {
            VStack(alignment: .leading, spacing: 14) {
                Label("Überblick", systemImage: "chart.bar.xaxis")
                    .font(AboLifeTypography.cardTitle)
                    .foregroundStyle(AboLifeColors.primaryText)

                if let errorMessage = store.errorMessage {
                    Text(errorMessage)
                        .font(AboLifeTypography.caption)
                        .foregroundStyle(AboLifeColors.secondaryText)
                } else if store.insights.isEmpty {
                    emptyState
                } else {
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                        ForEach(store.insights) { insight in
                            StatisticInsightTile(insight: insight)
                        }
                    }
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text("Noch keine Statistikdaten.")
                .font(AboLifeTypography.body.weight(.semibold))
                .foregroundStyle(AboLifeColors.primaryText)

            Text("Sobald du Einträge speicherst, entstehen hier echte Wochen- und Monatswerte.")
                .font(AboLifeTypography.caption)
                .foregroundStyle(AboLifeColors.secondaryText)
        }
        .frame(maxWidth: .infinity, minHeight: 112, alignment: .leading)
    }
}

private struct StatisticInsightTile: View {
    let insight: StatisticInsight

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 9) {
                Image(systemName: insight.systemImage)
                    .foregroundStyle(tint)
                    .frame(width: 20)

                Text(insight.title)
                    .font(AboLifeTypography.caption.weight(.semibold))
                    .foregroundStyle(AboLifeColors.primaryText)
                    .lineLimit(1)
            }

            Text(insight.value)
                .font(AboLifeTypography.metric)
                .foregroundStyle(AboLifeColors.primaryText)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.72)

            Text(insight.detail)
                .font(AboLifeTypography.caption)
                .foregroundStyle(AboLifeColors.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .frame(maxWidth: .infinity, minHeight: 148, alignment: .topLeading)
        .background(AboLifeColors.quietFill, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(AboLifeColors.glassStrokeMuted, lineWidth: 0.7)
        }
    }

    private var tint: Color {
        switch insight.tintRole {
        case .training:
            return AboLifeColors.training
        case .finance:
            return AboLifeColors.finance
        case .habits:
            return AboLifeColors.habits
        case .review:
            return AboLifeColors.review
        }
    }
}
