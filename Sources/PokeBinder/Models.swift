import Foundation

/// Which half of the open spread a pocket sits on.
/// Side 1 (left) holds Absolute Positions 1–4, side 2 (right) holds 5–8.
enum BinderSide: Hashable, CaseIterable {
    case left, right
}

enum ViewMode: Hashable, CaseIterable, Identifiable {
    case binder, grid
    var id: Self { self }

    var title: String {
        switch self {
        case .binder: return "Binder"
        case .grid: return "Grid"
        }
    }
}

/// One pocket of the binder. `dexNumber` is nil for the permanently empty pocket
/// at the end of page 19.
struct BinderSlot: Identifiable, Hashable {
    let page: Int
    let side: BinderSide
    let slot: Int
    let dexNumber: Int?

    var id: String { "\(page)-\(side)-\(slot)" }

    var name: String? { dexNumber.map(Pokedex.name(for:)) }
    var formattedNumber: String? { dexNumber.map(Pokedex.formattedNumber) }

    static func slots(page: Int, side: BinderSide) -> [BinderSlot] {
        (1...Pokedex.slotsPerSide).map { slot in
            BinderSlot(
                page: page,
                side: side,
                slot: slot,
                dexNumber: Pokedex.dexNumber(page: page, side: side, slot: slot)
            )
        }
    }
}

/// How a slot should be drawn once search is taken into account.
enum SlotEmphasis {
    /// No search running — draw normally.
    case normal
    /// The match you are currently on: full brass ring, lifted, glowing.
    case spotlit
    /// Also a match, but not the one you're cycling on. Ringed more quietly, so
    /// stepping through matches with ⏎ is visible.
    case match
    /// Search running and this slot does not match.
    case dimmed
}

/// A pocket the user clicked, plus where that pocket was on screen when they
/// clicked it. The rect is what the detail panel grows out of and shrinks back
/// into — captured at tap time rather than tracked live, so a page turn or a
/// window resize behind the panel cannot move the target mid-flight.
struct CardSelection: Equatable {
    let dexNumber: Int
    /// The pocket's frame in the `BinderSpace.content` coordinate space.
    let sourceRect: CGRect
}

/// The one coordinate space the pocket and the zoom overlay agree on. Named on
/// `ContentView`'s root ZStack, which is the content area below the toolbar.
enum BinderSpace {
    static let content = "binder.content"
}
