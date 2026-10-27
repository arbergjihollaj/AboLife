import Foundation

final class ExternalInputDialogManager {
    private struct ConfirmationRecord {
        let createdAt: Date
        let result: ExternalInputResult
    }

    private struct BarcodeMealDraft: Equatable {
        let product: FoodProductLookupResult
        let grams: Double
        let calories: Int
        let protein: Double
    }

    private enum Step: Equatable {
        case none
        case waitingForWeight
        case waitingForExpenseAmount
        case waitingForExpenseTitle(amount: Double)
        case confirmingExpense(FinanceExpenseDraft)
        case choosingExpenseCategory(FinanceExpenseDraft)
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
    private var confirmations: [String: ConfirmationRecord] = [:]
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
            confirmations[sessionID] = nil
            return start(flow, sessionID: sessionID)
        case let .selectTemplate(id):
            sessions[sessionID] = Step.none
            return service.execute(.mealTemplate(date: Date(), templateId: id), sessionID: sessionID)
        case let .selectHabit(name):
            sessions[sessionID] = Step.none
            return service.execute(.habitCompleted(date: Date(), habitName: name), sessionID: sessionID)
        case let .selectExpenseCategory(name):
            return selectExpenseCategory(name, sessionID: sessionID)
        case .changeExpenseCategory:
            switch sessions[sessionID] ?? .none {
            case let .confirmingExpense(draft):
                sessions[sessionID] = .choosingExpenseCategory(draft)
                return .needsClarification(message: "Welche Kategorie passt besser?", options: FinanceExpenseInputService.categoryActions())
            default:
                return .failure(message: "Es gibt gerade keine Ausgabe, deren Kategorie geändert werden kann.", reason: "no_expense_draft")
            }
        case let .selectBarcodeAmount(grams):
            return prepareBarcodeConfirmation(grams: grams, sessionID: sessionID)
        case .enterBarcodeAmountManually:
            switch sessions[sessionID] ?? .none {
            case let .waitingForBarcodeAmount(product, packageGrams):
                sessions[sessionID] = .waitingForBarcodeManualAmount(product: product, packageGrams: packageGrams)
                return .needsClarification(message: "Wie viele Gramm waren es? Zum Beispiel 80 g.", options: cancelAction)
            default:
                return .failure(message: "Aktuell wartet kein Barcode-Produkt auf eine Mengenangabe.", reason: "no_barcode_product")
            }
        case let .undo(receiptID):
            sessions[sessionID] = Step.none
            confirmations[sessionID] = nil
            return service.undo(receiptID: receiptID, sessionID: sessionID)
        case .confirm:
            return confirm(sessionID: sessionID)
        case .cancel:
            sessions[sessionID] = Step.none
            confirmations[sessionID] = nil
            return .success(message: "Abgebrochen.", affectedModule: .menu)
        }
    }

    private func handleText(_ text: String, sessionID: String) -> ExternalInputResult {
        let parsedIntent = parser.parse(text)
        if case .cancel = parsedIntent {
            sessions[sessionID] = Step.none
            confirmations[sessionID] = nil
            return .success(message: "Abgebrochen.", affectedModule: .menu)
        }
        if case .start = parsedIntent {
            sessions[sessionID] = Step.none
            confirmations[sessionID] = nil
            return service.execute(parsedIntent, sessionID: sessionID)
        }
        if case .help = parsedIntent {
            sessions[sessionID] = Step.none
            confirmations[sessionID] = nil
            return service.execute(parsedIntent, sessionID: sessionID)
        }

        switch sessions[sessionID] ?? .none {
        case .none:
            let intent = parsedIntent
            if case let .expense(date, amount, title, category) = intent {
                let result = prepareExpense(date: date, amount: amount, title: title, category: category, sessionID: sessionID)
                if case .needsClarification = result {
                    return result
                }
                if case .failure = result {
                    return .menu(message: "\(result.message) Was möchtest du eintragen?", actions: ExternalInputAction.mainMenu)
                }
                return result
            }
            let result = service.execute(intent, sessionID: sessionID)
            if case .failure = result {
                return .menu(message: "\(result.message) Was möchtest du eintragen?", actions: ExternalInputAction.mainMenu)
            }
            return result
        case .waitingForWeight:
            guard let value = parser.parseNumber(text) else {
                return .needsClarification(message: "Bitte gib das Gewicht als Zahl ein, zum Beispiel 82,4.", options: cancelAction)
            }
            sessions[sessionID] = Step.none
            return service.execute(.weight(date: Date(), weightKg: value), sessionID: sessionID)
        case .waitingForExpenseAmount:
            guard let amount = parser.parseNumber(text), amount > 0 else {
                return .needsClarification(message: "Bitte gib einen gültigen Betrag ein, zum Beispiel 4,50 oder 12 EUR.", options: cancelAction)
            }
            sessions[sessionID] = .waitingForExpenseTitle(amount: amount)
            return .needsClarification(message: "Wofür war die Ausgabe?", options: cancelAction)
        case let .waitingForExpenseTitle(amount):
            let title = text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !title.isEmpty else {
                return .needsClarification(message: "Bitte gib eine kurze Beschreibung ein.", options: cancelAction)
            }
            return prepareExpense(date: Date(), amount: amount, title: title, category: nil, forceConfirmation: true, sessionID: sessionID)
        case let .confirmingExpense(draft):
            if isConfirmation(text) {
                return executeConfirmed(
                    .expense(date: draft.date, amount: draft.amount, title: draft.title, category: draft.category),
                    sessionID: sessionID
                )
            }
            return .needsClarification(message: "Bitte bestätige mit Speichern, ändere die Kategorie oder brich ab.", options: FinanceExpenseInputService.confirmationActions(category: draft.category))
        case .choosingExpenseCategory:
            return .needsClarification(message: "Bitte wähle eine Kategorie aus der Liste.", options: FinanceExpenseInputService.categoryActions())
        case .waitingForMealName:
            let name = text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !name.isEmpty else {
                return .needsClarification(message: "Bitte gib einen Namen für die Mahlzeit ein.", options: cancelAction)
            }
            sessions[sessionID] = .waitingForMealCalories(name: name)
            return .needsClarification(message: "Wie viele Kalorien?", options: cancelAction)
        case let .waitingForMealCalories(name):
            guard let calories = parser.parseNumber(text), calories >= 0 else {
                return .needsClarification(message: "Bitte gib Kalorien als Zahl ein, zum Beispiel 650 oder 650 kcal.", options: cancelAction)
            }
            sessions[sessionID] = .waitingForMealProtein(name: name, calories: Int(calories.rounded()))
            return .needsClarification(message: "Wie viel Protein in Gramm?", options: cancelAction)
        case let .waitingForMealProtein(name, calories):
            guard let protein = parser.parseNumber(text), protein >= 0 else {
                return .needsClarification(message: "Bitte gib Protein als Zahl ein, zum Beispiel 35 oder 35 g.", options: cancelAction)
            }
            sessions[sessionID] = .confirmingMeal(name: name, calories: calories, protein: protein)
            return .needsClarification(
                message: "Mahlzeit speichern? \(name) - \(calories) kcal, \(ExternalInputFormatting.decimal(protein)) g Protein",
                options: ExternalInputAction.confirmation
            )
        case let .confirmingMeal(name, calories, protein):
            if isConfirmation(text) {
                return executeConfirmed(
                    .meal(date: Date(), name: name, calories: calories, protein: protein, note: nil),
                    sessionID: sessionID
                )
            }
            return .needsClarification(message: "Bitte bestätige mit Speichern oder brich ab.", options: ExternalInputAction.confirmation)
        case .waitingForTemplate:
            return .needsClarification(message: "Bitte wähle eine Vorlage aus der Liste.", options: templateActions())
        case .waitingForHabit:
            let result = service.execute(.habitCompleted(date: Date(), habitName: text), sessionID: sessionID)
            if result.isSuccessfulSave {
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
        confirmations[sessionID] = nil
        let requiredMissing = missingRequiredNutrition(in: product)
        guard requiredMissing.isEmpty else {
            sessions[sessionID] = Step.none
            return .failure(
                message: """
                Produkt gefunden: \(product.name)
                Kalorien oder Protein pro 100 g fehlen: \(requiredMissing.joined(separator: ", ")).
                Ohne diese Angaben berechne ich keine Nährwerte. Bitte trage die Mahlzeit manuell ein.
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
            return service.execute(.workoutCompleted(date: Date(), note: nil), sessionID: sessionID)
        case .habit:
            sessions[sessionID] = .waitingForHabit
            return .needsClarification(message: "Welchen Habit möchtest du erledigen?", options: habitActions())
        }
    }

    private func confirm(sessionID: String) -> ExternalInputResult {
        switch sessions[sessionID] ?? .none {
        case let .confirmingExpense(draft):
            return executeConfirmed(
                .expense(date: draft.date, amount: draft.amount, title: draft.title, category: draft.category),
                sessionID: sessionID
            )
        case let .confirmingMeal(name, calories, protein):
            return executeConfirmed(
                .meal(date: Date(), name: name, calories: calories, protein: protein, note: nil),
                sessionID: sessionID
            )
        case let .confirmingBarcodeMeal(draft):
            return saveBarcodeMeal(draft, sessionID: sessionID)
        default:
            if let result = recentConfirmation(sessionID: sessionID) {
                return result
            }
            return .failure(message: "Es gibt gerade nichts zu speichern.", reason: "nothing_to_confirm")
        }
    }

    private func prepareExpense(
        date: Date,
        amount: Double,
        title: String,
        category: String?,
        forceConfirmation: Bool = false,
        sessionID: String
    ) -> ExternalInputResult {
        guard amount.isFinite, amount > 0 else {
            return .failure(message: "Bitte gib einen gültigen Betrag ein, zum Beispiel 4,50.", reason: "invalid_amount")
        }
        let input = FinanceExpenseInputService()
        let draft = input.draft(date: date, amount: amount, title: title, category: category, explicitCategory: category != nil)
        if forceConfirmation || draft.needsConfirmation {
            sessions[sessionID] = .confirmingExpense(draft)
            return .needsClarification(message: expenseConfirmationMessage(draft), options: FinanceExpenseInputService.confirmationActions(category: draft.category))
        }
        sessions[sessionID] = Step.none
        return service.execute(
            .expense(date: draft.date, amount: draft.amount, title: draft.title, category: draft.category),
            sessionID: sessionID
        )
    }

    private func selectExpenseCategory(_ category: String, sessionID: String) -> ExternalInputResult {
        switch sessions[sessionID] ?? .none {
        case let .confirmingExpense(draft), let .choosingExpenseCategory(draft):
            let updated = FinanceExpenseDraft(
                date: draft.date,
                amount: draft.amount,
                title: draft.title,
                category: FinanceCategoryCatalog.normalized(category, kind: .expense),
                note: draft.note,
                needsConfirmation: false
            )
            sessions[sessionID] = .confirmingExpense(updated)
            return .needsClarification(message: expenseConfirmationMessage(updated), options: FinanceExpenseInputService.confirmationActions(category: updated.category))
        default:
            return .failure(message: "Es gibt gerade keine Ausgabe für diese Kategorie.", reason: "no_expense_draft")
        }
    }

    private func expenseConfirmationMessage(_ draft: FinanceExpenseDraft) -> String {
        """
        Ausgabe speichern?
        \(ExternalInputFormatting.euro(draft.amount)) · \(draft.title)
        Kategorie: \(draft.category)
        """
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
            return .needsClarification(message: "Bitte wähle eine Menge zwischen 1 und 5000 g.", options: cancelAction)
        }
        guard let caloriesPer100g = product.caloriesPer100g,
              let proteinPer100g = product.proteinPer100g else {
            sessions[sessionID] = Step.none
            return .failure(
                message: "Für dieses Produkt fehlen notwendige Nährwerte. Es wurde nichts gespeichert.",
                reason: "barcode_nutrition_missing"
            )
        }
        let draft = BarcodeMealDraft(
            product: product,
            grams: grams,
            calories: Int((caloriesPer100g * grams / 100).rounded()),
            protein: proteinPer100g * grams / 100
        )
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
            ),
            sessionID: sessionID
        )
        guard result.isSuccessfulSave else { return result }
        let status = service.nutritionDayStatus()
        let suffix = status.isEmpty ? "" : "\n\(status)"
        let response = result.replacingMessage(
            """
            Gespeichert:
            \(draft.product.name)
            \(ExternalInputFormatting.decimal(draft.grams, maximumFractionDigits: 1)) g
            \(draft.calories) kcal
            \(ExternalInputFormatting.decimal(draft.protein, maximumFractionDigits: 1)) g Protein
            \(suffix)
            """
        )
        confirmations[sessionID] = ConfirmationRecord(createdAt: Date(), result: response)
        return response
    }

    private func executeConfirmed(_ intent: ExternalInputIntent, sessionID: String) -> ExternalInputResult {
        sessions[sessionID] = Step.none
        let result = service.execute(intent, sessionID: sessionID)
        if result.isSuccessfulSave {
            confirmations[sessionID] = ConfirmationRecord(createdAt: Date(), result: result)
        }
        return result
    }

    private func recentConfirmation(sessionID: String) -> ExternalInputResult? {
        guard let confirmation = confirmations[sessionID] else { return nil }
        guard Date().timeIntervalSince(confirmation.createdAt) <= 30 else {
            confirmations[sessionID] = nil
            return nil
        }
        return confirmation.result
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
        let quantityLine = product.quantityText.map { "Packungsangabe: \($0)\n" } ?? ""
        return """
        Produkt erkannt:
        \(brandLine)\(product.name)
        \(quantityLine)Quelle: Open Food Facts
        Nährwerte pro 100 g:
        • Kalorien: \(nutritionValue(product.caloriesPer100g, unit: "kcal", digits: 0))
        • Protein: \(nutritionValue(product.proteinPer100g, unit: "g", digits: 1))
        • Kohlenhydrate: \(nutritionValue(product.carbsPer100g, unit: "g", digits: 1))
        • Fett: \(nutritionValue(product.fatPer100g, unit: "g", digits: 1))
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
        actions.append(contentsOf: [100, 150, 250].map { grams in
            ExternalInputAction(
                id: "barcode.amount.\(grams)",
                label: "\(grams) g",
                kind: .selectBarcodeAmount(grams: Double(grams))
            )
        })
        actions.append(ExternalInputAction(id: "barcode.manual", label: "Eigene Grammzahl", kind: .enterBarcodeAmountManually))
        actions.append(contentsOf: cancelAction)
        return actions
    }

    private func missingRequiredNutrition(in product: FoodProductLookupResult) -> [String] {
        var missing: [String] = []
        if product.caloriesPer100g == nil { missing.append("Kalorien pro 100 g") }
        if product.proteinPer100g == nil { missing.append("Protein pro 100 g") }
        return missing
    }

    private func nutritionValue(_ value: Double?, unit: String, digits: Int) -> String {
        guard let value else { return "nicht angegeben" }
        return "\(ExternalInputFormatting.decimal(value, maximumFractionDigits: digits)) \(unit)"
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
