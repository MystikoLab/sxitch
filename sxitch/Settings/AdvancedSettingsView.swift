import SwiftUI

struct AdvancedSettingsView: View, SettingsTab {
    static let tabID = "advanced"
    static let tabTitle = "Advanced"
    static let tabIcon = "slider.horizontal.3"

    @AppStorage("appBlacklists") var blacklist: [String] = []
    @AppStorage("prefixStrips") var prefixStrip: [String] = ["microsoft", "adobe"]

    private var appState = userState.shared
    @State private var openApps = RunningApp.fetchRunningApps()

    var body: some View {
        Form {
            if appState.isPro {
                ManagedListSection(
                    addHeader: "Blacklist Apps",
                    listHeader: "Blacklisted Apps",
                    emptyMessage: "No apps blacklisted yet.",
                    placeholder: "App name",
                    items: $blacklist
                )
                AppHotkeySettingsView()
            }
            ManagedListSection(
                addHeader: "Strip Prefixes",
                listHeader: "Prefix Stripping",
                emptyMessage: "No prefixes added yet.",
                placeholder: "Prefix",
                items: $prefixStrip
            )
        }
        .padding()
        .formStyle(.grouped)
    }
}
