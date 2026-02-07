# Phase 7: Display - Research

**Researched:** 2026-02-07
**Domain:** Text formatting, regex pattern matching, SwiftUI settings, sensitive data detection
**Confidence:** HIGH

## Summary

Phase 7 implements display formatting for clipboard previews: truncation, invisible character handling, and sensitive content redaction. The user has locked decisions on behavior (80-char default, word boundary truncation, partial masking style) leaving implementation details to Claude's discretion (exact regex patterns, category groupings, sample text).

The codebase already has a working Regex pattern system (via `TransformEngine` and `IgnoredPatternEditorView`) using Swift's modern `Regex` type. The same pattern can be adapted for redaction. The main technical challenge is implementing partial masking that reveals enough context to recognize the content type while hiding sensitive parts.

**Primary recommendation:** Create a `DisplayFormatter` utility that applies formatting transformations (strip invisibles, truncate, redact) to `ClipboardItem.content` for display purposes only. Store redaction patterns in SwiftData with category grouping. Add "Display" tab to Settings.

## Standard Stack

The established libraries/tools for this domain:

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| Swift Regex | Swift 5.7+ | Pattern matching | Native to Swift, already used in codebase |
| SwiftUI | iOS 16+/macOS 13+ | Settings UI | Already used throughout |
| SwiftData | iOS 17+/macOS 14+ | Persist redaction patterns | Already used for all models |
| @AppStorage | SwiftUI | Store simple preferences | Native SwiftUI, syncs with UserDefaults |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| Foundation Regex | - | Regex compilation/matching | For complex pattern operations |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| @AppStorage | SwiftData for all settings | Overkill for simple values like truncation length |
| Custom regex engine | Third-party lib | No benefit, Swift Regex is excellent |

**Installation:**
No new dependencies needed. All required functionality available in existing stack.

## Architecture Patterns

### Recommended Project Structure
```
clipass/
├── Models/
│   └── RedactionPattern.swift      # NEW: SwiftData model for patterns
├── Services/
│   └── DisplayFormatter.swift      # NEW: Formatting utility
└── Views/
    ├── SettingsView.swift          # MODIFY: Add Display tab
    ├── DisplaySettingsView.swift   # NEW: Display settings UI
    ├── RedactionPatternsView.swift # NEW: Pattern list with categories
    └── HistoryItemRow.swift        # MODIFY: Use DisplayFormatter
```

### Pattern 1: Display-Only Formatting
**What:** Apply formatting transformations for display while preserving original content
**When to use:** When showing content in UI that differs from stored content
**Example:**
```swift
// In HistoryItemRow.swift
struct HistoryItemRow: View {
    let item: ClipboardItem
    @AppStorage("previewTruncationLength") private var truncationLength = 80
    
    var displayContent: String {
        DisplayFormatter.shared.format(
            item.content,
            truncationLength: truncationLength
        )
    }
    
    var body: some View {
        Text(displayContent)
        // ... item.content is unchanged for clipboard operations
    }
}
```

### Pattern 2: Partial Masking Strategy
**What:** Show enough context to identify content type while hiding sensitive parts
**When to use:** Redacting emails, API keys, credit cards
**Example:**
```swift
// Email: j***@e***.com - show first char, domain hint, TLD
// Credit card: ****-****-****-1234 - show last 4 only (standard)
// API key: sk-***...*** - show prefix, mask middle, show format hint

func partialMask(_ input: String, pattern: RedactionPattern) -> String {
    // Implementation depends on pattern category
    switch pattern.category {
    case .email:
        // Extract local part and domain
        // Mask: firstChar*** @ domainHint.tld
    case .creditCard:
        // Standard last-4 masking
    case .apiKey:
        // Show prefix, mask middle
    }
}
```

### Pattern 3: Category-Based Pattern Grouping
**What:** Group redaction patterns by category for cleaner UI
**When to use:** Settings UI for pattern management
**Example:**
```swift
enum RedactionCategory: String, CaseIterable, Codable {
    case credentials = "Credentials"
    case pii = "Personal Information"
    case financial = "Financial"
    case custom = "Custom Patterns"
}

@Model
class RedactionPattern {
    var name: String
    var pattern: String
    var category: RedactionCategory
    var isEnabled: Bool
    var isBuiltIn: Bool  // Can't delete built-in patterns
    var maskStyle: MaskStyle
}
```

