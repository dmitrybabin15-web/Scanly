import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var subscription: SubscriptionService

    @State private var showPaywall = false
    @State private var isRestoring = false
    @State private var alertMessage: String?
#if DEBUG
    @State private var showQAChecklist = false
#endif

    var body: some View {
        List {
            Section {
                HStack {
                    Text("settings_plan")
                    Spacer()
                    Text(subscription.isPro ? "settings_plan_pro_name" : "settings_plan_free")
                        .foregroundStyle(.secondary)
                }

                if !subscription.isPro {
                    HStack {
                        Text("settings_free_scans_left")
                        Spacer()
                        Text("\(subscription.freeScansRemaining)")
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }
                }

                if !subscription.isPro {
                    Button("settings_upgrade_pro") {
                        showPaywall = true
                    }
                }

                Button {
                    Task { await restore() }
                } label: {
                    HStack {
                        Text("settings_restore_purchases")
                        if isRestoring {
                            Spacer()
                            ProgressView()
                        }
                    }
                }
                .disabled(isRestoring || !subscription.isRevenueCatConfigured)

                if !subscription.isRevenueCatConfigured {
                    Text("settings_revenuecat_hint")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } header: {
                Text("settings_section_subscription")
            }

            Section {
                Link("settings_privacy_policy", destination: LegalLinks.privacyPolicy)
                Link("settings_terms_of_use", destination: LegalLinks.termsOfUse)
            } header: {
                Text("settings_section_legal")
            }

            Section {
                HStack {
                    Text("settings_version")
                    Spacer()
                    Text(appVersion)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
            }

#if DEBUG
            Section {
                debugRow("settings_debug_is_pro", value: subscription.isPro)
                debugRow("settings_debug_revenuecat_configured", value: subscription.isRevenueCatConfigured)
                HStack {
                    Text("settings_debug_free_scans_used")
                    Spacer()
                    Text("\(subscription.freeScansUsed)")
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
                Button("settings_debug_reset_free_scans") {
                    subscription.debugResetFreeScanUsage()
                }
                Button("settings_debug_open_checklist") {
                    showQAChecklist = true
                }
            } header: {
                Text("settings_debug_section")
            }
#endif
        }
        .navigationTitle("settings_nav_title")
        .sheet(isPresented: $showPaywall) {
            PaywallView(subscription: subscription)
        }
#if DEBUG
        .sheet(isPresented: $showQAChecklist) {
            NavigationStack {
                DebugQAChecklistView()
            }
        }
#endif
        .alert("settings_alert_subscriptions", isPresented: Binding(get: { alertMessage != nil }, set: { if !$0 { alertMessage = nil } })) {
            Button("common_ok", role: .cancel) {}
        } message: {
            Text(alertMessage ?? "")
        }
    }

    private var appVersion: String {
        let short = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "—"
        return "\(short) (\(build))"
    }

    private func restore() async {
        isRestoring = true
        defer { isRestoring = false }
        do {
            try await subscription.restorePurchases()
            if subscription.isPro {
                alertMessage = String(localized: String.LocalizationValue("settings_restore_active"))
            } else {
                alertMessage = String(localized: String.LocalizationValue("settings_restore_none"))
            }
        } catch {
            alertMessage = displayErrorMessage(error, fallbackKey: "settings_error_restore_fallback")
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

    @ViewBuilder
    private func debugRow(_ titleKey: LocalizedStringKey, value: Bool) -> some View {
        HStack {
            Text(titleKey)
            Spacer()
            Text(value ? "settings_value_yes" : "settings_value_no")
                .foregroundStyle(.secondary)
        }
    }
}

#Preview {
    NavigationStack {
        SettingsView()
    }
    .environmentObject(SubscriptionService.shared)
}
