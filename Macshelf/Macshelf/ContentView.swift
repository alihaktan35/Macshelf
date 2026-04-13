import SwiftUI

// MARK: - Root view

struct ContentView: View {
    @Environment(ShelfStore.self) private var store

    private let panelWidth:   CGFloat = 84
    private let cornerRadius: CGFloat = 22

    var body: some View {
        VStack(spacing: 0) {
            gripBar
            Divider().opacity(0.12)

            if store.items.isEmpty {
                emptyState
            } else {
                itemList
                clearBar
            }
        }
        .frame(width: panelWidth)
        .background { glassBackground }
        .overlay { glassEdge }
        .overlay { if store.isTargeted { dropHighlight } }
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .shadow(color: .black.opacity(0.3), radius: 28, x: 0, y: 14)
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: store.items.count)
        .animation(.spring(response: 0.25, dampingFraction: 0.7), value: store.isTargeted)
    }

    // MARK: - Grip bar

    private var gripBar: some View {
        Capsule()
            .fill(.white.opacity(0.28))
            .frame(width: 26, height: 3)
            .frame(maxWidth: .infinity)
            .frame(height: 28)
            .contentShape(Rectangle())
            .contextMenu {
                Button("Quit MacShelf", role: .destructive) {
                    NSApp.terminate(nil)
                }
            }
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: store.isTargeted ? "tray.and.arrow.down.fill" : "tray")
                .font(.system(size: 24, weight: .light))
                .foregroundStyle(.white.opacity(store.isTargeted ? 0.9 : 0.45))
                .scaleEffect(store.isTargeted ? 1.2 : 1)

            Text(store.isTargeted ? "Release to add" : "Drop\nanything\nhere")
                .font(.system(size: 9, weight: .medium, design: .rounded))
                .multilineTextAlignment(.center)
                .foregroundStyle(.white.opacity(store.isTargeted ? 0.7 : 0.35))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
    }

    // MARK: - Item list

    private var itemList: some View {
        ScrollView(.vertical, showsIndicators: false) {
            LazyVStack(spacing: 6) {
                ForEach(store.items) { item in
                    ShelfItemView(item: item) {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                            store.remove(item)
                        }
                    }
                    .transition(
                        .asymmetric(
                            insertion: .scale(scale: 0.6).combined(with: .opacity),
                            removal:   .scale(scale: 0.6).combined(with: .opacity)
                        )
                    )
                }
            }
            .padding(.horizontal, 9)
            .padding(.vertical, 8)
        }
        .frame(maxHeight: 320)
    }

    // MARK: - Clear bar

    private var clearBar: some View {
        Button {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                store.clear()
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "xmark").font(.system(size: 8, weight: .bold))
                Text("Clear all").font(.system(size: 9, weight: .semibold, design: .rounded))
            }
            .foregroundStyle(.white.opacity(0.5))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 9)
            .background(.white.opacity(0.05))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Liquid Glass layers

    private var glassBackground: some View {
        ZStack {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(.ultraThinMaterial)

            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(
                    LinearGradient(
                        stops: [
                            .init(color: .white.opacity(0.20), location: 0.00),
                            .init(color: .white.opacity(0.08), location: 0.30),
                            .init(color: .clear,               location: 0.65),
                            .init(color: .white.opacity(0.04), location: 1.00),
                        ],
                        startPoint: .top, endPoint: .bottom
                    )
                )

            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.45, green: 0.75, blue: 1.0).opacity(0.06),
                            Color(red: 0.55, green: 0.45, blue: 1.0).opacity(0.03),
                        ],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    )
                )
        }
    }

    private var glassEdge: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .strokeBorder(
                LinearGradient(
                    stops: [
                        .init(color: .white.opacity(0.55), location: 0.00),
                        .init(color: .white.opacity(0.20), location: 0.40),
                        .init(color: .white.opacity(0.10), location: 0.60),
                        .init(color: .white.opacity(0.30), location: 1.00),
                    ],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                ),
                lineWidth: 0.75
            )
    }

    private var dropHighlight: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(.white.opacity(0.07))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: [.white.opacity(0.8), .white.opacity(0.4)],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        ),
                        lineWidth: 1.5
                    )
            )
    }
}

#Preview {
    let store = ShelfStore()
    ContentView()
        .environment(store)
        .frame(width: 84)
        .padding(20)
        .background(.black.opacity(0.5))
}
