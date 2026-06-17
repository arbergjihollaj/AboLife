import SwiftUI

struct NutritionView: View {
    @StateObject private var store: NutritionStore
    @State private var templateSheet: NutritionTemplateSheet?

    init(database: AppDatabase?) {
        _store = StateObject(wrappedValue: NutritionStore(database: database))
    }

    var body: some View {
        ZStack {
            AboLifePremiumBackground()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    header
                    ringOverview
                    templatesSection
                    mealsSection
                }
                .padding(22)
            }
        }
        .navigationTitle("")
        .onAppear {
            store.reload()
        }
        .sheet(item: $templateSheet) { sheet in
            NutritionTemplateSheetView(store: store, sheet: sheet)
                .frame(minWidth: 440)
                .padding(20)
        }
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Ernährung")
                    .font(AboLifeTypography.dashboardTitle)
                    .foregroundStyle(AboLifeColors.primaryText)

                Text(store.dateSubtitle)
                    .font(AboLifeTypography.body)
                    .foregroundStyle(AboLifeColors.secondaryText)
            }

            Spacer()

            DatePicker("", selection: $store.selectedDate, displayedComponents: .date)
                .datePickerStyle(.compact)
                .labelsHidden()
                .frame(width: 132)

            Button {
                store.selectToday()
            } label: {
                Image(systemName: "calendar")
                    .font(.system(size: 14, weight: .semibold))
            }
            .buttonStyle(.bordered)
            .help("Heute")
            .disabled(store.isToday)

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

    private var ringOverview: some View {
        AboLifeCard(isProminent: true) {
            VStack(spacing: 16) {
                NutritionDoubleRingView(
                    caloriesConsumed: store.caloriesConsumed,
                    caloriesTarget: store.caloriesTarget,
                    proteinConsumed: store.proteinConsumed,
                    proteinTarget: store.proteinTarget,
                    caloriesProgress: store.caloriesProgress,
                    proteinProgress: store.proteinProgress
                )
                .frame(maxWidth: .infinity)

                HStack(spacing: 12) {
                    ringSummaryPill(
                        title: "Kalorien",
                        value: "\(store.caloriesConsumed) / \(store.caloriesTarget) kcal",
                        tint: AboLifeColors.nutrition
                    )

                    ringSummaryPill(
                        title: "Protein",
                        value: "\(Int(store.proteinConsumed)) / \(Int(store.proteinTarget)) g",
                        tint: AboLifeColors.protein
                    )

                    ringSummaryPill(
                        title: store.entries.count == 1 ? "Eintrag" : "Einträge",
                        value: "\(store.entries.count)",
                        tint: AboLifeColors.review
                    )
                }

                Text(statusMessage)
                    .font(AboLifeTypography.caption)
                    .foregroundStyle(AboLifeColors.secondaryText)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 460)
            }
            .frame(maxWidth: .infinity)
        }
    }

    private var mealsSection: some View {
        AboLifeCard(isProminent: true) {
            VStack(alignment: .leading, spacing: 13) {
                HStack {
                    Label("Mahlzeiten", systemImage: "fork.knife")
                        .font(AboLifeTypography.cardTitle)
                        .foregroundStyle(AboLifeColors.primaryText)

                    Spacer()

                    AboLifeGlassCapsule {
                        Text("\(store.caloriesConsumed) kcal · \(Int(store.proteinConsumed)) g")
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
                            NutritionEntryRow(entry: entry) {
                                store.deleteEntry(id: entry.id)
                            }
                        }
                    }
                }
            }
        }
    }

    private var templatesSection: some View {
        AboLifeCard(isProminent: true) {
            VStack(alignment: .leading, spacing: 13) {
                HStack {
                    Label("Favoriten & Vorlagen", systemImage: "star.square.on.square")
                        .font(AboLifeTypography.cardTitle)
                        .foregroundStyle(AboLifeColors.primaryText)

                    Spacer()

                    Button {
                        templateSheet = .create(kind: .favorite)
                    } label: {
                        Label("Favorit erstellen", systemImage: "star")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)

                    Button {
                        templateSheet = .create(kind: .mealTemplate)
                    } label: {
                        Label("Vorlage erstellen", systemImage: "plus")
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                    .tint(AboLifeColors.nutrition)
                }

                if let message = store.templateMessage {
                    Text(message)
                        .font(AboLifeTypography.caption)
                        .foregroundStyle(AboLifeColors.secondaryText)
                }

                if store.templates.isEmpty {
                    templatesEmptyState
                } else {
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], alignment: .leading, spacing: 10) {
                        ForEach(store.templates) { template in
                            NutritionTemplateRow(
                                template: template,
                                addToday: { store.addTemplateAsMeal(template, date: Date()) },
                                adjust: { templateSheet = .add(template) },
                                edit: { templateSheet = .edit(template) },
                                delete: { store.deleteTemplate(id: template.id) }
                            )
                        }
                    }
                }
            }
        }
    }

    private var templatesEmptyState: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text("Noch keine Favoriten")
                .font(AboLifeTypography.body.weight(.semibold))
                .foregroundStyle(AboLifeColors.primaryText)

            Text("Lege häufige Mahlzeiten an, damit du sie schneller eintragen kannst.")
                .font(AboLifeTypography.caption)
                .foregroundStyle(AboLifeColors.secondaryText)
        }
        .frame(maxWidth: .infinity, minHeight: 92, alignment: .leading)
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text("Heute noch keine Mahlzeit erfasst.")
                .font(AboLifeTypography.body.weight(.semibold))
                .foregroundStyle(AboLifeColors.primaryText)

            Text("Nutze Quick Add, um eine Mahlzeit einzutragen.")
                .font(AboLifeTypography.caption)
                .foregroundStyle(AboLifeColors.secondaryText)

            Text("Oder lege Favoriten an, um häufige Mahlzeiten später schneller einzutragen.")
                .font(AboLifeTypography.caption)
                .foregroundStyle(AboLifeColors.secondaryText)
        }
        .frame(maxWidth: .infinity, minHeight: 112, alignment: .leading)
    }

    private func errorState(_ message: String) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            Text("Ernährungsdaten konnten nicht geladen werden.")
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
            .tint(AboLifeColors.nutrition)
        }
        .frame(maxWidth: .infinity, minHeight: 112, alignment: .leading)
    }

    private var statusMessage: String {
        if store.entries.isEmpty {
            return "Noch keine Mahlzeit auf diesem Tag."
        }

        if store.caloriesConsumed > store.caloriesTarget {
            return "\(store.caloriesConsumed - store.caloriesTarget) kcal über Ziel."
        }

        return "\(store.caloriesRemaining) kcal Restbudget für den Tag."
    }

    private func ringSummaryPill(title: String, value: String, tint: Color) -> some View {
        VStack(spacing: 4) {
            HStack(spacing: 6) {
                Circle()
                    .fill(tint)
                    .frame(width: 6, height: 6)
                Text(title)
                    .font(AboLifeTypography.micro)
                    .foregroundStyle(AboLifeColors.secondaryText)
            }

            Text(value)
                .font(AboLifeTypography.caption.weight(.semibold))
                .foregroundStyle(AboLifeColors.primaryText)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.82)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .frame(maxWidth: 150)
        .background {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(AboLifeColors.quietFill)
                .overlay {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(AboLifeColors.glassStrokeMuted, lineWidth: 0.6)
                }
        }
    }
}

