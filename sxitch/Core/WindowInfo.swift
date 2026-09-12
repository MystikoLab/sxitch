import AppKit
import ApplicationServices

struct WindowInfo: Identifiable {
    let id: Int
    let title: String
    let axElement: AXUIElement
    let ownerApp: NSRunningApplication

    func performAction(_ action: AppMode) {
        switch action {
        case .normal:
            AXUIElementPerformAction(axElement, kAXRaiseAction as CFString)
            ownerApp.activate(options: [])

        case .hide:
            AXUIElementSetAttributeValue(
                axElement, kAXMinimizedAttribute as CFString, true as CFTypeRef
            )

        case .quit:
            var pid: pid_t = 0
            AXUIElementGetPid(axElement, &pid)
            if pid != 0 {
                NSRunningApplication(processIdentifier: pid)?.terminate()
            }
        }
    }
}

func fetchWindowsForApp(_ nsApp: NSRunningApplication) -> [WindowInfo] {
    let axApp = AXUIElementCreateApplication(nsApp.processIdentifier)
    var windowsRef: CFTypeRef?
    guard
        AXUIElementCopyAttributeValue(axApp, kAXWindowsAttribute as CFString, &windowsRef)
        == .success,
        let axWindows = windowsRef as? [AXUIElement]
    else { return [] }

    let rawWindows: [WindowInfo] = axWindows.enumerated().compactMap { index, axWindow in
        var titleRef: CFTypeRef?
        guard
            AXUIElementCopyAttributeValue(axWindow, kAXTitleAttribute as CFString, &titleRef)
            == .success,
            let title = titleRef as? String,
            !title.isEmpty
        else { return nil }
        return WindowInfo(id: index, title: title, axElement: axWindow, ownerApp: nsApp)
    }

    var nameCounts: [String: Int] = [:]
    for window in rawWindows {
        nameCounts[window.title.lowercased(), default: 0] += 1
    }

    var nameCounters: [String: Int] = [:]
    return rawWindows.map { window -> WindowInfo in
        let key = window.title.lowercased()
        var title = window.title
        if nameCounts[key]! > 1 {
            let index = nameCounters[key, default: 0]
            nameCounters[key] = index + 1
            title = "\(letterForIndex(index)) - \(window.title)"
        }
        return WindowInfo(id: window.id, title: title, axElement: window.axElement, ownerApp: window.ownerApp)
    }
}

func letterForIndex(_ index: Int) -> String {
    var result = ""
    var n = index
    repeat {
        let letter = Character(UnicodeScalar(65 + (n % 26))!)
        result = String(letter) + result
        n = n / 26 - 1
    } while n >= 0
    return result
}
