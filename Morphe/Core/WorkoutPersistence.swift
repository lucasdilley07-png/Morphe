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
/// What the user has typed into the custom set logger but not logged yet —
/// persisted per exercise so a dismissed sheet (or an app relaunch mid-set)
/// never eats their numbers.
struct PendingSetDraft: Codable, Equatable {
    var reps: Int = 10
    var weight: Double = 0
    var rpe: Int?
}

struct WorkoutSessionSnapshot: Codable, Equatable {
    /// Explicit migration hook for future non-additive schema changes.
    var schemaVersion: Int = 1
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
    /// Per-set style labels ("" = standard; superset/dropset sub-work text).
    /// Tolerantly decoded.
    var trackedSetLabels: [String: [String]]
    /// Per-set warm-up flags, parallel to trackedSetReps. Tolerantly
    /// decoded (older sessions = all working sets).
    var trackedSetWarmups: [String: [Bool]]
    /// Per-set camera-counted flags, parallel to trackedSetReps.
    /// Tolerantly decoded (older sessions = hand-entered).
    var trackedSetCamera: [String: [Bool]] = [:]
    /// Session superset pairs, both directions. Tolerantly decoded.
    var supersetPartners: [String: String]
    /// Unsaved custom-logger drafts per exercise. Tolerantly decoded.
    var pendingSetDrafts: [String: PendingSetDraft]
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
         trackedSetLabels: [String: [String]] = [:],
         trackedSetWarmups: [String: [Bool]] = [:],
         trackedSetCamera: [String: [Bool]] = [:],
         supersetPartners: [String: String] = [:],
         pendingSetDrafts: [String: PendingSetDraft] = [:],
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
        self.trackedSetLabels = trackedSetLabels
        self.trackedSetWarmups = trackedSetWarmups
        self.trackedSetCamera = trackedSetCamera
        self.supersetPartners = supersetPartners
        self.pendingSetDrafts = pendingSetDrafts
        self.workoutSessionStartedAt = workoutSessionStartedAt
        self.completedSessionMinutes = completedSessionMinutes
        self.isWorkoutLoggedToday = isWorkoutLoggedToday
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = ((try? c.decodeIfPresent(Int.self, forKey: .schemaVersion)) ?? nil) ?? 1
        currentWorkoutID = try c.decodeIfPresent(UUID.self, forKey: .currentWorkoutID)
        isWorkoutSessionActive = try c.decode(Bool.self, forKey: .isWorkoutSessionActive)
        hasStartedWorkoutFlow = try c.decode(Bool.self, forKey: .hasStartedWorkoutFlow)
        hasCompletedWorkoutFlow = try c.decode(Bool.self, forKey: .hasCompletedWorkoutFlow)
        activeWorkoutExerciseIndex = try c.decode(Int.self, forKey: .activeWorkoutExerciseIndex)
        completedWorkoutSets = try c.decode([String: Int].self, forKey: .completedWorkoutSets)
        trackedSetReps = try c.decode([String: [Int]].self, forKey: .trackedSetReps)
        trackedSetWeights = try c.decode([String: [Double]].self, forKey: .trackedSetWeights)
        trackedSetRPE = ((try? c.decodeIfPresent([String: [Int]].self, forKey: .trackedSetRPE)) ?? nil) ?? [:]
        trackedSetLabels = ((try? c.decodeIfPresent([String: [String]].self, forKey: .trackedSetLabels)) ?? nil) ?? [:]
        trackedSetWarmups = ((try? c.decodeIfPresent([String: [Bool]].self, forKey: .trackedSetWarmups)) ?? nil) ?? [:]
        trackedSetCamera = ((try? c.decodeIfPresent([String: [Bool]].self, forKey: .trackedSetCamera)) ?? nil) ?? [:]
        supersetPartners = ((try? c.decodeIfPresent([String: String].self, forKey: .supersetPartners)) ?? nil) ?? [:]
        pendingSetDrafts = ((try? c.decodeIfPresent([String: PendingSetDraft].self, forKey: .pendingSetDrafts)) ?? nil) ?? [:]
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
    /// Explicit migration hook for future non-additive schema changes.
    var schemaVersion: Int = 1
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
        schemaVersion = ((try? c.decodeIfPresent(Int.self, forKey: .schemaVersion)) ?? nil) ?? 1
        customExercises = try c.decode([CustomExerciseSnapshot].self, forKey: .customExercises)
        customWorkouts = try c.decode([CustomWorkoutSnapshot].self, forKey: .customWorkouts)
        savedCatalogWorkoutIDs = ((try? c.decodeIfPresent([String].self, forKey: .savedCatalogWorkoutIDs)) ?? nil) ?? []
        savedTemplates = ((try? c.decodeIfPresent([SavedTemplateSnapshot].self, forKey: .savedTemplates)) ?? nil) ?? []
        pinnedCatalogWorkoutIDs = ((try? c.decodeIfPresent([String].self, forKey: .pinnedCatalogWorkoutIDs)) ?? nil) ?? []
    }
}

// MARK: - Logged-history file format

