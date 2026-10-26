import AppKit
import SwiftUI

private enum QuickPanelInput: String, Identifiable {
    case meal
    case weight
    case expense

    var id: String { rawValue }

    var title: String {
        switch self {
        case .meal:
            return "Mahlzeit hinzufügen"
        case .weight:
            return "Gewicht eintragen"
        case .expense:
            return "Ausgabe hinzufügen"
        }
    }

    var systemImage: String {
        switch self {
        case .meal:
            return "fork.knife"
        case .weight:
            return "scalemass"
        case .expense:
            return "eurosign.circle"
        }
    }
}

struct MenuBarQuickPanelView: View {
    @Environment(\.openWindow) private var openWindow
    @EnvironmentObject private var navigation: AppNavigationCoordinator
    @EnvironmentObject private var telegram: TelegramAppCoordinator

    @StateObject private var store: DashboardStore
    @State private var activeInput: QuickPanelInput?
    @State private var isQuickActionsExpanded = false
    @State private var mealName = ""
    @State private var mealCalories = ""
    @State private var mealProtein = ""
    @State private var weight = ""
    @State private var expenseTitle = ""
    @State private var expenseAmount = ""
    @State private var expenseCategory = ""
    @State private var validationMessage: String?
    @State private var toastMessage: String?
    private let database: AppDatabase?

