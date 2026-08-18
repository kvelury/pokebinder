import SwiftUI

/// Floating glass meter that replaces the pager in grid mode.
///
/// One capsule — the ± glyphs live on it with no chrome of their own, so this is
/// not glass-on-glass.
struct GridZoomMeter: View {
    @EnvironmentObject private var grid: GridState
    @Environment(\.appTheme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var hoveringOut = false
    @State private var hoveringIn = false

    private let trackWidth: CGFloat = 120

    var body: some View {
        HStack(spacing: 10) {
            glyphButton(
                systemName: "minus.magnifyingglass",
                enabled: grid.cardWidth > GridState.minCardWidth,
                hovering: $hoveringOut
            ) {
                step { grid.stepOut() }
            }

            track

            glyphButton(
                systemName: "plus.magnifyingglass",
                enabled: grid.cardWidth < GridState.maxCardWidth,
                hovering: $hoveringIn
            ) {
                step { grid.stepIn() }
            }
        }
        .padding(.horizontal, 12)
        .frame(height: 36)
        .floatingPill(in: Capsule(), interactive: true)
        .help("Card size")
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Card size")
        .accessibilityValue("\(Int(grid.zoom * 100))%")
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: step { grid.stepIn() }
            case .decrement: step { grid.stepOut() }
            default: break
            }
        }
    }

    private var track: some View {
        ZStack(alignment: .leading) {
            Capsule()
                .fill(theme.controlStroke)
                .frame(width: trackWidth, height: 4)
            Capsule()
                .fill(theme.brass)
                .frame(width: grid.zoom * trackWidth, height: 4)
            Circle()
                .fill(theme.brass)
                .frame(width: 13, height: 13)
                .shadow(color: .black.opacity(0.25), radius: 2, y: 1)
                .offset(x: grid.zoom * trackWidth - 6.5)
        }
        .frame(width: trackWidth, height: 36)
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in
                    var transaction = Transaction()
                    transaction.disablesAnimations = true
                    withTransaction(transaction) {
                        grid.zoom = min(max(value.location.x / trackWidth, 0), 1)
                    }
                }
                .onEnded { _ in grid.commit() }
        )
    }

    private func glyphButton(
        systemName: String,
        enabled: Bool,
        hovering: Binding<Bool>,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(hovering.wrappedValue ? theme.textPrimary : theme.textSecondary)
                .frame(width: 22, height: 36)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.3)
        .onHover { hovering.wrappedValue = $0 }
    }

    private func step(_ action: () -> Void) {
        withAnimation(AppMotion.respectingReduceMotion(AppMotion.feedback, reduceMotion: reduceMotion)) {
            action()
        }
    }
}
