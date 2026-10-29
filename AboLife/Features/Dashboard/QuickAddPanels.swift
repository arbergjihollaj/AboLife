import SwiftUI

struct QuickAddGeneralMenu: View {
    let select: (QuickAddKind) -> Void
    let quickHabit: (QuickHabitAction) -> Void

    private let entryActions: [QuickAddAction] = [
        QuickAddAction(kind: .workout, title: "Training / Home-Workout", systemImage: "figure.strengthtraining.traditional", tint: AboLifeColors.training),
        QuickAddAction(kind: .expense, title: "Ausgabe eintragen", systemImage: "eurosign.circle", tint: AboLifeColors.finance),
        QuickAddAction(kind: .weight, title: "Gewicht eintragen", systemImage: "scalemass", tint: AboLifeColors.review),
        QuickAddAction(kind: .habit, title: "Gewohnheit aktualisieren", systemImage: "checkmark.seal", tint: AboLifeColors.habits)
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            QuickAddSection(title: "Eintragen", systemImage: "square.and.pencil") {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                    ForEach(entryActions) { action in
                        QuickAddChip(title: action.title, systemImage: action.systemImage, tint: action.tint) {
                            select(action.kind)
                        }
                    }
                }
            }

            QuickAddSection(title: "Schnelle Gewohnheiten", systemImage: "bolt.fill") {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                    ForEach(QuickHabitAction.generalMenuActions) { action in
                        QuickAddChip(title: action.title, systemImage: action.systemImage, tint: action.tint) {
                            quickHabit(action)
                        }
                    }
                }
            }
        }
    }
}



struct QuickAddTrainingPanel: View {
    @ObservedObject var store: DashboardStore
    let dismiss: DismissAction
    let setStatus: (String) -> Void

    @State private var selectedIntensity: HomeWorkoutIntensity = .normal
    @State private var manualName = ""
    @State private var manualDuration = "30"
    @State private var manualNote = ""

    private var scheduledWorkout: ScheduledHomeWorkout {
        HomeWorkoutPlanProvider.plan.workout(for: Date())
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            QuickAddFormCard(tint: AboLifeColors.training, systemImage: "house.fill", title: "Heutiges Home-Workout") {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(scheduledWorkout.day.name)
                            .font(AboLifeTypography.cardTitle)
                            .foregroundStyle(AboLifeColors.primaryText)
                        Text(scheduledWorkout.day.focusText)
                            .font(AboLifeTypography.caption)
                            .foregroundStyle(AboLifeColors.secondaryText)
                    }

                    Spacer()

                    AboLifeGlassCapsule {
                        Text(scheduledWorkout.headline)
                            .font(AboLifeTypography.micro)
                            .foregroundStyle(AboLifeColors.training)
                    }
                }

                Picker("Intensitaet", selection: $selectedIntensity) {
                    ForEach(HomeWorkoutIntensity.allCases) { intensity in
                        Text("\(intensity.rawValue) · \(intensity.durationMinutes) Min.").tag(intensity)
                    }
                }
                .pickerStyle(.segmented)

                Text(exercisePreview)
                    .font(AboLifeTypography.caption)
                    .foregroundStyle(AboLifeColors.secondaryText)
                    .lineLimit(2)

                QuickAddSubmitButton(title: "Home-Workout abschliessen", systemImage: "checkmark.circle.fill", tint: AboLifeColors.training) {
                    store.completeHomeWorkout(intensity: selectedIntensity)
                    setStatus("Training gespeichert")
                }
            }

            QuickAddFormCard(tint: AboLifeColors.review, systemImage: "square.and.pencil", title: "Training manuell eintragen") {
                labeledTextField("Name / Typ", text: $manualName)
                labeledTextField("Dauer Minuten", text: $manualDuration)
                labeledTextField("Notiz optional", text: $manualNote)

                QuickAddSubmitButton(title: "Manuell speichern", systemImage: "plus.circle.fill", tint: AboLifeColors.training) {
                    store.completeWorkout(type: manualName, durationMinutes: Int(parseDouble(manualDuration).rounded()), note: manualNote)
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
    @ObservedObject var store: DashboardStore
    let dismiss: DismissAction
    let setStatus: (String) -> Void

    @State private var title = ""
    @State private var amount = ""
    @State private var category = "Lebensmittel"
    @State private var note = ""

    private let categories = Array(FinanceCategoryCatalog.expenseCategories.prefix(8))

    var body: some View {
        QuickAddFormCard(tint: AboLifeColors.finance, systemImage: "eurosign.circle", title: "Ausgabe") {
            labeledTextField("Titel / Name", text: $title)
                .onChange(of: title) { _, newValue in
                    let suggestion = FinanceCategoryCatalog.normalized(newValue, kind: .expense)
                    if categories.contains(suggestion) {
                        category = suggestion
                    }
                }

            labeledTextField("Betrag in EUR", text: $amount)

            Picker("Kategorie", selection: $category) {
                ForEach(categories, id: \.self) { category in
                    Text(category).tag(category)
                }
            }
            .pickerStyle(.menu)
            .frame(maxWidth: .infinity, alignment: .leading)

            labeledTextField("Notiz optional", text: $note)

            QuickAddSubmitButton(title: "Speichern", systemImage: "checkmark.circle.fill", tint: AboLifeColors.finance) {
                store.addExpense(title: title.isEmpty ? category : title, amount: parseDouble(amount), category: category, note: note)
                title = ""
                amount = ""
                note = ""
                setStatus("Ausgabe gespeichert")
            }
        }
    }
}

struct QuickAddHabitPanel: View {
    @ObservedObject var store: DashboardStore
    let setStatus: (String) -> Void

    @State private var values: [String: Double] = [:]

    var body: some View {
        QuickAddFormCard(tint: AboLifeColors.habits, systemImage: "checkmark.seal", title: "Heute schnell Fortschritt eintragen") {
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
        setStatus(status(for: habit, delta: delta))
    }

    private func setSleep(done: Bool) {
        store.setSleepRoutine(isCompleted: done)
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
                    .foregroundStyle(AboLifeColors.primaryText)
                Text(displayText)
                    .font(AboLifeTypography.micro)
                    .foregroundStyle(AboLifeColors.secondaryText)
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
                Button(value >= 1 ? "Zuruecksetzen" : "Erledigt") {
                    value >= 1 ? reset() : complete()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .tint(habit.accent)
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
    @ObservedObject var store: DashboardStore
    let dismiss: DismissAction
    let setStatus: (String) -> Void

    @State private var weight = ""

    var body: some View {
        QuickAddFormCard(tint: AboLifeColors.review, systemImage: "scalemass", title: "Gewicht") {
            Text("Heute")
                .font(AboLifeTypography.caption)
                .foregroundStyle(AboLifeColors.secondaryText)

            labeledTextField("Gewicht in kg", text: $weight)
            QuickAddSubmitButton(title: "Speichern", systemImage: "checkmark.circle.fill", tint: AboLifeColors.review) {
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
