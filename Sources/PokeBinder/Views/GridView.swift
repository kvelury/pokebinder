import AppKit
import SwiftUI

/// Continuous 151-card grid on one page sheet, pinch-zoomable by relayout.
struct GridView: View {
    @EnvironmentObject private var binder: BinderState
    @EnvironmentObject private var collection: CollectionStore
    @EnvironmentObject private var grid: GridState
    @Environment(\.appTheme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @Binding var selection: CardSelection?

    private let outerInset:  CGFloat = 28   // horizontal margin; also feeds the column math
    private let topInset:    CGFloat = 86   // 58pt floating cluster + 28pt gap
    private let bottomInset: CGFloat = 88

    var body: some View {
        GeometryReader { geo in
            let m = grid.metrics
            let gap = m.cardGap
            let pad = m.pagePadding
            let available = geo.size.width - outerInset * 2 - pad * 2
            let columns = max(1, Int((available + gap) / (m.cardWidth + gap)))
            let sheetW = pad * 2 + CGFloat(columns) * m.cardWidth + CGFloat(columns - 1) * gap
            let viewportHeight = geo.size.height

            ScrollViewReader { proxy in
                ScrollView(.vertical) {
                    LazyVGrid(
                        columns: Array(
                            repeating: GridItem(.fixed(m.cardWidth), spacing: gap),
                            count: columns
                        ),
                        spacing: gap
                    ) {
                        ForEach(1...Pokedex.count, id: \.self) { dex in
                            CardSlotView(
                                slot: BinderSlot.forDex(dex),
                                metrics: m,
                                isOwned: collection.isOwned(dex),
                                emphasis: binder.emphasis(for: dex),
                                selection: $selection
                            )
                            .id(dex)
                        }
                    }
                    .padding(pad)
                    .background(pageSheet(metrics: m))
                    .frame(width: sheetW)
                    .frame(maxWidth: .infinity)
                    .padding(.bottom, bottomInset)
                }
                .contentMargins(.top, topInset, for: .scrollContent)
                .onScrollGeometryChange(for: CGFloat.self) { $0.contentOffset.y } action: { _, y in
                    let rowHeight = m.cardHeight + gap
                    let centreRow = (y + viewportHeight / 2 - pad - topInset) / rowHeight
                    let index = Int(centreRow.rounded()) * columns + columns / 2
                    grid.noteAnchor(dex: min(max(index + 1, 1), Pokedex.count))
                }
                .onChange(of: columns) { _, _ in
                    let dex = grid.anchorDex
                    var transaction = Transaction()
                    transaction.disablesAnimations = true
                    withTransaction(transaction) { proxy.scrollTo(dex, anchor: .center) }
                }
                .onChange(of: binder.currentMatchDex) { _, dex in
                    guard let dex else { return }
                    withAnimation(motion(AppMotion.feedback)) {
                        proxy.scrollTo(dex, anchor: .center)
                    }
                }
                .onChange(of: binder.currentPage) { _, page in
                    guard !binder.isSearching else { return }
                    proxy.scrollTo((page - 1) * Pokedex.slotsPerPage + 1, anchor: .top)
                }
                .onAppear {
                    let dex = (binder.currentPage - 1) * Pokedex.slotsPerPage + 1
                    var transaction = Transaction()
                    transaction.disablesAnimations = true
                    withTransaction(transaction) { proxy.scrollTo(dex, anchor: .top) }
                }
            }
            .overlay {
                TrackpadMagnifyCatcher(isSuspended: selection != nil) { event in
                    handleMagnify(event)
                }
                .allowsHitTesting(false)
            }
        }
        .task { await ArtworkStore.shared.prefetchAll() }
    }

    private func handleMagnify(_ event: TrackpadMagnifyEvent) {
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            grid.magnify(by: 1 + event.magnification)
        }
        if event.phase.contains(.ended) || event.phase.contains(.cancelled) {
            grid.commit()
        }
    }

    private func pageSheet(metrics: BinderMetrics) -> some View {
        let shape = RoundedRectangle(cornerRadius: metrics.pageCornerRadius, style: .continuous)
        return shape
            .fill(theme.page)
            .overlay(shape.strokeBorder(.black.opacity(0.08), lineWidth: 1))
            .shadow(
                color: .black.opacity(0.22),
                radius: metrics.cardWidth * 0.05,
                y: metrics.cardWidth * 0.02
            )
    }

    private func motion(_ animation: Animation) -> Animation? {
        AppMotion.respectingReduceMotion(animation, reduceMotion: reduceMotion)
    }
}

// MARK: - Trackpad magnify catcher

private struct TrackpadMagnifyEvent {
    let magnification: CGFloat
    let phase: NSEvent.Phase
}

/// Pinch-to-zoom over the grid, without stealing clicks from the cards or the scroll view.
///
/// Clicks pass through (`hitTest` is nil). Magnify events are caught with a local monitor
/// so SwiftUI hit testing never fights `ScrollView` or `CardSlotView.onTapGesture`.
private struct TrackpadMagnifyCatcher: NSViewRepresentable {
    var isSuspended: Bool
    var onMagnify: (TrackpadMagnifyEvent) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeNSView(context: Context) -> CatcherView {
        let view = CatcherView()
        context.coordinator.view = view
        view.coordinator = context.coordinator
        return view
    }

    func updateNSView(_ nsView: CatcherView, context: Context) {
        context.coordinator.isSuspended = isSuspended
        context.coordinator.onMagnify = onMagnify
        nsView.coordinator = context.coordinator
        context.coordinator.view = nsView
    }

    static func dismantleNSView(_ nsView: CatcherView, coordinator: Coordinator) {
        coordinator.teardown()
    }

    final class Coordinator {
        weak var view: CatcherView?
        var isSuspended = false
        var onMagnify: ((TrackpadMagnifyEvent) -> Void)?
        private var monitor: Any?

        func install() {
            guard monitor == nil else { return }
            monitor = NSEvent.addLocalMonitorForEvents(matching: .magnify) { [weak self] event in
                self?.handle(event) ?? event
            }
        }

        func teardown() {
            if let monitor {
                NSEvent.removeMonitor(monitor)
            }
            monitor = nil
        }

        private func handle(_ event: NSEvent) -> NSEvent? {
            if isSuspended { return event }
            guard let view else { return event }
            guard event.window === view.window else { return event }
            let location = view.convert(event.locationInWindow, from: nil)
            guard view.bounds.contains(location) else { return event }

            let payload = TrackpadMagnifyEvent(
                magnification: event.magnification,
                phase: event.phase
            )
            if Thread.isMainThread {
                onMagnify?(payload)
            } else {
                DispatchQueue.main.async { [onMagnify] in
                    onMagnify?(payload)
                }
            }
            return nil
        }
    }

    final class CatcherView: NSView {
        var coordinator: Coordinator?

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            if window != nil {
                coordinator?.install()
            } else {
                coordinator?.teardown()
            }
        }

        override func hitTest(_ point: NSPoint) -> NSView? { nil }
    }
}
