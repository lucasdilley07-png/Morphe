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

/// A meal the user logged today (persisted so nutrition survives relaunch).
struct MealSnapshot: Codable, Equatable {
    var mealType: String
    var name: String
    var calories: Int
    var protein: Int
}

/// A pain flag the user filed — safety data, kept across relaunches.
struct PainReportSnapshot: Codable, Equatable {
    var area: String
    var severity: Int
    var triggerExercise: String
    var alternative: String
    var note: String
}

/// Codable snapshot of the user's locally-saved identity and preferences.
struct LocalProfileSnapshot: Codable, Equatable {
    /// Explicit migration hook for future non-additive schema changes.
    var schemaVersion: Int = 1
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
    var trainingDaysPerWeek: Int = 3
    // Learning progress — earned XP/level and completed quizzes previously
    // lived only in memory, so everything a user earned vanished on relaunch.
    var levelTitle: String = ""
    var levelXP: Int = 0
    var levelTargetXP: Int = 0
    var completedQuizIDs: [String] = []
    // Body metrics, editable from Profile.
    var height: String = ""
    var bodyWeight: String = ""
    // Daily state — which calendar day the daily surfaces belong to, and which
    // tasks were completed that day (so a same-day relaunch can't re-offer
    // already-earned task XP).
    var dailyStateDay: String = ""
    var completedTaskTitlesToday: [String] = []
    // Days protected with a minimum win — they count in the streak.
    var protectedDayKeys: [String] = []
    // Where the user is in their catalog-backed daily-plan rotation.
    var planDayIndex: Int = 0
    // Minimum-win completions are day-scoped like task titles; without them a
    // same-day relaunch re-offered the task unchecked while keeping the XP —
    // an infinite XP faucet.
    var completedMinimumWinTitlesToday: [String] = []
    var minimumWinModeEnabled: Bool = false
    var selectedPlanBReason: String = ""
    // Today's nutrition log (day-scoped; goals stay seeded, the mode is a
    // lasting preference).
    var nutritionCaloriesConsumed: Int = 0
    var nutritionProteinConsumed: Int = 0
    var nutritionWaterConsumed: Int = 0
    var nutritionScore: Int = -1
    var nutritionMode: String = ""
    var nutritionMeals: [MealSnapshot] = []
    // Today's recovery check-in (day-scoped; -1 score = no check-in saved).
    var didCompleteQuickCheckIn: Bool = false
    var recoveryScore: Int = -1
    var recoveryStatus: String = ""
    var recoveryReason: String = ""
    var recoverySleepHours: Double = 0
    var recoveryEnergy: Int = 0
    var recoverySoreness: Int = 0
    var recoveryMood: Int = 0
    var recoveryPain: Bool = false
    // Durable safety + display preferences.
    var painReports: [PainReportSnapshot] = []
    var prefersCompactExerciseView: Bool = false
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
        trainingDaysPerWeek = ((try? c.decodeIfPresent(Int.self, forKey: .trainingDaysPerWeek)) ?? nil) ?? 3
        levelTitle = str(.levelTitle)
        levelXP = ((try? c.decodeIfPresent(Int.self, forKey: .levelXP)) ?? nil) ?? 0
        levelTargetXP = ((try? c.decodeIfPresent(Int.self, forKey: .levelTargetXP)) ?? nil) ?? 0
        completedQuizIDs = arr(.completedQuizIDs)
        height = str(.height)
        bodyWeight = str(.bodyWeight)
        dailyStateDay = str(.dailyStateDay)
        completedTaskTitlesToday = arr(.completedTaskTitlesToday)
        protectedDayKeys = arr(.protectedDayKeys)
        planDayIndex = ((try? c.decodeIfPresent(Int.self, forKey: .planDayIndex)) ?? nil) ?? 0
        schemaVersion = ((try? c.decodeIfPresent(Int.self, forKey: .schemaVersion)) ?? nil) ?? 1
        completedMinimumWinTitlesToday = arr(.completedMinimumWinTitlesToday)
        minimumWinModeEnabled = ((try? c.decodeIfPresent(Bool.self, forKey: .minimumWinModeEnabled)) ?? nil) ?? false
        selectedPlanBReason = str(.selectedPlanBReason)
        nutritionCaloriesConsumed = ((try? c.decodeIfPresent(Int.self, forKey: .nutritionCaloriesConsumed)) ?? nil) ?? 0
        nutritionProteinConsumed = ((try? c.decodeIfPresent(Int.self, forKey: .nutritionProteinConsumed)) ?? nil) ?? 0
        nutritionWaterConsumed = ((try? c.decodeIfPresent(Int.self, forKey: .nutritionWaterConsumed)) ?? nil) ?? 0
        nutritionScore = ((try? c.decodeIfPresent(Int.self, forKey: .nutritionScore)) ?? nil) ?? -1
        nutritionMode = str(.nutritionMode)
        nutritionMeals = ((try? c.decodeIfPresent([MealSnapshot].self, forKey: .nutritionMeals)) ?? nil) ?? []
        didCompleteQuickCheckIn = ((try? c.decodeIfPresent(Bool.self, forKey: .didCompleteQuickCheckIn)) ?? nil) ?? false
        recoveryScore = ((try? c.decodeIfPresent(Int.self, forKey: .recoveryScore)) ?? nil) ?? -1
        recoveryStatus = str(.recoveryStatus)
        recoveryReason = str(.recoveryReason)
        recoverySleepHours = ((try? c.decodeIfPresent(Double.self, forKey: .recoverySleepHours)) ?? nil) ?? 0
        recoveryEnergy = ((try? c.decodeIfPresent(Int.self, forKey: .recoveryEnergy)) ?? nil) ?? 0
        recoverySoreness = ((try? c.decodeIfPresent(Int.self, forKey: .recoverySoreness)) ?? nil) ?? 0
        recoveryMood = ((try? c.decodeIfPresent(Int.self, forKey: .recoveryMood)) ?? nil) ?? 0
        recoveryPain = ((try? c.decodeIfPresent(Bool.self, forKey: .recoveryPain)) ?? nil) ?? false
        painReports = ((try? c.decodeIfPresent([PainReportSnapshot].self, forKey: .painReports)) ?? nil) ?? []
        prefersCompactExerciseView = ((try? c.decodeIfPresent(Bool.self, forKey: .prefersCompactExerciseView)) ?? nil) ?? false
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
