import SwiftUI

struct QuickAddPlaceholderSheet: View {
    @ObservedObject var store: DashboardStore
    let initialKind: QuickAddKind?

    @Environment(\.dismiss) private var dismiss
    @State private var selectedKind: QuickAddKind?

    private let columns = [
        GridItem(.flexible(minimum: 130), spacing: 14),
        GridItem(.flexible(minimum: 130), spacing: 14)
    ]

    init(store: DashboardStore, initialKind: QuickAddKind? = nil) {
        self.store = store
        self.initialKind = initialKind
        _selectedKind = State(initialValue: initialKind)
    }

    var body: some View {
        ZStack {
            AboLifePremiumBackground()

            VStack(alignment: .leading, spacing: 18) {
                header

                if let selectedKind {
                    flow(for: selectedKind)
                } else {
                    actionGrid
                }
            }
            .padding(24)
            .frame(width: 500)
        }
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 5) {
                Text(selectedAction?.title ?? "Quick Add")
                    .font(AboLifeTypography.dashboardTitle)
                    .foregroundStyle(AboLifeColors.primaryText)
                Text("Lokale Erfassung mit SQLite")
                    .font(AboLifeTypography.caption)
                    .foregroundStyle(AboLifeColors.secondaryText)
            }

            Spacer()

