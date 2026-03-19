# Phase 14: Inline Editor - Research

**Researched:** 2026-03-19
**Domain:** SwiftUI/AppKit inline text editing in non-activating NSPanel, SwiftData mutation, focus management, ESC conflict resolution
**Confidence:** HIGH

---

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

**Edit trigger & gestures**
- Pencil icon button on each row — click to enter edit mode
- Icon visible on hover + selected rows; hidden otherwise
- Icon uses theme accent color (not secondary text)
- No tooltip on pencil icon
- Existing gestures unchanged: single-click selects, double-click pastes

**Editor appearance**
- Bottom panel layout — fixed panel appears at bottom of overlay, list shrinks above
- Monospace font in the text editor area (rows keep themed proportional font)
- Subtle distinct background for editor panel — visually separates from list while staying within theme
- Editor text area is scrollable for long content

**Save & cancel flow**
- Save via Cmd+Return keyboard shortcut or Save button click
- Return key inserts newline in editor (not save — multi-line editing)
- ESC in edit mode cancels edit first (returns to list view); second ESC dismisses overlay
- Unsaved changes discarded silently when switching rows, dismissing, or cancelling — no confirmation dialog
- After save, editor panel closes and returns to list view; edited item stays selected

**Keyboard & focus**
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

### Deferred Ideas (OUT OF SCOPE)
None — discussion stayed within phase scope
</user_constraints>

---

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| EDIT-01 | User can click a clipboard item in the overlay to enter edit mode | Pencil icon in OverlayItemRow with `onEdit` callback; `editingItemID` state in ClipboardOverlayView |
| EDIT-02 | User can modify the text and save changes | NSTextView-backed editor panel writes directly to `item.content` via SwiftData modelContext.save(); no pasteboard write |
| EDIT-03 | User can cancel editing with ESC (without dismissing overlay) | Two-stage ESC: OverlaySearchField `onEscape` checks `editingItemID != nil` before calling hide(); editor panel intercepts ESC first |
| EDIT-04 | Edits sync to the menu bar popup immediately (SwiftData round-trip) | SwiftData `@Query` in ClipboardPopup auto-observes model changes; save() triggers re-render in menu bar popup |
</phase_requirements>

---

## Summary

Phase 14 adds inline editing to the overlay panel. The architecture is a bottom-panel approach: when a user clicks the pencil icon on a row, a fixed-height editor panel slides up from the bottom of the overlay and the list area shrinks to fill the remaining space above it. The editor holds raw `item.content` (not the `DisplayFormatter`-truncated preview). After save, the SwiftData model is updated via `try? modelContext.save()` — no pasteboard write — so `ClipboardMonitor` does not react and no duplicate is created. The menu bar popup's `@Query` auto-observes the model context and re-renders immediately (EDIT-04 is free).

The primary implementation challenge is focus management in a non-activating NSPanel. The existing project already solved this pattern for `OverlaySearchField` by wrapping an `NSTextField` as `NSViewRepresentable` and calling `window?.makeFirstResponder(field)` via `DispatchQueue.main.async`. The same `NSViewRepresentable` + `NSTextView` (not `NSTextField`) pattern is required for the editor because: (1) `NSTextView` supports multi-line and scrollable content natively, and (2) `@FocusState` is documented as unreliable in NSPanel-hosted SwiftUI (STATE.md decision from Phase 12).

The ESC conflict is the most delicate interaction: `OverlaySearchField`'s coordinator intercepts `cancelOperation(_:)` and calls `onEscape` (which currently always calls `OverlayWindowController.shared.hide()`). In edit mode this must instead cancel editing. The fix is to pass an `isEditing` flag or closure into `OverlaySearchField`'s `onEscape` callback so the overlay view can choose whether to cancel the editor or dismiss.

