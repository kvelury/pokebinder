import SwiftUI
import AppKit

// MARK: - Color plumbing

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

/// A resolved, observable-through-the-environment palette. The view tree receives a
/// new value whenever either persisted theme setting changes, while the individual
/// colors remain dynamic providers that continue to follow light/dark appearance.
struct Theme: Equatable {
    let style: AppStyle
    let palette: GlassPalette

    static let classic = Theme(style: .classic, palette: .forestBrass)

    var isLiquidGlass: Bool { style == .liquidGlass }

    /// Classic is intentionally frozen to the original forest/brass palette.
    private var colors: GlassPalette {
        isLiquidGlass ? palette : .forestBrass
    }

    var windowBackground: Color {
        switch colors {
        case .fullGlass: Color.adaptive(light: 0xDDE3E6, dark: 0x10171B)
        case .forestBrass: Color.adaptive(light: 0xDCE3DD, dark: 0x0C1512)
        case .navyGold: Color.adaptive(light: 0xDCE3EC, dark: 0x090F1B)
        case .burgundyDarkGold: Color.adaptive(light: 0xE8DEE0, dark: 0x170B0E)
        }
    }

    var cover: Color {
        switch colors {
        case .fullGlass: Color.adaptive(light: 0x53636C, dark: 0x1A252B)
        case .forestBrass: Color.adaptive(light: 0x2E4A3C, dark: 0x12211B)
        case .navyGold: Color.adaptive(light: 0x183A5A, dark: 0x0B1B30)
        case .burgundyDarkGold: Color.adaptive(light: 0x602638, dark: 0x2A1019)
        }
    }

    var coverDeep: Color {
        switch colors {
        case .fullGlass: Color.adaptive(light: 0x3E4C54, dark: 0x101A20)
        case .forestBrass: Color.adaptive(light: 0x243B30, dark: 0x0B1712)
        case .navyGold: Color.adaptive(light: 0x102B45, dark: 0x071323)
        case .burgundyDarkGold: Color.adaptive(light: 0x471927, dark: 0x1B090F)
        }
    }

    var coverHighlight: Color {
        switch colors {
        case .fullGlass: Color.adaptive(light: 0x71828C, dark: 0x293840)
        case .forestBrass: Color.adaptive(light: 0x3A5A4A, dark: 0x1A2E25)
        case .navyGold: Color.adaptive(light: 0x28577D, dark: 0x142B46)
        case .burgundyDarkGold: Color.adaptive(light: 0x7B344A, dark: 0x3B1924)
        }
    }

    var page: Color {
        switch colors {
        case .fullGlass: Color.adaptive(light: 0xFCFDFD, dark: 0x1B252A)
        case .forestBrass: Color.adaptive(light: 0xFFFFFE, dark: 0x172420)
        case .navyGold: Color.adaptive(light: 0xFCFDFF, dark: 0x141E2C)
        case .burgundyDarkGold: Color.adaptive(light: 0xFFFBFA, dark: 0x26181B)
        }
    }

    var sleeve: Color {
        switch colors {
        case .fullGlass: Color.adaptive(light: 0xEEF2F4, dark: 0x243138)
        case .forestBrass: Color.adaptive(light: 0xF0F5F1, dark: 0x1F2E28)
        case .navyGold: Color.adaptive(light: 0xEBF0F7, dark: 0x1B293A)
        case .burgundyDarkGold: Color.adaptive(light: 0xF5ECEE, dark: 0x342126)
        }
    }

    var brass: Color {
        switch colors {
        case .fullGlass: Color.adaptive(light: 0x5F7D8C, dark: 0xB5CAD4)
        case .forestBrass: Color.adaptive(light: 0xA8863C, dark: 0xD0A94F)
        case .navyGold: Color.adaptive(light: 0xB78A1E, dark: 0xF0C85A)
        case .burgundyDarkGold: Color.adaptive(light: 0x94702B, dark: 0xD2A44B)
        }
    }

    var brassBright: Color {
        switch colors {
        case .fullGlass: Color.adaptive(light: 0x86A1AE, dark: 0xD4E2E8)
        case .forestBrass: Color.adaptive(light: 0xC9A659, dark: 0xE8C77A)
        case .navyGold: Color.adaptive(light: 0xD8AD3F, dark: 0xFFE18B)
        case .burgundyDarkGold: Color.adaptive(light: 0xB78D3D, dark: 0xE9C170)
        }
    }

    var brassDeep: Color {
        switch colors {
        case .fullGlass: Color.adaptive(light: 0x455F6B, dark: 0x7F9DAA)
        case .forestBrass: Color.adaptive(light: 0x7E6329, dark: 0x8E7233)
        case .navyGold: Color.adaptive(light: 0x806012, dark: 0xA98730)
        case .burgundyDarkGold: Color.adaptive(light: 0x694C19, dark: 0x967329)
        }
    }

