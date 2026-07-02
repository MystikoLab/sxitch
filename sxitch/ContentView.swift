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
            ScrollView {
                VStack(spacing: 0) {
                    ForEach(openApps, id: \.id) { app in
                        listRow(app)
                    }
                }
                .id(appState.mode)
            }
            .frame(width: 300)
            .frame(maxHeight: 400)
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

    var body: some View {
        appLayout
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: appState.typed)
            .animation(.spring(response: 0.25, dampingFraction: 0.65), value: appState.mode)
            .modernMacBackground()
            .clipShape(RoundedRectangle(cornerRadius: 30))
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
            Divider().opacity(0.4)
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
    var lastModifierKeyCode: Int64 = 0
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

    let altKeyCodes: Set<Int64> = [58, 61]
    let cmdKeyCodes: Set<Int64> = [55, 54]
    let shiftKeyCodes: Set<Int64> = [56, 60]
    let ctrlKeyCodes: Set<Int64> = [59, 62]

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
        let savedModifier = UserDefaults.standard.integer(forKey: "hotkey_modifier")
        let savedKeycode = UserDefaults.standard.integer(forKey: "hotkey_keycode")
        let hotkeySided = UserDefaults.standard.bool(forKey: "hotkey_sided")

        if type == .flagsChanged {
            lastModifierKeyCode = keyCode
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
        // open settings panel
        if window.isVisible, flags.contains(.maskCommand), keyCode == 43 {
            closeWindow()
            openSettings()
            return nil
        }

        if window.isVisible, flags.contains(.maskControl), proState.isPro {
            if keyCode == 12 {
                // `q` key
                DispatchQueue.main.async {
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.65)) {
                        self.appState.mode = self.appState.mode == .quit ? .normal : .quit
                    }
                }
                return nil
            } else if keyCode == 4 {
                // `h` key
                DispatchQueue.main.async {
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.65)) {
                        self.appState.mode = self.appState.mode == .hide ? .normal : .hide
                    }
                }
                return nil
            } else if keyCode == 45 {
                // `n` key
                DispatchQueue.main.async {
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

        let matchesModifier: Bool = {
            if hotkeySided {
                return keyCode == savedModifier
            } else {
                let k = Int64(savedModifier)
                if altKeyCodes.contains(k) { return altKeyCodes.contains(keyCode) }
                if cmdKeyCodes.contains(k) { return cmdKeyCodes.contains(keyCode) }
                if shiftKeyCodes.contains(k) { return shiftKeyCodes.contains(keyCode) }
                if ctrlKeyCodes.contains(k) { return ctrlKeyCodes.contains(keyCode) }
                if k == 57 { return keyCode == 57 } // caps lock
                if k == 63 { return keyCode == 63 } // fn
                return false
            }
        }()

        if savedKeycode == 256, matchesModifier,
           let flag = flagForKeyCode[keyCode],
           flags.contains(flag)
        {
            DispatchQueue.main.async {
                if self.window.isVisible {
                    self.closeWindow()
                } else {
                    // 1. Grab a dummy point on the mouse's current screen
                    let activeScreen = NSScreen.screens.first { $0.frame.contains(NSEvent.mouseLocation) } ?? NSScreen.main
                    if let screenFrame = activeScreen?.frame {
                        // 2. Warp the window origin to the active screen instantly (offscreen/hidden)
                        self.window.setFrameOrigin(screenFrame.origin)
                    }

                    // 3. Let AppKit handle the centering geometry natively
                    self.window.center()

                    NotificationCenter.default.post(name: .switcherWillShow, object: nil)
                    self.window.orderFrontRegardless()
                }
            }
            return nil
        }

        if window.isVisible, flags == CGEventFlags(rawValue: 256) {
            if let letter = keyCodeToChar[keyCode] {
                let candidate = appState.typed + "\(letter)"

                // ── Window picking mode ────────────────────────────────────
                if let drillApp = appState.drillDownApp {
                    let allWindows = fetchWindowsForApp(drillApp)
                    let matchedWindows = allWindows.filter {
                        $0.title.lowercased().starts(with: candidate.lowercased())
                    }
                    if matchedWindows.count == 1 {
                        DispatchQueue.main.async {
                            matchedWindows[0].performAction(self.appState.mode)
                            self.closeWindow()
                        }
                        appState.depth = 0
                        appState.typed = ""
                    } else if !matchedWindows.isEmpty {
                        DispatchQueue.main.async {
                            self.appState.typed = candidate
                            self.appState.depth += 1
                        }
                    }
                    // if nothing matches, swallow the keystroke silently
                    return nil
                }

                // ── App picking mode ───────────────────────────────────────
                let filteredApps = RunningApp.fetchRunningApps().filter { app in
                    app.appName.lowercased().starts(with: candidate.lowercased())
                }
                if filteredApps.count == 1 {
                    let singleApp = filteredApps[0]
                    let windows = fetchWindowsForApp(singleApp.app)
                    let windowPickerEnabled = UserDefaults.standard.bool(
                        forKey: "windowPickerEnabled"
                    )
                    if windows.count > 1 && proState.isPro && windowPickerEnabled {
                        DispatchQueue.main.async {
                            self.appState.typed = ""
                            self.appState.depth = 0
                            self.appState.drillDownApp = singleApp.app
                        }
                    } else if windows.count == 1 {
                        DispatchQueue.main.async {
                            windows[0].performAction(self.appState.mode)
                        }
                        if appState.mode == .normal {
                            closeWindow()
                        }
                        appState.depth = 0
                        appState.typed = ""
                    } else {
                        DispatchQueue.main.async {
                            singleApp.performAction(action: self.appState.mode)
                        }
                        if appState.mode == .normal {
                            closeWindow()
                        }
                        appState.depth = 0
                        appState.typed = ""
                    }
                } else {
                    DispatchQueue.main.async {
                        self.appState.typed = candidate
                        self.appState.depth += 1
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

        if type == .keyDown {
            let modifierMatch: Bool = {
                let k = Int64(savedModifier)
                if hotkeySided {
                    return lastModifierKeyCode == k
                } else {
                    if altKeyCodes.contains(k) { return flags.contains(.maskAlternate) }
                    if cmdKeyCodes.contains(k) { return flags.contains(.maskCommand) }
                    if shiftKeyCodes.contains(k) { return flags.contains(.maskShift) }
                    if ctrlKeyCodes.contains(k) { return flags.contains(.maskControl) }
                    if k == 57 { return flags.contains(.maskAlphaShift) }
                    if k == 63 { return lastModifierKeyCode == 63 }
                    return false
                }
            }()

            if savedKeycode != 256, modifierMatch, keyCode == Int64(savedKeycode) {
                DispatchQueue.main.async {
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
        DispatchQueue.main.async {
            guard !self.suppressActiveAppCheck else { return }
            if NSWorkspace.shared.frontmostApplication?.bundleIdentifier
                != Bundle.main.bundleIdentifier
            {
                self.closeWindow()
            }
        }
    }
}
