import Combine
import SwiftUI

struct SettingsView: View {
    private var usState = userState.shared
    @AppStorage("accentColorHex") var accentColorHex: String = "system"
    @AppStorage("selectedSettingsTab") private var selectedTab: String = "management"

    /// Shared observable model — the sidebar reads `modes` directly, so any
    /// add/edit/delete anywhere re-renders it automatically.
    private var modesModel = CustomModesModel.shared

    @State private var hostWindow: NSWindow?
    @State private var windowObservers: [NSObjectProtocol] = []

    /// Sidebar search: filters the tab list across all pages; the detail pane
    /// itself is untouched.
    @State private var searchText = ""

    /// Open drill-down page for the Modes tab (not a sidebar entry — the
    /// page replaces the All Modes list in the detail pane).
    @State private var openModeID: UUID?

    var accentColor: Color {
        resolvedAccentColor(from: accentColorHex) ?? .accentColor
    }

    /// Matched search-entry titles per tab id, feeding the sidebar's
    /// secondary text. Empty dictionary when not filtering.
    @State private var matchedTitles: [String: [String]] = [:]

    private var isFiltering: Bool {
        !searchText.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private var sidebarGroups: [SettingsTabGroup] {
        RegisteredTabs.groups
    }

    /// Groups rendered as titled sidebar sections. Account is excluded — it
    /// gets the pinned big row at the very top of the sidebar.
    private var renderedGroups: [SettingsTabGroup] {
        sidebarGroups.filter { $0.id != "account" }
    }

    /// Groups filtered by the search query. When filtering, results are a
    /// flat match across every group, re-grouped for display.
    private var visibleGroups: [SettingsTabGroup] {
        guard isFiltering else { return renderedGroups }
        return renderedGroups.compactMap { group in
            let tabs = group.tabs.filter { matchedTitles[$0.id] != nil }
            return tabs.isEmpty
                ? nil
                : SettingsTabGroup(id: group.id, title: group.title, tabs: tabs)
        }
    }

    /// The group currently containing the selected tab — used to highlight
    /// its section header in the sidebar.
    private var selectedGroupID: String? {
        sidebarGroups.first { group in
            group.tabs.contains { $0.id == selectedTab }
        }?.id
    }

    /// The big, pinned Account row at the top of the sidebar (System
    /// Settings-style), showing the license status at a glance.
    private var accountRow: some View {
        HStack(alignment: .center, spacing: 9) {
            Image(systemName: "person.crop.circle.fill")
                .font(.system(size: 23))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(usState.hasValidLicense ? .green : .gray)
            VStack(alignment: .leading, spacing: 2) {
                Text("Account")
                    .fontWeight(.semibold)
                Text(accountSubtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .padding(.vertical, 5)
        .tag("account")
    }

    /// License validity vs. the Pro Mode debug toggle: "Pro Mode off" only
    /// when a valid license exists but the user toggled `isPro` off.
    private var accountSubtitle: String {
        if usState.isPro {
            return "Sxitch Pro activated"
        }
        return usState.hasValidLicense ? "Pro Mode off" : "Free version"
    }

    private func matchedEntryTitles(for tabID: String) -> [String] {
        matchedTitles[tabID] ?? []
    }

    /// The detail pane for the Modes tab, with drill-down: the list, or the
    /// open mode's own settings page.
    @ViewBuilder
    private var modesContent: some View {
        if let modeID = openModeID {
            ModeSettingsPage(modeID: modeID) {
                openModeID = nil
            }
        } else {
            AllModesSettingsView { modeID in
                // Deferred: swaps the detail pane; doing it synchronously
                // inside the clicked row's table callback traps AppKit.
                DispatchQueue.main.async {
                    openModeID = modeID
                }
            }
        }
    }

    var selectedContent: some View {
        ZStack {
            Color(nsColor: .windowBackgroundColor)
            if selectedTab == "modes" {
                modesContent
            } else if let tab = sidebarGroups.flatMap(\.tabs).first(where: { $0.id == selectedTab }) {
                tab.content
            }
        }
    }

    var body: some View {
        NavigationSplitView {
            List(selection: Binding(
                get: { selectedTab },
                set: {
                    if let value = $0 {
                        selectedTab = value
                    }
                }
            )) {
                // Pinned big Account row — always first, always visible.
                Section {
                    accountRow
                        .listRowSeparator(.hidden)
                }

                let groups = visibleGroups
                if groups.isEmpty {
                    VStack(spacing: 10) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 26))
                            .foregroundStyle(.quaternary)
                        Text("No matching settings")
                            .font(.headline)
                            .foregroundStyle(.secondary)
                        Text("Try “hotkey”, “accent” or “blacklist”.")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                }
                ForEach(groups) { group in
                    Section {
                        ForEach(group.tabs) { tab in
                            Label {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(tab.title)
                                    let titles = matchedEntryTitles(for: tab.id)
                                    if !titles.isEmpty {
                                        Text(titles.prefix(3).joined(separator: " · "))
                                            .font(.caption2)
                                            .foregroundStyle(.tertiary)
                                            .lineLimit(1)
                                    }
                                }
                            } icon: {
                                Image(systemName: tab.icon)
                                    .symbolRenderingMode(.hierarchical)
                                    .foregroundStyle(sidebarIconColor(for: tab.id))
                            }
                            .tag(tab.id)
                            .simultaneousGesture(
                                TapGesture().onEnded {
                                    // Re-clicking "All Modes" while drilled
                                    // into a mode page exits the drill-down.
                                    if tab.id == "modes" {
                                        openModeID = nil
                                    }
                                }
                            )
                        }
                    } header: {
                        // The section header highlights when the selection is
                        // inside its group (e.g. "Modes" while on a mode page).
                        Text(group.title)
                            .foregroundStyle(
                                selectedGroupID == group.id ? Color.accentColor : Color.secondary
                            )
                            .fontWeight(selectedGroupID == group.id ? .semibold : nil)
                    }
                }
            }
            .listStyle(.sidebar)
            .frame(minWidth: 200)
            .searchable(
                text: $searchText,
                placement: .sidebar,
                prompt: "Search settings"
            )
            .onSubmit(of: .search) {
                if let first = visibleGroups.first?.tabs.first {
                    selectedTab = first.id
                }
            }
        } detail: {
            // The detail column's navigation title drives the window title on
            // macOS — the Settings scene otherwise keeps re-asserting its own
            // static "Sxitch Settings".
            selectedContent
                .navigationTitle(pageTitle)
        }
        .tint(accentColor)
        .frame(minWidth: 840, minHeight: 580)
        .background(
            WindowAccessor(window: $hostWindow)
                .frame(width: 0, height: 0)
        )
        .onChange(of: hostWindow) { _, newWindow in
            registerWindowObservers(for: newWindow)
            updateWindowTitle()
        }
        .onAppear {
            modesModel.reload()
            migrateLegacyTabIDIfNeeded()
            validateSelection()
            registerWindowObservers(for: hostWindow)
            updateWindowTitle()
            focusWindow()
        }
        .onDisappear {
            NSApp.setActivationPolicy(.accessory)
        }
        // Bridge for writers outside the model (e.g. the switcher's context
        // menu): re-read the store. The sidebar itself re-renders because it
        // reads the model's observable `modes` directly.
        .onReceive(NotificationCenter.default.publisher(for: .customModesChanged)) { _ in
            modesModel.reload()
            validateSelection()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.didBecomeKeyNotification)) { note in
            guard (note.object as? NSWindow) === hostWindow else { return }
            NSApp.activate(ignoringOtherApps: true)
            modesModel.reload()
            validateSelection()
            updateWindowTitle()
        }
        .onChange(of: selectedTab) { _, newValue in
            if newValue != "modes" {
                openModeID = nil
            }
            validateSelection()
            updateWindowTitle()
        }
        .onChange(of: modesModel.modes) { _, _ in
            updateWindowTitle()
        }
        .onChange(of: searchText) { _, newValue in
            matchedTitles = SettingsSearchIndex.matchedTabIDs(for: newValue, modes: modesModel.modes)
        }
    }

