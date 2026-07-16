//
//  ContentView.swift
//  sxitch
//
//  Created by Umang on 22/6/26.
//

import Combine
import KeyboardShortcuts
import SwiftUI

enum AppMode {
    case hide
    case quit
    case normal
}

class AppState: ObservableObject {
    @Published var typed: String = ""
    @Published var depth: Int = 0
    @Published var mode: AppMode = .normal
    @Published var drillDownApp: NSRunningApplication? = nil
}

typealias AppHotkeys = [String: String] // "keycode:modifier" → bundleIdentifier

extension UserDefaults {
    var appHotkeys: AppHotkeys {
        get { (dictionary(forKey: "app_hotkeys") as? AppHotkeys) ?? [:] }
        set { set(newValue, forKey: "app_hotkeys") }
    }

    var keyOverrides: [String: String] {
        get { (dictionary(forKey: "key_overrides") as? [String: String]) ?? [:] }
        set { set(newValue, forKey: "key_overrides") }
    }

    var iconMapping: [String: String] {
        get { (dictionary(forKey: "icon_mapping") as? [String: String]) ?? [:] }
        set { set(newValue, forKey: "icon_mapping") }
    }
}

struct ArcSegment: Shape {
    let innerRadius: CGFloat
    let outerRadius: CGFloat
    let startAngle: Angle
    let endAngle: Angle

    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        var path = Path()
        path.addArc(center: center, radius: outerRadius, startAngle: startAngle, endAngle: endAngle, clockwise: false)
        path.addArc(center: center, radius: innerRadius, startAngle: endAngle, endAngle: startAngle, clockwise: true)
        path.closeSubpath()
        return path
    }
}

struct ContentView: View {
    @State private var openApps: [RunningApp] = RunningApp.fetchRunningApps()
    @State private var accessibilityGranted: Bool = AXIsProcessTrusted()

    @Environment(\.openSettings) private var openSettings
    @Environment(\.scenePhase) private var scenePhase

    @AppStorage("appBlacklists") var blacklist: [String] = []
    @AppStorage("prefixStrips") var prefixStrip: [String] = ["microsoft", "adobe"]
    @AppStorage("layoutStyle") var layoutStyle: String = "grid"

    @ObservedObject var appState: AppState
    @State private var drillDownWindows: [WindowInfo] = []

    var appDelegate: AppDelegate

    @ViewBuilder
    private var appLayout: some View {
        if let drillApp = appState.drillDownApp {
            WindowPickerView(
                windows: drillDownWindows,
                appName: drillApp.localizedName ?? "Unknown",
                appIcon: drillApp.icon ?? NSImage(),
                typed: appState.typed,
                appMode: appState.mode
            ) {
                appDelegate.closeWindow()
            }
        } else if layoutStyle == "list" {
                VStack(spacing: 0) {
                    ForEach(openApps, id: \.id) { app in
                        listRow(app)
                    }
                }
                .padding(6)
                .id(appState.mode)
        } else if layoutStyle == "circle" {
                circleLayout
        } else {
                HStack {
                    ForEach(
                        openApps.filter {
                            $0.appName.lowercased().starts(with: appState.typed.lowercased())
                        }, id: \.id
                    ) { app in
                        appView(app)
                    }
                }
                .id(appState.mode)
                .frame(alignment: .center)
        }
    }

