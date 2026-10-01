import SwiftUI

struct DebugQAChecklistView: View {
    var body: some View {
        List {
            Section("settings_debug_checklist_section_scan") {
                checkItem("settings_debug_checklist_scan_1")
                checkItem("settings_debug_checklist_scan_2")
                checkItem("settings_debug_checklist_scan_3")
            }

            Section("settings_debug_checklist_section_paywall") {
                checkItem("settings_debug_checklist_paywall_1")
                checkItem("settings_debug_checklist_paywall_2")
                checkItem("settings_debug_checklist_paywall_3")
            }

            Section("settings_debug_checklist_section_restore") {
                checkItem("settings_debug_checklist_restore_1")
                checkItem("settings_debug_checklist_restore_2")
                checkItem("settings_debug_checklist_restore_3")
            }
        }
        .navigationTitle("settings_debug_checklist_title")
    }

    private func checkItem(_ key: LocalizedStringKey) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "checkmark.circle")
                .foregroundStyle(.tint)
                .padding(.top, 2)
            Text(key)
        }
    }
}

#Preview {
    NavigationStack {
        DebugQAChecklistView()
    }
}
