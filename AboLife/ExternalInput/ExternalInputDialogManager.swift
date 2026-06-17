import Foundation

final class ExternalInputDialogManager {
    private struct BarcodeMealDraft: Equatable {
        let product: FoodProductLookupResult
        let grams: Double

        var calories: Int {
            Int(((product.caloriesPer100g ?? 0) * grams / 100).rounded())
        }

        var protein: Double {
            (product.proteinPer100g ?? 0) * grams / 100
        }
    }

    private enum Step: Equatable {
        case none
        case waitingForWeight
        case waitingForExpenseAmount
        case waitingForExpenseTitle(amount: Double)
        case confirmingExpense(amount: Double, title: String)
        case waitingForMealName
        case waitingForMealCalories(name: String)
        case waitingForMealProtein(name: String, calories: Int)
        case confirmingMeal(name: String, calories: Int, protein: Double)
        case waitingForTemplate
        case waitingForHabit
        case waitingForBarcodeAmount(product: FoodProductLookupResult, packageGrams: Double?)
        case waitingForBarcodeManualAmount(product: FoodProductLookupResult, packageGrams: Double?)
        case confirmingBarcodeMeal(BarcodeMealDraft)
    }

    private var sessions: [String: Step] = [:]
    private let service: ExternalInputService
    private let parser: ExternalInputParser

    init(service: ExternalInputService, parser: ExternalInputParser = ExternalInputParser()) {
        self.service = service
        self.parser = parser
    }

    func handle(_ input: ExternalInputDialogInput, sessionID: String = "local") -> ExternalInputResult {
        switch input {
        case let .action(action):
            return handleAction(action, sessionID: sessionID)
        case let .text(text):
            return handleText(text, sessionID: sessionID)
        }
    }

    func hasActiveDialog(sessionID: String = "local") -> Bool {
        (sessions[sessionID] ?? .none) != .none
    }

    private func handleAction(_ action: ExternalInputAction.Kind, sessionID: String) -> ExternalInputResult {
        switch action {
        case let .startFlow(flow):
            return start(flow, sessionID: sessionID)
        case let .selectTemplate(id):
            sessions[sessionID] = Step.none
            return service.execute(.mealTemplate(date: Date(), templateId: id))
        case let .selectHabit(name):
            sessions[sessionID] = Step.none
            return service.execute(.habitCompleted(date: Date(), habitName: name))
        case let .selectBarcodeAmount(grams):
            return prepareBarcodeConfirmation(grams: grams, sessionID: sessionID)
        case .enterBarcodeAmountManually:
            switch sessions[sessionID] ?? .none {
            case let .waitingForBarcodeAmount(product, packageGrams):
                sessions[sessionID] = .waitingForBarcodeManualAmount(product: product, packageGrams: packageGrams)
                return .needsClarification(message: "Bitte Menge in Gramm senden, z. B. 55", options: cancelAction)
            default:
                return .failure(message: "Es gibt gerade kein Barcode-Produkt für eine manuelle Menge.", reason: "no_barcode_product")
            }
        case .confirm:
            return confirm(sessionID: sessionID)
        case .cancel:
            sessions[sessionID] = Step.none
            return .success(message: "Abgebrochen.", affectedModule: .menu)
        }
    }

