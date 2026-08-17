import Combine
import KeyboardShortcuts
import ServiceManagement
import SwiftUI

struct GeneralSettingsView: View, SettingsTab {
    static let tabID = "general"
    static let tabTitle = "General"
    static let tabIcon = "gear"

    @AppStorage("launchAtLogin") private var launchAtLogin: Bool = true
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding: Bool = false
    @AppStorage("windowPickerEnabled") private var windowPickerEnabled: Bool = true
    @AppStorage("showPickerUi") private var showUi = true
    @Environment(\.openWindow) private var openWindow
    private var usState = userState.shared
    @State private var accessibilityGranted: Bool = AXIsProcessTrusted()
    @State private var isLaunchAtLoginEnabled: Bool = SMAppService.mainApp.status == .enabled

    @AppStorage("hotkey_modifier_config") private var modifierConfig: String = "1:right"
    @AppStorage("hotkey_keycode") private var keycode: Int = 49

    @State private var overrides: [String: String] = UserDefaults.standard.keyOverrides
    @State private var newOverrideOriginal: String = ""
    @State private var newOverrideTo: String = ""

    private func stateFor(family: Int, side: String) -> Int {
        for entry in modifierConfig.split(separator: ",") {
            let parts = entry.split(separator: ":")
            guard parts.count == 2, let f = Int(parts[0]), f == family else { continue }
            let s = String(parts[1])
            if s == side { return 1 }
            if s == "either" { return 2 }
        }
        return 0
    }

    private func cycleKey(family: Int, side: String) {
        let current = stateFor(family: family, side: side)
        var entries = modifierConfig.split(separator: ",").compactMap { entry -> (Int, String)? in
            let parts = entry.split(separator: ":")
            guard parts.count == 2, let f = Int(parts[0]) else { return nil }
            return (f, String(parts[1]))
        }
        entries.removeAll { $0.0 == family }
        if current == 0 {
            entries.append((family, side))
        } else if current == 1 {
            entries.append((family, "either"))
        }
        modifierConfig = entries.map { "\($0.0):\($0.1)" }.joined(separator: ",")
    }

    private let keyNames: [Int: String] = [0: "Option", 1: "Command", 2: "Shift", 3: "Control"]
    private let keySymbols: [Int: String] = [0: "⌥", 1: "⌘", 2: "⇧", 3: "⌃"]