**Primary recommendation:** Implement the editor as an `NSTextView`-backed `NSViewRepresentable` (matching the existing `OverlaySearchField` pattern). Manage `editingItemID: ClipboardItem.ID?` as `@State` in `ClipboardOverlayView`. Gate `OverlaySearchField`'s `onEscape` callback so that when `editingItemID != nil`, ESC cancels the editor instead of dismissing the overlay.

---

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| AppKit `NSTextView` | Built-in | Multi-line scrollable text editor | Single-line `NSTextField` cannot scroll; `NSTextView` is the AppKit primitive for multi-line editing. Already established project pattern for NSViewRepresentable wrappers. |
| SwiftData `modelContext.save()` | Built-in | Persist edited content | Direct mutation of `@Model` object + `try? modelContext.save()` is the established project pattern |
| SwiftUI `@State` | Built-in | `editingItemID` state in ClipboardOverlayView | Drives conditional rendering of editor panel and disabling of search field |
| SwiftUI `withAnimation` | Built-in | Slide-up/down animation for editor panel | Matches existing overlay show/hide `.easeOut(duration: 0.15)` animation style |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| `NSScrollView` + `NSTextView` | Built-in | Scrollable editor text area | `NSTextView` must be embedded in `NSScrollView` to get scroll behavior |
| `NSFont.monospacedSystemFont` | Built-in | Monospace font in editor | System monospace font that respects Dynamic Type scale; correct choice for code/data content |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| NSTextView NSViewRepresentable | SwiftUI `TextEditor` | `TextEditor` relies on `@FocusState` which is unreliable in non-activating NSPanel (established project decision, STATE.md Phase 12) |
| NSTextView NSViewRepresentable | SwiftUI `TextField` with `axis: .vertical` | Still uses `@FocusState` under the hood; same NSPanel focus limitation |
| Direct `item.content` mutation | Copy-on-edit buffer | Buffer prevents accidental modification before save, but CONTEXT.md specifies silent discard on cancel — direct mutation with rollback on cancel is simpler and idiomatic |

**No external packages needed.** Everything required is in the standard SDK.

---

## Architecture Patterns

### Component Layout

```
ClipboardOverlayView
├── VStack(spacing: 0)
│   ├── OverlaySearchField          ← disabled (non-interactive) when editingItemID != nil
│   ├── themedDivider
│   ├── ScrollViewReader { ScrollView { LazyVStack { OverlayItemRow... } } }
│   │                               ← height flexible, shrinks when editor panel is shown
│   ├── themedDivider               ← only when editor hidden
│   ├── InlineEditorPanel           ← conditional, shown when editingItemID != nil
│   │   ├── EditorTextView          ← NSTextView NSViewRepresentable
│   │   └── HStack { Cancel Button, Save Button }
│   └── bottom bar (item count)     ← only when editor hidden
```

### State Management in ClipboardOverlayView

```swift
// New state variable — only addition needed
@State private var editingItemID: ClipboardItem.ID? = nil
@State private var editorContent: String = ""   // buffer for in-progress edit
```

`editingItemID != nil` drives:
1. Editor panel visibility (conditional view)
2. `OverlaySearchField` disabled state
3. `OverlaySearchField` `onEscape` routing (cancel editor vs dismiss overlay)
4. `OverlayItemRow` pencil icon visibility (show on hover/selected only)

### Pattern 1: NSTextView NSViewRepresentable (Editor)

**What:** Wrap `NSScrollView` + `NSTextView` as `NSViewRepresentable`. On `makeNSView`, request first-responder via `DispatchQueue.main.async`. Bind text via `NSTextViewDelegate.textDidChange`. Apply monospace font and theme colors in `updateNSView`.

**When to use:** Any multi-line text input in a non-activating NSPanel (same reason OverlaySearchField uses NSTextField instead of SwiftUI TextField).

