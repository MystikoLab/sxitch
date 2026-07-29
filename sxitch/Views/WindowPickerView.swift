import SwiftUI

struct WindowPickerView: View {
    let windows: [WindowInfo]
    let appName: String
    let appIcon: NSImage
    let typed: String
    let onSelect: () -> Void

    @Environment(\.modeTheme) var modeTheme

    @AppStorage("layoutStyle") private var layoutStyle: String = "grid"

    var filtered: [WindowInfo] {
        typed.isEmpty
            ? windows
            : windows.filter { $0.title.lowercased().starts(with: typed.lowercased()) }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Image(nsImage: appIcon)
                    .resizable()
                    .frame(width: 20, height: 20)
                Text(appName)
                    .font(.headline)
                    .opacity(0.8)
                Spacer()
                Text("\(filtered.count) window\(filtered.count == 1 ? "" : "s")")
                    .font(.caption)
                    .opacity(0.4)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)

            Divider().opacity(0.4)

            if filtered.isEmpty {
                Text("No windows match")
                    .font(.subheadline)
                    .opacity(0.4)
                    .padding(24)
            } else if layoutStyle == "list" {
                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(filtered) { window in
                            windowRow(window)
                        }
                    }
                }
            } else {
                ScrollView {
                    LazyVGrid(
                        columns: [GridItem(.adaptive(minimum: 80, maximum: 100))],
                        spacing: 12
                    ) {
                        ForEach(filtered) { window in
                            windowGridCell(window)
                        }
                    }
                    .padding(12)
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
                .opacity(0.85)
        }
        .padding(8)
        .frame(maxWidth: .infinity)
        .contentShape(RoundedRectangle(cornerRadius: 12))
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(nsColor: .windowBackgroundColor).opacity(0.4))
        )
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
                .opacity(0.85)
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .contentShape(Rectangle())
        .onTapGesture {
            modeTheme.windowAction(window)
            onSelect()
        }
        Divider().opacity(0.4)
    }
}
