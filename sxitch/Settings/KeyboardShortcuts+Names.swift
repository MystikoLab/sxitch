import AppKit
import KeyboardShortcuts
import Foundation

extension KeyboardShortcuts.Name {
    static let hideMode = Self(
        "sxitch_hideMode",
        initial: .init(.h, modifiers: [.control])
    )
    static let quitMode = Self(
        "sxitch_quitMode",
        initial: .init(.q, modifiers: [.control])
    )

    static let normalMode = Self(
        "sxitch_normalMode",
        initial: .init(.n, modifiers: [.control])
    )

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
