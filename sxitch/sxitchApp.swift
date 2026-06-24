//
//  sxitchApp.swift
//  sxitch
//
//  Created by Umang on 22/6/26.
//

import SwiftUI

@main
struct sxitchApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    var body: some Scene {
        Settings {
            SettingsView()
                .toolbar(.hidden)
        }
        .windowLevel(.floating)
        .windowBackgroundDragBehavior(.enabled)
        MenuBarExtra("Sxitch", systemImage: "tray.fill") {
            Button("Show") {
                appDelegate.window.makeKeyAndOrderFront(nil)
                appDelegate.window.orderFrontRegardless()
            }
            SettingsLink()
            Button(role: .destructive) {
                NSApp.terminate(nil)
            } label: {
                Text("Quit App")
            }
        }
    }
}
