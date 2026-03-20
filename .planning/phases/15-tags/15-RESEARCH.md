# Phase 15: Tags - Research

**Researched:** 2026-03-20
**Domain:** SwiftData many-to-many relationships, macOS SwiftUI tag badges, context menu submenus, schema migration
**Confidence:** HIGH

## Summary

Phase 15 adds a Tags feature to clipass: colored tag labels that users can assign to clipboard items, display as badges on overlay rows, filter by in the search field, and manage in a dedicated Settings tab. The implementation touches four layers: (1) a new `Tag` SwiftData model with a many-to-many relationship to `ClipboardItem`, (2) UI badge rendering in both `OverlayItemRow` and `HistoryItemRow`, (3) a "Tag as..." context menu submenu in both row views, and (4) a new Tags settings tab following the established list+editor split-pane pattern.

The project already has all structural patterns needed — `@Model` persistence, `@Query` live binding, `@Environment(ThemeManager.self)` for colors, `sidebarAdaptable` TabView for settings, and context menu submenus (see `Copy As...` in `HistoryItemRow`). Adding the `Tag` model is a lightweight additive migration (SwiftData handles it automatically when the new type is added to `ModelContainer`). The main engineering risk is the HistoryItemRow context menu submenu bug (known SwiftUI issue: `Button` actions inside `Menu` within `.contextMenu` do NOT fire in `MenuBarExtra(.window)` panels) — the existing code already documents this and works around it by placing custom actions directly, not in a submenu.

**Primary recommendation:** Implement `Tag` as a standard SwiftData `@Model` with explicit `@Relationship(inverse:)` on one side; add `Tag` to the `ModelContainer` initializer for automatic additive migration; replicate the `Copy As...` menu approach exactly for "Tag as...", noting the MenuBarExtra context menu bug workaround.

---

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions
- Primary tag assignment interaction: context menu "Tag as..." submenu with checkmark toggles
- Available in BOTH overlay (right-click) and menu bar popup (`HistoryItemRow` context menu)
- Submenu lists all tags with checkmarks for assigned ones, plus "+ New Tag..." at bottom
- "+ New Tag..." triggers `NSAlert` with text field for name input, auto-assigns random color from palette
- No tag assignment in the inline editor — context menu only
- Tag badges on the SECOND line (metadata row) alongside source app and timestamp
- Style: colored dot + tag name in caption font (like GitHub labels)
- Max 3 visible tag badges per row, then "+N" overflow indicator
- Badges appear in BOTH overlay (`OverlayItemRow`) and menu bar popup (`HistoryItemRow`)
- `tag:name` prefix syntax in overlay search field (TAG-03)
- Multiple tag filters use OR logic: `tag:work tag:code` shows items with either tag
- Tag filters combine with free text: `tag:work hello` = items tagged 'work' AND containing 'hello'
- No autocomplete when typing `tag:` — user types full tag name manually
- New "Tags" tab in Settings (8th tab in `sidebarAdaptable` TabView)
- Layout: list + editor split pane (same pattern as Transforms/Actions tabs)
- Left side: tag list with colored dots, [+] [-] buttons
- Right side: name text field, preset color palette (8-10 colors), delete button
- Color picker: preset palette only (red, orange, yellow, green, blue, purple, pink, gray) — no system color picker
- No default starter tags — starts empty, users create what they need
- Deleting a tag requires confirmation alert: "Delete tag 'X'? This removes it from all items."

### Claude's Discretion
- Exact preset color hex values (should work well across all 5 themes)
- Tag model schema details (SwiftData implicit many-to-many already decided)
- Sort order of tags in context menu submenu and Settings list
- Exact badge spacing and layout within the metadata row
- Whether overflow "+N" is clickable or just informational

### Deferred Ideas (OUT OF SCOPE)
None — discussion stayed within phase scope
</user_constraints>

---

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| TAG-01 | User can add tags to clipboard items | Tag model + "Tag as..." context menu submenu with checkmark toggle pattern |
| TAG-02 | User can remove tags from clipboard items | Same "Tag as..." checkmark toggle removes assigned tag |
| TAG-03 | User can filter clipboard history by tag in overlay search (`tag:work`) | `filteredItems` in `ClipboardOverlayView` needs `tag:` prefix parsing with OR + text combine logic |
| TAG-04 | User can manage tags (rename, delete, set color) in Settings | New TagsView + TagEditorView following RulesView / ContextActionsView patterns |
| TAG-05 | Tags display as colored badges on overlay rows | `TagBadgeView` component inserted into metadata HStack in both `OverlayItemRow` and `HistoryItemRow` |
</phase_requirements>

