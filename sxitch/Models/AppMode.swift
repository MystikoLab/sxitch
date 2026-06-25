import SwiftUI

enum AppMode: String, CaseIterable {
    case normal
    case quit
    case hide

    var displayName: String {
        switch self {
        case .normal: return "Normal"
        case .quit: return "Quit Mode"
        case .hide: return "Hide Mode"
        }
    }

    /// Fallback colour used where no theme is available (e.g. Keychain prompt dialogs).
    var tintColor: Color {
        switch self {
        case .normal: return .primary
        case .quit: return .red
        case .hide: return Color(red: 1.0, green: 0.75, blue: 0.0)
        }
    }

    /// Theme-aware colour.
    /// - normal → `theme.primary`  (used for selection highlights)
    /// - quit   → `theme.danger`
    /// - hide   → `theme.warning`
    func color(for theme: AppTheme) -> Color {
        switch self {
        case .normal: return theme.primary
        case .quit: return theme.danger
        case .hide: return theme.warning
        }
    }
}
