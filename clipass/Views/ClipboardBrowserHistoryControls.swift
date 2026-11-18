import SwiftUI

struct ClipboardBrowserOverflow<Items: View>: View {
    let canClear: Bool
    let confirmClear: () -> Void
    @ViewBuilder var items: () -> Items

    var body: some View {
        Menu {
            items()
            Button("Clear Recent History…", role: .destructive, action: confirmClear)
                .disabled(!canClear)
        } label: {
            ClipboardBrowserIcon(symbol: "ellipsis")
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
        .accessibilityLabel("More actions")
        .help("More actions")
    }
}

struct ClipboardBrowserHistoryControls: ViewModifier {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.clipboardBrowserStyle) private var style
    let isConfirming: Bool
    let dismissConfirmation: () -> Void
    let historyChanged: () -> Void

    @State private var cleared: ClearedClipboardHistory?
    @State private var errorMessage: String?

    func body(content: Content) -> some View {
        VStack(spacing: 0) {
            content
            if cleared != nil || errorMessage != nil {
                HStack {
                    Text(errorMessage ?? "Recent history cleared.")
                        .foregroundStyle(style.ink)
                    Spacer()
                    if cleared != nil { Button("Undo", action: undo) }
                    Button {
                        cleared = nil
                        errorMessage = nil
                    } label: {
                        Image(systemName: "xmark")
                    }
                    .accessibilityLabel("Dismiss history notice")
                }
                .font(.system(size: 11))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
            }
        }
        .disabled(isConfirming)
        .accessibilityHidden(isConfirming)
        .overlay {
            if isConfirming {
                ZStack {
                    Color.black.opacity(0.22)
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Clear recent history?").font(.headline)
                        Text("Unpinned items will be removed. Pinned items will be kept.")
                            .fixedSize(horizontal: false, vertical: true)
                        HStack {
                            Spacer()
                            Button("Cancel", action: dismissConfirmation)
                                .keyboardShortcut(.defaultAction)
                            Button("Clear Recent", role: .destructive, action: clear)
                        }
                    }
                    .foregroundStyle(style.ink)
                    .padding(16)
                    .frame(maxWidth: 290)
                    .background(style.surface, in: RoundedRectangle(cornerRadius: 12))
                    .shadow(radius: 10)
                    .padding(12)
                }
            }
        }
    }

    private func clear() {
        dismissConfirmation()
        do {
            let history = try ClearedClipboardHistory.clear(in: modelContext)
            if history.count > 0 { cleared = history }
            errorMessage = nil
            historyChanged()
        } catch {
            errorMessage = "Couldn’t clear recent history."
        }
    }

    private func undo() {
        guard let cleared else { return }
        do {
            try cleared.restore(in: modelContext)
            self.cleared = nil
            errorMessage = nil
            historyChanged()
        } catch {
            errorMessage = "Couldn’t restore recent history."
        }
    }
}