### Anti-Patterns to Avoid
- **Modifying original content:** Never alter `ClipboardItem.content` - formatting is display-only
- **Greedy regex patterns:** Patterns that match too broadly cause false positives
- **Complex nested regex:** Hard to debug; use simple patterns per type
- **Blocking UI with regex:** Run expensive pattern matching off main thread if needed

## Don't Hand-Roll

Problems that look simple but have existing solutions:

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| API key detection | Custom heuristics | Established patterns from gitleaks | Hundreds of edge cases already solved |
| Credit card validation | Manual Luhn check | Regex pattern + format check | Complex variants (Amex, Visa, etc.) |
| Email detection | Simple regex | RFC-compliant pattern | Unicode domains, plus signs, subdomains |
| Word boundary truncation | Character loop | `String.split` + `joined` | Handle Unicode grapheme clusters |

**Key insight:** Sensitive data detection is a solved problem. Use patterns from security tools like gitleaks that have been battle-tested against real-world data.

## Common Pitfalls

### Pitfall 1: Regex Performance on Long Text
**What goes wrong:** Long clipboard content causes UI lag during redaction
**Why it happens:** Complex regex patterns are O(n) or worse on each character
**How to avoid:** 
- Limit redaction to first N characters of content
- Cache compiled regex patterns
- Use simple prefix checks before expensive regex
**Warning signs:** UI stutters when scrolling history

### Pitfall 2: Over-Matching API Keys
**What goes wrong:** Normal base64 strings flagged as API keys
**Why it happens:** Generic patterns like `[A-Za-z0-9]{32}` match too much
**How to avoid:**
- Use prefix-based patterns (`sk-`, `ghp_`, `AKIA`)
- Require specific formatting (dashes, underscores)
- Default to conservative patterns, let users add aggressive ones
**Warning signs:** Users disable redaction because too many false positives

### Pitfall 3: Unicode Word Boundary Issues
**What goes wrong:** Truncation breaks in middle of emoji or accented character
**Why it happens:** Counting bytes or UTF-16 code units instead of graphemes
**How to avoid:**
- Use Swift's native String indexing (handles graphemes)
- Find word boundaries with `String.split`
- Never slice with raw integer indices
**Warning signs:** Truncated text shows replacement characters (�)

### Pitfall 4: Inconsistent Masking Formats
**What goes wrong:** Users can't recognize what was redacted
**Why it happens:** Each pattern type masked differently without clear convention
**How to avoid:**
- Define mask format per category (email: `a***@d***.com`, card: `****-1234`)
- Show category icon alongside masked content
- Use consistent placeholder (`***`) across types
**Warning signs:** Users copy redacted content thinking it's real

### Pitfall 5: Settings Not Persisting
**What goes wrong:** Truncation length resets on app restart
**Why it happens:** Using @State instead of @AppStorage for preferences
**How to avoid:**
- Use @AppStorage for simple settings (ints, bools, strings)
- Use SwiftData for complex settings (pattern lists)
- Test persistence across app restarts
**Warning signs:** Settings reset unexpectedly

## Code Examples

Verified patterns from authoritative sources:

### Stripping Invisible Characters
```swift
// Strip newlines and tabs from preview (per CONTEXT.md decision)
extension String {
    var displayClean: String {
        self.replacingOccurrences(of: "\n", with: "")
            .replacingOccurrences(of: "\r", with: "")
            .replacingOccurrences(of: "\t", with: "")
        // Note: Multiple spaces kept as-is per decision
    }
}
```

### Word-Boundary Truncation
```swift
// Truncate at word boundary with ellipsis
func truncateAtWordBoundary(_ text: String, maxLength: Int) -> String {
    guard text.count > maxLength else { return text }
    
    let truncated = String(text.prefix(maxLength))
    
    // Find last space for word boundary
    if let lastSpace = truncated.lastIndex(of: " "),
       lastSpace > truncated.startIndex {
        return String(truncated[..<lastSpace]) + "\u{2026}" // Unicode ellipsis
    }
    
    // No space found - truncate at maxLength
    return truncated + "\u{2026}"
}
```

