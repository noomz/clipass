import AppKit
import SwiftUI

struct ClipboardBrowserShortcut {
    typealias Action = ClipboardBrowserState.Action

    let key: String
    let title: String
    let symbols: String
    var modifiers: NSEvent.ModifierFlags = []
    var action: Action
    var focus: ClipboardBrowserState.Focus?

    static let keymap: [Self] = [
        .init(key: "1", title: "Open Recent", symbols: "⌘1", modifiers: .command, action: .openTab(.recent)),
        .init(key: "2", title: "Open Pinned", symbols: "⌘2", modifiers: .command, action: .openTab(.pinned)),
        .init(key: "{", title: "Previous tab", symbols: "⌘⇧[", modifiers: [.command, .shift], action: .cycleTab),
        .init(key: "}", title: "Next tab", symbols: "⌘⇧]", modifiers: [.command, .shift], action: .cycleTab),
        .init(key: "\u{F700}", title: "Previous result", symbols: "↑", action: .navigate(.previous), focus: .list),
        .init(key: "\u{F701}", title: "Next result", symbols: "↓", action: .navigate(.next), focus: .list),
        .init(key: "\u{F701}", title: "Enter results from search", symbols: "↓", action: .enterResults, focus: .search),
        .init(key: "\u{F700}", title: "First result", symbols: "⌘↑", modifiers: .command, action: .navigate(.first), focus: .list),
        .init(key: "\u{F701}", title: "Last result", symbols: "⌘↓", modifiers: .command, action: .navigate(.last), focus: .list),
        .init(key: "\u{F729}", title: "First result", symbols: "Home", action: .navigate(.first), focus: .list),
        .init(key: "\u{F72B}", title: "Last result", symbols: "End", action: .navigate(.last), focus: .list),
        .init(key: "f", title: "Select search text", symbols: "⌘F", modifiers: .command, action: .focusSearch),
        .init(key: " ", title: "Toggle preview from results or preview", symbols: "Space", action: .togglePreview),
        .init(key: "p", title: "Toggle preview", symbols: "⌘P", modifiers: .command, action: .togglePreview),
        .init(key: "\u{1B}", title: "Back one layer", symbols: "Esc", action: .back),
        .init(key: "\r", title: "Copy & close", symbols: "↵", action: .copyAndClose),
        .init(key: "/", title: "Shortcut help", symbols: "⌘/", modifiers: .command, action: .toggleHelp)
    ]

    static func match(_ event: NSEvent, focus: ClipboardBrowserState.Focus) -> Self? {
        let modifiers = event.modifierFlags.intersection([.command, .shift, .option, .control])
        let key = switch event.charactersIgnoringModifiers?.lowercased() {
        case "[" where modifiers.contains(.shift): "{"
        case "]" where modifiers.contains(.shift): "}"
        default: event.charactersIgnoringModifiers?.lowercased()
        }
        return keymap.first {
            $0.key == key && $0.modifiers == modifiers && ($0.focus == nil || $0.focus == focus)
                && (key != " " || focus == .list || focus == .preview)
        }
    }
}

struct ClipboardBrowserKeyboard: NSViewRepresentable {
    var focus: ClipboardBrowserState.Focus
    var action: (ClipboardBrowserState.Action, ClipboardBrowserState.Focus) -> Bool

    func makeNSView(context: Context) -> Probe { Probe() }

    func updateNSView(_ probe: Probe, context: Context) {
        probe.focus = focus
        probe.action = action
    }

    static func dismantleNSView(_ probe: Probe, coordinator: ()) {
        probe.stopMonitoring()
    }

    final class Probe: NSView {
        var focus: ClipboardBrowserState.Focus = .control
        var action: (ClipboardBrowserState.Action, ClipboardBrowserState.Focus) -> Bool = { _, _ in false }
        private var monitor: Any?

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            stopMonitoring()
            guard window != nil else { return }
            monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
                guard let self else { return event }
                return self.route(event)
            }
        }

        override func hitTest(_ point: NSPoint) -> NSView? { nil }

        func stopMonitoring() {
            if let monitor { NSEvent.removeMonitor(monitor) }
            monitor = nil
        }

        private func route(_ event: NSEvent) -> NSEvent? {
            guard let window, window.isKeyWindow, window.isVisible, event.window === window,
                  !isHiddenOrHasHiddenAncestor,
                  (window.firstResponder as? NSTextInputClient)?.hasMarkedText() != true else { return event }
            let actualFocus: ClipboardBrowserState.Focus = ClipboardBrowserTextField.hasFocus(in: window) ? .search : focus
            guard let shortcut = ClipboardBrowserShortcut.match(event, focus: actualFocus) else { return event }
            if event.isARepeat && [.back, .toggleHelp, .togglePreview].contains(shortcut.action) {
                return nil
            }
            return action(shortcut.action, actualFocus) ? nil : event
        }
    }
}
