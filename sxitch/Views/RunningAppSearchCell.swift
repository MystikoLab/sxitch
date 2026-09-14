
import SwiftUI

struct RunningAppSearchCell: View {
    let app: any SwitchableApp
    let depth: Int
    let typed: String
    let onTap: (any SwitchableApp) -> Void

    @Environment(\.modeTheme) var modeTheme

    private var highlightedName: Text {
        let name = app.appName
        let query = typed.lowercased()
        guard !query.isEmpty, name.lowercased().hasPrefix(query) else {
            return Text(name).foregroundStyle(modeTheme.foregroundStyle.opacity(0.7))
        }
        return Text(name.prefix(query.count))
            .fontWeight(.semibold)
            .foregroundStyle(modeTheme.foregroundStyle)
            + Text(name.dropFirst(query.count))
            .foregroundStyle(modeTheme.foregroundStyle.opacity(0.7))
    }

    var body: some View {
        HStack(spacing: 12) {
            ZStack(alignment: .topTrailing) {
                if let symbol = app.symbolName {
                    Image(systemName: symbol)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 48, height: 48)
                        .foregroundStyle(modeTheme.foregroundStyle)
                } else {
                    Image(nsImage: app.icon)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 48, height: 48)
                        .clipped()
                }

                if let nextChar = app.appName.dropFirst(depth).first(where: { !$0.isWhitespace }) {
                    Text(String(nextChar).uppercased())
                        .foregroundStyle(modeTheme.foregroundStyle)
                        .font(.caption2)
                        .padding(4)
                        .frame(width: 16, height: 16)
                        .background(Color(nsColor: .windowBackgroundColor).opacity(0.8))
                        .clipShape(RoundedRectangle(cornerRadius: 30))
                }
            }

            highlightedName
                .lineLimit(1)
                .truncationMode(.tail)
                .foregroundStyle(modeTheme.foregroundStyle)

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .contentShape(Rectangle())
        .appContextMenu(for: app)
        .onTapGesture {
            if let override = app.overrideTap {
                override(app)
            } else {
                modeTheme.appAction(app)
            }
        }
    }
}
