import SwiftUI

struct QuickAddGeneralMenu: View {
    @Environment(\.aboLifeStyle) private var designStyle
    let select: (QuickAddKind) -> Void
    let quickHabit: (QuickHabitAction) -> Void

    private var entryActions: [QuickAddAction] { [
        QuickAddAction(kind: .workout, title: "Training / Home-Workout", systemImage: "figure.strengthtraining.traditional", tint: designStyle.colors.training),
        QuickAddAction(kind: .expense, title: "Ausgabe eintragen", systemImage: "eurosign.circle", tint: designStyle.colors.finance),
        QuickAddAction(kind: .weight, title: "Gewicht eintragen", systemImage: "scalemass", tint: designStyle.colors.review),
        QuickAddAction(kind: .habit, title: "Gewohnheit aktualisieren", systemImage: "checkmark.seal", tint: designStyle.colors.habits)
    ] }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            QuickAddSection(title: "Eintragen", systemImage: "square.and.pencil") {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                    ForEach(entryActions) { action in
                        QuickAddChip(title: action.title, systemImage: action.systemImage) {
                            select(action.kind)
                        }
                    }
                }
            }

            QuickAddSection(title: "Schnelle Gewohnheiten", systemImage: "bolt.fill") {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                    ForEach(QuickHabitAction.generalMenuActions) { action in
                        QuickAddChip(title: action.title, systemImage: action.systemImage) {
                            quickHabit(action)
                        }
                    }
                }
            }
        }
    }
}



struct QuickAddTrainingPanel: View {
    @Environment(\.aboLifeStyle) private var designStyle
    @ObservedObject var store: DashboardStore
    let dismiss: DismissAction
    let setStatus: (String) -> Void

    @State private var selectedIntensity: HomeWorkoutIntensity = .normal
    @State private var manualName = ""
    @State private var manualDuration = "30"
    @State private var manualNote = ""
    @State private var durationError: String?

    private var scheduledWorkout: ScheduledHomeWorkout {
        HomeWorkoutPlanProvider.plan.workout(for: Date())
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            QuickAddFormCard(systemImage: "house.fill", title: "Heutiges Home-Workout") {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(scheduledWorkout.day.name)
                            .font(AboLifeTypography.cardTitle)
                            .foregroundStyle(designStyle.colors.primaryText)
                        Text(scheduledWorkout.day.focusText)
                            .font(AboLifeTypography.caption)
                            .foregroundStyle(designStyle.colors.secondaryText)
                    }

                    Spacer()

                    AboLifeGlassCapsule {
                        Text(scheduledWorkout.headline)
                            .font(AboLifeTypography.micro)
                            .foregroundStyle(designStyle.colors.training)
                    }
                }

                Picker("Intensität", selection: $selectedIntensity) {
                    ForEach(HomeWorkoutIntensity.allCases) { intensity in
                        Text("\(intensity.rawValue) · \(intensity.durationMinutes) Min.").tag(intensity)
                    }
                }
                .pickerStyle(.segmented)

                Text(exercisePreview)
                    .font(AboLifeTypography.caption)
                    .foregroundStyle(designStyle.colors.secondaryText)
                    .lineLimit(2)

                QuickAddSubmitButton(title: "Home-Workout abschließen", systemImage: "checkmark.circle.fill") {
                    if store.completeHomeWorkout(intensity: selectedIntensity) {
                        setStatus("Training gespeichert")
                    }
                }
            }

            QuickAddFormCard(systemImage: "square.and.pencil", title: "Training manuell eintragen") {
                labeledTextField("Name / Typ", text: $manualName)
                labeledTextField("Dauer Minuten", text: $manualDuration)
                labeledTextField("Notiz optional", text: $manualNote)

                if let durationError {
                    AboLifeNotice(title: "Dauer prüfen", message: durationError)
                }

                QuickAddSubmitButton(title: "Manuell speichern", systemImage: "plus.circle.fill") {
                    let minutes = parseDouble(manualDuration)
                    guard (1...1440).contains(minutes) else {
                        durationError = "Bitte eine gültige Dauer zwischen 1 und 1440 Minuten eingeben."
                        return
                    }
                    durationError = nil
                    guard store.completeWorkout(type: manualName, durationMinutes: Int(minutes.rounded()), note: manualNote) else { return }
                    manualName = ""
                    manualDuration = "30"
                    manualNote = ""
                    setStatus("Training gespeichert")
                }
            }
        }
    }

    private var exercisePreview: String {
        scheduledWorkout.day.exercises(for: selectedIntensity).map(\.name).joined(separator: " · ")
    }
}

struct QuickAddExpensePanel: View {
    @Environment(\.aboLifeStyle) private var designStyle
    @ObservedObject var store: DashboardStore
    let dismiss: DismissAction
    let setStatus: (String) -> Void

    @State private var title = ""
    @State private var amount = ""
    @State private var category = "Lebensmittel"
    @State private var note = ""
    @FocusState private var focusedField: Field?
    private enum Field { case title, amount }

    @State private var categories = FinanceCategoryCatalog.expenseCategories

