import SwiftUI

// The wrist logger (market audit 2026-08: the one hard-feature gap worth
// closing pre-scale). Deliberately minimal: see the exercise, log the set
// in one tap, rest with a countdown — every write goes through the phone
// store's own doors via WatchConnectivity, so the watch can never disagree
// with the app about what happened.

@main
struct MorpheWatchApp: App {
    @StateObject private var model = WatchSessionModel()

    var body: some Scene {
        WindowGroup {
            WatchRootView()
                .environmentObject(model)
        }
    }
}
