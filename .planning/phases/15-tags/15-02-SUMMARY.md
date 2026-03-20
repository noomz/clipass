---
phase: 15-tags
plan: 02
subsystem: ui
tags: [swiftui, swiftdata, tags, badges, context-menu, settings, search-filter]

# Dependency graph
requires:
  - phase: 15-tags-plan-01
    provides: Tag model, ClipboardItem.tags @Relationship, Tag.presetColors, Tag.randomPresetColor()

provides:
  - TagBadgeView: single colored-dot + name capsule badge component
  - TagBadgesRow: horizontal strip up to 3 badges + +N overflow, sorted alphabetically
  - TagsView: Settings split-pane (list + editor) for tag management
  - TagEditorPane: name field + 8-color palette + delete button
  - TagColorPalette: preset swatch picker with checkmark overlay
  - OverlayItemRow: tag badges on metadata line + Tag as... submenu + NSAlert new tag
  - HistoryItemRow: tag badges on metadata line + flat tag buttons (MenuBarExtra workaround)
  - ClipboardOverlayView: tag: prefix filter with OR/AND logic
  - SettingsView: 8th Tags tab between Actions and Appearance

affects: [future-tag-features, search-improvements, overlay-ui]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - TagBadgesRow uses overflowColor parameter instead of theme: Theme to work in both overlay (themed) and MenuBarExtra (no ThemeManager) contexts
    - Flat context menu buttons in MenuBarExtra — not submenus — due to known SwiftUI MenuBarExtra button action bug
    - NSAlert with NSTextField accessory for inline new-tag creation without a sheet

key-files:
  created:
    - clipass/Views/TagBadgeView.swift
    - clipass/Views/TagsView.swift
  modified:
    - clipass/Views/OverlayItemRow.swift
    - clipass/Views/HistoryItemRow.swift
    - clipass/Views/ClipboardOverlayView.swift
    - clipass/Views/SettingsView.swift

key-decisions:
  - "TagBadgesRow takes overflowColor: Color parameter instead of theme: Theme — enables reuse in MenuBarExtra context where ThemeManager is unavailable"
  - "Flat tag buttons in HistoryItemRow context menu — MenuBarExtra submenu actions silently fail (known SwiftUI bug), so tags listed as top-level items with Unicode checkmark prefix"

patterns-established:
  - "Badge pattern: colored dot + name in Capsule, sort alphabetically, max 3 + overflow"
  - "Dual context menu pattern: overlay uses Menu submenus (NSPanel supports it), menu bar uses flat buttons"
  - "Tag filter syntax: tag:name tokens parsed separately, OR among tags, AND with free text"

requirements-completed: [TAG-01, TAG-02, TAG-03, TAG-04, TAG-05]

# Metrics
duration: 4min
completed: 2026-03-20
---

# Phase 15 Plan 02: Tags UI Summary

**Tag badges (colored dot + name), context menu assignment, tag: search filter, and Settings > Tags split-pane — complete tag user experience across overlay, menu bar popup, and settings.**

## Performance

- **Duration:** ~4 min
- **Started:** 2026-03-20T08:16:32Z
- **Completed:** 2026-03-20T08:20:21Z
- **Tasks:** 2 of 2 auto tasks (Task 3 is human-verify checkpoint)
- **Files modified:** 6

## Accomplishments
- Created TagBadgeView and TagBadgesRow reusable components with alphabetical sort and overflow
- Built TagsView Settings split pane with list, editor, 8-color palette picker, and delete confirmation
- Wired tag badges onto both OverlayItemRow and HistoryItemRow metadata lines
- Added "Tag as..." context menu to overlay (submenu) and flat buttons to menu bar (bug workaround)
- Implemented tag: prefix search filter with OR multi-tag + AND free text logic
- Added 8th Tags tab to SettingsView (both modern sidebarAdaptable and legacy fallback paths)

## Task Commits

Each task was committed atomically:

1. **Task 1: Create TagBadgeView and TagsView components** - `d48c3c8` (feat)
2. **Task 2: Wire tag badges, context menus, search filter, and Settings tab** - `c57db27` (feat)

## Files Created/Modified
- `clipass/Views/TagBadgeView.swift` — TagBadgeView (single badge), TagBadgesRow (max-3 strip + overflow)
- `clipass/Views/TagsView.swift` — TagsView (split pane root), TagListRow, TagEditorPane, TagColorPalette
- `clipass/Views/OverlayItemRow.swift` — Added tag badges, Tag as... submenu, NSAlert new-tag creation
- `clipass/Views/HistoryItemRow.swift` — Added tag badges, flat tag toggle buttons, NSAlert new-tag
- `clipass/Views/ClipboardOverlayView.swift` — tag: prefix parsing with OR/AND logic
- `clipass/Views/SettingsView.swift` — 8th Tags tab in both tabViewModern and tabViewLegacy

## Decisions Made
- **TagBadgesRow uses `overflowColor: Color` not `theme: Theme`** — HistoryItemRow lives in MenuBarExtra which has no ThemeManager environment; using a plain Color parameter allows reuse without injecting ThemeManager.
- **Flat buttons in HistoryItemRow context menu** — MenuBarExtra(.window) silently swallows button tap events inside Menu submenus (known SwiftUI bug already documented in the codebase). Tag buttons rendered as top-level context menu items with Unicode checkmark (✓) prefix for checked state.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Design Adaptation] TagBadgesRow uses overflowColor instead of theme parameter**
- **Found during:** Task 2 (HistoryItemRow wiring)
- **Issue:** Plan specified `theme: Theme` for TagBadgesRow but HistoryItemRow has no ThemeManager environment (it's rendered inside MenuBarExtra)
- **Fix:** Changed `theme: Theme` parameter to `overflowColor: Color = .secondary` in TagBadgesRow. OverlayItemRow passes `overflowColor: isSelected ? .white.opacity(0.75) : theme.secondaryText`, HistoryItemRow passes default `.secondary`
- **Files modified:** clipass/Views/TagBadgeView.swift, both row views
- **Verification:** Build succeeds, no ThemeManager dependency in HistoryItemRow context
- **Committed in:** d48c3c8 (Task 1), c57db27 (Task 2)

---

**Total deviations:** 1 auto-fixed (Rule 1 - adaptation for MenuBarExtra context)
**Impact on plan:** Functionally equivalent result. Badge overflow color is still contextually correct in both overlay (theme-driven) and menu bar (system .secondary).

## Issues Encountered
None beyond the design adaptation noted above.

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- Complete tag UI implementation ready for human verification (Task 3 checkpoint)
- All TAG-01 through TAG-05 requirements implemented
- Build succeeds cleanly

---
*Phase: 15-tags*
*Completed: 2026-03-20*
