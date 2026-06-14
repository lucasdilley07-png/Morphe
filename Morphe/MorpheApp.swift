import SwiftUI

@main
struct MorpheApp: App {
    @State private var store = MorpheAppStore()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(store)
                .preferredColorScheme(store.selectedAppearance)
        }
    }
}
