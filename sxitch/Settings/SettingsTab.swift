import SwiftUI

protocol SettingsTab: View {
    static var tabID: String { get }
    static var tabTitle: String { get }
    static var tabIcon: String { get }
}

struct AnySettingsTab: Identifiable {
    let id: String
    let title: String
    let icon: String
    let content: AnyView
}

struct RegisteredTabs {
    static var all: [AnySettingsTab] = [
        AnySettingsTab(id: "general", title: "General", icon: "gear", content: AnyView(GeneralSettingsView())),
        AnySettingsTab(id: "theme", title: "Theme", icon: "paintpalette.fill", content: AnyView(ThemeSettingsView())),
        AnySettingsTab(id: "advanced", title: "Advanced", icon: "slider.horizontal.3", content: AnyView(AdvancedSettingsView())),
        AnySettingsTab(id: "activate", title: "Activate", icon: "lock", content: AnyView(ActivateSettingsView())),
    ]
}
