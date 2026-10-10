import AppKit
import SwiftUI

struct AccountSettingsView: View, SettingsTab {
    static let tabID = "account"
    static let tabTitle = "Account"
    static let tabIcon = "person.crop.circle.fill"

    @State private var licenseKey = ""
    @State private var isActivating = false
    @State private var errorMessage: String? = nil

    /// The stored license key (Keychain `key_id`); nil until loaded, empty
    /// string when unreadable.
    @State private var storedKey: String? = nil
    @State private var isKeyHovered = false
    @State private var didCopyKey = false
    @State private var didCopyInfo = false
    @State private var showsDisableProModeDialog = false

    /// Drives the Pro Mode toggle. Turning it off asks for confirmation
    /// before clearing `isPro`; turning it on re-runs the Polar validation
    /// before Pro features come back. While the re-check is in flight the
    /// toggle reads as on.
    private var proModeBinding: Binding<Bool> {
        Binding(
            get: { appState.isPro || appState.isCheckingLicense },
            set: { newValue in
                if newValue {
                    Task { await appState.checkCurrentActivationStatus(force: true) }
                } else {
                    showsDisableProModeDialog = true
                }
            }
        )
    }

    private var appState = userState.shared

    var body: some View {
        Form {
            Section {
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
                        Spacer()
                        Button("Deactivate Device", role: .destructive) {
                            deactivateLicense()
                        }
                    }
                    .padding(.vertical, 4)

                    HStack(spacing: 8) {
                        Text("License Key")
                        SettingInfoTip(
                            text:
                            "Hover the key to reveal it and show the copy button; click the key or the button to copy. It is stored in this Mac's Keychain, and each key covers up to 3 Macs."
                        )
                        Spacer()
                        Button {
                            copyKey()
                        } label: {
                            Text(didCopyKey ? "Copied" : "Copy")
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundStyle(didCopyKey ? Color.green : Color.primary)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .opacity(isKeyHovered ? 1 : 0)
                        .disabled(!isKeyHovered)
                        licenseKeyText
                            .onTapGesture { copyKey() }
                            .help("Hover to reveal · click to copy")
                    }
                    .onHover { isKeyHovered = $0 }
                    .animation(.easeInOut(duration: 0.15), value: isKeyHovered)
                } else {
                    HStack {
                        Image(systemName: "xmark.seal.fill")
                            .foregroundColor(.secondary)
                        Text("Free Version")
                            .font(.headline)
                    }
                }
            } header: {
                Text("License Status")
            }

            if appState.hasValidLicense {
                Section {
                    HStack(spacing: 8) {
                        Toggle("Pro Mode", isOn: proModeBinding)
                        SettingInfoTip(text: "Made for debugging free mode")
                    }
                    Text("Turn off to debug the free experience. Applies to this session only and resets on relaunch.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if !appState.isPro {
                        Button("Revert to Pro") {
                            Task { await appState.checkCurrentActivationStatus(force: true) }
                        }
                        .disabled(appState.isCheckingLicense)
                        .help("Re-validate your license to restore Pro Mode")
                    }
                } header: {
                    Text("Pro Mode")
                }
            }

            if appState.isPro {
                Section {
                    HStack(spacing: 8) {
                        Text("Email")
                        Spacer()
                        if let info = appState.licenseInfo {
                            Text(info.email)
                                .foregroundStyle(.secondary)
                                .textSelection(.enabled)
                        } else if appState.isRefreshingLicenseInfo {
                            ProgressView()
                                .controlSize(.small)
                        } else {
                            Text("Unable to load")
                                .foregroundStyle(.secondary)
                        }
                    }

                    if let info = appState.licenseInfo {
                        HStack {
                            Text("Activations")
                            SettingInfoTip(
                                text:
                                "Number of devices this license has been activated on."
                            )
                            Spacer()
                            Text("\(info.activationsUsed) of \(info.activationLimit)")
                                .foregroundStyle(.secondary)
                                .monospacedDigit()
                        }
                    }
                } header: {
                    HStack(spacing: 8) {
                        Text("License Details")
                        Spacer()
                        Button {
                            Task { await appState.refreshLicenseInfo() }
                        } label: {
                            Image(systemName: "arrow.clockwise")
                                .imageScale(.small)
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(.secondary)
                        .disabled(appState.isRefreshingLicenseInfo)
                        .help("Refresh license info")
                    }
                }
            }

            if !appState.isPro {
                Section {
                    TextField("XXXX-XXXX-XXXX-XXXX", text: $licenseKey)
                        .disabled(isActivating || appState.isCheckingLicense)
                        .labelsHidden()
                        .textFieldStyle(.roundedBorder)

                    if let errorMessage = errorMessage {
                        Text(errorMessage)
                            .foregroundColor(.red)
                            .font(.caption)
                    }

                    HStack(spacing: 12) {
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

                        Button("Recover") {
                            openURL("https://sxitch.app/recover")
                        }
                        .buttonStyle(.bordered)
                        .help("Lost your key? Opens sxitch.app/recover")
                    }
                } header: {
                    InfoTipHeader(
                        title: "Activate Pro",
                        tip: "Enter the license key received upon purchase to unlock Pro features."
                    )
                }
                Section {
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
                    Button(action: { openURL("https://buy.polar.sh/polar_cl_KHE76N1u71k4CQZMxjSlJDS9Ylh1gOI2p89z74ZxJ5c") }) {
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
                    .padding(.vertical, 4)
                } header: {
                    InfoTipHeader(
                        title: "Get Sxitch Pro",
                        tip: "You'll receive a license key by email after purchase. Activate it in the section above."
                    )
                }
            }

            Section {
                LazyVGrid(
                    columns: [
                        GridItem(.flexible(), spacing: 10),
                        GridItem(.flexible(), spacing: 10),
                    ],
                    spacing: 10
                ) {
                    Button {
                        copyDiagnostics()
                    } label: {
                        VStack(spacing: 6) {
                            Image(systemName: "info.circle.fill")
                                .font(.system(size: 28))
                                .foregroundStyle(didCopyInfo ? Color.green : Color.secondary)
                            Text(didCopyInfo ? "Copied!" : "Copy Info")
                                .font(.callout)
                                .foregroundStyle(didCopyInfo ? Color.green : Color.primary)
                        }
                        .frame(maxWidth: .infinity, minHeight: 64)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .help(diagnosticInfo)

                    supportLinkButton("GitHub", icon: "chevron.left.forwardslash.chevron.right") {
                        openURL("https://github.com/MystikoLab/sxitch")
                    }
                    supportLinkButton("Homepage", icon: "globe") {
                        openURL("https://sxitch.app")
                    }
                    supportLinkButton("Discord", icon: "person.2") {
                        openURL("https://discord.sxitch.app")
                    }
                }
            } header: {
                InfoTipHeader(
                    title: "Support",
                    tip: "Copy Info puts the macOS and Sxitch versions on your clipboard for bug reports."
                )
            }
        }
        .formStyle(.grouped)
        .confirmationDialog(
            "Turn off Pro Mode?",
            isPresented: $showsDisableProModeDialog,
            titleVisibility: .visible
        ) {
            Button("Turn Off", role: .destructive) {
                appState.isPro = false
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Pro features will be locked until you turn Pro Mode back on.")
        }
        .task {
            await appState.checkCurrentActivationStatus()
            loadStoredKey()
        }
        .onChange(of: appState.isPro) { _, isPro in
            if isPro {
                loadStoredKey()
            } else {
                storedKey = nil
            }
        }
    }

    /// Key rendered as its readable prefix (the "SXITCH" part) followed by
    /// the secret remainder, which is blurred until hovered.
    @ViewBuilder
    private var licenseKeyText: some View {
        let font = Font.system(.callout, design: .monospaced)
        if let key = storedKey, !key.isEmpty {
            // Split at the underscore when there is one; otherwise treat the
            // first 6 characters as the public prefix so a blur segment
            // always exists.
            let splitIndex = key.firstIndex(of: "_")
                ?? key.index(key.startIndex, offsetBy: min(6, key.count), limitedBy: key.endIndex)!
            let prefix = String(key[..<splitIndex])
            let secret = String(key[splitIndex...])
            HStack(spacing: 0) {
                Text(prefix)
                    .font(font)
                if !secret.isEmpty {
                    Text(secret)
                        .font(.system(size: 10, design: .monospaced))
                        .blur(radius: isKeyHovered ? 0 : 8)
                        .animation(.easeInOut(duration: 0.18), value: isKeyHovered)
                }
            }
            .textSelection(.disabled)
        } else {
            Text("Unavailable").font(font)
        }
    }

    private func loadStoredKey() {
        guard appState.isPro else { return }
        storedKey = (try? getCredentials()).map { _, keyId in keyId } ?? ""
    }

    private func copyKey() {
        guard let key = storedKey, !key.isEmpty else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(key, forType: .string)
        didCopyKey = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            didCopyKey = false
        }
    }

    /// Icon-above-text cell for the support grid.
    private func supportLinkButton(
        _ title: String,
        icon: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 28))
                    .foregroundStyle(.secondary)
                Text(title)
                    .font(.callout)
            }
            .frame(maxWidth: .infinity, minHeight: 64)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    /// Bug-report snippet: macOS version + Sxitch version.
    private var diagnosticInfo: String {
        """
        macOS: \(ProcessInfo.processInfo.operatingSystemVersionString)
        Sxitch: \(Bundle.main.appVersion)
        """
    }

    private func copyDiagnostics() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(diagnosticInfo, forType: .string)
        didCopyInfo = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            didCopyInfo = false
        }
    }

    private func openURL(_ string: String) {
        if let url = URL(string: string) {
            NSWorkspace.shared.open(url)
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
                    appState.hasValidLicense = true
                    licenseKey = ""
                    Task { await appState.refreshLicenseInfo() }
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
            appState.hasValidLicense = false
            storedKey = nil
        } catch {
            print("Failed to remove credentials from Keychain: \(error)")
        }
    }
}
