import SwiftUI

/// The selected card's detail panel, presented immediately in the window centre.
struct CardZoomOverlay: View {
    let selection: CardSelection
    let onDismiss: () -> Void

    @Environment(\.appTheme) private var theme
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    var body: some View {
        ZStack {
            scrim
            CardDetailPanel(dexNumber: selection.dexNumber, onClose: onDismiss)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(escapeKey)
    }

    private var scrim: some View {
        (theme.isLiquidGlass && !reduceTransparency ? theme.modalScrim : Color.black.opacity(0.45))
            .contentShape(Rectangle())
            .onTapGesture(perform: onDismiss)
    }

    /// Esc, scoped to the overlay's lifetime — a permanently installed escape
    /// shortcut in ContentView.keyboardShortcuts would swallow Esc app-wide.
    /// Zero opacity rather than `.hidden()`, which would drop it from the
    /// responder chain and kill the shortcut. Same trick as ContentView:226-241.
    private var escapeKey: some View {
        Button("", action: onDismiss)
            .keyboardShortcut(.escape, modifiers: [])
            .frame(width: 0, height: 0)
            .opacity(0)
    }
}
