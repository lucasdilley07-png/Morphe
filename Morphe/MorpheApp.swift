import SwiftUI

@main
struct MorpheApp: App {
    @StateObject private var store = MorpheAppStore()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(store)
                .preferredColorScheme(store.selectedAppearance)
        }
    }
}
