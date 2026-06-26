import SwiftUI
import Combine
import ServiceManagement

struct SettingsView: View {
    @State private var selectedTab: SettingsTab = .general
    @State private var columnVisibility: NavigationSplitViewVisibility = .all
    
    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            List(SettingsTab.allCases, selection: $selectedTab) { tab in
                Label(tab.title, systemImage: tab.icon).tag(tab)
            }
        } detail: {
            switch selectedTab {
            case .general:
                GeneralSettingsView()
            case .advanced:
                AdvancedSettingsView()
            case .theme:
                ThemeSettingsView()
            }
        }
    }
}

enum SettingsTab: String, CaseIterable, Identifiable, Hashable {
    case general
    case theme
    case advanced
    
    var id: String { self.rawValue }
    
    var title: String {
        switch self {
        case .general: "General"
        case .theme: "Theme"
        case .advanced: "Advanced"
        }
    }
    
    var icon: String {
        switch self {
        case .general: "gear"
        case .theme: "paintpalette.fill"
        case .advanced: "slider.horizontal.3"
        }
    }
}

struct GeneralSettingsView: View {
    @AppStorage("launchAtLogin") private var launchAtLogin: Bool = false
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
    @AppStorage("prefixStrips") var prefixStrip: [String] = ["microsoft", "adobe"]

    var body: some View {
        Form {
            ManagedListSection(
                addHeader: "Blacklist Apps",
                listHeader: "Blacklisted Apps",
                emptyMessage: "No apps blacklisted yet.",
                placeholder: "App name",
                items: $blacklist
            )
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
