import SwiftUI

/// The hover counterpart to `CardDetailPanel`: type information at the level chosen
/// in Settings, no artwork, and no ownership control. Presented by
/// `HoverTooltipHost`, so it is never hit-tested and never dismissible.
struct CardHoverCard: View {
    let dexNumber: Int
    let metrics: CardDetailMetrics

    @EnvironmentObject private var collection: CollectionStore
    @Environment(\.appTheme) private var theme
    @AppStorage(AppSettings.typeEraKey) private var typeEra: TypeEra = .current
    @AppStorage(AppSettings.matchupDetailLevelKey) private var detailLevel: MatchupDetailLevel = .simple

    var body: some View {
        VStack(alignment: .leading, spacing: metrics.hoverSectionSpacing) {
            header
            Divider()
            typeRows
            Divider()
            TypeMatchupTable(
                dexNumber: dexNumber,
                metrics: metrics,
                isMuted: !isOwned,
                levelOverride: detailLevel,
                showsRetry: false
            )
        }
        .padding(metrics.hoverPadding)
        .frame(width: metrics.hoverWidth)
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
