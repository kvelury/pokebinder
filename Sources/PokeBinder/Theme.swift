import SwiftUI
import AppKit

// MARK: - Color plumbing

extension NSColor {
    convenience init(hex: UInt32) {
        let r = CGFloat((hex >> 16) & 0xFF) / 255
        let g = CGFloat((hex >> 8) & 0xFF) / 255
        let b = CGFloat(hex & 0xFF) / 255
        self.init(srgbRed: r, green: g, blue: b, alpha: 1)
    }
}

extension Color {
    /// An appearance-aware color.
    ///
    /// SwiftUI's asset-catalog colors aren't available to an SPM executable, so the
    /// light/dark pair is resolved through `NSColor`'s dynamic provider instead. This
    /// re-resolves whenever the system appearance changes, which is what makes the
    /// "adaptive" decision actually work without restarting the app.
    static func adaptive(light: UInt32, dark: UInt32) -> Color {
        Color(nsColor: NSColor(name: nil) { appearance in
            let isDark = appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
            return NSColor(hex: isDark ? dark : light)
        })
    }
}

// MARK: - Theme

/// Forest green + brass, chosen by the user. Light and dark are both first-class —
/// the app follows System Settings rather than committing to one look.
enum Theme {
    /// Behind the binder itself — the desk the binder is lying on.
    static let windowBackground = Color.adaptive(light: 0xDCE3DD, dark: 0x0C1512)

    /// The binder cover.
    static let cover = Color.adaptive(light: 0x2E4A3C, dark: 0x12211B)
    /// A slightly deeper tone for the cover's edge and the spine channel.
    static let coverDeep = Color.adaptive(light: 0x243B30, dark: 0x0B1712)
    /// A lift on the cover's top edge, so it reads as a physical object.
    static let coverHighlight = Color.adaptive(light: 0x3A5A4A, dark: 0x1A2E25)

    /// The paper page inside the cover.
    static let page = Color.adaptive(light: 0xFFFFFE, dark: 0x172420)
    /// The plastic pocket a card sits in.
    static let sleeve = Color.adaptive(light: 0xF0F5F1, dark: 0x1F2E28)

    /// Ring hardware and the search spotlight, both brass.
    static let brass = Color.adaptive(light: 0xA8863C, dark: 0xD0A94F)
    static let brassBright = Color.adaptive(light: 0xC9A659, dark: 0xE8C77A)
    static let brassDeep = Color.adaptive(light: 0x7E6329, dark: 0x8E7233)

    static let textPrimary = Color.adaptive(light: 0x14201A, dark: 0xE8F0EA)
    static let textSecondary = Color.adaptive(light: 0x5C6B62, dark: 0x8DA096)

    /// The dashed outline around a pocket whose card you don't own.
    static let missingOutline = Color.adaptive(light: 0xB6C3BA, dark: 0x39493F)

    // MARK: Typography

    /// Pokédex numbers — mono, per the spec's typography note.
    static func numberFont(size: CGFloat) -> Font {
        .system(size: size, weight: .medium, design: .monospaced)
    }

    /// Pokémon names — rounded sans, per the spec.
    static func nameFont(size: CGFloat) -> Font {
        .system(size: size, weight: .semibold, design: .rounded)
    }
}

// MARK: - Geometry

/// Every binder measurement in one place, so the whole spread can be resized from
/// a single derived card width rather than a pile of magic numbers in views.
struct BinderMetrics {
    /// Real trading cards are 2.5" x 3.5".
    static let cardAspect: CGFloat = 5.0 / 7.0

    let cardWidth: CGFloat

    var cardHeight: CGFloat { cardWidth / Self.cardAspect }
    var cardGap: CGFloat { cardWidth * 0.09 }
    var cardCornerRadius: CGFloat { cardWidth * 0.055 }

    /// Margin between the page's edge and the 2x2 block of pockets.
    var pagePadding: CGFloat { cardWidth * 0.14 }
    /// Margin between the cover's edge and the pages.
    var coverPadding: CGFloat { cardWidth * 0.13 }
    var coverCornerRadius: CGFloat { cardWidth * 0.10 }
    var pageCornerRadius: CGFloat { cardWidth * 0.045 }

    /// The ring channel running down the center of the spread.
    var spineWidth: CGFloat { cardWidth * 0.42 }
    var ringDiameter: CGFloat { spineWidth * 0.62 }
    var ringThickness: CGFloat { max(2, spineWidth * 0.075) }

    var sideContentWidth: CGFloat { cardWidth * 2 + cardGap }
    var sideContentHeight: CGFloat { cardHeight * 2 + cardGap }
    var pageWidth: CGFloat { sideContentWidth + pagePadding * 2 }
    var pageHeight: CGFloat { sideContentHeight + pagePadding * 2 }

    var totalWidth: CGFloat { pageWidth * 2 + spineWidth + coverPadding * 2 }
    var totalHeight: CGFloat { pageHeight + coverPadding * 2 }

    /// Solve for the largest card that lets the whole spread fit in `size`.
    ///
    /// Both constraints are expressed back in terms of card width so the spread always
    /// scales as one object and never distorts.
    static func fitting(_ size: CGSize) -> BinderMetrics {
        // Ratios below mirror the computed properties above, expressed as multiples of cardWidth.
        let widthPerCard: CGFloat = 4 + 0.09 + 0.14 * 4 + 0.42 + 0.13 * 2   // totalWidth / cardWidth
        let heightPerCard: CGFloat = 2 / cardAspect + 0.09 + 0.14 * 2 + 0.13 * 2 // totalHeight / cardWidth

        let byWidth = size.width / widthPerCard
        let byHeight = size.height / heightPerCard
        return BinderMetrics(cardWidth: max(60, min(byWidth, byHeight)))
    }
}
