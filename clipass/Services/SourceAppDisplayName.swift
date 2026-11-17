import AppKit

extension ClipboardItem {
    @MainActor
    var sourceAppDisplayName: String? {
        guard let sourceApp else { return nil }
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: sourceApp),
              let bundle = Bundle(url: url) else { return sourceApp }
        return (bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String)
            ?? (bundle.object(forInfoDictionaryKey: "CFBundleName") as? String)
            ?? url.deletingPathExtension().lastPathComponent
    }
}
