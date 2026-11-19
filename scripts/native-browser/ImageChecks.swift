import AppKit
import SwiftData

extension NativeBrowserChecks {
    static func exerciseImage(isOverlay: Bool) async throws {
        let name = isOverlay ? "overlay" : "hosted popover"
        let container = try ModelContainer(
            for: ClipboardItem.self, TransformRule.self, Hook.self, IgnoredApp.self,
            IgnoredPattern.self, RedactionPattern.self, ContextAction.self, Tag.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let context = container.mainContext
        let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 640, pixelsHigh: 320, bitsPerSample: 8,
                                   samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
                                   bytesPerRow: 0, bitsPerPixel: 0)
        guard let rep, let pixels = rep.bitmapData else { throw Failure(description: "Could not build image fixture") }
        for index in 0..<(rep.bytesPerRow * rep.pixelsHigh) {
            pixels[index] = index % 4 == 3 ? 255 : UInt8(truncatingIfNeeded: index / 4 % 64 * 4)
        }
        guard let png = rep.representation(using: .png, properties: [:]),
              let image = ClipboardCapture.image(png: png) else { throw Failure(description: "Could not build image fixture") }
        context.insert(ClipboardItem(content: "Older text copy", timestamp: Date(timeIntervalSince1970: 1)))
        context.insert(ClipboardItem(content: image.label, sourceApp: "com.apple.Safari", timestamp: Date(timeIntervalSince1970: 2),
                                     imageData: image.png, thumbnailData: image.thumbnail, imageHash: image.hash))
        context.insert(ContextAction(name: "Example action", command: "", contentFilter: ""))
        try context.save()

        var copied: ClipboardPayload?
        let (host, window) = showInterface(isOverlay: isOverlay, context: context) { copied = $0 }
        defer { window.close() }
        try await waitForInterface(host)
        try expect(text(in: host).contains("Image 640×320"), "\(name): image row label missing: \(text(in: host))")
        try expect(element("Edit item", in: host) == nil, "\(name): selected image row offers editing")
        try capture(host, name: "\(name)-image-row")

        let menu = try rowMenu("Image 640×320", in: host, window: window)
        try expect(menu.item(withTitle: "Copy") != nil && menu.item(withTitle: "Pin") != nil &&
                   menu.item(withTitle: "Delete") != nil, "\(name): image menu lacks Copy, Pin or Delete")
        try expect(menu.item(withTitle: "Copy As...") == nil && menu.item(withTitle: "Example action") == nil,
                   "\(name): image menu offers text actions")

        try await key("p", code: 35, modifiers: .command, in: window)
        try expect(text(in: host).contains("640 × 320 px") && element("Image 640×320", in: host) != nil,
                   "\(name): image preview lacks pixel size or image: \(text(in: host))")
        let shown = try textFrame("Image 640×320", in: host)
        try expect(shown.width > 100 && shown.width <= 640 && abs(shown.width / shown.height - 2) < 0.05,
                   "\(name): preview image is not scaled to fit at its aspect ratio: \(shown)")
        try capture(host, name: "\(name)-image-preview")
        try await key("\r", code: 36, in: window)
        try expect(copied == .image(image.png), "\(name): Return did not copy the stored image bytes")
        print("PASS: \(name) image row, menu, preview, and image Copy & close")
    }
}
