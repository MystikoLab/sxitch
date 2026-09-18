import SwiftUI

struct AppContextActions {
    var blacklist: (any SwitchableApp) -> Void
    var rename: (any SwitchableApp) -> Void
    var modes: [CustomMode]
    var addToMode: (any SwitchableApp, CustomMode) -> Void
    var togglePin: (any SwitchableApp) -> Void
}

private struct AppContextActionsKey: EnvironmentKey {
    static let defaultValue: AppContextActions? = nil
}

extension EnvironmentValues {
    var appContextActions: AppContextActions? {
        get { self[AppContextActionsKey.self] }
        set { self[AppContextActionsKey.self] = newValue }
    }
}

extension SwitchableApp {
    var pinnedBundleURL: String? {
        if let url = runningApplication?.bundleURL?.absoluteString {
            return url
        }
        return (self as? PinnedApp)?.modeApp.bundleURL
    }

    var isPinned: Bool {
        pinnedBundleURL.map { UserDefaults.standard.pinnedAppURLs.contains($0) } == true
    }
}

extension View {
    @ViewBuilder
    func appContextMenu(for app: any SwitchableApp) -> some View {
        if userState.shared.hasFullAccess, app.runningApplication != nil || app.isPinned {
            modifier(AppContextMenuModifier(app: app))
        } else {
            self
        }
    }
}

private struct AppContextMenuModifier: ViewModifier {
    let app: any SwitchableApp
    @Environment(\.appContextActions) private var actions

    func body(content: Content) -> some View {
        content.contextMenu {
            if let actions {
                let isPinned = app.isPinned

                Button {
                    actions.togglePin(app)
                } label: {
                    if isPinned {
                        Label("Unpin \"\(app.appName)\"", systemImage: "pin.slash")
                    } else {
                        Label("Pin \"\(app.appName)\"", systemImage: "pin")
                    }
                }

                if app.runningApplication != nil {
                    Button {
                        actions.blacklist(app)
                    } label: {
                        Label("Blacklist \"\(app.appName)\"", systemImage: "eye.slash")
                    }

                    Button {
                        actions.rename(app)
                    } label: {
                        Label("Rename \"\(app.appName)\"…", systemImage: "pencil")
                    }

                    if !actions.modes.isEmpty {
                        Menu {
                            ForEach(actions.modes) { mode in
                                Button {
                                    actions.addToMode(app, mode)
                                } label: {
                                    Text(mode.name)
                                }
                            }
                        } label: {
                            Label("Add to Mode", systemImage: "square.stack.3d.up")
                        }
                    }
                }
            }
        }
    }
}
