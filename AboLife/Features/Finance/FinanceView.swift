import SwiftUI

struct FinanceView: View {
    @Environment(\.aboLifeStyle) private var designStyle
    @StateObject private var store: FinanceStore
    @State private var budgetCategory = ""
    @State private var budgetAmount = ""
    @State private var fixedTitle = ""
    @State private var fixedAmount = ""
    @State private var fixedCategory = "Fixkosten"
    @State private var fixedDueDay = 1
    @State private var goalTitle = ""
    @State private var goalTarget = ""
    @State private var goalCurrent = ""
    @State private var showPlanning = false
    @State private var showCategories = false
    @State private var entryFilter = "Alle"

    init(database: AppDatabase?) {
        _store = StateObject(wrappedValue: FinanceStore(database: database))
    }

    var body: some View {
        ZStack {
            AboLifePremiumBackground()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    header
                    if let error = store.errorMessage {
                        AboLifeNotice(title: "Finanzdaten prüfen", message: error, retry: store.reload)
                    }
                    budgetOverview
                    budgetDetails
                    DisclosureGroup("Budgetplanung, Fixkosten & Sparziele", isExpanded: $showPlanning) {
                        plannerSection.padding(.top, AboLifeSpacing.medium)
                    }
                    DisclosureGroup("Kategorien verwalten", isExpanded: $showCategories) {
                        categoryManagementSection.padding(.top, AboLifeSpacing.medium)
                    }
                    categorySection
                    chartSection
                    weeklySection
                    expensesSection
                }
                .aboLifePage()
            }
        }
        .navigationTitle("")
        .onAppear {
            store.reload()
        }
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Finanzen")
                    .accessibilityIdentifier("page.finance")
                    .font(AboLifeTypography.dashboardTitle)
                    .foregroundStyle(designStyle.colors.primaryText)

                Text(store.monthSubtitle)
                    .font(AboLifeTypography.body)
                    .foregroundStyle(designStyle.colors.secondaryText)
            }

            Spacer()

            AboLifePeriodControl(
                title: store.selectedDate.formatted(.dateTime.month(.abbreviated).year()),
                previousLabel: "Vorheriger Monat", nextLabel: "Nächster Monat", canGoForward: !store.isCurrentMonth,
                previous: { store.moveMonth(by: -1) }, next: { store.moveMonth(by: 1) }
            )

            Button {
                store.selectCurrentMonth()
            } label: {
                Image(systemName: "calendar")
                    .font(.system(size: 16, weight: .medium))
            }
            .buttonStyle(.bordered)
            .help("Dieser Monat").accessibilityLabel("Dieser Monat")
            .disabled(store.isCurrentMonth)

            Button {
                store.reload()
            } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 16, weight: .medium))
            }
            .buttonStyle(.bordered)
            .help("Neu laden").accessibilityLabel("Neu laden")
        }
    }

    private var budgetOverview: some View {
        AboLifeCard(isProminent: true) {
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .center, spacing: 24) {
                    overviewCopy
                    Spacer(minLength: 0)
                    budgetRing(size: 152, lineWidth: 8)
                }

                VStack(alignment: .leading, spacing: 16) {
                    overviewCopy
                    budgetRing(size: 136, lineWidth: 8)
                }
            }
        }
    }

    private func budgetRing(size: CGFloat, lineWidth: CGFloat) -> some View {
        CoreRingView(
            progress: store.budgetProgress,
            lineWidth: lineWidth,
            tint: store.isOverBudget ? designStyle.colors.habits : designStyle.colors.finance,
            valueText: "\(Int(store.budgetProgress * 100))%",
            labelText: "Budget genutzt"
        )
        .frame(width: size, height: size)
    }

    private var overviewCopy: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Monatsbudget")
                .font(AboLifeTypography.cardTitle)
                .foregroundStyle(designStyle.colors.secondaryText)

            Text("\(store.formatAmount(store.remainingBudget)) Restbudget")
                .font(AboLifeTypography.heroMessage)
                .foregroundStyle(designStyle.colors.primaryText)
                .monospacedDigit()
                .aboLifeNumericTransition(value: store.remainingBudget)

            Text("\(store.formatAmount(store.monthlySpent)) von \(store.formatAmount(store.monthlyBudget)) ausgegeben")
                .font(AboLifeTypography.body)
                .foregroundStyle(designStyle.colors.secondaryText)
                .monospacedDigit()

            Text("\(store.statusMessage) \(store.forecastMessage)")
                .font(AboLifeTypography.body)
                .foregroundStyle(designStyle.colors.secondaryText)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 8) {
                if store.isCurrentMonth {
                    financeStatusCapsule("Heute frei", store.formatAmount(store.dailyBudgetRemaining), designStyle.colors.finance)
                }
                financeStatusCapsule("Fixkosten offen", store.formatAmount(store.remainingFixedCosts), designStyle.colors.secondaryText)
            }
            if !store.isCurrentMonth {
                Text("Buchungen aus dem gewählten Monat · Budget und Zielwerte verwenden die aktuellen Einstellungen.")
                    .font(AboLifeTypography.caption)
                    .foregroundStyle(designStyle.colors.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: 620, alignment: .leading)
    }

    private var budgetDetails: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 190), spacing: 12)], spacing: 12) {
            detailPill(title: "Einnahmen", value: store.formatAmount(store.monthlyIncome))
            detailPill(title: "Saldo", value: store.formatAmount(store.monthlyBalance))
            detailPill(title: "Ø pro Tag", value: store.formatAmount(store.monthlyTrend.averageDailySpend))
            detailPill(title: "Prognose", value: store.formatAmount(store.forecastSpend))
            detailPill(title: "Letzter Monat", value: store.previousMonthText)
            detailPill(title: "Vergleich", value: store.spentChangeText)
        }
    }

    private var plannerSection: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 300), spacing: 12)], spacing: 12) {
            planningCard(
                title: "Monatliche Budgetplanung",
                systemImage: "target",
                footer: "Kategorie-Budgets gelten für \(FinanceRepository.monthKey(for: store.selectedDate))."
            ) {
                HStack(spacing: 8) {
                    compactTextField("Kategorie", text: $budgetCategory)
                    compactTextField(store.currency, text: $budgetAmount, width: 80)
                    iconButton("plus.circle.fill", help: "Budget speichern") {
                        guard store.saveCategoryBudget(category: budgetCategory, amount: decimal(budgetAmount)) else { return }
                        budgetCategory = ""
                        budgetAmount = ""
                    }
                }

                ForEach(store.categoryBudgets.prefix(4)) { budget in
                    compactListRow(
                        title: budget.category,
                        value: store.formatAmount(budget.budgetAmount),
                        systemImage: "chart.pie",
                        tint: designStyle.colors.finance
                    ) {
                        store.deleteCategoryBudget(id: budget.id)
                    }
                }
            }

            planningCard(
                title: "Fixkosten",
                systemImage: "repeat.circle",
                footer: "\(store.formatAmount(store.plannedFixedCosts)) geplant, \(store.formatAmount(store.remainingFixedCosts)) noch offen."
            ) {
                HStack(spacing: 8) {
                    compactTextField("Titel", text: $fixedTitle)
                    compactTextField(store.currency, text: $fixedAmount, width: 70)
                    Stepper("\(fixedDueDay)", value: $fixedDueDay, in: 1...31)
                        .font(AboLifeTypography.micro)
                        .frame(width: 62)
                    iconButton("plus.circle.fill", help: "Fixkosten speichern") {
                        guard store.saveFixedCost(title: fixedTitle, amount: decimal(fixedAmount), category: fixedCategory, dueDay: fixedDueDay) else { return }
                        fixedTitle = ""
                        fixedAmount = ""
                    }
                }

                ForEach(store.fixedCosts.prefix(4)) { fixedCost in
                    fixedCostRow(fixedCost)
                }
            }

            planningCard(
                title: "Sparziele",
                systemImage: "banknote",
                footer: "Aktiver Fortschritt: \(Int((store.savingsProgress * 100).rounded()))%."
            ) {
                HStack(spacing: 8) {
                    compactTextField("Ziel", text: $goalTitle)
                    compactTextField("Soll", text: $goalTarget, width: 62)
                    compactTextField("Ist", text: $goalCurrent, width: 62)
                    iconButton("plus.circle.fill", help: "Sparziel speichern") {
                        guard store.saveSavingsGoal(title: goalTitle, targetAmount: decimal(goalTarget), currentAmount: decimal(goalCurrent)) else { return }
                        goalTitle = ""
                        goalTarget = ""
                        goalCurrent = ""
                    }
                }

                ForEach(store.savingsGoals.prefix(4)) { goal in
                    VStack(alignment: .leading, spacing: 6) {
                        compactListRow(
                            title: goal.title,
                            value: "\(store.formatAmount(goal.currentAmount)) / \(store.formatAmount(goal.targetAmount))",
                            systemImage: "banknote",
                            tint: designStyle.colors.review
                        ) {
                            store.deleteSavingsGoal(id: goal.id)
                        }

                        ProgressView(value: goal.progress)
                            .tint(designStyle.colors.review)
                    }
                }
            }
        }
    }

    private var categoryManagementSection: some View {
        AboLifeCard {
            VStack(alignment: .leading, spacing: 13) {
                HStack(alignment: .firstTextBaseline) {
                    sectionHeader("Kategorien", systemImage: "tag")

                    Spacer()

                    AboLifeGlassCapsule {
                        Text("\(activeCategoryNames.count) aktiv")
                            .font(AboLifeTypography.micro)
                            .foregroundStyle(designStyle.colors.finance)
                            .monospacedDigit()
                    }
                }

                Text("Aktive Vorschläge bleiben schlicht; ältere, unbekannte Kategorien aus Ausgaben bleiben darunter sichtbar.")
                    .font(AboLifeTypography.caption)
                    .foregroundStyle(designStyle.colors.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)

                TagCloud(items: activeCategoryNames, tint: designStyle.colors.finance)

                if !observedCategoryNames.isEmpty {
                    VStack(alignment: .leading, spacing: 7) {
                        Text("In deinen Daten gesehen")
                            .font(AboLifeTypography.micro.weight(.semibold))
                            .foregroundStyle(designStyle.colors.secondaryText)

                        TagCloud(items: observedCategoryNames, tint: designStyle.colors.review)
                    }
                }
            }
        }
    }

    private var categorySection: some View {
        AboLifeCard(isProminent: true) {
            VStack(alignment: .leading, spacing: 13) {
                HStack(alignment: .firstTextBaseline) {
                    sectionHeader("Kategorie-Trends", systemImage: "chart.pie")
                    Spacer()
                    Text(store.monthSubtitle)
                        .font(AboLifeTypography.micro)
                        .foregroundStyle(designStyle.colors.secondaryText)
                }

                if store.categorySummaries.isEmpty {
                    quietEmptyState(
                        title: "Noch keine Kategorie-Trends.",
                        message: "Sobald Ausgaben vorhanden sind, siehst du hier Anteile, Budgets und ruhige Hinweise."
                    )
                } else {
                    VStack(spacing: 10) {
                        ForEach(store.categorySummaries) { summary in
                            categoryRow(summary)
                        }
                    }
                }
            }
        }
    }

    private var chartSection: some View {
        AboLifeCard(isProminent: true) {
            VStack(alignment: .leading, spacing: 13) {
                HStack(alignment: .firstTextBaseline) {
                    sectionHeader("Monatsanalyse", systemImage: "chart.bar.xaxis")
                    Spacer()
                    Text(monthAnalysisHint)
                        .font(AboLifeTypography.micro)
                        .foregroundStyle(designStyle.colors.secondaryText)
                }

                HStack(alignment: .bottom, spacing: 18) {
                    financeBar(title: "Einnahmen", amount: store.monthlyIncome, maxAmount: chartMaximum, tint: designStyle.colors.positive)
                    financeBar(title: "Ausgaben", amount: store.monthlySpent, maxAmount: chartMaximum, tint: designStyle.colors.finance)
                    financeBar(title: "Prognose", amount: store.forecastSpend, maxAmount: chartMaximum, tint: store.monthPlan?.isForecastOverBudget == true ? designStyle.colors.habits : designStyle.colors.review)
                    financeBar(title: "Budget", amount: store.monthlyBudget, maxAmount: chartMaximum, tint: designStyle.colors.secondaryText)
                }
                .frame(height: 190)

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 170), spacing: 10)], spacing: 10) {
                    insightTile("Rest pro Tag", store.formatAmount(store.dailyBudgetRemaining), "Bis Monatsende verfügbar.", designStyle.colors.finance)
                    insightTile("Aktive Ausgabentage", "\(activeExpenseDays)", activeExpenseDays == 0 ? "Noch wenig Daten." : "Tage mit Ausgaben.", designStyle.colors.review)
                    insightTile("Größte Ausgabe", largestExpenseText, "Einzelner Ausreißer im Blick.", designStyle.colors.habits)
                    insightTile("Teuerste Kategorie", topCategoryText, "Ruhig beobachten, nicht jagen.", designStyle.colors.finance)
                }
            }
        }
    }

    private var weeklySection: some View {
        AboLifeCard {
            VStack(alignment: .leading, spacing: 11) {
                sectionHeader("Wochenblick", systemImage: "calendar.badge.clock")

                HStack(spacing: 12) {
                    detailPill(title: "Woche", value: store.formatAmount(store.weeklySpent))
                    detailPill(title: "Top Kategorie", value: store.weeklySummary.topCategory ?? "offen")
                    detailPill(title: "Einträge", value: "\(store.weeklySummary.entryCount)")
                }

                Text(weeklyFinanceSentence)
                    .font(AboLifeTypography.caption)
                    .foregroundStyle(designStyle.colors.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var expensesSection: some View {
        AboLifeCard(isProminent: true) {
            VStack(alignment: .leading, spacing: 13) {
                HStack {
                    Label("Buchungen im Monat", systemImage: "list.bullet.rectangle")
                        .font(AboLifeTypography.cardTitle)
                        .foregroundStyle(designStyle.colors.primaryText)

                    Spacer()

                    AboLifeGlassCapsule {
                        Text(store.formatAmount(store.monthlySpent))
                            .font(AboLifeTypography.micro)
                            .foregroundStyle(designStyle.colors.secondaryText)
                            .monospacedDigit()
                    }
                }

                Picker("Buchungen filtern", selection: $entryFilter) {
                    ForEach(["Alle", "Ausgaben", "Einnahmen"], id: \.self) { Text($0) }
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 360)

                if visibleEntries.isEmpty {
                    emptyState
                } else {
                    VStack(spacing: 10) {
                        ForEach(visibleEntries) { entry in
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
            Text("Keine Buchungen für diese Auswahl.")
                .font(AboLifeTypography.body.weight(.semibold))
                .foregroundStyle(designStyle.colors.primaryText)

            Text("Ändere den Filter oder nutze die Schnellerfassung für deine erste Ausgabe.")
                .font(AboLifeTypography.caption)
                .foregroundStyle(designStyle.colors.secondaryText)
        }
        .frame(maxWidth: .infinity, minHeight: 112, alignment: .leading)
    }

    private func detailPill(title: String, value: String) -> some View {
        AboLifeCard {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(AboLifeTypography.caption)
                    .foregroundStyle(designStyle.colors.secondaryText)

                Text(value)
                    .font(AboLifeTypography.sectionTitle)
                    .foregroundStyle(designStyle.colors.primaryText)
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)
            }
        }
    }

    private func planningCard<Content: View>(
        title: String,
        systemImage: String,
        footer: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        AboLifeCard {
            VStack(alignment: .leading, spacing: 12) {
                sectionHeader(title, systemImage: systemImage)
                content()
                Text(footer)
                    .font(AboLifeTypography.micro)
                    .foregroundStyle(designStyle.colors.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func sectionHeader(_ title: String, systemImage: String) -> some View {
        Label(title, systemImage: systemImage)
            .font(AboLifeTypography.cardTitle)
            .foregroundStyle(designStyle.colors.primaryText)
    }

    private func compactTextField(_ placeholder: String, text: Binding<String>, width: CGFloat? = nil) -> some View {
        TextField(placeholder, text: text)
            .textFieldStyle(.plain)
            .font(AboLifeTypography.caption)
            .foregroundStyle(designStyle.colors.primaryText)
            .padding(.horizontal, 9)
            .frame(width: width, height: 30)
            .background(designStyle.colors.quietFill, in: RoundedRectangle(cornerRadius: 7, style: .continuous))
    }

    private func iconButton(_ systemImage: String, help: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 16, weight: .semibold))
        }
        .buttonStyle(.plain)
        .foregroundStyle(designStyle.colors.review)
        .accessibilityLabel(help)
        .help(help).accessibilityLabel(help)
    }

    private func compactListRow(title: String, value: String, systemImage: String, tint: Color, delete: @escaping () -> Void) -> some View {
        HStack(spacing: 8) {
            Image(systemName: systemImage)
                .foregroundStyle(tint)
                .frame(width: 18)
            Text(title)
                .font(AboLifeTypography.caption)
                .foregroundStyle(designStyle.colors.primaryText)
                .lineLimit(1)
            Spacer()
            Text(value)
                .font(AboLifeTypography.micro)
                .foregroundStyle(designStyle.colors.secondaryText)
                .monospacedDigit()
            Button(role: .destructive, action: delete) {
                Image(systemName: "trash")
            }
            .buttonStyle(.borderless)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(designStyle.colors.quietFill, in: RoundedRectangle(cornerRadius: 7, style: .continuous))
    }

    private func categoryRow(_ summary: FinanceCategorySummary) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(summary.category)
                        .font(AboLifeTypography.body.weight(.semibold))
                        .foregroundStyle(designStyle.colors.primaryText)

                    Text(categoryHint(for: summary))
                        .font(AboLifeTypography.micro)
                        .foregroundStyle(designStyle.colors.secondaryText)
                }

                Spacer()
                Text(summary.budget.map { "\(store.formatAmount(summary.spent)) / \(store.formatAmount($0))" } ?? store.formatAmount(summary.spent))
                    .font(AboLifeTypography.caption.weight(.semibold))
                    .foregroundStyle(summary.isOverBudget ? designStyle.colors.habits : designStyle.colors.secondaryText)
                    .monospacedDigit()
            }

            ProgressView(value: summary.budget == nil ? min(summary.spent / max(store.monthlySpent, 1), 1) : summary.progress)
                .tint(summary.isOverBudget ? designStyle.colors.habits : designStyle.colors.finance)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(designStyle.colors.quietFill, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private func financeBar(title: String, amount: Double, maxAmount: Double, tint: Color) -> some View {
        VStack(spacing: 8) {
            Spacer(minLength: 0)
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(tint.opacity(0.72))
                .frame(width: 54, height: max(CGFloat(amount / maxAmount) * 126, 0))
                .aboLifeMotion(value: amount)
            Text(title)
                .font(AboLifeTypography.micro)
                .foregroundStyle(designStyle.colors.secondaryText)
                .lineLimit(1)
            Text(store.formatAmount(amount))
                .font(AboLifeTypography.micro)
                .foregroundStyle(designStyle.colors.primaryText)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(title): \(store.formatAmount(amount))")
    }

    private var chartMaximum: Double {
        max(store.monthlyIncome, store.monthlySpent, store.forecastSpend, store.monthlyBudget, 1)
    }

    private var visibleEntries: [FinanceEntryRecord] {
        store.entries.filter { entry in
            entryFilter == "Alle" || (entryFilter == "Ausgaben" ? entry.amount > 0 : entry.amount < 0)
        }
    }

    private func financeStatusCapsule(_ title: String, _ value: String, _ tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(title)
                .font(AboLifeTypography.micro)
                .foregroundStyle(designStyle.colors.secondaryText)
            Text(value)
                .font(AboLifeTypography.caption.weight(.semibold))
                .foregroundStyle(tint)
                .monospacedDigit()
                .lineLimit(1)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(designStyle.colors.quietFill, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
    }

    private func insightTile(_ title: String, _ value: String, _ detail: String, _ tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title)
                .font(AboLifeTypography.micro)
                .foregroundStyle(designStyle.colors.secondaryText)
            Text(value)
                .font(AboLifeTypography.caption.weight(.semibold))
                .foregroundStyle(designStyle.colors.primaryText)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.78)
            Text(detail)
                .font(AboLifeTypography.micro)
                .foregroundStyle(tint)
                .lineLimit(2)
        }
        .padding(10)
        .frame(maxWidth: .infinity, minHeight: 78, alignment: .leading)
        .background(designStyle.colors.quietFill, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private func fixedCostRow(_ fixedCost: FinanceFixedCostRecord) -> some View {
        HStack(spacing: 9) {
            Image(systemName: fixedCost.isActive ? "checkmark.circle" : "pause.circle")
                .foregroundStyle(fixedCost.isActive ? designStyle.colors.finance : designStyle.colors.secondaryText)
                .frame(width: 18)

            VStack(alignment: .leading, spacing: 2) {
                Text(fixedCost.title)
                    .font(AboLifeTypography.caption.weight(.semibold))
                    .foregroundStyle(designStyle.colors.primaryText)
                    .lineLimit(1)
                Text("\(fixedCost.category) · fällig Tag \(fixedCost.dueDay)")
                    .font(AboLifeTypography.micro)
                    .foregroundStyle(designStyle.colors.secondaryText)
                    .lineLimit(1)
            }

            Spacer()

            Text(store.formatAmount(fixedCost.amount))
                .font(AboLifeTypography.micro.weight(.semibold))
                .foregroundStyle(designStyle.colors.primaryText)
                .monospacedDigit()

            Button {
                store.toggleFixedCost(fixedCost)
            } label: {
                Image(systemName: fixedCost.isActive ? "pause.circle" : "play.circle")
            }
            .buttonStyle(.borderless)
            .help(fixedCost.isActive ? "Pausieren" : "Aktivieren")

            Button(role: .destructive) {
                store.deleteFixedCost(id: fixedCost.id)
            } label: {
                Image(systemName: "trash")
            }
            .buttonStyle(.borderless)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(designStyle.colors.quietFill, in: RoundedRectangle(cornerRadius: 7, style: .continuous))
    }

    private func quietEmptyState(title: String, message: String) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title)
                .font(AboLifeTypography.body.weight(.semibold))
                .foregroundStyle(designStyle.colors.primaryText)
            Text(message)
                .font(AboLifeTypography.caption)
                .foregroundStyle(designStyle.colors.secondaryText)
        }
        .frame(maxWidth: .infinity, minHeight: 88, alignment: .leading)
        .padding(12)
        .background(designStyle.colors.quietFill, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private func categoryHint(for summary: FinanceCategorySummary) -> String {
        if summary.isOverBudget, let budget = summary.budget {
            return "\(store.formatAmount(summary.spent - budget)) über geplantem Monatswert."
        }
        if let budget = summary.budget {
            return "\(store.formatAmount(max(budget - summary.spent, 0))) Budgetpuffer."
        }
        let share = store.monthlySpent > 0 ? Int((summary.spent / store.monthlySpent * 100).rounded()) : 0
        return "\(share)% der Monatsausgaben."
    }

    private var activeCategoryNames: [String] {
        FinanceCategoryCatalog.expenseCategories
    }

    private var observedCategoryNames: [String] {
        let values = Set(
            store.entries.map(\.category)
                + store.categoryBudgets.map(\.category)
                + store.fixedCosts.map(\.category)
                + store.categorySummaries.map(\.category)
        )
        return values
            .map { FinanceCategoryCatalog.normalized($0, kind: .expense) }
            .filter { !activeCategoryNames.contains($0) }
            .sorted()
    }

    private var activeExpenseDays: Int {
        Set(store.entries.filter { $0.amount >= 0 }.map { Calendar.current.startOfDay(for: $0.occurredAt) }).count
    }

    private var largestExpenseText: String {
        guard let entry = store.entries.filter({ $0.amount >= 0 }).max(by: { $0.amount < $1.amount }) else {
            return "noch offen"
        }
        return "\(entry.title) · \(store.formatAmount(entry.amount))"
    }

    private var topCategoryText: String {
        store.categorySummaries.first?.category ?? "noch offen"
    }

    private var monthAnalysisHint: String {
        store.entries.count >= 3 ? "Trend belastbarer" : "mehr Daten helfen"
    }

    private var weeklyFinanceSentence: String {
        if store.weeklySummary.entryCount == 0 {
            return "Für diese Woche gibt es noch keine Finanzdaten."
        }
        if let category = store.weeklySummary.topCategory {
            return "Diese Woche war \(category) die größte Kategorie."
        }
        return "Diese Woche sind \(store.weeklySummary.entryCount) Finanz-Einträge vorhanden."
    }

    private func decimal(_ text: String) -> Double {
        Double(text.replacingOccurrences(of: ",", with: ".").trimmingCharacters(in: .whitespacesAndNewlines)) ?? 0
    }
}

private struct TagCloud: View {
    @Environment(\.aboLifeStyle) private var designStyle
    let items: [String]
    let tint: Color

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 118), spacing: 8)], alignment: .leading, spacing: 8) {
            ForEach(items, id: \.self) { item in
                Text(item)
                    .font(AboLifeTypography.micro.weight(.semibold))
                    .foregroundStyle(designStyle.colors.primaryText)
                    .lineLimit(1)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(tint.opacity(0.12), in: Capsule())
                    .overlay {
                        Capsule().strokeBorder(tint.opacity(0.16), lineWidth: 0.7)
                    }
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
