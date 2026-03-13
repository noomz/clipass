import SwiftUI
import SwiftData

/// Root SwiftUI view for the overlay panel content.
/// Hosts a search field, filtered clipboard list with keyboard navigation,
/// vibrancy background, and smooth show/hide animation.
struct ClipboardOverlayView: View {

    @Environment(\.modelContext) private var modelContext
    @Query(sort: \ClipboardItem.timestamp, order: .reverse) private var items: [ClipboardItem]

    @State private var searchText = ""
    @State private var selectedID: ClipboardItem.ID?
    @State private var showContent = false

    // MARK: - Filtered Items

    /// Items sorted with pinned first, then by timestamp descending, filtered by search text.
    private var filteredItems: [ClipboardItem] {
        let sorted = items.sorted { a, b in
            if a.isPinned != b.isPinned { return a.isPinned }
            return a.timestamp > b.timestamp
        }
        if searchText.isEmpty { return sorted }
        return sorted.filter { $0.content.localizedCaseInsensitiveContains(searchText) }
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            // Frosted glass vibrancy background
            VisualEffectView()

            // Content with animation
            if showContent {
                contentStack
                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
                    .animation(.easeOut(duration: 0.15), value: showContent)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .frame(width: 640, height: 400)
        .onAppear {
            showContent = true
            selectedID = filteredItems.first?.id
        }
        // Reset state when overlay is about to show (controller posts this before makeKeyAndOrderFront)
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("overlayWillShow"))) { _ in
            searchText = ""
            showContent = true
            selectedID = filteredItems.first?.id
        }
        // Auto-select first item whenever filtered list changes
        .onChange(of: filteredItems) { _, newItems in
            if selectedID == nil || !newItems.contains(where: { $0.id == selectedID }) {
                selectedID = newItems.first?.id
            }
        }
    }

    // MARK: - Content Stack

    private var contentStack: some View {
        VStack(spacing: 0) {
            // Search field — custom NSViewRepresentable handles:
            //   • Auto-focus (requests first-responder immediately)
            //   • Arrow key interception (↑/↓ move list selection)
            //   • ESC interception (dismisses overlay)
            //   • Return interception (pastes selected item)
            OverlaySearchField(
                text: $searchText,
                placeholder: "Search clipboard...",
                onArrowUp: moveSelectionUp,
                onArrowDown: moveSelectionDown,
                onEscape: { OverlayWindowController.shared.hide() },
                onReturn: pasteSelected
            )
            .frame(height: 44)
            .padding(.horizontal, 12)

            Divider()

            // Clipboard list — selection and scroll position are driven entirely by selectedID.
            // Arrow key events are handled by OverlaySearchField and update selectedID;
            // the ScrollViewReader auto-scrolls to keep the selected row visible.
            // Using ScrollView+ForEach (not List) so selection highlight renders correctly
            // even when the search field — not the list — holds first-responder status.
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(filteredItems) { item in
                            OverlayItemRow(
                                item: item,
                                isSelected: item.id == selectedID,
                                onTap: {
                                    selectedID = item.id
                                },
                                onDoubleTap: {
                                    selectedID = item.id
                                    pasteSelected()
                                }
                            )
                            .id(item.id)
                        }
                    }
                    .padding(.vertical, 4)
                }
                .onChange(of: selectedID) { _, newID in
                    if let id = newID {
                        withAnimation(.linear(duration: 0.1)) {
                            proxy.scrollTo(id, anchor: nil)
                        }
                    }
                }
            }

            Divider()

            // Bottom bar — item count
            HStack {
                Spacer()
                Text("\(filteredItems.count) item\(filteredItems.count == 1 ? "" : "s")")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
            }
        }
    }

    // MARK: - Keyboard Actions

    private func moveSelectionDown() {
        guard !filteredItems.isEmpty else { return }
        if let current = selectedID,
           let idx = filteredItems.firstIndex(where: { $0.id == current }),
           idx + 1 < filteredItems.count {
            selectedID = filteredItems[idx + 1].id
        } else {
            selectedID = filteredItems.first?.id
        }
    }

    private func moveSelectionUp() {
        guard !filteredItems.isEmpty else { return }
        if let current = selectedID,
           let idx = filteredItems.firstIndex(where: { $0.id == current }),
           idx > 0 {
            selectedID = filteredItems[idx - 1].id
        } else {
            selectedID = filteredItems.last?.id
        }
    }

    private func pasteSelected() {
        guard let selectedID,
              let item = filteredItems.first(where: { $0.id == selectedID }) else { return }
        OverlayWindowController.shared.pasteAndHide(content: item.content)
    }
}
