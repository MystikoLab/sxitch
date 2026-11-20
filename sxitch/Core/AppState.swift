import Combine
import SwiftUI

class AppState: ObservableObject {
    @Published var typed: String = ""
    @Published var depth: Int = 0
    @Published var mode: AppMode = .normal
    @Published var activeModeID: String? = nil
    @Published var drillDownApp: NSRunningApplication? = nil
    /// Keyboard-navigated selection: the lowercased name of the selected app
    /// entry, or the window title of the selected window while drilling down.
    /// Maps to nothing when keyboard navigation is disabled.
    @Published var selectedName: String? = nil
    /// Lowercased names of the entries queued while the multi-open modifier
    /// is held, in selection order. Runs (and empties) on release.
    @Published var multiOpenQueue: [String] = []
    /// On-screen positions of the selectable items, reported by the current
    /// layout for arrow-key navigation. Not published: only read on keypress.
    var navigationLayout = NavigationLayout()
}
