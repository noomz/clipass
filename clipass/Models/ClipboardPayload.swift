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
            pasteboard.setData(png, forType: .png)
            if let tiff = NSBitmapImageRep(data: png)?.tiffRepresentation {
                pasteboard.setData(tiff, forType: .tiff)
            }
        }
    }
}
