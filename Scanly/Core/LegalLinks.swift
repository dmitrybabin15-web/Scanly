import Foundation

/// Privacy and Terms URLs read from `Info.plist` (`ScanlyPrivacyPolicyURL`, `ScanlyTermsOfUseURL`).
/// Defaults are defined in `LegalURLs.plist`, merged with the generated Info.plist. Edit that file or override the keys in build settings.
enum LegalLinks {
    private static let privacyInfoKey = "ScanlyPrivacyPolicyURL"
    private static let termsInfoKey = "ScanlyTermsOfUseURL"

    private static let defaultPrivacyURL = "https://scanly.app/privacy"
    private static let defaultTermsURL = "https://scanly.app/terms"

    static var privacyPolicy: URL {
        url(forInfoKey: privacyInfoKey, fallback: defaultPrivacyURL)
    }

    static var termsOfUse: URL {
        url(forInfoKey: termsInfoKey, fallback: defaultTermsURL)
    }

    private static func url(forInfoKey key: String, fallback: String) -> URL {
        if let raw = Bundle.main.object(forInfoDictionaryKey: key) as? String {
            let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            if let u = URL(string: trimmed), !trimmed.isEmpty {
                return u
            }
        }
        return URL(string: fallback)!
    }
}
