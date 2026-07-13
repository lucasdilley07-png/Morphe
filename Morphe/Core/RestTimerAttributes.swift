import Foundation
import ActivityKit

// Shared between the app and the MorpheWidgets extension: the rest-timer
// Live Activity's identity and countdown window.

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
