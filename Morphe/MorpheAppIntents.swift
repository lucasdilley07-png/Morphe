import AppIntents
import Foundation

// MARK: - App Intents (rebuild wave, Lucas 2026-08-27)
//
// The outside-the-app voice path. Apple requires the app name in every
// Siri phrase — "Start my workout in Morphe" — which is exactly why the
// in-app wake word exists for everything else. The intent only sets a
// flag: the store consumes it on foreground (cold launch included), so
// the same guarded door as every other entry point runs the session.

struct StartWorkoutIntent: AppIntent {
    static let title: LocalizedStringResource = "Start Workout"
    static let description = IntentDescription("Opens Morphe and starts today's workout.")
    static let openAppWhenRun = true

    @MainActor
    func perform() async throws -> some IntentResult {
        UserDefaults.standard.set(true, forKey: "morphe.intent.startWorkout")
        NotificationCenter.default.post(name: .morpheIntentArrived, object: nil)
        return .result()
    }
}

extension Notification.Name {
    /// Fired when an App Intent lands while the app is already running —
    /// the scene-phase hook only covers background → foreground.
    static let morpheIntentArrived = Notification.Name("morphe.intent.arrived")
}

struct MorpheShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: StartWorkoutIntent(),
            phrases: [
                "Start my workout in \(.applicationName)",
                "Start training in \(.applicationName)",
                "Train in \(.applicationName)"
            ],
            shortTitle: "Start Workout",
            systemImageName: "figure.strengthtraining.traditional"
        )
    }
}
