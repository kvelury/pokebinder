import SwiftUI

/// Chrome for surfaces the app floats *above* the binder — the pager capsules, the
/// collected-count pill. macOS 26 draws them in Liquid Glass; macOS 14/15 fall back
/// to the material + hairline + shadow recipe.
///
/// Ported from Dosa's `FloatingChrome` (Sources/Dosa/Views/SharedViews.swift).
/// `canImport(FoundationModels)` is the compile-time probe for a macOS 26 SDK, so a
/// binary built against an older SDK still compiles and takes the fallback.
///
/// Two rules this must not break, both learned the hard way in Dosa:
///  1. Never apply this to a toolbar item. macOS 26 gives toolbar items their own
///     Liquid Glass; ours on top would be glass-on-glass.
///  2. Never `.interactive()`. That is for glass which is itself a single button —
///     on a container holding its own controls it lights the whole surface up
///     whenever the pointer nears any child.
struct FloatingChrome<S: InsettableShape>: ViewModifier {
    let shape: S

    @ViewBuilder
    func body(content: Content) -> some View {
        #if canImport(FoundationModels)
        if #available(macOS 26.0, *) {
            content.glassEffect(.regular, in: shape)
        } else {
            material(content)
        }
        #else
        material(content)
        #endif
    }

    private func material(_ content: Content) -> some View {
        content
            .background(.regularMaterial, in: shape)
            .overlay(shape.strokeBorder(.quaternary))
            .shadow(color: .black.opacity(0.15), radius: 10, y: 3)
    }
}

extension View {
    func floatingChrome<S: InsettableShape>(in shape: S) -> some View {
        modifier(FloatingChrome(shape: shape))
    }
}
