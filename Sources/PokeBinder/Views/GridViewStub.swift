import SwiftUI

/// Placeholder for the Grid view.
///
/// The segment is deliberately live rather than disabled — a permanently greyed-out
/// control reads as a bug, and this is the real container the grid drops into later.
/// Replacing the body of this view is the whole of that future change.
struct GridViewStub: View {
    @EnvironmentObject private var binder: BinderState

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "square.grid.3x3.fill")
                .font(.system(size: 46))
                .foregroundStyle(Theme.brass.opacity(0.85))
                .padding(.bottom, 4)

            Text("Grid view")
                .font(Theme.nameFont(size: 21))
                .foregroundStyle(Theme.textPrimary)

            Text("Coming soon")
                .font(Theme.nameFont(size: 13))
                .foregroundStyle(Theme.textSecondary)

            Button("Back to Binder") {
                binder.viewMode = .binder
            }
            .buttonStyle(.borderedProminent)
            .tint(Theme.brass)
            .padding(.top, 10)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