    init(database: AppDatabase?) {
        self.database = database
        _store = StateObject(wrappedValue: DashboardStore(database: database))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
            dayStatus
            financeStatus
            quickActions
        }
        .padding(12)
        .frame(width: 292)
        .background { panelBackground }
        .preferredColorScheme(.dark)
        .onAppear {
            isQuickActionsExpanded = false
            closeInput()
            refreshPanel()
        }
    }

    @ViewBuilder
    private var panelBackground: some View {
        let shape = RoundedRectangle(cornerRadius: 22, style: .continuous)
        if #available(macOS 26.0, *) {
            Color.clear
                .glassEffect(.regular.tint(AboLifeColors.pageBackground.opacity(0.6)), in: shape)
        } else {
            AboLifeLiquidGlassSurface(shape: shape)
                .overlay { shape.fill(AboLifeColors.pageBackground.opacity(0.35)) }
        }
    }

    private var foregroundCardBackground: some View {
        AboLifeColors.premiumBackgroundGradient
            .overlay(AboLifeColors.elevatedCardBackground)
    }

    private var header: some View {
        HStack(spacing: 10) {
            Button {
                open(.dashboard)
            } label: {
                Text("M")
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(AboLifeColors.review)
                    .frame(width: 28, height: 28)
                    .background { foregroundCardBackground.clipShape(Circle()) }
                    .overlay {
                        Circle().strokeBorder(AboLifeColors.glassStrokeMuted, lineWidth: 1)
                    }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Hauptfenster öffnen")
            .help("Hauptfenster öffnen")

            VStack(alignment: .leading, spacing: 1) {
                Text("AboLife 0.2")
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(AboLifeColors.primaryText)
                Text(Date.now.formatted(date: .abbreviated, time: .omitted))
                    .font(AboLifeTypography.micro)
                    .foregroundStyle(AboLifeColors.secondaryText)
            }

            Spacer(minLength: 0)

            if let toastMessage {
                Text(toastMessage)
                    .font(AboLifeTypography.micro)
                    .foregroundStyle(AboLifeColors.protein)
                    .lineLimit(1)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(AboLifeColors.quietFill, in: Capsule())
                    .transition(.opacity.combined(with: .move(edge: .trailing)))
            }
        }
    }

    private var dayStatus: some View {
        panelSection("Tagesstatus", systemImage: "gauge.with.dots.needle.67percent") {
            MenuBarNutritionDoubleRing(
                caloriesConsumed: store.state.caloriesConsumed,
                caloriesTarget: store.state.caloriesTarget,
                proteinConsumed: store.state.proteinConsumed,
                proteinTarget: store.state.proteinTarget,
                caloriesProgress: progress(Double(store.state.caloriesConsumed), Double(store.state.caloriesTarget)),
                proteinProgress: progress(store.state.proteinConsumed, store.state.proteinTarget)
            )
            .frame(maxWidth: .infinity)
        }
    }

    private var financeStatus: some View {
        panelSection("Budget", systemImage: "wallet.pass") {
            MenuBarBudgetRing(
                monthlyBudget: store.state.monthlyBudget,
                dailyBudgetRemaining: store.state.dailyBudgetRemaining
            )
            .frame(maxWidth: .infinity)
        }
    }

    private var quickActions: some View {
        Button {
            isQuickActionsExpanded.toggle()
        } label: {
            HStack(spacing: 8) {
                Label("Quick Actions", systemImage: "bolt.circle")
                Spacer(minLength: 0)
                Image(systemName: isQuickActionsExpanded ? "chevron.up" : "chevron.down")
            }
            .font(AboLifeTypography.caption.weight(.semibold))
            .foregroundStyle(AboLifeColors.primaryText)
            .padding(10)
            .frame(maxWidth: .infinity, minHeight: 36)
            .background {
                foregroundCardBackground
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(AboLifeColors.glassStrokeMuted, lineWidth: 1)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityValue(isQuickActionsExpanded ? "Ausgeklappt" : "Eingeklappt")
        .popover(isPresented: $isQuickActionsExpanded, arrowEdge: .bottom) {
            ScrollView {
                quickActionContent
                    .padding(12)
            }
            .frame(width: 280, height: 420)
            .background(AboLifeColors.premiumBackgroundGradient)
            .preferredColorScheme(.dark)
        }
        .onChange(of: isQuickActionsExpanded) { _, expanded in
            if !expanded { closeInput() }
        }
    }

    private var quickActionContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                actionButton("Mahlzeit hinzufügen", systemImage: "fork.knife", tint: AboLifeColors.nutrition) {
                    showInput(.meal)
                }
                actionButton("Gewicht eintragen", systemImage: "scalemass", tint: AboLifeColors.review) {
                    showInput(.weight)
                }
                actionButton("Ausgabe hinzufügen", systemImage: "eurosign.circle", tint: AboLifeColors.finance) {
                    showInput(.expense)
                }
                actionButton("Training erledigt", systemImage: "figure.strengthtraining.traditional", tint: AboLifeColors.training) {
                    store.completeHomeWorkout(intensity: .normal)
                    finishAction("Training")
                }
                actionButton("Minimum-Training", systemImage: "checkmark.circle", tint: AboLifeColors.training) {
                    store.completeHomeWorkout(intensity: .minimum)
                    finishAction("Minimum")
                }
                actionButton("Training mit Details", systemImage: "list.bullet.clipboard", tint: AboLifeColors.training) {
                    open(.training)
                }
                actionButton("Proteinshake erledigt", systemImage: "takeoutbag.and.cup.and.straw", tint: AboLifeColors.protein) {
                    completeReminderHabit(TelegramReminderHabit.proteinShakeKey, message: "Proteinshake")
                }
                actionButton("Medikamente erledigt", systemImage: "pills", tint: AboLifeColors.habits) {
                    completeReminderHabit(TelegramReminderHabit.medicationKey, message: "Medikamente")
                }
            }

            if let activeInput {
                miniInput(activeInput)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
            telegramSection
        }
    }

    private var telegramSection: some View {
        panelSection("Telegram", systemImage: "paperplane") {
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 7) {
                        Circle()
                            .fill(telegramTint)
                            .frame(width: 7, height: 7)
                        Text(telegramStatusText)
                            .font(AboLifeTypography.caption.weight(.semibold))
                            .foregroundStyle(AboLifeColors.primaryText)
                            .lineLimit(1)
                    }

                    Text("Letztes Update: \(telegramLastUpdateText)")
                        .font(AboLifeTypography.micro)
                        .foregroundStyle(AboLifeColors.secondaryText)
                        .lineLimit(1)

                    if telegram.lastErrorMessage != nil {
                        Text("Fehler")
                            .font(AboLifeTypography.micro)
                            .foregroundStyle(AboLifeColors.habits)
                            .lineLimit(1)
                    }
                }

                Spacer(minLength: 8)

                Button {
                    telegram.isRunning ? telegram.stop() : telegram.start()
                } label: {
                    Image(systemName: telegram.isRunning ? "stop.circle.fill" : "play.circle.fill")
                        .font(.system(size: 18, weight: .semibold))
                }
                .buttonStyle(.plain)
                .foregroundStyle(telegramTint)
                .disabled(!telegram.canStart && !telegram.isRunning)
                .help(telegram.isRunning ? "Telegram stoppen" : "Telegram starten")
            }
        }
    }

    private func panelSection<Content: View>(
        _ title: String,
        systemImage: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            Label(title, systemImage: systemImage)
                .font(AboLifeTypography.caption.weight(.semibold))
                .foregroundStyle(AboLifeColors.primaryText)

            content()
        }
        .padding(10)
        .background {
            foregroundCardBackground
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(AboLifeColors.glassStrokeMuted, lineWidth: 1)
        }
    }

    private func actionButton(_ title: String, systemImage: String, tint: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 7) {
                Image(systemName: systemImage)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(tint)
                    .frame(width: 16)
                Text(title)
                    .font(AboLifeTypography.micro.weight(.semibold))
                    .foregroundStyle(AboLifeColors.primaryText)
                    .lineLimit(2)
                    .minimumScaleFactor(0.82)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 9)
            .frame(maxWidth: .infinity, minHeight: 34, alignment: .leading)
            .background(tint.opacity(0.15), in: RoundedRectangle(cornerRadius: 7, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .strokeBorder(tint.opacity(0.18), lineWidth: 0.8)
            }
        }
        .buttonStyle(.plain)
        .help(title)
    }

    private func miniInput(_ input: QuickPanelInput) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack {
                Label(input.title, systemImage: input.systemImage)
                    .font(AboLifeTypography.caption.weight(.semibold))
                    .foregroundStyle(AboLifeColors.primaryText)
                    .lineLimit(1)
                Spacer()
                Button {
                    closeInput()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 14, weight: .semibold))
                }
                .buttonStyle(.plain)
                .foregroundStyle(AboLifeColors.secondaryText)
                .help("Abbrechen")
            }

            switch input {
            case .meal:
                VStack(spacing: 7) {
                    quickTextField("Name", text: $mealName)
                    HStack(spacing: 7) {
                        quickTextField("Kalorien", text: $mealCalories)
                        quickTextField("Protein", text: $mealProtein)
                    }
                }
            case .weight:
                quickTextField("Gewicht in kg", text: $weight)
            case .expense:
                VStack(spacing: 7) {
                    quickTextField("Titel", text: $expenseTitle)
                        .onChange(of: expenseTitle) { _, newValue in
                            applyExpenseSuggestion(for: newValue)
                        }
                    HStack(spacing: 7) {
                        quickTextField("Betrag in EUR", text: $expenseAmount)
                        quickTextField("Kategorie", text: $expenseCategory)
                    }
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 90), spacing: 6)], spacing: 6) {
                        ForEach(menuExpenseCategories, id: \.self) { category in
                            Button {
                                expenseCategory = category
                            } label: {
                                Text(category)
                                    .font(AboLifeTypography.micro.weight(.semibold))
                                    .lineLimit(1)
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.plain)
                            .foregroundStyle(expenseCategory == category ? AboLifeColors.primaryText : AboLifeColors.secondaryText)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 5)
                            .background(
                                (expenseCategory == category ? AboLifeColors.finance.opacity(0.20) : AboLifeColors.elevatedCardBackground),
                                in: Capsule()
                            )
                        }
                    }
                }
            }

            if let validationMessage {
                Text(validationMessage)
                    .font(AboLifeTypography.micro)
                    .foregroundStyle(AboLifeColors.habits)
                    .lineLimit(2)
            }

            HStack(spacing: 8) {
                Button("Abbrechen") {
                    closeInput()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

                Button("Speichern") {
                    save(input)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .tint(AboLifeColors.review)
            }
        }
        .padding(10)
        .background(AboLifeColors.quietFill, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(AboLifeColors.glassStrokeMuted, lineWidth: 1)
        }
    }

    private func quickTextField(_ placeholder: String, text: Binding<String>) -> some View {
        TextField(placeholder, text: text)
            .textFieldStyle(.plain)
            .font(AboLifeTypography.caption)
            .foregroundStyle(AboLifeColors.primaryText)
            .padding(.horizontal, 9)
            .frame(height: 30)
            .background(AboLifeColors.elevatedCardBackground, in: RoundedRectangle(cornerRadius: 7, style: .continuous))
    }

    private func showInput(_ input: QuickPanelInput) {
        validationMessage = nil
        activeInput = input
        if input == .expense, expenseCategory.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            expenseCategory = suggestedExpenseCategory(for: expenseTitle)
        }
    }

    private func closeInput() {
        activeInput = nil
        validationMessage = nil
    }

    private func save(_ input: QuickPanelInput) {
        switch input {
        case .meal:
            addMeal()
        case .weight:
            addWeight()
        case .expense:
            addExpense()
        }
    }

    private func addMeal() {
        let cleanName = mealName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanName.isEmpty else {
            validationMessage = "Bitte einen Namen eintragen."
            return
        }
        guard let calories = Int(mealCalories.trimmingCharacters(in: .whitespacesAndNewlines)), calories >= 0 else {
            validationMessage = "Kalorien bitte als Zahl eintragen."
            return
        }
        guard let protein = parsedDouble(mealProtein), protein >= 0 else {
            validationMessage = "Protein bitte als Zahl eintragen."
            return
        }

        store.addMeal(name: cleanName, calories: calories, protein: protein)
        mealName = ""
        mealCalories = ""
        mealProtein = ""
        closeInput()
        finishAction("Mahlzeit")
    }

    private func addWeight() {
        guard let parsedWeight = parsedDouble(weight), parsedWeight >= 20, parsedWeight <= 300 else {
            validationMessage = "Gewicht bitte zwischen 20 und 300 kg eintragen."
            return
        }

        guard store.updateWeight(parsedWeight) else {
            validationMessage = "Gewicht konnte nicht gespeichert werden."
            return
        }

        weight = ""
        closeInput()
        finishAction("Gewicht")
    }

    private func addExpense() {
        let cleanTitle = expenseTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanCategory = expenseCategory.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanTitle.isEmpty else {
            validationMessage = "Bitte einen Titel eintragen."
            return
        }
        guard let amount = parsedDouble(expenseAmount), amount > 0 else {
            validationMessage = "Betrag bitte als Zahl größer 0 eintragen."
            return
        }

        store.addExpense(
            title: cleanTitle,
            amount: amount,
            category: cleanCategory.isEmpty ? "Sonstiges" : cleanCategory
        )
        expenseTitle = ""
        expenseAmount = ""
        expenseCategory = "Sonstiges"
        closeInput()
        finishAction("Ausgabe")
    }

    private func completeReminderHabit(_ key: String, message: String) {
        if store.completeHabit(habitKey: key) {
            finishAction(message)
        } else {
            showToast("Nicht gespeichert")
        }
    }

    private func finishAction(_ message: String) {
        refreshPanel()
        showToast("\(message) gespeichert")
    }

    private func refreshPanel() {
        store.refreshFromPersistence()
    }

    private func showToast(_ message: String) {
        withAnimation(.easeOut(duration: 0.16)) {
            toastMessage = message
        }
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 1_700_000_000)
            withAnimation(.easeOut(duration: 0.18)) {
                if toastMessage == message {
                    toastMessage = nil
                }
            }
        }
    }

    private func parsedDouble(_ text: String) -> Double? {
        let normalized = text
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: ",", with: ".")
        guard let value = Double(normalized), value.isFinite else { return nil }
        return value
    }

    private func open(_ section: AppSection) {
        isQuickActionsExpanded = false
        navigation.select(section)
        guard navigation.shouldOpenMainWindow() else { return }

        openWindow(id: AppNavigationCoordinator.mainWindowID)
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 200_000_000)
            navigation.finishOpeningMainWindow()
        }
    }

    private func progress(_ current: Double, _ target: Double) -> Double {
        guard target > 0 else { return 0 }
        return min(max(current / target, 0), 1)
    }

    private var menuExpenseCategories: [String] {
        Array(FinanceCategoryCatalog.expenseCategories.prefix(6))
    }

    private func applyExpenseSuggestion(for title: String) {
        let current = expenseCategory.trimmingCharacters(in: .whitespacesAndNewlines)
        guard current.isEmpty || current == "Sonstiges" || menuExpenseCategories.contains(current) else { return }
        expenseCategory = suggestedExpenseCategory(for: title)
    }

    private func suggestedExpenseCategory(for title: String) -> String {
        FinanceCategoryCatalog.normalized(title, kind: .expense)
    }

    private var telegramStatusText: String {
        switch telegram.state {
        case .running:
            return "Status: Aktiv"
        case .ready, .stopped:
            return "Status: Inaktiv"
        case .error:
            return "Status: Fehler"
        case .notConfigured:
            return "Status: Nicht konfiguriert"
        }
    }

    private var telegramLastUpdateText: String {
        telegram.lastUpdateId.map { "#\($0)" } ?? "keins"
    }

    private var telegramTint: Color {
        switch telegram.state {
        case .running:
            return AboLifeColors.protein
        case .error, .notConfigured:
            return AboLifeColors.habits
        case .ready:
            return AboLifeColors.review
        case .stopped:
            return AboLifeColors.secondaryText
        }
    }
}

