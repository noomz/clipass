import AppKit
import XCTest
@testable import clipass

final class ClipboardPayloadTests: XCTestCase {
    private var pasteboard: NSPasteboard!

    override func setUp() {
        pasteboard = NSPasteboard(name: NSPasteboard.Name("clipass-tests-\(UUID())"))
    }

    override func tearDown() {
        pasteboard.releaseGlobally()
    }

    func testTextPayloadWritesOnlyAString() {
        ClipboardPayload.text("hello").write(to: pasteboard)
        XCTAssertEqual(pasteboard.string(forType: .string), "hello")
        XCTAssertNil(pasteboard.data(forType: .png))
        XCTAssertNil(pasteboard.data(forType: .tiff))
    }

    func testImagePayloadWritesStoredPNGAndTIFF() throws {
        let png = try TestImages.png(width: 4, height: 2)
        ClipboardPayload.image(png).write(to: pasteboard)
        XCTAssertEqual(pasteboard.data(forType: .png), png)
        let tiff = try XCTUnwrap(pasteboard.data(forType: .tiff))
        XCTAssertEqual(NSBitmapImageRep(data: tiff)?.pixelsWide, 4)
        XCTAssertNil(pasteboard.string(forType: .string))
    }

    func testItemPayloadPrefersImageData() throws {
        let png = try TestImages.png(width: 1, height: 1)
        XCTAssertEqual(ClipboardItem(content: "note").payload, .text("note"))
        let image = ClipboardItem(content: "Image 1×1", imageData: png, imageHash: "h")
        XCTAssertEqual(image.payload, .image(png))
        XCTAssertTrue(image.isImage)
        XCTAssertFalse(ClipboardItem(content: "note").isImage)
    }
}

enum TestImages {
    /// A bitmap whose point size is half its pixel size, like a Retina screenshot.
    static func rep(width: Int, height: Int) throws -> NSBitmapImageRep {
        let rep = try XCTUnwrap(NSBitmapImageRep(
            bitmapDataPlanes: nil, pixelsWide: width, pixelsHigh: height, bitsPerSample: 8,
            samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
            bytesPerRow: 0, bitsPerPixel: 0))
        let pixels = try XCTUnwrap(rep.bitmapData)
        for index in 0..<(rep.bytesPerRow * height) {
            pixels[index] = UInt8(truncatingIfNeeded: index * 7)
        }
        rep.size = NSSize(width: CGFloat(width) / 2, height: CGFloat(height) / 2)
        return rep
    }

    static func png(width: Int, height: Int) throws -> Data {
        try XCTUnwrap(rep(width: width, height: height).representation(using: .png, properties: [:]))
    }

    static func tiff(width: Int, height: Int) throws -> Data {
        try XCTUnwrap(rep(width: width, height: height).tiffRepresentation)
    }
}
