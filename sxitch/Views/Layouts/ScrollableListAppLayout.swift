import AppKit
import SwiftUI

struct ScrollableListAppLayout: View {
    let apps: [any SwitchableApp]
    let typed: String
    let onTap: (any SwitchableApp) -> Void
    var selection: String?

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    ForEach(apps, id: \.id) { app in
                        RunningAppListCell(
                            app: app,
                            depth: typed.count,
                            onTap: onTap,
                            isSelected: isSelected(app)
                        )
                        .id(app.id)
                    }
                }
                .padding(6)
            }
            .onChange(of: selection) { _, newValue in
                guard let newValue,
                      let selected = apps.first(where: { $0.appName.lowercased() == newValue })
                else { return }
                withAnimation(.easeOut(duration: 0.12)) {
                    proxy.scrollTo(selected.id, anchor: .center)
                }
            }
        }
        .frame(maxHeight: maxPanelHeight)
    }

    private func isSelected(_ app: any SwitchableApp) -> Bool {
        guard let selection else { return false }
        return app.appName.lowercased() == selection
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
