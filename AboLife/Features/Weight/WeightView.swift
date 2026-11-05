import SwiftUI

struct WeightView: View {
    @Environment(\.aboLifeStyle) private var designStyle
    @StateObject private var store: WeightStore

    init(database: AppDatabase?) {
        _store = StateObject(wrappedValue: WeightStore(database: database))
    }

    var body: some View {
        ZStack {
            AboLifePremiumBackground()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    header
                    inputCard
                    goalCard
                    overviewGrid
                    historySection
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
                Text("Gewicht")
                    .font(AboLifeTypography.dashboardTitle)
                    .foregroundStyle(designStyle.colors.primaryText)

                Text(store.dateSubtitle)
                    .font(AboLifeTypography.body)
                    .foregroundStyle(designStyle.colors.secondaryText)
            }

            Spacer()

            DatePicker("", selection: $store.selectedDate, displayedComponents: .date)
                .datePickerStyle(.compact)
                .labelsHidden()
                .frame(width: 132)

            Button {
                store.selectToday()
            } label: {
                Image(systemName: "calendar")
                    .font(.system(size: 16, weight: .medium))
            }
            .buttonStyle(.bordered)
            .help("Heute").accessibilityLabel("Heute")

            Button {
                store.reload()
            } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 16, weight: .medium))
            }
            .buttonStyle(.bordered)
            .help("Neu laden").accessibilityLabel("Neu laden")
        }
    }

    private var inputCard: some View {
        AboLifeCard(isProminent: true) {
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .center, spacing: 20) {
                    inputCopy
                    Spacer(minLength: 0)
                    inputControls
                        .frame(width: 260)
                }

                VStack(alignment: .leading, spacing: 16) {
                    inputCopy
                    inputControls
                }
            }
        }
    }

    private var inputCopy: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Tagesgewicht", systemImage: "scalemass")
                .font(AboLifeTypography.cardTitle)
                .foregroundStyle(designStyle.colors.primaryText)

            Text(store.latestValueText)
                .font(AboLifeTypography.heroMessage)
                .foregroundStyle(designStyle.colors.primaryText)
                .monospacedDigit()

            Text(store.latestEntry == nil ? "Noch kein Gewicht eingetragen." : "Letzter Eintrag: \(store.latestEntry?.date ?? "")")
                .font(AboLifeTypography.body)
                .foregroundStyle(designStyle.colors.secondaryText)
        }
    }

    private var inputControls: some View {
        VStack(alignment: .leading, spacing: 10) {
            labeledTextField("Gewicht in kg", text: $store.weightInput)

            if let errorMessage = store.errorMessage {
                Text(errorMessage)
                    .font(AboLifeTypography.caption)
                    .foregroundStyle(designStyle.colors.habits)
            }

            Button {
                _ = store.saveSelectedWeight()
            } label: {
                Label("Speichern", systemImage: "checkmark.circle.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .tint(designStyle.colors.action)
        }
    }

    private var overviewGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            metricTile(title: "Aktuell", value: store.latestValueText, systemImage: "scalemass", tint: designStyle.colors.review)
            metricTile(title: "Ziel", value: store.goalSummary.targetWeightKg.map(WeightStore.formatWeight) ?? "nicht gesetzt", systemImage: "target", tint: designStyle.colors.finance)
            metricTile(title: "Veränderung", value: WeightStore.formatChange(store.changeFromPreviousKg), systemImage: "arrow.up.arrow.down", tint: designStyle.colors.habits)
        }
    }

    private var goalCard: some View {
        AboLifeCard {
            VStack(alignment: .leading, spacing: 14) {
                Label("Zielgewicht und Korridor", systemImage: "target")
                    .font(AboLifeTypography.cardTitle)
                    .foregroundStyle(designStyle.colors.primaryText)

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                    metricTile(title: "Ziel", value: store.goalSummary.targetWeightKg.map(WeightStore.formatWeight) ?? "nicht gesetzt", systemImage: "target", tint: designStyle.colors.review)
                    metricTile(title: "Abstand", value: store.goalSummary.distanceText, systemImage: "arrow.left.and.right", tint: designStyle.colors.finance)
                    metricTile(title: "Status", value: store.goalSummary.statusText, systemImage: store.goalSummary.isInTargetCorridor == true ? "checkmark.circle" : "exclamationmark.circle", tint: store.goalSummary.isInTargetCorridor == true ? designStyle.colors.positive : designStyle.colors.habits)
                }

                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 10) {
                        labeledTextField("Ziel kg", text: $store.targetWeightInput)
                        labeledTextField("Untergrenze", text: $store.targetLowerInput)
                        labeledTextField("Obergrenze", text: $store.targetUpperInput)
                        Button {
                            _ = store.saveGoals()
                        } label: {
                            Label("Ziele speichern", systemImage: "checkmark.circle")
                        }
                        .buttonStyle(.bordered)
                        .tint(designStyle.colors.review)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        labeledTextField("Ziel kg", text: $store.targetWeightInput)
                        labeledTextField("Untergrenze", text: $store.targetLowerInput)
                        labeledTextField("Obergrenze", text: $store.targetUpperInput)
                        Button {
                            _ = store.saveGoals()
                        } label: {
                            Label("Ziele speichern", systemImage: "checkmark.circle")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        .tint(designStyle.colors.review)
                    }
                }
            }
        }
    }

    private var historySection: some View {
        AboLifeCard(isProminent: true) {
            VStack(alignment: .leading, spacing: 16) {
                Label("Verlauf", systemImage: "chart.xyaxis.line")
                    .font(AboLifeTypography.cardTitle)
                    .foregroundStyle(designStyle.colors.primaryText)

                if store.entries.isEmpty {
                    emptyState
                } else {
                    WeightLineChart(entries: store.sevenDayEntries, tint: designStyle.colors.review)
                        .frame(height: 150)

                    if store.thirtyDayEntries.count >= 2 {
                        WeightLineChart(entries: store.thirtyDayEntries, tint: designStyle.colors.finance)
                            .frame(height: 150)
                    } else {
                        Text("Noch nicht genug Gewichtsdaten für einen 30-Tage-Verlauf.")
                            .font(AboLifeTypography.caption)
                            .foregroundStyle(designStyle.colors.secondaryText)
                    }

                    VStack(spacing: 10) {
                        ForEach(store.entries.prefix(30)) { entry in
                            WeightEntryRow(entry: entry, edit: { store.edit(entry) }, delete: { store.delete(id: entry.id) })
                        }
                    }
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text("Noch kein Gewicht eingetragen.")
                .font(AboLifeTypography.body.weight(.semibold))
                .foregroundStyle(designStyle.colors.primaryText)

            Text("Trage oben dein Tagesgewicht ein. Ein vorhandener Eintrag am selben Tag wird aktualisiert.")
                .font(AboLifeTypography.caption)
                .foregroundStyle(designStyle.colors.secondaryText)
        }
        .frame(maxWidth: .infinity, minHeight: 112, alignment: .leading)
    }

    private func metricTile(title: String, value: String, systemImage: String, tint: Color) -> some View {
        HStack(spacing: 10) {
            Image(systemName: systemImage)
                .foregroundStyle(tint)
                .frame(width: 22)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(AboLifeTypography.micro)
                    .foregroundStyle(designStyle.colors.secondaryText)
                Text(value)
                    .font(AboLifeTypography.caption.weight(.semibold))
                    .foregroundStyle(designStyle.colors.primaryText)
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
        }
        .padding(13)
        .frame(maxWidth: .infinity, minHeight: 64, alignment: .leading)
        .background(designStyle.colors.quietFill, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(designStyle.colors.glassStrokeMuted, lineWidth: 0.7)
        }
    }
}

private struct WeightEntryRow: View {
    @Environment(\.aboLifeStyle) private var designStyle
    let entry: WeightEntryRecord
    let edit: () -> Void
    let delete: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(entry.date)
                    .font(AboLifeTypography.caption.weight(.semibold))
                    .foregroundStyle(designStyle.colors.primaryText)
                Text("Aktualisiert \(entry.updatedAt.formatted(.dateTime.hour().minute()))")
                    .font(AboLifeTypography.micro)
                    .foregroundStyle(designStyle.colors.secondaryText)
            }

            Spacer()

            Text(WeightStore.formatWeight(entry.weightKg))
                .font(AboLifeTypography.caption.weight(.semibold))
                .foregroundStyle(designStyle.colors.primaryText)
                .monospacedDigit()

            Button(action: edit) {
                Image(systemName: "pencil")
            }
            .buttonStyle(.bordered)
            .help("Bearbeiten").accessibilityLabel("Bearbeiten")

            Button(role: .destructive, action: delete) {
                Image(systemName: "trash")
            }
            .buttonStyle(.bordered)
            .help("Löschen").accessibilityLabel("Löschen")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(designStyle.colors.quietFill, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

private struct WeightLineChart: View {
    @Environment(\.aboLifeStyle) private var designStyle
    let entries: [WeightEntryRecord]
    let tint: Color

    var body: some View {
        GeometryReader { proxy in
            let inset: CGFloat = 14
            let width = max(proxy.size.width - inset * 2, 1)
            let height = max(proxy.size.height - inset * 2, 1)
            let values = entries.map(\.weightKg)
            let minValue = values.min() ?? 0
            let maxValue = values.max() ?? 1
            let range = max(maxValue - minValue, 1)
            let points = entries.enumerated().map { index, entry in
                let x = inset + (entries.count <= 1 ? width / 2 : CGFloat(index) / CGFloat(entries.count - 1) * width)
                let y = inset + height - CGFloat((entry.weightKg - minValue) / range) * height
                return CGPoint(x: x, y: y)
            }

            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(designStyle.colors.quietFill)

                if points.count < 2 {
                    Text("Noch nicht genug Daten für einen Verlauf.")
                        .font(AboLifeTypography.caption)
                        .foregroundStyle(designStyle.colors.secondaryText)
                } else {
                    Path { path in
                        path.move(to: points[0])
                        points.dropFirst().forEach { path.addLine(to: $0) }
                    }
                    .stroke(tint, style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))

                    ForEach(Array(points.enumerated()), id: \.offset) { _, point in
                        Circle()
                            .fill(tint)
                            .frame(width: 7, height: 7)
                            .position(x: point.x, y: point.y)
                    }
                }
            }
        }
    }
}
