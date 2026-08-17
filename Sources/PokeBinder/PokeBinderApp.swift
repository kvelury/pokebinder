import SwiftUI

@main
struct PokeBinderApp: App {
    @AppStorage(AppSettings.appearanceKey) private var appearance: AppAppearance = .system

    var body: some Scene {
        WindowGroup {
            ContentView()
                .frame(minWidth: 1000, minHeight: 780)
                // `initial: true` applies the saved choice on launch as well as on change.
                .onChange(of: appearance, initial: true) { _, new in new.apply() }
        }
        .defaultSize(width: 1320, height: 900)
        .windowToolbarStyle(.unified)
    }
}
