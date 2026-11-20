import AppKit
import ObjectiveC
import SwiftUI

/// One drag at a time. The source window has to stay in the hierarchy until the drop,
/// or AppKit cancels the session. OverlayPanel defers its own resign. Every other
/// source window, including the menu-bar popover, suppresses hide until the drag ends.
final class ClipboardDragGate {
    static let shared = ClipboardDragGate()

    private(set) var isActive = false
    private var overlayResign: OverlayPanel?
    private var suppressed: [WeakBox] = []

    func begin(window: NSWindow?) {
        isActive = true
        overlayResign = nil
        suppressed = []
        guard let window, !(window is OverlayPanel) else { return }
        ClipboardDragHold.install(on: window)
    }

    func noteOverlayResign(_ panel: OverlayPanel) {
        guard isActive else { return }
        overlayResign = panel
    }

    func noteSuppressedClose(_ window: NSWindow) {
        guard isActive, !suppressed.contains(where: { $0.window === window }) else { return }
        suppressed.append(WeakBox(window))
    }

    /// A drop dismisses the source. A cancel dismisses the overlay only if it already resigned.
    /// A cancelled popover stays open so the drag can be tried again.
    func end(operation: NSDragOperation) {
        let dropped = !operation.isEmpty
        let panel = overlayResign
        let windows = suppressed.compactMap(\.window)
        overlayResign = nil
        suppressed = []
        isActive = false
        panel?.dismissAfterDrag(restoreFocus: !dropped)
        for window in windows {
            if dropped {
                ClipboardDragHold.close(window)
            } else {
                ClipboardDragHold.restore(window)
            }
        }
    }
}

private final class WeakBox {
    weak var window: NSWindow?
    init(_ window: NSWindow) { self.window = window }
}

enum ClipboardDragFiles {
    static func writeImage(_ png: Data) -> URL? {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("clipass-drag", isDirectory: true)
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            prune(directory)
            let url = directory.appendingPathComponent("Image-\(UUID().uuidString).png")
            try png.write(to: url, options: .atomic)
            return url
        } catch {
            return nil
        }
    }

    private static func prune(_ directory: URL) {
        let cutoff = Date().addingTimeInterval(-86_400)
        let files = (try? FileManager.default.contentsOfDirectory(
            at: directory, includingPropertiesForKeys: [.contentModificationDateKey])) ?? []
        for file in files {
            let modified = (try? file.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
            if modified < cutoff { try? FileManager.default.removeItem(at: file) }
        }
    }
}

enum ClipboardDragHold {
    private static var originalClassKey: UInt8 = 0

    static func install(on window: NSWindow) {
        let current: AnyClass = object_getClass(window)!
        guard !NSStringFromClass(current).hasPrefix("ClipassDragHold_") else { return }
        let subclass: AnyClass = holdClass(of: current)
        objc_setAssociatedObject(window, &originalClassKey, NSStringFromClass(current), .OBJC_ASSOCIATION_RETAIN)
        object_setClass(window, subclass)
    }

    static func restore(_ window: NSWindow) {
        guard let name = objc_getAssociatedObject(window, &originalClassKey) as? String,
              let original = NSClassFromString(name) else { return }
        object_setClass(window, original)
    }

    static func close(_ window: NSWindow) {
        restore(window)
        window.orderOut(nil)
    }

    private static func holdClass(of original: AnyClass) -> AnyClass {
        let name = "ClipassDragHold_\(NSStringFromClass(original))"
        if let existing = NSClassFromString(name) { return existing }
        guard let subclass = objc_allocateClassPair(original, name, 0) else { return original }
        addOrderOut(to: subclass)
        addClose(to: subclass)
        addVisibility(to: subclass)
        objc_registerClassPair(subclass)
        return subclass
    }

