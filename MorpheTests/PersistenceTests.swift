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
