import SwiftUI

struct GridAppLayout: View {
    let apps: [RunningApp]
    let typed: String
    let onTap: (RunningApp) -> Void

    @Environment(\.modeTheme) var modeTheme

    var body: some View {
        HStack {
            ForEach(
                apps.filter {
                    $0.appName.lowercased().starts(with: typed.lowercased())
                }, id: \.id
            ) { app in
                RunningAppCell(app: app, depth: typed.count, onTap: onTap)
            }
        }
        .frame(alignment: .center)
    }
}
