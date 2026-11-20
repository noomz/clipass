import AppKit
import SwiftUI
import XCTest
@testable import clipass

final class ClipboardDragTests: XCTestCase {
    private var pasteboard: NSPasteboard!

    override func setUp() {
        pasteboard = NSPasteboard(name: NSPasteboard.Name("clipass-drag-\(UUID())"))
        ClipboardDragGate.shared.end(operation: [])
    }

    override func tearDown() {
        ClipboardDragGate.shared.end(operation: [])
        pasteboard.releaseGlobally()
    }

    func testTextDragOffersTheStoredStringAndDoesNotTouchTheClipboard() {
        let before = NSPasteboard.general.changeCount
        let offered = ClipboardPayload.text("hello").dragItem(fileExists: { _ in false }, imageFileURL: { _ in nil })
        pasteboard.clearContents()
        pasteboard.writeObjects([offered.item])

        XCTAssertEqual(pasteboard.string(forType: .string), "hello")
        XCTAssertNil(pasteboard.string(forType: .fileURL))
        XCTAssertNil(pasteboard.string(forType: .URL))
        XCTAssertNil(pasteboard.data(forType: .png))
        XCTAssertEqual(NSPasteboard.general.changeCount, before)
    }

    func testExistingFilePathAlsoOffersThatFile() {
        let offered = ClipboardPayload.text("  ~/Notes/report.txt  ").dragItem(
            fileExists: { $0 == NSString(string: "~/Notes/report.txt").expandingTildeInPath },
            imageFileURL: { _ in nil })
        pasteboard.clearContents()
        pasteboard.writeObjects([offered.item])

        XCTAssertEqual(pasteboard.string(forType: .string), "  ~/Notes/report.txt  ")
        let file = try? XCTUnwrap(URL(string: pasteboard.string(forType: .fileURL) ?? ""))
        XCTAssertEqual(file?.path, NSString(string: "~/Notes/report.txt").expandingTildeInPath)
    }

    func testMissingPathAndMultilineTextStayText() {
        let missing = ClipboardPayload.text("/tmp/clipass-does-not-exist").dragItem(
            fileExists: { _ in false }, imageFileURL: { _ in nil })
        let multiline = ClipboardPayload.text("/tmp/a\n/tmp/b").dragItem(
            fileExists: { _ in true }, imageFileURL: { _ in nil })
        for offered in [missing, multiline] {
            pasteboard.clearContents()
            pasteboard.writeObjects([offered.item])
            XCTAssertNil(pasteboard.string(forType: .fileURL))
        }
    }

    func testWebLinkAlsoOffersAURL() {
        let offered = ClipboardPayload.text("https://example.com/a").dragItem(
            fileExists: { _ in true }, imageFileURL: { _ in nil })
        pasteboard.clearContents()
        pasteboard.writeObjects([offered.item])
        XCTAssertEqual(pasteboard.string(forType: .string), "https://example.com/a")
        XCTAssertEqual(pasteboard.string(forType: .URL), "https://example.com/a")
        XCTAssertNil(pasteboard.string(forType: .fileURL))
    }

    func testImageDragOffersStoredPNGAndTIFFAndAFileWhenWritten() throws {
        let png = try TestImages.png(width: 4, height: 2)
        let file = URL(fileURLWithPath: "/tmp/clipass-drag-image.png")
        let offered = ClipboardPayload.image(png).dragItem(fileExists: { _ in false }, imageFileURL: { data in
            XCTAssertEqual(data, png)
            return file
        })
        pasteboard.clearContents()
        pasteboard.writeObjects([offered.item])

        XCTAssertEqual(pasteboard.data(forType: .png), png)
        let tiff = try XCTUnwrap(pasteboard.data(forType: .tiff))
        XCTAssertEqual(NSBitmapImageRep(data: tiff)?.pixelsWide, 4)
        XCTAssertNil(pasteboard.string(forType: .string))
        XCTAssertEqual(URL(string: pasteboard.string(forType: .fileURL) ?? "")?.path, file.path)
    }

    func testImageFileWriterStoresThePNGBytes() throws {
        let png = try TestImages.png(width: 2, height: 2)
        let url = try XCTUnwrap(ClipboardDragFiles.writeImage(png))
        defer { try? FileManager.default.removeItem(at: url) }
        XCTAssertEqual(try Data(contentsOf: url), png)
        XCTAssertEqual(url.pathExtension, "png")
    }