    private func handleText(_ text: String, sessionID: String) -> ExternalInputResult {
        if case .cancel = parser.parse(text) {
            sessions[sessionID] = Step.none
            return .success(message: "Abgebrochen.", affectedModule: .menu)
        }

        switch sessions[sessionID] ?? .none {
        case .none:
            let intent = parser.parse(text)
            let result = service.execute(intent)
            if case .failure = result {
                return .menu(message: "\(result.message) Was möchtest du eintragen?", actions: ExternalInputAction.mainMenu)
            }
            return result
        case .waitingForWeight:
            guard let value = parser.parseNumber(text) else {
                return .needsClarification(message: "Bitte gib das Gewicht als Zahl ein, zum Beispiel 82,4.", options: cancelAction)
            }
            sessions[sessionID] = Step.none
            return service.execute(.weight(date: Date(), weightKg: value))
        case .waitingForExpenseAmount:
            guard let amount = parser.parseNumber(text), amount > 0 else {
                return .needsClarification(message: "Bitte gib einen gültigen Betrag ein, zum Beispiel 4,50.", options: cancelAction)
            }
            sessions[sessionID] = .waitingForExpenseTitle(amount: amount)
            return .needsClarification(message: "Wofür war die Ausgabe?", options: cancelAction)
        case let .waitingForExpenseTitle(amount):
            let title = text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !title.isEmpty else {
                return .needsClarification(message: "Bitte gib eine kurze Beschreibung ein.", options: cancelAction)
            }
            sessions[sessionID] = .confirmingExpense(amount: amount, title: title)
            return .needsClarification(
                message: "Ausgabe speichern? \(ExternalInputFormatting.euro(amount)) - \(title)",
                options: ExternalInputAction.confirmation
            )
        case let .confirmingExpense(amount, title):
            if isConfirmation(text) {
                sessions[sessionID] = Step.none
                return service.execute(.expense(date: Date(), amount: amount, title: title, category: nil))
            }
            return .needsClarification(message: "Bitte bestätige mit Speichern oder brich ab.", options: ExternalInputAction.confirmation)
        case .waitingForMealName:
            let name = text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !name.isEmpty else {
                return .needsClarification(message: "Bitte gib einen Namen für die Mahlzeit ein.", options: cancelAction)
            }
            sessions[sessionID] = .waitingForMealCalories(name: name)
            return .needsClarification(message: "Wie viele Kalorien?", options: cancelAction)
        case let .waitingForMealCalories(name):
            guard let calories = parser.parseNumber(text), calories >= 0 else {
                return .needsClarification(message: "Bitte gib Kalorien als Zahl ein.", options: cancelAction)
            }
            sessions[sessionID] = .waitingForMealProtein(name: name, calories: Int(calories.rounded()))
            return .needsClarification(message: "Wie viel Protein in Gramm?", options: cancelAction)
        case let .waitingForMealProtein(name, calories):
            guard let protein = parser.parseNumber(text), protein >= 0 else {
                return .needsClarification(message: "Bitte gib Protein als Zahl ein.", options: cancelAction)
            }
            sessions[sessionID] = .confirmingMeal(name: name, calories: calories, protein: protein)
            return .needsClarification(
                message: "Mahlzeit speichern? \(name) - \(calories) kcal, \(ExternalInputFormatting.decimal(protein)) g Protein",
                options: ExternalInputAction.confirmation
            )
        case let .confirmingMeal(name, calories, protein):
            if isConfirmation(text) {
                sessions[sessionID] = Step.none
                return service.execute(.meal(date: Date(), name: name, calories: calories, protein: protein, note: nil))
            }
            return .needsClarification(message: "Bitte bestätige mit Speichern oder brich ab.", options: ExternalInputAction.confirmation)
        case .waitingForTemplate:
            return .needsClarification(message: "Bitte wähle eine Vorlage aus der Liste.", options: templateActions())
        case .waitingForHabit:
            let result = service.execute(.habitCompleted(date: Date(), habitName: text))
            if case .success = result {
                sessions[sessionID] = Step.none
            }
            return result
        case let .waitingForBarcodeAmount(product, packageGrams):
            return parseBarcodeAmountText(text, product: product, packageGrams: packageGrams, sessionID: sessionID)
        case let .waitingForBarcodeManualAmount(product, packageGrams):
            return parseBarcodeAmountText(text, product: product, packageGrams: packageGrams, sessionID: sessionID)
        case let .confirmingBarcodeMeal(draft):
            if isConfirmation(text) {
                return saveBarcodeMeal(draft, sessionID: sessionID)
            }
            return .needsClarification(message: "Bitte bestätige mit Speichern oder brich ab.", options: ExternalInputAction.confirmation)
        }
    }

    func beginBarcodeMeal(product: FoodProductLookupResult, sessionID: String = "local") -> ExternalInputResult {
        guard product.caloriesPer100g != nil, product.proteinPer100g != nil else {
            sessions[sessionID] = Step.none
            return .failure(
                message: """
                Produkt gefunden, aber Kalorien oder Protein pro 100 g fehlen.
                \(product.name)
                Barcode: \(product.barcode)
                Bitte trage diese Mahlzeit manuell mit eigenen Nährwerten ein.
                """,
                reason: "barcode_nutrition_missing"
            )
        }

        let packageGrams = FoodQuantityParser.grams(from: product.quantityText)
        sessions[sessionID] = .waitingForBarcodeAmount(product: product, packageGrams: packageGrams)
        return .needsClarification(message: productPreview(product), options: barcodeAmountActions(packageGrams: packageGrams))
    }

