import SwiftUI
import AppKit

/// NSViewRepresentable wrapper that renders an overlay background according to
/// the theme's BackgroundMode. Supports three rendering paths:
///
/// - `.vibrancy(material)`: NSVisualEffectView with the given material.
/// - `.tintedVibrancy(material, tint, opacity)`: NSVisualEffectView with a
///   semi-transparent tint Color layer on top.
/// - `.solid`: Plain NSView with a solid background color.
///
/// CRITICAL: `state = .active` is required for apps using `.accessory` activation
/// policy. Without it the blur renders as flat gray because the default state
/// `.followsWindowActiveState` is always inactive under .accessory policy.
/// This must be set in both makeNSView AND updateNSView (Pitfall 5).
struct VisualEffectView: NSViewRepresentable {

    var backgroundMode: BackgroundMode
    var forceAppearance: NSAppearance?

    /// Solid-mode background color. Passed separately to avoid bridging Color → NSColor
    /// on every SwiftUI update cycle unnecessarily.
    var solidColor: NSColor?

    init(
        backgroundMode: BackgroundMode = .vibrancy(material: .hudWindow),
        forceAppearance: NSAppearance? = nil,
        solidColor: NSColor? = nil
    ) {
        self.backgroundMode = backgroundMode
        self.forceAppearance = forceAppearance
        self.solidColor = solidColor
    }

    // MARK: NSViewRepresentable

    func makeNSView(context: Context) -> NSView {
        switch backgroundMode {
        case .vibrancy(let material):
            return makeVibrantView(material: material)

        case .tintedVibrancy(let material, _, _):
            // Container NSView with a vibrancy sublayer + tint overlay sublayer.
            let container = NSView()
            container.wantsLayer = true

            let vibrant = makeVibrantView(material: material)
            vibrant.translatesAutoresizingMaskIntoConstraints = false
            container.addSubview(vibrant)
            NSLayoutConstraint.activate([
                vibrant.topAnchor.constraint(equalTo: container.topAnchor),
                vibrant.bottomAnchor.constraint(equalTo: container.bottomAnchor),
                vibrant.leadingAnchor.constraint(equalTo: container.leadingAnchor),
                vibrant.trailingAnchor.constraint(equalTo: container.trailingAnchor)
            ])

            let tintView = NSView()
            tintView.wantsLayer = true
            tintView.translatesAutoresizingMaskIntoConstraints = false
            container.addSubview(tintView)
            NSLayoutConstraint.activate([
                tintView.topAnchor.constraint(equalTo: container.topAnchor),
                tintView.bottomAnchor.constraint(equalTo: container.bottomAnchor),
                tintView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
                tintView.trailingAnchor.constraint(equalTo: container.trailingAnchor)
            ])

            return container

        case .solid:
            let view = NSView()
            view.wantsLayer = true
            if let color = solidColor {
                view.layer?.backgroundColor = color.cgColor
            }
            return view
        }
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        switch backgroundMode {
        case .vibrancy(let material):
            guard let vibrant = nsView as? NSVisualEffectView else { return }
            vibrant.material = material
            // CRITICAL: Must re-set state = .active on every update.
            // Material assignment does not preserve state under .accessory policy.
            vibrant.state = .active
            // Set appearance in updateNSView (not makeNSView) — NSAppearance inheritance
            // resolution happens at display time, after the view is in the hierarchy.
            vibrant.appearance = forceAppearance

        case .tintedVibrancy(let material, let tint, let opacity):
            guard let vibrant = nsView.subviews.first as? NSVisualEffectView,
                  let tintView = nsView.subviews.last else { return }
            vibrant.material = material
            vibrant.state = .active   // CRITICAL: see note above
            vibrant.appearance = forceAppearance

            // Update tint color layer.
            let nsColor = NSColor(tint).withAlphaComponent(opacity)
            tintView.layer?.backgroundColor = nsColor.cgColor

        case .solid:
            if let color = solidColor {
                nsView.layer?.backgroundColor = color.cgColor
            }
        }
    }

    // MARK: Private helpers

    private func makeVibrantView(material: NSVisualEffectView.Material) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = .behindWindow
        // CRITICAL: Must be .active for .accessory activation policy.
        view.state = .active
        // Appearance is intentionally NOT set here — set it in updateNSView after
        // the view joins the hierarchy (Pitfall 1).
        return view
    }
}
