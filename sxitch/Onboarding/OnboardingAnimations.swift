//
//  OnboardingAnimations.swift
//  sxitch
//
//  Small self-playing vector demos used on onboarding tutorial pages:
//  keycap press, typing-to-jump app switching, mode flip, and a draw-in
//  checkmark. All loop gently and honor Reduce Motion (static final frame).
//

import KeyboardShortcuts
import SwiftUI

/// NSEvent key codes for the default mode shortcuts (Q/H on ANSI layouts).
private enum ModeKey {
    static let q: UInt16 = 12 // kVK_ANSI_Q
    static let h: UInt16 = 4  // kVK_ANSI_H
    static let n: UInt16 = 45 // kVK_ANSI_N
}

// MARK: - Keycap

/// Rounded keycap drawn from translucent white layers so it reads on dark
/// glass in both light and dark system appearances. `tint` colors the label
/// (white normally, mode color when a mode keycap is active).
struct KeycapShape: View {
    var label: String
    var pressed: Bool
    var tint: Color = .white
    var size: CGSize? = nil

    var body: some View {
        Text(label)
            .font(size != nil ? .headline.weight(.semibold) : .title3.weight(.semibold))
            .foregroundStyle(tint)
            .frame(width: size?.width ?? 84, height: size?.height ?? 56)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.white.opacity(pressed ? 0.26 : 0.14))
                    .shadow(color: .black.opacity(pressed ? 0.08 : 0.2), radius: pressed ? 2 : 6, y: pressed ? 1 : 3)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(tint.opacity(0.45), lineWidth: 1.5)
            )
            .animation(.spring(response: 0.25, dampingFraction: 0.6), value: pressed)
    }
}

// MARK: - Real app icons

/// A running app's icon, used by the interactive demos.
struct SwitcherAppSample: Identifiable {
    let id: String
    let icon: NSImage
    let name: String
}

@MainActor
func sampleRunningApps(max: Int) -> [SwitcherAppSample] {
    NSWorkspace.shared.runningApplications
        .filter {
            $0.activationPolicy == .regular
                && $0.bundleIdentifier != Bundle.main.bundleIdentifier
        }
        .sorted { ($0.localizedName ?? "") < ($1.localizedName ?? "") }
        .prefix(max)
        .compactMap { app -> SwitcherAppSample? in
            guard let icon = app.icon else { return nil }
            return SwitcherAppSample(
                id: app.bundleIdentifier ?? UUID().uuidString,
                icon: icon,
                name: app.localizedName ?? "App"
            )
        }
}

// MARK: - Summon demo (interactive)

/// "Try pressing your hotkey", pressing it unlocks the Next button
/// of launching the switcher (see the AppDelegate suppression during
/// onboarding). Text reflects the user's configured hotkey.
struct SummonDemoView: View {
    var hotkeyDescription: String
    var keycapLabel: String
    /// True once the user actually presses the hotkey: plays the summon
    /// feedback (keycap press + switcher pop-in) and stops the idle pulse.
    var summonPressed = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var pulse = false
    @State private var apps: [SwitcherAppSample] = []

    private var keycapIsPressed: Bool {
        summonPressed || (pulse && !reduceMotion)
    }

    /// Running apps shown in the mock switcher, with Sxitch itself included.
    @MainActor
    private var sampleApps: [SwitcherAppSample] {
        var result = [SwitcherAppSample(
            id: "self",
            icon: NSApp.applicationIconImage,
            name: "Sxitch"
        )]
        result.append(contentsOf: apps.filter { $0.name != "Sxitch" })
        return Array(result.prefix(3))
    }

    var body: some View {
        VStack(spacing: 16) {
            ZStack(alignment: .top) {
                if summonPressed {
                    // Pop-in mock switcher: just the running apps (with
                    // Sxitch included), plain, without any card boxes.
                    HStack(spacing: 16) {
                        ForEach(sampleApps) { app in
                            VStack(spacing: 3) {
                                Image(nsImage: app.icon)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 32, height: 32)
                                Text(app.name)
                                    .font(.system(size: 10))
                                    .foregroundStyle(.white.opacity(0.8))
                                    .lineLimit(1)
                            }
                        }
                    }
                    .offset(y: 6)
                    .transition(.scale(scale: 0.75).combined(with: .opacity))
                }

                KeycapShape(label: keycapLabel, pressed: keycapIsPressed)
                    .scaleEffect(!reduceMotion && pulse ? 1.04 : 1)
                    .animation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true).paused(reduceMotion), value: pulse)
                    .opacity(summonPressed ? 0 : 1)
                    .offset(y: summonPressed ? 34 : 0)
            }
            .frame(height: 128)
            .animation(.spring(response: 0.3, dampingFraction: 0.75), value: summonPressed)

            if summonPressed {
                Text("It works! Your hotkey summoned the switcher.")
                    .font(.body.weight(.medium))
                    .foregroundStyle(.white.opacity(0.95))
                    .transition(.opacity)
            } else {
                Text("Try pressing \(hotkeyDescription)")
                    .font(.body.weight(.medium))
                    .foregroundStyle(.white.opacity(0.95))
            }
        }
        .padding(18)
        .background(Color.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 16))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Try pressing \(hotkeyDescription) to continue.")
        .onAppear {
            apps = sampleRunningApps(max: 4)
            guard !reduceMotion else { return }
            pulse = true
        }
    }
}


