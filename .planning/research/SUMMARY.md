# Project Research Summary

**Project:** clipass v2.0 — Overlay UI & Theming
**Domain:** macOS clipboard manager — Raycast-style floating overlay, semantic theming, inline text editor
**Researched:** 2026-03-13
**Confidence:** HIGH

## Executive Summary

clipass v2.0 adds three distinct features on top of a solid v1.1 foundation: a floating overlay panel (Raycast/Spotlight-style), a Raycast-inspired theme system, and an inline text editor scoped to the overlay. All three features are buildable with zero new Swift Package dependencies — the entire implementation uses AppKit (`NSPanel`, `NSVisualEffectView`) bridged to SwiftUI via patterns already in the codebase, the `@Observable` macro (macOS 14+), and the `KeyboardShortcuts` package already in use. No dependency churn, no data model changes, and a clear four-stage build order driven by hard architectural dependencies.

The critical architectural decision is that the overlay must be an `NSPanel` subclass, not a SwiftUI `Window` scene. SwiftUI `Window` scenes activate the app on show, appear in the Dock, cannot be kept at `.floating` window level, and cannot be centered programmatically — all disqualifying for a non-intrusive launcher overlay. The `NSPanel` with `.nonactivatingPanel` style mask is the same mechanism used by Raycast, Alfred, and Spotlight, and is well-documented across multiple high-confidence sources. The theme system uses `@Observable` + SwiftUI `EnvironmentValues` injection at the `NSHostingView` boundary; the inline editor uses `TextEditor` + `@FocusState` with commit/discard semantics.

The top risks are all implementation-level, not architectural: (1) the panel stealing focus from the previously active app if `.nonactivatingPanel` is omitted, (2) the SwiftUI environment being lost at the `NSHostingView` boundary if theme objects are not re-injected, and (3) inline edits polluting clipboard history if the clipboard monitor's change detection is not suppressed around edit commits. All three have clear, verified mitigations documented with specific code patterns.

## Key Findings

### Recommended Stack

No new dependencies are required. All v2.0 capabilities are available in the existing stack or via AppKit bridging patterns already in use. The `KeyboardShortcuts` package (already at `from: "2.0.0"`) handles the second overlay shortcut via a new `KeyboardShortcuts.Name` declaration — no upgrade needed. `NSVisualEffectView` (via `NSViewRepresentable`) provides frosted glass backgrounds on macOS 14+. The newer `.glassEffect` modifier is macOS 26 only and must not be used.

**Core technologies:**
- `NSPanel` subclass: floating overlay window — only viable mechanism for non-activating launcher overlays on macOS
- `NSVisualEffectView` (via `NSViewRepresentable`): frosted glass background — macOS 14+ confirmed, requires `.state = .active` when app uses `.accessory` activation policy
- `@Observable` + `EnvironmentValues`: theme propagation — macOS 14+ compatible, zero-dependency; must use `@Environment` key-path pattern (not `@EnvironmentObject`) for reliable style propagation
- `@AppStorage` (UserDefaults): theme persistence — correct tool for a string ID; SwiftData is overkill
- `TextEditor` + `@FocusState`: inline editor — stable macOS 14+ SwiftUI APIs; commit/discard semantics preferred over shared undo stack
- `KeyboardShortcuts` (existing): second global hotkey — register a new `Name` alongside existing `.toggleClipboard`

### Expected Features

**Must have (table stakes):**
- Floating center-screen panel with non-activating behavior — users expect this from any launcher overlay
- Separate global hotkey to summon/toggle the overlay — distinct from the existing Cmd+Shift+V menu bar shortcut
- ESC dismisses overlay; click outside dismisses overlay — universal macOS launcher conventions
- Search field auto-focused on open — without auto-focus, the overlay feels broken immediately
- Keyboard navigation (↑↓) and Return-to-paste — mouse-free use is the point of a launcher overlay
- Frosted glass / vibrancy background — macOS visual convention for floating utility panels
- Predefined themes (Dark, Light, at minimum) — required to call it a theme system
- Theme persists across launches — basic settings contract

**Should have (differentiators):**
- Click-to-edit inline text editor (overlay only) — no free clipboard manager does this; high value, medium complexity
- 3–5 curated named themes (Dark, Light, High Contrast, Nord or similar accent) — quality presets reduce configuration burden
- Theme picker in Settings with live preview — immediate visual feedback before committing
- ESC conflict resolution: ESC cancels edit (not overlay dismiss) when a row is in edit mode

