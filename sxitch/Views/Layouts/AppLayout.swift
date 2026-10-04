import SwiftUI

protocol AppLayout: View {
    associatedtype Content: View
    var apps: [any SwitchableApp] { get }
    var typed: String { get }
    var selection: String? { get }
    var onTap: (any SwitchableApp) -> Void { get }
    init(
        apps: [any SwitchableApp],
        typed: String,
        onTap: @escaping (any SwitchableApp) -> Void,
        selection: String?
    )
}

struct AnyAppLayout: View {
    let apps: [any SwitchableApp]
    let typed: String
    let onTap: (any SwitchableApp) -> Void
    var selection: String?
    let layoutStyle: String

    var body: some View {
        switch layoutStyle {
        case "list":
            ListAppLayout(apps: apps, typed: typed, onTap: onTap, selection: selection)
        case "circle":
            CircleAppLayout(apps: apps, typed: typed, onTap: onTap, selection: selection)
        case "scrollList":
            ScrollableListAppLayout(apps: apps, typed: typed, onTap: onTap, selection: selection)
        default:
            GridAppLayout(apps: apps, typed: typed, onTap: onTap, selection: selection)
        }
    }
}
