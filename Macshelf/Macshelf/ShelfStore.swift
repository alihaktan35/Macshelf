import Foundation
import AppKit
import SwiftUI

@Observable
final class ShelfStore {

    var items: [ShelfItem] = []

    /// Driven by DropReceivingView — controls the drop-hover visual in ContentView.
    var isTargeted = false

    // MARK: - Add

    /// Adds local files or web URLs read synchronously from NSPasteboard.
    /// No async, no NSItemProvider — called directly from performDragOperation.
    func add(urls: [URL]) {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
            for url in urls {
                if url.isFileURL {
                    let icon = NSWorkspace.shared.icon(forFile: url.path(percentEncoded: false))
                    items.append(ShelfItem(kind: .file(url), icon: icon,
                                          displayName: url.lastPathComponent))
                } else {
                    let icon = NSImage(systemSymbolName: "link.circle.fill",
                                      accessibilityDescription: nil) ?? NSImage()
                    let name = url.host(percentEncoded: false) ?? url.absoluteString
                    items.append(ShelfItem(kind: .webURL(url), icon: icon, displayName: name))
                }
            }
        }
    }

    /// Adds a plain-text snippet read from NSPasteboard.
    func add(text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let icon = NSImage(systemSymbolName: "text.quote", accessibilityDescription: nil) ?? NSImage()
        let name = String(trimmed.prefix(48))
        withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
            items.append(ShelfItem(kind: .text(text), icon: icon, displayName: name))
        }
    }

    // MARK: - Remove

    func remove(_ item: ShelfItem) {
        items.removeAll { $0.id == item.id }
    }

    func clear() {
        items.removeAll()
    }
}
