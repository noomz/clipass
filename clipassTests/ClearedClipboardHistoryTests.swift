import SwiftData
import XCTest
@testable import clipass

final class ClearedClipboardHistoryTests: XCTestCase {
    @MainActor
    func testClearAndUndoPreservePinsTagsAndLaterCaptures() throws {
        let container = try ModelContainer(for: ClipboardItem.self, Tag.self,
                                           configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let context = container.mainContext
        let pin = ClipboardItem(content: "Pinned", isPinned: true)
        let recent = ClipboardItem(content: "Original", sourceApp: "org.example.notes",
                                   timestamp: Date(timeIntervalSince1970: 123))
        let tag = Tag(name: "Work")
        context.insert(pin)
        context.insert(recent)
        context.insert(tag)
        recent.tags = [tag]
        pin.tags = [tag]
        let recentID = recent.id
        let pinID = pin.id
        try context.save()

        let cleared = try ClearedClipboardHistory.clear(in: context)
        XCTAssertEqual(cleared.count, 1)
        XCTAssertEqual(try context.fetch(FetchDescriptor<ClipboardItem>()).map(\.id), [pinID])
        XCTAssertEqual(tag.items.map(\.id), [pinID])

        let later = ClipboardItem(content: "Copied later")
        context.insert(later)
        pin.content = "Pinned, edited later"
        try context.save()
        try cleared.restore(in: context)
        try cleared.restore(in: context)

        let items = try context.fetch(FetchDescriptor<ClipboardItem>())
        XCTAssertEqual(items.count, 3)
        let restored = try XCTUnwrap(items.first { $0.id == recentID })
        XCTAssertEqual(restored.content, "Original")
        XCTAssertEqual(restored.sourceApp, "org.example.notes")
        XCTAssertEqual(restored.timestamp, Date(timeIntervalSince1970: 123))
        XCTAssertFalse(restored.isPinned)
        XCTAssertEqual(restored.tags.map(\.id), [tag.id])
        XCTAssertEqual(Set(tag.items.map(\.id)), Set([pinID, recentID]))
        XCTAssertEqual(items.first { $0.id == later.id }?.content, "Copied later")
        XCTAssertEqual(items.first { $0.id == pinID }?.content, "Pinned, edited later")
    }

    @MainActor
    func testUndoRestoresImageItems() throws {
        let container = try ModelContainer(for: ClipboardItem.self, Tag.self,
                                           configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let context = container.mainContext
        let png = try TestImages.png(width: 6, height: 3)
        let image = ClipboardItem(content: "Image 6×3", imageData: png, thumbnailData: Data([7]),
                                  imageHash: ClipboardCapture.hash(png))
        let imageID = image.id
        context.insert(image)
        try context.save()

        let cleared = try ClearedClipboardHistory.clear(in: context)
        XCTAssertTrue(try context.fetch(FetchDescriptor<ClipboardItem>()).isEmpty)
        try cleared.restore(in: context)

        let restored = try XCTUnwrap(try context.fetch(FetchDescriptor<ClipboardItem>()).first)
        XCTAssertEqual(restored.id, imageID)
        XCTAssertEqual(restored.payload, .image(png))
        XCTAssertEqual(restored.thumbnailData, Data([7]))
        XCTAssertEqual(restored.imageHash, ClipboardCapture.hash(png))
        XCTAssertEqual(restored.content, "Image 6×3")
    }

    @MainActor
    func testClearWithOnlyPinsIsANoOp() throws {
        let container = try ModelContainer(for: ClipboardItem.self, Tag.self,
                                           configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let context = container.mainContext
        let pin = ClipboardItem(content: "Pinned", isPinned: true)
        context.insert(pin)
        try context.save()
        XCTAssertEqual(try ClearedClipboardHistory.clear(in: context).count, 0)
        XCTAssertEqual(try context.fetch(FetchDescriptor<ClipboardItem>()).map(\.id), [pin.id])
    }
}
