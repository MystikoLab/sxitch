import Combine
import SwiftUI

// MARK: - Settings Navigation Enum

enum SettingsNav: String, Identifiable, Hashable {
    case general = "General"
    case modes = "Modes"
    case themes = "Themes"
    case about = "About"
    case activate = "Activate"
    case advanced = "Advanced"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .general: return "gearshape"
        case .modes: return "arrow.triangle.branch"
        case .themes: return "paintbrush"
        case .about: return "info.circle"
        case .activate: return "key"
        case .advanced: return "terminal"
        }
    }

    /// Items shown in the sidebar — Advanced only in DEBUG builds.
    static var visible: [SettingsNav] {
        var list: [SettingsNav] = [.general, .modes, .themes, .about, .activate]
        #if DEBUG
            list.append(.advanced)
        #endif
        return list
    }
}

// MARK: - SettingsView

struct SettingsView: View {
    @ObservedObject var config = AppConfig.shared
    @ObservedObject var licenseManager = LicenseManager.shared

    /// Active sidebar selection — mirrors Rust's NavPage.
    /// Optional so SwiftUI's List(selection:) type-checks (expects Binding<Value?>).
    @State private var selectedNav: SettingsNav? = .general

    // Activate-tab local state
    @State private var licenseInput: String = ""
    @State private var showLicenseKey: Bool = false

    var body: some View {
        NavigationSplitView(columnVisibility: .constant(.all)) {
            sidebarContent
                .navigationSplitViewColumnWidth(min: 160, ideal: 180, max: 200)
        } detail: {
            detailContent
        }
        .frame(width: 680, height: 500)
        // Mirror Rust's Message::ActivateKey success branch:
        // Task::done(Message::SwitchToPage(Page::Settings(NavPage::General), wid))
        .onChange(of: licenseManager.isActivated) { _, activated in
            if activated {
                withAnimation { selectedNav = .general }
            }
        }
    }

    // MARK: - Sidebar

    private var sidebarContent: some View {
        // Must use List(selection:) + ForEach + .tag() together.
        // List(collection, id:, selection:) does NOT wire up the selection;
        // only explicit .tag(nav) on each row teaches SwiftUI which value to
        // write into the binding when a row is tapped.
        List(selection: $selectedNav) {
            ForEach(SettingsNav.visible) { nav in
                navRow(nav).tag(nav)
            }
        }
        .listStyle(.sidebar)
    }

    private func navRow(_ nav: SettingsNav) -> some View {
        HStack(spacing: 10) {
            Image(systemName: nav.icon)
                .frame(width: 18, alignment: .center)
                .foregroundStyle(nav == selectedNav ? Color.accentColor : Color.secondary)

            Text(nav.rawValue)
                .font(.system(size: 13))

            if nav == .activate {
                Spacer()
                // Mirror Rust tray icon: shows Pro/Free status indicator
                if config.isPro {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(.green)
                } else {
                    Text("FREE")
                        .font(.system(size: 8, weight: .medium))
                        .foregroundStyle(Color.secondary.opacity(0.7))
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(Color(NSColor.quaternaryLabelColor).opacity(0.4))
                        .clipShape(Capsule())
                }
            }
        }
    }

    // MARK: - Detail Router

    @ViewBuilder
    private var detailContent: some View {
        // selectedNav is Optional — coalesce to .general so there is always a
        // destination even before the first tap registers.
        switch selectedNav ?? .general {
        case .general: generalContent
        case .modes: modesContent
        case .themes: themesContent
        case .about: aboutContent
        case .activate: activateContent
        case .advanced: advancedContent
        }
    }

    // MARK: - General

