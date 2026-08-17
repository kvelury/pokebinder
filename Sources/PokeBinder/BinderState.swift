import Foundation
import SwiftUI

/// Which page is open, which view is showing, and what search is matching.
///
/// Part 1 owns page navigation and match *computation*. Part 2 layers the motion
/// and navigation behaviours on top: the 3D page turn, auto-flipping to the first
/// match, and ⏎/⌘G cycling through `matches`. Those all drive `goTo(page:)`, so
/// part 2 should not need to change how matching works.
@MainActor
final class BinderState: ObservableObject {
    @Published var viewMode: ViewMode = .binder

    /// Always opens on page 1 — the app "automatically opens to the first page".
    @Published private(set) var currentPage: Int = 1

    @Published var searchText: String = "" {
        didSet { recomputeMatches() }
    }

    /// Pokédex numbers matching the current query, in binder order.
    @Published private(set) var matches: [Int] = []
    private var matchSet: Set<Int> = []

    /// Which match you are currently parked on. Drives both the auto-flip and the
    /// stronger of the two highlight treatments.
    @Published private(set) var currentMatchIndex: Int?

    var currentMatchDex: Int? {
        guard let index = currentMatchIndex, matches.indices.contains(index) else { return nil }
        return matches[index]
    }

    /// "2 of 7" — shown beside the search field.
    var matchPositionLabel: String {
        guard !matches.isEmpty else { return "no matches" }
        let position = (currentMatchIndex ?? 0) + 1
        return "\(position) of \(matches.count)"
    }

    var isSearching: Bool {
        !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var canGoPrevious: Bool { currentPage > 1 }
    var canGoNext: Bool { currentPage < Pokedex.pageCount }

    // MARK: - Navigation
    //
    // Every way of changing pages — arrows, the editable field, keyboard shortcuts,
    // and (in part 2) search auto-flip — funnels through goTo(page:) so there is a
    // single place for the page-turn animation to hook into.

    func goTo(page: Int) {
        let clamped = min(max(page, 1), Pokedex.pageCount)
        guard clamped != currentPage else { return }
        currentPage = clamped
        prefetchNeighbours()
    }

    func next() { goTo(page: currentPage + 1) }
    func previous() { goTo(page: currentPage - 1) }

    /// Warm the pages either side so a flip is never blank.
    func prefetchNeighbours() {
        let pages = [currentPage, currentPage - 1, currentPage + 1]
        Task {
            for page in pages {
                await ArtworkStore.shared.prefetch(page: page)
            }
        }
    }

    // MARK: - Search

    /// The page holding the first match, if there is one.
    var firstMatchPage: Int? {
        matches.first.map(Pokedex.page(for:))
    }

    /// Step to the next match, wrapping, flipping the binder to reach it.
    func nextMatch() {
        guard !matches.isEmpty else { return }
        focusMatch(at: ((currentMatchIndex ?? -1) + 1) % matches.count)
    }

    func previousMatch() {
        guard !matches.isEmpty else { return }
        focusMatch(at: ((currentMatchIndex ?? 0) - 1 + matches.count) % matches.count)
    }

    private func focusMatch(at index: Int) {
        currentMatchIndex = index
        goTo(page: Pokedex.page(for: matches[index]))
    }

    func emphasis(for dexNumber: Int?) -> SlotEmphasis {
        guard isSearching else { return .normal }
        guard let dexNumber, matchSet.contains(dexNumber) else { return .dimmed }
        return dexNumber == currentMatchDex ? .spotlit : .match
    }

    private func recomputeMatches() {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else {
            matches = []
            matchSet = []
            currentMatchIndex = nil
            // Deliberately does not navigate: clearing the field should leave you
            // on the page you were reading, not throw you back to page 1.
            return
        }

        // A bare number means that exact Pokédex entry — typing "25" should land on
        // Pikachu, not on every number containing a 2 and a 5.
        let exactNumber = Int(query).flatMap { (1...Pokedex.count).contains($0) ? $0 : nil }

        let found = (1...Pokedex.count).filter { dex in
            if dex == exactNumber { return true }
            return Pokedex.name(for: dex).localizedStandardContains(query)
        }
        matches = found
        matchSet = Set(found)

        // Travel to the first match as you type. Without this, searching for
        // something that isn't on the page you're looking at appears to do nothing
        // at all — every card just dims.
        if let first = found.first {
            currentMatchIndex = 0
            goTo(page: Pokedex.page(for: first))
        } else {
            currentMatchIndex = nil
        }
    }
}
