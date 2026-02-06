# Release Notes

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
