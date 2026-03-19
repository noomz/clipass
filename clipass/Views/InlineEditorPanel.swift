import SwiftUI

/// Bottom panel container for inline clipboard item editing.
///
/// Holds a scrollable monospace NSTextView (via EditorTextView) with Cancel and Save buttons.
/// Appears at the bottom of ClipboardOverlayView when editingItemID != nil.
/// The editor auto-focuses when the panel appears (isActive: true).
struct InlineEditorPanel: View {

    @Binding var content: String
    var theme: Theme
    var onSave: () -> Void
    var onCancel: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Monospace editor — NSTextView via NSViewRepresentable for reliable
            // focus management in a non-activating NSPanel (Phase 12 pattern)
            EditorTextView(
                text: $content,
                theme: theme,
                isActive: true,
                onCommit: onSave,
                onCancel: onCancel
            )
            .padding(4)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(theme.primaryText.opacity(0.04))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(theme.secondaryText.opacity(0.3), lineWidth: 1)
            )
            .padding(.horizontal, 12)
            .padding(.top, 10)
            .padding(.bottom, 6)

            // Button row
            HStack {
                Button("Cancel") {
                    onCancel()
                }
                .buttonStyle(.plain)
                .font(.system(size: theme.bodyFontSize - 1))
                .foregroundColor(theme.secondaryText)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .contentShape(Rectangle())

                Spacer()

                Button("Save") {
                    onSave()
                }
                .buttonStyle(.plain)
                .font(.system(size: theme.bodyFontSize - 1, weight: .medium))
                .foregroundColor(.white)
                .padding(.horizontal, 14)
                .padding(.vertical, 5)
                .background(
                    RoundedRectangle(cornerRadius: 5)
                        .fill(theme.accentColor)
                )
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 10)
        }
        .background(theme.searchFieldBackground.opacity(0.85))
    }
}
