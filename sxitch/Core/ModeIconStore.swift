import AppKit
import Foundation

class ModeIconStore {
    static let shared = ModeIconStore()

    private let storageURL: URL = {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = appSupport.appendingPathComponent("Sxitch/ModeIcons")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }()

    func save(pngData: Data) -> String {
        let filename = "\(UUID().uuidString).png"
        let url = storageURL.appendingPathComponent(filename)
        try? pngData.write(to: url)
        return filename
    }

    func image(named: String) -> NSImage? {
        let url = storageURL.appendingPathComponent(named)
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        return NSImage(contentsOf: url)
    }

    func delete(named: String) {
        let url = storageURL.appendingPathComponent(named)
        try? FileManager.default.removeItem(at: url)
    }
}