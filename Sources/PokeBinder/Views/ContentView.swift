import SwiftUI

/// Toolbar sizing, in one place so the icon buttons and the search field stay the
/// same height as each other. They are the only things in the bar, so anything
/// shorter than the search pill leaves the icons swimming in empty bar.
private enum Chrome {
    static let toolbarControlHeight: CGFloat = 30
    /// The square every toolbar glyph is fitted into — see `toolbarIcon`.
    static let toolbarIcon: CGFloat = 16
    static let toolbarButtonWidth: CGFloat = 36
}

struct ContentView: View {
    @StateObject private var binder = BinderState()
    @StateObject private var collection = CollectionStore()
    @StateObject private var notion = NotionManager()
    @State private var showSettings = false
    @State private var selection: CardSelection?
    @FocusState private var searchFocused: Bool

    var body: some View {
        ZStack {
            Theme.windowBackground.ignoresSafeArea()

            switch binder.viewMode {
            case .binder:
                BinderView(selection: $selection)
            case .grid:
                GridViewStub()
            }

            if binder.viewMode == .binder {
                VStack {
                    Spacer()
                    bottomBar
                }
            }

            if let selection {
                GeometryReader { geo in
                    CardZoomOverlay(
                        selection: selection,
                        containerSize: geo.size,
                        onDismissed: { self.selection = nil }
                    )
                }
                .transition(.opacity)
            }

            toolbarDivider
            keyboardShortcuts
        }
        .coordinateSpace(.named(BinderSpace.content))
        .background(WindowConfigurator())
        .environmentObject(binder)
        .environmentObject(collection)
        .environmentObject(notion)
        .toolbar { toolbarContent }
        // The app's name is already in the menu bar; a second copy of it between the
        // view tabs and the search field is just noise. `titleVisibility = .hidden` on
        // the NSWindow no longer covers this — a unified toolbar draws the title as a
        // toolbar item of its own, so it has to be removed as one.
        .toolbar(removing: .title)
        // A flat, opaque bar. Without this the titlebar stays translucent and the
        // desktop behind the window shows through along the top edge.
        .toolbarBackground(Theme.chrome, for: .windowToolbar)
        .toolbarBackground(.visible, for: .windowToolbar)
        .sheet(isPresented: $showSettings) {
            SettingsSheet()
                .environmentObject(collection)
                .environmentObject(notion)
        }
        .onChange(of: binder.viewMode) { _, _ in selection = nil }
        .task {
            if notion.isConnected {
                await collection.use(NotionOwnershipBackend(manager: notion))
            } else {
                await collection.load()
            }
            binder.prefetchNeighbours()
        }
    }