**Defer to later milestone:**
- Custom theme authoring / Theme Studio UI — Raycast's equivalent is Pro-only; no reference open-source implementation found
- Theme import/export — requires community infrastructure that does not exist yet
- Rich text / Markdown rendering in inline editor — conflicts with existing transform model; massive complexity
- Drag-to-reorder in overlay — fragile in a transient overlay; pin/unpin from v1.1 handles priority
- Per-theme typography or density controls
- Overlay search query persistence between invocations

### Architecture Approach

The overlay is managed by a new `OverlayWindowController` (owned by `AppServices`) that creates one `NSPanel` lazily and caches it — never recreated. The panel hosts `ClipboardOverlayView` via `NSHostingView`, with `ThemeManager` and the shared `ModelContext` injected at that boundary. The theme system is a `ThemeManager` `@Observable` singleton with `Theme` value-type structs for each predefined theme. The inline editor is contained entirely in `OverlayItemRow` with local `@State` — no shared editing state at the parent level. The existing `ClipboardPopup` (menu bar popup) is unchanged; both surfaces share the same SwiftData `ModelContext`, so edits in the overlay automatically reflect in the popup via `@Query`.

**Major components:**
1. `OverlayWindowController` — NSPanel lifecycle, show/hide/toggle, screen positioning; lives in `AppServices`
2. `ThemeManager` (`@Observable`) — holds active `Theme`, persists selection to UserDefaults, single source of truth
3. `Theme` (value type struct) — all color/style tokens for one theme; predefined as static instances in code
4. `ClipboardOverlayView` — root SwiftUI view in the panel; search, item list, keyboard navigation
5. `OverlayItemRow` — display mode + inline edit mode; manages its own `isEditing` / `editText` state
6. `AppearanceSettingsView` — theme picker tab in Settings (7th tab added to existing `SettingsView`)
7. `VisualEffectBackground` (`NSViewRepresentable`) — frosted glass background wrapper

**New files: 7. Modified files: 3 (`clipassApp.swift`, `SettingsView.swift`, `GeneralSettingsView`). Data model changes: none.**

### Critical Pitfalls

1. **NSPanel steals focus from the active app** — must use `.nonactivatingPanel` style mask AND set `NSApp.activationPolicy` to `.accessory`. Missing either causes the overlay to disrupt the frontmost app on every summon. Test: open overlay while Terminal is focused; Terminal should stay active (blue title bar).

2. **SwiftUI environment lost at the NSHostingView boundary** — `ThemeManager` and `ModelContext` must be explicitly re-injected via `.environment(themeManager)` and `.modelContext(...)` at the `NSHostingView` call site. Without this, overlay views crash at runtime with "No observable object of type ThemeManager found" — works in previews, crashes in production.

3. **Inline edits pollute clipboard history** — the 500ms clipboard monitor detects pasteboard writes from edit commits as new clipboard entries, duplicating history. Preferred fix: skip the pasteboard write on save — update only the SwiftData model and copy to pasteboard only on explicit user paste. Alternative: set `suppressNextChange = true` on `ClipboardMonitor` before any pasteboard write.

4. **TextField in overlay receives no keyboard input** — `.nonactivatingPanel` does not automatically become the key window. Must override `canBecomeKey` to return `true` on the `NSPanel` subclass AND call `makeKeyAndOrderFront` (not `orderFrontRegardless`). Critical: `canBecomeMain` must return `false` — the combination of both returning `true` crashes.

5. **Multiple overlay instances from rapid hotkey presses** — the hotkey handler must use a singleton controller with lazy panel creation and an `isVisible` check. Never allocate a new `NSPanel` on each keypress.

## Implications for Roadmap

The build order is dictated by hard architectural dependencies: the NSPanel foundation must exist before theming can be visually tested; theming must be structurally in place before overlay views are styled; item rows need a working overlay before the inline editor can be added. This is not a preference — it is dependency order.

### Phase 1: NSPanel Foundation

**Rationale:** Everything in v2.0 depends on the overlay panel existing. This is also where the highest-severity pitfalls live (focus steal, no keyboard input, multiple instances). All subsequent phases are blocked until this is verified.

