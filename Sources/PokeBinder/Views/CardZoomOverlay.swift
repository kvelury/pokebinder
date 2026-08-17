import SwiftUI

/// The selected card's detail panel, quickly animated from its pocket to the window centre.
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
            ZStack {
                if selection != nil {
                    scrim
                        .transition(.opacity)
                }

                if let selection {
                    CardDetailPanel(dexNumber: selection.dexNumber, onClose: dismiss)
                        .position(x: geo.size.width / 2, y: geo.size.height / 2)
                        .transition(panelTransition(for: selection, in: geo.size))
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

    private var scrim: some View {
        (theme.isLiquidGlass && !reduceTransparency ? theme.modalScrim : Color.black.opacity(0.45))
            .contentShape(Rectangle())
            .onTapGesture { dismiss() }
    }

    private func panelTransition(for selection: CardSelection, in containerSize: CGSize) -> AnyTransition {
        if reduceMotion {
            return .opacity
        }

        let centre = CGPoint(x: containerSize.width / 2, y: containerSize.height / 2)
        let startScale = max(0.05, selection.sourceRect.width / CardDetailPanel.width)
        return .scale(scale: startScale)
            .combined(with: .offset(
                x: selection.sourceRect.midX - centre.x,
                y: selection.sourceRect.midY - centre.y
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