### Credit Card Detection (Source: OWASP)
```swift
// OWASP credit card pattern (Visa, MC, Amex, Discover)
// Source: https://owasp.org/www-community/OWASP_Validation_Regex_Repository
let creditCardPattern = #"((4\d{3})|(5[1-5]\d{2})|(6011)|(7\d{3}))-?\d{4}-?\d{4}-?\d{4}|3[4,7]\d{13}"#

// Partial mask: show last 4 digits only
func maskCreditCard(_ card: String) -> String {
    let digitsOnly = card.filter { $0.isNumber }
    guard digitsOnly.count >= 4 else { return "****" }
    let last4 = String(digitsOnly.suffix(4))
    return "****-****-****-\(last4)"
}
```

### Email Detection (Source: OWASP)
```swift
// OWASP email pattern
// Source: https://owasp.org/www-community/OWASP_Validation_Regex_Repository
let emailPattern = #"[a-zA-Z0-9_+&*-]+(?:\.[a-zA-Z0-9_+&*-]+)*@(?:[a-zA-Z0-9-]+\.)+[a-zA-Z]{2,}"#

// Partial mask: j***@e***.com
func maskEmail(_ email: String) -> String {
    guard let atIndex = email.firstIndex(of: "@") else { return "***@***.***" }
    
    let local = String(email[..<atIndex])
    let domain = String(email[email.index(after: atIndex)...])
    
    let maskedLocal = local.isEmpty ? "***" : "\(local.first!)***"
    
    // Handle domain (e.g., "example.com" -> "e***.com")
    let parts = domain.split(separator: ".")
    guard parts.count >= 2 else { return "\(maskedLocal)@***" }
    
    let domainName = String(parts[0])
    let tld = parts[1...]
    let maskedDomain = domainName.isEmpty ? "***" : "\(domainName.first!)***"
    
    return "\(maskedLocal)@\(maskedDomain).\(tld.joined(separator: "."))"
}
```

### API Key Patterns (Source: gitleaks)
```swift
// Common API key prefixes - HIGH confidence patterns
// Source: https://github.com/zricethezav/gitleaks
struct APIKeyPatterns {
    // OpenAI (most common for developers)
    static let openai = #"sk-(?:proj|svcacct|admin)-[A-Za-z0-9_-]{20,}T3BlbkFJ[A-Za-z0-9_-]{20,}"#
    
    // GitHub tokens
    static let githubPAT = #"ghp_[0-9a-zA-Z]{36}"#
    static let githubOAuth = #"gho_[0-9a-zA-Z]{36}"#
    static let githubApp = #"(?:ghu|ghs)_[0-9a-zA-Z]{36}"#
    
    // AWS
    static let awsAccessKey = #"(?:A3T[A-Z0-9]|AKIA|ASIA|ABIA|ACCA)[A-Z2-7]{16}"#
    
    // Stripe
    static let stripe = #"(?:sk|rk)_(?:test|live|prod)_[a-zA-Z0-9]{10,99}"#
    
    // Anthropic
    static let anthropic = #"sk-ant-api03-[a-zA-Z0-9_\-]{93}AA"#
    
    // Generic (catches many but has false positives)
    static let genericSecret = #"(?i)(?:api[_-]?key|secret|token|password)[=:]\s*['\"]?[a-zA-Z0-9_-]{16,}['\"]?"#
}

// Mask API key: show prefix, hide rest
func maskAPIKey(_ key: String) -> String {
    // Find prefix (e.g., "sk-", "ghp_", "AKIA")
    let prefixPatterns = ["sk-", "ghp_", "gho_", "ghu_", "ghs_", "AKIA", "rk_"]
    
    for prefix in prefixPatterns {
        if key.hasPrefix(prefix) {
            return "\(prefix)***...***"
        }
    }
    
    // Generic: show first 4, hide rest
    if key.count > 8 {
        return "\(key.prefix(4))***...***"
    }
    return "***"
}
```