**Delivers:** Overlay panel that appears on hotkey, centers on the active screen, takes keyboard focus without stealing it from the frontmost app, dismisses on ESC/click-outside/hotkey toggle. Stub `ClipboardOverlayView` (plain list, unstyled).

**Addresses:** Floating panel, global hotkey, toggle, ESC dismiss, click-outside dismiss, search auto-focus, `hidesOnDeactivate`, smooth animation, keyboard navigation, Return-to-paste, shortcut recorder in Settings.

**Avoids:** Pitfall #1 (focus steal), #3 (multiple instances), #4 (no keyboard input), #11 (wrong panel size), #12 (hotkey conflict), #13 (wrong screen/space).

**Research flag:** Standard patterns — no additional research needed.

### Phase 2: Theme System

**Rationale:** Themes must be structurally in place before overlay views are styled. `OverlayItemRow` uses theme tokens for selection and hover colors, so theming must precede item row work. `AppearanceSettingsView` belongs here since it depends entirely on the theme infrastructure.

**Delivers:** `Theme` struct with all color tokens, `ThemeManager` (`@Observable`), 4 predefined themes (Dark, Light, Midnight, Nord), `VisualEffectBackground` vibrancy wrapper, `AppearanceSettingsView` (new tab in Settings), overlay styled with active theme, theme persistence across launches, live theme switching.

**Uses:** `@Observable` + `EnvironmentValues` injection at `NSHostingView` boundary, `@AppStorage` for theme ID persistence, `NSVisualEffectView` with `.state = .active`.

**Avoids:** Pitfall #2 (environment lost at boundary), #7 (hardcoded color literals), #8 (`@EnvironmentObject` unreliable in SwiftUI styles — use `EnvironmentValues` extension instead), #15 (blur renders flat when app is inactive).

**Research flag:** Standard patterns — no additional research needed.

### Phase 3: Overlay Item Rows

**Rationale:** Establishes the complete overlay interaction loop (search, select, navigate, paste) before adding edit complexity. Separating this from Phase 1 keeps each stage independently verifiable.

**Delivers:** Themed `OverlayItemRow` (display mode), `@Query` ClipboardItem list in overlay, search filtering with 150ms debounce, full keyboard navigation (↑↓ arrows, Return to paste), Escape to dismiss.

**Avoids:** Pitfall #6 (SwiftData re-fetch per keystroke — debounce search to avoid per-keystroke query execution).

**Research flag:** Standard patterns — reuses selection logic from existing `ClipboardPopup.swift`. No research needed.

### Phase 4: Inline Text Editor

**Rationale:** Depends on all prior phases. Isolated to `OverlayItemRow` with no impact on other phases — correctly sequenced last. Can be developed and reviewed independently.

**Delivers:** Two-state `OverlayItemRow` (display/edit), `TextEditor` bound to local `editText` buffer, commit on Return/save button, cancel on ESC (without dismissing overlay), ESC conflict resolution (row in edit mode: ESC cancels edit, not overlay dismiss), SwiftData round-trip verified (edits appear in menu bar popup without restart).

**Avoids:** Pitfall #5 (edit pollutes history — skip pasteboard write on save), #9 (focus/selection conflict — double-tap for edit, single-tap for select), #10 (shared undo stack — use commit/discard, not undo), #14 (race with clipboard monitor poll — set suppress flag before pasteboard write).

**Research flag:** Standard patterns — pitfalls are documented with prevention code. No additional research needed.

### Phase Ordering Rationale

- NSPanel before everything: the overlay window is the prerequisite for all visual and interaction work.
- Theme before rows: `OverlayItemRow` uses theme tokens; building rows without theming means rework.
- Rows before editor: the inline editor is a second mode within `OverlayItemRow`; the display mode must be stable before adding edit mode complexity.
- Inline editor last: zero impact on other three phases; can be deferred without blocking anything else.

### Research Flags

All four phases use standard, well-documented patterns. No phases require `/gsd:research-phase` during planning.

- **Phase 1:** NSPanel + SwiftUI hosting — battle-tested pattern from Raycast, Alfred, Spotlight; multiple high-confidence guides including a real production post-mortem (Multi.app blog)
- **Phase 2:** `@Observable` + EnvironmentValues theming — documented Apple pattern, confirmed macOS 14+
- **Phase 3:** Clipboard list + search — reuses `ClipboardPopup.swift` patterns already in the codebase
- **Phase 4:** TextEditor + FocusState inline editing — documented in detail; pitfalls catalogued with prevention code

