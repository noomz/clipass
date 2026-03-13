import SwiftUI
import AppKit

/// NSViewRepresentable wrapper for NSVisualEffectView.
/// Provides frosted glass vibrancy background for the overlay panel.
///
/// IMPORTANT: `state = .active` is required for apps using `.accessory` activation policy.
/// Without it, the blur renders as flat gray because NSVisualEffectView defaults to
/// `.followsWindowActiveState` which is always inactive under .accessory policy.
struct VisualEffectView: NSViewRepresentable {

    var material: NSVisualEffectView.Material
    var blendingMode: NSVisualEffectView.BlendingMode

    init(
        material: NSVisualEffectView.Material = .hudWindow,
        blendingMode: NSVisualEffectView.BlendingMode = .behindWindow
    ) {
        self.material = material
        self.blendingMode = blendingMode
    }

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        // CRITICAL: Must be set to .active for .accessory activation policy apps.
        // Under .accessory policy the window is never "active" in AppKit's sense,
        // so the default .followsWindowActiveState produces flat gray — not blur.
        view.state = .active
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
    }
}
