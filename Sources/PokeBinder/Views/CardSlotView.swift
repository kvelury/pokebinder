import SwiftUI

/// One pocket of the binder: a plastic sleeve holding a card.
///
/// Layout is the "corner badge + name" design the user chose — mono Pokédex number
/// in a badge at the top-left, artwork filling the middle, name centred at the base.
/// Missing cards get the "grayscale + dashed sleeve" treatment: desaturated art at
/// reduced opacity behind a dashed border, with the number still fully legible.
struct CardSlotView: View {
    let slot: BinderSlot
    let metrics: BinderMetrics
    let isOwned: Bool
    let emphasis: SlotEmphasis
    @Binding var selectedDex: Int?

    @State private var isHovering = false

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: metrics.cardCornerRadius, style: .continuous)
    }

    var body: some View {
        ZStack {
            sleeve
            if let dex = slot.dexNumber {
                cardContent(dex: dex)
            }
        }
        .frame(width: metrics.cardWidth, height: metrics.cardHeight)
        .overlay(border)
        .contentShape(shape)
        .opacity(emphasis == .dimmed ? 0.32 : 1)
        .scaleEffect(scale)
        .shadow(
            color: Theme.brass.opacity(emphasis == .spotlit ? 0.45 : 0),
            radius: metrics.cardWidth * 0.09
        )
        .animation(.easeOut(duration: 0.22), value: emphasis)
        .animation(.easeOut(duration: 0.15), value: isHovering)
        .animation(.easeOut(duration: 0.2), value: isOwned)
        .onHover { isHovering = $0 }
        .onTapGesture {
            guard let dex = slot.dexNumber else { return }
            selectedDex = (selectedDex == dex) ? nil : dex
        }
        .popover(isPresented: popoverBinding, arrowEdge: .bottom) {
            if let dex = slot.dexNumber {
                CardDetailPopover(dexNumber: dex)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
    }

    // MARK: - Pieces

    /// The plastic pocket. The inner shadow is what sells it as a sleeve rather
    /// than a flat rectangle.
    private var sleeve: some View {
        shape.fill(
            Theme.sleeve.shadow(
                .inner(color: .black.opacity(0.20), radius: metrics.cardWidth * 0.03, y: metrics.cardWidth * 0.012)
            )
        )
    }

    private func cardContent(dex: Int) -> some View {
        VStack(spacing: 0) {
            ZStack(alignment: .topLeading) {
                Color.clear
                CardArtworkView(dexNumber: dex)
                    .padding(.horizontal, metrics.cardWidth * 0.07)
                    .padding(.top, metrics.cardWidth * 0.06)
                    .saturation(isOwned ? 1 : 0)
                    .opacity(isOwned ? 1 : 0.45)
                numberBadge(dex: dex)
                    .padding(metrics.cardWidth * 0.05)
            }
            Text(Pokedex.name(for: dex))
                .font(Theme.nameFont(size: metrics.cardWidth * 0.108))
                .foregroundStyle(isOwned ? Theme.textPrimary : Theme.textSecondary)
                .lineLimit(1)
                .minimumScaleFactor(0.55)
                .padding(.horizontal, metrics.cardWidth * 0.06)
                .padding(.bottom, metrics.cardWidth * 0.085)
        }
    }

    /// Stays fully legible even when the card is missing — that was the point of
    /// choosing the corner badge over text laid over the art.
    private func numberBadge(dex: Int) -> some View {
        Text(Pokedex.formattedNumber(dex))
            .font(Theme.numberFont(size: metrics.cardWidth * 0.088))
            .foregroundStyle(isOwned ? Theme.brassDeep : Theme.textSecondary)
            .padding(.horizontal, metrics.cardWidth * 0.052)
            .padding(.vertical, metrics.cardWidth * 0.024)
            .background(
                Capsule().fill(Theme.page.opacity(isOwned ? 0.92 : 0.62))
            )
            .overlay(
                Capsule().strokeBorder(
                    isOwned ? Theme.brass.opacity(0.5) : Theme.missingOutline.opacity(0.7),
                    lineWidth: 0.75
                )
            )
    }

    @ViewBuilder
    private var border: some View {
        if emphasis == .spotlit {
            shape.strokeBorder(Theme.brass, lineWidth: max(2.5, metrics.cardWidth * 0.02))
        } else if emphasis == .match {
            shape.strokeBorder(Theme.brass.opacity(0.55), lineWidth: max(1.5, metrics.cardWidth * 0.012))
        } else if slot.dexNumber == nil {
            // The permanently empty pocket at the end of page 19.
            shape.strokeBorder(
                Theme.missingOutline.opacity(0.45),
                style: StrokeStyle(lineWidth: 1, dash: [3, 5])
            )
        } else if isOwned {
            shape.strokeBorder(Theme.brass.opacity(0.8), lineWidth: 1)
        } else {
            shape.strokeBorder(
                Theme.missingOutline,
                style: StrokeStyle(lineWidth: 1.5, dash: [5, 4])
            )
        }
    }

    // MARK: - Derived

    private var scale: CGFloat {
        if emphasis == .spotlit { return 1.04 }
        if isHovering && slot.dexNumber != nil { return 1.02 }
        return 1
    }

    private var popoverBinding: Binding<Bool> {
        Binding(
            get: { slot.dexNumber != nil && selectedDex == slot.dexNumber },
            set: { if !$0 { selectedDex = nil } }
        )
    }

    private var accessibilityLabel: String {
        guard let dex = slot.dexNumber else { return "Empty pocket" }
        return "\(Pokedex.name(for: dex)), number \(dex), \(isOwned ? "owned" : "missing")"
    }
}
