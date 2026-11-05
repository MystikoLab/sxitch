import AppKit
import ApplicationServices
import Combine
import ScreenCaptureKit
import SwiftUI

/// Private AX call mapping a window element to its CoreGraphics window ID.
/// Used by most macOS window switchers; there is no public equivalent.
@_silgen_name("_AXUIElementGetWindow")
@discardableResult
private func _AXUIElementGetWindow(_ element: AXUIElement, _ windowID: UnsafeMutablePointer<CGWindowID>) -> AXError

func cgWindowID(for element: AXUIElement) -> CGWindowID? {
    var id: CGWindowID = 0
    guard _AXUIElementGetWindow(element, &id) == .success, id != 0 else { return nil }
    return id
}

enum WindowPreviewSettings {
    static let enabledKey = "windowPreviewsEnabled"
    /// Thumbnails are letterboxed into a fixed 16:10 box so cells keep a
    /// stable size whether or not a capture has landed yet.
    static let aspectRatio: CGFloat = 10.0 / 16.0
    static let height: CGFloat = 120
    static let width: CGFloat = height / aspectRatio

    /// Fraction of the screen width a row of thumbnails may span before the
    /// grid wraps.
    static let maxRowWidthFraction: CGFloat = 0.8

    /// Only the grid shows thumbnails: list rows get too tall and radial
    /// rings are too cramped.
    static func layoutSupportsPreviews(_ style: String) -> Bool {
        style == "grid"
    }

    /// Previews are Pro-only and need Screen Recording to capture anything.
    static var isActive: Bool {
        userState.shared.isPro
            && UserDefaults.standard.bool(forKey: enabledKey)
            && CGPreflightScreenCaptureAccess()
    }
}

/// In-memory cache of window snapshots. ScreenCaptureKit can only capture
/// windows on the current Space, so a pass also runs in the background on
/// every Space change; windows on other Spaces then show their last capture.
/// Windows never captured (minimized, hidden, unvisited Space) have no entry,
/// and cells fall back to the app icon.
@MainActor
final class WindowPreviewStore: ObservableObject {
    static let shared = WindowPreviewStore()

    /// Keyed by CGWindowID.
    @Published private(set) var windowImages: [CGWindowID: NSImage] = [:]
    /// Last frontmost window seen on screen per app, keyed by PID.
    @Published private(set) var appWindowIDs: [pid_t: CGWindowID] = [:]

    /// One task per trigger so a background pass and an open-time refresh
    /// don't cancel each other.
    private var openCaptureTask: Task<Void, Never>?
    private var backgroundCaptureTask: Task<Void, Never>?
    private var spaceObserver: NSObjectProtocol?

    /// Space switches animate; windows on the new Space aren't reported as
    /// on screen until the transition settles.
    private static let spaceSettleDelay: Duration = .milliseconds(600)

    private init() {}

    func image(forApp pid: pid_t) -> NSImage? {
        appWindowIDs[pid].flatMap { windowImages[$0] }
    }

    func image(forWindow id: CGWindowID?) -> NSImage? {
        id.flatMap { windowImages[$0] }
    }