    var textPrimary: Color {
        switch colors {
        case .fullGlass: Color.adaptive(light: 0x162126, dark: 0xEDF4F6)
        case .forestBrass: Color.adaptive(light: 0x14201A, dark: 0xE8F0EA)
        case .navyGold: Color.adaptive(light: 0x111D2B, dark: 0xEDF3FC)
        case .burgundyDarkGold: Color.adaptive(light: 0x29171C, dark: 0xF8ECEF)
        }
    }

    var textSecondary: Color {
        switch colors {
        case .fullGlass: Color.adaptive(light: 0x5C6D75, dark: 0x9BABB2)
        case .forestBrass: Color.adaptive(light: 0x5C6B62, dark: 0x8DA096)
        case .navyGold: Color.adaptive(light: 0x5A6879, dark: 0x96A8BF)
        case .burgundyDarkGold: Color.adaptive(light: 0x725C62, dark: 0xB49AA1)
        }
    }

    var missingOutline: Color {
        switch colors {
        case .fullGlass: Color.adaptive(light: 0xB6C2C7, dark: 0x45545B)
        case .forestBrass: Color.adaptive(light: 0xB6C3BA, dark: 0x39493F)
        case .navyGold: Color.adaptive(light: 0xB5C0CF, dark: 0x384A61)
        case .burgundyDarkGold: Color.adaptive(light: 0xC9B8BC, dark: 0x594047)
        }
    }

    var chrome: Color {
        switch colors {
        case .fullGlass: Color.adaptive(light: 0xEEF2F4, dark: 0x151F24)
        case .forestBrass: Color.adaptive(light: 0xEDF2EE, dark: 0x101C17)
        case .navyGold: Color.adaptive(light: 0xEEF2F8, dark: 0x101927)
        case .burgundyDarkGold: Color.adaptive(light: 0xF5EFF0, dark: 0x211419)
        }
    }

    var chromeDivider: Color {
        switch colors {
        case .fullGlass: Color.adaptive(light: 0xCAD3D7, dark: 0x29363C)
        case .forestBrass: Color.adaptive(light: 0xC8D2CB, dark: 0x22302A)
        case .navyGold: Color.adaptive(light: 0xC8D1DD, dark: 0x273448)
        case .burgundyDarkGold: Color.adaptive(light: 0xD9CCCF, dark: 0x38242A)
        }
    }

    var controlFill: Color {
        switch colors {
        case .fullGlass: Color.adaptive(light: 0xFFFFFF, dark: 0x253137)
        case .forestBrass: Color.adaptive(light: 0xFFFFFF, dark: 0x1F2D26)
        case .navyGold: Color.adaptive(light: 0xFFFFFF, dark: 0x202D40)
        case .burgundyDarkGold: Color.adaptive(light: 0xFFFFFF, dark: 0x38252A)
        }
    }

    var controlFillActive: Color {
        switch colors {
        case .fullGlass: Color.adaptive(light: 0xE4EAED, dark: 0x314047)
        case .forestBrass: Color.adaptive(light: 0xE3EBE5, dark: 0x2A3A32)
        case .navyGold: Color.adaptive(light: 0xE3EAF3, dark: 0x2B3B52)
        case .burgundyDarkGold: Color.adaptive(light: 0xEEE3E5, dark: 0x4A3037)
        }
    }

    var controlStroke: Color {
        switch colors {
        case .fullGlass: Color.adaptive(light: 0xD1DADF, dark: 0x3B4B53)
        case .forestBrass: Color.adaptive(light: 0xD5DFD8, dark: 0x2E3D35)
        case .navyGold: Color.adaptive(light: 0xD3DCE8, dark: 0x35465D)
        case .burgundyDarkGold: Color.adaptive(light: 0xE0D2D5, dark: 0x543740)
        }
    }

    /// `nil` is the intentional "Full Glass" appearance.
    var glassTint: Color? {
        switch colors {
        case .fullGlass: nil
        case .forestBrass: cover
        case .navyGold: cover
        case .burgundyDarkGold: cover
        }
    }

    var modalScrim: Color {
        isLiquidGlass ? Color.black.opacity(0.30) : Color.black.opacity(0.45)
    }

    func numberFont(size: CGFloat) -> Font {
        .system(size: size, weight: .medium, design: .monospaced)
    }

    func nameFont(size: CGFloat) -> Font {
        .system(size: size, weight: .semibold, design: .rounded)
    }
}