    @MainActor
    func testDragStartsOnlyAfterFourPoints() {
        XCTAssertFalse(ClipboardDragMonitor.shouldStart(from: .zero, to: NSPoint(x: 3.9, y: 0)))
        XCTAssertTrue(ClipboardDragMonitor.shouldStart(from: .zero, to: NSPoint(x: 4, y: 0)))
        XCTAssertTrue(ClipboardDragMonitor.shouldStart(from: NSPoint(x: 1, y: 1), to: NSPoint(x: 1, y: 5)))
    }

    func testPopoverHideWaitsUntilTheDrop() {
        let window = NSWindow(contentRect: NSRect(x: 80, y: 80, width: 120, height: 80),
                              styleMask: [.titled], backing: .buffered, defer: false)
        window.orderFront(nil)
        ClipboardDragGate.shared.begin(window: window)
        window.orderOut(nil)
        XCTAssertTrue(window.isVisible, "source window hid before the drop")
        ClipboardDragGate.shared.end(operation: [])
        XCTAssertTrue(window.isVisible, "a cancelled drag closed the popover")
        window.orderOut(nil)
        XCTAssertFalse(window.isVisible)

        window.orderFront(nil)
        ClipboardDragGate.shared.begin(window: window)
        window.close()
        XCTAssertTrue(window.isVisible)
        ClipboardDragGate.shared.end(operation: .copy)
        XCTAssertFalse(window.isVisible, "a completed drop left the popover open")
    }

    @MainActor
    func testHostedRowFrameMatchesAPointInsideTheRow() {
        let item = ClipboardItem(content: "stored secret")
        let host = NSHostingView(rootView: ClipboardBrowserRow(
            item: item, previewText: "stored secret", tags: [], isSelected: false, isHovered: false
        ) { EmptyView() }
            .clipboardDragHost()
            .frame(width: 300, height: 80))
        let window = NSWindow(contentRect: NSRect(x: 240, y: 240, width: 300, height: 80),
                              styleMask: [.borderless], backing: .buffered, defer: false)
        host.frame = NSRect(x: 0, y: 0, width: 300, height: 80)
        window.contentView = host
        window.orderFront(nil)
        defer {
            window.orderOut(nil)
            ClipboardDragMonitor.shared.removeFrame(item.id)
        }
        host.layoutSubtreeIfNeeded()
        RunLoop.current.run(until: Date().addingTimeInterval(0.15))

        let point = NSPoint(x: 80, y: 40)
        XCTAssertEqual(ClipboardDragMonitor.shared.rowID(in: window, at: point), item.id,
                       "a point inside the hosted row was not the drag target")
    }

    @MainActor
    func testRowFrameConvertsIntoTheWindowAndDoesNotCoverItWithADragView() {
        let swiftUI = CGRect(x: 8, y: 10, width: 280, height: 52)
        let converted = ClipboardDragMonitor.windowRect(for: swiftUI, height: 356)
        XCTAssertEqual(converted, NSRect(x: 8, y: 294, width: 280, height: 52))

        let item = ClipboardItem(content: "stored secret")
        let host = NSHostingView(rootView: ClipboardBrowserRow(
            item: item, previewText: "stored …", tags: [], isSelected: false, isHovered: false
        ) { EmptyView() }.clipboardDragHost())
        let window = NSWindow(contentRect: NSRect(x: 200, y: 200, width: 300, height: 52),
                              styleMask: [.titled], backing: .buffered, defer: false)
        host.frame = window.contentView!.bounds
        window.contentView = host
        window.orderFront(nil)
        defer { window.orderOut(nil) }
        host.layoutSubtreeIfNeeded()
        let covering = Self.views(in: host).filter { $0 is ClipboardDragSource && $0.bounds.width > 20 }
        XCTAssertTrue(covering.isEmpty, "drag source covers the row and will swallow clicks")
    }

    private static func views(in view: NSView) -> [NSView] {
        [view] + view.subviews.flatMap { views(in: $0) }
    }

    func testOverlayStaysUpDuringADragAndDismissesAfterTheDrop() {
        let panel = OverlayPanel()
        panel.setFrame(NSRect(x: 120, y: 120, width: 200, height: 120), display: false)
        panel.shownAt = Date().addingTimeInterval(-1)
        panel.orderFront(nil)
        ClipboardDragGate.shared.begin(window: panel)
        panel.resignKey()
        XCTAssertTrue(panel.isVisible, "overlay dismissed while the drag was active")
        ClipboardDragGate.shared.end(operation: .copy)
        XCTAssertFalse(panel.isVisible)

        panel.shownAt = Date().addingTimeInterval(-1)
        panel.orderFront(nil)
        ClipboardDragGate.shared.begin(window: panel)
        ClipboardDragGate.shared.end(operation: [])
        XCTAssertTrue(panel.isVisible, "a cancelled drag that never left the overlay dismissed it")
        panel.orderOut(nil)
    }
}
