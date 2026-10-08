import AppKit
import KeyboardShortcuts
import SwiftUI
import UniformTypeIdentifiers

// MARK: - All Modes

/// The Modes settings page: every custom mode with its hotkey, plus
/// add/delete. Clicking a mode drills down into its own settings page
/// (mode pages are intentionally not sidebar entries).
struct AllModesSettingsView: View, SettingsTab {
    static let tabID = "modes"
    static let tabTitle = "All Modes"
    static let tabIcon = "square.stack.3d.up"

    /// Opens a mode's settings page in the detail pane (injected by
    /// `SettingsView`).
    var onOpenMode: ((UUID) -> Void)? = nil

    private var modesModel = CustomModesModel.shared
    private var usState = userState.shared

    private var modes: [CustomMode] {
        modesModel.modes
    }

    private var atLimit: Bool {
        !usState.isPro && modes.count >= CustomModeStore.freeModeLimit
    }

    private var canAdd: Bool {
        usState.isPro || modes.count < CustomModeStore.freeModeLimit
    }

    var body: some View {
        Form {
            Section {
                if modes.isEmpty {
                    Text("No modes yet. Create one to curate your own app collections.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, minHeight: 40, alignment: .center)
                }
                ForEach(modes) { mode in
                    ModeListRow(
                        mode: mode,
                        isHotkeyEligible: hotkeyEligible(for: mode),
                        onOpen: {
                            onOpenMode?(mode.id)
                        },
                        onDelete: {
                            deleteMode(mode.id)
                        }
                    )
                }
                Button {
                    addMode()
                } label: {
                    Label("Add Mode", systemImage: "plus")
                }
                .disabled(!canAdd)
                if atLimit {
                    HStack {
                        Label("Pro", systemImage: "lock.fill")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                    }
                    Text("Upgrade to Pro for unlimited modes. Hotkeys for your first two modes work on the free plan.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } header: {
                InfoTipHeader(
                    title: "Modes",
                    tip: "Each mode shows its pinned apps and shell commands in the switcher. Assign a hotkey to summon the switcher directly into that mode. Click a mode to open its settings."
                )
            }
        }
        .formStyle(.grouped)
    }

    private func addMode() {
        let mode = CustomMode(name: "New Mode", apps: [])
        // Deferred: adds a list row and swaps the detail pane; doing it
        // synchronously inside the clicked button's table callback traps
        // AppKit (reentrant delegate mutation).
        DispatchQueue.main.async {
            var updated = modesModel.modes
            updated.append(mode)
            modesModel.save(updated)
            onOpenMode?(mode.id)
        }
    }

    private func deleteMode(_ modeID: UUID) {
        KeyboardShortcuts.reset(.customMode(modeID.uuidString))
        DispatchQueue.main.async {
            let updated = modesModel.modes.filter { $0.id != modeID }
            modesModel.save(updated)
        }
    }

    /// Mirrors the runtime: on the free plan hotkeys only fire for the
    /// first `freeModeLimit` modes.
    private func hotkeyEligible(for mode: CustomMode) -> Bool {
        usState.isPro
            || (modes.firstIndex(where: { $0.id == mode.id }) ?? Int.max)
            < CustomModeStore.freeModeLimit
    }
}

// MARK: - Mode list row

/// One row of the All Modes list: the entire row opens the mode's settings
/// page; deletion lives in the right-click context menu.
private struct ModeListRow: View {
    let mode: CustomMode
    let isHotkeyEligible: Bool
    let onOpen: () -> Void
    let onDelete: () -> Void

    @State private var isHovering = false

    var body: some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text(mode.name)
                    .fontWeight(.medium)
                if mode.apps.isEmpty {
                    Text("(no items)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            KeyboardShortcuts.Recorder(for: .customMode(mode.id.uuidString))
                .disabled(!isHotkeyEligible)
                .help(
                    isHotkeyEligible
                        ? "" : "Free plan covers hotkeys for the first 2 modes"
                )
            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(
                    isHovering ? Color.secondary : Color.secondary.opacity(0.45)
                )
        }
        // Padding lives inside the tappable button itself — the highlight
        // spans the full form row edge-to-edge.
        .padding(.vertical, 7)
        .padding(.horizontal, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isHovering ? Color.primary.opacity(0.05) : Color.clear)
        )
        .listRowInsets(EdgeInsets())
        .onHover { isHovering = $0 }
        .onTapGesture {
            onOpen()
        }
        .contextMenu {
            Button {
                onOpen()
            } label: {
                Label("Open", systemImage: "chevron.right")
            }
            Divider()
            Button(role: .destructive) {
                onDelete()
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }
}

// MARK: - Per-mode page

/// Full settings page for a single custom mode, drilled into from the All
/// Modes list (not a sidebar entry). Rename, hotkey, add/remove apps &
/// commands, and drag-to-reorder of the mode's items.
struct ModeSettingsPage: View {
    let modeID: UUID
    var onBack: () -> Void

    private var modesModel = CustomModesModel.shared
    private var usState = userState.shared

    @State private var showSymbolPicker = false
    @State private var imageTargetAppID: UUID?
    @State private var symbolTargetAppID: UUID?

    /// Free users can record hotkeys for the modes the runtime actually
    /// registers them for: the first `freeModeLimit` modes (see
    /// `AppDelegate.registerModeHotkeys`). Total count doesn't matter.
    private var canRecord: Bool {
        usState.isPro || hotkeyEligible
    }

    private var hotkeyEligible: Bool {
        guard let index = modesModel.modes.firstIndex(where: { $0.id == modeID }) else {
            return false
        }
        return index < CustomModeStore.freeModeLimit
    }

    var body: some View {
        pageContent
            .toolbar {
                ToolbarItem(placement: .destructiveAction) {
                    Button(role: .destructive) {
                        deleteMode()
                    } label: {
                        Text("Delete")
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                    }
                    .buttonStyle(.bordered)
                }
            }
            .popover(isPresented: $showSymbolPicker, arrowEdge: .bottom) {
                SFSymbolPickerView { name in
                    guard let target = symbolTargetAppID else { return }
                    if let mode = modesModel.binding(for: modeID) {
                        setSystemIcon(name, forAppID: target, mode: mode)
                    }
                    showSymbolPicker = false
                }
            }
    }

    @ViewBuilder
    private var pageContent: some View {
        if let binding = modesModel.binding(for: modeID) {
            editor(mode: binding)
        } else {
            // Deleted elsewhere (switcher context menu) while open.
            Text("This mode no longer exists.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func editor(mode: Binding<CustomMode>) -> some View {
        Form {
            Section("Mode") {
                TextField("Mode name", text: mode.name)
                HStack {
                    Text("Hotkey")
                    SettingInfoTip(text: "Summon the switcher directly into this mode.")
                    Spacer()
                    KeyboardShortcuts.Recorder(for: .customMode(modeID.uuidString))
                        .disabled(!canRecord)
                    if !canRecord {
                        Label("Pro", systemImage: "lock.fill")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Section {
                if mode.wrappedValue.apps.isEmpty {
                    Text("No items yet. Add an app or shell command to show in this mode.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                ForEach(mode.apps) { $app in
                    ModeAppRow(
                        app: $app,
                        iconMenu: { iconButton(for: $0, mode: mode) },
                        commandField: { commandField(for: $0, mode: mode) },
                        onRemoveItem: {
                            mode.wrappedValue.apps.removeAll { $0.id == app.id }
                        },
                        onMove: { draggedID in
                            moveApp(draggedID: draggedID, onto: app.id, mode: mode)
                        }
                    )
                }
                Button {
                    askAddChoice(mode: mode)
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 11, weight: .medium))
                        .frame(width: 24, height: 22)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .help("Add app or shell command")
            } header: {
                InfoTipHeader(
                    title: "Apps & Commands",
                    tip: "These items appear in the switcher when the mode is active. Drag rows up or down to change their order."
                )
            }
        }
        .formStyle(.grouped)
    }

    private func deleteMode() {
        KeyboardShortcuts.reset(.customMode(modeID.uuidString))
        // Deferred like every other detail-pane swap on this page.
        DispatchQueue.main.async {
            let updated = modesModel.modes.filter { $0.id != modeID }
            modesModel.save(updated)
            onBack()
        }
    }

    private func commandField(for app: ModeApp, mode: Binding<CustomMode>) -> some View {
        TextField(
            "e.g. brew upgrade sxitch",
            text: Binding(
                get: { app.shellCommand ?? "" },
                set: { newValue in
                    mutate(mode) { updated in
                        guard let idx = updated.apps.firstIndex(where: { $0.id == app.id })
                        else { return }
                        updated.apps[idx].shellCommand = newValue
                        if updated.apps[idx].displayName.isEmpty
                            || updated.apps[idx].displayName == "New Command"
                        {
                            updated.apps[idx].displayName = Self.defaultName(for: newValue)
                        }
                    }
                }
            )
        )
        .textFieldStyle(.roundedBorder)
        .font(.system(.callout, design: .monospaced))
    }

    /// Applies a change through the binding — the set side writes both the
    /// observable model and the store, so the switcher stays in sync live.
    private func mutate(
        _ mode: Binding<CustomMode>,
        _ change: (inout CustomMode) -> Void
    ) {
        change(&mode.wrappedValue)
    }

    private func moveApp(
        draggedID: String,
        onto targetID: UUID,
        mode: Binding<CustomMode>
    ) -> Bool {
        guard draggedID != targetID.uuidString,
              let from = mode.wrappedValue.apps.firstIndex(where: { $0.id.uuidString == draggedID }),
              let to = mode.wrappedValue.apps.firstIndex(where: { $0.id == targetID }),
              mode.wrappedValue.apps.indices.contains(from),
              mode.wrappedValue.apps.indices.contains(to)
        else { return false }
        var apps = mode.wrappedValue.apps
        let moved = apps.remove(at: from)
        apps.insert(moved, at: to)
        mode.wrappedValue.apps = apps
        return true
    }

    /// Single + button: asks whether to add an app or a shell command.
    private func askAddChoice(mode: Binding<CustomMode>) {
        let alert = NSAlert()
        alert.messageText = "Add to “\(mode.wrappedValue.name)”"
        alert.informativeText = "What do you want to add to this mode?"
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Add App")
        alert.addButton(withTitle: "Add Command")
        alert.addButton(withTitle: "Cancel")

        let handle: (NSApplication.ModalResponse) -> Void = { response in
            switch response {
            case .alertFirstButtonReturn:
                pickAppBundle(mode: mode)
            case .alertSecondButtonReturn:
                addCommand(mode: mode)
            default:
                break
            }
        }

        if let window = NSApp.keyWindow {
            alert.beginSheetModal(for: window) { response in
                handle(response)
            }
        } else {
            handle(alert.runModal())
        }
    }

    private func pickAppBundle(mode: Binding<CustomMode>) {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.applicationBundle]
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.prompt = "Add Apps"
        panel.begin { response in
            guard response == .OK, !panel.urls.isEmpty else { return }
            addApps(urls: panel.urls, mode: mode)
        }
    }

    private func pickImageFile(mode: Binding<CustomMode>) {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.image, UTType("com.apple.icns")!]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.prompt = "Choose Image"
        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            guard let target = imageTargetAppID else { return }
            setImageIcon(from: url, forAppID: target, mode: mode)
        }
    }

    private func iconButton(for app: Binding<ModeApp>, mode: Binding<CustomMode>) -> some View {
        Menu {
            Button("Choose Image File…") {
                imageTargetAppID = app.wrappedValue.id
                pickImageFile(mode: mode)
            }
            Button("SF Symbol…") {
                symbolTargetAppID = app.wrappedValue.id
                showSymbolPicker = true
            }
            Divider()
            Button("Remove icon") {
                removeIcon(from: &app.wrappedValue)
            }
        } label: {
            iconThumbnail(for: app.wrappedValue)
        }
        .menuIndicator(.hidden)
        .fixedSize()
    }

    private func iconThumbnail(for app: ModeApp) -> some View {
        Group {
            if let symbol = PinnedApp(modeApp: app).symbolName {
                Image(systemName: symbol)
                    .resizable()
                    .scaledToFit()
            } else {
                Image(nsImage: Self.thumbnailIcon(from: PinnedApp(modeApp: app).icon))
                    .resizable()
                    .interpolation(.high)
            }
        }
        .frame(width: 28, height: 28)
        .clipped()
        .padding(4)
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(Color(nsColor: .separatorColor).opacity(0.4), lineWidth: 0.5)
        )
    }

    private static func thumbnailIcon(from source: NSImage) -> NSImage {
        let side: CGFloat = 28
        return NSImage(size: NSSize(width: side, height: side), flipped: false) { dstRect in
            let srcSize = source.size
            guard srcSize.width > 0, srcSize.height > 0 else { return true }
            let scale = max(dstRect.width / srcSize.width, dstRect.height / srcSize.height)
            let drawWidth = srcSize.width * scale
            let drawHeight = srcSize.height * scale
            let drawRect = NSRect(
                x: dstRect.midX - drawWidth / 2,
                y: dstRect.midY - drawHeight / 2,
                width: drawWidth,
                height: drawHeight
            )
            source.draw(in: drawRect, from: .zero, operation: .copy, fraction: 1.0)
            return true
        }
    }

    private func addApps(urls: [URL], mode: Binding<CustomMode>) {
        let existing = Set(mode.wrappedValue.apps.map(\.bundleURL))
        var added = 0
        var skipped: [String] = []
        mutate(mode) { updated in
            for url in urls {
                let bundleURL = url.absoluteString
                if existing.contains(bundleURL) {
                    skipped.append(displayName(for: bundleURL))
                    continue
                }
                updated.apps.append(
                    ModeApp(bundleURL: bundleURL, displayName: displayName(for: bundleURL))
                )
                added += 1
            }
        }
        if !skipped.isEmpty {
            presentSkippedAlert(skippedNames: skipped, addedCount: added, mode: mode.wrappedValue)
        }
    }

    private func presentSkippedAlert(
        skippedNames: [String],
        addedCount: Int,
        mode: CustomMode
    ) {
        let alert = NSAlert()
        alert.messageText = "Already in “\(mode.name)”"
        let list = skippedNames.joined(separator: ", ")
        if addedCount == 0 {
            alert.informativeText = "These apps are already in this mode: \(list)"
        } else {
            alert.informativeText = "Added \(addedCount) app\(addedCount == 1 ? "" : "s"). Skipped (already in this mode): \(list)"
        }
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")

        if let window = NSApp.keyWindow {
            alert.beginSheetModal(for: window)
        } else {
            alert.runModal()
        }
    }

    private func addCommand(mode: Binding<CustomMode>) {
        mutate(mode) { updated in
            updated.apps.append(
                ModeApp(
                    bundleURL: "",
                    displayName: "New Command",
                    icon: .system("terminal"),
                    shellCommand: ""
                )
            )
        }
    }

    private static func defaultName(for command: String) -> String {
        let token = command
            .split(separator: " ", omittingEmptySubsequences: true)
            .first.map(String.init) ?? ""
        return token.isEmpty ? "New Command" : token
    }

    private func displayName(for bundleURL: String) -> String {
        if let url = URL(string: bundleURL), let bundle = Bundle(url: url) {
            let name = bundle.localizedInfoDictionary?["CFBundleDisplayName"] as? String
                ?? bundle.infoDictionary?["CFBundleDisplayName"] as? String
                ?? bundle.infoDictionary?["CFBundleName"] as? String
            if let name, !name.isEmpty {
                return name.filter("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz1234567890 ".contains)
            }
        }
        return URL(string: bundleURL)?.deletingPathExtension().lastPathComponent ?? "Unknown"
    }

    private func setImageIcon(from url: URL, forAppID id: UUID, mode: Binding<CustomMode>) {
        guard let pngData = Self.pngData(from: url) else { return }
        let filename = ModeIconStore.shared.save(pngData: pngData)
        mutate(mode) { updated in
            guard let idx = updated.apps.firstIndex(where: { $0.id == id }) else { return }
            updated.apps[idx].icon = .image(filename)
        }
    }

    private func setSystemIcon(_ name: String, forAppID id: UUID, mode: Binding<CustomMode>) {
        mutate(mode) { updated in
            guard let idx = updated.apps.firstIndex(where: { $0.id == id }) else { return }
            updated.apps[idx].icon = .system(name)
        }
    }

    private func removeIcon(from app: inout ModeApp) {
        if case let .image(file) = app.icon {
            ModeIconStore.shared.delete(named: file)
        }
        app.icon = nil
    }

    private static func pngData(from url: URL) -> Data? {
        if let data = try? Data(contentsOf: url), isPNG(data) {
            return data
        }
        guard let image = NSImage(contentsOf: url),
              let tiff = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiff),
              let png = bitmap.representation(using: .png, properties: [:])
        else { return nil }
        return png
    }

    private static func isPNG(_ data: Data) -> Bool {
        let signature: [UInt8] = [0x89, 0x50, 0x4E, 0x47]
        return data.count >= signature.count && data.starts(with: signature)
    }
}

private struct ModeAppRow<Icon: View, Command: View>: View {
    @Binding var app: ModeApp
    @ViewBuilder var iconMenu: (Binding<ModeApp>) -> Icon
    @ViewBuilder var commandField: (ModeApp) -> Command
    var onRemoveItem: () -> Void
    var onMove: (String) -> Bool

    @State private var isDropTarget = false
    @State private var isHovering = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Image(systemName: "line.3.horizontal")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                iconMenu($app)
                TextField("", text: $app.displayName)
                    .textFieldStyle(.roundedBorder)
                    .frame(minWidth: 180)
                if app.icon != nil {
                    Button {
                        removeCustomIcon()
                    } label: {
                        Image(systemName: "xmark.circle")
                    }
                    .help("Remove custom icon")
                    .buttonStyle(.borderless)
                }
                Button(role: .destructive) {
                    onRemoveItem()
                } label: {
                    Image(systemName: "trash")
                }
                .buttonStyle(.borderless)
            }
            if app.isShellCommand {
                commandField(app)
            }
        }
        .padding(6)
        .contentShape(Rectangle())
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(rowFill)
        )
        .overlay(alignment: .leading) {
            if isDropTarget {
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.accentColor)
                    .frame(width: 3)
                    .padding(.vertical, 4)
            }
        }
        .onHover { isHovering = $0 }
        // The entire row is the drag source — the grip is just the visual
        // cue. contentShape makes the row's full rectangle hittable, so a
        // drag can start anywhere that isn't a text field or button.
        .draggable(app.id.uuidString)
        .dropDestination(for: String.self) { payload, _ in
            guard let draggedID = payload.first else { return false }
            return onMove(draggedID)
        } isTargeted: { targeted in
            isDropTarget = targeted
        }
    }

    private var rowFill: Color {
        if isDropTarget {
            return Color.accentColor.opacity(0.12)
        }
        return isHovering ? Color.primary.opacity(0.04) : .clear
    }

    private func removeCustomIcon() {
        if case let .image(file) = app.icon {
            ModeIconStore.shared.delete(named: file)
        }
        app.icon = nil
    }
}