    private static func addOrderOut(to subclass: AnyClass) {
        let block: @convention(block) (AnyObject, Any?) -> Void = { object, sender in
            guard let window = object as? NSWindow else { return }
            if ClipboardDragGate.shared.isActive {
                ClipboardDragGate.shared.noteSuppressedClose(window)
                return
            }
            call(object, #selector(NSWindow.orderOut(_:)), sender)
        }
        class_addMethod(subclass, #selector(NSWindow.orderOut(_:)), imp_implementationWithBlock(block), "v@:@")
    }

    private static func addClose(to subclass: AnyClass) {
        let block: @convention(block) (AnyObject) -> Void = { object in
            guard let window = object as? NSWindow else { return }
            if ClipboardDragGate.shared.isActive {
                ClipboardDragGate.shared.noteSuppressedClose(window)
                return
            }
            call(object, #selector(NSWindow.close))
        }
        class_addMethod(subclass, #selector(NSWindow.close), imp_implementationWithBlock(block), "v@:")
    }

    private static func addVisibility(to subclass: AnyClass) {
        let selector = NSSelectorFromString("setIsVisible:")
        let block: @convention(block) (AnyObject, Bool) -> Void = { object, visible in
            guard let window = object as? NSWindow else { return }
            if !visible && ClipboardDragGate.shared.isActive {
                ClipboardDragGate.shared.noteSuppressedClose(window)
                return
            }
            call(object, selector, visible)
        }
        class_addMethod(subclass, selector, imp_implementationWithBlock(block), "v@:B")
    }

    private static func call(_ object: AnyObject, _ selector: Selector, _ argument: Any? = nil) {
        guard let name = objc_getAssociatedObject(object, &originalClassKey) as? String,
              let original = NSClassFromString(name),
              let method = class_getInstanceMethod(original, selector) else { return }
        let implementation = method_getImplementation(method)
        if argument == nil && selector == #selector(NSWindow.close) {
            typealias Close = @convention(c) (AnyObject, Selector) -> Void
            unsafeBitCast(implementation, to: Close.self)(object, selector)
        } else if selector == NSSelectorFromString("setIsVisible:") {
            typealias Visibility = @convention(c) (AnyObject, Selector, Bool) -> Void
            unsafeBitCast(implementation, to: Visibility.self)(object, selector, (argument as? Bool) ?? false)
        } else {
            typealias OrderOut = @convention(c) (AnyObject, Selector, Any?) -> Void
            unsafeBitCast(implementation, to: OrderOut.self)(object, selector, argument)
        }
    }
}

@MainActor
final class ClipboardDragMonitor {
    static let shared = ClipboardDragMonitor()
    static let startDistance: CGFloat = 4

    private var monitors: [ObjectIdentifier: Any] = [:]
    private var closeObservers: [ObjectIdentifier: NSObjectProtocol] = [:]
    private var sources: [ObjectIdentifier: ClipboardDragSource] = [:]
    private var down: (window: ObjectIdentifier, point: NSPoint, id: UUID)?

    func register(_ source: ClipboardDragSource) {
        guard let window = source.window else { return }
        let id = ObjectIdentifier(window)
        sources[id] = source
        guard monitors[id] == nil else { return }
        monitors[id] = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .leftMouseDragged, .leftMouseUp]) { [weak self] event in
            self?.handle(event)
            return event
        }
        closeObservers[id] = NotificationCenter.default.addObserver(
            forName: NSWindow.willCloseNotification, object: window, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.removeMonitor(id) }
        }
    }

    private func removeMonitor(_ id: ObjectIdentifier) {
        if let token = monitors.removeValue(forKey: id) { NSEvent.removeMonitor(token) }
        if let observer = closeObservers.removeValue(forKey: id) { NotificationCenter.default.removeObserver(observer) }
        sources[id] = nil
    }

    func handle(_ event: NSEvent) {
        switch event.type {
        case .leftMouseDown:
            guard let window = event.window, let row = rowID(in: window, at: event.locationInWindow) else {
                down = nil
                return
            }
            down = (ObjectIdentifier(window), event.locationInWindow, row)
        case .leftMouseDragged:
            guard let down, let window = event.window, down.window == ObjectIdentifier(window),
                  !ClipboardDragGate.shared.isActive,
                  Self.shouldStart(from: down.point, to: event.locationInWindow),
                  let source = sources[down.window] else { return }
            self.down = nil
            let row = anchor(in: window, id: down.id)
            source.beginDrag(with: event, payload: row?.payload ?? { .text("") }, label: row?.label ?? "")
        case .leftMouseUp:
            down = nil
        default:
            break
        }
    }

    static func shouldStart(from start: NSPoint, to current: NSPoint) -> Bool {
        let dx = current.x - start.x
        let dy = current.y - start.y
        return dx * dx + dy * dy >= startDistance * startDistance
    }

    func rowID(in window: NSWindow, at point: NSPoint) -> UUID? {
        guard let root = window.contentView else { return nil }
        return Self.anchors(in: root).first { $0.hitFrame()?.contains(point) == true }?.itemID
    }