---

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| SwiftData | macOS 14+ (already in project) | `Tag` @Model persistence, many-to-many with `ClipboardItem` | Project-wide persistence layer |
| SwiftUI | macOS 14+ (already in project) | All UI — badge views, settings tab, context menus | Project-wide UI framework |
| AppKit / NSAlert | macOS 14+ (already in project) | "+ New Tag..." name input dialog | Native macOS pattern already used in project |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| `@Bindable` (SwiftUI) | Swift 5.9+ | Editing `Tag` in settings editor pane | Required for mutating `@Model` objects inline without sheet dismissal |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| NSAlert for "+ New Tag..." | Custom SwiftUI sheet | NSAlert is native macOS feel; already documented as the decision |
| Preset color palette | System color picker | Preset is the decision; simpler, works across all 5 themes |
| Storing color as hex String | Storing as `Int` (RGB packed) | Both work; String is more readable and maps to existing `Color(hex:)` helper |

**Installation:** No new dependencies — all libraries already in the project.

---

## Architecture Patterns

### Recommended Project Structure
```
clipass/Models/
├── Tag.swift                  # new — @Model with name, colorHex, many-to-many with ClipboardItem
clipass/Views/
├── TagBadgeView.swift         # new — colored dot + name badge component
├── TagsView.swift             # new — Settings Tags tab (list + editor pane)
├── OverlayItemRow.swift       # modified — add TagBadgesRow to second metadata line
├── HistoryItemRow.swift       # modified — add "Tag as..." submenu + TagBadgesRow
├── ClipboardOverlayView.swift # modified — parse tag: prefix in filteredItems
├── SettingsView.swift         # modified — add 8th Tags tab
clipass/clipassApp.swift       # modified — add Tag.self to ModelContainer
```

### Pattern 1: SwiftData Many-to-Many Relationship

**What:** `Tag` model with array of `ClipboardItem`, `ClipboardItem` with `@Relationship(inverse:)` pointing back.

**When to use:** Any time both sides hold arrays of the other model.

**Example:**
```swift
// Tag.swift
// Source: https://www.hackingwithswift.com/quick-start/swiftdata/how-to-create-many-to-many-relationships
@Model
class Tag {
    var id: UUID = UUID()
    var name: String = ""
    var colorHex: String = "#3a7bd5"  // default blue; stored as hex
    var createdAt: Date = Date()

    // No @Relationship macro here — the other side declares inverse
    var items: [ClipboardItem] = []

    init(name: String, colorHex: String = "#3a7bd5") {
        self.name = name
        self.colorHex = colorHex
    }
}

// ClipboardItem.swift — add to existing @Model
@Relationship(inverse: \Tag.items)
var tags: [Tag] = []
```

**Critical:** Declare `@Relationship(inverse:)` on exactly ONE side. The default delete rule (`.nullify`) is correct — deleting a tag removes it from items but does not delete items.

### Pattern 2: Additive SwiftData Schema Migration

**What:** Adding `Tag` to `ModelContainer` triggers an automatic lightweight migration. SwiftData treats adding a new model type as a lightweight additive change.

**When to use:** Adding new `@Model` types or new properties with default values to an existing deployed schema.

**Example:**
```swift
// clipassApp.swift — add Tag.self to the list
modelContainer = try ModelContainer(
    for: ClipboardItem.self, TransformRule.self, Hook.self,
        IgnoredApp.self, IgnoredPattern.self, RedactionPattern.self,
        ContextAction.self, Tag.self   // <-- added
)
```

No `VersionedSchema` or `SchemaMigrationPlan` needed for this additive change. The existing error-recovery block (delete store on failure, retry) handles any edge case.

**Note on VersionedSchema:** Apple recommends eventually adopting `VersionedSchema` for production apps so future complex migrations have a baseline, but it is NOT required for this purely additive change.

### Pattern 3: Tag Badge Component

**What:** Reusable `TagBadgeView` — colored circle dot + tag name text in caption2 font. Fits the existing metadata HStack.

