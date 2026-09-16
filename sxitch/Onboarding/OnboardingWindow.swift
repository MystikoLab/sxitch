//
//  OnboardingWindow.swift
//  sxitch
//
//  Strips the native window chrome/background from the onboarding window so
//  the aurora backdrop fills the entire frame: transparent NSWindow backing,
//  fully transparent title bar, full-size content view.
//

import SwiftUI

struct OnboardingWindowConfigurator: NSViewRepresentable {
    func makeNSView(context _: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            guard let window = view.window else { return }
            window.isOpaque = false
            window.backgroundColor = .clear
            window.titlebarAppearsTransparent = true
            window.titleVisibility = .hidden
            if window.styleMask.contains(.titled) {
                window.styleMask.insert(.fullSizeContentView)
            }
            window.standardWindowButton(.closeButton)?.isHidden = true
            window.standardWindowButton(.miniaturizeButton)?.isHidden = true
            window.standardWindowButton(.zoomButton)?.isHidden = true
        }
        return view
    }

    func updateNSView(_: NSView, context _: Context) {}
}