private struct NutritionTemplateRow: View {
    let template: NutritionTemplateRecord
    let addToday: () -> Void
    let adjust: () -> Void
    let edit: () -> Void
    let delete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: template.kind == .favorite ? "star.fill" : "list.bullet.rectangle")
                    .foregroundStyle(template.kind == .favorite ? AboLifeColors.habits : AboLifeColors.nutrition)
                    .frame(width: 20)

                VStack(alignment: .leading, spacing: 4) {
                    Text(template.name)
                        .font(AboLifeTypography.caption.weight(.semibold))
                        .foregroundStyle(AboLifeColors.primaryText)
                        .lineLimit(2)

                    Text(detailText)
                        .font(AboLifeTypography.micro)
                        .foregroundStyle(AboLifeColors.secondaryText)
                        .monospacedDigit()
                        .lineLimit(2)
                }

                Spacer(minLength: 6)
            }

            HStack(spacing: 8) {
                Button("Heute hinzufügen", action: addToday)
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                    .tint(AboLifeColors.nutrition)

                Button("Anpassen", action: adjust)
                    .buttonStyle(.bordered)
                    .controlSize(.small)

                Spacer()

                Button(action: edit) {
                    Image(systemName: "pencil")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .help("Vorlage bearbeiten")

                Button(role: .destructive, action: delete) {
                    Image(systemName: "trash")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .help("Vorlage löschen")
            }
        }
        .padding(13)
        .frame(maxWidth: .infinity, minHeight: 118, alignment: .topLeading)
        .background {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(AboLifeColors.quietFill)
                .overlay {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(AboLifeColors.glassStrokeMuted, lineWidth: 0.6)
                }
        }
    }

    private var detailText: String {
        var parts = ["\(template.caloriesKcal) kcal", "\(Int(template.proteinG)) g Protein"]
        if let mealType = template.mealType {
            parts.append(mealType)
        }
        if let portion = template.defaultPortion {
            parts.append(portion)
        }
        return parts.joined(separator: " · ")
    }
}

