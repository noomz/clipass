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
            // A full-size TIFF can be ~100 MB, so build it only when an app asks for TIFF.
            let item = NSPasteboardItem()
            item.setData(png, forType: .png)
            let provider = TIFFProvider(png: png)
            item.setDataProvider(provider, forTypes: [.tiff])
            TIFFProvider.current = provider
            pasteboard.writeObjects([item])
        }
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
