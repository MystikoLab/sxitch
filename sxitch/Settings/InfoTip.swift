import SwiftUI

/// A small `info.circle.fill` icon that pops up an explanatory popover while
/// the pointer hovers over it. Replaces inline caption/footnote explainer
/// text next to settings.
///
/// The popover stays open while the pointer is over the icon *or* the
/// popover itself; leaving both closes it after a short grace period so the
/// icon → popover hand-off never flickers.
struct SettingInfoTip: View {
    let text: String

    @State private var isHovering = false
    @State private var dismissWorkItem: DispatchWorkItem?

    var body: some View {
        Image(systemName: "info.circle.fill")
            .foregroundStyle(.tertiary)
            .imageScale(.small)
            .padding(3)
            .contentShape(Rectangle())
            .onHover { hovering in
                hovering ? present() : scheduleDismissal()
            }
            .popover(isPresented: $isHovering, arrowEdge: .bottom) {
                Text(text)
                    .font(.callout)
                    .multilineTextAlignment(.leading)
                    .padding(10)
                    .frame(width: 240, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
                    .onHover { hovering in
                        hovering ? present() : scheduleDismissal()
                    }
            }
            .onDisappear {
                dismissWorkItem?.cancel()
            }
    }

    private func present() {
        dismissWorkItem?.cancel()
        dismissWorkItem = nil
        if !isHovering {
            isHovering = true
        }
    }

    private func scheduleDismissal() {
        dismissWorkItem?.cancel()
        let item = DispatchWorkItem { isHovering = false }
        dismissWorkItem = item
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25, execute: item)
    }
}

/// Section header with an inline info tip — for grouped forms where the
/// explanation belongs to the whole section rather than a single row.
struct InfoTipHeader: View {
    let title: String
    let tip: String

    var body: some View {
        HStack(spacing: 4) {
            Text(title)
            SettingInfoTip(text: tip)
        }
    }
}
