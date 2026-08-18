import AppKit
import SwiftUI

struct ContentView: View {
    @State private var openApps: [RunningApp] = RunningApp.fetchRunningApps()
    @State private var accessibilityGranted: Bool = AXIsProcessTrusted()

    @Environment(\.openSettings) private var openSettings
    @Environment(\.scenePhase) private var scenePhase

    @AppStorage("appBlacklists") var blacklist: [String] = []
    @AppStorage("prefixStrips") var prefixStrip: [String] = ["microsoft", "adobe"]
    @AppStorage("layoutStyle") var layoutStyle: String = "grid"
    @AppStorage("showPickerUi") private var showUi = true

    @ObservedObject var appState: AppState
    @State private var drillDownWindows: [WindowInfo] = []

    var appDelegate: AppDelegate

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
                .id(appState.mode)
            } else {
                AnyAppLayout(
                    apps: openApps,
                    typed: appState.typed,
                    onTap: handleAppTap,
                    layoutStyle: layoutStyle
                )
                .environment(\.modeTheme, ModeTheme.theme(for: appState.mode))
                .id(appState.mode)
            }
        }
    }

    var body: some View {
        Group {
            if layoutStyle == "circle" {
                appLayout
            } else {
                appLayout
                    .modernMacBackground()
                    .clipShape(RoundedRectangle(cornerRadius: 30))
            }
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: appState.typed)
        .animation(.spring(response: 0.25, dampingFraction: 0.65), value: appState.mode)
            .onReceive(
                NSWorkspace.shared.notificationCenter.publisher(
                    for: NSWorkspace.didLaunchApplicationNotification
                )
            ) { _ in
                guard appDelegate.window.isVisible else { return }
                withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                    openApps = RunningApp.fetchRunningApps()
                }
            }
            .onReceive(
                NSWorkspace.shared.notificationCenter.publisher(
                    for: NSWorkspace.didTerminateApplicationNotification
                )
            ) { _ in
                guard appDelegate.window.isVisible else { return }
                withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                    openApps = RunningApp.fetchRunningApps()
                }
            }
            .onReceive(
                NotificationCenter.default.publisher(for: .switcherWillShow)
            ) { _ in
                appDelegate.refreshCachedAppNames()
                openApps = RunningApp.fetchRunningApps()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                    appDelegate.resizeWindowToFit()
                }
            }
            .onReceive(
                NotificationCenter.default.publisher(for: .openSettingsRequested)
            ) { _ in
                openSettings()
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
                } else {
                    appDelegate.closeWindow()
                }
                return KeyPress.Result.handled
            }
            .onChange(of: blacklist) { _, _ in
                openApps = RunningApp.fetchRunningApps()
                NotificationCenter.default.post(name: .appSettingsChanged, object: nil)
            }
            .onChange(of: prefixStrip) { _, _ in
                openApps = RunningApp.fetchRunningApps()
                NotificationCenter.default.post(name: .appSettingsChanged, object: nil)
            }
            .onChange(of: openApps) { _, _ in
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                    appDelegate.resizeWindowToFit()
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
            }
    }

    func handleAppTap(_ app: RunningApp) {
        let windows = fetchWindowsForApp(app.app)
        let windowPickerEnabled = UserDefaults.standard.bool(forKey: "windowPickerEnabled")
        let currentMode = appState.mode

        if windows.count > 1, userState.shared.isPro, windowPickerEnabled {
            appState.drillDownApp = app.app
        } else if windows.count == 1 {
            let theme = ModeTheme.theme(for: currentMode)
            theme.windowAction(windows[0])
            appDelegate.closeWindow()
        } else {
            let theme = ModeTheme.theme(for: currentMode)
            theme.appAction(app)
            if currentMode == .normal { appDelegate.closeWindow() }
        }
    }
}