    @ViewBuilder
    private func keyboardKeyView(family: Int, side: String, width: CGFloat? = nil) -> some View {
        let accent = resolvedAccentColor(from: UserDefaults.standard.string(forKey: "accentColorHex") ?? "system") ?? .accentColor
        let stateVal = stateFor(family: family, side: side)
        let symbol = keySymbols[family] ?? ""
        let name = keyNames[family] ?? ""
        let modeText: String = {
            switch stateVal {
            case 0: return "off"
            case 1: return side == "left" ? "◀" : "▶"
            case 2: return "⇔"
            default: return ""
            }
        }()
        Button {
            cycleKey(family: family, side: side)
        } label: {
            VStack(spacing: 0) {
                Text(symbol)
                    .font(.system(size: 13, weight: .semibold))
                    .lineLimit(1)
                Text(name)
                    .font(.system(size: 8, weight: .medium))
                    .lineLimit(1)
                Text(modeText)
                    .font(.system(size: 7, weight: .bold))
                    .lineLimit(1)
                    .opacity(stateVal == 0 ? 0.35 : 1)
                    .padding(.top, 1)
            }
            .frame(minHeight: 44)
            .frame(maxWidth: width == nil ? .infinity : width)
            .padding(.horizontal, 6)
            .padding(.vertical, 5)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(stateVal == 0 ? Color(nsColor: .controlBackgroundColor) :
                        stateVal == 1 ? accent :
                        accent.opacity(0.12))
            )
            .foregroundColor(stateVal == 0 ? .primary :
                stateVal == 1 ? .white :
                accent)
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(stateVal == 0 ? Color(nsColor: .separatorColor).opacity(0.6) :
                        stateVal == 1 ? accent :
                        accent.opacity(0.6),
                        lineWidth: stateVal == 0 ? 0.5 : 2)
            )
        }
        .buttonStyle(.plain)
        .help(stateVal == 0 ? "\(name) — off" :
            stateVal == 1 ? "\(name) — \(side) only" :
            "\(name) — either")
    }

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
            }
            Section("Hotkey") {
                VStack(spacing: 5) {
                    HStack(spacing: 5) {
                        keyboardKeyView(family: 2, side: "left", width: 110)
                        Spacer()
                        keyboardKeyView(family: 2, side: "right", width: 110)
                    }
                    HStack(spacing: 5) {
                        keyboardKeyView(family: 3, side: "left", width: 60)
                        keyboardKeyView(family: 0, side: "left", width: 60)
                        keyboardKeyView(family: 1, side: "left", width: 90)
                        Text("space")
                            .font(.system(size: 10, weight: .regular))
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity, minHeight: 44)
                            .padding(.vertical, 5)
                            .background(
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(Color(nsColor: .controlBackgroundColor))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(Color(nsColor: .separatorColor).opacity(0.4), lineWidth: 0.5)
                            )
                        keyboardKeyView(family: 1, side: "right", width: 90)
                        keyboardKeyView(family: 0, side: "right", width: 60)
                    }
                }

                Picker("Key", selection: $keycode) {
                    Text("None").tag(256)
                    Text("Space").tag(49)
                    Text("Tab").tag(48)
                    Text("Return").tag(36)
                }
                .pickerStyle(.segmented)
            }
            Section("Mode Hotkeys") {
                HStack {
                    Text("Hide mode")
                    Spacer()
                    KeyboardShortcuts.Recorder(for: .hideMode)
                        .disabled(!usState.isPro)
                }
                HStack {
                    Text("Quit mode")
                    Spacer()
                    KeyboardShortcuts.Recorder(for: .quitMode)
                        .disabled(!usState.isPro)
                }
                HStack {
                    Text("Normal mode")
                    Spacer()
                    KeyboardShortcuts.Recorder(for: .normalMode)
                        .disabled(!usState.isPro)
                }
                if !usState.isPro {
                    HStack {
                        Label("Pro", systemImage: "lock.fill")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                    }
                }
                Text("While the switcher is open, the shortcut toggles the corresponding action mode.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Section {
                HStack {
                    Toggle("Window Picker", isOn: $windowPickerEnabled)
                        .disabled(!usState.isPro)
                    if !usState.isPro {
                        Spacer()
                        Label("Pro", systemImage: "lock.fill")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                if !usState.isPro {
                    Text("Upgrade to Pro to pick individual windows when an app has multiple open.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Section("Key Overrides") {
                if !usState.isPro {
                    HStack {
                        Label("Pro", systemImage: "lock.fill")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                    }
                }
                Text("Override the key that selects an app. Pressing the original key will select apps starting with the override letter instead.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                HStack {
                    TextField("Original", text: $newOverrideOriginal)
                        .textFieldStyle(.roundedBorder)
                        .disabled(!usState.isPro)
                    TextField("Override", text: $newOverrideTo)
                        .textFieldStyle(.roundedBorder)
                        .disabled(!usState.isPro)
                    Button("Add", systemImage: "plus") { addOverride() }
                        .disabled(!usState.isPro || newOverrideOriginal.trimmingCharacters(in: .whitespaces).count != 1 || newOverrideTo.trimmingCharacters(in: .whitespaces).isEmpty)
                }

                if overrides.isEmpty {
                    Text("No overrides configured yet.")
                        .foregroundStyle(.secondary)
                        .font(.callout)
                        .italic()
                        .frame(maxWidth: .infinity, minHeight: 60, alignment: .center)
                } else {
                    ForEach(Array(overrides.keys.sorted()), id: \.self) { original in
                        HStack {
                            Text(original.uppercased())
                                .font(.system(size: 13, weight: .semibold))
                                .frame(width: 24, height: 24)
                                .background(Color(nsColor: .controlBackgroundColor))
                                .clipShape(RoundedRectangle(cornerRadius: 4))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 4)
                                        .stroke(Color(nsColor: .separatorColor).opacity(0.4), lineWidth: 0.5)
                                )

                            Image(systemName: "arrow.right")
                                .font(.caption)
                                .foregroundStyle(.secondary)

                            Text(overrides[original]!.uppercased())
                                .font(.system(size: 13, weight: .semibold))

                            Spacer()

                            Button(role: .destructive) {
                                overrides.removeValue(forKey: original)
                                saveOverrides()
                            } label: {
                                Image(systemName: "trash")
                            }
                            .buttonStyle(.borderless)
                            .disabled(!usState.isPro)
                        }
                        .padding(.vertical, 2)
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
            }

            Section {
                Toggle("Show picker UI", isOn: $showUi)
                    .onChange(of: showUi) { oldValue, newValue in
                        showUi = newValue
                    }
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
        .onAppear {
            if UserDefaults.standard.object(forKey: "hotkey_modifier_config") == nil {
                let oldStr = UserDefaults.standard.string(forKey: "hotkey_modifiers") ?? ""
                if oldStr.isEmpty {
                    let oldValue = UserDefaults.standard.integer(forKey: "hotkey_modifier")
                    if oldValue > 0 {
                        let family: Int = {
                            switch oldValue {
                            case 58, 61: return 0
                            case 55, 54: return 1
                            case 56, 60: return 2
                            case 59, 62: return 3
                            case 57: return 4
                            default: return 0
                            }
                        }()
                        let rightCodes = [61, 54, 60, 62, 57]
                        let side = oldValue == rightCodes[family] ? "right" : "left"
                        let sided = UserDefaults.standard.bool(forKey: "hotkey_sided")
                        modifierConfig = "\(family):\(sided ? side : "either")"
                    }
                } else {
                    let entries = oldStr.split(separator: ",").compactMap { Int($0.trimmingCharacters(in: .whitespaces)) }.map { code -> String in
                        let family: Int = {
                            switch code {
                            case 58, 61: return 0
                            case 55, 54: return 1
                            case 56, 60: return 2
                            case 59, 62: return 3
                            case 57: return 4
                            default: return 0
                            }
                        }()
                        let rightCodes = [61, 54, 60, 62, 57]
                        let side = code == rightCodes[family] ? "right" : "left"
                        return "\(family):\(side)"
                    }
                    modifierConfig = entries.joined(separator: ",")
                }
            }
        }
    }

    private func addOverride() {
        let original = newOverrideOriginal.trimmingCharacters(in: .whitespaces).lowercased()
        let override = newOverrideTo.trimmingCharacters(in: .whitespaces).lowercased()
        guard original.count == 1, !override.isEmpty, original != override else { return }
        overrides[original] = override
        saveOverrides()
        newOverrideOriginal = ""
        newOverrideTo = ""
    }

    private func saveOverrides() {
        UserDefaults.standard.keyOverrides = overrides
    }
}
