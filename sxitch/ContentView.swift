//
//  ContentView.swift
//  sxitch
//
//  Created by Umang on 22/6/26.
//

import SwiftUI
import Combine
import KeyboardShortcuts

enum AppMode {
    case hide
    case quit
    case normal
}


class AppState: ObservableObject {
    @Published var typed: String = ""
    @Published var depth: Int = 0
    @Published var mode: AppMode = .normal
}

typealias AppHotkeys = [String: String]  // "keycode:modifier" → bundleIdentifier

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
    
    @ObservedObject var appState: AppState
    
    var appDelegate: AppDelegate
    
    var body: some View {
        HStack {
            ForEach(openApps, id: \.id) { app in
                if app.appName.lowercased().starts(with: appState.typed.lowercased()) {
                    appView(app)
                }
            }
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: appState.typed)
        .animation(.spring(response: 0.25, dampingFraction: 0.65), value: appState.mode)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 30))
        .frame(maxWidth: .infinity,alignment: .center)
        .onReceive(NSWorkspace.shared.notificationCenter.publisher(for: NSWorkspace.didLaunchApplicationNotification)) { note in
            withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                openApps = RunningApp.fetchRunningApps()
            }
        }
        .onReceive(NSWorkspace.shared.notificationCenter.publisher(for: NSWorkspace.didTerminateApplicationNotification)) { _ in
            withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                openApps = RunningApp.fetchRunningApps()
            }
        }
        .onKeyPress(.escape) {
            if !self.appState.typed.isEmpty {
                self.appState.typed = ""
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
        }.task {
            if !userState.shared.isPro {
                await userState.shared.checkCurrentActivationStatus()
            }
        }
    }
    
    func appView(_ app: RunningApp) -> some View {
        var modifiedApp = app
        modifiedApp.depth = appState.typed.count
        modifiedApp.appMode = appState.mode
        return modifiedApp
            .transition(.asymmetric(
                insertion: .scale(scale: 0.85).combined(with: .opacity),
                removal: .scale(scale: 0.85).combined(with: .opacity)
            ))
    }
    
    
}

class AppDelegate: NSObject, NSApplicationDelegate {
    @Environment(\.openSettings) private var openSettings
    var appState = AppState()
    var window: NSWindow!
    var eventTap: CFMachPort?
    private var permissionCheckTimer: Timer?
    var lastModifierKeyCode: Int64 = 0
    let keyCodeToChar: [Int64: Character] = [
        0:"a",  11:"b", 8:"c",  2:"d",  14:"e", 3:"f",  5:"g",
        4:"h",  34:"i", 38:"j", 40:"k", 37:"l", 46:"m", 45:"n",
        31:"o", 35:"p", 12:"q", 15:"r", 1:"s",  17:"t", 32:"u",
        9:"v",  13:"w", 7:"x",  16:"y", 6:"z"
    ]
    
    var proState = userState.shared
    
    let flagForKeyCode: [Int64: CGEventFlags] = [
        58: .maskAlternate,    // left ⌥
        61: .maskAlternate,    // right ⌥
        55: .maskCommand,      // left ⌘
        54: .maskCommand,      // right ⌘
        56: .maskShift,        // left ⇧
        60: .maskShift,        // right ⇧
        59: .maskControl,      // left ⌃
        62: .maskControl,      // right ⌃
        57: .maskAlphaShift,   // caps lock
    ]

    let altKeyCodes: Set<Int64> = [58, 61]
    let cmdKeyCodes: Set<Int64> = [55, 54]
    let shiftKeyCodes: Set<Int64> = [56, 60]
    let ctrlKeyCodes: Set<Int64> = [59, 62]
    
