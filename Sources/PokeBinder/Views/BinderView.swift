import AppKit
import SwiftUI

/// The open binder: a cover, two pages, and the ring hardware down the middle.
///
/// The whole spread scales as one object from a single derived card width
/// (`BinderMetrics.fitting`), so it never distorts at any window size.
///
/// Page changes all flow through `BinderState.currentPage`. This view holds the 3D
/// turn on that value — a new `goTo` mid-flight retargets the in-flight angle
/// rather than queuing a second animation. Reduce Motion skips the rotation.
struct BinderView: View {
    @EnvironmentObject private var binder: BinderState
    @EnvironmentObject private var collection: CollectionStore
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @Binding var selection: CardSelection?

    /// The spread the turn is leaving. Settled when it equals `toPage` and `angle` is 0.
    @State private var fromPage: Int = 1
    /// The spread the turn is heading toward — swapped in place when search retargets.
    @State private var toPage: Int = 1
    /// 0 when settled. Forward (higher page) animates 0 → −180; backward 0 → +180.
    @State private var angle: Double = 0
    /// Bumped to cancel an in-flight animation's completion so retargets don't settle stale.
    @State private var turnGeneration: Int = 0
    @State private var swipe: SwipeSession?
    @State private var swipeEndTask: Task<Void, Never>?
    /// When set, the next `currentPage` change matching this value is ours — don't start a new turn.
    @State private var ignorePageChange: Int?

    /// Room left for the floating pager bar so the binder never sits under it.
    private let outerInset: CGFloat = 28
    private let bottomInset: CGFloat = 88

    private var isTurning: Bool { abs(angle) > 0.5 || fromPage != toPage }

    var body: some View {
        GeometryReader { geo in
            let available = CGSize(
                width: max(geo.size.width - outerInset * 2, 1),
                height: max(geo.size.height - outerInset - bottomInset, 1)
            )
            let metrics = BinderMetrics.fitting(available)

            BinderStack(
                fromPage: fromPage,
                toPage: toPage,
                angle: reduceMotion ? 0 : angle,
                metrics: metrics,
                selection: $selection
            )
            .frame(width: metrics.totalWidth, height: metrics.totalHeight)
            .frame(width: geo.size.width, height: geo.size.height - bottomInset + outerInset, alignment: .center)
            .overlay {
                TrackpadPageTurnCatcher(isTracking: swipe != nil, isSuspended: selection != nil) { event in
                    handleScroll(event, pageWidth: metrics.pageWidth)
                }
                .allowsHitTesting(false)
            }
        }
        // Clicking the page background dismisses an open card popover.
        .contentShape(Rectangle())
        .onTapGesture { selection = nil }
        .onAppear {
            fromPage = binder.currentPage
            toPage = binder.currentPage
        }
        .onChange(of: binder.currentPage) { _, newValue in
            if selection != nil {
                withAnimation(.easeOut(duration: 0.16)) { selection = nil }
            }
            if ignorePageChange == newValue {
                ignorePageChange = nil
                return
            }
            ignorePageChange = nil
            handlePageChange(newValue)
        }
        .onChange(of: reduceMotion) { _, reduced in
            if reduced { snapToCurrentPage() }
        }
    }

    // MARK: - currentPage → turn

    private func handlePageChange(_ newPage: Int) {
        if reduceMotion {
            snapToCurrentPage()
            return
        }

        // A search auto-flip (or the pager) wins over a finger still on the trackpad.
        if swipe != nil {
            swipe = nil
            swipeEndTask?.cancel()
            swipeEndTask = nil
        }

        retarget(to: newPage)
    }

    /// Drive the in-flight turn toward `newPage` instead of queueing another one.
    private func retarget(to newPage: Int) {
        if abs(abs(angle) - 180) < 1 {
            var transaction = Transaction()
            transaction.disablesAnimations = true
            withTransaction(transaction) {
                fromPage = toPage
                angle = 0
            }
        }

        if newPage == fromPage && abs(angle) < 0.5 {
            toPage = newPage
            return
        }

        if newPage == fromPage {
            toPage = newPage
            animateAngle(to: 0)
            return
        }

        toPage = newPage
        animateAngle(to: newPage > fromPage ? -180 : 180)
    }

