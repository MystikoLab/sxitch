import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct LayoutSettingsView: View, SettingsTab {
    static let tabID = "layout"
    static let tabTitle = "Layout"
    static let tabIcon = "rectangle.grid.2x2"

    @AppStorage("layoutStyle") var layoutStyle: String = "grid"
    @AppStorage("windowPosition") var windowPosition: String = Position.default.rawValue

    @State private var wallpaperURL: URL?
    @State private var sampleApps: [PreviewSwitchableApp] = []

    private let columns = [
        GridItem(.flexible(), spacing: 14),
        GridItem(.flexible(), spacing: 14),
    ]

    var body: some View {
        Form {
            Section {
                LazyVGrid(columns: columns, spacing: 14) {
                    LayoutShowcaseCard(
                        style: "grid", label: "Grid",
                        isSelected: layoutStyle == "grid",
                        apps: sampleApps, wallpaperURL: wallpaperURL
                    ) {
                        layoutStyle = "grid"
                    }
                    LayoutShowcaseCard(
                        style: "list", label: "List",
                        isSelected: layoutStyle == "list",
                        apps: sampleApps, wallpaperURL: wallpaperURL
                    ) {
                        layoutStyle = "list"
                    }
                    LayoutShowcaseCard(
                        style: "circle", label: "Circle",
                        isSelected: layoutStyle == "circle",
                        apps: sampleApps, wallpaperURL: wallpaperURL
                    ) {
                        layoutStyle = "circle"
                    }
                    LayoutShowcaseCard(
                        style: "scrollList", label: "Scrollable List",
                        isSelected: layoutStyle == "scrollList",
                        apps: sampleApps, wallpaperURL: wallpaperURL
                    ) {
                        layoutStyle = "scrollList"
                    }
                }
                .padding(.vertical, 4)
            } header: {
                InfoTipHeader(
                    title: "Layout",
                    tip: "How apps are arranged inside the switcher panel. Previews use real running apps and your desktop wallpaper."
                )
            }

            Section {
                HStack {
                    Text("Window Position")
                    SettingInfoTip(text: "Where the switcher panel appears on screen.")
                    Spacer()
                    Picker("Window Position", selection: $windowPosition) {
                        ForEach(Position.allCases, id: \.rawValue) { pos in
                            Text(pos.displayName).tag(pos.rawValue)
                        }
                    }
                    .labelsHidden()
                    .fixedSize()
                }
            }
        }
        .formStyle(.grouped)
        .onAppear {
            loadWallpaper()
            loadSampleApps()
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
        // Hard cap of 4 apps in every preview card.
        sampleApps = Array(
            sampleRunningApps(max: 4).prefix(4).map {
                PreviewSwitchableApp(id: $0.id, appName: $0.name, icon: $0.icon)
            }
        )
        if sampleApps.isEmpty {
            // Offline fallback so the previews are never empty.
            let placeholder = NSWorkspace.shared.icon(for: .applicationBundle)
            sampleApps = ["Safari", "Mail", "Notes", "Terminal"].prefix(4).map {
                PreviewSwitchableApp(
                    id: $0, appName: $0,
                    icon: placeholder
                )
            }
        }
    }
}

// MARK: - Sample app conforming to SwitchableApp

/// Lightweight `SwitchableApp` backed by sample data — lets the real layout
/// views render inside settings previews without a live switcher session.
struct PreviewSwitchableApp: SwitchableApp {
    let id: String
    let appName: String

    var realName: String {
        appName
    }

    let icon: NSImage
    var symbolName: String? {
        nil
    }

    var depth: Int {
        0
    }

    var runningApplication: NSRunningApplication? {
        nil
    }

    var overrideTap: ((any SwitchableApp) -> Void)? {
        nil
    }

    func activate() {}
    func hideApp() {}
    func quitApp() {}
}

// MARK: - Showcase card

/// Wallpaper-backed preview of one of the four layouts, rendered with the
/// real layout views at a fit-to-card scale. Clicking the card selects it.
struct LayoutShowcaseCard: View {
    let style: String
    let label: String
    let isSelected: Bool
    let apps: [PreviewSwitchableApp]
    let wallpaperURL: URL?
    let onTap: () -> Void

    @State private var isHovering = false

    /// Unlaid-out (1×) size of each layout's content, used to compute the
    /// fit-to-card scale. List variants are kept narrow so their panels hug
    /// the app rows instead of stretching wide.
    private var contentSize: CGSize {
        switch style {
        case "list": CGSize(width: 170, height: 162)
        case "circle": CGSize(width: 420, height: 420)
        case "scrollList": CGSize(width: 170, height: 220)
        default: CGSize(width: 400, height: 130)
        }
    }

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 6) {
                GeometryReader { geo in
                    // Fit-to-card, then shrink further (and never upscale
                    // past the cap) so each layout reads as a mini switcher.
                    let fit = min(
                        geo.size.width / contentSize.width,
                        geo.size.height / contentSize.height
                    )
                    let scale = min(fit * 0.8, 0.65)
                    ZStack {
                        wallpaper
                            .frame(width: geo.size.width, height: geo.size.height)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .strokeBorder(
                                        Color.primary.opacity(isSelected ? 0.9 : 0.2),
                                        lineWidth: isSelected ? 2 : 1
                                    )
                            )

                        panel
                            .frame(width: contentSize.width, height: contentSize.height)
                            .scaleEffect(scale)
                            .allowsHitTesting(false)
                    }
                    .frame(width: geo.size.width, height: geo.size.height)
                }
                .frame(height: 165)

                Text(label)
                    .font(.caption)
                    .foregroundStyle(isSelected ? Color.primary : Color.secondary)
                    .opacity(isSelected ? 1 : 0.7)
            }
            .scaleEffect(isSelected ? 1.02 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: isSelected)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovering = hovering
            }
        }
        .help(label)
    }

    /// The panel material behind the layout, matching how the real switcher
    /// draws it (Circle floats free over the wallpaper).
    @ViewBuilder
    private var panel: some View {
        if style == "circle" {
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

    @ViewBuilder
    private var layoutContent: some View {
        switch style {
        case "list":
            ListAppLayout(apps: apps, typed: "", onTap: { _ in })
        case "circle":
            CircleAppLayout(apps: apps, typed: "", onTap: { _ in })
        case "scrollList":
            ScrollableListAppLayout(apps: apps, typed: "", onTap: { _ in })
        default:
            GridAppLayout(apps: apps, typed: "", onTap: { _ in })
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
