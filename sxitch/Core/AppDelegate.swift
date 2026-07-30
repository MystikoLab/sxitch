import Cocoa
import Combine
import KeyboardShortcuts
import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate {
    var appState = AppState()
    var window: NSWindow!
    var eventTap: CFMachPort?
    private var suppressActiveAppCheck = false
    private var permissionCheckTimer: Timer?
    var allModifiersHeldPreviously: Bool = false
    var heldModifierKeyCodes: Set<Int64> = []
    private var cancellables = Set<AnyCancellable>()
    var cachedAppNames: [String] = []

    let keyCodeToChar: [Int64: Character] = [
        0: "a", 11: "b", 8: "c", 2: "d", 14: "e", 3: "f", 5: "g",
        4: "h", 34: "i", 38: "j", 40: "k", 37: "l", 46: "m", 45: "n",
        31: "o", 35: "p", 12: "q", 15: "r", 1: "s", 17: "t", 32: "u",
        9: "v", 13: "w", 7: "x", 16: "y", 6: "z",
    ]

    var proState = userState.shared

    let flagForKeyCode: [Int64: CGEventFlags] = [
        58: .maskAlternate,
        61: .maskAlternate,
        55: .maskCommand,
        54: .maskCommand,
        56: .maskShift,
        60: .maskShift,
        59: .maskControl,
        62: .maskControl,
        57: .maskAlphaShift,
    ]

    let familyLeftCodes: [Int] = [58, 55, 56, 59, 57]
    let familyRightCodes: [Int] = [61, 54, 60, 62, 57]

    private func parseModifierConfig() -> [(family: Int, side: String)] {
        let str = UserDefaults.standard.string(forKey: "hotkey_modifier_config") ?? ""
        if str.isEmpty {
            let oldStr = UserDefaults.standard.string(forKey: "hotkey_modifiers") ?? ""
            if oldStr.isEmpty {
                let code = UserDefaults.standard.integer(forKey: "hotkey_modifier")
                if code > 0 {
                    let family: Int = {
                        switch code {
                        case 58, 61: return 0
                        case 55, 54: return 1
                        case 56, 60: return 2
                        case 59, 62: return 3
                        case 57: return 4
                        default: return 0
                        }
                    }()
                    let left = familyLeftCodes[family]
                    let right = familyRightCodes[family]
                    let side = code == right ? "right" : "left"
                    let sided = UserDefaults.standard.bool(forKey: "hotkey_sided")
                    return [(family, sided ? side : "either")]
                }
                return [(1, "right")]
            }
            return oldStr.split(separator: ",").compactMap { Int($0.trimmingCharacters(in: .whitespaces)) }.map { code in
                let family: Int = {
                    switch code {
                    case 58, 61: return 0
                    case 55, 54: return 1
                    case 56, 60: return 2
                    case 59, 62: return 3
                    case 57: return 4
                    default: return 0
                    }
                }()
                let left = familyLeftCodes[family]
                let right = familyRightCodes[family]
                let side = code == right ? "right" : "left"
                return (family, side)
            }
        }
        return str.split(separator: ",").compactMap { entry in
            let parts = entry.split(separator: ":")
            guard parts.count == 2, let family = Int(parts[0]) else { return nil }
            return (family, String(parts[1]))
        }
    }

    private func modifiersSatisfied(config: [(family: Int, side: String)]) -> Bool {
        config.allSatisfy { family, side in
            if family == 4 {
                return NSEvent.modifierFlags.contains(.capsLock)
            }
            let left = Int64(familyLeftCodes[family])
            let right = Int64(familyRightCodes[family])
            switch side {
            case "left": return heldModifierKeyCodes.contains(left)
            case "right": return heldModifierKeyCodes.contains(right)
            case "either": return heldModifierKeyCodes.contains(left) || heldModifierKeyCodes.contains(right)
            default: return false
            }
        }
    }

    func applicationWillFinishLaunching(_: Notification) {
        NSApp.setActivationPolicy(.accessory)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_: NSApplication) -> Bool {
        return false
    }

    func closeWindow() {
        guard window.isVisible else { return }
        appState.typed = ""
        appState.depth = 0
        appState.mode = .normal
        appState.drillDownApp = nil
        window.orderOut(nil)
    }

    var windowPosition: Position {
        get {
            let raw = UserDefaults.standard.string(forKey: "windowPosition") ?? Position.default.rawValue
            return Position(rawValue: raw) ?? .default
        }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: "windowPosition") }
    }

    func screenWithMouse() -> NSScreen {
        let mouse = NSEvent.mouseLocation
        return NSScreen.screens.first { $0.frame.contains(mouse) } ?? NSScreen.main!
    }

    func centerWindowHorizontally() {
        let screen = window.screen ?? NSScreen.main
        let screenWidth = screen?.frame.width ?? 0
        let currentFrame = window.frame
        let newX = (screenWidth - currentFrame.width) / 2
        window.setFrameOrigin(NSPoint(x: newX, y: currentFrame.minY))
    }

    func positionWindow() {
        if windowPosition == .default {
            window.center()
        } else {
            let screen = screenWithMouse()
            let size = window.frame.size
            let origin = windowPosition.point(for: size, on: screen)
            window.setFrameOrigin(origin)
        }
    }

    func resizeWindowToFit() {
        guard window.isVisible else { return }
        guard let hostingView = window.contentView else { return }
        hostingView.layoutSubtreeIfNeeded();
        let newSize = hostingView.fittingSize
        guard newSize.width > 0, newSize.height > 0 else { return }
        let currentFrame = window.frame
        window.setFrame(
            NSRect(origin: currentFrame.origin, size: newSize),
            display: false
        )
        if windowPosition == .default {
            window.center()
        } else {
            let screen = window.screen ?? screenWithMouse()
            let origin = windowPosition.point(for: newSize, on: screen)
            window.setFrameOrigin(origin)
        }
    }

    func applicationDidFinishLaunching(_: Notification) {
        window = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 0, height: 0),
            styleMask: [.borderless, .fullSizeContentView, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        (window as! NSPanel).isFloatingPanel = true
        window.isOpaque = false
        self.resizeWindowToFit()
        window.backgroundColor = .clear
        window.level = NSWindow.Level(NSWindow.Level.floating.rawValue + 200)
        window.isMovableByWindowBackground = true
        window.collectionBehavior = [.canJoinAllSpaces, .stationary]

        let contentView = NSHostingView(
            rootView: ContentView(appState: appState, appDelegate: self)
        )
        contentView.translatesAutoresizingMaskIntoConstraints = false
        window.contentView = contentView

        window.hasShadow = true
        window.contentView?.wantsLayer = true
        window.contentView?.layer?.cornerRadius = 10
        window.contentView?.layer?.masksToBounds = true

        window.setContentSize(contentView.fittingSize)
        window.center()

        if UserDefaults.standard.bool(forKey: "hasCompletedOnboarding") {
            window.makeKeyAndOrderFront(nil)
            self.appState.depth = 0
            self.appState.typed = ""
        }

        NotificationCenter.default.addObserver(
            forName: .onboardingCompleted, object: nil, queue: .main
        ) { [weak self] _ in
            guard let self else { return }
            NSApp.windows
                .filter { $0.identifier?.rawValue == "onboarding" }
                .forEach { $0.close() }
            NotificationCenter.default.post(name: .switcherWillShow, object: nil)
            self.window.makeKeyAndOrderFront(nil)
            self.window.orderFrontRegardless()
        }

        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(activeAppChanged),
            name: NSWorkspace.didActivateApplicationNotification,
            object: nil
        )

        NotificationCenter.default.addObserver(forName: .appHotkeyAdded, object: nil, queue: .main) { note in
            guard let bundleURL = note.object as? String else { return }
            Task { @MainActor in
                KeyboardShortcuts.onKeyDown(for: .appLaunch(bundleURL)) {
                    guard let url = URL(string: bundleURL) else { return }
                    let config = NSWorkspace.OpenConfiguration()
                    config.activates = true
                    NSWorkspace.shared.openApplication(at: url, configuration: config)
                }
            }
        }

        setupEventTap()
        setupAutoSelect()
        refreshCachedAppNames()
        NSWorkspace.shared.notificationCenter.addObserver(
            self, selector: #selector(refreshCachedAppNames),
            name: NSWorkspace.didLaunchApplicationNotification, object: nil
        )
        NSWorkspace.shared.notificationCenter.addObserver(
            self, selector: #selector(refreshCachedAppNames),
            name: NSWorkspace.didTerminateApplicationNotification, object: nil
        )
        NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) {
            [weak self] _ in
            guard let self = self else { return }
            if self.window.isVisible {
                self.closeWindow()
            }
        }
    }

    func setupAutoSelect() {
        appState.$typed
            .debounce(for: .milliseconds(100), scheduler: DispatchQueue.main)
            .sink { [weak self] typed in
                guard let self = self, !typed.isEmpty, self.window.isVisible else { return }

                if let drillApp = self.appState.drillDownApp {
                    let allWindows = fetchWindowsForApp(drillApp)
                    let matched = allWindows.filter {
                        $0.title.lowercased().starts(with: typed.lowercased())
                    }
                    if matched.count == 1 {
                        let theme = ModeTheme.theme(for: self.appState.mode)
                        theme.windowAction(matched[0])
                        self.appState.depth = 0
                        self.appState.typed = ""
                        if self.appState.mode == .normal {
                            self.closeWindow()
                        }
                    }
                } else {
                    let filteredApps = RunningApp.fetchRunningApps().filter {
                        $0.appName.lowercased().starts(with: typed.lowercased())
                    }
                    if filteredApps.count == 1 {
                        let singleApp = filteredApps[0]
                        let theme = ModeTheme.theme(for: self.appState.mode)
                        let windows = fetchWindowsForApp(singleApp.app)
                        if windows.count == 1 {
                            theme.windowAction(windows[0])
                        } else {
                            theme.appAction(singleApp)
                        }
                        if self.appState.mode == .normal { self.closeWindow() }
                        self.appState.depth = 0
                        self.appState.typed = ""
                    }
                }
            }
            .store(in: &cancellables)
    }

    @objc func refreshCachedAppNames() {
        let blacklist = UserDefaults.standard.stringArray(forKey: "appBlacklists") ?? []
        let prefixStrips = UserDefaults.standard.stringArray(forKey: "prefixStrips") ?? ["microsoft", "adobe"]
        let usState = userState.shared
        cachedAppNames = NSWorkspace.shared.runningApplications
            .filter { $0.activationPolicy == .regular }
            .map { $0.localizedName ?? "Unknown" }
            .map { name in
                var appName = name
                for prefix in prefixStrips {
                    if appName.lowercased().hasPrefix(prefix.lowercased()) {
                        appName = String(appName.dropFirst(prefix.count)).trimmingCharacters(in: .whitespaces)
                        break
                    }
                }
                return appName.lowercased()
            }
            .filter { !blacklist.contains($0) || !usState.isPro }
    }

    func setupEventTap() {
        if let existing = eventTap, CGEvent.tapIsEnabled(tap: existing) {
            return
        }

        guard AXIsProcessTrusted() else {
            if permissionCheckTimer == nil {
                permissionCheckTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) {
                    [weak self] _ in
                    if AXIsProcessTrusted() {
                        self?.permissionCheckTimer?.invalidate()
                        self?.permissionCheckTimer = nil
                        self?.setupEventTap()
                    }
                }
            }
            return
        }

        permissionCheckTimer?.invalidate()
        permissionCheckTimer = nil

        let mask: CGEventMask =
            (1 << CGEventType.keyDown.rawValue) | (1 << CGEventType.flagsChanged.rawValue)

        guard
            let tap = CGEvent.tapCreate(
                tap: .cgSessionEventTap,
                place: .headInsertEventTap,
                options: .defaultTap,
                eventsOfInterest: mask,
                callback: { proxy, type, event, userInfo in
                    let delegate = Unmanaged<AppDelegate>.fromOpaque(userInfo!)
                        .takeUnretainedValue()
                    return delegate.handleEvent(proxy: proxy, type: type, event: event)
                },
                userInfo: Unmanaged.passUnretained(self).toOpaque()
            )
        else {
            print("Failed to create event tap")
            return
        }

        eventTap = tap
        let runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        print("Event tap created successfully")
    }

    func handleEvent(proxy _: CGEventTapProxy, type: CGEventType, event: CGEvent) -> Unmanaged<
        CGEvent
    >? {
        let flags = event.flags
        let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
        let savedKeycode = UserDefaults.standard.integer(forKey: "hotkey_keycode")

        if type == .flagsChanged, flagForKeyCode.keys.contains(keyCode) {
            if flags.contains(flagForKeyCode[keyCode]!) {
                heldModifierKeyCodes.insert(keyCode)
            } else {
                heldModifierKeyCodes.remove(keyCode)
            }
        }

        if keyCode == 53, window.isVisible {
            DispatchQueue.main.async {
                if self.appState.drillDownApp != nil {
                    if self.appState.typed.isEmpty {
                        self.appState.drillDownApp = nil
                    } else {
                        self.appState.typed = ""
                    }
                } else if self.appState.typed.isEmpty {
                    self.closeWindow()
                } else {
                    self.appState.typed = ""
                }
            }
            return nil
        }
        if window.isVisible, flags.contains(.maskCommand), keyCode == 43 {
            closeWindow()
            if #available(macOS 14.0, *) {
                NSApp.sendAction(Selector(("openSettings:")), to: nil, from: nil)
            } else {
                NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
            }
            return nil
        } else if window.isVisible, flags.contains(.maskCommand), keyCode == 12 {
            NSApp.terminate(nil)
            return nil
        }

        if window.isVisible, flags.contains(.maskControl), proState.isPro {
            if keyCode == 12 {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.65)) {
                        self.appState.mode = self.appState.mode == .quit ? .normal : .quit
                    }
                }
                return nil
            } else if keyCode == 4 {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.65)) {
                        self.appState.mode = self.appState.mode == .hide ? .normal : .hide
                    }
                }
                return nil
            } else if keyCode == 45 {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.65)) {
                        self.appState.mode = .normal
                    }
                }
                return nil
            }
        }

        if proState.isPro {
            for bundleURL in UserDefaults.standard.appHotkeys.keys {
                KeyboardShortcuts.onKeyDown(for: .appLaunch(bundleURL)) {
                    guard let url = URL(string: bundleURL) else { return }
                    let config = NSWorkspace.OpenConfiguration()
                    config.activates = true
                    NSWorkspace.shared.openApplication(at: url, configuration: config)
                }
            }
        }

        if savedKeycode == 256, type == .flagsChanged {
            let config = parseModifierConfig()
            let allHeld = modifiersSatisfied(config: config)
            if allHeld && !allModifiersHeldPreviously {
                allModifiersHeldPreviously = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                    if self.window.isVisible {
                        self.closeWindow()
                    } else {
                        self.positionWindow()
                        NotificationCenter.default.post(name: .switcherWillShow, object: nil)
                        self.window.orderFrontRegardless()
                    }
                }
                return nil
            } else if !allHeld {
                allModifiersHeldPreviously = false
            }
        }

        if window.isVisible, flags == CGEventFlags(rawValue: 256) {
            if let letter = keyCodeToChar[keyCode] {
                let raw = String(letter)
                let pickerChar: String
                if self.proState.isPro {
                    let overrides = UserDefaults.standard.keyOverrides
                    pickerChar = overrides[raw] ?? raw
                } else {
                    pickerChar = raw
                }
                let candidate = appState.typed + pickerChar
                let candidateLower = candidate.lowercased()
                let matchingNames = cachedAppNames.filter { $0.hasPrefix(candidateLower) }
                if matchingNames.isEmpty { return nil }
                if matchingNames.count == 1, appState.drillDownApp == nil {
                    let name = matchingNames[0]
                    DispatchQueue.main.async {
                        let allApps = RunningApp.fetchRunningApps()
                        let filtered = allApps.filter { $0.appName.lowercased() == name }
                        if let app = filtered.first {
                            let theme = ModeTheme.theme(for: self.appState.mode)
                            let windows = fetchWindowsForApp(app.app)
                            if windows.count == 1 {
                                theme.windowAction(windows[0])
                            } else {
                                theme.appAction(app)
                            }
                            if self.appState.mode == .normal { self.closeWindow() }
                        }
                    }
                    return nil
                }
                DispatchQueue.main.async {
                    self.appState.typed = candidate
                    self.appState.depth += pickerChar.count
                }
                return nil
            }
        }

        if type == .keyDown, savedKeycode != 256, keyCode == Int64(savedKeycode) {
            let config = parseModifierConfig()
            if modifiersSatisfied(config: config) {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                    if self.window.isVisible {
                        self.closeWindow()
                    } else {
                        self.positionWindow()
                        NotificationCenter.default.post(name: .switcherWillShow, object: nil)
                        self.window.orderFrontRegardless()
                    }
                }
                return nil
            }
        }

        return Unmanaged.passUnretained(event)
    }

    @objc func activeAppChanged() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            guard !self.suppressActiveAppCheck else { return }
            if NSWorkspace.shared.frontmostApplication?.bundleIdentifier
                != Bundle.main.bundleIdentifier
            {
                self.closeWindow()
            }
        }
    }
}