/// Reads the current summon hotkey config (same keys the settings picker and
/// the event tap use) and returns a displayable description.
@MainActor
func onboardingSummonHotkey() -> (symbol: String, description: String) {
    let config = UserDefaults.standard.string(forKey: "hotkey_modifier_config") ?? ""
    let keycode = UserDefaults.standard.integer(forKey: "hotkey_keycode")

    let symbols: [Int: String] = [0: "⌥", 1: "⌘", 2: "⇧", 3: "⌃"]
    let names: [Int: String] = [0: "Option", 1: "Command", 2: "Shift", 3: "Control"]
    let nonModifierName: [Int: String] = [49: "Space", 48: "Tab", 36: "Return"]

    var symbol = ""
    var namesPart: [String] = []
    for entry in config.split(separator: ",") {
        let parts = entry.split(separator: ":")
        guard parts.count >= 2, let family = Int(parts[0]) else { continue }
        if let s = symbols[family] {
            symbol += s
        }
        let side = parts.count > 1 ? String(parts[1]) : "either"
        switch side {
        case "left": namesPart.append("Left \(names[family] ?? "")")
        case "right": namesPart.append("Right \(names[family] ?? "")")
        default: namesPart.append(names[family] ?? "")
        }
    }

    var keyName = namesPart.joined(separator: " + ")
    if keycode != 256, let name = nonModifierName[keycode] {
        if keyName.isEmpty {
            keyName = name
        } else {
            keyName = "\(keyName) + \(name)"
        }
    }
    if keyName.isEmpty { keyName = "Right ⌘"; symbol = "⌘" }

    // Keycap symbol: use the composed modifier symbols, or a mnemonic for the
    // plain key.
    var cap = symbol
    if cap.isEmpty {
        switch keycode {
        case 49: cap = "space"
        case 48: cap = "⇥"
        case 36: cap = "⏎"
        default: cap = "⌘"
        }
    }
    return (symbol: cap, description: keyName)
}

extension Animation {
    /// repeatForever but paused: used so Reduce Motion simply freezes the pulse.
    func paused(_ paused: Bool) -> Animation {
        paused ? .easeInOut(duration: 0.001) : self
    }
}

// MARK: - Power modes demo (interactive)

/// Interactive power-modes demo: press the configured Hide/Quit/Normal mode
/// shortcuts (defaults ⌃Q / ⌃H / ⌃N) while the demo is on screen and the
/// Sxitch app tile previews the respective action.
struct PowerModeDemo: View {
    var tint: Color

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var modeIndex = 0
    @State private var keyMonitor: Any?

    var body: some View {
        VStack(spacing: 18) {
            // The Sxitch app tile that reacts to the mode shortcuts.
            ZStack {
                RoundedRectangle(cornerRadius: 16)
                    .fill(modeColor.opacity(modeIndex == 0 ? 0.08 : 0.16))
                    .frame(width: 108, height: 108)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .strokeBorder(modeColor.opacity(modeIndex == 0 ? 0.25 : 0.8), lineWidth: 2)
                    )

                Image(nsImage: NSApp.applicationIconImage)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 62, height: 62)
                    .opacity(modeIndex == 2 ? 0.5 : 1)

                if modeIndex != 0 {
                    Image(systemName: modeIndex == 1 ? "xmark.circle.fill" : "eye.slash.fill")
                        .font(.system(size: 28, weight: .semibold))
                        .foregroundStyle(modeColor)
                        .offset(y: -34)
                }
            }

