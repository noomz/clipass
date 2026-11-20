import AppKit
import SwiftData

extension NativeBrowserChecks {
    @MainActor
    final class CaptureFixture {
        let container: ModelContainer
        let pasteboard = NSPasteboard.withUniqueName()
        lazy var monitor = ClipboardMonitor(pasteboard: pasteboard)
        var copied: ClipboardPayload?
        var context: ModelContext { container.mainContext }

        init() throws {
            container = try ModelContainer(
                for: ClipboardItem.self, TransformRule.self, Hook.self, IgnoredApp.self,
                IgnoredPattern.self, RedactionPattern.self, ContextAction.self, Tag.self,
                configurations: ModelConfiguration(isStoredInMemoryOnly: true)
            )
            for index in 1...40 {
                context.insert(ClipboardItem(content: Self.row(index), timestamp: Date(timeIntervalSince1970: Double(index)),
                                             isPinned: index.isMultiple(of: 2)))
            }
            try context.save()
        }

        static func row(_ index: Int) -> String { "Fixture note \(String(format: "%02d", index))" }

        func capture(_ content: String) async throws {
            let previous = try mostRecent()?.timestamp
            pasteboard.clearContents()
            pasteboard.setString(content, forType: .string)
            for _ in 0..<25 {
                if let newest = try mostRecent(), newest.content == content, newest.timestamp != previous {
                    try await settle()
                    return
                }
                try await Task.sleep(nanoseconds: 100_000_000)
            }
            throw Failure(description: "ClipboardMonitor did not capture \(content)")
        }

        private func mostRecent() throws -> ClipboardItem? {
            try context.fetch(FetchDescriptor<ClipboardItem>(sortBy: [SortDescriptor(\.timestamp, order: .reverse)])).first
        }
    }

