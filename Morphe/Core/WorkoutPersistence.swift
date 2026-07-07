import Foundation

// MARK: - Workout domain persistence
//
// First on-device persistence "seam" for Morphe. Until now every piece of
// state lived only in memory on `MorpheAppStore` and was lost on relaunch.
// `MorpheAppStore` now talks to a `WorkoutPersisting` for the workout-tracking
// domain (logged workouts + the in-progress session) instead of holding that
// data only in memory.
//
// The protocol is the important part: swapping `WorkoutFilePersistence` for a
// cloud-backed implementation later is the v2 backend path, and no view or
// store logic has to change.

/// Codable snapshot of an in-progress workout session, so a session in flight
/// survives backgrounding or a relaunch.
struct WorkoutSessionSnapshot: Codable, Equatable {
    var currentWorkoutID: UUID?
    var isWorkoutSessionActive: Bool
    var hasStartedWorkoutFlow: Bool
    var hasCompletedWorkoutFlow: Bool
    var activeWorkoutExerciseIndex: Int
    var completedWorkoutSets: [String: Int]
    var trackedSetReps: [String: [Int]]
    var trackedSetWeights: [String: [Double]]
    /// Per-set RPE, parallel to trackedSetReps (0 = not rated). Tolerantly
    /// decoded so sessions saved before this field existed still restore.
    var trackedSetRPE: [String: [Int]]
    /// Session timing (tolerantly decoded): when the live session started and
    /// the elapsed minutes captured at finish.
    var workoutSessionStartedAt: Date?
    var completedSessionMinutes: Int?
    var isWorkoutLoggedToday: Bool
    /// The staged workout's NAME, as a fallback key: seeded template UUIDs
    /// re-mint every launch, so the id alone can't restore a staged seeded
    /// workout across relaunches. Tolerantly decoded.
    var currentWorkoutName: String

    init(currentWorkoutID: UUID?, isWorkoutSessionActive: Bool, hasStartedWorkoutFlow: Bool,
         hasCompletedWorkoutFlow: Bool, activeWorkoutExerciseIndex: Int,
         completedWorkoutSets: [String: Int], trackedSetReps: [String: [Int]],
         trackedSetWeights: [String: [Double]], trackedSetRPE: [String: [Int]],
         workoutSessionStartedAt: Date?, completedSessionMinutes: Int?,
         isWorkoutLoggedToday: Bool, currentWorkoutName: String = "") {
        self.currentWorkoutName = currentWorkoutName
        self.currentWorkoutID = currentWorkoutID
        self.isWorkoutSessionActive = isWorkoutSessionActive
        self.hasStartedWorkoutFlow = hasStartedWorkoutFlow
        self.hasCompletedWorkoutFlow = hasCompletedWorkoutFlow
        self.activeWorkoutExerciseIndex = activeWorkoutExerciseIndex
        self.completedWorkoutSets = completedWorkoutSets
        self.trackedSetReps = trackedSetReps
        self.trackedSetWeights = trackedSetWeights
        self.trackedSetRPE = trackedSetRPE
        self.workoutSessionStartedAt = workoutSessionStartedAt
        self.completedSessionMinutes = completedSessionMinutes
        self.isWorkoutLoggedToday = isWorkoutLoggedToday
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        currentWorkoutID = try c.decodeIfPresent(UUID.self, forKey: .currentWorkoutID)
        isWorkoutSessionActive = try c.decode(Bool.self, forKey: .isWorkoutSessionActive)
        hasStartedWorkoutFlow = try c.decode(Bool.self, forKey: .hasStartedWorkoutFlow)
        hasCompletedWorkoutFlow = try c.decode(Bool.self, forKey: .hasCompletedWorkoutFlow)
        activeWorkoutExerciseIndex = try c.decode(Int.self, forKey: .activeWorkoutExerciseIndex)
        completedWorkoutSets = try c.decode([String: Int].self, forKey: .completedWorkoutSets)
        trackedSetReps = try c.decode([String: [Int]].self, forKey: .trackedSetReps)
        trackedSetWeights = try c.decode([String: [Double]].self, forKey: .trackedSetWeights)
        trackedSetRPE = ((try? c.decodeIfPresent([String: [Int]].self, forKey: .trackedSetRPE)) ?? nil) ?? [:]
        workoutSessionStartedAt = ((try? c.decodeIfPresent(Date.self, forKey: .workoutSessionStartedAt)) ?? nil)
        completedSessionMinutes = ((try? c.decodeIfPresent(Int.self, forKey: .completedSessionMinutes)) ?? nil)
        isWorkoutLoggedToday = try c.decode(Bool.self, forKey: .isWorkoutLoggedToday)
        currentWorkoutName = ((try? c.decodeIfPresent(String.self, forKey: .currentWorkoutName)) ?? nil) ?? ""
    }
}