## Confidence Assessment

| Area | Confidence | Notes |
|------|------------|-------|
| Stack | HIGH | All technologies are verified Apple APIs or existing dependencies; zero new packages; macOS 14+ compatibility confirmed for all patterns used |
| Features | HIGH | Table stakes consistent across Raycast, Alfred, Spotlight, and Apple HIG Panels; click-to-edit is MEDIUM (no Apple-official inline edit primitive, but exact pattern documented by polpiella.dev) |
| Architecture | HIGH | Derived from direct codebase analysis (50 files, 8K lines) + verified NSPanel patterns; anti-patterns explicitly documented with rationale |
| Pitfalls | HIGH | Multiple production post-mortems cited; Five Stars SwiftUI environment propagation analysis; Apple developer forum confirmation |

**Overall confidence:** HIGH

### Gaps to Address

- **`@FocusState` reliability in NSPanel-hosted SwiftUI:** Pitfall #4 notes a fallback via `NSApp.keyWindow?.makeFirstResponder()` for cases where `@FocusState` does not work in non-activating panels. This fallback has not been empirically tested in this codebase. Validate in Phase 1 before building search-dependent phases.

- **Vibrancy when app uses `.accessory` activation policy:** Pitfall #15 documents that `NSVisualEffectView` may render flat without blur when the owning app is not frontmost. The `.state = .active` fix is documented but must be verified in the actual running app, not Xcode previews. Validate in Phase 2.

- **Custom themes (deferred):** No reference open-source implementation found for a custom theme builder on macOS. If pursued in a later milestone, fresh research is required into JSON-based color scheme persistence and a live preview editor pattern.

## Sources

### Primary (HIGH confidence)

- NSPanel nonactivating pattern: https://developer.apple.com/documentation/appkit/nswindow/stylemask-swift.struct/nonactivatingpanel
- Apple HIG: Panels: https://developer.apple.com/design/human-interface-guidelines/panels
- Floating panel SwiftUI guide (Cindori): https://cindori.com/developer/floating-panel
- Nailing overlay activation behavior (Multi.app production post-mortem): https://multi.app/blog/nailing-the-activation-behavior-of-a-spotlight-raycast-like-command-palette
- NSVisualEffectView: https://developer.apple.com/documentation/appkit/nsvisualeffectview
- SwiftUI editable list text items (polpiella.dev): https://www.polpiella.dev/swiftui-editable-list-text-items
- SwiftUI environment propagation in AppKit bridges (Five Stars): https://www.fivestars.blog/articles/swiftui-environment-propagation-3/
- Environment objects in SwiftUI styles (Five Stars): https://www.fivestars.blog/articles/environment-objects-and-swiftui-styles/
- TextEditor: https://developer.apple.com/documentation/swiftui/texteditor
- @Entry macro for custom environment values: https://www.avanderlee.com/swiftui/entry-macro-custom-environment-values/

### Secondary (MEDIUM confidence)

- Spotlight-like window on macOS with SwiftUI (Markus Bodner): https://www.markusbodner.com/til/2021/02/08/create-a-spotlight/alfred-like-window-on-macos-with-swiftui/
- Fine-tuning macOS app activation behavior: https://artlasovsky.com/fine-tuning-macos-app-activation-behavior
- Resolving NSPanel 500x500 size issue: https://medium.com/@clyapp/resolving-nspanel-size-500x500-issues-in-macos-swift-app-71ba9ca8bc71
- Vibrancy in modern AppKit/SwiftUI (philz.blog): https://philz.blog/vibrancy-nsappearance-and-visual-effects-in-modern-appkit-apps/
- glassEffect macOS 26 limitation: https://www.klaritydisk.com/blog/building-liquid-glass-ui-macos
- Raycast custom themes: https://manual.raycast.com/custom-themes
- SwiftUI design tokens theming system: https://dev.to/sebastienlato/swiftui-design-tokens-theming-system-production-scale-b16
- SwiftData + List performance: https://www.hackingwithswift.com/forums/swiftui/performance-struggles-with-swiftdata-and-list/27724

### Tertiary (context only)

- Direct codebase analysis: clipass v1.1 (50 Swift files, 8,014 lines) — component boundaries, integration points, existing patterns

---
*Research completed: 2026-03-13*
*Ready for roadmap: yes*
