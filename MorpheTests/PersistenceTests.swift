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
}
