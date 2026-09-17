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

    static let trialLengthDays: Int = 14

    var isPro: Bool = false
    var isCheckingLicense: Bool = false

    /// Date the free trial started; nil means the user has never started one.
    var trialStartDate: Date?

    /// Set by the onboarding layout page: while true, the summon hotkey
    /// toggles the real switcher (demo) instead of being suppressed.
    var layoutDemoActive = false
    /// Tracks whether the onboarding demo switcher is currently on screen.
    var demoSwitcherVisible = false

    private init() {}

    // MARK: - Trial

    /// The full Pro experience is unlocked by a valid license OR an active trial.
    var hasFullAccess: Bool {
        isPro || isTrialActive
    }

    var isTrialActive: Bool {
        guard let start = trialStartDate else { return false }
        return Date().timeIntervalSince(start) < Self.trialLength
    }

    /// Whole days left in the trial, clamped to 0.
    var trialDaysRemaining: Int {
        guard let start = trialStartDate else { return 0 }
        let remaining = (start.addingTimeInterval(Self.trialLength).timeIntervalSinceNow) / 86400
        return max(0, Int(remaining.rounded(.up)))
    }

    var hasTrialEverStarted: Bool {
        trialStartDate != nil
    }

    var isTrialExpired: Bool {
        hasTrialEverStarted && !isTrialActive
    }

    private static var trialLength: TimeInterval {
        Double(trialLengthDays) * 86400
    }

    /// Starts the 14-day trial if it has not been started before.
    func startTrial() {
        guard trialStartDate == nil else { return }
        let now = Date()
        trialStartDate = now
        persistTrialStart(now)
    }

    /// Called on launch: restores the persisted trial date and shows the
    /// expiry alert once if the trial has ended.
    func beginTrialIfNeeded() {
        trialStartDate = loadTrialStartDate()
        showTrialExpiryAlertIfNeeded()
    }

    // MARK: Trial persistence

    // The trial start date is written to the Keychain (primary, survives
    // app deletion) and mirrored in UserDefaults as a fallback. If both
    // exist and disagree, the earliest date wins so deleting either copy
    // or rolling the clock cannot extend the trial.

    private static let trialKeychainAccount = "trial_start"
    private static let trialDefaultsKey = "trial_start_mirror"

    private func persistTrialStart(_ date: Date) {
        let iso = ISO8601DateFormatter().string(from: date)
        UserDefaults.standard.set(iso, forKey: Self.trialDefaultsKey)
        try? saveKeychainSecret(account: Self.trialKeychainAccount, secret: iso)
    }

    private func loadTrialStartDate() -> Date? {
        var dates: [Date] = []

        if let iso = UserDefaults.standard.string(forKey: Self.trialDefaultsKey) {
            if let date = ISO8601DateFormatter().date(from: iso) {
                dates.append(date)
            }
        }

        if let iso = try? readKeychainSecret(account: Self.trialKeychainAccount) {
            if let date = ISO8601DateFormatter().date(from: iso) {
                dates.append(date)
            }
        }

        guard let earliest = dates.min() else { return nil }

        // Heal whichever copy is missing or drifted.
        if dates.count < 2 {
            persistTrialStart(earliest)
        }

        return earliest
    }

    // MARK: Trial expiry alert

    private static let trialExpiryAlertShownKey = "trial_expiry_alert_shown"

    func showTrialExpiryAlertIfNeeded() {
        guard isTrialExpired else { return }
        let defaults = UserDefaults.standard
        guard !defaults.bool(forKey: Self.trialExpiryAlertShownKey) else { return }
        defaults.set(true, forKey: Self.trialExpiryAlertShownKey)

        let alert = NSAlert()
        alert.messageText = "Your Sxitch Pro trial has ended"
        alert.informativeText = "The 14-day trial is over and Pro features are now locked. Activate a license key to keep them."
        alert.addButton(withTitle: "Enter License Key")
        alert.addButton(withTitle: "Not Now")

        if alert.runModal() == .alertFirstButtonReturn {
            UserDefaults.standard.set("activate", forKey: "selectedSettingsTab")
            NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
        }
    }

    // MARK: - License

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
