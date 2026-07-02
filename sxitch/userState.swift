//
//  userState.swift
//  sxitch
//
//  Created by Umang on 26/6/26.
//

import SwiftUI

@Observable
final class userState {
    static let shared = userState()

    var isPro: Bool = false
    var isCheckingLicense: Bool = false

    private init() {}

    /// Call this on app launch (e.g., in your App struct's init or .task)
    func checkCurrentActivationStatus() async {
        guard !isCheckingLicense else { return }

        await MainActor.run { isCheckingLicense = true }

        do {
            // 1. Fetch encrypted tokens from macOS/iOS secure system Keychain
            let (activationId, keyId) = try getCredentials()

            // 2. Validate against Polar API server dynamically
            let isValid = try await validateKey(key: keyId, activationId: activationId)

            await MainActor.run {
                self.isPro = isValid
                self.isCheckingLicense = false
            }
        } catch {
            // Keychain missing keys or network failed
            await MainActor.run {
                self.isPro = false
                self.isCheckingLicense = false
            }
        }
    }
}
