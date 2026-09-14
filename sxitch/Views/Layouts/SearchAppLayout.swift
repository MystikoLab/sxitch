import SwiftUI

struct SearchAppLayout: View {
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
        VStack(spacing: 0) {
            Section {
                Text(typed.isEmpty ? "Start Typing..." : typed)
                    .foregroundStyle(typed.isEmpty ? .secondary : .primary)
                    .animation(.easeInOut(duration: 0.2), value: typed.isEmpty)
                    .contentTransition(.opacity)
            }
            .padding(.horizontal, 6)
            .padding(.top, 6)

            ScrollView(showsIndicators: false) {
                if filteredApps.isEmpty {
                    VStack(spacing: 8) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 32))
                            .opacity(0.4)
                            .foregroundStyle(modeTheme.foregroundStyle)
                        Text("No matches")
                            .font(.headline)
                            .foregroundStyle(modeTheme.foregroundStyle)
                            .opacity(0.6)
                        Text("Check the spelling or delete a few characters")
                            .font(.caption)
                            .foregroundStyle(modeTheme.foregroundStyle)
                            .opacity(0.4)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 40)
                } else {
                    HStack(alignment: .top, spacing: 0) {
                        ForEach(chunkedApps.indices, id: \.self) { columnIndex in
                            VStack(spacing: 0) {
                                ForEach(chunkedApps[columnIndex], id: \.id) { app in
                                    RunningAppSearchCell(app: app, depth: typed.count, typed: typed, onTap: onTap)
                                }
                            }
                        }
                    }
                    .padding(6)
                }
            }
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: filteredApps.isEmpty)
            .frame(maxHeight: 500)

            if !typed.isEmpty {
                Text("\(filteredApps.count) match\(filteredApps.count == 1 ? "" : "es")")
                    .padding(.vertical, 6)
                    .frame(maxWidth: .infinity)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .animation(.easeInOut(duration: 0.2), value: filteredApps.count)
                    .contentTransition(.opacity)
            }
        }
    }
}
