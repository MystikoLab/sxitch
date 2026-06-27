//
//  OnboardingView.swift
//  sxitch
//

import Combine
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

struct OnboardingView: View {
    @Binding var hasCompletedOnboarding: Bool
    @AppStorage("accentColorHex") var accentColorHex: String = "system"
    @State private var currentPage: Int = 0
    @State private var accessibilityGranted: Bool = AXIsProcessTrusted()

    let permissionTimer = Timer.publish(every: 1.5, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(spacing: 0) {
            // Page content
            Group {
                switch currentPage {
                case 0: WelcomePage()
                case 1: PermissionsPage(accessibilityGranted: $accessibilityGranted)
                case 2: TutorialPage()
                case 3: FinishPage()
                default: WelcomePage()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(
                LinearGradient(
                    colors: [
                        Color(nsColor: .windowBackgroundColor),
                        Color(nsColor: .controlBackgroundColor),
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .clipped()
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

            // Bottom navigation bar — always visible, never clipped
            HStack {
                // Page dots
                HStack(spacing: 8) {
                    ForEach(0..<4, id: \.self) { index in
                        Circle()
                            .fill(
                                index == currentPage
                                    ? (resolvedAccentColor(from: accentColorHex) ?? .accentColor)
                                    : Color.secondary.opacity(0.4)
                            )
                            .frame(
                                width: index == currentPage ? 8 : 6,
                                height: index == currentPage ? 8 : 6
                            )
                            .animation(
                                .spring(response: 0.3, dampingFraction: 0.7), value: currentPage
                            )
                    }
                }

                Spacer()

                HStack(spacing: 12) {
                    Button("Back") {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                            currentPage = max(0, currentPage - 1)
                        }
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                    .opacity(currentPage > 0 ? 1 : 0)
                    .disabled(currentPage == 0)

                    if currentPage < 3 {
                        Button("Next") {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                                currentPage += 1
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                        .disabled(currentPage == 1 && !accessibilityGranted)
                    } else {
                        Button("Get Started") {
                            hasCompletedOnboarding = true
                            NotificationCenter.default.post(name: .onboardingCompleted, object: nil)
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                    }
                }
            }
            .padding(.horizontal, 40)
            .padding(.vertical, 24)
            .background(.ultraThinMaterial)
        }
        .frame(width: 640, height: 480)
        .tint(resolvedAccentColor(from: accentColorHex))
    }
}

// MARK: - Welcome Page

struct WelcomePage: View {
    @AppStorage("accentColorHex") var accentColorHex: String = "system"
    var accentColor: Color { resolvedAccentColor(from: accentColorHex) ?? .accentColor }

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "arrow.left.arrow.right.circle.fill")
                .resizable()
                .scaledToFit()
                .frame(width: 80, height: 80)
                .foregroundStyle(accentColor)
                .symbolRenderingMode(.hierarchical)

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
                .frame(maxWidth: 420)
            }

            Spacer()
        }
        .padding(40)
    }
}

// MARK: - Permissions Page

struct PermissionsPage: View {
    @Binding var accessibilityGranted: Bool
    @State private var screenRecordingGranted: Bool = CGPreflightScreenCaptureAccess()

    let timer = Timer.publish(every: 1.5, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

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
            .frame(maxWidth: 480)

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
    let action: () -> Void
    @AppStorage("accentColorHex") var accentColorHex: String = "system"
    var accentColor: Color { resolvedAccentColor(from: accentColorHex) ?? .accentColor }

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(accentColor)
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
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
        .padding(14)
        .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Tutorial Page

struct TutorialPage: View {
    var body: some View {
        VStack(spacing: 20) {
            VStack(spacing: 8) {
                Text("How Sxitch Works")
                    .font(.largeTitle)
                    .fontWeight(.bold)

                Text("Three things to know and you're set.")
                    .font(.body)
                    .foregroundStyle(.secondary)
            }

            VStack(spacing: 12) {
                TutorialRow(
                    number: "1",
                    title: "Summon with your hotkey",
                    description:
                        "Press Right ⌘ (or your configured hotkey) to show the switcher overlay."
                )

                TutorialRow(
                    number: "2",
                    title: "Type to jump to an app",
                    description:
                        "Type the first letter(s) of an app's name. With only one match, Sxitch opens it instantly."
                )

                TutorialRow(
                    number: "3",
                    title: "Power modes (Pro)",
                    description:
                        "Press ⌃Q for Quit mode, ⌃H to Hide, ⌃N to return to Normal mode while the overlay is open."
                )
            }
            .frame(maxWidth: 480)
        }
        .padding(40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct TutorialRow: View {
    let number: String
    let title: String
    let description: String
    @AppStorage("accentColorHex") var accentColorHex: String = "system"
    var accentColor: Color { resolvedAccentColor(from: accentColorHex) ?? .accentColor }

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            Text(number)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundStyle(accentColor)
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

// MARK: - Finish Page

struct FinishPage: View {
    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "checkmark.seal.fill")
                .resizable()
                .scaledToFit()
                .frame(width: 80, height: 80)
                .foregroundStyle(Color.green)
                .symbolRenderingMode(.hierarchical)

            VStack(spacing: 12) {
                Text("You're all set!")
                    .font(.largeTitle)
                    .fontWeight(.bold)

                Text(
                    "Sxitch lives in your menu bar. Press your hotkey anytime to switch apps.\nEnjoy the speed — you won't want to go back."
                )
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 420)
            }

            HStack(spacing: 12) {
                Link(destination: URL(string: "https://sxitch.app/#pricing")!) {
                    Label("Get Sxitch Pro", systemImage: "star.fill")
                }
                .buttonStyle(.bordered)

                Link(destination: URL(string: "https://discord.sxitch.app")!) {
                    Label("Join Discord", systemImage: "person.2.fill")
                }
                .buttonStyle(.bordered)
            }

            Spacer()
        }
        .padding(40)
    }
}