    private func animateAngle(to target: Double) {
        turnGeneration += 1
        let generation = turnGeneration
        let remaining = max(0.12, PageTurn.duration * (1 - abs(angle) / 180))
        withAnimation(.easeInOut(duration: remaining), completionCriteria: .logicallyComplete) {
            angle = target
        } completion: {
            guard generation == turnGeneration else { return }
            settle()
        }
    }

    private func settle() {
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            fromPage = toPage
            angle = 0
        }
    }

    private func snapToCurrentPage() {
        turnGeneration += 1
        swipe = nil
        swipeEndTask?.cancel()
        swipeEndTask = nil
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            fromPage = binder.currentPage
            toPage = binder.currentPage
            angle = 0
        }
    }

    // MARK: - Trackpad

    private func handleScroll(_ event: TrackpadScrollEvent, pageWidth: CGFloat) {
        guard selection == nil else { return }
        let deltaX = event.deltaX
        let phase = event.phase
        let momentum = event.momentum

        // Inertia after we've already committed or cancelled should not start a new turn.
        if swipe == nil && !momentum.isEmpty { return }

        // A mouse wheel is discrete notches, not a finger tracking across the pad.
        if !event.isPrecise && phase.isEmpty && momentum.isEmpty {
            if deltaX < -0.5 { binder.next() }
            else if deltaX > 0.5 { binder.previous() }
            return
        }

        if reduceMotion {
            handleReducedMotionScroll(deltaX, phase: phase, momentum: momentum)
            return
        }

        if swipe == nil {
            if phase.contains(.ended) || phase.contains(.cancelled) { return }
            beginSwipeIfNeeded(deltaX: deltaX, timestamp: event.timestamp)
        }

        guard let session = swipe else { return }

        // Fingers up: commit or snap. Don't let leftover inertia keep scrubbing.
        if phase.contains(.ended) || phase.contains(.cancelled) || !momentum.isEmpty {
            endSwipe()
            return
        }

        let deltaDegrees = Double(deltaX / max(pageWidth, 1)) * 180
        var newAngle = angle + deltaDegrees
        if session.isForward {
            newAngle = min(0, max(-180, newAngle))
        } else {
            newAngle = max(0, min(180, newAngle))
        }

        var updated = session
        let dt = event.timestamp - session.lastTimestamp
        if dt > 0 {
            updated.velocity = deltaX / CGFloat(dt)
        }
        updated.lastTimestamp = event.timestamp
        swipe = updated

        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) { angle = newAngle }
        scheduleSwipeEndIfNeeded()
    }

    private func scheduleSwipeEndIfNeeded() {
        swipeEndTask?.cancel()
        swipeEndTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 200_000_000)
            guard !Task.isCancelled, swipe != nil else { return }
            endSwipe()
        }
    }

    private func handleReducedMotionScroll(
        _ deltaX: CGFloat,
        phase: NSEvent.Phase,
        momentum: NSEvent.Phase
    ) {
        if swipe == nil {
            let wantForward = deltaX < 0
            if wantForward && !binder.canGoNext { return }
            if !wantForward && !binder.canGoPrevious { return }
            swipe = SwipeSession(isForward: wantForward, velocity: 0, lastTimestamp: 0, accumulated: 0)
        }
        guard var session = swipe else { return }
        session.accumulated += deltaX
        swipe = session

        let finished = phase.contains(.ended) || phase.contains(.cancelled)
            || (phase.isEmpty && momentum.isEmpty)
        guard finished else { return }
        swipe = nil
        if session.accumulated < -40 {
            binder.next()
        } else if session.accumulated > 40 {
            binder.previous()
        }
    }

    private func beginSwipeIfNeeded(deltaX: CGFloat, timestamp: TimeInterval) {
        guard swipe == nil else { return }
        let wantForward = deltaX < 0
        let inFlight = abs(angle) > 0.5 || fromPage != toPage

        if inFlight {
            let forward = angle < 0 || (abs(angle) < 0.5 && toPage >= fromPage)
            swipe = SwipeSession(isForward: forward, velocity: 0, lastTimestamp: timestamp, accumulated: 0)
            turnGeneration += 1
            return
        }

        if wantForward && !binder.canGoNext { return }
        if !wantForward && !binder.canGoPrevious { return }

        fromPage = binder.currentPage
        toPage = wantForward ? fromPage + 1 : fromPage - 1
        swipe = SwipeSession(isForward: wantForward, velocity: 0, lastTimestamp: timestamp, accumulated: 0)
        binder.prefetch(page: toPage)
    }

    private func endSwipe() {
        guard let session = swipe else { return }
        swipe = nil
        swipeEndTask?.cancel()
        swipeEndTask = nil

        let progress = abs(angle) / 180
        let flicked = abs(session.velocity) > 800 && (
            session.isForward ? session.velocity < 0 : session.velocity > 0
        )

        if progress > 0.35 || flicked {
            let dest = min(max(toPage, 1), Pokedex.pageCount)
            toPage = dest
            let target: Double = session.isForward ? -180 : 180
            turnGeneration += 1
            let generation = turnGeneration
            let remaining = max(0.12, PageTurn.duration * (1 - progress))
            withAnimation(.easeInOut(duration: remaining), completionCriteria: .logicallyComplete) {
                angle = target
            } completion: {
                guard generation == turnGeneration else { return }
                settle()
                syncCurrentPage(dest)
            }
        } else {
            let origin = fromPage
            toPage = origin
            turnGeneration += 1
            let generation = turnGeneration
            withAnimation(.spring(response: 0.35, dampingFraction: 0.86), completionCriteria: .logicallyComplete) {
                angle = 0
            } completion: {
                guard generation == turnGeneration else { return }
                settle()
                syncCurrentPage(origin)
            }
        }
    }

    private func syncCurrentPage(_ page: Int) {
        guard binder.currentPage != page else { return }
        ignorePageChange = page
        binder.goTo(page: page)
    }
}