    @ViewBuilder
    private var circleLayout: some View {
        let filtered = openApps.filter { $0.appName.lowercased().starts(with: appState.typed.lowercased()) }
        let count = filtered.count
        let appCircleSize: CGFloat = 110
        let totalAngle: Double = count >= 4 ? (2 * .pi) : .pi
        let startAngle: Double = -.pi / 2 - totalAngle / 2

        let segments = totalAngle == 2 * .pi ? max(count, 1) : max(count - 1, 1)
        let spacing = totalAngle / Double(segments)
        let minRadius = CGFloat(appCircleSize / spacing) * 1.4
        let radius = max(minRadius, 50)

        ZStack {
            ForEach(Array(filtered.enumerated()), id: \.element.id) { index, app in
                let t = Double(index) / Double(segments)
                let angle = startAngle + t * totalAngle
                let halfSpan = spacing / 2

                ArcSegment(
                    innerRadius: radius - appCircleSize / 2,
                    outerRadius: radius + appCircleSize / 2,
                    startAngle: Angle(radians: angle - halfSpan),
                    endAngle: Angle(radians: angle + halfSpan)
                )
                .fill(.ultraThinMaterial)
            }

            ForEach(Array(filtered.enumerated()), id: \.element.id) { index, app in
                let t = Double(index) / Double(segments)
                let angle = startAngle + t * totalAngle
                let x = radius * CGFloat(cos(angle))
                let y = radius * CGFloat(sin(angle))

                appView(app)
                    .rotationEffect(.radians(angle + .pi / 2))
                    .offset(x: x, y: y)
            }
        }
        .frame(width: (radius + appCircleSize) * 2, height: (radius + appCircleSize) * 2)
        .id(appState.mode)
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
                // Skip while the window is hidden: updating @State during a constraint
                // update pass on a hidden window triggers a setNeedsUpdateConstraints
                // reentrancy crash. The list is refreshed when the window is shown instead.
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
                openApps = RunningApp.fetchRunningApps()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                    appDelegate.resizeWindowToFit()
                }
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
            }
            .onChange(of: prefixStrip) { _, _ in
                openApps = RunningApp.fetchRunningApps()
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

    @ViewBuilder
    func listRow(_ app: RunningApp) -> some View {
        if app.appName.lowercased().starts(with: appState.typed.lowercased()) {
            appListView(app)
        }
    }

    func appListView(_ app: RunningApp) -> some View {
        var modifiedApp = app
        modifiedApp.depth = appState.typed.count
        modifiedApp.appMode = appState.mode
        modifiedApp.overrideTap = { [self] tapped in handleAppTap(tapped) }
        return modifiedApp.listBody
            .transition(
                .asymmetric(
                    insertion: .move(edge: .top).combined(with: .opacity),
                    removal: .move(edge: .top).combined(with: .opacity)
                )
            )
    }

    func handleAppTap(_ app: RunningApp) {
        let windows = fetchWindowsForApp(app.app)
        let windowPickerEnabled = UserDefaults.standard.bool(forKey: "windowPickerEnabled")
        let currentMode = appState.mode // capture before closeWindow() resets it

        if windows.count > 1, userState.shared.isPro, windowPickerEnabled {
            appState.drillDownApp = app.app
        } else if windows.count == 1 {
            windows[0].performAction(currentMode)
            appDelegate.closeWindow()
        } else {
            app.performAction(action: currentMode)
            if currentMode == .normal { appDelegate.closeWindow() }
        }
    }

    func appView(_ app: RunningApp) -> some View {
        var modifiedApp = app
        modifiedApp.depth = appState.typed.count
        modifiedApp.appMode = appState.mode
        modifiedApp.overrideTap = { [self] tapped in handleAppTap(tapped) }
        return
            modifiedApp
                .transition(
                    .asymmetric(
                        insertion: .scale(scale: 0.85).combined(with: .opacity),
                        removal: .scale(scale: 0.85).combined(with: .opacity)
                    )
                )
    }
}

import SwiftUI