    /// A hairline where the toolbar ends and the content begins.
    ///
    /// The unified toolbar blends into the window background, which leaves the top of
    /// the app with no edge at all. One rule reinstates it. It hangs off the top of
    /// the content area, so it lands exactly on the titlebar boundary.
    private var toolbarDivider: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(Theme.chromeDivider)
                .frame(height: 1)
            Spacer()
        }
    }

    // MARK: - Bottom bar

    /// The pager stays centred in the window regardless of how wide the count pill
    /// gets, so it sits under the spine rather than drifting.
    private var bottomBar: some View {
        ZStack {
            PagerBar()
            HStack {
                Spacer()
                CollectedCountPill()
            }
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 20)
    }

    // MARK: - Toolbar
    //
    // Three clusters, the shape of a plain macOS toolbar: icon buttons at the left,
    // search taking the whole middle, one action at the right.
    //
    // No `if #available` may appear inside this builder: ToolbarContentBuilder's
    // buildLimitedAvailability is macOS 14.5+, so below that it resolves to the
    // obsoleted overload. We now target 26, so nothing here needs a branch —
    // keep the rule anyway.
    //
    // Everything here draws its own flat pill via `.pillChrome`. `.buttonStyle(.plain)`
    // is what keeps macOS 26 from adding Liquid Glass of its own underneath — drop it
    // and the pill becomes a pill inside a capsule of glass.

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .navigation) {
            HStack(spacing: 4) {
                viewModeButton(.binder, icon: "book.closed")
                viewModeButton(.grid, icon: "square.grid.2x2")
            }
        }
        // Two buttons in one toolbar item get a shared macOS 26 container drawn around
        // the pair — an outer capsule enclosing the active pill's own capsule. Only the
        // active fill should mark the selection, so hide the group's background.
        .sharedBackgroundVisibility(.hidden)

        ToolbarItem(placement: .principal) {
            searchField
        }
        // macOS 26 wraps a toolbar item in a 36pt container of its own — a second capsule
        // 3pt outside ours. `.buttonStyle(.plain)` is what stops that on the icon buttons,
        // but it does not apply to a TextField, so the search pill needs this instead.
        .sharedBackgroundVisibility(.hidden)

        ToolbarItem(placement: .primaryAction) {
            Button {
                showSettings = true
            } label: {
                toolbarIcon("gearshape", tint: Theme.textSecondary)
                    .contentShape(Capsule())
            }
            .buttonStyle(.plain)
            .help("Settings")
        }
        // `.buttonStyle(.plain)` is not enough here: a primary-action item still gets
        // macOS 26's own container drawn around it, which is the ring that appeared
        // around the gear. Nothing in this bar is outlined unless it is selected.
        .sharedBackgroundVisibility(.hidden)
    }

    /// One recipe for every glyph in the bar, so the three icon buttons are the same
    /// size as each other and sit on one line.
    ///
    /// A shared point size is not enough on its own: SF Symbols do not share a bounding
    /// box, and at 16pt `gearshape` draws about a third wider than `book.closed`. Fitting
    /// each glyph into the same square box is what actually makes them match. The button
    /// frame around it is shared too, so every icon is centred in an identical target
    /// and the settings button lines up with the view-mode pair across the bar.
    private func toolbarIcon(_ name: String, tint: Color) -> some View {
        Image(systemName: name)
            .resizable()
            .scaledToFit()
            .fontWeight(.medium)
            .foregroundStyle(tint)
            .frame(width: Chrome.toolbarIcon, height: Chrome.toolbarIcon)
            .frame(width: Chrome.toolbarButtonWidth, height: Chrome.toolbarControlHeight)
    }

    /// Icon-only pills. Only the active one takes a fill, which is what makes the pair
    /// read as a single selection rather than as two unrelated buttons — the same job
    /// the brass underline used to do, without a second visual language for it.
    private func viewModeButton(_ mode: ViewMode, icon: String) -> some View {
        let isActive = binder.viewMode == mode
        return Button {
            binder.viewMode = mode
        } label: {
            toolbarIcon(icon, tint: isActive ? Theme.brass : Theme.textSecondary)
                .background(Capsule().fill(isActive ? Theme.controlFillActive : .clear))
                .overlay(Capsule().strokeBorder(isActive ? Theme.controlStroke : .clear, lineWidth: 1))
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .help(mode.title)
        .animation(.easeOut(duration: 0.15), value: isActive)
    }

    /// One wide pill holding icon, field, match counter and clear button. Search gets
    /// the whole middle of the bar rather than a 190pt slot, because it is the only
    /// control here anyone reaches for repeatedly.
    private var searchField: some View {
        HStack(spacing: 7) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Theme.textSecondary)

            TextField("Search Pokémon", text: $binder.searchText)
                .textFieldStyle(.plain)
                .font(.system(size: 13))
                .focused($searchFocused)
                .onSubmit { binder.nextMatch() }

            if binder.isSearching {
                Text(binder.matchPositionLabel)
                    .font(Theme.numberFont(size: 11))
                    .foregroundStyle(binder.matches.isEmpty ? Theme.textSecondary : Theme.brass)
                    .fixedSize()

                Button {
                    binder.searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.textSecondary)
                }
                .buttonStyle(.plain)
                .help("Clear search")
            }
        }
        .padding(.horizontal, 12)
        .frame(width: 380, height: Chrome.toolbarControlHeight)
        .pillChrome(in: Capsule(), stroked: false)
    }

    /// Zero-sized buttons purely to carry key equivalents. `.hidden()` would take
    /// them out of the responder chain; zero-opacity keeps the shortcuts live.
    private var keyboardShortcuts: some View {
        VStack(spacing: 0) {
            Button("") { searchFocused = true }
                .keyboardShortcut("f", modifiers: .command)
            Button("") { binder.nextMatch() }
                .keyboardShortcut("g", modifiers: .command)
            Button("") { binder.previousMatch() }
                .keyboardShortcut("g", modifiers: [.command, .shift])
            Button("") { binder.previous() }
                .keyboardShortcut(.leftArrow, modifiers: .command)
            Button("") { binder.next() }
                .keyboardShortcut(.rightArrow, modifiers: .command)
        }
        .frame(width: 0, height: 0)
        .opacity(0)
    }
}
