import SwiftUI

struct AccentSwatch<Swatch: View>: View {
    let label: String
    let isSelected: Bool
    @ViewBuilder let swatch: () -> Swatch
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            swatch()
                .frame(width: 28, height: 28)
                .clipShape(Circle())
                .overlay(
                    Circle()
                        .strokeBorder(
                            Color.primary.opacity(isSelected ? 0.9 : 0.15),
                            lineWidth: isSelected ? 2.5 : 1
                        )
                )
                .overlay(
                    Image(systemName: "checkmark")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.white)
                        .shadow(radius: 1)
                        .opacity(isSelected ? 1 : 0)
                )
                .scaleEffect(isSelected ? 1.15 : 1)
                .animation(.spring(response: 0.25, dampingFraction: 0.7), value: isSelected)
        }
        .buttonStyle(.plain)
        .help(label)
    }
}
