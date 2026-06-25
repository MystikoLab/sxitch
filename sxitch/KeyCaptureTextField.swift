import SwiftUI

struct KeyCaptureTextField: NSViewRepresentable {
    @Binding var modifier: Int
    @Binding var keycode: Int

    func makeNSView(context: Context) -> KeyCaptureView {
        let view = KeyCaptureView()
        view.coordinator = context.coordinator
        view.font = NSFont.monospacedSystemFont(ofSize: 13, weight: .medium)
        view.stringValue = displayString()
        return view
    }

    func updateNSView(_ nsView: KeyCaptureView, context: Context) {
        nsView.stringValue = displayString()
    }

    func makeCoordinator() -> Coordinator { Coordinator(parent: self) }

    private func displayString() -> String {
        modifierString(for: modifier) + keycodeString(for: keycode)
    }

    func modifierString(for value: Int) -> String {
        switch value {
        case 0: return "⌥"
        case 1: return "⌘"
        case 2: return "⌃"
        case 3: return "⇧"
        default: return ""
        }
    }

    func keycodeString(for code: Int) -> String {
        if code == 256 { return "None" }
        let special: [Int: String] = [
            49: "Space", 48: "Tab", 36: "Return", 53: "Escape",
            12: "Q", 4: "H", 45: "N",
        ]
        if let s = special[code] { return s }
        let keyMap: [Int: String] = [
            0: "A", 11: "B", 8: "C", 2: "D", 14: "E", 3: "F", 5: "G",
            4: "H", 34: "I", 38: "J", 40: "K", 37: "L", 46: "M", 45: "N",
            31: "O", 35: "P", 12: "Q", 15: "R", 1: "S", 17: "T", 32: "U",
            9: "V", 13: "W", 7: "X", 16: "Y", 6: "Z",
            18: "1", 19: "2", 20: "3", 21: "4", 23: "5",
            22: "6", 26: "7", 28: "8", 25: "9", 29: "0",
        ]
        return keyMap[code] ?? "Key\(code)"
    }

    class Coordinator: NSObject {
        var parent: KeyCaptureTextField
        init(parent: KeyCaptureTextField) { self.parent = parent }
    }
}

// MARK: - KeyCaptureView

class KeyCaptureView: NSView {
    var coordinator: KeyCaptureTextField.Coordinator?
    var stringValue: String = "" { didSet { needsDisplay = true } }
    var font: NSFont = NSFont.monospacedSystemFont(ofSize: 13, weight: .medium)

    // Pulsing dot state
    private var pulseTimer: Timer?
    private var dotVisible = true

    override var acceptsFirstResponder: Bool { true }

    // MARK: Drawing

    override func draw(_ dirtyRect: NSRect) {
        let recording = window?.firstResponder === self

        // ── Background ────────────────────────────────────────────────────────
        let bg: NSColor =
            recording
            ? NSColor.controlAccentColor.withAlphaComponent(0.08)
            : NSColor.controlBackgroundColor
        bg.setFill()

        let rect = bounds.insetBy(dx: 0.5, dy: 0.5)
        let path = NSBezierPath(roundedRect: rect, xRadius: 5, yRadius: 5)
        path.fill()

        // ── Border ────────────────────────────────────────────────────────────
        if recording {
            NSColor.controlAccentColor.setStroke()
            path.lineWidth = 1.5
        } else {
            NSColor.separatorColor.setStroke()
            path.lineWidth = 1.0
        }
        path.stroke()

        // ── Content ───────────────────────────────────────────────────────────
        if recording {
            drawRecordingContent()
        } else {
            drawIdleContent()
        }
    }

    private func drawRecordingContent() {
        // Pulsing dot
        let dotD: CGFloat = 6
        let dotX: CGFloat = 10
        let dotY = bounds.midY - dotD / 2
        let dotPath = NSBezierPath(ovalIn: NSRect(x: dotX, y: dotY, width: dotD, height: dotD))
        let dotAlpha: CGFloat = dotVisible ? 1.0 : 0.25
        NSColor.controlAccentColor.withAlphaComponent(dotAlpha).setFill()
        dotPath.fill()

        // "Press a key…" placeholder
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 12),
            .foregroundColor: NSColor.tertiaryLabelColor,
        ]
        let str = NSAttributedString(string: "Press a key…", attributes: attrs)
        let sz = str.size()
        str.draw(
            at: NSPoint(
                x: dotX + dotD + 5,
                y: bounds.midY - sz.height / 2
            ))
    }

    private func drawIdleContent() {
        let attrs: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: NSColor.labelColor,
        ]
        let str = NSAttributedString(string: stringValue, attributes: attrs)
        let sz = str.size()
        str.draw(
            at: NSPoint(
                x: bounds.midX - sz.width / 2,
                y: bounds.midY - sz.height / 2
            ))
    }

    // MARK: Cursor

    override func resetCursorRects() {
        addCursorRect(bounds, cursor: .pointingHand)
    }

    // MARK: Responder

    override func becomeFirstResponder() -> Bool {
        startPulse()
        needsDisplay = true
        return true
    }

    override func resignFirstResponder() -> Bool {
        stopPulse()
        needsDisplay = true
        return true
    }

    override func mouseDown(with event: NSEvent) {
        window?.makeFirstResponder(self)
    }

    override func keyDown(with event: NSEvent) {
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        var modValue = 0
        if flags.contains(.option) {
            modValue = 0
        } else if flags.contains(.command) {
            modValue = 1
        } else if flags.contains(.control) {
            modValue = 2
        } else if flags.contains(.shift) {
            modValue = 3
        }

        coordinator?.parent.modifier = modValue
        coordinator?.parent.keycode = Int(event.keyCode)
        window?.makeFirstResponder(nil)
    }

    // MARK: Pulse timer

    private func startPulse() {
        stopPulse()
        dotVisible = true
        pulseTimer = Timer.scheduledTimer(withTimeInterval: 0.55, repeats: true) { [weak self] _ in
            self?.dotVisible.toggle()
            self?.needsDisplay = true
        }
    }

    private func stopPulse() {
        pulseTimer?.invalidate()
        pulseTimer = nil
        dotVisible = true
    }
}
