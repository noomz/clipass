# Phase 7: Display - Context

**Gathered:** 2026-02-07
**Status:** Ready for planning

<domain>
## Phase Boundary

Control how clipboard items appear in the menu preview. Users can configure truncation length, and sensitive content is redacted in the preview. Invisible characters are handled automatically. All formatting is display-only — full content is preserved in storage.

</domain>

<decisions>
## Implementation Decisions

### Preview truncation
- Default preview length: 80 characters
- Truncation indicator: Unicode ellipsis (…)
- Truncate at word boundary, not mid-word
- User can adjust truncation length via text field in Settings (not slider)

### Invisible characters
- Fixed behavior, not user-configurable
- Newlines: Strip entirely from preview
- Tabs: Strip entirely from preview
- Multiple consecutive spaces: Keep as-is (preserve exact spacing)

### Redaction patterns
- Enabled by default: API keys, credit card numbers
- Not enabled by default: Email addresses, phone numbers (user can enable)
- Redaction style: Partial mask (e.g., `j***@e***.com`, `sk-***...***`)
- Toggles: Grouped by category (PII, Credentials, etc.) rather than individual patterns
- Custom patterns: Users can add their own via regex input

### Settings UI layout
- Display settings get their own "Display" tab in Settings
- Redaction patterns shown in grouped sections by category
- Live preview: Show sample text with current redaction applied
- Custom regex patterns added via inline + button within the patterns list

### Claude's Discretion
- Exact regex patterns for detecting API keys, credit cards, etc.
- Category names and groupings for redaction patterns
- Sample text content for live preview
- Text field validation for truncation length (min/max bounds)

</decisions>

<specifics>
## Specific Ideas

- Partial mask style should show enough context to recognize the type (email domain hint, card type last 4 digits) while hiding the sensitive parts
- Live preview in Settings helps users understand what redaction does before seeing it in the menu

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

---

*Phase: 07-display*
*Context gathered: 2026-02-07*