    func startBackgroundCaching() {
        guard spaceObserver == nil else { return }
        spaceObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.activeSpaceDidChangeNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.cacheCurrentSpace() }
        }
        cacheCurrentSpace()
    }

    /// Captures every on-screen window of regular apps on the current Space.
    private func cacheCurrentSpace() {
        backgroundCaptureTask?.cancel()
        backgroundCaptureTask = Task {
            try? await Task.sleep(for: Self.spaceSettleDelay)
            guard !Task.isCancelled,
                  WindowPreviewSettings.isActive,
                  WindowPreviewSettings.layoutSupportsPreviews(
                      UserDefaults.standard.string(forKey: "layoutStyle") ?? "grid"
                  )
            else { return }
            let pids = Set(
                NSWorkspace.shared.runningApplications
                    .filter { $0.activationPolicy == .regular }
                    .map(\.processIdentifier)
            )
            let windows = Self.onScreenWindows(for: pids)
            recordFrontmost(windows)
            await capture(Set(windows.map(\.id)))
        }
    }

    /// Captures the frontmost window of each given app.
    func refreshApps(_ pids: [pid_t]) {
        guard WindowPreviewSettings.isActive else { return clear() }
        let windows = Self.onScreenWindows(for: Set(pids))
        recordFrontmost(windows)
        let ids = Set(windows.compactMap { appWindowIDs[$0.pid] == $0.id ? $0.id : nil })
        openCaptureTask?.cancel()
        openCaptureTask = Task { await capture(ids) }
    }

    /// Captures the given windows (window picker).
    func refreshWindows(_ ids: [CGWindowID]) {
        guard WindowPreviewSettings.isActive else { return clear() }
        openCaptureTask?.cancel()
        openCaptureTask = Task { await capture(Set(ids)) }
    }

    func clear() {
        openCaptureTask?.cancel()
        backgroundCaptureTask?.cancel()
        windowImages = [:]
        appWindowIDs = [:]
    }

    /// Windows arrive front to back, so the first one per PID is that app's
    /// frontmost. Apps with nothing on this Space keep their earlier entry.
    private func recordFrontmost(_ windows: [(pid: pid_t, id: CGWindowID)]) {
        var seen: Set<pid_t> = []
        for window in windows where seen.insert(window.pid).inserted {
            appWindowIDs[window.pid] = window.id
        }
    }

    /// Drops cached windows that have closed and apps that have quit.
    private func pruneClosedWindows() {
        guard let list = CGWindowListCopyWindowInfo([.optionAll], kCGNullWindowID) as? [[String: Any]]
        else { return }
        let existing = Set(list.compactMap { $0[kCGWindowNumber as String] as? CGWindowID })
        windowImages = windowImages.filter { existing.contains($0.key) }
        appWindowIDs = appWindowIDs.filter { existing.contains($0.value) }
    }

    private func capture(_ ids: Set<CGWindowID>) async {
        pruneClosedWindows()
        guard !ids.isEmpty else { return }

        let width = WindowPreviewSettings.width
        let scale = NSScreen.main?.backingScaleFactor ?? 2

        guard let content = try? await SCShareableContent.excludingDesktopWindows(
            true, onScreenWindowsOnly: true
        ), !Task.isCancelled else { return }
        let targets = content.windows.filter { ids.contains($0.windowID) }

        await withTaskGroup(of: (CGWindowID, NSImage?).self) { group in
            for window in targets {
                group.addTask {
                    await(window.windowID, Self.snapshot(window, width: width, scale: scale))
                }
            }
            for await(id, image) in group {
                guard !Task.isCancelled else { return }
                if let image {
                    windowImages[id] = image
                }
            }
        }
    }

    private nonisolated static func snapshot(_ window: SCWindow, width: CGFloat, scale: CGFloat) async -> NSImage? {
        let frame = window.frame
        guard frame.width > 1, frame.height > 1 else { return nil }

        let config = SCStreamConfiguration()
        let targetWidth = min(frame.width, width) * scale
        config.width = Int(targetWidth)
        config.height = Int(targetWidth * frame.height / frame.width)
        config.showsCursor = false
        config.ignoreShadowsSingleWindow = true

        let filter = SCContentFilter(desktopIndependentWindow: window)
        guard let cgImage = try? await SCScreenshotManager.captureImage(
            contentFilter: filter, configuration: config
        ) else { return nil }
        return NSImage(cgImage: cgImage, size: NSSize(width: frame.width, height: frame.height))
    }

    /// Normal-layer, non-trivial on-screen windows of the given apps, front
    /// to back as CGWindowList reports them.
    private static func onScreenWindows(for pids: Set<pid_t>) -> [(pid: pid_t, id: CGWindowID)] {
        guard let list = CGWindowListCopyWindowInfo(
            [.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID
        ) as? [[String: Any]] else { return [] }

        return list.compactMap { info in
            guard let pid = info[kCGWindowOwnerPID as String] as? pid_t,
                  pids.contains(pid),
                  (info[kCGWindowLayer as String] as? Int) == 0,
                  let id = info[kCGWindowNumber as String] as? CGWindowID,
                  let bounds = info[kCGWindowBounds as String] as? [String: CGFloat],
                  (bounds["Width"] ?? 0) > 50, (bounds["Height"] ?? 0) > 50
            else { return nil }
            return (pid, id)
        }
    }
}

/// A window thumbnail in a fixed 16:10 box, falling back to the app icon
/// when no capture is available. Shows a small app icon badge over captures.
struct WindowThumbnail: View {
    let image: NSImage?
    let fallbackIcon: NSImage
    let width: CGFloat

    private var height: CGFloat {
        width * WindowPreviewSettings.aspectRatio
    }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            if let image {
                Image(nsImage: image)
                    .resizable()
                    .interpolation(.high)
                    .scaledToFit()
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    .frame(width: width, height: height)

                Image(nsImage: fallbackIcon)
                    .resizable()
                    .frame(width: badgeSize, height: badgeSize)
                    .shadow(radius: 2)
                    .offset(x: badgeSize / 4, y: badgeSize / 4)
            } else {
                Image(nsImage: fallbackIcon)
                    .resizable()
                    .scaledToFit()
                    .frame(width: fallbackIconSize, height: fallbackIconSize)
                    .frame(width: width, height: height)
            }
        }
        .frame(width: width, height: height)
    }

    /// Stays icon-sized however large the thumbnail box gets.
    private let fallbackIconSize: CGFloat = 48

    private var badgeSize: CGFloat {
        max(16, min(28, width * 0.15))
    }
}
