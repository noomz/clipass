import AppKit
import SwiftData
import SwiftUI

extension NativeBrowserChecks {
    static func exerciseHistoryActions(isOverlay: Bool) async throws {
        let name = isOverlay ? "overlay" : "hosted popover"
        let container = try ModelContainer(
            for: ClipboardItem.self, TransformRule.self, Hook.self, IgnoredApp.self,
            IgnoredPattern.self, RedactionPattern.self, ContextAction.self, Tag.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let context = container.mainContext
        let pin = ClipboardItem(content: "Keep this pin", timestamp: Date(timeIntervalSince1970: 1), isPinned: true)
        let recent = ClipboardItem(content: "Restore this copy", timestamp: Date(timeIntervalSince1970: 2))
        let newest = ClipboardItem(content: "Delete this copy", timestamp: Date(timeIntervalSince1970: 3))
        context.insert(pin)
        context.insert(recent)
        context.insert(newest)
        context.insert(ContextAction(name: "Example action", command: "", contentFilter: "Delete this copy"))
        try context.save()

        var copied: ClipboardPayload?
        let (host, window) = showInterface(isOverlay: isOverlay, context: context) { copied = $0 }
        defer { window.close() }
        try await waitForInterface(host)

        let row = try rowMenu("Delete this copy", in: host, window: window)
        try expect(row.item(withTitle: "Copy") != nil && row.item(withTitle: "Pin") != nil &&
                   row.item(withTitle: "Example action") != nil, "\(name): context menu lacks Copy, Pin or custom action")
        let formats = row.item(withTitle: "Copy As...")?.submenu
        try expect(["Plain Text", "Uppercase", "Trimmed", "Base64 Encoded"].allSatisfy { formats?.item(withTitle: $0) != nil },
                   "\(name): context menu lacks copy formats")
        try activateMenuItem("Pin", in: row)
        try await settle()
        let pinnedRow = try rowMenu("Delete this copy", in: host, window: window)
        try expect(newest.isPinned, "\(name): Pin did not update the item")
        try activateMenuItem("Unpin", in: pinnedRow)
        try await settle()
        try expect(!newest.isPinned, "\(name): Unpin did not update the item")
        try activateMenuItem("Delete", in: pinnedRow)
        try await settle()
        try expect(!text(in: host).contains("Delete this copy"), "\(name): deleted row is still visible")
        try press("Copy & close", in: host)
        try expect(copied == .text("Restore this copy"), "\(name): deletion left stale selection")

        try await openClearConfirmation(in: host, window: window)
        try expect(text(in: host).contains("Pinned items will be kept."), "\(name): no explanation that pins are kept")
        copied = nil
        try await key("\r", code: 36, in: window)
        try expect(element("Cancel", in: host) == nil && element("Undo", in: host) == nil,
                   "\(name): Return did not cancel safely")
        try expect(copied == nil && text(in: host).contains("Restore this copy"), "\(name): cancel copied or removed an item")

        try await openClearConfirmation(in: host, window: window)
        try await key("\u{1B}", code: 53, in: window)
        try expect(element("Cancel", in: host) == nil && window.isVisible, "\(name): Escape did not close only the confirmation")

        try await openClearConfirmation(in: host, window: window)
        try press("Clear Recent", in: host)
        try await settle()
        try expect(!text(in: host).contains("Restore this copy") && text(in: host).contains("Keep this pin"),
                   "\(name): Clear Recent removed the wrong rows")
        try press("Copy & close", in: host)
        try expect(copied == .text("Keep this pin"), "\(name): Clear Recent left stale selection")

        context.insert(ClipboardItem(content: "Copied after clearing"))
        try context.save()
        try await settle()
        try press("Undo", in: host)
        try await settle()
        let afterUndo = text(in: host)
        try expect(afterUndo.contains("Restore this copy") && afterUndo.contains("Keep this pin") &&
                   afterUndo.contains("Copied after clearing") && !afterUndo.contains("Delete this copy"),
                   "\(name): Undo did not restore precisely the cleared history")
        try expect(element("Undo", in: host) == nil, "\(name): Undo is still offered after restore")
        print("PASS: \(name) V13–V14 item actions, selection reconciliation, safe confirmation and Undo")
    }

    static func rowMenu(_ label: String, in host: NSView, window: NSWindow) throws -> NSMenu {
        let rect = window.convertFromScreen(try textFrame(label, in: host))
        let point = NSPoint(x: rect.midX, y: rect.midY)
        func receiver(in view: NSView) -> RightClickReceiver.RightClickNSView? {
            if let receiver = view as? RightClickReceiver.RightClickNSView,
               receiver.bounds.contains(receiver.convert(point, from: nil)) { return receiver }
            return view.subviews.lazy.compactMap { receiver(in: $0) }.first
        }
        guard let menu = receiver(in: host)?.menuBuilder?() else {
            throw Failure(description: "No native item menu for \(label)")
        }
        return menu
    }

    private static func activateMenuItem(_ label: String, in menu: NSMenu) throws {
        guard let item = menu.item(withTitle: label), item.isEnabled, let action = item.action,
              NSApp.sendAction(action, to: item.target, from: item) else {
            throw Failure(description: "Could not activate \(label) in \(menu.items.map(\.title))")
        }
    }

    @MainActor private final class TrackedMenu {
        var menu: NSMenu?
    }

    private static func openClearConfirmation(in host: NSView, window: NSWindow) async throws {
        let tracked = TrackedMenu()
        let label = "Clear Recent History…"
        let observer = NotificationCenter.default.addObserver(forName: NSMenu.didBeginTrackingNotification,
                                                              object: nil, queue: nil) { notification in
            MainActor.assumeIsolated {
                tracked.menu = notification.object as? NSMenu
            }
        }
        let stopTracking = Timer(timeInterval: 0.2, repeats: false) { _ in
            MainActor.assumeIsolated { tracked.menu?.cancelTracking() }
        }
        RunLoop.main.add(stopTracking, forMode: .eventTracking)
        RunLoop.main.add(stopTracking, forMode: .common)
        defer {
            stopTracking.invalidate()
            NotificationCenter.default.removeObserver(observer)
        }
        try clickText("More", in: host, window: window)
        try await settle()
        guard let trackedMenu = tracked.menu else { throw Failure(description: "Overflow did not open its native menu") }
        try activateMenuItem(label, in: trackedMenu)
        try await settle()
        try expect(element("Cancel", in: host) != nil, "Clear Recent History did not open confirmation")
    }
}
