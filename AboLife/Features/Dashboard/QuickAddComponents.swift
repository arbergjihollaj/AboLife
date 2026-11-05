import SwiftUI

struct QuickAddFormCard<Content: View>: View {
    @Environment(\.aboLifeStyle) private var designStyle
    let systemImage: String
    let title: String
    let content: Content

    init(systemImage: String, title: String, @ViewBuilder content: () -> Content) {
        self.systemImage = systemImage
        self.title = title
        self.content = content()
    }

    var body: some View {
        AboLifeCard(isProminent: true) {
            VStack(alignment: .leading, spacing: 12) {
                Label(title, systemImage: systemImage)
                    .font(AboLifeTypography.cardTitle)
                    .foregroundStyle(designStyle.colors.primaryText)

                content
            }
        }
    }
}

struct QuickAddSection<Content: View>: View {
    @Environment(\.aboLifeStyle) private var designStyle
    let title: String
    let systemImage: String
    let content: Content

    init(title: String, systemImage: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.systemImage = systemImage
        self.content = content()
    }

    var body: some View {
        AboLifeCard(isProminent: true) {
            VStack(alignment: .leading, spacing: 12) {
                Label(title, systemImage: systemImage)
                    .font(AboLifeTypography.cardTitle)
                    .foregroundStyle(designStyle.colors.primaryText)

                content
            }
        }
    }
}

struct QuickAddChip: View {
    @Environment(\.aboLifeStyle) private var designStyle
    let title: String
    let systemImage: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: systemImage)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(designStyle.colors.secondaryText)
                    .frame(width: 20)

                Text(title)
                    .font(AboLifeTypography.caption.weight(.medium))
                    .foregroundStyle(designStyle.colors.primaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 12)
            .frame(maxWidth: .infinity, minHeight: 44)
            .background(designStyle.colors.elevatedCardBackground, in: RoundedRectangle(cornerRadius: 8))
            .overlay {
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(designStyle.colors.glassStrokeMuted.opacity(0.72), lineWidth: 0.7)
            }
        }
        .buttonStyle(.plain)
    }
}

struct QuickAddSubmitButton: View {
    @Environment(\.aboLifeStyle) private var designStyle
    let title: String
    let systemImage: String
    let action: () -> Void

    var body: some View {
        HStack {
            Spacer()
            Button(action: action) {
                Label(title, systemImage: systemImage)
                    .font(.system(size: 14, weight: .semibold))
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .tint(designStyle.colors.action)
        }
    }
}

struct QuickAddStatusMessage: View {
    @Environment(\.aboLifeStyle) private var designStyle
    let message: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(designStyle.colors.habits)
            Text(message)
                .font(AboLifeTypography.caption.weight(.semibold))
                .foregroundStyle(designStyle.colors.primaryText)
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(designStyle.colors.elevatedCardBackground, in: RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(designStyle.colors.glassStrokeMuted.opacity(0.65), lineWidth: 0.7)
        }
    }
}

enum QuickHabitAction: String, Identifiable {
    case waterUp
    case learningUp
    case sleepDone

    var id: String { rawValue }

    var habitKey: String {
        switch self {
        case .waterUp:
            return "water"
        case .learningUp:
            return "learning"
        case .sleepDone:
            return "sleep"
        }
    }

    var delta: Double {
        switch self {
        case .waterUp:
            return 0.25
        case .learningUp:
            return 15
        case .sleepDone:
            return 1
        }
    }

    var title: String {
        switch self {
        case .waterUp:
            return "Wasser +0.25 L"
        case .learningUp:
            return "Lernen +15 Min."
        case .sleepDone:
            return "Schlafroutine erledigt"
        }
    }

    var successMessage: String {
        switch self {
        case .waterUp:
            return "+0.25 L Wasser"
        case .learningUp:
            return "+15 Min. Lernen"
        case .sleepDone:
            return "Schlafroutine erledigt"
        }
    }

    var systemImage: String {
        FixedHabit.defaultDefinition(for: habitKey)?.systemImage ?? "checkmark"
    }

    var tint: Color {
        FixedHabit.defaultDefinition(for: habitKey)?.accent ?? AboLifeColors.habits
    }

    static let generalMenuActions: [QuickHabitAction] = [.waterUp, .learningUp, .sleepDone]
}

@ViewBuilder
func labeledTextField(_ title: String, text: Binding<String>) -> some View {
    VStack(alignment: .leading, spacing: 6) {
        Text(title)
            .font(AboLifeTypography.caption)
            .foregroundStyle(AboLifeColors.secondaryText)

        TextField(title, text: text)
            .textFieldStyle(.roundedBorder)
    }
}

func parseDouble(_ value: String) -> Double {
    let parsed = Double(value.replacingOccurrences(of: ",", with: ".").trimmingCharacters(in: .whitespacesAndNewlines)) ?? 0
    return parsed.isFinite ? parsed : 0
}
