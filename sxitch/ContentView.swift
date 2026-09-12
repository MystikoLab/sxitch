import AppKit
import SwiftUI

struct ContentView: View {
    @State private var openApps: [any SwitchableApp] = RunningApp.fetchRunningApps()
    @State private var accessibilityGranted: Bool = AXIsProcessTrusted()

    @Environment(\.openSettings) private var openSettings
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.modeTheme) private var modeTheme

    @AppStorage("appBlacklists") var blacklist: [String] = []
    @AppStorage("prefixStrips") var prefixStrip: [String] = ["microsoft", "adobe"]
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
            addToMode: addAppToMode
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
                .modernMacBackground()
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
            }
            .onReceive(
                NotificationCenter.default.publisher(for: .openSettingsRequested)
            ) { _ in
                openSettings()
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
        let key = currentName.lowercased()
        var renames = UserDefaults.standard.appRenames
        if newName.isEmpty || newName == currentName {
            renames.removeValue(forKey: key)
        } else {
            renames[key] = newName
        }
        UserDefaults.standard.appRenames = renames
        NotificationCenter.default.post(name: .appSettingsChanged, object: nil)
        reloadEntries()
    }

    private func addAppToMode(_ app: any SwitchableApp, _ mode: CustomMode) {
        appDelegate.closeWindow()
        guard let bundleURL = app.runningApplication?.bundleURL?.absoluteString else { return }
        var modes = CustomModeStore.load()
        guard let index = modes.firstIndex(where: { $0.id == mode.id }) else { return }
        if modes[index].apps.contains(where: { $0.bundleURL == bundleURL }) { return }
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
