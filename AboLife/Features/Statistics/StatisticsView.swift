import SwiftUI

struct StatisticsView: View {
    @Environment(\.aboLifeStyle) private var designStyle
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
                    Text(
                        "Berechnet aus lokalen Einträgen. Wochenwerte beziehen sich auf die Woche des ausgewählten Datums, Monatswerte auf den gesamten Monat. Ziele verwenden aktuelle Einstellungen. Gewichtsschnitte nutzen vorhandene Messungen der letzten 7 bzw. 30 Kalendertage; fehlende Tage werden nicht ergänzt. Aktive Tage zählen über den gesamten Verlauf."
                    )
                    .font(AboLifeTypography.caption)
                    .foregroundStyle(designStyle.colors.secondaryText)
                }
                .aboLifePage()
            }
        }
        .navigationTitle("")
        .onAppear {
            store.reload()
        }
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Statistiken")
                    .accessibilityIdentifier("page.statistics")
                    .font(AboLifeTypography.dashboardTitle)
                    .foregroundStyle(designStyle.colors.primaryText)

                Text(store.periodDescription)
                    .font(AboLifeTypography.body)
                    .foregroundStyle(designStyle.colors.secondaryText)
            }

            Spacer()

            AboLifePeriodControl(
                title: store.selectedDate.formatted(.dateTime.month(.abbreviated).year()),
                previousLabel: "Statistiken des Vormonats", nextLabel: "Statistiken des Folgemonats",
                canGoForward: !Calendar.current.isDate(store.selectedDate, equalTo: Date(), toGranularity: .month),
                previous: { store.moveMonth(by: -1) }, next: { store.moveMonth(by: 1) }
            )

            Button("Aktuellen Zeitraum anzeigen", systemImage: "calendar") { store.selectedDate = Date() }
                .labelStyle(.iconOnly)
                .buttonStyle(.bordered)

            Button {
                store.reload()
            } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 16, weight: .medium))
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
                    .foregroundStyle(designStyle.colors.primaryText)

                if let errorMessage = store.errorMessage {
                    AboLifeNotice(title: "Statistiken nicht verfügbar", message: errorMessage, retry: store.reload)
                } else if store.insights.isEmpty {
                    emptyState
                } else {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 216), spacing: 12)], spacing: 12) {
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
            Text("Noch keine Statistikdaten")
                .font(AboLifeTypography.body.weight(.semibold))
                .foregroundStyle(designStyle.colors.primaryText)

            Text("Wochen- und Monatswerte erscheinen nach deinem ersten Eintrag")
                .font(AboLifeTypography.caption)
                .foregroundStyle(designStyle.colors.secondaryText)
        }
        .frame(maxWidth: .infinity, minHeight: 112, alignment: .leading)
    }
}
