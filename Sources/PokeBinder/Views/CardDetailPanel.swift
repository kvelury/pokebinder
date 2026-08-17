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

    var body: some View {
        VStack(spacing: 16) {
            CardArtworkView(dexNumber: dexNumber)
                .frame(width: Self.artSize, height: Self.artSize)
                .saturation(isOwned ? 1 : 0)
                .opacity(isOwned ? 1 : 0.5)
                .animation(.easeOut(duration: 0.25), value: isOwned)

            VStack(spacing: 4) {
                Text(Pokedex.name(for: dexNumber))
                    .font(Theme.nameFont(size: 22))
                    .foregroundStyle(Theme.textPrimary)
                Text("#\(Pokedex.formattedNumber(dexNumber))")
                    .font(Theme.numberFont(size: 14))
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
                .font(Theme.nameFont(size: 15))

            if let message = collection.errorMessage {
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(24)
        .frame(width: Self.width)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Theme.page)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Theme.controlStroke, lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.35), radius: 28, y: 12)
        .overlay(alignment: .topTrailing) {
            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(Theme.textSecondary)
                    .frame(width: 22, height: 22)
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .pillChrome(in: Circle())
            .padding(10)
            .help("Close")
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
