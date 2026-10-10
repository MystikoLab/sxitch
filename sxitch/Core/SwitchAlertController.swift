import AppKit
import SwiftUI

/// Non-activating floating panel that briefly shows "Opening/Hiding/Quitting
/// <App>" near the bottom of where the switcher panel sits. Lives separately
/// from the switcher panel so the alert stays readable after the switcher
/// closes (normal-mode taps close it immediately).
final class SwitchAlertController {
    static let shared = SwitchAlertController()

    enum Verb {
        case opening
        case hiding
        case quitting

        var label: String {
            switch self {
            case .opening: return "Opening"
            case .hiding: return "Hiding"
            case .quitting: return "Quitting"
            }
        }
    }

    private let displayDuration: TimeInterval = 1.5
    private let fadeDuration: TimeInterval = 0.25

    private var panel: NSPanel?
    private let model = SwitchAlertModel()
    private var hideWork: DispatchWorkItem?

    private init() {}

    func show(_ verb: Verb, appName: String) {
        guard UserDefaults.standard.bool(forKey: "switchAlertsEnabled") else { return }
        DispatchQueue.main.async {
            self.display(verb: verb, appName: appName)
        }
    }

    /// Immediate dismissal via the alert's X button.
    func dismissNow() {
        hideWork?.cancel()
        hideWork = nil
        guard let panel, panel.isVisible else { return }
        panel.orderOut(nil)
        panel.alphaValue = 1
    }

    private func display(verb: Verb, appName: String) {
        let panel = ensurePanel()
        guard let hosting = panel.contentView as? NSHostingView<SwitchAlertPanelContent> else {
            return
        }

        hideWork?.cancel()
        model.message = "\(verb.label) \(appName)"
        hosting.rootView = SwitchAlertPanelContent(model: model)
        hosting.layoutSubtreeIfNeeded()
        position(panel: panel, size: hosting.fittingSize)

        panel.alphaValue = 1
        panel.orderFrontRegardless()

        let work = DispatchWorkItem { [weak self] in
            self?.fadeOut()
        }
        hideWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + displayDuration, execute: work)
    }

    private func fadeOut() {
        guard let panel, panel.isVisible else { return }
        NSAnimationContext.runAnimationGroup { context in
            context.duration = fadeDuration
            panel.animator().alphaValue = 0
        } completionHandler: {
            panel.orderOut(nil)
            panel.alphaValue = 1
        }
    }

    private func ensurePanel() -> NSPanel {
        if let panel {
            return panel
        }
        let newPanel = NSPanel(
            contentRect: .zero,
            styleMask: [.borderless, .fullSizeContentView, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        newPanel.isFloatingPanel = true
        newPanel.level = NSWindow.Level(NSWindow.Level.floating.rawValue + 100)
        newPanel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        newPanel.isOpaque = false
        newPanel.backgroundColor = .clear
        newPanel.hasShadow = true
        newPanel.animationBehavior = .none
        newPanel.isMovableByWindowBackground = false

        let hosting = NSHostingView(
            rootView: SwitchAlertPanelContent(model: model)
        )
        hosting.translatesAutoresizingMaskIntoConstraints = false
        newPanel.contentView = hosting
        panel = newPanel
        return newPanel
    }

    /// Positions the alert per the "switchAlertPosition" setting: centred
    /// over the switcher panel's frame, or bottom-centre of the screen.
    /// Either way it's clamped into the visible frame of the nearest screen.
    private func position(panel: NSPanel, size: NSSize) {
        let anchor = switcherFrame()
        let screen = anchor.map { frame in
            NSScreen.screens.first { $0.frame.intersects(frame) }
        } ?? NSScreen.main
        let visible = screen?.visibleFrame
            ?? NSRect(x: 0, y: 0, width: 1280, height: 800)

        let useSwitcher = UserDefaults.standard.string(forKey: "switchAlertPosition") == "switcher"
            && anchor != nil

        let centerX: CGFloat
        let centerY: CGFloat
        if useSwitcher, let anchor {
            centerX = anchor.midX
            centerY = anchor.midY
        } else {
            // Bottom padding only applies to the screen-bottom position.
            let bottomPadding = UserDefaults.standard.double(forKey: "switchAlertPadding")
            centerX = visible.midX
            centerY = visible.minY + bottomPadding + size.height / 2
        }
        let x = max(visible.minX, min(centerX - size.width / 2, visible.maxX - size.width))
        let y = max(visible.minY, min(centerY - size.height / 2, visible.maxY - size.height))
        panel.setFrame(NSRect(origin: NSPoint(x: x, y: y), size: size), display: false)
    }

    private func switcherFrame() -> NSRect? {
        NSApp.windows
            .first { $0.identifier?.rawValue == "sxitch.switcher" }?
            .frame
    }
}
