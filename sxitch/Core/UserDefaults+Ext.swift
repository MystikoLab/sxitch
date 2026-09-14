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

    var appRenames: [String: String] {
        get { (dictionary(forKey: "app_renames") as? [String: String]) ?? [:] }
        set { set(newValue, forKey: "app_renames") }
    }

    var pinnedAppURLs: [String] {
        get {
            if let arr = object(forKey: "pinned_app_urls") as? [String] {
                return arr
            }
            if let raw = string(forKey: "pinned_app_urls") {
                if let arr = [String](rawValue: raw) {
                    return arr
                }
            }
            return []
        }
        set { set(newValue.rawValue, forKey: "pinned_app_urls") }
    }
}