// MARK: - User-built workout library (custom workouts + custom exercises)

struct CustomExerciseSnapshot: Codable, Equatable {
    var id: String
    var name: String
    var muscleGroup: String
}

struct CustomWorkoutExerciseSnapshot: Codable, Equatable {
    /// The exercise's stable in-workout id. Persisted so an in-progress
    /// session's tracked sets (keyed by this id) reattach after a relaunch.
    /// Tolerantly decoded: libraries saved before this field existed load
    /// with an empty id and the loader mints one instead.
    var id: String
    var libraryID: String
    var name: String
    var muscleGroup: String
    var sets: String
    var reps: String
    var formCue: String

    init(id: String, libraryID: String, name: String, muscleGroup: String, sets: String, reps: String, formCue: String) {
        self.id = id
        self.libraryID = libraryID
        self.name = name
        self.muscleGroup = muscleGroup
        self.sets = sets
        self.reps = reps
        self.formCue = formCue
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = ((try? c.decodeIfPresent(String.self, forKey: .id)) ?? nil) ?? ""
        libraryID = try c.decode(String.self, forKey: .libraryID)
        name = try c.decode(String.self, forKey: .name)
        muscleGroup = try c.decode(String.self, forKey: .muscleGroup)
        sets = try c.decode(String.self, forKey: .sets)
        reps = try c.decode(String.self, forKey: .reps)
        formCue = try c.decode(String.self, forKey: .formCue)
    }
}

struct CustomWorkoutSnapshot: Codable, Equatable {
    var id: String
    var name: String
    var sport: String
    var durationMinutes: Int
    var exercises: [CustomWorkoutExerciseSnapshot]
}

/// A non-catalog library save (seeded or custom template), persisted by NAME —
/// seeded template UUIDs are re-minted every launch, so ids can't be trusted
/// across relaunches. Names are unique across the seeded set and custom builds.
struct SavedTemplateSnapshot: Codable, Equatable {
    var name: String
    var sourceName: String
    var sourceContext: String
    var bestFor: String
    var note: String
    var isPinned: Bool
}

struct WorkoutLibrarySnapshot: Codable, Equatable {
    var customExercises: [CustomExerciseSnapshot]
    var customWorkouts: [CustomWorkoutSnapshot]
    /// Catalog workouts the user saved from Discover (template UUID strings).
    /// Tolerantly decoded so libraries saved before this field existed load.
    var savedCatalogWorkoutIDs: [String]
    /// Non-catalog saves (recommendation saves, duplicated copies) — these
    /// used to silently vanish for a returning user.
    var savedTemplates: [SavedTemplateSnapshot]
    /// Pinned catalog saves (template UUID strings) — catalog items persist
    /// as bare ids, so the pin needs its own record to survive relaunch.
    var pinnedCatalogWorkoutIDs: [String]