```swift
// Source: Established project pattern from OverlaySearchField.swift
struct EditorTextView: NSViewRepresentable {

    @Binding var text: String
    var theme: Theme
    var isActive: Bool           // triggers focus on activation
    var onCommit: () -> Void     // Cmd+Return
    var onCancel: () -> Void     // ESC

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        let textView = NSTextView()

        textView.delegate = context.coordinator
        textView.isEditable = true
        textView.isRichText = false
        textView.allowsUndo = true
        textView.font = NSFont.monospacedSystemFont(ofSize: NSFont.systemFontSize, weight: .regular)
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.textContainer?.widthTracksTextView = true
        textView.textContainer?.containerSize = NSSize(width: .greatestFiniteMagnitude, height: .greatestFiniteMagnitude)

        scrollView.documentView = textView
        scrollView.hasVerticalScroller = true
        scrollView.drawsBackground = false

        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? NSTextView else { return }

        // Sync text only when changed externally (avoid caret-jump during typing)
        if textView.string != text {
            textView.string = text
        }

        // Apply theme colors
        textView.textColor = NSColor(theme.primaryText)
        textView.insertionPointColor = NSColor(theme.accentColor)

        // Focus: when isActive becomes true, request first-responder
        if isActive {
            DispatchQueue.main.async {
                textView.window?.makeFirstResponder(textView)
                // Move cursor to end of content
                let end = textView.string.endIndex
                let nsRange = NSRange(end..<end, in: textView.string)
                textView.setSelectedRange(nsRange)
            }
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject, NSTextViewDelegate {
        var parent: EditorTextView

        init(_ parent: EditorTextView) { self.parent = parent }

        func textDidChange(_ notification: Notification) {
            guard let tv = notification.object as? NSTextView else { return }
            parent.text = tv.string
        }

        // Intercept Cmd+Return (commit) and ESC (cancel)
        func textView(_ textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
            if commandSelector == #selector(NSResponder.insertNewline(_:)) {
                // Check for Cmd modifier — Cmd+Return = save, bare Return = newline
                if NSApp.currentEvent?.modifierFlags.contains(.command) == true {
                    parent.onCommit()
                    return true
                }
                return false   // let Return insert newline
            }
            if commandSelector == #selector(NSResponder.cancelOperation(_:)) {
                parent.onCancel()
                return true
            }
            return false
        }
    }
}
```

### Pattern 2: ESC Conflict Resolution

**What:** The two-stage ESC behavior (cancel editor → dismiss overlay) is controlled in `ClipboardOverlayView` by routing the `onEscape` callback based on `editingItemID`.

**When to use:** Any time the overlay has a modal sub-state that ESC should exit before the overlay itself closes.

```swift
// In ClipboardOverlayView — OverlaySearchField construction:
OverlaySearchField(
    text: $searchText,
    placeholder: "Search clipboard...",
    theme: theme,
    onArrowUp: editingItemID == nil ? moveSelectionUp : {},
    onArrowDown: editingItemID == nil ? moveSelectionDown : {},
    onEscape: {
        if editingItemID != nil {
            cancelEdit()   // first ESC: cancel editor
        } else {
            OverlayWindowController.shared.hide()   // second ESC: dismiss overlay
        }
    },
    onReturn: editingItemID == nil ? pasteSelected : {}
)
// Disable interaction entirely during edit:
.disabled(editingItemID != nil)
.opacity(editingItemID != nil ? 0.5 : 1.0)
```

Note: `OverlayPanel.cancelOperation(_:)` (the NSPanel-level ESC fallback) calls `OverlayWindowController.shared.hide()` directly. If the EditorTextView holds first-responder, its `doCommandBy cancelOperation` fires first and calls `onCancel` before the panel-level handler. This is the correct priority chain — the editor sees ESC first.

### Pattern 3: SwiftData Save (No Pasteboard Write)

**What:** Mutate `item.content` directly on the `@Model` object and call `try? modelContext.save()`. The `ClipboardMonitor` will NOT fire because it watches `NSPasteboard.changeCount` — a SwiftData write does not change the pasteboard.

**When to use:** All editor saves.

