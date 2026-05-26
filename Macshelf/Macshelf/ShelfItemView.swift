import SwiftUI
import AppKit

// MARK: - Public SwiftUI wrapper

/// SwiftUI entry-point for a shelf item.
/// Backed by ItemDragView so we get NSDraggingSource lifecycle callbacks
/// that SwiftUI's `onDrag` does not expose — specifically the
/// `draggingSession(_:endedAt:operation:)` delegate that tells us whether
/// the drop was accepted, letting us remove the item automatically.
struct ShelfItemView: NSViewRepresentable {
    let item: ShelfItem
    let onRemove: () -> Void

    func makeNSView(context: Context) -> ItemDragView {
        ItemDragView(item: item, onRemove: onRemove)
    }

    func updateNSView(_ nsView: ItemDragView, context: Context) {
        nsView.update(item: item, onRemove: onRemove)
    }

    /// Fixed height; width fills whatever the LazyVStack provides.
    func sizeThatFits(_ proposal: ProposedViewSize,
                      nsView: ItemDragView,
                      context: Context) -> CGSize? {
        CGSize(width: proposal.width ?? 64, height: 80)
    }
}

// MARK: - Drag-capable NSView

final class ItemDragView: NSView, NSDraggingSource {

    private(set) var item: ShelfItem
    private(set) var onRemove: () -> Void

    private var host: NSHostingView<ItemVisual>!
    private var mouseDownPt: NSPoint = .zero
    private var dragActive = false
    private var isHovering = false { didSet { refreshVisual() } }
    private var hoverTrackingArea: NSTrackingArea?

    // MARK: Init

    init(item: ShelfItem, onRemove: @escaping () -> Void) {
        self.item = item
        self.onRemove = onRemove
        super.init(frame: .zero)
        setup()
    }

    required init?(coder: NSCoder) { fatalError() }

    func update(item: ShelfItem, onRemove: @escaping () -> Void) {
        self.item = item
        self.onRemove = onRemove
        refreshVisual()
    }

    private func setup() {
        host = NSHostingView(rootView: makeVisual())
        host.autoresizingMask = [.width, .height]
        addSubview(host)

        // Right-click → remove
        let removeItem = NSMenuItem(title: "Remove", action: #selector(handleRemove), keyEquivalent: "")
        removeItem.target = self
        let menu = NSMenu()
        menu.addItem(removeItem)
        self.menu = menu
    }

    private func makeVisual() -> ItemVisual {
        ItemVisual(item: item, isHovering: isHovering)
    }

    private func refreshVisual() {
        host.rootView = makeVisual()
    }

    @objc private func handleRemove() {
        withAnimation(.spring(response: 0.3)) { onRemove() }
    }

    // MARK: - Hit testing
    //
    // Return self for all points within our frame so that mouseDown /
    // mouseDragged reach us before NSHostingView can consume them.
    // This lets us call beginDraggingSession ourselves.

    override func hitTest(_ point: NSPoint) -> NSView? {
        frame.contains(point) ? self : nil
    }

    // MARK: - Hover tracking

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        // Remove only OUR tracking area — not the system-managed one that
        // powers NSView.toolTip. Removing all tracking areas kills tooltips.
        if let old = hoverTrackingArea { removeTrackingArea(old) }
        let ta = NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .activeAlways],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(ta)
        hoverTrackingArea = ta
    }

    override func mouseEntered(with event: NSEvent) { isHovering = true }
    override func mouseExited(with event: NSEvent)  { isHovering = false }

    // MARK: - Drag initiation

    override func mouseDown(with event: NSEvent) {
        mouseDownPt = event.locationInWindow
        dragActive = false
    }

    override func mouseDragged(with event: NSEvent) {
        guard !dragActive else { return }
        let loc = event.locationInWindow
        guard hypot(loc.x - mouseDownPt.x, loc.y - mouseDownPt.y) > 4 else { return }
        dragActive = true
        startDrag(event: event)
    }

    override func mouseUp(with event: NSEvent) {
        dragActive = false
    }

    private func startDrag(event: NSEvent) {
        let sz = CGSize(width: 48, height: 48)
        let origin = bounds.isEmpty
            ? NSPoint(x: 8, y: 16)
            : NSPoint(x: (bounds.width - sz.width) / 2, y: (bounds.height - sz.height) / 2)
        let frame = NSRect(origin: origin, size: sz)
        // Groups produce one NSDraggingItem per file so the destination receives all
        // URLs in a single session — the user drags once, everything lands at once.
        let draggingItems = zip(item.pasteboardWriters, item.dragIcons).map { writer, dragIcon -> NSDraggingItem in
            let di = NSDraggingItem(pasteboardWriter: writer)
            di.setDraggingFrame(frame, contents: dragIcon)
            return di
        }
        beginDraggingSession(with: draggingItems, event: event, source: self)
    }

    // MARK: - NSDraggingSource

    func draggingSession(_ session: NSDraggingSession,
                         sourceOperationMaskFor context: NSDraggingContext) -> NSDragOperation {
        .copy
    }

    /// Called after the drag ends — operation is .none for cancelled/rejected drags.
    func draggingSession(_ session: NSDraggingSession,
                         endedAt screenPoint: NSPoint,
                         operation: NSDragOperation) {
        dragActive = false
        guard !operation.isEmpty else { return }

        // The destination accepted the drop → remove item from shelf.
        DispatchQueue.main.async { [weak self] in
            withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                self?.onRemove()
            }
        }
    }
}

