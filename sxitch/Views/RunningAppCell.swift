import SwiftUI

struct RunningAppCell: View {
    let app: any SwitchableApp
    let depth: Int
    let onTap: (any SwitchableApp) -> Void
    var isSelected: Bool = false

    @Environment(\.modeTheme) var modeTheme

    private var accentColor: Color {
        resolvedAccentColor(from: UserDefaults.standard.string(forKey: "accentColorHex") ?? "system")
            ?? .accentColor
    }

    var body: some View {
        VStack {
            ZStack(alignment: .topTrailing) {
                if let symbol = app.symbolName {
                    Image(systemName: symbol)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 60, height: 60)
                        .foregroundStyle(modeTheme.foregroundStyle)
                } else {
                    Image(nsImage: app.icon)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 60, height: 60)
                        .clipped()
                }

                if let nextChar = app.appName.dropFirst(depth).first(where: { !$0.isWhitespace }) {
                    Text(String(nextChar).uppercased())
                        .foregroundStyle(modeTheme.foregroundStyle)
                        .font(.callout)
                        .padding(3)
                        .frame(width: 23, height: 23)
                        .background(Color(nsColor: .windowBackgroundColor).opacity(0.8))
                        .clipShape(RoundedRectangle(cornerRadius: 30))
                }
            }
            .padding(12)
            .overlay(
                RoundedRectangle(cornerRadius: 22)
                    .strokeBorder(isSelected ? accentColor : .clear, lineWidth: 3)
            )
            .animation(.easeOut(duration: 0.12), value: isSelected)

            Text(app.appName)
                .opacity(isSelected ? 1 : 0.7)
                .fontWeight(isSelected ? .semibold : .regular)
                .lineLimit(1)
                .truncationMode(.tail)
                .foregroundStyle(modeTheme.foregroundStyle)
        }
        .frame(maxWidth: 80)
        .padding(12)
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