    init(customExercises: [CustomExerciseSnapshot], customWorkouts: [CustomWorkoutSnapshot],
         savedCatalogWorkoutIDs: [String] = [], savedTemplates: [SavedTemplateSnapshot] = [],
         pinnedCatalogWorkoutIDs: [String] = []) {
        self.customExercises = customExercises
        self.customWorkouts = customWorkouts
        self.savedCatalogWorkoutIDs = savedCatalogWorkoutIDs
        self.savedTemplates = savedTemplates
        self.pinnedCatalogWorkoutIDs = pinnedCatalogWorkoutIDs
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        customExercises = try c.decode([CustomExerciseSnapshot].self, forKey: .customExercises)
        customWorkouts = try c.decode([CustomWorkoutSnapshot].self, forKey: .customWorkouts)
        savedCatalogWorkoutIDs = ((try? c.decodeIfPresent([String].self, forKey: .savedCatalogWorkoutIDs)) ?? nil) ?? []
        savedTemplates = ((try? c.decodeIfPresent([SavedTemplateSnapshot].self, forKey: .savedTemplates)) ?? nil) ?? []
        pinnedCatalogWorkoutIDs = ((try? c.decodeIfPresent([String].self, forKey: .pinnedCatalogWorkoutIDs)) ?? nil) ?? []
    }
}

/// Abstraction over where workout data is stored.
protocol WorkoutPersisting: AnyObject {
    func loadLogs() -> [WorkoutLog]?
    func saveLogs(_ logs: [WorkoutLog])
    func loadSession() -> WorkoutSessionSnapshot?
    func saveSession(_ snapshot: WorkoutSessionSnapshot)
    func loadLibrary() -> WorkoutLibrarySnapshot?
    func saveLibrary(_ snapshot: WorkoutLibrarySnapshot)
    /// Remove all persisted workout data (used by tests / sign-out later).
    func clear()
}

/// File-based implementation that writes JSON into the app's Application Support
/// directory. Writes are atomic so a crash mid-write can't corrupt the store.
final class WorkoutFilePersistence: WorkoutPersisting {
    private let logsURL: URL
    private let sessionURL: URL
    private let libraryURL: URL
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init(directoryName: String = "MorpheStore") {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        self.encoder = encoder

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        self.decoder = decoder

        let fileManager = FileManager.default
        let base = (try? fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )) ?? fileManager.temporaryDirectory
        let directory = base.appendingPathComponent(directoryName, isDirectory: true)
        try? fileManager.createDirectory(at: directory, withIntermediateDirectories: true)

        self.logsURL = directory.appendingPathComponent("workout-logs.json")
        self.sessionURL = directory.appendingPathComponent("workout-session.json")
        self.libraryURL = directory.appendingPathComponent("workout-library.json")
    }

    func loadLogs() -> [WorkoutLog]? {
        guard let data = try? Data(contentsOf: logsURL) else { return nil }
        return try? decoder.decode([WorkoutLog].self, from: data)
    }

    func saveLogs(_ logs: [WorkoutLog]) {
        guard let data = try? encoder.encode(logs) else { return }
        try? data.write(to: logsURL, options: [.atomic])
    }

    func loadSession() -> WorkoutSessionSnapshot? {
        guard let data = try? Data(contentsOf: sessionURL) else { return nil }
        return try? decoder.decode(WorkoutSessionSnapshot.self, from: data)
    }

    func saveSession(_ snapshot: WorkoutSessionSnapshot) {
        guard let data = try? encoder.encode(snapshot) else { return }
        try? data.write(to: sessionURL, options: [.atomic])
    }

    func loadLibrary() -> WorkoutLibrarySnapshot? {
        guard let data = try? Data(contentsOf: libraryURL) else { return nil }
        return try? decoder.decode(WorkoutLibrarySnapshot.self, from: data)
    }

    func saveLibrary(_ snapshot: WorkoutLibrarySnapshot) {
        guard let data = try? encoder.encode(snapshot) else { return }
        try? data.write(to: libraryURL, options: [.atomic])
    }

    func clear() {
        try? FileManager.default.removeItem(at: logsURL)
        try? FileManager.default.removeItem(at: sessionURL)
        try? FileManager.default.removeItem(at: libraryURL)
    }
}
