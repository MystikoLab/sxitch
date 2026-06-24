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
        case .hide: return .yellow
        }
    }
}
