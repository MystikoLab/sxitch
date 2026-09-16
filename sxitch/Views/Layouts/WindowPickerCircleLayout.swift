import SwiftUI

struct WindowPickerCircleLayout: View {
    let windows: [WindowInfo]
    let appName: String
    let appIcon: NSImage
    let typed: String
    let onSelect: () -> Void

    @Environment(\.modeTheme) var modeTheme

    private let centerDiscSize: CGFloat = 150
    private let tileIconSize: CGFloat = 44
    private let slotSize: CGFloat = 110
    private let ringGap: CGFloat = 20 // clearance BETWEEN ring edges, not center-to-center
    private let ringIncrement: Int = 5

    private var rings: [[WindowInfo]] {
        var result: [[WindowInfo]] = []
        var startIndex = 0
        var ringNumber = 1

        while startIndex < windows.count {
            let capacity = ringIncrement * ringNumber
            let endIndex = min(startIndex + capacity, windows.count)
            result.append(Array(windows[startIndex ..< endIndex]))
            startIndex = endIndex
            ringNumber += 1
        }

        return result
    }

    private var firstRingRadius: CGFloat {
        guard !windows.isEmpty else { return centerDiscSize / 2 + slotSize / 2 + ringGap }
        let count = rings[0].count
        let totalAngle: Double = count >= 4 ? (2 * .pi) : .pi
        let segments = totalAngle == 2 * .pi ? max(count, 1) : max(count - 1, 1)
        let spacing = totalAngle / Double(segments)
        let neededRadius = max(CGFloat(slotSize / spacing) * 1.4, 50)
        return max(neededRadius, centerDiscSize / 2 + slotSize / 2 + ringGap)
    }

    private var ringRadii: [CGFloat] {
        var radii: [CGFloat] = []
        var previousOuterEdge = firstRingRadius + slotSize / 2

        for (index, ringApps) in rings.enumerated() {
            if index == 0 {
                radii.append(firstRingRadius)
                continue
            }

            let count = ringApps.count
            let totalAngle: Double = count >= 4 ? (2 * .pi) : .pi
            let segments = totalAngle == 2 * .pi ? max(count, 1) : max(count - 1, 1)
            let spacing = totalAngle / Double(segments)
            let neededRadius = max(CGFloat(slotSize / spacing) * 1.4, 50)
            let minRadius = previousOuterEdge + slotSize / 2 + ringGap

            let r = max(neededRadius, minRadius)
            radii.append(r)
            previousOuterEdge = r + slotSize / 2
        }

        return radii
    }

    var body: some View {
        ZStack {
            if windows.isEmpty {
                Text("No windows match")
                    .font(.subheadline)
                    .opacity(0.4)
                    .padding(24)
                    .glassTile(cornerRadius: 30)
            } else {
                centerDisc

                ForEach(rings.indices, id: \.self) { ringIndex in
                    ringView(windows: rings[ringIndex], radius: ringRadii[ringIndex])
                }
            }
        }
        .frame(width: overallDiameter, height: overallDiameter)
    }

    private var overallDiameter: CGFloat {
        guard let lastRadius = ringRadii.last else { return centerDiscSize }
        return (lastRadius + slotSize / 2) * 2
    }

    private var centerDisc: some View {
        VStack(spacing: 6) {
            Image(nsImage: appIcon)
                .resizable()
                .frame(width: 52, height: 52)
                .clipShape(RoundedRectangle(cornerRadius: 12))

            Text(appName)
                .font(.headline)
                .lineLimit(1)
                .truncationMode(.tail)
                .foregroundStyle(modeTheme.foregroundStyle)
                .opacity(0.9)
                .frame(maxWidth: centerDiscSize - 30)

            Text("\(windows.count) window\(windows.count == 1 ? "" : "s")")
                .font(.caption)
                .foregroundStyle(modeTheme.foregroundStyle)
                .opacity(0.5)
        }
        .frame(width: centerDiscSize, height: centerDiscSize)
        .background(Circle().fill(.ultraThinMaterial))
        .contentShape(Circle())
    }

    @ViewBuilder
    private func ringView(windows ringWindows: [WindowInfo], radius r: CGFloat) -> some View {
        let count = ringWindows.count
        let totalAngle: Double = count >= 4 ? (2 * .pi) : .pi
        let startAngle: Double = -.pi / 2 - totalAngle / 2
        let segments = totalAngle == 2 * .pi ? max(count, 1) : max(count - 1, 1)
        let spacing = totalAngle / Double(segments)

        ZStack {
            ForEach(Array(ringWindows.enumerated()), id: \.element.id) { index, _ in
                let t = Double(index) / Double(segments)
                let angle = startAngle + t * totalAngle
                let halfSpan = spacing / 2

                ArcSegment(
                    innerRadius: r - slotSize / 2,
                    outerRadius: r + slotSize / 2,
                    startAngle: Angle(radians: angle - halfSpan),
                    endAngle: Angle(radians: angle + halfSpan)
                )
                .fill(.ultraThinMaterial)
            }

            ForEach(Array(ringWindows.enumerated()), id: \.element.id) { index, window in
                let t = Double(index) / Double(segments)
                let angle = startAngle + t * totalAngle
                let x = r * CGFloat(cos(angle))
                let y = r * CGFloat(sin(angle))

                windowTile(window)
                    .offset(x: x, y: y)
            }
        }
    }

    private func windowTile(_ window: WindowInfo) -> some View {
        VStack(spacing: 4) {
            ZStack(alignment: .topTrailing) {
                Image(nsImage: appIcon)
                    .resizable()
                    .frame(width: tileIconSize, height: tileIconSize)
                    .clipShape(RoundedRectangle(cornerRadius: 10))

                if let nextChar = window.title.dropFirst(typed.count).first(where: {
                    !$0.isWhitespace
                }) {
                    Text(String(nextChar).uppercased())
                        .font(.caption2)
                        .padding(3)
                        .frame(width: 16, height: 16)
                        .background(Color(nsColor: .windowBackgroundColor).opacity(0.85))
                        .clipShape(RoundedRectangle(cornerRadius: 30))
                }
            }

            Text(window.title)
                .font(.caption2)
                .lineLimit(1)
                .truncationMode(.tail)
                .foregroundStyle(modeTheme.foregroundStyle)
                .opacity(0.85)
                .frame(maxWidth: slotSize - 20)
        }
        .frame(width: slotSize - 16, height: slotSize - 16)
        .contentShape(Rectangle())
        .onTapGesture {
            modeTheme.windowAction(window)
            onSelect()
        }
    }
}