```swift
// In ClipboardOverlayView
private func commitEdit() {
    guard let id = editingItemID,
          let item = filteredItems.first(where: { $0.id == id }) else { return }
    item.content = editorContent
    try? modelContext.save()
    // editingItemID = nil closes the panel; selectedID remains on the item
    editingItemID = nil
    // Return focus to search field
    // (OverlaySearchField's makeNSView auto-focuses on next update cycle)
}

private func cancelEdit() {
    editorContent = ""    // discard — no save
    editingItemID = nil
}
```

EDIT-04 (immediate sync to menu bar popup) is free: `ClipboardPopup` uses `@Query` which observes the SwiftData `ModelContext`. When `modelContext.save()` fires, SwiftUI re-renders `ClipboardPopup` automatically. No notification or explicit refresh needed.

### Pattern 4: Pencil Icon in OverlayItemRow

**What:** Add `onEdit` callback and `isEditing` flag to `OverlayItemRow`. Show a pencil icon (`pencil` SF Symbol) on the trailing edge of the row when `isHovered || isSelected`, hidden when `editingItemID != nil` for this row or when nothing is selected.

**When to use:** All rows.

```swift
// OverlayItemRow additions:
var onEdit: (() -> Void)? = nil
var isEditing: Bool = false   // true when THIS row is being edited

// In row body, trailing side of the HStack:
if (isSelected || isHovered) && !isEditing {
    Button(action: { onEdit?() }) {
        Image(systemName: "pencil")
            .font(.caption)
            .foregroundColor(theme.accentColor)
    }
    .buttonStyle(.plain)
}
```

### Pattern 5: Editor Panel as Conditional View

**What:** Conditional `VStack` bottom section. When `editingItemID != nil`, a fixed-height panel slides up using `.transition(.move(edge: .bottom).combined(with: .opacity))`.

```swift
// At the bottom of contentStack VStack, replacing the static bottom bar:
if let editingID = editingItemID,
   let item = filteredItems.first(where: { $0.id == editingID }) {

    themedDivider

    InlineEditorPanel(
        content: $editorContent,
        theme: theme,
        onSave: commitEdit,
        onCancel: cancelEdit
    )
    .frame(height: 160)   // Claude's discretion: fixed height
    .transition(.move(edge: .bottom).combined(with: .opacity))

} else {
    themedDivider

    // Existing bottom bar (item count)
    HStack { ... }
}
```

Use `withAnimation(.easeOut(duration: 0.15))` when setting `editingItemID` — matches existing overlay animation style.

### Pattern 6: Overlay Height Accommodation

The overlay is fixed at `640 × 400` (set in `OverlayPanel.init` and `ClipboardOverlayView.frame`). When the editor panel appears at the bottom, the `ScrollView` naturally shrinks because `VStack` distributes remaining space. No frame changes to the panel are needed — the list compresses upward, the editor panel occupies its `frame(height: 160)` at the bottom.

### Anti-Patterns to Avoid

