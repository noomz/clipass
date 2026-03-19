import AppKit
import SwiftUI

/// NSTextView-backed NSViewRepresentable for multi-line monospace editing in a non-activating NSPanel.
///
/// Uses the same NSViewRepresentable + makeFirstResponder pattern as OverlaySearchField
/// because @FocusState is unreliable in non-activating NSPanel (Phase 12 decision).
/// NSTextView handles multi-line content, scrolling, undo/redo, and cursor management natively.
struct EditorTextView: NSViewRepresentable {

    @Binding var text: String
    var theme: Theme
    var isActive: Bool      // when true, requests first-responder focus and moves cursor to end
    var onCommit: () -> Void    // called on Cmd+Return
    var onCancel: () -> Void    // called on ESC

    // MARK: NSViewRepresentable

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        let textView = EditorNSTextView()

        textView.delegate = context.coordinator
        let coordinator = context.coordinator
        textView.onCommit = { coordinator.parent.onCommit() }

        // Text editing configuration
        textView.isEditable = true
        textView.isRichText = false
        textView.allowsUndo = true
        textView.font = NSFont.monospacedSystemFont(ofSize: NSFont.systemFontSize, weight: .regular)

        // Vertical growth — NSTextView must be set up to expand vertically and track width
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
        textView.textContainer?.widthTracksTextView = true
        textView.textContainer?.containerSize = NSSize(
            width: CGFloat.greatestFiniteMagnitude,
            height: CGFloat.greatestFiniteMagnitude
        )

        // Background: let the SwiftUI container handle it (same as OverlaySearchField)
        textView.drawsBackground = false

        // Scroll view setup
        scrollView.documentView = textView
        scrollView.hasVerticalScroller = true
        scrollView.drawsBackground = false
        scrollView.autohidesScrollers = true

        // Line number gutter
        let gutterView = LineNumberGutterView(textView: textView)
        scrollView.verticalRulerView = gutterView
        scrollView.hasVerticalRuler = true
        scrollView.rulersVisible = true

        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? NSTextView else { return }

        // Sync text only when changed externally to avoid caret-jump during typing
        if textView.string != text {
            textView.string = text
        }

        // Apply theme colors
        textView.textColor = NSColor(theme.primaryText)
        textView.insertionPointColor = NSColor(theme.accentColor)
        textView.selectedTextAttributes = [
            .backgroundColor: NSColor(theme.itemBackground).withAlphaComponent(0.4)
        ]

        // Keep coordinator callbacks current (closures capture latest state)
        context.coordinator.parent = self
        (textView as? EditorNSTextView)?.onCommit = {
            context.coordinator.parent.onCommit()
        }

        // Focus: when isActive is true, request first-responder and move cursor to end.
        // Must use DispatchQueue.main.async — same pattern as OverlaySearchField — because
        // makeFirstResponder must be called after the view is in the window hierarchy.
        if isActive {
            DispatchQueue.main.async {
                guard let window = textView.window else { return }
                if window.firstResponder != textView {
                    window.makeFirstResponder(textView)
                }
                // Move cursor to end of content
                let length = (textView.string as NSString).length
                textView.setSelectedRange(NSRange(location: length, length: 0))
            }
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    // MARK: Coordinator

    final class Coordinator: NSObject, NSTextViewDelegate {
        var parent: EditorTextView

        init(_ parent: EditorTextView) {
            self.parent = parent
        }

        func textDidChange(_ notification: Notification) {
            guard let tv = notification.object as? NSTextView else { return }
            parent.text = tv.string
        }

        /// Intercept Cmd+Return (commit) and ESC (cancel) from the editor.
        /// Bare Return inserts a newline (returns false to let NSTextView handle it).
        func textView(_ textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
            if commandSelector == #selector(NSResponder.cancelOperation(_:)) {
                // Defer to next runloop — calling onCancel synchronously removes the
                // EditorTextView from the hierarchy while this delegate is on the stack.
                DispatchQueue.main.async { [weak self] in self?.parent.onCancel() }
                return true
            }
            return false
        }
    }
}

// MARK: - EditorNSTextView

