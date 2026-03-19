# Competitive Research: macOS Clipboard Managers

## 1. Maccy (maccy.app)

**Pricing:** Free, open-source (MIT license) — "It is and will always be free"
**Requires:** macOS Sonoma 14+

**Features:**
- Clipboard history with fast search
- Keyboard-first navigation (type to find, Enter to select)
- Password manager integration (auto-removes copied passwords)
- Lightweight, minimal footprint
- Native macOS UI
- Local-only storage

**Philosophy:** Deliberately minimal — avoids feature bloat, single-purpose design.

**What clipass already matches:** History, search, keyboard nav, password filtering, local-only
**What clipass does better:** Transform rules, external hooks, context actions, overlay UI, theming, inline editor

---

## 2. ClipBook (clipbook.app)

**Pricing:** Free 5-day trial, then paid subscription. Open source on GitHub.
**Requires:** macOS 12.0+

**Features:**
- Unlimited clipboard history
- Multi-type support: text, images, files, links, colors, emails
- Global shortcut: Shift+Cmd+V
- Quick paste shortcuts: Cmd+1-9 for first 9 items
- Edit text items (Cmd+E)
- Mark favorites (Cmd+S)
- Merge multiple text items (newline-separated)
- Copy-and-merge (Cmd+CC appends to previous item)
- Paste without formatting
- Paste multiple items simultaneously
- Post-paste actions (Enter, Tab, or nothing)
- Open links in browser (Option+Enter)
- OCR: Extract text from images (Shift+Cmd+C)
- Dark/light/system themes
- Resizable/movable window
- Collapsible preview pane (Cmd+P)
- App-specific ignore lists
- Pause/resume clipboard monitoring
- Clear history on quit option
- Per-screen position/size memory
- Hideable menu bar icon
- Launch at login
- No analytics/tracking

**What clipass is missing:**
- Favorites/starred items (clipass has pin, similar)
- Merge multiple items
- Copy-and-merge (Cmd+CC append)
- Paste without formatting
- Paste multiple items at once
- Post-paste actions (Enter/Tab after paste)
- OCR text extraction from images
- Collapsible preview pane
- Pause/resume monitoring
- Per-screen position memory
- Hideable menu bar icon

---

## 3. Paste (pasteapp.io)

**Pricing:** $3.99/month or $29.99/year (also on Setapp)
**Requires:** macOS, iOS, iPadOS

**Features:**
- Visual card-style clipboard history (rich previews)
- Pinboards: organize frequently-used snippets into collections
- Shared Pinboards (v5.0): collaborative clipboard via iCloud
- iCloud sync across Mac/iPhone/iPad
- Universal Clipboard compatible
- Power Search with filters by type, app, date
- OCR: search text inside screenshots
- Quick Look previews before pasting
- Drag and drop clippings into any app
- Rules to ignore sensitive content
- Multi-type: text, links, images, files
- Keyboard shortcuts for navigation

**What clipass is missing:**
- Visual card-style preview (rich visual layout)
- Pinboards/collections (clipass has pin but not organized boards)
- Drag and drop from history
- Quick Look previews
- OCR
- iCloud sync (explicitly out of scope)

---

## 4. Pastebot (tapbots.com/pastebot)

**Pricing:** Paid (one-time purchase), free trial available
**Requires:** macOS 10.14+

**Features:**
- Clipboard history with persistent storage
- Custom pasteboard groups for organizing clippings
- Keyboard shortcuts assigned to specific clippings
- Powerful text filters with live preview
- Filter application during paste
- Shareable/exportable filters
- Quick Paste Menu accessible from any app
- Search by content, app, date, data type
- Sequential paste queuing (paste items in order)
- iCloud sync across Macs
- Universal Clipboard compatible
- Multiple Quick Paste window styles
- Plain text paste option
- Release-to-paste
- Application blacklist

**What clipass is missing:**
- Custom groups/boards for organizing
- Text filters with live preview (clipass has transforms but no preview)
- Sequential paste queuing
- Release-to-paste
- Shareable/exportable filters

---

## Feature Gap Matrix

| Feature | clipass | Maccy | ClipBook | Paste | Pastebot |
|---------|---------|-------|----------|-------|----------|
| Clipboard history | Y | Y | Y | Y | Y |
| Search/filter | Y | Y | Y | Y | Y |
| Keyboard shortcuts | Y | Y | Y | Y | Y |
| Password filtering | Y | Y | Y | Y | Y |
| Transform rules | Y | - | - | - | Y (filters) |
| External hooks | Y | - | - | - | - |
| Context actions | Y | - | - | - | - |
| Overlay UI | Y | - | - | - | - |
| Theming | Y | - | Y | - | - |
| Inline editor | Y | - | Y | - | - |
| Pin/favorites | Y | - | Y | Y | - |
| Paste plain text | - | - | Y | - | Y |
| Paste multiple | - | - | Y | - | - |
| Merge items | - | - | Y | - | - |
| Copy-append | - | - | Y | - | - |
| OCR | - | - | Y | Y | - |
| Collections/boards | - | - | - | Y | Y |
| Drag & drop | - | - | - | Y | - |
| Sequential paste | - | - | - | - | Y |
| Post-paste action | - | - | Y | - | - |
| iCloud sync | - | - | - | Y | Y |
| iOS companion | - | - | - | Y | - |
| Preview pane | - | - | Y | Y | - |
| Pause monitoring | - | - | Y | - | - |
| Filter preview | - | - | - | - | Y |
| Hide menu icon | - | - | Y | - | - |

## clipass Unique Advantages (no competitor has)

1. **Transform rules engine** — regex-based auto-cleaning on paste (Pastebot has filters but not auto-apply on copy)
2. **External hooks** — shell script automation on clipboard change
3. **Smart context actions** — content-aware menu (URL, email, JSON, path detection)
4. **Overlay + Menu bar dual UI** — two access modes
5. **Free + open source** — vs paid competitors (except Maccy which is minimal)

## Top Feature Gaps to Close

### High Impact (competitors all have, clipass doesn't):
1. **Paste as plain text** — strip formatting on paste
2. **Preview pane** — see full content before pasting
3. **Collections/groups** — organize items beyond pin/unpin

### Medium Impact (differentiators from top competitors):
4. **Merge items** — combine multiple clipboard entries
5. **Copy-append (Cmd+CC)** — append to last copied item
6. **Sequential paste** — queue items, paste in order
7. **Post-paste actions** — auto-press Enter/Tab after paste
8. **Drag & drop** — drag items from history into apps

### Nice to Have:
9. **OCR text extraction** — extract text from copied images
10. **Pause/resume monitoring** — temporarily stop capturing
11. **Hide menu bar icon** — cleaner menu bar
12. **Transform live preview** — see transform result before applying
