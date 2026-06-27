import Combine
import KeyboardShortcuts
import ServiceManagement
import SwiftUI

// When the user adds a hotkey, register a name dynamically
extension KeyboardShortcuts.Name {
    static func appLaunch(_ bundleURL: String) -> Self {
        .init("appLaunch_\(bundleURL)")
    }
}

extension Notification.Name {
    static let appHotkeyAdded = Notification.Name("appHotkeyAdded")
    static let onboardingCompleted = Notification.Name("onboardingCompleted")
}

struct SettingsView: View {
    private var usState = userState.shared
    @AppStorage("accentColorHex") var accentColorHex: String = "system"
    @State private var selectedTab: SettingsTab = .general

    var accentColor: Color { resolvedAccentColor(from: accentColorHex) ?? .accentColor }

    var body: some View {
        VStack(spacing: 0) {
            // Custom tab bar — responds to accent colour
            HStack(spacing: 0) {
                ForEach(SettingsTab.allCases) { tab in
                    Button {
                        selectedTab = tab
                    } label: {
                        VStack(spacing: 5) {
                            Image(systemName: tab.icon(isPro: usState.isPro))
                                .font(.system(size: 20))
                            Text(tab.title)
                                .font(.caption)
                        }
                        .foregroundStyle(selectedTab == tab ? accentColor : .secondary)
                        .frame(minWidth: 80)
                        .padding(.vertical, 10)
                        .background(
                            selectedTab == tab
                                ? accentColor.opacity(0.12)
                                : Color.clear,
                            in: RoundedRectangle(cornerRadius: 8)
                        )
                        .animation(
                            .spring(response: 0.25, dampingFraction: 0.7), value: selectedTab)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity)
            .background(.bar)

            Divider()

            // Tab content
            Group {
                switch selectedTab {
                case .general: GeneralSettingsView()
                case .theme: ThemeSettingsView()
                case .activate: ActivateSettingsView()
                case .advanced: AdvancedSettingsView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(width: 800, height: 600)
        .tint(accentColor)
        .onAppear {
            DispatchQueue.main.async {
                guard let window = NSApp.keyWindow else { return }
                window.standardWindowButton(.closeButton)?.isHidden = true
                window.standardWindowButton(.miniaturizeButton)?.isHidden = true
                window.standardWindowButton(.zoomButton)?.isHidden = true
            }
        }
    }
}

enum SettingsTab: String, CaseIterable, Identifiable, Hashable {
    case general
    case theme
    case advanced
    case activate

    var id: String { self.rawValue }

    var title: String {
        switch self {
        case .general: "General"
        case .theme: "Theme"
        case .advanced: "Advanced"
        case .activate: "Activate"
        }
    }

    var icon: String { icon(isPro: false) }

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
    @Environment(\.openWindow) private var openWindow
    @State private var accessibilityGranted: Bool = AXIsProcessTrusted()
    @State private var isLaunchAtLoginEnabled: Bool = {
        SMAppService.mainApp.status == .enabled
    }()

    @AppStorage("hotkey_modifier") private var savedModifier: Int = 58
    @AppStorage("hotkey_keycode") private var keycode: Int = 49
    @AppStorage("hotkey_sided") private var hotkeySided: Bool = false

    private var selectedFamily: Int {
        switch savedModifier {
        case 58, 61: return 0
        case 55, 54: return 1
        case 56, 60: return 2
        case 59, 62: return 3
        case 57: return 4
        default: return 0
        }
    }

    private func leftKeycode(for family: Int) -> Int {
        switch family {
        case 0: return 58
        case 1: return 55
        case 2: return 56
        case 3: return 59
        case 4: return 57
        default: return 58
        }
    }

    private func rightKeycode(for family: Int) -> Int {
        switch family {
        case 0: return 61
        case 1: return 54
        case 2: return 60
        case 3: return 62
        case 4: return 57
        default: return 61
        }
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
                Picker(
                    "Modifier",
                    selection: Binding(
                        get: { selectedFamily },
                        set: { newFamily in
                            savedModifier =
                                hotkeySided
                                ? (savedModifier == rightKeycode(for: selectedFamily)
                                    ? rightKeycode(for: newFamily)
                                    : leftKeycode(for: newFamily))
                                : leftKeycode(for: newFamily)
                        }
                    )
                ) {
                    Text("⌥ Option").tag(0)
                    Text("⌘ Command").tag(1)
                    Text("⇧ Shift").tag(2)
                    Text("⌃ Control").tag(3)
                    Text("⇪ Caps Lock").tag(4)
                }

                Toggle("Sided", isOn: $hotkeySided)
                    .onChange(of: hotkeySided) { _, newSided in
                        if !newSided {
                            savedModifier = leftKeycode(for: selectedFamily)
                        }
                    }

                if hotkeySided {
                    Picker(
                        "Side",
                        selection: Binding(
                            get: { savedModifier == rightKeycode(for: selectedFamily) ? 1 : 0 },
                            set: { side in
                                savedModifier =
                                    side == 0
                                    ? leftKeycode(for: selectedFamily)
                                    : rightKeycode(for: selectedFamily)
                            }
                        )
                    ) {
                        Text("Left").tag(0)
                        Text("Right").tag(1)
                    }
                    .pickerStyle(.segmented)
                }

                Picker("Key", selection: $keycode) {
                    Text("None").tag(256)
                    Text("Space").tag(49)
                    Text("Tab").tag(48)
                    Text("Return").tag(36)
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
                                "Failed to update login item state: \(error.localizedDescription)")
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
                Int((ns.redComponent.clamped(to: 0...1) * 255).rounded()),
                Int((ns.greenComponent.clamped(to: 0...1) * 255).rounded()),
                Int((ns.blueComponent.clamped(to: 0...1) * 255).rounded())
            )
        }
        if let ns = NSColor(self).usingColorSpace(.deviceRGB) {
            return String(
                format: "%02X%02X%02X",
                Int((ns.redComponent.clamped(to: 0...1) * 255).rounded()),
                Int((ns.greenComponent.clamped(to: 0...1) * 255).rounded()),
                Int((ns.blueComponent.clamped(to: 0...1) * 255).rounded())
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
                Int((c[0].clamped(to: 0...1) * 255).rounded()),
                Int((c[1].clamped(to: 0...1) * 255).rounded()),
                Int((c[2].clamped(to: 0...1) * 255).rounded())
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
                            lineWidth: isSelected ? 2.5 : 1)
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

// MARK: - Cleaned up AdvancedSettingsView
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

    let runningApps = NSWorkspace.shared.runningApplications
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
                        "Enter the license key received upon purchase to unlock Pro features.")
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
                            || isActivating)
                }
            }
        }
        .padding()
        .formStyle(.grouped)  // Enforces matching macOS Settings style architecture
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
