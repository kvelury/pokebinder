import SwiftUI

/// The original vertical 151-card grid: one page sheet, pinch-zoomable by relayout.
struct ClassicGridView: View {
    @EnvironmentObject private var binder: BinderState
    @EnvironmentObject private var collection: CollectionStore
    @EnvironmentObject private var grid: GridState
    @Environment(\.appTheme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @Binding var selection: CardSelection?

    private let outerInset:  CGFloat = 28   // horizontal margin; also feeds the column math
    private let topInset:    CGFloat = 86   // 58pt floating cluster + 28pt gap
    private let bottomInset: CGFloat = 88

    private enum ScrollTarget: Hashable {
        case top
    }

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
                    LazyVStack(spacing: 0) {
                        // Real scroll content, rather than a ScrollView content margin:
                        // ScrollViewReader can jump past a margin and hide row 1 under
                        // the floating controls when entering grid mode.
                        Color.clear
                            .frame(height: topInset)
                            .id(ScrollTarget.top)

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
                }
                .onScrollGeometryChange(for: CGFloat.self) { $0.contentOffset.y } action: { _, y in
                    let rowHeight = m.cardHeight + gap
                    let centreRow = (y + viewportHeight / 2 - pad - topInset) / rowHeight
                    let index = Int(centreRow.rounded()) * columns + columns / 2
                    grid.noteAnchor(dex: min(max(index + 1, 1), Pokedex.count))
                }
                .onChange(of: columns) { _, _ in
                    recenter(on: grid.anchorDex, proxy: proxy)
                }
                .onChange(of: binder.currentMatchDex) { _, dex in
                    guard let dex else { return }
                    withAnimation(motion(AppMotion.feedback)) {
                        proxy.scrollTo(dex, anchor: .center)
                    }
                }
                .onChange(of: binder.currentPage) { _, page in
                    guard !binder.isSearching else { return }
                    scrollToPageStart(
                        page,
                        metrics: m,
                        viewportHeight: viewportHeight,
                        proxy: proxy
                    )
                }
                .onAppear {
                    var transaction = Transaction()
                    transaction.disablesAnimations = true
                    withTransaction(transaction) {
                        restorePosition(
                            metrics: m,
                            viewportHeight: viewportHeight,
                            proxy: proxy
                        )
                    }
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

    /// Binder→grid lands on the current page with Classic's top-spacer clearance.
    /// Switching from Continuous keeps the card that was in the centre.
    private func restorePosition(
        metrics: BinderMetrics,
        viewportHeight: CGFloat,
        proxy: ScrollViewProxy
    ) {
        let pageStart = (binder.currentPage - 1) * Pokedex.slotsPerPage + 1
        if grid.anchorDex == pageStart {
            scrollToPageStart(
                binder.currentPage,
                metrics: metrics,
                viewportHeight: viewportHeight,
                proxy: proxy
            )
        } else {
            proxy.scrollTo(grid.anchorDex, anchor: .center)
        }
    }

    /// Place the requested page's first row below the floating controls. Page 1
    /// targets the real top spacer so that clearance scrolls away naturally. Later
    /// pages use an equivalent viewport anchor instead of landing flush at y = 0.
    private func scrollToPageStart(
        _ page: Int,
        metrics: BinderMetrics,
        viewportHeight: CGFloat,
        proxy: ScrollViewProxy
    ) {
        let dex = (page - 1) * Pokedex.slotsPerPage + 1
        guard dex > 1 else {
            proxy.scrollTo(ScrollTarget.top, anchor: .top)
            return
        }

        let availableTravel = max(viewportHeight - metrics.cardHeight, 1)
        let anchorY = min(max(topInset / availableTravel, 0), 1)
        proxy.scrollTo(dex, anchor: UnitPoint(x: 0.5, y: anchorY))
    }

    private func recenter(on dex: Int, proxy: ScrollViewProxy) {
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) { proxy.scrollTo(dex, anchor: .center) }
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