- **Using SwiftUI `TextEditor` or `TextField` for the editor:** Both depend on `@FocusState`, which is unreliable in non-activating NSPanel (established project decision from Phase 12).
- **Writing to NSPasteboard on save:** This would cause `ClipboardMonitor` to detect a change and create a duplicate entry. EDIT-02 and the CONTEXT.md explicitly forbid pasteboard writes on save.
- **Calling `OverlayWindowController.shared.hide()` from `OverlayPanel.cancelOperation` when editor is active:** The panel-level ESC fallback bypasses the two-stage ESC flow. Since `EditorTextView.doCommandBy cancelOperation` fires first when the text view holds first-responder, this is automatically handled — but must not be overridden.
- **Implementing editor panel as a separate NSPanel or sheet:** Keeping the editor within the same `ClipboardOverlayView` is simpler, avoids focus complications, and matches the CONTEXT.md "bottom panel" decision.
- **Using `@FocusState` to drive focus into EditorTextView:** Known to be unreliable in NSPanel (Phase 12 decision). Use `DispatchQueue.main.async { textView.window?.makeFirstResponder(textView) }` in `updateNSView` triggered by `isActive` parameter change.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Multi-line text editing | Custom word-wrap TextField | `NSTextView` in `NSScrollView` | NSTextView handles selection, caret, scroll, undo — building equivalent is 500+ lines and misses edge cases |
| Undo/redo in editor | Custom undo stack | `NSTextView.allowsUndo = true` | NSTextView has built-in undo manager; it's a one-line enable |
| Scroll-to-cursor | Manual scroll position tracking | `NSScrollView` with `NSTextView` as document view | Automatic scroll-to-insertion-point is built in |
| SwiftData → menu bar popup sync | Notification center broadcast | `@Query` in ClipboardPopup | @Query auto-observes model context; save() triggers re-render with zero extra code |
| Focus restoration to search field | Manual NSResponder traversal | Setting `editingItemID = nil` triggers `OverlaySearchField.updateNSView` which re-requests focus | The existing auto-focus mechanism in OverlaySearchField fires whenever the field re-renders |

**Key insight:** NSTextView is the correct AppKit primitive for multi-line text editing. Using it via NSViewRepresentable (as established for OverlaySearchField) is the minimal, correct path. Any SwiftUI-native approach breaks due to NSPanel focus constraints already documented in STATE.md.

---

## Common Pitfalls

### Pitfall 1: Focus Not Transferred to EditorTextView on Activation
**What goes wrong:** Clicking the pencil icon opens the editor panel but the cursor doesn't appear; keyboard input goes to OverlaySearchField instead.
**Why it happens:** `makeFirstResponder` called before the view is in the window hierarchy (same issue as OverlaySearchField — documented in Phase 12).
**How to avoid:** Call `textView.window?.makeFirstResponder(textView)` inside `DispatchQueue.main.async` in `updateNSView` (not `makeNSView`), triggered when `isActive` transitions to `true`.
**Warning signs:** Editor panel appears visually but you cannot type in it immediately.

### Pitfall 2: ESC Dismisses Overlay Instead of Cancelling Edit
**What goes wrong:** Pressing ESC while in edit mode closes the whole overlay rather than just the editor panel.
**Why it happens:** `OverlaySearchField.onEscape` unconditionally calls `OverlayWindowController.shared.hide()`. The search field may still hold first-responder in some cases (because `disabled()` does not remove focus on macOS).
**How to avoid:** Gate `onEscape` on `editingItemID != nil` as shown in Pattern 2. Additionally ensure `EditorTextView.doCommandBy cancelOperation` fires and calls `onCancel` before the search field coordinator fires.
**Warning signs:** After entering edit mode, ESC immediately closes the overlay.

### Pitfall 3: Duplicate History Entry After Save
**What goes wrong:** After saving an edit, the modified content appears twice in clipboard history — once as the edited original, once as a new entry.
**Why it happens:** If the save path writes to `NSPasteboard.general` (accidentally or as a "convenience"), `ClipboardMonitor` detects the pasteboard change and inserts a new `ClipboardItem`.
**How to avoid:** Never write to the pasteboard in the save path. Mutate `item.content` and call `modelContext.save()` only. The CONTEXT.md architecture decision confirms this explicitly.
**Warning signs:** History grows by one item each time you edit and save.

### Pitfall 4: OverlaySearchField Focus Not Restored After Edit
**What goes wrong:** After saving or cancelling edit, keyboard input is lost — neither the search field nor the editor has focus, and the arrow-key navigation stops working.
**Why it happens:** Setting `editingItemID = nil` removes `EditorTextView` from the hierarchy. The search field doesn't automatically reclaim focus because `makeFirstResponder` in its `makeNSView` only fires once at creation.
**How to avoid:** `OverlaySearchField.updateNSView` already re-applies theme on every update. Add a mechanism to re-request focus when the field transitions from `disabled` to `enabled` — either via a `Bool` `shouldFocus` parameter or by observing the `isEditing` state. Alternatively: when `editingItemID` becomes `nil`, explicitly call `panel.makeFirstResponder(searchField)` from `OverlayWindowController` or `ClipboardOverlayView`.
**Warning signs:** After cancelling or saving an edit, the overlay is visible but typing does nothing.

