# Phase 15: Tags - Context

**Gathered:** 2026-03-20
**Status:** Ready for planning

<domain>
## Phase Boundary

Users can organize clipboard items with colored tags and filter history by tag in the overlay. Tag management (create, rename, delete, set color) lives in Settings. This phase covers the Tag data model, UI for assigning/displaying/filtering tags, and the Settings Tags tab. CLI tag commands and pub/sub tag events are separate phases (17).

</domain>

<decisions>
## Implementation Decisions

### Tag assignment UX
- Primary interaction: context menu "Tag as..." submenu with checkmark toggles
- Available in BOTH overlay (right-click) and menu bar popup (HistoryItemRow context menu)
- Submenu lists all tags with checkmarks for assigned ones, plus "+ New Tag..." at bottom
- "+ New Tag..." triggers NSAlert with text field for name input, auto-assigns random color from palette
- No tag assignment in the inline editor — context menu only

### Badge display
- Tag badges on the SECOND line (metadata row) alongside source app and timestamp
- Style: colored dot + tag name in caption font (like GitHub labels)
- Max 3 visible tag badges per row, then "+N" overflow indicator
- Badges appear in BOTH overlay (OverlayItemRow) and menu bar popup (HistoryItemRow)

### Search & filtering
- `tag:name` prefix syntax in overlay search field (TAG-03)
- Multiple tag filters use OR logic: `tag:work tag:code` shows items with either tag
- Tag filters combine with free text: `tag:work hello` = items tagged 'work' AND containing 'hello'
- No autocomplete when typing `tag:` — user types full tag name manually

### Settings management
- New "Tags" tab in Settings (8th tab in sidebarAdaptable TabView)
- Layout: list + editor split pane (same pattern as Transforms/Actions tabs)
- Left side: tag list with colored dots, [+] [-] buttons
- Right side: name text field, preset color palette (8-10 colors), delete button
- Color picker: preset palette only (red, orange, yellow, green, blue, purple, pink, gray) — no system color picker
- No default starter tags — starts empty, users create what they need
- Deleting a tag requires confirmation alert: "Delete tag 'X'? This removes it from all items."

### Claude's Discretion
- Exact preset color hex values (should work well across all 5 themes)
- Tag model schema details (SwiftData implicit many-to-many already decided)
- Sort order of tags in context menu submenu and Settings list
- Exact badge spacing and layout within the metadata row
- Whether overflow "+N" is clickable or just informational

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Requirements
- `.planning/REQUIREMENTS.md` — TAG-01 through TAG-05 define acceptance criteria for this phase

### Architecture decisions
- `.planning/STATE.md` §Accumulated Context — Documents SwiftData implicit many-to-many for tags, additive lightweight migration

### Existing patterns
- `clipass/Views/HistoryItemRow.swift` — Context menu pattern (Pin/Unpin, Copy As, content-aware actions, custom actions) — "Tag as..." goes here
- `clipass/Views/OverlayItemRow.swift` — Overlay row layout with pin badge, metadata line — tag badges go on second line
- `clipass/Views/SettingsView.swift` — sidebarAdaptable TabView with 7 tabs — new Tags tab follows same pattern
- `clipass/Models/ClipboardItem.swift` — Current model (id, content, sourceApp, timestamp, isPinned) — needs tags relationship
- `clipass/Views/ClipboardOverlayView.swift` — Search filtering logic in `filteredItems` — needs `tag:` prefix parsing

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `OverlayItemRow`: Already has second metadata line (source app + timestamp) — badges insert between them
- `HistoryItemRow`: Context menu with submenu pattern (Copy As...) — "Tag as..." follows same approach
- `ContentAnalyzer`: Pattern for content-aware features — could inform tag suggestions later (out of scope)
- `ThemeManager` + `Theme`: All colors theme-aware — tag badge colors need theme-compatible rendering
- `DisplayFormatter`: Formats preview text — no changes needed for tags

### Established Patterns
- SwiftData `@Model` for persistence (ClipboardItem, TransformRule, Hook, ContextAction, etc.)
- `@Query` in views for live data binding
- `@AppStorage` for simple settings
- `@Environment(ThemeManager.self)` for theme access
- NSAlert for system prompts (used in other macOS apps — standard pattern for "+ New Tag...")
- sidebarAdaptable TabView for settings tabs

### Integration Points
- `ClipboardItem` model: Add tags relationship (many-to-many)
- `SettingsView`: Add 8th "Tags" tab
- `ClipboardOverlayView.filteredItems`: Parse `tag:` prefix from search text
- `OverlayItemRow`: Add tag badges to metadata line
- `HistoryItemRow.contextMenu`: Add "Tag as..." submenu
- SwiftData schema: Lightweight additive migration for new Tag model

</code_context>

<specifics>
## Specific Ideas

- Badge style like GitHub labels: small colored dot + tag name — clean, readable
- Settings Tags tab follows list + editor split pane pattern (like Transforms/Actions)
- NSAlert for inline tag creation — native macOS feel, no custom UI needed

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

---

*Phase: 15-tags*
*Context gathered: 2026-03-20*
