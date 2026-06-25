import AppKit
import ApplicationServices
import CoreGraphics
import SwiftUI

// MARK: - Model

struct AppWindow: Identifiable {
    let id: CGWindowID
    let title: String
    let pid: pid_t
}

// MARK: - WindowPickerView

struct WindowPickerView: View {
    let app: RunningApp
    @Binding var isPresented: Bool
    let layout: String  // "Grid" or "List"

    @State private var windows: [AppWindow] = []
    @State private var filterText: String = ""

    var filtered: [AppWindow] {
        filterText.isEmpty
            ? windows
            : windows.filter {
                $0.title.localizedCaseInsensitiveContains(filterText)
            }
    }

    var body: some View {
        VStack(spacing: 0) {
            header

            if windows.count > 3 {
                searchField
            }

            content
        }
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(.separator, lineWidth: 0.5))
        .frame(minWidth: 300)
        .onAppear { loadWindows() }
        .animation(.easeOut(duration: 0.15), value: filtered.count)
    }

    // MARK: Sub-views

    private var header: some View {
        HStack(spacing: 10) {
            Image(nsImage: app.icon)
                .resizable()
                .interpolation(.high)
                .frame(width: 28, height: 28)
                .clipShape(RoundedRectangle(cornerRadius: 6))

            Text(app.appName)
                .font(.system(size: 14, weight: .semibold))
                .lineLimit(1)

            Spacer()

            Button {
                isPresented = false
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .semibold))
                    .frame(width: 22, height: 22)
                    .background(.thinMaterial)
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.top, 14)
        .padding(.bottom, windows.count > 3 ? 8 : 14)
    }

    private var searchField: some View {
        TextField("Filter windows…", text: $filterText)
            .textFieldStyle(.roundedBorder)
            .padding(.horizontal, 16)
            .padding(.bottom, 10)
    }

    @ViewBuilder
    private var content: some View {
        if filtered.isEmpty {
            Text("No windows")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 28)
        } else if layout == "Grid" {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(filtered) { window in
                        WindowGridCell(window: window) {
                            focusWindow(window)
                            isPresented = false
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 14)
            }
        } else {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 4) {
                    ForEach(filtered) { window in
                        WindowListRow(window: window) {
                            focusWindow(window)
                            isPresented = false
                        }
                    }
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 10)
            }
        }
    }

    // MARK: - Data Loading

    /// Loads on-screen windows for the app's PID using CGWindowListCopyWindowInfo.
    /// Only includes windows with a non-empty title and kCGWindowLayer == 0
    /// (normal application windows, excluding HUDs, drawers, etc.).
    private func loadWindows() {
        guard
            let rawList = CGWindowListCopyWindowInfo(
                [.excludeDesktopElements, .optionOnScreenOnly],
                kCGNullWindowID
            ) as? [[String: Any]]
        else { return }

        let pid = app.app.processIdentifier
        windows = rawList.compactMap { info -> AppWindow? in
            guard
                let ownerPID = info[kCGWindowOwnerPID as String] as? Int,
                pid_t(ownerPID) == pid,
                let title = info[kCGWindowName as String] as? String,
                !title.isEmpty,
                let layer = info[kCGWindowLayer as String] as? Int,
                layer == 0,
                let rawID = info[kCGWindowNumber as String] as? Int
            else { return nil }

            return AppWindow(id: CGWindowID(rawID), title: title, pid: pid_t(ownerPID))
        }
    }

    // MARK: - Window Focus

    /// Raises and focuses a specific window via the Accessibility API, then activates the app.
    ///
    /// Steps:
    /// 1. Create an AXUIElement for the app process.
    /// 2. Fetch all AX windows via kAXWindowsAttribute.
    /// 3. Match by kAXTitleAttribute against the target window title.
    /// 4. Set kAXMainAttribute and kAXFocusedAttribute to kCFBooleanTrue.
    /// 5. Activate the NSRunningApplication so it comes to the foreground.
    private func focusWindow(_ window: AppWindow) {
        let axApp = AXUIElementCreateApplication(window.pid)

        var windowsValue: CFTypeRef?
        guard
            AXUIElementCopyAttributeValue(axApp, kAXWindowsAttribute as CFString, &windowsValue)
                == .success,
            let axWindows = windowsValue as? [AXUIElement]
        else {
            app.app.activate()
            return
        }

        for axWindow in axWindows {
            var titleValue: CFTypeRef?
            guard
                AXUIElementCopyAttributeValue(axWindow, kAXTitleAttribute as CFString, &titleValue)
                    == .success,
                let title = titleValue as? String,
                title == window.title
            else { continue }

            AXUIElementSetAttributeValue(axWindow, kAXMainAttribute as CFString, kCFBooleanTrue)
            AXUIElementSetAttributeValue(axWindow, kAXFocusedAttribute as CFString, kCFBooleanTrue)
            break
        }

        app.app.activate()
    }
}

// MARK: - WindowGridCell

struct WindowGridCell: View {
    let window: AppWindow
    let onTap: () -> Void

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "macwindow")
                .font(.system(size: 36))
                .foregroundStyle(.secondary)
                .frame(width: 70, height: 70)
                .background(.thinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 14))

            Text(window.title)
                .font(.system(size: 11))
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 80)
        }
        .onTapGesture { onTap() }
    }
}

// MARK: - WindowListRow

struct WindowListRow: View {
    let window: AppWindow
    let onTap: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "macwindow")
                .font(.system(size: 18))
                .foregroundStyle(.secondary)
                .frame(width: 28, height: 28)

            Text(window.title)
                .font(.system(size: 13))
                .lineLimit(1)

            Spacer()
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(.primary.opacity(0.05))
        )
        .onTapGesture { onTap() }
    }
}
