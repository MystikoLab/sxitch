//
//  appFunctions.swift
//  sxitch
//
//  Created by Umang on 25/6/26.
//

import Foundation
import SwiftUI

struct RunningApp: Identifiable, View {
    var id: Int32 { app.processIdentifier }
    var appName: String
    var app: NSRunningApplication
    var icon: NSImage
    var bundleUrl: URL?
    var depth: Int = 0
    
    var body: some View {
        VStack {
            ZStack(alignment: .topTrailing) {
                Image(nsImage: self.icon)
                    .resizable()
                    .frame(width: 60, height: 60)
                
                if depth < self.appName.count {
                    let charIndex = self.appName.index(self.appName.startIndex, offsetBy: depth)
                    let singleCharString = String(self.appName[charIndex])
                    
                    Text(singleCharString.uppercased())
                        .font(.callout)
                        .padding(6)
                        .frame(width: 20, height: 20)
                        .background(Color(nsColor: .windowBackgroundColor).opacity(0.8))
                        .clipShape(RoundedRectangle(cornerRadius: 30))
                        
                        //.offset(x: 8, y: -8)
                }
            }
            Text(self.appName)
                .opacity(0.7)
        }
        .padding(20)
        .onTapGesture {
            self.openApp()
        }
    }
    
    static func fetchRunningApps() -> [RunningApp] {
        return NSWorkspace.shared.runningApplications
            .filter { $0.activationPolicy == .regular  }
            .map { app in
                RunningApp(
                    appName: app.localizedName ?? "Unknown",
                    app: app,
                    icon: app.icon ?? NSImage(),
                    bundleUrl: app.bundleURL
                )
            }
            .sorted{ $0.appName < $1.appName }
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
        self.app.terminate()
    }
    
    func openApp() {
        if let bundleUrl = self.bundleUrl {
            NSWorkspace.shared.open(bundleUrl)
        }
    }
}
