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

    func testQuizNeverReawardsXP() {
        let store = MorpheAppStore()
        store.onboardingDraft.name = "Sarah"
        store.completeOnboarding()

        let quiz = store.quizzes.first!
        store.answerQuiz(quiz, with: quiz.correctIndex)
        let earnedXP = store.clientProfile.level.currentXP

        // The day rotation cycles the pool, so an aced quiz can come around
        // again — answering it a second time must not pay twice.
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
        XCTAssertEqual(store.selectedClientTab, .discover, "'open discover' navigates to the Discover tab")
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

        // Signing back in (still unaccepted) puts the gate right back up.
        store.authUser = AppUser(id: "user-1", email: "sarah@morphe.app", role: .athlete, displayName: "Sarah", createdAt: .now)
        XCTAssertTrue(store.needsTermsAcceptance, "the gate returns on every open until they agree")
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
