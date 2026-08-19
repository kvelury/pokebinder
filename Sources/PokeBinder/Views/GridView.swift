import AppKit
import SwiftUI

/// Preference-driven grid: Classic (vertical reflow sheet) or Continuous (2D surface).
struct GridView: View {
    @AppStorage(AppSettings.gridLayoutKey) private var gridLayout: GridLayoutMode = .classic
    @Binding var selection: CardSelection?

    var body: some View {
        switch gridLayout {
        case .classic:
            ClassicGridView(selection: $selection)
        case .continuous:
            ContinuousGridView(selection: $selection)
        }
    }
}

// MARK: - Trackpad magnify catcher

struct TrackpadMagnifyEvent {
    let magnification: CGFloat
    let phase: NSEvent.Phase
}

/// Pinch-to-zoom over the grid, without stealing clicks from the cards or the scroll view.
///
/// Clicks pass through (`hitTest` is nil). Magnify events are caught with a local monitor
/// so SwiftUI hit testing never fights `ScrollView` or `CardSlotView.onTapGesture`.
struct TrackpadMagnifyCatcher: NSViewRepresentable {
    var isSuspended: Bool
    var onMagnify: (TrackpadMagnifyEvent) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeNSView(context: Context) -> CatcherView {
        let view = CatcherView()
        context.coordinator.view = view
        view.coordinator = context.coordinator
        return view
    }

    func updateNSView(_ nsView: CatcherView, context: Context) {
        context.coordinator.isSuspended = isSuspended
        context.coordinator.onMagnify = onMagnify
        nsView.coordinator = context.coordinator
        context.coordinator.view = nsView
    }

    static func dismantleNSView(_ nsView: CatcherView, coordinator: Coordinator) {
        coordinator.teardown()
    }

    final class Coordinator {
        weak var view: CatcherView?
        var isSuspended = false
        var onMagnify: ((TrackpadMagnifyEvent) -> Void)?
        private var monitor: Any?

        func install() {
            guard monitor == nil else { return }
            monitor = NSEvent.addLocalMonitorForEvents(matching: .magnify) { [weak self] event in
                self?.handle(event) ?? event
            }
        }

        func teardown() {
            if let monitor {
                NSEvent.removeMonitor(monitor)
            }
            monitor = nil
        }

        private func handle(_ event: NSEvent) -> NSEvent? {
            if isSuspended { return event }
            guard let view else { return event }
            guard event.window === view.window else { return event }
            let location = view.convert(event.locationInWindow, from: nil)
            guard view.bounds.contains(location) else { return event }

            let payload = TrackpadMagnifyEvent(
                magnification: event.magnification,
                phase: event.phase
            )
            if Thread.isMainThread {
                onMagnify?(payload)
            } else {
                DispatchQueue.main.async { [onMagnify] in
                    onMagnify?(payload)
                }
            }
            return nil
        }
    }

    final class CatcherView: NSView {
        var coordinator: Coordinator?

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            if window != nil {
                coordinator?.install()
            } else {
                coordinator?.teardown()
            }
        }

        override func hitTest(_ point: NSPoint) -> NSView? { nil }
    }
}