/// Versioned wrapper for the workout-logs file. Files written before
/// versioning are bare `[WorkoutLog]` arrays; the version field gives future
/// schema changes an explicit migration hook instead of relying on per-field
/// tolerance alone.
struct WorkoutLogsSnapshot: Codable {
    var schemaVersion: Int
    var logs: [WorkoutLog]
}

/// Wraps an element so one undecodable entry drops that entry instead of
/// nil-ing the whole array (which used to resurrect seeded demo logs over a
/// real user's entire history).
struct FailableElement<Element: Decodable>: Decodable {
    let value: Element?

    init(from decoder: Decoder) {
        value = try? Element(from: decoder)
    }
}

private struct TolerantLogsSnapshot: Decodable {
    var schemaVersion: Int
    var logs: [FailableElement<WorkoutLog>]
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
        // Current format: versioned wrapper, tolerant per element.
        if let snapshot = try? decoder.decode(TolerantLogsSnapshot.self, from: data) {
            return snapshot.logs.compactMap(\.value)
        }
        // Legacy format: bare array (pre-versioning), tolerant per element.
        if let elements = try? decoder.decode([FailableElement<WorkoutLog>].self, from: data) {
            return elements.compactMap(\.value)
        }
        // The file exists but is unreadable. Returning nil would resurrect
        // the seeded demo logs AND overwrite this file on the next save —
        // keep the evidence aside and start from an empty history instead.
        let backupURL = logsURL.appendingPathExtension("corrupt")
        try? FileManager.default.removeItem(at: backupURL)
        try? FileManager.default.copyItem(at: logsURL, to: backupURL)
        return []
    }

    func saveLogs(_ logs: [WorkoutLog]) {
        guard let data = try? encoder.encode(WorkoutLogsSnapshot(schemaVersion: 1, logs: logs)) else { return }
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

// MARK: - Import from other trackers (2026-10-04)
//
// Reads the per-set CSV that Strong and Hevy export, by HEADER NAME rather
// than column position, so either app's file (and small format drift) maps
// onto the same shape. Pure: text in, sessions out. Rows without reps
// (timed or distance work) are counted and skipped, never guessed at.

enum WorkoutImport {
    struct Exercise: Equatable {
        var name: String
        var reps: [Int] = []
        var weights: [Double] = []
        var rpes: [Int] = []
        var warmups: [Bool] = []
    }

    struct Session: Equatable {
        var title: String
        var date: Date
        var durationMinutes: Int
        var exercises: [Exercise]
        var setCount: Int { exercises.reduce(0) { $0 + $1.reps.count } }
    }

    struct Parsed: Equatable {
        var sessions: [Session]
        var skippedRows: Int
        /// "lb" / "kg" when the file itself says; nil = the user must say.
        var unitInFile: String?
        var sourceApp: String
    }

    /// RFC-4180-style split: quoted fields, doubled quotes, CR/LF.
    static func rows(_ text: String, delimiter: Character) -> [[String]] {
        var rows: [[String]] = []
        var row: [String] = []
        var field = ""
        var quoted = false
        var iterator = text.makeIterator()
        var pending: Character? = nil
        func next() -> Character? {
            if let p = pending { pending = nil; return p }
            return iterator.next()
        }
        while let ch = next() {
            if quoted {
                if ch == "\"" {
                    if let after = next() {
                        if after == "\"" { field.append("\"") } else { quoted = false; pending = after }
                    } else { quoted = false }
                } else { field.append(ch) }
            } else if ch == "\"" {
                quoted = true
            } else if ch == delimiter {
                row.append(field); field = ""
            } else if ch == "\n" || ch == "\r\n" || ch == "\r" {
                row.append(field); field = ""
                if !(row.count == 1 && row[0].isEmpty) { rows.append(row) }
                row = []
            } else {
                field.append(ch)
            }
        }
        row.append(field)
        if !(row.count == 1 && row[0].isEmpty) { rows.append(row) }
        return rows
    }

    private static func key(_ header: String) -> String {
        header.lowercased().filter { $0.isLetter || $0.isNumber }
    }

    private static let dateFormats = [
        "yyyy-MM-dd HH:mm:ss", "yyyy-MM-dd HH:mm", "d MMM yyyy, HH:mm",
        "yyyy-MM-dd'T'HH:mm:ssXXXXX", "yyyy-MM-dd'T'HH:mm:ss", "yyyy-MM-dd"
    ]

    static func date(from text: String) -> Date? {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        for format in dateFormats {
            formatter.dateFormat = format
            if let date = formatter.date(from: trimmed) { return date }
        }
        return nil
    }

    /// "1h 5m", "45m", "01:02:00", "3720" (seconds) → minutes.
    static func minutes(from text: String) -> Int? {
        let trimmed = text.trimmingCharacters(in: .whitespaces).lowercased()
        guard !trimmed.isEmpty else { return nil }
        let clock = trimmed.split(separator: ":").compactMap { Int($0) }
        if trimmed.contains(":"), clock.count == 3 { return clock[0] * 60 + clock[1] + (clock[2] >= 30 ? 1 : 0) }
        if trimmed.contains(":"), clock.count == 2 { return clock[0] * 60 + clock[1] }
        if trimmed.contains("h") || trimmed.contains("m") {
            var total = 0
            var digits = ""
            for ch in trimmed {
                if ch.isNumber { digits.append(ch) }
                else if ch == "h" { total += (Int(digits) ?? 0) * 60; digits = "" }
                else if ch == "m" { total += Int(digits) ?? 0; digits = "" }
                else if ch == "s" { digits = "" }
            }
            return total > 0 ? total : nil
        }
        if let seconds = Double(trimmed) { return max(Int((seconds / 60).rounded()), 1) }
        return nil
    }

    static func parse(_ raw: String) -> Parsed? {
        var text = raw
        if text.hasPrefix("\u{FEFF}") { text.removeFirst() }
        guard let headerLine = text.split(whereSeparator: \.isNewline).first else { return nil }
        let delimiter: Character = headerLine.filter { $0 == ";" }.count > headerLine.filter { $0 == "," }.count ? ";" : ","
        let table = rows(text, delimiter: delimiter)
        guard table.count >= 2 else { return nil }
        let headers = table[0].map(key)
        func column(_ names: [String]) -> Int? { names.compactMap { headers.firstIndex(of: $0) }.first }

        guard let dateCol = column(["date", "starttime"]),
              let exerciseCol = column(["exercisename", "exercisetitle"]),
              let repsCol = column(["reps"]) else { return nil }
        let titleCol = column(["workoutname", "title"])
        let weightCol = column(["weight", "weightlbs", "weightlb", "weightkg"])
        let unitCol = column(["weightunit"])
        let rpeCol = column(["rpe"])
        let typeCol = column(["settype"])
        let orderCol = column(["setorder", "setindex"])
        let durationCol = column(["duration"])
        let endCol = column(["endtime"])
        let hevy = headers.contains("exercisetitle")

        var unit: String?
        if let weightCol {
            if headers[weightCol].hasSuffix("kg") { unit = "kg" }
            if headers[weightCol].hasSuffix("lbs") || headers[weightCol].hasSuffix("lb") { unit = "lb" }
        }

        var sessions: [Session] = []
        var index: [String: Int] = [:]
        var skipped = 0
        for row in table.dropFirst().prefix(50_000) {
            func cell(_ col: Int?) -> String {
                guard let col, row.indices.contains(col) else { return "" }
                return row[col].trimmingCharacters(in: .whitespaces)
            }
            func number(_ col: Int?) -> Double? {
                var value = cell(col)
                if delimiter == ";" { value = value.replacingOccurrences(of: ",", with: ".") }
                return Double(value)
            }
            let order = cell(orderCol).lowercased()
            let name = cell(exerciseCol)
            guard !name.isEmpty, order != "rest timer", order != "note",
                  let date = date(from: cell(dateCol)),
                  let reps = number(repsCol).map({ Int($0.rounded()) }), reps > 0, reps <= 1_000 else {
                skipped += 1
                continue
            }
            if unit == nil, !cell(unitCol).isEmpty {
                unit = cell(unitCol).lowercased().hasPrefix("k") ? "kg" : "lb"
            }
            let title = cell(titleCol).isEmpty ? "Imported Workout" : cell(titleCol)
            let sessionKey = "\(cell(dateCol))|\(title)"
            let sessionIndex: Int
            if let found = index[sessionKey] {
                sessionIndex = found
            } else {
                var duration = minutes(from: cell(durationCol))
                if duration == nil, let end = WorkoutImport.date(from: cell(endCol)), end > date {
                    duration = Int((end.timeIntervalSince(date) / 60).rounded())
                }
                sessions.append(Session(title: String(title.prefix(80)), date: date,
                                        durationMinutes: min(max(duration ?? 45, 5), 300), exercises: []))
                sessionIndex = sessions.count - 1
                index[sessionKey] = sessionIndex
            }
            // Sets of one exercise stay together even when a superset
            // interleaves rows in the file.
            let exerciseIndex: Int
            if let found = sessions[sessionIndex].exercises.firstIndex(where: { $0.name == name }) {
                exerciseIndex = found
            } else {
                sessions[sessionIndex].exercises.append(Exercise(name: String(name.prefix(80))))
                exerciseIndex = sessions[sessionIndex].exercises.count - 1
            }
            let type = cell(typeCol).lowercased()
            let rpe = number(rpeCol).map { Int($0.rounded()) } ?? 0
            sessions[sessionIndex].exercises[exerciseIndex].reps.append(reps)
            sessions[sessionIndex].exercises[exerciseIndex].weights.append(min(max(number(weightCol) ?? 0, 0), 2_500))
            sessions[sessionIndex].exercises[exerciseIndex].rpes.append((6...10).contains(rpe) ? rpe : 0)
            sessions[sessionIndex].exercises[exerciseIndex].warmups.append(type.hasPrefix("warm") || order == "w")
        }
        guard !sessions.isEmpty else { return nil }
        return Parsed(sessions: sessions.sorted { $0.date < $1.date }, skippedRows: skipped,
                      unitInFile: unit, sourceApp: hevy ? "Hevy" : "Strong")
    }
}
