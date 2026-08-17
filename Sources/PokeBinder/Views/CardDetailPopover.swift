import SwiftUI

/// Opened by clicking a pocket. The user chose a popover over click-to-toggle so a
/// stray click can never edit the collection — marking a card owned is deliberate,
/// via the switch at the bottom.
///
/// The `Owned` toggle writes through `CollectionStore`, which is optimistic and
/// reverts on failure. Persist errors surface under the toggle.
struct CardDetailPopover: View {
    let dexNumber: Int

    @EnvironmentObject private var collection: CollectionStore

    var body: some View {
        VStack(spacing: 14) {
            CardArtworkView(dexNumber: dexNumber)
                .frame(width: 180, height: 180)
                .saturation(isOwned ? 1 : 0)
                .opacity(isOwned ? 1 : 0.5)
                .animation(.easeOut(duration: 0.25), value: isOwned)

            VStack(spacing: 3) {
                Text(Pokedex.name(for: dexNumber))
                    .font(Theme.nameFont(size: 19))
                    .foregroundStyle(Theme.textPrimary)
                Text("#\(Pokedex.formattedNumber(dexNumber))")
                    .font(Theme.numberFont(size: 13))
                    .foregroundStyle(Theme.textSecondary)
            }

            Divider()

            HStack {
                Label("Page \(Pokedex.page(for: dexNumber))", systemImage: "book.closed")
                Spacer()
                Text("Slot \(Pokedex.absolutePosition(for: dexNumber)) of \(Pokedex.slotsPerPage)")
            }
            .font(.caption)
            .foregroundStyle(Theme.textSecondary)

            Divider()

            Toggle("Owned", isOn: ownedBinding)
                .toggleStyle(.switch)
                .tint(Theme.brass)
                .font(Theme.nameFont(size: 14))

            if let message = collection.errorMessage {
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(18)
        .frame(width: 250)
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
