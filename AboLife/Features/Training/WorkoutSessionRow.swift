import SwiftUI

struct WorkoutSessionRow: View {
    @Environment(\.aboLifeStyle) private var designStyle
    let session: WorkoutSessionRecord
    let delete: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 8) {
                    Text(session.workoutType)
                        .font(AboLifeTypography.body.weight(.semibold))
                        .foregroundStyle(designStyle.colors.primaryText)
                        .lineLimit(1)

                    Text(session.occurredAt.formatted(.dateTime.weekday(.abbreviated).hour().minute()))
                        .font(AboLifeTypography.micro)
                        .foregroundStyle(designStyle.colors.tertiaryText)
                        .monospacedDigit()
                }

                if let note = session.note, !note.isEmpty {
                    Text(note)
                        .font(AboLifeTypography.caption)
                        .foregroundStyle(designStyle.colors.secondaryText)
                        .lineLimit(2)
                }
            }

            Spacer(minLength: 12)

            VStack(alignment: .trailing, spacing: 3) {
                Text("\(session.durationMin) Min.")
                    .font(AboLifeTypography.caption.weight(.semibold))
                    .foregroundStyle(designStyle.colors.primaryText)
                    .monospacedDigit()

                Text(session.status == "done" ? "Abgeschlossen" : session.status.capitalized)
                    .font(AboLifeTypography.micro)
                    .foregroundStyle(
                        session.status == "done" ? designStyle.colors.training : designStyle.colors.secondaryText)
            }

            Button(role: .destructive, action: delete) {
                Image(systemName: "trash")
                    .font(.system(size: 13, weight: .semibold))
            }
            .buttonStyle(.borderless)
            .accessibilityLabel("Training löschen: \(session.workoutType)")
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
