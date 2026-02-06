# clipass

A macOS menu bar clipboard manager with intelligent transforms and automation hooks.

clipass lives in your menu bar, monitors the system clipboard, stores text history, and can automatically clean up clipboard content using regex-based rules. It also supports triggering external shell commands when clipboard content matches certain patterns.

## Features

- **Clipboard History** - Stores up to 100 recent text items with one-click re-copy
- **Global Hotkey** - `Cmd+Shift+V` to open the popup (customizable)
- **Search** - Real-time filtering across your clipboard history
- **Transform Rules** - Regex-based rules that automatically clean clipboard content (e.g., strip trailing whitespace, normalize line endings)
- **Automation Hooks** - Execute shell commands when clipboard content matches a pattern, with clipboard content available via `$CLIPASS_CONTENT` and `$CLIPASS_SOURCE_APP` environment variables
- **Password Manager Aware** - Ignores transient/concealed pasteboard types from password managers
- **Settings Window** - Tabbed UI for managing transform rules and hooks

## Requirements

- macOS 14 (Sonoma) or later
- Swift 5.9+

## Building

clipass uses Swift Package Manager:

```bash
# Clone the repository
git clone https://github.com/noomz/clipass.git
cd clipass

# Build
swift build

# Build for release
swift build -c release
```

The built binary will be at `.build/release/clipass`.

To run directly:

```bash
swift run
```

## Usage

1. Launch clipass - it appears as a clipboard icon in your menu bar
2. Copy text normally - clipass captures it in the background
3. Click the menu bar icon or press `Cmd+Shift+V` to open the popup
4. Click any history item to copy it back to the clipboard
5. Use the search field to filter history

### Transform Rules

Transform rules automatically modify clipboard content using regex patterns. clipass ships with three default rules:

| Rule | Pattern | Effect |
|------|---------|--------|
| Strip Terminal trailing whitespace | `\s+$` | Removes trailing whitespace from Terminal copies |
| Strip trailing whitespace | `\s+$` | Removes trailing whitespace from all apps |
| Normalize line endings | `\r\n` | Converts Windows line endings to Unix |

You can add, edit, disable, or reorder rules in the Settings window. Rules can be scoped to specific source apps by bundle identifier (e.g., `com.apple.Terminal`).

### Automation Hooks

Hooks execute shell commands when clipboard content matches a regex pattern. The clipboard content and source app are passed via environment variables:

- `CLIPASS_CONTENT` - The clipboard text
- `CLIPASS_SOURCE_APP` - Bundle identifier of the source app

Example: Log all clipboard changes to a file:

```bash
echo "$CLIPASS_CONTENT" >> ~/clipboard.log
```

Hooks can also be filtered by source app bundle identifier and are executed asynchronously in the background.

## Architecture

```
clipass/
├── clipassApp.swift          # App entry point, service wiring
├── Models/
│   ├── ClipboardItem.swift   # Clipboard history item (SwiftData)
│   ├── TransformRule.swift   # Regex transform rule (SwiftData)
│   └── Hook.swift            # Automation hook (SwiftData)
├── Services/
│   ├── ClipboardMonitor.swift  # Clipboard polling & event dispatch
│   ├── TransformEngine.swift   # Regex transform pipeline
│   └── HookEngine.swift        # External command execution
└── Views/
    ├── ClipboardPopup.swift    # Menu bar popup UI
    ├── HistoryItemRow.swift    # History item row
    ├── SettingsView.swift      # Tabbed settings container
    ├── RulesView.swift         # Transform rules list
    ├── RuleEditorView.swift    # Rule editor form
    ├── HooksView.swift         # Hooks list
    └── HookEditorView.swift    # Hook editor form
```

Built with SwiftUI, SwiftData, and [KeyboardShortcuts](https://github.com/sindresorhus/KeyboardShortcuts).

## License

[MIT](LICENSE)
