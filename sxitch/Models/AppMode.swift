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

    var tintColor: Color {
        switch self {
        case .normal: return .primary
        case .quit: return .red
        case .hide: return Color(red: 1.0, green: 0.75, blue: 0.0)  // amber (#FFBF00)
        }
    }
}
