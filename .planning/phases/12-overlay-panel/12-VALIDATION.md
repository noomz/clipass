---
phase: 12
slug: overlay-panel
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-03-13
---

# Phase 12 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | None (no test targets in Package.swift) |
| **Config file** | None |
| **Quick run command** | `swift build` |
| **Full suite command** | `swift build` |
| **Estimated runtime** | ~30 seconds |

---

## Sampling Rate

- **After every task commit:** Run `swift build`
- **After every plan wave:** Run `swift build` + manual smoke test
- **Before `/gsd:verify-work`:** Full manual checklist must pass
- **Max feedback latency:** 30 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|-----------|-------------------|-------------|--------|
| 12-01-01 | 01 | 1 | OVRL-01 | manual | `swift build` | N/A | pending |
| 12-01-02 | 01 | 1 | OVRL-02 | manual | `swift build` | N/A | pending |
| 12-01-03 | 01 | 1 | OVRL-03 | manual | `swift build` | N/A | pending |
| 12-01-04 | 01 | 1 | OVRL-04 | manual | `swift build` | N/A | pending |
| 12-02-01 | 02 | 2 | OVRL-05 | manual | `swift build` | N/A | pending |
| 12-02-02 | 02 | 2 | OVRL-06 | manual | `swift build` | N/A | pending |
| 12-02-03 | 02 | 2 | OVRL-07 | manual | `swift build` | N/A | pending |
| 12-02-04 | 02 | 2 | OVRL-08 | manual | `swift build` | N/A | pending |
| 12-02-05 | 02 | 2 | OVRL-09 | manual | `swift build` | N/A | pending |

*Status: pending / green / red / flaky*

---

## Wave 0 Requirements

*Existing infrastructure covers all phase requirements. No test target exists — manual verification is the established pattern.*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Overlay hotkey summons panel | OVRL-01 | Requires global hotkey system interaction | Press configured hotkey, verify panel appears |
| ESC dismisses overlay | OVRL-02 | Requires UI interaction | Open overlay, press ESC, verify dismissed |
| Click outside dismisses | OVRL-03 | Requires UI interaction | Open overlay, click outside, verify dismissed |
| Toggle open/close | OVRL-04 | Requires UI state | Press hotkey twice, verify toggle behavior |
| Search focuses on open | OVRL-05 | Requires focus system | Open overlay, verify cursor in search field |
| Arrow keys + Return paste | OVRL-06 | Requires UI + pasteboard | Open overlay, arrow to item, press Return, verify paste |
| Frosted glass vibrancy | OVRL-07 | Visual only | Open overlay, verify frosted glass background |
| Smooth animation | OVRL-08 | Visual only | Open/close overlay, verify smooth fade/scale |
| Settings hotkey recorder | OVRL-09 | Requires UI | Open Settings, verify hotkey recorder works |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 30s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
