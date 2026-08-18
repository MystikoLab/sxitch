import Foundation

enum ModeAppIcon: Codable, Equatable {
    case system(String)
    case image(String)
}

struct ModeApp: Codable, Equatable, Identifiable {
    var id = UUID()
    var bundleURL: String
    var displayName: String
    var icon: ModeAppIcon?
}

struct CustomMode: Codable, Equatable, Identifiable {
    var id = UUID()
    var name: String
    var apps: [ModeApp]
}

enum CustomModeStore {
    static let key = "customModes"
    static let freeModeLimit = 2

    static func load() -> [CustomMode] {
        guard let data = UserDefaults.standard.data(forKey: key),
              let modes = try? JSONDecoder().decode([CustomMode].self, from: data)
        else { return [] }
        return modes
    }

    static func save(_ modes: [CustomMode]) {
        guard let data = try? JSONEncoder().encode(modes) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }
}