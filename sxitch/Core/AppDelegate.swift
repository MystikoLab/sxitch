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
    private var registeredModeHotkeyIDs: Set<String> = []

    // Snapshots read by the event-tap callback. The tap runs on its own thread under a
    // hard timeout: enumerating NSWorkspace (which builds an icon per running app) or
    // walking the AX API of another process can easily overrun it, and macOS responds by
    // disabling the tap. These are refreshed on the main thread whenever the switcher is
    // shown or its contents change, so the callback only ever reads memory.
    private let cacheLock = NSLock()
    private var cachedAppNames: [String] = []
    private var cachedDrillWindows: [WindowInfo] = []

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

    /// Seeds the defaults the event tap reads directly.
    ///
    /// `@AppStorage("hotkey_keycode")` in the settings view only supplies a fallback to
    /// SwiftUI — it writes nothing until the user changes the picker. Without this,
    /// `UserDefaults.standard.integer(forKey:)` in `handleEvent` returns 0 on a fresh
    /// install, which is the keycode for "A", so the configured hotkey never matches.
    ///
    /// 256 is the sentinel for "no key, modifier only", i.e. the documented default of
    /// tapping Right ⌘ on its own.
    ///
    /// `hotkey_modifier_config` is deliberately *not* registered: both `parseModifierConfig()`
    /// and the settings view treat its absence as the trigger to migrate the pre-1.x
    /// `hotkey_modifiers` / `hotkey_modifier` keys, and both already fall back to right ⌘.
    private func registerDefaultSettings() {
        UserDefaults.standard.register(defaults: [
            "hotkey_keycode": 256,
        ])
        if #available(macOS 26.0, *) {
            UserDefaults.standard.register(defaults: [
                "liquidGlass": true,
            ])
        }
    }

    func applicationWillFinishLaunching(_: Notification) {
        registerDefaultSettings()
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
        appState.activeModeID = nil
        appState.drillDownApp = nil
        window.orderOut(nil)
    }

    private func toggleMode(_ mode: AppMode) {
        guard window.isVisible, proState.isPro else {
            closeWindow()
            let alert = NSAlert()
            alert.messageText = "Hide and Quit modes are disabled"
            alert.informativeText = "This feature is only available in Sxitch Pro"
            alert.alertStyle = .informational
            alert.addButton(withTitle: "Get Sxitch Pro")
            alert.addButton(withTitle: "Cancel")
            let response = alert.runModal()

            if response == .alertFirstButtonReturn {
                if let sxitchUrl = URL(string: "https://sxitch.app/#download") {
                    NSWorkspace.shared.open(sxitchUrl)
                }
            }

            return
        }
        DispatchQueue.main.async {
            withAnimation(.spring(response: 0.25, dampingFraction: 0.65)) {
                self.appState.mode = self.appState.mode == mode ? .normal : mode
            }
        }
    }

    /// Arms the handlers for every saved app-launch hotkey.
    ///
    /// This used to live inside the event-tap callback, which re-registered every handler on
    /// every single key event — expensive enough to trip the tap's timeout, and done from the
    /// tap's thread rather than the main actor. Doing it once at launch also fixes saved
    /// hotkeys staying dead until some unrelated key happened to be pressed.
    func registerAppLaunchHotkeys() {
        for bundleURL in UserDefaults.standard.appHotkeys.keys {
            registerAppLaunchHotkey(bundleURL: bundleURL)
        }
    }

    func registerAppLaunchHotkey(bundleURL: String) {
        KeyboardShortcuts.onKeyDown(for: .appLaunch(bundleURL)) { [weak self] in
            // App-launch hotkeys are Pro-only. The handler is registered regardless so the
            // shortcut stays claimed and survives the async licence check, but it only acts
            // once a licence is present.
            guard let self, self.proState.isPro else { return }
            guard let url = URL(string: bundleURL) else { return }
            let config = NSWorkspace.OpenConfiguration()
            config.activates = true
            NSWorkspace.shared.openApplication(at: url, configuration: config)
        }
    }

    func registerModeHotkeys() {
        let modes = CustomModeStore.load()
        let eligible = proState.isPro
            ? modes
            : Array(modes.prefix(CustomModeStore.freeModeLimit))
        let eligibleIDs = Set(eligible.map { $0.id.uuidString })
        for stale in registeredModeHotkeyIDs.subtracting(eligibleIDs) {
            KeyboardShortcuts.removeHandler(for: .customMode(stale))
        }
        for mode in eligible {
            let id = mode.id.uuidString
            KeyboardShortcuts.removeHandler(for: .customMode(id))
            KeyboardShortcuts.onKeyDown(for: .customMode(id)) { [weak self] in
                self?.toggleCustomMode(id)
            }
        }
        registeredModeHotkeyIDs = eligibleIDs
    }

    private func toggleCustomMode(_ id: String) {
        guard CustomModeStore.load().contains(where: { $0.id.uuidString == id }) else { return }
        DispatchQueue.main.async {
            if self.window.isVisible {
                if self.appState.activeModeID == id {
                    // Same mode again: toggle the window closed.
                    self.closeWindow()
                } else {
                    // Different mode (or default switcher): swap content in place.
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.65)) {
                        self.appState.activeModeID = id
                        self.appState.typed = ""
                        self.appState.depth = 0
                    }
                    self.resizeWindowToFit(force: true)
                }
            } else {
                // Hidden: set the mode *before* showing so the panel renders its final
                // content and size off-screen, then reveal it once — no flicker.
                self.appState.activeModeID = id
                self.appState.typed = ""
                self.appState.depth = 0
                DispatchQueue.main.async {
                    self.resizeWindowToFit(force: true)
                    self.positionWindow()
                    NotificationCenter.default.post(name: .switcherWillShow, object: nil)
                    self.window.orderFrontRegardless()
                }
            }
        }
    }

    func currentEntries() -> [any SwitchableApp] {
        if let id = appState.activeModeID,
           let mode = CustomModeStore.load().first(where: { $0.id.uuidString == id })
        {
            return mode.apps.map { PinnedApp(modeApp: $0) }
        }
        var entries: [any SwitchableApp] = RunningApp.fetchRunningApps()
        let pinnedURLs = UserDefaults.standard.pinnedAppURLs
        let runningURLs = Set(
            entries.compactMap {
                ($0.runningApplication?.bundleURL?.absoluteString)
                    ?? (($0 as? PinnedApp)?.modeApp.bundleURL)
            }
        )
        for url in pinnedURLs where !runningURLs.contains(url) {
            let path = URL(string: url)?.path ?? url
            let name = FileManager.default.displayName(atPath: path)
            entries.append(
                PinnedApp(
                    modeApp: ModeApp(
                        bundleURL: url,
                        displayName: name.isEmpty ? "App" : name
                    )
                )
            )
        }
        return entries
    }

    func currentAppNames() -> [String] {
        currentEntries().map { $0.appName.lowercased() }
    }

    /// Recomputes the snapshots the event tap matches against. Main thread only.
    func refreshTapCaches() {
        let names = currentAppNames()
        let windows = appState.drillDownApp.map { fetchWindowsForApp($0) } ?? []
        cacheLock.lock()
        cachedAppNames = names
        cachedDrillWindows = windows
        cacheLock.unlock()
    }

    private func tapAppNames() -> [String] {
        cacheLock.lock()
        defer { cacheLock.unlock() }
        return cachedAppNames
    }

    private func tapDrillWindows() -> [WindowInfo] {
        cacheLock.lock()
        defer { cacheLock.unlock() }
        return cachedDrillWindows
    }

    func selectCurrentApp(named: String) {
        let entries = currentEntries()
        guard let entry = entries.first(where: { $0.appName.lowercased() == named }) else { return }
        let theme = ModeTheme.theme(for: appState.mode)
        let windowPickerEnabled = UserDefaults.standard.bool(forKey: "windowPickerEnabled")

        if let running = entry.runningApplication {
            let windows = fetchWindowsForApp(running)
            if windows.count == 1 {
                theme.windowAction(windows[0])
                if appState.mode == .normal {
                    closeWindow()
                }
            } else if windows.count > 1, proState.isPro, windowPickerEnabled {
                appState.drillDownApp = running
            } else {
                theme.appAction(entry)
                if appState.mode == .normal {
                    closeWindow()
                }
            }
        } else {
            theme.appAction(entry)
            if appState.mode == .normal {
                closeWindow()
            }
        }

        appState.depth = 0
        appState.typed = ""
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
        } else if windowPosition == .mousePos {
            let mouseLocation = NSEvent.mouseLocation
            let screen = screenWithMouse()
            let size = window.frame.size

            var origin = NSPoint(
                x: mouseLocation.x - size.width / 2,
                y: mouseLocation.y - size.height / 2
            )

            // Clamp to the screen's visible frame so it doesn't hang off an edge
            let visible = screen.visibleFrame
            origin.x = min(max(origin.x, visible.minX), visible.maxX - size.width)
            origin.y = min(max(origin.y, visible.minY), visible.maxY - size.height)

            window.setFrameOrigin(origin)
        } else {
            let screen = screenWithMouse()
            let size = window.frame.size
            let origin = windowPosition.point(for: size, on: screen)
            window.setFrameOrigin(origin)
        }
    }

    func resizeWindowToFit(force: Bool = false) {
        guard force || window.isVisible else { return }
        guard let hostingView = window.contentView else { return }
        hostingView.layoutSubtreeIfNeeded()
        let newSize = hostingView.fittingSize
        guard newSize.width > 0, newSize.height > 0 else { return }
        let currentFrame = window.frame
        window.setFrame(
            NSRect(origin: currentFrame.origin, size: newSize),
            display: false
        )
        if windowPosition == .default {
            window.center()
        } else if windowPosition != .mousePos {
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
        resizeWindowToFit()
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
            appState.depth = 0
            appState.typed = ""
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

        NotificationCenter.default.addObserver(forName: .appHotkeyAdded, object: nil, queue: .main) {
            [weak self] note in
            guard let self, let bundleURL = note.object as? String else { return }
            self.registerAppLaunchHotkey(bundleURL: bundleURL)
        }

        registerAppLaunchHotkeys()

        KeyboardShortcuts.onKeyDown(for: .hideMode) { [weak self] in
            self?.toggleMode(.hide)
        }
        KeyboardShortcuts.onKeyDown(for: .quitMode) { [weak self] in
            self?.toggleMode(.quit)
        }
        KeyboardShortcuts.onKeyDown(for: .normalMode) { [weak self] in
            self?.toggleMode(.normal)
        }

        registerModeHotkeys()

        NotificationCenter.default.addObserver(
            forName: .customModesChanged, object: nil, queue: .main
        ) { [weak self] _ in
            self?.registerModeHotkeys()
        }

        window.publisher(for: \.isVisible)
            .removeDuplicates()
            .sink { isVisible in
                if isVisible {
                    KeyboardShortcuts.enable([.hideMode, .quitMode, .normalMode])
                } else {
                    KeyboardShortcuts.disable([.hideMode, .quitMode, .normalMode])
                }
            }
            .store(in: &cancellables)

        setupTapCacheRefresh()
        setupEventTap()
        setupAutoSelect()
        NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) {
            [weak self] _ in
            guard let self = self else { return }
            if self.window.isVisible {
                self.closeWindow()
            }
        }
    }

    /// Keeps the event tap's snapshots current, on the main thread, so the callback itself
    /// never has to enumerate apps or windows.
    func setupTapCacheRefresh() {
        refreshTapCaches()

        NotificationCenter.default.addObserver(
            forName: .switcherWillShow, object: nil, queue: .main
        ) { [weak self] _ in
            self?.refreshTapCaches()
        }

        // Contents change without a fresh show when a mode is toggled or the user drills
        // into an app's windows.
        //
        // `receive(on:)` is load-bearing, not tidiness: @Published fires from willSet, so a
        // synchronous sink would recompute the caches from the *previous* value. Hopping to
        // the next runloop pass means refreshTapCaches() sees the new one.
        appState.$activeModeID
            .removeDuplicates()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.refreshTapCaches() }
            .store(in: &cancellables)

        appState.$drillDownApp
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.refreshTapCaches() }
            .store(in: &cancellables)

        // Apps launching or quitting while the overlay is open. Only worth recomputing while
        // it is on screen — the tap consults the caches only then, and .switcherWillShow
        // refreshes them on the way in.
        let workspaceCenter = NSWorkspace.shared.notificationCenter
        let didTerminate = workspaceCenter.publisher(
            for: NSWorkspace.didTerminateApplicationNotification
        )
        workspaceCenter.publisher(for: NSWorkspace.didLaunchApplicationNotification)
            .merge(with: didTerminate)
            .debounce(for: .milliseconds(300), scheduler: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self, self.window.isVisible else { return }
                self.refreshTapCaches()
            }
            .store(in: &cancellables)
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
                    let filteredApps = self.currentEntries().filter {
                        $0.appName.lowercased().starts(with: typed.lowercased())
                    }
                    if filteredApps.count == 1 {
                        self.selectCurrentApp(named: filteredApps[0].appName.lowercased())
                    }
                }
            }
            .store(in: &cancellables)
    }

    func setupEventTap() {
        if let existing = eventTap, CGEvent.tapIsEnabled(tap: existing) {
            return
        }

        guard AXIsProcessTrusted() else {
            if permissionCheckTimer == nil {
                print("Accessibility permission not granted — hotkeys are inactive, polling for it")
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
                    // The system disables the tap if a callback overruns its timeout, or
                    // when a secure input session takes over. Nothing re-arms it for us,
                    // so without this every hotkey stops working until the app restarts.
                    if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
                        delegate.reenableEventTap(reason: type)
                        return nil
                    }
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

    /// Re-arms the tap after macOS disabled it.
    ///
    /// While the tap was off we missed key events, so any modifier we believe is still
    /// held may in fact have been released — clear the tracked state rather than let a
    /// phantom modifier suppress or spuriously fire the hotkey.
    func reenableEventTap(reason: CGEventType) {
        guard let tap = eventTap else { return }
        let cause = reason == .tapDisabledByTimeout ? "timeout" : "user input"
        print("Event tap disabled by \(cause), re-enabling")
        heldModifierKeyCodes.removeAll()
        allModifiersHeldPreviously = false
        CGEvent.tapEnable(tap: tap, enable: true)
    }

    private func typedCharacter(from event: CGEvent) -> String? {
        var chars = [UniChar](repeating: 0, count: 4)
        var length = 0
        event.keyboardGetUnicodeString(
            maxStringLength: chars.count,
            actualStringLength: &length,
            unicodeString: &chars
        )
        guard length > 0 else { return nil }
        let s = String(utf16CodeUnits: chars, count: length)
        guard s.count == 1, let c = s.first, c.isLetter || c.isNumber || c == " " else { return nil }
        return String(c).lowercased()
    }

    func handleEvent(proxy _: CGEventTapProxy, type: CGEventType, event: CGEvent) -> Unmanaged<
        CGEvent
    >? {
        let flags = event.flags
        let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
        let savedKeycode = UserDefaults.standard.integer(forKey: "hotkey_keycode")

        if type == .flagsChanged {
            if let flag = flagForKeyCode[keyCode] {
                if !flags.contains(flag) {
                    // Last key of this family went up.
                    heldModifierKeyCodes.remove(keyCode)
                } else if heldModifierKeyCodes.contains(keyCode) {
                    // The family flag is still set because the *other* side is down, but
                    // this key was already tracked, so this event is its release. Without
                    // this, holding both shifts and releasing one left it stuck as held.
                    heldModifierKeyCodes.remove(keyCode)
                } else {
                    heldModifierKeyCodes.insert(keyCode)
                }
            }
            // Self-heal: drop anything whose family flag is no longer set at all. Key-ups
            // missed while the tap was disabled, or swallowed by a system shortcut, would
            // otherwise leave a modifier stuck as held for the rest of the session.
            heldModifierKeyCodes = heldModifierKeyCodes.filter { code in
                guard let flag = flagForKeyCode[code] else { return false }
                return flags.contains(flag)
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
                } else if !self.appState.typed.isEmpty {
                    self.appState.typed = ""
                } else if self.appState.activeModeID != nil {
                    // Step back to the normal switcher before closing.
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.65)) {
                        self.appState.activeModeID = nil
                    }
                    self.resizeWindowToFit(force: true)
                } else {
                    self.closeWindow()
                }
            }
            return nil
        }
        // Both branches touch AppKit, which must not happen on the tap's thread.
        if window.isVisible, flags.contains(.maskCommand), keyCode == 43 {
            DispatchQueue.main.async {
                self.closeWindow()
                NotificationCenter.default.post(name: .openSettingsRequested, object: nil)
            }
            return nil
        } else if window.isVisible, flags.contains(.maskCommand), keyCode == 12 {
            DispatchQueue.main.async {
                NSApp.terminate(nil)
            }
            return nil
        }

        if savedKeycode == 256, type == .flagsChanged {
            let config = parseModifierConfig()
            let allHeld = modifiersSatisfied(config: config)
            if allHeld, !allModifiersHeldPreviously {
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
            // Backspace: remove the last typed character so a typo doesn't force
            // Escape + full retype.
            if keyCode == 51, !appState.typed.isEmpty {
                DispatchQueue.main.async {
                    let removed = self.appState.typed.removeLast()
                    self.appState.depth = max(0, self.appState.depth - String(removed).count)
                }
                return nil
            }
            if let letter = typedCharacter(from: event) {
                let raw = String(letter)
                let pickerChar: String
                if proState.isPro {
                    let overrides = UserDefaults.standard.keyOverrides
                    pickerChar = overrides[raw] ?? raw
                } else {
                    pickerChar = raw
                }
                let candidate = appState.typed + pickerChar
                let candidateLower = candidate.lowercased()

                if appState.drillDownApp != nil {
                    // Window-picking mode: match against window titles for this app
                    let allWindows = tapDrillWindows()
                    let matchingWindows = allWindows.filter {
                        $0.title.lowercased().hasPrefix(candidateLower)
                    }
                    if matchingWindows.isEmpty {
                        return nil
                    }
                    if matchingWindows.count == 1 {
                        let theme = ModeTheme.theme(for: appState.mode)
                        DispatchQueue.main.async {
                            theme.windowAction(matchingWindows[0])
                            self.appState.depth = 0
                            self.appState.typed = ""
                            if self.appState.mode == .normal {
                                self.closeWindow()
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

                // App-picking mode: match against app names (unchanged)
                let matchingNames = tapAppNames().filter { app in
                    app.hasPrefix(candidateLower)
                }
                if matchingNames.isEmpty {
                    return nil
                }
                if matchingNames.count == 1 {
                    let name = matchingNames[0]
                    DispatchQueue.main.async {
                        self.selectCurrentApp(named: name)
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
