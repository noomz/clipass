# Phase 14: Inline Editor - Context

**Gathered:** 2026-03-18
**Status:** Ready for planning

<domain>
## Phase Boundary

Users can edit a clipboard item directly in the overlay and have changes immediately reflected in the menu bar popup. Click a pencil icon on a row to open a bottom editor panel, modify text, save to SwiftData. No pasteboard write on save — prevents history duplication. Overlay-only feature.

</domain>

<decisions>
## Implementation Decisions

### Edit trigger & gestures
- Pencil icon button on each row — click to enter edit mode
- Icon visible on hover + selected rows; hidden otherwise
- Icon uses theme accent color (not secondary text)
- No tooltip on pencil icon
- Existing gestures unchanged: single-click selects, double-click pastes

### Editor appearance
- Bottom panel layout — fixed panel appears at bottom of overlay, list shrinks above
- Monospace font in the text editor area (rows keep themed proportional font)
- Subtle distinct background for editor panel — visually separates from list while staying within theme
- Editor text area is scrollable for long content

### Save & cancel flow
- Save via Cmd+Return keyboard shortcut or Save button click
- Return key inserts newline in editor (not save — multi-line editing)
- ESC in edit mode cancels edit first (returns to list view); second ESC dismisses overlay
- Unsaved changes discarded silently when switching rows, dismissing, or cancelling — no confirmation dialog
- After save, editor panel closes and returns to list view; edited item stays selected

### Keyboard & focus
- On edit activation: focus moves to text editor, cursor at end of content
- On cancel/save: focus returns to search field
- Arrow keys disabled for list navigation during editing — arrows move cursor in editor only
- Search field visible but disabled (non-interactive) while editor panel is open
- Search text preserved when returning from editor

### Claude's Discretion
- Editor panel height/sizing strategy (fixed vs adaptive)
- Exact editor panel background shade per theme
- Cancel/Save button styling and positioning
- Animation for editor panel appear/disappear
- How to implement focus transfer (AppKit NSTextField vs SwiftUI @FocusState, given known NSPanel issues)

</decisions>

<specifics>
## Specific Ideas

- Bottom panel approach gives consistent editing space regardless of item content length
- Monospace font is practical — clipboard content is often code, JSON, URLs
- Two-stage ESC (cancel edit → dismiss overlay) matches how modal states work in most apps
- Silent discard fits the ephemeral Raycast/Spotlight feel — no heavy confirmation dialogs

</specifics>

<code_context>
## Existing Code Insights

### Reusable Assets
- `OverlayItemRow`: Has `onTap`, `onDoubleTap`, `isHovered`, theme integration — add pencil icon and `onEdit` callback
- `OverlaySearchField` (NSViewRepresentable): Handles ESC, arrow keys, Return — edit mode needs to intercept ESC before it reaches this field
- `ThemeManager` / `Theme`: Full theme system with colors, fonts, spacing — editor panel reads same theme properties
- `DisplayFormatter.format()`: Used for preview text — editor shows raw `item.content` instead
- `ClipboardItem` (@Model): SwiftData model with `content` field — editor modifies this directly

### Established Patterns
- `@Environment(ThemeManager.self)` for theme injection — editor panel uses same pattern
- `OverlayWindowController.shared` singleton for panel lifecycle — edit state may need to live here or in ClipboardOverlayView
- NSViewRepresentable pattern for AppKit controls in NSPanel — may need NSTextView wrapper for reliable focus in non-activating panel (same issue as OverlaySearchField)
- `@AppStorage` for persistent settings — no new settings needed for editor
- Notification-based communication (`overlayWillShow`) — could use similar pattern to reset edit state

### Integration Points
- `ClipboardOverlayView`: Add editor panel below ScrollView, manage edit state (`editingItemID`)
- `OverlayItemRow`: Add pencil icon button, `onEdit` callback
- `OverlaySearchField`: ESC handler needs to check edit state before dismissing overlay
- `ClipboardMonitor`: No changes needed — edits save to SwiftData only, not pasteboard, so monitor won't re-detect
- `OverlayWindowController`: May need edit state reset on `hide()`

</code_context>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

---

*Phase: 14-inline-editor*
*Context gathered: 2026-03-18*
