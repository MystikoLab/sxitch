import Foundation

enum SwitcherAnimation: String, CaseIterable {
    /// The free plan's animation: a short AppKit-driven fade that matches the
    /// macOS-native window appearance.
    case fade
    /// Rise-from-below-with-a-fade.
    case slide
    /// Descend-from-above with a small settle bounce.
    case drop
    /// Grow from ~90% size, centered, with a fade.
    case scale

    var displayName: String {
        switch self {
        case .fade: "Default"
        case .slide: "Slide In"
        case .drop: "Drop In"
        case .scale: "Scale In"
        }
    }

    var isPro: Bool {
        switch self {
        case .fade: false
        case .slide, .drop, .scale: true
        }
    }

    static let userDefaultsKey = "switcherAnimationStyle"
    static let speedKey = "animationSpeedMultiplier"
    /// Master switch for the whole feature; when off, the switcher appears
    /// and closes with no animation at all.
    static let enabledKey = "openCloseAnimationsEnabled"

    /// Whether animations are enabled at all (checked live).
    static var enabled: Bool {
        UserDefaults.standard.object(forKey: enabledKey) == nil
            ? true
            : UserDefaults.standard.bool(forKey: enabledKey)
    }

    /// Resolves the stored animation, downgrading Pro styles to fade when no
    /// valid licence is present so a lapsed licence can never keep a Premium
    /// style active. Unknown stored values (pre-1.x styles that were removed,
    /// e.g. "staggered") are migrated to fade in place — otherwise the
    /// settings picker has no matching tag and renders empty, and the runtime
    /// silently falls back to fade instead of the user's real choice.
    static var current: SwitcherAnimation {
        guard !userState.shared.isPro else { return stored }
        return stored.isPro ? .fade : stored
    }

    private static var stored: SwitcherAnimation {
        if let value = UserDefaults.standard.string(forKey: userDefaultsKey),
           let style = SwitcherAnimation(rawValue: value)
        {
            return style
        }
        let fallback = SwitcherAnimation.fade
        UserDefaults.standard.set(fallback.rawValue, forKey: userDefaultsKey)
        return fallback
    }

    /// Animation speed multiplier, read live so the settings slider takes
    /// effect without any cache invalidation.
    static var speed: Double {
        let value = UserDefaults.standard.double(forKey: speedKey)
        return value == 0 ? 1 : min(max(value, 0.5), 2.0)
    }

    // MARK: - Timings (seconds, pre-speed-scaling)

    var openDuration: Double {
        switch self {
        case .fade: 0.2
        case .slide: 0.22
        case .drop: 0.28
        case .scale: 0.2
        }
    }

    /// Close plays the same motion roughly 1.5x faster so dismissing never
    /// feels like it delays the next action.
    var closeDuration: Double {
        openDuration / 1.5
    }

    /// Vertical distance the panel travels for the slide (below) and drop
    /// (above) styles.
    static let slideOffset: CGFloat = 24
    static let dropOffset: CGFloat = 18
    /// Start size fraction for the scale style.
    static let scaleStartFactor: CGFloat = 0.9
    /// Overshoot bounce depth for the drop style.
    static let dropOvershoot: CGFloat = 4
}
