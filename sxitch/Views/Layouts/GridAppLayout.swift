import SwiftUI

struct GridAppLayout: View {
    let apps: [any SwitchableApp]
    let typed: String
    let onTap: (any SwitchableApp) -> Void

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
