import AppKit

/// The configurable haptic moments, each persisted as its own bool in
/// UserDefaults behind the shared master switch (`hapticsEnabled`).
enum HapticEvent: CaseIterable {
    case showUp
    case switchApp
    case modeSwitch
    case customModeSwitch
    case onboarding

    var defaultsKey: String {
        switch self {
        case .showUp: "hapticShowUp"
        case .switchApp: "hapticSwitchApp"
        case .modeSwitch: "hapticModeSwitch"
        case .customModeSwitch: "hapticCustomModeSwitch"
        case .onboarding: "hapticOnboarding"
        }
    }
}

/// The feedback patterns `NSHapticFeedbackManager` offers, persisted by raw
/// value. Non-generic patterns are Pro-only.
enum HapticPattern: String, CaseIterable {
    case generic
    case alignment
    case levelChange

    var feedbackPattern: NSHapticFeedbackManager.FeedbackPattern {
        switch self {
        case .generic: .generic
        case .alignment: .alignment
        case .levelChange: .levelChange
        }
    }

    var displayName: String {
        switch self {
        case .generic: "Generic"
        case .alignment: "Alignment"
        case .levelChange: "Level Change"
        }
    }

    var isPro: Bool {
        self != .generic
    }
}

/// Single entry point for every configurable haptic so the master switch,
/// per-event toggles and the chosen pattern stay consistent everywhere.
@MainActor
enum Haptics {
    static func isEnabled() -> Bool {
        UserDefaults.standard.object(forKey: "hapticsEnabled") as? Bool ?? true
    }

    static func eventEnabled(_ event: HapticEvent) -> Bool {
        UserDefaults.standard.object(forKey: event.defaultsKey) as? Bool ?? true
    }

    static var pattern: HapticPattern {
        HapticPattern(rawValue: UserDefaults.standard.string(forKey: "hapticPattern") ?? "") ?? .generic
    }

    /// Plays a haptic for an event, honouring the master switch and the
    /// per-event toggle. No-op when feedback is turned off.
    static func perform(_ event: HapticEvent) {
        guard isEnabled(), eventEnabled(event) else { return }
        perform(pattern: pattern.feedbackPattern)
    }

    /// Plays a concrete pattern directly, e.g. for settings previews.
    static func perform(pattern: NSHapticFeedbackManager.FeedbackPattern) {
        NSHapticFeedbackManager.defaultPerformer.perform(pattern, performanceTime: .now)
    }
}
