import AppKit
import Foundation

class CustomIconStore {
    static let shared = CustomIconStore()
    
    private let storageURL: URL = {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = appSupport.appendingPathComponent("Sxitch/CustomIcons")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }()
    
    func save(image: NSImage, for bundleID: String) {
        guard let tiff = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiff),
              let png = bitmap.representation(using: .png, properties: [:]) else { return }
        let url = storageURL.appendingPathComponent("\(bundleID).png")
        try? png.write(to: url)
    }
    
    func load(for bundleID: String) -> NSImage? {
        let url = storageURL.appendingPathComponent("\(bundleID).png")
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        return NSImage(contentsOf: url)
    }
    
    func delete(for bundleID: String) {
        let url = storageURL.appendingPathComponent("\(bundleID).png")
        try? FileManager.default.removeItem(at: url)
    }
}
