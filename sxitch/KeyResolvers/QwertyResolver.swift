import Foundation

struct QwertyResolver: KeyResolver {
    private let qwertyRow = Array("qwertyuiop")

    func assignKeys(to apps: [RunningApp], depth: Int) -> [RunningApp: String] {
        Dictionary(uniqueKeysWithValues: apps.enumerated().map { index, app in
            let key = index < qwertyRow.count ? String(qwertyRow[index]) : ""
            return (app, key)
        })
    }
}