private enum PageTurn {
    static let duration: TimeInterval = 0.45
    /// Deliberately shallow. A strong vanishing point fans the leaf's outer edge to
    /// several times its real height at 90°, so the turning page reads as bigger than
    /// the binder holding it. See `leafScale` for the rest of that correction.
    static let perspective: CGFloat = 0.2
}

private struct SwipeSession {
    var isForward: Bool
    var velocity: CGFloat
    var lastTimestamp: TimeInterval
    var accumulated: CGFloat
}

private struct TrackpadScrollEvent {
    var deltaX: CGFloat
    var phase: NSEvent.Phase
    var momentum: NSEvent.Phase
    var timestamp: TimeInterval
    var isPrecise: Bool
}

// MARK: - The binder

/// The whole binder, at rest and mid-turn alike: cover, both pages, the ring
/// hardware — plus, while a turn is in flight, the leaf standing up off the rings.
///
/// One view for both states on purpose. Swapping between a "turning" view and a
/// "settled" view handed every pocket a new identity the instant the turn ended, so
/// the page you had just landed on tore itself down and rebuilt itself — the quick
/// refresh you could see on the left side. Here the flat pages are the same views
/// from the first frame of a turn to the last; only the leaf comes and goes.
///
/// The flat layer is *not* a single spread. A turning leaf only uncovers the side it
/// lifts off; the side it is falling toward keeps showing the page that is already
/// there until the leaf actually lands on it. Rendering the destination spread whole
/// underneath is what made the far page change halfway through the turn.
///
/// Z-order, back to front: cover plate, the flat pages, the turning leaf, the rings.
/// The leaf rides *over* the cover's border, clipped to the binder's outer edge so it
/// can never spill onto the desk.
struct BinderStack: View {
    let fromPage: Int
    let toPage: Int
    let angle: Double
    let metrics: BinderMetrics
    @Binding var selection: CardSelection?

    private var isTurning: Bool { abs(angle) > 0.5 || fromPage != toPage }
    private var showingFront: Bool { abs(angle) < 90 }

    /// Negative angle = right leaf flipping left (higher page). At rest, the destination
    /// relative to `fromPage` decides, so the first frame of a turn is already correct.
    private var isForward: Bool {
        if abs(angle) > 0.5 { return angle < 0 }
        return toPage >= fromPage
    }

    /// Peaks at 90° and returns to 0 at ±180 so the shadow does not pop when we settle.
    private var shadowOpacity: Double {
        sin(abs(angle) * .pi / 180) * 0.5
    }

    /// Undoes the perspective fan on the leaf's outer edge.
    ///
    /// Perspective scales a point by `1 / (1 - perspective · sin|θ|)` at the edge
    /// furthest from the hinge, which is what pushed the page past the cover. Shrinking
    /// by the inverse keeps the leaf inside the binder for the whole turn while the
    /// near/far taper — the part that actually reads as depth — survives.
    private var leafScale: CGFloat {
        1 - PageTurn.perspective * CGFloat(sin(abs(angle) * .pi / 180))
    }

