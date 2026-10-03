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

/// A titled sidebar group ("General", "Theming", …) holding its tabs.
struct SettingsTabGroup: Identifiable {
    let id: String
    let title: String
    let tabs: [AnySettingsTab]
}

enum RegisteredTabs {
    static let generalTabs: [AnySettingsTab] = [
        AnySettingsTab(id: "app", title: "App", icon: "gear", content: AnyView(AppSettingsView())),
        AnySettingsTab(id: "keyboard", title: "Keyboard", icon: "keyboard", content: AnyView(KeyboardSettingsView())),
        AnySettingsTab(
            id: "management", title: "Management & Rules",
            icon: "line.3.horizontal.decrease.circle",
            content: AnyView(ManagementRulesSettingsView())
        ),
        AnySettingsTab(id: "modes", title: "All Modes", icon: "square.stack.3d.up", content: AnyView(AllModesSettingsView())),
        AnySettingsTab(id: "alerts", title: "Alert behaviour", icon: "megaphone", content: AnyView(AlertsSettingsView())),
    ]

    static let themingTabs: [AnySettingsTab] = [
        AnySettingsTab(id: "appearance", title: "Appearance", icon: "paintpalette.fill", content: AnyView(AppearanceSettingsView())),
        AnySettingsTab(id: "layout", title: "Layout", icon: "rectangle.grid.2x2", content: AnyView(LayoutSettingsView())),
        AnySettingsTab(id: "animation", title: "Animation", icon: "sparkles", content: AnyView(AnimationSettingsView())),
        AnySettingsTab(id: "haptics", title: "Haptics", icon: "waveform", content: AnyView(HapticsSettingsView())),
    ]

    static let accountTabs: [AnySettingsTab] = [
        AnySettingsTab(id: "account", title: "Account", icon: "person.crop.circle.fill", content: AnyView(AccountSettingsView())),
    ]

    static var groups: [SettingsTabGroup] {
        [
            SettingsTabGroup(id: "general", title: "General", tabs: generalTabs),
            SettingsTabGroup(id: "theming", title: "Theming", tabs: themingTabs),
            SettingsTabGroup(id: "account", title: "Account", tabs: accountTabs),
        ]
    }

    static var allTabIDs: [String] {
        groups.flatMap(\.tabs).map(\.id)
    }
}
