import AppKit

extension NativeBrowserChecks {
    static func exercisePreview(isOverlay: Bool) async throws {
        let name = isOverlay ? "overlay" : "hosted popover"
        let fixture = try CaptureFixture()
        let tag = Tag(name: "Inspection")
        let tail = "Last preview line"
        let raw = "Fixture token-123456 multiline\n" + String(repeating: "A long line of JSON text\n", count: 60) + tail
        let item = ClipboardItem(content: raw, sourceApp: "com.apple.finder", timestamp: Date(timeIntervalSince1970: 1.5))
        fixture.context.insert(tag)
        fixture.context.insert(item)
        item.tags.append(tag)
        fixture.context.insert(RedactionPattern(name: "Test", pattern: #"token-\d+"#,
                                                category: RedactionPattern.categoryCustom))
        try fixture.context.save()

        let suite = "clipass-preview-\(UUID())"
        guard let defaults = UserDefaults(suiteName: suite) else { throw Failure(description: "Missing test defaults") }
        defaults.set(22, forKey: "previewMaxLength")
        defer { defaults.removePersistentDomain(forName: suite) }
        let (host, window) = showInterface(isOverlay: isOverlay, context: fixture.context, monitor: fixture.monitor,
                                           closesOnCopy: true, defaults: defaults) { fixture.copied = $0 }
        defer { window.close() }
        try await waitForInterface(host)
        guard let field = textField(in: host), let list = scrollView(in: host), let document = list.documentView else {
            throw Failure(description: "\(name): history list missing")
        }
        try await key("p", code: 35, modifiers: .command, in: window)
        try expect(element("History", in: host) != nil, "\(name): ⌘P did not open preview from search")
        try await key(" ", code: 49, in: window)
        try expect(element("History", in: host) == nil, "\(name): Space did not close preview")
        window.makeFirstResponder(field)
        setQuery("Fixture", field: field)
        try await settle()
        scrollToBottom(list, document: document)
        try await settle()

        let row = "Fixture *** multiline..."
        try expect(text(in: host).contains(row) && !text(in: host).contains("token-123456"),
                   "\(name): row did not use configured length and redaction: \(text(in: host))")
        try clickText(row, in: host, window: window)
        try await settle()
        let viewport = list.contentView.bounds.origin
        try clickText("Preview selected item", in: host, window: window)
        try await settle()
        let shown = text(in: host)
        try expect(shown.contains("Fixture *** multiline\n") && shown.contains(tail) && !shown.contains("token-123456"),
                   "\(name): preview did not expose full masked multiline text")
        try expect(shown.contains("Finder") && shown.contains("#Inspection"), "\(name): preview metadata missing")
        guard let preview = scrollViews(in: host).first(where: { $0 !== list && $0.documentView != nil }),
              let previewDocument = preview.documentView else { throw Failure(description: "\(name): preview is not scrollable") }
        let initial = preview.contentView.bounds.origin
        try await key("\u{F701}", code: 125, in: window)
        try expect(element("History", in: host) != nil && !searchHasFocus(field, in: window) && fixture.copied == nil,
                   "\(name): ↓ left the preview, focused search, or copied while scrolling")
        scrollToBottom(preview, document: previewDocument)
        try await settle()
        try expect(preview.contentView.bounds.origin != initial, "\(name): preview cannot scroll to its end")

        try await key("/", code: 44, modifiers: .command, in: window)
        try expect(text(in: host).contains("Keyboard shortcuts"),
                   "\(name): ⌘/ did not open help above preview (key: \(window.isKeyWindow))")
        try await key("\u{1B}", code: 53, in: window)
        try expect(element("History", in: host) != nil && !text(in: host).contains("Keyboard shortcuts"),
                   "\(name): Escape did not reveal preview beneath help (key: \(window.isKeyWindow), visible: \(window.isVisible), AX: \(text(in: host).prefix(400)))")
        try await key("\u{1B}", code: 53, in: window)
        try expect(list.contentView.bounds.origin == viewport && field.stringValue == "Fixture" && window.isVisible,
                   "\(name): preview close changed the list viewport, query, or window")
        try await key(" ", code: 49, in: window)
        try expect(element("History", in: host) != nil, "\(name): preview close did not restore Space on the selected list row")
        try await key("\r", code: 36, in: window)
        try expect(fixture.copied == .text(raw) && !window.isVisible, "\(name): Return in preview did not copy original and close")
        print("PASS: \(name) V9, V11, V12: preview, redaction, scroll restoration, and original Copy & close")
    }

    private static func scrollViews(in root: NSView) -> [NSScrollView] {
        (root as? NSScrollView).map { [$0] } ?? root.subviews.flatMap { scrollViews(in: $0) }
    }
}
