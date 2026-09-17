//
//  OnboardingView.swift
//  sxitch
//

import Combine
import KeyboardShortcuts
import SwiftUI

/// Renders the menu bar icon and opens the onboarding window on first launch.
struct OnboardingLauncher: View {
    let hasCompletedOnboarding: Bool
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Image(nsImage: makeMenuBarIcon())
            .task {
                if !hasCompletedOnboarding {
                    openWindow(id: "onboarding")
                }
            }
    }
}

// MARK: - Pages

private enum OnboardingPage: Int, CaseIterable {
    case welcome
    case permissions
    case hotkeySetup
    case tutorialBasics
    case tutorialModes
    case tutorialFeatures
    case tutorialLayout
    case license
    case finish
}

// MARK: - Main view

struct OnboardingView: View {
    @Binding var hasCompletedOnboarding: Bool
    @State private var currentPage: OnboardingPage = .welcome
    @State private var accessibilityGranted: Bool = AXIsProcessTrusted()
    @State private var nextVisible = false
    @State private var summonStepReady = false

    private var pageIndex: Int {
        currentPage.rawValue
    }

    let permissionTimer = Timer.publish(every: 1.5, on: .main, in: .common).autoconnect()

    var body: some View {
        ZStack {
            // Glass material fills the entire window, behind everything.
            OnboardingBackground()

            VStack(spacing: 0) {
                // Page content
                Group {
                    switch currentPage {
                    case .welcome: WelcomePage()
                    case .permissions:
                        PermissionsPage(
                            accent: .white,
                            accessibilityGranted: $accessibilityGranted
                        )
                    case .tutorialBasics: TutorialBasicsPage(summonPressed: summonStepReady)
                    case .hotkeySetup: HotkeySetupPage()
                    case .tutorialModes: TutorialModesPage()
                    case .tutorialFeatures: TutorialFeaturesPage(accent: .white)
                    case .tutorialLayout: TutorialLayoutPage()
                    case .license: LicensePage(accent: .white, onSkip: { advance() })
                    case .finish: FinishPage(accent: .white)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .transition(
                    .asymmetric(
                        insertion: .move(edge: .trailing).combined(with: .opacity),
                        removal: .move(edge: .leading).combined(with: .opacity)
                    )
                )
                .id(currentPage)
                .onReceive(permissionTimer) { _ in
                    accessibilityGranted = AXIsProcessTrusted()
                }

                // Step indicator + navigation, floating over the glass.
                stepFooter
            }
        }
        .frame(width: 680, height: 520)
        .background(OnboardingWindowConfigurator())
        .onReceive(NotificationCenter.default.publisher(for: .onboardingRestarted)) { _ in
            // "Open Guide" always restarts from the first page.
            currentPage = .welcome
        }
        .onReceive(NotificationCenter.default.publisher(for: .onboardingSummonPressed)) { _ in
            // Pressing the configured summon hotkey on the "try it" step
            // unlocks the Next button (the tap suppresses the real switcher).
            if currentPage == .tutorialBasics && !summonStepReady {
                withAnimation(.easeOut(duration: 0.4)) {
                    summonStepReady = true
                }
            }
        }
        .onChange(of: currentPage) { old, new in
            userState.shared.layoutDemoActive = new == .tutorialLayout
            if old == .tutorialLayout {
                NotificationCenter.default.post(name: .onboardingHideSwitcher, object: nil)
            }
        }
    }

    private var stepFooter: some View {
        VStack(spacing: 10) {
            HStack(spacing: 14) {
                if currentPage != .welcome {
                    Button {
                        goBack()
                    } label: {
                        Image(systemName: "arrow.left")
                            .font(.body.weight(.semibold))
                            .foregroundStyle(.white)
                            .frame(width: 30, height: 30)
                    }
                    .buttonStyle(WhitishCircleStyle())
                    .keyboardShortcut(keyboardShortcutIfAllowed(.leftArrow))
                } else {
                    // Invisible spacer keeps the step label centered alignment.
                    Color.clear
                        .frame(width: 30, height: 30)
                }

                Text("Step \(pageIndex + 1) of \(OnboardingPage.allCases.count)")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.white.opacity(0.9))

                Spacer()

                if currentPage == .license {
                    // License page has its own delayed skip / continue flow.
                    EmptyView()
                } else if currentPage != .finish {
                    Button("Next") {
                        advance()
                    }
                    .buttonStyle(WhitishProminentStyle())
                    .disabled(currentPage == .permissions && !accessibilityGranted)
                    .disabled(
                        currentPage == .tutorialBasics && !summonStepReady
                    )
                    .opacity(nextVisible ? 1 : 0)
                    .animation(.easeInOut(duration: 1.0), value: nextVisible)
                    .keyboardShortcut(keyboardShortcutIfAllowed(.rightArrow))
                } else {
                    Button("Get Started") {
                        hasCompletedOnboarding = true
                        NotificationCenter.default.post(name: .onboardingCompleted, object: nil)
                    }
                    .buttonStyle(WhitishProminentStyle())
                    .opacity(nextVisible ? 1 : 0)
                    .animation(.easeInOut(duration: 1.0), value: nextVisible)
                    .keyboardShortcut(keyboardShortcutIfAllowed(.return))
                }
            }

            // Progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.white.opacity(0.18))
                    Capsule()
                        .fill(Color.white.opacity(0.9))
                        .frame(width: geo.size.width * progressFraction)
                        .animation(.spring(response: 0.45, dampingFraction: 0.8), value: progressFraction)
                }
            }
            .frame(height: 4)
        }
        .padding(.horizontal, 40)
        .padding(.top, 12)
        .padding(.bottom, 20)
        .task(id: currentPage) {
            // The primary action fades in over a one-second beat on every page.
            nextVisible = false
            summonStepReady = false
            try? await Task.sleep(for: .seconds(0.25))
            nextVisible = true
        }
    }

    private var progressFraction: Double {
        Double(pageIndex + 1) / Double(OnboardingPage.allCases.count)
    }

    /// Arrow-key navigation to move between steps; disabled on the license
    /// page where the SecureField owns those keys.
    private func keyboardShortcutIfAllowed(_ key: KeyEquivalent) -> KeyboardShortcut? {
        guard currentPage != .license else { return nil }
        return KeyboardShortcut(key, modifiers: [])
    }

    private func goBack() {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
            currentPage = OnboardingPage(rawValue: max(0, pageIndex - 1)) ?? .welcome
        }
    }

    private func advance() {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
            if let next = OnboardingPage(rawValue: pageIndex + 1) {
                currentPage = next
            }
        }
    }
}

