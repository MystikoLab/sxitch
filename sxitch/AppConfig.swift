import SwiftUI
import Combine

class AppConfig: ObservableObject {
    static let shared = AppConfig()

    let objectWillChange = PassthroughSubject<Void, Never>()

    var hotkeyModifier: Int {
        get { UserDefaults.standard.integer(forKey: "hotkey_modifier") }
        set { UserDefaults.standard.set(newValue, forKey: "hotkey_modifier"); publish() }
    }
    var hotkeyKeycode: Int {
        get { UserDefaults.standard.integer(forKey: "hotkey_keycode") }
        set { UserDefaults.standard.set(newValue, forKey: "hotkey_keycode"); publish() }
    }
    var quitModeModifier: Int {
        get { UserDefaults.standard.integer(forKey: "mode_quit_modifier") }
        set { UserDefaults.standard.set(newValue, forKey: "mode_quit_modifier"); publish() }
    }
    var quitModeKeycode: Int {
        get { UserDefaults.standard.integer(forKey: "mode_quit_keycode") }
        set { UserDefaults.standard.set(newValue, forKey: "mode_quit_keycode"); publish() }
    }
    var hideModeModifier: Int {
        get { UserDefaults.standard.integer(forKey: "mode_hide_modifier") }
        set { UserDefaults.standard.set(newValue, forKey: "mode_hide_modifier"); publish() }
    }
    var hideModeKeycode: Int {
        get { UserDefaults.standard.integer(forKey: "mode_hide_keycode") }
        set { UserDefaults.standard.set(newValue, forKey: "mode_hide_keycode"); publish() }
    }
    var normalModeModifier: Int {
        get { UserDefaults.standard.integer(forKey: "mode_normal_modifier") }
        set { UserDefaults.standard.set(newValue, forKey: "mode_normal_modifier"); publish() }
    }
    var normalModeKeycode: Int {
        get { UserDefaults.standard.integer(forKey: "mode_normal_keycode") }
        set { UserDefaults.standard.set(newValue, forKey: "mode_normal_keycode"); publish() }
    }
    var keyScheme: String {
        get { UserDefaults.standard.string(forKey: "key_scheme") ?? "NameIncrement" }
        set { UserDefaults.standard.set(newValue, forKey: "key_scheme"); publish() }
    }
    var showKeys: Bool {
        get { UserDefaults.standard.bool(forKey: "show_keys") }
        set { UserDefaults.standard.set(newValue, forKey: "show_keys"); publish() }
    }
    var enableUI: Bool {
        get { UserDefaults.standard.bool(forKey: "enable_ui") }
        set { UserDefaults.standard.set(newValue, forKey: "enable_ui"); publish() }
    }
    var skipPrefixesData: String {
        get { UserDefaults.standard.string(forKey: "skip_prefixes") ?? "microsoft,adobe" }
        set { UserDefaults.standard.set(newValue, forKey: "skip_prefixes"); publish() }
    }
    var layout: String {
        get { UserDefaults.standard.string(forKey: "layout") ?? "Grid" }
        set { UserDefaults.standard.set(newValue, forKey: "layout"); publish() }
    }
    var isPro: Bool {
        get { UserDefaults.standard.bool(forKey: "is_pro") }
        set { UserDefaults.standard.set(newValue, forKey: "is_pro") }
    }
    var licenseKey: String {
        get { UserDefaults.standard.string(forKey: "license_key") ?? "" }
        set { UserDefaults.standard.set(newValue, forKey: "license_key") }
    }
    var firstLaunch: Bool {
        get { UserDefaults.standard.bool(forKey: "first_launch") }
        set { UserDefaults.standard.set(newValue, forKey: "first_launch") }
    }

    private func publish() {
        objectWillChange.send()
    }
}

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
