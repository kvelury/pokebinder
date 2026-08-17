import SwiftUI

/// One side of the open spread — a paper page holding a 2x2 block of pockets.
///
/// Side 1 (left) is Absolute Positions 1–4, side 2 (right) is 5–8. The gutter
/// shadow falls toward the spine, which is what makes the two pages read as one
/// bound spread rather than two floating panels.
struct PageSideView: View {
    let page: Int
    let side: BinderSide
    let metrics: BinderMetrics
    @Binding var selectedDex: Int?

    @EnvironmentObject private var binder: BinderState
    @EnvironmentObject private var collection: CollectionStore

    private var slots: [BinderSlot] { BinderSlot.slots(page: page, side: side) }

    var body: some View {
        ZStack {
            pageBackground
            VStack(spacing: metrics.cardGap) {
                HStack(spacing: metrics.cardGap) {
                    slotView(slots[0])
                    slotView(slots[1])
                }
                HStack(spacing: metrics.cardGap) {
                    slotView(slots[2])
                    slotView(slots[3])
                }
            }
        }
        .frame(width: metrics.pageWidth, height: metrics.pageHeight)
    }

    private func slotView(_ slot: BinderSlot) -> some View {
        CardSlotView(
            slot: slot,
            metrics: metrics,
            isOwned: slot.dexNumber.map(collection.isOwned) ?? false,
            emphasis: binder.emphasis(for: slot.dexNumber),
            selectedDex: $selectedDex
        )
    }

    private var pageBackground: some View {
        let shape = RoundedRectangle(cornerRadius: metrics.pageCornerRadius, style: .continuous)
        return shape
            .fill(Theme.page)
            .overlay(
                // Darkening toward the spine — the page curving into the gutter.
                LinearGradient(
                    colors: [.clear, .black.opacity(0.14)],
                    startPoint: side == .left ? .leading : .trailing,
                    endPoint: side == .left ? .trailing : .leading
                )
                .mask(shape)
            )
            .overlay(shape.strokeBorder(.black.opacity(0.08), lineWidth: 1))
            .shadow(color: .black.opacity(0.22), radius: metrics.cardWidth * 0.05, y: metrics.cardWidth * 0.02)
    }
}
