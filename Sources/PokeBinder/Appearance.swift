import SwiftUI
import AppKit

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
