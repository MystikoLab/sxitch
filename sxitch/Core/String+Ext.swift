extension String {
    func capitalizedFirst() -> String {
        guard let first = first else { return self }
        return first.uppercased() + dropFirst()
    }
}

// MARK: - Typed matching

extension Character {
    /// Skipped when matching typed text against a name, so the " - " in a
    /// deduplicated "A - Safari" (or a plain space) never has to be typed.
    var isTypedMatchSeparator: Bool {
        isWhitespace || self == "-"
    }
}

extension String {
    /// Lowercased, with separators removed; what typed text is compared on.
    var typedMatchKey: String {
        lowercased().filter { !$0.isTypedMatchSeparator }
    }

    /// Whether `typed` is a prefix of this name, ignoring case and separators.
    func matchesTyped(_ typed: String) -> Bool {
        typedMatchKey.hasPrefix(typed.typedMatchKey)
    }

    /// The character to type next once `typedCount` characters matched, i.e.
    /// the next non-separator character after them.
    func nextTypedCharacter(afterTyped typedCount: Int) -> Character? {
        lazy.filter { !$0.isTypedMatchSeparator }.dropFirst(typedCount).first
    }
}