    static func exerciseSummon(isOverlay: Bool) async throws {
        let name = isOverlay ? "overlay" : "menu-bar popover"
        let fixture = isOverlay ? try CaptureFixture() : popoverFixture
        fixture.monitor.setModelContext(fixture.context)
        fixture.monitor.start()
        defer {
            fixture.monitor.stop()
            fixture.pasteboard.releaseGlobally()
        }

        let panel: OverlayPanel?
        let initial: (NSView, NSWindow)
        if isOverlay {
            let (host, window) = showInterface(isOverlay: true, context: fixture.context, monitor: fixture.monitor) { fixture.copied = $0 }
            panel = window as? OverlayPanel
            initial = (host, window)
        } else {
            panel = nil
            initial = try await openRealPopover()
        }
        defer { panel?.close() }
        try await waitForInterface(initial.0)
        try await assertLatest(CaptureFixture.row(40), in: initial, fixture: fixture, isOverlay: isOverlay)

        let (initialHost, initialWindow) = initial
        try press("Pinned", in: initialHost)
        try await settle()
        guard let firstField = textField(in: initialHost) else { throw Failure(description: "\(name): search field missing") }
        editQuery("note 02", field: firstField, window: initialWindow, isOverlay: isOverlay)
        try await settle()
        try expect(isRowVisible(CaptureFixture.row(2), host: initialHost),
                   "\(name): query did not reveal the pinned fixture (field: \(firstField.stringValue), visible: \(text(in: initialHost)))")
        try clickText(CaptureFixture.row(2), in: initialHost, window: initialWindow)
        try await settle()
        try press("Copy & close", in: initialHost)
        try await settle()
        try expect(fixture.copied == .text(CaptureFixture.row(2)), "\(name): older pinned selection not established")
        try await dismiss(initialWindow, isOverlay: isOverlay)
        let captured = "Newest captured fixture"
        try await fixture.capture(captured)

        let reopened = try await reopen(panel: panel, hosted: initialHost)
        try await assertLatest(captured, in: reopened, fixture: fixture, isOverlay: isOverlay)
        let (host, window) = reopened
        guard let scroll = scrollView(in: host), let document = scroll.documentView else {
            throw Failure(description: "\(name): scrolling history missing")
        }
        try await scrollFixtureToBottom(scroll, document: document, isOverlay: isOverlay) {
            !isRowVisible(captured, host: host)
        }
        try expect(!isRowVisible(captured, host: host),
                   "\(name): unchanged-ID fixture did not scroll newest out of view (clip: \(scroll.contentView.bounds), document: \(document.frame))")
        try await dismiss(window, isOverlay: isOverlay)
        let unchanged = try await reopen(panel: panel, hosted: initialHost)
        try await assertLatest(captured, in: unchanged, fixture: fixture, isOverlay: isOverlay)

        let (openHost, openWindow) = unchanged
        guard let field = textField(in: openHost), let resultsScroll = scrollView(in: openHost),
              let resultsDocument = resultsScroll.documentView else {
            throw Failure(description: "\(name): browsing fixture unavailable")
        }
        editQuery("Fixture note", field: field, window: openWindow, isOverlay: isOverlay)
        try await settle()
        let oldContent = CaptureFixture.row(2)
        try await scrollFixtureToBottom(resultsScroll, document: resultsDocument, isOverlay: isOverlay) {
            isRowVisible(oldContent, host: openHost)
        }
        if !isOverlay, manualPopover {
            let frame = try textFrame(oldContent, in: openHost)
            let clip = resultsScroll.contentView
            let visible = frame.intersection(openWindow.convertToScreen(clip.convert(clip.bounds, to: nil)))
            try expect(!visible.isEmpty, "Old row has no visible hit target")
            let screenTop = NSScreen.screens[0].frame.maxY
            fputs("ROWCLICK: \(Int(visible.midX)),\(Int(screenTop - visible.midY)) frame=\(frame) visible=\(visible) key=\(openWindow.isKeyWindow)\n", stderr)
            for _ in 0..<100 {
                if !searchHasFocus(field, in: openWindow) { break }
                try await Task.sleep(nanoseconds: 100_000_000)
            }
        } else {
            try clickText(oldContent, in: openHost, window: openWindow)
        }
        try await settle()
        let before = try textFrame(oldContent, in: openHost)
        try expect(isRowVisible(oldContent, host: openHost), "\(name): old selection is not visible")
        try expect(!searchHasFocus(field, in: openWindow), "\(name): old row did not take focus out of search")

        let newest = "Fixture note captured while browsing"
        try await fixture.capture(newest)
        try expect(field.stringValue == "Fixture note", "\(name): capture erased the query")
        try expect(!searchHasFocus(field, in: openWindow), "\(name): capture stole list focus")
        let after = try textFrame(oldContent, in: openHost)
        try expect(abs(before.midY - after.midY) < 1, "\(name): capture moved browsing viewport by \(after.midY - before.midY) points")
        try press("Copy & close", in: openHost)
        try await settle()
        try expect(fixture.copied == .text(oldContent), "\(name): capture changed selected row")
        try press("Jump to latest", in: openHost)
        try await settle()
        try await assertLatest(newest, in: unchanged, fixture: fixture, isOverlay: isOverlay)

        try press("Pinned", in: openHost)
        try await settle()
        let oldPin = CaptureFixture.row(4)
        try await fixture.capture(oldPin)
        try expect(element("Jump to latest", in: openHost) != nil, "\(name): same-ID recopy did not show notice")
        try expect(!text(in: openHost).contains(newest), "\(name): capture changed Pinned to Recent")
        try press("Jump to latest", in: openHost)
        try await settle()
        try await assertLatest(oldPin, in: unchanged, fixture: fixture, isOverlay: isOverlay)
        try await dismiss(openWindow, isOverlay: isOverlay)
        print("PASS: \(name) V1, V2, V4 and V16 summon, unchanged ID, and noninterrupting capture")
    }

