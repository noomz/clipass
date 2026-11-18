import SwiftUI
import SwiftData
import AppKit

@MainActor
struct NativeBrowserCheckApp: App {
    @NSApplicationDelegateAdaptor(NativeBrowserChecks.CheckAppDelegate.self) private var delegate

    var body: some Scene {
        MenuBarExtra {
            ClipboardPopup(monitor: NativeBrowserChecks.popoverFixture.monitor,
                           onCopy: { NativeBrowserChecks.popoverFixture.copied = $0 })
                .modelContext(NativeBrowserChecks.popoverFixture.context)
                .background { NativeBrowserChecks.PopoverProbe() }
        } label: {
            Text("Clipass T3")
        }
        .menuBarExtraStyle(.window)
    }
}

@main
@MainActor
struct NativeBrowserChecks {
    static let popoverFixture = try! CaptureFixture()
    static let usesRealPopover = ProcessInfo.processInfo.environment["CLIPASS_CHECK_REAL_POPOVER"] == "1"
    static let manualPopover = ProcessInfo.processInfo.environment["CLIPASS_CHECK_MANUAL_POPOVER"] == "1"
    static weak var popoverProbe: NSView?

    struct PopoverProbe: NSViewRepresentable {
        func makeNSView(context: Context) -> NSView {
            let probe = NSView()
            NativeBrowserChecks.popoverProbe = probe
            return probe
        }

        func updateNSView(_ probe: NSView, context: Context) {}
    }

    static func main() {
        if usesRealPopover {
            NativeBrowserCheckApp.main()
        } else {
            let app = NSApplication.shared
            app.setActivationPolicy(.regular)
            let delegate = CheckAppDelegate()
            app.delegate = delegate
            withExtendedLifetime(delegate) { app.run() }
        }
    }

    final class CheckAppDelegate: NSObject, NSApplicationDelegate {
        func applicationDidFinishLaunching(_ notification: Notification) {
            NSApp.setActivationPolicy(.regular)
            let timeout = manualPopover ? 600 : 55
            DispatchQueue.global().asyncAfter(deadline: .now() + .seconds(timeout)) {
                fputs("FAIL: native checks exceeded \(timeout) seconds\n", stderr)
                exit(2)
            }
            Task { @MainActor in
                do {
                    if usesRealPopover {
                        try await exerciseSummon(isOverlay: false)
                        exit(0)
                    }
                    try renderTabs()
                    try await exerciseInterface(isOverlay: false)
                    try await exerciseInterface(isOverlay: true)
                    try await exerciseSummon(isOverlay: true)
                    if let fixturePath = ProcessInfo.processInfo.environment["CLIPASS_PARITY_FIXTURE"] {
                        let fixture = try Data(contentsOf: URL(fileURLWithPath: fixturePath))
                        let entries = try JSONDecoder().decode([FixtureEntry].self, from: fixture)
                        try await captureParity(entries, isOverlay: false)
                        try await captureParity(entries, isOverlay: true)
                    }
                    print("PASS: native popover and overlay layout, tabs, shared search, Copy, and empty states")
                    exit(0)
                } catch {
                    fputs("FAIL: \(error)\n", stderr)
                    exit(1)
                }
            }
        }
    }

    struct Failure: Error, CustomStringConvertible {
        let description: String
    }

    static func expect(_ condition: @autoclosure () -> Bool, _ message: String) throws {
        if !condition() { throw Failure(description: message) }
    }

