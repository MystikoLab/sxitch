import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct IconsSettingsView: View, SettingsTab {
    static let tabID = "icons"
    static let tabTitle = "Icons"
    static let tabIcon = "app.badge"

    @AppStorage(IconStyle.scaleKey) private var scale: Double = 1
    @AppStorage(IconStyle.showBadgeKey) private var showBadge = true
    @AppStorage(IconStyle.showNameKey) private var showName = true
    @AppStorage(IconStyle.nameFontKey) private var nameFont: String = IconNameFont.regular.rawValue
    @AppStorage(IconStyle.dimUnselectedKey) private var dimUnselected = false
    @AppStorage(IconStyle.dimOpacityKey) private var dimOpacity: Double = 0.5
    @AppStorage(IconStyle.spacingKey) private var spacing: Double = 8
    @AppStorage("layoutStyle") private var layoutStyle: String = "grid"
    @AppStorage(WindowPreviewSettings.enabledKey) private var previewsEnabled = false

    private var iconSettings = IconStyleSettings()
    private var usState = userState.shared

    @State private var wallpaperURL: URL?
    @State private var sampleApps: [PreviewSwitchableApp] = []

    var body: some View {
        Form {
            Section {
                IconStyleShowcase(
                    layoutStyle: layoutStyle,
                    apps: sampleApps,
                    wallpaperURL: wallpaperURL
                )
                .environment(\.iconStyle, iconSettings.style)
                .frame(height: 240)
                .listRowBackground(Color.clear)
            } header: {
                InfoTipHeader(
                    title: "Preview",
                    tip: "Your current layout with the first app selected, using real window snapshots when Window Previews are on. Custom modes always use the default icon style."
                )
            }

            Section {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("Icon size")
                        SettingInfoTip(text: "Scales app icons in every layout. Circle rings grow to fit.")
                        Spacer()
                        Text("\(Int((scale * 100).rounded()))%")
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                        Button("Reset") { scale = 1 }
                            .disabled(scale == 1)
                    }
                    Slider(value: $scale, in: IconStyle.scaleRange, step: 0.05)
                }
            } header: {
                InfoTipHeader(title: "Size", tip: "Applies to the regular switcher, including Hide and Quit modes.")
            }

            Section {
                HStack {
                    Toggle("Show key badge", isOn: $showBadge)
                    SettingInfoTip(text: "The letter in the corner of each icon showing which key picks it.")
                }
                HStack {
                    Toggle("Show app name", isOn: $showName)
                    SettingInfoTip(text: "The name under each icon in the Grid and Circle layouts. List layouts always show names.")
                }
                Picker("Name size", selection: $nameFont) {
                    ForEach(IconNameFont.allCases, id: \.rawValue) { font in
                        Text(font.displayName).tag(font.rawValue)
                    }
                }
                .pickerStyle(.segmented)
                .disabled(!showName && layoutStyle != "list" && layoutStyle != "scrollList")
            } header: {
                proHeader("Labels", tip: "What's drawn around each icon.")
            }
            .disabled(!usState.isPro)

            Section {
                HStack {
                    Toggle("Dim unselected icons", isOn: $dimUnselected)
                    SettingInfoTip(text: "Fades every icon except the selected one. Only applies while something is selected.")
                }
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("Unselected opacity")
                        Spacer()
                        Text("\(Int((dimOpacity * 100).rounded()))%")
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }
                    Slider(value: $dimOpacity, in: IconStyle.dimOpacityRange, step: 0.05)
                }
                .disabled(!dimUnselected)
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("Spacing")
                        SettingInfoTip(text: "Gap between icons in the Grid layout, and row padding in List layouts.")
                        Spacer()
                        Text("\(Int(spacing))pt")
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }
                    Slider(value: $spacing, in: IconStyle.spacingRange, step: 1)
                }
            } header: {
                proHeader("Arrangement", tip: "How icons sit relative to each other.")
            }
            .disabled(!usState.isPro)

            if !usState.isPro {
                Section {
                    Text("Upgrade to Pro to customise labels, dimming and spacing. Your choices are kept and apply once Pro is active.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .formStyle(.grouped)
        .onAppear {
            loadWallpaper()
            loadSampleApps()
            refreshPreviews()
        }
        .onChange(of: previewsEnabled) { _, _ in refreshPreviews() }
        .onChange(of: layoutStyle) { _, _ in refreshPreviews() }
    }

    private func proHeader(_ title: String, tip: String) -> some View {
        HStack {
            InfoTipHeader(title: title, tip: tip)
            if !usState.isPro {
                Spacer()
                Label("Pro", systemImage: "lock.fill")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func loadWallpaper() {
        let screens = NSScreen.screens
        if let screen = NSScreen.main ?? screens.first {
            wallpaperURL = NSWorkspace.shared.desktopImageURL(for: screen)
        }
    }

    @MainActor
    private func loadSampleApps() {
        sampleApps = sampleRunningApps(max: 4).map {
            PreviewSwitchableApp(
                id: $0.id, appName: $0.name, icon: $0.icon,
                runningApplication: NSRunningApplication.runningApplications(withBundleIdentifier: $0.id).first
            )
        }
        if sampleApps.isEmpty {
            // Offline fallback so the preview is never empty.
            let placeholder = NSWorkspace.shared.icon(for: .applicationBundle)
            sampleApps = ["Safari", "Mail", "Notes", "Terminal"].map {
                PreviewSwitchableApp(id: $0, appName: $0, icon: placeholder)
            }
        }
    }

    /// Captures the sample apps' windows so the grid preview shows the same
    /// snapshots the switcher would. The store gates on Pro, the setting and
    /// Screen Recording itself, and cells fall back to icons without them.
    private func refreshPreviews() {
        guard WindowPreviewSettings.layoutSupportsPreviews(layoutStyle) else { return }
        WindowPreviewStore.shared.refreshApps(
            sampleApps.compactMap { $0.runningApplication?.processIdentifier }
        )
    }
}

// MARK: - Showcase

/// Wallpaper-backed render of the real layout with the first app selected,
/// shrunk to fit whatever size the icon settings produce.
private struct IconStyleShowcase: View {
    let layoutStyle: String
    let apps: [PreviewSwitchableApp]
    let wallpaperURL: URL?

    @State private var contentSize: CGSize = .zero

    var body: some View {
        GeometryReader { geo in
            let fit = contentSize.width > 0 && contentSize.height > 0
                ? min(
                    (geo.size.width - 24) / contentSize.width,
                    (geo.size.height - 24) / contentSize.height
                ) : 1
            ZStack {
                wallpaper
                    .frame(width: geo.size.width, height: geo.size.height)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .strokeBorder(Color.primary.opacity(0.15), lineWidth: 1)
                    )

                panel
                    .fixedSize()
                    .onGeometryChange(for: CGSize.self) { $0.size } action: { contentSize = $0 }
                    .scaleEffect(min(fit, 1))
                    .allowsHitTesting(false)
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
    }

    /// Matches how the real switcher draws its panel; Circle floats free.
    @ViewBuilder
    private var panel: some View {
        if layoutStyle == "circle" {
            layoutContent
        } else {
            layoutContent
                .padding(4)
                .modernMacBackground(cornerRadius: 10)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
                )
        }
    }

    private var selection: String? {
        apps.first?.appName.lowercased()
    }

    @ViewBuilder
    private var layoutContent: some View {
        switch layoutStyle {
        case "list", "scrollList":
            // The scrolling variant needs a bounded height to lay out, so
            // the preview shows its rows the plain list way.
            ListAppLayout(apps: apps, typed: "", onTap: { _ in }, selection: selection)
        case "circle":
            CircleAppLayout(apps: apps, typed: "", onTap: { _ in }, selection: selection)
        default:
            GridAppLayout(apps: apps, typed: "", onTap: { _ in }, selection: selection)
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
}
