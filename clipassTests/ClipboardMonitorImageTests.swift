import AppKit
import Combine
import SwiftData
import XCTest
@testable import clipass

@MainActor
final class ClipboardMonitorImageTests: XCTestCase {
    func testImageCapturesDedupeByHashAndNeverMatchTextWithTheSameLabel() throws {
        let pasteboard = NSPasteboard(name: NSPasteboard.Name("clipass-tests-\(UUID())"))
        defer { pasteboard.releaseGlobally() }
        let container = try ModelContainer(for: ClipboardItem.self, Tag.self, IgnoredApp.self, IgnoredPattern.self,
                                           configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let context = container.mainContext
        let monitor = ClipboardMonitor(pasteboard: pasteboard)
        monitor.setModelContext(context)
        monitor.start()
        defer { monitor.stop() }
        var captures = 0
        let subscription = monitor.captures.sink { captures += 1 }
        defer { subscription.cancel() }

        func copy(_ payload: ClipboardPayload) {
            let expected = captures + 1
            payload.write(to: pasteboard)
            let deadline = Date().addingTimeInterval(5)
            while captures < expected && Date() < deadline {
                RunLoop.main.run(until: Date().addingTimeInterval(0.05))
            }
            XCTAssertEqual(captures, expected, "capture of \(payload) did not land")
        }

        let png = try TestImages.png(width: 10, height: 10)
        copy(.image(png))
        copy(.image(png))
        copy(.text("Image 10×10"))

        let items = try context.fetch(FetchDescriptor<ClipboardItem>())
        XCTAssertEqual(items.count, 2)
        let image = try XCTUnwrap(items.first { $0.isImage })
        XCTAssertEqual(image.content, "Image 10×10")
        XCTAssertEqual(image.imageData, png)
        XCTAssertEqual(image.imageHash, ClipboardCapture.hash(png))
        XCTAssertNotNil(image.thumbnailData)
        XCTAssertEqual(items.first { !$0.isImage }?.payload, .text("Image 10×10"))
    }
}
