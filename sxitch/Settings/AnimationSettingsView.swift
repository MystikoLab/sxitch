import AppKit
import SwiftUI

struct AnimationSettingsView: View, SettingsTab {
    static let tabID = "animation"
    static let tabTitle = "Animation"
    static let tabIcon = "sparkles"

    @AppStorage(SwitcherAnimation.userDefaultsKey) private var animationRaw: String = SwitcherAnimation.fade.rawValue
    @AppStorage(SwitcherAnimation.speedKey) private var animationSpeed: Double = 1.0
    @AppStorage(SwitcherAnimation.enabledKey) private var animationsEnabled: Bool = true

    private var usState = userState.shared

    @State private var wallpaperURL: URL?
    @State private var replayToken: UUID = .init()
    @State private var sampleApps: [SwitcherAppSample] = []
    @State private var isAdjustingSpeed = false

    private var selectedStyle: SwitcherAnimation {
        SwitcherAnimation(rawValue: animationRaw) ?? .fade
    }

    /// Unlicensed selection downgrades to Fade, matching what the real
    /// switcher plays (see `SwitcherAnimation.current`).
    private var effectiveStyle: SwitcherAnimation {
        selectedStyle.isPro && !usState.isPro ? .fade : selectedStyle
    }

    var body: some View {
        Form {
            Section {
                HStack {
                    Toggle("Enable animations", isOn: $animationsEnabled)
                        .onChange(of: animationsEnabled) { _, _ in
                            replayToken = UUID()
                        }
                    SettingInfoTip(text: "When off, the switcher appears and closes with no animation.")
                }
            }

            Section("Preview") {
                AnimationShowcase(
                    style: effectiveStyle,
                    speed: animationSpeed,
                    wallpaperURL: wallpaperURL,
                    apps: sampleApps,
                    replayToken: replayToken
                )
                .frame(height: 230)
                .listRowBackground(Color.clear)
                .opacity(animationsEnabled ? 1 : 0.45)
            }

            Section("Open / Close Animation") {
                Picker("Animation", selection: animationBinding) {
                    ForEach(SwitcherAnimation.allCases, id: \.rawValue) { style in
                        Text(style.displayName).tag(style.rawValue)
                    }
                }
                .pickerStyle(.menu)
                .disabled(!animationsEnabled)

                if !usState.isPro {
                    Text(
                        selectedStyle.isPro
                            ? "Upgrade to Pro to use \(selectedStyle.displayName) on summon."
                            : "Upgrade to Pro to unlock Slide In, Drop In and Scale In."
                    )
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
            }

            Section("Speed") {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("Speed")
                        SettingInfoTip(text: "Applies to every animation, including Default.")
                        Spacer()
                        Text(String(format: "%.1fs", animationSpeed))
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }
                    Slider(value: $animationSpeed, in: 0.5 ... 2.0, step: 0.05) { editing in
                        isAdjustingSpeed = editing
                        if !editing {
                            replayToken = UUID()
                            performHaptic(.generic)
                        }
                    }
                    .onChange(of: animationSpeed) { _, _ in
                        guard isAdjustingSpeed else { return }
                        // Alignment ticks match the 0.05 slider step; the
                        // performer coalesces rapid repeats on its own.
                        performHaptic(.alignment)
                    }
                }
                .disabled(!animationsEnabled)
            }
        }
        .formStyle(.grouped)
        .onAppear {
            loadWallpaper()
            loadSampleApps()
            replayToken = UUID()
        }
        .onChange(of: animationRaw) { _, _ in
            replayToken = UUID()
        }
    }

    private var animationBinding: Binding<String> {
        Binding(
            get: { SwitcherAnimation(rawValue: animationRaw)?.rawValue ?? SwitcherAnimation.fade.rawValue },
            set: { newValue in
                guard let style = SwitcherAnimation(rawValue: newValue) else { return }
                if style.isPro, !usState.isPro {
                    // Snap back: keeps the gate airtight even if the disabled
                    // state were bypassed in the UI.
                    animationRaw = effectiveStyle.rawValue
                } else {
                    animationRaw = newValue
                }
            }
        )
    }

    private func loadWallpaper() {
        let screens = NSScreen.screens
        if let screen = NSScreen.main ?? screens.first {
            wallpaperURL = NSWorkspace.shared.desktopImageURL(for: screen)
        }
    }

    @MainActor
    private func loadSampleApps() {
        sampleApps = sampleRunningApps(max: 4)
    }

    private func performHaptic(_ pattern: NSHapticFeedbackManager.FeedbackPattern) {
        NSHapticFeedbackManager.defaultPerformer.perform(pattern, performanceTime: .now)
    }
}

// MARK: - Showcase

/// Wallpaper-backed mock of the switcher that plays the chosen open
/// animation only when triggered (on appear, selection change, or the play
/// button) — no self-running loop. Only the mock window animates; the
/// wallpaper behind it stays perfectly still. Non-interactive otherwise.
struct AnimationShowcase: View {
    let style: SwitcherAnimation
    let speed: Double
    let wallpaperURL: URL?
    let apps: [SwitcherAppSample]
    let replayToken: UUID

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var shown = true

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .center) {
                wallpaper
                    .frame(width: geo.size.width, height: geo.size.height)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .strokeBorder(Color.primary.opacity(0.15), lineWidth: 1)
                    )
                    .allowsHitTesting(false)

                if shown {
                    mockPanel
                        .transition(transition)
                        .allowsHitTesting(false)
                }

                Button {
                    play()
                } label: {
                    Image(systemName: "play.fill")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.primary)
                        .frame(width: 26, height: 26)
                        .background(.thinMaterial, in: Circle())
                }
                .buttonStyle(.plain)
                .help("Replay animation")
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                .padding(10)
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .onAppear {
            play()
        }
        .onChange(of: replayToken) { _, _ in
            play()
        }
    }

    private var openDuration: Double {
        max(style.openDuration, 0.12) * max(speed, 0.5)
    }

    private var transition: AnyTransition {
        switch style {
        case .fade:
            // Represents the macOS-native window fade.
            .opacity
        case .slide:
            .offset(y: SwitcherAnimation.slideOffset)
                .combined(with: .opacity)
        case .drop:
            .offset(y: -SwitcherAnimation.dropOffset)
                .combined(with: .opacity)
        case .scale:
            .scale(scale: SwitcherAnimation.scaleStartFactor, anchor: .center)
                .combined(with: .opacity)
        }
    }

    @ViewBuilder
    private var wallpaper: some View {
        if let url = wallpaperURL, let image = NSImage(contentsOf: url) {
            Image(nsImage: image)
                .resizable()
                .scaledToFill()
        } else {
            LinearGradient(
                colors: [
                    Color(nsColor: .controlAccentColor).opacity(0.5),
                    .indigo.opacity(0.5),
                    .black.opacity(0.8),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }

    private var mockPanel: some View {
        HStack(spacing: 16) {
            ForEach(apps) { app in
                VStack(spacing: 4) {
                    Image(nsImage: app.icon)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 40, height: 40)
                    Text(app.name)
                        .font(.system(size: 9))
                        .foregroundStyle(.white.opacity(0.85))
                        .lineLimit(1)
                }
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 18)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(.ultraThinMaterial)
        )
        .shadow(color: .black.opacity(0.35), radius: 10, y: 4)
    }

    private func play() {
        guard !reduceMotion else {
            shown = true
            return
        }
        shown = false
        // Reset without animation, then bring the panel back in on the next
        // frame so the transition runs on every replay.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            withAnimation(.easeOut(duration: openDuration)) {
                shown = true
            }
        }
    }
}
