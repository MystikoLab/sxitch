import AppKit
import KeyboardShortcuts
import SwiftUI
import UniformTypeIdentifiers

struct CustomModesSettingsView: View {
    @State private var modes: [CustomMode] = CustomModeStore.load()
    @State private var editingIndex: Int?
    private var usState = userState.shared

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
                ForEach(Array(modes.enumerated()), id: \.element.id) { index, mode in
                    HStack(spacing: 8) {
                        Text(mode.name)
                            .fontWeight(.medium)
                        if mode.apps.isEmpty {
                            Text("(no apps)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        KeyboardShortcuts.Recorder(for: .customMode(mode.id.uuidString))
                            .disabled(atLimit)
                        Button {
                            editingIndex = index
                        } label: {
                            Image(systemName: "pencil")
                        }
                        .buttonStyle(.borderless)
                        Button(role: .destructive) {
                            deleteMode(mode)
                        } label: {
                            Image(systemName: "trash")
                        }
                        .buttonStyle(.borderless)
                    }
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
                    Text("Upgrade to Pro for unlimited modes and mode hotkeys.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } header: {
                Text("Modes")
            } footer: {
                Text("Each mode shows its pinned apps in the switcher. Assign a hotkey to summon the switcher directly into that mode.")
            }
        }
        .formStyle(.grouped)
        .padding()
        .onChange(of: modes) { _, _ in
            save()
        }
        .sheet(
            isPresented: Binding(
                get: { editingIndex != nil },
                set: { if !$0 { editingIndex = nil } }
            )
        ) {
            if let idx = editingIndex {
                ModeEditorView(mode: $modes[idx], canRecord: !atLimit)
            }
        }
    }

    private func save() {
        CustomModeStore.save(modes)
        NotificationCenter.default.post(name: .customModesChanged, object: nil)
    }

    private func addMode() {
        modes.append(CustomMode(name: "New Mode", apps: []))
        editingIndex = modes.count - 1
    }

    private func deleteMode(_ mode: CustomMode) {
        KeyboardShortcuts.reset(.customMode(mode.id.uuidString))
        modes.removeAll { $0.id == mode.id }
    }
}

struct ModeEditorView: View {
    @Binding var mode: CustomMode
    let canRecord: Bool

    @Environment(\.dismiss) private var dismiss

    @State private var showSymbolPicker = false
    @State private var imageTargetAppID: UUID?
    @State private var symbolTargetAppID: UUID?

    var body: some View {
        Form {
            Section("Mode") {
                TextField("Mode name", text: $mode.name)
                HStack {
                    Text("Hotkey")
                    Spacer()
                    KeyboardShortcuts.Recorder(for: .customMode(mode.id.uuidString))
                        .disabled(!canRecord)
                }
            }
            Section("Apps") {
                if mode.apps.isEmpty {
                    Text("No apps yet. Add an app to show in this mode.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                ForEach($mode.apps) { $app in
                    HStack(spacing: 8) {
                        iconButton(for: $app)
                        TextField("", text: $app.displayName)
                            .textFieldStyle(.roundedBorder)
                            .frame(minWidth: 180)
                        Button {
                            removeIcon(from: &app)
                        } label: {
                            Image(systemName: "xmark.circle")
                        }
                        .help("Remove custom icon")
                        .buttonStyle(.borderless)
                        Button(role: .destructive) {
                            mode.apps.removeAll { $0.id == app.id }
                        } label: {
                            Image(systemName: "trash")
                        }
                        .buttonStyle(.borderless)
                    }
                }
                Button {
                    pickAppBundle()
                } label: {
                    Label("Add App", systemImage: "plus")
                }
            }
        }
        .formStyle(.grouped)
        .frame(minWidth: 480, minHeight: 360)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Done") { dismiss() }
            }
        }
    }

    private func pickAppBundle() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.applicationBundle]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.prompt = "Add App"
        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            addApp(bundleURL: url.absoluteString)
        }
    }

    private func pickImageFile() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.image, UTType("com.apple.icns")!]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.prompt = "Choose Image"
        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            guard let target = imageTargetAppID else { return }
            setImageIcon(from: url, forAppID: target)
        }
    }

    @ViewBuilder
    private func iconButton(for app: Binding<ModeApp>) -> some View {
        Menu {
            Button("Choose Image File…") {
                imageTargetAppID = app.wrappedValue.id
                pickImageFile()
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
        .popover(isPresented: $showSymbolPicker, arrowEdge: .bottom) {
            SFSymbolPickerView { name in
                guard let target = symbolTargetAppID else { return }
                setSystemIcon(name, forAppID: target)
                showSymbolPicker = false
            }
        }
    }

    @ViewBuilder
    private func iconThumbnail(for app: ModeApp) -> some View {
        Group {
            if let symbol = PinnedApp(modeApp: app).symbolName {
                Image(systemName: symbol)
                    .resizable()
                    .scaledToFit()
            } else {
                Image(nsImage: PinnedApp(modeApp: app).icon)
                    .resizable()
            }
        }
        .frame(width: 28, height: 28)
        .padding(4)
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(Color(nsColor: .separatorColor).opacity(0.4), lineWidth: 0.5)
        )
    }

    private func addApp(bundleURL: String) {
        mode.apps.append(
            ModeApp(bundleURL: bundleURL, displayName: displayName(for: bundleURL))
        )
    }

    private func displayName(for bundleURL: String) -> String {
        if let url = URL(string: bundleURL), let bundle = Bundle(url: url) {
            let name = bundle.localizedInfoDictionary?["CFBundleDisplayName"] as? String
                ?? bundle.infoDictionary?["CFBundleDisplayName"] as? String
                ?? bundle.infoDictionary?["CFBundleName"] as? String
            if let name, !name.isEmpty {
                return name
            }
        }
        return URL(string: bundleURL)?.deletingPathExtension().lastPathComponent ?? "Unknown"
    }

    private func setImageIcon(from url: URL, forAppID id: UUID) {
        guard let pngData = Self.pngData(from: url),
              let idx = mode.apps.firstIndex(where: { $0.id == id })
        else { return }
        let filename = ModeIconStore.shared.save(pngData: pngData)
        mode.apps[idx].icon = .image(filename)
    }

    private func setSystemIcon(_ name: String, forAppID id: UUID) {
        guard let idx = mode.apps.firstIndex(where: { $0.id == id }) else { return }
        mode.apps[idx].icon = .system(name)
    }

    private func removeIcon(from app: inout ModeApp) {
        if case .image(let file) = app.icon {
            ModeIconStore.shared.delete(named: file)
        }
        app.icon = nil
    }

    private static func pngData(from url: URL) -> Data? {
        if let data = try? Data(contentsOf: url), Self.isPNG(data) {
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
