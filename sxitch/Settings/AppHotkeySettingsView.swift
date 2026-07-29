import AppKit
import Combine
import KeyboardShortcuts
import SwiftUI

struct AppHotkeySettingsView: View {
    @State private var hotkeys: AppHotkeys = UserDefaults.standard.appHotkeys
    @State private var isRecording = false
    @State private var recordingMonitor: Any? = nil

    @State private var chosenBundleId: String = ""
    @State private var pendingKeyLabel: String? = nil
    @State private var pendingKeyCode: String? = nil
    @State private var chosenBundleURL: String = ""

    @State private var runningApps = NSWorkspace.shared.runningApplications
        .filter { $0.activationPolicy == .regular }

    @State private var openApps = RunningApp.fetchRunningApps()

    let keyCodeToChar: [Int64: String] = [
        0: "A", 11: "B", 8: "C", 2: "D", 14: "E", 3: "F", 5: "G",
        4: "H", 34: "I", 38: "J", 40: "K", 37: "L", 46: "M", 45: "N",
        31: "O", 35: "P", 12: "Q", 15: "R", 1: "S", 17: "T", 32: "U",
        9: "V", 13: "W", 7: "X", 16: "Y", 6: "Z",
    ]

    var body: some View {
        Section(
            header: Text("App Launch Hotkeys"),
            footer: Text("Shortcuts will launch the app even if it's not running.")
        ) {
            ForEach(Array(hotkeys.keys.sorted()), id: \.self) { bundleURL in
                HStack {
                    Text(appName(for: bundleURL))
                    Spacer()
                    KeyboardShortcuts.Recorder(for: .appLaunch(bundleURL))
                    Button(role: .destructive) {
                        KeyboardShortcuts.reset(.appLaunch(bundleURL))
                        hotkeys.removeValue(forKey: bundleURL)
                        save()
                    } label: {
                        Image(systemName: "trash")
                    }
                    .buttonStyle(.borderless)
                }
            }

            HStack {
                Picker("App", selection: $chosenBundleURL) {
                    Text("Select an app…").tag("")
                    ForEach(runningApps, id: \.bundleURL) { app in
                        Text(app.localizedName ?? "Unknown")
                            .tag(app.bundleURL?.absoluteString ?? "")
                    }
                }

                Button("Add") {
                    guard !chosenBundleURL.isEmpty else { return }
                    NotificationCenter.default.post(name: .appHotkeyAdded, object: chosenBundleURL)
                    hotkeys[chosenBundleURL] = chosenBundleURL
                    UserDefaults.standard.appHotkeys = hotkeys
                    chosenBundleURL = ""
                }
                .disabled(chosenBundleURL.isEmpty)
            }
        }
        .onReceive(
            NSWorkspace.shared.notificationCenter
                .publisher(for: NSWorkspace.didLaunchApplicationNotification)
                .merge(
                    with: NSWorkspace.shared.notificationCenter
                        .publisher(for: NSWorkspace.didTerminateApplicationNotification)
                )
        ) { _ in
            runningApps = NSWorkspace.shared.runningApplications
                .filter { $0.activationPolicy == .regular }
        }
        .onReceive(
            NSWorkspace.shared.notificationCenter
                .publisher(for: NSWorkspace.didDeactivateApplicationNotification)
                .merge(
                    with: NSWorkspace.shared.notificationCenter
                        .publisher(for: NSWorkspace.didTerminateApplicationNotification)
                )
        ) { _ in
            runningApps = NSWorkspace.shared.runningApplications
                .filter { $0.activationPolicy == .regular }
        }
    }

    private func startRecording() {
        isRecording = true
        recordingMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            let keyCode = Int64(event.keyCode)
            pendingKeyCode = "\(keyCode)"
            pendingKeyLabel = keyCodeToChar[keyCode] ?? "?"
            stopRecording()
            return nil
        }
    }

    private func stopRecording() {
        isRecording = false
        if let monitor = recordingMonitor {
            NSEvent.removeMonitor(monitor)
            recordingMonitor = nil
        }
    }

    private func save() {
        UserDefaults.standard.appHotkeys = hotkeys
    }

    private func appName(for bundleURL: String) -> String {
        runningApps.first { $0.bundleURL?.absoluteString == bundleURL }?.localizedName ?? bundleURL
    }
}