    static func exerciseInterface(isOverlay: Bool) async throws {
        let name = isOverlay ? "overlay" : "popover"
        let container = try ModelContainer(
            for: ClipboardItem.self, TransformRule.self, Hook.self, IgnoredApp.self,
            IgnoredPattern.self, RedactionPattern.self, ContextAction.self, Tag.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let context = container.mainContext
        let old = ClipboardItem(content: "Older work notes", timestamp: Date(timeIntervalSince1970: 10), isPinned: true)
        let new = ClipboardItem(content: "Newest work notes", timestamp: Date(timeIntervalSince1970: 20))
        let tag = Tag(name: "Work")
        context.insert(old)
        context.insert(new)
        context.insert(tag)
        old.tags.append(tag)
        new.tags.append(tag)
        try context.save()

        var copied: String?
        let (host, window) = showInterface(isOverlay: isOverlay, context: context) { copied = $0 }
        defer { window.close() }
        try await waitForInterface(host)

        try expect(element("Recent", in: host) != nil, "\(name): Recent tab missing: \(text(in: host))")
        try expect(element("Pinned", in: host) != nil, "\(name): Pinned tab missing")
        guard let field = textField(in: host) else { throw Failure(description: "\(name): no native search field") }
        let expectedSize = isOverlay ? CGSize(width: 640, height: 420) : CGSize(width: 300, height: 356)
        try expect(host.bounds.size == expectedSize, "\(name): unexpected content size \(host.bounds.size)")
        let searchFrame = window.convertToScreen(field.convert(field.bounds, to: nil))
        let tabFrame = try textFrame("Recent", in: host)
        let rowFrame = try textFrame("Newest work notes", in: host)
        let copyLabel = isOverlay ? "Copy & close" : "Copy"
        let copyFrame = try textFrame(copyLabel, in: host)
        try expect(searchFrame.midY > tabFrame.midY && tabFrame.midY > rowFrame.midY && rowFrame.midY > copyFrame.midY,
                   "\(name): search, tabs, history and Copy are out of order")
        try capture(host, name: "\(name)-recent")
        try press(copyLabel, in: host)
        try await settle()
        try expect(copied == "Newest work notes", "\(name): visible Copy did not copy selection")

        try press("Pinned", in: host)
        try await settle()
        try expect(text(in: host).contains("Older work notes"), "\(name): pinned copy missing")
        try expect(!text(in: host).contains("Newest work notes"), "\(name): Pinned includes unpinned copy")

        try capture(host, name: "\(name)-pinned")
        window.makeFirstResponder(field)
        setQuery("tag:work work notes", field: field)
        try await settle()
        try press("Recent", in: host)
        try await settle()
        try expect(field.stringValue == "tag:work work notes", "\(name): tab change lost query")
        try expect(text(in: host).contains("Newest work notes"), "\(name): shared tag/text search failed")
        try expect(searchHasFocus(field, in: window), "\(name): tab change did not restore search focus")
        let newestFrame = try textFrame("Newest work notes", in: host)
        let olderFrame = try textFrame("Older work notes", in: host)
        try expect(newestFrame.midY > olderFrame.midY, "\(name): old pin promoted above newer copy")

        try clickText("Older work notes", in: host, window: window)
        try await settle()
        try expect(!searchHasFocus(field, in: window), "\(name): row click did not enter list")
        try press("Pinned", in: host)
        try await settle()
        try expect(!searchHasFocus(field, in: window), "\(name): tab change stole list focus")
        if isOverlay {
            guard let event = NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: [],
                                              timestamp: ProcessInfo.processInfo.systemUptime,
                                              windowNumber: window.windowNumber, context: nil,
                                              characters: "\r", charactersIgnoringModifiers: "\r",
                                              isARepeat: false, keyCode: 36) else {
                throw Failure(description: "Could not create Return key")
            }
            NSApp.postEvent(event, atStart: false)
            try await settle()
            try expect(copied == "Older work notes", "overlay: moving focus to list broke Return copy")
        }
        try press("Recent", in: host)
        try await settle()
        window.makeFirstResponder(field)

        setQuery("missing query", field: field)
        try await settle()
        try expect(text(in: host).contains("No matches"), "\(name): no-match explanation missing")
        try expect(!text(in: host).contains("Newest work notes"), "\(name): stale no-match row")
        guard let button = element(copyLabel, in: host) else { throw Failure(description: "\(name): Copy disappeared") }
        try expect(button.value(forKey: "accessibilityEnabled") as? Bool == false,
                   "\(name): no-match Copy is enabled")
        try capture(host, name: "\(name)-no-matches")
        try press("Clear Search", in: host)
        try await settle()
        try expect(field.stringValue.isEmpty, "\(name): Clear Search did not update field")
        try expect(text(in: host).contains("Newest work notes"), "\(name): Clear Search did not restore results")

        for index in 1...40 {
            context.insert(ClipboardItem(content: "Archive entry \(index)", timestamp: Date(timeIntervalSince1970: Double(-index))))
        }
        try context.save()
        try await settle()
        guard let scroll = scrollView(in: host), let document = scroll.documentView else {
            throw Failure(description: "\(name): no native history scroll view")
        }
        let clip = scroll.contentView
        scrollToBottom(scroll, document: document)
        try await settle()
        let viewport = window.convertToScreen(clip.convert(clip.bounds, to: nil))
        let scrolledFrame = try? textFrame("Newest work notes", in: host)
        try expect(scrolledFrame.map { !$0.intersects(viewport) } ?? true,
                   "\(name): newest row \(String(describing: scrolledFrame)) still intersects \(viewport) after scrolling to \(clip.bounds.origin) in \(document.frame)")
        setQuery("work", field: field)
        try await settle()
        let revealedFrame = try textFrame("Newest work notes", in: host)
        try expect(revealedFrame.intersects(viewport), "\(name): query change left selection offscreen")
        setQuery("", field: field)
        try await settle()
        try capture(host, name: "\(name)-query-reveal")

        old.isPinned = false
        try context.save()
        try await settle()
        try press("Pinned", in: host)
        try await settle()
        try expect(text(in: host).contains("No pinned items yet"), "\(name): empty Pinned explanation missing")
        try expect(!text(in: host).contains("Older work notes"), "\(name): stale unpinned row")
        try capture(host, name: "\(name)-empty-pinned")
        for item in try context.fetch(FetchDescriptor<ClipboardItem>()) { context.delete(item) }
        try context.save()
        try await settle()
        try expect(text(in: host).contains("Copy text to get started."), "\(name): empty-history explanation missing")
        try capture(host, name: "\(name)-empty-history")
        print("PASS: \(name)")
    }

