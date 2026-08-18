import SwiftUI

/// The hover counterpart to `CardDetailPanel`: same type information, no artwork,
/// no ownership control, and one detail level shallower. Presented by
/// `HoverTooltipHost`, so it is never hit-tested and never dismissible.
struct CardHoverCard: View {
    let dexNumber: Int
    let metrics: CardDetailMetrics

    @EnvironmentObject private var collection: CollectionStore
    @Environment(\.appTheme) private var theme
    @AppStorage(AppSettings.typeEraKey) private var typeEra: TypeEra = .current
    @AppStorage(AppSettings.matchupDetailLevelKey) private var detailLevel: MatchupDetailLevel = .simple

    var body: some View {
        let rowLevel = detailLevel.hoverRowLevel
        VStack(alignment: .leading, spacing: metrics.hoverSectionSpacing) {
            header
            Divider()
            typeRows
            if let rowLevel {
                Divider()
                TypeMatchupTable(
                    dexNumber: dexNumber,
                    metrics: metrics,
                    isMuted: !isOwned,
                    levelOverride: rowLevel,
                    showsRetry: false
                )
            }
        }
        .padding(metrics.hoverPadding)
        // Types-only stays as small as its content; with rows, match the panel's
        // details-column width so the chips wrap identically.
        .modifier(HoverWidth(width: rowLevel == nil ? nil : metrics.hoverWidth))
        .panelChrome(in: RoundedRectangle(
            cornerRadius: metrics.hoverCornerRadius(liquidGlass: theme.isLiquidGlass),
            style: .continuous
        ))
        .accessibilityHidden(true)
    }

    private var isOwned: Bool { collection.isOwned(dexNumber) }

    private var header: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(Pokedex.name(for: dexNumber))
                .font(theme.nameFont(size: metrics.hoverTitleFontSize))
                .foregroundStyle(theme.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Spacer(minLength: 8)
            Text("#\(Pokedex.formattedNumber(dexNumber))")
                .font(theme.numberFont(size: metrics.hoverNumberFontSize))
                .foregroundStyle(theme.textSecondary)
        }
    }

    private var typeRows: some View {
        VStack(alignment: .leading, spacing: metrics.hoverTypeRowSpacing) {
            ForEach(Pokedex.types(for: dexNumber, era: typeEra)) { type in
                HStack(spacing: metrics.hoverTypeRowSpacing) {
                    TypeIconView(
                        type: type,
                        size: metrics.hoverTypeIconSize,
                        isMuted: !isOwned,
                        showsTooltip: false
                    )
                    Text(type.title)
                        .font(theme.nameFont(size: metrics.hoverTypeLabelSize))
                        .foregroundStyle(theme.textPrimary)
                }
            }
        }
    }
}

/// `.frame(width:)` when a width is given, `.fixedSize()` when it is not. A plain
/// `if` in the modifier chain will not type-check.
private struct HoverWidth: ViewModifier {
    let width: CGFloat?

    func body(content: Content) -> some View {
        if let width {
            content.frame(width: width)
        } else {
            content.fixedSize()
        }
    }
}