// MARK: - Whitish button styles (no macOS accent)

/// The primary step action: a whitish capsule with dark text. Greys out
/// (muted capsule, dimmed text) while the button is disabled.
struct WhitishProminentStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(
                isEnabled ? Color.black.opacity(0.78) : Color.white.opacity(0.38)
            )
            .padding(.horizontal, 20)
            .padding(.vertical, 9)
            .background(
                Capsule().fill(
                    isEnabled
                        ? Color.white.opacity(configuration.isPressed ? 0.72 : 0.92)
                        : Color.white.opacity(0.14)
                )
            )
    }
}

/// Small circular ghost button (back arrow) for use on dark glass.
struct WhitishCircleStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(
                Circle().fill(Color.white.opacity(configuration.isPressed ? 0.3 : 0.16))
            )
    }
}

/// Secondary outlined button (border + text on the glass, no fill).
struct WhitishOutlineStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(isEnabled ? .white.opacity(0.92) : .white.opacity(0.38))
            .padding(.horizontal, 18)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(Color.white.opacity(configuration.isPressed ? 0.1 : 0.04))
                    .overlay(
                        Capsule().strokeBorder(
                            Color.white.opacity(
                                configuration.isPressed ? 0.7 : 0.45
                            ),
                            lineWidth: 1.5
                        )
                    )
            )
    }
}

/// Tertiary text button (Grant, Skip) on dark glass.
struct WhitishGhostStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.medium))
            .foregroundStyle(.white.opacity(configuration.isPressed ? 0.6 : 0.9))
            .padding(.horizontal, 14)
            .padding(.vertical, 6)
            .background(
                Capsule().fill(Color.white.opacity(configuration.isPressed ? 0.22 : 0.12))
            )
    }
}

