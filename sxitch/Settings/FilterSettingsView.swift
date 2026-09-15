import SwiftUI

struct FilterSettingsView: View, SettingsTab {
    static let tabID = "filters"
    static let tabTitle = "Filters"
    static let tabIcon = "line.3.horizontal.decrease.circle"

    @AppStorage("appBlacklists") var blacklist: [String] = []
    @AppStorage("prefixStrips") var prefixStrip: [String] = ["microsoft", "adobe"]

    private var appState = userState.shared
    @State private var openApps = RunningApp.fetchRunningApps()

    @State private var appRenames: [String: String] = UserDefaults.standard.appRenames
    @State private var newAppRename: String = ""
    @State private var newAppRenameTo: String = ""

    var body: some View {
        Form {
            if appState.isPro {
                ManagedListSection(
                    addHeader: "Blacklist Apps",
                    listHeader: "Blacklisted Apps",
                    emptyMessage: "No apps blacklisted yet.",
                    placeholder: "App name",
                    items: $blacklist
                )
            }
            ManagedListSection(
                addHeader: "Strip Prefixes",
                listHeader: "Prefix Stripping",
                emptyMessage: "No prefixes added yet.",
                placeholder: "Prefix",
                items: $prefixStrip
            )
            Section("App name override") {
                if !appState.isPro {
                    HStack {
                        Label("Pro", systemImage: "lock.fill")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                    }
                }
                Text("Override the app's name, changing which keypresses will trigger the app.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                HStack {
                    TextField("Old name", text: $newAppRename)
                        .textFieldStyle(.roundedBorder)
                        .disabled(!appState.isPro)
                    TextField("New name", text: $newAppRenameTo)
                        .textFieldStyle(.roundedBorder)
                        .disabled(!appState.isPro)
                    Button("Add", systemImage: "plus") { addAppRename() }
                        .disabled(!appState.isPro || newAppRename.trimmingCharacters(in: .whitespaces).isEmpty || newAppRenameTo.trimmingCharacters(in: .whitespaces).isEmpty)
                }

                if appRenames.isEmpty {
                    Text("No app renames configured yet.")
                        .foregroundStyle(.secondary)
                        .font(.callout)
                        .italic()
                        .frame(maxWidth: .infinity, minHeight: 60, alignment: .center)
                } else {
                    ForEach(Array(appRenames.keys.sorted()), id: \.self) { original in
                        HStack {
                            Text(original)

                            Image(systemName: "arrow.right")
                                .font(.caption)
                                .foregroundStyle(.secondary)

                            Text(appRenames[original]!)
                                .font(.system(size: 13, weight: .semibold))

                            Spacer()

                            Button(role: .destructive) {
                                appRenames.removeValue(forKey: original)
                                saveAppRenames()
                            } label: {
                                Image(systemName: "trash")
                            }
                            .buttonStyle(.borderless)
                            .disabled(!appState.isPro)
                        }
                        .padding(.vertical, 2)
                    }
                }
            }
        }
        .padding()
        .formStyle(.grouped)
    }

    private func addAppRename() {
        let original = newAppRename.trimmingCharacters(in: .whitespaces).lowercased()
        let appRename = newAppRenameTo.trimmingCharacters(in: .whitespaces)
        guard !appRename.isEmpty, original != appRename else { return }
        appRenames[original] = appRename
        saveAppRenames()
        newAppRename = ""
        newAppRenameTo = ""
    }

    private func saveAppRenames() {
        UserDefaults.standard.appRenames = appRenames
        NotificationCenter.default.post(name: .appRenamesChanged, object: nil)
    }
}
