import AppKit
import Foundation
import KeyboardShortcuts

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

    static func customMode(_ id: String) -> Self {
        .init("customMode_\(id)")
    }
}

extension Notification.Name {
    static let appHotkeyAdded = Notification.Name("appHotkeyAdded")
    static let onboardingCompleted = Notification.Name("onboardingCompleted")
    static let switcherWillShow = Notification.Name("sxitch.switcherWillShow")
    static let openSettingsRequested = Notification.Name("sxitch.openSettingsRequested")
    static let appSettingsChanged = Notification.Name("appSettingsChanged")
    static let customModesChanged = Notification.Name("sxitch.customModesChanged")
    static let appRenamesChanged = Notification.Name("sxitch.appRenamesChanged")
    static let onboardingRestarted = Notification.Name("sxitch.onboardingRestarted")
    static let onboardingSummonPressed = Notification.Name("sxitch.onboardingSummonPressed")
    static let onboardingShowSwitcher = Notification.Name("sxitch.onboardingShowSwitcher")
    static let onboardingHideSwitcher = Notification.Name("sxitch.onboardingHideSwitcher")
}
