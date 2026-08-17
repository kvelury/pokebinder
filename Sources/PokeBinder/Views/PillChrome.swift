import SwiftUI

/// The single surface recipe for both visual systems. Classic renders the original
/// flat fill and hairline; Liquid Glass uses the system material so refraction,
/// pointer response, contrast, and specular highlights stay native to macOS 26.
struct PillChrome<S: InsettableShape>: ViewModifier {
    let shape: S
    let active: Bool
    let floating: Bool
    let stroked: Bool
    let interactive: Bool

    @Environment(\.appTheme) private var theme
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    @ViewBuilder
    func body(content: Content) -> some View {
        if theme.isLiquidGlass && !reduceTransparency {
            content
                .glassEffect(glass, in: shape)
                .shadow(color: .black.opacity(floating ? 0.16 : 0), radius: floating ? 10 : 0, y: floating ? 3 : 0)
        } else {
            content
                .background(active ? theme.controlFillActive : theme.controlFill, in: shape)
                .overlay(shape.strokeBorder(stroked ? theme.controlStroke : .clear, lineWidth: 1))
                .shadow(
                    color: .black.opacity(floating ? 0.18 : 0),
                    radius: floating ? 8 : 0,
                    y: floating ? 2 : 0
                )
        }
    }

    private var glass: Glass {
        let base: Glass
        if active {
            base = .regular.tint(theme.brass.opacity(0.28))
        } else if let tint = theme.glassTint {
            base = .regular.tint(tint.opacity(0.16))
        } else {
            base = .regular
        }
        return base.interactive(interactive)
    }
}

/// A large transient surface such as the card detail panel. Glass is intentionally
/// noninteractive here; only the controls placed on it react to the pointer.
private struct PanelChrome<S: InsettableShape>: ViewModifier {
    let shape: S

    @Environment(\.appTheme) private var theme
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    @ViewBuilder
    func body(content: Content) -> some View {
        if theme.isLiquidGlass && !reduceTransparency {
            content
                .glassEffect(panelGlass, in: shape)
                .shadow(color: .black.opacity(0.28), radius: 30, y: 12)
        } else {
            content
                .background(theme.page, in: shape)
                .overlay(shape.strokeBorder(theme.controlStroke, lineWidth: 1))
                .shadow(color: .black.opacity(0.35), radius: 28, y: 12)
        }
    }

    private var panelGlass: Glass {
        if let tint = theme.glassTint {
            return .regular.tint(tint.opacity(0.12))
        }
        return .regular
    }
}

extension View {
    func pillChrome<S: InsettableShape>(
        in shape: S,
        active: Bool = false,
        stroked: Bool = true,
        interactive: Bool = false
    ) -> some View {
        modifier(PillChrome(
            shape: shape,
            active: active,
            floating: false,
            stroked: stroked,
            interactive: interactive
        ))
    }

    func floatingPill<S: InsettableShape>(
        in shape: S,
        active: Bool = false,
        interactive: Bool = false
    ) -> some View {
        modifier(PillChrome(
            shape: shape,
            active: active,
            floating: true,
            stroked: true,
            interactive: interactive
        ))
    }

    func panelChrome<S: InsettableShape>(in shape: S) -> some View {
        modifier(PanelChrome(shape: shape))
    }
}
