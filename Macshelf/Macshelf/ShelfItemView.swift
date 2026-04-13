import SwiftUI

/// One item card in the shelf — shows an icon and a name,
/// supports hover feedback, drag-out, and a context-menu remove action.
struct ShelfItemView: View {
    let item: ShelfItem
    let onRemove: () -> Void

    @State private var isHovering = false

    var body: some View {
        VStack(spacing: 5) {
            icon
            label
        }
        .padding(.vertical, 7)
        .padding(.horizontal, 5)
        .frame(maxWidth: .infinity)
        .background(itemBackground)
        .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
        .overlay(itemBorder)
        .scaleEffect(isHovering ? 1.05 : 1)
        .animation(.spring(response: 0.22, dampingFraction: 0.65), value: isHovering)
        .onHover { isHovering = $0 }
        // Drag-out: hands the stored provider back to the system drag engine.
        .onDrag { item.dragProvider }
        .contextMenu {
            Button("Remove", role: .destructive, action: onRemove)
        }
    }

    // MARK: - Sub-views

    private var icon: some View {
        Image(nsImage: item.icon)
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(width: 46, height: 46)
            .shadow(color: .black.opacity(0.25), radius: 5, x: 0, y: 3)
    }

    private var label: some View {
        Text(item.displayName)
            .font(.system(size: 8, weight: .medium, design: .rounded))
            .foregroundStyle(.white.opacity(0.75))
            .lineLimit(2)
            .multilineTextAlignment(.center)
            .truncationMode(.middle)
    }

    // MARK: - Glass visuals

    private var itemBackground: some View {
        RoundedRectangle(cornerRadius: 13, style: .continuous)
            .fill(isHovering ? .white.opacity(0.14) : .white.opacity(0.07))
    }

    private var itemBorder: some View {
        RoundedRectangle(cornerRadius: 13, style: .continuous)
            .strokeBorder(.white.opacity(isHovering ? 0.35 : 0.12), lineWidth: 0.5)
    }
}
