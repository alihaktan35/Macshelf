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

    // MARK: Drag-out provider

    /// Builds an NSItemProvider suitable for dragging this item
    /// onto Finder, Mail, a text editor, or any drop target.
    var dragProvider: NSItemProvider {
        switch kind {
        case .file(let url):
            // `contentsOf:` creates a file-backed provider; fall back to a URL
            // provider if the file is inaccessible (e.g. sandbox revocation).
            return NSItemProvider(contentsOf: url)
                ?? NSItemProvider(object: url as NSURL)

        case .webURL(let url):
            return NSItemProvider(object: url as NSURL)

        case .text(let string):
            return NSItemProvider(object: string as NSString)
        }
    }
}
