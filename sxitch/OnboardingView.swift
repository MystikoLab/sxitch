import Combine
import IOKit.hid
import SwiftUI

// MARK: - OnboardingView

struct OnboardingView: View {
    var onFinish: () -> Void
    @State private var page: Int = 0

    var body: some View {
        VStack(spacing: 0) {
            // Page content area
            ZStack {
                switch page {
                case 0: welcomePage
                case 1: permissionsPage
                case 2: tutorialPage
                default: finishPage
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .animation(.easeInOut, value: page)

            navigationBar
        }
        .frame(width: 520, height: 440)
        .background(.regularMaterial)
    }

    // MARK: - Page 0: Welcome

    private var welcomePage: some View {
        VStack(spacing: 20) {
            Image(systemName: "arrow.left.arrow.right.square.fill")
                .font(.system(size: 72))
                .foregroundStyle(.blue)

            Text("Welcome to Sxitch")
                .font(.title)
                .bold()

            Text("A blazing-fast keyboard-driven app switcher for macOS.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 360)
        }
        .padding(40)
    }

    // MARK: - Page 1: Permissions

    private var permissionsPage: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Permissions Required")
                .font(.title2)
                .bold()

            Text("Sxitch needs these permissions to work:")
                .foregroundStyle(.secondary)

            Divider()

            PermissionRowView(
                icon: "accessibility",
                title: "Accessibility",
                description: "Needed to detect keystrokes and control app switching.",
                check: { AXIsProcessTrusted() },
                grant: {
                    if let url = URL(
                        string:
                            "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
                    ) {
                        NSWorkspace.shared.open(url)
                    }
                }
            )

            PermissionRowView(
                icon: "keyboard",
                title: "Input Monitoring",
                description: "Needed to listen for global hotkeys.",
                check: {
                    IOHIDCheckAccess(kIOHIDRequestTypeListenEvent) == kIOHIDAccessTypeGranted
                },
                grant: {
                    if let url = URL(
                        string:
                            "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent"
                    ) {
                        NSWorkspace.shared.open(url)
                    }
                }
            )

            PermissionRowView(
                icon: "rectangle.on.rectangle",
                title: "Screen Recording",
                description: "Needed to display live app window previews.",
                check: { CGPreflightScreenCaptureAccess() },
                grant: { _ = CGRequestScreenCaptureAccess() }
            )
        }
        .padding(.horizontal, 32)
        .padding(.vertical, 24)
    }

    // MARK: - Page 2: Tutorial

    private var tutorialPage: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("How to Use Sxitch")
                .font(.title2)
                .bold()

            Divider()

            VStack(alignment: .leading, spacing: 14) {
                TutorialRow(
                    icon: "command",
                    text: "Press your configured hotkey (default: Right ⌘) to open the switcher")
                TutorialRow(
                    icon: "keyboard",
                    text: "Type a character to jump directly to an app by key")
                TutorialRow(
                    icon: "arrow.left.arrow.right",
                    text: "Use arrow keys or Tab/Shift+Tab to navigate")
                TutorialRow(
                    icon: "return",
                    text: "Press Return to switch to focused app, Escape to dismiss")
                TutorialRow(
                    icon: "xmark.circle",
                    text: "Press ⌃Q for Quit mode, ⌃H for Hide mode, ⌃N for Normal mode")
            }
        }
        .padding(.horizontal, 32)
        .padding(.vertical, 24)
    }

    // MARK: - Page 3: Finish

    private var finishPage: some View {
        VStack(spacing: 20) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 72))
                .foregroundStyle(.green)

            Text("You're All Set!")
                .font(.title)
                .bold()

            Text("Sxitch lives in your menu bar. Press your hotkey any time to switch apps.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 360)
        }
        .padding(40)
    }

    // MARK: - Navigation Bar

    private var navigationBar: some View {
        HStack {
            if page > 0 {
                Button("Back") {
                    page -= 1
                }
                .buttonStyle(.plain)
            } else {
                // Reserve space so the dot indicator stays centred
                Color.clear.frame(width: 44, height: 1)
            }

            Spacer()

            // Page indicator dots
            HStack(spacing: 6) {
                ForEach(0..<4, id: \.self) { index in
                    Circle()
                        .fill(index == page ? Color.accentColor : Color.secondary.opacity(0.35))
                        .frame(width: 8, height: 8)
                        .animation(.easeInOut, value: page)
                }
            }

            Spacer()

            if page < 3 {
                Button("Next") {
                    page += 1
                }
                .buttonStyle(.borderedProminent)
            } else {
                Button("Get Started") {
                    onFinish()
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 20)
    }
}

// MARK: - PermissionRowView

struct PermissionRowView: View {
    let icon: String
    let title: String
    let description: String
    let check: () -> Bool
    let grant: () -> Void

    @State private var isGranted: Bool = false
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(isGranted ? .green : .secondary)
                .frame(width: 32, alignment: .center)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline)
                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if isGranted {
                Image(systemName: "checkmark.circle.fill")
                    .font(.title3)
                    .foregroundStyle(.green)
            } else {
                Button("Grant", action: grant)
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
            }
        }
        .onAppear { isGranted = check() }
        .onReceive(timer) { _ in isGranted = check() }
    }
}

// MARK: - TutorialRow (private helper)

private struct TutorialRow: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.body)
                .foregroundStyle(.secondary)
                .frame(width: 24, alignment: .center)

            Text(text)
                .font(.callout)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
