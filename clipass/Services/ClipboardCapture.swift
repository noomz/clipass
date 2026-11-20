import AppKit
import CryptoKit
import ImageIO

struct CapturedImage: Equatable {
    let png: Data
    let thumbnail: Data
    let hash: String
    let label: String
}

enum CapturedPayload: Equatable {
    case text(String)
    case image(CapturedImage)
}

/// Reads what clipass stores from a pasteboard. Safe off the main queue.
enum ClipboardCapture {
    static let maxImageBytes = 20 * 1024 * 1024
    static let thumbnailMaxPixels = 96

    /// A string always wins, so Finder file copies and spreadsheet cells stay text.
    static func read(from pasteboard: NSPasteboard) -> CapturedPayload? {
        if let text = pasteboard.string(forType: .string) { return .text(text) }
        if let png = pasteboard.data(forType: .png) { return image(png: png).map(CapturedPayload.image) }
        guard let tiff = pasteboard.data(forType: .tiff),
              let png = NSBitmapImageRep(data: tiff)?.representation(using: .png, properties: [:]) else { return nil }
        return image(png: png).map(CapturedPayload.image)
    }

    static func image(png: Data) -> CapturedImage? {
        guard png.count <= maxImageBytes, let size = pixelSize(of: png),
              let thumbnail = thumbnail(of: png) else { return nil }
        return CapturedImage(png: png, thumbnail: thumbnail, hash: hash(png),
                             label: "Image \(size.width)×\(size.height)")
    }

    static func hash(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    static func pixelSize(of data: Data) -> (width: Int, height: Int)? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let width = properties[kCGImagePropertyPixelWidth] as? Int,
              let height = properties[kCGImagePropertyPixelHeight] as? Int,
              width > 0, height > 0 else { return nil }
        return (width, height)
    }

    private static func thumbnail(of data: Data) -> Data? {
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: thumbnailMaxPixels,
        ]
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else { return nil }
        return NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:])
    }
}
