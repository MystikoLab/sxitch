import SwiftUI

struct ManagementRulesSettingsView: View, SettingsTab {
    static let tabID = "management"
    static let tabTitle = "Management & Rules"
    static let tabIcon = "line.3.horizontal.decrease.circle"

    @AppStorage("appBlacklists") var blacklist: [String] = []
    @AppStorage("prefixStrips") var prefixStrip: [String] = ["microsoft", "adobe"]
    @AppStorage("windowPickerEnabled") private var windowPickerEnabled: Bool = true

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
                    infoText: "Apps whose name matches an entry are hidden from the switcher entirely. Matching is case-insensitive.",
                    items: $blacklist
                )
            }
            ManagedListSection(
                addHeader: "Strip Prefixes",
                listHeader: "Prefix Stripping",
                emptyMessage: "No prefixes added yet.",
                placeholder: "Prefix",
                infoText: "Leading words are removed from app names before matching, so \"Microsoft Word\" becomes \"Word\" and typing W finds it.",
                items: $prefixStrip
            )
            Section {
                HStack {
                    InfoTipHeader(
                        title: "App name override",
                        tip: "Replace an app's name with your own, changing which keypresses will trigger the app. Enter the current name on the left and the replacement on the right."
                    )
                    Spacer()
                    if !appState.isPro {
                        Label("Pro", systemImage: "lock.fill")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

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

            Section {
                HStack {
                    Toggle("Window Picker", isOn: $windowPickerEnabled)
                        .disabled(!appState.isPro)
                    SettingInfoTip(text: "When an app has multiple windows open, drill down and pick the exact window instead of just activating the app.")
                    if !appState.isPro {
                        Spacer()
                        Label("Pro", systemImage: "lock.fill")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                if !appState.isPro {
                    Text("Upgrade to Pro to pick individual windows when an app has multiple open.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .formStyle(.grouped)
        .onReceive(NotificationCenter.default.publisher(for: .appRenamesChanged)) { _ in
            // Renames can also be made from the switcher's right-click menu;
            // keep the rules list in sync without reopening Settings.
            appRenames = UserDefaults.standard.appRenames
        }
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
