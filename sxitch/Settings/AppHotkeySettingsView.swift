import AppKit
import Combine
import KeyboardShortcuts
import SwiftUI
import UniformTypeIdentifiers

struct AppHotkeySettingsView: View {
    @State private var hotkeys: AppHotkeys = UserDefaults.standard.appHotkeys

    @State private var runningApps = NSWorkspace.shared.runningApplications
        .filter { $0.activationPolicy == .regular }

    @State private var showPicker = false

    var body: some View {
        Section(
            header: Text("App Launch Hotkeys"),
            footer: Text("Shortcuts will launch the app even if it's not running.")
        ) {
            ForEach(Array(hotkeys.keys.sorted()), id: \.self) { bundleURL in
                HStack {
                    Text(appName(for: bundleURL))
                    Spacer()
                    KeyboardShortcuts.Recorder(for: .appLaunch(bundleURL))
                    Button(role: .destructive) {
                        KeyboardShortcuts.reset(.appLaunch(bundleURL))
                        hotkeys.removeValue(forKey: bundleURL)
                        save()
                    } label: {
                        Image(systemName: "trash")
                    }
                    .buttonStyle(.borderless)
                }
            }

            Button("Choose app") {
                showPicker = true
            }
            .fileImporter(
                isPresented: $showPicker,
                allowedContentTypes: [.applicationBundle],
                allowsMultipleSelection: false
            ) { result in
                switch result {
                case .success(let urls):
                    guard let url = urls.first else { return }
                    addApp(bundleURL: url.absoluteString)
                case .failure(let error):
                    print("Error: \(error)")
                }
            }
        }
        .onReceive(
            NSWorkspace.shared.notificationCenter
                .publisher(for: NSWorkspace.didLaunchApplicationNotification)
                .merge(
                    with: NSWorkspace.shared.notificationCenter
                        .publisher(for: NSWorkspace.didTerminateApplicationNotification)
                )
        ) { _ in
            runningApps = NSWorkspace.shared.runningApplications
                .filter { $0.activationPolicy == .regular }
        }
        .onReceive(
            NSWorkspace.shared.notificationCenter
                .publisher(for: NSWorkspace.didDeactivateApplicationNotification)
                .merge(
                    with: NSWorkspace.shared.notificationCenter
                        .publisher(for: NSWorkspace.didTerminateApplicationNotification)
                )
        ) { _ in
            runningApps = NSWorkspace.shared.runningApplications
                .filter { $0.activationPolicy == .regular }
        }
    }

    private func addApp(bundleURL: String) {
        NotificationCenter.default.post(name: .appHotkeyAdded, object: bundleURL)
        hotkeys[bundleURL] = bundleURL
        save()
    }

    private func save() {
        UserDefaults.standard.appHotkeys = hotkeys
    }

    private func appName(for bundleURL: String) -> String {
        if let app = runningApps.first(where: { $0.bundleURL?.absoluteString == bundleURL }) {
            return app.localizedName ?? bundleURL
        }
        if let url = URL(string: bundleURL), let bundle = Bundle(url: url) {
            let displayName = bundle.localizedInfoDictionary?["CFBundleDisplayName"] as? String
                ?? bundle.infoDictionary?["CFBundleDisplayName"] as? String
                ?? bundle.infoDictionary?["CFBundleName"] as? String
            if let displayName, !displayName.isEmpty {
                return displayName
            }
        }
        return URL(string: bundleURL)?.deletingPathExtension().lastPathComponent ?? bundleURL
    }
}