    private func start(_ flow: ExternalInputDialogFlow, sessionID: String) -> ExternalInputResult {
        switch flow {
        case .weight:
            sessions[sessionID] = .waitingForWeight
            return .needsClarification(message: "Welches Gewicht möchtest du für heute speichern?", options: cancelAction)
        case .expense:
            sessions[sessionID] = .waitingForExpenseAmount
            return .needsClarification(message: "Wie viel hast du ausgegeben?", options: cancelAction)
        case .meal:
            sessions[sessionID] = .waitingForMealName
            return .needsClarification(message: "Welche Mahlzeit möchtest du speichern?", options: cancelAction)
        case .mealTemplate:
            sessions[sessionID] = .waitingForTemplate
            let actions = templateActions()
            if actions.count == 1 {
                return .failure(message: "Es gibt noch keine Vorlagen oder Favoriten.", reason: "no_templates")
            }
            return .needsClarification(message: "Welche Vorlage möchtest du als Mahlzeit speichern?", options: actions)
        case .workout:
            sessions[sessionID] = Step.none
            return service.execute(.workoutCompleted(date: Date(), note: nil))
        case .habit:
            sessions[sessionID] = .waitingForHabit
            return .needsClarification(message: "Welchen Habit möchtest du erledigen?", options: habitActions())
        }
    }

    private func confirm(sessionID: String) -> ExternalInputResult {
        switch sessions[sessionID] ?? .none {
        case let .confirmingExpense(amount, title):
            sessions[sessionID] = Step.none
            return service.execute(.expense(date: Date(), amount: amount, title: title, category: nil))
        case let .confirmingMeal(name, calories, protein):
            sessions[sessionID] = Step.none
            return service.execute(.meal(date: Date(), name: name, calories: calories, protein: protein, note: nil))
        case let .confirmingBarcodeMeal(draft):
            return saveBarcodeMeal(draft, sessionID: sessionID)
        default:
            return .failure(message: "Es gibt gerade nichts zu speichern.", reason: "nothing_to_confirm")
        }
    }

    private func prepareBarcodeConfirmation(grams: Double, sessionID: String) -> ExternalInputResult {
        switch sessions[sessionID] ?? .none {
        case let .waitingForBarcodeAmount(product, _), let .waitingForBarcodeManualAmount(product, _):
            return barcodeConfirmation(product: product, grams: grams, sessionID: sessionID)
        default:
            return .failure(message: "Es gibt gerade kein Barcode-Produkt für diese Menge.", reason: "no_barcode_product")
        }
    }

    private func parseBarcodeAmountText(_ text: String, product: FoodProductLookupResult, packageGrams: Double?, sessionID: String) -> ExternalInputResult {
        guard let grams = parseBarcodeGrams(text, packageGrams: packageGrams) else {
            sessions[sessionID] = .waitingForBarcodeManualAmount(product: product, packageGrams: packageGrams)
            return .needsClarification(
                message: "Bitte sende eine gültige Menge in Gramm, z. B. 55 oder 55 g.",
                options: cancelAction
            )
        }
        return barcodeConfirmation(product: product, grams: grams, sessionID: sessionID)
    }

    private func barcodeConfirmation(product: FoodProductLookupResult, grams: Double, sessionID: String) -> ExternalInputResult {
        guard grams.isFinite, grams > 0, grams <= 5_000 else {
            return .needsClarification(message: "Bitte sende eine plausible Menge zwischen 1 und 5000 g.", options: cancelAction)
        }
        let draft = BarcodeMealDraft(product: product, grams: grams)
        sessions[sessionID] = .confirmingBarcodeMeal(draft)
        return .needsClarification(
            message: """
            Speichern?
            \(product.name)
            \(ExternalInputFormatting.decimal(grams, maximumFractionDigits: 1)) g
            \(draft.calories) kcal
            \(ExternalInputFormatting.decimal(draft.protein, maximumFractionDigits: 1)) g Protein
            """,
            options: ExternalInputAction.confirmation
        )
    }

