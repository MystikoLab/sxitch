import AppKit

protocol SwitchableApp: Identifiable {
    var id: String { get }
    var appName: String { get }
    var icon: NSImage { get }
    var symbolName: String? { get }
    var depth: Int { get }
    var runningApplication: NSRunningApplication? { get }
    var overrideTap: ((any SwitchableApp) -> Void)? { get }
    func activate()
    func hideApp()
    func quitApp()
}