import SwiftUI
import Combine

struct SettingsView: View {
    @AppStorage("hotkey_modifier") private var savedModifier: Int = 58
    @AppStorage("hotkey_keycode") private var keycode: Int = 49
    @AppStorage("hotkey_sided") private var hotkeySided: Bool = false
    @State private var accessibilityGranted: Bool = AXIsProcessTrusted()
    
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
