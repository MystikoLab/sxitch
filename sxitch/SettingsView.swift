import SwiftUI
import Combine
import ServiceManagement

struct SettingsView: View {
    private var usState = userState.shared
    var systemimg = if userState.shared.isPro {
        "lock.open"
    } else {
        "lock"
    }
    var body: some View {
        TabView {
            Tab("General", systemImage: "gear") {
                GeneralSettingsView()
            }
            Tab("Theme", systemImage: "paintpalette.fill") {
                ThemeSettingsView()
            }
            Tab("Activate", systemImage: systemimg) {
                ActivateSettingsView()
            }
            Tab("Advanced", systemImage: "slider.horizontal.3") {
                AdvancedSettingsView()
            }
        }
        .frame(width: 800, height: 600)
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
    
    var icon: String {
        switch self {
        case .general: "gear"
        case .theme: "paintpalette.fill"
        case .advanced: "slider.horizontal.3"
        case .activate: "lock"
        }
    }
}

struct GeneralSettingsView: View {
    @AppStorage("launchAtLogin") private var launchAtLogin: Bool = true
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
        case 57:     return 4
        default:     return 0
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
            Section("Hotkey") {
                Picker("Modifier", selection: Binding(
                    get: { selectedFamily },
                    set: { newFamily in
                        savedModifier = hotkeySided
                        ? (savedModifier == rightKeycode(for: selectedFamily)
                           ? rightKeycode(for: newFamily)
                           : leftKeycode(for: newFamily))
                        : leftKeycode(for: newFamily)
                    }
                )) {
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
                    Picker("Side", selection: Binding(
                        get: { savedModifier == rightKeycode(for: selectedFamily) ? 1 : 0 },
                        set: { side in
                            savedModifier = side == 0
                            ? leftKeycode(for: selectedFamily)
                            : rightKeycode(for: selectedFamily)
                        }
                    )) {
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
                            print("Failed to update login item state: \(error.localizedDescription)")
                            isLaunchAtLoginEnabled = oldValue
                        }
                    }
            }
        }
        .padding()
        .formStyle(.grouped)
    }
}

struct ThemeSettingsView: View {
    @AppStorage("showMenuIcon") var showMenuIcon: Bool = true

    var body: some View {
        Form {
            Section {
                Toggle(isOn: $showMenuIcon) {
                    Text("Show menubar icon")
                }
            }
        }
        .padding()
        .formStyle(.grouped)
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
                        Button(role: .destructive) { remove(item) } label: {
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
    @AppStorage("prefixStrips") var prefixStrip: [String] = ["microsoft", "adobe"];
    
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
                    footer: Text("Enter the license key received upon purchase to unlock Pro features.")
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
                    .disabled(licenseKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isActivating)
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
