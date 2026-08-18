import SwiftUI

@main
struct PokeBinderApp: App {
    @AppStorage(AppSettings.appearanceKey) private var appearance: AppAppearance = .system
    @AppStorage(AppSettings.appStyleKey) private var appStyle: AppStyle = .classic
    @AppStorage(AppSettings.glassPaletteKey) private var glassPalette: GlassPalette = .fullGlass

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.appTheme, Theme(style: appStyle, palette: glassPalette))
                .frame(minWidth: 1000, minHeight: 780)
                // `initial: true` applies the saved choice on launch as well as on change.
                .onChange(of: appearance, initial: true) { _, new in new.apply() }
                .task { await TypeMatchupStore.shared.warmup() }
        }
        .defaultSize(width: 1320, height: 900)
        .windowToolbarStyle(.unified)
    }
}
