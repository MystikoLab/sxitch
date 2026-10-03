import Combine
import SwiftUI

/// Backing store for the alert capsule hosted in the floating panel.
@MainActor
final class SwitchAlertModel: ObservableObject {
    @Published var message: String = ""
}

/// The panel-hosted alert: model-driven so the controller can swap the
/// message without recreating the hosting view.
struct SwitchAlertPanelContent: View {
    @ObservedObject var model: SwitchAlertModel

    var body: some View {
        SwitchAlertView(message: model.message)
    }
}

/// A single switch alert: green tick, "Opening <App>" text and an X that
/// dismisses the alert instantly.
struct SwitchAlertView: View {
    let message: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
                .font(.body.weight(.semibold))

            Text(message)
                .font(.callout.weight(.medium))
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)

            Button {
                SwitchAlertController.shared.dismissNow()
            } label: {
                Image(systemName: "xmark")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .padding(3)
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .help("Dismiss")
        }
        .padding(.leading, 14)
        .padding(.trailing, 8)
        .padding(.vertical, 9)
        .alertBackground()
    }
}
