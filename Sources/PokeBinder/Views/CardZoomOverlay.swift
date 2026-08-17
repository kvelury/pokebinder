import SwiftUI

private enum CardZoom {
    static let pop = Animation.spring(response: 0.34, dampingFraction: 0.82)
    static let reduced = Animation.easeOut(duration: 0.14)
    /// The panel's fixed width, from `CardDetailPanel.width`.
    static let panelWidth: CGFloat = CardDetailPanel.width
}

/// The clicked card, lifted out of its pocket and brought to the middle.
///
/// Not a `matchedGeometryEffect`: `BinderStack` renders the same pocket twice
/// during a page turn (flat page + turning leaf), which would give one namespace
/// two sources for the same id. The pocket's frame is captured at tap time
/// instead — a plain `CGRect`, immune to the leaf's 3D transform.
///
/// Presentation and dismissal are both driven by `presented`, and the view only
/// leaves the hierarchy in the dismiss animation's completion, so the panel
/// actually plays its way back into the pocket instead of blinking out.
struct CardZoomOverlay: View {
    let selection: CardSelection
    /// Size of the content area — the coordinate space `sourceRect` was measured in.
    let containerSize: CGSize
    let onDismissed: () -> Void

    @Environment(\.appTheme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @State private var presented = false

    private var animation: Animation { reduceMotion ? CardZoom.reduced : CardZoom.pop }

    private var sourceCentre: CGPoint {
        CGPoint(x: selection.sourceRect.midX, y: selection.sourceRect.midY)
    }

    private var centre: CGPoint {
        CGPoint(x: containerSize.width / 2, y: containerSize.height / 2)
    }

    /// The pocket's width as a fraction of the panel's, so the panel starts out
    /// the size of the hole it came from.
    private var startScale: CGFloat {
        max(0.05, selection.sourceRect.width / CardZoom.panelWidth)
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
            .scaleEffect(reduceMotion ? 1 : (presented ? 1 : startScale), anchor: .center)
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
