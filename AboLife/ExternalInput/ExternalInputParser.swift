import Foundation

struct ExternalInputParser {
    var now: () -> Date = Date.init

    func parse(_ rawText: String) -> ExternalInputIntent {
        let text = rawText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else {
            return .unknown(rawText: rawText, reason: "Bitte gib einen kurzen Text ein.")
        }

        let folded = text.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "de_DE"))
        let lowered = folded.lowercased()

        if ["/start", "start"].contains(lowered) { return .start }
        if ["/help", "hilfe", "help"].contains(lowered) { return .help }
        if ["/cancel", "abbrechen", "cancel"].contains(lowered) { return .cancel }

        if ["training pausieren", "training pause", "workout pausieren"].contains(lowered) {
            return .workoutPaused(date: now())
        }

        if ["training minimum erledigt", "workout minimum erledigt", "minimum training erledigt"].contains(lowered) {
            return .homeWorkoutCompleted(date: now(), workoutName: nil, intensity: .minimum, note: "Telegram")
        }

        if ["training erledigt", "workout erledigt", "trainiert"].contains(lowered) {
            return .workoutCompleted(date: now(), note: nil)
        }

        if let workout = parseNamedWorkout(lowered: lowered) {
            return .homeWorkoutCompleted(date: now(), workoutName: workout, intensity: .normal, note: "Telegram")
        }

        if let sets = parseWorkoutSets(text: text, lowered: lowered) {
            return sets
        }

        if lowered.hasPrefix("habit "), lowered.hasSuffix(" erledigt") {
            let name = text
                .dropFirst("Habit ".count)
                .dropLast(" erledigt".count)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            guard !name.isEmpty else {
                return .unknown(rawText: rawText, reason: "Bitte nenne den Habit, der erledigt ist.")
            }
            return .habitCompleted(date: now(), habitName: name)
        }

        if let weight = parseWeight(text: text, lowered: lowered) {
            return weight
        }

        if let meal = parseMeal(text: text, lowered: lowered) {
            return meal
        }

        if let expense = parseExpense(text: text, lowered: lowered) {
            return expense
        }

        return .unknown(rawText: rawText, reason: "Ich konnte die Eingabe noch nicht eindeutig zuordnen.")
    }

    func parseNumber(_ rawValue: String) -> Double? {
        let normalized = rawValue
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: ",", with: ".")
        let candidate: String
        if let match = firstNumber(in: normalized) {
            candidate = match
        } else {
            candidate = normalized
        }
        guard let value = Double(candidate), value.isFinite else { return nil }
        return value
    }

    private func parseWeight(text: String, lowered: String) -> ExternalInputIntent? {
        if ["gewicht status", "gewicht aktuell", "aktuelles gewicht"].contains(lowered) {
            return .weightStatus
        }

        if lowered.hasPrefix("zielgewicht") {
            let remainder = String(text.dropFirst("Zielgewicht".count))
            guard let numberText = firstNumber(in: remainder), let value = parseNumber(numberText) else {
                return .unknown(rawText: text, reason: "Bitte gib das Zielgewicht als Zahl an, zum Beispiel 80.")
            }
            return .weightTarget(weightKg: value)
        }

        if lowered.hasPrefix("zielkorridor") {
            let numbers = allNumbers(in: text).compactMap(parseNumber)
            guard numbers.count >= 2 else {
                return .unknown(rawText: text, reason: "Bitte gib den Zielkorridor mit zwei Zahlen an, zum Beispiel 78 82.")
            }
            return .weightCorridor(lowerKg: numbers[0], upperKg: numbers[1])
        }

        if lowered.hasPrefix("gewicht") {
            let remainder = String(text.dropFirst("Gewicht".count))
            guard let numberText = firstNumber(in: remainder), let value = parseNumber(numberText) else {
                return .unknown(rawText: text, reason: "Bitte gib das Gewicht als Zahl an, zum Beispiel 82,4.")
            }
            return .weight(date: now(), weightKg: value)
        }

        if (lowered.hasSuffix(" kg") || lowered.hasSuffix("kg")), let numberText = firstNumber(in: text), let value = parseNumber(numberText) {
            return .weight(date: now(), weightKg: value)
        }

        return nil
    }

    private func parseExpense(text: String, lowered: String) -> ExternalInputIntent? {
        var source: String
        let isExplicitExpense: Bool
        if lowered.hasPrefix("ausgabe ") {
            source = String(text.dropFirst("Ausgabe ".count))
            isExplicitExpense = true
        } else {
            source = text
            isExplicitExpense = false
        }

        let date = parseRelativeExpenseDate(from: &source) ?? now()

        guard let match = firstNumberMatch(in: source) else {
            return nil
        }
        let trimmedSource = source.trimmingCharacters(in: .whitespacesAndNewlines)
        let numberText = match.value
        guard isExplicitExpense || trimmedSource.hasPrefix(numberText) || plausiblePlainExpense(source: trimmedSource, numberRange: match.range) else { return nil }
        guard let amount = parseNumber(numberText) else {
            return .unknown(rawText: text, reason: "Bitte gib den Betrag als Zahl an.")
        }

        var beforeAmount = String(source[..<match.range.lowerBound])
            .trimmingCharacters(in: .whitespacesAndNewlines)
        var afterAmount = String(source[match.range.upperBound...])
            .replacingOccurrences(of: "€", with: "")
            .replacingOccurrences(of: "eur", with: "", options: [.caseInsensitive])
            .trimmingCharacters(in: .whitespacesAndNewlines)

        let explicitCategoryAfterAmount = extractLeadingCategory(from: &afterAmount)
        let explicitCategoryBeforeAmount = extractTrailingCategory(from: &beforeAmount)
        let explicitCategory = explicitCategoryAfterAmount ?? explicitCategoryBeforeAmount

        var title: String
        if trimmedSource.hasPrefix(numberText) {
            title = afterAmount
        } else {
            title = beforeAmount
        }
        title = title
            .replacingOccurrences(of: "€", with: "")
            .replacingOccurrences(of: "eur", with: "", options: [.caseInsensitive])
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if title.isEmpty, let explicitCategory {
            title = explicitCategory
        }
        guard !title.isEmpty else {
            return .unknown(rawText: text, reason: "Bitte ergänze eine Beschreibung für die Ausgabe.")
        }

        return .expense(date: date, amount: amount, title: title.isEmpty ? "Ausgabe" : title, category: explicitCategory)
    }

    private func parseMeal(text: String, lowered: String) -> ExternalInputIntent? {
        let prefixes = ["essen ", "meal ", "mahlzeit "]
        guard let prefix = prefixes.first(where: { lowered.hasPrefix($0) }) else { return nil }

        let body = String(text.dropFirst(prefix.count)).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !body.isEmpty else {
            return .unknown(rawText: text, reason: "Bitte gib einen Namen für die Mahlzeit an.")
        }

        let lowerBody = body.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "de_DE")).lowercased()
        let calories = value(before: "kcal", in: body, lowered: lowerBody).map { Int($0.rounded()) }
        let protein = value(before: "protein", in: body, lowered: lowerBody)

        let markerRanges = ["kcal", "protein"].compactMap { marker -> String.Index? in
            lowerBody.range(of: marker)?.lowerBound.samePosition(in: body)
        }
        let nameEnd = markerRanges.min() ?? body.endIndex
        var name = String(body[..<nameEnd]).trimmingCharacters(in: .whitespacesAndNewlines)
        while let last = name.split(separator: " ").last, parseNumber(String(last)) != nil {
            name = name.split(separator: " ").dropLast().joined(separator: " ")
        }

        guard !name.isEmpty else {
            return .unknown(rawText: text, reason: "Bitte gib einen Namen für die Mahlzeit an.")
        }

        return .meal(date: now(), name: name, calories: calories, protein: protein, note: nil)
    }

    private func parseNamedWorkout(lowered: String) -> String? {
        guard lowered.hasSuffix(" erledigt") else { return nil }
        let name = lowered.dropLast(" erledigt".count).trimmingCharacters(in: .whitespacesAndNewlines)
        switch name {
        case "pull":
            return "Pull + Core"
        case "push":
            return "Push + Legs"
        case "full body", "fullbody":
            return "Full Body"
        default:
            return nil
        }
    }

    private func parseWorkoutSets(text: String, lowered: String) -> ExternalInputIntent? {
        let parts = text.split(separator: " ").map(String.init)
        guard parts.count >= 3 else { return nil }
        let numbers = parts.dropFirst().compactMap { Int($0) }
        guard numbers.count == parts.count - 1, numbers.allSatisfy({ $0 >= 0 && $0 <= 300 }) else {
            return nil
        }
        let exerciseName = parts[0]
        let knownPrefixes = ["klimm", "liegest", "squat", "squats", "kniebeug", "plank", "rudern"]
        guard knownPrefixes.contains(where: { lowered.hasPrefix($0) }) else { return nil }
        return .workoutExerciseSets(date: now(), exerciseName: exerciseName, reps: numbers)
    }

    private func firstNumber(in text: String) -> String? {
        firstNumberMatch(in: text)?.value
    }

    private func parseRelativeExpenseDate(from source: inout String) -> Date? {
        let trimmed = source.trimmingCharacters(in: .whitespacesAndNewlines)
        let lowered = trimmed.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "de_DE")).lowercased()
        let prefixes: [(String, Int)] = [
            ("gestern ", -1),
            ("heute ", 0)
        ]
        guard let match = prefixes.first(where: { lowered.hasPrefix($0.0) }) else { return nil }
        source = String(trimmed.dropFirst(match.0.count)).trimmingCharacters(in: .whitespacesAndNewlines)
        return Calendar.current.date(byAdding: .day, value: match.1, to: now()) ?? now()
    }

    private func plausiblePlainExpense(source: String, numberRange: Range<String.Index>) -> Bool {
        let before = source[..<numberRange.lowerBound].trimmingCharacters(in: .whitespacesAndNewlines)
        let after = source[numberRange.upperBound...].trimmingCharacters(in: .whitespacesAndNewlines)
        guard !before.isEmpty || !after.isEmpty else { return false }
        if before.split(separator: " ").count <= 4, !before.contains("kcal"), !before.contains("kg") {
            return true
        }
        return source.contains("€") || source.localizedCaseInsensitiveContains(" eur")
    }

    private func extractLeadingCategory(from text: inout String) -> String? {
        let categories = FinanceExpenseInputService.suggestedExpenseCategories.sorted { $0.count > $1.count }
        let normalizedText = normalized(text)
        guard let category = categories.first(where: { normalizedText == normalized($0) || normalizedText.hasPrefix(normalized($0) + " ") }) else {
            return nil
        }
        text = String(text.dropFirst(category.count)).trimmingCharacters(in: .whitespacesAndNewlines)
        return category
    }

    private func extractTrailingCategory(from text: inout String) -> String? {
        let categories = FinanceExpenseInputService.suggestedExpenseCategories.sorted { $0.count > $1.count }
        let normalizedText = normalized(text)
        guard let category = categories.first(where: { normalizedText == normalized($0) || normalizedText.hasSuffix(" " + normalized($0)) }) else {
            return nil
        }
        text = String(text.dropLast(category.count)).trimmingCharacters(in: .whitespacesAndNewlines)
        return category
    }

    private func normalized(_ value: String) -> String {
        value
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "de_DE"))
            .lowercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func firstNumberMatch(in text: String) -> (value: String, range: Range<String.Index>)? {
        let pattern = #"^\s*([0-9]+(?:[\.,][0-9]+)?)|([0-9]+(?:[\.,][0-9]+)?)"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        guard let match = regex.firstMatch(in: text, range: range) else { return nil }
        for index in 1..<match.numberOfRanges {
            let matchRange = match.range(at: index)
            if matchRange.location != NSNotFound, let swiftRange = Range(matchRange, in: text) {
                return (String(text[swiftRange]), swiftRange)
            }
        }
        return nil
    }

    private func allNumbers(in text: String) -> [String] {
        let pattern = #"[0-9]+(?:[\.,][0-9]+)?"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        return regex.matches(in: text, range: range).compactMap { match in
            guard let swiftRange = Range(match.range, in: text) else { return nil }
            return String(text[swiftRange])
        }
    }

    private func value(before marker: String, in text: String, lowered: String) -> Double? {
        guard let markerRange = lowered.range(of: marker),
              let bodyMarkerStart = markerRange.lowerBound.samePosition(in: text) else {
            return nil
        }
        let beforeMarker = String(text[..<bodyMarkerStart])
        return beforeMarker
            .split(separator: " ")
            .reversed()
            .lazy
            .compactMap { parseNumber(String($0)) }
            .first
    }
}
