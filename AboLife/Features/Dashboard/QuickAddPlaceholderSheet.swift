import SwiftUI

struct QuickAddPlaceholderSheet: View {
    @ObservedObject var store: DashboardStore
    let initialKind: QuickAddKind?

    @Environment(\.dismiss) private var dismiss
    @State private var selectedKind: QuickAddKind?
    @State private var statusMessage: String?

    init(store: DashboardStore, initialKind: QuickAddKind? = nil) {
        self.store = store
        self.initialKind = initialKind
        _selectedKind = State(initialValue: initialKind)
    }

    var body: some View {
        ZStack {
            AboLifePremiumBackground()

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    header
                    flow(for: selectedKind ?? .general)

                    if let statusMessage {
                        QuickAddStatusMessage(message: statusMessage)
                    }
                }
                .padding(24)
                .frame(width: 560, alignment: .leading)
            }
            .scrollIndicators(.hidden)
            .frame(width: 560)
            .frame(maxHeight: 720)
        }
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 5) {
                Text(headerTitle)
                    .font(AboLifeTypography.dashboardTitle)
                    .foregroundStyle(AboLifeColors.primaryText)
                Text(headerSubtitle)
                    .font(AboLifeTypography.caption)
                    .foregroundStyle(AboLifeColors.secondaryText)
            }

            Spacer()

            if selectedKind != nil && selectedKind != .general {
                Button {
                    selectedKind = .general
                    statusMessage = nil
                } label: {
                    Image(systemName: "chevron.left.circle.fill")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(AboLifeColors.secondaryText)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Zurueck")
            }

            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(AboLifeColors.secondaryText)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Schliessen")
        }
    }

    private var headerTitle: String {
        switch selectedKind ?? .general {
        case .general:
            return "Quick Actions"
        case .meal:
            return "Mahlzeit eintragen"
        case .workout:
            return "Training eintragen"
        case .expense:
            return "Ausgabe eintragen"
        case .habit:
            return "Gewohnheit aktualisieren"
        case .weight:
            return "Gewicht merken"
        case .note:
            return "Tagesnotiz"
        }
    }

    private var headerSubtitle: String {
        switch selectedKind ?? .general {
        case .habit:
            return "Heute schnell Fortschritt eintragen"
        case .general:
            return "Kompakte lokale Erfassung"
        default:
            return "Speichert lokal in SQLite"
        }
    }

    @ViewBuilder
    private func flow(for kind: QuickAddKind) -> some View {
        switch kind {
        case .general:
            QuickAddGeneralMenu(
                select: { selectedKind = $0; statusMessage = nil },
                quickHabit: handleQuickHabitAction
            )
        case .meal:
            QuickAddMealPanel(store: store, dismiss: dismiss, setStatus: setStatus)
        case .workout:
            QuickAddTrainingPanel(store: store, dismiss: dismiss, setStatus: setStatus)
        case .expense:
            QuickAddExpensePanel(store: store, dismiss: dismiss, setStatus: setStatus)
        case .habit:
            QuickAddHabitPanel(store: store, setStatus: setStatus)
        case .weight:
            QuickAddWeightPanel(store: store, dismiss: dismiss, setStatus: setStatus)
        case .note:
            QuickAddNotePanel(store: store, dismiss: dismiss, setStatus: setStatus)
        }
    }

    private func handleQuickHabitAction(_ action: QuickHabitAction) {
        switch action {
        case .sleepDone:
            store.setSleepRoutine(isCompleted: true)
        default:
            _ = store.applyHabitDelta(habitKey: action.habitKey, delta: action.delta)
        }
        statusMessage = action.successMessage
    }

    private func setStatus(_ message: String) {
        statusMessage = message
    }
}
