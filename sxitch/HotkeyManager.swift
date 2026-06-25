import Combine
import SwiftUI

@MainActor
class HotkeyManager {
    weak var appSwitcher: AppSwitcher?
    weak var window: NSWindow?
    var eventTap: CFMachPort?
    private var permissionCheckTimer: Timer?

    private let keyCodeToChar: [Int64: Character] = [
        0: "a", 11: "b", 8: "c", 2: "d", 14: "e", 3: "f", 5: "g",
        4: "h", 34: "i", 38: "j", 40: "k", 37: "l", 46: "m", 45: "n",
        31: "o", 35: "p", 12: "q", 15: "r", 1: "s", 17: "t", 32: "u",
        9: "v", 13: "w", 7: "x", 16: "y", 6: "z",
        18: "1", 19: "2", 20: "3", 21: "4", 23: "5",
        22: "6", 26: "7", 28: "8", 25: "9", 29: "0",
    ]

    func setupEventTap() {
        if let existing = eventTap, CGEvent.tapIsEnabled(tap: existing) {
            return
        }

        guard AXIsProcessTrusted() else {
            let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true] as CFDictionary
            AXIsProcessTrustedWithOptions(options)

            if permissionCheckTimer == nil {
                permissionCheckTimer = Timer.scheduledTimer(
                    withTimeInterval: 1.0,
                    repeats: true
                ) { [weak self] _ in
                    guard let self else { return }
                    if AXIsProcessTrusted() {
                        DispatchQueue.main.async {
                            self.permissionCheckTimer?.invalidate()
                            self.permissionCheckTimer = nil
                            self.setupEventTap()
                        }
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
                    let manager = Unmanaged<HotkeyManager>.fromOpaque(userInfo!)
                        .takeUnretainedValue()
                    return manager.handleEvent(proxy: proxy, type: type, event: event)
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

    func handleEvent(proxy: CGEventTapProxy, type: CGEventType, event: CGEvent) -> Unmanaged<
        CGEvent
    >? {
        guard let appSwitcher = appSwitcher, let window = window else {
            return Unmanaged.passUnretained(event)
        }

        let flags = event.flags
        let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
        let config = AppConfig.shared

        if type == .flagsChanged {
            let savedModifier = config.hotkeyModifier
            let savedKeycode = config.hotkeyKeycode

            if savedKeycode == 256 {
                let isOptionPress = (savedModifier == 0 && (keyCode == 58 || keyCode == 61))
                let isCommandPress = (savedModifier == 1 && (keyCode == 55 || keyCode == 54))

                if isOptionPress || isCommandPress {
                    let modifierActive =
                        savedModifier == 0
                        ? flags.contains(.maskAlternate)
                        : flags.contains(.maskCommand)

                    if modifierActive {
                        DispatchQueue.main.async {
                            self.toggleWindow()
                        }
                        return nil
                    }
                }
            }
            return Unmanaged.passUnretained(event)
        }

        if type == .keyDown {
            if isModeHotkey(flags: flags, keyCode: keyCode, config: config, mode: "quit") {
                DispatchQueue.main.async {
                    appSwitcher.setMode(.quit)
                    self.showWindow()
                }
                return nil
            }

            if isModeHotkey(flags: flags, keyCode: keyCode, config: config, mode: "hide") {
                DispatchQueue.main.async {
                    appSwitcher.setMode(.hide)
                    self.showWindow()
                }
                return nil
            }

            if isModeHotkey(flags: flags, keyCode: keyCode, config: config, mode: "normal") {
                DispatchQueue.main.async {
                    appSwitcher.setMode(.normal)
                    self.showWindow()
                }
                return nil
            }

            if isSummonHotkey(flags: flags, keyCode: keyCode, config: config) {
                DispatchQueue.main.async {
                    self.toggleWindow()
                }
                return nil
            }

            if window.isVisible {
                if flags.contains(.maskCommand) && keyCode == 43 {
                    DispatchQueue.main.async {
                        self.hideWindow()
                        NSApp.activate(ignoringOtherApps: true)
                        NotificationCenter.default.post(name: .openSettings, object: nil)
                    }
                    return nil
                }

                if keyCode == 53 {
                    DispatchQueue.main.async {
                        if appSwitcher.typed.isEmpty {
                            appSwitcher.reset()
                            self.hideWindow()
                        } else {
                            appSwitcher.resetTyped()
                        }
                    }
                    return nil
                }

                if keyCode == 36 {
                    DispatchQueue.main.async {
                        appSwitcher.activateSelection()
                        self.hideWindow()
                    }
                    return nil
                }

                if flags == CGEventFlags(rawValue: 256) || flags == .maskNonCoalesced {
                    if let letter = keyCodeToChar[keyCode] {
                        DispatchQueue.main.async {
                            appSwitcher.selectByKey(letter)
                        }
                        return nil
                    }
                }

                if keyCode == 125 || keyCode == 124 {
                    DispatchQueue.main.async {
                        appSwitcher.cycleSelection(direction: 1)
                    }
                    return nil
                }

                if keyCode == 126 || keyCode == 123 {
                    DispatchQueue.main.async {
                        appSwitcher.cycleSelection(direction: -1)
                    }
                    return nil
                }

                if keyCode == 48 {
                    DispatchQueue.main.async {
                        if flags.contains(.maskShift) {
                            appSwitcher.cycleSelection(direction: -1)
                        } else {
                            appSwitcher.cycleSelection(direction: 1)
                        }
                    }
                    return nil
                }
            }
        }

        return Unmanaged.passUnretained(event)
    }

    private func isSummonHotkey(flags: CGEventFlags, keyCode: Int64, config: AppConfig) -> Bool {
        let savedModifier = config.hotkeyModifier
        let savedKeycode = config.hotkeyKeycode
        if savedKeycode == 256 { return false }
        let modifierMatch = modifierFlag(for: savedModifier).map { flags.contains($0) } ?? false
        return modifierMatch && keyCode == Int64(savedKeycode)
    }

    private func isModeHotkey(flags: CGEventFlags, keyCode: Int64, config: AppConfig, mode: String)
        -> Bool
    {
        let modifierKey: String
        let codeKey: String
        switch mode {
        case "quit":
            modifierKey = "mode_quit_modifier"
            codeKey = "mode_quit_keycode"
        case "hide":
            modifierKey = "mode_hide_modifier"
            codeKey = "mode_hide_keycode"
        case "normal":
            modifierKey = "mode_normal_modifier"
            codeKey = "mode_normal_keycode"
        default:
            return false
        }

        let savedModifier = UserDefaults.standard.integer(forKey: modifierKey)
        let savedKeycode = UserDefaults.standard.integer(forKey: codeKey)

        let modifierMatch = modifierFlag(for: savedModifier).map { flags.contains($0) } ?? false
        return modifierMatch && keyCode == Int64(savedKeycode)
    }

    private func modifierFlag(for value: Int) -> CGEventFlags? {
        switch value {
        case 0: return .maskAlternate
        case 1: return .maskCommand
        case 2: return .maskControl
        case 3: return .maskShift
        default: return nil
        }
    }

    func toggleWindow() {
        guard let window = window, let appSwitcher = appSwitcher else { return }
        if window.isVisible {
            appSwitcher.mode = .normal
            appSwitcher.reset()
            window.orderOut(nil)
        } else {
            // Mirror Rust's Message::OpenThisApp — re-validate if Pro not yet confirmed.
            LicenseManager.shared.checkStoredLicense()
            positionOnActiveScreen()
            window.orderFrontRegardless()
            window.makeKey()
        }
    }

    func showWindow() {
        guard let window = window else { return }
        LicenseManager.shared.checkStoredLicense()
        positionOnActiveScreen()
        window.orderFrontRegardless()
        window.makeKey()
    }

    func hideWindow() {
        appSwitcher?.mode = .normal
        window?.orderOut(nil)
    }

    func positionOnActiveScreen() {
        guard let window = window else { return }
        let config = AppConfig.shared
        let screen =
            NSScreen.screens.first(where: { NSMouseInRect(NSEvent.mouseLocation, $0.frame, false) })
            ?? NSScreen.main

        guard let screen = screen else {
            window.center()
            return
        }

        let sf = screen.visibleFrame
        let ws = window.frame.size
        let margin: CGFloat = 20

        let x: CGFloat
        let y: CGFloat

        switch config.position {
        case "TopLeft":
            x = sf.minX + margin
            y = sf.maxY - ws.height - margin
        case "TopCenter":
            x = sf.midX - ws.width / 2
            y = sf.maxY - ws.height - margin
        case "TopRight":
            x = sf.maxX - ws.width - margin
            y = sf.maxY - ws.height - margin
        case "MiddleLeft":
            x = sf.minX + margin
            y = sf.midY - ws.height / 2
        case "MiddleCenter":
            x = sf.midX - ws.width / 2
            y = sf.midY - ws.height / 2
        case "MiddleRight":
            x = sf.maxX - ws.width - margin
            y = sf.midY - ws.height / 2
        case "BottomLeft":
            x = sf.minX + margin
            y = sf.minY + margin
        case "BottomCenter":
            x = sf.midX - ws.width / 2
            y = sf.minY + margin
        case "BottomRight":
            x = sf.maxX - ws.width - margin
            y = sf.minY + margin
        default:  // "Default" — above vertical center
            x = sf.midX - ws.width / 2
            y = sf.midY + ws.height / 2 + 100
        }

        window.setFrameOrigin(NSPoint(x: x, y: y))
    }
}
