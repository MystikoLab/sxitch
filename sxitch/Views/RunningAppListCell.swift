import SwiftUI

struct RunningAppListCell: View {
    let app: any SwitchableApp
    let depth: Int
    let onTap: (any SwitchableApp) -> Void
    var isSelected: Bool = false
    /// Whether anything in the switcher is selected, so unselected rows
    /// only dim while there's a selection to contrast with.
    var hasSelection: Bool = false

    @Environment(\.modeTheme) var modeTheme
    @Environment(\.iconStyle) private var iconStyle
    @Environment(\.multiOpenQueue) private var multiOpenQueue
    @Environment(\.multiOpenClick) private var multiOpenClick

    private var isQueued: Bool {
        multiOpenQueue.contains(app.appName.lowercased())
    }

    private var iconSize: CGFloat {
        36 * iconStyle.scale
    }

    private var accentColor: Color {
        resolvedAccentColor(from: UserDefaults.standard.string(forKey: "accentColorHex") ?? "system")
            ?? .accentColor
    }

    var body: some View {
        HStack(spacing: 12) {
            ZStack(alignment: .topTrailing) {
                if let symbol = app.symbolName {
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
                        .font(.caption2)
                        .padding(4)
                        .frame(width: 16, height: 16)
                        .background(Color(nsColor: .windowBackgroundColor).opacity(0.8))
                        .clipShape(RoundedRectangle(cornerRadius: 30))
                }
            }

            // List rows always keep their name; it's the row's whole label.
            Text(app.appName)
                .font(iconStyle.nameFont.font)
                .lineLimit(1)
                .truncationMode(.tail)
                .opacity(isSelected || isQueued ? 1 : 0.7)
                .fontWeight(isSelected || isQueued ? .semibold : .regular)
                .foregroundStyle(modeTheme.foregroundStyle)

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, iconStyle.spacing)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(accentColor.opacity(isQueued ? 0.3 : 0))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(accentColor.opacity(isSelected ? 0.9 : 0), lineWidth: 2)
        )
        .opacity(iconStyle.opacity(isSelected: isSelected || isQueued, hasSelection: hasSelection))
        .animation(.easeOut(duration: 0.12), value: isSelected)
        .animation(.easeOut(duration: 0.12), value: isQueued)
        .contentShape(Rectangle())
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
