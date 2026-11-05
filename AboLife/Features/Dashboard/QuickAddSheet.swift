import SwiftUI

struct QuickAddSheet: View {
    @Environment(\.aboLifeStyle) private var designStyle
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
        VStack(alignment: .leading, spacing: 16) {
            header
                .padding(.horizontal, 24)
                .padding(.top, 24)

            ScrollView(.vertical) {
                VStack(alignment: .leading, spacing: 16) {
                    flow(for: selectedKind ?? .general)

                    if let error = store.errorMessage {
                        AboLifeNotice(title: "Nicht gespeichert", message: error)
                    } else if let statusMessage {
                        QuickAddStatusMessage(message: statusMessage)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
            }
            .scrollIndicators(.automatic)
        }
        .frame(minWidth: 460, idealWidth: 540, maxWidth: 620, minHeight: 360, idealHeight: 560, maxHeight: 640)
        .background { AboLifePremiumBackground() }
        .aboLifeMotion(value: selectedKind, kind: .navigation)
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(headerTitle)
                    .font(AboLifeTypography.dashboardTitle)
                    .foregroundStyle(designStyle.colors.primaryText)
                Text(headerSubtitle)
                    .font(AboLifeTypography.caption)
                    .foregroundStyle(designStyle.colors.secondaryText)
            }

            Spacer()

            if selectedKind != nil && selectedKind != .general {
                Button {
                    selectedKind = .general
                    statusMessage = nil
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(designStyle.colors.secondaryText)
                }
                .buttonStyle(.bordered)
                .accessibilityLabel("Zurück")
            }

            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(designStyle.colors.secondaryText)
            }
            .buttonStyle(.bordered)
            .accessibilityLabel("Schließen")
            .keyboardShortcut(.cancelAction)
        }
    }

    private var headerTitle: String {
        switch selectedKind ?? .general {
        case .general:
            return "Schnellerfassung"
        case .workout:
            return "Training eintragen"
        case .expense:
            return "Ausgabe eintragen"
        case .habit:
            return "Gewohnheit aktualisieren"
        case .weight:
            return "Gewicht eintragen"
        }
    }

    private var headerSubtitle: String {
        switch selectedKind ?? .general {
        case .habit:
            return "Heute schnell Fortschritt eintragen"
        case .general:
            return "Training, Ausgaben, Gewicht und Gewohnheiten"
        default:
            return "Wird auf deinem Mac gespeichert"
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
        case .workout:
            QuickAddTrainingPanel(store: store, dismiss: dismiss, setStatus: setStatus)
        case .expense:
            QuickAddExpensePanel(store: store, dismiss: dismiss, setStatus: setStatus)
        case .habit:
            QuickAddHabitPanel(store: store, setStatus: setStatus)
        case .weight:
            QuickAddWeightPanel(store: store, dismiss: dismiss, setStatus: setStatus)
        }
    }

    private func handleQuickHabitAction(_ action: QuickHabitAction) {
        switch action {
        case .sleepDone:
            store.setSleepRoutine(isCompleted: true)
        default:
            _ = store.applyHabitDelta(habitKey: action.habitKey, delta: action.delta)
        }
        statusMessage = store.errorMessage == nil ? action.successMessage : nil
    }

    private func setStatus(_ message: String) {
        statusMessage = message
    }
}
