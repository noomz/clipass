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
    @FocusState private var searchFocused: Bool
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
            searchFocused = true
            showContent = true
            selectedID = filteredItems.first?.id
        }
        // Reset state when overlay is about to show (controller posts this before makeKeyAndOrderFront)
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("overlayWillShow"))) { _ in
            searchText = ""
            showContent = true
            searchFocused = true
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
            // Search field
            TextField("Search clipboard...", text: $searchText)
                .textFieldStyle(.plain)
                .font(.body)
                .padding(12)
                .focused($searchFocused)

            Divider()

            // Clipboard list with selection binding
            List(filteredItems, selection: $selectedID) { item in
                OverlayItemRow(item: item)
                    .tag(item.id)
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .onKeyPress(.return) {
                guard let selectedID,
                      let item = filteredItems.first(where: { $0.id == selectedID }) else {
                    return .ignored
                }
                OverlayWindowController.shared.pasteAndHide(content: item.content)
                return .handled
            }
            .onKeyPress(.escape) {
                OverlayWindowController.shared.hide()
                return .handled
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
}
