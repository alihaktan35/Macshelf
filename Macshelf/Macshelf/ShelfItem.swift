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
        case file(URL)                // local file or folder
        case webURL(URL)              // link dragged from a browser
        case text(String)             // plain-text snippet
        case image(NSImage)           // raw image (e.g. dragged from Preview or Photos)
        case group([URL], [NSImage])  // multiple files dropped together; icons are pre-fetched
    }

    // MARK: Drag-out

    /// One writer per logical item — groups produce N writers so the destination
    /// receives every URL in a single drag session without the user dragging twice.
    var pasteboardWriters: [any NSPasteboardWriting] {
        switch kind {
        case .file(let url):          return [url as NSURL]
        case .webURL(let url):        return [url as NSURL]
        case .text(let string):       return [string as NSString]
        case .image(let nsImage):
            let pb = NSPasteboardItem()
            if let tiff = nsImage.tiffRepresentation { pb.setData(tiff, forType: .tiff) }
            return [pb]
        case .group(let urls, _):     return urls.map { $0 as NSURL }
        }
    }

    /// Drag images paired 1:1 with pasteboardWriters.
    var dragIcons: [NSImage] {
        switch kind {
        case .group(_, let icons): return icons
        default:                   return [icon]
        }
    }
}
