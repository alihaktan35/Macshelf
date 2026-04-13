import Foundation
import AppKit
import UniformTypeIdentifiers

// MARK: - Store

@Observable
final class ShelfStore {
    var items: [ShelfItem] = []

    // MARK: - Mutations

    /// Resolves each provider asynchronously and appends successful results.
    func addItems(from providers: [NSItemProvider]) {
        for provider in providers {
            Task {
                guard let item = await resolve(provider) else { return }
                items.append(item)
            }
        }
    }

    func remove(_ item: ShelfItem) {
        items.removeAll { $0.id == item.id }
    }

    func clear() {
        items.removeAll()
    }

    // MARK: - Resolution Pipeline

    /// Tries each type in priority order: file → URL → text.
    private func resolve(_ provider: NSItemProvider) async -> ShelfItem? {

        // 1. Local file / folder
        if provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
            if let url = try? await provider.loadFileURL() {
                let icon = NSWorkspace.shared.icon(forFile: url.path(percentEncoded: false))
                return ShelfItem(kind: .file(url), icon: icon, displayName: url.lastPathComponent)
            }
        }

        // 2. Web URL (link, image URL, …)
        if provider.hasItemConformingToTypeIdentifier(UTType.url.identifier) {
            if let url = try? await provider.loadGenericURL() {
                let icon = NSImage(systemSymbolName: "link.circle.fill",
                                   accessibilityDescription: nil) ?? NSImage()
                let name = url.host(percentEncoded: false) ?? url.absoluteString
                return ShelfItem(kind: .webURL(url), icon: icon, displayName: name)
            }
        }

        // 3. Plain-text snippet
        if provider.hasItemConformingToTypeIdentifier(UTType.plainText.identifier) {
            if let text = try? await provider.loadPlainText() {
                let icon = NSImage(systemSymbolName: "text.quote",
                                   accessibilityDescription: nil) ?? NSImage()
                let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
                let name = trimmed.isEmpty ? "Text" : String(trimmed.prefix(48))
                return ShelfItem(kind: .text(text), icon: icon, displayName: name)
            }
        }

        return nil
    }
}

// MARK: - NSItemProvider async bridge

extension NSItemProvider {

    func loadFileURL() async throws -> URL {
        try await withCheckedThrowingContinuation { cont in
            loadItem(forTypeIdentifier: UTType.fileURL.identifier) { item, error in
                if let error { cont.resume(throwing: error); return }
                if let url = item as? URL { cont.resume(returning: url); return }
                if let data = item as? Data,
                   let url = URL(dataRepresentation: data, relativeTo: nil) {
                    cont.resume(returning: url); return
                }
                cont.resume(throwing: CocoaError(.fileNoSuchFile))
            }
        }
    }

    func loadGenericURL() async throws -> URL {
        try await withCheckedThrowingContinuation { cont in
            loadItem(forTypeIdentifier: UTType.url.identifier) { item, error in
                if let error { cont.resume(throwing: error); return }
                if let url = item as? URL { cont.resume(returning: url); return }
                if let data = item as? Data,
                   let url = URL(dataRepresentation: data, relativeTo: nil) {
                    cont.resume(returning: url); return
                }
                cont.resume(throwing: CocoaError(.fileNoSuchFile))
            }
        }
    }

    func loadPlainText() async throws -> String {
        try await withCheckedThrowingContinuation { cont in
            loadItem(forTypeIdentifier: UTType.plainText.identifier) { item, error in
                if let error { cont.resume(throwing: error); return }
                if let string = item as? String { cont.resume(returning: string); return }
                if let data = item as? Data,
                   let string = String(data: data, encoding: .utf8) {
                    cont.resume(returning: string); return
                }
                cont.resume(throwing: CocoaError(.fileReadUnknown))
            }
        }
    }
}
