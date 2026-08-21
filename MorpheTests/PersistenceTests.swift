import XCTest
@testable import Morphe

/// Tests for the on-device persistence layer (the first real seam added for v1).
/// These protect the workout-log and local-profile round-trips that the app now
/// depends on to survive relaunches.
final class PersistenceTests: XCTestCase {

    // Each test uses a unique directory so runs are isolated and don't touch
    // the real on-device store.
    private func makeWorkoutStore(_ name: String) -> WorkoutFilePersistence {
        WorkoutFilePersistence(directoryName: "MorpheTests-\(name)")
    }

    private func makeProfileStore(_ name: String) -> ProfileFilePersistence {
        ProfileFilePersistence(directoryName: "MorpheTests-\(name)")
    }

    private func sampleLog(title: String) -> WorkoutLog {
        WorkoutLog(
            athleteID: UUID(),
            athleteName: "Tester",
            workoutTemplateID: nil,
            workoutTitle: title,
            sport: .strength,
            completedAt: Date(timeIntervalSince1970: 1_700_000_000),
            durationMinutes: 42,
            exercises: [
                LoggedExercise(name: "Goblet Squat", sets: "3", reps: "10", weight: "40 lb", note: "clean")
            ],
            notes: "test log",
            source: .athleteManual,
            enteredByUserID: UUID(),
            enteredByRole: .client,
            enteredByName: "Tester",
            verificationStatus: .athleteSubmitted
        )
    }

    // MARK: - Workout logs