extension View {
    @ViewBuilder
    func modernMacBackground() -> some View {
        if #available(macOS 27.0, *) {
            background(.ultraThinMaterial)
        } else {
            // Your manual fallback for older macOS versions
            background(.regularMaterial)
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    @Environment(\.openSettings) private var openSettings
    var appState = AppState()
    var window: NSWindow!
    var eventTap: CFMachPort?
    private var suppressActiveAppCheck = false
    private var permissionCheckTimer: Timer?
    var allModifiersHeldPreviously: Bool = false
    var heldModifierKeyCodes: Set<Int64> = []
    let keyCodeToChar: [Int64: Character] = [
        0: "a", 11: "b", 8: "c", 2: "d", 14: "e", 3: "f", 5: "g",
        4: "h", 34: "i", 38: "j", 40: "k", 37: "l", 46: "m", 45: "n",
        31: "o", 35: "p", 12: "q", 15: "r", 1: "s", 17: "t", 32: "u",
        9: "v", 13: "w", 7: "x", 16: "y", 6: "z",
    ]

    var proState = userState.shared

    let flagForKeyCode: [Int64: CGEventFlags] = [
        58: .maskAlternate, // left ⌥
        61: .maskAlternate, // right ⌥
        55: .maskCommand, // left ⌘
        54: .maskCommand, // right ⌘
        56: .maskShift, // left ⇧
        60: .maskShift, // right ⇧
        59: .maskControl, // left ⌃
        62: .maskControl, // right ⌃
        57: .maskAlphaShift, // caps lock
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

    func centerWindowHorizontally() {
        let screen = window.screen ?? NSScreen.main
        let screenWidth = screen?.frame.width ?? 0
        let currentFrame = window.frame
        let newX = (screenWidth - currentFrame.width) / 2
        window.setFrameOrigin(NSPoint(x: newX, y: currentFrame.minY))
    }

    func resizeWindowToFit() {
        guard window.isVisible else { return }
        guard let hostingView = window.contentView else { return }
        hostingView.layoutSubtreeIfNeeded();
        let newSize = hostingView.fittingSize
        guard newSize.width > 0, newSize.height > 0 else { return }
        let currentFrame = window.frame
        let screen = window.screen ?? NSScreen.main
        let screenWidth = screen?.frame.width ?? 0
        let newX = (screenWidth - newSize.width) / 2
        let newY = currentFrame.maxY - newSize.height
        // display: false avoids triggering an immediate display pass (which runs
        // updateConstraints) while a state change may still be pending, preventing
        // the setNeedsUpdateConstraints reentrancy that causes NSGenericException.
        window.setFrame(
            NSRect(x: newX, y: newY, width: newSize.width, height: newSize.height),
            display: false
        )
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

        // Only show the switcher immediately if onboarding is already done
        if UserDefaults.standard.bool(forKey: "hasCompletedOnboarding") {
            window.makeKeyAndOrderFront(nil)
            self.appState.depth = 0
            self.appState.typed = ""
        }

        // Show the switcher once the onboarding window signals it's done
        NotificationCenter.default.addObserver(
            forName: .onboardingCompleted, object: nil, queue: .main
        ) { [weak self] _ in
            guard let self else { return }
            // Close any onboarding NSWindow
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
        NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) {
            [weak self] _ in
            guard let self = self else { return }
            if self.window.isVisible {
                self.closeWindow()
            }
        }
    }

    func setupEventTap() {
        if let existing = eventTap, CGEvent.tapIsEnabled(tap: existing) {
            return
        }

        guard AXIsProcessTrusted() else {
            // Start polling silently — the onboarding page handles prompting the user
            // Start polling if not already doing so
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
        CFRunLoopAddSource(CFRunLoopGetMain(), runLoopSource, .commonModes) // ← .getMain() not .getCurrent()
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
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
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
        // open settings panel
        if window.isVisible, flags.contains(.maskCommand), keyCode == 43 {
            closeWindow()
            openSettings()
            return nil
        } else if window.isVisible, flags.contains(.maskCommand), keyCode == 12 {
            NSApp.terminate(nil)
            return nil
        }

        if window.isVisible, flags.contains(.maskControl), proState.isPro {
            if keyCode == 12 {
                // `q` key
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.65)) {
                        self.appState.mode = self.appState.mode == .quit ? .normal : .quit
                    }
                }
                return nil
            } else if keyCode == 4 {
                // `h` key
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.65)) {
                        self.appState.mode = self.appState.mode == .hide ? .normal : .hide
                    }
                }
                return nil
            } else if keyCode == 45 {
                // `n` key
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
                        let activeScreen = NSScreen.screens.first { $0.frame.contains(NSEvent.mouseLocation) } ?? NSScreen.main
                        if let screenFrame = activeScreen?.frame {
                            self.window.setFrameOrigin(screenFrame.origin)
                        }
                        self.window.center()
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

                // ── Window picking mode ────────────────────────────────────
                if let drillApp = appState.drillDownApp {
                    let allWindows = fetchWindowsForApp(drillApp)
                    let matchedWindows = allWindows.filter {
                        $0.title.lowercased().starts(with: candidate.lowercased())
                    }
                    if matchedWindows.count == 1 {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                            matchedWindows[0].performAction(self.appState.mode)
                            self.closeWindow()
                        }
                        appState.depth = 0
                        appState.typed = ""
                    } else if !matchedWindows.isEmpty {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                            self.appState.typed = candidate
                            self.appState.depth += pickerChar.count
                        }
                    }
                    // if nothing matches, swallow the keystroke silently
                    return nil
                }

                // ── App picking mode ───────────────────────────────────────
                DispatchQueue.main.async {
                let filteredApps = RunningApp.fetchRunningApps().filter { app in
                    app.appName.lowercased().starts(with: candidate.lowercased())
                }
                if filteredApps.count == 1 {
                    let singleApp = filteredApps[0]
                    let windows = fetchWindowsForApp(singleApp.app)
                    let windowPickerEnabled = UserDefaults.standard.bool(
                        forKey: "windowPickerEnabled"
                    )
                    if windows.count > 1 && self.proState.isPro && windowPickerEnabled {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                            self.appState.typed = ""
                            self.appState.depth = 0
                            self.appState.drillDownApp = singleApp.app
                        }
                    } else if windows.count == 1 {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                            windows[0].performAction(self.appState.mode)
                        }
                        if self.appState.mode == .normal {
                            self.closeWindow()
                        }
                        self.appState.depth = 0
                        self.appState.typed = ""
                    } else {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                            singleApp.performAction(action: self.appState.mode)
                        }
                        if self.appState.mode == .normal {
                            self.closeWindow()
                        }
                        self.appState.depth = 0
                        self.appState.typed = ""
                    }
                } else {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                        self.appState.typed = candidate
                        self.appState.depth += pickerChar.count
                    }
                }
                }
                return nil
            }
            //                let index = Int(letter.asciiValue! - Character("a").asciiValue!)
            //                let apps = ContentView.fetchRunningApps()
            //                if index < apps.count {
            //                    let target = apps[index]
            //                    DispatchQueue.main.async {
            //                        if let bundleUrl = target.bundleUrl {
            //                            NSWorkspace.shared.open(bundleUrl)
            //                        }
            //                        self.window.orderOut(nil)
            //                    }
            //                    return nil
            //                }
        }

        if type == .keyDown, savedKeycode != 256, keyCode == Int64(savedKeycode) {
            let config = parseModifierConfig()
            if modifiersSatisfied(config: config) {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                    if self.window.isVisible {
                        self.closeWindow()
                    } else {
                        self.centerWindowHorizontally()
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
