import Foundation
import ActivityKit
import AppIntents

// Shared between the app and the MorpheWidgets extension (Lucas
// 2026-08-30): the whole SESSION lives on the lock screen now, not just
// the rest countdown. One card: exercise + set progress always, with
// Log Set / Rest / mic buttons while working and the countdown while
// resting. The lock-screen intents run in the APP's process (that's how
// LiveActivityIntent works), so they act through the bridge below — the
// extension compiles this file but never executes the closures.

struct WorkoutSessionAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var exerciseName: String
        var setsDone: Int
        var setsTarget: Int
        /// The one-tap set the Log button commits — same suggestion the
        /// watch logs (last session's weight, else the progression pick).
        var suggestedReps: Int
        var suggestedWeight: Double
        var unit: String
        /// Non-nil while resting: the wall-clock countdown window the
        /// lock screen renders with Text(timerInterval:) — it keeps
        /// ticking with the app suspended.
        var restEndDate: Date?
        var workoutComplete: Bool
    }

    var workoutName: String
}

/// The ONE wall-clock truth the lock-screen intents and the in-app bar
/// reconcile against, living in the App Group so both processes see it.
enum RestTimerSharedState {
    static let suite = "group.com.morpheapp.Morphe"
    private static let endDateKey = "morphe.rest.endDate"

    static func write(endDate: Date?) {
        let defaults = UserDefaults(suiteName: suite)
        if let endDate {
            defaults?.set(endDate.timeIntervalSince1970, forKey: endDateKey)
        } else {
            defaults?.removeObject(forKey: endDateKey)
        }
    }

    static func readEndDate() -> Date? {
        guard let raw = UserDefaults(suiteName: suite)?.object(forKey: endDateKey) as? Double else { return nil }
        return Date(timeIntervalSince1970: raw)
    }
}

/// App-installed handlers for the lock-screen buttons. LiveActivityIntent
/// performs in the app process — the store installs these at init, so the
/// buttons work even from a cold background launch (the app's init runs
/// before any intent performs).
@MainActor
enum MorpheSessionIntentBridge {
    static var logSet: (() -> Void)?
    static var startRest: (() -> Void)?
    static var addRestTime: (() -> Void)?
    static var skipRest: (() -> Void)?
    static var armVoice: (() -> Void)?
}

/// Lock-screen "Log set" — commits the suggested set through the same
/// store door the phone UI and the watch use.
struct LogSetIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "Log Set"

    func perform() async throws -> some IntentResult {
        await MainActor.run { MorpheSessionIntentBridge.logSet?() }
        return .result()
    }
}

/// Lock-screen "Rest" — starts the exercise's rest countdown.
struct StartRestIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "Start Rest"

    func perform() async throws -> some IntentResult {
        await MainActor.run { MorpheSessionIntentBridge.startRest?() }
        return .result()
    }
}

/// Lock-screen "+15s" mid-rest.
struct AddRestTimeIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "Add Rest Time"

    func perform() async throws -> some IntentResult {
        await MainActor.run { MorpheSessionIntentBridge.addRestTime?() }
        return .result()
    }
}

/// Lock-screen "Skip" — ends the rest everywhere.
struct SkipRestIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "Skip Rest"

    func perform() async throws -> some IntentResult {
        await MainActor.run { MorpheSessionIntentBridge.skipRest?() }
        return .result()
    }
}

/// Lock-screen mic — iOS forbids third-party wake words on the lock
/// screen, so this is the honest equivalent: open Morphe straight into
/// active voice capture, no wake phrase needed.
struct SessionMicIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "Talk to Morphe"
    static let openAppWhenRun = true

    func perform() async throws -> some IntentResult {
        await MainActor.run { MorpheSessionIntentBridge.armVoice?() }
        return .result()
    }
}
