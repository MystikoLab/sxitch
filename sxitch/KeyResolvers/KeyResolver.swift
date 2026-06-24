import Foundation

protocol KeyResolver {
    func assignKeys(to apps: [RunningApp], depth: Int) -> [RunningApp: String]
}

enum KeyResolverFactory {
    static func make(_ scheme: String) -> KeyResolver {
        switch scheme {
        case "Alphabets":
            return AlphabetsResolver()
        case "Numbers":
            return NumbersResolver()
        case "Qwerty":
            return QwertyResolver()
        case "NameIncrement":
            return NameIncrementResolver()
        default:
            return NameIncrementResolver()
        }
    }
}
