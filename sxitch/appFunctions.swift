//
//  appFunctions.swift
//  sxitch
//
//  Created by Umang on 25/6/26.
//

import Foundation
import SwiftUI

struct RunningApp: Identifiable, Equatable, View {
    static func == (lhs: RunningApp, rhs: RunningApp) -> Bool {
        lhs.id == rhs.id && lhs.depth == rhs.depth && lhs.appMode == rhs.appMode
    }
    @AppStorage("appBlacklists") var blacklist: [String] = []

    var id: Int32 { app.processIdentifier }
    var appName: String
    var app: NSRunningApplication
    var icon: NSImage
    var bundleUrl: URL?
    var depth: Int = 0
    var appMode: AppMode = .normal
    var overrideTap: ((RunningApp) -> Void)? = nil
    var modeOverlayColor: Color {
        switch appMode {
        case .quit: return .red.opacity(0.7)
        case .hide: return .orange.opacity(0.7)
        case .normal: return .clear
        }
    }

    /// Compact horizontal row used in list layout
    var listBody: some View {
        HStack(spacing: 12) {
            ZStack(alignment: .topTrailing) {
                Image(nsImage: self.icon)
                    .resizable()
                    .frame(width: 36, height: 36)

                if let nextChar = self.appName.dropFirst(depth).first(where: { !$0.isWhitespace }) {
                    Text(String(nextChar).uppercased())
                        .foregroundStyle(appMode == .normal ? Color.primary : modeOverlayColor)
                        .font(.caption2)
                        .padding(4)
                        .frame(width: 16, height: 16)
                        .background(Color(nsColor: .windowBackgroundColor).opacity(0.8))
                        .clipShape(RoundedRectangle(cornerRadius: 30))
                }
            }

            Text(self.appName)
                .opacity(0.7)
                .foregroundStyle(appMode == .normal ? Color.primary : modeOverlayColor)

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .contentShape(Rectangle())
        .onTapGesture {
            if let override = overrideTap {
                override(self)
            } else {
                self.performAction(action: appMode)
            }
        }
    }

    var body: some View {
        VStack {
            ZStack(alignment: .topTrailing) {
                Image(nsImage: self.icon)
                    .resizable()
                    .frame(width: 60, height: 60)

                if let nextChar = self.appName.dropFirst(depth).first(where: { !$0.isWhitespace }) {
                    Text(String(nextChar).uppercased())
                        .foregroundStyle(appMode == .normal ? Color.primary : modeOverlayColor)
                        .font(.callout)
                        .padding(3)
                        .frame(width: 23, height: 23)
                        .background(Color(nsColor: .windowBackgroundColor).opacity(0.8))
                        .clipShape(RoundedRectangle(cornerRadius: 30))
                }
            }
            Text(self.appName)
                .opacity(0.7)
                .foregroundStyle(appMode == .normal ? Color.primary : modeOverlayColor)
        }
        .frame(maxWidth: 60)
        .padding(20)
        .onTapGesture {
            if let override = overrideTap {
                override(self)
            } else {
                self.performAction(action: appMode)
            }
        }
    }

    static func fetchRunningApps() -> [RunningApp] {
        let usState = userState.shared
        @AppStorage("appBlacklists") var blacklist: [String] = []
        @AppStorage("prefixStrips") var prefixStrips: [String] = ["microsoft", "adobe"]
        return NSWorkspace.shared.runningApplications
            .map { app in
                RunningApp(
                    appName: app.localizedName ?? "Unknown",
                    app: app,
                    icon: app.icon ?? NSImage(),
                    bundleUrl: app.bundleURL
                )
            }
            .map { app in
                var app = app
                for prefix in prefixStrips {
                    if app.appName.lowercased().hasPrefix(prefix.lowercased()) {
                        app.appName = String(app.appName.dropFirst(prefix.count))
                            .trimmingCharacters(in: .whitespaces)
                        break
                    }
                }
                return app
            }
            .filter { app in
                return app.app.activationPolicy == .regular
                    && (!blacklist.contains(app.appName.lowercased()) || !usState.isPro)
            }
            .sorted { $0.appName < $1.appName }
    }

    func performAction(action: AppMode) {
        switch action {
        case .normal: self.openApp()
        case .hide: self.hideApp()
        case .quit: self.quitApp()
        }
    }

    func hideApp() {
        self.app.hide()
    }

    func quitApp() {
        print("Terminating: \(self.appName)")
        self.app.terminate()
    }

    func openApp() {
        if let bundleUrl = self.bundleUrl {
            NSWorkspace.shared.open(bundleUrl)
        }
    }
}