### SwiftUI Settings with @AppStorage
```swift
// Display settings using @AppStorage for persistence
struct DisplaySettingsView: View {
    @AppStorage("previewTruncationLength") private var truncationLength = 80
    @AppStorage("redactionEnabled") private var redactionEnabled = true
    
    var body: some View {
        Form {
            Section("Preview") {
                HStack {
                    Text("Truncation length")
                    Spacer()
                    TextField("", value: $truncationLength, format: .number)
                        .frame(width: 60)
                        .textFieldStyle(.roundedBorder)
                        .multilineTextAlignment(.trailing)
                    Text("characters")
                        .foregroundColor(.secondary)
                }
            }
            
            Section("Redaction") {
                Toggle("Enable sensitive content redaction", isOn: $redactionEnabled)
            }
        }
        .formStyle(.grouped)
    }
}
```

### Live Preview Component
```swift
// Live preview of redaction in Settings
struct RedactionPreviewView: View {
    let sampleText: String
    @Binding var patternsEnabled: [String: Bool]
    
    private var previewText: String {
        DisplayFormatter.shared.format(
            sampleText,
            enabledPatterns: patternsEnabled
        )
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Preview")
                .font(.caption)
                .foregroundColor(.secondary)
            
            Text(previewText)
                .font(.system(.body, design: .monospaced))
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.secondary.opacity(0.1))
                .cornerRadius(8)
        }
    }
}

// Sample text for live preview
let samplePreviewText = """
Contact: john.doe@example.com
API Key: sk-xxxx-REDACTED
Card: 4111-1111-1111-1234
Phone: (555) 123-4567
"""
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| NSRegularExpression | Swift Regex | Swift 5.7 (2022) | Cleaner syntax, better performance |
| UserDefaults direct | @AppStorage | iOS 14 (2020) | Automatic SwiftUI binding |
| Manual string indexing | String grapheme clusters | Swift 4 (2017) | Unicode safety |

**Deprecated/outdated:**
- `NSRegularExpression`: Still works but Swift `Regex` is cleaner
- Manual regex escaping: Use `Regex` literal syntax or `try Regex(string)`

## Open Questions

Things that couldn't be fully resolved:

1. **US Phone Number Pattern Scope**
   - What we know: OWASP has US phone pattern `^\D?(\d{3})\D?\D?(\d{3})\D?(\d{4})$`
   - What's unclear: Should we include international formats? (+44, +81, etc.)
   - Recommendation: Start with US format only, let users add international as custom patterns

2. **Regex Performance Threshold**
   - What we know: Complex patterns can be slow on long text
   - What's unclear: At what text length should we limit redaction?
   - Recommendation: Test with 10KB+ text, add truncation limit if needed (redact first 1000 chars only)

3. **Category Icon Design**
   - What we know: SF Symbols has `creditcard`, `envelope`, `key`
   - What's unclear: Best symbols for each category
   - Recommendation: Use `key.fill` for credentials, `person.fill` for PII, `creditcard.fill` for financial

## Sources

### Primary (HIGH confidence)
- Swift String/Regex documentation - String handling, Unicode safety
- OWASP Validation Regex Repository - Email, credit card patterns
  - https://owasp.org/www-community/OWASP_Validation_Regex_Repository
- gitleaks configuration - API key patterns (OpenAI, GitHub, AWS, Stripe)
  - https://github.com/zricethezav/gitleaks/blob/master/config/gitleaks.toml

### Secondary (MEDIUM confidence)
- Existing codebase patterns (TransformEngine, IgnoredPatternEditorView)
- SwiftUI @AppStorage usage patterns

### Tertiary (LOW confidence)
- None - all critical patterns verified with authoritative sources

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - Using existing codebase patterns
- Architecture: HIGH - Follows established patterns in codebase
- Regex patterns: HIGH - Sourced from OWASP and gitleaks (security-focused projects)
- Pitfalls: MEDIUM - Based on common regex/UI issues

**Research date:** 2026-02-07
**Valid until:** 2026-03-07 (30 days - stable domain)

---
*Phase: 07-display*
*Research completed: 2026-02-07*
