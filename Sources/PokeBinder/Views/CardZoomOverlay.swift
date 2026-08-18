import SwiftUI

/// The selected card's detail panel, quickly animated from its pocket into the
/// safe content area — never into the floating search controls.
struct CardZoomOverlay: View {
    @Binding var selection: CardSelection?

    @Environment(\.appTheme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    private var animation: Animation {
        reduceMotion ? AppMotion.quick : AppMotion.cardDetail
    }

    var body: some View {
        GeometryReader { geo in
            let safe = Self.safePanelRect(in: geo.size, liquidGlass: theme.isLiquidGlass)
            ZStack {
                if selection != nil {
                    scrim
                        .transition(.opacity)
                }

                if let selection {
                    VStack(spacing: 0) {
                        Color.clear.frame(height: safe.minY)
                        HStack(spacing: 0) {
                            Spacer(minLength: 0)
                            CardDetailPanel(
                                dexNumber: selection.dexNumber,
                                maxWidth: safe.width,
                                maxHeight: safe.height,
                                onClose: dismiss
                            )
                            Spacer(minLength: 0)
                        }
                        .frame(width: geo.size.width, height: safe.height)
                        Spacer(minLength: 0)
                    }
                    .transition(panelTransition(for: selection, landing: CGPoint(x: safe.midX, y: safe.midY)))
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
            .background {
                if selection != nil {
                    escapeKey
                }
            }
            .allowsHitTesting(selection != nil)
        }
    }

    /// Liquid Glass search controls sit in this overlay's coordinate space
    /// (48pt bar + 10pt top inset). Classic uses the window toolbar, so only
    /// a regular margin is reserved there.
    static func safePanelRect(in size: CGSize, liquidGlass: Bool) -> CGRect {
        let topReserved: CGFloat = liquidGlass ? 10 + 48 + 16 : 16
        let margin: CGFloat = 24
        let x = margin
        let y = topReserved
        let width = max(320, size.width - margin * 2)
        let height = max(280, size.height - topReserved - margin)
        return CGRect(x: x, y: y, width: width, height: height)
    }

    private var scrim: some View {
        (theme.isLiquidGlass && !reduceTransparency ? theme.modalScrim : Color.black.opacity(0.45))
            .contentShape(Rectangle())
            .onTapGesture { dismiss() }
    }

    private func panelTransition(for selection: CardSelection, landing: CGPoint) -> AnyTransition {
        if reduceMotion {
            return .opacity
        }

        let startScale = max(0.05, selection.sourceRect.width / CardDetailPanel.width)
        return .scale(scale: startScale)
            .combined(with: .offset(
                x: selection.sourceRect.midX - landing.x,
                y: selection.sourceRect.midY - landing.y
            ))
    }

    /// Esc, scoped to the overlay's lifetime — a permanently installed escape
    /// shortcut in ContentView.keyboardShortcuts would swallow Esc app-wide.
    /// Zero opacity rather than `.hidden()`, which would drop it from the
    /// responder chain and kill the shortcut. Same trick as ContentView:226-241.
    private var escapeKey: some View {
        Button("") { dismiss() }
            .keyboardShortcut(.escape, modifiers: [])
            .frame(width: 0, height: 0)
            .opacity(0)
    }

    private func dismiss() {
        withAnimation(animation) {
            selection = nil
        }
    }
}
