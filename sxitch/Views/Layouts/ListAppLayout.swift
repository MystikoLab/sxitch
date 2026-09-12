import SwiftUI

struct ListAppLayout: View {
    let apps: [any SwitchableApp]
    let typed: String
    let onTap: (any SwitchableApp) -> Void

    @Environment(\.modeTheme) var modeTheme

    private var filteredApps: [any SwitchableApp] {
        apps.filter {
            $0.appName.lowercased().starts(with: typed.lowercased())
        }
    }

    private var chunkedApps: [[any SwitchableApp]] {
        filteredApps.chunkedEvenly(maxPerRow: 10) // reuse same helper — "maxPerRow" here means "max per column"
    }

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            ForEach(chunkedApps.indices, id: \.self) { columnIndex in
                VStack(spacing: 0) {
                    ForEach(chunkedApps[columnIndex], id: \.id) { app in
                        RunningAppListCell(app: app, depth: typed.count, onTap: onTap)
                    }
                }
            }
        }
        .padding(6)
    }
}
