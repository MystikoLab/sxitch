import SwiftUI

struct RunningAppListCell: View {
    let app: any SwitchableApp
    let depth: Int
    let onTap: (any SwitchableApp) -> Void

    @Environment(\.modeTheme) var modeTheme

    var body: some View {
        HStack(spacing: 12) {
            ZStack(alignment: .topTrailing) {
                if let symbol = app.symbolName {
                    Image(systemName: symbol)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 36, height: 36)
                        .foregroundStyle(modeTheme.foregroundStyle)
                } else {
                    Image(nsImage: app.icon)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 36, height: 36)
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

            Text(app.appName)
                .opacity(0.7)
                .foregroundStyle(modeTheme.foregroundStyle)

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .contentShape(Rectangle())
        .onTapGesture {
            if let override = app.overrideTap {
                override(app)
            } else {
                modeTheme.appAction(app)
            }
        }
    }
}
