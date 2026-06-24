import SwiftUI
import Combine

@main
struct sxitchApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings {
            SettingsView()
                .toolbar(.hidden)
        }
        .windowLevel(.floating)
        .windowBackgroundDragBehavior(.enabled)

        MenuBarExtra("Sxitch", systemImage: "tray.fill") {
            Button("Show") {
                appDelegate.showWindow()
            }
            SettingsLink()
            Divider()
            Button("Quit Sxitch") {
                NSApp.terminate(nil)
            }
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    let appSwitcher = AppSwitcher(config: AppConfig.shared)
    lazy var hotkeyManager = HotkeyManager()
    var window: NSWindow!
    var cancellables = Set<AnyCancellable>()

    func applicationWillFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        window = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 0, height: 0),
            styleMask: [.borderless, .fullSizeContentView, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        (window as! NSPanel).isFloatingPanel = true
        window.isOpaque = false
        window.backgroundColor = .clear
        window.level = .floating
        window.isMovableByWindowBackground = true
        window.collectionBehavior = [.canJoinAllSpaces, .stationary]

        let contentView = NSHostingView(rootView: ContentView(appSwitcher: appSwitcher))
        contentView.translatesAutoresizingMaskIntoConstraints = false
        window.contentView = contentView

        window.hasShadow = true
        window.contentView?.wantsLayer = true
        window.contentView?.layer?.cornerRadius = 30
        window.contentView?.layer?.masksToBounds = true

        window.setContentSize(contentView.fittingSize)
        window.center()

        appSwitcher.$filteredApps
            .dropFirst()
            .debounce(for: .milliseconds(50), scheduler: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self = self else { return }
                guard let hostingView = self.window.contentView as? NSHostingView<ContentView> else { return }
                let newSize = hostingView.fittingSize
                if self.window.frame.size != newSize {
                    self.window.setContentSize(newSize)
                    self.window.center()
                }
            }
            .store(in: &cancellables)

        hotkeyManager.appSwitcher = appSwitcher
        hotkeyManager.window = window
        hotkeyManager.setupEventTap()

        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(activeAppChanged),
            name: NSWorkspace.didActivateApplicationNotification,
            object: nil
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(windowResignedKey),
            name: NSWindow.didResignKeyNotification,
            object: window
        )
    }

    func showWindow() {
        hotkeyManager.showWindow()
    }

    @objc func activeAppChanged() {
        if NSWorkspace.shared.frontmostApplication?.bundleIdentifier != Bundle.main.bundleIdentifier {
            window.orderOut(nil)
        }
    }

    @objc func windowResignedKey(_ notification: Notification) {
        window.orderOut(nil)
    }
}
