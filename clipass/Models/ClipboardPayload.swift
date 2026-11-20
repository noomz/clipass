import AppKit

enum ClipboardPayload: Equatable {
    case text(String)
    case image(Data)

    func write(to pasteboard: NSPasteboard) {
        pasteboard.clearContents()
        switch self {
        case .text(let text):
            pasteboard.setString(text, forType: .string)
        case .image(let png):
            let offered = dragItem(for: png)
            TIFFProvider.current = offered.provider
            pasteboard.writeObjects([offered.item])
        }
    }

    /// What a drop target receives. Text stays text. An existing file path also offers that file.
    /// An image offers the stored PNG and a lazy TIFF, plus a file URL when one was written.
    /// This does not touch the general pasteboard. Copy still does that.
    func dragItem(fileExists: (String) -> Bool = { FileManager.default.fileExists(atPath: $0) },
                  imageFileURL: (Data) -> URL? = ClipboardDragFiles.writeImage) -> ClipboardDragItem {
        switch self {
        case .text(let text):
            let item = NSPasteboardItem()
            item.setString(text, forType: .string)
            if let file = Self.existingFileURL(in: text, fileExists: fileExists) {
                item.setString(file.absoluteString, forType: .fileURL)
            } else if let link = Self.webURL(in: text) {
                item.setString(link.absoluteString, forType: .URL)
            }
            return ClipboardDragItem(item: item, provider: nil)
        case .image(let png):
            let offered = dragItem(for: png)
            if let file = imageFileURL(png) {
                offered.item.setString(file.absoluteString, forType: .fileURL)
            }
            return offered
        }
    }

    private func dragItem(for png: Data) -> ClipboardDragItem {
        let item = NSPasteboardItem()
        item.setData(png, forType: .png)
        let provider = TIFFProvider(png: png)
        item.setDataProvider(provider, forTypes: [.tiff])
        return ClipboardDragItem(item: item, provider: provider)
    }

    static func existingFileURL(in text: String, fileExists: (String) -> Bool) -> URL? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !trimmed.contains("\n"), !trimmed.contains("\r") else { return nil }
        guard trimmed.hasPrefix("/") || trimmed.hasPrefix("~/") else { return nil }
        let expanded = (trimmed as NSString).expandingTildeInPath
        guard fileExists(expanded) else { return nil }
        return URL(fileURLWithPath: expanded)
    }

    static func webURL(in text: String) -> URL? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.contains("\n"), !trimmed.contains("\r"),
              let url = URL(string: trimmed), let scheme = url.scheme?.lowercased(),
              scheme == "http" || scheme == "https", url.host != nil else { return nil }
        return url
    }
}

/// Retains the TIFF provider the pasteboard item does not.
final class ClipboardDragItem {
    let item: NSPasteboardItem
    fileprivate let provider: TIFFProvider?

    fileprivate init(item: NSPasteboardItem, provider: TIFFProvider?) {
        self.item = item
        self.provider = provider
    }
}

private final class TIFFProvider: NSObject, NSPasteboardItemDataProvider {
    // The pasteboard item does not keep its provider alive.
    static var current: TIFFProvider?

    let png: Data

    init(png: Data) { self.png = png }

    func pasteboard(_ pasteboard: NSPasteboard?, item: NSPasteboardItem, provideDataForType type: NSPasteboard.PasteboardType) {
        if let tiff = NSBitmapImageRep(data: png)?.tiffRepresentation { item.setData(tiff, forType: .tiff) }
    }
}
