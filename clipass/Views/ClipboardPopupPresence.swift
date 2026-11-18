import AppKit
import SwiftUI

struct ClipboardPopupPresence: NSViewRepresentable {
    let onVisibilityChange: (Bool) -> Void

    func makeNSView(context: Context) -> WindowProbe {
        let probe = WindowProbe()
        probe.onVisibilityChange = onVisibilityChange
        return probe
    }

    func updateNSView(_ probe: WindowProbe, context: Context) {
        probe.onVisibilityChange = onVisibilityChange
    }

    final class WindowProbe: NSView {
        var onVisibilityChange: (Bool) -> Void = { _ in }
        private var wasVisible = false

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            let center = NotificationCenter.default
            center.removeObserver(self)
            if let window {
                for name in [NSWindow.didBecomeKeyNotification, NSWindow.didResignKeyNotification,
                             NSWindow.didChangeOcclusionStateNotification, NSWindow.willCloseNotification] {
                    center.addObserver(self, selector: #selector(checkVisibility), name: name, object: window)
                }
            }
            checkVisibility()
        }

        override func viewDidHide() { checkVisibility() }
        override func viewDidUnhide() { checkVisibility() }

        @objc private func checkVisibility() {
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                let visible = window?.isVisible == true && !isHiddenOrHasHiddenAncestor
                guard visible != wasVisible else { return }
                wasVisible = visible
                onVisibilityChange(visible)
            }
        }
    }
}
