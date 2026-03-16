---
phase: 13
slug: theme-system
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-03-16
---

# Phase 13 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | None — no test target exists in Package.swift |
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
| 13-01-01 | 01 | 1 | THME-01 | compile | `swift build` | N/A | ⬜ pending |
| 13-01-02 | 01 | 1 | THME-01 | compile | `swift build` | N/A | ⬜ pending |
| 13-01-03 | 01 | 1 | THME-02 | manual-only | Manual UI verification | N/A | ⬜ pending |
| 13-01-04 | 01 | 1 | THME-03 | manual-only | Manual — relaunch app | N/A | ⬜ pending |
| 13-01-05 | 01 | 1 | THME-04 | manual-only | Manual UI verification | N/A | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

Existing infrastructure covers all phase requirements. No test target exists in Package.swift — adding one is out of scope (no test infrastructure in prior phases). Compile-time validation via `swift build` is the automated gate.

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Appearance tab visible in Settings with 4 themes | THME-02 | UI layout verification | Open Settings > Appearance tab, confirm Dark/Light/Midnight/Nord visible |
| Theme selection applies instantly to overlay | THME-02 | Visual rendering check | Select each theme, verify overlay colors change immediately |
| Selected theme persists across restart | THME-03 | App lifecycle test | Select theme, quit app, relaunch, verify same theme active |
| Mini preview cards match theme palettes | THME-04 | Visual fidelity check | Compare preview card colors against actual theme application |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 15s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
