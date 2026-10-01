import Foundation

/// Calls Anthropic Messages API. Set `ANTHROPIC_API_KEY` in the Run scheme (Environment Variables) for local development.
/// For production, route requests through your backend — do not ship API keys in the client binary.
enum AIParsingService {
    private static let endpoint = URL(string: "https://api.anthropic.com/v1/messages")!
    private static let model = "claude-3-5-haiku-20241022"

    private static var apiKey: String? {
        let key = ProcessInfo.processInfo.environment["ANTHROPIC_API_KEY"] ?? ""
        return key.isEmpty ? nil : key
    }

    /// Returns `nil` if no API key, network failure, or parse failure — caller should use OCR heuristics.
    static func parseReceipt(ocrText: String) async -> ParsedReceipt? {
        guard let key = apiKey else { return nil }
        guard !ocrText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }

        let systemPrompt = """
        You extract fields from noisy receipt OCR text for a personal expense app (US/EU).
        Reply with ONE JSON object only. No markdown fences, no commentary.
        Keys: amount (number or null), currencyCode (ISO 4217 string or null), date (string yyyy-MM-dd or null), merchant (string or null), category (string or null).
        category must be one of: Meals, Transport, Groceries, Software, Office, Travel, Healthcare, Utilities, Entertainment, Other.
        Prefer the receipt total (not subtotal) for amount when identifiable.
        """

        let userContent = "OCR text:\n---\n\(ocrText)\n---"

        let body: [String: Any] = [
            "model": model,
            "max_tokens": 1024,
            "system": systemPrompt,
            "messages": [
                ["role": "user", "content": userContent]
            ]
        ]

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(key, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse else { return nil }
            guard (200 ... 299).contains(http.statusCode) else { return nil }

            let decoded = try JSONDecoder().decode(AnthropicEnvelope.self, from: data)
            guard let text = decoded.firstTextBlock else { return nil }
            let jsonString = Self.extractJSONObject(from: text)
            guard let jsonData = jsonString.data(using: .utf8) else { return nil }
            return try JSONDecoder().decode(ParsedReceipt.self, from: jsonData)
        } catch {
            return nil
        }
    }

    private static func extractJSONObject(from text: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if let start = trimmed.firstIndex(of: "{"), let end = trimmed.lastIndex(of: "}") {
            return String(trimmed[start ... end])
        }
        return trimmed
    }

    private struct AnthropicEnvelope: Decodable {
        let content: [Block]

        struct Block: Decodable {
            let type: String
            let text: String?
        }

        var firstTextBlock: String? {
            content.first { $0.type == "text" }?.text
        }
    }
}