            Text(statusText)
                .font(.callout.weight(.medium))
                .foregroundStyle(.white.opacity(0.9))
                .multilineTextAlignment(.center)
        }
        .padding(20)
        .frame(maxWidth: 460)
        .background(Color.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 16))
        .onAppear { installKeyMonitor() }
        .onDisappear {
            if let keyMonitor {
                NSEvent.removeMonitor(keyMonitor)
                self.keyMonitor = nil
            }
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: modeIndex)
    }

    private var modeColor: Color {
        modeIndex == 1 ? .red : .orange
    }

    private var statusText: String {
        switch modeIndex {
        case 1: return "Quit mode: the app you pick with the switcher will quit instead of switching."
        case 2: return "Hide mode: the app you pick with the switcher will hide instantly."
        default: return "Normal mode: the app you pick with the switcher opens like usual."
        }
    }

    /// Maps ⌃Q / ⌃H / ⌃N (or the user's recorded mode shortcuts) to the demo.
    private func installKeyMonitor() {
        let monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            guard event.modifierFlags.contains(.control),
                  !event.modifierFlags.contains(.command),
                  !event.modifierFlags.contains(.option),
                  !event.modifierFlags.contains(.function)
            else { return event }

            let quitKey = KeyboardShortcuts.getShortcut(for: .quitMode)
            let hideKey = KeyboardShortcuts.getShortcut(for: .hideMode)
            let normalKey = KeyboardShortcuts.getShortcut(for: .normalMode)

            if matches(event, shortcut: quitKey, fallback: ModeKey.q) {
                select(1)
                return nil
            } else if matches(event, shortcut: hideKey, fallback: ModeKey.h) {
                select(2)
                return nil
            } else if matches(event, shortcut: normalKey, fallback: ModeKey.n) {
                select(0)
                return nil
            }
            return event
        }
        keyMonitor = monitor
    }

    private func matches(
        _ event: NSEvent,
        shortcut: KeyboardShortcuts.Shortcut?,
        fallback: UInt16
    ) -> Bool {
        guard let sc = shortcut else { return event.keyCode == fallback }
        // Carbon key codes match NSEvent key codes; require ⌃ without other
        // modifiers beyond the shortcut's own.
        return UInt16(sc.carbonKeyCode) == event.keyCode && sc.modifiers.contains(.control)
    }

    private func select(_ index: Int) {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            modeIndex = index
        }
    }
}

// MARK: - Feature rows (power features page)

struct FeatureShowcaseRow: View {
    let icon: String
    let title: String
    let description: String
    var tint: Color

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(tint)
                .frame(width: 36)
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

// MARK: - Confetti

/// Small burst of accent-tinted dots that explode outward and fade once.
struct ConfettiBurst: View {
    var tint: Color
    @State private var fired = false

    private let particles: [(angle: Double, distance: CGFloat, size: CGFloat)] = [
        (0, 1.0, 5), (30, 0.85, 4), (60, 1.05, 6), (95, 0.9, 4),
        (130, 1.0, 5), (160, 0.8, 4), (195, 1.1, 6), (230, 0.9, 4),
        (265, 1.0, 5), (300, 0.85, 4), (335, 1.05, 6),
    ]

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            ForEach(particles.indices, id: \.self) { i in
                let p = particles[i]
                Circle()
                    .fill(i % 3 == 0 ? tint : (i % 3 == 1 ? Color.orange : Color.pink))
                    .frame(width: p.size, height: p.size)
                    .offset(
                        x: fired ? cos(p.angle * .pi / 180) * p.distance * 46 : 0,
                        y: fired ? sin(p.angle * .pi / 180) * p.distance * 46 : 0
                    )
                    .opacity(fired ? 0 : 0.9)
                    .scaleEffect(fired ? 0.5 : 1)
            }
        }
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeOut(duration: 1.1).delay(0.25)) {
                fired = true
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

// MARK: - Draw-in checkmark

/// A checkmark that strokes itself in, used for activation success.
struct DrawInCheckmark: View {
    var tint: Color
    var size: CGFloat = 72

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var progress: CGFloat = 0

    var body: some View {
        ZStack {
            Circle()
                .stroke(tint.opacity(0.3), lineWidth: size * 0.06)
                .frame(width: size, height: size)

            CheckmarkShape()
                .trim(from: 0, to: reduceMotion ? 1 : progress)
                .stroke(tint, style: StrokeStyle(lineWidth: size * 0.09, lineCap: .round, lineJoin: .round))
                .frame(width: size * 0.52, height: size * 0.42)
        }
        .accessibilityHidden(true)
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeOut(duration: 0.5).delay(0.1)) {
                progress = 1
            }
        }
    }
}

struct CheckmarkShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: 0, y: rect.height * 0.55))
        p.addLine(to: CGPoint(x: rect.width * 0.36, y: rect.height))
        p.addLine(to: CGPoint(x: rect.width, y: 0))
        return p
    }
}
