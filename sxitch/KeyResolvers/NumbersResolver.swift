import Foundation

struct NumbersResolver: KeyResolver {
    func assignKeys(to apps: [RunningApp], depth: Int) -> [RunningApp: String] {
        Dictionary(uniqueKeysWithValues: apps.enumerated().map { index, app in
            let key = index < 9 ? "\(index + 1)" : ""
            return (app, key)
        })
    }
}