// MARK: - Welcome Page

struct WelcomePage: View {
    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .scaledToFit()
                .frame(width: 96, height: 96)

            VStack(spacing: 12) {
                Text("Welcome to Sxitch")
                    .font(.largeTitle)
                    .fontWeight(.bold)

                Text(
                    "A lightning-fast keyboard-driven app switcher for macOS.\nJump between apps without lifting your hands from the keyboard."
                )
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 440)
            }

            Spacer()
        }
        .padding(40)
    }
}

// MARK: - Permissions Page

struct PermissionsPage: View {
    var accent: Color
    @Binding var accessibilityGranted: Bool
    @State private var screenRecordingGranted: Bool = CGPreflightScreenCaptureAccess()

    let timer = Timer.publish(every: 1.5, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(spacing: 24) {
            VStack(spacing: 8) {
                Text("Permissions")
                    .font(.largeTitle)
                    .fontWeight(.bold)

                Text("Sxitch needs a few permissions to work its magic.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            VStack(spacing: 16) {
                PermissionRow(
                    icon: "hand.raised.fill",
                    title: "Accessibility",
                    description: "Required to detect the global hotkey and switch apps.",
                    isGranted: accessibilityGranted,
                    required: true,
                    accent: accent,
                    action: {
                        let options =
                            [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true]
                                as CFDictionary
                        AXIsProcessTrustedWithOptions(options)
                    }
                )

                PermissionRow(
                    icon: "rectangle.on.rectangle.fill",
                    title: "Screen Recording",
                    description: "Used to list open windows for the window picker feature.",
                    isGranted: screenRecordingGranted,
                    required: false,
                    accent: accent,
                    action: {
                        NSWorkspace.shared.open(
                            URL(
                                string:
                                "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture"
                            )!
                        )
                    }
                )
            }
            .frame(maxWidth: 500)

            if !accessibilityGranted {
                Label(
                    "Accessibility is required to continue.",
                    systemImage: "exclamationmark.triangle.fill"
                )
                .font(.caption)
                .foregroundStyle(.orange)
            }

            Spacer()
        }
        .padding(40)
        .onReceive(timer) { _ in
            accessibilityGranted = AXIsProcessTrusted()
            screenRecordingGranted = CGPreflightScreenCaptureAccess()
        }
    }
}

struct PermissionRow: View {
    let icon: String
    let title: String
    let description: String
    let isGranted: Bool
    var required: Bool = false
    var accent: Color
    let action: () -> Void

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(accent)
                .frame(width: 36)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(title)
                        .fontWeight(.semibold)
                    if required {
                        Text("REQUIRED")
                            .font(.caption2)
                            .fontWeight(.bold)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(Color.orange, in: Capsule())
                    }
                }
                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if isGranted {
                Label("Granted", systemImage: "checkmark.circle.fill")
                    .font(.caption)
                    .foregroundStyle(.green)
                    .labelStyle(.iconOnly)
                    .font(.title3)
            } else {
                Button("Grant") {
                    action()
                }
                .buttonStyle(WhitishGhostStyle())
            }
        }
        .padding(14)
        .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Hotkey setup

