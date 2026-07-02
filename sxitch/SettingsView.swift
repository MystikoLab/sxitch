import Combine
import KeyboardShortcuts
import ServiceManagement
import SwiftUI

/// When the user adds a hotkey, register a name dynamically
extension KeyboardShortcuts.Name {
    static func appLaunch(_ bundleURL: String) -> Self {
        .init("appLaunch_\(bundleURL)")
    }
}

extension Notification.Name {
    static let appHotkeyAdded = Notification.Name("appHotkeyAdded")
    static let onboardingCompleted = Notification.Name("onboardingCompleted")
    static let switcherWillShow = Notification.Name("sxitch.switcherWillShow")
}

struct SettingsView: View {
    private var usState = userState.shared
    @AppStorage("accentColorHex") var accentColorHex: String = "system"
    @State private var selectedTab: SettingsTab = .general

    var accentColor: Color {
        resolvedAccentColor(from: accentColorHex) ?? .accentColor
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            GeneralSettingsView()
                .tabItem {
                    Label("General", systemImage: SettingsTab.general.icon)
                }
                .tag(SettingsTab.general)

            ThemeSettingsView()
                .tabItem {
                    Label("Theme", systemImage: SettingsTab.theme.icon)
                }
                .tag(SettingsTab.theme)

            AdvancedSettingsView()
                .tabItem {
                    Label("Advanced", systemImage: SettingsTab.advanced.icon)
                }
                .tag(SettingsTab.advanced)

            ActivateSettingsView()
                .tabItem {
                    Label("Activate", systemImage: usState.isPro ? "lock.open" : "lock")
                }
                .tag(SettingsTab.activate)
        }
        .onAppear {
            if let window = NSApp.mainWindow {
                window.level = .floating
            }

        }
        .frame(width: 800, height: 600)
        .tint(accentColor)
    }
}

enum SettingsTab: String, CaseIterable, Identifiable, Hashable {
    case general
    case theme
    case advanced
    case activate

    var id: String {
        rawValue
    }

    var title: String {
        switch self {
        case .general: "General"
        case .theme: "Theme"
        case .advanced: "Advanced"
        case .activate: "Activate"
        }
    }

    var icon: String {
        icon(isPro: false)
    }

    func icon(isPro: Bool) -> String {
        switch self {
        case .general: "gear"
        case .theme: "paintpalette.fill"
        case .advanced: "slider.horizontal.3"
        case .activate: isPro ? "lock.open" : "lock"
        }
    }
}

struct GeneralSettingsView: View {
    @AppStorage("launchAtLogin") private var launchAtLogin: Bool = true
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding: Bool = false
    @AppStorage("windowPickerEnabled") private var windowPickerEnabled: Bool = true
    @Environment(\.openWindow) private var openWindow
    private var usState = userState.shared
    @State private var accessibilityGranted: Bool = AXIsProcessTrusted()
    @State private var isLaunchAtLoginEnabled: Bool = SMAppService.mainApp.status == .enabled

    @AppStorage("hotkey_modifier_config") private var modifierConfig: String = "1:right"
    @AppStorage("hotkey_keycode") private var keycode: Int = 49

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
}

// MARK: - Helpers

extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}

// MARK: - Accent colour helpers

extension Color {
    init?(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        guard hex.count == 6 else { return nil }
        var value: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&value)
        self.init(
            red: Double((value >> 16) & 0xFF) / 255,
            green: Double((value >> 8) & 0xFF) / 255,
            blue: Double(value & 0xFF) / 255
        )
    }

    var hexString: String {
        // Try sRGB first; fall back to deviceRGB; then read raw CGColor components
        if let ns = NSColor(self).usingColorSpace(.sRGB) {
            return String(
                format: "%02X%02X%02X",
                Int((ns.redComponent.clamped(to: 0 ... 1) * 255).rounded()),
                Int((ns.greenComponent.clamped(to: 0 ... 1) * 255).rounded()),
                Int((ns.blueComponent.clamped(to: 0 ... 1) * 255).rounded())
            )
        }
        if let ns = NSColor(self).usingColorSpace(.deviceRGB) {
            return String(
                format: "%02X%02X%02X",
                Int((ns.redComponent.clamped(to: 0 ... 1) * 255).rounded()),
                Int((ns.greenComponent.clamped(to: 0 ... 1) * 255).rounded()),
                Int((ns.blueComponent.clamped(to: 0 ... 1) * 255).rounded())
            )
        }
        // Last resort: pull from CGColor
        let cg = NSColor(self).cgColor
        let cs = CGColorSpace(name: CGColorSpace.sRGB)!
        if let converted = cg.converted(to: cs, intent: .defaultIntent, options: nil),
           let c = converted.components, c.count >= 3
        {
            return String(
                format: "%02X%02X%02X",
                Int((c[0].clamped(to: 0 ... 1) * 255).rounded()),
                Int((c[1].clamped(to: 0 ... 1) * 255).rounded()),
                Int((c[2].clamped(to: 0 ... 1) * 255).rounded())
            )
        }
        return "0000FF"
    }
}

func resolvedAccentColor(from hex: String) -> Color? {
    guard hex != "system" else { return nil }
    return Color(hex: hex)
}

// MARK: - Theme Settings

struct ThemeSettingsView: View {
    @AppStorage("showMenuIcon") var showMenuIcon: Bool = true
    @AppStorage("accentColorHex") var accentColorHex: String = "system"
    @AppStorage("layoutStyle") var layoutStyle: String = "grid"

