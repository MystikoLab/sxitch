import SwiftUI

struct SettingsSearchEntry {
    let tabID: String
    let title: String
    let keywords: [String]
}

enum SettingsSearchIndex {
    static let entries: [SettingsSearchEntry] = [
        // General › Management & Rules
        SettingsSearchEntry(tabID: "management", title: "Blacklist Apps", keywords: ["exclude", "hide apps", "filter"]),
        SettingsSearchEntry(tabID: "management", title: "Strip Prefixes", keywords: ["prefix", "microsoft", "adobe"]),
        SettingsSearchEntry(tabID: "management", title: "App name override", keywords: ["rename", "alias"]),
        SettingsSearchEntry(tabID: "management", title: "Window Picker", keywords: ["window picker", "multiple windows", "drill down"]),

        // General › Keyboard
        SettingsSearchEntry(tabID: "keyboard", title: "Switcher Hotkey", keywords: ["modifier", "summon", "shortcut", "other key"]),
        SettingsSearchEntry(tabID: "keyboard", title: "Mode Hotkeys", keywords: ["hide mode", "quit mode", "normal mode"]),
        SettingsSearchEntry(tabID: "keyboard", title: "App Launch Hotkeys", keywords: ["launch", "open app"]),
        SettingsSearchEntry(tabID: "keyboard", title: "Key Overrides", keywords: ["remap", "keys", "custom"]),

        // General › App
        SettingsSearchEntry(tabID: "app", title: "Permissions", keywords: ["accessibility", "screen recording"]),
        SettingsSearchEntry(tabID: "app", title: "Launch at login", keywords: ["startup", "login items"]),
        SettingsSearchEntry(tabID: "app", title: "Revisit the setup guide", keywords: ["onboarding", "guide", "tour"]),

        // Theming › Appearance
        SettingsSearchEntry(tabID: "appearance", title: "Show picker UI", keywords: ["switcher ui", "overlay", "invisible"]),
        SettingsSearchEntry(tabID: "appearance", title: "Show menubar icon", keywords: ["menu bar", "status item"]),
        SettingsSearchEntry(tabID: "appearance", title: "Liquid Glass", keywords: ["material", "transparency"]),
        SettingsSearchEntry(tabID: "appearance", title: "Accent Colour", keywords: ["color", "theme", "tint"]),

        // Theming › Layout
        SettingsSearchEntry(tabID: "layout", title: "Layout", keywords: ["grid", "list", "circle", "scrollable", "scroll list"]),
        SettingsSearchEntry(tabID: "layout", title: "Window Position", keywords: ["screen", "placement", "corner"]),

        // Theming › Animation
        SettingsSearchEntry(tabID: "animation", title: "Enable animations", keywords: ["disable", "off"]),
        SettingsSearchEntry(tabID: "animation", title: "Open / Close Animation", keywords: ["fade", "slide", "drop", "scale", "preview"]),
        SettingsSearchEntry(tabID: "animation", title: "Speed", keywords: ["duration", "multiplier"]),

        // Modes
        SettingsSearchEntry(tabID: "modes", title: "All Modes", keywords: ["custom mode", "add mode", "mode hotkey", "editor"]),

        // Account
        SettingsSearchEntry(tabID: "account", title: "License Status", keywords: ["pro", "free", "activated"]),
        SettingsSearchEntry(tabID: "account", title: "License Key", keywords: ["view key", "copy key"]),
        SettingsSearchEntry(tabID: "account", title: "Activate Pro", keywords: ["license", "key", "code", "unlock"]),
        SettingsSearchEntry(tabID: "account", title: "Get Sxitch Pro", keywords: ["buy", "subscribe", "price", "purchase"]),
    ]

    /// Per-mode entries derived from the stored modes so searching a mode's
    /// name — or one of its apps — surfaces the Modes tab. All modes live on
    /// the single "All Modes" page now.
    static func modeEntries(for modes: [CustomMode]) -> [SettingsSearchEntry] {
        modes.map { mode in
            SettingsSearchEntry(
                tabID: "modes",
                title: mode.name,
                keywords: mode.apps.map(\.displayName)
            )
        }
    }

    static func entries(for modes: [CustomMode]) -> [SettingsSearchEntry] {
        entries + modeEntries(for: modes)
    }

    /// Tabs matching the query — a tab matches when its title, any of its
    /// entries' titles/keywords, or an entry alias matches. Returned map feeds
    /// the sidebar's secondary text (tab id → matched entry titles).
    static func matchedTabIDs(for query: String, modes: [CustomMode]) -> [String: [String]] {
        let needle = query.trimmingCharacters(in: .whitespaces).lowercased()
        guard !needle.isEmpty else { return [:] }

        var perTab: [String: [String]] = [:]
        let allEntries = entries(for: modes)

        for group in RegisteredTabs.groups {
            for tab in group.tabs where tab.title.lowercased().contains(needle) {
                // Title match: list every entry so the row previews the page.
                perTab[tab.id] = allEntries
                    .filter { $0.tabID == tab.id }
                    .map(\.title)
            }
        }

        for entry in allEntries {
            let matchedTitle = entry.title.lowercased().contains(needle)
            let matchedKeyword = entry.keywords.contains { $0.lowercased().contains(needle) }
            if matchedTitle || matchedKeyword {
                perTab[entry.tabID, default: []].append(entry.title)
            }
        }

        var uniquePerTab: [String: [String]] = [:]
        for (tabID, titles) in perTab {
            uniquePerTab[tabID] = Array(OrderedSet(titles))
        }
        return uniquePerTab
    }
}

private struct OrderedSet: Sequence {
    private var items: [String] = []
    private var seen: Set<String> = []

    init(_ values: [String]) {
        for value in values where !seen.contains(value) {
            seen.insert(value)
            items.append(value)
        }
    }

    var count: Int {
        items.count
    }

    func makeIterator() -> IndexingIterator<[String]> {
        items.makeIterator()
    }
}
