//
//  SettingsView.swift
//  sxitch
//
//  Created by Umang on 22/6/26.
//
import SwiftUI
import Combine

struct SettingsView: View {
    @AppStorage("hotkey_modifier") private var modifier: Int = 0  // 0 = ⌥, 1 = ⌘
    @AppStorage("hotkey_keycode") private var keycode: Int = 49   // Space
    @State private var accessibilityGranted: Bool = AXIsProcessTrusted()

    var body: some View {
        Form {
            Section("Hotkey") {
                Picker("Modifier", selection: $modifier) {
                    Text("⌥ Option").tag(0)
                    Text("⌘ Command").tag(1)
                }
                Picker("Key", selection: $keycode) {
                    Text("None").tag(256)
                    Text("Space").tag(49)
                    Text("Tab").tag(48)
                    Text("Return").tag(36)
                }
            }

            Section("Permissions") {
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
                    let wasGranted = accessibilityGranted
                    accessibilityGranted = AXIsProcessTrusted()
                    if !wasGranted && accessibilityGranted {
                        (NSApp.delegate as? AppDelegate)?.setupEventTap()
                    }
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 360)
        .padding()
    }
}
