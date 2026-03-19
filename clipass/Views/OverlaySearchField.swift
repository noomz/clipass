import AppKit
import SwiftUI

// MARK: - OverlaySearchField

/// NSViewRepresentable wrapper around a custom NSTextField subclass.
///
/// Solves three known issues with SwiftUI TextField inside a non-activating NSPanel:
///   1. Auto-focus: requests first-responder status as soon as the field's window is available.
///   2. Arrow key navigation: intercepts ↑ / ↓ and calls `onArrowUp` / `onArrowDown` so the
///      parent view can update the List selection without SwiftUI ever receiving the key event.
///   3. ESC dismissal: intercepts Escape and calls `onEscape` because `.onKeyPress(.escape)` on
///      a List view does not fire when the search field holds first-responder status.
///
/// Theme colors are applied in both `makeNSView` and `updateNSView` so initial state
/// and subsequent theme changes both render correctly.
struct OverlaySearchField: NSViewRepresentable {

    @Binding var text: String
    var placeholder: String = "Search clipboard..."
    var theme: Theme
    var shouldRefocus: Bool = true  // when true, re-requests first-responder on next update
    var onArrowUp: () -> Void = {}
    var onArrowDown: () -> Void = {}
    var onEscape: () -> Void = {}
    var onReturn: () -> Void = {}

    // MARK: NSViewRepresentable

    func makeNSView(context: Context) -> InterceptingTextField {
        let field = InterceptingTextField()
        field.delegate = context.coordinator
        field.isBordered = false
        field.focusRingType = .none
        field.cell?.wraps = false
        field.cell?.isScrollable = true
        field.stringValue = text
        field.onArrowUp = onArrowUp
        field.onArrowDown = onArrowDown
        field.onEscape = onEscape
        field.onReturn = onReturn

        // Apply initial theme styling
        applyTheme(to: field)

        // Request first-responder status once the view is installed in a window.
        // Using asyncAfter(0) defers until the runloop tick after the hosting view
        // has been inserted into the NSPanel's view hierarchy.
        DispatchQueue.main.async {
            field.window?.makeFirstResponder(field)
        }

        return field
    }

    func updateNSView(_ nsView: InterceptingTextField, context: Context) {
        // Sync text only when changed externally (avoid caret-jump during typing).
        if nsView.stringValue != text {
            nsView.stringValue = text
        }

        // Always keep callbacks current (closures capture latest state).
        nsView.onArrowUp = onArrowUp
        nsView.onArrowDown = onArrowDown
        nsView.onEscape = onEscape
        nsView.onReturn = onReturn

        // Re-apply theme colors on every update so theme changes take effect immediately.
        applyTheme(to: nsView)

        // Restore focus to the search field when transitioning from editing back to normal mode.
        // Only re-request first-responder when shouldRefocus is true and the field doesn't already hold it.
        if shouldRefocus {
            DispatchQueue.main.async {
                guard let window = nsView.window else { return }
                let isFirstResponder = window.firstResponder == nsView.currentEditor()
                    || window.firstResponder == nsView
                if !isFirstResponder {
                    window.makeFirstResponder(nsView)
                }
            }
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    // MARK: Theme Application

    private func applyTheme(to nsView: NSTextField) {
        nsView.textColor = NSColor(theme.searchFieldText)
        nsView.font = NSFont.systemFont(ofSize: theme.bodyFontSize)

        // Placeholder with themed color
        let placeholderAttributes: [NSAttributedString.Key: Any] = [
            .foregroundColor: NSColor(theme.searchFieldPlaceholder),
            .font: NSFont.systemFont(ofSize: theme.bodyFontSize)
        ]
        nsView.placeholderAttributedString = NSAttributedString(
            string: placeholder,
            attributes: placeholderAttributes
        )

        // Never use NSTextField drawsBackground — the search field background
        // is rendered as a SwiftUI shape in ClipboardOverlayView instead.
        nsView.drawsBackground = false
        nsView.backgroundColor = .clear
    }

    // MARK: Coordinator

    final class Coordinator: NSObject, NSTextFieldDelegate {
        var parent: OverlaySearchField

        init(_ parent: OverlaySearchField) {
            self.parent = parent
        }

        func controlTextDidChange(_ obj: Notification) {
            guard let field = obj.object as? NSTextField else { return }
            parent.text = field.stringValue
        }

        /// Intercept key commands from the field editor (NSTextView) that handles
        /// input while the text field is being edited. Without this, arrow keys,
        /// ESC, and Return are consumed by the field editor and never reach
        /// InterceptingTextField.keyDown.
        func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
            switch commandSelector {
            case #selector(NSResponder.moveDown(_:)):
                parent.onArrowDown()
                return true
            case #selector(NSResponder.moveUp(_:)):
                parent.onArrowUp()
                return true
            case #selector(NSResponder.cancelOperation(_:)):
                parent.onEscape()
                return true
            case #selector(NSResponder.insertNewline(_:)):
                parent.onReturn()
                return true
            default:
                return false
            }
        }
    }
}

// MARK: - InterceptingTextField

/// NSTextField subclass that intercepts arrow keys and ESC before SwiftUI sees them.
final class InterceptingTextField: NSTextField {

    var onArrowUp: () -> Void = {}
    var onArrowDown: () -> Void = {}
    var onEscape: () -> Void = {}
    var onReturn: () -> Void = {}

    override func keyDown(with event: NSEvent) {
        switch event.keyCode {
        case 125: // ↓ Down Arrow
            onArrowDown()
        case 126: // ↑ Up Arrow
            onArrowUp()
        case 53:  // Escape
            onEscape()
        case 36:  // Return
            onReturn()
        default:
            super.keyDown(with: event)
        }
    }
}
