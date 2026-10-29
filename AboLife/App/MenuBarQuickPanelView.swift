import AppKit
import SwiftUI

struct MenuBarQuickPanelView: View {
    @Environment(\.openWindow) private var openWindow
    @EnvironmentObject private var navigation: AppNavigationCoordinator
    @StateObject private var store: DashboardStore
    @State private var quickActions = false
    @State private var selected: QuickAddKind?
    init(database: AppDatabase?) { _store = StateObject(wrappedValue: DashboardStore(database: database)) }
    var body: some View {
        VStack(spacing: 18) {
            HStack {
                Button {
                    openWindow(id: AppNavigationCoordinator.mainWindowID)
                    NSApp.activate(ignoringOtherApps: true)
                } label: {
                    Image("AppMark").resizable().frame(width: 30, height: 30)
                }.buttonStyle(.plain).accessibilityLabel("AboLife öffnen")
                Spacer()
                Text("AboLife").font(.headline)
            }
            CoreRingView(progress: store.snapshot.coreProgress, lineWidth: 9, tint: AboLifeColors.review, labelText: "Heute")
                .frame(width: 112, height: 112)
            MenuBarBudgetRing(monthlyBudget: store.state.monthlyBudget, dailyBudgetRemaining: store.state.dailyBudgetRemaining)
            Button { quickActions.toggle() } label: { Label("Quick Actions", systemImage: "plus.circle") }.buttonStyle(.bordered)
            if quickActions {
                ForEach(QuickAddAction.dashboardActions) { action in
                    Button { selected = action.kind } label: { Label(action.title, systemImage: action.systemImage).frame(maxWidth: .infinity, alignment: .leading) }.buttonStyle(.bordered)
                }
            }
        }
        .padding(18).frame(width: 292).background(.ultraThinMaterial).preferredColorScheme(.dark)
        .onAppear { store.refreshFromPersistence(); quickActions = false }
        .sheet(item: $selected) { QuickAddPlaceholderSheet(store: store, initialKind: $0) }
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
                .stroke(Color.gray.opacity(0.24), lineWidth: 8)

            if availableFraction > 0 {
                Circle()
                    .trim(from: 0, to: availableFraction)
                    .stroke(Color.green, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .rotationEffect(.degrees(-90))
            }

            VStack(spacing: 5) {
                Text(amountText)
                    .font(.system(size: 22, weight: .medium, design: .rounded))
                    .foregroundStyle(AboLifeColors.primaryText)
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                Text("heute frei")
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundStyle(AboLifeColors.secondaryText)
            }
            .padding(.horizontal, 14)
        }
        .frame(width: 144, height: 144)
        .padding(6)
        .animation(.easeInOut(duration: 0.2), value: availableFraction)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Budget: heute verfügbar")
        .accessibilityValue(amountText)
        .help("Grau: Monatsbudget. Grün: heute verfügbarer Anteil.")
    }
}