private enum NutritionTemplateSheet: Identifiable {
    case create(kind: NutritionTemplateKind)
    case edit(NutritionTemplateRecord)
    case add(NutritionTemplateRecord)

    var id: String {
        switch self {
        case .create(let kind):
            return "create-\(kind.rawValue)"
        case .edit(let template):
            return "edit-\(template.id)"
        case .add(let template):
            return "add-\(template.id)"
        }
    }
}

private struct NutritionTemplateSheetView: View {
    @ObservedObject var store: NutritionStore
    let sheet: NutritionTemplateSheet
    @Environment(\.dismiss) private var dismiss

    @State private var kind: NutritionTemplateKind
    @State private var name: String
    @State private var calories: String
    @State private var protein: String
    @State private var defaultPortion: String
    @State private var mealType: String
    @State private var note: String
    @State private var localMessage: String?

    private let mealTypes = ["", "Frühstück", "Mittag", "Abend", "Snack"]

    init(store: NutritionStore, sheet: NutritionTemplateSheet) {
        self.store = store
        self.sheet = sheet

        switch sheet {
        case .create(let kind):
            _kind = State(initialValue: kind)
            _name = State(initialValue: "")
            _calories = State(initialValue: "")
            _protein = State(initialValue: "")
            _defaultPortion = State(initialValue: "")
            _mealType = State(initialValue: "")
            _note = State(initialValue: "")
        case .edit(let template), .add(let template):
            _kind = State(initialValue: template.kind)
            _name = State(initialValue: template.name)
            _calories = State(initialValue: "\(template.caloriesKcal)")
            _protein = State(initialValue: String(format: "%.0f", template.proteinG))
            _defaultPortion = State(initialValue: template.defaultPortion ?? "")
            _mealType = State(initialValue: template.mealType ?? "")
            _note = State(initialValue: template.note ?? "")
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label(title, systemImage: icon)
                .font(AboLifeTypography.cardTitle)
                .foregroundStyle(AboLifeColors.primaryText)

            if isTemplateForm {
                Picker("Typ", selection: $kind) {
                    Text("Favorit").tag(NutritionTemplateKind.favorite)
                    Text("Vorlage").tag(NutritionTemplateKind.mealTemplate)
                }
                .pickerStyle(.segmented)
            }

            labeledTextField("Name", text: $name)

            HStack(spacing: 10) {
                labeledTextField("Kalorien", text: $calories)
                labeledTextField("Protein", text: $protein)
            }

            if isTemplateForm {
                HStack(spacing: 10) {
                    labeledTextField("Portion optional", text: $defaultPortion)

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Mahlzeit optional")
                            .font(AboLifeTypography.caption)
                            .foregroundStyle(AboLifeColors.secondaryText)
                        Picker("Mahlzeit optional", selection: $mealType) {
                            ForEach(mealTypes, id: \.self) { type in
                                Text(type.isEmpty ? "Keine" : type).tag(type)
                            }
                        }
                    }
                }
            }

            TextField("Notiz optional", text: $note, axis: .vertical)
                .lineLimit(2...4)
                .textFieldStyle(.roundedBorder)

            if let localMessage {
                Text(localMessage)
                    .font(AboLifeTypography.caption)
                    .foregroundStyle(AboLifeColors.habits)
            }

            HStack {
                Spacer()
                Button("Abbrechen") {
                    dismiss()
                }
                .buttonStyle(.bordered)

                Button(primaryButtonTitle) {
                    submit()
                }
                .buttonStyle(.borderedProminent)
                .tint(AboLifeColors.nutrition)
            }
        }
        .padding(18)
        .background(AboLifeColors.pageBackground)
    }

    private var isTemplateForm: Bool {
        if case .add = sheet {
            return false
        }
        return true
    }

    private var title: String {
        switch sheet {
        case .create:
            return "Favorit oder Vorlage erstellen"
        case .edit:
            return "Vorlage bearbeiten"
        case .add:
            return "Als Mahlzeit hinzufügen"
        }
    }

    private var icon: String {
        switch sheet {
        case .create, .edit:
            return "star.square.on.square"
        case .add:
            return "fork.knife"
        }
    }

    private var primaryButtonTitle: String {
        switch sheet {
        case .create:
            return "Speichern"
        case .edit:
            return "Aktualisieren"
        case .add:
            return "Heute hinzufügen"
        }
    }

    private func submit() {
        let caloriesValue = NutritionStore.normalizedCalories(parseDouble(calories))
        let proteinValue = parseDouble(protein)

        switch sheet {
        case .create:
            guard store.createTemplate(
                kind: kind,
                name: name,
                caloriesKcal: caloriesValue,
                proteinG: proteinValue,
                defaultPortion: defaultPortion,
                mealType: mealType,
                note: note
            ) else {
                localMessage = store.templateMessage
                return
            }
            dismiss()
        case .edit(let template):
            guard store.updateTemplate(
                id: template.id,
                kind: kind,
                name: name,
                caloriesKcal: caloriesValue,
                proteinG: proteinValue,
                defaultPortion: defaultPortion,
                mealType: mealType,
                note: note
            ) else {
                localMessage = store.templateMessage
                return
            }
            dismiss()
        case .add(let template):
            guard store.addAdjustedTemplateAsMeal(
                template,
                title: name,
                caloriesKcal: caloriesValue,
                proteinG: proteinValue,
                note: note,
                date: Date()
            ) else {
                localMessage = store.templateMessage
                return
            }
            dismiss()
        }
    }
}

