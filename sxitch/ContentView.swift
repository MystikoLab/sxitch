import SwiftUI

extension Notification.Name {
    static let openSettings = Notification.Name("com.sxitch.openSettings")
}

struct ContentView: View {
    @Environment(\.openSettings) private var openSettings
    @Environment(\.colorScheme) private var colorScheme
    @ObservedObject var appSwitcher: AppSwitcher

    @State private var windowPickerApp: RunningApp? = nil

    var body: some View {
        Group {
            if !appSwitcher.config.enableUI {
                // UI disabled — keep a 1×1 invisible view so the window stays alive
                // and the openSettings notification can still be received.
                Color.clear
                    .frame(width: 1, height: 1)
                    .onReceive(NotificationCenter.default.publisher(for: .openSettings)) { _ in
                        openSettings()
                    }
            } else if let pickerApp = windowPickerApp {
                WindowPickerView(
                    app: pickerApp,
                    isPresented: Binding(
                        get: { windowPickerApp != nil },
                        set: { if !$0 { windowPickerApp = nil } }
                    ),
                    layout: appSwitcher.config.layout
                )
                .transition(
                    .asymmetric(
                        insertion: .move(edge: .trailing).combined(with: .opacity),
                        removal: .move(edge: .trailing).combined(with: .opacity)
                    ))
            } else {
                mainSwitcher
                    .transition(.opacity)
            }
        }
        .animation(.easeOut(duration: 0.15), value: windowPickerApp?.id)
    }

    // MARK: - Main Switcher

    private var mainSwitcher: some View {
        VStack(spacing: 8) {
            if appSwitcher.mode != .normal {
                modeBanner
                    .transition(.move(edge: .top).combined(with: .opacity))
            }

            if appSwitcher.filteredApps.isEmpty {
                Text("No matching apps")
                    .foregroundStyle(.secondary)
                    .padding(40)
            } else if appSwitcher.config.layout == "List" {
                listLayout
            } else {
                gridLayout
            }
        }
        .background(backgroundContent)
        .clipShape(RoundedRectangle(cornerRadius: 30))
        .overlay(
            RoundedRectangle(cornerRadius: 30)
                .stroke(.separator, lineWidth: 0.5)
        )
        .preferredColorScheme(appSwitcher.config.effectiveColorScheme)
        .frame(maxWidth: .infinity, alignment: .center)
        .animation(.easeOut(duration: 0.2), value: appSwitcher.mode)
        .animation(.easeOut(duration: 0.075), value: appSwitcher.filteredApps.count)
        .onReceive(NotificationCenter.default.publisher(for: .openSettings)) { _ in
            openSettings()
        }
    }

    // MARK: - Background

    @ViewBuilder
    private var backgroundContent: some View {
        if appSwitcher.config.blur {
            Rectangle().fill(.ultraThinMaterial)
        } else {
            let theme = appSwitcher.config.currentTheme(for: colorScheme)
            Rectangle().fill(theme.background)
        }
    }

    // MARK: - Grid Layout

