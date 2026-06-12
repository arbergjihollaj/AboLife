import SwiftUI

struct FinanceView: View {
    @StateObject private var store: FinanceStore

    init(database: AppDatabase?) {
        _store = StateObject(wrappedValue: FinanceStore(database: database))
    }

    var body: some View {
        ZStack {
            AboLifePremiumBackground()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    header
                    budgetOverview
                    budgetDetails
                    expensesSection
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
                Text("Finanzen")
                    .font(AboLifeTypography.dashboardTitle)
                    .foregroundStyle(AboLifeColors.primaryText)

                Text(store.monthSubtitle)
                    .font(AboLifeTypography.body)
                    .foregroundStyle(AboLifeColors.secondaryText)
            }

            Spacer()

            Button {
                store.selectCurrentMonth()
            } label: {
                Image(systemName: "calendar")
                    .font(.system(size: 14, weight: .semibold))
            }
            .buttonStyle(.bordered)
            .help("Dieser Monat")
            .disabled(store.isCurrentMonth)

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

    private var budgetOverview: some View {
        AboLifeCard(isProminent: true) {
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .center, spacing: 24) {
                    budgetRing(size: 158, lineWidth: 14)
                    overviewCopy
                    Spacer(minLength: 0)
                }

                VStack(alignment: .leading, spacing: 18) {
                    budgetRing(size: 142, lineWidth: 12)
                    overviewCopy
                }
            }
        }
    }

    private func budgetRing(size: CGFloat, lineWidth: CGFloat) -> some View {
        CoreRingView(
            progress: store.budgetProgress,
            lineWidth: lineWidth,
            tint: store.isOverBudget ? AboLifeColors.habits : AboLifeColors.finance,
            valueText: "\(Int(store.budgetProgress * 100))%",
            labelText: "Budget genutzt"
        )
        .frame(width: size, height: size)
    }

    private var overviewCopy: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Label("Monatsbudget", systemImage: "eurosign.circle")
                    .font(AboLifeTypography.cardTitle)
                    .foregroundStyle(AboLifeColors.primaryText)

                AboLifeGlassCapsule {
                    Text(store.currency)
                        .font(AboLifeTypography.micro)
                        .foregroundStyle(AboLifeColors.finance)
                }
            }

            Text("\(store.formatAmount(store.remainingBudget)) Restbudget")
                .font(AboLifeTypography.heroMessage)
                .foregroundStyle(AboLifeColors.primaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.82)

            Text("\(store.formatAmount(store.monthlySpent)) / \(store.formatAmount(store.monthlyBudget)) ausgegeben")
                .font(AboLifeTypography.body)
                .foregroundStyle(AboLifeColors.secondaryText)
                .monospacedDigit()

            BudgetProgressBar(spent: store.monthlySpent, budget: store.monthlyBudget)
                .frame(maxWidth: 430)

            Text(store.statusMessage)
                .font(AboLifeTypography.body)
                .foregroundStyle(AboLifeColors.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: 620, alignment: .leading)
    }

    private var budgetDetails: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 12) {
                detailPill(title: "Ausgegeben", value: store.formatAmount(store.monthlySpent), systemImage: "cart", tint: AboLifeColors.finance)
                detailPill(title: "Restbudget", value: store.formatAmount(store.remainingBudget), systemImage: "wallet.pass", tint: AboLifeColors.review)
                detailPill(title: "Pro Tag", value: store.formatAmount(store.dailyBudgetRemaining), systemImage: "calendar", tint: AboLifeColors.protein)
                detailPill(title: "Ausgaben", value: "\(store.entries.count)", systemImage: "list.bullet", tint: AboLifeColors.habits)
            }

            VStack(spacing: 10) {
                detailPill(title: "Ausgegeben", value: store.formatAmount(store.monthlySpent), systemImage: "cart", tint: AboLifeColors.finance)
                detailPill(title: "Restbudget", value: store.formatAmount(store.remainingBudget), systemImage: "wallet.pass", tint: AboLifeColors.review)
                detailPill(title: "Pro Tag", value: store.formatAmount(store.dailyBudgetRemaining), systemImage: "calendar", tint: AboLifeColors.protein)
                detailPill(title: "Ausgaben", value: "\(store.entries.count)", systemImage: "list.bullet", tint: AboLifeColors.habits)
            }
        }
    }

    private var expensesSection: some View {
        AboLifeCard(isProminent: true) {
            VStack(alignment: .leading, spacing: 13) {
                HStack {
                    Label("Ausgaben diesen Monat", systemImage: "list.bullet.rectangle")
                        .font(AboLifeTypography.cardTitle)
                        .foregroundStyle(AboLifeColors.primaryText)

                    Spacer()

                    AboLifeGlassCapsule {
                        Text(store.formatAmount(store.monthlySpent))
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
                            FinanceEntryRow(entry: entry) {
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
            Text("Diesen Monat noch keine Ausgaben erfasst.")
                .font(AboLifeTypography.body.weight(.semibold))
                .foregroundStyle(AboLifeColors.primaryText)

            Text("Nutze Quick Add, um eine Ausgabe einzutragen.")
                .font(AboLifeTypography.caption)
                .foregroundStyle(AboLifeColors.secondaryText)
        }
        .frame(maxWidth: .infinity, minHeight: 112, alignment: .leading)
    }

    private func errorState(_ message: String) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            Text("Finanzdaten konnten nicht geladen werden.")
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
            .tint(AboLifeColors.finance)
        }
        .frame(maxWidth: .infinity, minHeight: 112, alignment: .leading)
    }

    private func detailPill(title: String, value: String, systemImage: String, tint: Color) -> some View {
        HStack(spacing: 9) {
            Image(systemName: systemImage)
                .foregroundStyle(tint)
                .frame(width: 18)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(AboLifeTypography.micro)
                    .foregroundStyle(AboLifeColors.secondaryText)

                Text(value)
                    .font(AboLifeTypography.caption.weight(.semibold))
                    .foregroundStyle(AboLifeColors.primaryText)
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, minHeight: 58, alignment: .leading)
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

private struct FinanceEntryRow: View {
    let entry: FinanceEntryRecord
    let delete: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 8) {
                    Text(entry.title)
                        .font(AboLifeTypography.body.weight(.semibold))
                        .foregroundStyle(AboLifeColors.primaryText)
                        .lineLimit(1)

                    Text(entry.occurredAt.formatted(.dateTime.day().month(.abbreviated).hour().minute()))
                        .font(AboLifeTypography.micro)
                        .foregroundStyle(AboLifeColors.tertiaryText)
                        .monospacedDigit()
                }

                HStack(spacing: 7) {
                    Text(entry.category)
                        .font(AboLifeTypography.micro)
                        .foregroundStyle(AboLifeColors.finance)

                    if let note = entry.note, !note.isEmpty {
                        Text(note)
                            .font(AboLifeTypography.caption)
                            .foregroundStyle(AboLifeColors.secondaryText)
                            .lineLimit(1)
                    }
                }
            }

            Spacer(minLength: 12)

            Text("\(Int(entry.amount.rounded())) \(entry.currency)")
                .font(AboLifeTypography.caption.weight(.semibold))
                .foregroundStyle(AboLifeColors.primaryText)
                .monospacedDigit()

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

struct FinanceView_Previews: PreviewProvider {
    static var previews: some View {
        FinanceView(database: nil)
            .frame(width: 1000, height: 720)
    }
}
