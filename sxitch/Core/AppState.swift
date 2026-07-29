import Combine
import SwiftUI

class AppState: ObservableObject {
    @Published var typed: String = ""
    @Published var depth: Int = 0
    @Published var mode: AppMode = .normal
    @Published var drillDownApp: NSRunningApplication? = nil
}