### Pitfall 5: Arrow Keys Move List Selection While in Editor
**What goes wrong:** Arrow keys in the editor move the clipboard list selection instead of moving the text cursor.
**Why it happens:** `OverlaySearchField` handles arrow keys via its `NSTextFieldDelegate.control(_:textView:doCommandBy:)` method, which fires for `moveDown` and `moveUp` selectors. If the search field still receives these events somehow, it calls `onArrowUp/onArrowDown`.
**How to avoid:** Pass `onArrowUp: {}` and `onArrowDown: {}` to `OverlaySearchField` when `editingItemID != nil` (as shown in Pattern 2). Additionally, `EditorTextView.doCommandBy` must NOT call `return false` for arrow key selectors — return `false` lets NSTextView handle them natively (correct), but ensure they don't bubble up past NSTextView.
**Warning signs:** While editing, pressing arrow keys scrolls the list rather than moving the text cursor.

### Pitfall 6: Content Is Formatted Preview Instead of Raw Content
**What goes wrong:** The editor opens with the truncated/formatted text from `DisplayFormatter.format()` instead of the full raw `item.content`.
**Why it happens:** Using `previewText` (which calls `DisplayFormatter.format()`) instead of `item.content` when initializing `editorContent`.
**How to avoid:** When entering edit mode, set `editorContent = item.content` (the raw SwiftData field), not `item.previewText` or `DisplayFormatter.format(item.content, ...)`.
**Warning signs:** Editor shows "..." truncated content; saves truncated version as the new content.

### Pitfall 7: OverlayPanel.cancelOperation Bypasses Two-Stage ESC
**What goes wrong:** If `EditorTextView` loses first-responder (e.g., user clicks elsewhere in the panel), the next ESC press hits `OverlayPanel.cancelOperation` which calls `hide()` directly — skipping the "cancel editor first" stage.
**Why it happens:** `OverlayPanel.cancelOperation` is an NSPanel-level override that fires when no other responder handles ESC. If the EditorTextView is not first-responder, its `doCommandBy cancelOperation` doesn't fire.
**How to avoid:** Update `OverlayPanel.cancelOperation` to check edit state before calling `hide()`, or route it through `ClipboardOverlayView` via a shared state check. The simplest fix: in `OverlayWindowController.hide()`, add an `editingItemID` check by adding a `cancelEditIfNeeded` closure that the overlay view registers.
**Warning signs:** Clicking outside the editor text area, then pressing ESC, dismisses the overlay without closing the editor panel first.

---

## Code Examples

### Entering Edit Mode (in ClipboardOverlayView)
```swift
// Source: established project patterns; @State + withAnimation pattern
private func enterEditMode(for item: ClipboardItem) {
    editorContent = item.content    // raw content, NOT DisplayFormatter output
    withAnimation(.easeOut(duration: 0.15)) {
        editingItemID = item.id
    }
    // selectedID stays on the item
}

private func commitEdit() {
    guard let id = editingItemID,
          let item = filteredItems.first(where: { $0.id == id }) else {
        cancelEdit()
        return
    }
    item.content = editorContent
    try? modelContext.save()
    withAnimation(.easeOut(duration: 0.15)) {
        editingItemID = nil
    }
    // selectedID remains unchanged — edited item stays highlighted
}

private func cancelEdit() {
    editorContent = ""
    withAnimation(.easeOut(duration: 0.15)) {
        editingItemID = nil
    }
    // selectedID unchanged — item remains selected after cancel
}
```

