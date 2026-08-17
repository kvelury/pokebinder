import SwiftUI

/// Opened by clicking a pocket. The user chose a popover over click-to-toggle so a
/// stray click can never edit the collection — marking a card owned is deliberate,
/// via the switch at the bottom.
///
/// The `Owned` toggle writes through `CollectionStore`, which is optimistic and
/// reverts on failure. Persist errors surface under the toggle.
struct CardDetailPanel: View {
    /// Wider than a pocket at every window size the binder supports, so the
    /// overlay reads as a focus view rather than a blown-up popover.
    static let width: CGFloat = 420
    static let artSize: CGFloat = 360

    let dexNumber: Int
    let onClose: () -> Void

    @EnvironmentObject private var collection: CollectionStore
    @Environment(\.appTheme) private var theme
    @AppStorage(AppSettings.typeEraKey) private var typeEra: TypeEra = .current

    var body: some View {
        VStack(spacing: 16) {
            CardArtworkView(dexNumber: dexNumber)
                .frame(width: Self.artSize, height: Self.artSize)
                .saturation(isOwned ? 1 : 0)
                .opacity(isOwned ? 1 : 0.5)
                .animation(.easeOut(duration: 0.25), value: isOwned)

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

            Divider()

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
        .padding(24)
        .frame(width: Self.width)
        .panelChrome(in: RoundedRectangle(
            cornerRadius: theme.isLiquidGlass ? 24 : 16,
            style: .continuous
        ))
        .overlay {
            HStack {
                pageIndicator
                Spacer()
                closeButton
            }
            .padding(10)
        }
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

    private var ownedBinding: Binding<Bool> {
        Binding(
            get: { collection.isOwned(dexNumber) },
            set: { newValue in
                Task { await collection.setOwned(dexNumber, newValue) }
            }
        )
    }
}