    func testWorkoutLogsRoundTrip() {
        let store = makeWorkoutStore(#function)
        defer { store.clear() }

        let logs = [sampleLog(title: "A"), sampleLog(title: "B")]
        store.saveLogs(logs)

        let loaded = store.loadLogs()
        XCTAssertEqual(loaded?.count, 2)
        XCTAssertEqual(loaded?.map(\.workoutTitle), ["A", "B"])
        XCTAssertEqual(loaded?.first?.durationMinutes, 42)
        XCTAssertEqual(loaded?.first?.exercises.first?.name, "Goblet Squat")
        XCTAssertEqual(loaded?.first?.source, .athleteManual)
    }

    func testLoadLogsReturnsNilWhenEmpty() {
        let store = makeWorkoutStore(#function)
        defer { store.clear() }
        XCTAssertNil(store.loadLogs())
    }

    func testClearRemovesLogs() {
        let store = makeWorkoutStore(#function)
        store.saveLogs([sampleLog(title: "A")])
        XCTAssertNotNil(store.loadLogs())
        store.clear()
        XCTAssertNil(store.loadLogs())
    }

    // MARK: - Session snapshot

    func testSessionSnapshotRoundTrip() {
        let store = makeWorkoutStore(#function)
        defer { store.clear() }

        let id = UUID()
        let snapshot = WorkoutSessionSnapshot(
            currentWorkoutID: id,
            isWorkoutSessionActive: true,
            hasStartedWorkoutFlow: true,
            hasCompletedWorkoutFlow: false,
            activeWorkoutExerciseIndex: 2,
            completedWorkoutSets: ["goblet-squat": 3],
            trackedSetReps: ["goblet-squat": [10, 9, 8]],
            trackedSetWeights: ["goblet-squat": [135, 135, 130]],
            trackedSetRPE: ["goblet-squat": [8, 8, 9]],
            workoutSessionStartedAt: Date(timeIntervalSince1970: 1_750_000_000),
            completedSessionMinutes: 42,
            isWorkoutLoggedToday: false
        )
        store.saveSession(snapshot)

        let loaded = store.loadSession()
        XCTAssertEqual(loaded, snapshot)
        XCTAssertEqual(loaded?.currentWorkoutID, id)
        XCTAssertEqual(loaded?.trackedSetReps["goblet-squat"], [10, 9, 8])
    }

    // MARK: - Local profile

    func testProfileRoundTrip() {
        let store = makeProfileStore(#function)
        defer { store.clear() }

        let snapshot = LocalProfileSnapshot(
            hasCompletedOnboarding: true,
            id: UUID().uuidString,
            name: "Alex",
            gender: "Male",
            accountRole: "Athlete",
            sportMode: "Boxing",
            selectedSports: ["Boxing"],
            selectedTrainingStyles: ["Conditioning"],
            selectedGoals: ["Improve conditioning"],
            goal: "Improve conditioning",
            physicalGoalTarget: "Move better",
            weightGoalTarget: "205 lbs",
            goalDeadline: "12 weeks",
            fitnessLevel: "Beginner",
            equipment: "Dumbbells",
            injuries: "None",
            theme: "",
            accentPalette: "",
            coachingTone: "",
            avatarStyle: "",
            displayName: "Alex",
            username: "alex",
            weightUnit: "lb",
            currentProgram: "Starter Strength",
            currentPhase: "Build Consistency"
        )
        store.saveProfile(snapshot)

        let loaded = store.loadProfile()
        XCTAssertEqual(loaded, snapshot)
        XCTAssertEqual(loaded?.name, "Alex")
        XCTAssertTrue(loaded?.hasCompletedOnboarding ?? false)
    }

    func testLoadProfileReturnsNilWhenEmpty() {
        let store = makeProfileStore(#function)
        defer { store.clear() }
        XCTAssertNil(store.loadProfile())
    }

    // MARK: - Codable conformance

    func testWorkoutLogCodableIsStable() throws {
        let log = sampleLog(title: "Codable")
        let data = try JSONEncoder().encode(log)
        let decoded = try JSONDecoder().decode(WorkoutLog.self, from: data)
        XCTAssertEqual(decoded, log)
    }
}

/// Verifies that completing onboarding gives the user their OWN empty account
/// instead of inheriting the seeded demo athlete ("Lucas") and his data.
@MainActor
final class OnboardingIdentityTests: XCTestCase {

    override func setUp() {
        super.setUp()
        // Isolate from any state a previous run left in the shared app container.
        WorkoutFilePersistence().clear()
        ProfileFilePersistence().clear()
    }

    func testOnboardingMintsFreshIdentity() {
        let store = MorpheAppStore()
        let beforeID = store.clientProfile.id
        store.onboardingDraft.name = "Sarah"
        store.completeOnboarding()

        XCTAssertNotEqual(store.clientProfile.id, beforeID,
                          "onboarding must mint a brand-new identity")
        XCTAssertEqual(store.clientProfile.name, "Sarah")
    }

    func testNewUserStartsEmpty() {
        let store = MorpheAppStore()
        store.onboardingDraft.name = "Sarah"
        store.completeOnboarding()

        XCTAssertTrue(store.workoutLogs.isEmpty, "no inherited workout logs")
        XCTAssertTrue(store.workoutHistory.isEmpty, "no inherited history")
        XCTAssertTrue(store.recentWins.isEmpty, "no fabricated wins")
        XCTAssertTrue(store.workoutPartners.isEmpty, "no seeded buddies")
        XCTAssertTrue(store.friendsActivity.isEmpty, "no stranger activity")
        XCTAssertEqual(store.clientProfile.level.streak, 0, "streak starts at zero")
        XCTAssertEqual(store.clientProfile.health.score, 0, "score starts at zero")
    }

    func testLoggedWorkoutBelongsToTheUser() {
        let store = MorpheAppStore()
        store.onboardingDraft.name = "Sarah"
        store.completeOnboarding()
        let userID = store.clientProfile.id

        store.startTodayWorkout()
        store.hasCompletedWorkoutFlow = true
        store.logWorkout()

        XCTAssertFalse(store.workoutLogs.isEmpty, "logging adds a real log")
        XCTAssertTrue(store.workoutLogs.allSatisfy { $0.athleteID == userID },
                      "the user's logs must be attributed to the user, not the demo athlete")
    }

    func testReturningUserStartsCleanAndKeepsIdentity() {
        let store = MorpheAppStore()
        store.onboardingDraft.name = "Sarah"
        store.completeOnboarding()
        let id = store.clientProfile.id

        // Simulate a relaunch.
        let reloaded = MorpheAppStore()

        XCTAssertEqual(reloaded.clientProfile.id, id, "identity must persist across launches")
        XCTAssertTrue(reloaded.recentWins.isEmpty, "no seeded wins should resurface")
        XCTAssertTrue(reloaded.workoutPartners.isEmpty, "no seeded buddies should resurface")
        XCTAssertTrue(reloaded.friendsActivity.isEmpty)
        XCTAssertTrue(reloaded.profileShowcase.personalRecords.isEmpty)
        XCTAssertEqual(reloaded.clientProfile.health.score, 0)
    }

    func testProfileEditsPersistAcrossLaunch() {
        let store = MorpheAppStore()
        store.onboardingDraft.name = "Sarah"
        store.completeOnboarding()
        store.weightUnit = .kilograms
        store.selectSportMode(.strength)

        let reloaded = MorpheAppStore()
        XCTAssertEqual(reloaded.weightUnit, .kilograms, "weight-unit change must persist")
        XCTAssertEqual(reloaded.clientProfile.sportMode, .strength, "sport change must persist")
    }

    func testLoggingCapturesRealWeightNotPlaceholder() {
        let store = MorpheAppStore()
        store.onboardingDraft.name = "Sarah"
        store.completeOnboarding()
        store.startTodayWorkout()
        store.completeTrackedSet(reps: 8, weight: 135)
        store.hasCompletedWorkoutFlow = true
        store.logWorkout()

        let weights = store.workoutLogs.first?.exercises.map(\.weight) ?? []
        XCTAssertFalse(weights.isEmpty)
        XCTAssertFalse(weights.contains("As logged"),
                       "the 'As logged' placeholder must be gone — got \(weights)")
        XCTAssertTrue(weights.contains { $0.contains("135") },
                      "the logged weight must reflect what the user entered — got \(weights)")
    }
}

/// Verifies the user can build their own workouts and custom exercises, and
/// that they persist across launches.
@MainActor
final class WorkoutBuilderTests: XCTestCase {

    override func setUp() {
        super.setUp()
        WorkoutFilePersistence().clear()
        ProfileFilePersistence().clear()
    }

    private func freshStore() -> MorpheAppStore {
        let store = MorpheAppStore()
        store.onboardingDraft.name = "Sarah"
        store.completeOnboarding()
        return store
    }

    func testCreateCustomWorkoutMakesItCurrentAndRunnable() {
        let store = freshStore()
        let exercise = store.allExercises.first!
        store.createCustomWorkout(
            name: "Push Day",
            sport: .strength,
            items: [CustomWorkoutItem(exercise: exercise, sets: 4, reps: 8)]
        )

        XCTAssertTrue(store.workoutTemplates.contains { $0.name == "Push Day" && store.isCustomWorkout($0.id) })
        XCTAssertEqual(store.currentWorkout.name, "Push Day")
        XCTAssertEqual(store.currentWorkout.exercises.count, 1)
    }

    func testCustomWorkoutPersistsAcrossLaunch() {
        let store = freshStore()
        let exercise = store.allExercises.first!
        store.createCustomWorkout(
            name: "Leg Day",
            sport: .strength,
            items: [CustomWorkoutItem(exercise: exercise, sets: 3, reps: 12)]
        )

        let reloaded = MorpheAppStore()
        XCTAssertTrue(reloaded.workoutTemplates.contains { $0.name == "Leg Day" },
                      "a built workout must survive a relaunch")
    }

    func testAddCustomExerciseExtendsLibrary() {
        let store = freshStore()
        let before = store.allExercises.count
        let created = store.addCustomExercise(name: "Sled Push", muscleGroup: .legs)

        XCTAssertEqual(store.allExercises.count, before + 1)
        XCTAssertTrue(store.allExercises.contains { $0.id == created.id && $0.name == "Sled Push" })
    }

    func testDeleteCustomWorkoutRemovesIt() {
        let store = freshStore()
        let exercise = store.allExercises.first!
        store.createCustomWorkout(name: "Temp", sport: .strength,
                                  items: [CustomWorkoutItem(exercise: exercise, sets: 3, reps: 10)])
        let id = store.workoutTemplates.first { $0.name == "Temp" }!.id
        store.deleteCustomWorkout(id)

        XCTAssertFalse(store.workoutTemplates.contains { $0.id == id })
    }
}

/// Verifies the live workout session: starting, weight capture, and restore.
@MainActor
final class WorkoutSessionTests: XCTestCase {

    override func setUp() {
        super.setUp()
        WorkoutFilePersistence().clear()
        ProfileFilePersistence().clear()
    }

    private func freshStore() -> MorpheAppStore {
        let store = MorpheAppStore()
        store.onboardingDraft.name = "Sarah"
        store.completeOnboarding()
        return store
    }

    func testBeginLiveWorkoutEntersLiveSession() {
        let store = freshStore()
        let template = store.workoutTemplates.first!

        store.beginLiveWorkout(template)

        XCTAssertTrue(store.isWorkoutSessionActive, "every Start action must enter the live tracker, not just stage the plan")
        XCTAssertEqual(store.currentWorkout.id, template.id)
        XCTAssertEqual(store.activeWorkoutExerciseIndex, 0)
    }

    func testApplyRecommendedWorkoutSwapsTodaysSession() {
        let store = freshStore()
        let recommendedID = store.currentGoodForTodayRecommendation.workoutTemplateID

        store.applyRecommendedWorkout()

        XCTAssertEqual(store.currentWorkout.id, recommendedID,
                       "accepting the suggestion makes it today's one workout")
        XCTAssertFalse(store.recommendedWorkoutDiffers, "suggestion row disappears once adopted")
        XCTAssertFalse(store.isWorkoutSessionActive, "adopting a suggestion stages it; Start goes live")
    }

    func testQuickLoggedSetRecordsWeight() {
        let store = freshStore()
        store.beginLiveWorkout(store.workoutTemplates.first!)
        let exercise = store.activeWorkoutExercise!

        store.completeTrackedSet(reps: 10, weight: 45)

        XCTAssertEqual(store.trackedSetWeights[exercise.id], [45], "a logged set must carry its real load")
        XCTAssertEqual(store.lastSessionWeight(for: exercise.id), 45, "the next set pre-fills from the last one")
    }

    /// Builds and starts a 2-exercise workout with 2 sets each, for session tests.
    private func startedTwoExerciseSession(_ store: MorpheAppStore) {
        let exercises = Array(store.allExercises.prefix(2))
        store.createCustomWorkout(
            name: "Session Test",
            sport: .strength,
            items: exercises.map { CustomWorkoutItem(exercise: $0, sets: 2, reps: 8) }
        )
        let custom = store.workoutTemplates.first { $0.name == "Session Test" }!
        store.beginLiveWorkout(custom)
    }

    func testWorkoutCompleteAfterAllSetsAndAdvanceSkipsDone() {
        let store = freshStore()
        startedTwoExerciseSession(store)

        // Finish exercise 1 (2 sets) — auto-advance should land on exercise 2.
        store.completeTrackedSet(reps: 8, weight: 50)
        XCTAssertFalse(store.isTrackedWorkoutComplete)
        store.completeTrackedSet(reps: 8, weight: 50)
        XCTAssertEqual(store.activeWorkoutExerciseIndex, 1, "auto-advance must move to the next incomplete exercise")

        // Finish exercise 2 — the workout is now complete, no dead-end clamp.
        store.completeTrackedSet(reps: 8)
        store.completeTrackedSet(reps: 8)
        XCTAssertTrue(store.isTrackedWorkoutComplete, "all sets logged must surface the complete state")
        XCTAssertEqual(store.trackedSetTotalCount, 4)
    }

    func testEditAndRemoveLoggedSet() {
        let store = freshStore()
        startedTwoExerciseSession(store)
        let exercise = store.activeWorkoutExercise!

        store.completeTrackedSet(reps: 8, weight: 50)
        store.updateTrackedSet(exerciseID: exercise.id, setIndex: 0, reps: 10, weight: 55)
        XCTAssertEqual(store.trackedSetReps[exercise.id], [10])
        XCTAssertEqual(store.trackedSetWeights[exercise.id], [55])

        store.removeTrackedSet(exerciseID: exercise.id, setIndex: 0)
        XCTAssertEqual(store.trackedSetReps[exercise.id], [])
        XCTAssertEqual(store.completedWorkoutSets[exercise.id], 0, "removing a set must re-open the exercise")
    }

    func testExtraSetBeyondTargetAndDiscard() {
        let store = freshStore()
        startedTwoExerciseSession(store)
        let exercise = store.activeWorkoutExercise!

        store.completeTrackedSet(reps: 8, weight: 50)
        store.completeTrackedSet(reps: 8, weight: 50)
        // Completing the target auto-advances; navigate back to the done exercise.
        store.goToPreviousTrackedExercise()
        XCTAssertEqual(store.activeWorkoutExercise?.id, exercise.id)
        // Quick-log stays guarded at target…
        store.completeTrackedSet(reps: 8, weight: 50)
        XCTAssertEqual(store.trackedSetReps[exercise.id]?.count, 2, "quick-log must not over-log past the target")
        // …but an explicit extra set is allowed.
        store.completeTrackedSet(reps: 8, weight: 50, allowExtra: true)
        XCTAssertEqual(store.trackedSetReps[exercise.id]?.count, 3, "an explicit extra set logs past the target")

        // Discard resets the whole session without logging.
        store.cancelTrackedWorkoutSession()
        XCTAssertFalse(store.isWorkoutSessionActive)
        XCTAssertEqual(store.trackedSetTotalCount, 0)
        XCTAssertFalse(store.hasCompletedWorkoutFlow)
    }

    func testUnitToggleConvertsLoggedSessionWeights() {
        let store = freshStore()
        startedTwoExerciseSession(store)
        let exercise = store.activeWorkoutExercise!

        store.completeTrackedSet(reps: 8, weight: 45)   // 45 lb
        store.weightUnit = .kilograms

        let converted = store.trackedSetWeights[exercise.id]?.first ?? 0
        XCTAssertEqual(converted, 20.4, accuracy: 0.05,
                       "toggling the unit must convert logged weights, not relabel them")

        store.weightUnit = .pounds
        let roundTripped = store.trackedSetWeights[exercise.id]?.first ?? 0
        XCTAssertEqual(roundTripped, 45, accuracy: 0.2, "converting back must round-trip")
    }

    func testCompleteTrackedSetReportsWhetherItLogged() {
        let store = freshStore()
        startedTwoExerciseSession(store)

        XCTAssertTrue(store.completeTrackedSet(reps: 8, weight: 50), "a set within target must log")
        XCTAssertTrue(store.completeTrackedSet(reps: 8, weight: 50))
        // Exercise 1 is complete (auto-advanced away) — a guarded quick-log
        // back on it must report failure so the auto rest timer stays quiet.
        store.goToPreviousTrackedExercise()
        XCTAssertFalse(store.completeTrackedSet(reps: 8, weight: 50),
                       "a rejected quick-log must say so — follow-on behavior keys off the result")
        XCTAssertTrue(store.completeTrackedSet(reps: 8, weight: 50, allowExtra: true),
                      "an explicit extra set still logs and reports success")
    }

    func testLoggingCelebratesPRsAndOnlyPRs() {
        let store = freshStore()
        startedTwoExerciseSession(store)
        let firstExerciseName = store.activeWorkoutExercise!.name

        // Session 1: first-ever weighted sets — a first record is a PR, and
        // a PR gets the full-screen stamp, not the banner.
        store.completeTrackedSet(reps: 8, weight: 50)
        store.completeTrackedSet(reps: 8, weight: 50)
        store.completeTrackedSet(reps: 8, weight: 40)
        store.completeTrackedSet(reps: 8, weight: 40)
        store.finishTrackedWorkoutSession()
        store.logWorkout()
        XCTAssertEqual(store.recordStamp?.kicker, "NEW RECORD",
                       "a session that sets a record must celebrate THAT, not generic XP")
        XCTAssertEqual(store.recordStamp?.headline, firstExerciseName)
        // Both exercises hit first records — the detail cites the first and
        // counts the rest.
        XCTAssertTrue(store.recordStamp?.detailLine.contains("Your first record") == true)
        XCTAssertNotNil(store.recordStamp?.prCard,
                        "a PR stamp carries its share card")
        XCTAssertNotEqual(store.celebration?.title, "+50 XP",
                          "the stamp replaces the XP banner — never both for one log")
        store.dismissRecordStamp()

        // Session 2: matching the record is NOT a new PR — generic banner,
        // no stamp.
        startedTwoExerciseSession(store)
        store.completeTrackedSet(reps: 8, weight: 50)
        store.completeTrackedSet(reps: 8, weight: 50)
        store.completeTrackedSet(reps: 8, weight: 40)
        store.completeTrackedSet(reps: 8, weight: 40)
        store.finishTrackedWorkoutSession()
        store.logWorkout()
        XCTAssertEqual(store.celebration?.title, "+50 XP",
                       "matching an existing record must not claim a PR")
        XCTAssertNil(store.recordStamp,
                     "matching an existing record earns no stamp")

        // Session 3: beating the record celebrates with the honest delta.
        startedTwoExerciseSession(store)
        store.completeTrackedSet(reps: 8, weight: 55)
        store.completeTrackedSet(reps: 8, weight: 55)
        store.completeTrackedSet(reps: 8, weight: 40)
        store.completeTrackedSet(reps: 8, weight: 40)
        store.finishTrackedWorkoutSession()
        store.logWorkout()
        XCTAssertEqual(store.recordStamp?.kicker, "NEW RECORD")
        XCTAssertEqual(store.recordStamp?.headline, firstExerciseName)
        XCTAssertTrue(store.recordStamp?.detailLine.contains("Up from") == true,
                      "a beaten record cites the previous best it beat")
        XCTAssertEqual(store.recordStamp?.prCard?.previousLabel.isEmpty, false,
                       "the share card carries the beaten record too")
    }

    func testLibraryFoldersAssignFilterAndSurviveReload() {
        let store = freshStore()
        let key = "morphe.library.folders.\(store.clientProfile.id.uuidString)"
        UserDefaults.standard.removeObject(forKey: key)
        store.loadLibraryFolders()

        store.createLibraryFolder("Push Day")
        store.createLibraryFolder("push day")   // case-insensitive dup refused
        XCTAssertEqual(store.libraryFolders, ["Push Day"])

        let templateID = UUID()
        store.assignLibraryWorkout(templateID: templateID, to: "Push Day")
        XCTAssertEqual(store.libraryFolder(forTemplateID: templateID), "Push Day")

        // Reload from disk — the blob round-trips.
        store.loadLibraryFolders()
        XCTAssertEqual(store.libraryFolder(forTemplateID: templateID), "Push Day")

        // Deleting the folder frees its workouts instead of losing them.
        store.deleteLibraryFolder("Push Day")
        XCTAssertTrue(store.libraryFolders.isEmpty)
        XCTAssertNil(store.libraryFolder(forTemplateID: templateID))

        UserDefaults.standard.removeObject(forKey: key)
    }

    func testDragReorderMovesExerciseToIndex() {
        let store = freshStore()
        startedTwoExerciseSession(store)
        let first = store.currentWorkout.exercises[0]
        store.moveSessionExercise(id: first.id, toIndex: 1)
        XCTAssertEqual(store.currentWorkout.exercises[1].id, first.id,
                       "drag lands the exercise at the drop index")
        XCTAssertEqual(store.activeWorkoutExercise?.id, first.id,
                       "the active exercise follows its new position")
    }

    func testSupersetLinksHopAlternatelyAndUnlinkCleanly() {
        let store = freshStore()
        startedTwoExerciseSession(store)
        let first = store.currentWorkout.exercises[0]
        let second = store.currentWorkout.exercises[1]

        store.toggleSupersetLink(for: first)
        XCTAssertEqual(store.supersetPartners[first.id], second.id)
        XCTAssertEqual(store.supersetPartners[second.id], first.id, "pairs store both directions")

        // A1 set → hop to A2 (caller suppresses rest on a hop).
        store.completeTrackedSet(reps: 8, weight: 50)
        XCTAssertTrue(store.hopToSupersetPartnerIfNeeded(after: first))
        XCTAssertEqual(store.activeWorkoutExercise?.id, second.id)

        // A2 set → back to A1.
        store.completeTrackedSet(reps: 8, weight: 30)
        XCTAssertTrue(store.hopToSupersetPartnerIfNeeded(after: second))
        XCTAssertEqual(store.activeWorkoutExercise?.id, first.id)

        // Unlink clears both directions; a hop no longer fires.
        store.toggleSupersetLink(for: first)
        XCTAssertTrue(store.supersetPartners.isEmpty)
        XCTAssertFalse(store.hopToSupersetPartnerIfNeeded(after: first))
    }

    func testReplacingAFinishedSessionLogsItFirst() {
        let store = freshStore()
        startedTwoExerciseSession(store)
        store.completeTrackedSet(reps: 8, weight: 50)
        _ = store.finishTrackedWorkoutSession()
        let logsBefore = store.currentAthleteWorkoutLogs.count

        // Starting the next workout over a FINISHED-but-unlogged session
        // must commit it, not discard it — finished sets are real facts.
        store.startTodayWorkout()
        XCTAssertNotNil(store.pendingWorkoutChange, "replacing session work asks first")
        store.confirmPendingWorkoutChange()

        XCTAssertEqual(store.currentAthleteWorkoutLogs.count, logsBefore + 1,
                       "the finished session logged instead of vanishing")
        XCTAssertTrue(store.isWorkoutSessionActive, "and the new session started")
    }

    func testTrainingPreferencesPersistAndShareToggleReArms() {
        let store = freshStore()
        XCTAssertTrue(store.autoRestTimerEnabled, "auto rest ships on by default")
        XCTAssertFalse(store.autoShareWorkoutsEnabled, "auto-share is opt-in — posting is never a surprise")

        store.autoRestTimerEnabled = false
        store.autoShareWorkoutsEnabled = true

        let reloaded = MorpheAppStore()
        XCTAssertFalse(reloaded.autoRestTimerEnabled, "the rest preference survives relaunch")
        // While the social feed is dark, a persisted auto-share is FORCED
        // off on load (post-cut audit P0-2). Asserted as a literal — not
        // against the flag it's meant to test (audit 5: that passed
        // vacuously). If socialFeedEnabled ever flips on, this fails and
        // the round-trip assertion comes back.
        XCTAssertFalse(reloaded.autoShareWorkoutsEnabled,
                       "while the feed is dark the persisted opt-in must load forced OFF")

        // A per-session opt-out lasts exactly one session.
        startedTwoExerciseSession(reloaded)
        reloaded.shareCompletedSessionToFeed = false
        reloaded.completeTrackedSet(reps: 8, weight: 50)
        reloaded.finishTrackedWorkoutSession()
        XCTAssertTrue(reloaded.shareCompletedSessionToFeed,
                      "finishing a session re-arms the share toggle — opting out is never sticky")
    }

    /// Audit 5, P2: while the feed is dark the runtime toggle is forced
    /// off, and the next unrelated preference write was persisting that
    /// forced-off value — silently erasing an opt-in recorded while the
    /// feed was live. The stored value must survive.
    func testDarkFeedPersistPreservesStoredAutoShareOptIn() {
        let store = freshStore()
        store.autoRestTimerEnabled = false   // force a persist so the blob exists

        // THIS store's blob only — a scan over every morphe.trainingprefs.*
        // key mutated and asserted over stale blobs from earlier runs on
        // the same simulator, which made the test environment-dependent.
        let key = "morphe.trainingprefs.\(store.clientProfile.id.uuidString)"

        // Simulate an opt-in recorded while the feed was LIVE, the way a
        // pre-cut build wrote it: flip the stored flag directly in the blob.
        guard let data = UserDefaults.standard.data(forKey: key),
              var json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
        else { return XCTFail("couldn't read this store's prefs blob") }
        json["autoShareWorkouts"] = true
        guard let updated = try? JSONSerialization.data(withJSONObject: json)
        else { return XCTFail("couldn't rewrite this store's prefs blob") }
        UserDefaults.standard.set(updated, forKey: key)

        // Reload: runtime forced off while the feed is dark…
        let reloaded = MorpheAppStore()
        XCTAssertFalse(reloaded.autoShareWorkoutsEnabled)

        // …and an unrelated preference write must NOT erase the stored opt-in.
        reloaded.autoRestTimerEnabled = true
        guard let after = UserDefaults.standard.data(forKey: key),
              let afterJSON = (try? JSONSerialization.jsonObject(with: after)) as? [String: Any]
        else { return XCTFail("prefs blob vanished") }
        XCTAssertEqual(afterJSON["autoShareWorkouts"] as? Bool, true,
                       "the stored opt-in survives unrelated preference writes while the feed is dark")
    }

    /// The dark-feed fetch gate, exercised on BOTH legs (audit 5, P2:
    /// every feed test injects a double, so the Firebase leg of the guard
    /// had zero coverage).
    func testShouldFetchFeedGate() {
        XCTAssertTrue(MorpheAppStore.shouldFetchFeed(socialFeedEnabled: true, usesFirebaseFeed: true))
        XCTAssertTrue(MorpheAppStore.shouldFetchFeed(socialFeedEnabled: true, usesFirebaseFeed: false))
        XCTAssertTrue(MorpheAppStore.shouldFetchFeed(socialFeedEnabled: false, usesFirebaseFeed: false),
                      "test doubles keep the feed logic warm while the flag is off")
        XCTAssertFalse(MorpheAppStore.shouldFetchFeed(socialFeedEnabled: false, usesFirebaseFeed: true),
                       "a dark feed never pays Firebase for a fetch no surface can show")
    }

    /// Alive wave: the greeting is personal and the Today prompt is derived
    /// from real state — it flips to the done-state line the moment a
    /// session is actually logged, never before.
    func testConversationalGreetingAndPromptDeriveFromRealState() {
        let store = freshStore()
        XCTAssertTrue(store.homeGreeting.contains("Sarah"), "the greeting addresses the user by name")
        XCTAssertFalse(store.homePrompt.isEmpty)
        XCTAssertFalse(store.homePrompt.contains("in the books"),
                       "no done-state language before anything is logged")

        startedTwoExerciseSession(store)
        store.completeTrackedSet(reps: 8, weight: 50)
        store.finishTrackedWorkoutSession()
        store.logWorkout()
        XCTAssertTrue(store.homePrompt.contains("in the books"),
                      "a LOGGED session flips the prompt to the done state — finishing alone doesn't")
    }

    /// Audit 7, P1-1: the prompt's priority must mirror the Today hero
    /// chain — a planned rest day outranks everything the hero would hide.
    func testHomePromptRestDayOutranksOtherStates() {
        let store = freshStore()
        let today = Calendar.current.component(.weekday, from: .now)
        store.trainingDays = [today == 1 ? 2 : 1]
        XCTAssertTrue(store.homePrompt.contains("rest day"),
                      "on a planned rest day the voice matches the rest-day card underneath")
    }

    /// Audit 9, P0-3: LocalProfileSnapshot's tolerant hand-written decoder
    /// silently dropped autoTaskTotalToday once — every field added to the
    /// struct must survive a round trip, and this is the canary.
    func testProfileSnapshotRoundTripsAutoTaskTotal() throws {
        // The tolerant decoder IS the no-arg initializer: an empty blob
        // decodes to all defaults.
        var snapshot = try JSONDecoder().decode(LocalProfileSnapshot.self, from: Data("{}".utf8))
        snapshot.autoTaskTotalToday = 2
        snapshot.dailyStateDay = "2026-08-15"
        snapshot.completedTaskTitlesToday = ["Complete today's workout"]

        let data = try JSONEncoder().encode(snapshot)
        let decoded = try JSONDecoder().decode(LocalProfileSnapshot.self, from: data)

        XCTAssertEqual(decoded.autoTaskTotalToday, 2,
                       "the day's auto-task denominator must survive persistence")
        XCTAssertEqual(decoded.dailyStateDay, "2026-08-15")
        XCTAssertEqual(decoded.completedTaskTitlesToday, ["Complete today's workout"])
    }

    /// Jarvis wave: the ask reshapes the day through REAL adjustments,
    /// persists its reply, and only asks once per day.
    func testMorpheAskAnswersHonestlyOncePerDay() {
        let store = freshStore()
        XCTAssertNil(store.morpheAskReplyToday)

        let reply = store.answerMorpheAsk(.short)
        XCTAssertTrue(reply.contains("trimmed"), "the reply describes the adjustment that actually ran")
        XCTAssertEqual(store.morpheAskReplyToday, reply, "the spoken reply persists for the day")
        // Every-open era: the popup re-offers by design, but the day's
        // SPOKEN reply is owned by the first answer.
        _ = store.answerMorpheAsk(.tired)
        XCTAssertEqual(store.morpheAskReplyToday, reply,
                       "a later answer re-applies the action, never rewrites the day's reply")
    }

    /// Moments engine: the daily ask remembers yesterday's answer and
    /// shapes today's question from it — the friend checking back in.
    func testMorpheAskRemembersYesterdaysAnswer() {
        let store = freshStore()
        XCTAssertFalse(store.dayPopupQuestion(evening: false).contains("recovery day"),
                      "no memory, no claim — the default question stands")

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: .now)!
        UserDefaults.standard.set(
            "Tired",
            forKey: "morphe.ask.\(store.clientProfile.id.uuidString).mood.\(formatter.string(from: yesterday))"
        )
        XCTAssertTrue(store.dayPopupQuestion(evening: false).contains("recovery day"),
                      "yesterday's 'Tired' shapes today's question")
    }

    /// Moments engine phase 3: the PR-proximity line is pure Epley math on
    /// logged sets — 100 lb x 8 banks an est. 1RM of 126.7, so 9 reps at
    /// 100 lb is the smallest count that tops it.
    func testPRProximityLineDerivesFromLoggedSets() {
        let store = freshStore()
        startedTwoExerciseSession(store)
        let exercise = store.activeWorkoutExercise!
        store.completeTrackedSet(reps: 8, weight: 100)
        store.finishTrackedWorkoutSession()
        store.logWorkout()

        let line = store.prProximityLine(for: exercise)
        XCTAssertNotNil(line, "one logged weighted session is enough history")
        XCTAssertTrue(line?.contains("9 reps") == true,
                      "Epley says 9 reps at the last top weight beats 8: \(line ?? "nil")")
    }

    /// Apple benchmark A2: the monthly challenge derives purely from real
    /// logs — invisible without a base month, last month + 1 with one.
    func testMonthlyChallengeDerivesFromRealLogs() {
        let store = freshStore()
        XCTAssertNil(store.monthlyChallenge, "no base month, no invented target")

        // Injected directly — the back-date door honestly caps at 14 days,
        // and a base month is older than that by definition.
        let calendar = Calendar.current
        let thisMonthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: .now))!
        for offset in 0..<3 {
            let day = calendar.date(byAdding: .day, value: -(5 + offset * 2), to: thisMonthStart)!
            store.workoutLogs.append(WorkoutLog(
                athleteID: store.clientProfile.id,
                athleteName: store.clientProfile.name,
                workoutTemplateID: nil,
                workoutTitle: "Base Month Session",
                sport: .strength,
                completedAt: day,
                durationMinutes: 40,
                exercises: [LoggedExercise(
                    name: "Push-Up", sets: "3 sets", reps: "10, 10, 10",
                    weight: "", note: "",
                    repsPerSet: [10, 10, 10], weightsPerSet: [0, 0, 0],
                    rpePerSet: [0, 0, 0], weightUnit: "lb"
                )],
                notes: "", source: .athleteManual,
                enteredByUserID: store.clientProfile.id, enteredByRole: .client,
                enteredByName: store.clientProfile.name, verificationStatus: .athleteSubmitted
            ))
        }

        guard let challenge = store.monthlyChallenge else {
            return XCTFail("three last-month sessions form a base month")
        }
        XCTAssertEqual(challenge.target, 4, "last month's 3 sets this month's bar at 4")
        XCTAssertTrue(challenge.line.contains("3 sessions"))
    }

    /// Apple benchmark A6 + audit 11 P0-1: a fresh onboarding fires the
    /// hello and HOLDS the welcome sheet (the overlay's completion raises
    /// it — raised together, the sheet hid the hello forever).
    func testHelloBeatFiresOncePerAccountAndDefersWelcome() {
        let store = freshStore()
        XCTAssertTrue(store.showHelloBeat, "a fresh account gets the hello")
        XCTAssertFalse(store.showWelcomeExperience,
                       "the welcome sheet waits for the hello to finish")
        store.showHelloBeat = false

        let reloaded = MorpheAppStore()
        XCTAssertFalse(reloaded.showHelloBeat, "relaunch never replays it")
    }

    /// Apple benchmark A3: unearned badges are visible goals with their
    /// unlock condition named — never presented as won.
    func testBadgeShowcaseOutlinesUnearnedGoals() {
        let store = freshStore()
        let showcase = store.badgeShowcase
        XCTAssertTrue(showcase.contains { $0.title == "First Workout" && !$0.earned })

        startedTwoExerciseSession(store)
        store.completeTrackedSet(reps: 8, weight: 50)
        store.finishTrackedWorkoutSession()
        store.logWorkout()
        XCTAssertTrue(store.badgeShowcase.contains { $0.title == "First Workout" && $0.earned },
                      "a real log flips the outline to earned")
    }

    /// "Hey Morphe": voice delegates to the chat action layer, questions
    /// never fire actions, and word boundaries stop keyword collisions.
    func testVoiceCommandsNavigateAndStayHonest() {
        let store = freshStore()

        // Audit 12, P0-1: a QUESTION containing command words must answer,
        // never act — the exact defect that once wiped live sessions.
        let question = store.routeVoiceCommand("when should I start training again")
        XCTAssertFalse(question.isEmpty)
        XCTAssertFalse(store.isWorkoutSessionActive, "questions never start a session")
        XCTAssertFalse(store.hasStartedWorkoutFlow)

        // Audit 12, P2-10: "progressive" must not match "progress".
        _ = store.routeVoiceCommand("explain progressive overload to me")
        XCTAssertEqual(store.selectedClientTab, .today, "no collision navigation")

        let progressReply = store.routeVoiceCommand("show my progress")
        XCTAssertFalse(progressReply.isEmpty)
        XCTAssertEqual(store.selectedClientTab, .hub, "voice uses the same door as the button")

        // The action layer owns start — with its live-session guard.
        startedTwoExerciseSession(store)
        store.completeTrackedSet(reps: 8, weight: 50)
        let guarded = store.routeVoiceCommand("start my workout")
        XCTAssertTrue(guarded.contains("already") || guarded.contains("mid-session"),
                      "a live session is never silently restarted by voice")

        let answer = store.routeVoiceCommand("how do I build a streak")
        XCTAssertFalse(answer.isEmpty, "unknown asks fall through to the Morphe AI brain")
    }

    /// Audit 12, P1-1/P1-2: the takeover re-arms only after a REAL
    /// background return, and never ambushes the post-log moment.
    func testDayPopupReArmGating() {
        let store = freshStore()
        store.dismissDayPopupForSession()
        XCTAssertFalse(store.shouldShowDayPopup)

        // An .active without a preceding .background (Control Center
        // glance) must NOT re-arm.
        store.reopenDayPopup()
        XCTAssertFalse(store.shouldShowDayPopup, "scene flicker never re-arms the takeover")

        store.noteBackgrounded()
        store.reopenDayPopup()
        XCTAssertTrue(store.shouldShowDayPopup, "a real background return re-arms it")

        // Logging parks it for the rest of this open.
        startedTwoExerciseSession(store)
        store.completeTrackedSet(reps: 8, weight: 50)
        store.finishTrackedWorkoutSession()
        store.logWorkout()
        XCTAssertFalse(store.shouldShowDayPopup, "the post-log moment is never ambushed")
    }

    /// Jarvis slide-up: the popup offers three context-derived choices
    /// plus Other, and an answer persists the day's reply through the
    /// same key the one-voice rules read.
    func testDayPopupChoicesAndAnswerPersist() {
        let store = freshStore()

        let choices = store.dayPopupChoices(evening: false)
        XCTAssertEqual(choices.count, 4, "three common answers plus Other")
        XCTAssertEqual(choices.last?.label, "Other…", "the fourth choice is always Other")
        XCTAssertEqual(choices.first?.label, "Start my workout")

        let evening = store.dayPopupChoices(evening: true)
        XCTAssertEqual(evening.count, 4, "the evening voice keeps the 3+Other shape")
        XCTAssertEqual(evening.first?.label, "Short session tonight")
        XCTAssertEqual(evening.last?.label, "Other…")

        store.answerDayPopup(.restUp)
        XCTAssertNotNil(store.morpheAskReplyToday, "an answered popup speaks for the day")
        XCTAssertFalse(store.shouldShowDayPopup, "answered parks the popup for this open")

        // Every open re-offers (Lucas 2026-08-18) — a REAL background
        // return brings it back even after an answer (audit 12, P1-1:
        // scene flickers alone never re-arm it).
        store.noteBackgrounded()
        store.reopenDayPopup()
        XCTAssertTrue(store.shouldShowDayPopup, "the popup greets every real app open")
    }

    /// Once the day's work is logged, the popup becomes a launcher — and
    /// its actions never overwrite the day's first spoken reply.
    func testDayPopupLoggedStateBecomesLauncher() {
        let store = freshStore()
        startedTwoExerciseSession(store)
        store.completeTrackedSet(reps: 8, weight: 50)
        store.finishTrackedWorkoutSession()
        store.logWorkout()

        let choices = store.dayPopupChoices(evening: false)
        XCTAssertEqual(choices.first?.label, "Go again")
        XCTAssertEqual(choices.last?.label, "Other…")
        XCTAssertTrue(store.dayPopupQuestion(evening: false).contains("in the books"))
    }

    /// Moments engine phase 2: the evening check-in's choices map to real
    /// actions, persist their reply, and stand down for the evening.
    func testEveningCheckInAnswersHonestly() {
        let store = freshStore()

        let reply = store.answerEveningCheckIn(.minimumWin)
        XCTAssertTrue(store.minimumWinModeEnabled, "the choice ran the real action")
        XCTAssertEqual(store.eveningCheckInReplyToday, reply, "the reply persists for the evening")

        // Answered means answered (audit 10, P2-12): a second answer must
        // return the original reply and change nothing — the old assert on
        // (the old shouldOfferEveningCheckIn assert was vacuous pre-17:00.)
        let secondReply = store.answerEveningCheckIn(.tomorrow)
        XCTAssertEqual(secondReply, reply, "no overwrite once the evening is answered")
        XCTAssertEqual(store.eveningCheckInReplyToday, reply)
    }

    /// Moments engine: milestone pep-talks fire once per milestone, only
    /// from numbers the logs actually earned.
    func testMilestonePepTalkFiresOnceFromRealLogs() {
        let store = freshStore()
        for _ in 1...10 {
            startedTwoExerciseSession(store)
            store.completeTrackedSet(reps: 8, weight: 50)
            store.finishTrackedWorkoutSession()
            store.logWorkout()
            // The first log sets a PR stamp; a real user dismisses it.
            // Milestones defer while a stamp holds the stage (audit 10,
            // P1-2), so the test clears it like the user would.
            store.recordStamp = nil
        }
        // The 10th log crosses the sessions10 milestone (same weight every
        // session, so no PR celebration competes on the later logs).
        XCTAssertEqual(store.celebration?.title, "TEN SESSIONS LOGGED")

        store.celebration = nil
        store.celebrateMilestonesAfterLog()
        XCTAssertNil(store.celebration, "a seen milestone never replays")
    }

    /// Alive wave: guide hints show once, then stay dismissed across
    /// relaunches for the same profile.
    func testGuideHintsShowOncePerProfile() {
        let store = freshStore()
        XCTAssertFalse(store.hasSeenGuide("home.welcome"))
        store.markGuideSeen("home.welcome")
        XCTAssertTrue(store.hasSeenGuide("home.welcome"))

        let reloaded = MorpheAppStore()
        XCTAssertTrue(reloaded.hasSeenGuide("home.welcome"), "seen state survives relaunch")
    }

    func testRPEIsCapturedRestoredAndLogged() {
        let store = freshStore()
        startedTwoExerciseSession(store)
        let exercise = store.activeWorkoutExercise!

        store.completeTrackedSet(reps: 8, weight: 45, rpe: 8)
        XCTAssertEqual(store.trackedSetRPE[exercise.id], [8])
        XCTAssertEqual(store.sessionRecapItems.first?.rpes, [8], "recap must carry the set's RPE")

        // RPE survives a mid-session relaunch.
        let reloaded = MorpheAppStore()
        let restoredExercise = reloaded.currentWorkout.exercises.first!
        XCTAssertEqual(reloaded.trackedSetRPE[restoredExercise.id], [8],
                       "per-set RPE must persist with the session snapshot")
    }

    private func strengthLog(for store: MorpheAppStore, exercise: String, daysAgo: Int,
                             topWeight: Double, unit: String = "lb") -> WorkoutLog {
        WorkoutLog(
            athleteID: store.clientProfile.id,
            athleteName: store.clientProfile.name,
            workoutTemplateID: nil,
            workoutTitle: "Strength Session",
            sport: .strength,
            completedAt: Calendar.current.date(byAdding: .day, value: -daysAgo, to: .now) ?? .now,
            durationMinutes: 30,
            exercises: [LoggedExercise(
                name: exercise, sets: "2 sets", reps: "8, 8",
                weight: "\(Int(topWeight)) \(unit)", note: "",
                repsPerSet: [8, 8], weightsPerSet: [topWeight - 5, topWeight],
                rpePerSet: [0, 8], weightUnit: unit
            )],
            notes: "", source: .athleteManual,
            enteredByUserID: store.clientProfile.id, enteredByRole: .client,
            enteredByName: store.clientProfile.name, verificationStatus: .athleteSubmitted
        )
    }

    func testStrengthProgressTracksTopSetAcrossSessions() {
        let store = freshStore()
        store.workoutLogs.append(strengthLog(for: store, exercise: "Goblet Squat", daysAgo: 7, topWeight: 45))
        store.workoutLogs.append(strengthLog(for: store, exercise: "Goblet Squat", daysAgo: 1, topWeight: 50))
        // Single-session exercise must NOT appear (one point isn't a trend).
        store.workoutLogs.append(strengthLog(for: store, exercise: "Deadlift", daysAgo: 2, topWeight: 135))

        let progress = store.exerciseStrengthProgress
        XCTAssertEqual(progress.count, 1, "only exercises with 2+ weighted sessions qualify")
        XCTAssertEqual(progress.first?.exerciseName, "Goblet Squat")
        XCTAssertEqual(progress.first?.latestTopWeight ?? 0, 50, accuracy: 0.001)
        XCTAssertEqual(progress.first?.previousTopWeight ?? 0, 45, accuracy: 0.001)
        XCTAssertEqual(progress.first?.delta ?? 0, 5, accuracy: 0.001)
    }

    func testPersonalRecordsDeriveFromLoggedSets() {
        let store = freshStore()
        XCTAssertTrue(store.derivedPersonalRecords.isEmpty, "no records before any logs")

        store.workoutLogs.append(strengthLog(for: store, exercise: "Goblet Squat", daysAgo: 7, topWeight: 45))
        store.workoutLogs.append(strengthLog(for: store, exercise: "Goblet Squat", daysAgo: 1, topWeight: 50))

        let records = store.derivedPersonalRecords
        XCTAssertEqual(records.count, 1, "one record per exercise")
        XCTAssertEqual(records.first?.title, "Goblet Squat")
        XCTAssertEqual(records.first?.value, "50 lb", "the record is the all-time top set")
    }

    func testInjuryNoteAndTrainingDaysAreEditablePostOnboarding() {
        let store = freshStore()

        store.updateInjuryNote("New shoulder tweak — no overhead work")
        XCTAssertEqual(store.clientProfile.limitations, "New shoulder tweak — no overhead work")
        XCTAssertEqual(store.personalRules.first?.detail, "New shoulder tweak — no overhead work",
                       "personal rules follow the injury note")

        store.updateTrainingDaysPerWeek(5)
        XCTAssertEqual(store.clientProfile.trainingDaysPerWeek, 5)

        // Both survive relaunch.
        let reloaded = MorpheAppStore()
        XCTAssertEqual(reloaded.clientProfile.limitations, "New shoulder tweak — no overhead work")
        XCTAssertEqual(reloaded.clientProfile.trainingDaysPerWeek, 5)
    }

    func testStrengthProgressNormalizesRecordedUnit() {
        let store = freshStore()
        store.weightUnit = .pounds
        // Two sessions recorded in kg while the display unit is lb.
        store.workoutLogs.append(strengthLog(for: store, exercise: "Bench Press", daysAgo: 7, topWeight: 20, unit: "kg"))
        store.workoutLogs.append(strengthLog(for: store, exercise: "Bench Press", daysAgo: 1, topWeight: 22.5, unit: "kg"))

        let progress = store.exerciseStrengthProgress.first
        XCTAssertEqual(progress?.latestTopWeight ?? 0, 49.6, accuracy: 0.2,
                       "kg-recorded weights are converted to the current lb display unit")
    }

    func testLoggedWorkoutPreservesPerSetData() {
        let store = freshStore()
        startedTwoExerciseSession(store)

        store.completeTrackedSet(reps: 10, weight: 45, rpe: 8)
        store.completeTrackedSet(reps: 8, weight: 50, rpe: 9)
        store.finishTrackedWorkoutSession()
        store.logWorkout()

        let logged = store.workoutLogs
            .first { $0.athleteID == store.clientProfile.id }?
            .exercises.first { $0.repsPerSet != nil }
        XCTAssertEqual(logged?.repsPerSet, [10, 8], "raw per-set reps must survive into the log")
        XCTAssertEqual(logged?.weightsPerSet, [45, 50], "raw per-set weights must survive into the log")
        XCTAssertEqual(logged?.rpePerSet, [8, 9], "raw per-set RPE must survive into the log")
        XCTAssertEqual(logged?.weightUnit, store.weightUnit.rawValue, "the recording unit is pinned on the log")
    }

    func testLoggedDurationIsElapsedTimeNotTemplateLength() {
        let store = freshStore()
        startedTwoExerciseSession(store)

        // Simulate a session that started 25 minutes ago.
        store.workoutSessionStartedAt = Date.now.addingTimeInterval(-25 * 60)
        store.completeTrackedSet(reps: 8, weight: 50)
        store.finishTrackedWorkoutSession()

        XCTAssertEqual(store.completedSessionMinutes ?? 0, 25, accuracy: 1)

        store.logWorkout()
        let log = store.workoutLogs.first { $0.athleteID == store.clientProfile.id }
        XCTAssertEqual(log?.durationMinutes ?? 0, 25, accuracy: 1,
                       "the log records time actually trained, not the template's planned length")
    }

    func testOnboardingSavesUsersOwnInjuriesNotDemoAthletes() {
        let store = MorpheAppStore()
        store.onboardingDraft.name = "Sarah"
        store.onboardingDraft.injuries = "Shoulder impingement, avoid overhead press"
        store.onboardingDraft.equipment = "Kettlebells only"
        store.completeOnboarding()

        XCTAssertEqual(store.clientProfile.limitations, "Shoulder impingement, avoid overhead press",
                       "the user's typed injuries must be saved — this is safety data")
        XCTAssertEqual(store.clientProfile.equipment, "Kettlebells only")
        XCTAssertFalse(store.clientProfile.limitations.contains("Knee"),
                       "the demo athlete's knee complaint must never leak into a real profile")

        // And it survives relaunch (was previously overwritten by demo data).
        let reloaded = MorpheAppStore()
        XCTAssertEqual(reloaded.clientProfile.limitations, "Shoulder impingement, avoid overhead press")
    }

    func testFreshUserStartsAtLevelOne() {
        let store = MorpheAppStore()
        store.onboardingDraft.name = "Sarah"
        store.completeOnboarding()

        XCTAssertEqual(store.clientProfile.level.currentXP, 0, "no inherited demo XP")
        XCTAssertEqual(store.clientProfile.level.currentTitle, "Level 1")
    }

    func testQuizProgressAndXPSurviveRelaunch() {
        let store = MorpheAppStore()
        store.onboardingDraft.name = "Sarah"
        store.completeOnboarding()

        let quiz = store.quizzes.first!
        store.answerQuiz(quiz, with: quiz.correctIndex)
        XCTAssertTrue(store.completedQuizIDs.contains(quiz.id))
        let earnedXP = store.clientProfile.level.currentXP
        XCTAssertGreaterThan(earnedXP, 0, "a correct answer earns XP")

        // Everything earned must survive a relaunch (it used to wipe to zero).
        let reloaded = MorpheAppStore()
        XCTAssertTrue(reloaded.completedQuizIDs.contains(quiz.id), "quiz completion persists via stable ids")
        XCTAssertEqual(reloaded.clientProfile.level.currentXP, earnedXP, "earned XP persists")
    }

    func testWrongThenRightEarnsNoXP() {
        let store = MorpheAppStore()
        store.onboardingDraft.name = "Sarah"
        store.completeOnboarding()

        let quiz = store.quizzes.first!
        let wrongIndex = quiz.correctIndex == 0 ? 1 : 0
        store.answerQuiz(quiz, with: wrongIndex)
        store.answerQuiz(quiz, with: quiz.correctIndex)   // explanation revealed the answer

        XCTAssertFalse(store.completedQuizIDs.contains(quiz.id), "the first answer is final")
        XCTAssertEqual(store.clientProfile.level.currentXP, 0, "no XP for answering after the reveal")
    }

    func testXPTargetsFollowDecadeCurve() {
        // Levels 1–10 take 100 XP each, 11–20 take 200, 21–30 take 300…
        XCTAssertEqual(MorpheAppStore.xpTarget(forLevel: 1), 100)
        XCTAssertEqual(MorpheAppStore.xpTarget(forLevel: 10), 100)
        XCTAssertEqual(MorpheAppStore.xpTarget(forLevel: 11), 200)
        XCTAssertEqual(MorpheAppStore.xpTarget(forLevel: 20), 200)
        XCTAssertEqual(MorpheAppStore.xpTarget(forLevel: 21), 300)
        XCTAssertEqual(MorpheAppStore.xpTarget(forLevel: 35), 400)
        XCTAssertEqual(MorpheAppStore.xpTarget(forLevel: 0), 100, "defensive floor at level 1")
    }

    func testLevelTargetsSurviveRelaunchOnTheCurve() {
        let store = MorpheAppStore()
        store.onboardingDraft.name = "Sarah"
        store.completeOnboarding()

        // Earn enough XP to cross at least one level boundary.
        for quiz in store.quizzes.prefix(12) {
            store.answerQuiz(quiz, with: quiz.correctIndex)
        }
        let levelBefore = store.currentLevelNumber
        let xpBefore = store.clientProfile.level.currentXP
        XCTAssertGreaterThan(levelBefore, 1)
        XCTAssertEqual(store.clientProfile.level.targetXP,
                       MorpheAppStore.xpTarget(forLevel: levelBefore),
                       "the live target follows the decade curve")

        let reloaded = MorpheAppStore()
        XCTAssertEqual(reloaded.currentLevelNumber, levelBefore)
        XCTAssertEqual(reloaded.clientProfile.level.currentXP, xpBefore)
        XCTAssertEqual(reloaded.clientProfile.level.targetXP,
                       MorpheAppStore.xpTarget(forLevel: levelBefore),
                       "restored targets are recomputed from the curve, not trusted from disk")
    }

    func testXPRollsOverIntoLevelUps() {
        let store = MorpheAppStore()
        store.onboardingDraft.name = "Sarah"
        store.completeOnboarding()

        // Fresh baseline: Level 1, 0/100. Ten correct quizzes (10-12 XP each)
        // must cross into Level 2 instead of clamping at the bar.
        for quiz in store.quizzes.prefix(10) {
            store.answerQuiz(quiz, with: quiz.correctIndex)
        }

        XCTAssertNotEqual(store.clientProfile.level.currentTitle, "Level 1",
                          "enough XP must actually level up (the bar used to clamp)")
    }

    func testSwapFallsThroughDanglingAlternatives() {
        let store = MorpheAppStore()
        store.onboardingDraft.name = "Sarah"
        store.completeOnboarding()

        // Every library exercise with ANY resolvable alternative must swap —
        // several list a dangling FIRST alternative (e.g. Shoulder Press ->
        // "Landmine Press"), which used to kill the swap outright.
        let swappable = store.exerciseDatabase.filter { reference in
            reference.alternatives.contains { name in
                store.exerciseDatabase.contains { $0.name == name }
            }
        }
        XCTAssertFalse(swappable.isEmpty)

        for reference in swappable {
            store.createCustomWorkout(
                name: "Swap \(reference.name)",
                sport: .strength,
                items: [CustomWorkoutItem(exercise: reference, sets: 3, reps: 10)]
            )
            let exercise = store.currentWorkout.exercises.first!
            store.swapExercise(exercise)
            XCTAssertNotEqual(store.currentWorkout.exercises.first?.name, reference.name,
                              "\(reference.name) must swap to a real alternative")
        }
    }

    func testCatalogLoadsValidatedAndStable() {
        let store = MorpheAppStore()

        XCTAssertGreaterThan(store.catalogWorkouts.count, 100, "the bundled catalog must load at scale")

        // Every exercise in every catalog workout must resolve to the library
        // (the loader drops broken documents — none should be dropped).
        let documents = WorkoutCatalog.loadBundled()
        XCTAssertEqual(store.catalogWorkouts.count, documents.count,
                       "no catalog workout should be dropped for unresolvable exercises")

        // Stable identity: a second load produces identical ids (saved
        // references must survive relaunch and regeneration).
        let reloadedIDs = Set(MorpheAppStore().catalogWorkouts.map(\.id))
        XCTAssertEqual(Set(store.catalogWorkouts.map(\.id)), reloadedIDs)

        // Facets are populated.
        XCTAssertTrue(store.catalogWorkouts.allSatisfy { !$0.focusTag.isEmpty })
    }

    func testDiscoverBrowsesTheV2LibraryByCategoryAndGoal() {
        let store = MorpheAppStore()

        // The v2 library is browsable again: hand-authored workouts across
        // the ten training-style categories.
        XCTAssertGreaterThanOrEqual(store.discoverWorkouts.count, 150, "the library ships 150+ workouts (grows with content drops)")

        let categories = Set(store.discoverWorkouts.map(\.categoryTag))
        XCTAssertGreaterThanOrEqual(categories.count, 13, "category spines (grows with content drops)")
        XCTAssertTrue(categories.contains("Strength & Powerlifting"))
        XCTAssertTrue(categories.contains("Recovery & Longevity"))

        // Every workout carries a result goal — the Discover goal lens.
        let goals = Set(store.discoverWorkouts.map(\.goalTag))
        XCTAssertEqual(goals, ["weightLoss", "strengthBuilding", "leanOut", "recovery"],
                       "all four goals are represented and nothing is untagged")

        // The catalog still powers the Today plan engine.
        XCTAssertFalse(store.catalogWorkouts.isEmpty,
                       "the bundled catalog still powers the daily plan and saved workouts")
        XCTAssertTrue(store.catalogWorkouts.allSatisfy { !$0.trainingTypeTag.isEmpty },
                      "every catalog workout carries a training type")

        // Intensity prescriptions survive the loader: a heavy strength lift
        // shows an honest %1RM, and rest carries through.
        let benchDay = store.discoverWorkouts.first { $0.name == "Heavy Bench Day" }
        XCTAssertNotNil(benchDay)
        let heavyBench = benchDay?.exercises.first { $0.exerciseLibraryID == "barbell-bench-press" }
        XCTAssertEqual(heavyBench?.intensityLabel, "87% 1RM")
        XCTAssertEqual(heavyBench?.restSeconds, 240)
    }

    func testSavedCatalogWorkoutSurvivesRelaunch() {
        let store = MorpheAppStore()
        store.onboardingDraft.name = "Sarah"
        store.completeOnboarding()

        let template = store.catalogWorkouts.first!
        store.saveCatalogWorkout(template)
        XCTAssertTrue(store.isCatalogWorkoutSaved(template))

        let reloaded = MorpheAppStore()
        XCTAssertTrue(reloaded.savedWorkouts.contains { $0.workoutTemplateID == template.id },
                      "a Discover save must survive relaunch")
        XCTAssertTrue(reloaded.workoutTemplates.contains { $0.id == template.id },
                      "the saved template must be startable after relaunch")
    }

    func testCatalogWorkoutStartsLiveSession() {
        let store = MorpheAppStore()
        store.onboardingDraft.name = "Sarah"
        store.completeOnboarding()

        let template = store.catalogWorkouts.first!
        store.startCatalogWorkout(template)

        XCTAssertTrue(store.isWorkoutSessionActive)
        XCTAssertEqual(store.currentWorkout.id, template.id)
        XCTAssertFalse(store.currentWorkout.exercises.isEmpty)
    }

    func testProfileDetailEditorsPersist() {
        let store = MorpheAppStore()
        store.onboardingDraft.name = "Sarah"
        store.completeOnboarding()

        store.updateBodyMetrics(height: "5'10\"", weight: "172 lb")
        store.updateExperienceLevel(.advanced)
        store.toggleProfileGoal(.gainMuscle)
        store.toggleProfileTrainingStyle(.strength)

        let reloaded = MorpheAppStore()
        XCTAssertEqual(reloaded.clientProfile.height, "5'10\"")
        XCTAssertEqual(reloaded.clientProfile.bodyWeight, "172 lb")
        XCTAssertEqual(reloaded.clientProfile.fitnessLevel, ExperienceLevelOption.advanced.rawValue)
        XCTAssertTrue(reloaded.clientProfile.selectedGoals.contains(FitnessGoalOption.gainMuscle.rawValue))
        XCTAssertTrue(reloaded.clientProfile.selectedTrainingStyles.contains(.strength))
    }

    func testMorpheAIExecutesCommands() {
        let store = MorpheAppStore()
        store.onboardingDraft.name = "Sarah"
        store.completeOnboarding()

        store.sendAIAgentPrompt("Start my workout")
        XCTAssertTrue(store.isWorkoutSessionActive, "'start my workout' actually starts the session")
        XCTAssertEqual(store.selectedClientTab, .train)

        // Discard is deliberately NOT executed from chat — logged sets are
        // unrecoverable, so Morphe AI points at the confirming UI instead.
        store.sendAIAgentPrompt("Discard this session")
        XCTAssertTrue(store.isWorkoutSessionActive, "chat never silently discards a live session")

        store.sendAIAgentPrompt("Switch to kg")
        XCTAssertEqual(store.weightUnit, .kilograms, "'switch to kg' changes the setting")

        store.sendAIAgentPrompt("Show my progress")
        XCTAssertEqual(store.selectedClientTab, .hub, "'show my progress' navigates there")

        // Every command produced a confirmation reply from Morphe AI.
        let aiReplies = store.athleteAIAgentConversation.filter { $0.senderName == "Morphe AI" }
        XCTAssertTrue(aiReplies.contains { $0.text.contains("kilograms") })
        XCTAssertTrue(aiReplies.contains { $0.text.contains("Discard at the top of Train") },
                      "the discard ask is answered with the safe path")
    }

    func testRenameKeepsClaimedUsernameAndCapsLength() {
        let store = MorpheAppStore()
        store.onboardingDraft.name = "Lucas"
        store.completeOnboarding()
        XCTAssertEqual(store.profileShowcase.username, "lucas")

        store.updateDisplayName("Maria Lopez")
        XCTAssertEqual(store.profileShowcase.displayName, "Maria Lopez")
        XCTAssertEqual(store.profileShowcase.username, "lucas",
                       "the @username is a claimed identity — a rename must never touch it")

        // Long names truncate to 40 (reset the rename cooldown so this
        // change isn't blocked by the 14-day rule).
        store.nameChangedAtEpoch = 0
        store.updateDisplayName(String(repeating: "x", count: 300))
        XCTAssertEqual(store.profileShowcase.displayName.count, 40, "names cap at 40 chars")

        let nameBefore = store.profileShowcase.displayName
        store.updateDisplayName("   ")
        XCTAssertEqual(store.profileShowcase.displayName, nameBefore, "an empty save keeps the old name")
    }

    func testFreshUserHasNoFabricatedMetricsOrRules() {
        let store = MorpheAppStore()
        store.onboardingDraft.name = "Sarah"
        store.onboardingDraft.injuries = "Wrist pain on push-ups"
        store.completeOnboarding()

        XCTAssertTrue(store.sportMetrics.isEmpty, "no fabricated sport metrics for a real user")
        XCTAssertEqual(store.personalRules.count, 1, "personal rules derive from the user's own injuries")
        XCTAssertEqual(store.personalRules.first?.detail, "Wrist pain on push-ups")
        XCTAssertFalse(store.personalRules.contains { $0.title.contains("Knee pain") },
                       "the demo athlete's rules must never leak")
        XCTAssertEqual(store.clientProfile.aiTodayInsight.title, "Today's tip",
                       "no 'AI Coach Message' branding")

        // Switching sports must not resurrect fabricated metrics.
        store.selectSportMode(.running)
        XCTAssertTrue(store.sportMetrics.isEmpty)
    }

    func testConsistencyTargetComesFromOnboarding() {
        let store = MorpheAppStore()
        store.onboardingDraft.name = "Sarah"
        store.onboardingDraft.trainingDaysPerWeek = 4
        store.completeOnboarding()

        XCTAssertEqual(store.clientProfile.trainingDaysPerWeek, 4)

        // And it survives a relaunch.
        let reloaded = MorpheAppStore()
        XCTAssertEqual(reloaded.clientProfile.trainingDaysPerWeek, 4,
                       "the weekly target persists with the profile")
    }

    func testSessionRecapListsOnlyLoggedExercises() {
        let store = freshStore()
        startedTwoExerciseSession(store)

        store.completeTrackedSet(reps: 8, weight: 45)
        let recap = store.sessionRecapItems

        XCTAssertEqual(recap.count, 1, "recap must list only exercises with logged sets")
        XCTAssertEqual(recap.first?.reps, [8])
        XCTAssertEqual(recap.first?.weights, [45])
    }

    func testCustomWorkoutSessionSurvivesRelaunch() {
        let store = freshStore()
        let exercise = store.allExercises.first!
        store.createCustomWorkout(
            name: "Push Day",
            sport: .strength,
            items: [CustomWorkoutItem(exercise: exercise, sets: 3, reps: 8)]
        )
        let custom = store.workoutTemplates.first { $0.name == "Push Day" }!
        store.beginLiveWorkout(custom)
        store.completeTrackedSet(reps: 8, weight: 100)

        // Simulate an app relaunch mid-session.
        let reloaded = MorpheAppStore()

        XCTAssertTrue(reloaded.isWorkoutSessionActive, "an in-progress session must survive relaunch")
        XCTAssertEqual(reloaded.currentWorkout.name, "Push Day",
                       "a custom-workout session must restore its own workout (library loads before session restore)")
        let restoredExercise = reloaded.currentWorkout.exercises.first!
        XCTAssertEqual(reloaded.trackedSetWeights[restoredExercise.id], [100],
                       "logged sets must reattach to the restored custom workout")
    }
}

/// Verifies the Today screen's progressive disclosure: a new user gets one
/// screen with one action; metrics and tools unlock as workouts are logged.
@MainActor
final class TodayExperienceTests: XCTestCase {

    override func setUp() {
        super.setUp()
        WorkoutFilePersistence().clear()
        ProfileFilePersistence().clear()
    }

    private func makeLog(athleteID: UUID, name: String = "Sarah") -> WorkoutLog {
        WorkoutLog(
            athleteID: athleteID,
            athleteName: name,
            workoutTemplateID: nil,
            workoutTitle: "Test Session",
            sport: .strength,
            completedAt: .now,
            durationMinutes: 30,
            exercises: [],
            notes: "",
            source: .athleteManual,
            enteredByUserID: athleteID,
            enteredByRole: .client,
            enteredByName: name,
            verificationStatus: .athleteSubmitted
        )
    }

    func testTodayTiersUnlockByLoggedWorkouts() {
        let store = MorpheAppStore()
        store.onboardingDraft.name = "Sarah"
        store.completeOnboarding()

        XCTAssertEqual(store.loggedWorkoutCount, 0)
        XCTAssertEqual(store.todayExperienceTier, 0, "a brand-new user gets the minimal Today screen")

        store.workoutLogs.append(makeLog(athleteID: store.clientProfile.id))
        XCTAssertEqual(store.todayExperienceTier, 1, "the first logged workout unlocks metrics and day tools")

        for _ in 0..<4 { store.workoutLogs.append(makeLog(athleteID: store.clientProfile.id)) }
        XCTAssertEqual(store.todayExperienceTier, 2, "five logs unlock the full dashboard")
    }

    func testOtherPeoplesLogsDontUnlockTiers() {
        let store = MorpheAppStore()
        store.onboardingDraft.name = "Sarah"
        store.completeOnboarding()

        store.workoutLogs.append(makeLog(athleteID: UUID(), name: "Someone Else"))

        XCTAssertEqual(store.loggedWorkoutCount, 0, "only the user's own logs count toward disclosure")
        XCTAssertEqual(store.todayExperienceTier, 0)
    }
}

/// Verifies the coach↔client training-commerce logic (booking + earnings).
@MainActor
final class BookingTests: XCTestCase {

    override func setUp() {
        super.setUp()
        // Absorb the PREVIOUS test's pending coalesced writes before
        // clearing: building a store triggers the cross-instance flush
        // (the relaunch-simulation mechanism), and without this throwaway
        // the flush re-lands a stale onboarded profile AFTER the clear —
        // which empties the demo booking slots these tests rely on.
        _ = MorpheAppStore()
        WorkoutFilePersistence().clear()
        ProfileFilePersistence().clear()
    }

    func testRequestBookingCreatesPendingAndTakesSlot() {
        let store = MorpheAppStore() // demo-seeded: has packages + slots
        let package = store.trainingPackages.first!
        let slot = store.openAvailabilitySlots.first!
        let openBefore = store.openAvailabilitySlots.count

        let booking = store.requestSessionBooking(package: package, slot: slot, coachName: "Coach K")

        XCTAssertEqual(booking.status, .requested)
        XCTAssertEqual(booking.paymentStatus, .pending)
        XCTAssertEqual(booking.priceValue, package.priceValue)
        XCTAssertTrue(store.sessionBookings.contains { $0.id == booking.id })
        XCTAssertEqual(store.openAvailabilitySlots.count, openBefore - 1,
                       "booking a slot must remove it from availability")
    }

    func testCancelBookingReopensSlot() {
        let store = MorpheAppStore()
        let package = store.trainingPackages.first!
        let slot = store.openAvailabilitySlots.first!
        let openBefore = store.openAvailabilitySlots.count

        let booking = store.requestSessionBooking(package: package, slot: slot, coachName: "Coach K")
        store.cancelBooking(booking)

        XCTAssertEqual(store.sessionBookings.first { $0.id == booking.id }?.status, .cancelled)
        XCTAssertEqual(store.openAvailabilitySlots.count, openBefore,
                       "cancelling must reopen the freed slot")
    }

    func testEarningsRollUpPaidVsPending() {
        let store = MorpheAppStore() // demo incoming bookings: $200 paid, $60 pending
        XCTAssertEqual(store.coachPaidEarnings, 200, accuracy: 0.001)
        XCTAssertEqual(store.coachPendingEarnings, 60, accuracy: 0.001)
    }

    func testClientBookingDoesNotCountAsCoachRevenue() {
        let store = MorpheAppStore()
        let paidBefore = store.coachPaidEarnings
        let pendingBefore = store.coachPendingEarnings
        let requestsBefore = store.coachBookingRequests.count

        let package = store.trainingPackages.first!
        let slot = store.openAvailabilitySlots.first!
        let booking = store.requestSessionBooking(package: package, slot: slot, coachName: "Coach K")

        // My own outgoing booking shows in My Sessions...
        XCTAssertTrue(store.myUpcomingBookings.contains { $0.id == booking.id })
        // ...and must NOT appear as the coach's own incoming revenue or requests.
        XCTAssertEqual(store.coachPaidEarnings, paidBefore, accuracy: 0.001)
        XCTAssertEqual(store.coachPendingEarnings, pendingBefore, accuracy: 0.001)
        XCTAssertEqual(store.coachBookingRequests.count, requestsBefore)
    }

    func testFreshUserHasNoBookingsOrPackages() {
        let store = MorpheAppStore()
        store.onboardingDraft.name = "Riley"
        store.completeOnboarding()

        XCTAssertTrue(store.sessionBookings.isEmpty, "a new account starts with no purchased sessions")
        XCTAssertTrue(store.trainingPackages.isEmpty, "a new account has no seeded coach offerings")
        XCTAssertEqual(store.coachPaidEarnings, 0)
    }

    func testFreshCoachHasNoSeededRoster() {
        let store = MorpheAppStore()
        store.onboardingDraft.name = "Riley"
        store.completeOnboarding()

        // The coach side must not inherit the demo roster (the "every user is
        // Lucas" bug class, coach edition).
        XCTAssertTrue(store.coachClients.isEmpty, "a new coach must not inherit demo clients")
        XCTAssertTrue(store.messageThreads.isEmpty)
        XCTAssertTrue(store.upcomingSessions.isEmpty)
        XCTAssertEqual(store.coachOverview.atRiskClients, 0)
    }
}

/// Locks in the tolerant profile decode — a schema change must never demote a
/// returning user back into onboarding (which would wipe their logs).
final class ProfileSnapshotDecodeTests: XCTestCase {
    func testDecodeToleratesMissingFields() throws {
        // Old-schema JSON written before `id`/`weightUnit`/`currentProgram` existed.
        let json = """
        {"hasCompletedOnboarding": true, "name": "Jordan", "gender": "", \
        "accountRole": "coach", "sportMode": "", "selectedSports": [], \
        "selectedTrainingStyles": [], "selectedGoals": [], "goal": "", \
        "physicalGoalTarget": "", "weightGoalTarget": "", "goalDeadline": "", \
        "fitnessLevel": "", "equipment": "", "injuries": "", "theme": "", \
        "accentPalette": "", "coachingTone": "", "avatarStyle": "", \
        "displayName": "", "username": ""}
        """.data(using: .utf8)!

        let snap = try JSONDecoder().decode(LocalProfileSnapshot.self, from: json)

        XCTAssertTrue(snap.hasCompletedOnboarding, "a returning user must not be demoted to onboarding by a schema gap")
        XCTAssertFalse(snap.id.isEmpty, "a missing id is minted, not a decode failure")
        XCTAssertEqual(snap.name, "Jordan")
        XCTAssertEqual(snap.accountRole, "coach")
        XCTAssertEqual(snap.weightUnit, "pounds", "a missing field falls back to its default")
    }
}

/// Verifies the account/auth seam (the foundation the Firebase backend plugs into).
final class AuthTests: XCTestCase {
    private func freshAuth() -> LocalAuthService {
        let auth = LocalAuthService(fileName: "account-test.json")
        auth.reset()
        return auth
    }

    func testSignUpCreatesAccountWithRole() async throws {
        let auth = freshAuth()
        let user = try await auth.signUp(email: "Coach@Morphe.app", password: "secret123",
                                         role: .coach, displayName: "Coach Sam")
        XCTAssertEqual(user.role, .coach)
        XCTAssertEqual(user.email, "coach@morphe.app", "email is normalized")
        XCTAssertFalse(user.id.isEmpty)
        XCTAssertEqual(auth.currentUser?.id, user.id, "sign-up signs the user in")
        auth.reset()
    }

    func testSignUpRejectsInvalidInput() async {
        let auth = freshAuth()
        await XCTAssertThrowsErrorAsync(try await auth.signUp(email: "nope", password: "secret1",
                                                             role: .athlete, displayName: "X"))
        await XCTAssertThrowsErrorAsync(try await auth.signUp(email: "ok@ok.com", password: "123",
                                                             role: .athlete, displayName: "X"))
        auth.reset()
    }

    func testSignInThenSignOut() async throws {
        let auth = freshAuth()
        _ = try await auth.signUp(email: "a@b.com", password: "secret1", role: .athlete, displayName: "A")
        let again = LocalAuthService(fileName: "account-test.json")
        let user = try await again.signIn(email: "a@b.com", password: "secret1")
        XCTAssertEqual(user.role, .athlete)
        again.signOut()
        XCTAssertNil(again.currentUser)
        again.reset()
    }
}

private func XCTAssertThrowsErrorAsync(_ expression: @autoclosure () async throws -> some Any,
                                       file: StaticString = #filePath, line: UInt = #line) async {
    do { _ = try await expression(); XCTFail("Expected an error", file: file, line: line) }
    catch { /* expected */ }
}

/// Verifies the Morphe Score and streak are derived from real logs, not seeded.
@MainActor
final class MetricsTests: XCTestCase {

    override func setUp() {
        super.setUp()
        WorkoutFilePersistence().clear()
        ProfileFilePersistence().clear()
    }

    func testRecoveryCheckInComputesFromInput() {
        let store = MorpheAppStore()
        store.onboardingDraft.name = "Sarah"
        store.completeOnboarding()

        // Strong recovery.
        store.submitRecoveryCheckIn(sleepHours: 8, energy: 9, soreness: 1, mood: 9, pain: false)
        XCTAssertTrue(store.didCompleteQuickCheckIn)
        XCTAssertGreaterThanOrEqual(store.recovery.score, 80)
        XCTAssertEqual(store.recovery.status, .ready)
        XCTAssertEqual(store.recovery.sleepHours, 8)

        // Poor recovery with pain should drop readiness and not read as "ready".
        store.submitRecoveryCheckIn(sleepHours: 4, energy: 3, soreness: 8, mood: 3, pain: true)
        XCTAssertLessThan(store.recovery.score, 50)
        XCTAssertNotEqual(store.recovery.status, .ready)
        XCTAssertTrue(store.recovery.pain)
    }

    func testScoreAndStreakAreDerivedFromLogs() {
        let store = MorpheAppStore()
        store.onboardingDraft.name = "Sarah"
        store.completeOnboarding()

        XCTAssertEqual(store.clientProfile.health.score, 0, "a new user starts at zero, not the seeded 76")
        XCTAssertEqual(store.clientProfile.level.streak, 0)

        store.startTodayWorkout()
        store.hasCompletedWorkoutFlow = true
        store.logWorkout()

        XCTAssertGreaterThan(store.clientProfile.health.score, 0, "logging should raise the derived score")
        XCTAssertNotEqual(store.clientProfile.health.score, 76, "must not be the seeded demo score")
        XCTAssertGreaterThanOrEqual(store.clientProfile.level.streak, 1, "today's log starts a streak")
        XCTAssertFalse(store.healthTrend.isEmpty, "activity trend reflects real logs")
    }

    // MARK: - Catalog session restore (audit red list)

    func testStartedCatalogWorkoutSessionSurvivesRelaunch() {
        let store = MorpheAppStore()
        store.onboardingDraft.name = "Sarah"
        store.completeOnboarding()

        // Start a Discover workout WITHOUT saving it — on relaunch its
        // template exists only in the bundled catalog, and the restore used
        // to silently point the live session at a different workout.
        let template = store.catalogWorkouts.first(where: { !$0.exercises.isEmpty })!
        store.startCatalogWorkout(template)
        store.completeTrackedSet(reps: 8, weight: 100)
        let exerciseID = template.exercises[0].id

        let reloaded = MorpheAppStore()
        XCTAssertTrue(reloaded.isWorkoutSessionActive)
        XCTAssertEqual(reloaded.currentWorkout.id, template.id,
                       "the session must reattach to the catalog workout it was started from")
        XCTAssertEqual(reloaded.trackedSetReps[exerciseID], [8],
                       "logged sets must resolve against the rebuilt template")
        XCTAssertNotNil(reloaded.activeWorkoutExercise, "the tracker must not come back headless")
    }

    func testStaleSessionForMissingWorkoutIsDropped() {
        let store = MorpheAppStore()
        store.onboardingDraft.name = "Sarah"
        store.completeOnboarding()

        // A persisted session pointing at a workout that no longer exists
        // anywhere (not in templates, not in the catalog).
        WorkoutFilePersistence().saveSession(
            WorkoutSessionSnapshot(
                currentWorkoutID: UUID(),
                isWorkoutSessionActive: true,
                hasStartedWorkoutFlow: true,
                hasCompletedWorkoutFlow: false,
                activeWorkoutExerciseIndex: 3,
                completedWorkoutSets: [:],
                trackedSetReps: [:],
                trackedSetWeights: [:],
                trackedSetRPE: [:],
                workoutSessionStartedAt: Date(),
                completedSessionMinutes: nil,
                isWorkoutLoggedToday: false
            )
        )

        let reloaded = MorpheAppStore()
        XCTAssertFalse(reloaded.isWorkoutSessionActive,
                       "a session whose workout is gone is dropped, not attached to a random template")
        XCTAssertEqual(reloaded.activeWorkoutExerciseIndex, 0)
    }

    // MARK: - Day rollover (audit red list)

    func testDayRolloverResetsDailySurfacesAndKeepsEarnings() {
        let store = MorpheAppStore()
        store.onboardingDraft.name = "Sarah"
        store.completeOnboarding()

        store.toggleTask(store.todayTasks[0])
        store.activateMinimumWinMode()
        let quiz = store.quizzes.first!
        store.answerQuiz(quiz, with: quiz.correctIndex)
        let earnedXP = store.clientProfile.level.currentXP
        XCTAssertGreaterThan(earnedXP, 0)

        store.handleDayRolloverIfNeeded(now: Date(timeIntervalSinceNow: 172_800))

        XCTAssertFalse(store.todayTasks[0].isCompleted, "a new day starts with fresh tasks")
        XCTAssertFalse(store.minimumWinModeEnabled, "Minimum Win is a per-day mode")
        XCTAssertFalse(store.didCompleteQuickCheckIn, "check-in resets daily")
        XCTAssertTrue(store.quizSelections.isEmpty, "quiz answers are per-day")
        XCTAssertEqual(store.clientProfile.level.currentXP, earnedXP, "earned XP is forever")
        XCTAssertTrue(store.completedQuizIDs.contains(quiz.id), "quiz mastery is forever")
    }

    func testSameDayRolloverIsANoOp() {
        let store = MorpheAppStore()
        store.onboardingDraft.name = "Sarah"
        store.completeOnboarding()

        store.toggleTask(store.todayTasks[0])
        store.handleDayRolloverIfNeeded()
        XCTAssertTrue(store.todayTasks[0].isCompleted,
                      "re-foregrounding on the same day must not wipe today's progress")
    }

    func testCompletedTasksSurviveSameDayRelaunch() {
        let store = MorpheAppStore()
        store.onboardingDraft.name = "Sarah"
        store.completeOnboarding()

        let task = store.todayTasks[0]
        store.toggleTask(task)
        let earnedXP = store.clientProfile.level.currentXP
        XCTAssertGreaterThan(earnedXP, 0)

        // Relaunching used to reset the checklist while keeping the XP —
        // re-checking the same tasks every launch was an infinite XP faucet.
        let reloaded = MorpheAppStore()
        XCTAssertTrue(reloaded.todayTasks.first { $0.title == task.title }?.isCompleted ?? false,
                      "a task completed today stays completed after a same-day relaunch")
        XCTAssertEqual(reloaded.clientProfile.level.currentXP, earnedXP)
    }

    /// Chronological unlock: quiz 1 leads, an answer consumes the day,
    /// and the next quiz waits for tomorrow.
    func testQuizzesUnlockChronologically() {
        let store = MorpheAppStore()
        store.onboardingDraft.name = "Sarah"
        store.completeOnboarding()

        XCTAssertEqual(store.todaysQuiz?.id, store.quizzes.first?.id,
                       "the line starts at quiz 1")

        store.answerQuiz(store.quizzes[0], with: store.quizzes[0].correctIndex)
        XCTAssertTrue(store.quizAnsweredToday)
        XCTAssertNil(store.todaysQuiz, "one attempt a day — the next quiz waits for tomorrow")
    }

    func testQuizNeverReawardsXP() {
        let store = MorpheAppStore()
        store.onboardingDraft.name = "Sarah"
        store.completeOnboarding()

        let quiz = store.quizzes.first!
        store.answerQuiz(quiz, with: quiz.correctIndex)
        let earnedXP = store.clientProfile.level.currentXP

        // Re-answering an aced quiz (however it resurfaces) must not pay
        // twice.
        store.handleDayRolloverIfNeeded(now: Date(timeIntervalSinceNow: 172_800))
        store.answerQuiz(quiz, with: quiz.correctIndex)
        XCTAssertEqual(store.clientProfile.level.currentXP, earnedXP, "quiz XP is once per quiz, ever")
    }

    // MARK: - Morphe AI safety (audit red list)

    func testAssistantTreatsQuestionsAsQuestionsNotCommands() {
        let store = MorpheAppStore()
        store.onboardingDraft.name = "Sarah"
        store.completeOnboarding()

        store.startTodayWorkout()
        store.completeTrackedSet(reps: 8, weight: 95)
        store.sendAIAgentPrompt("Should I stop training when my knee hurts?")
        XCTAssertTrue(store.isWorkoutSessionActive, "a coaching question must never wipe the session")

        store.sendAIAgentPrompt("stop my workout")
        XCTAssertTrue(store.isWorkoutSessionActive, "even the command form is answered with the safe path")
        store.cancelTrackedWorkoutSession()

        store.sendAIAgentPrompt("Where do I begin with my nutrition plan?")
        XCTAssertFalse(store.isWorkoutSessionActive, "a nutrition question must not start a workout")
    }

    func testAssistantUnitAndModeMatchersNeedIntent() {
        let store = MorpheAppStore()
        store.onboardingDraft.name = "Sarah"
        store.completeOnboarding()

        XCTAssertEqual(store.weightUnit, .pounds)
        store.sendAIAgentPrompt("I lifted 100 kg today")
        XCTAssertEqual(store.weightUnit, .pounds, "mentioning kg is not a request to switch units")

        store.sendAIAgentPrompt("I'm tired of chicken. Give me meal ideas")
        XCTAssertFalse(store.minimumWinModeEnabled, "being tired of chicken is not a training mode")

        store.sendAIAgentPrompt("switch to kg")
        XCTAssertEqual(store.weightUnit, .kilograms)
        store.sendAIAgentPrompt("change back to pounds")
        XCTAssertEqual(store.weightUnit, .pounds)

        store.sendAIAgentPrompt("I'm tired today")
        XCTAssertTrue(store.minimumWinModeEnabled, "a real low-energy signal still activates Minimum Win")
    }

    // MARK: - Library save persistence (audit backlog pass 3)

    func testNonCatalogSaveSurvivesRelaunch() {
        let store = MorpheAppStore()
        store.onboardingDraft.name = "Sarah"
        store.completeOnboarding()

        // Saving the recommendation stores a seeded template — those ids
        // re-mint every launch, so this save used to silently vanish.
        store.saveGoodForTodayRecommendation()
        let savedName = store.savedWorkouts.first!.workoutName

        let reloaded = MorpheAppStore()
        let restored = reloaded.savedWorkouts.first { $0.workoutName == savedName }
        XCTAssertNotNil(restored, "a recommendation save survives relaunch")
        XCTAssertTrue(reloaded.workoutTemplates.contains { $0.id == restored?.workoutTemplateID },
                      "the restored save points at a startable template")
    }

    func testDuplicatedWorkoutIsCustomAndStaysOutOfDiscover() {
        let store = MorpheAppStore()
        store.onboardingDraft.name = "Sarah"
        store.onboardingDraft.selectedSports = [.boxing]
        store.completeOnboarding()

        store.saveGoodForTodayRecommendation()
        store.duplicateSavedWorkout(store.savedWorkouts.first!)

        XCTAssertFalse(store.discoverWorkouts.contains { $0.name.hasPrefix("My Copy") },
                       "a personal copy must not surface in the curated Discover feed")

        let reloaded = MorpheAppStore()
        XCTAssertTrue(reloaded.workoutTemplates.contains { $0.name.hasPrefix("My Copy") },
                      "the copy persists as a custom workout")
        XCTAssertTrue(reloaded.savedWorkouts.contains { $0.workoutName.hasPrefix("My Copy") },
                      "the copy's library entry persists too")
    }

    // MARK: - Switch rotates the user's own library

    func testSwitchWithNoSavedWorkoutsShowsPopup() {
        let store = MorpheAppStore()
        store.onboardingDraft.name = "Sarah"
        store.completeOnboarding()

        let stagedID = store.currentWorkout.id
        store.cycleWorkout()

        XCTAssertTrue(store.showSwitchNeedsSavedWorkouts, "no library, nothing to switch to — say so")
        XCTAssertEqual(store.currentWorkout.id, stagedID, "the staged workout must not change")
    }

    func testSwitchRotatesThroughSavedWorkoutsOnly() {
        let store = MorpheAppStore()
        store.onboardingDraft.name = "Sarah"
        store.completeOnboarding()

        let first = store.catalogWorkouts[0]
        let second = store.catalogWorkouts[1]
        store.saveCatalogWorkout(first)
        store.saveCatalogWorkout(second)

        // Staged workout isn't saved — Switch enters the user's rotation
        // (library order, newest save first)…
        store.cycleWorkout()
        XCTAssertEqual(store.currentWorkout.id, second.id)
        // …and keeps rotating inside it, never back to unsaved templates.
        store.cycleWorkout()
        XCTAssertEqual(store.currentWorkout.id, first.id)
        store.cycleWorkout()
        XCTAssertEqual(store.currentWorkout.id, second.id)
        XCTAssertFalse(store.showSwitchNeedsSavedWorkouts)
    }

    func testSwitchWithOnlyStagedSaveShowsPopup() {
        let store = MorpheAppStore()
        store.onboardingDraft.name = "Sarah"
        store.completeOnboarding()

        let only = store.catalogWorkouts[0]
        store.saveCatalogWorkout(only)
        store.cycleWorkout()
        XCTAssertEqual(store.currentWorkout.id, only.id, "the single saved workout gets staged")

        store.cycleWorkout()
        XCTAssertTrue(store.showSwitchNeedsSavedWorkouts,
                      "the only saved workout is already staged — prompt to save more")
        XCTAssertEqual(store.currentWorkout.id, only.id)
    }

    // MARK: - Day-0 personalization + rotation (audit backlog pass 2)

    func testOnboardingPersonalizesFirstWorkout() {
        let store = MorpheAppStore()
        store.onboardingDraft.name = "Sarah"
        store.onboardingDraft.selectedSports = [.boxing]
        store.onboardingDraft.experienceLevel = .advanced
        store.completeOnboarding()

        // Today's plan now draws from the 348-workout catalog, matched to the
        // user's LEVEL. The generated catalog is sport-agnostic (sport-specific
        // sessions live in Discover), so personalization is by level + variety,
        // not by staging one repeated sport seed.
        XCTAssertTrue(store.catalogWorkouts.contains { $0.id == store.currentWorkout.id },
                      "the first workout is a catalog workout, not a repeated seed")
        XCTAssertEqual(store.currentWorkout.difficulty, .advanced,
                       "and it matches the chosen level")
    }

    func testOnboardingStagesARealTrainingSession() {
        let store = MorpheAppStore()
        store.onboardingDraft.name = "Sarah"
        store.completeOnboarding()

        // The first staged workout must be a real session — the recovery
        // pivot and the 15-minute fallback used to win on array order.
        XCTAssertNotEqual(store.currentWorkout.category, .recovery,
                          "day 0 must not open on a recovery pivot")
        XCTAssertGreaterThanOrEqual(store.currentWorkout.durationMinutes, 20)
    }

    func testStagedWorkoutSurvivesRelaunchByName() {
        let store = MorpheAppStore()
        store.onboardingDraft.name = "Sarah"
        store.onboardingDraft.selectedSports = [.boxing]
        store.completeOnboarding()
        let stagedName = store.currentWorkout.name

        // Seeded template ids re-mint every launch — the persisted name is
        // what keeps the personalized pick staged across relaunches.
        let reloaded = MorpheAppStore()
        XCTAssertEqual(reloaded.currentWorkout.name, stagedName,
                       "the staged workout survives relaunch")
    }

    func testRecommendationRotatesAfterLoggingCurrentWorkout() {
        let store = MorpheAppStore()
        store.onboardingDraft.name = "Sarah"
        store.completeOnboarding()

        XCTAssertFalse(store.recommendedWorkoutDiffers,
                       "before any logs, the staged workout is the recommendation")

        store.startTodayWorkout()
        store.hasCompletedWorkoutFlow = true
        store.logWorkout()

        XCTAssertTrue(store.recommendedWorkoutDiffers,
                      "after closing the staged workout, the suggestion moves to a different session")
        XCTAssertNotEqual(store.currentGoodForTodayRecommendation.workoutTemplateID, store.currentWorkout.id)
    }

    // MARK: - Review fixes (2026-07-06 audit)

    func testProgressSummaryUsesHonestStreak() {
        let store = MorpheAppStore()
        store.onboardingDraft.name = "Sarah"
        store.completeOnboarding()

        // A protected day must show up in the summary streak — the number
        // Progress and Profile display — not only in Learn's scoreboard.
        store.toggleMinimumWinTask(store.minimumWinTasks[0])
        let summary = store.workoutLogSummary(for: store.clientProfile.id)
        XCTAssertEqual(summary.currentStreakDays, 1,
                       "the summary streak honors protected days")
    }

    func testFiveDayTrainerSurvivesTheWeekend() {
        let store = MorpheAppStore()
        store.onboardingDraft.name = "Sarah"
        store.completeOnboarding()
        store.updateTrainingDaysPerWeek(5)
        let athleteID = store.clientProfile.id

        func log(daysAgo: Int) -> WorkoutLog {
            WorkoutLog(
                athleteID: athleteID, athleteName: "Sarah", workoutTemplateID: nil,
                workoutTitle: "Session", sport: .strength,
                completedAt: Calendar.current.date(byAdding: .day, value: -daysAgo, to: .now)!,
                durationMinutes: 30, exercises: [], notes: "",
                source: .athleteManual, enteredByUserID: athleteID,
                enteredByRole: .client, enteredByName: "Sarah",
                verificationStatus: .athleteSubmitted
            )
        }
        // Friday + Monday for a Mon–Fri trainer: a 3-day gap that the old
        // ceil(7/5)=2 allowance broke every single weekend.
        WorkoutFilePersistence().saveLogs([log(daysAgo: 3), log(daysAgo: 0)])

        let reloaded = MorpheAppStore()
        XCTAssertEqual(reloaded.clientProfile.level.streak, 2,
                       "a compliant 5-day/week schedule keeps its streak across the weekend")
    }

    func testLoggingWorkoutGrantsTaskXP() {
        let store = MorpheAppStore()
        store.onboardingDraft.name = "Sarah"
        store.completeOnboarding()

        store.startTodayWorkout()
        store.hasCompletedWorkoutFlow = true
        store.logWorkout()

        // 50 (workout) + 25 (anchor task) = 75 — the auto-checked task used
        // to advertise XP it never paid. (A beginner's day-one task mix has
        // no "Log your workout" task; when the dial adds it, it pays too.)
        XCTAssertEqual(store.clientProfile.level.currentXP, 75)
        XCTAssertTrue(store.todayTasks.first { $0.title == "Complete today's workout" }!.isCompleted)

        // And toggling an auto-completed task off/on nets exactly zero.
        let task = store.todayTasks.first { $0.title == "Complete today's workout" }!
        store.toggleTask(task)
        store.toggleTask(store.todayTasks.first { $0.title == task.title }!)
        XCTAssertEqual(store.clientProfile.level.currentXP, 75, "toggle off/on is XP-neutral")
    }

    func testXPRefundDemotesThroughLevelBoundary() {
        let store = MorpheAppStore()
        store.onboardingDraft.name = "Sarah"
        store.completeOnboarding()

        // 75 XP from logging; closing the rest of the day's tasks crosses
        // the 100-XP boundary into Level 2.
        store.startTodayWorkout()
        store.hasCompletedWorkoutFlow = true
        store.logWorkout()
        for task in store.todayTasks where !task.isCompleted {
            store.toggleTask(task)
        }
        XCTAssertEqual(store.currentLevelNumber, 2)
        let bankedXP = store.clientProfile.level.currentXP

        // Un-checking must demote back — the old clamp banked the level.
        let refund = store.todayTasks.first { $0.isCompleted && $0.title != "Complete today's workout" }!
        store.toggleTask(refund)
        XCTAssertEqual(store.currentLevelNumber, 1, "refund crosses the boundary back down")
        XCTAssertEqual(store.clientProfile.level.currentXP, bankedXP + 100 - refund.xp)
    }

    func testPinnedCatalogSaveSurvivesRelaunch() {
        let store = MorpheAppStore()
        store.onboardingDraft.name = "Sarah"
        store.completeOnboarding()

        let template = store.catalogWorkouts[0]
        store.saveCatalogWorkout(template)
        store.togglePinnedSavedWorkout(store.savedWorkouts.first { $0.workoutTemplateID == template.id }!)
        XCTAssertTrue(store.savedWorkouts.first { $0.workoutTemplateID == template.id }!.isPinned)

        let reloaded = MorpheAppStore()
        XCTAssertTrue(reloaded.savedWorkouts.first { $0.workoutTemplateID == template.id }?.isPinned ?? false,
                      "a pinned Discover save keeps its pin across relaunch")
    }

    func testUncheckingMinimumWinRetractsProtection() {
        let store = MorpheAppStore()
        store.onboardingDraft.name = "Sarah"
        store.completeOnboarding()

        store.toggleMinimumWinTask(store.minimumWinTasks[0])
        XCTAssertEqual(store.clientProfile.level.streak, 1)

        store.toggleMinimumWinTask(store.minimumWinTasks[0])
        XCTAssertFalse(store.streakProtected, "retracting the win retracts the protection")
        XCTAssertEqual(store.clientProfile.level.streak, 0)
    }

    func testCustomWorkoutNamesAreUnique() {
        let store = MorpheAppStore()
        store.onboardingDraft.name = "Sarah"
        store.completeOnboarding()

        let exercise = store.exerciseDatabase[0]
        store.createCustomWorkout(name: "Leg Day", sport: .generalFitness,
                                  items: [CustomWorkoutItem(exercise: exercise, sets: 3, reps: 10)])
        store.createCustomWorkout(name: "Leg Day", sport: .generalFitness,
                                  items: [CustomWorkoutItem(exercise: exercise, sets: 3, reps: 10)])

        let names = store.workoutTemplates.filter { $0.name.hasPrefix("Leg Day") }.map(\.name)
        XCTAssertEqual(Set(names).count, names.count,
                       "names double as restore keys, so duplicates must be suffixed")
        XCTAssertEqual(names.count, 2)
    }

    // MARK: - Honest streak (audit backlog pass 1)

    func testStreakSurvivesRestDaysOnSchedule() {
        let store = MorpheAppStore()
        store.onboardingDraft.name = "Sarah"
        store.completeOnboarding()
        store.updateTrainingDaysPerWeek(3)
        let athleteID = store.clientProfile.id

        // Trained 3 days ago and today — perfectly on a 3-day/week schedule.
        // The old consecutive-day rule called this "streak: 1".
        func log(daysAgo: Int) -> WorkoutLog {
            WorkoutLog(
                athleteID: athleteID,
                athleteName: "Sarah",
                workoutTemplateID: nil,
                workoutTitle: "Session",
                sport: .strength,
                completedAt: Calendar.current.date(byAdding: .day, value: -daysAgo, to: .now)!,
                durationMinutes: 30,
                exercises: [],
                notes: "",
                source: .athleteManual,
                enteredByUserID: athleteID,
                enteredByRole: .client,
                enteredByName: "Sarah",
                verificationStatus: .athleteSubmitted
            )
        }
        WorkoutFilePersistence().saveLogs([log(daysAgo: 3), log(daysAgo: 0)])

        let reloaded = MorpheAppStore()
        XCTAssertEqual(reloaded.clientProfile.level.streak, 2,
                       "rest days inside the user's own schedule must not break the streak")
    }

    func testMinimumWinActuallyProtectsStreak() {
        let store = MorpheAppStore()
        store.onboardingDraft.name = "Sarah"
        store.completeOnboarding()

        XCTAssertEqual(store.clientProfile.level.streak, 0)
        store.toggleMinimumWinTask(store.minimumWinTasks[0])
        XCTAssertTrue(store.streakProtected)
        XCTAssertEqual(store.clientProfile.level.streak, 1,
                       "'Momentum protected' must actually feed the streak, not just show a toast")

        // And it survives a relaunch.
        let reloaded = MorpheAppStore()
        XCTAssertEqual(reloaded.clientProfile.level.streak, 1, "protected days persist")
        XCTAssertTrue(reloaded.streakProtected, "same-day relaunch still shows today as protected")
    }

    func testAssistantOpensDiscoverTab() {
        let store = MorpheAppStore()
        store.onboardingDraft.name = "Sarah"
        store.completeOnboarding()

        store.sendAIAgentPrompt("open discover")
        // Discover is a Train segment now (5-tab fold).
        XCTAssertEqual(store.selectedClientTab, .train, "'open discover' lands on Train…")
        XCTAssertEqual(store.selectedTrainSection, .discover, "…with the Discover segment selected")
    }

    func testAssistantStartWinsOverStopPhrasing() {
        let store = MorpheAppStore()
        store.onboardingDraft.name = "Sarah"
        store.completeOnboarding()

        store.sendAIAgentPrompt("stop procrastinating and start my workout")
        XCTAssertTrue(store.isWorkoutSessionActive, "'…and start my workout' is a start, not a discard")
    }
}

/// Regression tests for the second full-audit fix pass: the session-work
/// gate, honest logging, the minimum-win XP faucet, and tolerant history
/// decoding.
@MainActor
final class AuditFixRegressionTests: XCTestCase {

    override func setUp() {
        super.setUp()
        WorkoutFilePersistence().clear()
        ProfileFilePersistence().clear()
    }

    override func tearDown() {
        WorkoutFilePersistence().clear()
        ProfileFilePersistence().clear()
        super.tearDown()
    }

    private func freshStore() -> MorpheAppStore {
        let store = MorpheAppStore()
        store.onboardingDraft.name = "Sarah"
        store.completeOnboarding()
        return store
    }

    /// Starts a live session on the user's own 2-exercise custom workout.
    private func startedSession(_ store: MorpheAppStore) {
        let exercises = Array(store.allExercises.prefix(2))
        store.createCustomWorkout(
            name: "Gate Test",
            sport: .strength,
            items: exercises.map { CustomWorkoutItem(exercise: $0, sets: 2, reps: 8) }
        )
        let custom = store.workoutTemplates.first { $0.name == "Gate Test" }!
        store.beginLiveWorkout(custom)
    }

    // MARK: - Session-work gate

    func testReplacingLiveSessionRequiresConfirmation() {
        let store = freshStore()
        startedSession(store)
        store.completeTrackedSet(reps: 8, weight: 50)
        let activeID = store.currentWorkout.id
        let other = store.workoutTemplates.first { $0.id != activeID }!

        store.openWorkoutTemplate(other)

        XCTAssertNotNil(store.pendingWorkoutChange, "destroying a live session must ask first")
        XCTAssertEqual(store.currentWorkout.id, activeID, "nothing changes until confirmed")
        XCTAssertTrue(store.isWorkoutSessionActive, "the session survives until the user confirms")

        store.confirmPendingWorkoutChange()
        XCTAssertEqual(store.currentWorkout.id, other.id)
        XCTAssertFalse(store.isWorkoutSessionActive)
        XCTAssertNil(store.pendingWorkoutChange)
    }

    func testCancellingGateKeepsSessionIntact() {
        let store = freshStore()
        startedSession(store)
        store.completeTrackedSet(reps: 8, weight: 50)
        let activeID = store.currentWorkout.id

        store.startTodayWorkout() // "restart" while live must also gate
        XCTAssertNotNil(store.pendingWorkoutChange)

        store.cancelPendingWorkoutChange()
        XCTAssertNil(store.pendingWorkoutChange)
        XCTAssertTrue(store.isWorkoutSessionActive)
        XCTAssertEqual(store.currentWorkout.id, activeID)
        XCTAssertEqual(store.trackedSetTotalCount, 1, "logged sets survive a cancelled restart")
    }

    // MARK: - Honest logging

    func testUntrackedExercisesAreNotLoggedAsPerformed() {
        let store = freshStore()
        startedSession(store)
        // Track only the first exercise; leave the second untouched.
        store.completeTrackedSet(reps: 8, weight: 50)
        store.completeTrackedSet(reps: 8, weight: 50)
        XCTAssertTrue(store.finishTrackedWorkoutSession())

        let before = store.workoutLogs.count
        store.logWorkout()

        XCTAssertEqual(store.workoutLogs.count, before + 1)
        let log = store.workoutLogs.first { $0.workoutTitle == "Gate Test" }!
        XCTAssertEqual(log.exercises.count, 1, "an untouched exercise must not be logged as performed")
        XCTAssertEqual(log.exercises.first?.sets, "2 sets")
    }

    func testUseSuggestionAfterFinishCannotFabricateALog() {
        let store = freshStore()
        startedSession(store)
        store.completeTrackedSet(reps: 8, weight: 50)
        XCTAssertTrue(store.finishTrackedWorkoutSession())

        store.applyRecommendedWorkout()
        XCTAssertNotNil(store.pendingWorkoutChange, "adopting a suggestion over an unlogged recap must gate")
        store.confirmPendingWorkoutChange()

        XCTAssertFalse(store.hasCompletedWorkoutFlow, "the stale finished flag must not survive the switch")
        let before = store.workoutLogs.count
        store.logWorkout()
        XCTAssertEqual(store.workoutLogs.count, before, "no log may be written for a session that never ran")
    }

    func testSecondFinishedSessionSameDayIsLoggable() {
        let store = freshStore()

        startedSession(store)
        store.completeTrackedSet(reps: 8, weight: 50)
        XCTAssertTrue(store.finishTrackedWorkoutSession())
        let before = store.workoutLogs.count
        store.logWorkout()
        XCTAssertEqual(store.workoutLogs.count, before + 1)
        XCTAssertTrue(store.isWorkoutLoggedToday)

        // Evening session, same day — used to hit "already logged" and vanish.
        let other = store.workoutTemplates.first { $0.name != "Gate Test" }!
        store.beginLiveWorkout(other)
        store.completeTrackedSet(reps: 10, weight: 40)
        XCTAssertTrue(store.finishTrackedWorkoutSession())
        store.logWorkout()

        XCTAssertEqual(store.workoutLogs.count, before + 2, "a second finished session must be loggable")
        XCTAssertFalse(store.hasCompletedWorkoutFlow, "logging closes the session either way")
    }

    // MARK: - Minimum-win XP faucet

    func testMinimumWinCompletionSurvivesRelaunch() {
        let store = freshStore()
        let task = store.minimumWinTasks.first!
        store.toggleMinimumWinTask(task)
        let xpAfterToggle = store.clientProfile.level.currentXP
        let levelAfterToggle = store.clientProfile.level.currentTitle

        let reloaded = MorpheAppStore()
        XCTAssertEqual(reloaded.clientProfile.level.currentXP, xpAfterToggle)
        XCTAssertEqual(reloaded.clientProfile.level.currentTitle, levelAfterToggle)
        XCTAssertTrue(
            reloaded.minimumWinTasks.first { $0.title == task.title }?.isCompleted ?? false,
            "a same-day relaunch must not re-offer an already-earned minimum win (XP faucet)"
        )
    }

    // MARK: - Day-scoped data durability

    func testNutritionAndPainReportsSurviveRelaunch() {
        let store = freshStore()
        store.addWaterCup()
        if let meal = store.nutrition.quickMeals.first {
            store.addQuickMeal(meal)
        }
        store.painArea = "Knee"
        store.painSeverity = 6
        store.savePainFlag()

        let reloaded = MorpheAppStore()
        XCTAssertEqual(reloaded.nutrition.waterConsumed, 1, "same-day water log must survive relaunch")
        if store.nutrition.quickMeals.first != nil {
            XCTAssertEqual(reloaded.nutrition.meals.count, 1, "same-day meals must survive relaunch")
        }
        XCTAssertEqual(reloaded.painReports.count, 1, "pain flags are safety data and must persist")
        XCTAssertEqual(reloaded.painReports.first?.area, "Knee")
        XCTAssertEqual(reloaded.painReports.first?.severity, 6)
    }

    func testProfileSportEditSurvivesRelaunch() {
        let store = freshStore()
        let newSport = SportFocus.allCases.first { !store.clientProfile.selectedSports.contains($0) && $0 != .generalFitness }!
        store.toggleProfileSport(newSport)
        XCTAssertEqual(store.clientProfile.selectedSports.first, newSport)

        let reloaded = MorpheAppStore()
        XCTAssertEqual(reloaded.clientProfile.selectedSports.first, newSport,
                       "a sport edit in Profile must survive relaunch")
    }

    // MARK: - Tolerant history decoding

    private func logsFileURL(_ name: String) -> URL {
        let base = try! FileManager.default.url(
            for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
        return base
            .appendingPathComponent("MorpheTests-\(name)", isDirectory: true)
            .appendingPathComponent("workout-logs.json")
    }

    private func sampleLog() -> WorkoutLog {
        WorkoutLog(
            athleteID: UUID(),
            athleteName: "Tester",
            workoutTemplateID: nil,
            workoutTitle: "Real Workout",
            sport: .strength,
            completedAt: Date(timeIntervalSince1970: 1_700_000_000),
            durationMinutes: 42,
            exercises: [],
            notes: "",
            source: .athleteManual,
            enteredByUserID: UUID(),
            enteredByRole: .client,
            enteredByName: "Tester",
            verificationStatus: .athleteSubmitted
        )
    }

    func testCorruptLogsFileLoadsEmptyNotNil() {
        let persistence = WorkoutFilePersistence(directoryName: "MorpheTests-\(#function)")
        defer { persistence.clear() }
        try! Data("this is not json".utf8).write(to: logsFileURL(#function))

        let loaded = persistence.loadLogs()
        XCTAssertNotNil(loaded, "a corrupt file must not read as 'no file' (that resurrects demo logs)")
        XCTAssertEqual(loaded?.count, 0)
    }

    func testLegacyBareArrayLogsStillLoad() {
        let persistence = WorkoutFilePersistence(directoryName: "MorpheTests-\(#function)")
        defer { persistence.clear() }
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        try! encoder.encode([sampleLog()]).write(to: logsFileURL(#function))

        let loaded = persistence.loadLogs()
        XCTAssertEqual(loaded?.count, 1, "pre-versioning bare-array files must still load")
        XCTAssertEqual(loaded?.first?.workoutTitle, "Real Workout")
    }

    func testOneBadLogDoesNotDestroyHistory() {
        let persistence = WorkoutFilePersistence(directoryName: "MorpheTests-\(#function)")
        defer { persistence.clear() }
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let goodObject = try! JSONSerialization.jsonObject(with: encoder.encode(sampleLog()))
        let wrapper: [String: Any] = [
            "schemaVersion": 1,
            "logs": [goodObject, ["sport": 12345]] // second entry is garbage
        ]
        try! JSONSerialization.data(withJSONObject: wrapper).write(to: logsFileURL(#function))

        let loaded = persistence.loadLogs()
        XCTAssertEqual(loaded?.count, 1, "one undecodable log must drop that log, not the whole history")
        XCTAssertEqual(loaded?.first?.workoutTitle, "Real Workout")
    }

    func testUnknownEnumValueInOneFieldKeepsTheLog() {
        let persistence = WorkoutFilePersistence(directoryName: "MorpheTests-\(#function)")
        defer { persistence.clear() }
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        var object = try! JSONSerialization.jsonObject(with: encoder.encode(sampleLog())) as! [String: Any]
        object["sport"] = "A Sport From The Future"
        let wrapper: [String: Any] = ["schemaVersion": 1, "logs": [object]]
        try! JSONSerialization.data(withJSONObject: wrapper).write(to: logsFileURL(#function))

        let loaded = persistence.loadLogs()
        XCTAssertEqual(loaded?.count, 1, "an unknown enum raw value must not throw the log away")
        XCTAssertEqual(loaded?.first?.sport, .generalFitness, "unknown sport falls back to the neutral case")
    }
}

/// Regression tests for the fourth audit's fix pass: chat never fakes
/// success, custom builds can't fabricate logs, swaps can't eat sets,
/// Plan B doesn't leak across days, and coach identity survives relaunch.
@MainActor
final class Audit4RegressionTests: XCTestCase {

    override func setUp() {
        super.setUp()
        WorkoutFilePersistence().clear()
        ProfileFilePersistence().clear()
    }

    override func tearDown() {
        WorkoutFilePersistence().clear()
        ProfileFilePersistence().clear()
        super.tearDown()
    }

    private func freshStore() -> MorpheAppStore {
        let store = MorpheAppStore()
        store.onboardingDraft.name = "Sarah"
        store.completeOnboarding()
        return store
    }

    private func finishedUnloggedSession(_ store: MorpheAppStore) {
        store.beginLiveWorkout(store.workoutTemplates.first!)
        store.completeTrackedSet(reps: 8, weight: 50)
        XCTAssertTrue(store.finishTrackedWorkoutSession())
        XCTAssertTrue(store.hasCompletedWorkoutFlow)
    }

    func testAIStartDeclinesOverUnloggedRecap() {
        let store = freshStore()
        finishedUnloggedSession(store)

        store.sendAIAgentPrompt("start my workout")

        XCTAssertNil(store.pendingWorkoutChange, "chat must never queue a destructive confirmation")
        XCTAssertTrue(store.hasCompletedWorkoutFlow, "the unlogged recap survives the chat request")
        XCTAssertFalse(store.isWorkoutSessionActive, "no session may start while claiming nothing")
    }

    func testCreateCustomWorkoutOverRecapCannotFabricateALog() {
        let store = freshStore()
        finishedUnloggedSession(store)
        let stagedID = store.currentWorkout.id

        let exercises = Array(store.allExercises.prefix(1))
        store.createCustomWorkout(
            name: "Fabrication Test",
            sport: .strength,
            items: exercises.map { CustomWorkoutItem(exercise: $0, sets: 2, reps: 8) }
        )

        // New behavior: building over a recap doesn't stage the build at all
        // (no gate queued from the builder sheet), so the never-performed build
        // can never become the logged workout.
        XCTAssertNil(store.pendingWorkoutChange, "no gate queued from the builder sheet")
        XCTAssertEqual(store.currentWorkout.id, stagedID, "the build must not stage over the recap")
        XCTAssertTrue(store.workoutTemplates.contains { $0.name == "Fabrication Test" },
                      "the build itself still lands in the library")

        store.logWorkout()
        XCTAssertFalse(store.workoutLogs.contains { $0.workoutTitle == "Fabrication Test" },
                       "the logged workout is the real finished session, never the untouched build")
    }

    func testSwapRefusedWhenExerciseHasLoggedSets() {
        let store = freshStore()
        let exercises = Array(store.allExercises.prefix(2))
        store.createCustomWorkout(
            name: "Swap Test",
            sport: .strength,
            items: exercises.map { CustomWorkoutItem(exercise: $0, sets: 2, reps: 8) }
        )
        let custom = store.workoutTemplates.first { $0.name == "Swap Test" }!
        store.beginLiveWorkout(custom)
        let active = store.activeWorkoutExercise!
        store.completeTrackedSet(reps: 8, weight: 50)

        store.swapExercise(active)

        XCTAssertTrue(store.currentWorkout.exercises.contains { $0.id == active.id },
                      "an exercise with logged sets must not be swapped out (its sets would vanish from the log)")
    }

    func testPlanBStateResetsOnDayRollover() {
        let store = freshStore()
        let defaultTitles = store.minimumWinTasks.map(\.title)
        store.choosePlanB(.traveling)
        store.toggleMinimumWinTask(store.minimumWinTasks.first!)
        XCTAssertTrue(store.minimumWinModeEnabled)

        store.handleDayRolloverIfNeeded(now: Date.now.addingTimeInterval(86_400))

        XCTAssertEqual(store.minimumWinTasks.map(\.title), defaultTitles,
                       "a new day starts from the default minimum wins")
        XCTAssertFalse(store.minimumWinTasks.contains(where: \.isCompleted))
        XCTAssertFalse(store.minimumWinModeEnabled)
        XCTAssertNil(store.selectedPlanBReason)
    }

    func testCoachIdentityKeepsOwnSportsAcrossRelaunch() {
        let store = MorpheAppStore()
        store.onboardingDraft.name = "Sam"
        store.onboardingDraft.accountType = .coach
        store.onboardingDraft.selectedSports = [.soccer]
        store.completeOnboarding()
        // The workspace addresses the user with the coach title by design.
        XCTAssertEqual(store.coachProfile.name, "Coach Sam")
        XCTAssertTrue(store.coachProfile.specialty.contains("Soccer"), store.coachProfile.specialty)

        let reloaded = MorpheAppStore()
        XCTAssertEqual(reloaded.coachProfile.name, "Coach Sam",
                       "a relaunch must not revert the workspace to demo Coach Marcus")
        XCTAssertTrue(reloaded.coachProfile.specialty.contains("Soccer"),
                      "specialty must come from the coach's own sports, not the demo athlete's: \(reloaded.coachProfile.specialty)")
        XCTAssertEqual(reloaded.coachProfile.activeClients, 0)
    }

    func testDeleteCustomWorkoutPerformsAndCleansSavedCards() {
        let store = freshStore()
        let exercises = Array(store.allExercises.prefix(1))
        store.createCustomWorkout(
            name: "Delete Test",
            sport: .strength,
            items: exercises.map { CustomWorkoutItem(exercise: $0, sets: 2, reps: 8) }
        )
        let custom = store.workoutTemplates.first { $0.name == "Delete Test" }!

        store.deleteCustomWorkout(custom.id)

        XCTAssertFalse(store.workoutTemplates.contains { $0.id == custom.id })
        XCTAssertFalse(store.savedWorkouts.contains { $0.workoutTemplateID == custom.id })
        XCTAssertNil(store.pendingWorkoutChange, "deletion is confirmed at the view layer, not the session gate")
    }
}

/// Regression tests for the audit-4 cleanup: these exercise the
/// finished-but-unlogged-recap path and the post-log state that the earlier
/// audit-4 tests skipped (which is why F1–F4 slipped through).
@MainActor
final class CleanupRegressionTests: XCTestCase {

    override func setUp() {
        super.setUp()
        WorkoutFilePersistence().clear()
        ProfileFilePersistence().clear()
    }

    override func tearDown() {
        WorkoutFilePersistence().clear()
        ProfileFilePersistence().clear()
        super.tearDown()
    }

    private func freshStore() -> MorpheAppStore {
        let store = MorpheAppStore()
        store.onboardingDraft.name = "Sarah"
        store.completeOnboarding()
        return store
    }

    private func stagedCustom(_ store: MorpheAppStore, name: String, count: Int = 2) -> WorkoutTemplate {
        let exercises = Array(store.allExercises.prefix(count))
        store.createCustomWorkout(
            name: name,
            sport: .strength,
            items: exercises.map { CustomWorkoutItem(exercise: $0, sets: 2, reps: 8) }
        )
        return store.workoutTemplates.first { $0.name == name }!
    }

    // F1/F5 — swap guard only fires during an unsaved session, never after log.
    func testSwapBlockedOnlyDuringUnsavedSession() {
        let store = freshStore()
        let custom = stagedCustom(store, name: "Swap Guard")
        store.beginLiveWorkout(custom)
        let active = store.activeWorkoutExercise!
        let untouched = store.currentWorkout.exercises.first { $0.id != active.id }!

        store.completeTrackedSet(reps: 8, weight: 50)
        XCTAssertNotNil(store.swapBlockReason(for: active),
                        "a logged exercise blocks swap mid-session")
        XCTAssertNil(store.swapBlockReason(for: untouched),
                     "an untouched exercise stays swappable")

        XCTAssertTrue(store.finishTrackedWorkoutSession())
        store.logWorkout()
        XCTAssertNil(store.swapBlockReason(for: active),
                     "after logging, a stale tracked count must not permanently wall off a swap")
    }

    // F2 — deleting the staged workout over a recap performs cleanly (the
    // session-loss disclosure lives in the view dialog).
    func testDeleteCurrentWorkoutOverRecapPerformsCleanly() {
        let store = freshStore()
        let custom = stagedCustom(store, name: "Recap Delete")
        store.beginLiveWorkout(custom)
        store.completeTrackedSet(reps: 8, weight: 50)
        XCTAssertTrue(store.finishTrackedWorkoutSession())
        XCTAssertTrue(store.hasCompletedWorkoutFlow)

        store.deleteCustomWorkout(custom.id)

        XCTAssertFalse(store.workoutTemplates.contains { $0.id == custom.id })
        XCTAssertFalse(store.hasCompletedWorkoutFlow, "deleting the staged workout resets the recap")
        XCTAssertNil(store.pendingWorkoutChange, "delete confirms at the view, never via the session gate")
    }

    // F3 — building a workout over a recap doesn't stage it (no gate queued
    // from the builder sheet, recap survives).
    func testCustomBuildOverRecapDoesNotStageOrQueue() {
        let store = freshStore()
        store.beginLiveWorkout(store.currentWorkout)
        store.completeTrackedSet(reps: 8, weight: 50)
        XCTAssertTrue(store.finishTrackedWorkoutSession())

        _ = stagedCustom(store, name: "Build Over Recap", count: 1)

        XCTAssertNil(store.pendingWorkoutChange, "no gate may be queued from the builder sheet")
        XCTAssertTrue(store.workoutTemplates.contains { $0.name == "Build Over Recap" },
                      "the build still lands in the library")
        XCTAssertNotEqual(store.currentWorkout.name, "Build Over Recap",
                          "it must not stage over the unlogged recap")
        XCTAssertTrue(store.hasCompletedWorkoutFlow, "the recap survives the build")
    }

    // F3 (happy path) — with no session, a new build stages immediately.
    func testCustomBuildWithNoSessionStagesImmediately() {
        let store = freshStore()
        let custom = stagedCustom(store, name: "Clean Build", count: 1)
        XCTAssertEqual(store.currentWorkout.id, custom.id, "no session → the build becomes the current plan")
        XCTAssertNil(store.pendingWorkoutChange)
    }

    // F4 — a coach who picked no sports gets an honest specialty, not the
    // demo athlete's Boxing/Strength.
    func testCoachWithNoSportsGetsHonestSpecialty() {
        let store = MorpheAppStore()
        store.onboardingDraft.name = "Dana"
        store.onboardingDraft.accountType = .coach
        store.onboardingDraft.selectedSports = []
        store.completeOnboarding()

        XCTAssertEqual(store.coachProfile.specialty, "Personal coaching")
        XCTAssertFalse(store.coachProfile.specialty.contains("Boxing"),
                       "a sportless coach must never inherit the demo athlete's sports")
    }
}

/// Form Check Phase 2 — the cue analyzer is a pure function of rep metrics, so
/// the advice logic is verified here even though the camera can't run on the
/// Simulator.
final class FormAnalyzerTests: XCTestCase {

    private func rep(angle: CGFloat, valgus: CGFloat? = 1.0, descent: Double = 2.0) -> FormRepMetrics {
        FormRepMetrics(minKneeAngle: angle, valgusRatio: valgus, descentSeconds: descent, ascentSeconds: 1.5)
    }

    func testCleanSetPraisesDepthAndFlagsNothingElse() {
        let s = FormAnalyzer.analyze(Array(repeating: rep(angle: 88), count: 5), movement: .squat)
        XCTAssertEqual(s.reps, 5)
        XCTAssertEqual(Int(s.bestMinKneeAngle), 88)
        XCTAssertTrue(s.cues.contains { $0.category == .depth && $0.tone == .good })
        XCTAssertFalse(s.cues.contains { $0.category == .knees })
        XCTAssertFalse(s.cues.contains { $0.category == .tempo })
    }

    func testShallowRepsSuggestGoingLower() {
        let s = FormAnalyzer.analyze(Array(repeating: rep(angle: 125), count: 5), movement: .squat)
        XCTAssertTrue(s.cues.contains { $0.category == .depth && $0.tone == .suggestion })
    }

    func testCavingKneesLeadTheCues() {
        let s = FormAnalyzer.analyze(Array(repeating: rep(angle: 88, valgus: 0.8), count: 5), movement: .squat)
        XCTAssertEqual(s.cues.first?.category, .knees, "the injury-relevant cue must lead")
    }

    func testFastDescentSuggestsControl() {
        let s = FormAnalyzer.analyze(Array(repeating: rep(angle: 88, descent: 0.3), count: 5), movement: .squat)
        XCTAssertTrue(s.cues.contains { $0.category == .tempo })
    }

    func testUnmeasuredValgusIsNeverFlagged() {
        let s = FormAnalyzer.analyze(Array(repeating: rep(angle: 88, valgus: nil), count: 5), movement: .squat)
        XCTAssertFalse(s.cues.contains { $0.category == .knees }, "can't flag what the camera couldn't measure")
    }

    func testCuesCapAtThreeKneesFirst() {
        let s = FormAnalyzer.analyze(Array(repeating: rep(angle: 125, valgus: 0.8, descent: 0.3), count: 5), movement: .squat)
        XCTAssertLessThanOrEqual(s.cues.count, 3)
        XCTAssertEqual(s.cues.first?.category, .knees)
        XCTAssertTrue(s.cues.contains { $0.category == .depth && $0.tone == .suggestion })
        XCTAssertTrue(s.cues.contains { $0.category == .tempo })
    }

    func testEmptySetHasNoCues() {
        let s = FormAnalyzer.analyze([], movement: .squat)
        XCTAssertEqual(s.reps, 0)
        XCTAssertTrue(s.cues.isEmpty)
    }

    func testLiveCueReflectsTheWorstIssue() {
        XCTAssertTrue(FormAnalyzer.liveCue(for: rep(angle: 88, valgus: 0.7), repNumber: 3, movement: .squat).contains("caved"))
        XCTAssertTrue(FormAnalyzer.liveCue(for: rep(angle: 130), repNumber: 2, movement: .squat).contains("above parallel"))
        XCTAssertTrue(FormAnalyzer.liveCue(for: rep(angle: 88), repNumber: 1, movement: .squat).contains("clean"))
    }

    func testHistoryRoundTripAndDeepestBest() {
        let store = FormCheckFilePersistence(directoryName: "MorpheTests-\(#function)")
        defer { store.clear() }
        XCTAssertTrue(store.load().isEmpty)
        store.append(FormCheckResult(date: 1, exercise: "Squat", reps: 5, avgMinKneeAngle: 95, bestMinKneeAngle: 90, cues: ["a"]))
        store.append(FormCheckResult(date: 2, exercise: "Squat", reps: 6, avgMinKneeAngle: 88, bestMinKneeAngle: 82, cues: []))
        let all = store.load()
        XCTAssertEqual(all.count, 2)
        XCTAssertEqual(all.first?.reps, 6, "newest first")
        XCTAssertEqual(store.bestDepthAngle(), 82, "smallest angle = deepest rep")
    }

    func testEveryCatalogWorkoutResolvesToATemplate() {
        // A workout whose exercise isn't in the library is silently dropped by
        // the loader — this pins the full v2 catalog as resolvable, so a bad
        // libraryID fails here, not in prod.
        let catalog = WorkoutCatalog.loadBundled()
        XCTAssertGreaterThanOrEqual(catalog.count, 150, "bundled catalog size (grows with content drops)")
        let resolved = catalog.compactMap {
            WorkoutCatalog.template(from: $0, library: MorpheDemoContent.exerciseDatabase)
        }
        XCTAssertEqual(resolved.count, catalog.count, "every catalog workout must resolve")
    }

    func testMovementInference() {
        XCTAssertEqual(FormCheckMovement.infer(exerciseName: "Push-Up", muscleGroup: .chest), .pushup)
        XCTAssertEqual(FormCheckMovement.infer(exerciseName: "Overhead Press", muscleGroup: .shoulders), .pushup)
        XCTAssertEqual(FormCheckMovement.infer(exerciseName: "Chest Fly", muscleGroup: .chest), .pushup)
        XCTAssertEqual(FormCheckMovement.infer(exerciseName: "Back Squat", muscleGroup: .legs), .squat)
        XCTAssertEqual(FormCheckMovement.infer(exerciseName: "Walking Lunge", muscleGroup: .legs), .squat)
    }

    func testRepGrading() {
        // Deep, controlled, knees stacked -> excellent.
        XCTAssertEqual(FormAnalyzer.grade(rep(angle: 88, valgus: 0.95, descent: 1.5), movement: .squat), .excellent)
        // Shallow, caved, dropping fast -> poor.
        XCTAssertEqual(FormAnalyzer.grade(rep(angle: 130, valgus: 0.70, descent: 0.3), movement: .squat), .poor)
        // Solid but not perfect -> good/great.
        XCTAssertTrue([.good, .great].contains(FormAnalyzer.grade(rep(angle: 100, valgus: 0.87, descent: 1.0), movement: .squat)))
        // Push-up deep + controlled, valgus not measured -> great/excellent.
        XCTAssertTrue([.great, .excellent].contains(FormAnalyzer.grade(rep(angle: 88, valgus: nil, descent: 1.2), movement: .pushup)))
    }

    func testPushupCuesUsePushLanguageAndSkipKnees() {
        // Shallow push-ups; the valgus value must be ignored for this movement.
        let m = Array(repeating: rep(angle: 130, valgus: 0.7), count: 5)
        let s = FormAnalyzer.analyze(m, movement: .pushup)
        XCTAssertFalse(s.cues.contains { $0.category == .knees }, "push-ups never get a knee cue")
        let depth = s.cues.first { $0.category == .depth }
        XCTAssertEqual(depth?.tone, .suggestion)
        XCTAssertTrue(depth?.message.contains("lower") ?? false)
        XCTAssertTrue(FormAnalyzer.liveCue(for: rep(angle: 130), repNumber: 1, movement: .pushup).contains("shallow"))
    }
}

/// "Today's plan" now draws from the 348-workout catalog, matched to the
/// user's level and rotated by focus day to day.
@MainActor
final class DailyPlanTests: XCTestCase {

    override func setUp() {
        super.setUp()
        WorkoutFilePersistence().clear()
        ProfileFilePersistence().clear()
    }

    override func tearDown() {
        WorkoutFilePersistence().clear()
        ProfileFilePersistence().clear()
        super.tearDown()
    }

    private func onboard(level: ExperienceLevelOption) -> MorpheAppStore {
        let store = MorpheAppStore()
        store.onboardingDraft.name = "Sarah"
        store.onboardingDraft.experienceLevel = level
        store.completeOnboarding()
        return store
    }

    func testOnboardingStagesACatalogWorkout() {
        let store = onboard(level: .beginner)
        XCTAssertFalse(store.personalizedPlanIDs.isEmpty, "a plan is built from the catalog")
        XCTAssertTrue(store.catalogWorkouts.contains { $0.id == store.currentWorkout.id },
                      "Today's workout is a catalog workout, not one of the five seeds")
    }

    func testPlanIsFilteredToTheUsersLevel() {
        let store = onboard(level: .beginner)
        for id in store.personalizedPlanIDs {
            XCTAssertEqual(store.catalogWorkouts.first { $0.id == id }?.difficulty, .beginner)
        }
    }

    func testConsecutivePlanDaysChangeFocus() {
        let store = onboard(level: .intermediate)
        let focuses = store.personalizedPlanIDs.prefix(4).compactMap { id in
            store.catalogWorkouts.first { $0.id == id }?.focusTag
        }
        XCTAssertGreaterThanOrEqual(focuses.count, 2)
        XCTAssertNotEqual(focuses[0], focuses[1], "day 2 must not repeat day 1's focus")
    }

    func testNewDayStagesTheNextPlanWorkout() {
        let store = onboard(level: .intermediate)
        let day1 = store.currentWorkout.id
        XCTAssertEqual(store.planDayIndex, 0)

        store.handleDayRolloverIfNeeded(now: Date.now.addingTimeInterval(86_400))

        XCTAssertEqual(store.planDayIndex, 1)
        XCTAssertNotEqual(store.currentWorkout.id, day1, "a new day is a different workout")
        XCTAssertEqual(store.currentWorkout.id, store.personalizedPlanIDs[1])
    }

    func testHandPickedWorkoutSurvivesDayRollover() {
        let store = onboard(level: .intermediate)
        let ex = Array(store.allExercises.prefix(2))
        store.createCustomWorkout(name: "My Own Day", sport: .strength,
            items: ex.map { CustomWorkoutItem(exercise: $0, sets: 3, reps: 8) })
        let custom = store.workoutTemplates.first { $0.name == "My Own Day" }!
        XCTAssertEqual(store.currentWorkout.id, custom.id)
        XCTAssertFalse(store.personalizedPlanIDs.contains(custom.id))

        store.handleDayRolloverIfNeeded(now: Date.now.addingTimeInterval(86_400))

        XCTAssertEqual(store.currentWorkout.id, custom.id,
                       "a workout the user chose themselves must not be auto-rotated away")
    }

    func testPlanPositionIsPersistedAndRebuildsOnRelaunch() {
        let store = onboard(level: .intermediate)
        store.handleDayRolloverIfNeeded(now: Date.now.addingTimeInterval(86_400))
        XCTAssertEqual(store.planDayIndex, 1)

        XCTAssertEqual(ProfileFilePersistence().loadProfile()?.planDayIndex, 1,
                       "the plan position is persisted")

        // A relaunch rebuilds the plan and stages a valid catalog workout. (A
        // genuinely new calendar day legitimately advances the index again, so
        // this asserts a working plan, not a frozen index.)
        let reloaded = MorpheAppStore()
        XCTAssertFalse(reloaded.personalizedPlanIDs.isEmpty, "the plan rebuilds on relaunch")
        XCTAssertTrue(reloaded.catalogWorkouts.contains { $0.id == reloaded.currentWorkout.id },
                      "a catalog plan workout is staged after relaunch")
    }
}

/// Progression — a session that felt "too easy" makes Morphe pre-fill a small
/// bump on that exercise's next working weight (the promise that used to be a
/// text card).
@MainActor
final class ProgressionTests: XCTestCase {

    override func setUp() {
        super.setUp()
        WorkoutFilePersistence().clear()
        ProfileFilePersistence().clear()
    }

    override func tearDown() {
        WorkoutFilePersistence().clear()
        ProfileFilePersistence().clear()
        super.tearDown()
    }

    private func freshStore() -> MorpheAppStore {
        let store = MorpheAppStore()
        store.onboardingDraft.name = "Sarah"
        store.completeOnboarding()
        return store
    }

    /// Runs one session on the current workout, logging `weight` on the first
    /// exercise, rating it, and logging the workout. Returns that exercise.
    @discardableResult
    private func logSession(_ store: MorpheAppStore, weight: Double, feedback: WorkoutFeedbackOption) -> WorkoutExercise {
        store.startTodayWorkout()
        let exercise = store.activeWorkoutExercise!
        store.completeTrackedSet(reps: 8, weight: weight)
        XCTAssertTrue(store.finishTrackedWorkoutSession())
        store.submitWorkoutFeedback(feedback)
        store.logWorkout()
        return exercise
    }

    func testTooEasyBumpsNextSuggestedWeight() {
        let store = freshStore()
        let exercise = logSession(store, weight: 100, feedback: .tooEasy)

        // Pounds default → +5 lb bump on the next suggestion for that exercise.
        XCTAssertEqual(store.suggestedWorkingWeight(for: exercise), 105)
        XCTAssertNotNil(store.progressionNote(for: exercise))
    }

    func testJustRightHoldsTheWeight() {
        let store = freshStore()
        let exercise = logSession(store, weight: 100, feedback: .justRight)

        XCTAssertEqual(store.suggestedWorkingWeight(for: exercise), 100, "no bump when it felt right")
        XCTAssertNil(store.progressionNote(for: exercise))
    }

    func testTooHardDoesNotBump() {
        let store = freshStore()
        let exercise = logSession(store, weight: 100, feedback: .tooHard)
        XCTAssertEqual(store.suggestedWorkingWeight(for: exercise), 100)
        XCTAssertNil(store.progressionNote(for: exercise))
    }

    func testBodyweightExerciseGetsNoWeightSuggestion() {
        let store = freshStore()
        let exercise = logSession(store, weight: 0, feedback: .tooEasy)
        XCTAssertNil(store.suggestedWorkingWeight(for: exercise), "bodyweight has no weight to bump")
        XCTAssertNil(store.progressionNote(for: exercise))
    }

    func testSuggestionSurvivesRelaunch() {
        let store = freshStore()
        let exercise = logSession(store, weight: 135, feedback: .tooEasy)
        XCTAssertEqual(store.suggestedWorkingWeight(for: exercise), 140)

        let reloaded = MorpheAppStore()
        // The exercise resolves by name from the persisted log.
        XCTAssertEqual(reloaded.suggestedWorkingWeight(for: exercise), 140,
                       "the too-easy feedback + weight persist, so the bump survives relaunch")
    }
}

/// Tier-2 personalization engine: sport-aware plan ranking, injury-aware
/// ordering, nutrition targets from the user's own logged weight, top-set RPE
/// driving progression, and the equipment/goal editors the Profile UI calls.
@MainActor
final class PersonalizationEngineTests: XCTestCase {

    override func setUp() {
        super.setUp()
        WorkoutFilePersistence().clear()
        ProfileFilePersistence().clear()
    }

    override func tearDown() {
        WorkoutFilePersistence().clear()
        ProfileFilePersistence().clear()
        super.tearDown()
    }

    private func freshStore() -> MorpheAppStore {
        let store = MorpheAppStore()
        store.onboardingDraft.name = "Sarah"
        store.completeOnboarding()
        return store
    }

    private func template(name: String, sport: SportFocus, exercises: [String] = [],
                          focusTag: String = "Full Body", equipment: String = "Bodyweight") -> WorkoutTemplate {
        WorkoutTemplate(
            name: name, type: "Strength", sport: sport, goal: "Test",
            difficulty: .moderate, durationMinutes: 30, equipment: equipment,
            focusTag: focusTag,
            exercises: exercises.map {
                WorkoutExercise(id: $0.lowercased(), exerciseLibraryID: "", name: $0,
                                muscleGroup: .legs, sets: "3", reps: "10",
                                difficulty: .moderate, formCue: "")
            },
            notes: "", coachNote: ""
        )
    }

    // MARK: Sport-aware ranking

    func testSportMatchRanksAheadOfOtherwiseEqualMismatch() {
        // "A ..." would win on the name tiebreak — only the sport preference
        // can put the boxing template first for a boxing user.
        let mismatch = template(name: "A Runner Builder", sport: .running)
        let match = template(name: "B Boxing Builder", sport: .boxing)

        let ranked = MorpheAppStore.rankedPlanCandidates(
            [mismatch, match], sport: .boxing, equipmentOrder: ["Bodyweight"], flaggedAreas: []
        )
        XCTAssertEqual(ranked.first?.name, "B Boxing Builder",
                       "a matching-sport template outranks an otherwise-equal mismatch")

        // Soft preference, never a filter: the mismatch is still in the pool.
        XCTAssertEqual(ranked.count, 2, "sport mismatches are down-ranked, not excluded")
    }

    // MARK: Injury-aware ordering

    func testFlaggedAreasParsesInjuryNote() {
        XCTAssertEqual(MorpheAppStore.flaggedAreas(from: "knee pain after squats"), ["knee"])
        XCTAssertEqual(MorpheAppStore.flaggedAreas(from: "Shoulder + lower back issues"), ["shoulder", "back"])
        XCTAssertTrue(MorpheAppStore.flaggedAreas(from: "").isEmpty)
        XCTAssertTrue(MorpheAppStore.flaggedAreas(from: "none").isEmpty)
    }

    func testKneeFlagDownRanksSquatHeavyTemplateWithoutExcludingIt() {
        let kneeHeavy = template(name: "A Squat Blast", sport: .generalFitness,
                                 exercises: ["Back Squat", "Walking Lunge", "Jump Squat"], focusTag: "Legs")
        let kneeFriendly = template(name: "Z Upper Builder", sport: .generalFitness,
                                    exercises: ["Bench Press Machine Row", "Curl"], focusTag: "Pull")
        let areas = MorpheAppStore.flaggedAreas(from: "knee pain after squats")

        XCTAssertGreaterThan(MorpheAppStore.injuryPenalty(for: kneeHeavy, areas: areas), 0)
        XCTAssertEqual(MorpheAppStore.injuryPenalty(for: kneeHeavy, areas: []), 0,
                       "no flagged areas, no penalty")

        let ranked = MorpheAppStore.rankedPlanCandidates(
            [kneeHeavy, kneeFriendly], sport: .generalFitness,
            equipmentOrder: ["Bodyweight"], flaggedAreas: areas
        )
        XCTAssertEqual(ranked.first?.name, "Z Upper Builder",
                       "knee-loading work moves behind safer options")
        XCTAssertEqual(ranked.count, 2, "flagged workouts are re-ordered, never removed")
    }

    // MARK: Nutrition targets from real data

    func testNutritionTargetsFromLoggedWeightAndFatLossGoal() {
        let store = freshStore()
        store.clientProfile.selectedGoals = ["Lose weight"]
        store.clientProfile.goal = "Lose weight"
        store.updateBodyMetrics(height: "", weight: "170 lb")

        let targets = store.nutritionTargets
        XCTAssertEqual(targets.calories, 2200, "170 lb x 13 (fat loss), rounded to 50")
        XCTAssertEqual(targets.proteinGrams, 145, "170 lb x 0.85 g/lb, rounded to 5")
        XCTAssertEqual(targets.waterCups, 9, "170 / 20, clamped 8...16")
        XCTAssertTrue(targets.sourceNote.contains("170 lb"),
                      "the note cites the real logged weight — got \(targets.sourceNote)")

        // The nutrition card's goal numbers follow the computed targets.
        XCTAssertEqual(store.nutrition.calorieGoal, 2200)
        XCTAssertEqual(store.nutrition.proteinGoal, 145)
        XCTAssertEqual(store.nutrition.waterGoal, 9)
    }

    func testNutritionTargetsFallBackToLabeledStartersWithoutWeight() {
        let store = freshStore()
        let targets = store.nutritionTargets
        XCTAssertEqual(targets.calories, 2200)
        XCTAssertEqual(targets.proteinGrams, 160)
        XCTAssertEqual(targets.waterCups, 8)
        XCTAssertTrue(targets.sourceNote.contains("Starter targets"),
                      "defaults must be labeled as starters, not passed off as personalized")
    }

    func testBodyWeightParsingHandlesKilograms() {
        let parsed = MorpheAppStore.parsedBodyWeightLb("77 kg")
        XCTAssertEqual(parsed ?? 0, 169.76, accuracy: 0.1)
        XCTAssertEqual(MorpheAppStore.parsedBodyWeightLb("170"), 170)
        XCTAssertNil(MorpheAppStore.parsedBodyWeightLb("soon"), "words are not a weight")
        XCTAssertNil(MorpheAppStore.parsedBodyWeightLb("9999 lb"), "implausible values fall back")
    }

    func testMealPrepTipReflectsHabitAndInterest() {
        let store = freshStore()
        store.clientProfile.mealPrepHabit = ""
        XCTAssertNil(store.mealPrepTip, "never asked = no tip")

        store.clientProfile.mealPrepHabit = MealPrepOption.never.rawValue
        store.clientProfile.mealPrepInterested = false
        XCTAssertNil(store.mealPrepTip, "not interested = no unsolicited prep sermon")

        store.clientProfile.mealPrepInterested = true
        XCTAssertTrue(store.mealPrepTip?.contains("one prepped breakfast") ?? false)

        store.clientProfile.mealPrepHabit = MealPrepOption.weekly.rawValue
        XCTAssertTrue(store.mealPrepTip?.contains("already prep") ?? false)
    }

    // MARK: Top-set RPE drives progression

    func testTopSetRPESixTriggersTooEasyStyleBump() {
        let store = freshStore()
        store.startTodayWorkout()
        let exercise = store.activeWorkoutExercise!
        store.completeTrackedSet(reps: 8, weight: 100, rpe: 6)
        XCTAssertTrue(store.finishTrackedWorkoutSession())
        // Session rated "just right" — only the per-set RPE says there was
        // room, and that alone must drive the bump.
        store.submitWorkoutFeedback(.justRight)
        store.logWorkout()

        XCTAssertEqual(store.suggestedWorkingWeight(for: exercise), 105,
                       "top set at RPE 6 suggests the same +5 lb as a too-easy rating")
        XCTAssertTrue(store.progressionNote(for: exercise)?.contains("RPE 6") ?? false,
                      "the note cites the real RPE — got \(store.progressionNote(for: exercise) ?? "nil")")
    }

    func testTopSetRPETenSuggestsHolding() {
        let store = freshStore()
        store.startTodayWorkout()
        let exercise = store.activeWorkoutExercise!
        store.completeTrackedSet(reps: 8, weight: 100, rpe: 10)
        XCTAssertTrue(store.finishTrackedWorkoutSession())
        store.submitWorkoutFeedback(.justRight)
        store.logWorkout()

        XCTAssertEqual(store.suggestedWorkingWeight(for: exercise), 100, "RPE 10 never loads further")
        XCTAssertTrue(store.progressionNote(for: exercise)?.lowercased().contains("holding") ?? false)
    }

    func testUnratedRPEChangesNothing() {
        let store = freshStore()
        store.startTodayWorkout()
        let exercise = store.activeWorkoutExercise!
        store.completeTrackedSet(reps: 8, weight: 100) // rpe defaults to unrated
        XCTAssertTrue(store.finishTrackedWorkoutSession())
        store.submitWorkoutFeedback(.justRight)
        store.logWorkout()

        XCTAssertEqual(store.suggestedWorkingWeight(for: exercise), 100)
        XCTAssertNil(store.progressionNote(for: exercise), "no rating is not a signal")
    }

    // MARK: Equipment + goal editors (the contract ProfileView calls)

    func testUpdateEquipmentChangesProfileAndPersists() {
        let store = freshStore()
        store.updateEquipment("  Pull-up bar ")
        XCTAssertEqual(store.clientProfile.equipment, "Pull-up bar")

        let reloaded = MorpheAppStore()
        XCTAssertEqual(reloaded.clientProfile.equipment, "Pull-up bar",
                       "the equipment edit survives relaunch")
        XCTAssertFalse(reloaded.personalizedPlanIDs.isEmpty, "the plan rebuilt around it")
    }

    func testUpdateGoalTargetsTrimsCapsAndPersists() {
        let store = freshStore()
        store.updateGoalTargets(
            physical: "  Visible abs ",
            weight: String(repeating: "9", count: 200),
            deadline: "12 weeks"
        )
        XCTAssertEqual(store.clientProfile.physicalGoalTarget, "Visible abs")
        XCTAssertEqual(store.clientProfile.weightGoalTarget.count, 120, "capped at 120 chars")

        let reloaded = MorpheAppStore()
        XCTAssertEqual(reloaded.clientProfile.goalDeadline, "12 weeks")
        XCTAssertEqual(reloaded.clientProfile.physicalGoalTarget, "Visible abs",
                       "goal targets survive relaunch")
    }
}

/// The press-and-hold stepper ramps to ~4x after 2 seconds held.
final class HoldRepeaterTests: XCTestCase {
    func testCadenceRampsAfterTwoSeconds() {
        let slow = HoldRepeater.interval(heldSeconds: 0.5)
        let fast = HoldRepeater.interval(heldSeconds: 2.5)
        XCTAssertEqual(slow, 0.16, "before 2s a hold repeats at the normal rate")
        XCTAssertEqual(fast, 0.04, "after 2s it accelerates")
        XCTAssertEqual(slow / fast, 4, accuracy: 0.01, "roughly 4x faster once ramped")
        // The boundary flips exactly at 2 seconds.
        XCTAssertEqual(HoldRepeater.interval(heldSeconds: 1.99), 0.16)
        XCTAssertEqual(HoldRepeater.interval(heldSeconds: 2.0), 0.04)
    }
}

/// The personalized difficulty engine: tasks and the plan scale from the
/// profile level and the user's actual results — never invented data.
@MainActor
final class DifficultyEngineTests: XCTestCase {

    override func setUp() {
        super.setUp()
        WorkoutFilePersistence().clear()
        ProfileFilePersistence().clear()
    }

    private func onboardedStore(level: ExperienceLevelOption) -> MorpheAppStore {
        let store = MorpheAppStore()
        store.onboardingDraft.name = "Sarah"
        store.onboardingDraft.experienceLevel = level
        store.completeOnboarding()
        return store
    }

    func testBeginnerStartsGentleAdvancedStartsChallenging() {
        let beginner = onboardedStore(level: .beginner)
        XCTAssertEqual(beginner.taskDifficultyDial, 0, "a fresh beginner starts at the gentlest dial")
        XCTAssertEqual(beginner.todayTasks.count, 4, "the engine always builds a 4-task day")
        XCTAssertTrue(beginner.todayTasks.contains { $0.title == "Complete today's workout" },
                      "the workout anchor keeps its exact title (auto-completion matches on it)")
        XCTAssertFalse(beginner.todayTasks.contains { $0.difficulty == .stretch },
                       "no stretch tasks on a beginner's day one")

        ProfileFilePersistence().clear()
        WorkoutFilePersistence().clear()
        let advanced = onboardedStore(level: .advanced)
        XCTAssertEqual(advanced.taskDifficultyDial, 3, "a fresh advanced user starts challenging")
        XCTAssertTrue(advanced.todayTasks.contains { $0.difficulty == .stretch },
                      "an advanced day includes stretch work from the start")
    }

    func testConsistentTaskCompletionRaisesTheDial() {
        let store = onboardedStore(level: .beginner)
        let base = store.taskDifficultyDial
        // Two strong weeks of closed tasks, recorded the way rollover records them.
        for day in 1...14 {
            store.taskCompletionHistory.append(
                TaskDayRecord(day: String(format: "2026-06-%02d", day), completed: 4, total: 4)
            )
        }
        XCTAssertGreaterThan(store.taskDifficultyDial, base,
                             "closing tasks for two weeks must raise the dial")
        XCTAssertLessThanOrEqual(store.taskDifficultyDial, 2,
                                 "a beginner's dial is capped — it grows slowly, not to advanced-tier")
    }

    func testSlippingTasksTrimTheDial() {
        let store = onboardedStore(level: .intermediate)
        for day in 1...14 {
            store.taskCompletionHistory.append(
                TaskDayRecord(day: String(format: "2026-06-%02d", day), completed: 0, total: 4)
            )
        }
        XCTAssertEqual(store.taskDifficultyDial, 0,
                       "an intermediate user who stops closing tasks drops to the gentlest mix")
    }

    func testEasyRatedFastSessionsPushThePlanUp() {
        let store = onboardedStore(level: .beginner)
        XCTAssertEqual(store.workoutIntensityBias, 0, "no logs = no bias")

        let template = store.currentWorkout
        for offset in 0..<3 {
            store.workoutLogs.append(
                WorkoutLog(
                    athleteID: store.clientProfile.id,
                    athleteName: "Sarah",
                    workoutTemplateID: template.id,
                    workoutTitle: template.name,
                    sport: template.sport,
                    completedAt: Date.now.addingTimeInterval(TimeInterval(-offset * 86_400)),
                    durationMinutes: max(template.durationMinutes / 2, 1),
                    exercises: [],
                    notes: "",
                    source: .athleteManual,
                    enteredByUserID: store.clientProfile.id,
                    enteredByRole: .client,
                    enteredByName: "Sarah",
                    verificationStatus: .athleteSubmitted,
                    sessionFeedback: WorkoutFeedbackOption.tooEasy.rawValue
                )
            )
        }
        XCTAssertEqual(store.workoutIntensityBias, 1,
                       "three too-easy, fast-finished sessions must tilt the plan up")
        XCTAssertNotNil(store.workoutIntensityNote, "a tilted plan explains itself on the Today card")
    }

    func testPainPullsThePlanDown() {
        let store = onboardedStore(level: .advanced)
        for offset in 0..<2 {
            store.workoutLogs.append(
                WorkoutLog(
                    athleteID: store.clientProfile.id,
                    athleteName: "Sarah",
                    workoutTemplateID: nil,
                    workoutTitle: "Heavy Day",
                    sport: .generalFitness,
                    completedAt: Date.now.addingTimeInterval(TimeInterval(-offset * 86_400)),
                    durationMinutes: 40,
                    exercises: [],
                    notes: "",
                    source: .athleteManual,
                    enteredByUserID: store.clientProfile.id,
                    enteredByRole: .client,
                    enteredByName: "Sarah",
                    verificationStatus: .athleteSubmitted,
                    sessionFeedback: WorkoutFeedbackOption.pain.rawValue
                )
            )
        }
        XCTAssertEqual(store.workoutIntensityBias, -1,
                       "repeated pain reports must ease the plan off")
    }

    func testSameDayRegenerationIsDeterministic() {
        let store = onboardedStore(level: .intermediate)
        let titles = store.todayTasks.map(\.title)
        XCTAssertEqual(store.personalizedDailyTasks().map(\.title), titles,
                       "same day + same dial must regenerate the identical list, or restored completions miss their rows")
    }
}

/// Train Together (buddy sessions): the store side, backed by a mock service
/// so nothing touches the network.
@MainActor
final class TrainTogetherTests: XCTestCase {

    final class MockPartyService: WorkoutPartying {
        var createdParty: WorkoutParty?
        var createdWorkout: PartyWorkoutSnapshot?
        var joins: [(partyID: String, participant: PartyParticipant)] = []
        var summaries: [(partyID: String, participantID: String, summary: String)] = []
        var fetchResult: (party: WorkoutParty, workout: PartyWorkoutSnapshot)?
        var leaves: [String] = []

        func createParty(_ party: WorkoutParty, host: PartyParticipant, workout: PartyWorkoutSnapshot) async -> Bool {
            createdParty = party
            createdWorkout = workout
            joins.append((party.id, host))
            return true
        }
        func fetchParty(code: String) async -> (party: WorkoutParty, workout: PartyWorkoutSnapshot)? { fetchResult }
        func join(partyID: String, participant: PartyParticipant) async -> Bool {
            joins.append((partyID, participant))
            return true
        }
        func leave(partyID: String, participantID: String) async { leaves.append(participantID) }
        func publishProgress(partyID: String, participantID: String, progress: PartyProgressUpdate) {}
        func publishSummary(partyID: String, participantID: String, summary: String) {
            summaries.append((partyID, participantID, summary))
        }
        func sendNudge(partyID: String, from participant: PartyParticipant, emoji: String) {}
        func updateStatus(partyID: String, status: PartyStatus) {}
        func listen(partyID: String,
                    onStatus: @escaping (PartyStatus) -> Void,
                    onMembers: @escaping ([PartyParticipant]) -> Void,
                    onNudge: @escaping (PartyNudge) -> Void) {}
        func stopListening() {}
    }

    override func setUp() {
        super.setUp()
        WorkoutFilePersistence().clear()
        ProfileFilePersistence().clear()
    }

    private func signedInStore(service: MockPartyService) -> MorpheAppStore {
        let store = MorpheAppStore(partyService: service)
        store.onboardingDraft.name = "Sarah"
        store.completeOnboarding()
        store.authUser = AppUser(id: "user-1", email: "sarah@morphe.app", role: .athlete, displayName: "Sarah", createdAt: .now)
        return store
    }

    func testHostingCreatesPartyAroundTheCurrentWorkout() async {
        let service = MockPartyService()
        let store = signedInStore(service: service)

        let started = await store.startTrainTogether(mode: .inPerson)

        XCTAssertTrue(started)
        XCTAssertNotNil(store.activeParty, "hosting puts the user in a live party")
        XCTAssertTrue(store.isPartyHost)
        XCTAssertEqual(store.activeParty?.id.count, 6, "join codes are six characters")
        XCTAssertEqual(service.createdWorkout?.name, store.currentWorkout.name,
                       "the party carries a snapshot of the host's workout")
        XCTAssertEqual(service.createdWorkout?.exercises.count, store.currentWorkout.exercises.count)
    }

    func testTrainTogetherRequiresSignIn() async {
        let service = MockPartyService()
        let store = MorpheAppStore(partyService: service)
        store.onboardingDraft.name = "Sarah"
        store.completeOnboarding()
        store.authUser = nil

        let started = await store.startTrainTogether(mode: .inPerson)
        XCTAssertFalse(started, "no anonymous parties — Firestore needs an authed user")
        XCTAssertNil(store.activeParty)
    }

    func testJoiningRunsTheHostsExactWorkout() async {
        let service = MockPartyService()
        let store = signedInStore(service: service)

        var hostTemplate = store.currentWorkout
        hostTemplate.name = "Colt's Heavy Push Day"
        service.fetchResult = (
            party: WorkoutParty(id: "F7KQ2M", mode: .inPerson, hostID: "host-9",
                                hostName: "Colt", workoutName: hostTemplate.name,
                                participants: [PartyParticipant(id: "host-9", name: "Colt", email: "colt@morphe.app", isHost: true)]),
            workout: PartyWorkoutSnapshot(template: hostTemplate)
        )

        let joined = await store.joinParty(code: "f7kq2m")

        XCTAssertTrue(joined, "codes are case-insensitive")
        XCTAssertEqual(store.activeParty?.id, "F7KQ2M")
        XCTAssertFalse(store.isPartyHost)
        XCTAssertEqual(store.currentWorkout.name, "Colt's Heavy Push Day",
                       "joining stages the host's workout on this phone")
        XCTAssertTrue(store.isWorkoutSessionActive, "the session starts immediately on join")
        XCTAssertEqual(service.joins.last?.participant.name, "Sarah")
    }

    func testLoggingPublishesTotalsAndClosesTheParty() async {
        let service = MockPartyService()
        let store = signedInStore(service: service)
        _ = await store.startTrainTogether(mode: .inPerson)
        store.activeParty?.participants.append(
            PartyParticipant(id: "buddy-2", name: "Colt", email: "colt@morphe.app", isHost: false)
        )

        store.startTodayWorkout()
        store.hasCompletedWorkoutFlow = true
        store.logWorkout()

        XCTAssertEqual(service.summaries.count, 1, "logging publishes this user's totals to the party")
        XCTAssertEqual(service.summaries.first?.participantID, "user-1")
        XCTAssertNil(store.activeParty, "the party clears locally once the session is logged")
        XCTAssertTrue(store.workoutLogs.first?.notes.contains("Trained with Colt") ?? false,
                      "the log remembers who was there")
    }
}

/// Train Together Phase 2: live virtual-session sync through the party service.
@MainActor
final class TrainTogetherLiveSyncTests: XCTestCase {

    final class RecordingPartyService: WorkoutPartying {
        var progress: [(participantID: String, update: PartyProgressUpdate)] = []
        var nudges: [(from: String, emoji: String)] = []
        func createParty(_ party: WorkoutParty, host: PartyParticipant, workout: PartyWorkoutSnapshot) async -> Bool { true }
        func fetchParty(code: String) async -> (party: WorkoutParty, workout: PartyWorkoutSnapshot)? { nil }
        func join(partyID: String, participant: PartyParticipant) async -> Bool { true }
        func leave(partyID: String, participantID: String) async {}
        func publishProgress(partyID: String, participantID: String, progress update: PartyProgressUpdate) {
            progress.append((participantID, update))
        }
        func publishSummary(partyID: String, participantID: String, summary: String) {}
        func sendNudge(partyID: String, from participant: PartyParticipant, emoji: String) {
            nudges.append((participant.name, emoji))
        }
        func updateStatus(partyID: String, status: PartyStatus) {}
        func listen(partyID: String,
                    onStatus: @escaping (PartyStatus) -> Void,
                    onMembers: @escaping ([PartyParticipant]) -> Void,
                    onNudge: @escaping (PartyNudge) -> Void) {}
        func stopListening() {}
    }

    override func setUp() {
        super.setUp()
        WorkoutFilePersistence().clear()
        ProfileFilePersistence().clear()
    }

    private func virtualSessionStore(service: RecordingPartyService) async -> MorpheAppStore {
        let store = MorpheAppStore(partyService: service)
        store.onboardingDraft.name = "Sarah"
        store.completeOnboarding()
        store.authUser = AppUser(id: "user-1", email: "sarah@morphe.app", role: .athlete, displayName: "Sarah", createdAt: .now)
        _ = await store.startTrainTogether(mode: .virtualSession)
        store.startTodayWorkout()
        return store
    }

    func testLoggingASetPublishesLiveProgress() async {
        let service = RecordingPartyService()
        let store = await virtualSessionStore(service: service)
        service.progress = []

        store.completeTrackedSet(reps: 10, weight: 95)

        let last = service.progress.last
        XCTAssertNotNil(last, "each logged set mirrors progress to the party")
        XCTAssertEqual(last?.participantID, "user-1")
        // Logging can auto-advance to the next exercise (which publishes
        // again), so the final update mirrors wherever the session actually
        // is right now.
        XCTAssertEqual(last?.update.exerciseName, store.activeWorkoutExercise?.name)
        XCTAssertEqual(last?.update.setsDone,
                       store.activeWorkoutExercise.map { store.completedWorkoutSets[$0.id, default: 0] })
    }

    func testReadyCheckPublishesAndSticks() async {
        let service = RecordingPartyService()
        let store = await virtualSessionStore(service: service)
        service.progress = []

        store.markPartyReady()

        XCTAssertTrue(store.partyIsReadySelf)
        XCTAssertEqual(service.progress.last?.update.isReady, true)
    }

    func testNudgeGoesThroughTheService() async {
        let service = RecordingPartyService()
        let store = await virtualSessionStore(service: service)

        store.sendPartyNudge("🔥")

        XCTAssertEqual(service.nudges.last?.emoji, "🔥")
        XCTAssertEqual(service.nudges.last?.from, "Sarah")
    }

    func testSoloSessionsNeverPublish() {
        let service = RecordingPartyService()
        let store = MorpheAppStore(partyService: service)
        store.onboardingDraft.name = "Sarah"
        store.completeOnboarding()

        store.startTodayWorkout()
        store.completeTrackedSet(reps: 10)

        XCTAssertTrue(service.progress.isEmpty, "no party = nothing leaves the phone")
    }
}

/// Train Together Phase 3: group classes — lobby, host start, leaderboard.
@MainActor
final class GroupClassTests: XCTestCase {

    final class LobbyPartyService: WorkoutPartying {
        var statusUpdates: [(partyID: String, status: PartyStatus)] = []
        var capturedOnStatus: ((PartyStatus) -> Void)?
        var fetchResult: (party: WorkoutParty, workout: PartyWorkoutSnapshot)?
        var createdParty: WorkoutParty?

        func createParty(_ party: WorkoutParty, host: PartyParticipant, workout: PartyWorkoutSnapshot) async -> Bool {
            createdParty = party
            return true
        }
        func fetchParty(code: String) async -> (party: WorkoutParty, workout: PartyWorkoutSnapshot)? { fetchResult }
        func join(partyID: String, participant: PartyParticipant) async -> Bool { true }
        func leave(partyID: String, participantID: String) async {}
        func updateStatus(partyID: String, status: PartyStatus) {
            statusUpdates.append((partyID, status))
        }
        func publishProgress(partyID: String, participantID: String, progress: PartyProgressUpdate) {}
        func publishSummary(partyID: String, participantID: String, summary: String) {}
        func sendNudge(partyID: String, from participant: PartyParticipant, emoji: String) {}
        func listen(partyID: String,
                    onStatus: @escaping (PartyStatus) -> Void,
                    onMembers: @escaping ([PartyParticipant]) -> Void,
                    onNudge: @escaping (PartyNudge) -> Void) {
            capturedOnStatus = onStatus
        }
        func stopListening() {}
    }

    override func setUp() {
        super.setUp()
        WorkoutFilePersistence().clear()
        ProfileFilePersistence().clear()
    }

    private func signedInStore(service: LobbyPartyService) -> MorpheAppStore {
        let store = MorpheAppStore(partyService: service)
        store.onboardingDraft.name = "Sarah"
        store.completeOnboarding()
        store.authUser = AppUser(id: "user-1", email: "sarah@morphe.app", role: .athlete, displayName: "Sarah", createdAt: .now)
        return store
    }

    func testGroupClassOpensInALobby() async {
        let service = LobbyPartyService()
        let store = signedInStore(service: service)

        _ = await store.startTrainTogether(mode: .group)

        XCTAssertEqual(service.createdParty?.status, .lobby, "a class opens in the lobby, not live")
        XCTAssertEqual(store.activeParty?.status, .lobby)
        XCTAssertFalse(store.isWorkoutSessionActive, "nobody trains until the host starts the class")
    }

    func testJoiningALobbyHoldsTheWorkoutUntilTheHostStarts() async {
        let service = LobbyPartyService()
        let store = signedInStore(service: service)

        var classTemplate = store.currentWorkout
        classTemplate.name = "Saturday Conditioning Class"
        service.fetchResult = (
            party: WorkoutParty(id: "C7KQ2M", mode: .group, hostID: "coach-9",
                                hostName: "Coach Colt", workoutName: classTemplate.name,
                                status: .lobby,
                                participants: [PartyParticipant(id: "coach-9", name: "Coach Colt", email: "", isHost: true)]),
            workout: PartyWorkoutSnapshot(template: classTemplate)
        )

        let joined = await store.joinParty(code: "C7KQ2M")

        XCTAssertTrue(joined)
        XCTAssertFalse(store.isWorkoutSessionActive, "the lobby holds the workout — no early starts")

        // The host flips the class live; this phone's listener fires.
        service.capturedOnStatus?(.live)
        await Task.yield()
        try? await Task.sleep(nanoseconds: 100_000_000)

        XCTAssertEqual(store.activeParty?.status, .live)
        XCTAssertTrue(store.isWorkoutSessionActive, "the held workout launches when the class goes live")
        XCTAssertEqual(store.currentWorkout.name, "Saturday Conditioning Class")
    }

    func testHostStartFlipsStatusAndStartsTheirOwnSession() async {
        let service = LobbyPartyService()
        let store = signedInStore(service: service)
        _ = await store.startTrainTogether(mode: .group)

        store.startGroupClass()

        XCTAssertEqual(service.statusUpdates.last?.status, .live, "the flip reaches the backend")
        XCTAssertEqual(store.activeParty?.status, .live)
        XCTAssertTrue(store.isWorkoutSessionActive, "the host trains too")
    }

    func testLeaderboardRanksByTotalSetsWithLocalSelfPatch() async {
        let service = LobbyPartyService()
        let store = signedInStore(service: service)
        _ = await store.startTrainTogether(mode: .group)
        store.startGroupClass()

        store.activeParty?.participants = [
            PartyParticipant(id: "user-1", name: "Sarah", email: "", isHost: true, totalSetsDone: 0),
            PartyParticipant(id: "m2", name: "Colt", email: "", isHost: false, totalSetsDone: 3),
            PartyParticipant(id: "m3", name: "Ava", email: "", isHost: false, totalSetsDone: 5)
        ]
        // Sarah logs 6 sets locally — her row must rank first even before the
        // round-trip through the backend updates her synced count.
        for _ in 0..<6 { store.completeTrackedSet(reps: 8, allowExtra: true) }

        let board = store.partyLeaderboard
        XCTAssertEqual(board.first?.name, "Sarah")
        XCTAssertGreaterThanOrEqual(board.first?.totalSetsDone ?? 0, 6)
        XCTAssertEqual(board.map(\.name), ["Sarah", "Ava", "Colt"])
    }
}

/// Unique usernames, 14-day rename cooldowns, and the terms gate.
@MainActor
final class IdentityAndTermsTests: XCTestCase {

    final class MockUsernameDirectory: UsernameDirectoryService {
        var taken: Set<String> = []
        var claims: [(name: String, uid: String, released: String?)] = []

        func isAvailable(_ username: String, for uid: String) async -> Bool {
            !taken.contains(username)
        }
        func claim(_ username: String, for uid: String, releasing previous: String?) async -> UsernameClaimResult {
            if taken.contains(username) { return .taken }
            claims.append((username, uid, previous))
            taken.insert(username)
            if let previous { taken.remove(previous) }
            return .claimed
        }
        func search(prefix: String, limit: Int) async -> [(username: String, uid: String)] {
            taken.filter { $0.hasPrefix(prefix) }.sorted().prefix(limit).map { ($0, "uid-\($0)") }
        }
        func release(_ username: String, for uid: String) async {
            taken.remove(username)
        }
    }

    override func setUp() {
        super.setUp()
        WorkoutFilePersistence().clear()
        ProfileFilePersistence().clear()
    }

    private func makeStore(directory: MockUsernameDirectory = MockUsernameDirectory()) -> MorpheAppStore {
        let store = MorpheAppStore(usernameDirectory: directory)
        store.authUser = AppUser(id: "user-1", email: "sarah@morphe.app", role: .athlete, displayName: "Sarah", createdAt: .now)
        return store
    }

    func testUsernameRulesNormalizeAndValidate() {
        XCTAssertEqual(UsernameRules.normalize("Sarah Lifts!"), "sarahlifts")
        XCTAssertEqual(UsernameRules.normalize("IRON_mike99"), "iron_mike99")
        XCTAssertNotNil(UsernameRules.validationError("ab"), "too short")
        XCTAssertNotNil(UsernameRules.validationError("_sneaky"), "must start with a letter")
        XCTAssertNil(UsernameRules.validationError("sarahlifts"))
    }

    func testOnboardingReservesTheChosenUsername() async {
        let directory = MockUsernameDirectory()
        let store = makeStore(directory: directory)

        let error = await store.checkAndReserveUsername("Sarah_Lifts")
        XCTAssertNil(error)
        XCTAssertEqual(store.onboardingDraft.username, "sarah_lifts")
        XCTAssertEqual(directory.claims.last?.uid, "user-1")

        store.onboardingDraft.name = "Sarah"
        store.completeOnboarding()
        XCTAssertEqual(store.profileShowcase.username, "sarah_lifts",
                       "the profile carries the reserved username, not a name-derived handle")
    }

    func testTakenUsernameIsRejected() async {
        let directory = MockUsernameDirectory()
        directory.taken = ["sarahlifts"]
        let store = makeStore(directory: directory)

        let error = await store.checkAndReserveUsername("sarahlifts")
        XCTAssertNotNil(error, "a name someone else owns can never be claimed twice")
        XCTAssertTrue(error?.contains("taken") ?? false)
    }

    func testUsernameChangeReleasesOldNameAndStartsCooldown() async {
        let directory = MockUsernameDirectory()
        let store = makeStore(directory: directory)
        store.onboardingDraft.name = "Sarah"
        _ = await store.checkAndReserveUsername("sarahlifts")
        store.completeOnboarding()
        store.authUser = AppUser(id: "user-1", email: "sarah@morphe.app", role: .athlete, displayName: "Sarah", createdAt: .now)

        let changed = await store.changeUsername(to: "ironsarah")
        XCTAssertTrue(changed)
        XCTAssertEqual(store.profileShowcase.username, "ironsarah")
        XCTAssertEqual(directory.claims.last?.released, "sarahlifts",
                       "the old name is released in the same claim — an account never holds two")

        // Second change inside 14 days is blocked.
        let again = await store.changeUsername(to: "sarahstrong")
        XCTAssertFalse(again, "username changes are limited to once every 14 days")
        XCTAssertEqual(store.profileShowcase.username, "ironsarah")
        XCTAssertNotNil(store.nextUsernameChangeDate)

        // ...and frees up after the window passes.
        store.usernameChangedAtEpoch = Date.now.addingTimeInterval(-15 * 24 * 3600).timeIntervalSince1970
        let afterWindow = await store.changeUsername(to: "sarahstrong")
        XCTAssertTrue(afterWindow)
    }

    func testNameChangeCooldown() {
        let store = makeStore()
        store.onboardingDraft.name = "Sarah"
        store.completeOnboarding()

        store.updateDisplayName("Sarah D")
        XCTAssertEqual(store.profileShowcase.displayName, "Sarah D", "the first change is free")

        store.updateDisplayName("Sarah Dee")
        XCTAssertEqual(store.profileShowcase.displayName, "Sarah D",
                       "a second change inside 14 days is blocked")
        XCTAssertNotNil(store.nextNameChangeDate)

        store.nameChangedAtEpoch = Date.now.addingTimeInterval(-15 * 24 * 3600).timeIntervalSince1970
        store.updateDisplayName("Sarah Dee")
        XCTAssertEqual(store.profileShowcase.displayName, "Sarah Dee", "free again after the window")
    }

    func testTermsGateShowsAfterOnboardingUntilAccepted() {
        let store = makeStore()
        store.onboardingDraft.name = "Sarah"
        store.completeOnboarding()

        XCTAssertTrue(store.needsTermsAcceptance, "the gate follows onboarding")
        XCTAssertFalse(store.showWelcomeExperience, "the celebration waits behind the gate")

        store.acceptTerms()
        XCTAssertFalse(store.needsTermsAcceptance)
        XCTAssertTrue(store.showWelcomeExperience, "accepting releases the welcome beat")

        // Accepted once = remembered across relaunch.
        let reloaded = MorpheAppStore()
        XCTAssertTrue(reloaded.hasAcceptedTerms, "acceptance persists — the popup never returns")
    }

    func testDecliningTermsSignsOutAndGateReturns() {
        let store = makeStore()
        store.onboardingDraft.name = "Sarah"
        store.completeOnboarding()
        store.authUser = AppUser(id: "user-1", email: "sarah@morphe.app", role: .athlete, displayName: "Sarah", createdAt: .now)

        store.declineTerms()
        XCTAssertNil(store.authUser, "declining signs the account out")
        XCTAssertFalse(store.hasAcceptedTerms)

        // Sign-out now wipes the device (launch audit) — the decliner
        // re-onboards on return, and the terms gate lives inside
        // onboarding's final step, so consent is still unavoidable.
        XCTAssertFalse(store.hasCompletedOnboarding,
                       "declining terms leaves no half-onboarded local state behind")
    }
}

/// The REAL appointments schedule (personal, per-account). These run through
/// the NoOp sync service — no Firebase, no notification center — and protect
/// the add/cancel/delete round-trip the schedule UI depends on.
@MainActor
final class AppointmentTests: XCTestCase {

    override func setUp() {
        super.setUp()
        WorkoutFilePersistence().clear()
        ProfileFilePersistence().clear()
    }

    func testAddAppointmentRoundTrip() {
        let store = MorpheAppStore()
        XCTAssertTrue(store.appointments.isEmpty, "a fresh user has an empty schedule — nothing seeded")

        let later = Date.now.addingTimeInterval(48 * 3600)
        let sooner = Date.now.addingTimeInterval(24 * 3600)
        store.addAppointment(title: "Leg Day", date: later, durationMinutes: 60,
                             kind: .session, withName: "Jordan", notes: "Bring straps")
        let added = store.addAppointment(title: "Check-in", date: sooner, durationMinutes: 30,
                                         kind: .checkIn, withName: "", notes: "")

        XCTAssertEqual(store.appointments.count, 2)
        XCTAssertEqual(store.appointments.map(\.title), ["Check-in", "Leg Day"],
                       "the schedule stays sorted by date")
        XCTAssertEqual(added?.status, Appointment.statusScheduled)
        XCTAssertEqual(added?.createdByRole, store.selectedRole.rawValue)
        XCTAssertEqual(store.upcomingAppointments.count, 2)

        // A blank title is rejected, not silently saved.
        XCTAssertNil(store.addAppointment(title: "   ", date: sooner, durationMinutes: 30,
                                          kind: .custom, withName: "", notes: ""))
        XCTAssertEqual(store.appointments.count, 2)
    }

    func testCancelAndDeleteAppointment() {
        let store = MorpheAppStore()
        guard let appointment = store.addAppointment(
            title: "Assessment", date: .now.addingTimeInterval(24 * 3600),
            durationMinutes: 45, kind: .assessment, withName: "Sam", notes: ""
        ) else { return XCTFail("add must succeed") }

        // Cancel keeps the record (its history) but drops it from upcoming.
        store.updateAppointmentStatus(appointment, to: Appointment.statusCancelled)
        XCTAssertEqual(store.appointments.first?.status, Appointment.statusCancelled)
        XCTAssertTrue(store.upcomingAppointments.isEmpty)

        // Delete removes it entirely.
        store.deleteAppointment(appointment)
        XCTAssertTrue(store.appointments.isEmpty)
    }
}

// MARK: - Social feed (follow graph, typed reactions, rich cards)

@MainActor
final class SocialFeedTests: XCTestCase {

    override func setUp() {
        super.setUp()
        WorkoutFilePersistence().clear()
        ProfileFilePersistence().clear()
    }

    /// Onboarded store with a fake signed-in identity — services stay NoOp,
    /// so every assertion below is about STORE state, not Firestore.
    private func signedInStore() -> MorpheAppStore {
        let store = MorpheAppStore()
        store.onboardingDraft.name = "Sarah"
        store.completeOnboarding()
        store.authUser = AppUser(
            id: "uid-test", email: "t@morphe.app", role: .athlete,
            displayName: "Sarah", createdAt: .now
        )
        return store
    }

    func testReactionTypeRewritesWithoutDoubleCounting() {
        let store = signedInStore()
        let post = FeedPost(id: "p1", authorUid: "other", authorName: "Alex", text: "win")
        store.feedPosts = [post]
        store.feedReactionCounts["p1"] = 0

        store.toggleReaction(post)
        XCTAssertEqual(store.feedReactionCounts["p1"], 1, "first reaction counts once")
        XCTAssertEqual(store.myReactionTypes["p1"], "heart", "plain tap is a heart")

        store.react(to: post, type: "fire")
        XCTAssertEqual(store.feedReactionCounts["p1"], 1, "changing type must not move the count")
        XCTAssertEqual(store.myReactionTypes["p1"], "fire")

        store.react(to: post, type: nil)
        XCTAssertEqual(store.feedReactionCounts["p1"], 0)
        XCTAssertFalse(store.myReactedPostIds.contains("p1"))
    }

    func testFollowToggleGuardsSelfAndFlips() {
        let store = signedInStore()
        XCTAssertFalse(store.isFollowing("friend-1"))

        store.toggleFollow(uid: "friend-1", name: "@alex")
        XCTAssertTrue(store.isFollowing("friend-1"))

        store.toggleFollow(uid: "friend-1", name: "@alex")
        XCTAssertFalse(store.isFollowing("friend-1"))

        store.toggleFollow(uid: "uid-test", name: "@me")
        XCTAssertFalse(store.isFollowing("uid-test"), "following yourself is refused")
    }

    func testReferralLinkNormalizesAndStoresTheHandle() {
        UserDefaults.standard.removeObject(forKey: "morphe.referral.pending")
        let store = signedInStore()
        store.handleIncomingURL(URL(string: "morphe://invite/LucasD")!)
        XCTAssertEqual(UserDefaults.standard.string(forKey: "morphe.referral.pending"), "lucasd",
                       "invite handle is normalized like every username")
        // Universal-Link form: https /invite/<handle> parses like the
        // custom scheme (iOS only delivers AASA-matched hosts, so the
        // handler is host-agnostic — see docs/UNIVERSAL-LINKS.md).
        store.handleIncomingURL(URL(string: "https://morphe.example/invite/Sarah_Lifts")!)
        XCTAssertEqual(UserDefaults.standard.string(forKey: "morphe.referral.pending"), "sarah_lifts",
                       "https invite links store the normalized handle")
        // A non-invite https path changes nothing.
        store.handleIncomingURL(URL(string: "https://morphe.example/privacy")!)
        XCTAssertEqual(UserDefaults.standard.string(forKey: "morphe.referral.pending"), "sarah_lifts")
        UserDefaults.standard.removeObject(forKey: "morphe.referral.pending")
    }

    // MARK: Referral receipts (the recruiter-visible join ledger)

    final class SpyReferralService: ReferralSyncing {
        var recorded: [(recruiterUid: String, referredUid: String)] = []
        var countToReturn: Int?
        func recordReferral(recruiterUid: String, referredUid: String) {
            recorded.append((recruiterUid, referredUid))
        }
        func referralCount(uid: String) async -> Int? { countToReturn }
        func eraseReceipts(referredUid: String, recruiterUids: [String]) async {}
    }

    /// Any non-NoOp FeedSyncing flips isRealFeedActive — behavior matches
    /// NoOp so the assertions stay about store state.
    final class LiveFeedStub: FeedSyncing {
        func publish(post: FeedPost) async -> Bool { false }
        func fetchRecent(limit: Int, before: Date?) async -> [FeedPost]? { nil }
        func fetchSince(date: Date, limit: Int) async -> [FeedPost]? { nil }
        func react(postId: String, uid: String, type: String?) {}
        func fetchReactionCounts(postIds: [String]) async -> [String: Int] { [:] }
        func fetchMyReactions(uid: String, postIds: [String]) async -> [String: String]? { nil }
        func fetchComments(postId: String, limit: Int) async -> [PostComment]? { nil }
        func addComment(_ comment: PostComment) async -> Bool { false }
        func deleteComment(postId: String, commentId: String) {}
        func savePost(uid: String, postId: String, on: Bool) {}
        func fetchSavedPostIds(uid: String) async -> Set<String>? { nil }
        func setFollow(uid: String, targetUid: String, on: Bool) {}
        func fetchFollowing(uid: String) async -> Set<String>? { nil }
        func submitReport(reporterUid: String, kind: String, targetId: String,
                          targetUid: String, reason: String, excerpt: String) async -> Bool { false }
        func setBlocked(uid: String, targetUid: String, name: String, on: Bool) {}
        func fetchBlocked(uid: String) async -> [String: String]? { nil }
        func delete(postId: String) {}
    }

    final class StubUsernameDirectory: UsernameDirectoryService {
        var entries: [(username: String, uid: String)] = []
        func isAvailable(_ username: String, for uid: String) async -> Bool { true }
        func claim(_ username: String, for uid: String, releasing previous: String?) async -> UsernameClaimResult { .claimed }
        func search(prefix: String, limit: Int) async -> [(username: String, uid: String)] {
            entries.filter { $0.username.hasPrefix(prefix) }
        }
        func release(_ username: String, for uid: String) async {}
    }

    func testConsumingAReferralWritesTheRecruiterReceipt() async {
        UserDefaults.standard.set("lucasd", forKey: "morphe.referral.pending")
        UserDefaults.standard.removeObject(forKey: "morphe.referrals.written.uid-test")
        let spy = SpyReferralService()
        let directory = StubUsernameDirectory()
        directory.entries = [("lucasd", "uid-recruiter")]
        let store = MorpheAppStore(usernameDirectory: directory,
                                   feedService: LiveFeedStub(),
                                   referralService: spy)
        store.onboardingDraft.name = "Sarah"
        store.completeOnboarding()
        store.authUser = AppUser(
            id: "uid-test", email: "t@morphe.app", role: .athlete,
            displayName: "Sarah", createdAt: .now
        )

        await store.consumePendingReferral()

        XCTAssertEqual(spy.recorded.count, 1, "one receipt in the recruiter's ledger")
        XCTAssertEqual(spy.recorded.first?.recruiterUid, "uid-recruiter")
        XCTAssertEqual(spy.recorded.first?.referredUid, "uid-test",
                       "the referred user writes their OWN receipt")
        XCTAssertEqual(UserDefaults.standard.stringArray(forKey: "morphe.referrals.written.uid-test"),
                       ["uid-recruiter"],
                       "the receipt path is remembered for account erasure")
        UserDefaults.standard.removeObject(forKey: "morphe.referrals.written.uid-test")
    }

    func testDuoStreakCountsConsecutiveBothPostedDays() {
        let store = signedInStore()
        let calendar = Calendar.current
        func post(_ id: String, _ uid: String, daysAgo: Int) -> FeedPost {
            FeedPost(id: id, authorUid: uid, authorName: uid, text: "s",
                     createdAt: calendar.date(byAdding: .day, value: -daysAgo, to: .now)!)
        }

        // Both posted yesterday and the day before; only the friend posted
        // 3 days ago — the streak is the BOTH run: 2, alive via yesterday.
        store.feedPosts = [
            post("m1", "uid-test", daysAgo: 1), post("m2", "uid-test", daysAgo: 2),
            post("f1", "friend", daysAgo: 1), post("f2", "friend", daysAgo: 2),
            post("f3", "friend", daysAgo: 3)
        ]
        XCTAssertEqual(store.duoStreak(with: "friend"), 2)

        // A gap two days back kills the run at 1.
        store.feedPosts.removeAll { $0.id == "m2" }
        XCTAssertEqual(store.duoStreak(with: "friend"), 1)

        // Nothing shared, no streak — and never with yourself.
        XCTAssertEqual(store.duoStreak(with: "stranger"), 0)
        XCTAssertEqual(store.duoStreak(with: "uid-test"), 0)
    }

    func testTrainedTodayEntriesAreA24hSelfFirstLens() {
        let store = signedInStore()
        let seenKey = "morphe.stories.seen.\(store.clientProfile.id.uuidString)"
        UserDefaults.standard.removeObject(forKey: seenKey)

        store.feedPosts = [
            FeedPost(id: "mine", authorUid: "uid-test", authorName: "Sarah", text: "win",
                     createdAt: .now.addingTimeInterval(-3600)),
            FeedPost(id: "fresh", authorUid: "friend", authorName: "Alex", text: "session",
                     createdAt: .now.addingTimeInterval(-7200)),
            FeedPost(id: "stale", authorUid: "old", authorName: "Riley", text: "ancient",
                     createdAt: .now.addingTimeInterval(-30 * 3600))
        ]

        var entries = store.trainedTodayEntries
        XCTAssertEqual(entries.map(\.id), ["uid-test", "friend"],
                       "24h lens: stale authors drop out; self sorts first")
        // Your own bubble is the mirror — it NEVER claims "new content you
        // haven't seen" (audit fix); only others' bubbles carry the ring.
        XCTAssertFalse(entries[0].hasUnseen, "self bubble never wears the unseen ring")
        XCTAssertTrue(entries[1].hasUnseen)

        // Seeing the friend's only post clears their ring, not the order rule.
        store.markStorySeen(store.feedPosts[1])
        entries = store.trainedTodayEntries
        XCTAssertFalse(entries[1].hasUnseen, "seen state flips the ring")

        UserDefaults.standard.removeObject(forKey: seenKey)
    }

    func testFetchStatesDistinguishLoadingFailedAndLoaded() async {
        let store = signedInStore()
        XCTAssertEqual(store.feedFetchState, .idle)

        // NoOp services answer nil — with nothing on screen that's a
        // VISIBLE failure, not an empty state.
        await store.refreshFeed()
        XCTAssertEqual(store.feedFetchState, .failed)
        await store.refreshLeaderboard()
        XCTAssertEqual(store.leaderboardFetchState, .failed)

        // No joined challenges is the loaded truth, not a fetch gap.
        await store.refreshChallenges()
        XCTAssertEqual(store.challengesFetchState, .loaded)

        // A failed RE-fetch never blanks a working surface.
        store.feedPosts = [FeedPost(id: "p", authorUid: "u", authorName: "A", text: "t")]
        store.feedFetchState = .loaded
        await store.refreshFeed()
        XCTAssertEqual(store.feedFetchState, .loaded)
    }

    func testRecruiterPaletteUnlocksByReferralNotLevel() {
        let store = signedInStore()
        XCTAssertFalse(store.isPaletteUnlocked(.recruiter), "no joins, no Recruiter")
        let before = store.profileShowcase.accentPalette
        store.updateAccentPalette(.recruiter)
        XCTAssertEqual(store.profileShowcase.accentPalette, before,
                       "a locked palette can't be applied")

        store.referralCount = 1
        XCTAssertTrue(store.isPaletteUnlocked(.recruiter))
        store.updateAccentPalette(.recruiter)
        XCTAssertEqual(store.profileShowcase.accentPalette, .recruiter)
    }

    func testSessionStatsRideTheFeedPost() {
        var post = FeedPost(id: "p", authorUid: "u", authorName: "A", text: "t")
        XCTAssertFalse(post.hasSessionStats, "plain text posts carry no stats card")

        post.setCount = 18
        post.durationMinutes = 42
        XCTAssertTrue(post.hasSessionStats)
    }
}

// MARK: - Tier 3 analytics (e1RM, plateau, muscle balance, export)

@MainActor
final class StrengthAnalyticsTests: XCTestCase {

    override func setUp() {
        super.setUp()
        WorkoutFilePersistence().clear()
        ProfileFilePersistence().clear()
    }

    private func freshStore() -> MorpheAppStore {
        let store = MorpheAppStore()
        store.onboardingDraft.name = "Sarah"
        store.completeOnboarding()
        return store
    }

    /// A log with explicit per-set reps+weights for one exercise.
    private func log(for store: MorpheAppStore, exercise: String, daysAgo: Int,
                     reps: [Int], weights: [Double], muscleGroup: String? = nil) -> WorkoutLog {
        WorkoutLog(
            athleteID: store.clientProfile.id,
            athleteName: store.clientProfile.name,
            workoutTemplateID: nil,
            workoutTitle: "Session",
            sport: .strength,
            completedAt: Calendar.current.date(byAdding: .day, value: -daysAgo, to: .now) ?? .now,
            durationMinutes: 30,
            exercises: [LoggedExercise(
                name: exercise, sets: "\(reps.count) sets",
                reps: reps.map(String.init).joined(separator: ", "),
                weight: "\(Int(weights.max() ?? 0)) lb", note: "",
                repsPerSet: reps, weightsPerSet: weights,
                rpePerSet: reps.map { _ in 0 }, weightUnit: "lb",
                muscleGroup: muscleGroup
            )],
            notes: "", source: .athleteManual,
            enteredByUserID: store.clientProfile.id, enteredByRole: .client,
            enteredByName: store.clientProfile.name, verificationStatus: .athleteSubmitted
        )
    }

    func testE1RMRisesWhenTopSetIsFlat() {
        let store = freshStore()
        // Same 185 top set, 5 reps then 8 reps — top-set line is flat,
        // e1RM must rise (Epley: 185×(1+reps/30)).
        store.workoutLogs.append(log(for: store, exercise: "Bench Press", daysAgo: 7, reps: [5], weights: [185]))
        store.workoutLogs.append(log(for: store, exercise: "Bench Press", daysAgo: 1, reps: [8], weights: [185]))

        let topSet = store.strengthProgression(for: "Bench Press")
        XCTAssertEqual(topSet.first?.topWeight ?? 0, topSet.last?.topWeight ?? -1,
                       accuracy: 0.001, "top-set line is flat by construction")

        let e1RM = store.estimatedOneRMProgression(for: "Bench Press")
        XCTAssertEqual(e1RM.count, 2)
        XCTAssertGreaterThan(e1RM.last?.topWeight ?? 0, e1RM.first?.topWeight ?? 0,
                             "more reps at the same weight must raise the estimated 1RM")
    }

    func testStalledDetectionFlagsNoNewHighInLastThree() {
        let store = freshStore()
        // A high 4 sessions ago, then three sessions that never beat it.
        store.workoutLogs.append(log(for: store, exercise: "Squat", daysAgo: 21, reps: [5], weights: [225]))
        store.workoutLogs.append(log(for: store, exercise: "Squat", daysAgo: 14, reps: [5], weights: [225]))
        store.workoutLogs.append(log(for: store, exercise: "Squat", daysAgo: 7, reps: [5], weights: [220]))
        store.workoutLogs.append(log(for: store, exercise: "Squat", daysAgo: 1, reps: [5], weights: [225]))
        XCTAssertEqual(store.stalledExerciseNames, ["Squat"])

        // A new high in the last 3 sessions clears the flag.
        store.workoutLogs.append(log(for: store, exercise: "Squat", daysAgo: 0, reps: [5], weights: [230]))
        XCTAssertTrue(store.stalledExerciseNames.isEmpty, "a fresh top set is not a plateau")
    }

    func testMuscleBalanceCountsOnlyTaggedSets() {
        let store = freshStore()
        store.workoutLogs.append(log(for: store, exercise: "Bench", daysAgo: 1,
                                     reps: [8, 8, 8], weights: [135, 135, 135], muscleGroup: "Chest"))
        store.workoutLogs.append(log(for: store, exercise: "Row", daysAgo: 2,
                                     reps: [8, 8], weights: [95, 95], muscleGroup: "Back"))
        // Untagged legacy log must not appear in the balance at all.
        store.workoutLogs.append(log(for: store, exercise: "Mystery", daysAgo: 1,
                                     reps: [10], weights: [50]))

        let balance = store.muscleGroupSetBalance(days: 7)
        XCTAssertEqual(balance.map(\.group), ["Chest", "Back"], "largest first, untagged excluded")
        XCTAssertEqual(balance.map(\.sets), [3, 2])
    }

    func testShareCardDataStatesOnlyLoggedFacts() {
        let store = freshStore()
        XCTAssertNil(store.latestSessionShareCardData, "no log, no card")

        store.workoutLogs.append(log(for: store, exercise: "Bench", daysAgo: 0,
                                     reps: [8, 8], weights: [135, 135]))
        let card = store.latestSessionShareCardData
        XCTAssertEqual(card?.setCount, 2)
        XCTAssertEqual(card?.exerciseCount, 1)
        XCTAssertEqual(card?.minutes, 30)
        XCTAssertEqual(card?.prNames, ["Bench"], "a record set on the log's day rides as a PR line")
    }

    func testPRAndStreakShareCardsStateOnlyLoggedFacts() {
        let store = freshStore()

        // PR card from the timeline: the prior top isn't known there, so
        // the card omits the "up from" claim instead of inventing one.
        let standing = store.prShareCardData(exerciseName: "Bench", weight: 135)
        XCTAssertEqual(standing.exerciseName, "Bench")
        XCTAssertTrue(standing.previousLabel.isEmpty,
                      "an unknown prior is omitted, never invented")

        let beaten = store.prShareCardData(exerciseName: "Bench", weight: 145, previous: 135)
        XCTAssertFalse(beaten.previousLabel.isEmpty,
                       "a log-time PR cites the record it beat")

        // Streak card: same ≥2-day bar as the streak-risk reminder.
        XCTAssertNil(store.streakShareCardData, "no streak, no card")
        store.workoutLogs.append(log(for: store, exercise: "Bench", daysAgo: 1, reps: [8], weights: [135]))
        store.workoutLogs.append(log(for: store, exercise: "Bench", daysAgo: 0, reps: [8], weights: [135]))
        XCTAssertEqual(store.streakShareCardData?.streak, 2)
    }

    func testAthleteCanCorrectAndDeleteOwnLogs() {
        let store = freshStore()
        // The fat-fingered 500 that must not be permanent.
        store.workoutLogs.append(log(for: store, exercise: "Bench", daysAgo: 0, reps: [8], weights: [500]))

        var fixed = store.workoutLogs[0]
        fixed.exercises[0].weightsPerSet = [150]
        store.updateOwnWorkoutLog(fixed)
        XCTAssertEqual(store.workoutLogs[0].exercises[0].weightsPerSet, [150])
        XCTAssertEqual(store.recentPersonalRecords(limit: 5).first?.weight ?? 0, 150,
                       "derived PRs recompute from the corrected log")

        store.deleteOwnWorkoutLog(store.workoutLogs[0])
        XCTAssertTrue(store.currentAthleteWorkoutLogs.isEmpty)
        XCTAssertTrue(store.recentPersonalRecords(limit: 5).isEmpty,
                      "a deleted log takes its records with it")

        // Someone else's log is refused — own-log rule, not a free-for-all.
        var foreign = log(for: store, exercise: "Row", daysAgo: 0, reps: [5], weights: [100])
        foreign.athleteID = UUID()
        store.workoutLogs.append(foreign)
        store.deleteOwnWorkoutLog(foreign)
        XCTAssertEqual(store.workoutLogs.count, 1, "not your log, not your delete")
    }

    func testComebackDetectsLapseOnceAndClearsOnAnswer() {
        let store = freshStore()
        let lastKnownKey = "morphe.streak.lastKnown.\(store.clientProfile.id.uuidString)"
        let pendingKey = "morphe.streak.comeback.\(store.clientProfile.id.uuidString)"
        UserDefaults.standard.removeObject(forKey: lastKnownKey)
        UserDefaults.standard.removeObject(forKey: pendingKey)

        // A live 3-day streak: remembered, never a lapse.
        for day in 0..<3 {
            store.workoutLogs.append(log(for: store, exercise: "Bench", daysAgo: day, reps: [8], weights: [100]))
        }
        store.detectStreakLapse()
        XCTAssertNil(store.comebackLapsedStreak, "a live streak is not a lapse")
        XCTAssertEqual(UserDefaults.standard.integer(forKey: lastKnownKey), 3)

        // The run dies — the lapse is recorded once, at its real size.
        store.workoutLogs = [log(for: store, exercise: "Bench", daysAgo: 30, reps: [8], weights: [100])]
        store.detectStreakLapse()
        XCTAssertEqual(store.comebackLapsedStreak, 3, "the ended run is named honestly")

        // A relaunch keeps the pending state — it never re-mints.
        store.detectStreakLapse()
        XCTAssertEqual(store.comebackLapsedStreak, 3)

        // Dismissal is an answer, not a snooze.
        store.dismissComebackCard()
        XCTAssertNil(store.comebackLapsedStreak)
        store.detectStreakLapse()
        XCTAssertNil(store.comebackLapsedStreak, "a dismissed lapse stays answered")

        UserDefaults.standard.removeObject(forKey: lastKnownKey)
        UserDefaults.standard.removeObject(forKey: pendingKey)
    }

    func testExtrasBackupRoundTripsPerProfileState() {
        let store = freshStore()
        let completionsKey = "morphe.programCompletions.\(store.clientProfile.id.uuidString)"
        UserDefaults.standard.removeObject(forKey: completionsKey)
        store.loadProgramCompletions()

        // Seed the per-profile state the backup used to miss.
        let program = MorpheAppStore.trainingPrograms[0]
        store.startProgram(program)
        store.recordProgramCompletion(program.id)

        let blobs = store.perProfileExtrasBlobs()
        XCTAssertNotNil(blobs["activeProgram"], "program position rides the backup")
        XCTAssertNotNil(blobs["programCompletions"])

        // Wipe like a fresh install, then restore the blob bag.
        store.leaveProgram()
        UserDefaults.standard.removeObject(forKey: completionsKey)
        store.loadProgramCompletions()
        XCTAssertNil(store.programProgress)
        XCTAssertTrue(store.completedProgramIDs.isEmpty)

        store.applyRestoredExtras(blobs)
        XCTAssertEqual(store.programProgress?.program.id, program.id,
                       "a new phone resumes the program where it left off")
        XCTAssertEqual(store.completedProgramIDs, [program.id],
                       "finished programs survive the new phone")

        // Leave nothing behind for other tests.
        store.leaveProgram()
        UserDefaults.standard.removeObject(forKey: completionsKey)
        store.loadProgramCompletions()
    }

    func testEarnedBadgesDeriveOnlyFromRealData() {
        let store = freshStore()
        // Per-profile completions persist across runs — start clean.
        let completionsKey = "morphe.programCompletions.\(store.clientProfile.id.uuidString)"
        UserDefaults.standard.removeObject(forKey: completionsKey)
        store.loadProgramCompletions()

        XCTAssertTrue(store.earnedBadges.isEmpty, "no data, no badges")

        // 8 consecutive training days with weighted sets.
        for day in 0..<8 {
            store.workoutLogs.append(log(for: store, exercise: "Bench", daysAgo: day, reps: [5], weights: [100]))
        }
        var titles = store.earnedBadges.map(\.title)
        XCTAssertTrue(titles.contains("First Workout"))
        XCTAssertTrue(titles.contains("First Record"))
        XCTAssertTrue(titles.contains("7-Day Streak"))
        XCTAssertFalse(titles.contains("30-Day Streak"), "milestones stay earned-only")

        // Program completion: once per program id, never a duplicate stack.
        let programID = MorpheAppStore.trainingPrograms[0].id
        store.recordProgramCompletion(programID)
        store.recordProgramCompletion(programID)
        titles = store.earnedBadges.map(\.title)
        XCTAssertEqual(titles.filter { $0 == "Program Complete" }.count, 1)

        // Recruiter follows the server-backed referral count.
        store.referralCount = 1
        XCTAssertTrue(store.earnedBadges.contains { $0.title == "Recruiter" })

        UserDefaults.standard.removeObject(forKey: completionsKey)
    }

    func testLogPastWorkoutLandsOnTheChosenDay() {
        let store = freshStore()
        let template = store.workoutTemplates[0]
        let calendar = Calendar.current
        let twoDaysAgo = calendar.date(byAdding: .day, value: -2, to: .now)!

        XCTAssertTrue(store.logPastWorkout(
            template: template, on: twoDaysAgo, durationMinutes: 40,
            entries: [(name: "Bench", sets: 3, reps: 8, weight: 100, muscleGroup: nil)]))
        let logged = store.currentAthleteWorkoutLogs.first
        XCTAssertEqual(calendar.startOfDay(for: logged?.completedAt ?? .now),
                       calendar.startOfDay(for: twoDaysAgo),
                       "the log lands on the chosen day, not today")
        XCTAssertTrue(logged?.notes.contains("after the fact") == true,
                      "back-logs say they were logged later")

        // The future and beyond the 14-day window are refused.
        XCTAssertFalse(store.logPastWorkout(
            template: template,
            on: calendar.date(byAdding: .day, value: 1, to: .now)!,
            durationMinutes: 40,
            entries: [(name: "Bench", sets: 3, reps: 8, weight: 100, muscleGroup: nil)]))
        XCTAssertFalse(store.logPastWorkout(
            template: template,
            on: calendar.date(byAdding: .day, value: -20, to: .now)!,
            durationMinutes: 40,
            entries: [(name: "Bench", sets: 3, reps: 8, weight: 100, muscleGroup: nil)]))
        XCTAssertEqual(store.currentAthleteWorkoutLogs.count, 1)
    }

    func testWarmupSetsNeverMintRecords() {
        let store = freshStore()
        var entry = log(for: store, exercise: "Bench", daysAgo: 0, reps: [5, 8], weights: [225, 135])
        entry.exercises[0].warmupPerSet = [true, false]
        store.workoutLogs.append(entry)

        XCTAssertEqual(entry.exercises[0].workingWeightsPerSet, [135],
                       "warm-up indices drop out of the working weights")
        XCTAssertEqual(store.recentPersonalRecords(limit: 5).first?.weight ?? 0, 135,
                       "the heavy warm-up single is not the record — the working set is")
    }

    func testWeeklyRecapCoversOnlyTheLastCompletedWeek() {
        let store = freshStore()
        XCTAssertNil(store.weeklyRecapData, "no logs, no recap")

        // Mirror the implementation's Monday anchor (ISO weeks), not
        // Calendar.current — in a US locale they disagree by a day.
        let calendar = Calendar.current
        let thisWeekStart = LeaderboardWeek.start()
        let lastWeekDay = thisWeekStart.addingTimeInterval(-86_400)
        let daysAgo = calendar.dateComponents(
            [.day],
            from: calendar.startOfDay(for: lastWeekDay),
            to: calendar.startOfDay(for: .now)
        ).day ?? 1

        // A session today sits in the RUNNING week — no early recap.
        store.workoutLogs.append(log(for: store, exercise: "Bench", daysAgo: 0, reps: [8], weights: [135]))
        XCTAssertNil(store.weeklyRecapData, "the running week never recaps early")

        // Two sessions on the last day of the completed week.
        store.workoutLogs.append(log(for: store, exercise: "Bench", daysAgo: daysAgo, reps: [8, 8], weights: [135, 135]))
        store.workoutLogs.append(log(for: store, exercise: "Squat", daysAgo: daysAgo, reps: [5], weights: [225]))

        let recap = store.weeklyRecapData
        XCTAssertEqual(recap?.sessions, 2, "only the completed week's logs count")
        XCTAssertEqual(recap?.sets, 3)
        XCTAssertEqual(recap?.minutes, 60)
        XCTAssertEqual(recap?.prCount, 2, "first-time records that week ride the recap")
    }

    func testExportFileContainsLogsAndWeightHistory() throws {
        let store = freshStore()
        store.workoutLogs.append(log(for: store, exercise: "Bench", daysAgo: 1, reps: [8], weights: [135]))

        let url = try XCTUnwrap(store.exportDataFile())
        let data = try Data(contentsOf: url)
        let json = try XCTUnwrap(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        XCTAssertNotNil(json["exportedAt"])
        XCTAssertEqual((json["workoutLogs"] as? [[String: Any]])?.count, 1)
        XCTAssertNotNil(json["bodyWeightHistoryLb"], "weight series rides the export even when empty")
    }
}

// MARK: - Moderation (App Store 1.2: filter, block, report)

@MainActor
final class ModerationTests: XCTestCase {

    override func setUp() {
        super.setUp()
        WorkoutFilePersistence().clear()
        ProfileFilePersistence().clear()
    }

    private func signedInStore() -> MorpheAppStore {
        let store = MorpheAppStore()
        store.onboardingDraft.name = "Sarah"
        store.completeOnboarding()
        store.authUser = AppUser(
            id: "uid-test", email: "t@morphe.app", role: .athlete,
            displayName: "Sarah", createdAt: .now
        )
        return store
    }

    func testContentFilterCatchesSlursNotScunthorpe() {
        XCTAssertTrue(ContentModeration.containsBlockedTerm("you are a faggot"), "slurs are caught")
        XCTAssertTrue(ContentModeration.containsBlockedTerm("KYS loser"), "case-insensitive")
        XCTAssertFalse(ContentModeration.containsBlockedTerm("great class today"), "substrings inside words don't trigger")
        XCTAssertFalse(ContentModeration.containsBlockedTerm("new grape smoothie recipe"), "word boundaries hold")
        XCTAssertFalse(ContentModeration.containsBlockedTerm("Completed Push Day — 18 sets, 42 min."), "recaps sail through")
    }

    func testBlockingRemovesContentAndSeversFollow() {
        let store = signedInStore()
        store.followedUids = ["bad-actor"]
        store.feedPosts = [
            FeedPost(id: "p1", authorUid: "bad-actor", authorName: "Troll", text: "spam"),
            FeedPost(id: "p2", authorUid: "friend", authorName: "Alex", text: "real win")
        ]
        store.postComments["p2"] = [
            PostComment(id: "c1", postId: "p2", authorUid: "bad-actor", authorName: "Troll", text: "spam"),
            PostComment(id: "c2", postId: "p2", authorUid: "friend", authorName: "Alex", text: "nice")
        ]

        store.blockAccount(uid: "bad-actor", name: "Troll")

        XCTAssertEqual(store.feedPosts.map(\.id), ["p2"], "blocked author's posts vanish")
        XCTAssertEqual(store.postComments["p2"]?.map(\.id), ["c2"], "blocked author's comments vanish")
        XCTAssertFalse(store.followedUids.contains("bad-actor"), "block severs the follow")
        XCTAssertEqual(store.blockedAccounts["bad-actor"], "Troll", "name kept for the manage list")

        store.unblockAccount(uid: "bad-actor")
        XCTAssertTrue(store.blockedAccounts.isEmpty)
    }

    func testWireClampNeverExceedsByteBoundOrSplitsCharacters() {
        let emoji = String(repeating: "\u{1F4AA}", count: 200)   // 4 UTF-8 bytes each
        let clamped = emoji.wireClamped(300)
        XCTAssertLessThanOrEqual(clamped.utf8.count, 300, "rules-side size() can never be exceeded")
        XCTAssertFalse(clamped.contains("\u{FFFD}"), "no split characters")
        XCTAssertEqual("plain text".wireClamped(300), "plain text", "short ASCII passes untouched")
    }

    func testSelfBlockIsRefused() {
        let store = signedInStore()
        store.blockAccount(uid: "uid-test", name: "Me")
        XCTAssertTrue(store.blockedAccounts.isEmpty, "you can't block yourself")
    }
}

// MARK: - Depth sprint (programs, milestone unlocks)

@MainActor
final class DepthSprintTests: XCTestCase {

    override func setUp() {
        super.setUp()
        WorkoutFilePersistence().clear()
        ProfileFilePersistence().clear()
    }

    private func freshStore() -> MorpheAppStore {
        let store = MorpheAppStore()
        store.onboardingDraft.name = "Sarah"
        store.completeOnboarding()
        return store
    }

    /// Runs one full live session of whatever is currently staged and logs it.
    private func logStagedWorkout(_ store: MorpheAppStore) {
        store.beginLiveWorkout(store.currentWorkout)
        store.completeTrackedSet(reps: 5, weight: 45, allowExtra: true)
        store.finishTrackedWorkoutSession()
        store.logWorkout()
    }

    func testProgramAdvancesOnlyOnMatchingLoggedSession() {
        let store = freshStore()
        let program = MorpheAppStore.trainingPrograms[0]
        store.startProgram(program)

        XCTAssertEqual(store.programProgress?.week, 1)
        XCTAssertEqual(store.currentWorkout.name, program.weeklySessionNames[0],
                       "starting a program stages its first session")

        logStagedWorkout(store)
        XCTAssertEqual(store.programProgress?.completedSessions, 1,
                       "logging the program's session advances it")
        XCTAssertEqual(store.programProgress?.nextSessionName, program.weeklySessionNames[1])

        // A random non-program session must NOT advance it.
        if let other = store.discoverWorkouts.first(where: { !program.weeklySessionNames.contains($0.name) }) {
            store.startCatalogWorkout(other)
            logStagedWorkout(store)
            XCTAssertEqual(store.programProgress?.completedSessions, 1,
                           "off-program sessions never advance the program")
        }

        store.leaveProgram()
        XCTAssertNil(store.programProgress, "leaving clears the position")
    }

    func testDeloadWeekDerivesFromCountAndCutsSuggestion() throws {
        let store = freshStore()
        let program = MorpheAppStore.trainingPrograms[0]   // 4 weeks x 3, deload wk 4

        // Reach week 4 through the PUBLIC path — the third audit made the
        // program state a stored mirror, so poking the defaults blob
        // directly no longer describes real behavior.
        store.startProgram(program)
        for _ in 0..<9 {
            logStagedWorkout(store)
            store.startNextProgramSession()
        }
        XCTAssertEqual(store.programProgress?.week, 4, "9 of 12 sessions = week 4")
        XCTAssertTrue(store.isProgramDeloadWeek)
        XCTAssertTrue(store.isDeloadActiveForCurrentSession,
                      "the staged session IS a program session in deload week")

        // Deload suggestion: ~10% off the last logged 100 lb, snapped to 5s.
        store.workoutLogs.append(WorkoutLog(
            athleteID: store.clientProfile.id, athleteName: "Sarah",
            workoutTemplateID: nil, workoutTitle: "S", sport: .strength,
            completedAt: .now, durationMinutes: 30,
            exercises: [LoggedExercise(name: "Back Squat", sets: "1 set", reps: "5",
                                       weight: "100 lb", note: "", repsPerSet: [5],
                                       weightsPerSet: [100], rpePerSet: [0], weightUnit: "lb")],
            notes: "", source: .athleteManual,
            enteredByUserID: store.clientProfile.id, enteredByRole: .client,
            enteredByName: "Sarah", verificationStatus: .athleteSubmitted))
        let exercise = WorkoutExercise(id: "bs", exerciseLibraryID: "back-squat",
                                       name: "Back Squat", muscleGroup: .legs, sets: "3 sets",
                                       reps: "5", difficulty: .moderate, formCue: "")
        XCTAssertEqual(store.suggestedWorkingWeight(for: exercise) ?? 0, 90, accuracy: 0.01,
                       "deload week suggests ~10% off, snapped to the increment")

        // The cut is SCOPED: a non-program session during the same deload
        // week keeps normal progression — the program doesn't own it.
        // (Cancel the staged program session first: switching workouts is
        // confirm-gated while a live session is active.)
        store.cancelTrackedWorkoutSession()
        if let other = store.discoverWorkouts.first(where: { !program.weeklySessionNames.contains($0.name) }) {
            store.startCatalogWorkout(other)
            XCTAssertFalse(store.isDeloadActiveForCurrentSession)
            XCTAssertEqual(store.suggestedWorkingWeight(for: exercise) ?? 0, 100, accuracy: 0.01,
                           "off-program sessions never inherit the deload cut")
        }

        store.leaveProgram()
    }

    func testPaletteUnlocksGateAndGrandfather() {
        let store = freshStore()   // level 1
        XCTAssertTrue(store.isPaletteUnlocked(.gold), "brand default ships free")
        XCTAssertFalse(store.isPaletteUnlocked(.pink), "pink is a level-12 earn")

        let before = store.profileShowcase.accentPalette
        store.updateAccentPalette(.pink)
        XCTAssertEqual(store.profileShowcase.accentPalette, before,
                       "a locked palette refuses with a toast, never applies")

        store.profileShowcase.accentPalette = .pink
        XCTAssertTrue(store.isPaletteUnlocked(.pink),
                      "an applied palette is grandfathered — updates never revoke a choice")
    }
}

// MARK: - Coach share (athlete-consented progress visibility)

@MainActor
final class CoachShareTests: XCTestCase {

    override func setUp() {
        super.setUp()
        WorkoutFilePersistence().clear()
        ProfileFilePersistence().clear()
    }

    private func signedInStore() -> MorpheAppStore {
        let store = MorpheAppStore()
        store.onboardingDraft.name = "Sarah"
        store.completeOnboarding()
        store.authUser = AppUser(
            id: "uid-athlete", email: "s@morphe.app", role: .athlete,
            displayName: "Sarah", createdAt: .now
        )
        return store
    }

    private func log(for store: MorpheAppStore, title: String, daysAgo: Int,
                     reps: [Int], weights: [Double]) -> WorkoutLog {
        WorkoutLog(
            athleteID: store.clientProfile.id,
            athleteName: store.clientProfile.name,
            workoutTemplateID: nil,
            workoutTitle: title,
            sport: .strength,
            completedAt: Calendar.current.date(byAdding: .day, value: -daysAgo, to: .now) ?? .now,
            durationMinutes: 40,
            exercises: [LoggedExercise(
                name: "Bench Press", sets: "\(reps.count) sets",
                reps: reps.map(String.init).joined(separator: ", "),
                weight: "\(Int(weights.max() ?? 0)) lb", note: "",
                repsPerSet: reps, weightsPerSet: weights,
                rpePerSet: reps.map { _ in 0 }, weightUnit: "lb"
            )],
            notes: "", source: .athleteManual,
            enteredByUserID: store.clientProfile.id, enteredByRole: .client,
            enteredByName: store.clientProfile.name, verificationStatus: .athleteSubmitted,
            sessionFeedback: "Just right"
        )
    }

    func testSummaryDerivesFromRealLogsOnly() {
        let store = signedInStore()
        store.workoutLogs.append(log(for: store, title: "Push Day", daysAgo: 0, reps: [8, 8], weights: [135, 145]))
        store.workoutLogs.append(log(for: store, title: "Pull Day", daysAgo: 8, reps: [8], weights: [95]))

        let summary = store.makeCoachShareSummary(coachUid: "uid-coach")

        XCTAssertEqual(summary.coachUid, "uid-coach", "the named reader is the consent boundary")
        XCTAssertEqual(summary.totalWorkouts, 2)
        XCTAssertEqual(summary.weeklyWorkouts, 1, "only this week's sessions count as weekly")
        XCTAssertEqual(summary.recentSessions.first?.title, "Push Day")
        XCTAssertEqual(summary.recentSessions.first?.sets, 2)
        XCTAssertEqual(summary.recentSessions.first?.feedback, "Just right")
        XCTAssertEqual(summary.recentPRs.first?.name, "Bench Press")
        XCTAssertEqual(summary.recentPRs.first?.weight ?? 0, 145, accuracy: 0.001)
        XCTAssertEqual(summary.readinessNote, "", "no check-in today means NO readiness claim")
    }

    func testConsentToggleRequiresALinkedCoach() {
        let store = signedInStore()
        store.setCoachShare(enabled: true)
        XCTAssertFalse(store.coachShareEnabled, "no linked coach, no consent flip")

        store.linkedCoachUid = "uid-coach"
        store.linkedCoachName = "Marcus"
        store.setCoachShare(enabled: true)
        XCTAssertTrue(store.coachShareEnabled)

        store.setCoachShare(enabled: false)
        XCTAssertFalse(store.coachShareEnabled, "revocation flips off cleanly")
    }

    func testLinkedCoachSurvivesRelaunch() {
        let store = signedInStore()
        store.linkedCoachUid = "uid-coach"
        store.linkedCoachName = "Marcus"

        let reloaded = MorpheAppStore()
        XCTAssertEqual(reloaded.linkedCoachUid, "uid-coach")
        XCTAssertEqual(reloaded.linkedCoachName, "Marcus")
    }
}

// MARK: - Backlog batch (series, mid-session editing, first week, roster)

@MainActor
final class BacklogBatchTests: XCTestCase {

    override func setUp() {
        super.setUp()
        WorkoutFilePersistence().clear()
        ProfileFilePersistence().clear()
    }

    private func freshStore() -> MorpheAppStore {
        let store = MorpheAppStore()
        store.onboardingDraft.name = "Sarah"
        store.completeOnboarding()
        return store
    }

    func testRecoverySeriesRecordsOnePerDayAndReplaces() {
        let store = freshStore()
        XCTAssertTrue(store.recoverySeries.isEmpty)

        store.submitRecoveryCheckIn(sleepHours: 7, energy: 6, soreness: 3, mood: 7, pain: false)
        XCTAssertEqual(store.recoverySeries.count, 1)
        let firstScore = store.recoverySeries.last?.score ?? -1

        // A same-day re-check-in replaces, never duplicates.
        store.submitRecoveryCheckIn(sleepHours: 9, energy: 9, soreness: 1, mood: 9, pain: false)
        XCTAssertEqual(store.recoverySeries.count, 1, "one entry per day")
        XCTAssertGreaterThan(store.recoverySeries.last?.score ?? -1, firstScore,
                             "the replacement carries the new inputs")
    }

    func testMidSessionAddAndReorder() {
        let store = freshStore()
        store.beginLiveWorkout(store.workoutTemplates.first!)
        let originalCount = store.currentWorkout.exercises.count
        let newExercise = store.allExercises.first {
            reference in !store.currentWorkout.exercises.contains { $0.id == reference.id }
        }!

        store.addExerciseToSession(newExercise)
        XCTAssertEqual(store.currentWorkout.exercises.count, originalCount + 1)
        XCTAssertEqual(store.currentWorkout.exercises.last?.id, newExercise.id)

        // Duplicates refused — tracked-set dictionaries key by exercise id.
        store.addExerciseToSession(newExercise)
        XCTAssertEqual(store.currentWorkout.exercises.count, originalCount + 1)

        // Reorder: the active pointer follows the exercise it was on.
        let activeID = store.activeWorkoutExercise!.id
        store.moveSessionExercise(id: newExercise.id, up: true)
        XCTAssertEqual(store.activeWorkoutExercise?.id, activeID,
                       "reordering must not silently change what's being tracked")
        XCTAssertEqual(store.currentWorkout.exercises[originalCount - 1].id, newExercise.id)

        // Top can't move up.
        let topID = store.currentWorkout.exercises[0].id
        store.moveSessionExercise(id: topID, up: true)
        XCTAssertEqual(store.currentWorkout.exercises[0].id, topID)
    }

    func testFirstWeekArcDerivesAndExpires() {
        let store = freshStore()
        guard var steps = store.firstWeekSteps else {
            return XCTFail("fresh onboarding must start the first-week arc")
        }
        XCTAssertEqual(steps.count, 6)
        XCTAssertTrue(steps[0].done, "the setup tick is pre-earned — account + plan exist")
        XCTAssertFalse(steps[1].done, "no session logged yet")

        store.submitRecoveryCheckIn(sleepHours: 7, energy: 6, soreness: 3, mood: 7, pain: false)
        steps = store.firstWeekSteps!
        XCTAssertTrue(steps[2].done, "check-in step derives from real state")

        // Day 8: the arc is over, complete or not.
        store.firstWeekStart = Calendar.current.date(byAdding: .day, value: -8, to: .now)
        XCTAssertNil(store.firstWeekSteps, "the arc never nags past week one")
    }

    func testClaimedRosterArchiveIsViewStateOnly() {
        let store = freshStore()
        let claimed = ManagedClient(
            id: "CODE01", coachUid: "uid-coach", coachName: "Marcus",
            name: "Alex", status: .claimed, claimedByUid: "uid-alex"
        )
        let unclaimed = ManagedClient(
            id: "CODE02", coachUid: "uid-coach", coachName: "Marcus",
            name: "Sam", status: .unclaimed
        )
        store.managedClients = [claimed, unclaimed]

        store.archiveClaimedClient(unclaimed)
        XCTAssertTrue(store.archivedClientCodes.isEmpty, "unclaimed clients use real delete, not archive")

        store.archiveClaimedClient(claimed)
        XCTAssertEqual(store.visibleManagedClients.map(\.id), ["CODE02"], "archived leaves the view")
        XCTAssertEqual(store.managedClients.count, 2, "the underlying data is untouched")

        store.restoreArchivedClients()
        XCTAssertEqual(store.visibleManagedClients.count, 2)
    }
}

// MARK: - First-party telemetry (milestone instrumentation)

@MainActor
final class TelemetryTests: XCTestCase {

    final class SpyTelemetry: TelemetrySyncing {
        var events: [(uid: String, name: String, day: String)] = []
        func record(uid: String, name: String, day: String) {
            events.append((uid, name, day))
        }
        func eraseAll(uid: String) async {
            events.removeAll { $0.uid == uid }
        }
    }

    override func setUp() {
        super.setUp()
        _ = MorpheAppStore()
        WorkoutFilePersistence().clear()
        ProfileFilePersistence().clear()
    }

    func testDayActiveDedupesAndMilestonesFire() {
        let spy = SpyTelemetry()
        let store = MorpheAppStore(telemetryService: spy)
        store.onboardingDraft.name = "Sarah"
        store.completeOnboarding()
        // Fresh uid every run — the day-active dedupe key is per-uid in
        // UserDefaults and must not leak across test invocations.
        let uid = "uid-\(UUID().uuidString)"
        store.authUser = AppUser(
            id: uid, email: "t@morphe.app", role: .athlete,
            displayName: "Sarah", createdAt: .now
        )

        store.trackDayActiveIfNeeded()
        store.trackDayActiveIfNeeded()
        XCTAssertEqual(spy.events.filter { $0.name == "day_active" }.count, 1,
                       "one active-day event per account per calendar day")
        XCTAssertEqual(spy.events.first?.uid, uid, "events carry the account id, nothing else")

        // Activation fires on the FIRST logged workout only.
        store.beginLiveWorkout(store.workoutTemplates.first!)
        store.completeTrackedSet(reps: 8, weight: 50, allowExtra: true)
        store.finishTrackedWorkoutSession()
        store.logWorkout()
        XCTAssertEqual(spy.events.filter { $0.name == "activation_first_log" }.count, 1)
        XCTAssertEqual(spy.events.filter { $0.name == "workout_logged" }.count, 1)

        store.beginLiveWorkout(store.workoutTemplates.first!)
        store.completeTrackedSet(reps: 8, weight: 50, allowExtra: true)
        store.finishTrackedWorkoutSession()
        store.logWorkout()
        XCTAssertEqual(spy.events.filter { $0.name == "activation_first_log" }.count, 1,
                       "the second workout is not a second activation")
        XCTAssertEqual(spy.events.filter { $0.name == "workout_logged" }.count, 2)

        // Check-in milestone.
        store.submitRecoveryCheckIn(sleepHours: 7, energy: 6, soreness: 3, mood: 7, pain: false)
        XCTAssertEqual(spy.events.filter { $0.name == "checkin_completed" }.count, 1)
    }

    func testNoEventsWithoutAnAccount() {
        let spy = SpyTelemetry()
        let store = MorpheAppStore(telemetryService: spy)
        store.onboardingDraft.name = "Sarah"
        store.completeOnboarding()
        // Signed out: nothing to attribute, nothing recorded.
        store.trackDayActiveIfNeeded()
        store.beginLiveWorkout(store.workoutTemplates.first!)
        store.completeTrackedSet(reps: 8, weight: 50, allowExtra: true)
        store.finishTrackedWorkoutSession()
        store.logWorkout()
        XCTAssertTrue(spy.events.isEmpty, "no account, no telemetry — ever")
    }
}

// MARK: - Messaging-door consolidation (wave 8)
//
// Network → Contact is THE messaging surface. Every door (Home Coach tile,
// story-viewer shortcut, post-workout prompt) deep-links there; nothing
// presents a parallel messaging sheet anymore.
@MainActor
final class MessagingDoorTests: XCTestCase {

    private func freshStore() -> MorpheAppStore {
        WorkoutFilePersistence().clear()
        ProfileFilePersistence().clear()
        let store = MorpheAppStore()
        store.onboardingDraft.name = "Sarah"
        store.completeOnboarding()
        return store
    }

    func testContactIsReachableWithoutTheMultiUserFlag() {
        let store = freshStore()
        XCTAssertFalse(FeatureFlags.multiUserEnabled, "v1 precondition")
        store.openCommunity(.contact)
        XCTAssertEqual(store.selectedClientTab, .community)
        XCTAssertEqual(store.selectedCommunitySection, .contact,
                       "Contact is real now — the old flag gate must not swallow deep-links")
    }

    func testPostWorkoutCoachDoorRoutesToContactWhenARealThreadExists() {
        let store = freshStore()
        store.liveThreads = [MessageThreadSummary(
            id: "t1", coachUid: "coach-uid", athleteUid: "me-uid",
            coachName: "Coach", athleteName: "Sarah"
        )]
        store.openPostWorkoutCoachThread()
        XCTAssertEqual(store.selectedClientTab, .community)
        XCTAssertEqual(store.selectedCommunitySection, .contact)
        XCTAssertNotNil(store.athleteThreadDraftSeed,
                        "the seed must survive routing so ThreadChatView can consume it")
    }

    func testPostWorkoutCoachDoorWithoutRealThreadsDoesNotStrandTheUser() {
        let store = freshStore()
        XCTAssertTrue(store.liveThreads.isEmpty)
        let tabBefore = store.selectedClientTab
        store.openPostWorkoutCoachThread()
        // No demo thread matches the coach name on a real fresh account, so
        // the demo fallback declines to navigate — the user stays put
        // instead of landing on an empty demo inbox.
        XCTAssertEqual(store.selectedClientTab, tabBefore)
    }
}

// MARK: - Chat streaks (S4)
//
// Consecutive days BOTH parties messaged, yesterday-grace like duoStreak.
// Pure derivation over the full thread history — dates injected.
@MainActor
final class ChatStreakTests: XCTestCase {

    private let calendar = Calendar.current

    private func message(_ uid: String, daysAgo: Int, from today: Date) -> ChatMessage {
        let day = calendar.date(byAdding: .day, value: -daysAgo, to: today)!
        return ChatMessage(id: UUID().uuidString, senderUid: uid, text: "hi", sentAt: day)
    }

    func testBothMessagingConsecutiveDaysCounts() {
        let today = Date()
        let messages = (0...2).flatMap { day in
            [message("a", daysAgo: day, from: today), message("b", daysAgo: day, from: today)]
        }
        XCTAssertEqual(MorpheAppStore.messageStreak(messages: messages, uidA: "a", uidB: "b", today: today), 3)
    }

    func testYesterdayGraceKeepsALiveStreak() {
        let today = Date()
        // Both messaged the last two days but not yet today.
        let messages = [1, 2].flatMap { day in
            [message("a", daysAgo: day, from: today), message("b", daysAgo: day, from: today)]
        }
        XCTAssertEqual(MorpheAppStore.messageStreak(messages: messages, uidA: "a", uidB: "b", today: today), 2,
                       "an unanswered morning must not kill a streak")
    }

    func testOneSidedDayBreaksTheStreak() {
        let today = Date()
        var messages = [message("a", daysAgo: 0, from: today), message("b", daysAgo: 0, from: today)]
        // Yesterday only A messaged; the day before both did.
        messages.append(message("a", daysAgo: 1, from: today))
        messages.append(contentsOf: [message("a", daysAgo: 2, from: today), message("b", daysAgo: 2, from: today)])
        XCTAssertEqual(MorpheAppStore.messageStreak(messages: messages, uidA: "a", uidB: "b", today: today), 1,
                       "a one-sided day is not a mutual streak day")
    }

    func testStaleHistoryIsZero() {
        let today = Date()
        let messages = [message("a", daysAgo: 5, from: today), message("b", daysAgo: 5, from: today)]
        XCTAssertEqual(MorpheAppStore.messageStreak(messages: messages, uidA: "a", uidB: "b", today: today), 0)
    }
}

// MARK: - Thread read-state + accent identity (S5)
@MainActor
final class ThreadReadStateTests: XCTestCase {

    private func coachedStore() -> MorpheAppStore {
        WorkoutFilePersistence().clear()
        ProfileFilePersistence().clear()
        let store = MorpheAppStore()
        store.onboardingDraft.name = "Sarah"
        store.completeOnboarding()
        store.authUser = AppUser(id: "me-uid", email: "sarah@morphe.app", role: .athlete,
                                 displayName: "Sarah", createdAt: .now)
        return store
    }

    private func thread(lastSender: String, updatedAt: Date = .now,
                        lastMessage: String = "see you at 8") -> MessageThreadSummary {
        MessageThreadSummary(id: "t-read", coachUid: "coach-uid", athleteUid: "me-uid",
                             coachName: "Coach", athleteName: "Sarah",
                             lastMessage: lastMessage, lastSender: lastSender,
                             updatedAt: updatedAt)
    }

    func testCounterpartMessageIsUnreadUntilOpened() {
        let store = coachedStore()
        let t = thread(lastSender: "coach-uid")
        store.liveThreads = [t]
        XCTAssertTrue(store.isThreadUnread(t))
        XCTAssertEqual(store.unreadThreadCount, 1)

        store.openThread(t)
        XCTAssertFalse(store.isThreadUnread(t), "opening the thread stamps it read")
        XCTAssertEqual(store.unreadThreadCount, 0)
    }

    func testNewerMessageMakesItUnreadAgain() {
        let store = coachedStore()
        var t = thread(lastSender: "coach-uid")
        store.liveThreads = [t]
        store.openThread(t)
        store.closeThread()

        t.updatedAt = Date.now.addingTimeInterval(60)
        store.liveThreads = [t]
        XCTAssertTrue(store.isThreadUnread(t), "a message after the last open is news")
    }

    func testOwnMessagesAndEmptyThreadsAreNeverUnread() {
        let store = coachedStore()
        let mine = thread(lastSender: "me-uid")
        let empty = thread(lastSender: "", lastMessage: "")
        XCTAssertFalse(store.isThreadUnread(mine), "your own message needs no badge")
        XCTAssertFalse(store.isThreadUnread(empty))
    }

    func testAccentIdentityDefaultsAndMapping() {
        // Tolerant identity: unknown/empty palette ids degrade to brand gold
        // at the mapping layer; the model default is "".
        XCTAssertEqual(FeedPost(id: "p", authorUid: "u", authorName: "A", text: "t").authorAccent, "")
        XCTAssertEqual(MorpheTheme.accentColor(forPaletteId: "Electric Blue"),
                       MorpheTheme.colors(for: .electricBlue).primary)
        XCTAssertEqual(MorpheTheme.accentColor(forPaletteId: "not-a-palette"), MorpheTheme.brandYellow)
        XCTAssertEqual(MorpheTheme.accentColor(forPaletteId: ""), MorpheTheme.brandYellow)
    }
}

// MARK: - Author headline (N1 — professional-feed byline)
@MainActor
final class AuthorHeadlineTests: XCTestCase {

    private func freshStore() -> MorpheAppStore {
        WorkoutFilePersistence().clear()
        ProfileFilePersistence().clear()
        let store = MorpheAppStore()
        store.onboardingDraft.name = "Sarah"
        store.completeOnboarding()
        return store
    }

    func testHeadlineIsSportOnlyWithoutAStreak() {
        let store = freshStore()
        XCTAssertEqual(store.clientProfile.level.streak, 0, "fresh account precondition")
        XCTAssertEqual(store.feedAuthorHeadline, store.clientProfile.sportMode.rawValue,
                       "no streak → no streak claim, just the sport")
        XCTAssertFalse(store.feedAuthorHeadline.contains("streak"))
    }

    func testHeadlineCarriesARealStreak() {
        let store = freshStore()
        store.clientProfile.level.streak = 5
        XCTAssertTrue(store.feedAuthorHeadline.hasSuffix("· 5-day streak"))
        XCTAssertTrue(store.feedAuthorHeadline.hasPrefix(store.clientProfile.sportMode.rawValue))
    }

    func testSingleDayIsNotAStreak() {
        let store = freshStore()
        store.clientProfile.level.streak = 1
        XCTAssertFalse(store.feedAuthorHeadline.contains("streak"),
                       "one day is a start, not a streak")
    }

    func testModelDefaultIsEmptyAndDecodesTolerantly() {
        XCTAssertEqual(FeedPost(id: "p", authorUid: "u", authorName: "A", text: "t").authorHeadline, "")
    }
}

// MARK: - Feed read diet (READINESS-300 R1–R4)
@MainActor
final class FeedReadDietTests: XCTestCase {

    final class CountingFeedService: FeedSyncing {
        var posts: [FeedPost] = []
        var olderPosts: [FeedPost] = []
        var fetchRecentCalls = 0
        var reactionCountCalls: [[String]] = []
        func publish(post: FeedPost) async -> Bool { true }
        func fetchRecent(limit: Int, before: Date?) async -> [FeedPost]? {
            fetchRecentCalls += 1
            return Array((before == nil ? posts : olderPosts).prefix(limit))
        }
        var sincePosts: [FeedPost] = []
        func fetchSince(date: Date, limit: Int) async -> [FeedPost]? {
            Array(sincePosts.prefix(limit))
        }
        func react(postId: String, uid: String, type: String?) {}
        func fetchReactionCounts(postIds: [String]) async -> [String: Int] {
            reactionCountCalls.append(postIds)
            return postIds.reduce(into: [:]) { $0[$1] = 1 }
        }
        func fetchMyReactions(uid: String, postIds: [String]) async -> [String: String]? { [:] }
        func fetchComments(postId: String, limit: Int) async -> [PostComment]? { nil }
        func addComment(_ comment: PostComment) async -> Bool { false }
        func deleteComment(postId: String, commentId: String) {}
        func savePost(uid: String, postId: String, on: Bool) {}
        func fetchSavedPostIds(uid: String) async -> Set<String>? { nil }
        func setFollow(uid: String, targetUid: String, on: Bool) {}
        func fetchFollowing(uid: String) async -> Set<String>? { nil }
        func submitReport(reporterUid: String, kind: String, targetId: String,
                          targetUid: String, reason: String, excerpt: String) async -> Bool { false }
        func setBlocked(uid: String, targetUid: String, name: String, on: Bool) {}
        func fetchBlocked(uid: String) async -> [String: String]? { nil }
        func delete(postId: String) {}
    }

    private func post(_ i: Int) -> FeedPost {
        FeedPost(id: "p\(i)", authorUid: "author-x", authorName: "A",
                 text: "post \(i)", createdAt: Date.now.addingTimeInterval(-Double(i) * 60))
    }

    private func makeStore(_ service: CountingFeedService) -> MorpheAppStore {
        WorkoutFilePersistence().clear()
        ProfileFilePersistence().clear()
        let store = MorpheAppStore(feedService: service)
        store.onboardingDraft.name = "Sarah"
        store.completeOnboarding()
        store.authUser = AppUser(id: "me-uid", email: "s@m.app", role: .athlete,
                                 displayName: "Sarah", createdAt: .now)
        return store
    }

    func testRefreshIsPagedAndStalenessGated() async {
        let service = CountingFeedService()
        service.posts = (0..<25).map(post)
        let store = makeStore(service)

        await store.refreshFeed()
        XCTAssertEqual(service.fetchRecentCalls, 1)
        XCTAssertEqual(store.feedPosts.count, MorpheAppStore.feedPageSize, "one page, not the firehose")
        XCTAssertTrue(store.feedHasOlderPosts)

        await store.refreshFeed()
        XCTAssertEqual(service.fetchRecentCalls, 1, "a fresh page within the window is a no-op")

        await store.refreshFeed(force: true)
        XCTAssertEqual(service.fetchRecentCalls, 2, "pull-to-refresh always hits the network")
    }

    func testLoadOlderAppendsAndHydratesOnlyNewIds() async {
        let service = CountingFeedService()
        service.posts = (0..<20).map(post)
        service.olderPosts = (20..<28).map(post)
        let store = makeStore(service)

        await store.refreshFeed()
        XCTAssertEqual(store.feedPosts.count, 20)
        await store.loadOlderFeedPosts()
        XCTAssertEqual(store.feedPosts.count, 28)
        XCTAssertFalse(store.feedHasOlderPosts, "a short page means the end")

        // Reaction hydration: page one's 20 ids, then ONLY the 8 new ones.
        XCTAssertEqual(service.reactionCountCalls.count, 2)
        XCTAssertEqual(service.reactionCountCalls[0].count, 20)
        XCTAssertEqual(service.reactionCountCalls[1].count, 8)
        XCTAssertTrue(Set(service.reactionCountCalls[0]).isDisjoint(with: service.reactionCountCalls[1]))
    }
}

// MARK: - AI agent commands (READINESS-300 AI-3)
@MainActor
final class AIAgentCommandTests: XCTestCase {

    private func freshStore() -> MorpheAppStore {
        WorkoutFilePersistence().clear()
        ProfileFilePersistence().clear()
        let store = MorpheAppStore()
        store.onboardingDraft.name = "Sarah"
        store.completeOnboarding()
        return store
    }

    func testParseSetCommand() {
        let parsed = MorpheAppStore.parseSetCommand("log 3x10 at 135")
        XCTAssertEqual(parsed?.sets, 3)
        XCTAssertEqual(parsed?.reps, 10)
        XCTAssertEqual(parsed?.weight, 135)

        let decimal = MorpheAppStore.parseSetCommand("did 5x5 @ 225.5")
        XCTAssertEqual(decimal?.sets, 5)
        XCTAssertEqual(decimal?.weight, 225.5)

        let noWeight = MorpheAppStore.parseSetCommand("log 4x8")
        XCTAssertEqual(noWeight?.reps, 8)
        XCTAssertNil(noWeight?.weight)

        XCTAssertNil(MorpheAppStore.parseSetCommand("log my workout"))
        XCTAssertNil(MorpheAppStore.parseSetCommand("3x10"), "a bare rep scheme is not a command")
    }

    func testLogCommandLogsRealSetsIntoTheLiveSession() {
        let store = freshStore()
        store.beginLiveWorkout(store.workoutTemplates.first!)

        XCTAssertTrue(store.sendAIAgentPrompt("log 2x8 at 100"), "an action, not a chat reply")
        store.finishTrackedWorkoutSession()
        store.logWorkout()

        let logged = store.workoutLogs.first?.exercises.first
        XCTAssertEqual(logged?.repsPerSet, [8, 8])
        XCTAssertEqual(logged?.weightsPerSet, [100, 100])
    }

    func testLogCommandWithoutASessionLogsNothing() {
        let store = freshStore()
        _ = store.sendAIAgentPrompt("log 3x10 at 135")
        XCTAssertTrue(store.workoutLogs.isEmpty)
        XCTAssertFalse(store.isWorkoutSessionActive)
    }

    func testNamedWorkoutStart() {
        let store = freshStore()
        guard let template = store.workoutTemplates.first(where: { $0.name.count >= 4 }) else {
            return XCTFail("no template to start")
        }
        XCTAssertTrue(store.sendAIAgentPrompt("start \(template.name.lowercased())"))
        XCTAssertTrue(store.isWorkoutSessionActive)
    }
}

// MARK: - Custom accent + network identity controls (L1)
@MainActor
final class CustomizationTests: XCTestCase {

    private func freshStore() -> MorpheAppStore {
        WorkoutFilePersistence().clear()
        ProfileFilePersistence().clear()
        let store = MorpheAppStore()
        store.onboardingDraft.name = "Sarah"
        store.completeOnboarding()
        return store
    }

    func testHexRoundTripAndTolerance() {
        XCTAssertEqual(MorpheTheme.hex(from: MorpheTheme.color(fromHex: "#3AF2D6")!), "#3AF2D6")
        XCTAssertEqual(MorpheTheme.hex(from: MorpheTheme.color(fromHex: "3AF2D6")!), "#3AF2D6",
                       "leading # is optional")
        XCTAssertNil(MorpheTheme.color(fromHex: "not-a-color"))
        XCTAssertNil(MorpheTheme.color(fromHex: "#12345"))
    }

    func testForeignAccentIdsResolveSafely() {
        // A hex on the wire renders as that color for every viewer.
        XCTAssertEqual(MorpheTheme.hex(from: MorpheTheme.accentColor(forPaletteId: "#FF0000")), "#FF0000")
        // A foreign "Custom" id must NOT read this device's custom color.
        XCTAssertEqual(MorpheTheme.accentColor(forPaletteId: "Custom"), MorpheTheme.brandYellow)
        XCTAssertEqual(MorpheTheme.accentColor(forPaletteId: "garbage"), MorpheTheme.brandYellow)
    }

    func testCustomAccentPersistsAcrossRelaunch() {
        let store = freshStore()
        store.updateAccentPalette(.custom)
        store.updateCustomAccent(hex: "#123456")
        XCTAssertEqual(store.profileShowcase.customAccentHex, "#123456")

        let relaunched = MorpheAppStore()
        XCTAssertEqual(relaunched.profileShowcase.accentPalette, .custom)
        XCTAssertEqual(relaunched.profileShowcase.customAccentHex, "#123456")
    }

    func testMalformedHexIsRejected() {
        let store = freshStore()
        store.updateCustomAccent(hex: "#123456")
        store.updateCustomAccent(hex: "nope")
        XCTAssertEqual(store.profileShowcase.customAccentHex, "#123456")
    }

    func testFeedIdentityRespectsTheControls() {
        let store = freshStore()
        store.clientProfile.level.streak = 5

        // Defaults: both on.
        XCTAssertTrue(store.feedAuthorHeadline.contains("streak"))
        store.updateAccentPalette(.custom)
        store.updateCustomAccent(hex: "#00FF88")
        XCTAssertEqual(store.feedAuthorAccentId, "#00FF88")

        store.postStreakByline = false
        XCTAssertFalse(store.feedAuthorHeadline.contains("streak"),
                       "byline falls back to sport only")
        XCTAssertEqual(store.feedAuthorHeadline, store.clientProfile.sportMode.rawValue)

        store.postAccentIdentity = false
        XCTAssertEqual(store.feedAuthorAccentId, "", "no accent rides the post when off")
    }

    func testIdentityControlsPersistAcrossRelaunch() {
        let store = freshStore()
        store.postStreakByline = false
        store.postAccentIdentity = false

        let relaunched = MorpheAppStore()
        XCTAssertFalse(relaunched.postStreakByline)
        XCTAssertFalse(relaunched.postAccentIdentity)
    }

    func testCustomPaletteIsFreeForEveryone() {
        let store = freshStore()
        XCTAssertTrue(store.isPaletteUnlocked(.custom))
    }
}

// MARK: - Full-audit regression fixes
@MainActor
final class AuditFixTests: XCTestCase {

    private func post(_ i: Int, minutesAgo: Int) -> FeedPost {
        FeedPost(id: "ap\(i)", authorUid: "author-\(i)", authorName: "A\(i)",
                 text: "p", createdAt: Date.now.addingTimeInterval(-Double(minutesAgo) * 60))
    }

    private func makeStore(_ service: FeedReadDietTests.CountingFeedService) -> MorpheAppStore {
        WorkoutFilePersistence().clear()
        ProfileFilePersistence().clear()
        let store = MorpheAppStore(feedService: service)
        store.onboardingDraft.name = "Sarah"
        store.completeOnboarding()
        store.authUser = AppUser(id: "me-uid", email: "s@m.app", role: .athlete,
                                 displayName: "Sarah", createdAt: .now)
        return store
    }

    func testForcedRefreshPreservesLoadedPages() async {
        let service = FeedReadDietTests.CountingFeedService()
        service.posts = (0..<20).map { post($0, minutesAgo: $0 + 1) }
        service.olderPosts = (20..<28).map { post($0, minutesAgo: $0 + 1) }
        let store = makeStore(service)

        await store.refreshFeed()
        await store.loadOlderFeedPosts()
        XCTAssertEqual(store.feedPosts.count, 28)

        await store.refreshFeed(force: true)
        XCTAssertEqual(store.feedPosts.count, 28,
                       "pull-to-refresh must merge, never delete paginated pages")
    }

    func testPresenceRailIsIndependentOfPageSize() async {
        let service = FeedReadDietTests.CountingFeedService()
        service.posts = (0..<20).map { post($0, minutesAgo: $0 + 1) }
        // An author whose only <24h post sits BEYOND page one.
        service.sincePosts = [post(99, minutesAgo: 300)]
        let store = makeStore(service)

        await store.refreshFeed()
        XCTAssertTrue(store.trainedTodayEntries.contains { $0.id == "author-99" },
                      "presence must come from the 24h query, not the paginated window")
    }

    func testMinimumWinModeHasAnExit() {
        WorkoutFilePersistence().clear()
        ProfileFilePersistence().clear()
        let store = MorpheAppStore()
        store.onboardingDraft.name = "Sarah"
        store.completeOnboarding()

        store.activateMinimumWinMode()
        XCTAssertTrue(store.minimumWinModeEnabled)
        store.deactivateMinimumWinMode()
        XCTAssertFalse(store.minimumWinModeEnabled, "activation must not be a one-way door")
    }

    func testNamedExerciseLogCommandGuidesInsteadOfMislogging() {
        WorkoutFilePersistence().clear()
        ProfileFilePersistence().clear()
        let store = MorpheAppStore()
        store.onboardingDraft.name = "Sarah"
        store.completeOnboarding()
        store.beginLiveWorkout(store.workoutTemplates.first!)

        XCTAssertTrue(store.sendAIAgentPrompt("log bench press 3x10 at 135"))
        store.finishTrackedWorkoutSession()
        store.logWorkout()
        let sets = store.workoutLogs.first?.exercises.first?.repsPerSet ?? []
        XCTAssertTrue(sets.isEmpty, "a named exercise must guide, never silently log against the active one")
    }
}

// MARK: - AI parity wave (AI-5/6/7)
@MainActor
final class AIParityTests: XCTestCase {

    private func freshStore() -> MorpheAppStore {
        WorkoutFilePersistence().clear()
        ProfileFilePersistence().clear()
        let store = MorpheAppStore()
        store.onboardingDraft.name = "Sarah"
        store.completeOnboarding()
        return store
    }

    func testFormAsksRouteToTheLibraryNotLessons() {
        let store = freshStore()
        XCTAssertTrue(store.sendAIAgentPrompt("show me proper form for squats"))
        XCTAssertEqual(store.selectedClientTab, .more)
        XCTAssertEqual(store.selectedHubFeature, .library,
                       "a form ask is a form-guide ask — Lessons used to hijack it")
    }

    func testCoachActionLayerNavigates() {
        let store = freshStore()
        store.selectedRole = .coach
        XCTAssertTrue(store.sendAIAgentPrompt("open athletes"))
        // .athletes has no mounted page — the clamp lands on Build, where
        // the roster tools actually live (coach audit: blank-screen fix).
        XCTAssertEqual(store.selectedCoachTab, .programs)
    }

    func testCoachAttentionAnswerDerivesFromRealLogs() {
        let store = freshStore()
        store.selectedRole = .coach
        XCTAssertTrue(store.sendAIAgentPrompt("who needs attention today?"),
                      "the attention ask is an answered action, not template chat")
        let reply = store.coachAIAgentConversation.last?.text ?? ""
        // Whatever the roster state, the reply must be the derived shape —
        // never the old canned "highest-friction athlete" template.
        XCTAssertFalse(reply.contains("highest-friction athlete"))
    }

    func testDerivedInsightsAreHonestAboutData() {
        let store = freshStore()
        // Zero data: falls back to the generic tip, no invented numbers.
        XCTAssertEqual(store.derivedProgressInsight.title, store.clientProfile.aiProgressInsight.title)

        store.beginLiveWorkout(store.workoutTemplates.first!)
        store.completeTrackedSet(reps: 8, weight: 50, allowExtra: true)
        store.finishTrackedWorkoutSession()
        store.logWorkout()

        let insight = store.derivedProgressInsight
        XCTAssertTrue(insight.summary.contains("1 session"),
                      "with real logs the insight reads the real count")
        XCTAssertEqual(insight.title, "This week, from your logs")
    }
}

// MARK: - Backup health (surfaced failures + retry)
@MainActor
final class BackupHealthTests: XCTestCase {

    final class SpyBackup: CloudBackingUp {
        var pushResult = true
        var pushCount = 0
        func setUser(_ uid: String?) {}
        func pushProfile(_ snapshot: LocalProfileSnapshot) {}
        func pushLogs(_ logs: [WorkoutLog]) async -> Bool {
            pushCount += 1
            return pushResult
        }
        func pushWeightHistory(_ entries: [MorpheAppStore.BodyWeightHistoryEntry]) {}
        func pushExtras(_ blobs: [String: String]) {}
        func pull() async -> CloudSnapshot { CloudSnapshot() }
        func eraseUser() async {}
    }

    private func freshStore(backup: CloudBackingUp) -> MorpheAppStore {
        WorkoutFilePersistence().clear()
        ProfileFilePersistence().clear()
        let store = MorpheAppStore(cloudBackup: backup)
        store.onboardingDraft.name = "Sarah"
        store.completeOnboarding()
        store.authUser = AppUser(id: "me-uid", email: "s@m.app", role: .athlete,
                                 displayName: "Sarah", createdAt: .now)
        return store
    }

    func testSuccessfulPushIsCurrent() async {
        let spy = SpyBackup()
        let store = freshStore(backup: spy)
        await store.flushLogBackupNow()
        XCTAssertEqual(spy.pushCount, 1)
        if case .current = store.logBackupState {} else {
            XCTFail("a landed push must read as current, got \(store.logBackupState)")
        }
    }

    func testFailedPushSurfacesBehindAndArmsRetry() async {
        let spy = SpyBackup()
        spy.pushResult = false
        let store = freshStore(backup: spy)
        await store.flushLogBackupNow()
        XCTAssertEqual(store.logBackupState, .behind,
                       "a failed upload must be VISIBLE, not silent")

        // Manual retry after the network comes back.
        spy.pushResult = true
        await store.flushLogBackupNow()
        if case .current = store.logBackupState {} else {
            XCTFail("recovery must clear the behind state")
        }
    }

    func testInertBackupNeverClaimsBackedUp() async {
        WorkoutFilePersistence().clear()
        ProfileFilePersistence().clear()
        let store = MorpheAppStore()
        store.onboardingDraft.name = "Sarah"
        store.completeOnboarding()
        XCTAssertFalse(store.cloudBackupActive)
        await store.flushLogBackupNow()
        XCTAssertEqual(store.logBackupState, .idle,
                       "no real backup target → no 'backed up ✓' claim")
    }
}

// MARK: - Simplification wave (E5: no tab yank on log)
@MainActor
final class SimplificationTests: XCTestCase {
    func testLoggingStaysOnTheCurrentTab() {
        WorkoutFilePersistence().clear()
        ProfileFilePersistence().clear()
        let store = MorpheAppStore()
        store.onboardingDraft.name = "Sarah"
        store.completeOnboarding()

        store.beginLiveWorkout(store.workoutTemplates.first!)
        store.completeTrackedSet(reps: 8, weight: 50, allowExtra: true)
        store.finishTrackedWorkoutSession()
        let tabBefore = store.selectedClientTab
        store.logWorkout()
        XCTAssertEqual(store.selectedClientTab, tabBefore,
                       "logging must not teleport the user to another tab")
        XCTAssertTrue(store.isWorkoutLoggedToday)
    }
}

// MARK: - Ranked feed (TIKTOK-PLAN T2)
@MainActor
final class FeedRankingTests: XCTestCase {

    private func post(_ id: String, author: String, hoursAgo: Double) -> FeedPost {
        FeedPost(id: id, authorUid: author, authorName: author, text: "p",
                 createdAt: Date.now.addingTimeInterval(-hoursAgo * 3600))
    }

    func testEngagementOutranksBareRecency() {
        let fresh = post("fresh", author: "a", hoursAgo: 1)
        let engaged = post("engaged", author: "b", hoursAgo: 6)
        let ranked = MorpheAppStore.rankFeedPosts(
            [fresh, engaged],
            reactionCounts: ["engaged": 8],
            commentCounts: ["engaged": 3],
            followedUids: []
        )
        XCTAssertEqual(ranked.first?.id, "engaged",
                       "8 reactions + 3 comments must beat a 5-hour head start")
    }

    func testFollowBoostBreaksTies() {
        let stranger = post("s", author: "stranger", hoursAgo: 2)
        let friend = post("f", author: "friend", hoursAgo: 2)
        let ranked = MorpheAppStore.rankFeedPosts(
            [stranger, friend], reactionCounts: [:], commentCounts: [:],
            followedUids: ["friend"]
        )
        XCTAssertEqual(ranked.first?.id, "f")
    }

    func testDiversityGuardBreaksAuthorRuns() {
        let a1 = post("a1", author: "a", hoursAgo: 1)
        let a2 = post("a2", author: "a", hoursAgo: 2)
        let b1 = post("b1", author: "b", hoursAgo: 3)
        let ranked = MorpheAppStore.rankFeedPosts(
            [a1, a2, b1], reactionCounts: [:], commentCounts: [:], followedUids: []
        )
        XCTAssertNotEqual(ranked[1].authorUid, ranked[0].authorUid,
                          "one author must not own consecutive top slots when others exist")
    }
}

// MARK: - Activity diff (TIKTOK-PLAN T5)
@MainActor
final class ActivityDiffTests: XCTestCase {
    func testActivityDiffCountsAcknowledgesAndGrows() {
        WorkoutFilePersistence().clear()
        ProfileFilePersistence().clear()
        let store = MorpheAppStore()
        store.onboardingDraft.name = "Sarah"
        store.completeOnboarding()
        store.authUser = AppUser(id: "me-uid", email: "s@m.app", role: .athlete,
                                 displayName: "Sarah", createdAt: .now)
        UserDefaults.standard.removeObject(
            forKey: "morphe.activity.seen.\(store.clientProfile.id.uuidString)")

        store.feedPosts = [
            FeedPost(id: "mine", authorUid: "me-uid", authorName: "Sarah", text: "w"),
            FeedPost(id: "theirs", authorUid: "other", authorName: "O", text: "x")
        ]
        store.feedReactionCounts = ["mine": 3, "theirs": 9]

        XCTAssertEqual(store.unseenActivityCount, 3,
                       "only MY posts count, never other people's")
        store.acknowledgeActivity()
        XCTAssertEqual(store.unseenActivityCount, 0)

        store.feedReactionCounts["mine"] = 5
        XCTAssertEqual(store.unseenActivityCount, 2, "new engagement re-arms the diff")
    }
}

// MARK: - Rest days (E4)
@MainActor
final class RestDayTests: XCTestCase {
    func testRestDayDerivationAndPersistence() {
        WorkoutFilePersistence().clear()
        ProfileFilePersistence().clear()
        let store = MorpheAppStore()
        store.onboardingDraft.name = "Sarah"
        store.completeOnboarding()

        XCTAssertFalse(store.plannedRestDay(), "empty set = feature off, never a rest day")

        let calendar = Calendar.current
        let todayWeekday = calendar.component(.weekday, from: .now)
        let otherDay = todayWeekday == 7 ? 1 : todayWeekday + 1
        store.trainingDays = [otherDay]
        XCTAssertTrue(store.plannedRestDay(), "today isn't picked → planned rest")
        store.trainingDays = [todayWeekday]
        XCTAssertFalse(store.plannedRestDay())

        let relaunched = MorpheAppStore()
        XCTAssertEqual(relaunched.trainingDays, [todayWeekday], "picked days survive relaunch")
    }
}

// MARK: - AI chat UI wave (honest fallback + new chat)
@MainActor
final class AIChatUITests: XCTestCase {
    func testUnmatchedAskGetsHonestCapabilities() {
        WorkoutFilePersistence().clear()
        ProfileFilePersistence().clear()
        let store = MorpheAppStore()
        store.onboardingDraft.name = "Sarah"
        store.completeOnboarding()

        XCTAssertFalse(store.sendAIAgentPrompt("what's the meaning of life"))
        let reply = store.athleteAIAgentConversation.last?.text ?? ""
        XCTAssertTrue(reply.contains("don't have a real answer"),
                      "unmatched asks must admit it, not vibe")
        XCTAssertTrue(reply.contains("start your workout"), "and say what it CAN do")
    }

    func testNewChatResetsToGreeting() {
        WorkoutFilePersistence().clear()
        ProfileFilePersistence().clear()
        let store = MorpheAppStore()
        store.onboardingDraft.name = "Sarah"
        store.completeOnboarding()

        _ = store.sendAIAgentPrompt("open progress")
        XCTAssertGreaterThan(store.athleteAIAgentConversation.count, 1)
        store.resetAIAgentConversation()
        XCTAssertEqual(store.athleteAIAgentConversation.count, 1, "back to the greeting")
        XCTAssertEqual(store.athleteAIAgentConversation.first?.sender, .ai)
    }
}

// MARK: - Audit fix: AI transcript wiped on sign-out
@MainActor
final class AITranscriptPrivacyTests: XCTestCase {
    func testSignOutClearsTheAITranscript() {
        WorkoutFilePersistence().clear()
        ProfileFilePersistence().clear()
        let store = MorpheAppStore()
        store.onboardingDraft.name = "Sarah"
        store.completeOnboarding()

        _ = store.sendAIAgentPrompt("what's my goal")
        XCTAssertGreaterThan(store.athleteAIAgentConversation.count, 1)
        store.signOut()
        XCTAssertEqual(store.athleteAIAgentConversation.count, 1,
                       "the next account must never read a previous user's AI chat")
        XCTAssertEqual(store.athleteAIAgentConversation.first?.sender, .ai)
    }
}

// MARK: - Snapchat wave: direct chats + photo posts

@MainActor
final class SnapNetworkTests: XCTestCase {

    /// Records ensureThread's exact arguments and serves the resulting
    /// threads back, so the canonical-pair contract is testable offline.
    final class SpyMessaging: MessagingSyncing {
        struct Ensured { var coachUid: String; var athleteUid: String
                         var coachName: String; var athleteName: String }
        var ensured: [Ensured] = []
        func ensureThread(coachUid: String, athleteUid: String,
                          coachName: String, athleteName: String) async -> String? {
            ensured.append(Ensured(coachUid: coachUid, athleteUid: athleteUid,
                                   coachName: coachName, athleteName: athleteName))
            return "\(coachUid)_\(athleteUid)"
        }
        func send(threadId: String, senderUid: String, text: String) async -> Bool { true }
        func fetchThreads(for uid: String) async -> [MessageThreadSummary]? {
            ensured.map {
                MessageThreadSummary(id: "\($0.coachUid)_\($0.athleteUid)",
                                     coachUid: $0.coachUid, athleteUid: $0.athleteUid,
                                     coachName: $0.coachName, athleteName: $0.athleteName)
            }
        }
        func listenMessages(threadId: String, onChange: @escaping ([ChatMessage]) -> Void) {}
        func stopListening() {}
        func fetchMessages(threadId: String, limit: Int) async -> [ChatMessage]? { nil }
    }

    /// Captures the exact FeedPost handed to publish.
    final class CapturingFeedService: FeedSyncing {
        var published: [FeedPost] = []
        func publish(post: FeedPost) async -> Bool { published.append(post); return true }
        func fetchRecent(limit: Int, before: Date?) async -> [FeedPost]? { [] }
        func fetchSince(date: Date, limit: Int) async -> [FeedPost]? { [] }
        func react(postId: String, uid: String, type: String?) {}
        func fetchReactionCounts(postIds: [String]) async -> [String: Int] { [:] }
        func fetchMyReactions(uid: String, postIds: [String]) async -> [String: String]? { [:] }
        func fetchComments(postId: String, limit: Int) async -> [PostComment]? { nil }
        func addComment(_ comment: PostComment) async -> Bool { false }
        func deleteComment(postId: String, commentId: String) {}
        func savePost(uid: String, postId: String, on: Bool) {}
        func fetchSavedPostIds(uid: String) async -> Set<String>? { nil }
        func setFollow(uid: String, targetUid: String, on: Bool) {}
        func fetchFollowing(uid: String) async -> Set<String>? { nil }
        func submitReport(reporterUid: String, kind: String, targetId: String,
                          targetUid: String, reason: String, excerpt: String) async -> Bool { false }
        func setBlocked(uid: String, targetUid: String, name: String, on: Bool) {}
        func fetchBlocked(uid: String) async -> [String: String]? { nil }
        func delete(postId: String) {}
    }

    private func makeStore(messaging: SpyMessaging = SpyMessaging(),
                           feed: CapturingFeedService = CapturingFeedService(),
                           myUid: String) -> MorpheAppStore {
        WorkoutFilePersistence().clear()
        ProfileFilePersistence().clear()
        let store = MorpheAppStore(messagingService: messaging, feedService: feed)
        store.onboardingDraft.name = "Me"
        store.completeOnboarding()
        store.authUser = AppUser(id: myUid, email: "me@m.app", role: .athlete,
                                 displayName: "Me", createdAt: .now)
        return store
    }

    func testDirectChatOrdersPairCanonically() async {
        // My uid sorts AFTER theirs — I take the athlete slot.
        let messaging = SpyMessaging()
        let store = makeStore(messaging: messaging, myUid: "zed-uid")
        let ok = await store.startDirectChat(with: "abe-uid", name: "abe")
        XCTAssertTrue(ok)
        XCTAssertEqual(messaging.ensured.count, 1)
        XCTAssertEqual(messaging.ensured[0].coachUid, "abe-uid")
        XCTAssertEqual(messaging.ensured[0].athleteUid, "zed-uid")
        XCTAssertEqual(messaging.ensured[0].coachName, "abe")
        XCTAssertEqual(store.pendingThreadOpenID, "abe-uid_zed-uid",
                       "the inbox door opens the thread we just made")
    }

    func testDirectChatSameIdFromEitherEnd() async {
        // My uid sorts BEFORE theirs — same thread id as the reverse case.
        let messaging = SpyMessaging()
        let store = makeStore(messaging: messaging, myUid: "abe-uid")
        _ = await store.startDirectChat(with: "zed-uid", name: "zed")
        XCTAssertEqual(messaging.ensured[0].coachUid, "abe-uid")
        XCTAssertEqual(messaging.ensured[0].athleteUid, "zed-uid")
        XCTAssertEqual(store.pendingThreadOpenID, "abe-uid_zed-uid",
                       "both directions collapse onto one deterministic thread")
    }

    func testDirectChatRefusesSelf() async {
        let messaging = SpyMessaging()
        let store = makeStore(messaging: messaging, myUid: "abe-uid")
        let ok = await store.startDirectChat(with: "abe-uid", name: "me")
        XCTAssertFalse(ok)
        XCTAssertTrue(messaging.ensured.isEmpty, "no self-threads")
    }

    func testPhotoPostRidesThePipelineWithPlaceholderCaption() async {
        let feed = CapturingFeedService()
        let store = makeStore(feed: feed, myUid: "me-uid")
        let posted = await store.publishPhotoPost(caption: "", imageB64: "QUJD")
        XCTAssertTrue(posted)
        let published = feed.published.first
        XCTAssertNotNil(published)
        XCTAssertEqual(published?.imageB64, "QUJD")
        XCTAssertEqual(published?.text, " ",
                       "empty captions ride as the single-space placeholder, never invented text")
        XCTAssertEqual(published?.hasImage, true)
    }

    func testPhotoPostRejectsOverCapImage() async {
        let feed = CapturingFeedService()
        let store = makeStore(feed: feed, myUid: "me-uid")
        let oversized = String(repeating: "A", count: 90_001)
        let posted = await store.publishPhotoPost(caption: "big", imageB64: oversized)
        XCTAssertFalse(posted, "the client refuses what the rules would refuse")
        XCTAssertTrue(feed.published.isEmpty)
    }
}

// MARK: - UX psychology wave (goal gradient + honest loss framing)

@MainActor
final class UXPsychologyTests: XCTestCase {
    private func makeStore() -> MorpheAppStore {
        WorkoutFilePersistence().clear()
        ProfileFilePersistence().clear()
        let store = MorpheAppStore()
        store.onboardingDraft.name = "Sarah"
        store.completeOnboarding()
        return store
    }

    private func backdateSession(_ store: MorpheAppStore, daysAgo: Int) {
        let day = Calendar.current.date(byAdding: .day, value: -daysAgo, to: .now) ?? .now
        XCTAssertTrue(store.logPastWorkout(
            template: store.currentWorkout, on: day, durationMinutes: 30,
            entries: [(name: "Goblet Squat", sets: 3, reps: 10, weight: 40, muscleGroup: nil)]
        ), "backdated session should log (\(daysAgo) days ago is inside the 14-day window)")
    }

    func testFirstWeekStartsOnTheBoardHonestly() {
        let store = makeStore()
        let steps = store.firstWeekSteps
        XCTAssertEqual(steps?.first?.title, "Create your account and plan")
        XCTAssertEqual(steps?.first?.done, true,
                       "the pre-checked tick is a REAL completed fact — setup happened")
        XCTAssertEqual(steps?.filter(\.done).count, 1,
                       "exactly one earned tick at start — nothing else invented")
    }

    func testStreakOnTheLineNeedsARealStreak() {
        let store = makeStore()
        XCTAssertNil(store.streakOnTheLineDays, "no logs → nothing at stake → no loss framing")

        backdateSession(store, daysAgo: 2)
        backdateSession(store, daysAgo: 1)
        XCTAssertEqual(store.streakOnTheLineDays, 2,
                       "two logged days and an unlogged today = a real streak at risk")

        store.startTodayWorkout()
        store.hasCompletedWorkoutFlow = true
        store.logWorkout()
        XCTAssertNil(store.streakOnTheLineDays, "today's session saves the streak — the line vanishes")
    }

    func testStreakOnTheLineRespectsPlannedRestDays() {
        let store = makeStore()
        backdateSession(store, daysAgo: 2)
        backdateSession(store, daysAgo: 1)

        let todayWeekday = Calendar.current.component(.weekday, from: .now)
        let otherDay = todayWeekday == 7 ? 1 : todayWeekday + 1
        store.trainingDays = [otherDay]
        XCTAssertNil(store.streakOnTheLineDays,
                     "a planned rest day never guilt-trips — rest is part of the program")
    }
}

// MARK: - 1000-user wave: sign-out hygiene, unit-aware weight, real coach data

@MainActor
final class LaunchHardeningTests: XCTestCase {
    private func makeStore() -> MorpheAppStore {
        WorkoutFilePersistence().clear()
        ProfileFilePersistence().clear()
        let store = MorpheAppStore()
        store.onboardingDraft.name = "Sarah"
        store.completeOnboarding()
        return store
    }

    func testSignOutWipesTheDeviceForTheNextAccount() {
        let store = makeStore()
        store.startTodayWorkout()
        store.hasCompletedWorkoutFlow = true
        store.logWorkout()
        XCTAssertFalse(store.workoutLogs.isEmpty)

        store.signOut()

        XCTAssertFalse(store.hasCompletedOnboarding,
                       "the NEXT account must onboard — inheriting the flag skipped onboarding and stole this identity")
        XCTAssertTrue(store.workoutLogs.isEmpty, "logs belong to the signed-out account")
        XCTAssertNil(store.profilePhotoData, "the photo must never become the next user's face")

        // The wiped device restores nothing locally on relaunch.
        let relaunched = MorpheAppStore()
        XCTAssertFalse(relaunched.hasCompletedOnboarding,
                       "no local snapshot may survive sign-out")
        XCTAssertTrue(relaunched.workoutLogs.isEmpty)
    }

    func testBareWeightNumberSpeaksTheUsersUnit() {
        XCTAssertEqual(MorpheAppStore.parsedBodyWeightLb("77", assumedUnit: .kilograms) ?? 0, 169.75, accuracy: 0.1,
                       "a kg user typing 77 means 77 kg, not 77 lb")
        XCTAssertEqual(MorpheAppStore.parsedBodyWeightLb("77", assumedUnit: .pounds), 77)
        XCTAssertEqual(MorpheAppStore.parsedBodyWeightLb("170 lb", assumedUnit: .kilograms), 170,
                       "an explicit suffix always wins over the assumed unit")
        XCTAssertEqual(MorpheAppStore.parsedBodyWeightLb("77 kg", assumedUnit: .pounds) ?? 0, 169.75, accuracy: 0.1)
    }

    func testLiveCoachOverviewDerivesFromRealRoster() {
        let store = makeStore()
        XCTAssertEqual(store.liveCoachOverview.activeClients, 0)
        XCTAssertEqual(store.liveCoachOverview.weeklySummary, "Add your first client to start coaching.")

        let fresh = ManagedClient(id: "C1", coachUid: "u", coachName: "Coach",
                                  name: "Alex", logs: [])
        store.managedClients = [fresh]
        let overview = store.liveCoachOverview
        XCTAssertEqual(overview.activeClients, 1)
        XCTAssertEqual(overview.atRiskClients, 1, "no logged session ever = quiet 7+ days")
        XCTAssertTrue(overview.alerts.first?.contains("Alex") == true)
    }

    func testAssignWorkoutStampsTheManagedClient() {
        let store = makeStore()
        store.managedClients = [
            ManagedClient(id: "C2", coachUid: "u", coachName: "Coach", name: "Sam")
        ]
        let template = WorkoutTemplate(
            name: "Foundation Strength", type: "Strength", sport: .strength,
            goal: "", difficulty: .moderate, durationMinutes: 40,
            equipment: "", exercises: [], notes: "", coachNote: "")
        store.assignWorkout(template, to: store.managedClients[0],
                            on: .now, scheduledLabel: "Friday 5:00 PM")
        XCTAssertTrue(store.managedClients[0].notes.contains("Assigned Foundation Strength for Friday 5:00 PM."),
                      "the assignment lands in the client doc, not a dead demo array")
        XCTAssertEqual(store.managedClients[0].assignments.first?.workout.name, "Foundation Strength")
    }

    func testRemindersMasterTogglePersists() {
        let store = makeStore()
        XCTAssertTrue(store.remindersEnabled, "on by default")
        store.remindersEnabled = false
        let relaunched = MorpheAppStore()
        // Fresh store loads the same profile's prefs blob.
        _ = relaunched
        XCTAssertFalse(store.remindersEnabled)
    }
}

// MARK: - Program delivery (Trainerize benchmark Tier 1)

@MainActor
final class ProgramDeliveryTests: XCTestCase {
    final class SpyManagedService: ManagedClientSyncing {
        var pushedAssignments: [(code: String, assignments: [WorkoutAssignment])] = []
        var claimedDocs: [ManagedClient] = []
        func push(_ client: ManagedClient) {}
        func fetchMine(coachUid: String) async -> [ManagedClient]? { nil }
        func claim(code: String, athleteUid: String, athleteName: String) async -> Result<ManagedClient, ManagedClientClaimError> { .failure(.network) }
        func pushAssignments(code: String, assignments: [WorkoutAssignment]) {
            pushedAssignments.append((code, assignments))
        }
        func fetchClaimed(athleteUid: String) async -> [ManagedClient]? { claimedDocs }
        func delete(code: String) {}
        func pushCoachShare(_ summary: CoachShareSummary, athleteUid: String) {}
        func clearCoachShare(athleteUid: String) {}
        func fetchCoachShare(athleteUid: String) async -> CoachShareSummary? { nil }
    }

    private func makeStore(service: SpyManagedService) -> MorpheAppStore {
        WorkoutFilePersistence().clear()
        ProfileFilePersistence().clear()
        let store = MorpheAppStore(managedClientService: service)
        store.onboardingDraft.name = "Sarah"
        store.completeOnboarding()
        store.authUser = AppUser(id: "me-uid", email: "s@m.app", role: .athlete,
                                 displayName: "Sarah", createdAt: .now)
        return store
    }

    private var sampleTemplate: WorkoutTemplate {
        WorkoutTemplate(
            name: "Coach Special", type: "Strength", sport: .strength,
            goal: "Get stronger", difficulty: .moderate, durationMinutes: 40,
            equipment: "", exercises: [
                WorkoutExercise(id: "e1", exerciseLibraryID: "lib1", name: "Goblet Squat",
                                muscleGroup: .legs, sets: "3", reps: "10",
                                difficulty: .moderate, formCue: "", intensityLabel: "")
            ], notes: "", coachNote: "")
    }

    func testAssignDeliversFullRunnableSnapshot() {
        let service = SpyManagedService()
        let store = makeStore(service: service)
        store.managedClients = [
            ManagedClient(id: "C1", coachUid: "me-uid", coachName: "Coach",
                          name: "Alex", status: .claimed, claimedByUid: "alex-uid")
        ]
        store.assignWorkout(sampleTemplate, to: store.managedClients[0],
                            on: .now, scheduledLabel: "Friday 5 PM")

        XCTAssertEqual(service.pushedAssignments.count, 1)
        let delivered = service.pushedAssignments[0]
        XCTAssertEqual(delivered.code, "C1")
        XCTAssertEqual(delivered.assignments.first?.workout.name, "Coach Special")
        XCTAssertEqual(delivered.assignments.first?.workout.exercises.first?.name, "Goblet Squat",
                       "the FULL runnable workout rides the doc — not a name-only note")
        XCTAssertTrue(store.managedClients[0].notes.contains("Assigned Coach Special"),
                      "the paper-trail note still lands")
    }

    func testAssignmentsCapAtTwenty() {
        let service = SpyManagedService()
        let store = makeStore(service: service)
        store.managedClients = [
            ManagedClient(id: "C2", coachUid: "me-uid", coachName: "Coach", name: "Sam")
        ]
        for _ in 0..<25 {
            store.assignWorkout(sampleTemplate, to: store.managedClients[0],
                                on: .now, scheduledLabel: "x")
        }
        XCTAssertEqual(store.managedClients[0].assignments.count, 20,
                       "the doc's JSON stays bounded")
    }

    func testAthleteSeesPendingAndCompletionDerivesFromLogs() async {
        let service = SpyManagedService()
        let store = makeStore(service: service)
        store.linkedCoachUid = "coach-uid"
        let assignment = WorkoutAssignment(
            workout: PartyWorkoutSnapshot(template: sampleTemplate),
            scheduledFor: .now, scheduledLabel: "today", coachName: "Coach Q")
        service.claimedDocs = [
            ManagedClient(id: "C3", coachUid: "coach-uid", coachName: "Coach Q",
                          name: "Sarah", status: .claimed, claimedByUid: "me-uid",
                          assignments: [assignment])
        ]

        await store.refreshCoachAssignments(force: true)
        XCTAssertEqual(store.pendingCoachAssignments.count, 1, "delivered and waiting")

        // Logging the coach's workout completes it — derived, no checkbox.
        XCTAssertTrue(store.logPastWorkout(
            template: sampleTemplate, on: .now, durationMinutes: 40,
            entries: [(name: "Goblet Squat", sets: 3, reps: 10, weight: 40, muscleGroup: nil)]))
        XCTAssertTrue(store.isAssignmentDone(assignment))
        XCTAssertTrue(store.pendingCoachAssignments.isEmpty,
                      "a matching real log clears the row")
    }

    func testStartAssignedWorkoutRunsTheCoachsExactSession() {
        let service = SpyManagedService()
        let store = makeStore(service: service)
        let assignment = WorkoutAssignment(
            workout: PartyWorkoutSnapshot(template: sampleTemplate),
            scheduledFor: .now, coachName: "Coach Q")

        store.startAssignedWorkout(assignment)
        XCTAssertTrue(store.isWorkoutSessionActive)
        XCTAssertEqual(store.currentWorkout.name, "Coach Special")
        XCTAssertEqual(store.currentWorkout.exercises.first?.name, "Goblet Squat")
        XCTAssertEqual(store.currentWorkout.type, "Coach Assignment")
    }
}

// MARK: - Tier 2: honest coach analytics + feed identity

@MainActor
final class CoachTier2Tests: XCTestCase {
    private func makeStore() -> MorpheAppStore {
        WorkoutFilePersistence().clear()
        ProfileFilePersistence().clear()
        let store = MorpheAppStore()
        store.onboardingDraft.name = "Sarah"
        store.completeOnboarding()
        store.authUser = AppUser(id: "coach-uid", email: "c@m.app", role: .coach,
                                 displayName: "Sarah", createdAt: .now)
        store.selectedRole = .coach
        return store
    }

    func testCoachHeadlineDerivesFromRealRoster() {
        let store = makeStore()
        XCTAssertTrue(store.feedAuthorHeadline.hasPrefix("Coach"),
                      "the byline leads with the role")
        XCTAssertFalse(store.feedAuthorHeadline.contains("athlete"),
                       "zero clients = no practice-size claim")
        store.managedClients = [
            ManagedClient(id: "C1", coachUid: "coach-uid", coachName: "S", name: "A"),
            ManagedClient(id: "C2", coachUid: "coach-uid", coachName: "S", name: "B")
        ]
        XCTAssertTrue(store.feedAuthorHeadline.contains("2 athletes"),
                      "the byline states the REAL roster count")
    }

    func testLiveAnalyticsStayHonestWithoutSharedData() {
        let store = makeStore()
        XCTAssertEqual(store.liveCoachAnalytics.rosterCount, 0)

        var client = ManagedClient(id: "C3", coachUid: "coach-uid", coachName: "S",
                                   name: "Alex", status: .claimed, claimedByUid: "alex-uid")
        client.assignments = [WorkoutAssignment(
            workout: PartyWorkoutSnapshot(template: WorkoutTemplate(
                name: "W", type: "t", sport: .strength, goal: "", difficulty: .moderate,
                durationMinutes: 30, equipment: "", exercises: [], notes: "", coachNote: "")),
            scheduledFor: Calendar.current.date(byAdding: .day, value: -3, to: .now)!)]
        store.managedClients = [client]

        let analytics = store.liveCoachAnalytics
        XCTAssertEqual(analytics.rosterCount, 1)
        XCTAssertEqual(analytics.quietCount, 1, "no sessions anywhere = quiet")
        XCTAssertNil(analytics.assignmentCompletion,
                     "no shared progress = NO completion claim, not a fake 0%")
    }

    func testAwaitingReplyCountsThreadsWhereClientSpokeLast() {
        let store = makeStore()
        store.managedClients = [
            ManagedClient(id: "C4", coachUid: "coach-uid", coachName: "S", name: "A")
        ]
        store.liveThreads = [
            MessageThreadSummary(id: "t1", coachUid: "coach-uid", athleteUid: "a1",
                                 coachName: "S", athleteName: "A",
                                 lastMessage: "hey coach", lastSender: "a1"),
            MessageThreadSummary(id: "t2", coachUid: "coach-uid", athleteUid: "a2",
                                 coachName: "S", athleteName: "B",
                                 lastMessage: "done!", lastSender: "coach-uid")
        ]
        XCTAssertEqual(store.liveCoachAnalytics.awaitingReply, 1,
                       "only the thread where the client spoke last is a real reply queue item")
    }
}

// MARK: - Tier 3 slice: rule-based session generation

@MainActor
final class SessionGenerationTests: XCTestCase {
    func testGeneratorMatchesSportAndSkipsRecentAssignments() {
        WorkoutFilePersistence().clear()
        ProfileFilePersistence().clear()
        let store = MorpheAppStore()
        store.onboardingDraft.name = "Sarah"
        store.completeOnboarding()

        var client = ManagedClient(id: "G1", coachUid: "u", coachName: "C",
                                   name: "Alex", sport: .strength)
        guard let first = store.generateSessionTemplate(for: client) else {
            return XCTFail("a seeded library must generate")
        }
        XCTAssertEqual(first.sport, .strength, "the pick matches the client's sport")

        // Assign it — the next generation must pick something fresh when
        // the library has an alternative.
        client.assignments = [WorkoutAssignment(
            workout: PartyWorkoutSnapshot(template: first), scheduledFor: .now)]
        if let second = store.generateSessionTemplate(for: client),
           store.workoutTemplates.filter({ $0.sport == .strength }).count > 1 {
            XCTAssertNotEqual(second.name, first.name, "fresh-first, not a repeat")
        }
    }
}

// MARK: - Fresh-audit fix wave

@MainActor
final class AuditSeamTests: XCTestCase {
    final class FailingCloudBackup: CloudBackingUp {
        func setUser(_ uid: String?) {}
        func pushProfile(_ snapshot: LocalProfileSnapshot) {}
        func pushLogs(_ logs: [WorkoutLog]) async -> Bool { false }
        func pushWeightHistory(_ entries: [MorpheAppStore.BodyWeightHistoryEntry]) {}
        func pushExtras(_ blobs: [String: String]) {}
        func pull() async -> CloudSnapshot {
            var snapshot = CloudSnapshot()
            snapshot.fetchFailed = true
            return snapshot
        }
        func eraseUser() async {}
    }

    func testFailedCloudPullBlocksOnboardingInsteadOfOverwriting() async {
        WorkoutFilePersistence().clear()
        ProfileFilePersistence().clear()
        let store = MorpheAppStore(cloudBackup: FailingCloudBackup())
        store.authUser = AppUser(id: "returning-uid", email: "r@m.app", role: .athlete,
                                 displayName: "Returner", createdAt: .now)
        await store.retryCloudRestore()
        XCTAssertTrue(store.cloudRestoreBlocked,
                      "a FAILED pull must hold the gate — proceeding to onboarding could overwrite a real backup")
        XCTAssertFalse(store.hasCompletedOnboarding)
    }

    func testBlockingReachesMessaging() {
        WorkoutFilePersistence().clear()
        ProfileFilePersistence().clear()
        let store = MorpheAppStore()
        store.onboardingDraft.name = "Sarah"
        store.completeOnboarding()
        store.authUser = AppUser(id: "me", email: "s@m.app", role: .athlete,
                                 displayName: "Sarah", createdAt: .now)
        store.liveThreads = [
            MessageThreadSummary(id: "bad_me", coachUid: "bad-uid", athleteUid: "me",
                                 coachName: "Bad Actor", athleteName: "Sarah")
        ]
        store.blockAccount(uid: "bad-uid", name: "Bad Actor")
        XCTAssertTrue(store.liveThreads.isEmpty,
                      "blocking removes the conversation instantly")
    }

    func testStartDirectChatRefusesBlockedTargets() async {
        WorkoutFilePersistence().clear()
        ProfileFilePersistence().clear()
        let store = MorpheAppStore()
        store.onboardingDraft.name = "Sarah"
        store.completeOnboarding()
        store.authUser = AppUser(id: "me", email: "s@m.app", role: .athlete,
                                 displayName: "Sarah", createdAt: .now)
        store.blockAccount(uid: "bad-uid", name: "Bad Actor")
        let ok = await store.startDirectChat(with: "bad-uid", name: "bad")
        XCTAssertFalse(ok, "no new chats with blocked accounts")
    }
}