### Reset Edit State on Overlay Dismiss
```swift
// In ClipboardOverlayView — add to the overlayWillShow notification handler
.onReceive(NotificationCenter.default.publisher(for: Notification.Name("overlayWillShow"))) { _ in
    searchText = ""
    editingItemID = nil    // reset edit state when overlay re-shows
    editorContent = ""
    showContent = true
}
```

Also reset in `OverlayWindowController.hide()` or via notification so that if the overlay is dismissed while editing (e.g., click-outside via `resignKey`), state is clean on next open.

### NSTextView Monospace Font and Colors
```swift
// Source: AppKit NSTextView API
textView.font = NSFont.monospacedSystemFont(ofSize: NSFont.systemFontSize, weight: .regular)
textView.textColor = NSColor(theme.primaryText)
textView.insertionPointColor = NSColor(theme.accentColor)
textView.selectedTextAttributes = [
    .backgroundColor: NSColor(theme.itemBackground).withAlphaComponent(0.4)
]
// Background: let the SwiftUI container handle it (same as OverlaySearchField)
textView.drawsBackground = false
```

### Editor Panel Background (Claude's Discretion)
```swift
// Recommended: slightly darker variant of overlayBackground, per-theme
// Use theme.searchFieldBackground as a reasonable proxy — it's already a
// "recessed" surface within the overlay aesthetic for each theme.
RoundedRectangle(cornerRadius: 0)
    .fill(theme.searchFieldBackground.opacity(0.8))
    .padding(0)
```

---

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| `@FocusState` in NSPanel-hosted SwiftUI | `NSViewRepresentable` + `makeFirstResponder` | macOS 12-14 practical experience | @FocusState works in standard SwiftUI Windows but is unreliable in non-activating NSPanel; NSViewRepresentable wrapping is the canonical fix |
| `NSTextField` for multi-line | `NSTextView` in `NSScrollView` | Always | NSTextField is single-line; NSTextView is AppKit's multi-line editing primitive |
| SwiftUI `TextEditor` | `NSTextView` NSViewRepresentable | macOS 14 in NSPanel | TextEditor uses @FocusState internally; same NSPanel limitation applies |

**Deprecated/outdated:**
- Using `NSText` (superclass of `NSTextView`): Avoid — `NSText` is the abstract base. Use `NSTextView` directly.
- `NSTextView.string = ""` to clear content: Safe for initialization; in `updateNSView` always check `textView.string != text` before assigning to avoid cursor-jump.

---

## Open Questions

1. **Focus return to search field after edit**
   - What we know: `OverlaySearchField.makeNSView` calls `window?.makeFirstResponder(field)` once at creation via `DispatchQueue.main.async`. It does not re-request focus on updates.
   - What's unclear: Whether setting `editingItemID = nil` (removing `EditorTextView` from the hierarchy) is sufficient to trigger focus return, or whether an explicit `makeFirstResponder` call is needed.
   - Recommendation: Add a `shouldRefocus: Bool` parameter to `OverlaySearchField` that, when it transitions from `false` to `true` in `updateNSView`, calls `DispatchQueue.main.async { field.window?.makeFirstResponder(field) }`. This is the safe, explicit approach.

2. **OverlayPanel.cancelOperation and two-stage ESC**
   - What we know: `OverlayPanel.cancelOperation` calls `OverlayWindowController.shared.hide()` directly, bypassing any view-level ESC routing.
   - What's unclear: Whether `EditorTextView` reliably holds first-responder while the editor is open (preventing `OverlayPanel.cancelOperation` from firing for ESC).
   - Recommendation: Update `OverlayPanel.cancelOperation` to check a stored `isEditing` flag (set by the overlay view via a registered callback or a shared observable) before calling `hide()`. Or: accept that Pitfall 7 can occur in edge cases and note it as a known limitation. The primary ESC path (EditorTextView first-responder) is the happy path.