**Example:**
```swift
// TagBadgeView.swift
struct TagBadgeView: View {
    let tag: Tag
    let isSelected: Bool  // used to invert colors on row selection

    var body: some View {
        HStack(spacing: 3) {
            Circle()
                .fill(Color(hex: tag.colorHex))
                .frame(width: 6, height: 6)
            Text(tag.name)
                .font(.caption2)
                .foregroundColor(isSelected ? .white.opacity(0.85) : Color(hex: tag.colorHex))
        }
        .padding(.horizontal, 5)
        .padding(.vertical, 2)
        .background(
            Capsule()
                .fill(Color(hex: tag.colorHex).opacity(isSelected ? 0.3 : 0.15))
        )
    }
}
```

For the metadata row with max 3 badges + overflow:
```swift
// Inside OverlayItemRow metadata HStack
let visibleTags = Array(item.tags.prefix(3))
let overflowCount = item.tags.count - 3

HStack(spacing: 4) {
    ForEach(visibleTags) { tag in
        TagBadgeView(tag: tag, isSelected: isSelected)
    }
    if overflowCount > 0 {
        Text("+\(overflowCount)")
            .font(.caption2)
            .foregroundColor(isSelected ? .white.opacity(0.75) : theme.secondaryText)
    }
}
```

### Pattern 4: "Tag as..." Context Menu Submenu

**What:** A `Menu("Tag as...")` containing `Button` items per tag with checkmark toggles, plus a "+ New Tag..." button.

**CRITICAL KNOWN BUG:** Buttons inside `Menu` within `.contextMenu` do NOT fire in `MenuBarExtra(.window)` panels. The existing code documents this in `HistoryItemRow`:
```swift
// NOTE: Actions are placed directly in the context menu (not in a
// submenu) because Button actions inside a Menu within .contextMenu
// do not fire in MenuBarExtra(.window) panels — a known SwiftUI bug.
```

**Resolution for HistoryItemRow:** "Tag as..." with checkmarks must be implemented as flat context menu items (not wrapped in `Menu`), or accept that it only works in the overlay. Alternatively, each tag becomes a direct `Button` in the context menu with a prefix to indicate current state.

**Resolution for OverlayItemRow:** The overlay is an `NSPanel`, not a `MenuBarExtra`, so `Menu` submenus within `.contextMenu` work normally there. The submenu pattern can be used in `OverlayItemRow.contextMenu`.

**Working pattern for overlay (NSPanel — works fine):**
```swift
.contextMenu {
    Menu("Tag as...") {
        ForEach(allTags) { tag in
            Button(action: { toggleTag(tag, on: item) }) {
                Label(tag.name, systemImage: item.tags.contains(tag) ? "checkmark" : "")
            }
        }
        Divider()
        Button("+ New Tag...") { showNewTagAlert() }
    }
}
```

