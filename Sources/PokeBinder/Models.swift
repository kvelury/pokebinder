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

/// How the grid lays out and scrolls. Classic is the original vertical reflow
/// sheet. Continuous is a fixed 2D surface you can pan in any direction.
enum GridLayoutMode: String, CaseIterable, Identifiable {
    case classic
    case continuous

    var id: String { rawValue }

    var title: String {
        switch self {
        case .classic: "Classic"
        case .continuous: "Continuous"
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

    static func forDex(_ dex: Int) -> BinderSlot {
        BinderSlot(
            page: Pokedex.page(for: dex),
            side: Pokedex.side(for: dex),
            slot: Pokedex.slot(for: dex),
            dexNumber: dex
        )
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

/// A pocket the user clicked, plus its on-screen frame for the detail transition.
struct CardSelection: Equatable {
    let dexNumber: Int
    let sourceRect: CGRect
}

/// The coordinate space shared by card transitions and root-level hover tooltips. Named on
/// `ContentView`'s root ZStack, which is the content area below the toolbar.
enum BinderSpace {
    static let content = "binder.content"
}
