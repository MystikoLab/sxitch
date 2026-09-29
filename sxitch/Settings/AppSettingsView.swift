import Combine
import CoreGraphics
import ServiceManagement
import SwiftUI

struct AppSettingsView: View, SettingsTab {
    static let tabID = "app"
    static let tabTitle = "App"
    static let tabIcon = "gear"

    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding: Bool = false
    @Environment(\.openWindow) private var openWindow
    @State private var accessibilityGranted: Bool = AXIsProcessTrusted()
    @State private var screenRecordingGranted: Bool = CGPreflightScreenCaptureAccess()
    @State private var isLaunchAtLoginEnabled: Bool = SMAppService.mainApp.status == .enabled

    var body: some View {
        Form {
            Section {
                HStack {
                    Image(
                        systemName: accessibilityGranted
                            ? "checkmark.circle.fill" : "xmark.circle.fill"
                    )
                    .foregroundStyle(accessibilityGranted ? .green : .red)
                    Text(
                        accessibilityGranted ? "Accessibility granted" : "Accessibility not granted"
                    )
                    Spacer()
                    if !accessibilityGranted {
                        Button("Request") {
                            let options =
                                [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true]
                                    as CFDictionary
                            AXIsProcessTrustedWithOptions(options)
                        }
                    }
                }
                .onReceive(Timer.publish(every: 1, on: .main, in: .common).autoconnect()) { _ in
                    let wasGranted = accessibilityGranted
                    accessibilityGranted = AXIsProcessTrusted()
                    if !wasGranted && accessibilityGranted {
                        (NSApp.delegate as? AppDelegate)?.setupEventTap()
                    }
                }
                HStack {
                    Image(
                        systemName: screenRecordingGranted
                            ? "checkmark.circle.fill" : "xmark.circle.fill"
                    )
                    .foregroundStyle(screenRecordingGranted ? .green : .red)
                    Text(
                        screenRecordingGranted ? "Screen recording permissions granted" : "Screen recording permissions not granted"
                    )
                    Spacer()
                    if !screenRecordingGranted {
                        Button("Request") {
                            let granted = CGRequestScreenCaptureAccess()
                            if !granted {
                                let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture")!
                                NSWorkspace.shared.open(url)
                            }
                        }
                    }
                }
            } header: {
                InfoTipHeader(
                    title: "Permissions",
                    tip: "Sxitch needs Accessibility to intercept the hotkey and switch apps, and Screen Recording to read app windows."
                )
            }

            Section {
                HStack {
                    Toggle("Launch at login", isOn: $isLaunchAtLoginEnabled)
                        .onChange(of: isLaunchAtLoginEnabled) { oldValue, newValue in
                            do {
                                if newValue {
                                    try SMAppService.mainApp.register()
                                } else {
                                    try SMAppService.mainApp.unregister()
                                }
                            } catch {
                                print(
                                    "Failed to update login item state: \(error.localizedDescription)"
                                )
                                isLaunchAtLoginEnabled = oldValue
                            }
                        }
                    SettingInfoTip(text: "Start Sxitch automatically when you log in to this Mac.")
                }
            }

            Section {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 4) {
                            Text("Revisit the setup guide")
                                .fontWeight(.medium)
                            SettingInfoTip(text: "Walk through permissions and usage tips again.")
                        }
                    }
                    Spacer()
                    Button("Open Guide") {
                        hasCompletedOnboarding = false
                        openWindow(id: "onboarding")
                        NotificationCenter.default.post(name: .onboardingRestarted, object: nil)
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
        .formStyle(.grouped)
    }
}
