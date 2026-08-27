import Foundation
import WatchConnectivity

// MARK: - Watch bridge (market audit 2026-08)
//
// The audit's one pre-scale build: a minimal wrist logger. This is the
// phone side. Snapshots flow OUT on every session mutation (via
// updateApplicationContext, so the watch always has the latest state even
// after being off-wrist); commands flow IN and run the SAME store doors
// the phone UI and voice layer use — the watch is another honest client,
// never a second source of truth.

final class WatchBridge: NSObject, WCSessionDelegate {
    static let shared = WatchBridge()

    private weak var store: MorpheAppStore?
    /// Monotonic sequence so the watch can discard out-of-order snapshots.
    private var sequence = 0

    func activate(store: MorpheAppStore) {
        guard WCSession.isSupported() else { return }
        self.store = store
        let session = WCSession.default
        session.delegate = self
        session.activate()
    }

    /// Called by the store (main actor) after session mutations.
    func publish() {
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        guard session.activationState == .activated else { return }
        guard let store else { return }
        sequence += 1
        var snapshot = MainActor.assumeIsolated { store.watchSnapshot() }
        snapshot["seq"] = sequence
        // applicationContext keeps only the latest — exactly right for
        // state that supersedes itself.
        try? session.updateApplicationContext(snapshot)
    }

    // MARK: WCSessionDelegate

    func session(_ session: WCSession,
                 activationDidCompleteWith activationState: WCSessionActivationState,
                 error: Error?) {
        DispatchQueue.main.async { self.publish() }
    }

    func sessionDidBecomeInactive(_ session: WCSession) {}

    func sessionDidDeactivate(_ session: WCSession) {
        // Watch switched — reactivate for the new one.
        session.activate()
    }

    func session(_ session: WCSession,
                 didReceiveMessage message: [String: Any],
                 replyHandler: @escaping ([String: Any]) -> Void) {
        DispatchQueue.main.async { [weak self] in
            guard let self, let store = self.store else {
                replyHandler(["error": "store unavailable"])
                return
            }
            var reply = MainActor.assumeIsolated { store.handleWatchCommand(message) }
            self.sequence += 1
            reply["seq"] = self.sequence
            replyHandler(reply)
        }
    }
}

// MARK: - Store surface for the watch

extension MorpheAppStore {

    /// Everything the wrist needs, plist-safe types only.
    func watchSnapshot() -> [String: Any] {
        var snapshot: [String: Any] = [
            "sessionActive": isWorkoutSessionActive,
            "workoutName": currentWorkout.name,
            "unit": weightUnit == .kilograms ? "kg" : "lb",
            "workoutComplete": isTrackedWorkoutComplete
        ]
        if let exercise = activeWorkoutExercise {
            let setsTarget = Self.watchSetCount(exercise.sets)
            snapshot["exerciseName"] = exercise.name
            snapshot["exerciseIndex"] = activeWorkoutExerciseIndex
            snapshot["totalExercises"] = currentWorkout.exercises.count
            snapshot["setsDone"] = completedWorkoutSets[exercise.id, default: 0]
            snapshot["setsTarget"] = setsTarget
            snapshot["suggestedReps"] = Self.watchRepCount(exercise.reps)
            snapshot["weight"] = lastSessionWeight(for: exercise.id)
                ?? suggestedWorkingWeight(for: exercise)
                ?? 0
            snapshot["restSeconds"] = exercise.restSeconds ?? 180
            snapshot["canPrev"] = activeWorkoutExerciseIndex > 0
            if let last = lastSessionLine(forExerciseNamed: exercise.name) {
                snapshot["lastLine"] = last
            }
        }
        return snapshot
    }

    /// Commands run the same doors as the phone UI — same guards, same
    /// honesty rules (a complete exercise refuses extra sets, exactly like
    /// a stray tap on the phone).
    func handleWatchCommand(_ message: [String: Any]) -> [String: Any] {
        switch message["cmd"] as? String {
        case "logSet":
            let reps = message["reps"] as? Int ?? 0
            let weight = message["weight"] as? Double ?? 0
            var reply = [String: Any]()
            if reps >= 1, reps <= 50, weight >= 0, weight <= 995 {
                let exercise = activeWorkoutExercise
                if completeTrackedSet(reps: reps, weight: weight) {
                    reply["logged"] = true
                    if let exercise { _ = hopToSupersetPartnerIfNeeded(after: exercise) }
                } else {
                    reply["logged"] = false
                }
            } else {
                reply["logged"] = false
            }
            reply.merge(watchSnapshot()) { a, _ in a }
            return reply
        case "next":
            goToNextTrackedExercise()
            return watchSnapshot()
        case "prev":
            goToPreviousTrackedExercise()
            return watchSnapshot()
        case "start":
            if !isWorkoutSessionActive { startTodayWorkout() }
            return watchSnapshot()
        default:
            return watchSnapshot()
        }
    }

    /// Mirrors the phone parsers: first integer anywhere in the string.
    /// Internal: the session voice layer shares them (Lucas 2026-08-27).
    static func watchSetCount(_ sets: String) -> Int {
        Int(sets.components(separatedBy: CharacterSet.decimalDigits.inverted)
            .first { !$0.isEmpty } ?? "") ?? 1
    }

    static func watchRepCount(_ reps: String) -> Int {
        Int(reps.components(separatedBy: CharacterSet.decimalDigits.inverted)
            .first { !$0.isEmpty } ?? "10") ?? 10
    }
}