    private func saveBarcodeMeal(_ draft: BarcodeMealDraft, sessionID: String) -> ExternalInputResult {
        sessions[sessionID] = Step.none
        let note = "Telegram Barcode / Open Food Facts / Barcode \(draft.product.barcode)"
        let result = service.execute(
            .meal(
                date: Date(),
                name: draft.product.name,
                calories: draft.calories,
                protein: draft.protein,
                note: note
            )
        )
        guard case .success = result else { return result }
        let status = service.nutritionDayStatus()
        let suffix = status.isEmpty ? "" : "\n\(status)"
        return .success(
            message: """
            Gespeichert:
            \(draft.product.name)
            \(ExternalInputFormatting.decimal(draft.grams, maximumFractionDigits: 1)) g
            \(draft.calories) kcal
            \(ExternalInputFormatting.decimal(draft.protein, maximumFractionDigits: 1)) g Protein
            \(suffix)
            """,
            affectedModule: .nutrition
        )
    }

    private func parseBarcodeGrams(_ text: String, packageGrams: Double?) -> Double? {
        let normalized = text
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "de_DE"))
            .lowercased()
        let withoutUnit = normalized.replacingOccurrences(of: " ", with: "")
        if let grams = FoodQuantityParser.grams(from: normalized) {
            return grams
        }
        if let number = parser.parseNumber(withoutUnit.replacingOccurrences(of: "g", with: "")), number > 0 {
            return number
        }
        if normalized.contains("packung"), let packageGrams {
            let numberText = normalized
                .replacingOccurrences(of: "packung", with: "")
                .replacingOccurrences(of: "packungen", with: "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if let factor = parser.parseNumber(numberText), factor > 0 {
                return factor * packageGrams
            }
        }
        return nil
    }

    private func productPreview(_ product: FoodProductLookupResult) -> String {
        let brandLine = product.brand.map { "\($0)\n" } ?? ""
        return """
        Produkt erkannt:
        \(brandLine)\(product.name)
        Barcode: \(product.barcode)
        Quelle: Open Food Facts
        Nährwerte pro 100 g:
        * \(ExternalInputFormatting.decimal(product.caloriesPer100g ?? 0, maximumFractionDigits: 0)) kcal
        * \(ExternalInputFormatting.decimal(product.proteinPer100g ?? 0, maximumFractionDigits: 1)) g Protein
        Wie viel hast du gegessen?
        """
    }

    private func barcodeAmountActions(packageGrams: Double?) -> [ExternalInputAction] {
        var actions: [ExternalInputAction] = []
        if let packageGrams {
            actions.append(
                ExternalInputAction(
                    id: "barcode.amount.\(Self.callbackNumber(packageGrams))",
                    label: "Ganze Packung \(ExternalInputFormatting.decimal(packageGrams, maximumFractionDigits: 0)) g",
                    kind: .selectBarcodeAmount(grams: packageGrams)
                )
            )
        }
        actions.append(contentsOf: [50, 100, 150].map { grams in
            ExternalInputAction(
                id: "barcode.amount.\(grams)",
                label: "\(grams) g",
                kind: .selectBarcodeAmount(grams: Double(grams))
            )
        })
        actions.append(ExternalInputAction(id: "barcode.manual", label: "Manuell", kind: .enterBarcodeAmountManually))
        actions.append(contentsOf: cancelAction)
        return actions
    }

    private static func callbackNumber(_ value: Double) -> String {
        if value.rounded() == value {
            return String(Int(value))
        }
        return String(value).replacingOccurrences(of: ",", with: ".")
    }

    private func templateActions() -> [ExternalInputAction] {
        service.templates() + cancelAction
    }

    private func habitActions() -> [ExternalInputAction] {
        service.habits() + cancelAction
    }

    private var cancelAction: [ExternalInputAction] {
        [ExternalInputAction(id: "flow.cancel", label: "Abbrechen", kind: .cancel)]
    }

    private func isConfirmation(_ text: String) -> Bool {
        let normalized = text.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "de_DE")).lowercased()
        return ["speichern", "ja", "ok", "bestätigen", "bestaetigen"].contains(normalized)
    }
}
