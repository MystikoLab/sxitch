import KeyboardShortcuts
import Foundation

extension KeyboardShortcuts.Name {
    static func appLaunch(_ bundleURL: String) -> Self {
        .init("appLaunch_\(bundleURL)")
    }
}

extension Notification.Name {
    static let appHotkeyAdded = Notification.Name("appHotkeyAdded")
    static let onboardingCompleted = Notification.Name("onboardingCompleted")
    static let switcherWillShow = Notification.Name("sxitch.switcherWillShow")
    static let openSettingsRequested = Notification.Name("sxitch.openSettingsRequested")
}
