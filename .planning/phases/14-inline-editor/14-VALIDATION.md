---
phase: 14
slug: inline-editor
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-03-19
---

# Phase 14 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | None — no test target exists (compile validation only) |
| **Config file** | None |
| **Quick run command** | `swift build` |
| **Full suite command** | `swift build` |
| **Estimated runtime** | ~15 seconds |

---

## Sampling Rate

- **After every task commit:** Run `swift build`
- **After every plan wave:** Run `swift build`
- **Before `/gsd:verify-work`:** Full suite must be green + manual UI verification
- **Max feedback latency:** 15 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|-----------|-------------------|-------------|--------|
| 14-01-01 | 01 | 1 | EDIT-01 | manual-only | `swift build` (compile check) | N/A | ⬜ pending |
| 14-01-02 | 01 | 1 | EDIT-02 | manual-only | `swift build` (compile check) | N/A | ⬜ pending |
| 14-01-03 | 01 | 1 | EDIT-03 | manual-only | `swift build` (compile check) | N/A | ⬜ pending |
| 14-01-04 | 01 | 1 | EDIT-04 | manual-only | `swift build` (compile check) | N/A | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

Existing infrastructure covers all phase requirements. No new test files needed.

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Pencil icon appears on hover/selection; clicking enters edit mode | EDIT-01 | UI interaction requires visual confirmation | Hover over row → pencil icon appears; click pencil → editor panel opens |
| Editor shows raw content; save persists to SwiftData; no duplicate | EDIT-02 | SwiftData round-trip + UI state requires runtime verification | Edit text, Cmd+Return → content updated in list and menu popup; no duplicate entry |
| First ESC cancels editor; second ESC dismisses overlay | EDIT-03 | Two-stage ESC requires keyboard interaction testing | Press ESC in editor → editor closes, list restored; press ESC again → overlay dismissed |
| Edited content appears in menu bar popup immediately | EDIT-04 | Cross-view sync requires visual verification | Edit item in overlay → click menu bar icon → same item shows updated content |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 15s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
