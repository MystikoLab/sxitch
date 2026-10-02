import AppKit
import SwiftUI

struct ContentView: View {
    @State private var openApps: [any SwitchableApp] = RunningApp.fetchRunningApps()
    @State private var accessibilityGranted: Bool = AXIsProcessTrusted()

    @Environment(\.openWindow) private var openWindow
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.modeTheme) private var modeTheme

    @AppStorage("appBlacklists") var blacklist: [String] = []
    @AppStorage("prefixStrips") var prefixStrip: [String] = ["microsoft", "adobe"]
    @AppStorage("pinned_app_urls") var pinnedAppURLs: [String] = []
    @AppStorage("layoutStyle") var layoutStyle: String = "grid"
    @AppStorage("showPickerUi") private var showUi = true

    @ObservedObject var appState: AppState
    @State private var drillDownWindows: [WindowInfo] = []

    var appDelegate: AppDelegate

    private var activeMode: CustomMode? {
        guard let id = appState.activeModeID else { return nil }
        return CustomModeStore.load().first { $0.id.uuidString == id }
    }

    private var displayedEntries: [any SwitchableApp] {
        if appState.activeModeID != nil {
            return appDelegate.currentEntries()
        }
        return openApps
    }

    private var appContextActions: AppContextActions {
        AppContextActions(
            blacklist: blacklistApp,
            rename: renameApp,
            modes: CustomModeStore.load(),
            addToMode: addAppToMode,
            togglePin: togglePinApp
        )
    }

    @ViewBuilder
    private var appLayout: some View {
        if !showUi {
        } else {
            if let drillApp = appState.drillDownApp {
                WindowPickerView(
                    windows: drillDownWindows,
                    appName: drillApp.localizedName ?? "Unknown",
                    appIcon: drillApp.icon ?? NSImage(),
                    typed: appState.typed,
                    onSelect: { appDelegate.closeWindow() }
                )
                .environment(\.modeTheme, ModeTheme.theme(for: appState.mode))
                .id("\(appState.mode.rawValue)-\(appState.activeModeID ?? "default")")
            } else {
                VStack(spacing: 0) {
                    if let mode = activeMode, mode.apps.isEmpty {
                        VStack(spacing: 8) {
                            Image(systemName: "square.stack.3d.up")
                                .font(.system(size: 32))
                                .opacity(0.4)
                            Text("No apps in this mode")
                                .font(.headline)
                                .opacity(0.6)
                            Text("Add apps or commands in Settings → Modes")
                                .font(.caption)
                                .opacity(0.4)
                        }
                        .frame(minWidth: 280, minHeight: 150)
                    } else {
                        AnyAppLayout(
                            apps: displayedEntries,
                            typed: appState.typed,
                            onTap: handleAppTap,
                            layoutStyle: layoutStyle
                        )
                    }
                }
                .environment(\.appContextActions, appContextActions)
                .environment(\.modeTheme, ModeTheme.theme(for: appState.mode))
                .id("\(appState.mode.rawValue)-\(appState.activeModeID ?? "default")")
            }
        }
    }

    @ViewBuilder
    private var switcher: some View {
        if layoutStyle == "circle" {
            appLayout
        } else {
            appLayout
                .modernMacBackground(cornerRadius: 30)
                .clipShape(RoundedRectangle(cornerRadius: 30))
        }
    }

    var body: some View {
        switcher
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: appState.typed)
            .animation(.spring(response: 0.25, dampingFraction: 0.65), value: appState.mode)
            .animation(.spring(response: 0.25, dampingFraction: 0.65), value: appState.activeModeID)
            .onReceive(
                NSWorkspace.shared.notificationCenter.publisher(
                    for: NSWorkspace.didLaunchApplicationNotification
                )
            ) { _ in
                guard appDelegate.window.isVisible else { return }
                withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                    reloadEntries()
                }
            }
            .onReceive(
                NSWorkspace.shared.notificationCenter.publisher(
                    for: NSWorkspace.didTerminateApplicationNotification
                )
            ) { _ in
                guard appDelegate.window.isVisible else { return }
                withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                    reloadEntries()
                }
            }
            .onReceive(
                NotificationCenter.default.publisher(for: .switcherWillShow)
            ) { _ in
                reloadEntries()
                appDelegate.prepareOpenAnimation()
            }
            .onReceive(
                NotificationCenter.default.publisher(for: .openSettingsRequested)
            ) { _ in
                openWindow(id: "settings")
            }
            .onReceive(
                NotificationCenter.default.publisher(for: .customModesChanged)
            ) { _ in
                guard appDelegate.window.isVisible else { return }
                reloadEntries()
            }
            .onKeyPress(.escape) {
                if appState.drillDownApp != nil {
                    if appState.typed.isEmpty {
                        appState.drillDownApp = nil
                    } else {
                        appState.typed = ""
                    }
                } else if !appState.typed.isEmpty {
                    appState.typed = ""
                } else if appState.activeModeID != nil {
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.65)) {
                        appState.activeModeID = nil
                    }
                    appDelegate.resizeWindowToFit(force: true)
                } else {
                    appDelegate.closeWindow()
                }
                return KeyPress.Result.handled
            }
            .onChange(of: blacklist) { _, _ in
                reloadEntries()
                NotificationCenter.default.post(name: .appSettingsChanged, object: nil)
            }
            .onChange(of: pinnedAppURLs) { _, _ in
                reloadEntries()
                NotificationCenter.default.post(name: .appSettingsChanged, object: nil)
            }
            .onChange(of: prefixStrip) { _, _ in
                reloadEntries()
                NotificationCenter.default.post(name: .appSettingsChanged, object: nil)
            }
            .onChange(of: appState.activeModeID) { _, _ in
                if appDelegate.window.isVisible {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                        reloadEntries()
                    }
                }
            }
            .onChange(of: appState.typed) { _, _ in
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                    appDelegate.resizeWindowToFit()
                }
            }
            .onChange(of: layoutStyle) { _, _ in
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                    appDelegate.resizeWindowToFit()
                }
            }
            .onChange(of: appState.drillDownApp) { _, newApp in
                if let app = newApp {
                    drillDownWindows = fetchWindowsForApp(app)
                    appState.typed = ""
                } else {
                    drillDownWindows = []
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                    appDelegate.resizeWindowToFit()
                }
            }
            .task {
                if !userState.shared.isPro {
                    await userState.shared.checkCurrentActivationStatus()
                }
                NotificationCenter.default.post(name: .customModesChanged, object: nil)
            }
    }

    func reloadEntries() {
        openApps = appDelegate.currentEntries()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            appDelegate.resizeWindowToFit()
        }
    }

    private func blacklistApp(_ app: any SwitchableApp) {
        appDelegate.closeWindow()
        let name = app.appName.lowercased()
        if !blacklist.contains(name) {
            blacklist.append(name)
        }
    }

    private func renameApp(_ app: any SwitchableApp) {
        appDelegate.closeWindow()
        let currentName = app.appName
        let alert = NSAlert()
        alert.messageText = "Rename \"\(currentName)\""
        alert.informativeText = "The new name will be shown in the switcher."
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Rename")
        alert.addButton(withTitle: "Cancel")

        let input = NSTextField(frame: NSRect(x: 0, y: 0, width: 260, height: 24))
        input.stringValue = currentName
        input.placeholderString = "App name"
        alert.accessoryView = input

        guard alert.runModal() == .alertFirstButtonReturn else { return }
        let newName = input.stringValue.trimmingCharacters(in: .whitespaces)

        if let pinned = app as? PinnedApp {
            renameModeEntry(pinned, newName: newName)
        } else {
            renameRunningApp(app, newName: newName, currentName: currentName)
        }
    }

    /// Entries backed by a custom-mode app are renamed by editing that entry's
    /// own display name in place, matched by its UUID so a rename survives the
    /// name change itself.
    private func renameModeEntry(_ pinned: PinnedApp, newName: String) {
        guard !newName.isEmpty else { return }
        let entryID = pinned.modeApp.id
        var modes = CustomModeStore.load()
        guard let modeIndex = modes.firstIndex(where: { mode in
            mode.apps.contains(where: { $0.id == entryID })
        }) else { return }
        guard let appIndex = modes[modeIndex].apps.firstIndex(where: { $0.id == entryID }) else { return }
        if modes[modeIndex].apps[appIndex].displayName == newName {
            return
        }
        modes[modeIndex].apps[appIndex].displayName = newName
        CustomModeStore.save(modes)
        NotificationCenter.default.post(name: .customModesChanged, object: nil)
        reloadEntries()
    }

    /// Running apps are renamed through the global `app_renames` rules, keyed
    /// by the app's real name — the same key the name lookup reads when the
    /// switcher is populated. Re-renaming therefore edits the existing rule
    /// instead of writing a new one that can never match.
    private func renameRunningApp(_ app: any SwitchableApp, newName: String, currentName: String) {
        let realKey = app.realName.lowercased()
        var renames = UserDefaults.standard.appRenames
        if newName == currentName {
            // Nothing changed: leave any existing rule alone.
            return
        }
        if newName.isEmpty || newName == app.realName {
            // Clearing the field or typing the original name reverts the rename.
            renames.removeValue(forKey: realKey)
        } else {
            renames[realKey] = newName
        }
        // The app may be displayed under a rename or prefix strip, so a rule
        // written by earlier versions (keyed by the displayed name) may exist
        // alongside the corrected one. Clear any such stale entry.
        let displayedKey = currentName.lowercased()
        if displayedKey != realKey {
            renames.removeValue(forKey: displayedKey)
        }
        UserDefaults.standard.appRenames = renames
        NotificationCenter.default.post(name: .appRenamesChanged, object: nil)
        NotificationCenter.default.post(name: .appSettingsChanged, object: nil)
        reloadEntries()
    }

    private func togglePinApp(_ app: any SwitchableApp) {
        guard let url = app.pinnedBundleURL else { return }
        appDelegate.closeWindow()
        if let index = pinnedAppURLs.firstIndex(of: url) {
            pinnedAppURLs.remove(at: index)
        } else {
            pinnedAppURLs.append(url)
        }
    }

    private func addAppToMode(_ app: any SwitchableApp, _ mode: CustomMode) {
        appDelegate.closeWindow()
        guard let bundleURL = app.runningApplication?.bundleURL?.absoluteString else { return }
        var modes = CustomModeStore.load()
        guard let index = modes.firstIndex(where: { $0.id == mode.id }) else { return }
        if modes[index].apps.contains(where: { $0.bundleURL == bundleURL }) {
            return
        }
        modes[index].apps.append(
            ModeApp(bundleURL: bundleURL, displayName: app.appName)
        )
        CustomModeStore.save(modes)
        NotificationCenter.default.post(name: .customModesChanged, object: nil)
    }

    func handleAppTap(_ app: any SwitchableApp) {
        guard let runningApp = app.runningApplication else {
            let theme = ModeTheme.theme(for: appState.mode)
            theme.appAction(app)
            if appState.mode == .normal {
                appDelegate.closeWindow()
            }
            return
        }
        let windows = fetchWindowsForApp(runningApp)
        let windowPickerEnabled = UserDefaults.standard.bool(forKey: "windowPickerEnabled")
        let currentMode = appState.mode

        if windows.count > 1, userState.shared.isPro, windowPickerEnabled {
            appState.drillDownApp = runningApp
        } else if windows.count == 1 {
            let theme = ModeTheme.theme(for: currentMode)
            theme.windowAction(windows[0])
            appDelegate.closeWindow()
        } else {
            let theme = ModeTheme.theme(for: currentMode)
            theme.appAction(app)
            if currentMode == .normal {
                appDelegate.closeWindow()
            }
        }
    }
}
