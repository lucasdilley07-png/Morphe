import Foundation
import ActivityKit

// The app-side driver for the lock-screen session card (Lucas
// 2026-08-30). One activity per live session: started/updated/ended by
// sync(from:) — hooked at the same choke point that feeds the watch —
// and rest transitions mutate the countdown in place.

@MainActor
enum WorkoutSessionActivityController {
    private static var activity: Activity<WorkoutSessionAttributes>?
    /// The last rest window pushed to the card — survives sync() updates
    /// so a set logged mid-rest doesn't erase the countdown.
    private static var restEndDate: Date?

    /// Mirrors the live session onto the lock screen. Idempotent: called
    /// on every session mutation (same cadence as the watch snapshot).
    static func sync(from store: MorpheAppStore) {
        guard store.isWorkoutSessionActive else {
            end()
            return
        }
        guard let exercise = store.activeWorkoutExercise else { return }
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }

        // A rest that ran out on wall clock is over, shown or not.
        if let rest = restEndDate, rest <= Date() { restEndDate = nil }

        let state = WorkoutSessionAttributes.ContentState(
            exerciseName: exercise.name,
            setsDone: store.completedWorkoutSets[exercise.id, default: 0],
            setsTarget: MorpheAppStore.watchSetCount(exercise.sets),
            suggestedReps: MorpheAppStore.watchRepCount(exercise.reps),
            suggestedWeight: store.lastSessionWeight(for: exercise.id)
                ?? store.suggestedWorkingWeight(for: exercise)
                ?? 0,
            unit: store.weightUnit == .kilograms ? "kg" : "lb",
            restEndDate: restEndDate,
            workoutComplete: store.isTrackedWorkoutComplete
        )
        let content = ActivityContent(state: state, staleDate: restEndDate)

        // Adopt a survivor from a previous process before starting anew.
        if activity == nil {
            activity = Activity<WorkoutSessionAttributes>.activities.first
        }
        if let activity {
            Task { await activity.update(content) }
        } else {
            activity = try? Activity.request(
                attributes: WorkoutSessionAttributes(workoutName: store.currentWorkout.name),
                content: content
            )
        }
    }

    // MARK: Rest transitions (from the in-app bar and the lock buttons)

    static func restStarted(store: MorpheAppStore, endDate: Date) {
        restEndDate = endDate
        RestTimerSharedState.write(endDate: endDate)
        sync(from: store)
    }

    static func restUpdated(store: MorpheAppStore, endDate: Date) {
        restStarted(store: store, endDate: endDate)
    }

    static func restEnded(store: MorpheAppStore) {
        restEndDate = nil
        RestTimerSharedState.write(endDate: nil)
        sync(from: store)
    }

    static func end() {
        restEndDate = nil
        RestTimerSharedState.write(endDate: nil)
        let current = activity ?? Activity<WorkoutSessionAttributes>.activities.first
        activity = nil
        guard let current else { return }
        Task { await current.end(nil, dismissalPolicy: .immediate) }
    }
}