    final class CheckPopoverWindow: NSWindow {
        override var canBecomeKey: Bool { true }
        override var canBecomeMain: Bool { true }
    }

    struct FixtureEntry: Decodable {
        let content: String
        let app: String
        let tags: [String]
        let minutes: Int
        let pinned: Bool?
    }

    static func captureParity(_ entries: [FixtureEntry], isOverlay: Bool) async throws {
        let name = isOverlay ? "overlay" : "popover"
        let container = try ModelContainer(
            for: ClipboardItem.self, TransformRule.self, Hook.self, IgnoredApp.self,
            IgnoredPattern.self, RedactionPattern.self, ContextAction.self, Tag.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let context = container.mainContext
        let now = Date()
        let tags = Dictionary(uniqueKeysWithValues: Set(entries.flatMap(\.tags)).map { name in
            let tag = Tag(name: name)
            context.insert(tag)
            return (name, tag)
        })
        for entry in entries {
            let item = ClipboardItem(content: entry.content, sourceApp: entry.app,
                                     timestamp: now.addingTimeInterval(TimeInterval(-60 * entry.minutes)),
                                     isPinned: entry.pinned ?? false)
            context.insert(item)
            item.tags = entry.tags.compactMap { tags[$0] }
        }
        try context.save()
        let (host, window) = showInterface(isOverlay: isOverlay, context: context) { _ in }
        defer { window.close() }
        try await waitForInterface(host)
        try capture(host, name: "\(name)-b-recent")
        try press("Pinned", in: host)
        try await settle()
        try capture(host, name: "\(name)-b-pinned")
        guard let field = textField(in: host) else { throw Failure(description: "\(name): no native search field") }
        try press("Recent", in: host)
        window.makeFirstResponder(field)
        setQuery("missing query", field: field)
        try await settle()
        try capture(host, name: "\(name)-b-no-matches")
    }

    static func showInterface(isOverlay: Bool, context: ModelContext,
                              monitor: ClipboardMonitor = ClipboardMonitor(), onCopy: @escaping (String) -> Void)
        -> (NSHostingView<AnyView>, NSWindow) {
        let panel = OverlayPanel()
        panel.shownAt = .distantFuture
        let root: AnyView
        if isOverlay {
            let themes = ThemeManager()
            themes.current = Theme.themes[.system]!
            root = AnyView(ClipboardOverlayView(panel: panel, monitor: monitor, onCopyAndClose: onCopy, onDismiss: { panel.orderOut(nil) })
                .environment(themes).modelContext(context))
        } else {
            root = AnyView(ClipboardPopup(monitor: monitor, onCopy: onCopy).modelContext(context))
        }
        let host = isOverlay ? panel.host(root) : NSHostingView(rootView: root)
        let window = isOverlay ? panel : CheckPopoverWindow(
            contentRect: NSRect(origin: NSPoint(x: 100, y: 100), size: ClipboardBrowserStyle.popoverSize),
            styleMask: [.borderless], backing: .buffered, defer: false
        )
        window.isReleasedWhenClosed = false
        window.appearance = NSAppearance(named: .aqua)
        if !isOverlay { window.contentView = host }
        window.center()
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
        return (host, window)
    }

    static func scrollToBottom(_ scroll: NSScrollView, document: NSView) {
        let clip = scroll.contentView
        let bottom = document.isFlipped ? document.frame.maxY - clip.bounds.height : document.frame.minY
        let proposed = NSRect(origin: NSPoint(x: clip.bounds.minX, y: bottom), size: clip.bounds.size)
        clip.scroll(to: clip.constrainBoundsRect(proposed).origin)
        scroll.reflectScrolledClipView(clip)
    }

    static func waitForInterface(_ host: NSView) async throws {
        for _ in 0..<20 {
            if element("Recent", in: host) != nil { break }
            try await Task.sleep(nanoseconds: 100_000_000)
        }
        try await settle()
    }

    static func renderTabs() throws {
        guard let directory = ProcessInfo.processInfo.environment["CLIPASS_NATIVE_RENDER_EVIDENCE"] else { return }
        for (name, scheme) in [("light", ColorScheme.light), ("dark", ColorScheme.dark)] {
            let renderer = ImageRenderer(content: ClipboardBrowserTabs(tab: .recent, onSelect: { _ in })
                .padding(.top, 8).frame(width: 300).background(.background)
                .environment(\.colorScheme, scheme)
                .environment(\.clipboardBrowserStyle, ClipboardBrowserStyle(compact: true, scheme: scheme)))
            renderer.scale = 2
            guard let image = renderer.nsImage, let tiff = image.tiffRepresentation,
                  let bitmap = NSBitmapImageRep(data: tiff),
                  let png = bitmap.representation(using: .png, properties: [:]) else {
                throw Failure(description: "Could not render \(name) tab controls")
            }
            try png.write(to: URL(fileURLWithPath: directory).appendingPathComponent("tabs-\(name).png"))
        }
    }

    static func searchHasFocus(_ field: NSTextField, in window: NSWindow) -> Bool {
        window.firstResponder === field || (field.currentEditor() != nil && window.firstResponder === field.currentEditor())
    }

    static func scrollView(in root: NSView) -> NSScrollView? {
        if let scroll = root as? NSScrollView { return scroll }
        return root.subviews.compactMap { scrollView(in: $0) }.first
    }

    static func textFrame(_ text: String, in host: NSView) throws -> NSRect {
        guard let node = elements(in: host).first(where: {
            attribute("accessibilityValue", of: $0) as? String == text ||
            (attribute("accessibilityLabel", of: $0) as? String)?.contains(text) == true
        }), node.responds(to: NSSelectorFromString("accessibilityFrame")),
              let frame = node.value(forKey: "accessibilityFrame") as? NSValue else {
            throw Failure(description: "No native frame for \(text)")
        }
        return frame.rectValue
    }

    static func clickText(_ text: String, in host: NSView, window: NSWindow) throws {
        let frame = try textFrame(text, in: host)
        let rect = window.convertFromScreen(frame)
        let location = NSPoint(x: rect.midX, y: rect.midY)
        for type in [NSEvent.EventType.leftMouseDown, .leftMouseUp] {
            guard let event = NSEvent.mouseEvent(with: type, location: location, modifierFlags: [],
                                                timestamp: ProcessInfo.processInfo.systemUptime,
                                                windowNumber: window.windowNumber, context: nil,
                                                eventNumber: 1, clickCount: 1, pressure: 1) else {
                throw Failure(description: "Could not create native row click")
            }
            window.sendEvent(event)
        }
    }

    static func settle() async throws {
        try await Task.sleep(nanoseconds: 300_000_000)
    }

    static func setQuery(_ query: String, field: NSTextField) {
        field.stringValue = query
        field.delegate?.controlTextDidChange?(Notification(name: NSControl.textDidChangeNotification, object: field))
    }

    // SwiftUI nodes implement these public AppKit selectors without adopting the full protocol.
    static func attribute(_ name: String, of object: NSObject) -> Any? {
        let selector = NSSelectorFromString(name)
        if object.responds(to: selector), let value = object.perform(selector)?.takeUnretainedValue() {
            return value
        }
        let suffix = String(name.dropFirst("accessibility".count))
        return object.accessibilityAttributeValue(NSAccessibility.Attribute(rawValue: "AX" + suffix))
    }

    static func elements(in root: NSObject, depth: Int = 0) -> [NSObject] {
        guard depth < 20 else { return [] }
        let children = ["accessibilityChildren", "accessibilityRows", "accessibilityContents"].flatMap {
            attribute($0, of: root) as? [NSObject] ?? []
        }
        var seen = Set<ObjectIdentifier>()
        return [root] + children.filter { seen.insert(ObjectIdentifier($0)).inserted && $0 !== root }
            .flatMap { elements(in: $0, depth: depth + 1) }
    }

    static func text(in host: NSView) -> String {
        elements(in: host).map {
            ((attribute("accessibilityLabel", of: $0) as? String) ?? "") + " " +
            ((attribute("accessibilityValue", of: $0) as? String) ?? "")
        }.joined(separator: "\n")
    }

    static func element(_ label: String, in host: NSView) -> NSObject? {
        elements(in: host).first { attribute("accessibilityLabel", of: $0) as? String == label }
    }

    static func press(_ label: String, in host: NSView) throws {
        let selector = NSSelectorFromString("accessibilityPerformPress")
        guard let target = element(label, in: host), target.responds(to: selector) else {
            throw Failure(description: "Missing actionable \(label): \(text(in: host))")
        }
        _ = target.perform(selector)
    }

    static func textField(in root: NSView) -> NSTextField? {
        if let field = root as? NSTextField, field.isEditable { return field }
        return root.subviews.compactMap { textField(in: $0) }.first
    }

    static func capture(_ host: NSView, name: String) throws {
        guard let directory = ProcessInfo.processInfo.environment["CLIPASS_NATIVE_EVIDENCE"],
              let window = host.window else { return }
        let url = URL(fileURLWithPath: directory).appendingPathComponent("\(name).png")
        let capture = Process()
        capture.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
        capture.arguments = ["-x", "-o", "-l", String(window.windowNumber), url.path]
        try capture.run()
        capture.waitUntilExit()
        try expect(capture.terminationStatus == 0, "Window screenshot failed. Allow Screen Recording or omit CLIPASS_NATIVE_EVIDENCE.")
    }
}
