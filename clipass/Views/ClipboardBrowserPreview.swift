import ImageIO
import SwiftUI

extension View {
    func clipboardPreview(
        _ item: ClipboardItem?, tags: [UUID: [TagInfo]], patterns: [RedactionPattern],
        focus: FocusState<ClipboardBrowserState.Focus?>.Binding
    ) -> some View {
        opacity(item == nil ? 1 : 0)
            .disabled(item != nil)
            .allowsHitTesting(item == nil)
            .accessibilityHidden(item != nil)
            .overlay {
                if let item {
                    ClipboardBrowserPreview(item: item, tags: tags[item.id] ?? [], patterns: patterns, focus: focus)
                        .id(item.id)
                }
            }
    }
}

private struct ClipboardBrowserPreview: View {
    let item: ClipboardItem
    let tags: [TagInfo]
    let patterns: [RedactionPattern]
    let focus: FocusState<ClipboardBrowserState.Focus?>.Binding
    @Environment(\.clipboardBrowserStyle) private var style
    @State private var image: ClipboardPreviewImage?

    private var metadata: [String] {
        var parts = [item.sourceAppDisplayName ?? "Unknown app", item.timestamp.formatted(date: .abbreviated, time: .shortened)]
        if let image { parts.append("\(image.width) × \(image.height) px") }
        return parts
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Preview")
                .font(.system(size: 12, weight: .semibold))
                .accessibilityAddTraits(.isHeader)
            Text(metadata.joined(separator: " · "))
                .font(.system(size: 10))
                .foregroundStyle(style.muted)
            if !tags.isEmpty {
                Text(tags.map { "#\($0.name)" }.joined(separator: " "))
                    .font(.system(size: 10))
                    .foregroundStyle(style.muted)
            }
            ScrollView {
                if let image {
                    Image(image.picture, scale: image.scale, label: Text(item.content))
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: CGFloat(image.width) / image.scale, maxHeight: CGFloat(image.height) / image.scale)
                        .frame(maxWidth: .infinity)
                        .padding(8)
                } else if !item.isImage {
                    Text(DisplayFormatter.redact(item.content, patterns: patterns))
                        .font(.system(size: 12, design: .monospaced))
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(8)
                }
            }
            .background(style.searchFill, in: RoundedRectangle(cornerRadius: 6))
            .focusable()
            .focused(focus, equals: .preview)
            .accessibilityLabel("Preview content")
        }
        .foregroundStyle(style.ink)
        .padding(.horizontal, 12)
        .padding(.bottom, 6)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .task(id: item.id) {
            // imageData is a SwiftData read, so it stays on main; decoding a large image does not.
            guard let data = item.imageData else { return }
            image = await Task.detached(priority: .userInitiated) { ClipboardPreviewImage(data) }.value
        }
    }
}

private struct ClipboardPreviewImage {
    static let maxPixels = 1600

    let picture: CGImage
    let width: Int
    let height: Int
    let scale: CGFloat

    init?(_ data: Data) {
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: Self.maxPixels,
        ]
        guard let size = ClipboardCapture.pixelSize(of: data),
              let source = CGImageSourceCreateWithData(data as CFData, nil),
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let picture = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else { return nil }
        self.picture = picture
        width = size.width
        height = size.height
        // Keep the original's point size, as NSImage would: a 144-dpi screenshot is 2 px per point.
        let dpi = properties[kCGImagePropertyDPIWidth] as? CGFloat ?? 72
        scale = dpi / 72 * CGFloat(picture.width) / CGFloat(size.width)
    }
}

struct ClipboardRowPreviewButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ClipboardBrowserIcon(symbol: "eye")
        }
        .buttonStyle(.borderless)
        .accessibilityLabel("Preview selected item")
        .help("Preview selected item")
    }
}
