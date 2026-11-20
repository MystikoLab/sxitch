import AppKit
import SwiftUI

/// The modifier held to queue several apps; released, the queue runs. Raw
/// values are the modifier families used by `hotkey_modifier_config`.
enum MultiOpenModifier: Int, CaseIterable {
    case option = 0
    case shift = 2
    case control = 3

    var displayName: String {
        switch self {
        case .option: "Option (⌥)"
        case .shift: "Shift (⇧)"
        case .control: "Control (⌃)"
        }
    }

    var cgFlag: CGEventFlags {
        switch self {
        case .option: .maskAlternate
        case .shift: .maskShift
        case .control: .maskControl
        }
    }

    var nsFlag: NSEvent.ModifierFlags {
        switch self {
        case .option: .option
        case .shift: .shift
        case .control: .control
        }
    }
}

/// Which queued app ends up frontmost once the batch has run.
enum MultiOpenOrder: String, CaseIterable {
    case lastOnTop
    case firstOnTop

    var displayName: String {
        switch self {
        case .lastOnTop: "Last selected on top"
        case .firstOnTop: "First selected on top"
        }
    }
}

enum MultiOpenSettings {
    static let enabledKey = "multiOpenEnabled"
    static let modifierKey = "multiOpenModifier"
    static let orderKey = "multiOpenOrder"

    /// Gap between consecutive actions so each activation settles before the
    /// next one; firing them back to back loses the stacking order.
    static let actionDelay: TimeInterval = 0.15

    static var enabled: Bool {
        UserDefaults.standard.bool(forKey: enabledKey)
    }

    static var modifier: MultiOpenModifier {
        MultiOpenModifier(rawValue: UserDefaults.standard.integer(forKey: modifierKey)) ?? .shift
    }

    static var order: MultiOpenOrder {
        MultiOpenOrder(rawValue: UserDefaults.standard.string(forKey: orderKey) ?? "") ?? .lastOnTop
    }

    /// True when the summon hotkey uses the multi-open modifier, in which case
    /// multi-open stays inactive — holding the summon modifier must not queue.
    static func clashes(_ modifier: MultiOpenModifier, summonFamilies: [Int]) -> Bool {
        summonFamilies.contains(modifier.rawValue)
    }

    /// Families named in a `hotkey_modifier_config` string ("family:side,...").
    static func summonFamilies(from config: String) -> [Int] {
        config.split(separator: ",").compactMap { entry in
            entry.split(separator: ":").first.flatMap { Int($0) }
        }
    }
}

/// Lowercased names of the queued entries, in selection order.
struct MultiOpenQueueKey: EnvironmentKey {
    static let defaultValue: [String] = []
}

/// Offered a clicked entry; returns true when it was queued instead of acted on.
struct MultiOpenClickKey: EnvironmentKey {
    static let defaultValue: ((any SwitchableApp) -> Bool)? = nil
}

extension EnvironmentValues {
    var multiOpenQueue: [String] {
        get { self[MultiOpenQueueKey.self] }
        set { self[MultiOpenQueueKey.self] = newValue }
    }

    var multiOpenClick: ((any SwitchableApp) -> Bool)? {
        get { self[MultiOpenClickKey.self] }
        set { self[MultiOpenClickKey.self] = newValue }
    }
}
