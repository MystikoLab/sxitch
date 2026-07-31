import SwiftUI

struct RunningAppCell: View {
    let app: RunningApp
    let depth: Int
    let onTap: (RunningApp) -> Void

    @Environment(\.modeTheme) var modeTheme

    var body: some View {
        VStack {
            ZStack(alignment: .topTrailing) {
                Image(nsImage: app.icon)
                    .resizable()
                    .frame(width: 60, height: 60)

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
            Text(app.appName)
                .opacity(0.7)
                .foregroundStyle(modeTheme.foregroundStyle)
        }
        .frame(maxWidth: 60)
        .padding(20)
        .onTapGesture {
            if let override = app.overrideTap {
                override(app)
            } else {
                modeTheme.appAction(app)
            }
        }
    }
}
