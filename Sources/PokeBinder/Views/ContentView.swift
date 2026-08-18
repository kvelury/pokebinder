import PokeBinderSync
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
    @Environment(\.appTheme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var binder = BinderState()
    @StateObject private var collection = CollectionStore()
    @StateObject private var notion = NotionManager()
    @StateObject private var hoverTooltip = HoverTooltipModel()
    // Plain @State, not @StateObject, on purpose: ContentView must NOT subscribe to this
    // object. cardWidth changes on every frame of a pinch, and a @StateObject here would
    // re-evaluate the whole ContentView body — toolbar, overlay, tooltip host — 60 times a
    // second. GridView and GridZoomMeter take it as @EnvironmentObject and observe it there.
    @State private var grid = GridState()
    @State private var showSettings = false
    @State private var selection: CardSelection?
    @State private var isAppActive = true
    @FocusState private var searchFocused: Bool

    @AppStorage(AppSettings.notionSyncIntervalKey)
    private var syncInterval: NotionSyncInterval = .manual
    @AppStorage(AppSettings.notionSyncCustomMinutesKey)
    private var customSyncMinutes = AppSettings.defaultNotionSyncCustomMinutes

    var body: some View {
        ZStack {
            theme.windowBackground.ignoresSafeArea()

            Group {
                switch binder.viewMode {
                case .binder:
                    BinderView(selection: $selection)
                case .grid:
                    GridView(selection: $selection)
                }
            }
            .padding(.top, theme.isLiquidGlass ? 54 : 0)

            VStack {
                Spacer()
                bottomBar
            }

            CardZoomOverlay(selection: $selection)

            toolbarDivider
            keyboardShortcuts

            if theme.isLiquidGlass {
                VStack(spacing: 0) {
                    glassTopControls
                    Spacer()
                }
                .zIndex(50)
            }

            HoverTooltipHost(model: hoverTooltip)
                .zIndex(100)
        }
        .coordinateSpace(.named(BinderSpace.content))
        .background(WindowConfigurator(style: theme.style))
        .environmentObject(binder)
        .environmentObject(collection)
        .environmentObject(notion)
        .environmentObject(hoverTooltip)
        .environmentObject(grid)
        .toolbar { toolbarContent }
        // The app's name is already in the menu bar; a second copy of it between the
        // view tabs and the search field is just noise. `titleVisibility = .hidden` on
        // the NSWindow no longer covers this — a unified toolbar draws the title as a
        // toolbar item of its own, so it has to be removed as one.
        .toolbar(removing: .title)
        // A flat, opaque bar. Without this the titlebar stays translucent and the
        // desktop behind the window shows through along the top edge.
        .toolbarBackground(theme.chrome, for: .windowToolbar)
        .toolbarBackgroundVisibility(theme.isLiquidGlass ? .hidden : .visible, for: .windowToolbar)
        .sheet(isPresented: $showSettings) {
            SettingsSheet()
                .environmentObject(collection)
                .environmentObject(notion)
        }
        .onChange(of: binder.viewMode) { old, new in
            withAnimation(cardDetailMotion) { selection = nil }
            if old == .grid, new == .binder {
                binder.goTo(page: Pokedex.page(for: grid.anchorDex))
            }
        }
        .onChange(of: selection) { _, new in
            hoverTooltip.setSuppressed(
                new != nil,
                animation: AppMotion.respectingReduceMotion(AppMotion.quick, reduceMotion: reduceMotion)
            )
        }
        .task {
            if notion.isConnected {
                await collection.use(NotionOwnershipBackend(manager: notion))
            } else {
                await collection.load()
            }
            binder.prefetchNeighbours()
        }
        .task(id: syncScheduleID) {
            await runScheduledSyncLoop()
        }
        .onChange(of: scenePhase, initial: true) { _, phase in
            isAppActive = phase == .active
            if phase == .active, notion.isConnected {
                Task {
                    await collection.syncIfDue(
                        interval: syncInterval,
                        customMinutes: customSyncMinutes
                    )
                }
            }
        }
    }

    private var syncScheduleID: String {
        "\(syncInterval.rawValue)-\(customSyncMinutes)-\(notion.isConnected)"
    }

    private func runScheduledSyncLoop() async {
        guard notion.isConnected else { return }
        guard let minutes = syncInterval.resolvedMinutes(customMinutes: customSyncMinutes) else {
            return
        }
        while !Task.isCancelled {
            do {
                try await Task.sleep(for: .seconds(minutes * 60))
            } catch {
                return
            }
            guard !Task.isCancelled else { return }
            guard isAppActive else { continue }
            await collection.resync()
        }
    }

    /// A hairline where the toolbar ends and the content begins.
    ///
    /// The unified toolbar blends into the window background, which leaves the top of
    /// the app with no edge at all. One rule reinstates it. It hangs off the top of
    /// the content area, so it lands exactly on the titlebar boundary.
    private var toolbarDivider: some View {
        VStack(spacing: 0) {
            if !theme.isLiquidGlass {
                Rectangle()
                    .fill(theme.chromeDivider)
                    .frame(height: 1)
            }
            Spacer()
        }
    }

    // MARK: - Bottom bar

    /// The pager stays centred in the window regardless of how wide the count pill
    /// gets, so it sits under the spine rather than drifting.
    private var bottomBar: some View {
        ZStack {
            Group {
                switch binder.viewMode {
                case .binder: PagerBar()
                case .grid:   GridZoomMeter()
                }
            }
            HStack {
                NotionResyncButton()
                Spacer()
                CollectedCountPill()
            }
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 20)
    }

    /// Liquid Glass is a floating functional layer rather than a continuous bar.
    /// The leading inset clears the standard traffic-light controls while search
    /// remains mathematically centred in the window.
    private var glassTopControls: some View {
        GlassEffectContainer(spacing: 12) {
            ZStack {
                searchField

                HStack {
                    HStack(spacing: 8) {
                        viewModeButton(.binder, icon: "book.closed")
                        viewModeButton(.grid, icon: "square.grid.2x2")
                    }

                    Spacer()

                    Button {
                        showSettings = true
                    } label: {
                        toolbarIcon("gearshape", tint: theme.textSecondary)
                            .contentShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .floatingPill(in: Circle(), interactive: true)
                    .help("Settings")
                    .accessibilityLabel("Settings")
                }
                .padding(.leading, 76)
            }
            .padding(.horizontal, 16)
        }
        .frame(height: 48)
        .padding(.top, 10)
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
        if !theme.isLiquidGlass {
            ToolbarItem(placement: .navigation) {
                HStack(spacing: 4) {
                    viewModeButton(.binder, icon: "book.closed")
                    viewModeButton(.grid, icon: "square.grid.2x2")
                }
            }
            .sharedBackgroundVisibility(.hidden)

            ToolbarItem(placement: .principal) {
                searchField
            }
            .sharedBackgroundVisibility(.hidden)

            ToolbarItem(placement: .primaryAction) {
                Button {
                    showSettings = true
                } label: {
                    toolbarIcon("gearshape", tint: theme.textSecondary)
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .help("Settings")
            }
            .sharedBackgroundVisibility(.hidden)
        }
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
    @ViewBuilder
    private func viewModeButton(_ mode: ViewMode, icon: String) -> some View {
        let isActive = binder.viewMode == mode
        if theme.isLiquidGlass {
            Button {
                binder.viewMode = mode
            } label: {
                toolbarIcon(icon, tint: isActive ? theme.brass : theme.textSecondary)
                    .contentShape(Capsule())
            }
            .buttonStyle(.plain)
            .pillChrome(in: Capsule(), active: isActive, interactive: true)
            .help(mode.title)
            .animation(controlMotion, value: isActive)
        } else {
            Button {
                binder.viewMode = mode
            } label: {
                toolbarIcon(icon, tint: isActive ? theme.brass : theme.textSecondary)
                    .background(Capsule().fill(isActive ? theme.controlFillActive : .clear))
                    .overlay(Capsule().strokeBorder(isActive ? theme.controlStroke : .clear, lineWidth: 1))
                    .contentShape(Capsule())
            }
            .buttonStyle(.plain)
            .help(mode.title)
            .animation(controlMotion, value: isActive)
        }
    }

    private var controlMotion: Animation? {
        AppMotion.respectingReduceMotion(AppMotion.quick, reduceMotion: reduceMotion)
    }

    private var cardDetailMotion: Animation {
        reduceMotion ? AppMotion.quick : AppMotion.cardDetail
    }

    private func zoomStep(_ action: () -> Void) {
        withAnimation(AppMotion.respectingReduceMotion(AppMotion.feedback, reduceMotion: reduceMotion)) {
            action()
        }
    }

    /// One wide pill holding icon, field, match counter and clear button. Search gets
    /// the whole middle of the bar rather than a 190pt slot, because it is the only
    /// control here anyone reaches for repeatedly.
    private var searchField: some View {
        HStack(spacing: 7) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(theme.textSecondary)

            TextField("Search Pokémon", text: $binder.searchText)
                .textFieldStyle(.plain)
                .font(.system(size: 13))
                .focused($searchFocused)
                .onSubmit { binder.nextMatch() }

            if binder.isSearching {
                Text(binder.matchPositionLabel)
                    .font(theme.numberFont(size: 11))
                    .foregroundStyle(binder.matches.isEmpty ? theme.textSecondary : theme.brass)
                    .fixedSize()

                Button {
                    binder.searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(theme.textSecondary)
                }
                .buttonStyle(.plain)
                .help("Clear search")
            }
        }
        .padding(.horizontal, 12)
        .frame(width: 380, height: Chrome.toolbarControlHeight)
        .pillChrome(in: Capsule(), stroked: false, interactive: theme.isLiquidGlass)
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
            Button("") { if binder.viewMode == .grid { zoomStep { grid.stepIn() } } }
                .keyboardShortcut("+", modifiers: .command)
            Button("") { if binder.viewMode == .grid { zoomStep { grid.stepIn() } } }
                .keyboardShortcut("=", modifiers: .command)
            Button("") { if binder.viewMode == .grid { zoomStep { grid.stepOut() } } }
                .keyboardShortcut("-", modifiers: .command)
            Button("") { if binder.viewMode == .grid { zoomStep { grid.resetZoom() } } }
                .keyboardShortcut("0", modifiers: .command)
        }
        .frame(width: 0, height: 0)
        .opacity(0)
    }
}
