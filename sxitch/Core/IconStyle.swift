import SwiftUI

enum IconNameFont: String, CaseIterable {
    case small
    case regular
    case large

    var displayName: String {
        switch self {
        case .small: "Small"
        case .regular: "Regular"
        case .large: "Large"
        }
    }

    var font: Font {
        switch self {
        case .small: .callout
        case .regular: .body
        case .large: .title3
        }
    }
}

/// How the regular switcher (normal, Hide and Quit modes) draws its app
/// icons. Custom modes always use `.default`.
struct IconStyle: Equatable {
    var scale: CGFloat = 1
    var showBadge = true
    var showName = true
    var nameFont: IconNameFont = .regular
    var dimUnselected = false
    var dimOpacity: Double = 0.5
    var spacing: CGFloat = 8

    static let `default` = IconStyle()

    static let scaleRange: ClosedRange<Double> = 0.5 ... 2
    static let dimOpacityRange: ClosedRange<Double> = 0.2 ... 1
    static let spacingRange: ClosedRange<Double> = 0 ... 40

    static let scaleKey = "iconScale"
    static let showBadgeKey = "iconShowBadge"
    static let showNameKey = "iconShowName"
    static let nameFontKey = "iconNameFont"
    static let dimUnselectedKey = "iconDimUnselected"
    static let dimOpacityKey = "iconDimOpacity"
    static let spacingKey = "iconSpacing"

    /// Opacity for a cell, dimming unselected ones only while something is
    /// actually selected.
    func opacity(isSelected: Bool, hasSelection: Bool) -> Double {
        dimUnselected && hasSelection && !isSelected ? dimOpacity : 1
    }
}

/// Reads the stored icon settings. Size is free; everything else falls back
/// to the defaults without Pro while keeping the stored values, so they
/// return once Pro is re-enabled.
struct IconStyleSettings: DynamicProperty {
    @AppStorage(IconStyle.scaleKey) private var scale: Double = 1
    @AppStorage(IconStyle.showBadgeKey) private var showBadge = true
    @AppStorage(IconStyle.showNameKey) private var showName = true
    @AppStorage(IconStyle.nameFontKey) private var nameFont: String = IconNameFont.regular.rawValue
    @AppStorage(IconStyle.dimUnselectedKey) private var dimUnselected = false
    @AppStorage(IconStyle.dimOpacityKey) private var dimOpacity: Double = 0.5
    @AppStorage(IconStyle.spacingKey) private var spacing: Double = 8

    var style: IconStyle {
        var style = IconStyle.default
        style.scale = CGFloat(scale.clamped(to: IconStyle.scaleRange))
        guard userState.shared.isPro else { return style }
        style.showBadge = showBadge
        style.showName = showName
        style.nameFont = IconNameFont(rawValue: nameFont) ?? .regular
        style.dimUnselected = dimUnselected
        style.dimOpacity = dimOpacity.clamped(to: IconStyle.dimOpacityRange)
        style.spacing = CGFloat(spacing.clamped(to: IconStyle.spacingRange))
        return style
    }
}

struct IconStyleKey: EnvironmentKey {
    static let defaultValue: IconStyle = .default
}

extension EnvironmentValues {
    var iconStyle: IconStyle {
        get { self[IconStyleKey.self] }
        set { self[IconStyleKey.self] = newValue }
    }
}
