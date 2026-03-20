import SwiftUI
import SwiftData
import KeyboardShortcuts

extension KeyboardShortcuts.Name {
    static let toggleClipboard = Self("toggleClipboard", default: .init(.v, modifiers: [.command, .shift]))
    static let toggleOverlay = Self("toggleOverlay")  // No default — user configures in Settings
}

// Singleton to hold services and ensure single initialization
@MainActor
final class AppServices {
    static let shared = AppServices()

    let modelContainer: ModelContainer
    let clipboardMonitor = ClipboardMonitor()
    let transformEngine = TransformEngine()
    let hookEngine = HookEngine()
    let themeManager = ThemeManager()

    private var isInitialized = false

    private init() {
        do {
            modelContainer = try ModelContainer(for: ClipboardItem.self, TransformRule.self, Hook.self, IgnoredApp.self, IgnoredPattern.self, RedactionPattern.self, ContextAction.self, Tag.self)
        } catch {
            // Migration failed — delete corrupt store and retry
            let storeURL = URL.applicationSupportDirectory.appending(path: "default.store")
            for suffix in ["", "-wal", "-shm"] {
                let url = storeURL.deletingLastPathComponent().appending(path: "default.store\(suffix)")
                try? FileManager.default.removeItem(at: url)
            }
            do {
                modelContainer = try ModelContainer(for: ClipboardItem.self, TransformRule.self, Hook.self, IgnoredApp.self, IgnoredPattern.self, RedactionPattern.self, ContextAction.self, Tag.self)
            } catch {
                fatalError("Failed to create ModelContainer even after resetting store: \(error)")
            }
        }

        // Initialize after a brief delay to ensure main context is ready
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [self] in
            self.initialize()
        }
    }

    func initialize() {
        guard !isInitialized else { return }
        isInitialized = true

        let context = modelContainer.mainContext

        clipboardMonitor.setModelContext(context)
        transformEngine.setModelContext(context)
        hookEngine.setModelContext(context)
        clipboardMonitor.setTransformEngine(transformEngine)
        clipboardMonitor.setHookEngine(hookEngine)

        TransformEngine.createDefaultRulesIfNeeded(context: context)
        DisplayFormatter.createDefaultPatternsIfNeeded(context: context)

        clipboardMonitor.start()
        startAutoCleanupTimer()

        KeyboardShortcuts.onKeyUp(for: .toggleClipboard) {
            NSApp.activate(ignoringOtherApps: true)
        }

        KeyboardShortcuts.onKeyUp(for: .toggleOverlay) {
            // DO NOT call NSApp.activate() — overlay is non-activating by design
            OverlayWindowController.shared.toggle()
        }

        // Force-initialize the singleton at launch so the panel is ready before first use.
        _ = OverlayWindowController.shared
    }

    private func startAutoCleanupTimer() {
        performAutoCleanup()
        Timer.scheduledTimer(withTimeInterval: 3600, repeats: true) { [weak self] _ in
            DispatchQueue.main.async {
                self?.performAutoCleanup()
            }
        }
    }

    private func performAutoCleanup() {
        let days = UserDefaults.standard.integer(forKey: "autoCleanupDays")
        guard days > 0 else { return }

        guard let cutoffDate = Calendar.current.date(byAdding: .day, value: -days, to: Date()) else { return }
        let context = modelContainer.mainContext
        let predicate = #Predicate<ClipboardItem> { $0.timestamp < cutoffDate && !$0.isPinned }
        let descriptor = FetchDescriptor<ClipboardItem>(predicate: predicate)

        guard let oldItems = try? context.fetch(descriptor) else { return }
        for item in oldItems {
            context.delete(item)
        }
        if !oldItems.isEmpty {
            try? context.save()
        }
    }
}

@main
struct clipassApp: App {
    private var services = AppServices.shared

    init() {
        // Prevent macOS from automatically terminating the app
        // when there are no visible windows (menu bar apps have none).
        // Matches the pattern from exmen to survive sleep/wake cycles.
        ProcessInfo.processInfo.disableAutomaticTermination("Menu bar app must remain running")
        ProcessInfo.processInfo.disableSuddenTermination()
    }

    var body: some Scene {
        MenuBarExtra("clipass", systemImage: "doc.on.clipboard") {
            ClipboardPopup(monitor: services.clipboardMonitor)
                .modelContext(services.modelContainer.mainContext)
        }
        .menuBarExtraStyle(.window)

        Window("Settings", id: "settings") {
            SettingsView()
                .modelContext(services.modelContainer.mainContext)
                .environment(services.themeManager)
        }
        .windowResizability(.contentSize)
        .windowToolbarStyle(.unified)
    }
}
