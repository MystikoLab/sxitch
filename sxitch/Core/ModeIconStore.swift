import AppKit
import Foundation
import ImageIO

class ModeIconStore {
    static let shared = ModeIconStore()

    private static let maxPixelSize: CGFloat = 128

    private let storageURL: URL = {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = appSupport.appendingPathComponent("Sxitch/ModeIcons")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }()

    func save(pngData: Data) -> String {
        let filename = "\(UUID().uuidString).png"
        let url = storageURL.appendingPathComponent(filename)
        try? Self.downsampledPNG(from: pngData).write(to: url)
        return filename
    }

    func image(named: String) -> NSImage? {
        let url = storageURL.appendingPathComponent(named)
        guard FileManager.default.fileExists(atPath: url.path),
              let image = NSImage(contentsOf: url)
        else { return nil }
        let largestSide = max(image.size.width, image.size.height)
        if largestSide > Self.maxPixelSize, largestSide > 0 {
            let scale = Self.maxPixelSize / largestSide
            image.size = NSSize(
                width: image.size.width * scale,
                height: image.size.height * scale
            )
        }
        return image
    }

    func delete(named: String) {
        let url = storageURL.appendingPathComponent(named)
        try? FileManager.default.removeItem(at: url)
    }

    private static func downsampledPNG(from data: Data) -> Data {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let thumbnail = CGImageSourceCreateThumbnailAtIndex(
                  source,
                  0,
                  [
                      kCGImageSourceCreateThumbnailFromImageAlways: true,
                      kCGImageSourceThumbnailMaxPixelSize: maxPixelSize,
                      kCGImageSourceCreateThumbnailWithTransform: true,
                  ] as CFDictionary
              )
        else { return data }
        let rep = NSBitmapImageRep(cgImage: thumbnail)
        return rep.representation(using: .png, properties: [:]) ?? data
    }
}