3. **Editor panel height: fixed vs adaptive**
   - What we know: Fixed height is simpler and gives predictable UX ("consistent editing space regardless of item content length" from CONTEXT.md specifics). Adaptive height would expand for long content but could push list area to near-zero.
   - Recommendation: Use fixed height (~160pt). This gives room for ~5-8 lines of monospace text which covers the common case. The text area is scrollable for longer content.

---

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | None — no test target exists (established from Phase 13 research) |
| Config file | None |
| Quick run command | `swift build` (compile validation only) |
| Full suite command | `swift build` |

### Phase Requirements → Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| EDIT-01 | Pencil icon appears on hover/selection; clicking enters edit mode | manual-only | `swift build` (compile check) | N/A |
| EDIT-02 | Editor opens with raw content; save persists to SwiftData; no duplicate in history | manual-only | Manual UI verification | N/A |
| EDIT-03 | First ESC cancels editor (list restored); second ESC dismisses overlay | manual-only | Manual UI verification | N/A |
| EDIT-04 | Edited content appears in menu bar popup immediately after save | manual-only | Manual UI verification | N/A |

### Sampling Rate
- **Per task commit:** `swift build` — confirms no compile errors
- **Per wave merge:** `swift build` — same (no automated tests)
- **Phase gate:** Manual UI verification of all 4 success criteria before `/gsd:verify-work`

### Wave 0 Gaps
None — existing test infrastructure (compile-only) covers all phase requirements. No new test files needed.

---

## Sources

### Primary (HIGH confidence)
- `/clipass/Views/OverlaySearchField.swift` — NSViewRepresentable + NSTextField pattern read directly; NSPanel focus mechanism confirmed
- `/clipass/Controllers/OverlayWindowController.swift` — OverlayPanel.cancelOperation ESC fallback read directly
- `/clipass/Views/ClipboardOverlayView.swift` — existing state management, animation style, notification patterns read directly
- `/clipass/Views/OverlayItemRow.swift` — hover/selection state patterns read directly
- `/clipass/Models/ClipboardItem.swift` — `content` field confirmed as plain `String` @Model property
- `/clipass/Services/ClipboardMonitor.swift` — pasteboard change detection confirmed; SwiftData-only saves will NOT trigger monitor
- `.planning/STATE.md` — Phase 12 decisions on NSPanel focus, @FocusState unreliability confirmed
- `.planning/phases/14-inline-editor/14-CONTEXT.md` — all locked decisions, editor appearance, ESC flow read directly

### Secondary (MEDIUM confidence)
- Apple Developer Documentation (NSTextView) — NSTextView + NSScrollView embedding is well-established AppKit pattern; `doCommandBy` delegate method for intercepting Cmd+Return and ESC is documented
- Apple Developer Documentation (NSTextViewDelegate) — `textView(_:doCommandBy:)` returns `Bool` to intercept/passthrough key commands

### Tertiary (LOW confidence — needs in-app validation)
- Focus restoration to search field after edit: The specific interaction between `EditorTextView` removal and `OverlaySearchField` re-acquiring focus is not verified. The recommended `shouldRefocus` parameter approach is a reasonable pattern but needs runtime confirmation.
- OverlayPanel.cancelOperation firing while EditorTextView holds first-responder: The priority chain (EditorTextView fires first) is expected AppKit behavior but has not been verified in this specific NSPanel setup.

---

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — all AppKit/SwiftUI built-ins; NSTextView pattern is established
- Architecture (state management, SwiftData save, no-pasteboard): HIGH — directly confirmed by reading source files and STATE.md
- ESC routing: HIGH for the logic pattern; MEDIUM for Pitfall 7 edge case (OverlayPanel.cancelOperation bypass)
- Focus management: MEDIUM — NSViewRepresentable pattern is confirmed; exact focus-return mechanics need runtime validation (Open Question 1)
- EDIT-04 (SwiftData → menu bar popup sync): HIGH — @Query auto-observation is fundamental SwiftData behavior

**Research date:** 2026-03-19
**Valid until:** 2026-06-19 (stable APIs)
