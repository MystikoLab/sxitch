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
    /// Fetched once on startup (with the license check) and via the refresh
    /// button on the Account page.
    var licenseInfo: LicenseInfo?
    var isRefreshingLicenseInfo: Bool = false

    /// Set by the onboarding layout page: while true, the summon hotkey
    /// toggles the real switcher (demo) instead of being suppressed.
    var layoutDemoActive = false
    /// Tracks whether the onboarding demo switcher is currently on screen.
    var demoSwitcherVisible = false

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

            // 3. Fetch license info (email + activation usage) for the Account page
            if isValid {
                await refreshLicenseInfo()
            }

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

    /// Refreshes email + activation usage for the stored license key.
    func refreshLicenseInfo() async {
        guard let (_, keyId) = try? getCredentials(), !keyId.isEmpty else { return }
        let key = keyId

        await MainActor.run { isRefreshingLicenseInfo = true }

        do {
            let info = try await fetchLicenseInfo(key: key)
            await MainActor.run {
                licenseInfo = info
                isRefreshingLicenseInfo = false
            }
        } catch {
            await MainActor.run { isRefreshingLicenseInfo = false }
        }
    }
}
