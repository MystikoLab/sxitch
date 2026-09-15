import SwiftUI

extension View {
    /// Panel background: native Liquid Glass when the "liquidGlass" setting is
    /// enabled (macOS 26+), otherwise the classic ultra-thin material look.
    @ViewBuilder
    func modernMacBackground(cornerRadius: CGFloat) -> some View {
        if #available(macOS 26.0, *), UserDefaults.standard.bool(forKey: "liquidGlass") {
            glassEffect(.regular, in: RoundedRectangle(cornerRadius: cornerRadius))
        } else if #available(macOS 26.0, *) {
            background(.ultraThinMaterial)
        } else {
            background(.regularMaterial)
        }
    }

    /// Glass fill used for overlay tiles (window picker cells), with a
    /// translucent color fallback for older macOS or when glass is disabled.
    @ViewBuilder
    func glassTile(cornerRadius: CGFloat) -> some View {
        if #available(macOS 26.0, *), UserDefaults.standard.bool(forKey: "liquidGlass") {
            glassEffect(
                .regular.tint(Color.primary.opacity(0.08)),
                in: RoundedRectangle(cornerRadius: cornerRadius)
            )
        } else {
            background(Color(nsColor: .windowBackgroundColor).opacity(0.4))
        }
    }
}
