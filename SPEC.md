# Clipboard interface redesign

## §G Goal

Make clipboard retrieval predictable in the menu popover and global modal. Open on the newest captured copy. Support the same keyboard-first browsing, search, preview, and copy workflow in both interfaces.

## §C Constraints and approval

- C1. Scope: the two clipboard interfaces. Not a specification of every existing clipass feature.
- C2. User approved variant B, Recent and Pinned tabs, and its keyboard refinement on 2026-11-17. Approval is a design decision, not a claim of native implementation.
- C3. User explicitly chose layered Back behavior and list navigation that stops at the ends. No navigation-history stack. No wrapping.
- C4. Native target: macOS 14+, SwiftUI, AppKit, SwiftData. Preserve existing history, pin, tag, capture, filtering, and transform data.
- C5. Existing user-configured summon shortcuts remain unchanged. New shortcuts apply only inside the active clipass interface, not system-wide.
- C6. No automatic paste into another app. Copy means write the selected content to the clipboard. Copy & close also dismisses the interface.
- C7. Keep both interfaces compact and recognizably native. Use readable system typography, distinct selection and hover, visible focus, restrained separators, and a shared control vocabulary.
- C8. The saved HTML is a frozen design reference, not production code. Variants A and C remain comparison material only. Browser demo controls, fixture labels, state readouts, and variant switchers do not ship in the native app.
- C9. This spec governs behavior. The approved B artifact governs visual direction. A conflict requires an explicit decision, not silent replacement of either reference.
- C10. Native implementation and verification remain pending. The prototype does not prove native focus, keyboard routing, redaction, or scroll behavior.

## §I Interfaces and design artifact

- I.popover. Menu-bar popover. Native entry: `clipass/Views/ClipboardPopup.swift`. Rows: `clipass/Views/HistoryItemRow.swift`.
- I.modal. Global modal. Native entry: `clipass/Views/ClipboardOverlayView.swift`. Rows: `clipass/Views/OverlayItemRow.swift`. Window lifecycle: `clipass/Controllers/OverlayWindowController.swift`. Search bridge: `clipass/Views/OverlaySearchField.swift`.
- I.capture. Captured history and copy timestamps: `clipass/Models/ClipboardItem.swift`, `clipass/Services/ClipboardMonitor.swift`.
- I.display. Shared preview formatting and redaction: `clipass/Services/DisplayFormatter.swift`, `clipass/Views/DisplaySettingsView.swift`.
- I.design. Approved, self-contained snapshot: [docs/design/clipboard-b-approved.html](docs/design/clipboard-b-approved.html?variant=B). Default variant: B. Open directly in a browser. Uses fictional content and in-memory state. Does not read or write the OS clipboard.
- I.provenance. Design project: `clipass-clipboard-interaction-redesign-c3f8`. Entry: `index.html`. Approved refinement run: `3ce28aef-1735-4c55-b063-32047e00acf7`. Generated with Local Codex. Snapshot SHA-256: `fc8b6af22fc176bf66d8b14df683859e772917424d5bfefbde9a1aff945ba920`.
- I.portability. Repository snapshot is the durable artifact. Local preview and studio URLs are temporary and are not required to inspect the saved design.
- I.evidence. Before persistence, preview returned HTTP 200 and inline JavaScript passed `node --check`. Local Codex reported 137 DOM interaction checks plus A/C smoke checks. Those checks were not independently rerun. Live visuals and actual scroll geometry remain unverified.

### I.keys Shared keyboard contract

| Action | Shortcut | Scope and result |
| --- | --- | --- |
| Open Recent | `⌘1` | Active interface. Select first matching result in Recent. |
| Open Pinned | `⌘2` | Active interface. Select first matching result in Pinned. |
| Previous tab | `⌘⇧[` | Active interface. Cycle between Recent and Pinned. |
| Next tab | `⌘⇧]` | Active interface. Cycle between Recent and Pinned. |
| Previous or next result | `↑` or `↓` | List focus. Stop at the ends. Reveal selected row. |
| Enter results | `↓` | Search focus. Focus selected matching row, or first result if none selected. |
| First or last result | `⌘↑` or `⌘↓` | List focus only. Select and reveal first or last visible result. |
| First or last result, alternative | `Home` or `End` | List focus only. Same result as above. |
| Focus search | `⌘F` | Focus search and select existing query. Do not clear query. |
| Toggle preview | `Space` | List or preview focus. Search keeps normal space entry. |
| Toggle preview | `⌘P` | Active interface. Includes search focus. No global shortcut interception. |
| Back one layer | `Esc` | Close topmost help, menu, or confirmation; otherwise close preview; otherwise clear query; otherwise dismiss. One layer per press. |
| Copy & close | `Return` | Search, list, or preview focus. Copy selected item and dismiss. |
| Shortcut help | `⌘/` | Toggle visible shortcut help for active interface. |

## §V Invariants and acceptance criteria

V1. Every summon starts in Recent, clears query and edit state, closes transient layers, selects the newest captured item by copy timestamp, and focuses search. Empty history has no selection.