private struct AppThemeKey: EnvironmentKey {
    static let defaultValue = Theme.classic
}

extension EnvironmentValues {
    var appTheme: Theme {
        get { self[AppThemeKey.self] }
        set { self[AppThemeKey.self] = newValue }
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

/// Every card-detail measurement in one place, so the panel scales as one object with
/// the window the way `BinderMetrics` scales the spread.
///
/// `scale == 1` reproduces the hand-tuned panel at the app's default window size
/// (`PokeBinderApp`'s `.defaultSize`, 1320x900). Driven by the overlay's safe rect
/// rather than the raw window, so the Liquid Glass search bar's reserved strip is
/// already accounted for and both themes land on the same panel size.
struct CardDetailMetrics {
    /// `CardZoomOverlay.safePanelRect` at the default window size. Re-measure this if
    /// the toolbar chrome or `safePanelRect`'s insets ever change — it is the anchor
    /// that keeps the panel identical to its hand-tuned layout at the default size.
    static let referenceSafe = CGSize(width: 1272, height: 770)
    /// Below this the panel stops being legible; above it, absurd.
    static let minScale: CGFloat = 0.9
    static let maxScale: CGFloat = 2.0

    let scale: CGFloat

    // Frame
    var width: CGFloat { 600 * scale }
    var artSize: CGFloat { 200 * scale }
    var padding: CGFloat { 16 * scale }
    var columnSpacing: CGFloat { 14 * scale }
    var identitySpacing: CGFloat { 8 * scale }
    var titleBlockSpacing: CGFloat { 3 * scale }
    var identityRowSpacing: CGFloat { 8 * scale }
    var identityDividerHeight: CGFloat { 16 * scale }
    var detailsSpacing: CGFloat { 12 * scale }
    var toggleGroupSpacing: CGFloat { 6 * scale }
    var glyphInset: CGFloat { 10 * scale }
    var glyphSize: CGFloat { 22 * scale }
    var glyphIconSize: CGFloat { 10 * scale }

    func cornerRadius(liquidGlass: Bool) -> CGFloat { (liquidGlass ? 24 : 16) * scale }

    // Identity column
    var nameFontSize: CGFloat { 20 * scale }
    var numberFontSize: CGFloat { 26 * scale }        // bumped 2x from 13
    var identityIconSize: CGFloat { 48 * scale }      // bumped 2.4x from 20
    var identityIconSpacing: CGFloat { 8 * scale }    // was 4; widened for the bigger icons
    var ownedLabelFontSize: CGFloat { 14 * scale }
    var errorFontSize: CGFloat { 10 * scale }

    // Matchup table
    var matchupRowSpacing: CGFloat { 10 * scale }
    var matchupColumnSpacing: CGFloat { 10 * scale }
    var matchupTitleFontSize: CGFloat { 11 * scale }
    var matchupTitleGap: CGFloat { 4 * scale }
    var chipIconSize: CGFloat { 36 * scale }          // bumped 2x from 18
    var chipLabelFontSize: CGFloat { 16 * scale }     // bumped 2x from 8
    var chipLabelGap: CGFloat { 2 * scale }
    var chipSpacing: CGFloat { 8 * scale }            // was 6; widened for the bigger chips

    // Hover card
    //
    // `hoverWidth` is the panel's *details column* width, not a new number:
    // 600 - 200 (art) - 14 (columnSpacing) - 32 (padding) = 354, plus this card's
    // own 2 x 14 padding. Matching it is what makes the matchup rows wrap here
    // exactly the way they wrap in the panel.
    var hoverWidth: CGFloat { 390 * scale }
    var hoverPadding: CGFloat { 14 * scale }
    var hoverSectionSpacing: CGFloat { 10 * scale }
    var hoverTypeRowSpacing: CGFloat { 6 * scale }
    var hoverTypeIconSize: CGFloat { 34 * scale }
    var hoverTypeLabelSize: CGFloat { 15 * scale }
    var hoverTitleFontSize: CGFloat { 15 * scale }
    var hoverNumberFontSize: CGFloat { 12 * scale }

    func hoverCornerRadius(liquidGlass: Bool) -> CGFloat { (liquidGlass ? 18 : 12) * scale }

    /// Solve the scale that keeps the panel's footprint constant relative to the window.
    /// `min` across both axes so a short window shrinks the panel rather than pushing it
    /// into the scroll fallback.
    static func fitting(safe: CGSize) -> CardDetailMetrics {
        let raw = min(
            safe.width / referenceSafe.width,
            safe.height / referenceSafe.height
        )
        return CardDetailMetrics(scale: min(max(raw, minScale), maxScale))
    }
}
