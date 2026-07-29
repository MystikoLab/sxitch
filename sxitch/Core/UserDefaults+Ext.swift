import Foundation

typealias AppHotkeys = [String: String]

extension UserDefaults {
    var appHotkeys: AppHotkeys {
        get { (dictionary(forKey: "app_hotkeys") as? AppHotkeys) ?? [:] }
        set { set(newValue, forKey: "app_hotkeys") }
    }

    var keyOverrides: [String: String] {
        get { (dictionary(forKey: "key_overrides") as? [String: String]) ?? [:] }
        set { set(newValue, forKey: "key_overrides") }
    }

    var iconMapping: [String: String] {
        get { (dictionary(forKey: "icon_mapping") as? [String: String]) ?? [:] }
        set { set(newValue, forKey: "icon_mapping") }
    }
}
