import SwiftUI

struct ContentView: View {
    @ObservedObject var appSwitcher: AppSwitcher

    var body: some View {
        VStack(spacing: 8) {
            if appSwitcher.mode != .normal {
                modeBanner
                    .transition(.move(edge: .top).combined(with: .opacity))
            }

            if appSwitcher.filteredApps.isEmpty {
                Text("No matching apps")
                    .foregroundStyle(.secondary)
                    .padding(40)
            } else {
                HStack(spacing: 12) {
                    ForEach(Array(appSwitcher.filteredApps.enumerated()), id: \.element.id) { index, app in
                        AppCell(
                            app: app,
                            keyText: appSwitcher.config.showKeys ? appSwitcher.resolvedKeys[app] ?? "" : "",
                            isSelected: index == appSwitcher.selectedIndex,
                            mode: appSwitcher.mode
                        )
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
        }
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 30))
        .overlay(
            RoundedRectangle(cornerRadius: 30)
                .stroke(.separator, lineWidth: 0.5)
        )
        .frame(maxWidth: .infinity, alignment: .center)
        .animation(.easeOut(duration: 0.2), value: appSwitcher.mode)
    }

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
        .background(
            Capsule()
                .fill(appSwitcher.mode.tintColor.opacity(0.15))
        )
        .overlay(
            Capsule()
                .stroke(appSwitcher.mode.tintColor.opacity(0.3), lineWidth: 1)
        )
        .padding(.top, 10)
    }

    private var modeIcon: String {
        switch appSwitcher.mode {
        case .quit: return "xmark.circle.fill"
        case .hide: return "eye.slash.fill"
        case .normal: return ""
        }
    }
}

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
                    .frame(width: 60, height: 60)
                    .clipShape(RoundedRectangle(cornerRadius: 14))

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
