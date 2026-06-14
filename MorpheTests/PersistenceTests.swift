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
            weightUnit: "lb"
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
