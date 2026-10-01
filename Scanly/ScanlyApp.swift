import SwiftUI

@main
struct ScanlyApp: App {
    private let persistence = PersistenceController.shared

    @AppStorage("scanly.hasCompletedOnboarding") private var hasCompletedOnboarding = false

    var body: some Scene {
        WindowGroup {
            Group {
                if hasCompletedOnboarding {
                    ContentView()
                } else {
                    OnboardingView {
                        hasCompletedOnboarding = true
                    }
                }
            }
            .environment(\.managedObjectContext, persistence.container.viewContext)
            .environmentObject(SubscriptionService.shared)
            .task {
                await SubscriptionService.shared.configure()
            }
        }
    }
}
