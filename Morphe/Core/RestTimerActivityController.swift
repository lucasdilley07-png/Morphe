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
        Task {
            await activity.update(ActivityContent(state: state, staleDate: state.endDate))
        }
    }

    /// Rest finished, was paused, or the workout surface went away.
    static func end() {
        endImmediately()
    }

    private static func endImmediately() {
        guard let current = activity else { return }
        activity = nil
        Task {
            await current.end(nil, dismissalPolicy: .immediate)
        }
    }
}
