import SwiftUI

struct LayoutPreviewCard: View {
    let style: String
    let label: String
    let isSelected: Bool
    let onTap: () -> Void
    /// Accent used for the active slot; defaults to the system accent so the
    /// settings look unchanged, while onboarding passes whitish.
    var slotTint: Color = .accentColor

    @State private var isHovering = false
    @State private var activeIndex = 0
    @State private var timer: Timer?

    private var isAnimating: Bool {
        isSelected || isHovering
    }

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 6) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.primary.opacity(0.04))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .strokeBorder(
                                    Color.primary.opacity(isSelected ? 0.9 : 0.2),
                                    lineWidth: isSelected ? 2 : 1
                                )
                        )
                        .frame(width: 92, height: 64)

                    previewContent
                        .frame(width: 72, height: 44)
                        .modifier(PreviewBackdrop(style: style))
                }
                .frame(width: 96, height: 68)

                Text(label)
                    .font(.caption)
                    .foregroundStyle(isSelected ? Color.primary : Color.secondary)
                    .opacity(isSelected ? 1 : 0.7)
            }
            .scaleEffect(isSelected ? 1.05 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: isSelected)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovering = hovering
            }
        }
        .onChange(of: isAnimating) { animating in
            if animating {
                timer?.invalidate()
                activeIndex = 0
                timer = Timer.scheduledTimer(withTimeInterval: 0.85, repeats: true) { _ in
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                        activeIndex = (activeIndex + 1) % slotCount
                    }
                }
            } else {
                timer?.invalidate()
                timer = nil
            }
        }
        .onAppear {
            if isAnimating {
                timer?.invalidate()
                timer = Timer.scheduledTimer(withTimeInterval: 0.85, repeats: true) { _ in
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                        activeIndex = (activeIndex + 1) % slotCount
                    }
                }
            }
        }
        .onDisappear {
            timer?.invalidate()
            timer = nil
        }
        .help(label)
    }

    private var slotCount: Int {
        switch style {
        case "list": return 3
        case "circle": return 5
        case "search": return 3
        default: return 4
        }
    }

    @ViewBuilder
    private var previewContent: some View {
        switch style {
        case "list": listPreview
        case "circle": circlePreview
        case "search": searchPreview
        default: gridPreview
        }
    }

    private var gridPreview: some View {
        HStack(spacing: 4) {
            ForEach(0 ..< 4, id: \.self) { index in
                QuadSlot(isActive: activeIndex == index && isAnimating, tint: slotTint)
            }
        }
    }

    private var listPreview: some View {
        VStack(spacing: 4) {
            ForEach(0 ..< 3, id: \.self) { index in
                QuadSlot(isActive: activeIndex == index && isAnimating, isListRow: true, tint: slotTint)
            }
        }
    }

    private var circlePreview: some View {
        let count = slotCount
        let radius: CGFloat = 13
        return ZStack {
            ForEach(0 ..< count, id: \.self) { index in
                let angle = (Double(index) / Double(count)) * 2 * .pi - .pi / 2
                QuadSlot(isActive: activeIndex == index && isAnimating, tint: slotTint)
                    .offset(
                        x: radius * cos(angle),
                        y: radius * sin(angle)
                    )
            }
        }
    }

    private var searchPreview: some View {
        VStack(spacing: 4) {
            SearchBarSlot()

            VStack(spacing: 3) {
                ForEach(0 ..< slotCount, id: \.self) { index in
                    QuadSlot(isActive: activeIndex == index && isAnimating, isListRow: true, size: 9, tint: slotTint)
                }
            }
            .mask(
                LinearGradient(
                    stops: [
                        .init(color: .black, location: 0.6),
                        .init(color: .clear, location: 1.0),
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
        }
    }
}

private struct PreviewBackdrop: ViewModifier {
    let style: String

    func body(content: Content) -> some View {
        if style == "circle" {
            content
        } else {
            content
                .padding(3)
                .modernMacBackground(cornerRadius: 8)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
                )
        }
    }
}

private struct QuadSlot: View {
    let isActive: Bool
    var isListRow = false
    var size: CGFloat? = nil
    var tint: Color = .accentColor

    private var resolvedWidth: CGFloat {
        size ?? (isListRow ? 20 : 14)
    }

    private var resolvedHeight: CGFloat {
        size ?? 14
    }

    var body: some View {
        RoundedRectangle(cornerRadius: isListRow ? 3 : 4)
            .fill(isActive ? tint : Color.primary.opacity(0.18))
            .frame(width: resolvedWidth, height: resolvedHeight)
            .scaleEffect(isActive ? 1.15 : 1)
            .overlay(
                RoundedRectangle(cornerRadius: isListRow ? 3 : 4)
                    .strokeBorder(
                        Color.primary.opacity(isActive ? 0 : 0.06),
                        lineWidth: 1
                    )
            )
    }
}

private struct SearchBarSlot: View {
    var body: some View {
        HStack(spacing: 3) {
            Circle()
                .strokeBorder(Color.primary.opacity(0.4), lineWidth: 1)
                .frame(width: 5, height: 5)

            RoundedRectangle(cornerRadius: 1.5)
                .fill(Color.primary.opacity(0.18))
                .frame(height: 3)
        }
        .padding(.horizontal, 5)
        .frame(height: 11)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 5)
                .fill(Color.primary.opacity(0.07))
        )
    }
}
