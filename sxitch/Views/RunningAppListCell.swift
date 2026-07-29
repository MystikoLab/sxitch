import SwiftUI

struct RunningAppListCell: View {
    let app: RunningApp
    let depth: Int
    let onTap: (RunningApp) -> Void

    @Environment(\.modeTheme) var modeTheme

    var body: some View {
        HStack(spacing: 12) {
            ZStack(alignment: .topTrailing) {
                Image(nsImage: app.icon)
                    .resizable()
                    .frame(width: 36, height: 36)

                if let nextChar = app.appName.dropFirst(depth).first(where: { !$0.isWhitespace }) {
                    Text(String(nextChar).uppercased())
                        .foregroundStyle(app.appMode == .normal ? Color.primary : modeTheme.foregroundStyle)
                        .font(.caption2)
                        .padding(4)
                        .frame(width: 16, height: 16)
                        .background(Color(nsColor: .windowBackgroundColor).opacity(0.8))
                        .clipShape(RoundedRectangle(cornerRadius: 30))
                }
            }

            Text(app.appName)
                .opacity(0.7)
                .foregroundStyle(app.appMode == .normal ? Color.primary : modeTheme.foregroundStyle)

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
