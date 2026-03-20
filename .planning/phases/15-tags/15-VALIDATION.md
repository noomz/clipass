---
phase: 15
slug: tags
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-03-20
---

# Phase 15 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | Swift Testing / XCTest (macOS native) |
| **Config file** | Package.swift (testTarget) |
| **Quick run command** | `swift test --filter TagTests` |
| **Full suite command** | `swift test` |
| **Estimated runtime** | ~15 seconds |

---

## Sampling Rate

- **After every task commit:** Run `swift test --filter TagTests`
- **After every plan wave:** Run `swift test`
- **Before `/gsd:verify-work`:** Full suite must be green
- **Max feedback latency:** 15 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|-----------|-------------------|-------------|--------|
| 15-01-01 | 01 | 1 | TAG-01, TAG-02 | unit | `swift test --filter TagModelTests` | ❌ W0 | ⬜ pending |
| 15-01-02 | 01 | 1 | TAG-04 | unit | `swift test --filter TagModelTests` | ❌ W0 | ⬜ pending |
| 15-02-01 | 02 | 2 | TAG-05 | manual | Visual inspection | N/A | ⬜ pending |
| 15-02-02 | 02 | 2 | TAG-01, TAG-02 | manual | Context menu interaction | N/A | ⬜ pending |
| 15-02-03 | 02 | 2 | TAG-03 | manual | Search field `tag:work` | N/A | ⬜ pending |
| 15-02-04 | 02 | 2 | TAG-04 | manual | Settings > Tags tab | N/A | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `clipassTests/TagModelTests.swift` — stubs for TAG-01, TAG-02, TAG-04 (Tag CRUD, many-to-many relationship)
- Existing test infrastructure covers build verification

*Note: UI-heavy phase — most verification is manual (SwiftUI context menus, overlay badges, Settings tab).*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Tag badges display on overlay rows | TAG-05 | SwiftUI visual rendering | Open overlay, verify colored dot + name badges on tagged items |
| "Tag as..." context menu | TAG-01, TAG-02 | SwiftUI context menu interaction | Right-click item, verify submenu with checkmarks |
| `tag:work` search filter | TAG-03 | Overlay search field interaction | Type `tag:work` in overlay, verify filtered results |
| Settings > Tags tab | TAG-04 | SwiftUI settings interaction | Open Settings, verify list+editor, rename, color, delete with confirmation |
| "+ New Tag..." inline creation | TAG-01 | NSAlert interaction | Right-click > Tag as... > + New Tag..., verify alert and tag creation |
| Tags in menu bar popup | TAG-05 | MenuBarExtra rendering | Open menu bar popup, verify badges on tagged items |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 15s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
