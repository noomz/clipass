import Foundation
import Sparkle

/// Sparkle runs only when the bundle carries an HTTPS feed and a 32-byte EdDSA public key.
/// `swift run` builds have no bundle Info.plist, so they skip the updater.
enum UpdateConfiguration {
    static func isValid(feed: String?, publicKey: String?) -> Bool {
        guard let feed, let url = URL(string: feed), url.host != nil,
              url.scheme?.lowercased() == "https",
              let publicKey, let keyData = Data(base64Encoded: publicKey), keyData.count == 32 else {
            return false
        }
        return true
    }
}

@MainActor
final class UpdateSettings: ObservableObject {
    static let shared = UpdateSettings()

    let controller: SPUStandardUpdaterController?
    private var observations: [NSKeyValueObservation] = []

    private init() {
        guard UpdateConfiguration.isValid(
            feed: Bundle.main.object(forInfoDictionaryKey: "SUFeedURL") as? String,
            publicKey: Bundle.main.object(forInfoDictionaryKey: "SUPublicEDKey") as? String
        ) else {
            controller = nil
            return
        }
        let controller = SPUStandardUpdaterController(
            startingUpdater: true, updaterDelegate: nil, userDriverDelegate: nil
        )
        self.controller = controller
        observations = [
            controller.updater.observe(\.canCheckForUpdates, options: [.new]) { [weak self] _, _ in
                DispatchQueue.main.async { self?.objectWillChange.send() }
            },
            controller.updater.observe(\.automaticallyChecksForUpdates, options: [.new]) { [weak self] _, _ in
                DispatchQueue.main.async { self?.objectWillChange.send() }
            },
        ]
    }
}
