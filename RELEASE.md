# Release Notes

## v1.5.2

Build pipeline update. No app changes.

### Changes

- **Release build** — releases now use SwiftPM's default build system and pass the Xcode SDK version to the linker. They no longer use the deprecated `--build-system native` option. The app still records the real SDK (27.2), so the menu bar popover stays translucent.

---

## v1.5.1

More overlay themes.

### Changes

- **21 new overlay themes** from noomz-themes: Catppuccin (Latte, Frappé, Macchiato, Mocha), Everforest, Flexoki, Gruvbox (each light and dark), Kawakawa, Kanagawa Wave, Modus Operandi (and Tinted), Primer (light and dark), Rosé Pine (main, Moon, Dawn, Dawn Contrast), and Tokyo Night Day. Choose one in Settings → Appearance, which now shows themes in a grid.
- Every imported theme keeps body text at 5.2:1 contrast or higher, dim text at 4.5:1, and placeholder text at 3:1.

### Fixes

- **Selected row text** — selected rows always used white text, which was hard to read on light themes. Each theme now sets its own selected-text color.

---

## v1.5.0

In-app updates and a native popover background.

### Changes

- **Check for Updates** — Settings → General → Updates has a "Check for Updates…" button and an automatic-check toggle, powered by Sparkle. Updates are EdDSA-signed and served from `https://noomz.github.io/clipass/appcast.xml`. Updates from 1.5.0 onward install from inside the app. 1.4.x users need to install 1.5.0 by hand once.

### Fixes

- **Opaque popover** — releases were built with SwiftPM's default build backend, which records the deployment target (macOS 14) as the SDK version. AppKit then applied old-SDK compatibility, drawing the menu bar popover opaque. Releases are now built with the native backend against the current Xcode SDK. The build script fails if the recorded SDK doesn't match.

---

## v1.4.1

Signed release and launch crash fix.

### Fixes

- **Crash on launch** — the overlay view read `OverlayWindowController.shared` from `onAppear` while that singleton was still initializing. On recent macOS, `NSHostingView` runs `onAppear` synchronously, so libdispatch trapped on a recursive lock. The view now receives its panel directly.
- **Shortcut recorder crash** — the KeyboardShortcuts resource bundle is now included in the app, so opening the shortcut recorder in Settings no longer asserts.

### Changes

- **Signed and notarized** — the app is signed with a Developer ID, uses the hardened runtime, and is notarized and stapled by Apple, so Gatekeeper opens it without warnings. It ships as a DMG and as a zip.

---

## v1.4

Overlay and hotkey fixes.

### Fixes

- **Toggle Clipboard hotkey opens the popup** — `NSApp.activate()` no longer presents `MenuBarExtra` on modern macOS for this LSUIElement app. The hotkey now clicks the status item, same as clicking the menu bar icon.
- **Overlay stays on-screen** — the panel is centered (slightly above mid-screen) and clamped to the visible frame so it no longer sits behind the menu bar.
- **First overlay summon is centered** — a leftover `{0, 0}` origin from panel init is ignored instead of pinning the window to the bottom-left.
- **Overlay remembers position** — last origin is saved and restored across summons.

### Changes

- **Follow mouse screen** (Settings → General → Overlay, default on) — the overlay opens on the display under the pointer and keeps your last offset on that display. Turn it off to keep the overlay on the last display you used.

### System Requirements

- macOS 14 (Sonoma) or later

---

## v1.0.0

Initial public release.

### Features

- **Menu Bar Clipboard Manager** - Lives in the macOS menu bar with a popup window for browsing clipboard history
- **Clipboard History** - Automatically captures and stores up to 100 text clipboard items with timestamps and source app tracking
- **Global Hotkey** - `Cmd+Shift+V` opens the clipboard popup from anywhere (powered by KeyboardShortcuts)
- **Real-Time Search** - Filter clipboard history with instant search
- **One-Click Re-Copy** - Click any history item to copy it back to the clipboard
- **Transform Rules** - Regex-based rules that automatically clean clipboard content before storing
  - Strip trailing whitespace (Terminal-specific and global)
  - Normalize Windows line endings to Unix
  - Customizable: add, edit, reorder, enable/disable rules
  - Scoped rules: apply only to content from specific apps (by bundle identifier)
- **Automation Hooks** - Execute shell commands when clipboard content matches a pattern
  - Content and source app passed via environment variables (`CLIPASS_CONTENT`, `CLIPASS_SOURCE_APP`)
  - Pattern matching via regex with optional app filtering
  - Asynchronous execution on background threads
- **Settings Window** - Tabbed interface for managing transform rules and hooks
- **Password Manager Filtering** - Ignores transient and concealed pasteboard types (e.g., 1Password, Bitwarden)
- **Duplicate Detection** - Skips storing consecutive identical clipboard entries
- **History Pruning** - Automatically removes oldest items when exceeding the 100-item limit

### System Requirements

- macOS 14 (Sonoma) or later

### Dependencies

- [KeyboardShortcuts](https://github.com/sindresorhus/KeyboardShortcuts) v2.4.0 by Sindre Sorhus (MIT)

### Known Limitations

- Text-only clipboard support (no images, files, or rich text)
- Clipboard polling at 500ms intervals (not event-driven)
- Hook execution is fire-and-forget with no timeout or output capture
- No import/export for rules and hooks
- No iCloud sync for history or settings
