import AppKit
import SwiftUI

struct MenuBarQuickPanelView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.openWindow) private var openWindow
    @EnvironmentObject private var navigation: AppNavigationCoordinator
    @StateObject private var store: DashboardStore
    @State private var quickActions = false
    @State private var selected: QuickAddKind?
    init(database: AppDatabase?) { _store = StateObject(wrappedValue: DashboardStore(database: database)) }
    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Button {
                    openWindow(id: AppNavigationCoordinator.mainWindowID)
                    NSApp.activate(ignoringOtherApps: true)
                } label: {
                    AboLifeBrandMark()
                }.buttonStyle(.plain).accessibilityLabel("AboLife öffnen")
                Spacer()
                Text("AboLife").font(.headline)
            }
            HStack(spacing: 20) {
                CoreRingView(
                    progress: store.snapshot.coreProgress, lineWidth: 6, tint: AboLifeColors.review, labelText: "Heute"
                )
                .frame(width: 108, height: 108)
                MenuBarBudgetRing(
                    monthlyBudget: store.state.monthlyBudget, dailyBudgetRemaining: store.state.dailyBudgetRemaining)
            }
            Button {
                withAnimation(AboLifeMotion.animation(for: .navigation, reduceMotion: reduceMotion)) {
                    quickActions.toggle()
                }
            } label: {
                Label("Schnellerfassung", systemImage: quickActions ? "chevron.up" : "plus")
            }
            .buttonStyle(.bordered)
            .accessibilityValue(quickActions ? "Ausgeklappt" : "Eingeklappt")
            if quickActions {
                ForEach(QuickAddAction.dashboardActions) { action in
                    Button {
                        selected = action.kind
                    } label: {
                        Label(action.title, systemImage: action.systemImage).frame(
                            maxWidth: .infinity, alignment: .leading)
                    }.buttonStyle(.bordered)
                }
            }
        }
        .padding(16).frame(width: 288).background(AboLifeColors.pageBackground)
        .onAppear {
            store.refreshFromPersistence(); quickActions = false
        }
        .sheet(item: $selected) { QuickAddSheet(store: store, initialKind: $0) }
    }
}

private struct MenuBarBudgetRing: View {
    let monthlyBudget: Double
    let dailyBudgetRemaining: Double

    private var availableToday: Double {
        dailyBudgetRemaining.isFinite ? max(dailyBudgetRemaining, 0) : 0
    }

    private var availableFraction: Double {
        guard monthlyBudget.isFinite, monthlyBudget > 0 else { return 0 }
        return min(availableToday / monthlyBudget, 1)
    }

    private var amountText: String {
        availableToday.formatted(.currency(code: "EUR"))
    }

    var body: some View {
        ZStack {
            // The full ring is the monthly budget; only today's available share is green.
            Circle()
                .stroke(AboLifeColors.subtleFill, lineWidth: 6)

            if availableFraction > 0 {
                Circle()
                    .trim(from: 0, to: availableFraction)
                    .stroke(AboLifeColors.finance, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .aboLifeMotion(value: availableFraction)
            }

            VStack(spacing: 4) {
                Text(amountText)
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(AboLifeColors.primaryText)
                    .monospacedDigit()
                    .aboLifeNumericTransition(value: availableToday)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                Text("heute frei")
                    .font(AboLifeTypography.micro)
                    .foregroundStyle(AboLifeColors.secondaryText)
            }
            .padding(.horizontal, 12)
        }
        .frame(width: 108, height: 108)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Budget: heute verfügbar")
        .accessibilityValue(amountText)
        .help("Grau: Monatsbudget. Türkis: heute verfügbarer Anteil.")
    }
}
