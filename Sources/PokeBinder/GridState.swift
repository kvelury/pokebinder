import SwiftUI

enum ZoomStep {
    case `in`, out
}

/// Live zoom for grid mode. `cardWidth` is published so the grid and meter redraw
/// together during a pinch; `anchorDex` is deliberately not, because it changes on
/// every scroll frame and is only read imperatively.
@MainActor
final class GridState: ObservableObject {
    static let minCardWidth: CGFloat = 80
    static let maxCardWidth: CGFloat = 260
    static let defaultCardWidth: CGFloat = 140
    /// One press of ⌘+ / the meter's ± glyphs.
    static let stepFactor: CGFloat = 1.15

    /// Published: the grid and the meter both redraw on every frame of a pinch.
    @Published private(set) var cardWidth: CGFloat

    /// Deliberately NOT @Published. It changes on every scroll frame and is only ever
    /// read imperatively (at a mode switch, and to seed prefetch). Publishing it would
    /// re-render every observer of GridState 60 times a second while scrolling.
    private(set) var anchorDex: Int = 1

    var metrics: BinderMetrics { BinderMetrics(cardWidth: cardWidth) }

    /// The 0…1 track position, log-mapped both ways so a slider notch is a constant
    /// proportional size change and a pinch (which multiplies) maps to a constant
    /// offset in `t`.
    var zoom: CGFloat {
        get {
            log(cardWidth / Self.minCardWidth) / log(Self.maxCardWidth / Self.minCardWidth)
        }
        set {
            let t = min(max(newValue, 0), 1)
            cardWidth = Self.minCardWidth * pow(Self.maxCardWidth / Self.minCardWidth, t)
        }
    }

    init() {
        cardWidth = Self.loadPersistedWidth()
    }

    /// Live pinch; multiplies and clamps, does not persist.
    func magnify(by factor: CGFloat) {
        cardWidth = Self.clamped(cardWidth * factor)
    }

    func step(_ direction: ZoomStep) {
        switch direction {
        case .in: stepIn()
        case .out: stepOut()
        }
    }

    func stepIn() {
        cardWidth = Self.clamped(cardWidth * Self.stepFactor)
        commit()
    }

    func stepOut() {
        cardWidth = Self.clamped(cardWidth / Self.stepFactor)
        commit()
    }

    func resetZoom() {
        cardWidth = Self.defaultCardWidth
        commit()
    }

    /// Flush `cardWidth` to UserDefaults. Called on pinch end and after a step.
    func commit() {
        UserDefaults.standard.set(Double(cardWidth), forKey: AppSettings.gridCardWidthKey)
    }

    func noteAnchor(dex: Int) {
        anchorDex = min(max(dex, 1), Pokedex.count)
    }

    private static func loadPersistedWidth() -> CGFloat {
        let defaults = UserDefaults.standard
        guard defaults.object(forKey: AppSettings.gridCardWidthKey) != nil else {
            return defaultCardWidth
        }
        let stored = defaults.double(forKey: AppSettings.gridCardWidthKey)
        guard stored.isFinite, stored > 0 else { return defaultCardWidth }
        return clamped(CGFloat(stored))
    }

    private static func clamped(_ width: CGFloat) -> CGFloat {
        min(max(width, minCardWidth), maxCardWidth)
    }
}
