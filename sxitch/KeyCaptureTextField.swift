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

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    private func displayString() -> String {
        modifierString(for: modifier) + keycodeString(for: keycode)
    }

    private func modifierString(for value: Int) -> String {
        switch value {
        case 0: return "⌥"
        case 1: return "⌘"
        case 2: return "⌃"
        case 3: return "⇧"
        default: return ""
        }
    }

    private func keycodeString(for code: Int) -> String {
        if code == 256 { return "None" }
        let special: [Int: String] = [
            49: "Space", 48: "Tab", 36: "Return", 53: "Escape",
            12: "Q", 4: "H", 45: "N"
        ]
        if let s = special[code] { return s }
        let keyMap: [Int: String] = [
            0: "A", 11: "B", 8: "C", 2: "D", 14: "E", 3: "F", 5: "G",
            4: "H", 34: "I", 38: "J", 40: "K", 37: "L", 46: "M", 45: "N",
            31: "O", 35: "P", 12: "Q", 15: "R", 1: "S", 17: "T", 32: "U",
            9: "V", 13: "W", 7: "X", 16: "Y", 6: "Z",
            18: "1", 19: "2", 20: "3", 21: "4", 23: "5",
            22: "6", 26: "7", 28: "8", 25: "9", 29: "0"
        ]
        return keyMap[code] ?? "Key\(code)"
    }

    class Coordinator: NSObject {
        var parent: KeyCaptureTextField

        init(parent: KeyCaptureTextField) {
            self.parent = parent
        }
    }
}

class KeyCaptureView: NSView {
    var coordinator: KeyCaptureTextField.Coordinator?
    var stringValue: String = "" {
        didSet { needsDisplay = true }
    }
    var font: NSFont = NSFont.monospacedSystemFont(ofSize: 13, weight: .medium)

    override var acceptsFirstResponder: Bool { true }

    override func draw(_ dirtyRect: NSRect) {
        NSColor.controlBackgroundColor.setFill()
        dirtyRect.fill()

        let path = NSBezierPath(roundedRect: bounds, xRadius: 4, yRadius: 4)
        NSColor.separatorColor.setStroke()
        path.lineWidth = 1
        path.stroke()

        let attrs: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: NSColor.labelColor
        ]
        let attrStr = NSAttributedString(string: stringValue, attributes: attrs)
        let size = attrStr.size()
        let point = NSPoint(
            x: bounds.midX - size.width / 2,
            y: bounds.midY - size.height / 2
        )
        attrStr.draw(at: point)
    }

    override func keyDown(with event: NSEvent) {
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        var modValue = 0
        if flags.contains(.option) { modValue = 0 }
        else if flags.contains(.command) { modValue = 1 }
        else if flags.contains(.control) { modValue = 2 }
        else if flags.contains(.shift) { modValue = 3 }

        coordinator?.parent.modifier = modValue
        coordinator?.parent.keycode = Int(event.keyCode)
        window?.makeFirstResponder(nil)
    }

    override func becomeFirstResponder() -> Bool {
        needsDisplay = true
        return true
    }

    override func resignFirstResponder() -> Bool {
        needsDisplay = true
        return true
    }

    override func mouseDown(with event: NSEvent) {
        window?.makeFirstResponder(self)
    }
}
