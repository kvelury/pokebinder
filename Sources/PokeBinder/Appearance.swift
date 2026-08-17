import SwiftUI
import AppKit

/// The app's two visual systems. Classic preserves the original flat chrome;
/// Liquid Glass moves controls and transient surfaces into macOS 26's glass layer.
enum AppStyle: String, CaseIterable, Identifiable {
    case classic
    case liquidGlass

    var id: String { rawValue }

    var title: String {
        switch self {
        case .classic: "Classic"
        case .liquidGlass: "Liquid Glass"
        }
    }
}

/// Color families available to Liquid Glass. Full Glass deliberately supplies no
/// material tint so the binder and Pokémon artwork determine the reflected color.
enum GlassPalette: String, CaseIterable, Identifiable {
    case fullGlass
    case forestBrass
    case navyGold
    case burgundyDarkGold

    var id: String { rawValue }

    var title: String {
        switch self {
        case .fullGlass: "Full Glass"
        case .forestBrass: "Forest & Brass"
        case .navyGold: "Navy & Gold"
        case .burgundyDarkGold: "Burgundy & Dark Gold"
        }
    }
}

/// Light / Dark / Auto, applied app-wide.
///
/// Every Theme color is an `NSColor` dynamic provider (`Color.adaptive`), resolved against the
/// current `NSAppearance` at draw time — so overriding the app's appearance repaints the whole
/// binder without `Theme` knowing this type exists.
enum AppAppearance: String, CaseIterable, Identifiable {
    case system, light, dark

    var id: String { rawValue }

    var title: String {
        switch self {
        case .system: "Auto"
        case .light:  "Light"
        case .dark:   "Dark"
        }
    }

    /// `nil` means "inherit from the system", which is what restores Auto.
    private var nsAppearance: NSAppearance? {
        switch self {
        case .system: nil
        case .light:  NSAppearance(named: .aqua)
        case .dark:   NSAppearance(named: .darkAqua)
        }
    }

    /// App-wide rather than per-window: the Settings sheet and the card popover are
    /// their own windows, and a per-window override leaves them on the old appearance.
    func apply() {
        NSApplication.shared.appearance = nsAppearance
    }
}