    /// The window title reflects the open page instead of a static
    /// "Sxitch Settings" everywhere.
    private var pageTitle: String {
        // A drilled-in mode page titles the window with the mode's name.
        if selectedTab == "modes", let modeID = openModeID,
           let mode = modesModel.modes.first(where: { $0.id == modeID })
        {
            return mode.name
        }
        return sidebarGroups
            .flatMap(\.tabs)
            .first(where: { $0.id == selectedTab })?.title ?? "Sxitch Settings"
    }

    private func updateWindowTitle() {
        guard let window = hostWindow else { return }
        window.titleVisibility = .visible
        window.title = pageTitle
    }

    /// Old flat-tab ids → their new home, so a persisted selection survives
    /// the restructure.
    private func migrateLegacyTabIDIfNeeded() {
        let legacyMap = [
            "general": "app",
            "filters": "management",
            "activate": "account",
        ]
        if let mapped = legacyMap[selectedTab] {
            selectedTab = mapped
        }
        // Per-mode sidebar pages were folded back into the All Modes page.
        if selectedTab.hasPrefix("mode-") {
            selectedTab = "modes"
        }
    }

    /// Falls back to Management & Rules when the selection points at a tab
    /// that no longer exists.
    private func validateSelection() {
        let allIDs = Set(sidebarGroups.flatMap(\.tabs).map(\.id))
        if !allIDs.contains(selectedTab) {
            selectedTab = "management"
        }
    }

    private func sidebarIconColor(for id: String) -> Color {
        switch id {
        case "management": .teal
        case "keyboard": .indigo
        case "app": .gray
        case "appearance": .pink
        case "layout": .blue
        case "animation": .mint
        case "haptics": .purple
        case "modes", "modes-list": .orange
        default:
            id.hasPrefix("mode-") ? .orange : .gray
        }
    }

    /// Brings the settings window to the foreground. The app runs as an
    /// accessory between settings sessions, and `onAppear` fires only for the
    /// first frame — later opens (⌘, from the switcher, the menu-bar link,
    /// reopening after close) need an explicit activate per show.
    private func focusWindow() {
        NSApp.setActivationPolicy(.regular)
        hostWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    /// Lifecycle observers only — the window itself is left at SwiftUI's
    /// default configuration (default traffic lights, toolbar and resizing),
    /// matching the plain `NavigationSplitView` window setup.
    private func registerWindowObservers(for window: NSWindow?) {
        for observer in windowObservers {
            NotificationCenter.default.removeObserver(observer)
        }
        windowObservers.removeAll()
        guard let window else { return }
        windowObservers.append(
            NotificationCenter.default.addObserver(
                forName: NSWindow.willCloseNotification, object: window, queue: .main
            ) { _ in
                NSApp.setActivationPolicy(.accessory)
            }
        )
    }
}

struct WindowAccessor: NSViewRepresentable {
    @Binding var window: NSWindow?

    func makeNSView(context _: Context) -> NSView {
        let view = WindowFinderView()
        view.onWindowFound = { window = $0 }
        return view
    }

    func updateNSView(_: NSView, context _: Context) {}

    final class WindowFinderView: NSView {
        var onWindowFound: ((NSWindow?) -> Void)?

        override func viewDidMoveToWindow() {
            onWindowFound?(window)
        }
    }
}
