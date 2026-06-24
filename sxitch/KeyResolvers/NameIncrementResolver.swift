import Foundation

struct NameIncrementResolver: KeyResolver {
    func assignKeys(to apps: [RunningApp], depth: Int) -> [RunningApp: String] {
        Dictionary(uniqueKeysWithValues: apps.map { app in
            let name = app.appName.lowercased()
            let key: String
            if depth < name.count {
                let idx = name.index(name.startIndex, offsetBy: depth)
                key = String(name[idx])
            } else {
                key = ""
            }
            return (app, key)
        })
    }
}
