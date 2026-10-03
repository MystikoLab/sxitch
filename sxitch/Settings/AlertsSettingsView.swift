import AppKit
import SwiftUI

struct AlertsSettingsView: View, SettingsTab {
    static let tabID = "alerts"
    static let tabTitle = "Alert behaviour"
    static let tabIcon = "megaphone"

    @AppStorage("switchAlertsEnabled") var alertsEnabled: Bool = true
    @AppStorage("switchAlertStyle") var alertStyle: String = "liquid"
    @AppStorage("switchAlertPosition") var alertPosition: String = "screenBottom"
    @AppStorage("switchAlertPadding") var alertPadding: Double = 12

    @State private var isAdjustingPadding = false

    var body: some View {
        Form {
            Section("Preview") {
                AlertPositionDemo(position: alertPosition, bottomPadding: alertPadding)
                    .opacity(alertsEnabled ? 1 : 0.45)
            }

            Section {
                HStack {
                    Toggle("Show action alerts", isOn: $alertsEnabled)
                    SettingInfoTip(
                        text: "Shows a brief \"Opening / Hiding / Quitting <App>\" alert when you switch apps."
                    )
                }
            } header: {
                InfoTipHeader(
                    title: "Action Alerts",
                    tip: "Feedback for the action performed on the app you tapped or typed."
                )
            }

            alertStyleSection

            Section {
                Picker("Position", selection: $alertPosition) {
                    Text("Bottom of screen").tag("screenBottom")
                    Text("Switcher").tag("switcher")
                }
                .pickerStyle(.menu)
                .disabled(!alertsEnabled)

                if alertPosition == "screenBottom" {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("Bottom padding")
                            SettingInfoTip(
                                text: "Extra space between the alert and the bottom edge of the screen. Only applies to the Bottom of screen position."
                            )
                            Spacer()
                            Text(String(format: "%.0fpt", alertPadding))
                                .foregroundStyle(.secondary)
                                .monospacedDigit()
                        }
                        Slider(value: $alertPadding, in: 0 ... 64, step: 1) { editing in
                            isAdjustingPadding = editing
                            if !editing {
                                performHaptic(.generic)
                            }
                        }
                        .onChange(of: alertPadding) { _, _ in
                            guard isAdjustingPadding else { return }
                            // Alignment ticks match the 1pt slider step; the
                            // performer coalesces rapid repeats on its own.
                            performHaptic(.alignment)
                        }
                    }
                    .disabled(!alertsEnabled)
                }
            } header: {
                InfoTipHeader(
                    title: "Alert Position",
                    tip: "Bottom of screen pins the alert to the display's bottom edge; Switcher centres it over the switcher panel."
                )
            }
        }
        .formStyle(.grouped)
    }

    private func performHaptic(_ pattern: NSHapticFeedbackManager.FeedbackPattern) {
        NSHapticFeedbackManager.defaultPerformer.perform(pattern, performanceTime: .now)
    }

    @ViewBuilder
    private var alertStyleSection: some View {
        if #available(macOS 26.0, *) {
            Section {
                Picker("Style", selection: $alertStyle) {
                    Text("Liquid Glass").tag("liquid")
                    Text("Normal").tag("normal")
                }
                .pickerStyle(.menu)
                .disabled(!alertsEnabled)
            } header: {
                InfoTipHeader(
                    title: "Alert Style",
                    tip: "Liquid Glass uses the native macOS 26 material; Normal uses a classic translucent material."
                )
            }
        } else {
            Section {
                Text("Liquid Glass alert styling requires macOS 26 or later.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } header: {
                InfoTipHeader(
                    title: "Alert Style",
                    tip: "On this version of macOS alerts use the classic translucent material."
                )
            }
        }
    }
}

/// Demo strip for the settings preview: the user's current desktop wallpaper
/// (cropped to its top edge) as the background, with the alert capsule placed
/// according to the selected position option and bottom padding.
struct AlertPositionDemo: View {
    let position: String
    let bottomPadding: Double

    private var wallpaper: NSImage? {
        let screen = NSScreen.main ?? NSScreen.screens.first
        guard let url = screen.flatMap({ NSWorkspace.shared.desktopImageURL(for: $0) }) else {
            return nil
        }
        return NSImage(contentsOf: url)
    }

    var body: some View {
        ZStack(alignment: position == "switcher" ? .center : .bottom) {
            wallpaperBackground
            SwitchAlertView(message: "Opening Sxitch")
                .padding(.bottom, position == "switcher" ? 0 : bottomPadding)
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: bottomPadding)
        .frame(maxWidth: .infinity)
        .frame(height: 150)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private var wallpaperBackground: some View {
        if let wallpaper {
            Color.clear
                .overlay(
                    Image(nsImage: wallpaper)
                        .resizable()
                        .scaledToFill(),
                    alignment: .top
                )
        } else {
            Rectangle().fill(.regularMaterial)
        }
    }
}