    func applicationWillFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
    }
    
    func closeWindow() {
        appState.typed = ""
        appState.depth = 0
        appState.mode = .normal
        window.orderOut(nil)
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
        //window.level = NSWindow.level(window.level.rawValue + 100)
        window.level = NSWindow.Level(NSWindow.Level.floating.rawValue + 200)
        window.isMovableByWindowBackground = true
        window.collectionBehavior = [.canJoinAllSpaces, .stationary]
        
        let contentView = NSHostingView(rootView: ContentView(appState: appState, appDelegate: self))
        contentView.translatesAutoresizingMaskIntoConstraints = false
        window.contentView = contentView
        
        window.hasShadow = true
        window.contentView?.wantsLayer = true
        window.contentView?.layer?.cornerRadius = 10
        window.contentView?.layer?.masksToBounds = true
        
        window.setContentSize(contentView.fittingSize)
        window.center()
        window.makeKeyAndOrderFront(nil)
        
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
        NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
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
            // Prompt the user once
            let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true] as CFDictionary
            AXIsProcessTrustedWithOptions(options)
            
            // Start polling if not already doing so
            if permissionCheckTimer == nil {
                permissionCheckTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
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
        
        let mask: CGEventMask = (1 << CGEventType.keyDown.rawValue) | (1 << CGEventType.flagsChanged.rawValue)
        
        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: { proxy, type, event, userInfo in
                let delegate = Unmanaged<AppDelegate>.fromOpaque(userInfo!).takeUnretainedValue()
                return delegate.handleEvent(proxy: proxy, type: type, event: event)
            },
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else {
            print("Failed to create event tap")
            return
        }
        
        eventTap = tap
        let runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), runLoopSource, .commonModes)  // ← .getMain() not .getCurrent()
        CGEvent.tapEnable(tap: tap, enable: true)
        print("Event tap created successfully")
    }
    
    func handleEvent(proxy: CGEventTapProxy, type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        let flags = event.flags
        let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
        let savedModifier = UserDefaults.standard.integer(forKey: "hotkey_modifier")
        let savedKeycode = UserDefaults.standard.integer(forKey: "hotkey_keycode")
        let hotkeySided = UserDefaults.standard.bool(forKey: "hotkey_sided")
        
        if type == .flagsChanged {
            lastModifierKeyCode = keyCode
        }
        
        if keyCode == 53 && self.window.isVisible {
            if self.appState.typed == "" {
                self.closeWindow()
            } else {
                self.appState.typed = ""
            }
            return nil
        }
        // open settings panel
        if self.window.isVisible && flags.contains(.maskCommand) && keyCode == 43  {
            self.closeWindow()
            openSettings()
            return nil
        }
        
        if self.window.isVisible && flags.contains(.maskControl) && proState.isPro {
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
                if altKeyCodes.contains(k)   { return altKeyCodes.contains(keyCode) }
                if cmdKeyCodes.contains(k)   { return cmdKeyCodes.contains(keyCode) }
                if shiftKeyCodes.contains(k) { return shiftKeyCodes.contains(keyCode) }
                if ctrlKeyCodes.contains(k)  { return ctrlKeyCodes.contains(keyCode) }
                if k == 57                   { return keyCode == 57 }  // caps lock
                if k == 63                   { return keyCode == 63 }  // fn
                return false
            }
        }()

        if savedKeycode == 256, matchesModifier,
           let flag = flagForKeyCode[keyCode],
           flags.contains(flag) {
            DispatchQueue.main.async {
                if self.window.isVisible {
                    self.closeWindow()
                } else {
                    self.window.orderFrontRegardless()
                }
            }
            return nil
        }
        
        if window.isVisible && flags == CGEventFlags(rawValue: 256) {
            if let letter = keyCodeToChar[keyCode] {
                let candidate = self.appState.typed + "\(letter)"
                let filteredApps = RunningApp.fetchRunningApps().filter { app in
                    app.appName.lowercased().starts(with: candidate.lowercased())
                }
                if filteredApps.count == 1 {
                    DispatchQueue.main.async {
                        filteredApps[0].performAction(action: self.appState.mode)
                    }
                    if self.appState.mode == .normal {
                        closeWindow()
                    }
                    appState.depth = 0
                    appState.typed = ""
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
                    if altKeyCodes.contains(k)   { return flags.contains(.maskAlternate) }
                    if cmdKeyCodes.contains(k)   { return flags.contains(.maskCommand) }
                    if shiftKeyCodes.contains(k) { return flags.contains(.maskShift) }
                    if ctrlKeyCodes.contains(k)  { return flags.contains(.maskControl) }
                    if k == 57                   { return flags.contains(.maskAlphaShift) }
                    if k == 63                   { return lastModifierKeyCode == 63 }
                    return false
                }
            }()
            
            if savedKeycode != 256 && modifierMatch && keyCode == Int64(savedKeycode) {
                DispatchQueue.main.async {
                    if self.window.isVisible {
                        self.closeWindow()
                    } else {
                        self.window.orderFrontRegardless()
                    }
                }
                return nil
            }
        }
        
        return Unmanaged.passUnretained(event)
    }
    
    
    @objc func activeAppChanged() {
        if NSWorkspace.shared.frontmostApplication?.bundleIdentifier != Bundle.main.bundleIdentifier {
            self.closeWindow()
        }
    }
}

