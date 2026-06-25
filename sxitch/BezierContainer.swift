import SwiftUI

// MARK: - BezierContainer

/// A container view that wraps its content in a smoothly rounded bezier-curve
/// shape, producing squircle-like corners that feel softer than a standard
/// `RoundedRectangle`.
struct BezierContainer<Content: View>: View {
    var cornerRadius: CGFloat = 20
    /// Cubic-bezier control-point distance as a fraction of `cornerRadius`.
    /// The value 0.55 closely approximates a true circular arc.
    var curvature: CGFloat = 0.55
    var background: Color = Color(.windowBackgroundColor)
    var shadowRadius: CGFloat = 12
    var shadowOpacity: Double = 0.15
    var borderColor: Color = Color.primary.opacity(0.1)
    var borderWidth: CGFloat = 0.5
    @ViewBuilder var content: () -> Content

    var body: some View {
        content()
            .background(
                BezierShape(cornerRadius: cornerRadius, curvature: curvature)
                    .fill(background)
                    .shadow(
                        color: Color.black.opacity(shadowOpacity),
                        radius: shadowRadius,
                        x: 0,
                        y: shadowRadius / 3
                    )
            )
            .overlay(
                BezierShape(cornerRadius: cornerRadius, curvature: curvature)
                    .stroke(borderColor, lineWidth: borderWidth)
            )
    }
}

// MARK: - BezierShape

/// A `Shape` that draws a rounded rectangle using cubic bezier curves at each
/// corner, producing smoother transitions than the standard quarter-circle arcs.
///
/// At each corner the path uses two control points placed at distance
/// `curvature * cornerRadius` from the corner vertex along each adjacent edge.
struct BezierShape: Shape {
    var cornerRadius: CGFloat
    var curvature: CGFloat

    func path(in rect: CGRect) -> Path {
        let r = min(cornerRadius, min(rect.width, rect.height) / 2)
        let c = curvature * r  // control-point offset

        // Convenience named anchors on each edge at the corner tangent points.
        let tl = rect.origin  // top-left origin
        let tr = CGPoint(x: rect.maxX, y: rect.minY)  // top-right origin
        let br = CGPoint(x: rect.maxX, y: rect.maxY)  // bottom-right origin
        let bl = CGPoint(x: rect.minX, y: rect.maxY)  // bottom-left origin

        var path = Path()

        // ── Start: top edge, just right of the top-left corner ──────────────
        path.move(to: CGPoint(x: tl.x + r, y: tl.y))

        // Top edge → top-right corner
        path.addLine(to: CGPoint(x: tr.x - r, y: tr.y))
        path.addCurve(
            to: CGPoint(x: tr.x, y: tr.y + r),
            control1: CGPoint(x: tr.x - c, y: tr.y),
            control2: CGPoint(x: tr.x, y: tr.y + c)
        )

        // Right edge → bottom-right corner
        path.addLine(to: CGPoint(x: br.x, y: br.y - r))
        path.addCurve(
            to: CGPoint(x: br.x - r, y: br.y),
            control1: CGPoint(x: br.x, y: br.y - c),
            control2: CGPoint(x: br.x - c, y: br.y)
        )

        // Bottom edge → bottom-left corner
        path.addLine(to: CGPoint(x: bl.x + r, y: bl.y))
        path.addCurve(
            to: CGPoint(x: bl.x, y: bl.y - r),
            control1: CGPoint(x: bl.x + c, y: bl.y),
            control2: CGPoint(x: bl.x, y: bl.y - c)
        )

        // Left edge → top-left corner
        path.addLine(to: CGPoint(x: tl.x, y: tl.y + r))
        path.addCurve(
            to: CGPoint(x: tl.x + r, y: tl.y),
            control1: CGPoint(x: tl.x, y: tl.y + c),
            control2: CGPoint(x: tl.x + c, y: tl.y)
        )

        path.closeSubpath()
        return path
    }
}

// MARK: - Preview

#Preview {
    BezierContainer(
        cornerRadius: 24,
        background: Color(.windowBackgroundColor),
        shadowRadius: 16,
        shadowOpacity: 0.2
    ) {
        VStack(spacing: 12) {
            Text("Sxitch")
                .font(.title.bold())
            Text("Smooth bezier container")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(32)
    }
    .padding(40)
}
