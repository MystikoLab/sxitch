//
//  WindowPicker.swift
//  sxitch
//
//  Created by Umang on 27/6/26.
//

import ApplicationServices
import SwiftUI

// MARK: - WindowInfo

struct WindowInfo: Identifiable {
    let id: Int // index from AX enumeration
    let title: String
    let axElement: AXUIElement
    let ownerApp: NSRunningApplication

    func performAction(_ action: AppMode) {
        switch action {
        case .normal:
            // Raise the specific window then bring the app forward
            AXUIElementPerformAction(axElement, kAXRaiseAction as CFString)
            ownerApp.activate(options: [])

        case .hide:
            // Minimise just this window
            AXUIElementSetAttributeValue(
                axElement, kAXMinimizedAttribute as CFString, true as CFTypeRef
            )

        case .quit:
            // Press the window's close button
            var pid: pid_t = 0
            AXUIElementGetPid(axElement, &pid)
            if pid != 0 {
                NSRunningApplication(processIdentifier: pid)?.terminate()
            }
        }
    }
}

// MARK: - Fetch windows via Accessibility API

func fetchWindowsForApp(_ nsApp: NSRunningApplication) -> [WindowInfo] {
    let axApp = AXUIElementCreateApplication(nsApp.processIdentifier)
    var windowsRef: CFTypeRef?
    guard
        AXUIElementCopyAttributeValue(axApp, kAXWindowsAttribute as CFString, &windowsRef)
        == .success,
        let axWindows = windowsRef as? [AXUIElement]
    else { return [] }

    return axWindows.enumerated().compactMap { index, axWindow in
        var titleRef: CFTypeRef?
        guard
            AXUIElementCopyAttributeValue(axWindow, kAXTitleAttribute as CFString, &titleRef)
            == .success,
            let title = titleRef as? String,
            !title.isEmpty
        else { return nil }
        return WindowInfo(id: index, title: title, axElement: axWindow, ownerApp: nsApp)
    }
}

// MARK: - WindowPickerView

struct WindowPickerView: View {
    let windows: [WindowInfo]
    let appName: String
    let appIcon: NSImage
    let typed: String
    let appMode: AppMode
    let onSelect: () -> Void

    @AppStorage("layoutStyle") private var layoutStyle: String = "grid"

    var filtered: [WindowInfo] {
        typed.isEmpty
            ? windows
            : windows.filter { $0.title.lowercased().starts(with: typed.lowercased()) }
    }

    var modeColor: Color {
        switch appMode {
        case .quit: return .red.opacity(0.8)
        case .hide: return .orange.opacity(0.8)
        case .normal: return .primary
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header row
            HStack(spacing: 8) {
                Image(nsImage: appIcon)
                    .resizable()
                    .frame(width: 20, height: 20)
                Text(appName)
                    .font(.headline)
                    .opacity(0.8)
                Spacer()
                Text("\(filtered.count) window\(filtered.count == 1 ? "" : "s")")
                    .font(.caption)
                    .opacity(0.4)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)

            Divider().opacity(0.4)

            if filtered.isEmpty {
                Text("No windows match")
                    .font(.subheadline)
                    .opacity(0.4)
                    .padding(24)
            } else if layoutStyle == "list" {
                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(filtered) { window in
                            windowRow(window)
                        }
                    }
                }
            } else {
                ScrollView {
                    LazyVGrid(
                        columns: [GridItem(.adaptive(minimum: 80, maximum: 100))],
                        spacing: 12
                    ) {
                        ForEach(filtered) { window in
                            windowGridCell(window)
                        }
                    }
                    .padding(12)
                }
            }
        }
        .frame(width: 300)
        .frame(maxHeight: 400)
    }

    private func windowGridCell(_ window: WindowInfo) -> some View {
        VStack(spacing: 6) {
            ZStack(alignment: .topTrailing) {
                Image(nsImage: appIcon)
                    .resizable()
                    .frame(width: 48, height: 48)

                if !typed.isEmpty,
                   let nextChar = window.title.dropFirst(typed.count).first(where: {
                       !$0.isWhitespace
                   })
                {
                    Text(String(nextChar).uppercased())
                        .foregroundStyle(appMode == .normal ? Color.primary : modeColor)
                        .font(.caption2)
                        .padding(3)
                        .frame(width: 14, height: 14)
                        .background(Color(nsColor: .windowBackgroundColor).opacity(0.85))
                        .clipShape(RoundedRectangle(cornerRadius: 30))
                }
            }

            Text(window.title)
                .font(.caption)
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .foregroundStyle(appMode == .normal ? Color.primary : modeColor)
                .opacity(0.85)
        }
        .padding(8)
        .frame(maxWidth: .infinity)
        .contentShape(RoundedRectangle(cornerRadius: 12))
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(nsColor: .windowBackgroundColor).opacity(0.4))
        )
        .onTapGesture {
            window.performAction(appMode)
            onSelect()
        }
    }

    @ViewBuilder
    private func windowRow(_ window: WindowInfo) -> some View {
        HStack(spacing: 12) {
            ZStack(alignment: .topTrailing) {
                Image(nsImage: appIcon)
                    .resizable()
                    .frame(width: 36, height: 36)

                // Show the next character badge, same as the app picker
                if !typed.isEmpty,
                   let nextChar = window.title.dropFirst(typed.count).first(where: {
                       !$0.isWhitespace
                   })
                {
                    Text(String(nextChar).uppercased())
                        .foregroundStyle(appMode == .normal ? Color.primary : modeColor)
                        .font(.caption2)
                        .padding(3)
                        .frame(width: 14, height: 14)
                        .background(Color(nsColor: .windowBackgroundColor).opacity(0.85))
                        .clipShape(RoundedRectangle(cornerRadius: 30))
                }
            }

            Text(window.title)
                .lineLimit(1)
                .foregroundStyle(appMode == .normal ? Color.primary : modeColor)
                .opacity(0.85)
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .contentShape(Rectangle())
        .onTapGesture {
            window.performAction(appMode)
            onSelect()
        }
        Divider().opacity(0.4)
    }
}
