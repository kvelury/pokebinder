import SwiftUI
import AppKit

/// Hides the window title text while keeping the toolbar.
///
/// `.windowStyle(.hiddenTitleBar)` would take the whole titlebar — and the toolbar
/// with it — so the title is suppressed on the `NSWindow` directly instead. Without
/// this, "PokeBinder" sits between the view tabs and the search field and pushes the
/// search field off centre.
struct WindowConfigurator: NSViewRepresentable {
    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        // The view has no window until it is in the hierarchy.
        DispatchQueue.main.async {
            guard let window = view.window else { return }
            window.titleVisibility = .hidden
            // Left to itself AppKit gives first responder to the first text field in the key-view
            // loop, and NSTextField selects all of its text — so the app opened with the page
            // number highlighted blue before anyone had touched it.
            window.initialFirstResponder = nil
            window.makeFirstResponder(nil)
            // This block can run before the window becomes key. Clear once on first key
            // as well, then drop the observer so we never fight the user's own clicks.
            if !window.isKeyWindow {
                context.coordinator.observeBecomeKeyOnce(of: window)
            }
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {}

    final class Coordinator {
        private var observer: NSObjectProtocol?

        func observeBecomeKeyOnce(of window: NSWindow) {
            guard observer == nil else { return }
            observer = NotificationCenter.default.addObserver(
                forName: NSWindow.didBecomeKeyNotification,
                object: window,
                queue: .main
            ) { [weak self, weak window] _ in
                window?.makeFirstResponder(nil)
                guard let self, let observer = self.observer else { return }
                NotificationCenter.default.removeObserver(observer)
                self.observer = nil
            }
        }

        deinit {
            if let observer {
                NotificationCenter.default.removeObserver(observer)
            }
        }
    }
}
