import AppKit
import SwiftUI

extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}

extension Color {
    init?(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        guard hex.count == 6 else { return nil }
        var value: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&value)
        self.init(
            red: Double((value >> 16) & 0xFF) / 255,
            green: Double((value >> 8) & 0xFF) / 255,
            blue: Double(value & 0xFF) / 255
        )
    }

    var hexString: String {
        if let ns = NSColor(self).usingColorSpace(.sRGB) {
            return String(
                format: "%02X%02X%02X",
                Int((ns.redComponent.clamped(to: 0 ... 1) * 255).rounded()),
                Int((ns.greenComponent.clamped(to: 0 ... 1) * 255).rounded()),
                Int((ns.blueComponent.clamped(to: 0 ... 1) * 255).rounded())
            )
        }
        if let ns = NSColor(self).usingColorSpace(.deviceRGB) {
            return String(
                format: "%02X%02X%02X",
                Int((ns.redComponent.clamped(to: 0 ... 1) * 255).rounded()),
                Int((ns.greenComponent.clamped(to: 0 ... 1) * 255).rounded()),
                Int((ns.blueComponent.clamped(to: 0 ... 1) * 255).rounded())
            )
        }
        let cg = NSColor(self).cgColor
        let cs = CGColorSpace(name: CGColorSpace.sRGB)!
        if let converted = cg.converted(to: cs, intent: .defaultIntent, options: nil),
           let c = converted.components, c.count >= 3
        {
            return String(
                format: "%02X%02X%02X",
                Int((c[0].clamped(to: 0 ... 1) * 255).rounded()),
                Int((c[1].clamped(to: 0 ... 1) * 255).rounded()),
                Int((c[2].clamped(to: 0 ... 1) * 255).rounded())
            )
        }
        return "0000FF"
    }
}

func resolvedAccentColor(from hex: String) -> Color? {
    guard hex != "system" else { return nil }
    return Color(hex: hex)
}