    var body: some View {
        ZStack {
            BinderCover(metrics: metrics)

            ZStack {
                flatPages
                    .zIndex(0)

                if isTurning {
                    turningLeaf
                        // No fade on the way in or out. The leaf appears flat on top of
                        // the page it is lifting off and lands flat on the page it is
                        // covering, so both hand-offs are already pixel-identical.
                        .transition(.identity)
                        .zIndex(1)
                }

                SpineView(metrics: metrics)
                    .zIndex(2)
            }
            .frame(width: metrics.totalWidth, height: metrics.totalHeight)
            .clipShape(
                RoundedRectangle(cornerRadius: metrics.coverCornerRadius, style: .continuous)
            )
            // A leaf in flight must not swallow clicks meant for the pockets it passes over.
            .allowsHitTesting(!isTurning)
        }
        .frame(width: metrics.totalWidth, height: metrics.totalHeight)
    }

    /// Both pages lying flat under the leaf.
    ///
    /// The side the leaf lifts off shows the destination page, uncovered as the leaf
    /// rises. The side the leaf falls toward is still the page you were reading — it
    /// only becomes the destination page when the leaf lands on top of it, which is
    /// the frame this composite hands back to `BinderSpread`.
    private var flatPages: some View {
        HStack(spacing: 0) {
            PageSideView(
                page: isForward ? fromPage : toPage,
                side: .left,
                metrics: metrics,
                selection: $selection
            )
            .overlay { if !isForward { pageShadow(toward: .trailing) } }
            spineGutter
            PageSideView(
                page: isForward ? toPage : fromPage,
                side: .right,
                metrics: metrics,
                selection: $selection
            )
            .overlay { if isForward { pageShadow(toward: .leading) } }
        }
    }

    /// The shadow the standing leaf throws into the gutter of the page it uncovered.
    private func pageShadow(toward edge: Edge) -> some View {
        LinearGradient(
            colors: edge == .trailing
                ? [.clear, .black.opacity(shadowOpacity)]
                : [.black.opacity(shadowOpacity), .clear],
            startPoint: .leading,
            endPoint: .trailing
        )
        .clipShape(RoundedRectangle(cornerRadius: metrics.pageCornerRadius, style: .continuous))
        .allowsHitTesting(false)
    }

    @ViewBuilder
    private var turningLeaf: some View {
        let lift = sin(abs(angle) * .pi / 180) * 0.45
        let scale = leafScale
        if isForward {
            if showingFront {
                HStack(spacing: 0) {
                    Color.clear.frame(width: metrics.pageWidth, height: metrics.pageHeight)
                    spineGutter
                    PageSideView(page: fromPage, side: .right, metrics: metrics, selection: $selection)
                        .rotation3DEffect(
                            .degrees(angle),
                            axis: (x: 0, y: 1, z: 0),
                            anchor: .leading,
                            perspective: PageTurn.perspective
                        )
                        .scaleEffect(scale, anchor: .leading)
                        .shadow(color: .black.opacity(lift), radius: 18, x: -6, y: 4)
                }
            } else {
                HStack(spacing: 0) {
                    PageSideView(page: toPage, side: .left, metrics: metrics, selection: $selection)
                        .rotation3DEffect(
                            .degrees(angle + 180),
                            axis: (x: 0, y: 1, z: 0),
                            anchor: .trailing,
                            perspective: PageTurn.perspective
                        )
                        .scaleEffect(scale, anchor: .trailing)
                        .shadow(color: .black.opacity(lift), radius: 18, x: 6, y: 4)
                    spineGutter
                    Color.clear.frame(width: metrics.pageWidth, height: metrics.pageHeight)
                }
            }
        } else {
            if showingFront {
                HStack(spacing: 0) {
                    PageSideView(page: fromPage, side: .left, metrics: metrics, selection: $selection)
                        .rotation3DEffect(
                            .degrees(angle),
                            axis: (x: 0, y: 1, z: 0),
                            anchor: .trailing,
                            perspective: PageTurn.perspective
                        )
                        .scaleEffect(scale, anchor: .trailing)
                        .shadow(color: .black.opacity(lift), radius: 18, x: 6, y: 4)
                    spineGutter
                    Color.clear.frame(width: metrics.pageWidth, height: metrics.pageHeight)
                }
            } else {
                HStack(spacing: 0) {
                    Color.clear.frame(width: metrics.pageWidth, height: metrics.pageHeight)
                    spineGutter
                    PageSideView(page: toPage, side: .right, metrics: metrics, selection: $selection)
                        .rotation3DEffect(
                            .degrees(angle - 180),
                            axis: (x: 0, y: 1, z: 0),
                            anchor: .leading,
                            perspective: PageTurn.perspective
                        )
                        .scaleEffect(scale, anchor: .leading)
                        .shadow(color: .black.opacity(lift), radius: 18, x: -6, y: 4)
                }
            }
        }
    }

