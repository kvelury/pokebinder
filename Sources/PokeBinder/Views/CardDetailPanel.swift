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
    /// Wide enough for art plus a two-row matchup grid, still inside the
    /// app's 1000-point minimum window after overlay margins.
    static let width: CGFloat = 900
    static let artSize: CGFloat = 280

    let dexNumber: Int
    var maxWidth: CGFloat = width
    var maxHeight: CGFloat = .infinity
    let onClose: () -> Void

    @EnvironmentObject private var collection: CollectionStore
    @Environment(\.appTheme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage(AppSettings.typeEraKey) private var typeEra: TypeEra = .current

    var body: some View {
        ViewThatFits(in: .vertical) {
            panelBody
            ScrollView {
                panelBody
            }
            .scrollBounceBehavior(.basedOnSize)
        }
        .frame(width: min(Self.width, maxWidth))
        .frame(maxHeight: maxHeight)
        .panelChrome(in: RoundedRectangle(
            cornerRadius: theme.isLiquidGlass ? 24 : 16,
            style: .continuous
        ))
        .overlay(alignment: .topLeading) {
            pageIndicator
                .padding(10)
        }
        .overlay(alignment: .topTrailing) {
            closeButton
                .padding(10)
        }
    }

    private var panelBody: some View {
        HStack(alignment: .top, spacing: 20) {
            identityColumn
                .frame(width: Self.artSize)

            Divider()

            detailsColumn
        }
        .padding(24)
        .frame(width: min(Self.width, maxWidth))
    }

    private var identityColumn: some View {
        VStack(spacing: 14) {
            CardArtworkView(dexNumber: dexNumber)
                .frame(width: Self.artSize, height: Self.artSize)
                .saturation(isOwned ? 1 : 0)
                .opacity(isOwned ? 1 : 0.5)
                .animation(ownershipMotion, value: isOwned)

            VStack(spacing: 4) {
                Text(Pokedex.name(for: dexNumber))
                    .font(theme.nameFont(size: 22))
                    .foregroundStyle(theme.textPrimary)
                HStack(spacing: 11) {
                    Text("#\(Pokedex.formattedNumber(dexNumber))")
                        .font(theme.numberFont(size: 14))
                        .foregroundStyle(theme.textSecondary)

                    Divider()
                        .frame(height: 20)

                    TypeIconGroup(
                        types: Pokedex.types(for: dexNumber, era: typeEra),
                        size: 24,
                        spacing: 5,
                        isMuted: !isOwned
                    )
                }
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var detailsColumn: some View {
        VStack(alignment: .leading, spacing: 16) {
            TypeMatchupTable(dexNumber: dexNumber, isMuted: !isOwned)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

            VStack(alignment: .leading, spacing: 8) {
                Toggle("Owned", isOn: ownedBinding)
                    .toggleStyle(.switch)
                    .tint(theme.brass)
                    .font(theme.nameFont(size: 15))

                if let message = collection.errorMessage {
                    Text(message)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
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
            .font(.system(size: 10, weight: .bold))
            .foregroundStyle(theme.textSecondary)
            .frame(width: 22, height: 22)
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
