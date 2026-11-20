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
            ClipboardDragMonitor.shared.remove(item.id, from: window)
        }
        host.layoutSubtreeIfNeeded()
        RunLoop.current.run(until: Date().addingTimeInterval(0.15))

        let point = NSPoint(x: 80, y: 40)
        XCTAssertEqual(ClipboardDragMonitor.shared.rowID(in: window, at: point), item.id,
                       "a point inside the hosted row was not the drag target")
    }

    @MainActor
    func testSameItemInTwoWindowsKeepsEachWindowOwnRow() {
        let item = ClipboardItem(content: "stored secret")
        let left = hosted(item, width: 200, height: 80)
        let right = hosted(item, width: 200, height: 80, topSpacer: 60)
        defer {
            left.orderOut(nil)
            right.orderOut(nil)
            ClipboardDragMonitor.shared.remove(item.id, from: left)
            ClipboardDragMonitor.shared.remove(item.id, from: right)
        }
        RunLoop.current.run(until: Date().addingTimeInterval(0.2))

        XCTAssertEqual(ClipboardDragMonitor.shared.rowID(in: left, at: NSPoint(x: 40, y: 40)), item.id)
        XCTAssertNil(ClipboardDragMonitor.shared.rowID(in: right, at: NSPoint(x: 40, y: 70)),
                     "the other window's row frame was used")
        XCTAssertEqual(ClipboardDragMonitor.shared.rowID(in: right, at: NSPoint(x: 40, y: 8)), item.id)
    }

    @MainActor
    func testScrolledAwayRowIsNotADragTargetOutsideTheList() {
        let item = ClipboardItem(content: "stored secret")
        let window = NSWindow(contentRect: NSRect(x: 300, y: 300, width: 200, height: 160),
                              styleMask: [.borderless], backing: .buffered, defer: false)
        let scroll = NSScrollView(frame: NSRect(x: 0, y: 0, width: 200, height: 80))
        scroll.documentView = NSView(frame: NSRect(x: 0, y: 0, width: 200, height: 80))
        let row = NSHostingView(rootView: ClipboardBrowserRow(
            item: item, previewText: "stored secret", tags: [], isSelected: false, isHovered: false
        ) { EmptyView() }.clipboardDragHost())
        row.frame = NSRect(x: 0, y: 100, width: 200, height: 40)
        scroll.addSubview(row)
        window.contentView = NSView(frame: NSRect(x: 0, y: 0, width: 200, height: 160))
        window.contentView?.addSubview(scroll)
        window.orderFront(nil)
        defer {
            window.orderOut(nil)
            ClipboardDragMonitor.shared.remove(item.id, from: window)
        }
        row.layoutSubtreeIfNeeded()
        RunLoop.current.run(until: Date().addingTimeInterval(0.2))

        XCTAssertNil(ClipboardDragMonitor.shared.rowID(in: window, at: NSPoint(x: 40, y: 110)),
                     "a row outside the list was a drag target")
    }

    @MainActor
    private func hosted(_ item: ClipboardItem, width: CGFloat, height: CGFloat, topSpacer: CGFloat = 0) -> NSWindow {
        let row = ClipboardBrowserRow(
            item: item, previewText: item.content, tags: [], isSelected: false, isHovered: false
        ) { EmptyView() }
        let root = VStack(spacing: 0) {
            Color.clear.frame(height: topSpacer)
            row.frame(height: height - topSpacer)
        }
        .clipboardDragHost()
        .frame(width: width, height: height)
        let host = NSHostingView(rootView: root)
        let window = NSWindow(contentRect: NSRect(x: 400, y: 400, width: width, height: height),
                              styleMask: [.borderless], backing: .buffered, defer: false)
        host.frame = NSRect(x: 0, y: 0, width: width, height: height)
        window.contentView = host
        window.orderFront(nil)
        host.layoutSubtreeIfNeeded()
        return window
    }

    @MainActor
    func testRowDoesNotCoverItselfWithADragView() {
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
        let other = NSWindow(contentRect: NSRect(x: 400, y: 400, width: 80, height: 60),
                             styleMask: [.titled], backing: .buffered, defer: false)
        defer { other.orderOut(nil) }
        panel.makeKeyAndOrderFront(nil)
        ClipboardDragGate.shared.begin(window: panel)
        other.makeKeyAndOrderFront(nil)
        XCTAssertTrue(panel.isVisible, "overlay dismissed while the drag was active")
        var restored = false
        let token = NotificationCenter.default.addObserver(
            forName: .overlayDidResignKey, object: nil, queue: nil) { _ in restored = true }
        ClipboardDragGate.shared.end(operation: .copy)
        XCTAssertFalse(panel.isVisible)
        XCTAssertFalse(restored, "a completed drop restored the app that was in front before the overlay")
        NotificationCenter.default.removeObserver(token)

        panel.shownAt = Date().addingTimeInterval(-1)
        panel.makeKeyAndOrderFront(nil)
        ClipboardDragGate.shared.begin(window: panel)
        ClipboardDragGate.shared.end(operation: [])
        XCTAssertTrue(panel.isVisible, "a cancelled drag that never left the overlay dismissed it")

        ClipboardDragGate.shared.begin(window: panel)
        other.makeKeyAndOrderFront(nil)
        restored = false
        let cancel = NotificationCenter.default.addObserver(
            forName: .overlayDidResignKey, object: nil, queue: nil) { _ in restored = true }
        ClipboardDragGate.shared.end(operation: [])
        XCTAssertFalse(panel.isVisible)
        XCTAssertTrue(restored, "a cancelled drag that left the overlay did not return to the previous app")
        NotificationCenter.default.removeObserver(cancel)
    }
}
