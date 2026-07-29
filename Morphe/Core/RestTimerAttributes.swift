import Foundation
import ActivityKit
import AppIntents

// Shared between the app and the MorpheWidgets extension: the rest-timer
// Live Activity's identity, countdown window, shared wall-clock anchor,
// and the lock-screen intents.

struct RestTimerAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        /// Wall-clock countdown window. The lock screen renders
        /// Text(timerInterval:) from this range, so the countdown keeps
        /// ticking even while the app is suspended.
        var startDate: Date
        var endDate: Date
    }

    /// What the rest is for — the exercise the user is resting from.
    var exerciseName: String
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

/// Lock-screen "+15s" — LiveActivityIntent runs in the APP's process, so
/// it can retarget the activity directly. The in-app bar picks the new
/// end up from the shared anchor on foreground.
struct AddRestTimeIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "Add Rest Time"

    func perform() async throws -> some IntentResult {
        let base = RestTimerSharedState.readEndDate() ?? Date()
        let newEnd = max(base, Date()).addingTimeInterval(15)
        RestTimerSharedState.write(endDate: newEnd)
        for activity in Activity<RestTimerAttributes>.activities {
            let state = RestTimerAttributes.ContentState(startDate: Date(), endDate: newEnd)
            await activity.update(ActivityContent(state: state, staleDate: newEnd))
        }
        return .result()
    }
}

/// Lock-screen "Skip" — ends the rest everywhere: activity gone, shared
/// anchor cleared, and the in-app bar stops on foreground.
struct SkipRestIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "Skip Rest"

    func perform() async throws -> some IntentResult {
        RestTimerSharedState.write(endDate: nil)
        for activity in Activity<RestTimerAttributes>.activities {
            await activity.end(nil, dismissalPolicy: .immediate)
        }
        return .result()
    }
}
