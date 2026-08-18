import SwiftUI

/// Structured now so richer hover cards can be added without replacing the
/// positioning and presentation system.
enum HoverTooltipContent: Equatable {
    case label(String)
    case card(dexNumber: Int)
}

private struct HoverTooltipPresentation: Equatable {
    let id: UUID
    let content: HoverTooltipContent
    var targetFrame: CGRect
}

@MainActor
final class HoverTooltipModel: ObservableObject {
    @Published fileprivate var presentation: HoverTooltipPresentation?
    @Published private(set) var isSuppressed = false
    private var pendingTask: Task<Void, Never>?
    private var pendingID: UUID?

    func schedule(
        id: UUID,
        content: HoverTooltipContent,
        targetFrame: CGRect,
        animation: Animation?
    ) {
        guard !isSuppressed else { return }
        pendingTask?.cancel()
        pendingID = id

        if presentation?.id == id {
            presentation?.targetFrame = targetFrame
            pendingID = nil
            return
        }

        pendingTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 250_000_000)
            guard !Task.isCancelled, let self else { return }
            withAnimation(animation) {
                self.presentation = HoverTooltipPresentation(
                    id: id,
                    content: content,
                    targetFrame: targetFrame
                )
            }
            self.pendingID = nil
            self.pendingTask = nil
        }
    }

    func update(id: UUID, targetFrame: CGRect) {
        guard presentation?.id == id else { return }
        presentation?.targetFrame = targetFrame
    }

    func dismiss(id: UUID, animation: Animation?) {
        if pendingID == id {
            pendingTask?.cancel()
            pendingTask = nil
            pendingID = nil
        }
        guard presentation?.id == id else { return }
        withAnimation(animation) {
            presentation = nil
        }
    }

    func setSuppressed(_ suppressed: Bool, animation: Animation?) {
        isSuppressed = suppressed
        guard suppressed else { return }
        pendingTask?.cancel()
        pendingTask = nil
        pendingID = nil
        withAnimation(animation) { presentation = nil }
    }
}

private struct HoverTooltipModifier: ViewModifier {
    let content: HoverTooltipContent

    @EnvironmentObject private var model: HoverTooltipModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var id = UUID()
    @State private var targetFrame: CGRect = .zero
    @State private var isHovering = false

    func body(content view: Content) -> some View {
        view
            .onGeometryChange(for: CGRect.self) { proxy in
                proxy.frame(in: .named(BinderSpace.content))
            } action: { frame in
                targetFrame = frame
                if isHovering {
                    model.update(id: id, targetFrame: frame)
                }
            }
            .onHover { hovering in
                isHovering = hovering
                if hovering {
                    model.schedule(
                        id: id,
                        content: content,
                        targetFrame: targetFrame,
                        animation: motion
                    )
                } else {
                    model.dismiss(id: id, animation: motion)
                }
            }
            .onDisappear {
                model.dismiss(id: id, animation: motion)
            }
    }

    private var motion: Animation? {
        AppMotion.respectingReduceMotion(AppMotion.quick, reduceMotion: reduceMotion)
    }
}

extension View {
    func hoverTooltip(_ text: String) -> some View {
        modifier(HoverTooltipModifier(content: .label(text)))
    }

    func hoverCard(dexNumber: Int) -> some View {
        modifier(HoverTooltipModifier(content: .card(dexNumber: dexNumber)))
    }
}

struct HoverTooltipHost: View {
    @ObservedObject var model: HoverTooltipModel
    let floatingChrome: Bool
    @Environment(\.appTheme) private var theme
    @State private var tooltipSize: CGSize = .zero

    var body: some View {
        GeometryReader { proxy in
            let safe = CardZoomOverlay.safePanelRect(
                in: proxy.size,
                floatingChrome: floatingChrome
            )
            let metrics = CardDetailMetrics.fitting(safe: safe.size)
            if let presentation = model.presentation {
                tooltip(for: presentation.content, metrics: metrics)
                    .onGeometryChange(for: CGSize.self) { $0.size } action: {
                        tooltipSize = $0
                    }
                    .position(placement(
                        for: presentation.content,
                        target: presentation.targetFrame,
                        tooltipSize: tooltipSize,
                        containerSize: proxy.size
                    ))
                    .transition(.opacity.combined(with: .scale(scale: 0.96)))
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private func tooltip(for content: HoverTooltipContent, metrics: CardDetailMetrics) -> some View {
        switch content {
        case .label(let text):
            Text(text)
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundStyle(theme.textPrimary)
                .padding(.horizontal, 9)
                .padding(.vertical, 5)
                .fixedSize()
                .floatingPill(in: Capsule())
        case .card(let dexNumber):
            CardHoverCard(dexNumber: dexNumber, metrics: metrics)
        }
    }

    private func placement(
        for content: HoverTooltipContent,
        target: CGRect,
        tooltipSize: CGSize,
        containerSize: CGSize
    ) -> CGPoint {
        switch content {
        case .label:
            return position(for: target, tooltipSize: tooltipSize, containerSize: containerSize)
        case .card:
            return positionBeside(for: target, tooltipSize: tooltipSize, containerSize: containerSize)
                ?? position(for: target, tooltipSize: tooltipSize, containerSize: containerSize)
        }
    }

    private func position(
        for target: CGRect,
        tooltipSize: CGSize,
        containerSize: CGSize
    ) -> CGPoint {
        let margin: CGFloat = 8
        let gap: CGFloat = 7
        let width = max(tooltipSize.width, 1)
        let height = max(tooltipSize.height, 1)

        let x = min(
            max(target.midX, margin + width / 2),
            containerSize.width - margin - width / 2
        )
        let fitsAbove = target.minY >= height + gap + margin
        let proposedY = fitsAbove
            ? target.minY - gap - height / 2
            : target.maxY + gap + height / 2
        let y = min(
            max(proposedY, margin + height / 2),
            containerSize.height - margin - height / 2
        )
        return CGPoint(x: x, y: y)
    }

    /// Prefer the side of `target` with more free width — right first on a tie.
    /// Returns `nil` when neither side fits, so the caller can fall back to above/below.
    private func positionBeside(
        for target: CGRect,
        tooltipSize: CGSize,
        containerSize: CGSize
    ) -> CGPoint? {
        let margin: CGFloat = 8
        let gap: CGFloat = 7
        let width = max(tooltipSize.width, 1)
        let height = max(tooltipSize.height, 1)

        let leftFree = target.minX
        let rightFree = containerSize.width - target.maxX
        let preferRight = rightFree >= leftFree

        let rightFits = target.maxX + gap + width <= containerSize.width - margin
        let leftFits = target.minX - gap - width >= margin

        let placeRight: Bool?
        if preferRight {
            placeRight = rightFits ? true : (leftFits ? false : nil)
        } else {
            placeRight = leftFits ? false : (rightFits ? true : nil)
        }
        guard let placeRight else { return nil }

        let rawX = placeRight
            ? target.maxX + gap + width / 2
            : target.minX - gap - width / 2
        let x = min(
            max(rawX, margin + width / 2),
            containerSize.width - margin - width / 2
        )
        let y = min(
            max(target.midY, margin + height / 2),
            containerSize.height - margin - height / 2
        )
        return CGPoint(x: x, y: y)
    }
}
