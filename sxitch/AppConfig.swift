import Combine
import ServiceManagement
import SwiftUI

class AppConfig: ObservableObject {
    static let shared = AppConfig()

    let objectWillChange = PassthroughSubject<Void, Never>()

    // MARK: - Hotkey

    var hotkeyModifier: Int {
        get { UserDefaults.standard.integer(forKey: "hotkey_modifier") }
        set {
            UserDefaults.standard.set(newValue, forKey: "hotkey_modifier")
            publish()
        }
    }
    var hotkeyKeycode: Int {
        get { UserDefaults.standard.integer(forKey: "hotkey_keycode") }
        set {
            UserDefaults.standard.set(newValue, forKey: "hotkey_keycode")
            publish()
        }
    }

    // MARK: - Mode Hotkeys

    var quitModeModifier: Int {
        get { UserDefaults.standard.integer(forKey: "mode_quit_modifier") }
        set {
            UserDefaults.standard.set(newValue, forKey: "mode_quit_modifier")
            publish()
        }
    }
    var quitModeKeycode: Int {
        get { UserDefaults.standard.integer(forKey: "mode_quit_keycode") }
        set {
            UserDefaults.standard.set(newValue, forKey: "mode_quit_keycode")
            publish()
        }
    }
    var hideModeModifier: Int {
        get { UserDefaults.standard.integer(forKey: "mode_hide_modifier") }
        set {
            UserDefaults.standard.set(newValue, forKey: "mode_hide_modifier")
            publish()
        }
    }
    var hideModeKeycode: Int {
        get { UserDefaults.standard.integer(forKey: "mode_hide_keycode") }
        set {
            UserDefaults.standard.set(newValue, forKey: "mode_hide_keycode")
            publish()
        }
    }
    var normalModeModifier: Int {
        get { UserDefaults.standard.integer(forKey: "mode_normal_modifier") }
        set {
            UserDefaults.standard.set(newValue, forKey: "mode_normal_modifier")
            publish()
        }
    }
    var normalModeKeycode: Int {
        get { UserDefaults.standard.integer(forKey: "mode_normal_keycode") }
        set {
            UserDefaults.standard.set(newValue, forKey: "mode_normal_keycode")
            publish()
        }
    }

    // MARK: - Key Resolution

