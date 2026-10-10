import SwiftUI

struct AppearanceSettingsView: View, SettingsTab {
    static let tabID = "appearance"
    static let tabTitle = "Appearance"
    static let tabIcon = "paintpalette.fill"

    @AppStorage("accentColorHex") var accentColorHex: String = "system"
    @AppStorage("liquidGlass") var liquidGlass: Bool = true
    @AppStorage("showPickerUi") var showUi = true
    @AppStorage("showMenuIcon") var showMenuIcon: Bool = true

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
            Section {
                HStack {
                    Toggle("Show picker UI", isOn: $showUi)
                    SettingInfoTip(text: "Turn off to run Sxitch invisibly — apps still activate, but the switcher panel is never drawn.")
                }
                HStack {
                    Toggle("Show menubar icon", isOn: $showMenuIcon)
                    SettingInfoTip(text: "Shows the Sxitch status item in the menu bar for quick access to settings and modes.")
                }
            } header: {
                InfoTipHeader(
                    title: "Switcher UI",
                    tip: "Controls what Sxitch draws while you switch."
                )
            }

            Section {
                HStack {
                    Toggle("Liquid Glass", isOn: $liquidGlass)
                    SettingInfoTip(text: "Apply the native Liquid Glass material to the switcher overlay (macOS 26+).")
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
        .formStyle(.grouped)
    }
}