    private let presets: [(name: String, color: Color)] = [
        ("Blue", .blue),
        ("Purple", .purple),
        ("Pink", .pink),
        ("Red", .red),
        ("Orange", .orange),
        ("Yellow", .yellow),
        ("Green", .green),
        ("Mint", .mint),
        ("Teal", .teal),
        ("Indigo", .indigo),
    ]

    var body: some View {
        Form {
            Section {
                Toggle(isOn: $showMenuIcon) {
                    Text("Show menubar icon")
                }
            }

            Section("Layout") {
                Picker("View Style", selection: $layoutStyle) {
                    Label("Grid", systemImage: "square.grid.2x2").tag("grid")
                    Label("List", systemImage: "list.bullet").tag("list")
                }
                .pickerStyle(.segmented)
            }

            Section("Accent Colour") {
                HStack(spacing: 10) {
                    // System default
                    AccentSwatch(
                        label: "System",
                        isSelected: accentColorHex == "system"
                    ) {
                        ZStack {
                            Circle().fill(
                                AngularGradient(
                                    colors: [
                                        .blue, .purple, .pink, .red, .orange, .yellow, .green,
                                        .blue,
                                    ],
                                    center: .center
                                )
                            )
                        }
                    } onTap: {
                        accentColorHex = "system"
                    }

                    // Preset colours
                    ForEach(presets, id: \.name) { preset in
                        AccentSwatch(
                            label: preset.name,
                            isSelected: accentColorHex == preset.color.hexString
                        ) {
                            Circle().fill(preset.color)
                        } onTap: {
                            accentColorHex = preset.color.hexString
                        }
                    }
                }
                .padding(.vertical, 4)
            }
        }
        .padding()
        .formStyle(.grouped)
    }
}

struct AccentSwatch<Swatch: View>: View {
    let label: String
    let isSelected: Bool
    @ViewBuilder let swatch: () -> Swatch
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            swatch()
                .frame(width: 28, height: 28)
                .clipShape(Circle())
                .overlay(
                    Circle()
                        .strokeBorder(
                            Color.primary.opacity(isSelected ? 0.9 : 0.15),
                            lineWidth: isSelected ? 2.5 : 1
                        )
                )
                .overlay(
                    Image(systemName: "checkmark")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.white)
                        .shadow(radius: 1)
                        .opacity(isSelected ? 1 : 0)
                )
                .scaleEffect(isSelected ? 1.15 : 1)
                .animation(.spring(response: 0.25, dampingFraction: 0.7), value: isSelected)
        }
        .buttonStyle(.plain)
        .help(label)
    }
}

struct ManagedListSection: View {
    let addHeader: String
    let listHeader: String
    let emptyMessage: String
    let placeholder: String

    @Binding var items: [String]
    @State private var newEntry: String = ""

    var body: some View {
        Section(header: Text(addHeader)) {
            HStack {
                TextField(placeholder, text: $newEntry)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit { addItem() }
                Button("Add", systemImage: "plus") { addItem() }
                    .disabled(newEntry.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }

        Section(header: Text(listHeader)) {
            if items.isEmpty {
                Text(emptyMessage)
                    .foregroundStyle(.secondary)
                    .font(.callout)
                    .italic()
                    .frame(maxWidth: .infinity, minHeight: 80, alignment: .center)
            } else {
                ForEach(items, id: \.self) { item in
                    HStack {
                        Text(item)
                        Spacer()
                        Button(role: .destructive) {
                            remove(item)
                        } label: {
                            Image(systemName: "trash")
                        }
                        .buttonStyle(.borderless)
                    }
                    .padding(.vertical, 4)
                }
            }
        }
    }

    private func addItem() {
        let clean = newEntry.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !clean.isEmpty, !items.contains(where: { $0.lowercased() == clean }) else { return }
        items.append(clean)
        newEntry = ""
    }

    private func remove(_ item: String) {
        items.removeAll { $0 == item }
    }
}

struct AdvancedSettingsView: View {
    @AppStorage("appBlacklists") var blacklist: [String] = []
    @AppStorage("prefixStrips") var prefixStrip: [String] = ["microsoft", "adobe"]

    private var appState = userState.shared

    var body: some View {
        Form {
            if appState.isPro {
                ManagedListSection(
                    addHeader: "Blacklist Apps",
                    listHeader: "Blacklisted Apps",
                    emptyMessage: "No apps blacklisted yet.",
                    placeholder: "App name",
                    items: $blacklist
                )
                AppHotkeySettingsView()
            }
            ManagedListSection(
                addHeader: "Strip Prefixes",
                listHeader: "Prefix Stripping",
                emptyMessage: "No prefixes added yet.",
                placeholder: "Prefix",
                items: $prefixStrip
            )
        }
        .padding()
        .formStyle(.grouped)
    }
}

struct AppHotkeySettingsView: View {
    @State private var hotkeys: AppHotkeys = UserDefaults.standard.appHotkeys

    @State private var isRecording = false
    @State private var recordingMonitor: Any? = nil

    // For the "add new" row
    @State private var chosenBundleId: String = ""
    @State private var pendingKeyLabel: String? = nil
    @State private var pendingKeyCode: String? = nil
    @State private var chosenBundleURL: String = ""

    @State private var runningApps = NSWorkspace.shared.runningApplications
        .filter { $0.activationPolicy == .regular }

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

struct ActivateSettingsView: View {
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
                } else {
                    HStack {
                        Image(systemName: "xmark.seal.fill")
                            .foregroundColor(.secondary)
                        Text("Free Version")
                            .font(.headline)
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
            }
        }
        .padding()
        .formStyle(.grouped) // Enforces matching macOS Settings style architecture
        .task {
            await appState.checkCurrentActivationStatus()
        }
    }

    // MARK: - Actions

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
