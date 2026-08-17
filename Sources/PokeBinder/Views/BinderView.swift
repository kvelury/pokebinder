import SwiftUI

/// The open binder: a cover, two pages, and the ring hardware down the middle.
///
/// The whole spread scales as one object from a single derived card width
/// (`BinderMetrics.fitting`), so it never distorts at any window size.
///
/// **Part 2 hook:** the spread for a given page is isolated in `BinderSpread`, and
/// every page change funnels through `BinderState.goTo(page:)`. To add the 3D page
/// turn, keep the outgoing and incoming `BinderSpread` in the hierarchy together and
/// drive `rotation3DEffect` on the leaving half around the ring axis — nothing else
/// in this file should need to move.
struct BinderView: View {
    @EnvironmentObject private var binder: BinderState
    @EnvironmentObject private var collection: CollectionStore

    @State private var selectedDex: Int?

    /// Room left for the floating pager bar so the binder never sits under it.
    private let outerInset: CGFloat = 28
    private let bottomInset: CGFloat = 88

    var body: some View {
        GeometryReader { geo in
            let available = CGSize(
                width: max(geo.size.width - outerInset * 2, 1),
                height: max(geo.size.height - outerInset - bottomInset, 1)
            )
            let metrics = BinderMetrics.fitting(available)

            BinderSpread(page: binder.currentPage, metrics: metrics, selectedDex: $selectedDex)
                .frame(width: metrics.totalWidth, height: metrics.totalHeight)
                .frame(width: geo.size.width, height: geo.size.height - bottomInset + outerInset, alignment: .center)
        }
        // Clicking the page background dismisses an open card popover.
        .contentShape(Rectangle())
        .onTapGesture { selectedDex = nil }
    }
}

/// One complete open spread. Isolated so part 2 can render two at once mid-turn.
struct BinderSpread: View {
    let page: Int
    let metrics: BinderMetrics
    @Binding var selectedDex: Int?

    var body: some View {
        ZStack {
            cover
            HStack(spacing: 0) {
                PageSideView(page: page, side: .left, metrics: metrics, selectedDex: $selectedDex)
                SpineView(metrics: metrics)
                PageSideView(page: page, side: .right, metrics: metrics, selectedDex: $selectedDex)
            }
        }
    }

    private var cover: some View {
        let shape = RoundedRectangle(cornerRadius: metrics.coverCornerRadius, style: .continuous)
        return shape
            .fill(
                LinearGradient(
                    colors: [Theme.coverHighlight, Theme.cover, Theme.coverDeep],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .overlay(
                // A thin lit edge along the top, so the cover reads as a solid object
                // catching light rather than a flat fill.
                shape.strokeBorder(
                    LinearGradient(
                        colors: [.white.opacity(0.22), .clear, .black.opacity(0.25)],
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    lineWidth: 1.5
                )
            )
            .shadow(color: .black.opacity(0.35), radius: metrics.cardWidth * 0.16, y: metrics.cardWidth * 0.06)
    }
}

/// The ring channel between the two pages.
struct SpineView: View {
    let metrics: BinderMetrics

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Theme.coverDeep, Theme.cover, Theme.cover, Theme.coverDeep],
                startPoint: .leading,
                endPoint: .trailing
            )
            .overlay(
                // Pages cast into the gutter from both sides.
                LinearGradient(
                    colors: [.black.opacity(0.30), .clear, .black.opacity(0.30)],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )

            VStack(spacing: metrics.pageHeight * 0.22) {
                ForEach(0..<3, id: \.self) { _ in ring }
            }
        }
        .frame(width: metrics.spineWidth, height: metrics.pageHeight)
    }

    private var ring: some View {
        Circle()
            .strokeBorder(
                LinearGradient(
                    colors: [Theme.brassBright, Theme.brass, Theme.brassDeep, Theme.brass],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                lineWidth: metrics.ringThickness
            )
            .frame(width: metrics.ringDiameter, height: metrics.ringDiameter)
            .shadow(color: .black.opacity(0.45), radius: metrics.ringThickness * 0.8, y: 1)
    }
}
