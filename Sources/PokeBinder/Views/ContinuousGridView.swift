import PokeBinderGrid
import SwiftUI

/// A fixed 14-column surface of all 151 cards. Two-finger trackpad pans in any
/// direction with native momentum; cards clip at the window edge.
struct ContinuousGridView: View {
    @EnvironmentObject private var binder: BinderState
    @EnvironmentObject private var collection: CollectionStore
    @EnvironmentObject private var grid: GridState
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @Binding var selection: CardSelection?
    @State private var locksAnchorToProgrammaticTarget = true

    var body: some View {
        GeometryReader { geo in
            let m = grid.metrics
            let surface = ContinuousGridLayout.contentSize(
                cardCount: Pokedex.count,
                cardWidth: Double(m.cardWidth),
                cardHeight: Double(m.cardHeight),
                gap: Double(m.cardGap)
            )
            let columns = Array(
                repeating: GridItem(.fixed(m.cardWidth), spacing: m.cardGap),
                count: ContinuousGridLayout.columns
            )

            ScrollViewReader { proxy in
                ScrollView([.horizontal, .vertical]) {
                    LazyVGrid(columns: columns, alignment: .leading, spacing: m.cardGap) {
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
                    .frame(
                        width: CGFloat(surface.width),
                        height: CGFloat(surface.height),
                        alignment: .topLeading
                    )
                }
                .scrollIndicators(.hidden)
                .scrollBounceBehavior(.always)
                .onScrollGeometryChange(for: CGPoint.self) {
                    CGPoint(x: $0.contentOffset.x, y: $0.contentOffset.y)
                } action: { _, offset in
                    guard !locksAnchorToProgrammaticTarget else { return }
                    grid.noteAnchor(
                        dex: ContinuousGridLayout.anchorDex(
                            offsetX: Double(offset.x),
                            offsetY: Double(offset.y),
                            viewportWidth: Double(geo.size.width),
                            viewportHeight: Double(geo.size.height),
                            cardCount: Pokedex.count,
                            cardWidth: Double(m.cardWidth),
                            cardHeight: Double(m.cardHeight),
                            gap: Double(m.cardGap)
                        )
                    )
                }
                .onScrollPhaseChange { _, newPhase in
                    if newPhase == .interacting {
                        locksAnchorToProgrammaticTarget = false
                    }
                }
                .onChange(of: grid.cardWidth) { _, _ in
                    recenter(on: grid.anchorDex, proxy: proxy)
                }
                .onChange(of: binder.currentMatchDex) { _, dex in
                    guard let dex else { return }
                    lockAnchor(to: dex)
                    withAnimation(motion(AppMotion.feedback)) {
                        proxy.scrollTo(dex, anchor: .center)
                    }
                }
                .onChange(of: binder.currentPage) { _, page in
                    guard !binder.isSearching else { return }
                    let dex = pageStartDex(page)
                    lockAnchor(to: dex)
                    withAnimation(motion(AppMotion.feedback)) {
                        proxy.scrollTo(dex, anchor: .center)
                    }
                }
                .onAppear {
                    lockAnchor(to: grid.anchorDex)
                    var transaction = Transaction()
                    transaction.disablesAnimations = true
                    withTransaction(transaction) {
                        proxy.scrollTo(grid.anchorDex, anchor: .center)
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

    private func pageStartDex(_ page: Int) -> Int {
        (page - 1) * Pokedex.slotsPerPage + 1
    }

    private func recenter(on dex: Int, proxy: ScrollViewProxy) {
        lockAnchor(to: dex)
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) { proxy.scrollTo(dex, anchor: .center) }
    }

    private func lockAnchor(to dex: Int) {
        grid.noteAnchor(dex: dex)
        locksAnchorToProgrammaticTarget = true
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

    private func motion(_ animation: Animation) -> Animation? {
        AppMotion.respectingReduceMotion(animation, reduceMotion: reduceMotion)
    }
}
