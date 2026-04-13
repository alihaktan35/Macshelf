import AppKit
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {

    let store = ShelfStore()
    private var panel: NSPanel?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        buildPanel()
    }

    private func buildPanel() {
        let panel = NSPanel(
            contentRect: .zero,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.level = .floating
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.isMovableByWindowBackground = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.acceptsMouseMovedEvents = true

        // DropReceivingView is the panel's root view. By being an *ancestor*
        // of the SwiftUI NSHostingView, AppKit's drag machinery walks up
        // the superview chain and delivers drops here — without intercepting
        // any regular mouse events that SwiftUI content handles on its own.
        let dropView = DropReceivingView(store: store)
        dropView.autoresizingMask = [.width, .height]

        let host = NSHostingView(rootView: ContentView().environment(store))
        host.frame = dropView.bounds
        host.autoresizingMask = [.width, .height]
        dropView.addSubview(host)

        panel.contentView = dropView

        if let screen = NSScreen.main {
            let vis = screen.visibleFrame
            let size = CGSize(width: 88, height: 340)
            panel.setFrame(
                NSRect(
                    x: vis.maxX - size.width - 16,
                    y: vis.midY - size.height / 2,
                    width: size.width,
                    height: size.height
                ),
                display: false
            )
        }

        panel.orderFrontRegardless()
        self.panel = panel
    }
}

// MARK: - Drop Receiving View

/// Root NSView of the floating panel.
///
/// Registered as an `NSDraggingDestination` directly — reads URLs and text
/// from `NSPasteboard` synchronously during `performDragOperation`, which is
/// the only approach that works reliably in a sandboxed NSPanel.
///
/// SwiftUI's NSHostingView lives *inside* this view as a child subview, so
/// all regular mouse/keyboard events are handled by SwiftUI as normal.
final class DropReceivingView: NSView {

    private let store: ShelfStore

    init(store: ShelfStore) {
        self.store = store
        super.init(frame: .zero)
        registerForDraggedTypes([
            .fileURL,
            NSPasteboard.PasteboardType("NSFilenamesPboardType"),  // legacy Finder
            .URL,
            .string,
        ])
    }

    required init?(coder: NSCoder) { fatalError() }

    // MARK: NSDraggingDestination

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) {
            store.isTargeted = true
        }
        return .copy
    }

    override func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation { .copy }

    override func draggingExited(_ sender: NSDraggingInfo?) {
        withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) {
            store.isTargeted = false
        }
    }

    override func draggingEnded(_ sender: NSDraggingInfo) {
        store.isTargeted = false
    }

    override func prepareForDragOperation(_ sender: NSDraggingInfo) -> Bool { true }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        let pb = sender.draggingPasteboard

        // 1. Local files / folders (Finder, Desktop, etc.)
        let fileOptions: [NSPasteboard.ReadingOptionKey: Any] = [.urlReadingFileURLsOnly: true]
        if let urls = pb.readObjects(forClasses: [NSURL.self], options: fileOptions) as? [URL],
           !urls.isEmpty {
            store.add(urls: urls)
            return true
        }

        // 2. Web / generic URLs (links dragged from a browser)
        if let urls = pb.readObjects(forClasses: [NSURL.self], options: nil) as? [URL],
           !urls.isEmpty {
            store.add(urls: urls)
            return true
        }

        // 3. Plain-text snippet
        if let text = pb.string(forType: .string), !text.isEmpty {
            store.add(text: text)
            return true
        }

        return false
    }
}
