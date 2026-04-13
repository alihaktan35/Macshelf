import Foundation
import AppKit
import UniformTypeIdentifiers

// MARK: - Model

/// The canonical representation of one item on the shelf.
struct ShelfItem: Identifiable {
    let id = UUID()
    let kind: Kind
    let icon: NSImage
    let displayName: String

    enum Kind {
        case file(URL)      // local file or folder
        case webURL(URL)    // link dragged from a browser
        case text(String)   // plain-text snippet
    }

    // MARK: Drag-out

    /// Returns an NSPasteboardWriting-conforming object for NSDraggingItem.
    /// NSURL and NSString both conform directly; NSItemProvider does not in
    /// the macOS 26 SDK and cannot be used with NSDraggingItem.
    var pasteboardWriter: any NSPasteboardWriting {
        switch kind {
        case .file(let url):    return url as NSURL
        case .webURL(let url):  return url as NSURL
        case .text(let string): return string as NSString
        }
    }
}
