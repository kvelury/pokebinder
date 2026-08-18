import SwiftUI

/// Strengths and weaknesses for the opened Pokémon. Detail level is a setting;
/// the fetch is keyed by dex + era so a stale card can never linger.
///
/// Categories lay out in at most two rows: Simple is one row, Advanced is 2×2,
/// and Full is 2×3.
struct TypeMatchupTable: View {
    let dexNumber: Int
    let metrics: CardDetailMetrics
    var isMuted = false
    /// When set, overrides the stored setting — the hover card shows one level less.
    var levelOverride: MatchupDetailLevel? = nil
    /// The hover host is not hit-testable, so a Retry button there would be dead UI.
    var showsRetry = true

    @Environment(\.appTheme) private var theme
    @AppStorage(AppSettings.typeEraKey) private var typeEra: TypeEra = .current
    @AppStorage(AppSettings.matchupDetailLevelKey) private var detailLevel: MatchupDetailLevel = .simple

    @State private var loadState: LoadState = .loading

    var body: some View {
        Group {
            switch loadState {
            case .loading:
                ProgressView()
                    .controlSize(.small)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
            case .failed(let message):
                VStack(spacing: 6) {
                    Text(message)
                        .font(.caption)
                        .foregroundStyle(theme.textSecondary)
                        .multilineTextAlignment(.center)
                    if showsRetry {
                        Button("Retry") { Task { await load() } }
                            .font(.caption)
                            .buttonStyle(.plain)
                            .foregroundStyle(theme.brass)
                    }
                }
                .frame(maxWidth: .infinity)
            case .ready(let summary):
                let rows = summary.rows(for: levelOverride ?? detailLevel)
                if rows.isEmpty {
                    Text("No matchups to show.")
                        .font(.caption)
                        .foregroundStyle(theme.textSecondary)
                        .frame(maxWidth: .infinity)
                } else {
                    let columns = columnCount(for: rows.count)
                    VStack(alignment: .leading, spacing: metrics.matchupRowSpacing) {
                        ForEach(Array(stride(from: 0, to: rows.count, by: columns)), id: \.self) { start in
                            HStack(alignment: .top, spacing: metrics.matchupColumnSpacing) {
                                ForEach(Array(rows[start..<min(start + columns, rows.count)])) { row in
                                    matchupRow(row)
                                }
                            }
                        }
                    }
                }
            }
        }
        .task(id: loadKey) { await load() }
    }

    private var loadKey: String { "\(dexNumber).\(typeEra.rawValue)" }

    private func columnCount(for rowCount: Int) -> Int {
        switch rowCount {
        case ...2: max(1, rowCount)
        case ...4: 2
        default: 3
        }
    }

    @ViewBuilder
    private func matchupRow(_ row: TypeMatchupRow) -> some View {
        VStack(alignment: .leading, spacing: metrics.matchupTitleGap) {
            Text(row.kind.title)
                .font(.system(size: metrics.matchupTitleFontSize, weight: .semibold))
                .foregroundStyle(theme.textSecondary)

            FlowLayout(spacing: metrics.chipSpacing) {
                ForEach(row.entries) { entry in
                    TypeMatchupChip(entry: entry, metrics: metrics, isMuted: isMuted)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            "\(row.kind.title), \(row.entries.map(\.accessibilityLabel).joined(separator: ", "))"
        )
    }

    private func load() async {
        loadState = .loading
        do {
            let summary = try await Pokedex.matchupSummary(for: dexNumber, era: typeEra)
            guard !Task.isCancelled else { return }
            loadState = .ready(summary)
        } catch is CancellationError {
            return
        } catch {
            guard !Task.isCancelled else { return }
            loadState = .failed(error.localizedDescription)
        }
    }
}

private enum LoadState {
    case loading
    case ready(TypeMatchupSummary)
    case failed(String)
}

private struct TypeMatchupChip: View {
    let entry: TypeMatchupEntry
    let metrics: CardDetailMetrics
    var isMuted = false

    @Environment(\.appTheme) private var theme

    var body: some View {
        VStack(spacing: metrics.chipLabelGap) {
            TypeIconView(
                type: entry.type,
                size: metrics.chipIconSize,
                isMuted: isMuted
            )
            Text(entry.label)
                .font(theme.numberFont(size: metrics.chipLabelFontSize))
                .foregroundStyle(theme.textSecondary)
        }
        .accessibilityHidden(true)
    }
}

/// Wraps chips onto the next line inside one matchup category.
private struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        arrange(proposal: proposal, subviews: subviews).size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let placement = arrange(proposal: proposal, subviews: subviews)
        for (subview, origin) in zip(subviews, placement.origins) {
            subview.place(
                at: CGPoint(x: bounds.minX + origin.x, y: bounds.minY + origin.y),
                proposal: .unspecified
            )
        }
    }

    private func arrange(proposal: ProposedViewSize, subviews: Subviews) -> (size: CGSize, origins: [CGPoint]) {
        let maxWidth = proposal.width ?? .infinity
        var origins: [CGPoint] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var width: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > 0, x + size.width > maxWidth {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            origins.append(CGPoint(x: x, y: y))
            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
            width = max(width, x - spacing)
        }

        return (CGSize(width: width, height: y + rowHeight), origins)
    }
}
