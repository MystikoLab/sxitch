import SwiftUI

extension View {
    @ViewBuilder
    func modernMacBackground() -> some View {
        if #available(macOS 27.0, *) {
            background(.ultraThinMaterial)
        } else {
            background(.regularMaterial)
        }
    }
}
