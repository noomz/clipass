import CoreGraphics

/// Pure layout math for the overlay panel.
///
/// AppKit Y origin is the bottom-left. `visibleFrame` already excludes the
/// menu bar and Dock, so clamping `maxY` to `visibleFrame.maxY` keeps the
/// panel from sitting behind the menu bar (`.floating` is below menu-bar level).
enum OverlayPositioning {
    /// Center the panel on `visibleFrame`, nudge it up by 10% of the visible
    /// height, then clamp so every edge stays on-screen.
    static func defaultFrame(panelSize: CGSize, visibleFrame: CGRect) -> CGRect {
        let origin = CGPoint(
            x: visibleFrame.midX - panelSize.width / 2,
            y: visibleFrame.midY - panelSize.height / 2 + visibleFrame.height * 0.1
        )
        return clamp(CGRect(origin: origin, size: panelSize), to: visibleFrame)
    }

    /// Keep `frame` inside `visible`. If the panel is taller than the visible
    /// area, pin its top to `visible.maxY` so it stays below the menu bar.
    static func clamp(_ frame: CGRect, to visible: CGRect) -> CGRect {
        var f = frame
        if f.maxX > visible.maxX { f.origin.x = visible.maxX - f.width }
        if f.minX < visible.minX { f.origin.x = visible.minX }
        if f.maxY > visible.maxY { f.origin.y = visible.maxY - f.height }
        if f.minY < visible.minY { f.origin.y = visible.minY }
        if f.height > visible.height {
            f.origin.y = visible.maxY - f.height
        }
        return f
    }

    /// Place the panel for a summon.
    ///
    /// - `followsMouseScreen == true`: keep the last offset within a screen,
    ///   mapped onto `preferredVisibleFrame` (the display under the pointer).
    /// - `followsMouseScreen == false`: restore the last absolute origin if
    ///   that screen is still connected; otherwise default on the pointer display.
    static func frameForShow(
        panelSize: CGSize,
        savedOrigin: CGPoint?,
        visibleFrames: [CGRect],
        preferredVisibleFrame: CGRect,
        followsMouseScreen: Bool
    ) -> CGRect {
        // NSPanel is created at (0, 0); a persisted origin of zero is the
        // uninitialized frame, not a user position.
        let savedOrigin: CGPoint? = {
            guard let savedOrigin, savedOrigin != .zero else { return nil }
            return savedOrigin
        }()

        if followsMouseScreen {
            if let savedOrigin,
               let lastScreen = visibleFrames.first(where: {
                   $0.intersects(CGRect(origin: savedOrigin, size: panelSize))
               }) {
                let mapped = CGPoint(
                    x: preferredVisibleFrame.origin.x + (savedOrigin.x - lastScreen.origin.x),
                    y: preferredVisibleFrame.origin.y + (savedOrigin.y - lastScreen.origin.y)
                )
                return clamp(CGRect(origin: mapped, size: panelSize), to: preferredVisibleFrame)
            }
            return defaultFrame(panelSize: panelSize, visibleFrame: preferredVisibleFrame)
        }

        if let savedOrigin {
            let proposed = CGRect(origin: savedOrigin, size: panelSize)
            if let visible = visibleFrames.first(where: { $0.intersects(proposed) }) {
                return clamp(proposed, to: visible)
            }
        }
        return defaultFrame(panelSize: panelSize, visibleFrame: preferredVisibleFrame)
    }
}
