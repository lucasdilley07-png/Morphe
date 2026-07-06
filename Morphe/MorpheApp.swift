import SwiftUI

@main
struct MorpheApp: App {
    @State private var store = MorpheAppStore()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(store)
                .preferredColorScheme(store.selectedAppearance)
                .onChange(of: scenePhase) { _, phase in
                    // A calendar day can pass while the app sits suspended in
                    // the switcher — every return to the foreground re-checks
                    // whether "today" is still today.
                    if phase == .active {
                        store.handleDayRolloverIfNeeded()
                    }
                }
        }
    }
}
