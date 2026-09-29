import Foundation
import Observation
import SwiftUI

/// Observable source of truth for custom modes.
///
/// Settings surfaces read `modes` directly from the shared instance — SwiftUI
/// tracks those reads and re-renders on any mutation, wherever it happens.
/// This removes the notification → @State relay chain that let the sidebar
/// linger on stale mode lists.
@Observable
final class CustomModesModel {
    static let shared = CustomModesModel()

    private(set) var modes: [CustomMode]

    private init() {
        modes = CustomModeStore.load()
    }

    /// Re-reads the store (for writers outside this model, e.g. the switcher's
    /// context menu).
    func reload() {
        modes = CustomModeStore.load()
    }

    /// Persists and publishes a new list. Posts `.customModesChanged` so
    /// non-SwiftUI consumers (AppDelegate hotkey registration) stay in sync.
    func save(_ newModes: [CustomMode]) {
        modes = newModes
        CustomModeStore.save(newModes)
        NotificationCenter.default.post(name: .customModesChanged, object: nil)
    }

    /// Replaces a single mode (per-mode editor saves).
    func update(_ mode: CustomMode) {
        var all = modes
        guard let idx = all.firstIndex(where: { $0.id == mode.id }) else { return }
        all[idx] = mode
        save(all)
    }

    func contains(_ id: UUID) -> Bool {
        modes.contains { $0.id == id }
    }

    /// A binding into the current modes list for editor sheets. Get reads the
    /// model; set writes both the model and the store (per-keystroke edits
    /// update the sidebar live via the observable `modes`).
    func binding(for id: UUID) -> Binding<CustomMode>? {
        guard contains(id) else { return nil }
        return Binding<CustomMode>(
            get: { [self] in
                modes.first { $0.id == id } ?? CustomMode(name: "", apps: [])
            },
            set: { [self] newMode in
                var all = modes
                guard let idx = all.firstIndex(where: { $0.id == id }) else { return }
                all[idx] = newMode
                modes = all
                CustomModeStore.save(all)
            }
        )
    }
}
