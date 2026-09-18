import SwiftUI

struct ActivateSettingsView: View, SettingsTab {
    static let tabID = "activate"
    static let tabTitle = "Activate"
    static let tabIcon = "lock"

    @State private var licenseKey = ""
    @State private var isActivating = false
    @State private var errorMessage: String? = nil

    private var appState = userState.shared

    var body: some View {
        Form {
            Section(header: Text("License Status")) {
                if appState.isCheckingLicense {
                    HStack {
                        ProgressView()
                            .controlSize(.small)
                        Text("Verifying your license status...")
                            .foregroundColor(.secondary)
                    }
                } else if appState.isPro {
                    HStack {
                        Image(systemName: "checkmark.seal.fill")
                            .foregroundColor(.green)
                            .imageScale(.large)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Sxitch Pro Activated")
                                .font(.headline)
                            Text("Thank you for supporting development!")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.vertical, 4)

                    Button("Deactivate Device", role: .destructive) {
                        deactivateLicense()
                    }
                } else if appState.isTrialActive {
                    HStack {
                        Image(systemName: "hourglass.bottom.filled.tentpath")
                            .foregroundColor(.blue)
                            .imageScale(.large)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Pro Trial Active")
                                .font(.headline)
                            Text(
                                "\(appState.trialDaysRemaining) of \(userState.trialLengthDays) days remaining. All Pro features are unlocked."
                            )
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                } else {
                    HStack {
                        Image(systemName: appState.isTrialExpired ? "clock.badge.xmark" : "xmark.seal.fill")
                            .foregroundColor(.secondary)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(appState.isTrialExpired ? "Free Version (Trial Ended)" : "Free Version")
                                .font(.headline)
                            if appState.isTrialExpired {
                                Text("Your 14-day Pro trial has ended.")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    if !appState.hasTrialEverStarted {
                        Button {
                            appState.startTrial()
                        } label: {
                            Label("Start 14-Day Free Trial", systemImage: "clock.badge.checkmark")
                        }
                    }
                }
            }

            if !appState.isPro {
                Section(
                    header: Text("Activate Pro"),
                    footer: Text(
                        "Enter the license key received upon purchase to unlock Pro features."
                    )
                ) {
                    TextField("XXXX-XXXX-XXXX-XXXX", text: $licenseKey)
                        .disabled(isActivating || appState.isCheckingLicense)
                        .labelsHidden()
                        .textFieldStyle(.roundedBorder)

                    if let errorMessage = errorMessage {
                        Text(errorMessage)
                            .foregroundColor(.red)
                            .font(.caption)
                    }

                    Button(action: {
                        Task { await performActivation() }
                    }) {
                        if isActivating {
                            ProgressView()
                                .controlSize(.small)
                        } else {
                            Text("Activate Key")
                        }
                    }
                    .disabled(
                        licenseKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                            || isActivating
                    )
                }
                Section(
                    header: Text("Get Sxitch Pro"),
                    footer: Text("You'll receive a license key by email after purchase. Activate it below.")
                ) {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach([
                            "3 Macs · macOS 15+",
                            "Hide / Quit mode",
                            "Overrides and blacklists",
                            "Unlimited modes",
                            "Window picking",
                            "Priority Support (via Discord)",
                            "All future updates included",
                            "No account required",
                        ], id: \.self) { feature in
                            Label(feature, systemImage: "checkmark")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                    HStack(spacing: 12) {
                        Button(action: { openCheckout(.oneTime) }) {
                            VStack(spacing: 2) {
                                Text("Buy Once")
                                    .font(.headline)
                                Text("$10 · lifetime")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 6)
                        }
                        .buttonStyle(.borderedProminent)

                        Button(action: { openCheckout(.subscription) }) {
                            VStack(spacing: 2) {
                                Text("Subscribe")
                                    .font(.headline)
                                Text("$2 / month")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 6)
                        }
                        .buttonStyle(.bordered)
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .padding()
        .formStyle(.grouped)
        .task {
            await appState.checkCurrentActivationStatus()
        }
    }

    private func performActivation() async {
        isActivating = true
        errorMessage = nil
        let cleanedKey = licenseKey.trimmingCharacters(in: .whitespacesAndNewlines)

        do {
            let success = try await activateKey(key: cleanedKey)
            await MainActor.run {
                if success {
                    appState.isPro = true
                    licenseKey = ""
                } else {
                    errorMessage = "Invalid license key or activation limit reached."
                    appState.isPro = false
                }
                isActivating = false
            }
        } catch {
            await MainActor.run {
                errorMessage = "Network or connection error. Please try again."
                isActivating = false
            }
        }
    }

    private func deactivateLicense() {
        do {
            try deleteCredentials()
            appState.isPro = false
        } catch {
            print("Failed to remove credentials from Keychain: \(error)")
        }
    }
}

private enum PurchasePlan {
    case oneTime
    case subscription

    var checkoutURL: URL {
        switch self {
        case .oneTime:
            return URL(string: "https://buy.polar.sh/polar_cl_KHE76N1u71k4CQZMxjSlJDS9Ylh1gOI2p89z74ZxJ5c")!
        case .subscription:
            return URL(string: "https://buy.polar.sh/polar_cl_MhcxcWQljznmm2jcMhSp9XMevDqLz7zQfn9mD11VGTg")!
        }
    }
}

private func openCheckout(_ plan: PurchasePlan) {
    NSWorkspace.shared.open(plan.checkoutURL)
}
