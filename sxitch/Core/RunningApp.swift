import AppKit
import SwiftUI

struct RunningApp: SwitchableApp, Equatable {
    static func == (lhs: RunningApp, rhs: RunningApp) -> Bool {
        lhs.id == rhs.id && lhs.depth == rhs.depth
    }

    var id: String {
        "\(app.processIdentifier)"
    }

    var appName: String
    var realName: String
    var app: NSRunningApplication
    var icon: NSImage
    var bundleUrl: URL?
    var bundleID: String
    var depth: Int = 0
    var symbolName: String? = nil
    var overrideTap: ((any SwitchableApp) -> Void)? = nil

    var runningApplication: NSRunningApplication? {
        app
    }

    /// The picker matches names against typed characters, so a name has to be
    /// alphanumeric. A localized name that isn't (备忘录, Заметки) falls back to
    /// the bundle's filename, which macOS keeps in English (Notes), then to the
    /// last part of the bundle ID for apps whose filename is localized as well.
    static func typeableName(localizedName: String?, bundleURL: URL?, bundleID: String?) -> String {
        let allowed = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz1234567890 "
        if let localizedName, !localizedName.isEmpty, localizedName.allSatisfy(allowed.contains) {
            return localizedName
        }
        let candidates = [
            bundleURL?.deletingPathExtension().lastPathComponent,
            bundleID?.split(separator: ".").last.map(String.init),
            localizedName,
        ]
        for candidate in candidates {
            let name = (candidate ?? "").filter(allowed.contains).trimmingCharacters(in: .whitespaces)
            if !name.isEmpty {
                return name
            }
        }
        return "Unknown"
    }

    static func fetchRunningApps() -> [RunningApp] {
        let usState = userState.shared
        @AppStorage("appBlacklists") var blacklist: [String] = []
        @AppStorage("prefixStrips") var prefixStrips: [String] = ["microsoft", "adobe"]
        let appRenames = UserDefaults.standard.appRenames
        let processed = NSWorkspace.shared.runningApplications
            .map { app in
                let customIcon = CustomIconStore.shared.load(for: app.bundleIdentifier ?? "")
                let appName = typeableName(
                    localizedName: app.localizedName,
                    bundleURL: app.bundleURL,
                    bundleID: app.bundleIdentifier
                )
                let finalisedName = appRenames[appName.lowercased()] ?? appName
                return RunningApp(
                    appName: finalisedName,
                    realName: appName,
                    app: app,
                    icon: customIcon ?? app.icon ?? NSImage(),
                    bundleUrl: app.bundleURL,
                    bundleID: app.bundleIdentifier ?? ""
                )
            }
            .map { app -> RunningApp in
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

        let filtered = processed.filter { app in
            app.app.activationPolicy == .regular
                && (!blacklist.contains(app.appName.lowercased()) || !usState.isPro)
        }

        var nameCounts: [String: Int] = [:]
        for app in filtered {
            nameCounts[app.appName.lowercased(), default: 0] += 1
        }

        var nameCounters: [String: Int] = [:]
        let deduped = filtered.map { app -> RunningApp in
            var app = app
            let key = app.appName.lowercased()
            if nameCounts[key]! > 1 {
                let index = nameCounters[key, default: 0]
                nameCounters[key] = index + 1
                app.appName = "\(letterForIndex(index)) - \(app.appName)"
            }
            return app
        }

        return deduped.sorted { $0.appName < $1.appName }
    }

    func performAction(action: AppMode) {
        switch action {
        case .normal: activate()
        case .hide: hideApp()
        case .quit: quitApp()
        }
    }

    func hideApp() {
        app.hide()
    }

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
