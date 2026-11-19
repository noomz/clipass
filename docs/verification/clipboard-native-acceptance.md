# T7 clipboard acceptance

Native acceptance passed on `mbp14` (macOS 27.2.1, build 26B131; Swift 6.3.2). The run used production sources from `42e6b90`, a disposable native harness, in-memory history, and a named test pasteboard. `mac_jr` was running but could not be reached over SSH. No production code changed.

## Native runtime

| Check | Result |
| --- | --- |
| `swift test` | 43 passed, 0 failed. |
| Hosted popover and native overlay | The harness exited 0 in the unlocked Kitty session. Both passed tabs, filtered navigation without wrapping, search editing and query retention, preview focus and viewport restoration, layered Escape, shortcut isolation, Return in preview, Copy, empty states, redaction, safe clear confirmation, and Undo (V7–V12, V14, V17). |
| Native overlay summon | Passed newest selection and visibility after reopening, reveal when the newest ID is unchanged, and capture without disturbing browsing (V1, V2, V4, V16). The harness uses a native `OverlayPanel` directly, not the production global hotkey. |
| Real `MenuBarExtra` popover | The harness exited 0. It browsed an older pinned copy, dismissed, captured a new fixture, and reopened with that fixture selected and visible. It then scrolled the newest fixture out of view without changing selection and confirmed the next reopen revealed it again. A capture while browsing kept the old selection, query, list focus, and viewport. Jump to latest worked, including after a recopy with an unchanged ID (V1, V2, V4, V16). |

The first real-popover run reached the live-capture scenario but stopped when `NSWindow.sendEvent` did not move focus from Search after a synthetic row click. The production row selection handler sets list focus and requests that the field editor resign. To test that path, the manual harness now reports the on-screen center of the visible row. A Kitty-launched `agent-desktop` pointer click at that point moved focus out of Search, and the remaining assertions passed with unchanged production code. The original run showed a harness input failure, not a reproduced app focus defect. The test does not isolate the exact reason direct `sendEvent` delivery failed in that run.

Re-run the hosted suite from an unlocked GUI terminal with `CLIPASS_NATIVE_SCREENSHOTS=1 bash scripts/verify-native-browser.sh`. Add `CLIPASS_CHECK_REAL_POPOVER=1` for the real menu-bar check. Follow the `ACTION`, `SCROLL`, and `ROWCLICK` prompts. The `ROWCLICK` coordinate is in screen points. The runtime logs from this run are `swift-test-final.log`, `parity-native.log`, and `alternate-harness.log` under `/tmp/clipass-t7.7lH4CB` on `mbp14`.

[Real popover after reopen](clipboard-t7/real-popover-reopen.png) shows the newly captured fixture selected under Recent with Search focused.

## Visual comparison

I opened the approved HTML snapshot at `?variant=B` in headless Chrome. The snapshot matched the SHA-256 in I.provenance. I used its 21 fictional entries for the native captures and compared Recent, Pinned, and no matches at 2× scale. The comparison sheets show approved B on the left and native on the right, in that order from top to bottom:

- [Popover comparison](clipboard-t7/popover.png), 300 × 356 pt per panel.
- [Global modal comparison](clipboard-t7/modal.png), 640 × 420 pt per panel.

Both native panels match B's dimensions, search and tab hierarchy, visible focus ring, chronological rows, blue checked selection, preview affordance, and disabled Copy in the no-results state. The modal keeps the wider metadata and action layout. The native controls are not pixel-identical: the popover retains transform and hook controls, the modal retains inline Edit, and the footer moves Preview next to Copy and uses context-dependent shortcut hints. The compact popover still truncates its secondary Return hint in the captured configuration; the primary Copy & close label is fully visible. These comparisons cover the listed states, not every hover or appearance variant.

Browser captures are a visual reference only. No prototype interaction result is counted toward native runtime acceptance.
