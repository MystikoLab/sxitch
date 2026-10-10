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
                            columns: [GridItem(.adaptive(minimum: 80, maximum: 100))],
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
        .frame(width: 300)
        .frame(maxHeight: 400)
    }

    private func windowGridCell(_ window: WindowInfo) -> some View {
        VStack(spacing: 6) {
            ZStack(alignment: .topTrailing) {
                Image(nsImage: appIcon)
                    .resizable()
                    .frame(width: 48, height: 48)

                if !typed.isEmpty,
                   let nextChar = window.title.dropFirst(typed.count).first(where: {
                       !$0.isWhitespace
                   })
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
                   let nextChar = window.title.dropFirst(typed.count).first(where: {
                       !$0.isWhitespace
                   })
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
