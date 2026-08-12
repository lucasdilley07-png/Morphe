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
            usernameDirectory: FirebaseUsernameDirectory(),
            verificationService: FirebaseVerificationService(),
            appointmentService: FirebaseAppointmentService()
        ))
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                // Theme tokens are statics — SwiftUI won't re-run leaf
                // bodies just because a static changed. New identity on the
                // appearance flip rebuilds the whole tree, so every view
                // re-reads the light/dark tokens. One-time cost per flip.
                .id("\(store.appearanceIsLight)-\(store.profileShowcase.accentPalette.rawValue)-\(store.profileShowcase.customAccentHex)")
                .environment(store)
                .preferredColorScheme(store.selectedAppearance)
                .onChange(of: scenePhase) { _, phase in
                    // A calendar day can pass while the app sits suspended in
                    // the switcher — every return to the foreground re-checks
                    // whether "today" is still today.
                    if phase == .active {
                        store.handleDayRolloverIfNeeded()
                    }
                    // The log backup debounce is 60s — leaving the app
                    // flushes whatever is pending so a swipe-kill can't
                    // strand the last set locally.
                    if phase == .background {
                        store.requestImmediateLogBackup()
                    }
                }
        }
    }
}
