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

// MARK: - Headless session intents (AI rebuild Wave 1, 2026-10-15)
//
// These run WITHOUT opening the app (iOS 26 `supportedModes = .background`;
// older systems keep the default) against the live store, through the same
// session doors Hey Morphe uses — so Siri gets the door's own honest line:
// "Logged 8 at 135" or "Nothing's in session yet". The store registers
// itself at launch; an intent that lands before that (never, in practice,
// since the app's init runs first) says so instead of guessing.

/// The live store, registered by `MorpheApp` at launch for the intents.
@MainActor
enum IntentStore {
    static weak var store: MorpheAppStore?
}

struct SiriLogSetIntent: AppIntent {
    static let title: LocalizedStringResource = "Log a Set"
    static let description = IntentDescription("Logs a set on the exercise that's active in your Morphe session, without opening the app.")
    @available(iOS 26.0, *)
    static var supportedModes: IntentModes { .background }

    @Parameter(title: "Reps", requestValueDialog: "How many reps?")
    var reps: Int

    @Parameter(title: "Weight", requestValueDialog: "What weight? Say zero for bodyweight.")
    var weight: Double?

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        guard let store = IntentStore.store else {
            return .result(dialog: IntentDialog("Open Morphe once, then try again."))
        }
        guard store.isWorkoutSessionActive else {
            return .result(dialog: IntentDialog("Nothing's in session yet — start a workout in Morphe first."))
        }
        let count = max(1, min(reps, 200))
        let phrase: String
        if let weight, weight > 0 {
            let number = weight.rounded() == weight ? String(Int(weight)) : String(format: "%.1f", weight)
            phrase = "\(count) at \(number)"
        } else {
            phrase = "\(count) reps"
        }
        let reply = store.sessionVoiceReply(for: phrase) ?? "Couldn't log that — say the reps and the weight."
        return .result(dialog: IntentDialog("\(MorpheAppStore.spokenForm(of: reply))"))
    }
}

struct SiriStartRestIntent: AppIntent {
    static let title: LocalizedStringResource = "Start Rest"
    static let description = IntentDescription("Starts the rest timer in your Morphe session.")
    @available(iOS 26.0, *)
    static var supportedModes: IntentModes { .background }

    @Parameter(title: "Seconds")
    var seconds: Int?

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        guard let store = IntentStore.store else {
            return .result(dialog: IntentDialog("Open Morphe once, then try again."))
        }
        guard store.isWorkoutSessionActive else {
            return .result(dialog: IntentDialog("Nothing's in session yet — start a workout in Morphe first."))
        }
        let phrase = (seconds ?? 0) > 0 ? "rest for \(min(seconds ?? 0, 600)) seconds" : "start rest"
        let reply = store.sessionVoiceReply(for: phrase) ?? "Couldn't start the rest."
        return .result(dialog: IntentDialog("\(MorpheAppStore.spokenForm(of: reply))"))
    }
}

struct SiriNextExerciseIntent: AppIntent {
    static let title: LocalizedStringResource = "Next Exercise"
    static let description = IntentDescription("Moves your Morphe session to the next exercise.")
    @available(iOS 26.0, *)
    static var supportedModes: IntentModes { .background }

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        guard let store = IntentStore.store else {
            return .result(dialog: IntentDialog("Open Morphe once, then try again."))
        }
        guard store.isWorkoutSessionActive else {
            return .result(dialog: IntentDialog("Nothing's in session yet — start a workout in Morphe first."))
        }
        let reply = store.sessionVoiceReply(for: "next exercise") ?? "Couldn't move on."
        return .result(dialog: IntentDialog("\(MorpheAppStore.spokenForm(of: reply))"))
    }
}

struct MorpheShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: SiriLogSetIntent(),
            phrases: [
                "Log a set in \(.applicationName)",
                "Log my set in \(.applicationName)"
            ],
            shortTitle: "Log a Set",
            systemImageName: "checkmark.circle"
        )
        AppShortcut(
            intent: SiriStartRestIntent(),
            phrases: [
                "Start rest in \(.applicationName)",
                "Start my rest timer in \(.applicationName)"
            ],
            shortTitle: "Start Rest",
            systemImageName: "timer"
        )
        AppShortcut(
            intent: SiriNextExerciseIntent(),
            phrases: [
                "Next exercise in \(.applicationName)"
            ],
            shortTitle: "Next Exercise",
            systemImageName: "arrow.right.circle"
        )
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
