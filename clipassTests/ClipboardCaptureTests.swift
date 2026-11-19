import AppKit
import XCTest
@testable import clipass

final class ClipboardCaptureTests: XCTestCase {
    private var pasteboard: NSPasteboard!

    override func setUp() {
        pasteboard = NSPasteboard(name: NSPasteboard.Name("clipass-tests-\(UUID())"))
        pasteboard.clearContents()
    }

    override func tearDown() {
        pasteboard.releaseGlobally()
    }

    func testPNGOnlyPasteboardCapturesImageWithPixelLabelAndHash() throws {
        let png = try TestImages.png(width: 40, height: 20)
        pasteboard.setData(png, forType: .png)

        guard case .image(let image) = ClipboardCapture.read(from: pasteboard) else {
            return XCTFail("PNG pasteboard was not captured as an image")
        }
        XCTAssertEqual(image.png, png)
        XCTAssertEqual(image.label, "Image 40×20")
        XCTAssertEqual(image.hash, ClipboardCapture.hash(png))
        XCTAssertEqual(image.hash.count, 64)
        let thumbnail = try XCTUnwrap(NSBitmapImageRep(data: image.thumbnail))
        XCTAssertLessThanOrEqual(max(thumbnail.pixelsWide, thumbnail.pixelsHigh), ClipboardCapture.thumbnailMaxPixels)
    }

    func testStringBeatsImageOnTheSamePasteboard() throws {
        pasteboard.declareTypes([.string, .tiff], owner: nil)
        pasteboard.setString("report.pdf", forType: .string)
        pasteboard.setData(try TestImages.tiff(width: 8, height: 8), forType: .tiff)
        XCTAssertEqual(ClipboardCapture.read(from: pasteboard), .text("report.pdf"))
    }

    func testTIFFOnlyPasteboardIsStoredAsPNG() throws {
        pasteboard.setData(try TestImages.tiff(width: 12, height: 6), forType: .tiff)

        guard case .image(let image) = ClipboardCapture.read(from: pasteboard) else {
            return XCTFail("TIFF pasteboard was not captured as an image")
        }
        XCTAssertEqual(image.png.prefix(8), Data([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]))
        XCTAssertEqual(image.label, "Image 12×6")
    }

    func testRecopiedImageHashesTheSameSoHistoryDedupes() throws {
        pasteboard.setData(try TestImages.tiff(width: 10, height: 10), forType: .tiff)
        guard case .image(let first) = ClipboardCapture.read(from: pasteboard) else {
            return XCTFail("first capture missing")
        }
        ClipboardPayload.image(first.png).write(to: pasteboard)
        guard case .image(let again) = ClipboardCapture.read(from: pasteboard) else {
            return XCTFail("re-copied image was not captured")
        }
        XCTAssertEqual(again.hash, first.hash)
    }

    func testEmptyOrUndecodablePasteboardCapturesNothing() {
        XCTAssertNil(ClipboardCapture.read(from: pasteboard))
        pasteboard.setData(Data("not a png".utf8), forType: .png)
        XCTAssertNil(ClipboardCapture.read(from: pasteboard))
    }
}
