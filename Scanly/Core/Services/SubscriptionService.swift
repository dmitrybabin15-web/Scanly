import Combine
import Foundation
import RevenueCat

/// RevenueCat entitlement identifier — create the same ID in the RevenueCat dashboard (`pro`).
enum SubscriptionEntitlements {
    static let pro = "pro"
}

@MainActor
final class SubscriptionService: ObservableObject {
    static let shared = SubscriptionService()

    private static let quotaKey = "scanly.freeScanSaves"
    private let freeScanLimit = 5

    @Published private(set) var isPro: Bool = false
    @Published private(set) var isRevenueCatConfigured: Bool = false
    @Published private(set) var freeScansUsed: Int
    @Published private(set) var primaryPackagePrice: String = "—"
    /// Shown when App Store / RevenueCat expose an introductory offer on the primary package.
    @Published private(set) var introductoryOfferLine: String?

    private init() {
        freeScansUsed = UserDefaults.standard.integer(forKey: Self.quotaKey)
    }

    var freeScansRemaining: Int {
        max(0, freeScanLimit - freeScansUsed)
    }

    /// Free tier allows saving up to `freeScanLimit` scans; Pro is unlimited.
    func canStartNewScan() -> Bool {
        isPro || freeScansUsed < freeScanLimit
    }

    func configure() async {
        guard let apiKey = ProcessInfo.processInfo.environment["REVENUECAT_API_KEY"], !apiKey.isEmpty else {
            isRevenueCatConfigured = false
            isPro = false
            await loadPricePlaceholder()
            return
        }

        Purchases.logLevel = .warn
        Purchases.configure(withAPIKey: apiKey)
        isRevenueCatConfigured = true

        await refreshCustomerInfo()
        await loadOfferingsPrice()
    }

    func refreshCustomerInfo() async {
        guard isRevenueCatConfigured else {
            isPro = false
            return
        }
        do {
            let info = try await Purchases.shared.customerInfo()
            isPro = info.entitlements[SubscriptionEntitlements.pro]?.isActive == true
        } catch {
            isPro = false
        }
    }

    private func loadPricePlaceholder() async {
        primaryPackagePrice = "—"
        introductoryOfferLine = nil
    }

    func loadOfferingsPrice() async {
        guard isRevenueCatConfigured else {
            await loadPricePlaceholder()
            return
        }
        do {
            let offerings = try await Purchases.shared.offerings()
            if let package = offerings.current?.availablePackages.first {
                primaryPackagePrice = package.localizedPriceString
                if let intro = package.localizedIntroductoryPriceString, !intro.isEmpty {
                    introductoryOfferLine = String(
                        format: String(localized: String.LocalizationValue("paywall_intro_format")),
                        locale: .current,
                        intro,
                        package.localizedPriceString
                    )
                } else {
                    introductoryOfferLine = nil
                }
            } else {
                primaryPackagePrice = "—"
                introductoryOfferLine = nil
            }
        } catch {
            primaryPackagePrice = "—"
            introductoryOfferLine = nil
        }
    }

    func purchaseDefaultPackage() async throws {
        guard isRevenueCatConfigured else {
            throw SubscriptionError.revenueCatNotConfigured
        }
        let offerings = try await Purchases.shared.offerings()
        guard let package = offerings.current?.availablePackages.first else {
            throw SubscriptionError.noPackage
        }
        _ = try await Purchases.shared.purchase(package: package)
        await refreshCustomerInfo()
    }

    func restorePurchases() async throws {
        guard isRevenueCatConfigured else {
            throw SubscriptionError.revenueCatNotConfigured
        }
        _ = try await Purchases.shared.restorePurchases()
        await refreshCustomerInfo()
    }

    /// Call after a receipt from Scan is saved while the user is not Pro.
    func recordFreeScanSaveIfNeeded() {
        guard !isPro else { return }
        freeScansUsed = min(freeScanLimit, freeScansUsed + 1)
        UserDefaults.standard.set(freeScansUsed, forKey: Self.quotaKey)
    }

#if DEBUG
    /// Testing helper to restart free-tier flow without reinstalling the app.
    func debugResetFreeScanUsage() {
        freeScansUsed = 0
        UserDefaults.standard.set(0, forKey: Self.quotaKey)
    }
#endif
}

enum SubscriptionError: LocalizedError {
    case revenueCatNotConfigured
    case noPackage

    var errorDescription: String? {
        switch self {
        case .revenueCatNotConfigured:
            return String(localized: String.LocalizationValue("error_subscription_not_configured"))
        case .noPackage:
            return String(localized: String.LocalizationValue("error_no_package"))
        }
    }
}
