extension String {
    func capitalizedFirst() -> String {
        guard let first = self.first else { return self }
        return first.uppercased() + self.dropFirst()
    }
}