    private var generalContent: some View {
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

            Section("Layout") {
                Picker("Layout", selection: Binding.config(\.layout)) {
                    Text("Grid").tag("Grid")
                    Text("List").tag("List")
                }
                .pickerStyle(.segmented)
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

            Section(header: proHeader("Screen Position")) {
                if config.isPro {
                    Picker("Position", selection: Binding.config(\.position)) {
                        Text("Default (above center)").tag("Default")
                        Divider()
                        Text("Top Left").tag("TopLeft")
                        Text("Top Center").tag("TopCenter")
                        Text("Top Right").tag("TopRight")
                        Divider()
                        Text("Middle Left").tag("MiddleLeft")
                        Text("Middle Center").tag("MiddleCenter")
                        Text("Middle Right").tag("MiddleRight")
                        Divider()
                        Text("Bottom Left").tag("BottomLeft")
                        Text("Bottom Center").tag("BottomCenter")
                        Text("Bottom Right").tag("BottomRight")
                    }
                    .pickerStyle(.menu)
                } else {
                    proGateRow("Screen Position") { selectedNav = .activate }
                }
            }

            Section("App Filtering") {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Skip prefixes (comma-separated)")
                        .font(.caption).foregroundStyle(.secondary)
                    TextField(
                        "e.g. microsoft,adobe",
                        text: Binding.config(\.skipPrefixesData)
                    )
                    .textFieldStyle(.squareBorder)
                }

                if config.isPro {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Blacklist bundle IDs (comma-separated)")
                            .font(.caption).foregroundStyle(.secondary)
                        TextField(
                            "e.g. com.apple.Safari",
                            text: Binding.config(\.blacklist)
                        )
                        .textFieldStyle(.squareBorder)
                    }
                } else {
                    proGateRow("Blacklist") { selectedNav = .activate }
                }
            }

