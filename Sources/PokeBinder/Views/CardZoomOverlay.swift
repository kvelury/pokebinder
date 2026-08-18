import SwiftUI

/// The selected card's detail panel, quickly animated from its pocket into the
/// safe content area — never into the floating search controls.
///
/// Opening still uses an insertion transition in the click's transaction, so motion
/// starts on the same frame. Closing does not tear the overlay down immediately —
/// it animates the live panel back to the pocket and removes it only after the
/// spring has logically completed, which avoids the last-frame landing snap.
struct CardZoomOverlay: View {
    @Binding var selection: CardSelection?
    let floatingChrome: Bool

    @Environment(\.appTheme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    /// Held copy so the panel can finish travelling after `selection` is cleared.
    @State private var presentedSelection: CardSelection?
    @State private var isClosing = false
    @State private var closeGeneration = 0
    @State private var suppressSelectionNil = false

    private var animation: Animation {
        reduceMotion ? AppMotion.quick : AppMotion.cardDetail
    }

    /// Prefer the live binding so an open is inserted in the same transaction as the click.
    private var visibleSelection: CardSelection? {
        selection ?? presentedSelection
    }

    var body: some View {
        GeometryReader { geo in
            let safe = Self.safePanelRect(in: geo.size, floatingChrome: floatingChrome)
            let metrics = CardDetailMetrics.fitting(safe: safe.size)
            ZStack {
                if visibleSelection != nil {
                    scrim
                        .opacity(isClosing ? 0 : 1)
                        .transition(.opacity)
                }

                if let visibleSelection {
                    CardDetailPanel(
                        dexNumber: visibleSelection.dexNumber,
                        metrics: metrics,
                        maxWidth: safe.width,
                        maxHeight: safe.height,
                        onClose: dismiss
                    )
                    .scaleEffect(panelScale(for: visibleSelection, in: geo.size), anchor: .center)
                    .position(panelPosition(for: visibleSelection, in: geo.size))
                    .opacity(isClosing ? 0 : 1)
                    .transition(panelTransition(for: visibleSelection, in: geo.size))
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
            .background {
                if visibleSelection != nil && !isClosing {
                    escapeKey
                }
            }
            .allowsHitTesting(visibleSelection != nil && !isClosing)
        }
        .onChange(of: selection) { _, newValue in
            sync(to: newValue)
        }
    }

    /// Floating search controls sit in this overlay's coordinate space
    /// (48pt bar + 10pt top inset). Classic binder uses the window toolbar, so
    /// only a regular margin is reserved there.
    static func safePanelRect(in size: CGSize, floatingChrome: Bool) -> CGRect {
        let topReserved: CGFloat = floatingChrome ? 10 + 48 + 16 : 16
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

    private func landingPoint(in containerSize: CGSize) -> CGPoint {
        let safe = Self.safePanelRect(in: containerSize, floatingChrome: floatingChrome)
        return CGPoint(x: safe.midX, y: safe.midY)
    }

    private func panelScale(for selection: CardSelection, in containerSize: CGSize) -> CGFloat {
        if !isClosing || reduceMotion { return 1 }
        return pocketTravel(for: selection, in: containerSize).scale
    }

    private func panelPosition(for selection: CardSelection, in containerSize: CGSize) -> CGPoint {
        if !isClosing || reduceMotion { return landingPoint(in: containerSize) }
        return CGPoint(x: selection.sourceRect.midX, y: selection.sourceRect.midY)
    }

    private func panelTransition(for selection: CardSelection, in containerSize: CGSize) -> AnyTransition {
        if reduceMotion {
            return .opacity
        }

        let travel = pocketTravel(for: selection, in: containerSize)
        return .scale(scale: travel.scale)
            .combined(with: .offset(x: travel.offset.width, y: travel.offset.height))
    }

    private func pocketTravel(for selection: CardSelection, in containerSize: CGSize) -> (scale: CGFloat, offset: CGSize) {
        let safe = Self.safePanelRect(in: containerSize, floatingChrome: floatingChrome)
        let metrics = CardDetailMetrics.fitting(safe: safe.size)
        let landing = CGPoint(x: safe.midX, y: safe.midY)
        return (
            scale: max(0.05, selection.sourceRect.width / metrics.width),
            offset: CGSize(
                width: selection.sourceRect.midX - landing.x,
                height: selection.sourceRect.midY - landing.y
            )
        )
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

    private func sync(to newValue: CardSelection?) {
        if suppressSelectionNil { return }

        if let newValue {
            closeGeneration += 1
            presentedSelection = newValue
            isClosing = false
            return
        }

        startClose()
    }

    private func dismiss() {
        startClose()
    }

    private func startClose() {
        guard let current = visibleSelection, !isClosing else { return }
        presentedSelection = current
        closeGeneration += 1
        let generation = closeGeneration
        withAnimation(animation, completionCriteria: .logicallyComplete) {
            isClosing = true
        } completion: {
            finishClose(generation: generation)
        }
    }

    private func finishClose(generation: Int) {
        guard generation == closeGeneration, isClosing else { return }

        suppressSelectionNil = true
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            presentedSelection = nil
            selection = nil
            isClosing = false
        }
        suppressSelectionNil = false
    }
}
