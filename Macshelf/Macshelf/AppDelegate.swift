import AppKit
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {

    // Single source of truth — injected into the SwiftUI environment.
    let store = ShelfStore()

    private var panel: NSPanel?

    // MARK: - Lifecycle

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Remove the Dock tile; MacShelf lives as a floating utility.
        NSApp.setActivationPolicy(.accessory)
        buildPanel()
    }

    // MARK: - Panel Construction

    private func buildPanel() {
        let panel = NSPanel(
            contentRect: .zero,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        // Always float above every app, including full-screen spaces.
        panel.level = .floating
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true

        // The user grabs the panel by its background to reposition it.
        panel.isMovableByWindowBackground = true

        // Appear on every Space and alongside full-screen apps.
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

        // Needed so hover events reach SwiftUI views even when unfocused.
        panel.acceptsMouseMovedEvents = true

        let rootView = ContentView()
            .environment(store)

        let host = NSHostingView(rootView: rootView)
        host.wantsLayer = true

        panel.contentView = host

        // Position on the right edge of the main screen, vertically centered.
        placePanel(panel, size: CGSize(width: 88, height: 340))

        panel.orderFrontRegardless()
        self.panel = panel
    }

    private func placePanel(_ panel: NSPanel, size: CGSize) {
        guard let screen = NSScreen.main else { return }
        let visible = screen.visibleFrame
        let origin = CGPoint(
            x: visible.maxX - size.width - 16,
            y: visible.midY - size.height / 2
        )
        panel.setFrame(NSRect(origin: origin, size: size), display: false)
    }
}
