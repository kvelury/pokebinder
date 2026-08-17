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
    @Binding var selection: CardSelection?

    @Environment(\.appTheme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage(AppSettings.typeEraKey) private var typeEra: TypeEra = .current
    @State private var isHovering = false
    @State private var frameInContent: CGRect = .zero

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
        .onGeometryChange(for: CGRect.self) { proxy in
            proxy.frame(in: .named(BinderSpace.content))
        } action: { frameInContent = $0 }
        .overlay(border)
        .contentShape(shape)
        .opacity(emphasis == .dimmed ? 0.32 : 1)
        .scaleEffect(scale)
        .shadow(
            color: theme.brass.opacity(emphasis == .spotlit ? 0.45 : 0),
            radius: metrics.cardWidth * 0.09
        )
        .animation(motion(AppMotion.feedback), value: emphasis)
        .animation(motion(AppMotion.quick), value: isHovering)
        .animation(motion(AppMotion.feedback), value: isOwned)
        .onHover { isHovering = $0 }
        .onTapGesture {
            guard let dex = slot.dexNumber else { return }
            if selection?.dexNumber == dex {
                selection = nil
            } else {
                selection = CardSelection(dexNumber: dex, sourceRect: frameInContent)
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
            theme.sleeve.shadow(
                .inner(color: .black.opacity(0.20), radius: metrics.cardWidth * 0.03, y: metrics.cardWidth * 0.012)
            )
        )
    }

    private func cardContent(dex: Int) -> some View {
        VStack(spacing: 0) {
            ZStack(alignment: .topLeading) {
                Color.clear
                CardArtworkView(dexNumber: dex)
                    .saturation(isOwned ? 1 : 0)
                    .opacity(isOwned ? 1 : 0.45)
                    .padding(.horizontal, metrics.cardWidth * 0.07)
                    .padding(.vertical, metrics.cardWidth * 0.06)
                    // The art is square but the pocket is not, so a top-aligned image leaves all of
                    // its slack under the art and reads as sitting too high. Filling the region and
                    // letting the frame centre it puts the art in the middle of the space it
                    // actually has, without moving the badge off the corner.
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    // The name sits below this ZStack, so a true center in the remaining
                    // region still reads high on the card. Insetting from the top recentres
                    // in the space between the badge and the name, without shrinking the art.
                    .padding(.top, metrics.cardWidth * 0.16)
                numberBadge(dex: dex)
                    .padding(metrics.cardWidth * 0.05)
                TypeIconGroup(
                    types: Pokedex.types(for: dex, era: typeEra),
                    size: max(10, metrics.cardWidth * 0.14),
                    spacing: metrics.cardWidth * 0.018,
                    isMuted: !isOwned
                )
                .padding(metrics.cardWidth * 0.05)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
            }
            Text(Pokedex.name(for: dex))
                .font(theme.nameFont(size: metrics.cardWidth * 0.108))
                .foregroundStyle(isOwned ? theme.textPrimary : theme.textSecondary)
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
            .font(theme.numberFont(size: metrics.cardWidth * 0.088))
            .foregroundStyle(isOwned ? theme.brassDeep : theme.textSecondary)
            .padding(.horizontal, metrics.cardWidth * 0.052)
            .padding(.vertical, metrics.cardWidth * 0.024)
            .background(
                Capsule().fill(theme.page.opacity(isOwned ? 0.92 : 0.62))
            )
            .overlay(
                Capsule().strokeBorder(
                    isOwned ? theme.brass.opacity(0.5) : theme.missingOutline.opacity(0.7),
                    lineWidth: 0.75
                )
            )
    }

    @ViewBuilder
    private var border: some View {
        if emphasis == .spotlit {
            shape.strokeBorder(theme.brass, lineWidth: max(2.5, metrics.cardWidth * 0.02))
        } else if emphasis == .match {
            shape.strokeBorder(theme.brass.opacity(0.55), lineWidth: max(1.5, metrics.cardWidth * 0.012))
        } else if slot.dexNumber == nil {
            // The permanently empty pocket at the end of page 19.
            shape.strokeBorder(
                theme.missingOutline.opacity(0.45),
                style: StrokeStyle(lineWidth: 1, dash: [3, 5])
            )
        } else if isOwned {
            shape.strokeBorder(theme.brass.opacity(0.8), lineWidth: 1)
        } else {
            shape.strokeBorder(
                theme.missingOutline,
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

    private func motion(_ animation: Animation) -> Animation? {
        AppMotion.respectingReduceMotion(animation, reduceMotion: reduceMotion)
    }

    private var accessibilityLabel: String {
        guard let dex = slot.dexNumber else { return "Empty pocket" }
        let typeNames = Pokedex.types(for: dex, era: typeEra).map(\.title)
            .joined(separator: " and ")
        return "\(Pokedex.name(for: dex)), number \(dex), \(typeNames) type, \(isOwned ? "owned" : "missing")"
    }
}
