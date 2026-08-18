import SwiftUI

struct SettingsView: View {
    private var usState = userState.shared
    @AppStorage("accentColorHex") var accentColorHex: String = "system"
    @State private var selectedTab: String = "general"

    var accentColor: Color {
        resolvedAccentColor(from: accentColorHex) ?? .accentColor
    }

    var tabs: [AnySettingsTab] {
        let all = RegisteredTabs.all
        return all.map { tab in
            if tab.id == "activate" {
                AnySettingsTab(
                    id: tab.id, title: tab.title,
                    icon: usState.isPro ? "lock.open" : "lock",
                    content: tab.content
                )
            } else {
                tab
            }
        }
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            ForEach(tabs) { tab in
                tab.content
                    .tabItem {
                        Label(tab.title, systemImage: tab.icon)
                    }
                    .tag(tab.id)
            }
        }
        .frame(minWidth: 800, minHeight: 600)
        .tint(accentColor)
    }
}
