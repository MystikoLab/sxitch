import SwiftUI

extension View {
    /// Panel background: native Liquid Glass when the "liquidGlass" setting is
    /// enabled (macOS 26+), otherwise the classic ultra-thin material look.
    func modernMacBackground(cornerRadius: CGFloat) -> some View {
        modifier(GlassSurface(
            shape: RoundedRectangle(cornerRadius: cornerRadius),
            tint: nil,
            fallback: .material
        ))
    }

    /// Glass fill used for overlay tiles (window picker cells), with a
    /// translucent color fallback for older macOS or when glass is disabled.
    func glassTile(cornerRadius: CGFloat) -> some View {
        modifier(GlassSurface(
            shape: RoundedRectangle(cornerRadius: cornerRadius),
            tint: Color.primary.opacity(0.08),
            fallback: .windowColor
        ))
    }

    /// Glass behind an arbitrary shape (Circle layout rings, center disc).
    /// Falls back to ultra-thin material so the non-glass look is unchanged.
    /// `edgeSoftness` feathers the glass rim by that many points (glass only).
    func glassSurface(in shape: some Shape, edgeSoftness: CGFloat = 0) -> some View {
        modifier(GlassSurface(
            shape: shape,
            tint: nil,
            fallback: .ultraThinMaterial,
            edgeSoftness: edgeSoftness
        ))
    }

    /// Capsule background for switch alerts. Honors the independent
    /// "switchAlertStyle" setting: native Liquid Glass on macOS 26+, otherwise
    /// the classic material look.
    @ViewBuilder
    func alertBackground() -> some View {
        if #available(macOS 26.0, *),
           UserDefaults.standard.string(forKey: "switchAlertStyle") == "liquid"
        {
            glassEffect(.regular, in: Capsule())
        } else if #available(macOS 26.0, *) {
            background(.ultraThinMaterial, in: Capsule())
        } else {
            background(.regularMaterial, in: Capsule())
        }
    }
}

/// Observes "liquidGlass" through @AppStorage so toggling it in Settings
/// re-renders already-visible surfaces. The glass path is what picks up the
/// system-wide Liquid Glass transparency preference; materials ignore it.
private struct GlassSurface<S: Shape>: ViewModifier {
    enum Fallback {
        /// .ultraThinMaterial on macOS 26+, .regularMaterial before.
        case material
        case ultraThinMaterial
        case windowColor
    }

    let shape: S
    let tint: Color?
    let fallback: Fallback
    var edgeSoftness: CGFloat = 0

    @AppStorage("liquidGlass") private var liquidGlass: Bool = true

    func body(content: Content) -> some View {
        if #available(macOS 26.0, *), liquidGlass {
            if edgeSoftness > 0 {
                content
                    .glassEffect(.regular.tint(tint), in: shape)
                    .mask { shape.blur(radius: edgeSoftness) }
            } else {
                content.glassEffect(.regular.tint(tint), in: shape)
            }
        } else {
            switch fallback {
            case .material:
                if #available(macOS 26.0, *) {
                    content.background(.ultraThinMaterial, in: shape)
                } else {
                    content.background(.regularMaterial, in: shape)
                }
            case .ultraThinMaterial:
                content.background(.ultraThinMaterial, in: shape)
            case .windowColor:
                content.background(Color(nsColor: .windowBackgroundColor).opacity(0.4), in: shape)
            }
        }
    }
}
