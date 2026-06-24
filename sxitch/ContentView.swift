//
//  ContentView.swift
//  sxitch
//
//  Created by Umang on 22/6/26.
//

import SwiftUI
import Combine

struct RunningApp: Identifiable {
    var id: Int32 { app.processIdentifier }
    var appName: String
    var app: NSRunningApplication
    var icon: NSImage
    var bundleUrl: URL?
}

class AppState: ObservableObject {
    @Published var typed: String = ""
    @Published var depth: Int = 0
}

struct ContentView: View {
    @State private var openApps: [RunningApp] = ContentView.fetchRunningApps()
    
    @State private var accessibilityGranted: Bool = AXIsProcessTrusted()
    @ObservedObject var appState: AppState
    
    var body: some View {
        HStack {
            ForEach(openApps) { app in
                if app.appName.lowercased().starts(with: "\(appState.typed.lowercased())") {
                    VStack {
                        Image(nsImage: app.icon)
                            .resizable()
                            .frame(width: 60, height: 60)
                        Text(app.appName)
                            .opacity(0.7)
                    }
                    .padding(20)
                    .onTapGesture {
                        if let bundleUrl = app.bundleUrl {
                            NSWorkspace.shared.open(bundleUrl)
                        }
                    }
                }
                
            }
        }
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 30))
        .frame(maxWidth: .infinity,alignment: .center)
        .onReceive(NSWorkspace.shared.notificationCenter.publisher(for: NSWorkspace.didLaunchApplicationNotification)) { note in
            openApps = ContentView.fetchRunningApps()
        }
        .onReceive(NSWorkspace.shared.notificationCenter.publisher(for: NSWorkspace.didTerminateApplicationNotification)) { _ in
            openApps = ContentView.fetchRunningApps()
        }
    }
    
    static func fetchRunningApps() -> [RunningApp] {
        return NSWorkspace.shared.runningApplications
            .filter { $0.activationPolicy == .regular  }
            .map { app in
                RunningApp(
                    appName: app.localizedName ?? "Unknown",
                    app: app,
                    icon: app.icon ?? NSImage(),
                    bundleUrl: app.bundleURL
                )
            }
            .sorted{ $0.appName < $1.appName }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    var appState = AppState()
    var window: NSWindow!
    var eventTap: CFMachPort?
    private var permissionCheckTimer: Timer?
    let keyCodeToChar: [Int64: Character] = [
        0:"a",  11:"b", 8:"c",  2:"d",  14:"e", 3:"f",  5:"g",
        4:"h",  34:"i", 38:"j", 40:"k", 37:"l", 46:"m", 45:"n",
        31:"o", 35:"p", 12:"q", 15:"r", 1:"s",  17:"t", 32:"u",
        9:"v",  13:"w", 7:"x",  16:"y", 6:"z"
    ]
    
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
        
        let contentView = NSHostingView(rootView: ContentView(appState: appState))
        contentView.translatesAutoresizingMaskIntoConstraints = false
        window.contentView = contentView
        
        window.hasShadow = true
        window.contentView?.wantsLayer = true
        window.contentView?.layer?.cornerRadius = 30
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
        
        setupEventTap()
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
        
        // Modifier-only hotkey: trigger on the modifier key being pressed alone
        if savedKeycode == 256 && type == .flagsChanged {
            let isOptionPress = savedModifier == 0 && keyCode == 58 // left ⌥
            || savedModifier == 0 && keyCode == 61              // right ⌥
            let isCommandPress = savedModifier == 1 && keyCode == 55 // left ⌘
            || savedModifier == 1 && keyCode == 54              // right ⌘
            
            if isOptionPress || isCommandPress {
                // Only trigger on key-down (flags being set), not release
                let modifierActive = savedModifier == 0
                ? flags.contains(.maskAlternate)
                : flags.contains(.maskCommand)
                
                if modifierActive {
                    DispatchQueue.main.async {
                        if self.window.isVisible {
                            self.window.orderOut(nil)
                        } else {
                            self.window.orderFrontRegardless()
                        }
                    }
                    return nil
                }
            }
            return Unmanaged.passUnretained(event)
        }
        
        if window.isVisible && flags == CGEventFlags(rawValue: 256) {
            if let letter = keyCodeToChar[keyCode] {
                let candidate = self.appState.typed + "\(letter)"
                let filteredApps = ContentView.fetchRunningApps().filter { app in
                    app.appName.lowercased().starts(with: candidate.lowercased())
                }
                if filteredApps.count == 1, let bundleUrl = filteredApps[0].bundleUrl {
                    DispatchQueue.main.async {
                        self.appState.typed = ""
                        NSWorkspace.shared.open(bundleUrl)
                    }
                } else {
                    DispatchQueue.main.async {
                        self.appState.typed = candidate
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
            let modifierMatch = savedModifier == 0
            ? flags.contains(.maskAlternate)
            : flags.contains(.maskCommand)
            
            if savedKeycode != 256 && modifierMatch && keyCode == Int64(savedKeycode) {
                DispatchQueue.main.async {
                    if self.window.isVisible {
                        self.window.orderOut(nil)
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
            window.orderOut(nil)
        }
    }
}

