---
status: complete
phase: 11-context-actions
source: 11-01-PLAN.md (no SUMMARY.md — verified from plan + commit c004499)
started: 2026-03-13T00:00:00Z
updated: 2026-03-13T00:00:00Z
---

## Current Test

[testing complete]

## Tests

### 1. Content-aware context menu — URL item
expected: Right-click a clipboard item containing a URL. Context menu shows "Open URL" action.
result: pass

### 2. Content-aware context menu — non-URL item
expected: Right-click a clipboard item with plain text (no URL). "Open URL" should NOT appear in the context menu.
result: pass

### 3. Content-aware context menu — Email item
expected: Right-click a clipboard item containing an email address. "Send Email" action appears in context menu.
result: pass

### 4. Content-aware context menu — JSON item
expected: Right-click a clipboard item containing valid JSON. "Format JSON" action appears in context menu.
result: pass

### 5. Content-aware context menu — Path item
expected: Right-click a clipboard item containing a file path (e.g. /usr/local/bin). "Open in Finder" action appears.
result: pass

### 6. Pin/Unpin toggle
expected: Right-click any item, click "Pin". Item shows a pin icon and sorts to the top of the list. Right-click again, "Unpin" is available to remove it.
result: pass

### 7. Pinned items survive auto-cleanup
expected: Pin an item, then let auto-cleanup run (or trigger it). The pinned item remains in the list while unpinned old items are cleaned up.
result: pass

### 8. Always-available text actions
expected: Right-click any text item. "Copy Uppercase", "Copy Lowercase", "Copy Trimmed", "Copy Base64 Encode/Decode" actions are available.
result: pass

### 9. Actions tab in Settings
expected: Open Settings. An "Actions" tab is visible. Clicking it shows a list of custom actions with Add/Edit/Delete controls.
result: pass

### 10. Create custom action
expected: In Actions settings, click Add. An editor sheet appears with fields for name, command, content filter regex, "replaces clipboard" toggle. Save creates the action.
result: pass

### 11. Custom action appears in context menu
expected: After creating a custom action, right-click a clipboard item. The custom action appears (in a "Custom Actions" submenu or similar).
result: pass

### 12. Action result notification
expected: Execute a built-in action (e.g. "Copy Uppercase"). A success notification or visual feedback confirms the action was performed.
result: pass

## Summary

total: 12
passed: 12
issues: 0
pending: 0
skipped: 0

## Gaps

[none yet]
