import SwiftUI

struct ListAppLayout: View {
    let apps: [any SwitchableApp]
    let typed: String
    let onTap: (any SwitchableApp) -> Void
    var selection: String?

    @Environment(\.modeTheme) var modeTheme

    private var chunkedApps: [[any SwitchableApp]] {
        apps.chunkedEvenly(maxPerRow: 10) // reuse same helper — "maxPerRow" here means "max per column"
    }

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            ForEach(chunkedApps.indices, id: \.self) { columnIndex in
                VStack(spacing: 0) {
                    ForEach(chunkedApps[columnIndex], id: \.id) { app in
                        RunningAppListCell(
                            app: app,
                            depth: typed.count,
                            onTap: onTap,
                            isSelected: isSelected(app),
                            hasSelection: selection != nil
                        )
                        .navigationPoint(app.appName.lowercased())
                    }
                }
                // Columns take their widest row's width instead of whatever
                // width the panel was last laid out at.
                .fixedSize(horizontal: true, vertical: false)
            }
        }
        .padding(6)
        .navigationFlowAxis(.vertical)
    }

    private func isSelected(_ app: any SwitchableApp) -> Bool {
        guard let selection else { return false }
        return app.appName.lowercased() == selection
    }
}
