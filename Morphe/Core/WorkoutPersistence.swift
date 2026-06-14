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
    var isWorkoutLoggedToday: Bool
}

// MARK: - User-built workout library (custom workouts + custom exercises)

struct CustomExerciseSnapshot: Codable, Equatable {
    var id: String
    var name: String
    var muscleGroup: String
}

struct CustomWorkoutExerciseSnapshot: Codable, Equatable {
    var libraryID: String
    var name: String
    var muscleGroup: String
    var sets: String
    var reps: String
    var formCue: String
}

struct CustomWorkoutSnapshot: Codable, Equatable {
    var id: String
    var name: String
    var sport: String
    var durationMinutes: Int
    var exercises: [CustomWorkoutExerciseSnapshot]
}

struct WorkoutLibrarySnapshot: Codable, Equatable {
    var customExercises: [CustomExerciseSnapshot]
    var customWorkouts: [CustomWorkoutSnapshot]
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
