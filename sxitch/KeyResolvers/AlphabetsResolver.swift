import Foundation

struct AlphabetsResolver: KeyResolver {
    private let alphabet = Array("abcdefghijklmnopqrstuvwxyz")

    func assignKeys(to apps: [RunningApp], depth: Int) -> [RunningApp: String] {
        Dictionary(uniqueKeysWithValues: apps.enumerated().map { index, app in
            let key = index < alphabet.count ? String(alphabet[index]) : ""
            return (app, key)
        })
    }
}
