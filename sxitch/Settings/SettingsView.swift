import SwiftUI

struct SettingsView: View {
    private var usState = userState.shared
    @AppStorage("accentColorHex") var accentColorHex: String = "system"
    @AppStorage("selectedSettingsTab") private var selectedTab: String = "general"

    @State private var hostWindow: NSWindow?
    @State private var windowObservers: [NSObjectProtocol] = []

    var accentColor: Color {
        resolvedAccentColor(from: accentColorHex) ?? .accentColor
    }

    var tabs: [AnySettingsTab] {
        let all = RegisteredTabs.all
        return all.map { tab in
            if tab.id == "activate" {
                AnySettingsTab(
                    id: tab.id, title: tab.title,
                    icon: usState.hasFullAccess ? "lock.open" : "lock",
                    content: tab.content
                )
            } else {
                tab
            }
        }
    }

    private func sidebarIconColor(for id: String) -> Color {
        switch id {
        case "general": .gray
        case "keyboard": .indigo
        case "appearance": .pink
        case "modes": .orange
        case "filters": .teal
        case "activate": .green
        default: .gray
        }
    }

    var selectedContent: some View {
        ZStack {
            Color(nsColor: .windowBackgroundColor)
            if let tab = tabs.first(where: { $0.id == selectedTab }) {
                tab.content
            }
        }
    }

    var body: some View {
        NavigationSplitView {
            List(selection: Binding(
                get: { selectedTab },
                set: {
                    if let value = $0 {
                        selectedTab = value
                    }
                }
            )) {
                ForEach(tabs) { tab in
                    Label {
                        Text(tab.title)
                    } icon: {
                        Image(systemName: tab.icon)
                            .symbolRenderingMode(.hierarchical)
                            .foregroundStyle(sidebarIconColor(for: tab.id))
                    }
                    .tag(tab.id)
                }
            }
            .listStyle(.sidebar)
            .frame(minWidth: 180)
            .navigationTitle("Sxitch")
        } detail: {
            selectedContent
        }
        .tint(accentColor)
        .frame(minWidth: 840, minHeight: 580)
        .background(
            WindowAccessor(window: $hostWindow)
                .frame(width: 0, height: 0)
        )
        .onChange(of: hostWindow) { _, newWindow in
            configure(window: newWindow)
        }
        .onAppear {
            NSApp.setActivationPolicy(.regular)
            NSApp.activate(ignoringOtherApps: true)
            configure(window: hostWindow)
        }
        .onDisappear {
            NSApp.setActivationPolicy(.accessory)
        }
    }

    private func configure(window: NSWindow?) {
        guard let window = window else { return }
        window.styleMask.insert([.miniaturizable, .resizable])
        window.toolbarStyle = .unifiedCompact
        window.contentMinSize = NSSize(width: 840, height: 580)
        window.maxSize = NSSize(
            width: CGFloat.greatestFiniteMagnitude,
            height: CGFloat.greatestFiniteMagnitude
        )
        DispatchQueue.main.async {
            if let toolbar = window.toolbar {
                for item in toolbar.items
                    where String(describing: item.action).contains("toggleSidebar")
                {
                    toolbar.removeItem(identifier: item.itemIdentifier)
                }
            }
        }
        for observer in windowObservers {
            NotificationCenter.default.removeObserver(observer)
        }
        windowObservers.removeAll()
        windowObservers.append(
            NotificationCenter.default.addObserver(
                forName: NSWindow.willCloseNotification, object: window, queue: .main
            ) { _ in
                NSApp.setActivationPolicy(.accessory)
            }
        )
    }
}

struct WindowAccessor: NSViewRepresentable {
    @Binding var window: NSWindow?

    func makeNSView(context _: Context) -> NSView {
        let view = WindowFinderView()
        view.onWindowFound = { window = $0 }
        return view
    }

    func updateNSView(_: NSView, context _: Context) {}

    final class WindowFinderView: NSView {
        var onWindowFound: ((NSWindow?) -> Void)?

        override func viewDidMoveToWindow() {
            onWindowFound?(window)
        }
    }
}