            Section(header: proHeader("Key Overrides")) {
                if config.isPro {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Format: bundleID=key (comma-separated)")
                            .font(.caption).foregroundStyle(.secondary)
                        TextField(
                            "e.g. com.apple.Safari=s",
                            text: Binding.config(\.keyOverridesData)
                        )
                        .textFieldStyle(.squareBorder)
                    }
                } else {
                    proGateRow("Key Overrides") { selectedNav = .activate }
                }
            }

            Section(header: proHeader("Window Picking")) {
                if config.isPro {
                    Toggle(
                        "Show window picker when switching",
                        isOn: Binding.config(\.windowPicking))
                } else {
                    proGateRow("Window Picking") { selectedNav = .activate }
                }
            }

            Section("Startup & Display") {
                Toggle(
                    "Launch at Login",
                    isOn: Binding(
                        get: { config.openAtLogin },
                        set: { config.openAtLogin = $0 }
                    ))
                Toggle("Enable UI", isOn: Binding.config(\.enableUI))
            }

            Section("Permissions") {
                PermissionRow()
            }
        }
        .formStyle(.grouped)
    }

    // MARK: - Modes

    private var modesContent: some View {
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
                    .font(.caption).foregroundStyle(.secondary)
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
                    .font(.caption).foregroundStyle(.secondary)
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
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }

    // MARK: - Themes

    private var themesContent: some View {
        Form {
            Section("Appearance Mode") {
                Picker("Mode", selection: Binding.config(\.themeMode)) {
                    Text("Auto (Follow System)").tag("Auto")
                    Text("Light").tag("Light")
                    Text("Dark").tag("Dark")
                }
                .pickerStyle(.segmented)
            }

            Section("Light Theme") {
                Picker("Light Theme", selection: Binding.config(\.lightThemeName)) {
                    ForEach(AppTheme.allBuiltIn.filter { $0.family == .light }) { theme in
                        Label {
                            Text(theme.name)
                        } icon: {
                            Circle().fill(theme.primary).frame(width: 12, height: 12)
                        }
                        .tag(theme.id)
                    }
                }
                .pickerStyle(.menu)
                .disabled(config.themeMode == "Dark")
            }

            Section("Dark Theme") {
                Picker("Dark Theme", selection: Binding.config(\.darkThemeName)) {
                    ForEach(AppTheme.allBuiltIn.filter { $0.family == .dark }) { theme in
                        Label {
                            Text(theme.name)
                        } icon: {
                            Circle().fill(theme.primary).frame(width: 12, height: 12)
                        }
                        .tag(theme.id)
                    }
                }
                .pickerStyle(.menu)
                .disabled(config.themeMode == "Light")
            }

            Section("Window") {
                Toggle("Use native blur (recommended)", isOn: Binding.config(\.blur))
                Toggle("Show menu bar icon", isOn: Binding.config(\.trayIconVisible))
            }
        }
        .formStyle(.grouped)
    }

    // MARK: - About

    private var aboutContent: some View {
        VStack(spacing: 20) {
            Image(systemName: "arrow.left.arrow.right.square.fill")
                .font(.system(size: 64))
                .foregroundStyle(.blue)

            VStack(spacing: 6) {
                Text("Sxitch").font(.title2).bold()
                let version =
                    Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
                let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
                Text("Version \(version) (\(build))")
                    .font(.caption).foregroundStyle(.secondary)
            }

            Text("A blazing-fast keyboard-driven app switcher for macOS.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)

            Divider().padding(.horizontal, 60)

            VStack(spacing: 10) {
                SxitchLinkButton(title: "Homepage", url: "https://sxitch.app")
                SxitchLinkButton(title: "GitHub", url: "https://github.com/umangsurana/sxitch")
                SxitchLinkButton(title: "Community (Discord)", url: "https://discord.gg/sxitch")
                if !config.isPro {
                    SxitchLinkButton(
                        title: "Get Sxitch Pro", url: "https://sxitch.app/#pricing",
                        prominent: true)
                }
            }
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Activate
    //
    // Mirrors Rust's Message::StartKeyValidation → Message::ActivateKey flow.
    // On success: isActivated = true → .onChange navigates to .general.

    private var activateContent: some View {
        Group {
            if config.isPro {
                activatedView
            } else {
                activationFormView
            }
        }
    }

    private var activatedView: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 64))
                .foregroundStyle(.green)
            Text("Sxitch Pro Activated")
                .font(.title2).bold()
            Text("Thank you for supporting Sxitch!")
                .foregroundStyle(.secondary)
            Spacer()
            Button("Deactivate License") {
                LicenseManager.shared.deactivate()
            }
            .foregroundStyle(.red)
            .buttonStyle(.plain)
            .padding(.bottom, 16)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var activationFormView: some View {
        VStack(spacing: 0) {
            Spacer()

            // Icon + title
            VStack(spacing: 12) {
                Image(systemName: "key.fill")
                    .font(.system(size: 52))
                    .foregroundStyle(Color.accentColor)

                Text("Activate Sxitch Pro")
                    .font(.title2).bold()

                Text("Enter your license key to unlock all Pro features.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 340)
            }

            Spacer().frame(height: 28)

            // License key input
            VStack(spacing: 8) {
                HStack(spacing: 0) {
                    Group {
                        if showLicenseKey {
                            TextField("XXXX-XXXX-XXXX-XXXX", text: $licenseInput)
                        } else {
                            SecureField("XXXX-XXXX-XXXX-XXXX", text: $licenseInput)
                        }
                    }
                    .textFieldStyle(.plain)
                    .font(.system(size: 14, design: .monospaced))
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)

                    Button {
                        showLicenseKey.toggle()
                    } label: {
                        Image(systemName: showLicenseKey ? "eye.slash" : "eye")
                            .foregroundStyle(.secondary)
                            .frame(width: 36, height: 36)
                    }
                    .buttonStyle(.plain)
                }
                .background(Color(NSColor.controlBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color(NSColor.separatorColor), lineWidth: 1)
                )
                .frame(maxWidth: 360)

                // Status message
                if !licenseManager.activationMessage.isEmpty {
                    HStack(spacing: 6) {
                        Image(
                            systemName: licenseManager.isActivated
                                ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                        Text(licenseManager.activationMessage)
                            .font(.caption)
                    }
                    .foregroundStyle(licenseManager.isActivated ? Color.green : Color.red)
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
            .animation(.easeOut(duration: 0.2), value: licenseManager.activationMessage)

            Spacer().frame(height: 20)

            // Activate button + spinner
            // Mirrors Rust: Message::StartKeyValidation → Message::ActivateKey
            HStack(spacing: 12) {
                Button {
                    // Store key in config (mirrors Rust: config.license_key)
                    AppConfig.shared.licenseKey = licenseInput.trimmingCharacters(in: .whitespaces)
                    licenseManager.activate(key: licenseInput) { _, _ in }
                } label: {
                    Text(licenseManager.isActivating ? "Activating…" : "Activate")
                        .frame(width: 100)
                }
                .buttonStyle(.borderedProminent)
                .disabled(
                    licenseInput.trimmingCharacters(in: .whitespaces).isEmpty
                        || licenseManager.isActivating
                )
                .keyboardShortcut(.return, modifiers: [])

                if licenseManager.isActivating {
                    ProgressView().scaleEffect(0.75)
                }
            }

            Spacer().frame(height: 16)

            SxitchLinkButton(
                title: "Get Sxitch Pro →", url: "https://sxitch.app/#pricing",
                prominent: false)

            Spacer()
        }
        .padding(.horizontal, 40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Advanced (DEBUG only)

    private var advancedContent: some View {
        Form {
            Section("Debug Info") {
                LabeledContent(
                    "Bundle ID",
                    value: Bundle.main.bundleIdentifier ?? "unknown")
                LabeledContent(
                    "App Support Dir",
                    value: FileManager.default
                        .urls(for: .applicationSupportDirectory, in: .userDomainMask)
                        .first?.path ?? "?")
                LabeledContent("Pro Status", value: config.isPro ? "Activated" : "Free")
                LabeledContent(
                    "Keychain Key",
                    value: config.licenseKey.isEmpty
                        ? "(none)" : String(config.licenseKey.prefix(8)) + "…")
            }

            Section("Actions") {
                Button("Reset Onboarding") {
                    AppConfig.shared.onboardingComplete = false
                }
                Button("Clear All Settings (Dangerous)") {
                    if let bundleID = Bundle.main.bundleIdentifier {
                        UserDefaults.standard.removePersistentDomain(forName: bundleID)
                    }
                }
                .foregroundStyle(.red)
            }
        }
        .formStyle(.grouped)
    }

    // MARK: - Shared Helpers

    private func proHeader(_ title: String) -> some View {
        HStack(spacing: 4) {
            Text(title)
            if !config.isPro { ProBadge() }
        }
    }

    private func proGateRow(_ feature: String, action: @escaping () -> Void) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "lock.fill").foregroundStyle(.yellow)
            Text("\(feature) — Pro only").foregroundStyle(.secondary)
            Spacer()
            Button("Upgrade") { action() }
                .buttonStyle(.bordered)
                .controlSize(.small)
        }
    }
}

// MARK: - Shared Helper Views

struct ProBadge: View {
    var body: some View {
        Text("PRO")
            .font(.system(size: 9, weight: .medium))
            .foregroundStyle(Color.secondary)
            .padding(.horizontal, 5)
            .padding(.vertical, 2)
            .background(Color(NSColor.quaternaryLabelColor).opacity(0.5))
            .clipShape(Capsule())
    }
}

struct SxitchLinkButton: View {
    let title: String
    let url: String
    var prominent: Bool = false

    var body: some View {
        if prominent {
            Button(title) { openURL() }.buttonStyle(.borderedProminent)
        } else {
            Button(title) { openURL() }.buttonStyle(.bordered)
        }
    }

    private func openURL() {
        if let u = URL(string: url) { NSWorkspace.shared.open(u) }
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
            Button(accessibilityGranted ? "Open Settings" : "Request") {
                if accessibilityGranted {
                    if let url = URL(
                        string:
                            "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
                    ) {
                        NSWorkspace.shared.open(url)
                    }
                } else {
                    let options =
                        [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true]
                        as CFDictionary
                    AXIsProcessTrustedWithOptions(options)
                }
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
        .onReceive(Timer.publish(every: 1, on: .main, in: .common).autoconnect()) { _ in
            accessibilityGranted = AXIsProcessTrusted()
        }
    }
}
