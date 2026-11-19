import XCTest
import SwiftData
@testable import clipass

@MainActor
final class ClipboardBrowserSnapshotTests: XCTestCase {
    private func makeContext() throws -> ModelContext {
        let container = try ModelContainer(
            for: ClipboardItem.self, Tag.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        return ModelContext(container)
    }

    func testImageItemsSnapshotAsImagesAndMatchSearchForImage() throws {
        let context = try makeContext()
        let image = ClipboardItem(content: "Image 1440×900", imageData: Data([1]), thumbnailData: Data([2]),
                                  imageHash: "abc")
        let note = ClipboardItem(content: "Meeting notes")
        context.insert(image)
        context.insert(note)
        try context.save()

        var browser = ClipboardBrowserState(items: [image, note].map {
            ClipboardBrowserState.Item($0, tagLookup: .empty)
        })
        XCTAssertEqual(browser.visibleItems.map(\.isImage).sorted { !$0 && $1 }, [false, true])
        browser.setQuery("image")
        XCTAssertEqual(browser.visibleItems.map(\.id), [image.id])
        XCTAssertTrue(try XCTUnwrap(browser.selectedItem).isImage)
    }

    func testV3PinChangesKeepNativeSnapshotsChronological() throws {
        let context = try makeContext()
        let old = ClipboardItem(content: "old", timestamp: Date(timeIntervalSince1970: 10))
        let new = ClipboardItem(content: "new", timestamp: Date(timeIntervalSince1970: 20))
        context.insert(old)
        context.insert(new)
        try context.save()
        let items = [old, new]
        var browser = ClipboardBrowserState(items: items.map {
            ClipboardBrowserState.Item($0, tagLookup: .empty)
        })

        old.isPinned = true
        browser.replaceItems(items.map { ClipboardBrowserState.Item($0, tagLookup: .empty) })
        XCTAssertEqual(browser.visibleItems.map(\.id), [new.id, old.id])

        browser.openTab(.pinned)
        XCTAssertEqual(browser.visibleItems.map(\.id), [old.id])
        old.isPinned = false
        browser.replaceItems(items.map { ClipboardBrowserState.Item($0, tagLookup: .empty) })
        XCTAssertTrue(browser.visibleItems.isEmpty)
        XCTAssertNil(browser.selectedItem)
    }

    func testV5NativeTagChangesUpdateSharedSearchInBothSessions() throws {
        let context = try makeContext()
        let item = ClipboardItem(content: "Work notes", isPinned: true)
        let tag = Tag(name: "Work")
        context.insert(item)
        context.insert(tag)
        item.tags.append(tag)
        try context.save()
        let lookup = TagLookup.build(from: context)
        let snapshots = [ClipboardBrowserState.Item(item, tagLookup: lookup)]
        var popup = ClipboardBrowserState(items: snapshots)
        var overlay = ClipboardBrowserState(items: snapshots)
        overlay.openTab(.pinned)

        for query in [" Work notes ", "TAG:work notes"] {
            popup.setQuery(query)
            overlay.setQuery(query)
            XCTAssertEqual(popup.visibleItems, overlay.visibleItems)
            XCTAssertEqual(popup.selectedID, item.id)
            XCTAssertEqual(popup.query, query)
        }

        item.tags.removeAll()
        try context.save()
        let refreshed = [ClipboardBrowserState.Item(item, tagLookup: TagLookup.build(from: context))]
        popup.replaceItems(refreshed)
        overlay.replaceItems(refreshed)
        XCTAssertNil(popup.selectedItem)
        XCTAssertNil(overlay.selectedItem)
    }

    func testV15SourceNamesResolveWithoutChangingStoredIdentifiers() {
        let finder = ClipboardItem(content: "notes", sourceApp: "com.apple.finder")
        XCTAssertNotNil(finder.sourceAppDisplayName)
        XCTAssertNotEqual(finder.sourceAppDisplayName, "com.apple.finder")
        XCTAssertEqual(finder.sourceApp, "com.apple.finder")

        let unknown = ClipboardItem(content: "notes", sourceApp: "invalid.clipass.fixture")
        XCTAssertEqual(unknown.sourceAppDisplayName, "invalid.clipass.fixture")
        XCTAssertNil(ClipboardItem(content: "notes").sourceAppDisplayName)
    }

    func testV6EmptyStatesAndClearSearchReconcileSelection() {
        var browser = ClipboardBrowserState()
        XCTAssertEqual(browser.emptyState, .history)
        browser.openTab(.pinned)
        XCTAssertEqual(browser.emptyState, .history)
        XCTAssertNil(browser.selectedItem)

        let item = ClipboardBrowserState.Item(
            id: UUID(), content: "notes", timestamp: Date(), isPinned: false, tagNames: []
        )
        browser.replaceItems([item])
        XCTAssertEqual(browser.emptyState, .pinned)
        XCTAssertNil(browser.selectedItem)

        browser.setQuery("missing")
        XCTAssertEqual(browser.emptyState, .noMatches)
        browser.openTab(.recent)
        XCTAssertEqual(browser.emptyState, .noMatches)
        XCTAssertNil(browser.selectedItem)

        browser.setQuery("")
        XCTAssertNil(browser.emptyState)
        XCTAssertEqual(browser.selectedID, item.id)
    }
}
