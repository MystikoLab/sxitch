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
                .toolbarVisibility(.hidden)
                .navigationTitle("Sxitch Settings")
        }
        .windowToolbarStyle(.unified)
        .windowStyle(.hiddenTitleBar)

        
        MenuBarExtra {
            Label {
                Text("Sxitch")
            } icon: {
                Image(nsImage: makeMenuBarIcon())
                    .resizable()
                    .scaledToFit()
            }
            Label("Version: \(Bundle.main.appVersion)", systemImage: "number.circle")
            Button("Show", systemImage: "eye.fill") {
                appDelegate.window.makeKeyAndOrderFront(nil)
                appDelegate.window.orderFrontRegardless()
            }
            Divider()
            Button("Github", systemImage: "chevron.left.forwardslash.chevron.right") {
                if let github = URL(string: "https://github.com/unsecretised/sxitch-public") {
                    NSWorkspace.shared.open(github)
                }
            }
            Button("Homepage", systemImage: "arrow.up.forward.app") {
                if let homepage = URL(string: "https://sxitch.app") {
                    NSWorkspace.shared.open(homepage)
                }
            }
            Button("Community", systemImage: "person.2") {
                if let community = URL(string: "https://discord.sxitch.app") {
                    NSWorkspace.shared.open(community)
                }
            }
            Divider()
            SettingsLink()
            Button("Quit Sxitch", systemImage: "xmark.circle", role: .destructive) {
                NSApp.terminate(nil)
            }
        } label: {
            Image(nsImage: makeMenuBarIcon())
        }
    }
}

func makeMenuBarIcon() -> NSImage {
    let size: CGFloat = 20
    let image = NSImage(size: NSSize(width: size, height: size), flipped: false) { _ in
        let cx = size * 0.5
        let cy = size * 0.5
        let strokeW = size * 0.045
        let trunkHalf = size * 0.30
        let rodLen = size * 0.22
        let dotR = strokeW * 0.85

        NSColor.white.setStroke()
        NSColor.white.setFill()

        func drawLine(_ x0: CGFloat, _ y0: CGFloat, _ x1: CGFloat, _ y1: CGFloat) {
            let p = NSBezierPath()
            p.move(to: NSPoint(x: x0, y: y0))
            p.line(to: NSPoint(x: x1, y: y1))
            p.lineWidth = strokeW
            p.lineCapStyle = .round
            p.stroke()
        }

        func dotAt(angleDeg: CGFloat, len: CGFloat) {
            let rad = angleDeg * .pi / 180
            let tx = cx + len * cos(rad)
            let ty = cy + len * sin(rad)
            let d = NSBezierPath()
            d.appendArc(withCenter: NSPoint(x: tx, y: ty), radius: dotR, startAngle: 0, endAngle: 360)
            d.fill()
        }

        drawLine(cx, cy - trunkHalf, cx, cy + trunkHalf)
        dotAt(angleDeg: 90, len: trunkHalf)
        dotAt(angleDeg: 270, len: trunkHalf)

        let branches: [(CGFloat, CGFloat)] = [(50, rodLen), (135, rodLen)]
        for (angle, len) in branches {
            let rad = angle * .pi / 180
            let tipX = cx + len * cos(rad)
            let tipY = cy + len * sin(rad)
            drawLine(cx, cy, tipX, tipY)
            dotAt(angleDeg: angle, len: len)
        }

        return true
    }
    image.isTemplate = true
    return image
}
