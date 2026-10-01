import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            NavigationStack {
                ScanView()
            }
            .tabItem { Label("tab_scan", systemImage: "doc.viewfinder") }

            NavigationStack {
                ExpensesListView()
            }
            .tabItem { Label("tab_expenses", systemImage: "list.bullet.rectangle") }

            NavigationStack {
                InsightsView()
            }
            .tabItem { Label("tab_insights", systemImage: "chart.pie") }

            NavigationStack {
                SettingsView()
            }
            .tabItem { Label("tab_settings", systemImage: "gearshape") }
        }
    }
}

#Preview {
    ContentView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
        .environmentObject(SubscriptionService.shared)
}
