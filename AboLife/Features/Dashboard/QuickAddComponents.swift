import SwiftUI

struct QuickAddFormCard<Content: View>: View {
    let tint: Color
    let systemImage: String
    let title: String
    let content: Content

    init(tint: Color, systemImage: String, title: String, @ViewBuilder content: () -> Content) {
        self.tint = tint
        self.systemImage = systemImage
        self.title = title
        self.content = content()
    }

    var body: some View {
        AboLifeCard(isProminent: true) {
            VStack(alignment: .leading, spacing: 13) {
                Label(title, systemImage: systemImage)
                    .font(AboLifeTypography.cardTitle)
                    .foregroundStyle(AboLifeColors.primaryText)

                content
            }
        }
    }
}

struct QuickAddSection<Content: View>: View {
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
                    .foregroundStyle(AboLifeColors.primaryText)

                content
            }
        }
    }
}

struct QuickAddChip: View {
    let title: String
    let systemImage: String
    let tint: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 9) {
                Image(systemName: systemImage)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(tint)
                    .frame(width: 24, height: 24)
                    .background(tint.opacity(0.12), in: Circle())

                Text(title)
                    .font(AboLifeTypography.caption.weight(.medium))
                    .foregroundStyle(AboLifeColors.primaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 12)
            .frame(maxWidth: .infinity, minHeight: 44)
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(AboLifeColors.glassStrokeMuted.opacity(0.72), lineWidth: 0.7)
            }
        }
        .buttonStyle(.plain)
    }
}

struct QuickAddSubmitButton: View {
    let title: String
    let systemImage: String
    let tint: Color
    let action: () -> Void

    var body: some View {
        HStack {
            Spacer()
            Button(action: action) {
                Label(title, systemImage: systemImage)
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .tint(tint)
        }
    }
}

struct QuickAddStatusMessage: View {
    let message: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(AboLifeColors.habits)
            Text(message)
                .font(AboLifeTypography.caption.weight(.semibold))
                .foregroundStyle(AboLifeColors.primaryText)
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(AboLifeColors.glassStrokeMuted.opacity(0.65), lineWidth: 0.7)
        }
    }
}

enum QuickHabitAction: String, Identifiable {
    case waterUp
    case nutritionUp
    case learningUp
    case sleepDone

    var id: String { rawValue }

    var habitKey: String {
        switch self {
        case .waterUp:
            return "water"
        case .nutritionUp:
            return "nutrition"
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
        case .nutritionUp:
            return 1
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
        case .nutritionUp:
            return "Ernaehrung +1 Mahlzeit"
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
        case .nutritionUp:
            return "+1 Mahlzeit"
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

    static let generalMenuActions: [QuickHabitAction] = [.waterUp, .nutritionUp, .learningUp, .sleepDone]
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
