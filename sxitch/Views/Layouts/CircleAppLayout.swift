import SwiftUI

struct CircleAppLayout: View {
    let apps: [RunningApp]
    let typed: String
    let onTap: (RunningApp) -> Void

    @Environment(\.modeTheme) var modeTheme

    var body: some View {
        let filtered = apps.filter { $0.appName.lowercased().starts(with: typed.lowercased()) }
        let count = filtered.count
        let appCircleSize: CGFloat = 110
        let totalAngle: Double = count >= 4 ? (2 * .pi) : .pi
        let startAngle: Double = -.pi / 2 - totalAngle / 2

        let segments = totalAngle == 2 * .pi ? max(count, 1) : max(count - 1, 1)
        let spacing = totalAngle / Double(segments)
        let minRadius = CGFloat(appCircleSize / spacing) * 1.4
        let radius = max(minRadius, 50)

        ZStack {
            ForEach(Array(filtered.enumerated()), id: \.element.id) { index, app in
                let t = Double(index) / Double(segments)
                let angle = startAngle + t * totalAngle
                let halfSpan = spacing / 2

                ArcSegment(
                    innerRadius: radius - appCircleSize / 2,
                    outerRadius: radius + appCircleSize / 2,
                    startAngle: Angle(radians: angle - halfSpan),
                    endAngle: Angle(radians: angle + halfSpan)
                )
                .fill(.ultraThinMaterial)
            }

            ForEach(Array(filtered.enumerated()), id: \.element.id) { index, app in
                let t = Double(index) / Double(segments)
                let angle = startAngle + t * totalAngle
                let x = radius * CGFloat(cos(angle))
                let y = radius * CGFloat(sin(angle))

                RunningAppCell(app: app, depth: typed.count, onTap: onTap)
                    .rotationEffect(.radians(angle + .pi / 2))
                    .offset(x: x, y: y)
            }
        }
        .frame(width: (radius + appCircleSize) * 2, height: (radius + appCircleSize) * 2)
    }
}
