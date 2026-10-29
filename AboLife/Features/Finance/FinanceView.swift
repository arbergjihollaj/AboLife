import SwiftUI

struct FinanceView: View {
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

    init(database: AppDatabase?) {
        _store = StateObject(wrappedValue: FinanceStore(database: database))
    }

    var body: some View {
        ZStack {
            AboLifePremiumBackground()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    header
                    budgetOverview
                    budgetDetails
                    plannerSection
                    categoryManagementSection
                    categorySection
                    chartSection
                    weeklySection
                    expensesSection
                }
                .padding(22)
            }
        }
        .navigationTitle("")
        .onAppear {
            store.reload()
        }
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Finanzen")
                    .font(AboLifeTypography.dashboardTitle)
                    .foregroundStyle(AboLifeColors.primaryText)

                Text(store.monthSubtitle)
                    .font(AboLifeTypography.body)
                    .foregroundStyle(AboLifeColors.secondaryText)
            }

            Spacer()

            Button {
                store.selectCurrentMonth()
            } label: {
                Image(systemName: "calendar")
                    .font(.system(size: 14, weight: .semibold))
            }
            .buttonStyle(.bordered)
            .help("Dieser Monat")
            .disabled(store.isCurrentMonth)

            Button {
                store.reload()
            } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 14, weight: .semibold))
            }
            .buttonStyle(.bordered)
            .help("Neu laden")
        }
    }

    private var budgetOverview: some View {
        AboLifeCard(isProminent: true) {
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .center, spacing: 24) {
                    budgetRing(size: 158, lineWidth: 14)
                    overviewCopy
                    Spacer(minLength: 0)
                }

                VStack(alignment: .leading, spacing: 18) {
                    budgetRing(size: 142, lineWidth: 12)
                    overviewCopy
                }
            }
        }
    }

    private func budgetRing(size: CGFloat, lineWidth: CGFloat) -> some View {
        CoreRingView(
            progress: store.budgetProgress,
            lineWidth: lineWidth,
            tint: store.isOverBudget ? AboLifeColors.habits : AboLifeColors.finance,
            valueText: "\(Int(store.budgetProgress * 100))%",
            labelText: "Budget genutzt"
        )
        .frame(width: size, height: size)
    }

    private var overviewCopy: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Label("Monatsbudget", systemImage: "eurosign.circle")
                    .font(AboLifeTypography.cardTitle)
                    .foregroundStyle(AboLifeColors.primaryText)

                AboLifeGlassCapsule {
                    Text(store.currency)
                        .font(AboLifeTypography.micro)
                        .foregroundStyle(AboLifeColors.finance)
                }
            }

            Text("\(store.formatAmount(store.remainingBudget)) Restbudget")
                .font(AboLifeTypography.heroMessage)
                .foregroundStyle(AboLifeColors.primaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.82)

            Text("\(store.formatAmount(store.monthlySpent)) / \(store.formatAmount(store.monthlyBudget)) ausgegeben")
                .font(AboLifeTypography.body)
                .foregroundStyle(AboLifeColors.secondaryText)
                .monospacedDigit()

            BudgetProgressBar(spent: store.monthlySpent, budget: store.monthlyBudget)
                .frame(maxWidth: 430)

            Text("\(store.statusMessage) \(store.forecastMessage)")
                .font(AboLifeTypography.body)
                .foregroundStyle(AboLifeColors.secondaryText)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 8) {
                financeStatusCapsule("Heute frei", store.formatAmount(store.dailyBudgetRemaining), AboLifeColors.finance)
                financeStatusCapsule("Monat frei", store.formatAmount(store.remainingBudget), AboLifeColors.review)
                financeStatusCapsule("Fixkosten offen", store.formatAmount(store.remainingFixedCosts), AboLifeColors.secondaryText)
            }
        }
        .frame(maxWidth: 620, alignment: .leading)
    }

    private var budgetDetails: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 12) {
                detailPill(title: "Ausgegeben", value: store.formatAmount(store.monthlySpent), systemImage: "cart", tint: AboLifeColors.finance)
                detailPill(title: "Einnahmen", value: store.formatAmount(store.monthlyIncome), systemImage: "arrow.down.circle", tint: AboLifeColors.positive)
                detailPill(title: "Saldo", value: store.formatAmount(store.monthlyBalance), systemImage: "equal.circle", tint: store.monthlyBalance >= 0 ? AboLifeColors.review : AboLifeColors.habits)
                detailPill(title: "Restbudget", value: store.formatAmount(store.remainingBudget), systemImage: "wallet.pass", tint: AboLifeColors.review)
                detailPill(title: "Ø pro Tag", value: store.formatAmount(store.monthlyTrend.averageDailySpend), systemImage: "calendar", tint: AboLifeColors.positive)
                detailPill(title: "Prognose", value: store.formatAmount(store.forecastSpend), systemImage: "chart.line.uptrend.xyaxis", tint: store.monthPlan?.isForecastOverBudget == true ? AboLifeColors.habits : AboLifeColors.finance)
                detailPill(title: "Letzter Monat", value: store.previousMonthText, systemImage: "arrow.uturn.backward", tint: AboLifeColors.secondaryText)
                detailPill(title: "Vergleich", value: store.spentChangeText, systemImage: "arrow.up.arrow.down", tint: AboLifeColors.finance)
            }

            VStack(spacing: 10) {
                detailPill(title: "Ausgegeben", value: store.formatAmount(store.monthlySpent), systemImage: "cart", tint: AboLifeColors.finance)
                detailPill(title: "Einnahmen", value: store.formatAmount(store.monthlyIncome), systemImage: "arrow.down.circle", tint: AboLifeColors.positive)
                detailPill(title: "Saldo", value: store.formatAmount(store.monthlyBalance), systemImage: "equal.circle", tint: store.monthlyBalance >= 0 ? AboLifeColors.review : AboLifeColors.habits)
                detailPill(title: "Restbudget", value: store.formatAmount(store.remainingBudget), systemImage: "wallet.pass", tint: AboLifeColors.review)
                detailPill(title: "Ø pro Tag", value: store.formatAmount(store.monthlyTrend.averageDailySpend), systemImage: "calendar", tint: AboLifeColors.positive)
                detailPill(title: "Prognose", value: store.formatAmount(store.forecastSpend), systemImage: "chart.line.uptrend.xyaxis", tint: store.monthPlan?.isForecastOverBudget == true ? AboLifeColors.habits : AboLifeColors.finance)
                detailPill(title: "Letzter Monat", value: store.previousMonthText, systemImage: "arrow.uturn.backward", tint: AboLifeColors.secondaryText)
                detailPill(title: "Vergleich", value: store.spentChangeText, systemImage: "arrow.up.arrow.down", tint: AboLifeColors.finance)
            }
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
                        store.saveCategoryBudget(category: budgetCategory, amount: decimal(budgetAmount))
                        budgetCategory = ""
                        budgetAmount = ""
                    }
                }

                ForEach(store.categoryBudgets.prefix(4)) { budget in
                    compactListRow(
                        title: budget.category,
                        value: store.formatAmount(budget.budgetAmount),
                        systemImage: "chart.pie",
                        tint: AboLifeColors.finance
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
                        store.saveFixedCost(title: fixedTitle, amount: decimal(fixedAmount), category: fixedCategory, dueDay: fixedDueDay)
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
                        store.saveSavingsGoal(title: goalTitle, targetAmount: decimal(goalTarget), currentAmount: decimal(goalCurrent))
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
                            tint: AboLifeColors.review
                        ) {
                            store.deleteSavingsGoal(id: goal.id)
                        }

                        ProgressView(value: goal.progress)
                            .tint(AboLifeColors.review)
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
                            .foregroundStyle(AboLifeColors.finance)
                            .monospacedDigit()
                    }
                }

                Text("Aktive Vorschläge bleiben schlicht; ältere, unbekannte Kategorien aus Ausgaben bleiben darunter sichtbar.")
                    .font(AboLifeTypography.caption)
                    .foregroundStyle(AboLifeColors.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)

                TagCloud(items: activeCategoryNames, tint: AboLifeColors.finance)

                if !observedCategoryNames.isEmpty {
                    VStack(alignment: .leading, spacing: 7) {
                        Text("In deinen Daten gesehen")
                            .font(AboLifeTypography.micro.weight(.semibold))
                            .foregroundStyle(AboLifeColors.secondaryText)

                        TagCloud(items: observedCategoryNames, tint: AboLifeColors.review)
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
                    Text("aktueller Monat")
                        .font(AboLifeTypography.micro)
                        .foregroundStyle(AboLifeColors.secondaryText)
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
                        .foregroundStyle(AboLifeColors.secondaryText)
                }

                HStack(alignment: .bottom, spacing: 18) {
                    financeBar(title: "Einnahmen", amount: store.monthlyIncome, maxAmount: max(store.monthlyIncome, store.monthlySpent, 1), tint: AboLifeColors.positive)
                    financeBar(title: "Ausgaben", amount: store.monthlySpent, maxAmount: max(store.monthlyIncome, store.monthlySpent, 1), tint: AboLifeColors.finance)
                    financeBar(title: "Forecast", amount: store.forecastSpend, maxAmount: max(store.forecastSpend, store.monthlyBudget, 1), tint: store.monthPlan?.isForecastOverBudget == true ? AboLifeColors.habits : AboLifeColors.review)
                    financeBar(title: "Budget", amount: store.monthlyBudget, maxAmount: max(store.forecastSpend, store.monthlyBudget, 1), tint: AboLifeColors.secondaryText)
                }
                .frame(height: 190)

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 170), spacing: 10)], spacing: 10) {
                    insightTile("Rest pro Tag", store.formatAmount(store.dailyBudgetRemaining), "Bis Monatsende verfügbar.", AboLifeColors.finance)
                    insightTile("Aktive Ausgabentage", "\(activeExpenseDays)", activeExpenseDays == 0 ? "Noch wenig Daten." : "Tage mit Ausgaben.", AboLifeColors.review)
                    insightTile("Größte Ausgabe", largestExpenseText, "Einzelner Ausreißer im Blick.", AboLifeColors.habits)
                    insightTile("Teuerste Kategorie", topCategoryText, "Ruhig beobachten, nicht jagen.", AboLifeColors.finance)
                }
            }
        }
    }

    private var weeklySection: some View {
        AboLifeCard {
            VStack(alignment: .leading, spacing: 11) {
                sectionHeader("Wochenblick", systemImage: "calendar.badge.clock")

                HStack(spacing: 12) {
                    detailPill(title: "Woche", value: store.formatAmount(store.weeklySpent), systemImage: "calendar.badge.clock", tint: AboLifeColors.review)
                    detailPill(title: "Top Kategorie", value: store.weeklySummary.topCategory ?? "offen", systemImage: "tag", tint: AboLifeColors.finance)
                    detailPill(title: "Einträge", value: "\(store.weeklySummary.entryCount)", systemImage: "list.bullet", tint: AboLifeColors.habits)
                }

                Text(weeklyFinanceSentence)
                    .font(AboLifeTypography.caption)
                    .foregroundStyle(AboLifeColors.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var expensesSection: some View {
        AboLifeCard(isProminent: true) {
            VStack(alignment: .leading, spacing: 13) {
                HStack {
                    Label("Ausgaben diesen Monat", systemImage: "list.bullet.rectangle")
                        .font(AboLifeTypography.cardTitle)
                        .foregroundStyle(AboLifeColors.primaryText)

                    Spacer()

                    AboLifeGlassCapsule {
                        Text(store.formatAmount(store.monthlySpent))
                            .font(AboLifeTypography.micro)
                            .foregroundStyle(AboLifeColors.secondaryText)
                            .monospacedDigit()
                    }
                }

                if let errorMessage = store.errorMessage {
                    errorState(errorMessage)
                } else if store.entries.isEmpty {
                    emptyState
                } else {
                    VStack(spacing: 10) {
                        ForEach(store.entries) { entry in
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
            Text("Diesen Monat noch keine Ausgaben erfasst.")
                .font(AboLifeTypography.body.weight(.semibold))
                .foregroundStyle(AboLifeColors.primaryText)

            Text("Nutze Quick Add, um eine Ausgabe einzutragen.")
                .font(AboLifeTypography.caption)
                .foregroundStyle(AboLifeColors.secondaryText)
        }
        .frame(maxWidth: .infinity, minHeight: 112, alignment: .leading)
    }

    private func errorState(_ message: String) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            Text("Finanzdaten konnten nicht geladen werden.")
                .font(AboLifeTypography.body.weight(.semibold))
                .foregroundStyle(AboLifeColors.primaryText)

            Text(message)
                .font(AboLifeTypography.caption)
                .foregroundStyle(AboLifeColors.secondaryText)

            Button {
                store.reload()
            } label: {
                Label("Erneut versuchen", systemImage: "arrow.clockwise")
            }
            .buttonStyle(.borderedProminent)
            .tint(AboLifeColors.finance)
        }
        .frame(maxWidth: .infinity, minHeight: 112, alignment: .leading)
    }

    private func detailPill(title: String, value: String, systemImage: String, tint: Color) -> some View {
        HStack(spacing: 9) {
            Image(systemName: systemImage)
                .foregroundStyle(tint)
                .frame(width: 18)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(AboLifeTypography.micro)
                    .foregroundStyle(AboLifeColors.secondaryText)

                Text(value)
                    .font(AboLifeTypography.caption.weight(.semibold))
                    .foregroundStyle(AboLifeColors.primaryText)
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, minHeight: 58, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(AboLifeColors.quietFill)
                .overlay {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(AboLifeColors.glassStrokeMuted, lineWidth: 0.6)
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
                    .foregroundStyle(AboLifeColors.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func sectionHeader(_ title: String, systemImage: String) -> some View {
        Label(title, systemImage: systemImage)
            .font(AboLifeTypography.cardTitle)
            .foregroundStyle(AboLifeColors.primaryText)
    }

    private func compactTextField(_ placeholder: String, text: Binding<String>, width: CGFloat? = nil) -> some View {
        TextField(placeholder, text: text)
            .textFieldStyle(.plain)
            .font(AboLifeTypography.caption)
            .foregroundStyle(AboLifeColors.primaryText)
            .padding(.horizontal, 9)
            .frame(width: width, height: 30)
            .background(AboLifeColors.quietFill, in: RoundedRectangle(cornerRadius: 7, style: .continuous))
    }

    private func iconButton(_ systemImage: String, help: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 16, weight: .semibold))
        }
        .buttonStyle(.plain)
        .foregroundStyle(AboLifeColors.finance)
        .help(help)
    }

    private func compactListRow(title: String, value: String, systemImage: String, tint: Color, delete: @escaping () -> Void) -> some View {
        HStack(spacing: 8) {
            Image(systemName: systemImage)
                .foregroundStyle(tint)
                .frame(width: 18)
            Text(title)
                .font(AboLifeTypography.caption)
                .foregroundStyle(AboLifeColors.primaryText)
                .lineLimit(1)
            Spacer()
            Text(value)
                .font(AboLifeTypography.micro)
                .foregroundStyle(AboLifeColors.secondaryText)
                .monospacedDigit()
            Button(role: .destructive, action: delete) {
                Image(systemName: "trash")
            }
            .buttonStyle(.borderless)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(AboLifeColors.quietFill, in: RoundedRectangle(cornerRadius: 7, style: .continuous))
    }

    private func categoryRow(_ summary: FinanceCategorySummary) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(summary.category)
                        .font(AboLifeTypography.body.weight(.semibold))
                        .foregroundStyle(AboLifeColors.primaryText)

                    Text(categoryHint(for: summary))
                        .font(AboLifeTypography.micro)
                        .foregroundStyle(AboLifeColors.secondaryText)
                }

                Spacer()
                Text(summary.budget.map { "\(store.formatAmount(summary.spent)) / \(store.formatAmount($0))" } ?? store.formatAmount(summary.spent))
                    .font(AboLifeTypography.caption.weight(.semibold))
                    .foregroundStyle(summary.isOverBudget ? AboLifeColors.habits : AboLifeColors.secondaryText)
                    .monospacedDigit()
            }

            ProgressView(value: summary.budget == nil ? min(summary.spent / max(store.monthlySpent, 1), 1) : summary.progress)
                .tint(summary.isOverBudget ? AboLifeColors.habits : AboLifeColors.finance)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(AboLifeColors.quietFill, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private func financeBar(title: String, amount: Double, maxAmount: Double, tint: Color) -> some View {
        VStack(spacing: 8) {
            Spacer(minLength: 0)
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(tint.opacity(0.72))
                .frame(width: 54, height: max(CGFloat(amount / maxAmount) * 126, 4))
            Text(title)
                .font(AboLifeTypography.micro)
                .foregroundStyle(AboLifeColors.secondaryText)
                .lineLimit(1)
            Text(store.formatAmount(amount))
                .font(AboLifeTypography.micro)
                .foregroundStyle(AboLifeColors.primaryText)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .frame(maxWidth: .infinity)
    }

    private func financeStatusCapsule(_ title: String, _ value: String, _ tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(title)
                .font(AboLifeTypography.micro)
                .foregroundStyle(AboLifeColors.secondaryText)
            Text(value)
                .font(AboLifeTypography.caption.weight(.semibold))
                .foregroundStyle(tint)
                .monospacedDigit()
                .lineLimit(1)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(AboLifeColors.quietFill, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
    }

    private func insightTile(_ title: String, _ value: String, _ detail: String, _ tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title)
                .font(AboLifeTypography.micro)
                .foregroundStyle(AboLifeColors.secondaryText)
            Text(value)
                .font(AboLifeTypography.caption.weight(.semibold))
                .foregroundStyle(AboLifeColors.primaryText)
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
        .background(AboLifeColors.quietFill, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private func fixedCostRow(_ fixedCost: FinanceFixedCostRecord) -> some View {
        HStack(spacing: 9) {
            Image(systemName: fixedCost.isActive ? "checkmark.circle" : "pause.circle")
                .foregroundStyle(fixedCost.isActive ? AboLifeColors.finance : AboLifeColors.secondaryText)
                .frame(width: 18)

            VStack(alignment: .leading, spacing: 2) {
                Text(fixedCost.title)
                    .font(AboLifeTypography.caption.weight(.semibold))
                    .foregroundStyle(AboLifeColors.primaryText)
                    .lineLimit(1)
                Text("\(fixedCost.category) · fällig Tag \(fixedCost.dueDay)")
                    .font(AboLifeTypography.micro)
                    .foregroundStyle(AboLifeColors.secondaryText)
                    .lineLimit(1)
            }

            Spacer()

            Text(store.formatAmount(fixedCost.amount))
                .font(AboLifeTypography.micro.weight(.semibold))
                .foregroundStyle(AboLifeColors.primaryText)
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
        .background(AboLifeColors.quietFill, in: RoundedRectangle(cornerRadius: 7, style: .continuous))
    }

    private func quietEmptyState(title: String, message: String) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title)
                .font(AboLifeTypography.body.weight(.semibold))
                .foregroundStyle(AboLifeColors.primaryText)
            Text(message)
                .font(AboLifeTypography.caption)
                .foregroundStyle(AboLifeColors.secondaryText)
        }
        .frame(maxWidth: .infinity, minHeight: 88, alignment: .leading)
        .padding(12)
        .background(AboLifeColors.quietFill, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
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
    let items: [String]
    let tint: Color

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 118), spacing: 8)], alignment: .leading, spacing: 8) {
            ForEach(items, id: \.self) { item in
                Text(item)
                    .font(AboLifeTypography.micro.weight(.semibold))
                    .foregroundStyle(AboLifeColors.primaryText)
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

private struct FinanceEntryRow: View {
    let entry: FinanceEntryRecord
    let delete: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 8) {
                    Text(entry.title)
                        .font(AboLifeTypography.body.weight(.semibold))
                        .foregroundStyle(AboLifeColors.primaryText)
                        .lineLimit(1)

                    Text(entry.occurredAt.formatted(.dateTime.day().month(.abbreviated).hour().minute()))
                        .font(AboLifeTypography.micro)
                        .foregroundStyle(AboLifeColors.tertiaryText)
                        .monospacedDigit()
                }

                HStack(spacing: 7) {
                    Text(entry.category)
                        .font(AboLifeTypography.micro)
                        .foregroundStyle(AboLifeColors.finance)

                    if let note = entry.note, !note.isEmpty {
                        Text(note)
                            .font(AboLifeTypography.caption)
                            .foregroundStyle(AboLifeColors.secondaryText)
                            .lineLimit(1)
                    }
                }
            }

            Spacer(minLength: 12)

            Text("\(Int(entry.amount.rounded())) \(entry.currency)")
                .font(AboLifeTypography.caption.weight(.semibold))
                .foregroundStyle(AboLifeColors.primaryText)
                .monospacedDigit()

            Button(role: .destructive, action: delete) {
                Image(systemName: "trash")
                    .font(.system(size: 13, weight: .semibold))
            }
            .buttonStyle(.borderless)
            .help("Löschen")
        }
        .padding(.horizontal, 13)
        .padding(.vertical, 11)
        .background {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(AboLifeColors.quietFill)
                .overlay {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(AboLifeColors.glassStrokeMuted, lineWidth: 0.6)
                }
        }
        .contextMenu {
            Button(role: .destructive, action: delete) {
                Label("Löschen", systemImage: "trash")
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
