import SwiftUI

struct ModeTheme {
    let overlayColor: Color
    let foregroundStyle: Color
    let appAction: (any SwitchableApp) -> Void
    let windowAction: (WindowInfo) -> Void

    static let normal = ModeTheme(
        overlayColor: .clear,
        foregroundStyle: .primary,
        appAction: { app in
            SwitchAlertController.shared.show(.opening, appName: app.appName)
            app.activate()
        },
        windowAction: { window in
            SwitchAlertController.shared.show(.opening, appName: window.ownerApp.localizedName ?? "App")
            AXUIElementPerformAction(window.axElement, kAXRaiseAction as CFString)
            window.ownerApp.activate(options: [])
        }
    )

    static let hide = ModeTheme(
        overlayColor: .orange.opacity(0.7),
        foregroundStyle: Color.orange.opacity(0.8),
        appAction: { app in
            SwitchAlertController.shared.show(.hiding, appName: app.appName)
            app.hideApp()
        },
        windowAction: { window in
            SwitchAlertController.shared.show(.hiding, appName: window.ownerApp.localizedName ?? "App")
            AXUIElementSetAttributeValue(
                window.axElement, kAXMinimizedAttribute as CFString, true as CFTypeRef
            )
        }
    )

    static let quit = ModeTheme(
        overlayColor: .red.opacity(0.7),
        foregroundStyle: Color.red.opacity(0.8),
        appAction: { app in
            SwitchAlertController.shared.show(.quitting, appName: app.appName)
            app.quitApp()
        },
        windowAction: { window in
            SwitchAlertController.shared.show(.quitting, appName: window.ownerApp.localizedName ?? "App")
            var pid: pid_t = 0
            AXUIElementGetPid(window.axElement, &pid)
            if pid != 0 {
                NSRunningApplication(processIdentifier: pid)?.terminate()
            }
        }
    )

    static func theme(for mode: AppMode) -> ModeTheme {
        switch mode {
        case .normal: return .normal
        case .hide: return .hide
        case .quit: return .quit
        }
    }
}

struct ModeThemeKey: EnvironmentKey {
    static let defaultValue: ModeTheme = .normal
}

extension EnvironmentValues {
    var modeTheme: ModeTheme {
        get { self[ModeThemeKey.self] }
        set { self[ModeThemeKey.self] = newValue }
    }
}
