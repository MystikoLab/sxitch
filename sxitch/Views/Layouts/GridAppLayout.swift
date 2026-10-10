import SwiftUI

struct GridAppLayout: View {
    let apps: [any SwitchableApp]
    let typed: String
    let onTap: (any SwitchableApp) -> Void
    var selection: String?

    @Environment(\.modeTheme) var modeTheme

    private var chunkedApps: [[any SwitchableApp]] {
        apps.chunkedEvenly(maxPerRow: 10)
    }

    var body: some View {
        VStack {
            ForEach(chunkedApps.indices, id: \.self) { rowIndex in
                HStack {
                    ForEach(chunkedApps[rowIndex], id: \.id) { app in
                        RunningAppCell(
                            app: app,
                            depth: typed.count,
                            onTap: onTap,
                            isSelected: isSelected(app)
                        )
                    }
                }
            }
        }
        .frame(alignment: .center)
    }

    private func isSelected(_ app: any SwitchableApp) -> Bool {
        guard let selection else { return false }
        return app.appName.lowercased() == selection
    }
}

extension Array {
    /// Splits the array into `rows` chunks, distributed as evenly as possible.
    /// Earlier rows get the extra items if it doesn't divide evenly.
    func chunkedIntoRows(_ rows: Int) -> [[Element]] {
        guard rows > 0, !isEmpty else { return isEmpty ? [] : [self] }

        let baseSize = count / rows
        let remainder = count % rows

        var result: [[Element]] = []
        var startIndex = 0

        for row in 0 ..< rows {
            let thisRowSize = baseSize + (row < remainder ? 1 : 0)
            guard thisRowSize > 0 else { break }
            let endIndex = startIndex + thisRowSize
            result.append(Array(self[startIndex ..< endIndex]))
            startIndex = endIndex
        }

        return result
    }

    /// Splits into rows of at most `maxPerRow`, balancing items evenly
    /// across the minimum number of rows needed.
    func chunkedEvenly(maxPerRow: Int) -> [[Element]] {
        guard !isEmpty, maxPerRow > 0 else { return [] }
        let rows = (count + maxPerRow - 1) / maxPerRow // ceil(count / maxPerRow)
        return chunkedIntoRows(rows)
    }
}
