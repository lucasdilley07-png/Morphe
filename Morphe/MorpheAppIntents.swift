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

/// Tier 3 (Siri-level wave 2026-09-23): press the ACTION BUTTON (or say
/// "Talk to Morphe" to Siri) and the app opens with the mic already hot
/// — the same direct-capture machinery the lock-screen Live Activity
/// uses: no wake phrase, chime, ring, ready.
struct TalkToMorpheIntent: AppIntent {
    static let title: LocalizedStringResource = "Talk to Morphe"
    static let description = IntentDescription("Opens Morphe listening — ask or command by voice, no wake word needed.")
    static let openAppWhenRun = true

    @MainActor
    func perform() async throws -> some IntentResult {
        UserDefaults.standard.set(true, forKey: "morphe.intent.talkToMorphe")
        NotificationCenter.default.post(name: .morpheIntentArrived, object: nil)
        return .result()
    }
}

/// "Hey Siri, ask Morphe" → Siri collects the question, Morphe opens
/// with the answer already streaming in chat.
struct AskMorpheIntent: AppIntent {
    static let title: LocalizedStringResource = "Ask Morphe"
    static let description = IntentDescription("Sends a question to Morphe's AI and opens the answer.")
    static let openAppWhenRun = true

    @Parameter(title: "Question", requestValueDialog: "What should I ask Morphe?")
    var question: String

    @MainActor
    func perform() async throws -> some IntentResult {
        let trimmed = question.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            UserDefaults.standard.set(trimmed, forKey: "morphe.intent.askQuestion")
            NotificationCenter.default.post(name: .morpheIntentArrived, object: nil)
        }
        return .result()
    }
}

/// One-tap door to the numbers.
struct OpenProgressIntent: AppIntent {
    static let title: LocalizedStringResource = "Show My Progress"
    static let description = IntentDescription("Opens Morphe to your progress and scores.")
    static let openAppWhenRun = true

    @MainActor
    func perform() async throws -> some IntentResult {
        UserDefaults.standard.set(true, forKey: "morphe.intent.openProgress")
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
        AppShortcut(
            intent: TalkToMorpheIntent(),
            phrases: [
                "Talk to \(.applicationName)",
                "\(.applicationName) listen",
                "Open the \(.applicationName) mic"
            ],
            shortTitle: "Talk to Morphe",
            systemImageName: "waveform.circle.fill"
        )
        AppShortcut(
            intent: AskMorpheIntent(),
            phrases: [
                "Ask \(.applicationName)",
                "Ask \(.applicationName) a question"
            ],
            shortTitle: "Ask Morphe",
            systemImageName: "bubble.left.and.text.bubble.right.fill"
        )
        AppShortcut(
            intent: OpenProgressIntent(),
            phrases: [
                "Show my progress in \(.applicationName)",
                "\(.applicationName) progress"
            ],
            shortTitle: "My Progress",
            systemImageName: "chart.line.uptrend.xyaxis"
        )
    }
}