private struct NutritionEntryRow: View {
    let entry: NutritionEntryRecord
    let delete: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 8) {
                    Text(entry.title)
                        .font(AboLifeTypography.body.weight(.semibold))
                        .foregroundStyle(AboLifeColors.primaryText)
                        .lineLimit(1)

                    Text(entry.occurredAt.formatted(.dateTime.hour().minute()))
                        .font(AboLifeTypography.micro)
                        .foregroundStyle(AboLifeColors.tertiaryText)
                        .monospacedDigit()
                }

                if let note = entry.note, !note.isEmpty {
                    Text(note)
                        .font(AboLifeTypography.caption)
                        .foregroundStyle(AboLifeColors.secondaryText)
                        .lineLimit(2)
                }
            }

            Spacer(minLength: 12)

            VStack(alignment: .trailing, spacing: 3) {
                Text("\(entry.caloriesKcal) kcal")
                    .font(AboLifeTypography.caption.weight(.semibold))
                    .foregroundStyle(AboLifeColors.primaryText)
                    .monospacedDigit()

                Text("\(Int(entry.proteinG)) g Protein")
                    .font(AboLifeTypography.micro)
                    .foregroundStyle(AboLifeColors.secondaryText)
                    .monospacedDigit()
            }

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

struct NutritionView_Previews: PreviewProvider {
    static var previews: some View {
        NutritionView(database: nil)
            .frame(width: 1000, height: 720)
    }
}
