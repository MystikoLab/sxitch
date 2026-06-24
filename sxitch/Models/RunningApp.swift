import SwiftUI

struct RunningApp: Identifiable, Hashable {
    var id: Int32 { app.processIdentifier }
    var appName: String
    var app: NSRunningApplication
    var icon: NSImage
    var bundleUrl: URL?
    var bundleIdentifier: String

    init(app: NSRunningApplication) {
        self.appName = app.localizedName ?? "Unknown"
        self.app = app
        self.icon = app.icon ?? NSImage()
        self.bundleUrl = app.bundleURL
        self.bundleIdentifier = app.bundleIdentifier ?? ""
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(app.processIdentifier)
    }

    static func == (lhs: RunningApp, rhs: RunningApp) -> Bool {
        lhs.app.processIdentifier == rhs.app.processIdentifier
    }
}
