import SwiftUI

/// Structured now so richer hover cards can be added without replacing the
/// positioning and presentation system.
enum HoverTooltipContent: Equatable {
    case label(String)
}

private struct HoverTooltipPresentation: Equatable {
    let id: UUID
    let content: HoverTooltipContent
    var targetFrame: CGRect
}

@MainActor
final class HoverTooltipModel: ObservableObject {
    @Published fileprivate var presentation: HoverTooltipPresentation?
    private var pendingTask: Task<Void, Never>?
    private var pendingID: UUID?

    func schedule(id: UUID, content: HoverTooltipContent, targetFrame: CGRect) {
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
            withAnimation(.easeOut(duration: 0.12)) {
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

    func dismiss(id: UUID) {
        if pendingID == id {
            pendingTask?.cancel()
            pendingTask = nil
            pendingID = nil
        }
        guard presentation?.id == id else { return }
        withAnimation(.easeOut(duration: 0.08)) {
            presentation = nil
        }
    }
}

private struct HoverTooltipModifier: ViewModifier {
    let content: HoverTooltipContent

    @EnvironmentObject private var model: HoverTooltipModel
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
                    model.schedule(id: id, content: content, targetFrame: targetFrame)
                } else {
                    model.dismiss(id: id)
                }
            }
            .onDisappear {
                model.dismiss(id: id)
            }
    }
}

extension View {
    func hoverTooltip(_ text: String) -> some View {
        modifier(HoverTooltipModifier(content: .label(text)))
    }
}

struct HoverTooltipHost: View {
    @ObservedObject var model: HoverTooltipModel
    @State private var tooltipSize: CGSize = .zero

    var body: some View {
        GeometryReader { proxy in
            if let presentation = model.presentation {
                tooltip(for: presentation.content)
                    .onGeometryChange(for: CGSize.self) { $0.size } action: {
                        tooltipSize = $0
                    }
                    .position(position(
                        for: presentation.targetFrame,
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
    private func tooltip(for content: HoverTooltipContent) -> some View {
        switch content {
        case .label(let text):
            Text(text)
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundStyle(Theme.textPrimary)
                .padding(.horizontal, 9)
                .padding(.vertical, 5)
                .fixedSize()
                .background(Capsule().fill(Theme.controlFill))
                .overlay(Capsule().strokeBorder(Theme.controlStroke, lineWidth: 1))
                .shadow(color: .black.opacity(0.18), radius: 6, y: 2)
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
}
