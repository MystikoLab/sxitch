import Combine
import CoreGraphics
import ServiceManagement
import SwiftUI

struct GeneralSettingsView: View, SettingsTab {
    static let tabID = "general"
    static let tabTitle = "General"
    static let tabIcon = "gear"

    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding: Bool = false
    @AppStorage("showMenuIcon") private var showMenuIcon: Bool = true
    @Environment(\.openWindow) private var openWindow
    private var usState = userState.shared
    @State private var accessibilityGranted: Bool = AXIsProcessTrusted()
    @State private var screenRecordingGranted: Bool = CGPreflightScreenCaptureAccess()
    @State private var isLaunchAtLoginEnabled: Bool = SMAppService.mainApp.status == .enabled

    var body: some View {
        Form {
            Section("Permissions") {
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
            }

            Section {
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
                Toggle("Show menu bar icon", isOn: $showMenuIcon)
            }

            Section("Setup") {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Revisit the setup guide")
                            .fontWeight(.medium)
                        Text("Walk through permissions and usage tips again.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button("Open Guide") {
                        hasCompletedOnboarding = false
                        openWindow(id: "onboarding")
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
        .padding()
        .formStyle(.grouped)
    }
}
