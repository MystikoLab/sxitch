import SwiftUI

struct ListAppLayout: View {
    let apps: [RunningApp]
    let typed: String
    let onTap: (RunningApp) -> Void

    @Environment(\.modeTheme) var modeTheme

    var body: some View {
        VStack(spacing: 0) {
            ForEach(apps, id: \.id) { app in
                if app.appName.lowercased().starts(with: typed.lowercased()) {
                    RunningAppListCell(app: app, depth: typed.count, onTap: onTap)
                }
            }
        }
        .padding(6)
    }
}
