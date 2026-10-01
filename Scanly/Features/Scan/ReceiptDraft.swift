import Foundation

struct ReceiptDraft {
    var merchant: String
    var amount: String
    var currencyCode: String
    var date: Date
    var category: String
    var rawText: String

    private static let allowedCategories: Set<String> = [
        "Meals", "Transport", "Groceries", "Software", "Office", "Travel",
        "Healthcare", "Utilities", "Entertainment", "Other"
    ]

    static func fromOCRText(_ text: String) -> ReceiptDraft {
        fromOCRText(text, ai: nil)
    }

    /// Heuristic OCR parsing, optionally merged with AI (`ParsedReceipt`) when available.
    static func fromOCRText(_ text: String, ai: ParsedReceipt?) -> ReceiptDraft {
        let base = ReceiptDraft(
            merchant: guessMerchant(in: text),
            amount: guessAmount(in: text),
            currencyCode: guessCurrency(in: text),
            date: guessDate(in: text) ?? Date(),
            category: "Other",
            rawText: text
        )
        guard let ai else { return base }

        let merchant = ai.merchant.flatMap { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.flatMap { $0.isEmpty ? nil : $0 } ?? base.merchant

        let amountString: String
        if let amount = ai.amount {
            amountString = formatAmount(amount)
        } else {
            amountString = base.amount
        }

        let currency = normalizeCurrency(ai.currencyCode) ?? base.currencyCode

        let date = parseAISODate(ai.date) ?? base.date

        let category = normalizedCategory(ai.category) ?? base.category

        return ReceiptDraft(
            merchant: merchant,
            amount: amountString,
            currencyCode: currency,
            date: date,
            category: category,
            rawText: text
        )
    }

    var parsedAmount: Double { Double(amount.replacingOccurrences(of: ",", with: ".")) ?? 0 }

    private static func formatAmount(_ value: Double) -> String {
        String(format: "%.2f", value)
    }

    private static func normalizeCurrency(_ code: String?) -> String? {
        guard let code else { return nil }
        let trimmed = code.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard trimmed.count == 3, trimmed.range(of: "^[A-Z]{3}$", options: .regularExpression) != nil else {
            return nil
        }
        return trimmed
    }

    private static func parseAISODate(_ string: String?) -> Date? {
        guard let string else { return nil }
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withFullDate, .withDashSeparatorInDate]
        if let d = iso.date(from: trimmed) { return d }

        let df = DateFormatter()
        df.calendar = Calendar(identifier: .gregorian)
        df.locale = Locale(identifier: "en_US_POSIX")
        df.timeZone = TimeZone(secondsFromGMT: 0)
        df.dateFormat = "yyyy-MM-dd"
        return df.date(from: trimmed)
    }

    private static func normalizedCategory(_ raw: String?) -> String? {
        guard let raw else { return nil }
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard allowedCategories.contains(trimmed) else { return nil }
        return trimmed
    }

    private static func guessMerchant(in text: String) -> String {
        let lines = text
            .split(separator: "\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        return lines.first(where: { line in
            let hasLetter = line.range(of: "[A-Za-z]", options: .regularExpression) != nil
            let mostlyDigits = line.range(of: "^[0-9 .,:-]+$", options: .regularExpression) != nil
            return hasLetter && !mostlyDigits
        }) ?? ""
    }

    private static func guessAmount(in text: String) -> String {
        let pattern = #"(?i)(total|amount|sum)\s*[: ]?\$?€?\s*([0-9]+[\.,][0-9]{2})"#
        if let regex = try? NSRegularExpression(pattern: pattern),
           let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
           let range = Range(match.range(at: 2), in: text) {
            return String(text[range])
        }

        let fallbackPattern = #"[0-9]+[\.,][0-9]{2}"#
        if let regex = try? NSRegularExpression(pattern: fallbackPattern) {
            let matches = regex.matches(in: text, range: NSRange(text.startIndex..., in: text))
            if let last = matches.last, let range = Range(last.range, in: text) {
                return String(text[range])
            }
        }
        return ""
    }

    private static func guessCurrency(in text: String) -> String {
        if text.contains("€") { return "EUR" }
        return "USD"
    }

    private static func guessDate(in text: String) -> Date? {
        let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.date.rawValue)
        let range = NSRange(text.startIndex..., in: text)
        return detector?.firstMatch(in: text, range: range)?.date
    }
}
