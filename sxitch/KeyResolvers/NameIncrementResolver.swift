import Foundation

struct NameIncrementResolver: KeyResolver {
    func assignKeys(to apps: [RunningApp], depth: Int) -> [RunningApp: String] {
        Dictionary(uniqueKeysWithValues: apps.map { app in
            let name = app.appName.lowercased()
            let asciiName = String(name.unicodeScalars.filter { $0.isASCII })
            let key: String
            if depth < asciiName.count {
                let idx = asciiName.index(asciiName.startIndex, offsetBy: depth)
                key = String(asciiName[idx])
            } else {
                key = ""
            }
            return (app, key)
        })
    }
}
