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
    /// True once a license has been validated this session (launch check or
    /// activation) and the device hasn't been deactivated. Keeps the Pro Mode
    /// section on the Account page visible while debug-free mode is active.
    var hasValidLicense: Bool = false
    var isCheckingLicense: Bool = false
    /// True once a launch/page-visit license check has finished this
    /// session, so later Account page visits don't re-hit the network.
    private(set) var didCompleteLicenseCheck = false
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

    /// Validates the stored activation against Polar. Runs at most once per
    /// session unless `force` is set (Pro Mode toggle / Revert button on the
    /// Account page re-validate on demand).
    func checkCurrentActivationStatus(force: Bool = false) async {
        guard !isCheckingLicense, force || !didCompleteLicenseCheck else { return }

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
                self.hasValidLicense = isValid
                self.isCheckingLicense = false
                self.didCompleteLicenseCheck = true
            }
        } catch {
            // Keychain missing keys or network failed. `hasValidLicense` is
            // left untouched so a transient error doesn't hide the Pro Mode
            // toggle from a user whose license was already validated.
            await MainActor.run {
                self.isPro = false
                self.isCheckingLicense = false
                self.didCompleteLicenseCheck = true
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
