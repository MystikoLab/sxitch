import AppKit
import SwiftUI

struct RunningApp: SwitchableApp, Equatable {
    static func == (lhs: RunningApp, rhs: RunningApp) -> Bool {
        lhs.id == rhs.id && lhs.depth == rhs.depth
    }

    var id: String { "\(app.processIdentifier)" }

    var appName: String
    var app: NSRunningApplication
    var icon: NSImage
    var bundleUrl: URL?
    var bundleID: String
    var depth: Int = 0
    var symbolName: String? = nil
    var overrideTap: ((any SwitchableApp) -> Void)? = nil

    var runningApplication: NSRunningApplication? { app }

    static func fetchRunningApps() -> [RunningApp] {
        let usState = userState.shared
        @AppStorage("appBlacklists") var blacklist: [String] = []
        @AppStorage("prefixStrips") var prefixStrips: [String] = ["microsoft", "adobe"]
        return NSWorkspace.shared.runningApplications
            .map { app in
                let customIcon = CustomIconStore.shared.load(for: app.bundleIdentifier ?? "")
                return RunningApp(
                    appName: app.localizedName ?? "Unknown",
                    app: app,
                    icon: customIcon ?? app.icon ?? NSImage(),
                    bundleUrl: app.bundleURL,
                    bundleID: app.bundleIdentifier ?? "",
                )
            }
            .map { app in
                var app = app
                for prefix in prefixStrips {
                    if app.appName.lowercased().hasPrefix(prefix.lowercased()) {
                        app.appName = String(app.appName.dropFirst(prefix.count))
                            .trimmingCharacters(in: .whitespaces)
                        break
                    }
                }
                return app
            }
            .filter { app in
                app.app.activationPolicy == .regular
                    && (!blacklist.contains(app.appName.lowercased()) || !usState.isPro)
            }
            .sorted { $0.appName < $1.appName }
    }

    func performAction(action: AppMode) {
        switch action {
        case .normal: activate()
        case .hide: hideApp()
        case .quit: quitApp()
        }
    }

    func hideApp() { app.hide() }

    func quitApp() {
        print("Terminating: \(appName)")
        app.terminate()
    }

    func activate() {
        if let bundleUrl = bundleUrl {
            NSWorkspace.shared.open(bundleUrl)
        }
    }
}