struct HotkeySetupPage: View {
    var body: some View {
        VStack(spacing: 18) {
            VStack(spacing: 8) {
                Text("Choose Your Hotkey")
                    .font(.largeTitle)
                    .fontWeight(.bold)

                Text("Pick the keys you'll use to summon the switcher. This is the same control found in Settings.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 440)
            }

            SwitcherHotkeyPicker(tint: .white)
                .frame(maxWidth: 460)

            Text("The change takes effect immediately. You can come back to this anytime in Keyboard settings.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(32)
        .tint(.white)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Tutorial: Basics

struct TutorialBasicsPage: View {
    var summonPressed: Bool = false

    private var hotkey: (symbol: String, description: String) {
        onboardingSummonHotkey()
    }

    var body: some View {
        VStack(spacing: 18) {
            VStack(spacing: 8) {
                Text("Summon & Switch")
                    .font(.largeTitle)
                    .fontWeight(.bold)

                Text("Summon the switcher with the hotkey you picked, then type to jump.")
                    .font(.body)
                    .foregroundStyle(.secondary)
            }

            SummonDemoView(
                hotkeyDescription: hotkey.description,
                keycapLabel: hotkey.symbol,
                summonPressed: summonPressed
            )
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Tutorial: Modes

struct TutorialModesPage: View {
    var body: some View {
        VStack(spacing: 16) {
            VStack(spacing: 8) {
                Text("Power Modes")
                    .font(.largeTitle)
                    .fontWeight(.bold)

                Text("Press your mode shortcuts and watch what they do to the Sxitch tile.")
                    .font(.body)
                    .foregroundStyle(.secondary)
            }

            PowerModeDemo(tint: .white)
                .frame(maxWidth: 460)

            HStack(spacing: 20) {
                ModeHotkeyRow(label: "Hide mode", shortcut: .hideMode)
                Divider().frame(height: 18)
                ModeHotkeyRow(label: "Quit mode", shortcut: .quitMode)
                Divider().frame(height: 18)
                ModeHotkeyRow(label: "Normal mode", shortcut: .normalMode)
            }

            Text("While the switcher is open, each shortcut toggles its action mode. You can rebind them anytime in Keyboard settings.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 460)
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct ModeHotkeyRow: View {
    let label: String
    let shortcut: KeyboardShortcuts.Name

    var body: some View {
        HStack(spacing: 8) {
            Text(label)
            KeyboardShortcuts.Recorder(for: shortcut)
        }
    }
}

// MARK: - Tutorial: Power features

struct TutorialFeaturesPage: View {
    var accent: Color

    var body: some View {
        VStack(spacing: 20) {
            VStack(spacing: 8) {
                Text("Go Further")
                    .font(.largeTitle)
                    .fontWeight(.bold)

                Text("Everything you can reach from Settings once you're set up.")
                    .font(.body)
                    .foregroundStyle(.secondary)
            }

            VStack(spacing: 12) {
                FeatureShowcaseRow(
                    icon: "rectangle.split.2x2.fill",
                    title: "Window picking",
                    description: "Drill into an app's windows and jump to the exact one by typing its title.",
                    tint: accent
                )

                FeatureShowcaseRow(
                    icon: "pin.fill",
                    title: "Pinned apps",
                    description: "Pin the apps you live in, and they stay at the top of the switcher.",
                    tint: accent
                )

                FeatureShowcaseRow(
                    icon: "square.grid.3x3.square",
                    title: "Layouts & themes",
                    description: "Grid, list, or circle layout, plus themes, accent colors, and screen positions.",
                    tint: accent
                )

                FeatureShowcaseRow(
                    icon: "sparkle.magnifyingglass",
                    title: "Search & custom modes",
                    description: "A search-first layout, key overrides, blacklists, and custom modes.",
                    tint: accent
                )
            }
            .frame(maxWidth: 520)
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Tutorial: Layout

struct TutorialLayoutPage: View {
    @AppStorage("layoutStyle") var layoutStyle: String = "grid"
    @State private var demoSwitcherVisible = false

    private let visibilityTimer = Timer.publish(every: 0.4, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(spacing: 20) {
            VStack(spacing: 8) {
                Text("Pick Your Layout")
                    .font(.largeTitle)
                    .fontWeight(.bold)

                Text("How the switcher arranges your apps. Show it to preview each arrangement.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 440)
            }

            HStack(spacing: 12) {
                LayoutPreviewCard(style: "grid", label: "Grid", isSelected: layoutStyle == "grid", slotTint: .white) {
                    layoutStyle = "grid"
                }
                LayoutPreviewCard(style: "list", label: "List", isSelected: layoutStyle == "list", slotTint: .white) {
                    layoutStyle = "list"
                }
                LayoutPreviewCard(style: "circle", label: "Circle", isSelected: layoutStyle == "circle", slotTint: .white) {
                    layoutStyle = "circle"
                }
                LayoutPreviewCard(style: "search", label: "Search", isSelected: layoutStyle == "search", slotTint: .white) {
                    layoutStyle = "search"
                }
            }
            .padding(.vertical, 4)

            // Show/hide the real switcher; pressing the summon hotkey also
            // toggles it while this page is open.
            Button {
                NotificationCenter.default.post(name: .onboardingShowSwitcher, object: nil)
            } label: {
                Label(
                    demoSwitcherVisible ? "Hide switcher" : "Show switcher",
                    systemImage: demoSwitcherVisible
                        ? "rectangle.inset.filled" : "rectangle.on.rectangle"
                )
            }
            .buttonStyle(WhitishGhostStyle())
            .animation(.easeOut(duration: 0.2), value: demoSwitcherVisible)
        }
        .tint(.white)
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onReceive(visibilityTimer) { _ in
            withAnimation(.easeInOut(duration: 0.2)) {
                demoSwitcherVisible = userState.shared.demoSwitcherVisible
            }
        }
    }
}

struct TutorialPointRow: View {
    let number: String
    let title: String
    let description: String
    var accent: Color

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            Text(number)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundStyle(accent)
                .frame(width: 36, alignment: .center)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .fontWeight(.semibold)
                Text(description)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(14)
        .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - License Page

struct LicensePage: View {
    var accent: Color
    var onSkip: () -> Void = {}

    private var appState = userState.shared
    @State private var licenseKey = ""
    @State private var isActivating = false
    @State private var errorMessage: String?
    @State private var justActivated = false
    @State private var justStartedTrial = false
    @State private var showingKeyEntry = false

    private var showsConfirmation: Bool {
        justActivated || justStartedTrial || appState.hasFullAccess
    }

    var body: some View {
        VStack(spacing: 18) {
            if showsConfirmation {
                confirmationContent
            } else if showingKeyEntry {
                keyEntryContent
            } else {
                choiceContent
            }
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .animation(.easeOut(duration: 0.3), value: showingKeyEntry)
        .animation(.spring(response: 0.4, dampingFraction: 0.75), value: showsConfirmation)
    }

    // MARK: Choice state

    private var choiceContent: some View {
        VStack(spacing: 16) {
            VStack(spacing: 8) {
                Text("Choose Your Sxitch")
                    .font(.largeTitle)
                    .fontWeight(.bold)

                Text("Try everything Pro has to offer, unlock it with a key, or keep the free version. You can always change this later in Settings.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 440)
            }

            VStack(spacing: 10) {
                Button {
                    appState.startTrial()
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                        justStartedTrial = true
                    }
                } label: {
                    VStack(spacing: 3) {
                        Text("Start 14-Day Pro Trial")
                            .font(.headline)
                        Text("All Pro features free for 14 days. No card required.")
                            .font(.caption)
                            .opacity(0.7)
                    }
                    .frame(maxWidth: 380)
                }
                .buttonStyle(WhitishProminentStyle())

                Button {
                    withAnimation(.easeOut(duration: 0.3)) {
                        showingKeyEntry = true
                    }
                } label: {
                    VStack(spacing: 3) {
                        Text("Enter Activation Key")
                            .font(.headline)
                        Text("Already purchased? Unlock Pro with your license key.")
                            .font(.caption)
                            .opacity(0.7)
                    }
                    .frame(maxWidth: 380)
                }
                .buttonStyle(WhitishOutlineStyle())

                Button {
                    onSkip()
                } label: {
                    VStack(spacing: 3) {
                        Text("Use in Free Mode")
                            .font(.headline)
                        Text("Core switching features stay free, forever.")
                            .font(.caption)
                            .opacity(0.7)
                    }
                    .frame(maxWidth: 380)
                }
                .buttonStyle(WhitishGhostStyle())
            }
        }
        .transition(.opacity)
    }

    // MARK: Key entry state

    private var keyEntryContent: some View {
        VStack(spacing: 16) {
            VStack(spacing: 8) {
                Text("Enter Activation Key")
                    .font(.largeTitle)
                    .fontWeight(.bold)

                Text("Enter the license key you received after purchase to unlock Pro features.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 420)
            }

            HStack(spacing: 8) {
                SecureField("XXXX-XXXX-XXXX-XXXX", text: $licenseKey)
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: 260)
                    .disabled(isActivating)

                Button(action: { Task { await performActivation() } }) {
                    if isActivating {
                        HStack(spacing: 8) {
                            ProgressView()
                                .controlSize(.small)
                            Text("Activating")
                        }
                    } else {
                        Text("Activate")
                    }
                }
                .buttonStyle(WhitishProminentStyle())
                .disabled(
                    licenseKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isActivating
                )
            }

            if let errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            HStack(spacing: 12) {
                Button {
                    if let url = URL(string: "https://sxitch.app/#pricing") {
                        NSWorkspace.shared.open(url)
                    }
                } label: {
                    Text("Get Pro")
                }
                .buttonStyle(WhitishOutlineStyle())

                Button {
                    withAnimation(.easeOut(duration: 0.3)) {
                        showingKeyEntry = false
                    }
                } label: {
                    Text("Back to Options")
                }
                .buttonStyle(WhitishGhostStyle())

                Button {
                    onSkip()
                } label: {
                    Text("Skip")
                }
                .buttonStyle(WhitishGhostStyle())
            }
        }
        .transition(.opacity)
    }

    // MARK: Confirmation state

    private var confirmationContent: some View {
        VStack(spacing: 18) {
            ZStack {
                ConfettiBurst(tint: accent)
                DrawInCheckmark(tint: accent)
            }
            .frame(height: 100)

            VStack(spacing: 8) {
                if justActivated || appState.isPro {
                    Text("You're Pro! 🎉")
                        .font(.largeTitle)
                        .fontWeight(.bold)

                    Text("Thank you for supporting Sxitch's development.")
                        .font(.body)
                        .foregroundStyle(.secondary)
                } else {
                    Text("Trial Started! 🎉")
                        .font(.largeTitle)
                        .fontWeight(.bold)

                    Text("All Pro features are unlocked for the next \(userState.trialLengthDays) days. Enjoy!")
                        .font(.body)
                        .foregroundStyle(.secondary)
                }
            }

            Button("Continue") {
                onSkip()
            }
            .buttonStyle(WhitishProminentStyle())
        }
        .transition(.scale(scale: 0.9).combined(with: .opacity))
    }

    // MARK: Actions

    private func performActivation() async {
        isActivating = true
        errorMessage = nil
        let cleanedKey = licenseKey.trimmingCharacters(in: .whitespacesAndNewlines)

        do {
            let success = try await activateKey(key: cleanedKey)
            if success {
                appState.isPro = true
                licenseKey = ""
                withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                    justActivated = true
                }
            } else {
                errorMessage = "Invalid license key or activation limit reached."
                appState.isPro = false
            }
            isActivating = false
        } catch {
            errorMessage = "Network or connection error. Please try again."
            isActivating = false
        }
    }
}

// MARK: - Finish Page

struct FinishPage: View {
    var accent: Color

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            ZStack {
                ConfettiBurst(tint: accent)
                DrawInCheckmark(tint: accent, size: 96)
            }
            .frame(height: 110)

            VStack(spacing: 12) {
                Text("You're all set!")
                    .font(.largeTitle)
                    .fontWeight(.bold)

                Text(
                    "Sxitch lives in your menu bar. Press your hotkey anytime to switch apps.\nEnjoy the speed. You won't want to go back."
                )
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 440)
            }

            HStack(spacing: 12) {
                if userState.shared.isPro {
                    // Nothing extra to upsell for licensed users.
                } else if userState.shared.isTrialActive {
                    Text("\(userState.shared.trialDaysRemaining) days of Pro left")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else {
                    Link(destination: URL(string: "https://sxitch.app/#pricing")!) {
                        Label("Get Sxitch Pro", systemImage: "star.fill")
                    }
                    .buttonStyle(WhitishGhostStyle())
                }

                Link(destination: URL(string: "https://discord.sxitch.app")!) {
                    Label("Join Discord", systemImage: "person.2.fill")
                }
                .buttonStyle(WhitishGhostStyle())

                Link(destination: URL(string: "https://github.com/MystikoLab/sxitch")!) {
                    Label("Star on GitHub", systemImage: "star")
                }
                .buttonStyle(WhitishGhostStyle())
            }

            Spacer()
        }
        .padding(40)
    }
}
