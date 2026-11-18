import AppKit

extension NativeBrowserChecks {
    static func exerciseKeyboard(isOverlay: Bool) async throws {
        let name = isOverlay ? "overlay" : "hosted popover"
        let fixture = try CaptureFixture()
        let (host, window) = showInterface(isOverlay: isOverlay, context: fixture.context, monitor: fixture.monitor) {
            fixture.copied = $0
        }
        defer { window.close() }
        try await waitForInterface(host)
        guard let field = textField(in: host) else { throw Failure(description: "\(name): search field missing") }
        try expect(window.isKeyWindow && searchHasFocus(field, in: window), "\(name): cannot test keyboard without search focus")

        try await key("n", code: 45, in: window)
        try await key("o", code: 31, in: window)
        try await key("t", code: 17, in: window)
        try await key("e", code: 14, in: window)
        try await key(" ", code: 49, in: window)
        try await key("0", code: 29, in: window)
        try expect(field.stringValue == "note 0", "\(name): search did not accept typed text with a space (got \(field.stringValue))")

        try await key("2", code: 19, modifiers: .command, in: window)
        try expect(field.stringValue == "note 0" && searchHasFocus(field, in: window), "\(name): ⌘2 changed query or focus")
        try expect(!text(in: host).contains(CaptureFixture.row(9)), "\(name): ⌘2 did not switch to Pinned")
        try await key("\u{F701}", code: 125, in: window)
        try expect(!searchHasFocus(field, in: window), "\(name): ↓ did not focus results")
        try await key("\u{F701}", code: 125, modifiers: .command, in: window)
        try await key("\u{F701}", code: 125, in: window)
        let copyLabel = "Copy & close"
        try press(copyLabel, in: host)
        try await settle()
        try expect(fixture.copied == CaptureFixture.row(2), "\(name): ⌘↓ or clamped ↓ did not keep the last filtered pin")
        guard let clip = scrollView(in: host)?.contentView else { throw Failure(description: "\(name): missing result viewport") }
        let viewport = window.convertToScreen(clip.convert(clip.bounds, to: nil))
        let lastRow = try textFrame(CaptureFixture.row(2), in: host)
        try expect(lastRow.intersects(viewport),
                   "\(name): last selected row was not revealed")
        try await key("\u{F729}", code: 115, in: window)
        try await key("\u{F700}", code: 126, in: window)
        try press(copyLabel, in: host)
        try await settle()
        try expect(fixture.copied == CaptureFixture.row(8), "\(name): Home or clamped ↑ did not keep the first filtered pin")

        try await key("}", code: 30, modifiers: [.command, .shift], in: window)
        try expect(text(in: host).contains(CaptureFixture.row(9)) && !searchHasFocus(field, in: window),
                   "\(name): cycling tabs did not keep query and list focus")
        try await key("f", code: 3, modifiers: .command, in: window)
        guard let editor = field.currentEditor() as? NSTextView else { throw Failure(description: "\(name): no focused field editor") }
        try expect(searchHasFocus(field, in: window) && field.stringValue == "note 0" &&
                   editor.selectedRange() == NSRange(location: 0, length: 6), "\(name): ⌘F did not select the existing query")
        editor.setMarkedText("x", selectedRange: NSRange(location: 1, length: 0), replacementRange: editor.selectedRange())
        try expect(editor.hasMarkedText(), "\(name): could not start marked-text composition")
        try await key("/", code: 44, modifiers: .command, in: window)
        try expect(!text(in: host).contains("Keyboard shortcuts"), "\(name): shortcut intercepted marked-text composition")
        editor.unmarkText()
        editor.insertText("note 0", replacementRange: NSRange(location: 0, length: (editor.string as NSString).length))
        try await settle()

        let other = CheckPopoverWindow(contentRect: NSRect(x: 0, y: 0, width: 120, height: 80),
                                       styleMask: [.borderless], backing: .buffered, defer: false)
        other.isReleasedWhenClosed = false
        other.makeKeyAndOrderFront(nil)
        defer { other.close() }
        try await settle()
        try expect(other.isKeyWindow && window.isVisible, "\(name): could not create an inactive browser for the shortcut test")
        try await key("/", code: 44, modifiers: .command, in: window)
        try expect(!text(in: host).contains("Keyboard shortcuts"), "\(name): inactive browser handled ⌘/")
        other.orderOut(nil)
        window.makeKeyAndOrderFront(nil)
        try await settle()

        try await key("/", code: 44, modifiers: .command, in: window)
        try expect(text(in: host).contains("Keyboard shortcuts"), "\(name): ⌘/ did not open help")
        try expect(text(in: host).contains("Back one layer"), "\(name): help did not show keymap")
        fixture.copied = nil
        try await key("\r", code: 36, in: window)
        try expect(fixture.copied == nil && !text(in: host).contains("Keyboard shortcuts"),
                   "\(name): Return did not activate Close on help independently of Copy")
        try await key("/", code: 44, modifiers: .command, in: window)
        try await key("\u{1B}", code: 53, in: window)
        try expect(window.isVisible && field.stringValue == "note 0" && searchHasFocus(field, in: window) &&
                   !text(in: host).contains("Keyboard shortcuts"), "\(name): first Escape should only close help and restore search")
        try await key("\u{1B}", code: 53, repeatKey: true, in: window)
        try expect(field.stringValue == "note 0", "\(name): holding Escape cleared a second layer")
        try await key("\u{1B}", code: 53, in: window)
        try expect(window.isVisible && field.stringValue.isEmpty, "\(name): second Escape did not clear only search")
        try await key("\r", code: 36, in: window)
        try expect(fixture.copied == CaptureFixture.row(40), "\(name): Return in search did not copy the selected item")
        try await key("\u{1B}", code: 53, in: window)
        try expect(!window.isVisible, "\(name): Escape did not dismiss the browser")
        print("PASS: \(name) keyboard routing, native text editing, row reveal, and layered Escape")
    }

    static func key(_ characters: String, code: UInt16, modifiers: NSEvent.ModifierFlags = [],
                            repeatKey: Bool = false, in window: NSWindow) async throws {
        guard let event = NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: modifiers,
                                          timestamp: ProcessInfo.processInfo.systemUptime, windowNumber: window.windowNumber,
                                          context: nil, characters: characters, charactersIgnoringModifiers: characters,
                                          isARepeat: repeatKey, keyCode: code) else {
            throw Failure(description: "Could not create native key event \(code)")
        }
        NSApp.postEvent(event, atStart: false)
        try await settle()
    }
}