// MARK: - Pure SwiftUI visual layer

struct ItemVisual: View {
    let item: ShelfItem
    let isHovering: Bool

    @Environment(\.pixelLength) private var pixelLength

    @ViewBuilder
    private var iconView: some View {
        switch item.kind {
        case .group(_, let icons):
            GroupIconStack(icons: icons, count: icons.count)
        default:
            Image(nsImage: item.icon)
                .resizable()
                .interpolation(.high)
                .antialiased(true)
                .aspectRatio(contentMode: .fit)
                .frame(width: 46, height: 46)
                .shadow(color: .black.opacity(0.25), radius: 5, x: 0, y: 3)
        }
    }

    var body: some View {
        VStack(spacing: 5) {
            iconView

            Text(item.displayName)
                .font(.system(size: 9, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.75))
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .truncationMode(.middle)
                .opacity(isHovering ? 0 : 1)
        }
        .padding(.vertical, 7)
        .padding(.horizontal, 5)
        .frame(maxWidth: .infinity)
        .overlay(alignment: .bottom) {
            if isHovering {
                Text(item.displayName)
                    .font(.system(size: 9, weight: .medium, design: .rounded))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .lineLimit(4)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 4)
                    .frame(maxWidth: .infinity)
                    .background(.black.opacity(0.55), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .padding(3)
                    .transition(.opacity.combined(with: .scale(scale: 0.97, anchor: .bottom)))
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
        .background(
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .fill(isHovering ? .white.opacity(0.14) : .white.opacity(0.07))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .strokeBorder(.white.opacity(isHovering ? 0.35 : 0.12), lineWidth: pixelLength)
        )
        .scaleEffect(isHovering ? 1.05 : 1)
        .animation(.spring(response: 0.22, dampingFraction: 0.65), value: isHovering)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(item.displayName)
        .accessibilityHint("Drag to use, right-click to remove")
    }
}

// MARK: - Group icon stack

private struct GroupIconStack: View {
    let icons: [NSImage]
    let count: Int

    var body: some View {
        ZStack {
            // Back icons rendered first so they sit behind the front icon.
            if icons.count >= 3 {
                leafIcon(icons[2], size: 28)
                    .rotationEffect(.degrees(-12))
                    .offset(x: -8, y: 5)
                    .opacity(0.7)
            }
            if icons.count >= 2 {
                leafIcon(icons[1], size: 32)
                    .rotationEffect(.degrees(-6))
                    .offset(x: -4, y: 2)
                    .opacity(0.85)
            }
            if let first = icons.first {
                leafIcon(first, size: 36)
                    .shadow(color: .black.opacity(0.25), radius: 4, x: 0, y: 2)
            }
        }
        .frame(width: 46, height: 46)
        .overlay(alignment: .topTrailing) {
            Text("\(count)")
                .font(.system(size: 8, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .padding(.horizontal, 4)
                .padding(.vertical, 2)
                .background(Color.blue.opacity(0.85), in: Capsule())
        }
    }

    private func leafIcon(_ image: NSImage, size: CGFloat) -> some View {
        Image(nsImage: image)
            .resizable()
            .interpolation(.high)
            .aspectRatio(contentMode: .fit)
            .frame(width: size, height: size)
    }
}
