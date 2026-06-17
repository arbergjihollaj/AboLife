import Foundation

enum FoodQuantityParser {
    static func grams(from text: String?) -> Double? {
        let value = (text ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: ",", with: ".")
            .lowercased()
        guard !value.isEmpty else { return nil }
        guard !value.contains("ml") else { return nil }

        if let total = gramsFromMultiplier(value) {
            return total
        }
        return gramsFromSingleValue(value)
    }

    private static func gramsFromSingleValue(_ value: String) -> Double? {
        let pattern = #"^\s*([0-9]+(?:\.[0-9]+)?)\s*g(?:ramm|rams)?\s*$"#
        guard let match = firstMatch(pattern: pattern, in: value),
              let raw = capture(1, in: value, match: match),
              let grams = Double(raw),
              grams > 0 else {
            return nil
        }
        return grams
    }

    private static func gramsFromMultiplier(_ value: String) -> Double? {
        let pattern = #"^\s*([0-9]+(?:\.[0-9]+)?)\s*x\s*([0-9]+(?:\.[0-9]+)?)\s*g(?:ramm|rams)?\s*$"#
        guard let match = firstMatch(pattern: pattern, in: value),
              let countText = capture(1, in: value, match: match),
              let gramsText = capture(2, in: value, match: match),
              let count = Double(countText),
              let grams = Double(gramsText),
              count > 0,
              grams > 0 else {
            return nil
        }
        return count * grams
    }

    private static func firstMatch(pattern: String, in value: String) -> NSTextCheckingResult? {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        return regex.firstMatch(in: value, range: NSRange(value.startIndex..<value.endIndex, in: value))
    }

    private static func capture(_ index: Int, in value: String, match: NSTextCheckingResult) -> String? {
        guard match.numberOfRanges > index,
              let range = Range(match.range(at: index), in: value) else {
            return nil
        }
        return String(value[range])
    }
}
