import Foundation

/// Structured output expected from the AI (JSON). All fields optional — UI falls back to heuristics.
struct ParsedReceipt: Codable, Equatable {
    var amount: Double?
    var currencyCode: String?
    /// ISO 8601 calendar date, e.g. `2026-04-19`
    var date: String?
    var merchant: String?
    var category: String?
}
