import SwiftUI

/// An arrow key pressed while the switcher is open.
enum NavigationDirection {
    case up, down, left, right

    /// Unit vector in SwiftUI's coordinate space (y grows downwards).
    var vector: CGPoint {
        switch self {
        case .up: CGPoint(x: 0, y: -1)
        case .down: CGPoint(x: 0, y: 1)
        case .left: CGPoint(x: -1, y: 0)
        case .right: CGPoint(x: 1, y: 0)
        }
    }

    var axis: Axis {
        switch self {
        case .up, .down: .vertical
        case .left, .right: .horizontal
        }
    }

    /// Step through the flat list when the key moves "along" it.
    var linearDelta: Int {
        switch self {
        case .up, .left: -1
        case .down, .right: +1
        }
    }
}

enum KeyboardNavigationSettings {
    static let smartArrowsKey = "smartArrowNavigation"
    static let radialSelectionOpacityKey = "radialSelectionOpacity"
    static let radialSelectionOpacityRange: ClosedRange<Double> = 0.1 ... 0.6

    static var smartArrowsEnabled: Bool {
        UserDefaults.standard.bool(forKey: smartArrowsKey)
    }
}

/// Where each selectable item sits on screen, reported by the layout that
/// draws it, so arrow keys can move spatially instead of through the flat
/// list.
struct NavigationLayout: Equatable {
    /// Item centers in the `navigationSpace` coordinate space, keyed by the
    /// same names `AppState.selectedName` uses.
    var points: [String: CGPoint] = [:]
    /// The axis the flat list flows along (rows in a grid, columns in a
    /// list). Arrows on this axis step linearly so they keep reading order
    /// and roll over into the next row/column; arrows on the other axis jump
    /// to the adjacent row/column. nil (radial) moves spatially both ways.
    var flowAxis: Axis? = nil

    static let coordinateSpace = "switcherNavigation"

    /// Items sharing a row/column can be off by a few points of rounding.
    private static let lineTolerance: CGFloat = 8

    /// The name to select after pressing `direction` from `current`, or nil
    /// to fall back to a linear step.
    func target(from current: String, direction: NavigationDirection, in names: [String]) -> String? {
        if direction.axis == flowAxis {
            return nil
        }
        guard let origin = points[current] else { return nil }
        let candidates = names.compactMap { name -> (name: String, along: CGFloat, perp: CGFloat)? in
            guard name != current, let p = points[name] else { return nil }
            let d = CGPoint(x: p.x - origin.x, y: p.y - origin.y)
            let v = direction.vector
            let along = d.x * v.x + d.y * v.y
            let perp = abs(d.x * v.y - d.y * v.x)
            return (name, along, perp)
        }

        let ahead = candidates.filter { $0.along > Self.lineTolerance }
        if !ahead.isEmpty {
            return best(of: ahead, preferNearest: true)
        }
        // Nothing that way: wrap to the far side, unless everything sits on
        // one line (a single column/row) or some items aren't laid out yet
        // (lazy grids) — a linear step handles those better.
        let behind = candidates.filter { $0.along < -Self.lineTolerance }
        guard !behind.isEmpty, names.allSatisfy({ points[$0] != nil }) else { return nil }
        return best(of: behind, preferNearest: false)
    }

    /// With a flow axis, rows/columns are strict: the adjacent (or, when
    /// wrapping, the farthest) line wins, then the closest item across it.
    /// Radial layouts weigh both so the arrow picks what's visually that way
    /// (`along` is negative when wrapping, so the farthest item scores best).
    private func best(
        of candidates: [(name: String, along: CGFloat, perp: CGFloat)],
        preferNearest: Bool
    ) -> String? {
        guard flowAxis != nil else {
            return candidates.min { $0.along + 2 * $0.perp < $1.along + 2 * $1.perp }?.name
        }
        let alongs = candidates.map { abs($0.along) }
        guard let lineDistance = preferNearest ? alongs.min() : alongs.max() else { return nil }
        return candidates
            .filter { abs(abs($0.along) - lineDistance) <= Self.lineTolerance }
            .min { $0.perp < $1.perp }?.name
    }
}

struct NavigationPointsKey: PreferenceKey {
    static var defaultValue: [String: CGPoint] = [:]
    static func reduce(value: inout [String: CGPoint], nextValue: () -> [String: CGPoint]) {
        value.merge(nextValue()) { $1 }
    }
}

struct NavigationFlowAxisKey: PreferenceKey {
    static var defaultValue: Axis? = nil
    static func reduce(value: inout Axis?, nextValue: () -> Axis?) {
        value = nextValue() ?? value
    }
}

extension View {
    /// Reports this item's center for arrow-key navigation. Apply before any
    /// `.offset` so the reported point includes it.
    func navigationPoint(_ name: String) -> some View {
        background(
            GeometryReader { geo in
                let frame = geo.frame(in: .named(NavigationLayout.coordinateSpace))
                Color.clear.preference(
                    key: NavigationPointsKey.self,
                    value: [name: CGPoint(x: frame.midX, y: frame.midY)]
                )
            }
        )
    }

    /// Declares how the layout's flat list flows; see `NavigationLayout.flowAxis`.
    func navigationFlowAxis(_ axis: Axis?) -> some View {
        preference(key: NavigationFlowAxisKey.self, value: axis)
    }
}
