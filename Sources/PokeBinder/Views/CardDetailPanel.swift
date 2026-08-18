import SwiftUI

/// Opened by clicking a pocket. The user chose a popover over click-to-toggle so a
/// stray click can never edit the collection — marking a card owned is deliberate,
/// via the switch at the bottom.
///
/// Identity sits on the left; matchups and the Owned toggle sit on the right so
/// the panel stays short enough to clear the floating search controls.
///
/// The `Owned` toggle writes through `CollectionStore`, which is optimistic and
/// reverts on failure. Persist errors surface under the toggle.
struct CardDetailPanel: View {
    let dexNumber: Int
    let metrics: CardDetailMetrics
    var maxWidth: CGFloat
    var maxHeight: CGFloat = .infinity
    let onClose: () -> Void

    @EnvironmentObject private var collection: CollectionStore
    @Environment(\.appTheme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage(AppSettings.typeEraKey) private var typeEra: TypeEra = .current

    var body: some View {
        ViewThatFits(in: .vertical) {
            chromedBody
            ScrollView {
                chromedBody
            }
            .scrollBounceBehavior(.basedOnSize)
            .frame(maxHeight: maxHeight)
        }
        .frame(width: min(metrics.width, maxWidth))
        .fixedSize(horizontal: false, vertical: true)
    }

    private var chromedBody: some View {
        panelBody
            .panelChrome(in: RoundedRectangle(
                cornerRadius: metrics.cornerRadius(liquidGlass: theme.isLiquidGlass),
                style: .continuous
            ))
            .overlay(alignment: .topLeading) {
                pageIndicator
                    .padding(metrics.glyphInset)
            }
            .overlay(alignment: .topTrailing) {
                closeButton
                    .padding(metrics.glyphInset)
            }
    }

    private var panelBody: some View {
        HStack(alignment: .top, spacing: metrics.columnSpacing) {
            identityColumn
                .frame(width: metrics.artSize)

            Divider()

            detailsColumn
        }
        .padding(metrics.padding)
        .frame(width: min(metrics.width, maxWidth))
        .fixedSize(horizontal: false, vertical: true)
    }

    private var identityColumn: some View {
        VStack(spacing: metrics.identitySpacing) {
            CardArtworkView(dexNumber: dexNumber)
                .frame(width: metrics.artSize, height: metrics.artSize)
                .saturation(isOwned ? 1 : 0)
                .opacity(isOwned ? 1 : 0.5)
                .animation(ownershipMotion, value: isOwned)

            VStack(spacing: metrics.titleBlockSpacing) {
                Text(Pokedex.name(for: dexNumber))
                    .font(theme.nameFont(size: metrics.nameFontSize))
                    .foregroundStyle(theme.textPrimary)
                HStack(spacing: metrics.identityRowSpacing) {
                    Text("#\(Pokedex.formattedNumber(dexNumber))")
                        .font(theme.numberFont(size: metrics.numberFontSize))
                        .foregroundStyle(theme.textSecondary)

                    Divider()
                        .frame(height: metrics.identityDividerHeight)

                    TypeIconGroup(
                        types: Pokedex.types(for: dexNumber, era: typeEra),
                        size: metrics.identityIconSize,
                        spacing: metrics.identityIconSpacing,
                        isMuted: !isOwned
                    )
                }
            }
        }
    }

    private var detailsColumn: some View {
        VStack(alignment: .leading, spacing: metrics.detailsSpacing) {
            TypeMatchupTable(dexNumber: dexNumber, metrics: metrics, isMuted: !isOwned)

            VStack(alignment: .leading, spacing: metrics.toggleGroupSpacing) {
                Toggle("Owned", isOn: ownedBinding)
                    .toggleStyle(.switch)
                    .controlSize(metrics.scale >= 1.3 ? .large : .regular)
                    .tint(theme.brass)
                    .font(theme.nameFont(size: metrics.ownedLabelFontSize))

                if let message = collection.errorMessage {
                    Text(message)
                        .font(.system(size: metrics.errorFontSize))
                        .foregroundStyle(.red)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }

    private var pageDetailsLabel: String {
        "Page \(Pokedex.page(for: dexNumber)) · Slot \(Pokedex.absolutePosition(for: dexNumber)) of \(Pokedex.slotsPerPage)"
    }

    @ViewBuilder
    private var pageIndicator: some View {
        cornerGlyph("book.closed")
            .hoverTooltip(pageDetailsLabel)
            .accessibilityLabel(pageDetailsLabel)
    }

    @ViewBuilder
    private var closeButton: some View {
        Button(action: onClose) {
            cornerGlyph("xmark")
        }
        .buttonStyle(.plain)
        .help("Close")
        .accessibilityLabel("Close")
    }

    private func cornerGlyph(_ systemName: String) -> some View {
        let glyph = Image(systemName: systemName)
            .font(.system(size: metrics.glyphIconSize, weight: .bold))
            .foregroundStyle(theme.textSecondary)
            .frame(width: metrics.glyphSize, height: metrics.glyphSize)
            .contentShape(Circle())

        return Group {
            if theme.isLiquidGlass {
                glyph
            } else {
                glyph.pillChrome(in: Circle(), interactive: true)
            }
        }
    }

    private var isOwned: Bool { collection.isOwned(dexNumber) }

    private var ownershipMotion: Animation? {
        AppMotion.respectingReduceMotion(AppMotion.feedback, reduceMotion: reduceMotion)
    }

    private var ownedBinding: Binding<Bool> {
        Binding(
            get: { collection.isOwned(dexNumber) },
            set: { newValue in
                Task { await collection.setOwned(dexNumber, newValue) }
            }
        )
    }
}
