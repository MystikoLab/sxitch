import SwiftUI

struct WindowPickerView: View {
    let windows: [WindowInfo]
    let appName: String
    let appIcon: NSImage
    let typed: String
    let selection: String?
    let onSelect: () -> Void

    @Environment(\.modeTheme) var modeTheme

    @AppStorage("layoutStyle") private var layoutStyle: String = "grid"
    @AppStorage(WindowPreviewSettings.enabledKey) private var previewsEnabled = false
    /// Read so the cells redraw when the size changes; the value itself
    /// goes through `WindowPreviewSettings.width`.
    @AppStorage(WindowPreviewSettings.sizeKey) private var previewSize = WindowPreviewSize.medium.rawValue
    @ObservedObject private var previewStore = WindowPreviewStore.shared

    /// Thumbnail width for grid cells; nil keeps the app icon.
    private var thumbnailWidth: CGFloat? {
        previewsEnabled && WindowPreviewSettings.isActive
            && WindowPreviewSettings.layoutSupportsPreviews(layoutStyle)
            ? WindowPreviewSettings.width : nil
    }

    /// Grid cells pad their content by 8 on each side.
    private var gridCellMinimum: CGFloat {
        thumbnailWidth.map { $0 + 16 } ?? 80
    }

    /// Wide enough for two thumbnail columns, never narrower than the
    /// icon-only picker.
    private var panelWidth: CGFloat {
        guard thumbnailWidth != nil else { return 300 }
        return max(300, gridCellMinimum * 2 + 12 + 24)
    }

    var body: some View {
        if layoutStyle == "circle" {
            WindowPickerCircleLayout(
                windows: windows,
                appName: appName,
                appIcon: appIcon,
                typed: typed,
                selection: selection,
                onSelect: onSelect
            )
        } else {
            windowStack
        }
    }

    private var windowStack: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Image(nsImage: appIcon)
                    .resizable()
                    .frame(width: 20, height: 20)
                Text(appName)
                    .font(.headline)
                    .opacity(0.8)
                Spacer()
                Text("\(windows.count) window\(windows.count == 1 ? "" : "s")")
                    .font(.caption)
                    .opacity(0.4)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)

            Divider().opacity(0.4)

            if windows.isEmpty {
                Text("No windows match")
                    .font(.subheadline)
                    .opacity(0.4)
                    .padding(24)
            } else if layoutStyle == "list" {
                ScrollViewReader { _ in
                    ScrollView {
                        VStack(spacing: 0) {
                            ForEach(windows) { window in
                                windowRow(window)
                            }
                        }
                    }
                    .scrollSelectionIntoView(selection, ids: windows.map(\.title))
                }
            } else {
                ScrollViewReader { _ in
                    ScrollView {
                        LazyVGrid(
                            columns: [GridItem(.adaptive(
                                minimum: gridCellMinimum,
                                maximum: thumbnailWidth == nil ? 100 : gridCellMinimum
                            ))],
                            spacing: 12
                        ) {
                            ForEach(windows) { window in
                                windowGridCell(window)
                            }
                        }
                        .padding(12)
                    }
                    .scrollSelectionIntoView(selection, ids: windows.map(\.title))
                }
            }
        }
        .frame(width: panelWidth)
        .frame(maxHeight: thumbnailWidth == nil ? 400 : 560)
    }

    private func windowGridCell(_ window: WindowInfo) -> some View {
        VStack(spacing: 6) {
            ZStack(alignment: .topTrailing) {
                if let thumbnailWidth {
                    WindowThumbnail(
                        image: previewStore.image(forWindow: window.windowID),
                        fallbackIcon: appIcon,
                        width: thumbnailWidth
                    )
                } else {
                    Image(nsImage: appIcon)
                        .resizable()
                        .frame(width: 48, height: 48)
                }

                if !typed.isEmpty,
                   let nextChar = window.title.nextTypedCharacter(afterTyped: typed.count)
                {
                    Text(String(nextChar).uppercased())
                        .font(.caption2)
                        .padding(3)
                        .frame(width: 14, height: 14)
                        .background(Color(nsColor: .windowBackgroundColor).opacity(0.85))
                        .clipShape(RoundedRectangle(cornerRadius: 30))
                }
            }

            Text(window.title)
                .font(.caption)
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .foregroundStyle(modeTheme.foregroundStyle)
                .opacity(isSelected(window) ? 1 : 0.85)
                .fontWeight(isSelected(window) ? .semibold : .regular)
        }
        .padding(8)
        .frame(maxWidth: .infinity)
        .contentShape(RoundedRectangle(cornerRadius: 12))
        .glassTile(cornerRadius: 12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(selectionColor.opacity(isSelected(window) ? 0.9 : 0), lineWidth: 3)
        )
        .animation(.easeOut(duration: 0.12), value: isSelected(window))
        .id(window.title)
        .onTapGesture {
            modeTheme.windowAction(window)
            onSelect()
        }
    }

    @ViewBuilder
    private func windowRow(_ window: WindowInfo) -> some View {
        HStack(spacing: 12) {
            ZStack(alignment: .topTrailing) {
                Image(nsImage: appIcon)
                    .resizable()
                    .frame(width: 36, height: 36)

                if !typed.isEmpty,
                   let nextChar = window.title.nextTypedCharacter(afterTyped: typed.count)
                {
                    Text(String(nextChar).uppercased())
                        .font(.caption2)
                        .padding(3)
                        .frame(width: 14, height: 14)
                        .background(Color(nsColor: .windowBackgroundColor).opacity(0.85))
                        .clipShape(RoundedRectangle(cornerRadius: 30))
                }
            }

            Text(window.title)
                .lineLimit(1)
                .foregroundStyle(modeTheme.foregroundStyle)
                .opacity(isSelected(window) ? 1 : 0.85)
                .fontWeight(isSelected(window) ? .semibold : .regular)
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 0)
                .fill(selectionColor.opacity(isSelected(window) ? 0.18 : 0))
        )
        .contentShape(Rectangle())
        .id(window.title)
        .onTapGesture {
            modeTheme.windowAction(window)
            onSelect()
        }
        Divider().opacity(0.4)
    }
}

/// Keeps the keyboard-selected window visible when the picker list scrolls.
private extension View {
    func scrollSelectionIntoView(_ selection: String?, ids: [String]) -> some View {
        modifier(ScrollSelectionIntoView(selection: selection, ids: ids))
    }
}

private struct ScrollSelectionIntoView: ViewModifier {
    let selection: String?
    let ids: [String]

    func body(content: Content) -> some View {
        ScrollViewReader { proxy in
            content
                .onChange(of: selection) { _, newValue in
                    guard let newValue, ids.contains(newValue) else { return }
                    withAnimation(.easeOut(duration: 0.12)) {
                        proxy.scrollTo(newValue, anchor: .center)
                    }
                }
        }
    }
}

extension WindowPickerView {
    var selectionColor: Color {
        resolvedAccentColor(from: UserDefaults.standard.string(forKey: "accentColorHex") ?? "system")
            ?? .accentColor
    }

    func isSelected(_ window: WindowInfo) -> Bool {
        window.title == selection
    }
}