private struct MenuBarNutritionDoubleRing: View {
    let caloriesConsumed: Int
    let caloriesTarget: Int
    let proteinConsumed: Double
    let proteinTarget: Double
    let caloriesProgress: Double
    let proteinProgress: Double

    var body: some View {
        ZStack {
            ring(progress: caloriesProgress, tint: AboLifeColors.nutrition, lineWidth: 9)
                .frame(width: 104, height: 104)

            ring(progress: proteinProgress, tint: AboLifeColors.protein, lineWidth: 7)
                .frame(width: 70, height: 70)

            VStack(spacing: 1) {
                Text("\(caloriesConsumed)")
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                    .foregroundStyle(AboLifeColors.primaryText)
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.64)
                Text("kcal")
                    .font(.system(size: 8, weight: .semibold, design: .rounded))
                    .foregroundStyle(AboLifeColors.secondaryText)
                Text("\(Int(proteinConsumed.rounded())) g")
                    .font(.system(size: 9, weight: .semibold, design: .rounded))
                    .foregroundStyle(AboLifeColors.protein)
                    .monospacedDigit()
            }
            .frame(width: 52)
        }
        .frame(width: 112, height: 112)
        .accessibilityLabel("Kalorien \(caloriesConsumed) von \(caloriesTarget), Protein \(Int(proteinConsumed.rounded())) von \(Int(proteinTarget.rounded())) Gramm")
    }

    private func ring(progress: Double, tint: Color, lineWidth: CGFloat) -> some View {
        let clampedProgress = min(max(progress, 0), 1)
        return ZStack {
            Circle()
                .stroke(AboLifeColors.quietFill, lineWidth: lineWidth)
                .overlay {
                    Circle().stroke(AboLifeColors.glassStrokeMuted, lineWidth: 0.6)
                }

            Circle()
                .trim(from: 0, to: clampedProgress)
                .stroke(
                    AngularGradient(
                        colors: [tint.opacity(0.42), tint.opacity(0.86), tint.opacity(0.62)],
                        center: .center
                    ),
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .shadow(color: tint.opacity(0.10), radius: 5, x: 0, y: 0)
        }
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
                    .stroke(AboLifeColors.nutrition, style: StrokeStyle(lineWidth: 8, lineCap: .round))
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

struct MenuBarQuickPanelView_Previews: PreviewProvider {
    static var previews: some View {
        MenuBarQuickPanelView(database: nil)
            .environmentObject(AppNavigationCoordinator())
            .environmentObject(TelegramAppCoordinator())
    }
}
