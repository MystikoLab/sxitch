import SwiftUI

struct ArcSegment: Shape {
    let innerRadius: CGFloat
    let outerRadius: CGFloat
    let startAngle: Angle
    let endAngle: Angle

    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        var path = Path()

        // A full ring as two opposite-wound circles: the closed-arc form below
        // leaves a radial seam that Liquid Glass renders as a hard edge.
        if endAngle.radians - startAngle.radians >= 2 * .pi - 0.0001 {
            path.addArc(center: center, radius: outerRadius, startAngle: .zero, endAngle: .degrees(360), clockwise: false)
            path.closeSubpath()
            path.move(to: CGPoint(x: center.x + innerRadius, y: center.y))
            path.addArc(center: center, radius: innerRadius, startAngle: .zero, endAngle: .degrees(-360), clockwise: true)
            path.closeSubpath()
            return path
        }

        path.addArc(center: center, radius: outerRadius, startAngle: startAngle, endAngle: endAngle, clockwise: false)
        path.addArc(center: center, radius: innerRadius, startAngle: endAngle, endAngle: startAngle, clockwise: true)
        path.closeSubpath()
        return path
    }
}
