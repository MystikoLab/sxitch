import AppKit
import SwiftUI

struct HapticsSettingsView: View, SettingsTab {
    static let tabID = "haptics"
    static let tabTitle = "Haptics"
    static let tabIcon = "waveform"

    private var usState = userState.shared

    @AppStorage("hapticsEnabled") private var hapticsEnabled: Bool = true
    @AppStorage("hapticShowUp") private var showUp: Bool = true
    @AppStorage("hapticSwitchApp") private var switchApp: Bool = true
    @AppStorage("hapticModeSwitch") private var modeSwitch: Bool = true
    @AppStorage("hapticCustomModeSwitch") private var customModeSwitch: Bool = true
    @AppStorage("hapticOnboarding") private var onboarding: Bool = true
    @AppStorage("hapticPattern") private var patternRaw: String = HapticPattern.generic.rawValue

    private var selectedPattern: HapticPattern {
        HapticPattern(rawValue: patternRaw) ?? .generic
    }

    /// Unlicensed selection snaps back to Generic, matching what the real
    /// switcher plays (see `Haptics.pattern`).
    private var patternBinding: Binding<String> {
        Binding(
            get: { selectedPattern.rawValue },
            set: { newValue in
                guard let pattern = HapticPattern(rawValue: newValue) else { return }
                if pattern.isPro, !usState.isPro {
                    // Snap back: keeps the gate airtight even if the disabled
                    // state were bypassed in the UI.
                    patternRaw = HapticPattern.generic.rawValue
                } else {
                    patternRaw = newValue
                    Haptics.perform(pattern: pattern.feedbackPattern)
                }
            }
        )
    }

    var body: some View {
        Form {
            Section {
                HStack {
                    Toggle("Enable haptics", isOn: $hapticsEnabled)
                        .onChange(of: hapticsEnabled) { _, enabled in
                            if enabled {
                                Haptics.perform(pattern: Haptics.pattern.feedbackPattern)
                            }
                        }
                    SettingInfoTip(text: "When off, Sxitch stays silent, including this Settings page.")
                }
            } header: {
                InfoTipHeader(
                    title: "Master Switch",
                    tip: "Haptics only work on Macs with a Force Touch trackpad."
                )
            }

            Section {
                Toggle("When Sxitch shows up", isOn: $showUp)
                Toggle("When switching to an app", isOn: $switchApp)
                Toggle("When switching modes (hide / quit / normal)", isOn: $modeSwitch)
                Toggle("When switching to a custom mode", isOn: $customModeSwitch)
            } header: {
                InfoTipHeader(
                    title: "Switcher Feedback",
                    tip: "Choose which switcher moments give tactile feedback."
                )
            }
            .disabled(!hapticsEnabled)

            Section {
                Toggle("While navigating onboarding", isOn: $onboarding)
            } header: {
                InfoTipHeader(
                    title: "Onboarding",
                    tip: "Feedback while stepping through the setup guide."
                )
            }
            .disabled(!hapticsEnabled)

            Section {
                Picker("Pattern", selection: patternBinding) {
                    ForEach(HapticPattern.allCases, id: \.rawValue) { pattern in
                        Text(pattern.displayName).tag(pattern.rawValue)
                    }
                }
                .pickerStyle(.menu)
                .disabled(!hapticsEnabled || !usState.isPro)
                if !usState.isPro {
                    HStack {
                        Label("Pro", systemImage: "lock.fill")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                    }
                } else {
                    Text("The selected pattern applies to every enabled moment.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } header: {
                InfoTipHeader(
                    title: "Pattern",
                    tip: "The tactile feel used for every enabled moment."
                )
            }
            .disabled(!hapticsEnabled)
        }
        .formStyle(.grouped)
        // The toggles are disabled whenever the master switch is off, so
        // playing on any enable here is safe.
        .onChange(of: showUp) { _, on in
            if on {
                preview()
            }
        }
        .onChange(of: switchApp) { _, on in
            if on {
                preview()
            }
        }
        .onChange(of: modeSwitch) { _, on in
            if on {
                preview()
            }
        }
        .onChange(of: customModeSwitch) { _, on in
            if on {
                preview()
            }
        }
        .onChange(of: onboarding) { _, on in
            if on {
                preview()
            }
        }
    }

    private func preview() {
        Haptics.perform(pattern: Haptics.pattern.feedbackPattern)
    }
}