/// NSTextView subclass that intercepts Cmd+Return via keyDown.
/// The doCommandBy delegate doesn't reliably receive Cmd+Return
/// in non-activating panels, so we catch it at the keyDown level.
final class EditorNSTextView: NSTextView {

    /// Set by EditorTextView.Coordinator to call back into SwiftUI.
    var onCommit: (() -> Void)?

    override func keyDown(with event: NSEvent) {
        // Cmd+Return → commit edit
        if event.modifierFlags.contains(.command) && event.keyCode == 36 {
            DispatchQueue.main.async { [weak self] in self?.onCommit?() }
            return
        }
        super.keyDown(with: event)
    }
}

// MARK: - Line Number Gutter

/// Draws line numbers in the vertical ruler area of the scroll view.
final class LineNumberGutterView: NSRulerView {

    private weak var textView: NSTextView?
    private let gutterWidth: CGFloat = 36

    init(textView: NSTextView) {
        self.textView = textView
        super.init(scrollView: textView.enclosingScrollView, orientation: .verticalRuler)
        self.ruleThickness = gutterWidth
        self.clientView = textView
        self.clipsToBounds = true

        NotificationCenter.default.addObserver(
            self, selector: #selector(textDidChange(_:)),
            name: NSText.didChangeNotification, object: textView
        )
        NotificationCenter.default.addObserver(
            self, selector: #selector(boundsDidChange(_:)),
            name: NSView.boundsDidChangeNotification,
            object: textView.enclosingScrollView?.contentView
        )
    }

    @available(*, unavailable)
    required init(coder: NSCoder) { fatalError() }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    @objc private func textDidChange(_ note: Notification) { needsDisplay = true }
    @objc private func boundsDidChange(_ note: Notification) { needsDisplay = true }

    override func drawHashMarksAndLabels(in rect: NSRect) {
        guard let textView = textView,
              textView.window != nil,
              let layoutManager = textView.layoutManager,
              let textContainer = textView.textContainer else { return }

        let text = textView.string as NSString
        guard text.length > 0 else { return }

        // Ensure layout is complete before querying glyph positions
        layoutManager.ensureLayout(for: textContainer)

        let visibleRect = scrollView?.contentView.bounds ?? rect
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedDigitSystemFont(ofSize: NSFont.smallSystemFontSize, weight: .regular),
            .foregroundColor: NSColor.secondaryLabelColor
        ]

        let totalGlyphs = layoutManager.numberOfGlyphs
        guard totalGlyphs > 0 else { return }

        let glyphRange = layoutManager.glyphRange(forBoundingRect: visibleRect, in: textContainer)
        guard glyphRange.location != NSNotFound else { return }
        let charRange = layoutManager.characterRange(forGlyphRange: glyphRange, actualGlyphRange: nil)
        guard charRange.location != NSNotFound, charRange.location < text.length else { return }

        // Walk each line fragment in the visible range
        let prefix = charRange.location > 0 ? text.substring(to: charRange.location) : ""
        var lineNumber = prefix.components(separatedBy: "\n").count
        var index = charRange.location

        while index < text.length && index <= NSMaxRange(charRange) {
            let lineRange = text.lineRange(for: NSRange(location: index, length: 0))
            guard lineRange.location != NSNotFound, lineRange.length > 0 else { break }

            let glyphIdx = layoutManager.glyphIndexForCharacter(at: lineRange.location)
            guard glyphIdx < totalGlyphs else { break }

            var lineRect = layoutManager.lineFragmentRect(forGlyphAt: glyphIdx, effectiveRange: nil)
            lineRect.origin.y -= visibleRect.origin.y

            let numStr = "\(lineNumber)" as NSString
            let size = numStr.size(withAttributes: attrs)
            let drawPoint = NSPoint(
                x: gutterWidth - size.width - 6,
                y: lineRect.origin.y + (lineRect.height - size.height) / 2
            )
            numStr.draw(at: drawPoint, withAttributes: attrs)

            lineNumber += 1
            let nextIndex = NSMaxRange(lineRange)
            if nextIndex <= index { break }  // safety: no progress
            index = nextIndex
        }
    }
}
