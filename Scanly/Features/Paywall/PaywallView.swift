import SwiftUI

struct PaywallView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var subscription: SubscriptionService

    @State private var isPurchasing = false
    @State private var isRestoring = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    Image(systemName: "infinity")
                        .font(.system(size: 44))
                        .foregroundStyle(.tint)

                    Text("paywall_title")
                        .font(.title.bold())

                    Text("paywall_subtitle")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)

                    VStack(alignment: .leading, spacing: 8) {
                        labelRow("paywall_feature_unlimited", systemImage: "doc.viewfinder")
                        labelRow("paywall_feature_csv", systemImage: "square.and.arrow.up")
                        labelRow("paywall_feature_pdf", systemImage: "doc.richtext")
                        labelRow("paywall_feature_insights", systemImage: "chart.pie")
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(RoundedRectangle(cornerRadius: 12).fill(Color(.secondarySystemGroupedBackground)))

                    Text(subscription.primaryPackagePrice)
                        .font(.title2.weight(.semibold))
                        .monospacedDigit()

                    if let intro = subscription.introductoryOfferLine {
                        Text(intro)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }

                    Button {
                        Task { await purchase() }
                    } label: {
                        if isPurchasing {
                            ProgressView()
                                .tint(.white)
                                .frame(maxWidth: .infinity)
                        } else {
                            Text("paywall_subscribe")
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(isPurchasing || isRestoring)

                    Button("paywall_restore") {
                        Task { await restore() }
                    }
                    .disabled(isPurchasing || isRestoring)

                    if !subscription.isRevenueCatConfigured {
                        Text("paywall_revenuecat_hint")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        Text("paywall_payment_terms")
                            .font(.caption2)
                            .foregroundStyle(.secondary)

                        HStack(spacing: 16) {
                            Link("paywall_privacy", destination: LegalLinks.privacyPolicy)
                            Link("paywall_terms", destination: LegalLinks.termsOfUse)
                        }
                        .font(.caption)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 8)
                }
                .padding()
            }
            .navigationTitle("paywall_nav_upgrade")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("paywall_close") { dismiss() }
                }
            }
            .alert("paywall_alert_purchase", isPresented: Binding(get: { errorMessage != nil }, set: { _ in errorMessage = nil })) {
                Button("common_ok", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "")
            }
            .task {
                await subscription.loadOfferingsPrice()
            }
        }
    }

    private func labelRow(_ key: LocalizedStringKey, systemImage: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: systemImage)
                .foregroundStyle(.tint)
            Text(key)
        }
    }

    private func purchase() async {
        isPurchasing = true
        defer { isPurchasing = false }
        do {
            try await subscription.purchaseDefaultPackage()
            if subscription.isPro {
                dismiss()
            }
        } catch {
            errorMessage = displayErrorMessage(error, fallbackKey: "paywall_error_purchase_fallback")
        }
    }

    private func restore() async {
        isRestoring = true
        defer { isRestoring = false }
        do {
            try await subscription.restorePurchases()
            if subscription.isPro {
                dismiss()
            }
        } catch {
            errorMessage = displayErrorMessage(error, fallbackKey: "paywall_error_restore_fallback")
        }
    }

    private func displayErrorMessage(_ error: Error, fallbackKey: String) -> String {
        displayErrorMessage(error, fallback: String(localized: String.LocalizationValue(fallbackKey)))
    }

    private func displayErrorMessage(_ error: Error, fallback: String) -> String {
        let text = error.localizedDescription.trimmingCharacters(in: .whitespacesAndNewlines)
        if text.isEmpty || text == "The operation couldn’t be completed." {
            return fallback
        }
        return text
    }
}

#Preview {
    PaywallView(subscription: SubscriptionService.shared)
}
