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

enum RegisteredTabs {
    static var all: [AnySettingsTab] = [
        AnySettingsTab(id: "general", title: "General", icon: "gear", content: AnyView(GeneralSettingsView())),
        AnySettingsTab(id: "keyboard", title: "Keyboard", icon: "keyboard", content: AnyView(KeyboardSettingsView())),
        AnySettingsTab(id: "appearance", title: "Appearance", icon: "paintpalette.fill", content: AnyView(ThemeSettingsView())),
        AnySettingsTab(id: "modes", title: "Modes", icon: "square.stack.3d.up", content: AnyView(CustomModesSettingsView())),
        AnySettingsTab(id: "filters", title: "Filters", icon: "line.3.horizontal.decrease.circle", content: AnyView(FilterSettingsView())),
        AnySettingsTab(id: "activate", title: "Activate", icon: "lock", content: AnyView(ActivateSettingsView())),
    ]
}
