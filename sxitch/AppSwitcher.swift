import Combine
import SwiftUI

@MainActor
class AppSwitcher: ObservableObject {
    @Published var apps: [RunningApp] = []
    @Published var filteredApps: [RunningApp] = []
    @Published var mode: AppMode = .normal
    @Published var typed: String = ""
    @Published var depth: Int = 0
    @Published var selectedIndex: Int = 0
    @Published var resolvedKeys: [RunningApp: String] = [:]

    let config: AppConfig
    private var cancellables = Set<AnyCancellable>()
    private let debounceQueue = DispatchQueue.main

    init(config: AppConfig) {
        self.config = config
        fetchApps()
        reResolve()
        observeNotifications()
        observeConfigChanges()
    }

    func fetchApps() {
        let allApps = NSWorkspace.shared.runningApplications
            .filter { $0.activationPolicy == .regular }
            .map { RunningApp(app: $0) }
            .sorted { $0.appName.lowercased() < $1.appName.lowercased() }

        apps = allApps
        applyFilters()
    }

    private func applyFilters() {
        var result = apps

        // Skip-prefix filter
        let skipPrefixes = config.skipPrefixesData
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces).lowercased() }
            .filter { !$0.isEmpty }

        if !skipPrefixes.isEmpty {
            result = result.filter { app in
                let name = app.appName.lowercased()
                return !skipPrefixes.contains { name.hasPrefix($0) }
            }
        }

        // Blacklist filter (Pro) — filters by bundle ID
        let blacklist = config.parsedBlacklist
        if !blacklist.isEmpty {
            result = result.filter { !blacklist.contains($0.bundleIdentifier) }
        }

        // Typed filter for NameIncrement disambiguation
        if !typed.isEmpty {
            result = result.filter { $0.appName.lowercased().hasPrefix(typed.lowercased()) }
        }

        filteredApps = result
        selectedIndex = 0
        reResolve()
    }

    private func reResolve() {
        let resolver = KeyResolverFactory.make(config.keyScheme)
        var keys = resolver.assignKeys(to: filteredApps, depth: depth)

        // Apply key overrides (Pro) — override resolver's assignment for specific bundle IDs
        let overrides = config.parsedKeyOverrides
        if !overrides.isEmpty {
            for app in filteredApps {
                if let override = overrides[app.bundleIdentifier] {
                    keys[app] = override
                }
            }
        }

        resolvedKeys = keys
    }

    func selectByKey(_ char: Character) {
        let lowerChar = char.lowercased()

        let matchingApps = filteredApps.filter { app in
            resolvedKeys[app]?.lowercased() == lowerChar
        }

        if matchingApps.count == 1, let app = matchingApps.first {
            activateApp(app)
            reset()
        } else if matchingApps.count > 1 {
            if config.keyScheme == "NameIncrement" {
                filteredApps = matchingApps
                selectedIndex = 0
                depth += 1
                typed = typed + String(char).lowercased()
                reResolve()
            } else {
                NSSound.beep()
            }
        } else {
            NSSound.beep()
        }
    }

    func activateSelection() {
        guard selectedIndex < filteredApps.count else { return }
        let app = filteredApps[selectedIndex]
        activateApp(app)
        mode = .normal
        reset()
    }

    private func activateApp(_ runningApp: RunningApp) {
        switch mode {
        case .normal:
            if let url = runningApp.bundleUrl {
                NSWorkspace.shared.open(url)
            }
        case .quit:
            let matches = NSWorkspace.shared.runningApplications
                .filter { $0.bundleIdentifier == runningApp.bundleIdentifier }
            matches.first?.terminate()
        case .hide:
            let matches = NSWorkspace.shared.runningApplications
                .filter { $0.bundleIdentifier == runningApp.bundleIdentifier }
            matches.first?.hide()
        }
    }

    func setMode(_ newMode: AppMode) {
        // Pressing the same mode hotkey again toggles back to normal.
        mode = (mode == newMode) ? .normal : newMode
        reset()
    }

    func reset() {
        typed = ""
        depth = 0
        selectedIndex = 0
        applyFilters()
    }

    func resetTyped() {
        typed = ""
        depth = 0
        applyFilters()
    }

    func cycleSelection(direction: Int) {
        guard !filteredApps.isEmpty else { return }
        let count = filteredApps.count
        selectedIndex = (selectedIndex + direction + count) % count
    }

    private func observeNotifications() {
        let nc = NSWorkspace.shared.notificationCenter
        nc.publisher(for: NSWorkspace.didLaunchApplicationNotification)
            .merge(with: nc.publisher(for: NSWorkspace.didTerminateApplicationNotification))
            .debounce(for: .milliseconds(300), scheduler: debounceQueue)
            .sink { [weak self] _ in
                self?.fetchApps()
            }
            .store(in: &cancellables)
    }

    private func observeConfigChanges() {
        config.objectWillChange
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                // Defer to the next run-loop turn so we never publish @Published
                // changes while SwiftUI's own view-update cycle is still in flight.
                // Firing synchronously here is what causes:
                //   "Publishing changes from within view updates is not allowed"
                // …and subsequently causes macOS to disable the CGEventTap.
                DispatchQueue.main.async {
                    self?.reResolve()
                }
            }
            .store(in: &cancellables)
    }
}
