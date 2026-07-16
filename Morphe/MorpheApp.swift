import SwiftUI
import FirebaseCore

@main
struct MorpheApp: App {
    @State private var store: MorpheAppStore
    @Environment(\.scenePhase) private var scenePhase

    init() {
        // Firebase must be configured before anything touches Auth/Firestore —
        // assigning the store explicitly here (instead of a property default)
        // guarantees configure() runs first.
        FirebaseApp.configure()
        _store = State(initialValue: MorpheAppStore(
            authService: FirebaseAuthService(),
            cloudBackup: FirebaseCloudBackup(),
            partyService: FirebasePartyService(),
            managedClientService: FirebaseManagedClientService(),
            usernameDirectory: FirebaseUsernameDirectory()
        ))
    }

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