**Workaround for menu bar popup (MenuBarExtra — submenu buttons don't fire):**
```swift
.contextMenu {
    // Flat tag buttons: "✓ work" or "  work"
    ForEach(allTags) { tag in
        Button(item.tags.contains(tag) ? "✓ \(tag.name)" : "  \(tag.name)") {
            toggleTag(tag, on: item)
        }
    }
    Button("+ New Tag...") { showNewTagAlert() }
    Divider()
    // ... rest of menu
}
```

### Pattern 5: `tag:` Prefix Parsing in filteredItems

**What:** Parse `tag:name` tokens from `searchText`, apply OR logic for multiple tag tokens, AND with remaining free text.

**Example:**
```swift
// ClipboardOverlayView.swift — replace filteredItems computed property
private var filteredItems: [ClipboardItem] {
    let sorted = items.sorted { a, b in
        if a.isPinned != b.isPinned { return a.isPinned }
        return a.timestamp > b.timestamp
    }
    guard !searchText.isEmpty else { return sorted }

    // Parse tag: tokens
    let tokens = searchText.split(separator: " ").map(String.init)
    let tagTokens = tokens
        .filter { $0.lowercased().hasPrefix("tag:") }
        .map { String($0.dropFirst(4)).lowercased() }
    let textTokens = tokens
        .filter { !$0.lowercased().hasPrefix("tag:") }
        .joined(separator: " ")

    return sorted.filter { item in
        // Tag filter: any tag token matches (OR logic)
        let tagMatch: Bool
        if tagTokens.isEmpty {
            tagMatch = true
        } else {
            tagMatch = tagTokens.contains { tagName in
                item.tags.contains { $0.name.lowercased() == tagName }
            }
        }
        // Text filter: remaining text must match content
        let textMatch: Bool
        if textTokens.isEmpty {
            textMatch = true
        } else {
            textMatch = item.content.localizedCaseInsensitiveContains(textTokens)
        }
        return tagMatch && textMatch
    }
}
```

### Pattern 6: Settings Tags Tab — List + Editor Split Pane

**What:** Left pane shows tag list with [+] [-] buttons; selecting a tag shows name + color palette editor on the right. Inline editing via `@Bindable` (no sheet needed, unlike `RulesView`/`ContextActionsView`).

**Reference:** `ContextActionsView` uses sheets. The Tags tab should instead use inline split-pane editing similar to how a macOS Settings panel would work — `HSplitView` or manual `HStack` with a fixed left-pane width.

**Example structure:**
```swift
struct TagsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Tag.name) private var tags: [Tag]
    @State private var selectedTag: Tag?

    var body: some View {
        HStack(spacing: 0) {
            // Left pane: tag list
            VStack(spacing: 0) {
                List(selection: $selectedTag) {
                    ForEach(tags) { tag in
                        TagListRow(tag: tag)
                            .tag(tag)
                    }
                }
                Divider()
                HStack {
                    Button(action: addTag) { Image(systemName: "plus") }
                    Button(action: { deleteSelected() }) { Image(systemName: "minus") }
                        .disabled(selectedTag == nil)
                    Spacer()
                }
                .buttonStyle(.plain)
                .padding(6)
            }
            .frame(width: 180)

            Divider()

            // Right pane: editor
            if let tag = selectedTag {
                TagEditorPane(tag: tag, onDelete: deleteTag)
            } else {
                Text("Select a tag to edit")
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }
}
```

For the inline editor, use `@Bindable`:
```swift
struct TagEditorPane: View {
    @Bindable var tag: Tag  // @Bindable allows direct mutation of @Model
    let onDelete: (Tag) -> Void

    var body: some View {
        Form {
            TextField("Name", text: $tag.name)
                .textFieldStyle(.roundedBorder)
            TagColorPalette(selectedHex: $tag.colorHex)
        }
        Button("Delete Tag", role: .destructive) { onDelete(tag) }
    }
}
```

### Anti-Patterns to Avoid

- **Using `Color` directly in `@Model`:** SwiftData does not support `Color` or `NSColor` as stored properties. Store color as `String` (hex) and reconstruct with `Color(hex:)` — the project already has this extension in `Theme.swift`.
- **Declaring `@Relationship(inverse:)` on both sides:** This causes a "Circular reference" compiler error. Only one side declares the inverse.
- **Assuming submenu Buttons work in MenuBarExtra:** They don't. See Pattern 4 workaround.
- **Sorting `item.tags` non-deterministically:** Tags have no inherent order in the many-to-many; sort by name when rendering to avoid badge order jumping between renders.
- **Deleting a `Tag` without removing from items manually:** SwiftData's default `.nullify` delete rule handles this — deleting the `Tag` model automatically removes it from all `ClipboardItem.tags` arrays. No manual cleanup needed.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Tag color storage | Custom color serializer | Store hex String, use existing `Color(hex:)` from `Theme.swift` | Already exists in project |
| Tag confirmation dialog | Custom SwiftUI sheet alert | `NSAlert` (or SwiftUI `.confirmationDialog`) | Already used in project for destructive actions |
| Many-to-many join table | Manual join model | SwiftData implicit many-to-many via `@Relationship(inverse:)` | SwiftData handles join table internally |
| Schema migration for new Tag model | VersionedSchema + migration plan | Simply add `Tag.self` to `ModelContainer` — additive migration is automatic | Lightweight additive changes require no migration plan |

**Key insight:** The project's existing `Color(hex:)` extension, `@Model` patterns, and context menu structure cover almost everything. The only genuinely new component is `TagBadgeView`.

---

## Common Pitfalls

### Pitfall 1: Color Type in SwiftData Model
**What goes wrong:** Declaring `var color: Color` in a `@Model` class causes a compiler error or runtime crash — SwiftData cannot encode `SwiftUI.Color` or `AppKit.NSColor`.
**Why it happens:** SwiftData only persists Codable-conforming value types. `Color` is not Codable.
**How to avoid:** Store `var colorHex: String = "#3a7bd5"` and convert with `Color(hex: colorHex)` at render time.
**Warning signs:** Compiler warning "Type does not conform to PersistentModel" or runtime crash on schema build.

### Pitfall 2: MenuBarExtra Context Menu Submenu Bug
**What goes wrong:** Tapping a `Button` inside a `Menu` inside `.contextMenu` in a `MenuBarExtra(.window)` panel does nothing — the closure never fires.
**Why it happens:** Known SwiftUI bug in MenuBarExtra window mode. `HistoryItemRow` already documents this for custom actions.
**How to avoid:** In `HistoryItemRow`, render tag assignment as flat `Button` items (with text-prefix checkmarks), not inside a `Menu`. In `OverlayItemRow` (NSPanel), the full `Menu("Tag as...")` submenu works.
**Warning signs:** Tag toggle works in overlay but silently fails in menu bar popup.

### Pitfall 3: Relationship Declared on Both Sides
**What goes wrong:** Compiler error "Circular reference resolving attached macro 'Relationship'" if `@Relationship(inverse:)` appears on both `Tag.items` and `ClipboardItem.tags`.
**Why it happens:** The macro resolves both annotations and detects a cycle.
**How to avoid:** Declare `@Relationship(inverse: \Tag.items)` only on `ClipboardItem.tags`. Leave `Tag.items` as a plain `var items: [ClipboardItem] = []`.

### Pitfall 4: Non-Deterministic Badge Order
**What goes wrong:** Tag badges reorder between renders, looking unstable.
**Why it happens:** `item.tags` returns the array in SwiftData's internal order, which is not guaranteed stable across saves.
**How to avoid:** Sort by name before slicing: `item.tags.sorted { $0.name < $1.name }.prefix(3)`.

### Pitfall 5: Tag Deletion Side Effects
**What goes wrong:** After deleting a `Tag` from Settings, items that had the tag still show it in the badge row (stale reference).
**Why it happens:** If `.nullify` delete rule works correctly, this should not happen. But if the relationship is misconfigured (e.g., missing inverse), SwiftData may not cascade the nullification.
**How to avoid:** Verify the `@Relationship(inverse:)` is correct. After deletion, SwiftData's `.nullify` rule removes the tag from all `item.tags` arrays automatically.
**Warning signs:** Badges show a tag name for a tag that no longer exists in Settings list.

### Pitfall 6: `filteredItems` Breaking Existing Tests
**What goes wrong:** The new `tag:` parsing changes the behavior of `filteredItems` for all searches, not just tag searches.
**Why it happens:** If the token parsing is too aggressive (e.g., splits on spaces incorrectly), plain text searches may break.
**How to avoid:** The parsing only activates for tokens starting with `tag:`. A search with no `tag:` tokens falls through to the existing `localizedCaseInsensitiveContains` path unchanged.

---

## Code Examples

Verified patterns from existing codebase:

### Existing Color Hex Extension (Theme.swift — reuse directly)
```swift
// Source: clipass/Models/Theme.swift — already in project
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r = Double((int >> 16) & 0xFF) / 255.0
        let g = Double((int >>  8) & 0xFF) / 255.0
        let b = Double( int        & 0xFF) / 255.0
        self.init(red: r, green: g, blue: b)
    }
}
```

### Existing @Model Pattern (ContextAction.swift — follow exactly)
```swift
// Source: clipass/Models/ContextAction.swift
@Model
class ContextAction {
    var id: UUID = UUID()
    var name: String = ""
    // ... all properties with default values
}
```

### Existing sidebarAdaptable TabView Pattern (SettingsView.swift — add 8th tab)
```swift
// Source: clipass/Views/SettingsView.swift — macOS 15+ path
Tab("Tags", systemImage: "tag") {
    TagsView()
}
// Legacy path:
TagsView()
    .tabItem { Label("Tags", systemImage: "tag") }
```

### Existing @Bindable Usage (ContextActionsView.swift)
```swift
// Source: clipass/Views/ContextActionsView.swift
struct ContextActionRow: View {
    @Bindable var action: ContextAction  // mutates @Model inline
    ...
}
```

### Preset Color Palette Recommendation
Colors must work on all 5 themes (dark/light/solid/vibrancy backgrounds). Use saturated mid-range colors with sufficient contrast on both light and dark surfaces:

```swift
// Recommended preset hex values (Claude's discretion):
static let tagPresetColors: [String] = [
    "#e05252",  // red
    "#e0873a",  // orange
    "#d4c140",  // yellow
    "#4db86a",  // green
    "#3a8fd4",  // blue
    "#6b52d4",  // purple
    "#cc52a8",  // pink
    "#888888",  // gray
]
```

These are saturated enough to be legible as dot + capsule backgrounds (at 0.15 opacity) on dark overlays, and visible as dots on light backgrounds.

---

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Core Data NSManagedObject many-to-many with explicit join entity | SwiftData `@Relationship(inverse:)` implicit join | iOS 17 / macOS 14 (2023) | No explicit join table; SwiftData manages it |
| `VersionedSchema` required for all schema changes | Additive changes (new model, new defaulted property) handled automatically without migration plan | SwiftData initial release (2023) | Can add `Tag` model without `VersionedSchema` boilerplate |

**Deprecated/outdated:**
- Core Data style `NSManagedObjectID` relationship wiring: not needed in SwiftData
- `@Relationship(deleteRule: .cascade)` for tags: wrong for this use case — use `.nullify` (default) so deleting a tag doesn't delete clipboard items

---

## Open Questions

1. **Does the MenuBarExtra submenu bug affect `@available(macOS 15.0, *)` apps?**
   - What we know: Documented by existing project code as affecting `MenuBarExtra(.window)`. No version annotation on the workaround.
   - What's unclear: Whether the bug is fixed in macOS 15.
   - Recommendation: Apply the flat-button workaround in `HistoryItemRow` regardless; test on macOS 15 during verification and remove workaround if confirmed fixed.

2. **Tag sort order in context menu and Settings list**
   - What we know: Marked as Claude's discretion.
   - Recommendation: Sort alphabetically by name — predictable, no extra `order` field needed.

3. **Overflow "+N" badge — clickable or informational?**
   - What we know: Marked as Claude's discretion.
   - Recommendation: Make it non-interactive (informational only). A tap on "+N" badge in the overlay would need to open some UI to show all tags, which is out of scope for this phase.

---

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | None detected — no test target found in project |
| Config file | None |
| Quick run command | `xcodebuild test -scheme clipass -destination 'platform=macOS'` (if test target added) |
| Full suite command | Same |

No automated test infrastructure exists in this project. All validation is manual.

### Phase Requirements → Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| TAG-01 | Add tag via context menu | manual | n/a — no test target | ❌ |
| TAG-02 | Remove tag via context menu | manual | n/a — no test target | ❌ |
| TAG-03 | Filter `tag:work` in overlay search | manual | n/a — no test target | ❌ |
| TAG-04 | Rename, delete, set color in Settings > Tags | manual | n/a — no test target | ❌ |
| TAG-05 | Colored badges appear on overlay rows | manual | n/a — no test target | ❌ |

### Wave 0 Gaps
None — no test infrastructure exists and none is expected per project conventions. Manual verification against success criteria is the gate.

---

## Sources

### Primary (HIGH confidence)
- `clipass/Models/ClipboardItem.swift` — current model shape, confirms no `tags` relationship yet
- `clipass/Views/HistoryItemRow.swift` — MenuBarExtra submenu bug documented in code comment; `Copy As...` submenu pattern
- `clipass/Views/OverlayItemRow.swift` — metadata HStack structure where badges insert
- `clipass/Views/SettingsView.swift` — sidebarAdaptable TabView with 7 tabs; 8th tab slots in
- `clipass/Views/ClipboardOverlayView.swift` — `filteredItems` implementation to extend
- `clipass/Models/Theme.swift` — `Color(hex:)` extension and 5 theme definitions
- `clipass/clipassApp.swift` — `ModelContainer` initializer pattern; must add `Tag.self`
- [HackingWithSwift — SwiftData many-to-many](https://www.hackingwithswift.com/quick-start/swiftdata/how-to-create-many-to-many-relationships) — exact `@Relationship(inverse:)` pattern

### Secondary (MEDIUM confidence)
- [HackingWithSwift — Lightweight vs complex migrations](https://www.hackingwithswift.com/quick-start/swiftdata/lightweight-vs-complex-migrations) — confirms adding new model type is automatic lightweight migration
- [HackingWithSwift — Inferred vs explicit relationships](https://www.hackingwithswift.com/quick-start/swiftdata/inferred-vs-explicit-relationships) — confirms explicit `@Relationship(inverse:)` required for many-to-many

### Tertiary (LOW confidence — needs validation during implementation)
- MenuBarExtra submenu button bug: documented in project code; no official Apple bug report URL confirmed. Treat as real until proven fixed on target macOS version.

---

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — project uses SwiftData throughout; patterns are direct analogues of existing code
- Architecture: HIGH — all integration points are existing, well-understood code; new `Tag` model follows identical pattern to other models
- Pitfalls: HIGH for known pitfalls (color type, submenu bug, relationship direction); MEDIUM for migration (confirmed lightweight but not tested from this specific on-disk schema version)

**Research date:** 2026-03-20
**Valid until:** 2026-04-20 (stable SwiftData APIs, 30-day window)
