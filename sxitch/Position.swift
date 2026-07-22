import AppKit

enum Position: String, CaseIterable, Codable {
    case `default`
    case topLeft
    case topCenter
    case topRight
    case middleLeft
    case middleCenter
    case middleRight
    case bottomLeft
    case bottomCenter
    case bottomRight

    var displayName: String {
        switch self {
        case .default: "Default"
        case .topLeft: "Top Left"
        case .topCenter: "Top Center"
        case .topRight: "Top Right"
        case .middleLeft: "Middle Left"
        case .middleCenter: "Middle Center"
        case .middleRight: "Middle Right"
        case .bottomLeft: "Bottom Left"
        case .bottomCenter: "Bottom Center"
        case .bottomRight: "Bottom Right"
        }
    }

    func point(for size: NSSize, on screen: NSScreen) -> NSPoint {
        let frame = screen.frame
        switch self {
        case .default:
            return NSPoint(
                x: frame.origin.x + (frame.width - size.width) / 2,
                y: frame.origin.y + (frame.height - size.height) / 2
            )
        case .topLeft:
            return NSPoint(x: frame.origin.x, y: frame.origin.y + frame.height - size.height)
        case .topCenter:
            return NSPoint(
                x: frame.origin.x + (frame.width - size.width) / 2,
                y: frame.origin.y + frame.height - size.height
            )
        case .topRight:
            return NSPoint(
                x: frame.origin.x + frame.width - size.width,
                y: frame.origin.y + frame.height - size.height
            )
        case .middleLeft:
            return NSPoint(
                x: frame.origin.x,
                y: frame.origin.y + (frame.height - size.height) / 2
            )
        case .middleCenter:
            return NSPoint(
                x: frame.origin.x + (frame.width - size.width) / 2,
                y: frame.origin.y + (frame.height - size.height) / 2
            )
        case .middleRight:
            return NSPoint(
                x: frame.origin.x + frame.width - size.width,
                y: frame.origin.y + (frame.height - size.height) / 2
            )
        case .bottomLeft:
            return NSPoint(x: frame.origin.x, y: frame.origin.y)
        case .bottomCenter:
            return NSPoint(
                x: frame.origin.x + (frame.width - size.width) / 2,
                y: frame.origin.y
            )
        case .bottomRight:
            return NSPoint(
                x: frame.origin.x + frame.width - size.width,
                y: frame.origin.y
            )
        }
    }
}
