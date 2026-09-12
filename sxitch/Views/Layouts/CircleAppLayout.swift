import SwiftUI

struct CircleAppLayout: View {
    let apps: [any SwitchableApp]
    let typed: String
    let onTap: (any SwitchableApp) -> Void

    @Environment(\.modeTheme) var modeTheme

    private let appCircleSize: CGFloat = 110
    private let ringGap: CGFloat = 20 // clearance BETWEEN ring edges, not center-to-center
    private let ringIncrement: Int = 5 // ring N's capacity = ringIncrement * N

    private var filtered: [any SwitchableApp] {
        apps.filter { $0.appName.lowercased().starts(with: typed.lowercased()) }
    }

    // Ring 1 holds 5, ring 2 holds 10, ring 3 holds 15, etc.
    private var rings: [[any SwitchableApp]] {
        var result: [[any SwitchableApp]] = []
        var startIndex = 0
        var ringNumber = 1

        while startIndex < filtered.count {
            let capacity = ringIncrement * ringNumber
            let endIndex = min(startIndex + capacity, filtered.count)
            result.append(Array(filtered[startIndex..<endIndex]))
            startIndex = endIndex
            ringNumber += 1
        }

        return result
    }

    // Computed cumulatively so each ring's radius clears the previous
    // ring's actual outer edge, regardless of how full either ring is.
    private var ringRadii: [CGFloat] {
        var radii: [CGFloat] = []
        var previousOuterEdge: CGFloat = 0

        for (index, ringApps) in rings.enumerated() {
            let count = ringApps.count
            let totalAngle: Double = count >= 4 ? (2 * .pi) : .pi
            let segments = totalAngle == 2 * .pi ? max(count, 1) : max(count - 1, 1)
            let spacing = totalAngle / Double(segments)
            let neededRadius = max(CGFloat(appCircleSize / spacing) * 1.4, 50)

            let r: CGFloat
            if index == 0 {
                r = neededRadius
            } else {
                let minRadius = previousOuterEdge + appCircleSize / 2 + ringGap
                r = max(neededRadius, minRadius)
            }

            radii.append(r)
            previousOuterEdge = r + appCircleSize / 2
        }

        return radii
    }

    var body: some View {
        ZStack {
            ForEach(rings.indices, id: \.self) { ringIndex in
                ringView(apps: rings[ringIndex], radius: ringRadii[ringIndex])
            }
        }
        .frame(width: overallDiameter, height: overallDiameter)
    }

    private var overallDiameter: CGFloat {
        guard let lastRadius = ringRadii.last else { return appCircleSize }
        return (lastRadius + appCircleSize) * 2
    }

    @ViewBuilder
    private func ringView(apps ringApps: [any SwitchableApp], radius r: CGFloat) -> some View {
        let count = ringApps.count
        let totalAngle: Double = count >= 4 ? (2 * .pi) : .pi
        let startAngle: Double = -.pi / 2 - totalAngle / 2
        let segments = totalAngle == 2 * .pi ? max(count, 1) : max(count - 1, 1)
        let spacing = totalAngle / Double(segments)

        ZStack {
            ForEach(Array(ringApps.enumerated()), id: \.element.id) { index, _ in
                let t = Double(index) / Double(segments)
                let angle = startAngle + t * totalAngle
                let halfSpan = spacing / 2

                ArcSegment(
                    innerRadius: r - appCircleSize / 2,
                    outerRadius: r + appCircleSize / 2,
                    startAngle: Angle(radians: angle - halfSpan),
                    endAngle: Angle(radians: angle + halfSpan)
                )
                .fill(.ultraThinMaterial)
            }

            ForEach(Array(ringApps.enumerated()), id: \.element.id) { index, app in
                let t = Double(index) / Double(segments)
                let angle = startAngle + t * totalAngle
                let x = r * CGFloat(cos(angle))
                let y = r * CGFloat(sin(angle))

                RunningAppCell(app: app, depth: typed.count, onTap: onTap)
                    .offset(x: x, y: y)
            }
        }
    }
}
