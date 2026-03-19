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
        let textView = NSTextView()

        textView.delegate = context.coordinator

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
            if commandSelector == #selector(NSResponder.insertNewline(_:)) {
                // Cmd+Return = save; bare Return = newline insertion
                if NSApp.currentEvent?.modifierFlags.contains(.command) == true {
                    parent.onCommit()
                    return true
                }
                return false    // let NSTextView insert a newline
            }
            if commandSelector == #selector(NSResponder.cancelOperation(_:)) {
                parent.onCancel()
                return true
            }
            return false
        }
    }
}
