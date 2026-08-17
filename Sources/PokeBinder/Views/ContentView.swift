import SwiftUI

struct ContentView: View {
    @StateObject private var binder = BinderState()
    @StateObject private var collection = CollectionStore()
    @State private var showSettings = false
    @FocusState private var searchFocused: Bool

    var body: some View {
        ZStack {
            Theme.windowBackground.ignoresSafeArea()

            switch binder.viewMode {
            case .binder:
                BinderView()
            case .grid:
                GridViewStub()
            }

            if binder.viewMode == .binder {
                VStack {
                    Spacer()
                    bottomBar
                }
            }

            keyboardShortcuts
        }
        .background(WindowConfigurator())
        .environmentObject(binder)
        .environmentObject(collection)
        .toolbar { toolbarContent }
        .sheet(isPresented: $showSettings) {
            SettingsSheet()
                .environmentObject(collection)
        }
        .task {
            await collection.load()
            binder.prefetchNeighbours()
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
    // No `if #available` may appear inside this builder: ToolbarContentBuilder's
    // buildLimitedAvailability is macOS 14.5+, and we target 14.0, so it would
    // resolve to the obsoleted overload. Nothing here needs one.
    //
    // Toolbar items also get macOS 26's own Liquid Glass — never apply
    // `.floatingChrome` here, or it becomes glass-on-glass.

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .navigation) {
            HStack(spacing: 18) {
                viewModeTab(.binder)
                viewModeTab(.grid)
            }
        }

        ToolbarItem(placement: .principal) {
            searchField
        }

        ToolbarItem(placement: .primaryAction) {
            Button {
                showSettings = true
            } label: {
                Image(systemName: "gearshape")
            }
            .buttonStyle(.plain)
            .help("Settings")
        }
    }

    /// A bare text tab with a brass underline for the active view — no segmented
    /// track. macOS 26 already draws a glass capsule around each toolbar item, so
    /// any container of our own here would be an oval inside an oval.
    private func viewModeTab(_ mode: ViewMode) -> some View {
        let isActive = binder.viewMode == mode
        return Button {
            binder.viewMode = mode
        } label: {
            VStack(spacing: 3) {
                Text(mode.title)
                    .font(Theme.nameFont(size: 13))
                    .foregroundStyle(isActive ? Theme.brass : Theme.textSecondary)
                Capsule()
                    .fill(isActive ? Theme.brass : .clear)
                    .frame(height: 2)
            }
            .fixedSize()
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .animation(.easeOut(duration: 0.15), value: isActive)
    }

    /// Also bare — icon, field, and match counter with no background of its own.
    private var searchField: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 12))
                .foregroundStyle(Theme.textSecondary)

            TextField("Search", text: $binder.searchText)
                .textFieldStyle(.plain)
                .frame(width: 190)
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
                        .foregroundStyle(Theme.textSecondary)
                }
                .buttonStyle(.plain)
                .help("Clear search")
            }
        }
        .frame(height: 26)
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
        }
        .frame(width: 0, height: 0)
        .opacity(0)
    }
}
