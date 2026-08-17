import SwiftUI
import AppKit

/// Hides the window title text while keeping the toolbar.
///
/// `.windowStyle(.hiddenTitleBar)` would take the whole titlebar — and the toolbar
/// with it — so the title is suppressed on the `NSWindow` directly instead. Without
/// this, "PokeBinder" sits between the view tabs and the search field and pushes the
/// search field off centre.
struct WindowConfigurator: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        // The view has no window until it is in the hierarchy.
        DispatchQueue.main.async {
            guard let window = view.window else { return }
            window.titleVisibility = .hidden
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {}
}
