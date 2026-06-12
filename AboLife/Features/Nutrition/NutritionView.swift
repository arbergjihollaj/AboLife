import SwiftUI

struct NutritionView: View {
    @StateObject private var store: NutritionStore

    init(database: AppDatabase?) {
        _store = StateObject(wrappedValue: NutritionStore(database: database))
    }

    var body: some View {
        ZStack {
            AboLifePremiumBackground()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    header
                    ringOverview
                    mealsSection
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
                Text("Ernährung")
                    .font(AboLifeTypography.dashboardTitle)
                    .foregroundStyle(AboLifeColors.primaryText)

                Text(store.dateSubtitle)
                    .font(AboLifeTypography.body)
                    .foregroundStyle(AboLifeColors.secondaryText)
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
                    .font(.system(size: 14, weight: .semibold))
            }
            .buttonStyle(.bordered)
            .help("Heute")
            .disabled(store.isToday)

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

    private var ringOverview: some View {
        AboLifeCard(isProminent: true) {
            VStack(spacing: 16) {
                NutritionDoubleRingView(
                    caloriesConsumed: store.caloriesConsumed,
                    caloriesTarget: store.caloriesTarget,
                    proteinConsumed: store.proteinConsumed,
                    proteinTarget: store.proteinTarget,
                    caloriesProgress: store.caloriesProgress,
                    proteinProgress: store.proteinProgress
                )
                .frame(maxWidth: .infinity)

                HStack(spacing: 12) {
                    ringSummaryPill(
                        title: "Kalorien",
                        value: "\(store.caloriesConsumed) / \(store.caloriesTarget) kcal",
                        tint: AboLifeColors.nutrition
                    )

                    ringSummaryPill(
                        title: "Protein",
                        value: "\(Int(store.proteinConsumed)) / \(Int(store.proteinTarget)) g",
                        tint: AboLifeColors.protein
                    )

                    ringSummaryPill(
                        title: store.entries.count == 1 ? "Eintrag" : "Einträge",
                        value: "\(store.entries.count)",
                        tint: AboLifeColors.review
                    )
                }

                Text(statusMessage)
                    .font(AboLifeTypography.caption)
                    .foregroundStyle(AboLifeColors.secondaryText)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 460)
            }
            .frame(maxWidth: .infinity)
        }
    }

    private var mealsSection: some View {
        AboLifeCard(isProminent: true) {
            VStack(alignment: .leading, spacing: 13) {
                HStack {
                    Label("Mahlzeiten", systemImage: "fork.knife")
                        .font(AboLifeTypography.cardTitle)
                        .foregroundStyle(AboLifeColors.primaryText)

                    Spacer()

                    AboLifeGlassCapsule {
                        Text("\(store.caloriesConsumed) kcal · \(Int(store.proteinConsumed)) g")
                            .font(AboLifeTypography.micro)
                            .foregroundStyle(AboLifeColors.secondaryText)
                            .monospacedDigit()
                    }
                }

                if let errorMessage = store.errorMessage {
                    errorState(errorMessage)
                } else if store.entries.isEmpty {
                    emptyState
                } else {
                    VStack(spacing: 10) {
                        ForEach(store.entries) { entry in
                            NutritionEntryRow(entry: entry) {
                                store.deleteEntry(id: entry.id)
                            }
                        }
                    }
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text("Heute noch keine Mahlzeit erfasst.")
                .font(AboLifeTypography.body.weight(.semibold))
                .foregroundStyle(AboLifeColors.primaryText)

            Text("Nutze Quick Add, um eine Mahlzeit einzutragen.")
                .font(AboLifeTypography.caption)
                .foregroundStyle(AboLifeColors.secondaryText)
        }
        .frame(maxWidth: .infinity, minHeight: 112, alignment: .leading)
    }

    private func errorState(_ message: String) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            Text("Ernährungsdaten konnten nicht geladen werden.")
                .font(AboLifeTypography.body.weight(.semibold))
                .foregroundStyle(AboLifeColors.primaryText)

            Text(message)
                .font(AboLifeTypography.caption)
                .foregroundStyle(AboLifeColors.secondaryText)

            Button {
                store.reload()
            } label: {
                Label("Erneut versuchen", systemImage: "arrow.clockwise")
            }
            .buttonStyle(.borderedProminent)
            .tint(AboLifeColors.nutrition)
        }
        .frame(maxWidth: .infinity, minHeight: 112, alignment: .leading)
    }

    private var statusMessage: String {
        if store.entries.isEmpty {
            return "Noch keine Mahlzeit auf diesem Tag."
        }

        if store.caloriesConsumed > store.caloriesTarget {
            return "\(store.caloriesConsumed - store.caloriesTarget) kcal über Ziel."
        }

        return "\(store.caloriesRemaining) kcal Restbudget für den Tag."
    }

    private func ringSummaryPill(title: String, value: String, tint: Color) -> some View {
        VStack(spacing: 4) {
            HStack(spacing: 6) {
                Circle()
                    .fill(tint)
                    .frame(width: 6, height: 6)
                Text(title)
                    .font(AboLifeTypography.micro)
                    .foregroundStyle(AboLifeColors.secondaryText)
            }

            Text(value)
                .font(AboLifeTypography.caption.weight(.semibold))
                .foregroundStyle(AboLifeColors.primaryText)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.82)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .frame(maxWidth: 150)
        .background {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(AboLifeColors.quietFill)
                .overlay {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(AboLifeColors.glassStrokeMuted, lineWidth: 0.6)
                }
        }
    }
}

private struct NutritionEntryRow: View {
    let entry: NutritionEntryRecord
    let delete: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 8) {
                    Text(entry.title)
                        .font(AboLifeTypography.body.weight(.semibold))
                        .foregroundStyle(AboLifeColors.primaryText)
                        .lineLimit(1)

                    Text(entry.occurredAt.formatted(.dateTime.hour().minute()))
                        .font(AboLifeTypography.micro)
                        .foregroundStyle(AboLifeColors.tertiaryText)
                        .monospacedDigit()
                }

                if let note = entry.note, !note.isEmpty {
                    Text(note)
                        .font(AboLifeTypography.caption)
                        .foregroundStyle(AboLifeColors.secondaryText)
                        .lineLimit(2)
                }
            }

            Spacer(minLength: 12)

            VStack(alignment: .trailing, spacing: 3) {
                Text("\(entry.caloriesKcal) kcal")
                    .font(AboLifeTypography.caption.weight(.semibold))
                    .foregroundStyle(AboLifeColors.primaryText)
                    .monospacedDigit()

                Text("\(Int(entry.proteinG)) g Protein")
                    .font(AboLifeTypography.micro)
                    .foregroundStyle(AboLifeColors.secondaryText)
                    .monospacedDigit()
            }

            Button(role: .destructive, action: delete) {
                Image(systemName: "trash")
                    .font(.system(size: 13, weight: .semibold))
            }
            .buttonStyle(.borderless)
            .help("Löschen")
        }
        .padding(.horizontal, 13)
        .padding(.vertical, 11)
        .background {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(AboLifeColors.quietFill)
                .overlay {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(AboLifeColors.glassStrokeMuted, lineWidth: 0.6)
                }
        }
        .contextMenu {
            Button(role: .destructive, action: delete) {
                Label("Löschen", systemImage: "trash")
            }
        }
    }
}

struct NutritionView_Previews: PreviewProvider {
    static var previews: some View {
        NutritionView(database: nil)
            .frame(width: 1000, height: 720)
    }
}