    private static func assertLatest(_ content: String, in interface: (NSView, NSWindow),
                                     fixture: CaptureFixture, isOverlay: Bool) async throws {
        let (host, window) = interface
        let name = isOverlay ? "overlay" : "menu-bar popover"
        guard let field = textField(in: host) else { throw Failure(description: "\(name): no search field after summon") }
        try expect(field.stringValue.isEmpty, "\(name): summon kept query \(field.stringValue)")
        try expect(searchHasFocus(field, in: window),
                   "\(name): summon for \(content) did not focus search (key: \(window.isKeyWindow), responder: \(String(describing: window.firstResponder)))")
        try expect(element("Jump to latest", in: host) == nil, "\(name): summon kept stale notice")
        try expect(isRowVisible(content, host: host), "\(name): summon did not reveal \(content)")
        fixture.copied = nil
        try press("Copy & close", in: host)
        try await settle()
        try expect(fixture.copied == .text(content), "\(name): summon selected \(String(describing: fixture.copied)) instead of \(content)")
    }

    private static func scrollFixtureToBottom(_ scroll: NSScrollView, document: NSView, isOverlay: Bool,
                                              until ready: () -> Bool) async throws {
        if !isOverlay, ProcessInfo.processInfo.environment["CLIPASS_CHECK_MANUAL_SCROLL"] == "1" {
            fputs("SCROLL: Scroll down to the bottom of the real popover, without clicking a row.\n", stderr)
            for _ in 0..<1200 {
                if ready() { break }
                try await Task.sleep(nanoseconds: 100_000_000)
            }
        } else {
            scrollToBottom(scroll, document: document)
        }
        try await settle()
    }

    private static func editQuery(_ query: String, field: NSTextField, window: NSWindow, isOverlay: Bool) {
        window.makeFirstResponder(field)
        if !isOverlay, let editor = field.currentEditor() as? NSTextView {
            editor.insertText(query, replacementRange: NSRange(location: 0, length: (editor.string as NSString).length))
        } else {
            setQuery(query, field: field)
        }
    }

    private static func isRowVisible(_ content: String, host: NSView) -> Bool {
        guard let frame = try? textFrame(content, in: host), let clip = scrollView(in: host)?.contentView,
              let window = host.window else { return false }
        return window.convertToScreen(clip.convert(clip.bounds, to: nil)).intersects(frame)
    }

    private static func openRealPopover() async throws -> (NSView, NSWindow) {
        var toggled = false
        if manualPopover {
            fputs("ACTION: Click Clipass T3 in the VM menu bar to open.\n", stderr)
        } else {
            for _ in 0..<20 {
                toggled = ClipboardPopupToggle.toggle()
                if toggled { break }
                try await Task.sleep(nanoseconds: 100_000_000)
            }
        }
        for _ in 0..<(manualPopover ? 1200 : 20) {
            if let window = popoverProbe?.window, window.isVisible,
               let host = window.contentView, textField(in: host) != nil {
                try await settle()
                return (host, window)
            }
            try await Task.sleep(nanoseconds: 100_000_000)
        }
        let windows = NSApp.windows.map { "\($0.className) visible=\($0.isVisible) key=\($0.isKeyWindow) \($0.frame)" }
        let probe = popoverProbe.map { "\($0.window?.className ?? "detached"), \($0.window?.isVisible ?? false)" } ?? "not mounted"
        throw Failure(description: "Could not inspect the real MenuBarExtra window (status button clicked: \(toggled), probe: \(probe), windows: \(windows))")
    }

    private static func reopen(panel: OverlayPanel?, hosted view: NSView) async throws -> (NSView, NSWindow) {
        guard let panel else { return try await openRealPopover() }
        panel.summon()
        try await waitForInterface(view)
        return (view, panel)
    }

    private static func dismiss(_ window: NSWindow, isOverlay: Bool) async throws {
        if isOverlay {
            window.orderOut(nil)
        } else if manualPopover {
            fputs("ACTION: Click Clipass T3 again to close.\n", stderr)
            for _ in 0..<1200 {
                if !window.isVisible { break }
                try await Task.sleep(nanoseconds: 100_000_000)
            }
        } else {
            _ = ClipboardPopupToggle.toggle()
        }
        try await settle()
        try expect(!window.isVisible, "\(isOverlay ? "overlay" : "menu-bar popover"): native window did not dismiss")
    }
}