    private var spineGutter: some View {
        Color.clear.frame(width: metrics.spineWidth, height: metrics.pageHeight)
    }
}

// MARK: - Cover

/// The binder's outer plate — the object the pages sit inside.
private struct BinderCover: View {
    let metrics: BinderMetrics
    @Environment(\.appTheme) private var theme

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: metrics.coverCornerRadius, style: .continuous)
        return shape
            .fill(
                LinearGradient(
                    colors: [theme.coverHighlight, theme.cover, theme.coverDeep],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .overlay(
                shape.strokeBorder(
                    LinearGradient(
                        colors: [.white.opacity(0.22), .clear, .black.opacity(0.25)],
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    lineWidth: 1.5
                )
            )
            .shadow(
                color: .black.opacity(0.35),
                radius: metrics.cardWidth * 0.16,
                y: metrics.cardWidth * 0.06
            )
    }
}

/// The ring channel between the two pages.
struct SpineView: View {
    let metrics: BinderMetrics
    @Environment(\.appTheme) private var theme

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [theme.coverDeep, theme.cover, theme.cover, theme.coverDeep],
                startPoint: .leading,
                endPoint: .trailing
            )
            .overlay(
                LinearGradient(
                    colors: [.black.opacity(0.30), .clear, .black.opacity(0.30)],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )

            VStack(spacing: metrics.pageHeight * 0.22) {
                ForEach(0..<3, id: \.self) { _ in ring }
            }
        }
        .frame(width: metrics.spineWidth, height: metrics.pageHeight)
    }

    private var ring: some View {
        Circle()
            .strokeBorder(
                LinearGradient(
                    colors: [theme.brassBright, theme.brass, theme.brassDeep, theme.brass],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                lineWidth: metrics.ringThickness
            )
            .frame(width: metrics.ringDiameter, height: metrics.ringDiameter)
            .shadow(color: .black.opacity(0.45), radius: metrics.ringThickness * 0.8, y: 1)
    }
}

// MARK: - Trackpad catcher

/// Two-finger horizontal scrolling over the binder, without stealing clicks from the cards.
///
/// Clicks pass through (`hitTest` is nil). Scroll events are caught with a local monitor
/// so the page can follow the finger — a SwiftUI `DragGesture` would require a click-drag.
private struct TrackpadPageTurnCatcher: NSViewRepresentable {
    var isTracking: Bool
    var isSuspended: Bool
    var onScroll: (TrackpadScrollEvent) -> Void

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
        context.coordinator.isTracking = isTracking
        context.coordinator.isSuspended = isSuspended
        context.coordinator.onScroll = onScroll
        nsView.coordinator = context.coordinator
        context.coordinator.view = nsView
    }

    static func dismantleNSView(_ nsView: CatcherView, coordinator: Coordinator) {
        coordinator.teardown()
    }

    final class Coordinator {
        weak var view: CatcherView?
        var isTracking = false
        var isSuspended = false
        var onScroll: ((TrackpadScrollEvent) -> Void)?
        private var monitor: Any?

        func install() {
            guard monitor == nil else { return }
            monitor = NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { [weak self] event in
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

            let deltaX = event.scrollingDeltaX
            let deltaY = event.scrollingDeltaY
            if isTracking || abs(deltaX) > abs(deltaY) {
                let payload = TrackpadScrollEvent(
                    deltaX: deltaX,
                    phase: event.phase,
                    momentum: event.momentumPhase,
                    timestamp: event.timestamp,
                    isPrecise: event.hasPreciseScrollingDeltas
                )
                if Thread.isMainThread {
                    onScroll?(payload)
                } else {
                    DispatchQueue.main.async { [onScroll] in
                        onScroll?(payload)
                    }
                }
                return nil
            }
            return event
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
