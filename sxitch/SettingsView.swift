import SwiftUI
import Combine

struct SettingsView: View {
    @ObservedObject var config = AppConfig.shared

    var body: some View {
        TabView {
            generalTab
                .tabItem { Label("General", systemImage: "gearshape") }

            modesTab
                .tabItem { Label("Modes", systemImage: "arrow.triangle.branch") }
        }
        .frame(width: 420, height: 480)
    }

    private var generalTab: some View {
        Form {
            Section("Hotkey") {
                Picker("Modifier", selection: Binding.config(\.hotkeyModifier)) {
                    Text("⌥ Option").tag(0)
                    Text("⌘ Command").tag(1)
                    Text("⌃ Control").tag(2)
                    Text("⇧ Shift").tag(3)
                }
                Picker("Key", selection: Binding.config(\.hotkeyKeycode)) {
                    Text("None (modifier only)").tag(256)
                    Text("Space").tag(49)
                    Text("Tab").tag(48)
                    Text("Return").tag(36)
                    Text("Escape").tag(53)
                }
            }

            Section("Key Resolution Scheme") {
                Picker("Scheme", selection: Binding.config(\.keyScheme)) {
                    Text("Name Increment").tag("NameIncrement")
                    Text("Alphabets (a, b, c…)").tag("Alphabets")
                    Text("Numbers (1, 2, 3…)").tag("Numbers")
                    Text("Qwerty (q, w, e…)").tag("Qwerty")
                }
                .pickerStyle(.menu)

                Toggle("Show key badges", isOn: Binding.config(\.showKeys))
            }

            Section("Permissions") {
                PermissionRow()
            }
        }
        .formStyle(.grouped)
    }

    private var modesTab: some View {
        Form {
            Section("Quit Mode") {
                HStack {
                    Text("Hotkey")
                    Spacer()
                    KeyCaptureTextField(
                        modifier: Binding.config(\.quitModeModifier),
                        keycode: Binding.config(\.quitModeKeycode)
                    )
                    .frame(width: 100)
                }
                Text("Press to enter Quit mode. Then select an app to terminate it.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Hide Mode") {
                HStack {
                    Text("Hotkey")
                    Spacer()
                    KeyCaptureTextField(
                        modifier: Binding.config(\.hideModeModifier),
                        keycode: Binding.config(\.hideModeKeycode)
                    )
                    .frame(width: 100)
                }
                Text("Press to enter Hide mode. Then select an app to hide it.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Normal Mode") {
                HStack {
                    Text("Hotkey")
                    Spacer()
                    KeyCaptureTextField(
                        modifier: Binding.config(\.normalModeModifier),
                        keycode: Binding.config(\.normalModeKeycode)
                    )
                    .frame(width: 100)
                }
                Text("Return to Normal mode (switch/focus apps).")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }
}

struct PermissionRow: View {
    @State private var accessibilityGranted = AXIsProcessTrusted()

    var body: some View {
        HStack {
            Image(systemName: accessibilityGranted ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundStyle(accessibilityGranted ? .green : .red)
            Text(accessibilityGranted ? "Accessibility granted" : "Accessibility not granted")
            Spacer()
            if !accessibilityGranted {
                Button("Request") {
                    let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true] as CFDictionary
                    AXIsProcessTrustedWithOptions(options)
                }
            }
        }
        .onReceive(Timer.publish(every: 1, on: .main, in: .common).autoconnect()) { _ in
            accessibilityGranted = AXIsProcessTrusted()
        }
    }
}
