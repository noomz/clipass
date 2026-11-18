import AppKit
import SwiftUI

struct ClipboardBrowserSearchField: NSViewRepresentable {
    struct FocusRequest: Equatable {
        enum Intent { case focus, selectAll, resign }

        private let id = UUID()
        var intent: Intent = .focus
    }

    @Environment(\.isEnabled) private var isEnabled
    @Binding var text: String
    var textColor: Color
    var placeholderColor: Color
    var fontSize: CGFloat
    var focusRequest: FocusRequest
    var onFocusChange: (Bool) -> Void

    func makeNSView(context: Context) -> ClipboardBrowserTextField {
        let field = ClipboardBrowserTextField()
        field.delegate = context.coordinator
        field.isBordered = false
        field.focusRingType = .none
        field.drawsBackground = false
        field.setAccessibilityLabel("Search clipboard")
        field.cell?.wraps = false
        field.cell?.isScrollable = true
        return field
    }

    func updateNSView(_ field: ClipboardBrowserTextField, context: Context) {
        context.coordinator.parent = self
        field.isEnabled = isEnabled
        if field.stringValue != text { field.stringValue = text }
        field.textColor = NSColor(textColor)
        field.font = NSFont.systemFont(ofSize: fontSize)
        field.placeholderAttributedString = NSAttributedString(
            string: "Text or tag:work", attributes: [.foregroundColor: NSColor(placeholderColor)]
        )
        field.onFocusChange = onFocusChange
        if field.request != focusRequest {
            field.request = focusRequest
            field.applyFocusRequest()
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject, NSTextFieldDelegate {
        var parent: ClipboardBrowserSearchField

        init(_ parent: ClipboardBrowserSearchField) { self.parent = parent }

        func controlTextDidBeginEditing(_ notification: Notification) {
            (notification.object as? ClipboardBrowserTextField)?.reportFocus()
        }

        func controlTextDidEndEditing(_ notification: Notification) {
            (notification.object as? ClipboardBrowserTextField)?.reportFocus()
        }

        func controlTextDidChange(_ notification: Notification) {
            guard let field = notification.object as? NSTextField else { return }
            parent.text = field.stringValue
        }
    }
}

final class ClipboardBrowserTextField: NSTextField {
    var request: ClipboardBrowserSearchField.FocusRequest?
    private var appliedRequest: ClipboardBrowserSearchField.FocusRequest?
    var onFocusChange: (Bool) -> Void = { _ in }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        applyFocusRequest()
    }

    override func becomeFirstResponder() -> Bool {
        let accepted = super.becomeFirstResponder()
        if accepted { reportFocus() }
        return accepted
    }

    override func resignFirstResponder() -> Bool {
        let accepted = super.resignFirstResponder()
        if accepted { reportFocus() }
        return accepted
    }

    func applyFocusRequest() {
        guard let request else { return }
        DispatchQueue.main.async { [weak self] in
            guard let self, self.request == request, appliedRequest != request, let window, isEnabled else { return }
            appliedRequest = request
            switch request.intent {
            case .focus:
                if !hasFocus(in: window) { window.makeFirstResponder(self) }
            case .selectAll:
                selectText(nil)
            case .resign:
                if hasFocus(in: window) { window.makeFirstResponder(nil) }
            }
        }
    }

    func reportFocus() {
        DispatchQueue.main.async { [weak self] in
            guard let self, let window else { return }
            onFocusChange(hasFocus(in: window))
        }
    }

    private func hasFocus(in window: NSWindow) -> Bool {
        guard let responder = window.firstResponder else { return false }
        return responder === self || responder === currentEditor()
    }

    static func hasFocus(in window: NSWindow) -> Bool {
        func containsFocusedSearch(_ view: NSView) -> Bool {
            if let field = view as? ClipboardBrowserTextField { return field.hasFocus(in: window) }
            return view.subviews.contains(where: containsFocusedSearch)
        }
        return window.contentView.map(containsFocusedSearch) ?? false
    }
}
