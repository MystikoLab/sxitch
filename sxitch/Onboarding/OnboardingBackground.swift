//
//  OnboardingBackground.swift
//  sxitch
//
//  A plain system-material backdrop for the onboarding window: liquid glass
//  look, no accent tinting or motion. Solid color under Reduce Transparency.
//

import SwiftUI

struct OnboardingBackground: View {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    var body: some View {
        Group {
            if reduceTransparency {
                Color(nsColor: .windowBackgroundColor)
            } else {
                Rectangle().fill(.regularMaterial)
            }
        }
        .overlay(Color.black.opacity(0.28).ignoresSafeArea())
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }
}