            if selectedKind != nil && selectedKind != .general {
                Button {
                    selectedKind = .general
                } label: {
                    Image(systemName: "chevron.left.circle.fill")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(AboLifeColors.secondaryText)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Zurück")
            }

            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(AboLifeColors.secondaryText)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Schließen")
        }
    }

    private var selectedAction: QuickAddAction? {
        guard let selectedKind, selectedKind != .general else { return nil }
        return QuickAddAction.dashboardActions.first { $0.kind == selectedKind }
    }

    private var actionGrid: some View {
        VStack(alignment: .leading, spacing: 16) {
            AboLifeCard(isProminent: true) {
                VStack(alignment: .leading, spacing: 8) {
                    Label("Schnelle Erfassung", systemImage: "bolt.fill")
                        .font(AboLifeTypography.cardTitle)
                        .foregroundStyle(AboLifeColors.primaryText)

                    Text("Wähle eine Aktion. Die wichtigsten Einträge werden lokal gespeichert.")
                        .font(AboLifeTypography.body)
                        .foregroundStyle(AboLifeColors.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            LazyVGrid(columns: columns, spacing: 14) {
                ForEach(QuickAddAction.dashboardActions) { action in
                    quickAddTile(action)
                }
            }
        }
    }

    @ViewBuilder
    private func flow(for kind: QuickAddKind) -> some View {
        switch kind {
        case .general:
            actionGrid
        case .meal:
            QuickAddMealForm(store: store, dismiss: dismiss)
        case .workout:
            QuickAddWorkoutForm(store: store, dismiss: dismiss)
        case .expense:
            QuickAddExpenseForm(store: store, dismiss: dismiss)
        case .habit:
            QuickAddHabitForm(store: store)
        case .weight:
            QuickAddWeightForm(store: store, dismiss: dismiss)
        case .note:
            QuickAddNoteForm(store: store, dismiss: dismiss)
        }
    }

    private func quickAddTile(_ action: QuickAddAction) -> some View {
        Button {
            selectedKind = action.kind
        } label: {
            HStack(spacing: 11) {
                Image(systemName: action.systemImage)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(action.tint)
                    .frame(width: 28, height: 28)
                    .background(action.tint.opacity(0.10), in: Circle())

                Text(action.title)
                    .font(AboLifeTypography.caption.weight(.medium))
                    .foregroundStyle(AboLifeColors.primaryText)

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 14)
            .frame(maxWidth: .infinity, minHeight: 52)
            .background {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(.thinMaterial)
                    .overlay {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(AboLifeColors.glassSurfaceGradient)
                            .opacity(0.72)
                    }
            }
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(AboLifeColors.glassStrokeMuted.opacity(0.75))
            }
        }
        .buttonStyle(.plain)
    }
}

private struct QuickAddMealForm: View {
    @ObservedObject var store: DashboardStore
    let dismiss: DismissAction

    @State private var name = "Lunch"
    @State private var calories = "650"
    @State private var protein = "42"

    var body: some View {
        QuickAddFormCard(
            tint: AboLifeColors.nutrition,
            systemImage: "fork.knife",
            title: "Mahlzeit hinzufügen",
            submitTitle: "Hinzufügen",
            submitSystemImage: "plus.circle.fill",
            submit: submit
        ) {
            labeledTextField("Name", text: $name)
            labeledTextField("Kalorien", text: $calories)
            labeledTextField("Protein in g", text: $protein)
        }
    }

    private func submit() {
        store.addMeal(
            name: name,
            calories: Int(calories) ?? 0,
            protein: Double(protein.replacingOccurrences(of: ",", with: ".")) ?? 0
        )
        dismiss()
    }
}

private struct QuickAddWorkoutForm: View {
    @ObservedObject var store: DashboardStore
    let dismiss: DismissAction

    @State private var workoutType = "Push Day"
    @State private var duration = 45

    private let workoutTypes = ["Push Day", "Pull Day", "Leg Day", "Cardio"]

    var body: some View {
        QuickAddFormCard(
            tint: AboLifeColors.training,
            systemImage: "figure.strengthtraining.traditional",
            title: "Training abschließen",
            submitTitle: "Training abschließen",
            submitSystemImage: "checkmark.circle.fill",
            submit: submit
        ) {
            Picker("Trainingstyp", selection: $workoutType) {
                ForEach(workoutTypes, id: \.self) { type in
                    Text(type).tag(type)
                }
            }
            .pickerStyle(.segmented)

            Stepper("\(duration) Minuten", value: $duration, in: 10...180, step: 5)
                .font(AboLifeTypography.body)
                .foregroundStyle(AboLifeColors.primaryText)
        }
    }

    private func submit() {
        store.completeWorkout(type: workoutType, durationMinutes: duration)
        dismiss()
    }
}

private struct QuickAddExpenseForm: View {
    @ObservedObject var store: DashboardStore
    let dismiss: DismissAction

    @State private var title = "Essen"
    @State private var amount = "12"
    @State private var category = "Essen"

    private let categories = ["Essen", "Transport", "Haushalt", "Sonstiges"]

    var body: some View {
        QuickAddFormCard(
            tint: AboLifeColors.finance,
            systemImage: "eurosign.circle",
            title: "Ausgabe hinzufügen",
            submitTitle: "Ausgabe hinzufügen",
            submitSystemImage: "plus.circle.fill",
            submit: submit
        ) {
            labeledTextField("Titel", text: $title)
            labeledTextField("Betrag in EUR", text: $amount)

            Picker("Kategorie", selection: $category) {
                ForEach(categories, id: \.self) { category in
                    Text(category).tag(category)
                }
            }
            .pickerStyle(.segmented)
        }
    }

    private func submit() {
        store.addExpense(
            title: title,
            amount: Double(amount.replacingOccurrences(of: ",", with: ".")) ?? 0,
            category: category
        )
        dismiss()
    }
}

private struct QuickAddHabitForm: View {
    @ObservedObject var store: DashboardStore

    var body: some View {
        AboLifeCard(isProminent: true) {
            VStack(alignment: .leading, spacing: 14) {
                Label("Gewohnheit abhaken", systemImage: "checkmark.seal")
                    .font(AboLifeTypography.cardTitle)
                    .foregroundStyle(AboLifeColors.primaryText)

                ForEach(store.state.habits) { habit in
                    Toggle(isOn: Binding(
                        get: { habit.isCompleted },
                        set: { _ in store.toggleHabit(habit.id) }
                    )) {
                        Text(habit.title)
                            .font(AboLifeTypography.body)
                            .foregroundStyle(AboLifeColors.primaryText)
                    }
                    .toggleStyle(.checkbox)
                }
            }
        }
    }
}

private struct QuickAddWeightForm: View {
    @ObservedObject var store: DashboardStore
    let dismiss: DismissAction

    @State private var weight = "82.0"

    var body: some View {
        QuickAddFormCard(
            tint: AboLifeColors.review,
            systemImage: "scalemass",
            title: "Gewicht merken",
            submitTitle: "Gewicht speichern",
            submitSystemImage: "checkmark.circle.fill",
            submit: submit
        ) {
            labeledTextField("Gewicht in kg", text: $weight)
        }
    }

    private func submit() {
        store.updateWeight(Double(weight.replacingOccurrences(of: ",", with: ".")) ?? 0)
        dismiss()
    }
}

private struct QuickAddNoteForm: View {
    @ObservedObject var store: DashboardStore
    let dismiss: DismissAction

    @State private var note = ""

    var body: some View {
        QuickAddFormCard(
            tint: AboLifeColors.protein,
            systemImage: "note.text",
            title: "Tagesnotiz",
            submitTitle: "Notiz speichern",
            submitSystemImage: "checkmark.circle.fill",
            submit: submit
        ) {
            TextField("Kurzer Gedanke zum Tag", text: $note, axis: .vertical)
                .lineLimit(3...5)
                .textFieldStyle(.roundedBorder)
        }
        .onAppear {
            note = store.state.dailyNote ?? ""
        }
    }

    private func submit() {
        store.updateDailyNote(note)
        dismiss()
    }
}

private struct QuickAddFormCard<Fields: View>: View {
    let tint: Color
    let systemImage: String
    let title: String
    let submitTitle: String
    let submitSystemImage: String
    let submit: () -> Void
    let fields: Fields

    init(
        tint: Color,
        systemImage: String,
        title: String,
        submitTitle: String,
        submitSystemImage: String,
        submit: @escaping () -> Void,
        @ViewBuilder fields: () -> Fields
    ) {
        self.tint = tint
        self.systemImage = systemImage
        self.title = title
        self.submitTitle = submitTitle
        self.submitSystemImage = submitSystemImage
        self.submit = submit
        self.fields = fields()
    }

    var body: some View {
        AboLifeCard(isProminent: true) {
            VStack(alignment: .leading, spacing: 14) {
                Label(title, systemImage: systemImage)
                    .font(AboLifeTypography.cardTitle)
                    .foregroundStyle(AboLifeColors.primaryText)

                VStack(alignment: .leading, spacing: 12) {
                    fields
                }

                HStack {
                    Spacer()
                    Button(action: submit) {
                        Label(submitTitle, systemImage: submitSystemImage)
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .tint(tint)
                }
            }
        }
    }
}

@ViewBuilder
private func labeledTextField(_ title: String, text: Binding<String>) -> some View {
    VStack(alignment: .leading, spacing: 6) {
        Text(title)
            .font(AboLifeTypography.caption)
            .foregroundStyle(AboLifeColors.secondaryText)

        TextField(title, text: text)
            .textFieldStyle(.roundedBorder)
    }
}
