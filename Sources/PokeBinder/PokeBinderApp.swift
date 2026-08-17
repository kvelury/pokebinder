import SwiftUI

@main
struct PokeBinderApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .frame(minWidth: 1000, minHeight: 780)
        }
        .defaultSize(width: 1320, height: 900)
        .windowToolbarStyle(.unified)
    }
}
