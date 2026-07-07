import Foundation
import SwiftUI

/// Allows [String: String] dictionaries to be stored directly via @AppStorage
extension Dictionary: @retroactive RawRepresentable where Key == String, Value == String {
    public init?(rawValue: String) {
        guard let data = rawValue.data(using: .utf8),
              let result = try? JSONDecoder().decode([String: String].self, from: data)
        else {
            return nil
        }
        self = result
    }

    public var rawValue: String {
        guard let data = try? JSONEncoder().encode(self),
              let result = String(data: data, encoding: .utf8)
        else {
            return "{}"
        }
        return result
    }
}
