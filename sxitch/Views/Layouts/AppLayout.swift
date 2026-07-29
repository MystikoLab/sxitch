import SwiftUI

protocol AppLayout: View {
    associatedtype Content: View
    var apps: [RunningApp] { get }
    var typed: String { get }
    var onTap: (RunningApp) -> Void { get }
    init(apps: [RunningApp], typed: String, onTap: @escaping (RunningApp) -> Void)
}

struct AnyAppLayout: View {
    let apps: [RunningApp]
    let typed: String
    let onTap: (RunningApp) -> Void
    let layoutStyle: String

    var body: some View {
        switch layoutStyle {
        case "list":
            ListAppLayout(apps: apps, typed: typed, onTap: onTap)
        case "circle":
            CircleAppLayout(apps: apps, typed: typed, onTap: onTap)
        default:
            GridAppLayout(apps: apps, typed: typed, onTap: onTap)
        }
    }
}
