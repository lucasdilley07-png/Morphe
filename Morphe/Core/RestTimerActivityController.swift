import Foundation
import ActivityKit

// Bridges the in-app rest timer to a lock-screen Live Activity, so the
// countdown stays visible (and accurate — it runs on wall clock) after the
// phone locks mid-rest.

@MainActor
enum RestTimerActivityController {
    private static var activity: Activity<RestTimerAttributes>?

    /// Starts (or restarts) the lock-screen countdown.
    static func start(exerciseName: String, secondsRemaining: Int) {
        guard secondsRemaining > 0,
              ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        endImmediately()
        let now = Date()
        let state = RestTimerAttributes.ContentState(
            startDate: now,
            endDate: now.addingTimeInterval(TimeInterval(secondsRemaining))
        )
        // The shared anchor is what the lock-screen intents retarget and
        // the in-app bar reconciles against on foreground.
        RestTimerSharedState.write(endDate: state.endDate)
        activity = try? Activity.request(
            attributes: RestTimerAttributes(exerciseName: exerciseName),
            content: ActivityContent(state: state, staleDate: state.endDate)
        )
    }

    /// The user changed the rest length mid-countdown.
    static func update(secondsRemaining: Int) {
        guard let activity else { return }
        let now = Date()
        let state = RestTimerAttributes.ContentState(
            startDate: now,
            endDate: now.addingTimeInterval(TimeInterval(max(secondsRemaining, 0)))
        )
        RestTimerSharedState.write(endDate: state.endDate)
        Task {
            await activity.update(ActivityContent(state: state, staleDate: state.endDate))
        }
    }

    /// Rest finished, was paused, or the workout surface went away.
    static func end() {
        endImmediately()
    }

    private static func endImmediately() {
        // Clear the anchor even with no live activity — a stale end date
        // must never resurrect a rest on the next foreground.
        RestTimerSharedState.write(endDate: nil)
        guard let current = activity else { return }
        activity = nil
        Task {
            await current.end(nil, dismissalPolicy: .immediate)
        }
    }
}
