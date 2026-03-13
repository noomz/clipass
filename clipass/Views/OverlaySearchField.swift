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
struct OverlaySearchField: NSViewRepresentable {

    @Binding var text: String
    var placeholder: String = "Search clipboard..."
    var onArrowUp: () -> Void = {}
    var onArrowDown: () -> Void = {}
    var onEscape: () -> Void = {}
    var onReturn: () -> Void = {}

    // MARK: NSViewRepresentable

    func makeNSView(context: Context) -> InterceptingTextField {
        let field = InterceptingTextField()
        field.delegate = context.coordinator
        field.placeholderString = placeholder
        field.isBordered = false
        field.drawsBackground = false
        field.focusRingType = .none
        field.font = NSFont.systemFont(ofSize: NSFont.systemFontSize)
        field.cell?.wraps = false
        field.cell?.isScrollable = true
        field.stringValue = text
        field.onArrowUp = onArrowUp
        field.onArrowDown = onArrowDown
        field.onEscape = onEscape
        field.onReturn = onReturn

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
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
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