    var body: some View {
        QuickAddFormCard(systemImage: "eurosign.circle", title: "Ausgabe") {
            labeledTextField("Titel / Name", text: $title)
                .focused($focusedField, equals: .title)
                .onChange(of: title) { _, newValue in
                    let suggestion = FinanceCategoryCatalog.normalized(newValue, kind: .expense)
                    if categories.contains(suggestion) {
                        category = suggestion
                    }
                }

            labeledTextField("Betrag in \(store.currency)", text: $amount)
                .focused($focusedField, equals: .amount)

            Picker("Kategorie", selection: $category) {
                ForEach(categories, id: \.self) { category in
                    Text(category).tag(category)
                }
            }
            .pickerStyle(.menu)
            .frame(maxWidth: .infinity, alignment: .leading)

            labeledTextField("Notiz optional", text: $note)

            QuickAddSubmitButton(title: "Speichern", systemImage: "checkmark.circle.fill") {
                guard store.addExpense(title: title.isEmpty ? category : title, amount: parseDouble(amount), category: category, note: note) else { return }
                title = ""
                amount = ""
                note = ""
                setStatus("Ausgabe gespeichert")
                focusedField = .title
            }
            .disabled(parseDouble(amount) <= 0 || parseDouble(amount) > 1_000_000_000)
            .keyboardShortcut(.defaultAction)
        }
        .onAppear {
            categories = store.quickExpenseCategories()
            if !categories.contains(category), let first = categories.first { category = first }
            focusedField = .title
        }
    }
}

struct QuickAddHabitPanel: View {
    @Environment(\.aboLifeStyle) private var designStyle
    @ObservedObject var store: DashboardStore
    let setStatus: (String) -> Void

    @State private var values: [String: Double] = [:]

    var body: some View {
        QuickAddFormCard(systemImage: "checkmark.seal", title: "Heute schnell Fortschritt eintragen") {
            VStack(spacing: 10) {
                ForEach(FixedHabit.defaults) { habit in
                    HabitQuickActionRow(
                        habit: habit,
                        value: values[habit.key] ?? 0,
                        decrement: { apply(habit: habit, delta: -habit.stepValue) },
                        increment: { apply(habit: habit, delta: habit.stepValue) },
                        complete: { setSleep(done: true) },
                        reset: { setSleep(done: false) }
                    )
                }
            }
        }
        .onAppear {
            values = store.quickHabitValues()
        }
    }

    private func apply(habit: FixedHabit, delta: Double) {
        let nextValue = store.applyHabitDelta(habitKey: habit.key, delta: delta)
        values[habit.key] = nextValue
        if store.errorMessage == nil { setStatus(status(for: habit, delta: delta)) }
    }

    private func setSleep(done: Bool) {
        guard store.setSleepRoutine(isCompleted: done) else { return }
        values["sleep"] = done ? 1 : 0
        setStatus(done ? "Schlafroutine erledigt" : "Schlafroutine offen")
    }

    private func status(for habit: FixedHabit, delta: Double) -> String {
        let prefix = delta >= 0 ? "+" : "-"
        switch habit.key {
        case "water":
            return "\(prefix)0.25 L Wasser"
        case "nutrition":
            return "\(prefix)1 Mahlzeit"
        case "learning":
            return "\(prefix)15 Min. Lernen"
        default:
            return "\(habit.title) aktualisiert"
        }
    }
}

struct HabitQuickActionRow: View {
    @Environment(\.aboLifeStyle) private var designStyle
    let habit: FixedHabit
    let value: Double
    let decrement: () -> Void
    let increment: () -> Void
    let complete: () -> Void
    let reset: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: habit.systemImage)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(habit.accent)
                .frame(width: 30, height: 30)
                .background(habit.accent.opacity(0.13), in: Circle())

            VStack(alignment: .leading, spacing: 4) {
                Text(habit.title)
                    .font(AboLifeTypography.caption.weight(.semibold))
                    .foregroundStyle(designStyle.colors.primaryText)
                Text(displayText)
                    .font(AboLifeTypography.micro)
                    .foregroundStyle(designStyle.colors.secondaryText)
                    .monospacedDigit()
            }

            Spacer()

            if habit.isDerived {
                AboLifeGlassCapsule {
                    Label(value >= 1 ? "Training erledigt" : "Aus Workouts", systemImage: value >= 1 ? "checkmark.circle" : "arrow.triangle.2.circlepath")
                        .font(AboLifeTypography.micro)
                        .foregroundStyle(habit.accent)
                }
            } else if habit.isBoolean {
                Button(value >= 1 ? "Zurücksetzen" : "Erledigt") {
                    value >= 1 ? reset() : complete()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .tint(designStyle.colors.action)
            } else {
                Button(stepTitle(isNegative: true), action: decrement)
                    .disabled(value <= 0)
                Button(stepTitle(isNegative: false), action: increment)
            }
        }
        .buttonStyle(.bordered)
        .padding(.vertical, 4)
    }

    private var displayText: String {
        habit.isBoolean || habit.isDerived ? (value >= 1 ? "Erledigt" : "Offen") : habit.displayValue(value)
    }

    private func stepTitle(isNegative: Bool) -> String {
        let sign = isNegative ? "-" : "+"
        if habit.key == "water" {
            return "\(sign)0.25 L"
        }
        return "\(sign)\(Int(habit.stepValue.rounded()))"
    }
}

struct QuickAddWeightPanel: View {
    @Environment(\.aboLifeStyle) private var designStyle
    @ObservedObject var store: DashboardStore
    let dismiss: DismissAction
    let setStatus: (String) -> Void

    @State private var weight = ""

    var body: some View {
        QuickAddFormCard(systemImage: "scalemass", title: "Gewicht") {
            Text("Heute")
                .font(AboLifeTypography.caption)
                .foregroundStyle(designStyle.colors.secondaryText)

            labeledTextField("Gewicht in kg", text: $weight)
            QuickAddSubmitButton(title: "Speichern", systemImage: "checkmark.circle.fill") {
                if store.updateWeight(parseDouble(weight)) {
                    weight = ""
                    setStatus("Gewicht gespeichert")
                } else {
                    setStatus("Bitte gib ein plausibles Gewicht ein.")
                }
            }
        }
        .onAppear {
            if let current = store.snapshot.weight.valueKg {
                weight = String(format: "%.1f", current)
            }
        }
    }
}
