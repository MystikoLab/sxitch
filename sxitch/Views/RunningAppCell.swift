import SwiftUI

struct RunningAppCell: View {
    let app: any SwitchableApp
    let depth: Int
    let onTap: (any SwitchableApp) -> Void
    var isSelected: Bool = false
    /// Pads the icon so the selection outline has room. Layouts can turn this
    /// off when keyboard navigation is disabled and nothing is ever selected.
    var reservesSelectionSpace: Bool = true
    /// Width of the window thumbnail replacing the icon; nil shows the icon.
    var previewWidth: CGFloat? = nil
    /// Whether anything in the switcher is selected, so unselected cells
    /// only dim while there's a selection to contrast with.
    var hasSelection: Bool = false

    @Environment(\.modeTheme) var modeTheme
    @Environment(\.iconStyle) private var iconStyle
    @Environment(\.multiOpenQueue) private var multiOpenQueue
    @Environment(\.multiOpenClick) private var multiOpenClick
    @ObservedObject private var previewStore = WindowPreviewStore.shared

    private var isQueued: Bool {
        multiOpenQueue.contains(app.appName.lowercased())
    }

    private var accentColor: Color {
        resolvedAccentColor(from: UserDefaults.standard.string(forKey: "accentColorHex") ?? "system")
            ?? .accentColor
    }

    /// Only running apps have windows to preview; pinned launchers and
    /// commands keep their icon.
    private var thumbnailWidth: CGFloat? {
        app.runningApplication == nil ? nil : previewWidth
    }

    private var iconSize: CGFloat {
        60 * iconStyle.scale
    }

    var body: some View {
        VStack {
            ZStack(alignment: .topTrailing) {
                if let thumbnailWidth, let pid = app.runningApplication?.processIdentifier {
                    WindowThumbnail(
                        image: previewStore.image(forApp: pid),
                        fallbackIcon: app.icon,
                        width: thumbnailWidth
                    )
                } else if let symbol = app.symbolName {
                    Image(systemName: symbol)
                        .resizable()
                        .scaledToFit()
                        .frame(width: iconSize, height: iconSize)
                        .foregroundStyle(modeTheme.foregroundStyle)
                } else {
                    Image(nsImage: app.icon)
                        .resizable()
                        .scaledToFill()
                        .frame(width: iconSize, height: iconSize)
                        .clipped()
                }

                if iconStyle.showBadge,
                   let nextChar = app.appName.dropFirst(depth).first(where: { !$0.isWhitespace })
                {
                    Text(String(nextChar).uppercased())
                        .foregroundStyle(modeTheme.foregroundStyle)
                        .font(.callout)
                        .padding(3)
                        .frame(width: 23, height: 23)
                        .background(Color(nsColor: .windowBackgroundColor).opacity(0.8))
                        .clipShape(RoundedRectangle(cornerRadius: 30))
                }
            }
            .padding(reservesSelectionSpace ? 12 : 0)
            .background(
                RoundedRectangle(cornerRadius: 22)
                    .fill(accentColor.opacity(isQueued ? 0.3 : 0))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 22)
                    .strokeBorder(isSelected ? accentColor : .clear, lineWidth: 3)
            )
            .animation(.easeOut(duration: 0.12), value: isSelected)
            .animation(.easeOut(duration: 0.12), value: isQueued)

            if iconStyle.showName {
                Text(app.appName)
                    .font(iconStyle.nameFont.font)
                    .opacity(isSelected || isQueued ? 1 : 0.7)
                    .fontWeight(isSelected || isQueued ? .semibold : .regular)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .foregroundStyle(modeTheme.foregroundStyle)
            }
        }
        .frame(maxWidth: thumbnailWidth.map { max(80, $0 + (reservesSelectionSpace ? 24 : 0)) } ?? max(64, 80 * iconStyle.scale))
        .opacity(iconStyle.opacity(isSelected: isSelected || isQueued, hasSelection: hasSelection))
        .padding(12)
        .appContextMenu(for: app)
        .onTapGesture {
            if multiOpenClick?(app) == true {
                return
            }
            if let override = app.overrideTap {
                override(app)
            } else {
                modeTheme.appAction(app)
            }
        }
    }
}