    var keyScheme: String {
        get { UserDefaults.standard.string(forKey: "key_scheme") ?? "NameIncrement" }
        set {
            UserDefaults.standard.set(newValue, forKey: "key_scheme")
            publish()
        }
    }
    var showKeys: Bool {
        get {
            guard UserDefaults.standard.object(forKey: "show_keys") != nil else { return true }
            return UserDefaults.standard.bool(forKey: "show_keys")
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "show_keys")
            publish()
        }
    }

    // MARK: - Key Overrides (Pro)
    // Format: "com.apple.Safari=s,com.google.Chrome=c"

    var keyOverridesData: String {
        get { UserDefaults.standard.string(forKey: "key_overrides") ?? "" }
        set {
            UserDefaults.standard.set(newValue, forKey: "key_overrides")
            publish()
        }
    }

    var parsedKeyOverrides: [String: String] {
        var result: [String: String] = [:]
        for part in keyOverridesData.split(separator: ",") {
            let kv = part.trimmingCharacters(in: .whitespaces).split(separator: "=", maxSplits: 1)
            if kv.count == 2 {
                let bundleID = String(kv[0]).trimmingCharacters(in: .whitespaces)
                let key = String(kv[1]).trimmingCharacters(in: .whitespaces)
                if !bundleID.isEmpty && !key.isEmpty {
                    result[bundleID] = key
                }
            }
        }
        return result
    }

    // MARK: - Layout & UI

    var layout: String {
        get { UserDefaults.standard.string(forKey: "layout") ?? "Grid" }
        set {
            UserDefaults.standard.set(newValue, forKey: "layout")
            publish()
        }
    }
    var enableUI: Bool {
        get {
            guard UserDefaults.standard.object(forKey: "enable_ui") != nil else { return true }
            return UserDefaults.standard.bool(forKey: "enable_ui")
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "enable_ui")
            publish()
        }
    }
    var windowPicking: Bool {
        get { UserDefaults.standard.bool(forKey: "window_picking") }
        set {
            UserDefaults.standard.set(newValue, forKey: "window_picking")
            publish()
        }
    }

    // MARK: - Screen Position (Pro)

    var position: String {
        get { UserDefaults.standard.string(forKey: "position") ?? "Default" }
        set {
            UserDefaults.standard.set(newValue, forKey: "position")
            publish()
        }
    }

    // MARK: - App Filtering

    var skipPrefixesData: String {
        get { UserDefaults.standard.string(forKey: "skip_prefixes") ?? "microsoft,adobe" }
        set {
            UserDefaults.standard.set(newValue, forKey: "skip_prefixes")
            publish()
        }
    }

    /// Blacklist of bundle IDs to hide, comma-separated (Pro).
    var blacklist: String {
        get { UserDefaults.standard.string(forKey: "blacklist") ?? "" }
        set {
            UserDefaults.standard.set(newValue, forKey: "blacklist")
            publish()
        }
    }

    var parsedBlacklist: [String] {
        blacklist.split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }

    // MARK: - Theming

    var themeMode: String {
        get { UserDefaults.standard.string(forKey: "theme_mode") ?? "Auto" }
        set {
            UserDefaults.standard.set(newValue, forKey: "theme_mode")
            publish()
        }
    }
    var lightThemeName: String {
        get { UserDefaults.standard.string(forKey: "light_theme_name") ?? "light-default" }
        set {
            UserDefaults.standard.set(newValue, forKey: "light_theme_name")
            publish()
        }
    }
    var darkThemeName: String {
        get { UserDefaults.standard.string(forKey: "dark_theme_name") ?? "dark-default" }
        set {
            UserDefaults.standard.set(newValue, forKey: "dark_theme_name")
            publish()
        }
    }

    /// Pass the current SwiftUI colorScheme for Auto mode resolution.
    func currentTheme(for appearance: ColorScheme?) -> AppTheme {
        switch themeMode {
        case "Light":
            return AppTheme.theme(for: lightThemeName)
        case "Dark":
            return AppTheme.theme(for: darkThemeName)
        default:  // Auto
            if appearance == .light {
                return AppTheme.theme(for: lightThemeName)
            } else {
                return AppTheme.theme(for: darkThemeName)
            }
        }
    }

    /// Returns a SwiftUI preferred color scheme override (nil = follow system).
    var effectiveColorScheme: ColorScheme? {
        switch themeMode {
        case "Light": return .light
        case "Dark": return .dark
        default: return nil
        }
    }

    // MARK: - Window Appearance

    var blur: Bool {
        get {
            guard UserDefaults.standard.object(forKey: "blur") != nil else { return true }
            return UserDefaults.standard.bool(forKey: "blur")
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "blur")
            publish()
        }
    }

    // MARK: - Menu Bar

    var trayIconVisible: Bool {
        get {
            guard UserDefaults.standard.object(forKey: "tray_icon_visible") != nil else {
                return true
            }
            return UserDefaults.standard.bool(forKey: "tray_icon_visible")
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "tray_icon_visible")
            publish()
        }
    }

    // MARK: - Login Item

    var openAtLogin: Bool {
        get { SMAppService.mainApp.status == .enabled }
        set {
            do {
                if newValue {
                    try SMAppService.mainApp.register()
                } else {
                    try SMAppService.mainApp.unregister()
                }
            } catch {
                print("SMAppService error: \(error)")
            }
        }
    }

    // MARK: - Licensing

    var isPro: Bool {
        get { UserDefaults.standard.bool(forKey: "is_pro") }
        set {
            UserDefaults.standard.set(newValue, forKey: "is_pro")
            publish()
        }
    }
    var licenseKey: String {
        get { UserDefaults.standard.string(forKey: "license_key") ?? "" }
        set { UserDefaults.standard.set(newValue, forKey: "license_key") }
    }

    // MARK: - Onboarding

    var onboardingComplete: Bool {
        get { UserDefaults.standard.bool(forKey: "onboarding_complete") }
        set { UserDefaults.standard.set(newValue, forKey: "onboarding_complete") }
    }
    var firstLaunch: Bool {
        get { UserDefaults.standard.bool(forKey: "first_launch") }
        set { UserDefaults.standard.set(newValue, forKey: "first_launch") }
    }

    // MARK: - Private

    private func publish() {
        objectWillChange.send()
    }
}

// MARK: - Binding Helpers

extension Binding where Value == Int {
    static func config(_ keyPath: ReferenceWritableKeyPath<AppConfig, Int>) -> Binding<Int> {
        Binding(
            get: { AppConfig.shared[keyPath: keyPath] },
            set: { AppConfig.shared[keyPath: keyPath] = $0 }
        )
    }
}

extension Binding where Value == String {
    static func config(_ keyPath: ReferenceWritableKeyPath<AppConfig, String>) -> Binding<String> {
        Binding(
            get: { AppConfig.shared[keyPath: keyPath] },
            set: { AppConfig.shared[keyPath: keyPath] = $0 }
        )
    }
}

extension Binding where Value == Bool {
    static func config(_ keyPath: ReferenceWritableKeyPath<AppConfig, Bool>) -> Binding<Bool> {
        Binding(
            get: { AppConfig.shared[keyPath: keyPath] },
            set: { AppConfig.shared[keyPath: keyPath] = $0 }
        )
    }
}
