import Foundation

// MARK: - Local profile persistence
//
// Second persistence seam (same pattern as WorkoutPersistence). Stores the
// identity the user provides during onboarding on-device, so the app greets the
// real user by name on relaunch instead of the hardcoded demo profile — and so
// a returning user skips onboarding.
//
// This deliberately persists only the user-provided fields as a small, stable
// snapshot (raw values, not the full model graph). Derived/demo content (health
// scores, AI insights, badges) is still seeded at launch. When the v2 backend
// arrives, swapping `ProfileFilePersistence` for a cloud implementation is all
// that changes.

/// Codable snapshot of the user's locally-saved identity and preferences.
struct LocalProfileSnapshot: Codable, Equatable {
    var hasCompletedOnboarding: Bool
    /// The user's own stable identity (UUID string), minted at onboarding so a
    /// real user is never the seeded demo athlete.
    var id: String
    var name: String
    var gender: String
    var accountRole: String
    var sportMode: String
    var selectedSports: [String]
    var selectedTrainingStyles: [String]
    var selectedGoals: [String]
    var goal: String
    var physicalGoalTarget: String
    var weightGoalTarget: String
    var goalDeadline: String
    var fitnessLevel: String
    var equipment: String
    var injuries: String
    var theme: String
    var accentPalette: String
    var coachingTone: String
    var avatarStyle: String
    var displayName: String
    var username: String
    var weightUnit: String
    var currentProgram: String
    var currentPhase: String
}

extension LocalProfileSnapshot {
    /// Tolerant decode. Older saved profiles may predate fields added later
    /// (e.g. `id`, `weightUnit`). With the synthesized decoder a single missing
    /// key throws, `loadProfile()` returns nil, and the app re-runs onboarding —
    /// which calls `resetToFreshUser()` and wipes the user's real logs. Decoding
    /// every field with `decodeIfPresent` + a safe default makes a schema change
    /// non-destructive: a returning user keeps their session and data.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        func str(_ key: CodingKeys, _ fallback: String = "") -> String {
            ((try? c.decodeIfPresent(String.self, forKey: key)) ?? nil) ?? fallback
        }
        func arr(_ key: CodingKeys) -> [String] {
            ((try? c.decodeIfPresent([String].self, forKey: key)) ?? nil) ?? []
        }

        hasCompletedOnboarding = ((try? c.decodeIfPresent(Bool.self, forKey: .hasCompletedOnboarding)) ?? nil) ?? false
        // A missing id mints a fresh one but preserves onboarding state, so a
        // schema gap never demotes a real user back to the seeded demo identity.
        id = str(.id, UUID().uuidString)
        name = str(.name)
        gender = str(.gender)
        accountRole = str(.accountRole, "client")
        sportMode = str(.sportMode)
        selectedSports = arr(.selectedSports)
        selectedTrainingStyles = arr(.selectedTrainingStyles)
        selectedGoals = arr(.selectedGoals)
        goal = str(.goal)
        physicalGoalTarget = str(.physicalGoalTarget)
        weightGoalTarget = str(.weightGoalTarget)
        goalDeadline = str(.goalDeadline)
        fitnessLevel = str(.fitnessLevel)
        equipment = str(.equipment)
        injuries = str(.injuries)
        theme = str(.theme)
        accentPalette = str(.accentPalette)
        coachingTone = str(.coachingTone)
        avatarStyle = str(.avatarStyle)
        displayName = str(.displayName)
        username = str(.username)
        weightUnit = str(.weightUnit, "pounds")
        currentProgram = str(.currentProgram)
        currentPhase = str(.currentPhase)
    }
}

/// Abstraction over where the local profile is stored.
protocol ProfilePersisting: AnyObject {
    func loadProfile() -> LocalProfileSnapshot?
    func saveProfile(_ snapshot: LocalProfileSnapshot)
    func clear()
}

/// File-based implementation writing JSON atomically into Application Support.
final class ProfileFilePersistence: ProfilePersisting {
    private let profileURL: URL
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init(directoryName: String = "MorpheStore") {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        self.encoder = encoder
        self.decoder = JSONDecoder()

        let fileManager = FileManager.default
        let base = (try? fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )) ?? fileManager.temporaryDirectory
        let directory = base.appendingPathComponent(directoryName, isDirectory: true)
        try? fileManager.createDirectory(at: directory, withIntermediateDirectories: true)

        self.profileURL = directory.appendingPathComponent("local-profile.json")
    }

    func loadProfile() -> LocalProfileSnapshot? {
        guard let data = try? Data(contentsOf: profileURL) else { return nil }
        return try? decoder.decode(LocalProfileSnapshot.self, from: data)
    }

    func saveProfile(_ snapshot: LocalProfileSnapshot) {
        guard let data = try? encoder.encode(snapshot) else { return }
        try? data.write(to: profileURL, options: [.atomic])
    }

    func clear() {
        try? FileManager.default.removeItem(at: profileURL)
    }
}
