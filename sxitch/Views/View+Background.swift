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
