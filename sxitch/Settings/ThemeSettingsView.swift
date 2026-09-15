import SwiftUI

struct ThemeSettingsView: View, SettingsTab {
    static let tabID = "appearance"
    static let tabTitle = "Appearance"
    static let tabIcon = "paintpalette.fill"

    @AppStorage("accentColorHex") var accentColorHex: String = "system"
    @AppStorage("layoutStyle") var layoutStyle: String = "grid"
    @AppStorage("windowPosition") var windowPosition: String = Position.default.rawValue
    @AppStorage("showPickerUi") var showUi = true
    @AppStorage("windowPickerEnabled") private var windowPickerEnabled: Bool = true

    private var usState = userState.shared

    private let presets: [(name: String, color: Color)] = [
        ("Blue", .blue),
        ("Purple", .purple),
        ("Pink", .pink),
        ("Red", .red),
        ("Orange", .orange),
        ("Yellow", .yellow),
        ("Green", .green),
        ("Mint", .mint),
        ("Teal", .teal),
        ("Indigo", .indigo),
    ]

    var body: some View {
        Form {
            Section("Layout") {
                HStack(spacing: 12) {
                    LayoutPreviewCard(
                        style: "grid",
                        label: "Grid",
                        isSelected: layoutStyle == "grid"
                    ) {
                        layoutStyle = "grid"
                    }
                    LayoutPreviewCard(
                        style: "list",
                        label: "List",
                        isSelected: layoutStyle == "list"
                    ) {
                        layoutStyle = "list"
                    }
                    LayoutPreviewCard(
                        style: "circle",
                        label: "Circle",
                        isSelected: layoutStyle == "circle"
                    ) {
                        layoutStyle = "circle"
                    }
                    LayoutPreviewCard(
                        style: "search",
                        label: "search",
                        isSelected: layoutStyle == "search"
                    ) {
                        layoutStyle = "search"
                    }
                }
                .padding(.vertical, 4)

                Picker("Window Position", selection: $windowPosition) {
                    ForEach(Position.allCases, id: \.rawValue) { pos in
                        Text(pos.displayName).tag(pos.rawValue)
                    }
                }
            }

            Section("Switcher UI") {
                Toggle("Show picker UI", isOn: $showUi)
                HStack {
                    Toggle("Window Picker", isOn: $windowPickerEnabled)
                        .disabled(!usState.isPro)
                    if !usState.isPro {
                        Spacer()
                        Label("Pro", systemImage: "lock.fill")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                if !usState.isPro {
                    Text("Upgrade to Pro to pick individual windows when an app has multiple open.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Section("Accent Colour") {
                HStack(spacing: 10) {
                    AccentSwatch(
                        label: "System",
                        isSelected: accentColorHex == "system"
                    ) {
                        ZStack {
                            Circle().fill(
                                AngularGradient(
                                    colors: [
                                        .blue, .purple, .pink, .red, .orange, .yellow, .green,
                                        .blue,
                                    ],
                                    center: .center
                                )
                            )
                        }
                    } onTap: {
                        accentColorHex = "system"
                    }

                    ForEach(presets, id: \.name) { preset in
                        AccentSwatch(
                            label: preset.name,
                            isSelected: accentColorHex == preset.color.hexString
                        ) {
                            Circle().fill(preset.color)
                        } onTap: {
                            accentColorHex = preset.color.hexString
                        }
                    }
                }
                .padding(.vertical, 4)
            }
        }
        .padding()
        .formStyle(.grouped)
    }
}
