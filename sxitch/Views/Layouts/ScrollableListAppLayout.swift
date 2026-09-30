import AppKit
import SwiftUI

struct ScrollableListAppLayout: View {
    let apps: [any SwitchableApp]
    let typed: String
    let onTap: (any SwitchableApp) -> Void

    private var filteredApps: [any SwitchableApp] {
        apps.filter {
            $0.appName.lowercased().starts(with: typed.lowercased())
        }
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 0) {
                ForEach(filteredApps, id: \.id) { app in
                    RunningAppListCell(app: app, depth: typed.count, onTap: onTap)
                }
            }
            .padding(6)
        }
        .frame(maxHeight: maxPanelHeight)
    }

    /// The panel grows with content up to 75% of the screen height, then
    /// scrolls instead of stretching further.
    private var maxPanelHeight: CGFloat {
        if let screen = NSScreen.main {
            return screen.visibleFrame.height * 0.75
        }
        return 500
    }
}
