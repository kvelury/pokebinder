import SwiftUI

/// The app's one pill surface: a fill and a hairline, in a capsule or a circle.
///
/// This replaced a Liquid Glass treatment (`FloatingChrome`, ported from Dosa). Glass
/// gave every small control its own depth and specular edge, and with a pager, a count,
/// a search field and two view tabs on screen at once the chrome ended up competing
/// with the binder. Flat pills read as one system and let the binder be the only thing
/// in the window with weight.
///
/// Two variants, one recipe:
///  - `pillChrome` — controls resting *on* the toolbar. No shadow; there is nothing
///    for them to float above.
///  - `floatingPill` — the pager and the count, which sit *over* the binder and need a
///    whisper of a shadow to separate from the page under them.
struct PillChrome<S: InsettableShape>: ViewModifier {
    let shape: S
    let active: Bool
    let floating: Bool
    let stroked: Bool

    func body(content: Content) -> some View {
        content
            .background(active ? Theme.controlFillActive : Theme.controlFill, in: shape)
            .overlay(shape.strokeBorder(stroked ? Theme.controlStroke : .clear, lineWidth: 1))
            .shadow(
                color: .black.opacity(floating ? 0.18 : 0),
                radius: floating ? 8 : 0,
                y: floating ? 2 : 0
            )
    }
}

extension View {
    /// A pill sitting on the toolbar. `active` fills it, marking it as the selected
    /// one of a set — the only fill in a group is what makes the group read as a
    /// selection rather than as a row of separate buttons.
    /// `stroked: false` for a pill whose fill already carries the shape — the search field,
    /// where a hairline on top of the fill reads as a second border.
    func pillChrome<S: InsettableShape>(in shape: S, active: Bool = false, stroked: Bool = true) -> some View {
        modifier(PillChrome(shape: shape, active: active, floating: false, stroked: stroked))
    }

    /// A pill floating over the binder.
    func floatingPill<S: InsettableShape>(in shape: S) -> some View {
        modifier(PillChrome(shape: shape, active: false, floating: true, stroked: true))
    }
}
