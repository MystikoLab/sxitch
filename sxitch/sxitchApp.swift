import Combine
import SwiftUI

@main
struct sxitchApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        // Keep the Settings scene so Cmd+, and SettingsLink work via the notification path.
        Settings {
            SettingsView()
                .toolbar(.hidden)
        }
        .windowLevel(.floating)
        .windowBackgroundDragBehavior(.enabled)
    }
}

// MARK: - AppDelegate

class AppDelegate: NSObject, NSApplicationDelegate {
    let appSwitcher = AppSwitcher(config: AppConfig.shared)
    lazy var hotkeyManager = HotkeyManager()

    var window: NSWindow!
    var onboardingWindow: NSWindow?
    private var statusItem: NSStatusItem?
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Lifecycle

    func applicationWillFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupSwitcherWindow()
        setupHotkeyManager()
        setupWorkspaceObservers()
        setupTrayIcon()
        observeConfigChanges()

        LicenseManager.shared.checkStoredLicense()

        // Show onboarding on very first launch
        if !AppConfig.shared.onboardingComplete {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                self.showOnboarding()
            }
        }
    }

    // MARK: - Switcher Window

    private func setupSwitcherWindow() {
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 0, height: 0),
            styleMask: [.borderless, .fullSizeContentView, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isFloatingPanel = true
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.floatingWindow)) + 100)
        panel.isMovableByWindowBackground = true
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary]
        panel.hasShadow = true

        let contentView = NSHostingView(rootView: ContentView(appSwitcher: appSwitcher))
        contentView.translatesAutoresizingMaskIntoConstraints = false
        panel.contentView = contentView
        panel.contentView?.wantsLayer = true
        panel.contentView?.layer?.cornerRadius = 30
        panel.contentView?.layer?.masksToBounds = true
        panel.setContentSize(contentView.fittingSize)
        panel.center()

        window = panel

        // Auto-resize when filtered app list changes.
        // Keep the window's top-center pinned so pressing Escape (which restores
        // the full app list) doesn't jump the window to a new position.
        appSwitcher.$filteredApps
            .dropFirst()
            .debounce(for: .milliseconds(50), scheduler: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self,
                    let hostingView = self.window.contentView as? NSHostingView<ContentView>
                else { return }
                let newSize = hostingView.fittingSize
                let current = self.window.frame
                guard current.size != newSize else { return }

                if self.window.isVisible {
                    // Anchor the top-center so the panel grows/shrinks in place.
                    let topCenterX = current.midX
                    let topY = current.maxY  // maxY = top edge in macOS coords
                    let newOrigin = NSPoint(
                        x: topCenterX - newSize.width / 2,
                        y: topY - newSize.height
                    )
                    self.window.setFrame(
                        NSRect(origin: newOrigin, size: newSize),
                        display: true, animate: false
                    )
                } else {
                    // Window is hidden; just update size so it's correct when shown next.
                    self.window.setContentSize(newSize)
                }
            }
            .store(in: &cancellables)

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(windowResignedKey),
            name: NSWindow.didResignKeyNotification,
            object: window
        )
    }

    // MARK: - Hotkey Manager

    private func setupHotkeyManager() {
        hotkeyManager.appSwitcher = appSwitcher
        hotkeyManager.window = window
        hotkeyManager.setupEventTap()
    }

    // MARK: - Workspace Observers

    private func setupWorkspaceObservers() {
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(activeAppChanged),
            name: NSWorkspace.didActivateApplicationNotification,
            object: nil
        )
    }

    @objc private func activeAppChanged() {
        if NSWorkspace.shared.frontmostApplication?.bundleIdentifier
            != Bundle.main.bundleIdentifier
        {
            hotkeyManager.hideWindow()
        }
    }

    @objc private func windowResignedKey(_ notification: Notification) {
        hotkeyManager.hideWindow()
    }

    // MARK: - Tray Icon

    private func setupTrayIcon() {
        updateTrayVisibility()
    }

    private func observeConfigChanges() {
        AppConfig.shared.objectWillChange
            .receive(on: DispatchQueue.main)
            .debounce(for: .milliseconds(100), scheduler: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.updateTrayVisibility()
                self?.rebuildMenu()
            }
            .store(in: &cancellables)
    }

    func updateTrayVisibility() {
        let shouldShow = AppConfig.shared.trayIconVisible
        if shouldShow && statusItem == nil {
            statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
            if let button = statusItem?.button {
                button.image = makeTrayIcon()
                button.toolTip = "Sxitch"
            }
            rebuildMenu()
        } else if !shouldShow, let item = statusItem {
            NSStatusBar.system.removeStatusItem(item)
            statusItem = nil
        }
    }

    func rebuildMenu() {
        guard let statusItem else { return }
        let menu = NSMenu()
        let config = AppConfig.shared
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"

        // Status indicator
        let statusLabel = config.isPro ? "✦ Sxitch Pro" : "Sxitch Free"
        let statusMenuItem = NSMenuItem(title: statusLabel, action: nil, keyEquivalent: "")
        statusMenuItem.isEnabled = false
        menu.addItem(statusMenuItem)

        let versionItem = NSMenuItem(title: "Version \(version)", action: nil, keyEquivalent: "")
        versionItem.isEnabled = false
        menu.addItem(versionItem)

        menu.addItem(.separator())

        if !config.isPro {
            let proItem = NSMenuItem(
                title: "✨ Get Pro", action: #selector(openPricing), keyEquivalent: "")
            proItem.target = self
            menu.addItem(proItem)
        }

        let showItem = NSMenuItem(
            title: "Show", action: #selector(showWindowAction), keyEquivalent: "")
        showItem.target = self
        menu.addItem(showItem)

        menu.addItem(.separator())

        let ghItem = NSMenuItem(title: "GitHub", action: #selector(openGitHub), keyEquivalent: "")
        ghItem.target = self
        menu.addItem(ghItem)

        let homeItem = NSMenuItem(
            title: "Homepage", action: #selector(openHomepage), keyEquivalent: "")
        homeItem.target = self
        menu.addItem(homeItem)

        let communityItem = NSMenuItem(
            title: "Community", action: #selector(openCommunity), keyEquivalent: "")
        communityItem.target = self
        menu.addItem(communityItem)

        menu.addItem(.separator())

        let settingsItem = NSMenuItem(
            title: "Sxitch Settings",
            action: #selector(openSettingsAction),
            keyEquivalent: ","
        )
        settingsItem.keyEquivalentModifierMask = .command
        settingsItem.target = self
        menu.addItem(settingsItem)

        let quitItem = NSMenuItem(
            title: "Quit Sxitch",
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        )
        quitItem.keyEquivalentModifierMask = .command
        menu.addItem(quitItem)

        statusItem.menu = menu
    }

    // MARK: - Menu Actions

    @objc func showWindowAction() {
        hotkeyManager.showWindow()
    }

    @objc func openSettingsAction() {
        NSApp.activate(ignoringOtherApps: true)
        NotificationCenter.default.post(name: .openSettings, object: nil)
    }

    @objc func openPricing() {
        NSWorkspace.shared.open(URL(string: "https://sxitch.app/#pricing")!)
    }

    @objc func openGitHub() {
        NSWorkspace.shared.open(URL(string: "https://github.com/unsecretised/sxitch-public")!)
    }

    @objc func openHomepage() {
        NSWorkspace.shared.open(URL(string: "https://sxitch.app")!)
    }

    @objc func openCommunity() {
        NSWorkspace.shared.open(URL(string: "https://discord.sxitch.app")!)
    }

    // MARK: - Public Show Wrapper

    func showWindow() {
        hotkeyManager.showWindow()
    }

    // MARK: - Onboarding

    func showOnboarding() {
        guard onboardingWindow == nil else { return }

        let win = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 520, height: 440),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        win.title = "Welcome to Sxitch"
        win.isReleasedWhenClosed = false

        let view = OnboardingView {
            AppConfig.shared.onboardingComplete = true
            win.close()
            self.onboardingWindow = nil
        }
        win.contentView = NSHostingView(rootView: view)
        win.center()
        win.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        onboardingWindow = win
    }

    // MARK: - Tray Icon Drawing

    /// Programmatically draws a 512×512-equivalent toggle-switch icon scaled to menu bar size.
    private func makeTrayIcon() -> NSImage {
        let size = NSSize(width: 18, height: 18)
        let image = NSImage(size: size)
        image.lockFocus()

        let trackH: CGFloat = 8
        let trackY: CGFloat = (size.height - trackH) / 2
        let trackRect = NSRect(x: 1, y: trackY, width: size.width - 2, height: trackH)
        let track = NSBezierPath(roundedRect: trackRect, xRadius: trackH / 2, yRadius: trackH / 2)
        track.lineWidth = 1.5
        NSColor.black.setStroke()
        track.stroke()

        // Knob on right side (switch "on" state)
        let knobD = trackH - 2
        let knobX = trackRect.maxX - knobD - 1
        let knobRect = NSRect(x: knobX, y: trackY + 1, width: knobD, height: knobD)
        let knob = NSBezierPath(ovalIn: knobRect)
        NSColor.black.setFill()
        knob.fill()

        image.unlockFocus()
        // Template images auto-invert for light/dark menu bars
        image.isTemplate = true
        return image
    }
}
