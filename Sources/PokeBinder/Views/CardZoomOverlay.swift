import SwiftUI

/// The selected card's detail panel, quickly animated from its pocket to the window centre.
struct CardZoomOverlay: View {
    let selection: CardSelection
    let containerSize: CGSize
    let onDismissed: () -> Void

    @Environment(\.appTheme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @State private var presented = false

    private var animation: Animation {
        reduceMotion ? AppMotion.quick : AppMotion.cardDetail
    }

    private var sourceCentre: CGPoint {
        CGPoint(x: selection.sourceRect.midX, y: selection.sourceRect.midY)
    }

    private var centre: CGPoint {
        CGPoint(x: containerSize.width / 2, y: containerSize.height / 2)
    }

    private var startScale: CGFloat {
        max(0.05, selection.sourceRect.width / CardDetailPanel.width)
    }

    var body: some View {
        ZStack {
            scrim
            panel
        }
        .onAppear { withAnimation(animation) { presented = true } }
        .background(escapeKey)
    }

    private var scrim: some View {
        (theme.isLiquidGlass && !reduceTransparency ? theme.modalScrim : Color.black.opacity(0.45))
            .opacity(presented ? 1 : 0)
            .contentShape(Rectangle())
            .onTapGesture { dismiss() }
    }

    private var panel: some View {
        CardDetailPanel(dexNumber: selection.dexNumber, onClose: dismiss)
            .scaleEffect(reduceMotion ? 1 : (presented ? 1 : startScale))
            .position(reduceMotion ? centre : (presented ? centre : sourceCentre))
            .opacity(presented ? 1 : 0)
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
        withAnimation(animation, completionCriteria: .logicallyComplete) {
            presented = false
        } completion: {
            onDismissed()
        }
    }
}