    private var gridLayout: some View {
        HStack(spacing: 12) {
            ForEach(Array(appSwitcher.filteredApps.enumerated()), id: \.element.id) { index, app in
                AppCell(
                    app: app,
                    keyText: appSwitcher.config.showKeys
                        ? appSwitcher.resolvedKeys[app] ?? "" : "",
                    isSelected: index == appSwitcher.selectedIndex,
                    mode: appSwitcher.mode
                )
                .onTapGesture {
                    handleAppTap(app: app, at: index)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    // MARK: - List Layout

    private var listLayout: some View {
        VStack(spacing: 4) {
            ForEach(Array(appSwitcher.filteredApps.enumerated()), id: \.element.id) { index, app in
                AppListRow(
                    app: app,
                    keyText: appSwitcher.config.showKeys
                        ? appSwitcher.resolvedKeys[app] ?? "" : "",
                    isSelected: index == appSwitcher.selectedIndex,
                    mode: appSwitcher.mode
                )
                .onTapGesture {
                    handleAppTap(app: app, at: index)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }

    // MARK: - Mode Banner

    private var modeBanner: some View {
        HStack(spacing: 8) {
            Image(systemName: modeIcon)
                .font(.system(size: 14, weight: .bold))
                .contentTransition(.symbolEffect(.replace))
            Text(appSwitcher.mode.displayName)
                .font(.system(size: 12, weight: .semibold))
        }
        .foregroundStyle(appSwitcher.mode.tintColor)
        .padding(.horizontal, 14)
        .padding(.vertical, 6)
        .background(Capsule().fill(appSwitcher.mode.tintColor.opacity(0.15)))
        .overlay(Capsule().stroke(appSwitcher.mode.tintColor.opacity(0.3), lineWidth: 1))
        .padding(.top, 10)
    }

    private var modeIcon: String {
        switch appSwitcher.mode {
        case .quit: return "xmark.circle.fill"
        case .hide: return "eye.slash.fill"
        case .normal: return ""
        }
    }

    // MARK: - Tap Handler

    private func handleAppTap(app: RunningApp, at index: Int) {
        appSwitcher.selectedIndex = index
        if appSwitcher.config.windowPicking && appSwitcher.config.isPro {
            windowPickerApp = app
        } else {
            appSwitcher.activateSelection()
        }
    }
}

// MARK: - AppCell (Grid)

struct AppCell: View {
    let app: RunningApp
    let keyText: String
    let isSelected: Bool
    let mode: AppMode

    var body: some View {
        VStack(spacing: 6) {
            ZStack(alignment: .topTrailing) {
                Image(nsImage: app.icon)
                    .resizable()
                    .frame(width: 70, height: 70)
                    .clipShape(RoundedRectangle(cornerRadius: 16))

                if !keyText.isEmpty {
                    Text(keyText.uppercased())
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.primary)
                        .frame(width: 22, height: 22)
                        .background(.thinMaterial)
                        .clipShape(Circle())
                        .overlay(Circle().stroke(.separator, lineWidth: 0.5))
                        .offset(x: 4, y: -4)
                }

                // Mode indicator overlay
                if mode != .normal {
                    Image(systemName: mode == .quit ? "xmark.circle.fill" : "eye.slash.fill")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(mode.tintColor)
                        .frame(width: 22, height: 22)
                        .background(.thinMaterial)
                        .clipShape(Circle())
                        .offset(x: 4, y: -4)
                        .opacity(keyText.isEmpty ? 1 : 0)
                }
            }

            Text(app.appName)
                .font(.system(size: 11, weight: .medium))
                .lineLimit(1)
                .foregroundStyle(isSelected ? .primary : .secondary)
                .frame(maxWidth: 80)
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(isSelected ? mode.tintColor.opacity(0.2) : .clear)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(isSelected ? mode.tintColor : .clear, lineWidth: 2)
        )
        .scaleEffect(isSelected ? 1.05 : 1.0)
        .animation(.easeOut(duration: 0.075), value: isSelected)
    }
}

// MARK: - AppListRow (List)

struct AppListRow: View {
    let app: RunningApp
    let keyText: String
    let isSelected: Bool
    let mode: AppMode

    var body: some View {
        HStack(spacing: 10) {
            Image(nsImage: app.icon)
                .resizable()
                .frame(width: 28, height: 28)
                .clipShape(RoundedRectangle(cornerRadius: 6))

            Text(app.appName)
                .font(.system(size: 13, weight: isSelected ? .semibold : .regular))
                .lineLimit(1)
                .foregroundStyle(isSelected ? .primary : .secondary)

            Spacer()

            if mode != .normal {
                Image(systemName: mode == .quit ? "xmark.circle.fill" : "eye.slash.fill")
                    .font(.system(size: 13))
                    .foregroundStyle(mode.tintColor)
            }

            if !keyText.isEmpty {
                Text(keyText.uppercased())
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(.thinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                    .overlay(RoundedRectangle(cornerRadius: 4).stroke(.separator, lineWidth: 0.5))
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isSelected ? mode.tintColor.opacity(0.15) : .clear)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(isSelected ? mode.tintColor : .clear, lineWidth: 1.5)
        )
        .animation(.easeOut(duration: 0.075), value: isSelected)
    }
}
