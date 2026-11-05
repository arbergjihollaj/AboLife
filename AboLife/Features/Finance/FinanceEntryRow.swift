import SwiftUI

struct FinanceEntryRow: View {
    @Environment(\.aboLifeStyle) private var designStyle
    let entry: FinanceEntryRecord
    let delete: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 8) {
                    Text(entry.title)
                        .font(AboLifeTypography.body.weight(.semibold))
                        .foregroundStyle(designStyle.colors.primaryText)
                        .lineLimit(1)

                    Text(entry.occurredAt.formatted(.dateTime.day().month(.abbreviated).hour().minute()))
                        .font(AboLifeTypography.micro)
                        .foregroundStyle(designStyle.colors.tertiaryText)
                        .monospacedDigit()
                }

                HStack(spacing: 7) {
                    Text(entry.category)
                        .font(AboLifeTypography.micro)
                        .foregroundStyle(designStyle.colors.finance)

                    if let note = entry.note, !note.isEmpty {
                        Text(note)
                            .font(AboLifeTypography.caption)
                            .foregroundStyle(designStyle.colors.secondaryText)
                            .lineLimit(1)
                    }
                }
            }

            Spacer(minLength: 12)

            Text((entry.amount < 0 ? "+" : "−") + abs(entry.amount).formatted(.currency(code: entry.currency)))
                .font(AboLifeTypography.caption.weight(.semibold))
                .foregroundStyle(entry.amount < 0 ? designStyle.colors.positive : designStyle.colors.primaryText)
                .monospacedDigit()
                .accessibilityLabel(
                    "\(entry.amount < 0 ? "Einnahme" : "Ausgabe"): \(abs(entry.amount).formatted(.currency(code: entry.currency)))"
                )

            Button(role: .destructive, action: delete) {
                Image(systemName: "trash")
                    .font(.system(size: 13, weight: .semibold))
            }
            .buttonStyle(.borderless)
            .accessibilityLabel("Buchung löschen: \(entry.title)")
            .help("Löschen")
        }
        .padding(.horizontal, 13)
        .padding(.vertical, 11)
        .background {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(designStyle.colors.quietFill)
                .overlay {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(designStyle.colors.glassStrokeMuted, lineWidth: 0.6)
                }
        }
        .contextMenu {
            Button(role: .destructive, action: delete) {
                Label("Löschen", systemImage: "trash")
            }
        }
    }
}
