import SwiftUI

/// The page control: ◀ , an editable `N / 19`, ▶.
///
/// Kept as three surfaces rather than one wide pill because the gap gives the text
/// field's focus ring room to breathe when you click into it, and because the arrows
/// want to be round — a circle is the honest shape for a single glyph.
struct PagerBar: View {
    @EnvironmentObject private var binder: BinderState

    @State private var pageText: String = "1"
    @State private var isEditingPage = false
    @FocusState private var fieldFocused: Bool

    var body: some View {
        HStack(spacing: 10) {
            arrowButton(
                systemName: "chevron.left",
                enabled: binder.canGoPrevious,
                hint: "Previous page"
            ) { binder.previous() }

            pageField

            arrowButton(
                systemName: "chevron.right",
                enabled: binder.canGoNext,
                hint: "Next page"
            ) { binder.next() }
        }
        .onAppear { pageText = String(binder.currentPage) }
        .onChange(of: binder.currentPage) { _, newValue in
            // Keep the field honest when the page changes from anywhere else
            // (arrows, shortcuts, and in part 2 the search auto-flip).
            pageText = String(newValue)
        }
    }

    // MARK: - Pieces

    private func arrowButton(
        systemName: String,
        enabled: Bool,
        hint: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Theme.textPrimary)
                .frame(width: 36, height: 36)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.3)
        .floatingPill(in: Circle())
        .help(hint)
    }

    private var pageField: some View {
        HStack(spacing: 5) {
            Group {
                if isEditingPage {
                    TextField("", text: $pageText)
                        .textFieldStyle(.plain)
                        .multilineTextAlignment(.trailing)
                        .focused($fieldFocused)
                        // Focus has to wait for the field to exist — setting it in the tap
                        // handler lands before SwiftUI has installed the NSTextField.
                        .onAppear { fieldFocused = true }
                        .onSubmit { commit(); isEditingPage = false }
                } else {
                    Text(pageText)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
            }
            .font(Theme.numberFont(size: 15))
            .foregroundStyle(Theme.textPrimary)
            .frame(width: 28)

            Text("/ \(Pokedex.pageCount)")
                .font(Theme.numberFont(size: 15))
                .foregroundStyle(Theme.textSecondary)
        }
        .padding(.horizontal, 16)
        .frame(height: 36)
        .floatingPill(in: Capsule())
        // An idle-only hit target rather than a guarded .onTapGesture on the pill: a parent
        // tap gesture sitting over a live TextField steals the clicks that place the caret.
        .overlay {
            if !isEditingPage {
                Capsule()
                    .fill(.clear)
                    .contentShape(Capsule())
                    .onTapGesture { isEditingPage = true }
            }
        }
        .help("Click the page number and press Return")
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Page \(binder.currentPage) of \(Pokedex.pageCount)")
        .onChange(of: fieldFocused) { _, focused in
            // Leaving the field without pressing Return should not silently keep a
            // half-typed value on screen.
            if !focused && isEditingPage {
                commit()
                isEditingPage = false
            }
        }
    }

    /// Clamp to 1…19; anything unparseable reverts rather than erroring.
    private func commit() {
        if let value = Int(pageText.trimmingCharacters(in: .whitespaces)) {
            binder.goTo(page: value)
        }
        pageText = String(binder.currentPage)
    }
}

/// Collected count, sitting opposite the pager on the bottom bar.
struct CollectedCountPill: View {
    @EnvironmentObject private var collection: CollectionStore

    var body: some View {
        HStack(spacing: 8) {
            Text("\(collection.ownedCount)")
                .font(Theme.numberFont(size: 14))
                .foregroundStyle(Theme.brass)
            Text("/ \(collection.totalCount) collected")
                .font(Theme.nameFont(size: 12))
                .foregroundStyle(Theme.textSecondary)
        }
        .padding(.horizontal, 14)
        .frame(height: 32)
        .floatingPill(in: Capsule())
    }
}
