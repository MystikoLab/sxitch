import AppKit

struct PinnedApp: SwitchableApp {
    var modeApp: ModeApp
    var depth: Int = 0
    var overrideTap: ((any SwitchableApp) -> Void)? = nil

    var id: String { "pinned-\(modeApp.id.uuidString)" }
    var appName: String { modeApp.displayName }

    var symbolName: String? {
        switch modeApp.icon {
        case .system(let name):
            return name
        case .image:
            return nil
        case nil:
            return modeApp.isShellCommand ? "terminal" : nil
        }
    }

    var icon: NSImage {
        switch modeApp.icon {
        case .image(let file):
            return ModeIconStore.shared.image(named: file) ?? NSImage()
        case .system:
            return NSImage()
        case nil:
            if let url = URL(string: modeApp.bundleURL),
               FileManager.default.fileExists(atPath: url.path) {
                return NSWorkspace.shared.icon(forFile: url.path)
            }
            return NSImage(systemSymbolName: "app", accessibilityDescription: nil) ?? NSImage()
        }
    }

    var runningApplication: NSRunningApplication? {
        guard let url = URL(string: modeApp.bundleURL) else { return nil }
        return NSWorkspace.shared.runningApplications.first {
            $0.bundleURL == url
        }
    }

    func activate() {
        if let command = modeApp.shellCommand?
            .trimmingCharacters(in: .whitespacesAndNewlines), !command.isEmpty {
            ShellCommandRunner.run(command)
            return
        }
        guard let url = URL(string: modeApp.bundleURL) else { return }
        NSWorkspace.shared.open(url)
    }

    func hideApp() {
        runningApplication?.hide()
    }

    func quitApp() {
        runningApplication?.terminate()
    }
}