    private func anchor(in window: NSWindow, id: UUID) -> ClipboardDragRowAnchor? {
        guard let root = window.contentView else { return nil }
        return Self.anchors(in: root).first { $0.itemID == id }
    }

    private static func anchors(in view: NSView) -> [ClipboardDragRowAnchor] {
        var found = view.subviews.flatMap { anchors(in: $0) }
        if let anchor = view as? ClipboardDragRowAnchor { found.append(anchor) }
        return found
    }
}

final class ClipboardDragSource: NSView, NSDraggingSource {
    private var offered: ClipboardDragItem?

    override func hitTest(_ point: NSPoint) -> NSView? { nil }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if window != nil { ClipboardDragMonitor.shared.register(self) }
    }

    @discardableResult
    func beginDrag(with event: NSEvent, payload: () -> ClipboardPayload, label: String) -> NSDraggingSession? {
        guard let window, event.windowNumber == window.windowNumber, !ClipboardDragGate.shared.isActive else { return nil }
        let offer = payload().dragItem()
        offered = offer
        let dragging = NSDraggingItem(pasteboardWriter: offer.item)
        let preview = dragImage(label.isEmpty ? "Clipboard item" : label)
        let location = convert(event.locationInWindow, from: nil)
        dragging.setDraggingFrame(
            NSRect(x: location.x - 16, y: location.y - 14, width: preview.size.width, height: preview.size.height),
            contents: preview)
        ClipboardDragGate.shared.begin(window: window)
        return beginDraggingSession(with: [dragging], event: event, source: self)
    }

    func draggingSession(_ session: NSDraggingSession, sourceOperationMaskFor context: NSDraggingContext) -> NSDragOperation {
        .copy
    }

    func ignoreModifierKeys(for session: NSDraggingSession) -> Bool { true }

    func draggingSession(_ session: NSDraggingSession, endedAt screenPoint: NSPoint, operation: NSDragOperation) {
        offered = nil
        ClipboardDragGate.shared.end(operation: operation)
    }

    private func dragImage(_ text: String) -> NSImage {
        let size = NSSize(width: 180, height: 28)
        let image = NSImage(size: size)
        image.lockFocus()
        NSColor.windowBackgroundColor.setFill()
        NSBezierPath(roundedRect: NSRect(origin: .zero, size: size), xRadius: 6, yRadius: 6).fill()
        let shown = text.count > 40 ? String(text.prefix(39)) + "…" : text
        (shown as NSString).draw(at: NSPoint(x: 8, y: 6), withAttributes: [
            .font: NSFont.systemFont(ofSize: 12),
            .foregroundColor: NSColor.labelColor,
        ])
        image.unlockFocus()
        return image
    }
}

struct ClipboardDragSourceView: NSViewRepresentable {
    func makeNSView(context: Context) -> ClipboardDragSource { ClipboardDragSource() }
    func updateNSView(_ view: ClipboardDragSource, context: Context) {}
}

struct ClipboardDragRowReporter: NSViewRepresentable {
    let id: UUID
    let payload: () -> ClipboardPayload
    let label: String

    func makeNSView(context: Context) -> ClipboardDragRowAnchor {
        let view = ClipboardDragRowAnchor()
        view.update(id: id, payload: payload, label: label)
        return view
    }

    func updateNSView(_ view: ClipboardDragRowAnchor, context: Context) {
        view.update(id: id, payload: payload, label: label)
    }
}

final class ClipboardDragRowAnchor: NSView {
    private(set) var itemID = UUID()
    private(set) var payload: () -> ClipboardPayload = { .text("") }
    private(set) var label = ""

    override func hitTest(_ point: NSPoint) -> NSView? { nil }

    func update(id: UUID, payload: @escaping () -> ClipboardPayload, label: String) {
        itemID = id
        self.payload = payload
        self.label = label
    }

    /// Read at the mouse event, so a scroll that did not relayout the row cannot leave a stale target.
    func hitFrame() -> NSRect? {
        let row = convert(bounds, to: nil)
        guard let scroll = enclosingScrollView else { return row }
        let clip = scroll.contentView.convert(scroll.contentView.bounds, to: nil)
        let visible = row.intersection(clip)
        if visible.isNull || visible.width < 1 || visible.height < 1 { return nil }
        return visible
    }
}

extension View {
    func clipboardDragHost() -> some View {
        background(alignment: .topLeading) {
            ClipboardDragSourceView().frame(width: 1, height: 1).allowsHitTesting(false)
        }
    }
}
