import ApplicationServices
import AppKit

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

    return axWindows.enumerated().compactMap { index, axWindow in
        var titleRef: CFTypeRef?
        guard
            AXUIElementCopyAttributeValue(axWindow, kAXTitleAttribute as CFString, &titleRef)
            == .success,
            let title = titleRef as? String,
            !title.isEmpty
        else { return nil }
        return WindowInfo(id: index, title: title, axElement: axWindow, ownerApp: nsApp)
    }
}