V2. Every summon explicitly reveals the newest item, including when its ID is unchanged. Previous selection and scroll position cannot leave the newest copy offscreen.

V3. Recent contains all captured items in descending copy-time order, including pinned items in their chronological positions. Pinned contains only pinned items in descending copy-time order. Pinning never promotes an old item above a newer copy in Recent.

V4. A capture during an open browsing session preserves the current tab, query, selected item, focus, and viewport when the selected item remains valid. Show a new-item notice with Jump to latest. Jump to latest applies the same targeting rule as summon.

V5. Both interfaces share the same search semantics. Free text matches content. `tag:work` filters by tag. Spaces remain typeable. Changing query selects the first matching result deterministically and reveals it. Switching tab retains query, selects the first matching result in that tab, and closes transient layers. If list had focus, keep list focus; otherwise focus search.

V6. Search reports no matches with an explanation and a clear-search action. Empty history explains that copying text creates history. Empty Pinned explains how to pin an item. Empty states have no stale selectable item or enabled Copy action.

V7. List navigation clamps at the first and last result. First/last shortcuts target the current filtered tab, not the unfiltered history. Selected row stays visible. Search text editing and preview scrolling do not accidentally move history selection.

V8. Only the active interface handles its app shortcuts. Text inputs retain normal editing keys except the explicitly listed app actions. Composition events are not intercepted. Buttons, menus, and confirmations retain their normal Return activation.

V9. Preview is read-only and shows full inspectable text, source, time, and tags. Long text and JSON can scroll. Closing preview restores selected row, list focus, and prior viewport. Preview scrolling does not navigate history.

V10. Escape backs out of exactly one topmost layer per press. Closing preview restores the list. Clearing query keeps the interface open. Final dismissal returns control to the previous app. No hidden navigation-history stack is added.

V11. Single-click selects in both interfaces. A visible Copy control works without knowing a shortcut. Return and optional double-click perform Copy & close. Labels and feedback never claim that content was pasted into the previous app.

V12. List previews and full read-only preview apply the same configured redaction rules in both interfaces. Both interfaces honor configured preview length for rows. Masking does not mutate stored content or change the original content copied by the primary Copy action.

V13. Both interfaces provide the same core item actions: Copy, Pin or Unpin, Copy as plain text, Copy as uppercase, and Delete. Existing additional transforms and custom actions remain available; this redesign does not remove them.

V14. Clear recent history lives in overflow, requires confirmation, states that pins are kept, and offers Undo after completion. Cancel is the safe default. Clearing removes only unpinned history. Clearing or deleting reconciles selection against remaining visible results.

V15. Tabs display subtle `⌘1` and `⌘2` hints. Selected rows expose a visible preview affordance. Footer hints reflect focus context and fit the compact popover. Shortcut help exposes the complete keymap. Controls have accessible names and keyboard focus indicators. Friendly app names replace raw bundle identifiers where resolvable.

V16. Verification reproduces the reported sequence in both native interfaces: browse an old item, dismiss, capture a new item, reopen. The new item is selected and visible. Repeat with enough pins and history to require scrolling, and with the newest item already selected before dismissal.

V17. Native checks cover tab switching, filtered first/last navigation, no wrapping, query retention on `⌘F`, spaces in search, preview focus restoration, one-layer Escape, Return in preview, inactive-interface shortcut isolation, empty states, redaction consistency, and clear-history cancellation and Undo. DOM-only checks do not satisfy native focus or actual visibility checks.

## §T Implementation tasks

Status `.` means pending. All tasks describe future native work, not completed prototype work.

| id | status | task | cites |
| --- | --- | --- | --- |
| T1 | x | Define shared tab, query, selection, focus, and transient-layer state. Add behavior tests. | V1,V3,V5,V8,V10,I.popover,I.modal |
| T2 | x | Apply B tabs, chronological Recent, shared search, and empty states to both interfaces. | V3,V5,V6,V15,I.design |
| T2.1 | x | Match both native interfaces to approved B: layout, sizing, spacing, typography, tabs, search, row styling, selection and hover, empty states, and control placement. Compare native screenshots side by side with I.design; behavior tests and isolated control renders are not visual sign-off. Preserve T2 behavior; T3–T6 retain their feature scope. | V3,V5,V6,V11,V15,I.popover,I.modal,I.design |
| T3 | x | Implement summon reset, explicit newest-row reveal, and noninterrupting capture notice. | V1,V2,V4,V16,I.capture |
| T4 | . | Implement shared keyboard routing, clamped navigation, focus transitions, and shortcut help. | V7,V8,V10,V15,I.keys |
| T5 | . | Add read-only preview with redaction, viewport restoration, and consistent Copy controls. | V9,V11,V12,I.display |
| T6 | . | Align core item actions. Add safe clear-recent confirmation and Undo. | V13,V14,I.popover,I.modal |
| T7 | . | Run acceptance checks on both native interfaces. Record runtime and visual evidence separately from prototype checks. | V1,V2,V4,V7,V8,V9,V10,V11,V12,V14,V16,V17 |

## §B Bug history

| id | date | cause | fix |
| --- | --- | --- | --- |
