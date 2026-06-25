import SwiftUI

// MARK: - Theme Family

enum ThemeFamily: String, Equatable {
    case light
    case dark
    case custom
}

// MARK: - AppTheme

struct AppTheme: Identifiable, Equatable {
    let id: String
    let name: String
    let family: ThemeFamily
    let background: Color
    let text: Color
    let primary: Color
    let success: Color
    let warning: Color
    let danger: Color
}

// MARK: - Built-in Themes

extension AppTheme {
    static let allBuiltIn: [AppTheme] = [

        // MARK: Light

        AppTheme(
            id: "light-default",
            name: "Default",
            family: .light,
            background: Color(white: 0.96),
            text: .black,
            primary: .blue,
            success: .green,
            warning: .orange,
            danger: .red
        ),
        AppTheme(
            id: "light-solarized",
            name: "Solarized",
            family: .light,
            background: Color(hex: "#FDF6E3"),
            text: Color(hex: "#657B83"),
            primary: Color(hex: "#268BD2"),
            success: Color(hex: "#859900"),
            warning: Color(hex: "#B58900"),
            danger: Color(hex: "#DC322F")
        ),
        AppTheme(
            id: "light-github",
            name: "GitHub",
            family: .light,
            background: Color(hex: "#FFFFFF"),
            text: Color(hex: "#24292F"),
            primary: Color(hex: "#0969DA"),
            success: Color(hex: "#1A7F37"),
            warning: Color(hex: "#9A6700"),
            danger: Color(hex: "#CF222E")
        ),
        AppTheme(
            id: "light-catppuccin-latte",
            name: "Catppuccin Latte",
            family: .light,
            background: Color(hex: "#EFF1F5"),
            text: Color(hex: "#4C4F69"),
            primary: Color(hex: "#1E66F5"),
            success: Color(hex: "#40A02B"),
            warning: Color(hex: "#DF8E1D"),
            danger: Color(hex: "#D20F39")
        ),
        AppTheme(
            id: "light-tokyo-night-light",
            name: "Tokyo Night Light",
            family: .light,
            background: Color(hex: "#D5D6DB"),
            text: Color(hex: "#343B58"),
            primary: Color(hex: "#2E7DE9"),
            success: Color(hex: "#587539"),
            warning: Color(hex: "#8C6C3E"),
            danger: Color(hex: "#F52A65")
        ),
        AppTheme(
            id: "light-one-light",
            name: "One Light",
            family: .light,
            background: Color(hex: "#FAFAFA"),
            text: Color(hex: "#383A42"),
            primary: Color(hex: "#4078F2"),
            success: Color(hex: "#50A14F"),
            warning: Color(hex: "#C18401"),
            danger: Color(hex: "#E45649")
        ),

        // MARK: Dark

        AppTheme(
            id: "dark-default",
            name: "Default",
            family: .dark,
            background: Color(white: 0.1),
            text: .white,
            primary: .blue,
            success: .green,
            warning: .orange,
            danger: .red
        ),
        AppTheme(
            id: "dark-dracula",
            name: "Dracula",
            family: .dark,
            background: Color(hex: "#282A36"),
            text: Color(hex: "#F8F8F2"),
            primary: Color(hex: "#BD93F9"),
            success: Color(hex: "#50FA7B"),
            warning: Color(hex: "#FFB86C"),
            danger: Color(hex: "#FF5555")
        ),
        AppTheme(
            id: "dark-catppuccin-frappe",
            name: "Catppuccin Frappé",
            family: .dark,
            background: Color(hex: "#303446"),
            text: Color(hex: "#C6D0F5"),
            primary: Color(hex: "#8CAAEE"),
            success: Color(hex: "#A6D189"),
            warning: Color(hex: "#E5C890"),
            danger: Color(hex: "#E78284")
        ),
        AppTheme(
            id: "dark-catppuccin-mocha",
            name: "Catppuccin Mocha",
            family: .dark,
            background: Color(hex: "#1E1E2E"),
            text: Color(hex: "#CDD6F4"),
            primary: Color(hex: "#89B4FA"),
            success: Color(hex: "#A6E3A1"),
            warning: Color(hex: "#F9E2AF"),
            danger: Color(hex: "#F38BA8")
        ),
        AppTheme(
            id: "dark-catppuccin-macchiato",
            name: "Catppuccin Macchiato",
            family: .dark,
            background: Color(hex: "#24273A"),
            text: Color(hex: "#CAD3F5"),
            primary: Color(hex: "#8AADF4"),
            success: Color(hex: "#A6DA95"),
            warning: Color(hex: "#EED49F"),
            danger: Color(hex: "#ED8796")
        ),
        AppTheme(
            id: "dark-nord",
            name: "Nord",
            family: .dark,
            background: Color(hex: "#2E3440"),
            text: Color(hex: "#ECEFF4"),
            primary: Color(hex: "#88C0D0"),
            success: Color(hex: "#A3BE8C"),
            warning: Color(hex: "#EBCB8B"),
            danger: Color(hex: "#BF616A")
        ),
        AppTheme(
            id: "dark-tokyo-night-storm",
            name: "Tokyo Night Storm",
            family: .dark,
            background: Color(hex: "#24283B"),
            text: Color(hex: "#A9B1D6"),
            primary: Color(hex: "#7AA2F7"),
            success: Color(hex: "#9ECE6A"),
            warning: Color(hex: "#E0AF68"),
            danger: Color(hex: "#F7768E")
        ),
    ]

    /// Returns the theme matching `id`, falling back to the dark default.
    static func theme(for id: String) -> AppTheme {
        allBuiltIn.first { $0.id == id }
            ?? allBuiltIn.first { $0.id == "dark-default" }!
    }
}

// MARK: - SwiftUI Environment

private struct AppThemeKey: EnvironmentKey {
    static let defaultValue = AppTheme.theme(for: "dark-default")
}

extension EnvironmentValues {
    var appTheme: AppTheme {
        get { self[AppThemeKey.self] }
        set { self[AppThemeKey.self] = newValue }
    }
}

// MARK: - Color Hex Initializer

extension Color {
    /// Creates a `Color` from a hex string.
    ///
    /// Supported formats (with or without a leading `#`):
    /// - 3 chars  → `RGB`  (each digit is doubled, e.g. `F0A` → `FF00AA`)
    /// - 6 chars  → `RRGGBB`
    /// - 8 chars  → `RRGGBBAA`
    init(hex: String) {
        var raw = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if raw.hasPrefix("#") { raw.removeFirst() }

        // Expand shorthand 3-char form to 6-char form.
        if raw.count == 3 {
            raw = raw.map { "\($0)\($0)" }.joined()
        }

        let scanner = Scanner(string: raw)
        var value: UInt64 = 0
        scanner.scanHexInt64(&value)

        let r: Double
        let g: Double
        let b: Double
        let a: Double
        switch raw.count {
        case 6:
            r = Double((value >> 16) & 0xFF) / 255
            g = Double((value >> 8) & 0xFF) / 255
            b = Double(value & 0xFF) / 255
            a = 1.0
        case 8:
            r = Double((value >> 24) & 0xFF) / 255
            g = Double((value >> 16) & 0xFF) / 255
            b = Double((value >> 8) & 0xFF) / 255
            a = Double(value & 0xFF) / 255
        default:
            // Fallback to clear on unrecognised input.
            r = 0
            g = 0
            b = 0
            a = 0
        }

        self.init(.sRGB, red: r, green: g, blue: b, opacity: a)
    }
}
