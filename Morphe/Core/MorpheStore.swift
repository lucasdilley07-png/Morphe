import SwiftUI
import Observation

@MainActor
@Observable
final class MorpheAppStore {
    private enum CoachOutreachKind: String, CaseIterable, Hashable {
        case praise
        case missedSessionNudge
        case partnerPrompt
        case recoveryReminder
        case painCheckIn
        case generalCheckIn

        var title: String {
            switch self {
            case .praise:
                return "Praise"
            case .missedSessionNudge:
                return "Nudges"
            case .partnerPrompt:
                return "Partner prompts"
            case .recoveryReminder:
                return "Recovery reminders"
            case .painCheckIn:
                return "Pain check-ins"
            case .generalCheckIn:
                return "Check-ins"
            }
        }

        var insightLine: String {
            switch self {
            case .praise:
                return "Praise usually helps the next session get logged"
            case .missedSessionNudge:
                return "Nudges usually restart momentum"
            case .partnerPrompt:
                return "Partner prompts usually get the next session logged"
            case .recoveryReminder:
                return "Recovery reminders usually protect follow-through"
            case .painCheckIn:
                return "Pain check-ins usually keep the record moving"
            case .generalCheckIn:
                return "Check-ins usually get the next session logged"
            }
        }
    }

    private struct CoachOutreachEvent: Identifiable, Hashable {
        var id = UUID()
        var athleteID: UUID
        var athleteName: String
        var kind: CoachOutreachKind
        var sentAt: Date
        var sourceLabel: String
    }

    private struct CoachOutreachEffectiveness: Hashable {
        var kind: CoachOutreachKind
        var sentCount: Int
        var followThroughCount: Int

        var successRate: Int {
            guard sentCount > 0 else { return 0 }
            return Int((Double(followThroughCount) / Double(sentCount) * 100).rounded())
        }

        var insightLine: String {
            "\(kind.insightLine) \(followThroughCount) of \(sentCount) times lately."
        }
    }

    private struct PendingCoachOutreachContext: Hashable {
        var athleteID: UUID
        var kind: CoachOutreachKind
    }

    private struct WorkoutTemplateCompletionInsight {
        var completionCount: Int
        var recentCompletionCount: Int
        var buddyCompletionCount: Int
        var lastCompletedAt: Date?
        var lastSource: WorkoutLogSource?
        var recoveryFollowThroughCount: Int
    }

    private struct GoodForTodayBehaviorSnapshot {
        var fallbackFavorite: SavedWorkoutLibraryItem?
        var recoveryFavorite: SavedWorkoutLibraryItem?
        var buddyFavorite: SavedWorkoutLibraryItem?
        var repeatFavorite: SavedWorkoutLibraryItem?
        var currentPlanInsight: WorkoutTemplateCompletionInsight
        var coachLedSessionsAreLanding: Bool
        var buddyLiftIsReal: Bool
        var recoveryDaysLeadToMomentum: Bool
        var fallbackDaysSaveMomentum: Bool
        var coachPlanWorksAfterFallback: Bool
        var reboundWindowIsOpen: Bool
    }

    var selectedRole: AppRole = .client
    var selectedClientTab: ClientTab = .today
    var selectedCoachTab: CoachTab = .dashboard
    var selectedAppearance: ColorScheme? = .dark
    var toastMessage: String?
    var celebration: CelebrationMoment?

    var isShowingLaunchSequence = true
    var hasCompletedOnboarding = false
    var onboardingDraft = OnboardingDraft()
    var showWelcomeExperience = false
    var showClientProfile = false
    var showUniversalSearch = false
    var showQuickAdd = false
    var showAIAgent = false
    var selectedNetworkProfile: NetworkProfilePreview?
    // A tab named "Learn" opens to learning, not to a scoreboard.
    var selectedHubFeature: ClientHubFeature? = .learn
    var selectedCommunitySection: ClientCommunitySection = .forYou
    var selectedCoachBuildSection: CoachBuildSection = .builder
    var quickCaptureNotes: [String] = []

    var clientProfile: ClientProfile
    var profileShowcase: ProfileShowcase
    var todayTasks: [TaskItem]
    var minimumWinTasks: [TaskItem]
    var minimumWinModeEnabled = false
    var minimumWinMessage = "Today does not need to be perfect. Complete one small win to keep momentum."
    var streakProtected = false
    var selectedConfidence: ConfidenceLevel? = .maybe
    var didCompleteQuickCheckIn = false
    var recovery: RecoverySnapshot
    var currentPlanAdjustment: PlanAdjustment
    var selectedPlanBReason: PlanBReason?
    var selectedWorkoutFeedback: WorkoutFeedbackOption?
    var workoutFeedbackResponse = ""
    var painArea = "Knee"
    var painSeverity = 4
    var painTriggerExercise = "Walking Lunge"
    var painReports: [PainReport] = []
    var goalTranslation: GoalTranslation
    var personalRules: [PersonalRule]
    var roadmap: [RoadmapPhase]
    var patternInsights: [FrictionInsight]
    var activePatternIndex = 0
    var notifications: [SmartNotificationItem]
    var photoProgress: PhotoProgressSnapshot
    var whyThisMatters: [WhyThisMatters]
    var lessons: [LessonCard]
    var quizzes: [MiniQuiz]
    var quizSelections: [String: Int] = [:]
    var completedQuizIDs: Set<String> = []
    var selectedSportMode: SportFocus
    var sportMetrics: [SportMetric]

    var workoutTemplates: [WorkoutTemplate]
    /// The bundled Discover catalog (Morphe Programs) — browsable, separate
    /// from workoutTemplates so pickers/cycling aren't flooded by 273 entries.
    var catalogWorkouts: [WorkoutTemplate] = []
    /// Saved-from-Discover ids restored from disk, reapplied after demo clears.
    private var persistedSavedCatalogIDs: [String] = []
    var savedWorkouts: [SavedWorkoutLibraryItem]
    var currentWorkoutID: UUID { didSet { persistWorkoutSession() } }
    var workoutLogs: [WorkoutLog] {
        didSet { workoutPersistence.saveLogs(workoutLogs) }
    }
    var workoutAccessGrants: [AthleteAccessGrant]
    var workoutHistory: [WorkoutHistoryEntry]
    var healthTrend: [DayScore]
    var workoutConsistency: [WeeklyWorkoutCount]
    var strengthTrend: [StrengthPoint]
    var weightTrend: [WeightPoint]
    var recentWins: [String]
    var nutrition: NutritionSnapshot
    var friendsActivity: [FriendActivity]
    var challenges: [Challenge]
    var communityPosts: [ProgressPost]
    var pendingPartnerSessionPost: PartnerSessionPostDraft?
    var savedPartnerSessionRecaps: [PartnerSessionPostDraft]
    var networkSuggestions: [NetworkConnectionSuggestion]
    var trainingGroups: [TrainingGroupPreview]
    var leaderboards: [LeaderboardEntry]
    var workoutPartners: [WorkoutPartner]
    var selectedWorkoutPartnerID: UUID?
    var selectedPartnerWorkoutMode: PartnerWorkoutMode = .live
    var partnerWorkoutEnabled = false
    var prefersCompactExerciseView = false
    var athleteMessageThreads: [MessageThread]
    var selectedAthleteThreadID: UUID?
    var athleteThreadDraftSeed: String?
    var clientConversation: [ThreadMessage]
    var athleteAIAgentConversation: [ThreadMessage]
    var selectedMuscleGroup: MuscleGroup = .legs
    var selectedExercise: ExerciseReference?
    var workoutReminder = "Log this workout within 24 hours so Morphe can adjust your next plan accurately."
    var isWorkoutLoggedToday = false { didSet { persistWorkoutSession() } }
    var isWorkoutSessionActive = false { didSet { persistWorkoutSession() } }
    var hasStartedWorkoutFlow = false { didSet { persistWorkoutSession() } }
    var hasCompletedWorkoutFlow = false { didSet { persistWorkoutSession() } }
    var activeWorkoutExerciseIndex = 0 { didSet { persistWorkoutSession() } }
    var completedWorkoutSets: [String: Int] = [:] { didSet { persistWorkoutSession() } }
    var trackedSetReps: [String: [Int]] = [:] { didSet { persistWorkoutSession() } }
    var trackedSetWeights: [String: [Double]] = [:] { didSet { persistWorkoutSession() } }
    /// Per-set RPE (6–10), parallel to trackedSetReps; 0 = not rated.
    var trackedSetRPE: [String: [Int]] = [:] { didSet { persistWorkoutSession() } }
    /// When the live session actually began, so logs carry time trained —
    /// not the template's advertised length.
    var workoutSessionStartedAt: Date? { didSet { persistWorkoutSession() } }
    /// Elapsed minutes captured at finish (clamped 1min–8h); nil = no live
    /// session timing, fall back to the template's planned duration.
    var completedSessionMinutes: Int? { didSet { persistWorkoutSession() } }
    var weightUnit: WeightUnit = .pounds {
        didSet {
            guard oldValue != weightUnit else { return }
            // Convert already-logged session weights so they keep meaning the
            // same physical load (45 lb -> 20.4 kg). Without this, toggling
            // the unit mid-session silently relabeled the raw numbers at log
            // time. Skipped during profile restore — those weights were saved
            // in the restored unit already.
            if !isApplyingProfile {
                convertTrackedSessionWeights(to: weightUnit)
                Haptics.impact(.light)
                showToast("Weights now shown in \(weightUnit.label).")
            }
            persistLocalProfile()
        }
    }

    var coachProfile: CoachProfile
    var coachOverview: CoachOverview
    var coachClients: [CoachClient]
    private var coachOutreachEvents: [CoachOutreachEvent]
    var selectedClientID: UUID?
    var coachSportFilter: SportFocus?
    var messageThreads: [MessageThread]
    var selectedThreadID: UUID?
    var coachThreadDraftSeed: String?
    var coachAIAgentConversation: [ThreadMessage]
    var outreachSuggestions: [OutreachSuggestion]
    var messageTemplates: [MessageTemplate]
    var upcomingSessions: [CalendarEvent]
    var trainingPackages: [TrainingPackage]
    var availabilitySlots: [AvailabilitySlot]
    var sessionBookings: [SessionBooking]
    var selectedProgramTemplateID: UUID?
    var coachBroadcastText = "Team check-in: reply with your biggest win and biggest blocker."
    var coachInterventions: [CoachIntervention]
    var sportSessions: [SportSession]
    var selectedSessionID: UUID?
    var drills: [DrillReference]
    var teamGroups: [TeamGroup]
    var selectedGroupID: UUID?
    var playbooks: [CoachPlaybook]
    var leadRecords: [LeadRecord]
    var coachAnalytics: CoachAnalytics

    let exerciseDatabase: [ExerciseReference]
    /// Exercises the user created themselves (merged with the built-in library).
    var customExercises: [ExerciseReference] = []
    /// Template ids the user built, so we know which to persist as their library.
    private var customWorkoutIDs: Set<UUID> = []

    /// The full exercise library available to the builder: built-in + custom.
    var allExercises: [ExerciseReference] {
        exerciseDatabase + customExercises
    }
    let availableAvatars: [AvatarStyle]
    private let personalizationSelectionLimit = 5
    private var didShareCurrentWorkoutHighlight = false
    private var pendingCoachOutreachContext: PendingCoachOutreachContext?

    /// On-device persistence for the workout-tracking domain. Set once in `init`.
    private let workoutPersistence: WorkoutPersisting
    /// On-device persistence for the user's local profile. Set once in `init`.
    private let profilePersistence: ProfilePersisting

    // MARK: - Accounts (v2 backend foundation)
    /// Auth provider. LocalAuthService now; FirebaseAuthService once connected.
    private let authService: AuthService = LocalAuthService()
    /// The signed-in account, or nil when signed out.
    var authUser: AppUser?
    var authErrorMessage: String?
    var isAuthBusy = false
    /// Guards `persistWorkoutSession()` so session `didSet`s triggered while we
    /// restore a saved snapshot in `init` don't immediately re-save it.
    private var isRestoringWorkoutSession = false
    /// Guards profile persistence while a saved profile is being applied at launch.
    private var isApplyingProfile = false

    init() {
        let templates = MorpheDemoContent.workoutTemplates
        let clients = MorpheDemoContent.coachClients
        let threads = MorpheDemoContent.messageThreads
        let seededClientProfile = MorpheDemoContent.clientProfile
        let seededProfileShowcase = MorpheDemoContent.profileShowcase
        let seededSavedWorkouts = MorpheDemoContent.savedWorkouts
        let seededWorkoutLogs = MorpheDemoContent.workoutLogs.sorted { $0.completedAt > $1.completedAt }
        let seededWorkoutPartners = MorpheDemoContent.workoutPartners
        let seededCoachOutreachEvents = Self.seededCoachOutreachEvents(clients: clients, logs: seededWorkoutLogs)

        // Workout persistence: load the user's saved logs if they exist,
        // otherwise fall back to the seeded demo logs (first launch only).
        let workoutPersistence = WorkoutFilePersistence()
        let persistedWorkoutLogs = workoutPersistence.loadLogs()
        let initialWorkoutLogs = persistedWorkoutLogs ?? seededWorkoutLogs
        self.workoutPersistence = workoutPersistence

        // Local profile persistence: load the user's saved identity, if any.
        let profilePersistence = ProfileFilePersistence()
        let persistedProfile = profilePersistence.loadProfile()
        self.profilePersistence = profilePersistence

        self.exerciseDatabase = MorpheDemoContent.exerciseDatabase
        // Bundled Discover catalog: content as data. Every document is
        // validated against the library — a workout with a missing exercise
        // is dropped rather than shipped broken.
        self.catalogWorkouts = WorkoutCatalog.loadBundled().compactMap {
            WorkoutCatalog.template(from: $0, library: MorpheDemoContent.exerciseDatabase)
        }
        self.availableAvatars = MorpheDemoContent.avatarStyles

        self.clientProfile = seededClientProfile
        self.profileShowcase = seededProfileShowcase
        self.todayTasks = MorpheDemoContent.dailyTasks
        self.minimumWinTasks = MorpheDemoContent.minimumWinTasks
        self.recovery = MorpheDemoContent.recovery
        self.currentPlanAdjustment = MorpheDemoContent.defaultPlanAdjustment
        self.goalTranslation = MorpheDemoContent.goalTranslation(for: seededClientProfile.goal, sport: seededClientProfile.sportMode)
        self.personalRules = MorpheDemoContent.personalRules
        self.roadmap = MorpheDemoContent.roadmap
        self.patternInsights = MorpheDemoContent.patternInsights
        self.notifications = MorpheDemoContent.notifications
        self.photoProgress = MorpheDemoContent.photoProgress
        self.whyThisMatters = MorpheDemoContent.whyThisMatters
        self.lessons = MorpheDemoContent.lessons
        self.quizzes = MorpheDemoContent.quizzes
        self.selectedSportMode = seededClientProfile.sportMode
        self.sportMetrics = MorpheDemoContent.sportMetrics(for: seededClientProfile.sportMode)

        self.workoutTemplates = templates
        self.savedWorkouts = seededSavedWorkouts
        self.currentWorkoutID = templates.first?.id ?? UUID()
        self.workoutLogs = initialWorkoutLogs
        self.workoutAccessGrants = MorpheDemoContent.workoutAccessGrants
        self.workoutHistory = initialWorkoutLogs
            .filter { $0.athleteID == seededClientProfile.id }
            .map {
                WorkoutHistoryEntry(
                    title: $0.workoutTitle,
                    completedOn: Self.workoutDateLabel(for: $0.completedAt),
                    durationMinutes: $0.durationMinutes,
                    result: "\($0.source.badgeTitle) • \($0.verificationStatus.rawValue)"
                )
            }
        self.healthTrend = MorpheDemoContent.healthTrend
        self.workoutConsistency = Self.rebuiltWorkoutConsistency(
            from: initialWorkoutLogs,
            athleteID: seededClientProfile.id
        )
        self.strengthTrend = MorpheDemoContent.strengthTrend
        self.weightTrend = MorpheDemoContent.weightTrend
        self.recentWins = MorpheDemoContent.recentWins
        self.nutrition = MorpheDemoContent.nutrition
        self.friendsActivity = MorpheDemoContent.friendActivity
        self.challenges = MorpheDemoContent.challenges
        self.communityPosts = MorpheDemoContent.communityPosts
        self.savedPartnerSessionRecaps = []
        self.networkSuggestions = MorpheDemoContent.networkSuggestions
        self.trainingGroups = MorpheDemoContent.trainingGroups
        self.leaderboards = MorpheDemoContent.leaderboards
        self.workoutPartners = seededWorkoutPartners
        self.selectedWorkoutPartnerID = seededWorkoutPartners.first(where: { $0.linkedAthleteID != nil })?.id
            ?? seededWorkoutPartners.first?.id
        self.athleteMessageThreads = MorpheDemoContent.athleteMessageThreads
        self.selectedAthleteThreadID = nil
        self.athleteThreadDraftSeed = nil
        self.clientConversation = MorpheDemoContent.clientCoachConversation
        self.athleteAIAgentConversation = [
            ThreadMessage(sender: .ai, senderName: "Morphe AI", text: "I can get you around the app and get things done — try \"start my workout\", \"show my progress\", or \"switch to kg\". Ask \"what can you do?\" anytime.", timestamp: "Now")
        ]

        self.coachProfile = MorpheDemoContent.coachProfile
        self.coachOverview = MorpheDemoContent.coachOverview
        self.coachClients = clients
        self.coachOutreachEvents = seededCoachOutreachEvents
        self.selectedClientID = clients.first?.id
        self.messageThreads = threads
        self.selectedThreadID = threads.first?.id
        self.coachAIAgentConversation = [
            ThreadMessage(sender: .ai, senderName: "Morphe AI", text: "I can summarize athlete risk, draft outreach, and suggest lighter plans from your coaching data.", timestamp: "Now")
        ]
        self.outreachSuggestions = MorpheDemoContent.outreachSuggestions
        self.messageTemplates = MorpheDemoContent.messageTemplates
        self.upcomingSessions = MorpheDemoContent.upcomingSessions
        self.trainingPackages = MorpheDemoContent.trainingPackages
        self.availabilitySlots = MorpheDemoContent.availabilitySlots
        self.sessionBookings = MorpheDemoContent.sessionBookings
        self.selectedProgramTemplateID = templates.first?.id
        self.coachInterventions = MorpheDemoContent.coachInterventions
        self.sportSessions = MorpheDemoContent.sportSessions
        self.selectedSessionID = MorpheDemoContent.sportSessions.first?.id
        self.drills = MorpheDemoContent.drillLibrary
        self.teamGroups = MorpheDemoContent.teamGroups
        self.selectedGroupID = MorpheDemoContent.teamGroups.first?.id
        self.playbooks = MorpheDemoContent.playbooks
        self.leadRecords = MorpheDemoContent.leadRecords
        self.coachAnalytics = MorpheDemoContent.coachAnalytics

        MorpheTheme.apply(accentPalette: profileShowcase.accentPalette)

        // NOTE: demo logs are intentionally NOT persisted on first launch. A
        // brand-new user starts empty after onboarding (see resetToFreshUser);
        // the in-memory seed is never shown because onboarding gates the app.

        // Rebuild the user's custom exercises and workouts FIRST, so a restored
        // in-progress session can resolve a custom workout as its current one
        // (restoreWorkoutSession only restores currentWorkoutID if the template
        // already exists).
        loadCustomWorkoutLibrary()
        // Restore an in-progress workout session, if one was saved.
        if let snapshot = workoutPersistence.loadSession() {
            restoreWorkoutSession(from: snapshot)
        }
        // Apply the user's saved local profile so the app greets them by name
        // and a returning user skips onboarding.
        if let persistedProfile {
            applyPersistedProfile(persistedProfile)
        }

        authUser = authService.currentUser
        if let authUser { selectedRole = authUser.role.appRole }
    }

    // MARK: - Auth actions

    func signUp(email: String, password: String, role: UserRole, name: String) async {
        isAuthBusy = true
        authErrorMessage = nil
        defer { isAuthBusy = false }
        do {
            let user = try await authService.signUp(email: email, password: password, role: role, displayName: name)
            applySignedIn(user)
        } catch {
            authErrorMessage = (error as? AuthError)?.errorDescription ?? error.localizedDescription
        }
    }

    func signIn(email: String, password: String) async {
        isAuthBusy = true
        authErrorMessage = nil
        defer { isAuthBusy = false }
        do {
            let user = try await authService.signIn(email: email, password: password)
            applySignedIn(user)
        } catch {
            authErrorMessage = (error as? AuthError)?.errorDescription ?? error.localizedDescription
        }
    }

    func signOut() {
        authService.signOut()
        authUser = nil
    }

    private func applySignedIn(_ user: AppUser) {
        authUser = user
        selectedRole = user.role.appRole
        if !hasCompletedOnboarding, !user.displayName.isEmpty {
            onboardingDraft.name = user.displayName
        }
    }

    /// Applies a saved local-profile snapshot over the seeded demo profile.
    private func applyPersistedProfile(_ snapshot: LocalProfileSnapshot) {
        guard snapshot.hasCompletedOnboarding else { return }
        isApplyingProfile = true
        defer { isApplyingProfile = false }
        hasCompletedOnboarding = true

        // Restore the user's own identity so they are never the seeded demo
        // athlete, then recompute history/consistency against that id.
        if let id = UUID(uuidString: snapshot.id) {
            clientProfile.id = id
        }

        // Restore the chosen account role unless a signed-in account already
        // dictates it (auth wins once accounts are connected).
        if authUser == nil, let role = AppRole(rawValue: snapshot.accountRole) {
            selectedRole = role
        }

        clientProfile.name = snapshot.name
        if let gender = GenderOption(rawValue: snapshot.gender) {
            clientProfile.gender = gender
        }
        if !snapshot.selectedSports.isEmpty {
            clientProfile.selectedSports = snapshot.selectedSports.compactMap { SportFocus(rawValue: $0) }
        }
        if !snapshot.selectedTrainingStyles.isEmpty {
            clientProfile.selectedTrainingStyles = snapshot.selectedTrainingStyles.compactMap { TrainingStyleOption(rawValue: $0) }
        }
        if !snapshot.selectedGoals.isEmpty {
            clientProfile.selectedGoals = snapshot.selectedGoals
        }
        clientProfile.goal = snapshot.goal
        clientProfile.physicalGoalTarget = snapshot.physicalGoalTarget
        clientProfile.weightGoalTarget = snapshot.weightGoalTarget
        clientProfile.goalDeadline = snapshot.goalDeadline
        clientProfile.fitnessLevel = snapshot.fitnessLevel
        clientProfile.equipment = snapshot.equipment
        clientProfile.limitations = snapshot.injuries

        profileShowcase.displayName = snapshot.displayName.isEmpty ? snapshot.name : snapshot.displayName
        if !snapshot.username.isEmpty {
            profileShowcase.username = snapshot.username
        }
        if let theme = ThemePreset(rawValue: snapshot.theme) {
            profileShowcase.theme = theme
        }
        if let accent = AccentPalette(rawValue: snapshot.accentPalette) {
            profileShowcase.accentPalette = accent
        }
        if let tone = CoachingTone(rawValue: snapshot.coachingTone) {
            profileShowcase.coachingTone = tone
        }
        if let avatar = AvatarStyle(rawValue: snapshot.avatarStyle) {
            profileShowcase.avatar.style = avatar
        }

        if let unit = WeightUnit(rawValue: snapshot.weightUnit) {
            weightUnit = unit
        }
        if !snapshot.currentProgram.isEmpty {
            clientProfile.currentProgram = snapshot.currentProgram
        }
        if !snapshot.currentPhase.isEmpty {
            profileShowcase.currentPhase = snapshot.currentPhase
        }
        if snapshot.trainingDaysPerWeek > 0 {
            clientProfile.trainingDaysPerWeek = snapshot.trainingDaysPerWeek
        }

        onboardingDraft.name = snapshot.name
        if let sport = SportFocus(rawValue: snapshot.sportMode) {
            clientProfile.sportMode = sport
            applyPrimarySport(sport)
        }
        MorpheTheme.apply(accentPalette: profileShowcase.accentPalette)

        // A returning user must also start clean of seeded demo content (fake
        // wins, records, recovery, and "other people") — only their own persisted
        // logs and custom workouts survive.
        clearSeededDemoData()

        // Re-apply the user's own safety/setup notes: the demo clear above
        // resets limitations/equipment (so the demo athlete's knee complaint
        // can't leak), which must not erase what THIS user restored.
        clientProfile.equipment = snapshot.equipment
        clientProfile.limitations = snapshot.injuries
        clientProfile.height = snapshot.height
        clientProfile.bodyWeight = snapshot.bodyWeight

        rebuildPersonalRules()
        // The demo clear also wiped savedWorkouts — restore the user's own
        // Discover saves.
        rebuildSavedCatalogWorkouts()

        // Same for earned learning progress: the demo clear resets Level 1 /
        // 0 XP, which must not wipe what THIS user actually earned.
        if !snapshot.levelTitle.isEmpty, snapshot.levelTargetXP > 0 {
            let levelValue = levelNumber(from: snapshot.levelTitle) ?? 1
            clientProfile.level.currentTitle = snapshot.levelTitle
            clientProfile.level.nextTitle = "Level \(levelValue + 1)"
            clientProfile.level.currentXP = snapshot.levelXP
            clientProfile.level.targetXP = snapshot.levelTargetXP
        }
        completedQuizIDs = Set(snapshot.completedQuizIDs)

        // History/consistency/score/streak were derived in init against the seeded
        // id; rebuild them now that the user's real identity is restored.
        refreshWorkoutLogDerivedState(for: clientProfile.id)
    }

    /// Persists the current local profile snapshot to disk.
    private func persistLocalProfile() {
        guard !isApplyingProfile else { return }
        profilePersistence.saveProfile(
            LocalProfileSnapshot(
                hasCompletedOnboarding: hasCompletedOnboarding,
                id: clientProfile.id.uuidString,
                name: clientProfile.name,
                gender: clientProfile.gender.rawValue,
                accountRole: selectedRole.rawValue,
                sportMode: clientProfile.sportMode.rawValue,
                selectedSports: clientProfile.selectedSports.map(\.rawValue),
                selectedTrainingStyles: clientProfile.selectedTrainingStyles.map(\.rawValue),
                selectedGoals: clientProfile.selectedGoals,
                goal: clientProfile.goal,
                physicalGoalTarget: clientProfile.physicalGoalTarget,
                weightGoalTarget: clientProfile.weightGoalTarget,
                goalDeadline: clientProfile.goalDeadline,
                fitnessLevel: clientProfile.fitnessLevel,
                equipment: clientProfile.equipment,
                injuries: clientProfile.limitations,
                theme: profileShowcase.theme.rawValue,
                accentPalette: profileShowcase.accentPalette.rawValue,
                coachingTone: profileShowcase.coachingTone.rawValue,
                avatarStyle: profileShowcase.avatar.style.rawValue,
                displayName: profileShowcase.displayName,
                username: profileShowcase.username,
                weightUnit: weightUnit.rawValue,
                currentProgram: clientProfile.currentProgram,
                currentPhase: profileShowcase.currentPhase,
                trainingDaysPerWeek: clientProfile.trainingDaysPerWeek,
                levelTitle: clientProfile.level.currentTitle,
                levelXP: clientProfile.level.currentXP,
                levelTargetXP: clientProfile.level.targetXP,
                completedQuizIDs: Array(completedQuizIDs),
                height: clientProfile.height,
                bodyWeight: clientProfile.bodyWeight
            )
        )
    }

    // MARK: - User-built workouts

    /// Creates a custom exercise the user defines, available alongside the
    /// built-in library, and persists it.
    @discardableResult
    func addCustomExercise(name: String, muscleGroup: MuscleGroup) -> ExerciseReference {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let exercise = ExerciseReference(
            id: "custom-\(UUID().uuidString.prefix(8))",
            name: trimmed.isEmpty ? "Custom exercise" : trimmed,
            muscleGroup: muscleGroup,
            movementPattern: "Custom",
            musclesWorked: muscleGroup.rawValue,
            equipment: "Your choice",
            difficulty: .moderate,
            videoPlaceholder: "",
            instructions: ["Perform with controlled form."],
            formCue: "Move with control through a full range of motion.",
            commonMistakes: "Rushing the reps or using momentum.",
            beginnerModification: "Reduce the load or range until it feels solid.",
            alternatives: [],
            whyThisMatters: "A movement you added to fit your own training."
        )
        customExercises.append(exercise)
        persistWorkoutLibrary()
        return exercise
    }

    /// Builds a new workout from chosen exercises, makes it the current plan,
    /// and persists it so it survives relaunches.
    func createCustomWorkout(name: String, sport: SportFocus, items: [CustomWorkoutItem]) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let exercises = items.map { item in
            WorkoutExercise(
                id: "\(item.exercise.id)-\(UUID().uuidString.prefix(6))",
                exerciseLibraryID: item.exercise.id,
                name: item.exercise.name,
                muscleGroup: item.exercise.muscleGroup,
                sets: "\(item.sets) sets",
                reps: "\(item.reps) reps",
                difficulty: item.exercise.difficulty,
                formCue: item.exercise.formCue
            )
        }
        let template = WorkoutTemplate(
            name: trimmed.isEmpty ? "My Workout" : trimmed,
            type: "Custom workout",
            sport: sport,
            goal: "Your custom session",
            difficulty: .moderate,
            durationMinutes: max(15, items.count * 8),
            equipment: "Your choice",
            exercises: exercises,
            notes: "You built this workout.",
            coachNote: ""
        )
        workoutTemplates.insert(template, at: 0)
        customWorkoutIDs.insert(template.id)
        currentWorkoutID = template.id
        persistWorkoutLibrary()
        showToast("\(template.name) created. Start it from Current plan.")
    }

    /// Deletes one of the user's custom workouts.
    func deleteCustomWorkout(_ id: UUID) {
        guard customWorkoutIDs.contains(id) else { return }
        workoutTemplates.removeAll { $0.id == id }
        customWorkoutIDs.remove(id)
        if currentWorkoutID == id {
            currentWorkoutID = workoutTemplates.first?.id ?? currentWorkoutID
        }
        persistWorkoutLibrary()
    }

    /// True if a template was built by the user (vs a built-in starter).
    func isCustomWorkout(_ id: UUID) -> Bool {
        customWorkoutIDs.contains(id)
    }

    private func persistWorkoutLibrary() {
        let exerciseSnaps = customExercises.map {
            CustomExerciseSnapshot(id: $0.id, name: $0.name, muscleGroup: $0.muscleGroup.rawValue)
        }
        let workoutSnaps = workoutTemplates
            .filter { customWorkoutIDs.contains($0.id) }
            .map { template in
                CustomWorkoutSnapshot(
                    id: template.id.uuidString,
                    name: template.name,
                    sport: template.sport.rawValue,
                    durationMinutes: template.durationMinutes,
                    exercises: template.exercises.map {
                        CustomWorkoutExerciseSnapshot(
                            id: $0.id,
                            libraryID: $0.exerciseLibraryID,
                            name: $0.name,
                            muscleGroup: $0.muscleGroup.rawValue,
                            sets: $0.sets,
                            reps: $0.reps,
                            formCue: $0.formCue
                        )
                    }
                )
            }
        // Saved Discover items persist as catalog ids and are rebuilt on load.
        let savedCatalogIDs = savedWorkouts
            .map(\.workoutTemplateID)
            .filter { id in catalogWorkouts.contains { $0.id == id } }
            .map(\.uuidString)

        workoutPersistence.saveLibrary(
            WorkoutLibrarySnapshot(
                customExercises: exerciseSnaps,
                customWorkouts: workoutSnaps,
                savedCatalogWorkoutIDs: savedCatalogIDs
            )
        )
    }

    /// Rebuilds the user's custom exercises and workouts from disk at launch.
    private func loadCustomWorkoutLibrary() {
        guard let snapshot = workoutPersistence.loadLibrary() else { return }
        persistedSavedCatalogIDs = snapshot.savedCatalogWorkoutIDs
        rebuildSavedCatalogWorkouts()
        customExercises = snapshot.customExercises.map { snap in
            ExerciseReference(
                id: snap.id,
                name: snap.name,
                muscleGroup: MuscleGroup(rawValue: snap.muscleGroup) ?? .core,
                movementPattern: "Custom",
                musclesWorked: snap.muscleGroup,
                equipment: "Your choice",
                difficulty: .moderate,
                videoPlaceholder: "",
                instructions: ["Perform with controlled form."],
                formCue: "Move with control through a full range of motion.",
                commonMistakes: "Rushing the reps or using momentum.",
                beginnerModification: "Reduce the load or range until it feels solid.",
                alternatives: [],
                whyThisMatters: "A movement you added to fit your own training."
            )
        }
        for snap in snapshot.customWorkouts {
            let id = UUID(uuidString: snap.id) ?? UUID()
            guard !workoutTemplates.contains(where: { $0.id == id }) else { continue }
            let exercises = snap.exercises.map {
                WorkoutExercise(
                    // Reuse the persisted id so tracked-set data from an
                    // in-progress session survives relaunch; mint one only for
                    // libraries saved before the id was persisted.
                    id: $0.id.isEmpty ? "\($0.libraryID)-\(UUID().uuidString.prefix(6))" : $0.id,
                    exerciseLibraryID: $0.libraryID,
                    name: $0.name,
                    muscleGroup: MuscleGroup(rawValue: $0.muscleGroup) ?? .core,
                    sets: $0.sets,
                    reps: $0.reps,
                    difficulty: .moderate,
                    formCue: $0.formCue
                )
            }
            let template = WorkoutTemplate(
                id: id,
                name: snap.name,
                type: "Custom workout",
                sport: SportFocus(rawValue: snap.sport) ?? .generalFitness,
                goal: "Your custom session",
                difficulty: .moderate,
                durationMinutes: snap.durationMinutes,
                equipment: "Your choice",
                exercises: exercises,
                notes: "You built this workout.",
                coachNote: ""
            )
            customWorkoutIDs.insert(id)
            workoutTemplates.insert(template, at: 0)
        }
    }

    /// Re-applies a saved in-progress session snapshot. Guarded so the property
    /// `didSet`s it triggers don't immediately re-persist the same snapshot.
    private func restoreWorkoutSession(from snapshot: WorkoutSessionSnapshot) {
        isRestoringWorkoutSession = true
        defer { isRestoringWorkoutSession = false }

        if let id = snapshot.currentWorkoutID,
           workoutTemplates.contains(where: { $0.id == id }) {
            currentWorkoutID = id
        }
        isWorkoutLoggedToday = snapshot.isWorkoutLoggedToday
        isWorkoutSessionActive = snapshot.isWorkoutSessionActive
        hasStartedWorkoutFlow = snapshot.hasStartedWorkoutFlow
        hasCompletedWorkoutFlow = snapshot.hasCompletedWorkoutFlow
        activeWorkoutExerciseIndex = snapshot.activeWorkoutExerciseIndex
        completedWorkoutSets = snapshot.completedWorkoutSets
        trackedSetReps = snapshot.trackedSetReps
        trackedSetWeights = snapshot.trackedSetWeights
        trackedSetRPE = snapshot.trackedSetRPE
        workoutSessionStartedAt = snapshot.workoutSessionStartedAt
        completedSessionMinutes = snapshot.completedSessionMinutes
    }

    /// Persists the current in-progress session snapshot to disk.
    private func persistWorkoutSession() {
        guard !isRestoringWorkoutSession else { return }
        workoutPersistence.saveSession(
            WorkoutSessionSnapshot(
                currentWorkoutID: currentWorkoutID,
                isWorkoutSessionActive: isWorkoutSessionActive,
                hasStartedWorkoutFlow: hasStartedWorkoutFlow,
                hasCompletedWorkoutFlow: hasCompletedWorkoutFlow,
                activeWorkoutExerciseIndex: activeWorkoutExerciseIndex,
                completedWorkoutSets: completedWorkoutSets,
                trackedSetReps: trackedSetReps,
                trackedSetWeights: trackedSetWeights,
                trackedSetRPE: trackedSetRPE,
                workoutSessionStartedAt: workoutSessionStartedAt,
                completedSessionMinutes: completedSessionMinutes,
                isWorkoutLoggedToday: isWorkoutLoggedToday
            )
        )
    }

    var currentWorkout: WorkoutTemplate {
        workoutTemplates.first(where: { $0.id == currentWorkoutID })
            ?? workoutTemplates.first
            ?? WorkoutTemplate(
                name: "Training Session",
                type: "Gym Workout",
                sport: .generalFitness,
                goal: "Build consistency",
                difficulty: .beginner,
                durationMinutes: 30,
                equipment: "Bodyweight",
                exercises: [],
                notes: "No workout is loaded yet.",
                coachNote: "Choose a workout to get moving."
            )
    }

    var activeWorkoutExercise: WorkoutExercise? {
        guard currentWorkout.exercises.indices.contains(activeWorkoutExerciseIndex) else { return nil }
        return currentWorkout.exercises[activeWorkoutExerciseIndex]
    }

    var aiAgentQuickPrompts: [String] {
        if selectedRole == .coach {
            switch selectedCoachTab {
            case .dashboard:
                return ["Who needs attention today?", "Summarize this week's priorities", "Draft a quick outreach message", "Suggest a lighter plan adjustment"]
            case .athletes:
                return ["Summarize this athlete", "What should I watch for?", "Draft a coach note", "What follow-up should I send?"]
            case .programs:
                if selectedCoachBuildSection == .library {
                    return ["Recommend a drill", "Find a warm-up progression", "What fits low readiness?", "Suggest a boxing finisher"]
                }
                return ["Suggest today's session flow", "Draft a lighter version", "What should I assign next?", "Help me simplify this plan"]
            case .network:
                return ["Draft a coach post", "Who should I connect with?", "Summarize my network activity", "Suggest a useful comment"]
            case .messages:
                return ["Draft outreach", "Reply to the latest message", "Write a re-engagement text", "Summarize the conversation"]
            }
        }

        // Athlete prompts lead with ACTIONS the assistant can actually
        // perform, then a couple of coaching questions.
        switch selectedClientTab {
        case .today:
            return ["Start my workout", "I'm tired — give me a smaller win", "Show my progress", "What can you do?"]
        case .train:
            return ["Start my workout", "Open the exercise library", "How hard should this feel?", "Discard this session"]
        case .community:
            return ["Help me reply to my coach", "Draft a progress post", "What should I ask my partner?", "Summarize support messages"]
        case .hub:
            return ["Open today's quiz", "Explain my Morphe Score trend", "Start my workout", "What can you do?"]
        case .more:
            return ["Open the exercise library", "Show my progress", "Switch to kg", "What can you do?"]
        }
    }

    var aiAgentSubtitle: String {
        if selectedRole == .coach {
            switch selectedCoachTab {
            case .dashboard:
                return "Triage the day, spot risk fast, and turn alerts into action."
            case .athletes:
                return "Read athlete context, coach notes, and next-best follow-up without leaving the roster."
            case .programs:
                return selectedCoachBuildSection == .library
                    ? "Search drills, templates, and playbooks with fast coaching context."
                    : "Use the current plan, readiness, and coaching style to shape the next session."
            case .network:
                return "Coach publicly without the noise: useful updates, comments, and credibility signals."
            case .messages:
                return "Draft cleaner outreach, follow-ups, and accountability messages."
            }
        }

        switch selectedClientTab {
        case .today:
            return "Adjust the day, lower the friction, and keep momentum moving."
        case .train:
            return "Get form help, swaps, and pain-safe suggestions without breaking workout flow."
        case .community:
            return "Stay connected to your coach, partner, and support loop."
        case .hub:
            return "Turn scores, reports, and trends into one clear next step."
        case .more:
            return "Use Morphe's tools, library, and learning without digging through the app."
        }
    }

    var aiAgentPlaceholder: String {
        if selectedRole == .coach {
            switch selectedCoachTab {
            case .dashboard:
                return "Ask about athlete risk, priorities, or next moves..."
            case .athletes:
                return "Ask about this athlete's readiness, notes, or follow-up..."
            case .programs:
                return selectedCoachBuildSection == .library
                    ? "Ask for a drill, warm-up, or progression..."
                    : "Ask for a session flow, regression, or assignment idea..."
            case .network:
                return "Ask for a post, comment, or connection idea..."
            case .messages:
                return "Ask for outreach, a reply, or a re-engagement note..."
            }
        }

        switch selectedClientTab {
        case .today:
            return "Ask how to adjust today, lower the load, or protect the streak..."
        case .train:
            return "Ask for swaps, form help, or pain-safe options..."
        case .community:
            return "Ask for a reply, post idea, or partner check-in..."
        case .hub:
            return "Ask about your score, report, or trends..."
        case .more:
            return "Ask about tools, exercises, nutrition, or learning..."
        }
    }

    var aiAgentContextLabel: String {
        if selectedRole == .coach {
            let athlete = selectedCoachClient?.name ?? "All athletes"
            switch selectedCoachTab {
            case .dashboard:
                return "Coach Home"
            case .athletes:
                return "Athlete focus: \(athlete)"
            case .programs:
                return selectedCoachBuildSection == .library
                    ? "Build Library"
                    : "Build: \(selectedProgramTemplate?.name ?? "Program builder")"
            case .network:
                return "Coach network"
            case .messages:
                return "Inbox: \(selectedThread?.participant ?? "Messages")"
            }
        }

        switch selectedClientTab {
        case .today:
            return "Today plan"
        case .train:
            if isWorkoutSessionActive {
                return "Active workout: \(activeWorkoutExercise?.name ?? currentWorkout.name)"
            }
            return "Train: \(currentWorkout.name)"
        case .community:
            return selectedCommunitySection == .contact ? "Contact" : "For You"
        case .hub:
            return "Progress"
        case .more:
            return "More: \(selectedHubFeature?.rawValue ?? "Tools")"
        }
    }

    var filteredExercises: [ExerciseReference] {
        exerciseDatabase.filter { $0.muscleGroup == selectedMuscleGroup }
    }

    var currentPatternInsight: FrictionInsight? {
        guard !patternInsights.isEmpty else { return nil }
        return patternInsights[activePatternIndex % patternInsights.count]
    }

    var currentAthleteWorkoutLogs: [WorkoutLog] {
        workoutLogs(for: clientProfile.id)
    }

    /// Personal records derived from the user's real logged sets: the
    /// all-time top weight per exercise. This makes "your records build
    /// themselves from the workouts you log" actually true — the seeded
    /// showcase records were cleared for real users and nothing ever
    /// repopulated them.
    var derivedPersonalRecords: [PersonalRecord] {
        var best: [String: (weight: Double, date: Date)] = [:]

        for log in currentAthleteWorkoutLogs {
            for exercise in log.exercises {
                guard let weights = exercise.weightsPerSet,
                      let top = weights.max(), top > 0 else { continue }
                let recordedUnit = WeightUnit(rawValue: exercise.weightUnit ?? "") ?? weightUnit
                let normalized: Double
                if recordedUnit == weightUnit {
                    normalized = top
                } else {
                    let factor = weightUnit == .kilograms ? 0.45359237 : 2.20462262
                    normalized = ((top * factor) * 10).rounded() / 10
                }
                if normalized > (best[exercise.name]?.weight ?? 0) {
                    best[exercise.name] = (normalized, log.completedAt)
                }
            }
        }

        return best
            .map { name, entry in
                PersonalRecord(
                    title: name,
                    value: weightUnit.format(entry.weight),
                    detail: "Top set • \(Self.workoutDateLabel(for: entry.date))"
                )
            }
            .sorted { $0.title < $1.title }
    }

    /// Updates the user's injury/limitations note post-onboarding — safety
    /// data must stay editable, not locked after minute one.
    func updateInjuryNote(_ note: String) {
        clientProfile.limitations = note.trimmingCharacters(in: .whitespacesAndNewlines)
        rebuildPersonalRules()
        persistLocalProfile()
        showToast(clientProfile.limitations.isEmpty ? "Injury note cleared." : "Injury note updated.")
    }

    /// Updates free-text body metrics from Profile (onboarding no longer asks).
    func updateBodyMetrics(height: String, weight: String) {
        clientProfile.height = String(height.trimmingCharacters(in: .whitespacesAndNewlines).prefix(20))
        clientProfile.bodyWeight = String(weight.trimmingCharacters(in: .whitespacesAndNewlines).prefix(20))
        persistLocalProfile()
        showToast("Details saved.")
    }

    func updateExperienceLevel(_ level: ExperienceLevelOption) {
        guard clientProfile.fitnessLevel != level.rawValue else { return }
        clientProfile.fitnessLevel = level.rawValue
        persistLocalProfile()
        Haptics.impact(.light)
    }

    /// Updates the weekly training-day target (drives the consistency
    /// denominator on Progress and the profile snapshot).
    func updateTrainingDaysPerWeek(_ days: Int) {
        let clamped = min(max(days, 1), 7)
        guard clamped != clientProfile.trainingDaysPerWeek else { return }
        clientProfile.trainingDaysPerWeek = clamped
        persistLocalProfile()
        Haptics.impact(.light)
        showToast("Weekly target: \(clamped) day\(clamped == 1 ? "" : "s").")
    }

    /// Strength-over-time per exercise, from the raw per-set data on the
    /// user's own logs. Only exercises with 2+ weighted sessions qualify —
    /// one data point isn't a trend. Weights recorded in another unit are
    /// converted to the current display unit before comparison.
    var exerciseStrengthProgress: [ExerciseStrengthProgress] {
        // (exerciseName -> [(date, topWeight normalized to current unit)])
        var history: [String: [(date: Date, top: Double)]] = [:]

        for log in currentAthleteWorkoutLogs.sorted(by: { $0.completedAt < $1.completedAt }) {
            for exercise in log.exercises {
                guard let weights = exercise.weightsPerSet,
                      let top = weights.max(), top > 0 else { continue }
                let recordedUnit = WeightUnit(rawValue: exercise.weightUnit ?? "") ?? weightUnit
                let normalized: Double
                if recordedUnit == weightUnit {
                    normalized = top
                } else {
                    let factor = weightUnit == .kilograms ? 0.45359237 : 2.20462262
                    normalized = ((top * factor) * 10).rounded() / 10
                }
                history[exercise.name, default: []].append((log.completedAt, normalized))
            }
        }

        return history.compactMap { name, entries -> ExerciseStrengthProgress? in
            guard entries.count >= 2, let latest = entries.last else { return nil }
            let previous = entries[entries.count - 2]
            return ExerciseStrengthProgress(
                exerciseName: name,
                sessionCount: entries.count,
                latestTopWeight: latest.top,
                previousTopWeight: previous.top,
                latestDate: latest.date
            )
        }
        .sorted { $0.latestDate > $1.latestDate }
    }

    var currentAthleteWorkoutSummary: WorkoutLogSummary {
        workoutLogSummary(for: clientProfile.id)
    }

    var currentAthletePartnerTrainingInsight: PartnerTrainingInsight {
        partnerTrainingInsight(for: clientProfile.id)
    }

    var currentAthleteSoloBuddyTrend: [SoloBuddyTrendPoint] {
        soloBuddyTrend(for: clientProfile.id)
    }

    var currentAthleteSoloBuddyTrendSummary: String {
        soloBuddyTrendSummary(for: clientProfile.id)
    }

    var currentGoodForTodayRecommendation: GoodForTodayWorkoutRecommendation {
        goodForTodayRecommendation()
    }

    /// Workouts this user has actually logged themselves.
    var loggedWorkoutCount: Int {
        workoutLogs.filter { $0.athleteID == clientProfile.id }.count
    }

    /// Progressive disclosure for the Today screen. A brand-new user gets one
    /// screen with one action; metrics and tools appear as they're EARNED:
    ///   0 — first run: hero card + identity only (no zero-metrics, no tools)
    ///   1 — habit forming (1+ logs): score/streak pills, day plan, adjustments
    ///   2 — full dashboard (5+ logs): patterns, support & progress
    var todayExperienceTier: Int {
        switch loggedWorkoutCount {
        case 0: return 0
        case 1...4: return 1
        default: return 2
        }
    }

    var athletePatternInsights: [AthletePatternInsight] {
        buildAthletePatternInsights()
    }

    var primaryAthletePatternInsight: AthletePatternInsight? {
        athletePatternInsights.first
    }

    var selectedCoachClient: CoachClient? {
        guard let selectedClientID else { return nil }
        return coachClients.first(where: { $0.id == selectedClientID })
    }

    var selectedWorkoutPartner: WorkoutPartner? {
        guard let selectedWorkoutPartnerID else { return nil }
        return workoutPartners.first(where: { $0.id == selectedWorkoutPartnerID })
    }

    var currentPartnerWorkoutPlan: PartnerWorkoutPlan? {
        guard let selectedWorkoutPartner else { return nil }
        return MorpheDemoContent.partnerWorkoutPlan(
            for: currentWorkout,
            partner: selectedWorkoutPartner,
            mode: selectedPartnerWorkoutMode
        )
    }

    var clientAthleteProfile: CoachClient? {
        coachClients.first(where: { $0.id == clientProfile.id })
    }

    var filteredCoachClients: [CoachClient] {
        guard let coachSportFilter else { return coachClients }
        return coachClients.filter { $0.sport == coachSportFilter }
    }

    var selectedThread: MessageThread? {
        guard let selectedThreadID else { return nil }
        return messageThreads.first(where: { $0.id == selectedThreadID })
    }

    func rankedCommunityPosts(for perspective: AppRole) -> [ProgressPost] {
        communityPosts.sorted { lhs, rhs in
            let leftScore = communityFeedScore(for: lhs, perspective: perspective)
            let rightScore = communityFeedScore(for: rhs, perspective: perspective)

            if leftScore == rightScore {
                return lhs.createdAt > rhs.createdAt
            }

            return leftScore > rightScore
        }
    }

    var selectedAthleteThread: MessageThread? {
        guard let selectedAthleteThreadID else { return nil }
        return athleteMessageThreads.first(where: { $0.id == selectedAthleteThreadID })
    }

    func athleteInboxThreads(matching query: String) -> [MessageThread] {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let rankedThreads = athleteMessageThreads.sorted { lhs, rhs in
            let leftPriority = athleteInboxContext(for: lhs).priority
            let rightPriority = athleteInboxContext(for: rhs).priority

            if leftPriority == rightPriority {
                return lhs.participant.localizedCaseInsensitiveCompare(rhs.participant) == .orderedAscending
            }

            return leftPriority > rightPriority
        }

        guard !trimmedQuery.isEmpty else { return rankedThreads }

        return rankedThreads.filter { thread in
            let context = athleteInboxContext(for: thread)
            return thread.participant.lowercased().contains(trimmedQuery)
                || thread.preview.lowercased().contains(trimmedQuery)
                || context.badge.lowercased().contains(trimmedQuery)
                || context.detail.lowercased().contains(trimmedQuery)
                || context.quickActions.contains(where: { $0.rawValue.lowercased().contains(trimmedQuery) })
        }
    }

    func athleteInboxContext(for thread: MessageThread) -> AthleteInboxThreadContext {
        let justFinishedSession = hasCompletedWorkoutFlow && !isWorkoutLoggedToday
        let currentBuddyName = selectedWorkoutPartner?.name
        let hasRecentPainFlag = selectedWorkoutFeedback == .pain || !painReports.isEmpty
        let hasPlanAdjustment = !currentPlanAdjustment.reasons.isEmpty

        switch thread.participant {
        case clientProfile.coachName:
            if justFinishedSession {
                return AthleteInboxThreadContext(
                    badge: "Session update",
                    detail: "You finished today's work. Send your coach a quick note while the session is still fresh.",
                    priority: 100,
                    quickActions: [.reply, .shareWorkout]
                )
            }

            if hasRecentPainFlag {
                return AthleteInboxThreadContext(
                    badge: "Coach follow-up",
                    detail: "You flagged pain or discomfort recently. A quick coach update keeps the next session safer.",
                    priority: 96,
                    quickActions: [.askForSwap, .reply]
                )
            }

            if thread.isUnread {
                return AthleteInboxThreadContext(
                    badge: "Coach replied",
                    detail: "Your coach has a fresh note waiting, and this is still the fastest accountability thread in the app.",
                    priority: 94,
                    quickActions: [.reply]
                )
            }

            return AthleteInboxThreadContext(
                badge: "Coach line open",
                detail: "Keep this thread close for workout updates, quick feedback, and assignment follow-through.",
                priority: 88,
                quickActions: [.reply, .shareWorkout]
            )

        case "Morphe AI":
            if justFinishedSession {
                return AthleteInboxThreadContext(
                    badge: "AI reviewed",
                    detail: "Morphe can help summarize the session you just finished or tee up the next adjustment.",
                    priority: 92,
                    quickActions: [.reply, .askForSwap]
                )
            }

            if hasPlanAdjustment || hasRecentPainFlag {
                return AthleteInboxThreadContext(
                    badge: "Plan support",
                    detail: "AI already has enough context to suggest a cleaner swap, a lighter option, or a recovery-first next move.",
                    priority: 86,
                    quickActions: [.askForSwap, .reply]
                )
            }

            return AthleteInboxThreadContext(
                badge: thread.isUnread ? "New AI note" : "AI ready",
                detail: "Use Morphe for fast plan help, food questions, swaps, or end-of-session summaries.",
                priority: thread.isUnread ? 84 : 72,
                quickActions: [.reply, .askForSwap]
            )

        case currentBuddyName:
            if partnerWorkoutEnabled {
                return AthleteInboxThreadContext(
                    badge: "Buddy ready",
                    detail: "\(thread.participant) is your current workout partner for \(selectedPartnerWorkoutMode.rawValue.lowercased()) mode. Keep the next session moving.",
                    priority: 90,
                    quickActions: [.confirmTomorrow, .shareWorkout]
                )
            }

            if thread.isUnread {
                return AthleteInboxThreadContext(
                    badge: "Buddy ping",
                    detail: "Your workout partner reached out. A fast reply keeps the accountability rhythm intact.",
                    priority: 82,
                    quickActions: [.reply, .confirmTomorrow]
                )
            }

            return AthleteInboxThreadContext(
                badge: "Training buddy",
                detail: "This is a good thread to lock in the next partner session before the week gets crowded.",
                priority: 76,
                quickActions: [.confirmTomorrow, .reply]
            )

        default:
            if thread.isUnread {
                return AthleteInboxThreadContext(
                    badge: "New message",
                    detail: "A fresh training note is waiting here. Good for quick motivation or a social check-in.",
                    priority: 70,
                    quickActions: [.reply]
                )
            }

            return AthleteInboxThreadContext(
                badge: "Training circle",
                detail: "Keep this thread around for ideas, accountability, and seeing how other athletes are moving.",
                priority: 62,
                quickActions: [.reply, .shareWorkout]
            )
        }
    }

    var selectedProgramTemplate: WorkoutTemplate? {
        guard let selectedProgramTemplateID else { return nil }
        return workoutTemplates.first(where: { $0.id == selectedProgramTemplateID })
    }

    var selectedSession: SportSession? {
        guard let selectedSessionID else { return nil }
        return sportSessions.first(where: { $0.id == selectedSessionID })
    }

    var selectedGroup: TeamGroup? {
        guard let selectedGroupID else { return nil }
        return teamGroups.first(where: { $0.id == selectedGroupID })
    }

    var coachFilterOptions: [SportFocus] {
        Array(Set(coachClients.map(\.sport))).sorted { $0.rawValue < $1.rawValue }
    }

    var nutritionInsight: AIInsight {
        if nutrition.proteinConsumed < nutrition.proteinGoal {
            return clientProfile.aiNutritionInsight
        }

        return AIInsight(
            title: "Nutrition feedback",
            summary: "Protein is on track and hydration is improving. Keep dinner simple and consistent.",
            risk: .low,
            recommendation: "Repeat the same easy structure tonight.",
            suggestedAction: "Log your last meal"
        )
    }

    func finishLaunchSequence() {
        withAnimation(.easeInOut(duration: 0.3)) {
            isShowingLaunchSequence = false
        }
    }

    func selectRole(_ role: AppRole) {
        guard selectedRole != role else { return }
        selectedRole = role
        if role == .client {
            selectedClientTab = .today
            selectedCommunitySection = .forYou
        } else {
            selectedCoachTab = .dashboard
        }
        Haptics.impact(.light)
        showToast(role == .client ? "Athlete account active." : "Coach account active.")
    }

    func completeOnboarding() {
        let generatedPlan = MorpheDemoContent.generatedPlan(from: onboardingDraft)
        let primarySport = onboardingDraft.selectedSports.first ?? .generalFitness
        let selectedGoals = onboardingDraft.selectedGoals.map(\.rawValue)

        let trimmedName = onboardingDraft.name.trimmingCharacters(in: .whitespacesAndNewlines)
        let resolvedName = trimmedName.isEmpty ? clientProfile.name : trimmedName

        hasCompletedOnboarding = true
        selectedRole = onboardingDraft.accountType
        clientProfile.name = resolvedName
        profileShowcase.displayName = resolvedName
        let handle = resolvedName.lowercased().filter { $0.isLetter || $0.isNumber }
        if !handle.isEmpty {
            profileShowcase.username = handle
        }
        selectedClientTab = .today
        selectedCoachTab = .dashboard
        selectedCommunitySection = .forYou
        selectedSportMode = primarySport
        // Gender is deliberately NOT copied: the step was cut from onboarding,
        // so writing the draft's default would silently record "Male" for
        // every user without asking.
        clientProfile.selectedSports = onboardingDraft.selectedSports
        clientProfile.selectedTrainingStyles = onboardingDraft.selectedTrainingStyles
        clientProfile.selectedGoals = selectedGoals
        clientProfile.goal = selectedGoals.first ?? defaultGoal(for: primarySport)
        clientProfile.physicalGoalTarget = onboardingDraft.physicalGoalTarget
        clientProfile.weightGoalTarget = onboardingDraft.weightGoalTarget
        clientProfile.goalDeadline = onboardingDraft.goalDeadline
        clientProfile.fitnessLevel = onboardingDraft.experienceLevel.rawValue
        clientProfile.trainingDaysPerWeek = onboardingDraft.trainingDaysPerWeek
        clientProfile.sportMode = primarySport
        clientProfile.currentProgram = generatedPlan.phase
        profileShowcase.theme = onboardingDraft.theme
        profileShowcase.accentPalette = onboardingDraft.accentPalette
        profileShowcase.coachingTone = onboardingDraft.coachingTone
        profileShowcase.avatar.style = onboardingDraft.avatarStyle
        profileShowcase.currentPhase = generatedPlan.phase
        applyPrimarySport(primarySport)
        currentPlanAdjustment = MorpheDemoContent.defaultPlanAdjustment
        goalTranslation = generatedPlan.goalTranslation
        MorpheTheme.apply(accentPalette: onboardingDraft.accentPalette)

        // Mint a fresh identity and clear all seeded demo data so the user
        // starts in THEIR OWN empty account, not the demo athlete's.
        resetToFreshUser()

        // The user's own safety and setup notes — applied AFTER the reset
        // (which clears the demo athlete's) so they actually stick. These were
        // previously discarded and the demo knee complaint persisted instead.
        clientProfile.limitations = onboardingDraft.injuries.trimmingCharacters(in: .whitespacesAndNewlines)
        clientProfile.equipment = onboardingDraft.equipment.trimmingCharacters(in: .whitespacesAndNewlines)
        rebuildPersonalRules()

        // The welcome sheet IS the completion celebration — the toast overlay
        // rendered underneath it and expired unseen.
        showWelcomeExperience = true
        persistLocalProfile()
    }

    /// Resets the signed-in user to a clean, empty account: a brand-new identity
    /// and no seeded demo activity, metrics, history, or "other people" data.
    /// Called when onboarding completes.
    private func resetToFreshUser() {
        // The critical fix: give the user their own stable id. Until now every
        // user inherited the seeded demo athlete's UUID and therefore his logs.
        clientProfile.id = UUID()

        // No activity yet — clear logs, history, and any custom workouts.
        workoutLogs = []
        workoutHistory = []
        workoutConsistency = []
        workoutTemplates.removeAll { customWorkoutIDs.contains($0.id) }
        customWorkoutIDs = []
        customExercises = []

        clearSeededDemoData()
        // Derive starting metrics (score 0, streak 0) from the now-empty logs.
        refreshWorkoutLogDerivedState(for: clientProfile.id)

        workoutPersistence.saveLogs(workoutLogs)
        persistWorkoutLibrary()
    }

    /// Clears every piece of seeded demo content that is NOT the user's own
    /// persisted data (logs/custom workouts/identity). Run on onboarding AND on
    /// every launch for a returning user, so no demo "other people", fake wins,
    /// records, or seeded recovery ever resurface.
    private func clearSeededDemoData() {
        recentWins = []
        patternInsights = []
        notifications = []
        quickCaptureNotes = []
        healthTrend = []
        strengthTrend = []
        weightTrend = []
        roadmap = []                    // no fabricated "Assessment — Done" phases
        clientProfile.adherence = 0
        clientProfile.coachName = ""    // no seeded "Coach Marcus" in solo v1
        // The demo athlete's safety/setup notes and earned level must never
        // become a new user's (the injuries field is safety data).
        clientProfile.limitations = ""
        clientProfile.equipment = ""
        // Same class of leak: the demo's fabricated sport metrics ("Mile time
        // 6:08") and personal rules ("Knee pain history") are other-person data.
        sportMetrics = []
        personalRules = []
        profileShowcase.aiPerformanceBio = ""
        clientProfile.level = LevelProgress(
            currentTitle: "Level 1",
            nextTitle: "Level 2",
            currentXP: 0,
            targetXP: 100,
            streak: 0
        )
        didCompleteQuickCheckIn = false
        recovery = Self.neutralRecovery

        // Honest guidance tips (no fabricated "improved 25%" claims, no "AI" label).
        clientProfile.aiTodayInsight = AIInsight(
            title: "Today's tip",
            summary: "You don't need a perfect session — you need a consistent one. Show up and log it.",
            risk: .low,
            recommendation: "Start moderate, protect your sleep tonight, and add some protein.",
            suggestedAction: "Start today's workout"
        )
        clientProfile.aiProgressInsight = AIInsight(
            title: "Progress tip",
            summary: "Your progress lives in your logged sessions. Stack a few and the trend follows.",
            risk: .low,
            recommendation: "Aim for steady, repeatable workouts over perfect ones.",
            suggestedAction: "Review your progress"
        )
        clientProfile.aiNutritionInsight = AIInsight(
            title: "Nutrition tip",
            summary: "Hit protein and water first — the basics drive most of the result.",
            risk: .low,
            recommendation: "Aim for a protein source at each meal.",
            suggestedAction: "Plan a protein-forward meal"
        )

        // Clear the demo nutrition log (keep the generic goal targets).
        nutrition.caloriesConsumed = 0
        nutrition.proteinConsumed = 0
        nutrition.waterConsumed = 0
        nutrition.meals = []
        nutrition.weeklyProteinTrend = []

        // Clear demo profile showcase content (records/badges "Lucas" earned).
        profileShowcase.personalRecords = []
        profileShowcase.milestones = []
        profileShowcase.badges = []
        profileShowcase.communityStats = []
        profileShowcase.featuredWorkouts = []
        profileShowcase.featuredVideos = []

        // Seeded saved workouts carry demo/coach source names — clear them.
        savedWorkouts = []

        // Remove all seeded "other people": buddies, friends, community, network.
        workoutPartners = []
        selectedWorkoutPartnerID = nil
        partnerWorkoutEnabled = false
        friendsActivity = []
        communityPosts = []
        challenges = []
        networkSuggestions = []
        trainingGroups = []
        leaderboards = []
        athleteMessageThreads = []
        clientConversation = []
        savedPartnerSessionRecaps = []

        // No purchased sessions or coach offerings for a brand-new account.
        // A coach defines packages/availability; a client books from a coach.
        sessionBookings = []
        trainingPackages = []
        availabilitySlots = []

        // A brand-new COACH must not inherit the seeded demo roster (clients,
        // threads, sessions, leads). Same "inherited demo data" class as the
        // athlete identity fix — clear every "other people" collection and the
        // selections/counters that hang off them.
        coachClients = []
        messageThreads = []
        selectedClientID = nil
        selectedThreadID = nil
        upcomingSessions = []
        coachInterventions = []
        outreachSuggestions = []
        leadRecords = []
        teamGroups = []
        selectedGroupID = nil
        sportSessions = []
        selectedSessionID = nil
        coachOverview = CoachOverview(
            activeClients: 0, atRiskClients: 0, checkInsNeeded: 0,
            sessionsToday: 0, painFlags: 0, messagesNeedingResponse: 0,
            alerts: [], wins: [], todaySessions: [], sportAlerts: [],
            weeklySummary: "Add your first client to start coaching.",
            insight: AIInsight(
                title: "Getting started",
                summary: "Connect your first athlete and your coaching dashboard fills in from their real activity.",
                risk: .low,
                recommendation: "Invite an athlete or share your coach profile.",
                suggestedAction: "Add a client"
            )
        )
    }

    func selectSportMode(_ sport: SportFocus) {
        if clientProfile.selectedSports.contains(sport) {
            moveToFront(sport, in: &clientProfile.selectedSports)
        } else {
            clientProfile.selectedSports.insert(sport, at: 0)
        }

        applyPrimarySport(sport)

        if clientProfile.selectedGoals.isEmpty {
            clientProfile.selectedGoals = [defaultGoal(for: sport)]
        }

        clientProfile.goal = clientProfile.selectedGoals.first ?? defaultGoal(for: sport)
        goalTranslation = MorpheDemoContent.goalTranslation(for: clientProfile.goal, sport: sport)
        persistLocalProfile()
        showToast("\(sport.rawValue) mode loaded.")
    }

    func selectConfidence(_ level: ConfidenceLevel) {
        selectedConfidence = level
        Haptics.impact(.light)

        if level == .notConfident {
            currentPlanAdjustment = PlanAdjustment(
                title: "Let's make this easier today",
                body: "Confidence is low, so Morphe is offering lighter options before the day slips away.",
                reasons: [.notEnoughTime, .lowRecovery],
                recommendation: "Try Minimum Win Mode, a shorter workout, recovery session, or move the workout to tomorrow."
            )
        }
    }

    func completeQuickCheckIn() {
        didCompleteQuickCheckIn = true
        recovery.energy = min(recovery.energy + 1, 10)
        showToast("Quick check-in saved.")
    }

    /// Computes a real readiness snapshot from the user's recovery check-in
    /// inputs (instead of showing a seeded/neutral baseline).
    func submitRecoveryCheckIn(sleepHours: Double, energy: Int, soreness: Int, mood: Int, pain: Bool) {
        let sleepScore = min(1.0, max(0.0, sleepHours / 8.0))      // ~8h = full marks
        let energyScore = Double(energy) / 10.0
        let freshnessScore = Double(10 - soreness) / 10.0          // less sore is better
        let moodScore = Double(mood) / 10.0
        var score = Int(((sleepScore + energyScore + freshnessScore + moodScore) / 4.0) * 100)
        if pain { score = max(0, score - 25) }

        let status: RecoveryStatus
        switch score {
        case 80...100: status = .ready
        case 60...79: status = .moderate
        case 40...59: status = .takeItEasy
        default: status = .recoveryRecommended
        }

        let reason: String
        if pain {
            reason = "You flagged pain — keep it light and pick safe, pain-free movements today."
        } else if score >= 80 {
            reason = "Sleep and energy look strong. A good day to push a little."
        } else if score >= 60 {
            reason = "Solid but not peak. Train at a moderate, repeatable effort."
        } else {
            reason = "Recovery is low. Keep today light and protect tomorrow."
        }

        recovery = RecoverySnapshot(
            score: score,
            status: status,
            reason: reason,
            sleepHours: sleepHours,
            energy: energy,
            soreness: soreness,
            mood: mood,
            pain: pain,
            previousSessionFeedback: recovery.previousSessionFeedback
        )
        didCompleteQuickCheckIn = true
        Haptics.success()
        showToast("Recovery check-in saved.")
    }

    func activateMinimumWinMode() {
        minimumWinModeEnabled = true
        minimumWinMessage = "Today does not need to be perfect. Complete one small win to keep momentum."
        currentPlanAdjustment = PlanAdjustment(
            title: "Minimum Win Mode activated",
            body: "The full plan has been replaced with tiny achievable actions so the habit still moves forward.",
            reasons: [.notEnoughTime],
            recommendation: "One small win is enough today."
        )
        Haptics.impact(.medium)
        showCelebration(title: "Plan B activated", detail: "Smaller still counts", symbol: "figure.walk")
        showToast("Minimum Win Mode is on.")
    }

    func choosePlanB(_ reason: PlanBReason) {
        let result = MorpheDemoContent.planBResponse(for: reason)
        selectedPlanBReason = reason
        currentPlanAdjustment = result.0
        minimumWinTasks = result.1
        minimumWinMessage = result.2
        minimumWinModeEnabled = true

        switch reason {
        case .busy, .traveling:
            setCurrentWorkout(named: "15-Minute Quick Workout")
        case .sore, .tired, .competitionSoon, .pain:
            setCurrentWorkout(named: "Low Energy Recovery Day")
        case .noEquipment:
            setCurrentWorkout(named: "15-Minute Quick Workout")
        case .unmotivated:
            setCurrentWorkout(named: "Low Energy Recovery Day")
        }

        showCelebration(title: "Plan B ready", detail: reason.rawValue, symbol: "arrow.triangle.branch")
        showToast(reason.rawValue)
    }

    func protectStreak(with option: String) {
        let wasProtected = streakProtected
        streakProtected = true
        if !wasProtected {
            addAthleteActivityPost(
                title: "Momentum protected",
                detail: "Protected the streak with \(option.lowercased()) instead of letting the day disappear.",
                tags: [selectedSportMode.shortTitle, "Streak Save"],
                comments: [
                    coachHighlightComment(
                        text: "That still counts. The win is keeping the habit alive when the day could have slipped."
                    )
                ],
                reactions: 6
            )
        }
        showCelebration(title: "Momentum protected", detail: option, symbol: "shield.fill")
        showToast("Momentum protected.")
    }

    func toggleTask(_ task: TaskItem) {
        guard let index = todayTasks.firstIndex(where: { $0.id == task.id }) else { return }
        todayTasks[index].isCompleted.toggle()
        updateXP(for: todayTasks[index].xp, add: todayTasks[index].isCompleted)

        if todayTasks[index].isCompleted {
            showCelebration(
                title: "+\(todayTasks[index].xp) XP",
                detail: todayTasks[index].title,
                symbol: "sparkles"
            )
        }
    }

    func toggleMinimumWinTask(_ task: TaskItem) {
        guard let index = minimumWinTasks.firstIndex(where: { $0.id == task.id }) else { return }
        minimumWinTasks[index].isCompleted.toggle()
        updateXP(for: minimumWinTasks[index].xp, add: minimumWinTasks[index].isCompleted)

        if minimumWinTasks[index].isCompleted {
            let wasProtected = streakProtected
            streakProtected = true
            if !wasProtected {
                addAthleteActivityPost(
                    title: "Minimum win complete",
                    detail: "Kept the habit alive with \(task.title.lowercased()).",
                    tags: [selectedSportMode.shortTitle, "Minimum Win"]
                )
            }
            showCelebration(title: "Momentum protected", detail: task.title, symbol: "flame.fill")
            showToast("Momentum protected.")
        }
    }

    func cycleWorkout() {
        let names = workoutTemplates.map(\.name)
        guard let currentIndex = names.firstIndex(of: currentWorkout.name), !names.isEmpty else { return }
        let nextName = names[(currentIndex + 1) % names.count]
        setCurrentWorkout(named: nextName)
        showToast("Switched to \(nextName).")
    }

    func applyWorkoutAdjustment(_ option: WorkoutAdjustmentOption) {
        switch option {
        case .easier:
            setCurrentWorkout(named: "Low Energy Recovery Day")
            currentPlanAdjustment = MorpheDemoContent.planAdjustment(for: [.workoutTooHard])
        case .shorter:
            setCurrentWorkout(named: "15-Minute Quick Workout")
            currentPlanAdjustment = MorpheDemoContent.planAdjustment(for: [.notEnoughTime])
        case .home:
            setCurrentWorkout(named: "15-Minute Quick Workout")
            currentPlanAdjustment = MorpheDemoContent.planAdjustment(for: [.noEquipment])
        case .gym:
            setCurrentWorkout(named: "Beginner Full Body Strength")
            currentPlanAdjustment = MorpheDemoContent.defaultPlanAdjustment
        case .recovery:
            setCurrentWorkout(named: "Low Energy Recovery Day")
            currentPlanAdjustment = MorpheDemoContent.planAdjustment(for: [.lowRecovery])
        case .reschedule:
            currentPlanAdjustment = PlanAdjustment(
                title: "Moved to tomorrow",
                body: "The main workout moved so you can still keep the day manageable.",
                reasons: [.notEnoughTime],
                recommendation: "Use Minimum Win Mode today and return to the full session tomorrow."
            )
        }

        selectedClientTab = .train
        showToast(option.rawValue)
    }

    func startTodayWorkout() {
        isWorkoutSessionActive = true
        hasStartedWorkoutFlow = true
        hasCompletedWorkoutFlow = false
        didShareCurrentWorkoutHighlight = false
        workoutSessionStartedAt = .now
        completedSessionMinutes = nil
        activeWorkoutExerciseIndex = 0
        completedWorkoutSets = [:]
        trackedSetReps = [:]
        trackedSetWeights = [:]
        trackedSetRPE = [:]
        workoutFeedbackResponse = ""
        selectedWorkoutFeedback = nil
        selectedClientTab = .train
        if partnerWorkoutEnabled, let partner = selectedWorkoutPartner {
            showToast("Today's workout is ready with \(partner.name).")
        } else {
            showToast("Today's workout is ready in Train.")
        }
    }

    /// Loads `template` as the current workout AND immediately enters the live
    /// tracker. Every "Start" action funnels through here, so starting a workout
    /// always begins the session instead of only staging the plan in Train.
    func beginLiveWorkout(_ template: WorkoutTemplate) {
        currentWorkoutID = template.id
        startTodayWorkout()
    }

    // MARK: - Discover catalog (bundled Morphe Programs)

    /// Makes a catalog workout usable by the rest of the app (start, save,
    /// history resolution) by inserting its template into workoutTemplates.
    private func ensureCatalogWorkoutInLibrary(_ template: WorkoutTemplate) {
        guard !workoutTemplates.contains(where: { $0.id == template.id }) else { return }
        workoutTemplates.append(template)
    }

    func startCatalogWorkout(_ template: WorkoutTemplate) {
        ensureCatalogWorkoutInLibrary(template)
        beginLiveWorkout(template)
    }

    func saveCatalogWorkout(_ template: WorkoutTemplate) {
        ensureCatalogWorkoutInLibrary(template)
        guard !savedWorkouts.contains(where: { $0.workoutTemplateID == template.id }) else {
            showToast("\(template.name) is already in My Library.")
            return
        }
        savedWorkouts.insert(
            SavedWorkoutLibraryItem(
                workoutTemplateID: template.id,
                workoutName: template.name,
                sport: template.sport,
                sourceName: "Morphe Programs",
                sourceRole: .client,
                sourceContext: "Saved from Discover",
                bestFor: .solo,
                note: template.goal
            ),
            at: 0
        )
        if !persistedSavedCatalogIDs.contains(template.id.uuidString) {
            persistedSavedCatalogIDs.append(template.id.uuidString)
        }
        persistWorkoutLibrary()
        showCelebration(title: "Saved to My Library", detail: template.name, symbol: "bookmark.fill")
    }

    func isCatalogWorkoutSaved(_ template: WorkoutTemplate) -> Bool {
        savedWorkouts.contains { $0.workoutTemplateID == template.id }
    }

    /// Everything browsable in Discover: the bundled catalog plus the
    /// authored per-sport templates surfaced as "Sport-specific training"
    /// (real content — the 18th training type in the taxonomy).
    var discoverWorkouts: [WorkoutTemplate] {
        let sportSpecific = workoutTemplates
            .filter { $0.sport != .generalFitness && !isCustomWorkout($0.id) && $0.trainingTypeTag.isEmpty }
            .map { template -> WorkoutTemplate in
                var copy = template
                copy.trainingTypeTag = "Sport-specific training"
                copy.focusTag = template.sport.shortTitle
                copy.type = "Sport Series"
                return copy
            }
        return catalogWorkouts + sportSpecific
    }

    /// Rebuilds saved catalog items after a launch (or after the demo clear
    /// on the returning-user path wipes savedWorkouts).
    private func rebuildSavedCatalogWorkouts() {
        for idString in persistedSavedCatalogIDs {
            guard let template = catalogWorkouts.first(where: { $0.id.uuidString == idString }),
                  !savedWorkouts.contains(where: { $0.workoutTemplateID == template.id })
            else { continue }
            ensureCatalogWorkoutInLibrary(template)
            savedWorkouts.append(
                SavedWorkoutLibraryItem(
                    workoutTemplateID: template.id,
                    workoutName: template.name,
                    sport: template.sport,
                    sourceName: "Morphe Programs",
                    sourceRole: .client,
                    sourceContext: "Saved from Discover",
                    bestFor: .solo,
                    note: template.goal
                )
            )
        }
    }

    /// The most recent weight logged for this exercise in the current session,
    /// used to pre-fill the tracker's inline weight field set-to-set.
    func lastSessionWeight(for exerciseID: String) -> Double? {
        trackedSetWeights[exerciseID]?.last
    }

    /// True once every exercise in the live session has hit its target sets.
    var isTrackedWorkoutComplete: Bool {
        let exercises = currentWorkout.exercises
        guard isWorkoutSessionActive, !exercises.isEmpty else { return false }
        return exercises.allSatisfy {
            completedWorkoutSets[$0.id, default: 0] >= targetSetCount(for: $0)
        }
    }

    /// Total sets logged so far this session (drives the discard confirmation).
    var trackedSetTotalCount: Int {
        completedWorkoutSets.values.reduce(0, +)
    }

    /// The just-finished session's real logged work, per exercise, for the recap.
    var sessionRecapItems: [WorkoutSetRecap] {
        currentWorkout.exercises.compactMap { exercise in
            let reps = trackedSetReps[exercise.id, default: []]
            guard !reps.isEmpty else { return nil }
            return WorkoutSetRecap(
                id: exercise.id,
                name: exercise.name,
                reps: reps,
                weights: trackedSetWeights[exercise.id, default: []],
                rpes: trackedSetRPE[exercise.id, default: []]
            )
        }
    }

    /// `allowExtra` lets an explicit user action log past the target set count
    /// (the quick-log buttons stay guarded so a stray tap can't over-log).
    func completeTrackedSet(reps: Int, weight: Double? = nil, rpe: Int? = nil, allowExtra: Bool = false) {
        guard let exercise = activeWorkoutExercise else { return }
        let targetSets = targetSetCount(for: exercise)
        let currentCount = completedWorkoutSets[exercise.id, default: 0]

        guard allowExtra || currentCount < targetSets else {
            showToast("\(exercise.name) is already complete.")
            return
        }

        let updatedCount = currentCount + 1
        completedWorkoutSets[exercise.id] = updatedCount
        trackedSetReps[exercise.id, default: []].append(reps)
        // Record weight per set (0 = bodyweight) so logs carry real load, not "As logged".
        trackedSetWeights[exercise.id, default: []].append(max(0, weight ?? 0))
        trackedSetRPE[exercise.id, default: []].append(rpe ?? 0)
        Haptics.impact(.light)

        if updatedCount == targetSets {
            if isTrackedWorkoutComplete {
                showCelebration(
                    title: "All sets logged",
                    detail: "Great work — finish the session when you're ready.",
                    symbol: "checkmark.seal.fill"
                )
            } else {
                showToast("\(exercise.name) complete. Move to the next exercise.")
                advanceToNextIncompleteExercise()
            }
        } else if updatedCount > targetSets {
            showToast("Extra set logged — \(updatedCount) of \(targetSets) planned.")
        } else {
            showToast("\(reps) reps logged for set \(updatedCount) of \(targetSets).")
        }
    }

    /// Converts this session's logged weights into `unit` (lb <-> kg), rounded
    /// to one decimal, so a unit toggle never relabels raw numbers.
    private func convertTrackedSessionWeights(to unit: WeightUnit) {
        guard !trackedSetWeights.isEmpty else { return }
        let factor = unit == .kilograms ? 0.45359237 : 2.20462262
        trackedSetWeights = trackedSetWeights.mapValues { weights in
            weights.map { (($0 * factor) * 10).rounded() / 10 }
        }
    }

    /// Rewrites one already-logged set (fat-finger fix without losing the session).
    func updateTrackedSet(exerciseID: String, setIndex: Int, reps: Int, weight: Double, rpe: Int? = nil) {
        guard var repsLogged = trackedSetReps[exerciseID], repsLogged.indices.contains(setIndex),
              var weightsLogged = trackedSetWeights[exerciseID], weightsLogged.indices.contains(setIndex) else { return }
        repsLogged[setIndex] = reps
        weightsLogged[setIndex] = max(0, weight)
        trackedSetReps[exerciseID] = repsLogged
        trackedSetWeights[exerciseID] = weightsLogged
        if var rpesLogged = trackedSetRPE[exerciseID], rpesLogged.indices.contains(setIndex) {
            rpesLogged[setIndex] = rpe ?? 0
            trackedSetRPE[exerciseID] = rpesLogged
        }
        showToast("Set \(setIndex + 1) updated.")
    }

    /// Removes one logged set and re-syncs the completed count.
    func removeTrackedSet(exerciseID: String, setIndex: Int) {
        guard var repsLogged = trackedSetReps[exerciseID], repsLogged.indices.contains(setIndex) else { return }
        repsLogged.remove(at: setIndex)
        trackedSetReps[exerciseID] = repsLogged
        if var weightsLogged = trackedSetWeights[exerciseID], weightsLogged.indices.contains(setIndex) {
            weightsLogged.remove(at: setIndex)
            trackedSetWeights[exerciseID] = weightsLogged
        }
        if var rpesLogged = trackedSetRPE[exerciseID], rpesLogged.indices.contains(setIndex) {
            rpesLogged.remove(at: setIndex)
            trackedSetRPE[exerciseID] = rpesLogged
        }
        completedWorkoutSets[exerciseID] = repsLogged.count
        showToast("Set removed.")
    }

    /// Abandons the live session without logging anything.
    func cancelTrackedWorkoutSession() {
        isWorkoutSessionActive = false
        hasStartedWorkoutFlow = false
        hasCompletedWorkoutFlow = false
        workoutSessionStartedAt = nil
        completedSessionMinutes = nil
        activeWorkoutExerciseIndex = 0
        completedWorkoutSets = [:]
        trackedSetReps = [:]
        trackedSetWeights = [:]
        trackedSetRPE = [:]
        workoutFeedbackResponse = ""
        selectedWorkoutFeedback = nil
        showToast("Workout discarded.")
    }

    func goToNextTrackedExercise() {
        guard !currentWorkout.exercises.isEmpty else { return }
        activeWorkoutExerciseIndex = min(activeWorkoutExerciseIndex + 1, currentWorkout.exercises.count - 1)
        Haptics.impact(.light)
    }

    /// After an exercise completes, jump to the next one that still has sets
    /// remaining (wrapping), instead of dead-ending on the last exercise.
    private func advanceToNextIncompleteExercise() {
        let exercises = currentWorkout.exercises
        guard !exercises.isEmpty else { return }
        let count = exercises.count
        for offset in 1..<max(count, 2) {
            let index = (activeWorkoutExerciseIndex + offset) % count
            let exercise = exercises[index]
            if completedWorkoutSets[exercise.id, default: 0] < targetSetCount(for: exercise) {
                activeWorkoutExerciseIndex = index
                Haptics.impact(.light)
                return
            }
        }
    }

    func goToPreviousTrackedExercise() {
        guard !currentWorkout.exercises.isEmpty else { return }
        activeWorkoutExerciseIndex = max(activeWorkoutExerciseIndex - 1, 0)
        Haptics.impact(.light)
    }

    @discardableResult
    func finishTrackedWorkoutSession() -> Bool {
        guard hasStartedWorkoutFlow else {
            selectedClientTab = .train
            showToast("Start the session in Train before finishing it.")
            return false
        }

        // Capture how long the session actually ran (template length is only
        // the fallback when timing is unavailable, e.g. legacy sessions).
        if let startedAt = workoutSessionStartedAt {
            let elapsed = Int((Date.now.timeIntervalSince(startedAt) / 60).rounded())
            completedSessionMinutes = min(max(elapsed, 1), 480)
        }

        isWorkoutSessionActive = false
        hasCompletedWorkoutFlow = true
        Haptics.success()
        showToast("Session finished. Add feedback before logging it.")
        return true
    }

    func swapExercise(_ exercise: WorkoutExercise) {
        // Use the first alternative that actually exists in the library —
        // several exercises list a dangling first alt, which used to kill
        // the swap even when a valid second option existed.
        guard let libraryExercise = exerciseDatabase.first(where: { $0.id == exercise.exerciseLibraryID }),
              let replacement = libraryExercise.alternatives
                  .compactMap({ name in exerciseDatabase.first { $0.name == name } })
                  .first
        else {
            showToast("No swap available for \(exercise.name).")
            return
        }

        updateCurrentWorkout { workout in
            guard let index = workout.exercises.firstIndex(where: { $0.id == exercise.id }) else { return }
            workout.exercises[index] = MorpheDemoContent.makeWorkoutExercise(replacement.id, sets: exercise.sets, reps: exercise.reps)
        }

        showToast("Swapped \(exercise.name) for \(replacement.name).")
    }

    func selectAthleteMessageThread(_ thread: MessageThread) {
        selectedAthleteThreadID = thread.id
        Haptics.impact(.light)
    }

    func closeAthleteMessageThread() {
        selectedAthleteThreadID = nil
        Haptics.impact(.light)
    }

    func openAthleteMessageThread(named participant: String) {
        guard let thread = athleteMessageThreads.first(where: { $0.participant == participant }) else { return }
        selectedAthleteThreadID = thread.id
        openCommunity(.contact)
    }

    func performAthleteInboxQuickAction(_ action: AthleteInboxQuickAction, for thread: MessageThread) {
        switch action {
        case .reply:
            selectedAthleteThreadID = thread.id
            openCommunity(.contact)
            showToast("Reply ready.")
        case .shareWorkout:
            athleteThreadDraftSeed = athleteInboxDraft(for: .shareWorkout, thread: thread)
            selectedAthleteThreadID = thread.id
            openCommunity(.contact)
            showToast("Workout update ready to send.")
        case .askForSwap:
            athleteThreadDraftSeed = athleteInboxDraft(for: .askForSwap, thread: thread)
            selectedAthleteThreadID = thread.id
            openCommunity(.contact)
            showToast("Swap request ready.")
        case .confirmTomorrow:
            athleteThreadDraftSeed = athleteInboxDraft(for: .confirmTomorrow, thread: thread)
            selectedAthleteThreadID = thread.id
            openCommunity(.contact)
            showToast("Tomorrow check-in ready.")
        }
    }

    func openPostWorkoutCoachThread() {
        athleteThreadDraftSeed = postWorkoutCoachDraft()
        openAthleteMessageThread(named: clientProfile.coachName)
        showToast("Coach thread ready.")
    }

    func openPostWorkoutBuddyThread() {
        guard let partner = selectedWorkoutPartner else {
            showToast("Pick a workout partner first.")
            return
        }

        guard athleteMessageThreads.contains(where: { $0.participant == partner.name }) else {
            showToast("No buddy thread is ready for \(partner.name) yet.")
            return
        }

        athleteThreadDraftSeed = postWorkoutBuddyDraft(for: partner)
        openAthleteMessageThread(named: partner.name)
        showToast("\(partner.name) is ready for a follow-up.")
    }

    func sharePostWorkoutHighlight() {
        didShareCurrentWorkoutHighlight = true
        shareCommunityPost(postWorkoutHighlightText(), as: .client)
        openCommunity(.forYou)
        showToast("Workout highlight shared.")
    }

    func saveCurrentWorkoutAsFavorite() {
        if let existing = savedWorkouts.first(where: { $0.workoutTemplateID == currentWorkout.id }) {
            if existing.isPinned {
                showToast("\(existing.workoutName) is already pinned as a favorite.")
            } else {
                togglePinnedSavedWorkout(existing)
            }
            return
        }

        let sourceName: String
        let sourceRole: AppRole

        if currentWorkout.name == clientProfile.currentProgram {
            sourceName = clientProfile.planCreatedBy
            sourceRole = .coach
        } else {
            sourceName = profileShowcase.displayName
            sourceRole = .client
        }

        saveWorkoutTemplate(
            currentWorkout,
            sourceName: sourceName,
            sourceRole: sourceRole,
            sourceContext: "Saved after workout",
            bestFor: suggestedUseCase(for: currentWorkout, context: currentWorkout.name + " favorite"),
            note: "Saved after finishing \(currentWorkout.name)."
        )

        if let item = savedWorkouts.first(where: { $0.workoutTemplateID == currentWorkout.id }) {
            togglePinnedSavedWorkout(item)
        }
    }

    func showExerciseDetail(for exercise: WorkoutExercise) {
        if let reference = exerciseDatabase.first(where: { $0.id == exercise.exerciseLibraryID }) {
            selectedExercise = reference
        } else {
            // Custom exercises have no library page yet — say so instead of
            // a tap that silently does nothing.
            showToast("No form guide for \(exercise.name) yet.")
        }
    }

    func selectMuscleGroup(_ group: MuscleGroup) {
        selectedMuscleGroup = group
    }

    func submitWorkoutFeedback(_ option: WorkoutFeedbackOption) {
        selectedWorkoutFeedback = option
        workoutFeedbackResponse = MorpheDemoContent.workoutFeedbackResponse(for: option)
        recovery.previousSessionFeedback = option

        switch option {
        case .tooEasy:
            currentPlanAdjustment = MorpheDemoContent.planAdjustment(for: [.workoutTooEasy])
        case .tooHard:
            currentPlanAdjustment = MorpheDemoContent.planAdjustment(for: [.workoutTooHard])
        case .pain:
            currentPlanAdjustment = MorpheDemoContent.planAdjustment(for: [.painReported])
        case .skippedParts:
            currentPlanAdjustment = MorpheDemoContent.planAdjustment(for: [.notEnoughTime])
        case .justRight:
            currentPlanAdjustment = PlanAdjustment(
                title: "Session matched the plan",
                body: "The effort and structure landed where we wanted them today.",
                reasons: [],
                recommendation: "Stay steady. Morphe will keep progress gradual."
            )
        }

        if option == .pain {
            painTriggerExercise = currentWorkout.exercises.first?.name ?? "Walking Lunge"
        }

        clientConversation.append(ThreadMessage(sender: .ai, senderName: "Morphe AI", text: workoutFeedbackResponse, timestamp: "Now"))
        Haptics.impact(.medium)
    }

    func savePainFlag() {
        let result = MorpheDemoContent.painAlternative(area: painArea, triggerExercise: painTriggerExercise)
        let report = PainReport(area: painArea, severity: painSeverity, triggerExercise: painTriggerExercise, alternative: result.0, note: result.1)
        painReports.insert(report, at: 0)
        currentPlanAdjustment = MorpheDemoContent.planAdjustment(for: [.painReported])
        workoutFeedbackResponse = "Pain flag saved. Morphe recommends \(result.0) and coach review."
        clientConversation.append(ThreadMessage(sender: .system, senderName: "Morphe", text: "Pain flag saved. Safer option: \(result.1)", timestamp: "Now"))
        showToast("Pain flag saved.")
    }

    func quickAction(_ action: TodayQuickAction) {
        switch action {
        case .logWorkout:
            logWorkout()
        case .swapExercise:
            if let exercise = currentWorkout.exercises.first {
                swapExercise(exercise)
                selectedClientTab = .train
            }
        case .askAI:
            openAIAgent()
        case .messageTrainer:
            openAIAgent()
        }
    }

    func logWorkout() {
        if isWorkoutLoggedToday {
            openProgress()
            showToast("Today's workout is already logged.")
            return
        }

        guard hasCompletedWorkoutFlow else {
            selectedClientTab = .train
            showToast("Finish the session in Train before logging it.")
            return
        }

        isWorkoutLoggedToday = true
        markTaskCompleted(named: "Complete today's workout")
        markTaskCompleted(named: "Log your workout within 24 hours")
        updateXP(for: 50, add: true)
        // Morphe Score, streak, and trend are recomputed from logs in
        // appendWorkoutLog -> refreshWorkoutLogDerivedState; no manual edits here.
        let loggedExercises = makeLoggedExercisesFromCurrentWorkout()
        let isBuddySession = partnerWorkoutEnabled && selectedWorkoutPartner != nil
        let sessionNotes = partnerWorkoutSessionNote()

        appendWorkoutLog(
            WorkoutLog(
                athleteID: clientProfile.id,
                athleteName: clientProfile.name,
                workoutTemplateID: currentWorkout.id,
                workoutTitle: currentWorkout.name,
                sport: currentWorkout.sport,
                completedAt: .now,
                // Time actually trained, not the template's advertised length.
                durationMinutes: completedSessionMinutes ?? currentWorkout.durationMinutes,
                exercises: loggedExercises,
                notes: sessionNotes,
                source: isBuddySession ? .partnerShared : .athleteManual,
                enteredByUserID: clientProfile.id,
                enteredByRole: .client,
                enteredByName: isBuddySession
                    ? "\(clientProfile.name) + \(selectedWorkoutPartner?.name ?? "Partner")"
                    : clientProfile.name,
                verificationStatus: .athleteSubmitted
            )
        )

        if let partnerLog = makeMirroredPartnerWorkoutLog(exercises: loggedExercises) {
            appendWorkoutLog(partnerLog)
        }

        isWorkoutSessionActive = false
        hasStartedWorkoutFlow = false
        hasCompletedWorkoutFlow = false

        if !isBuddySession && !didShareCurrentWorkoutHighlight {
            let completedAssignedWorkout = currentWorkout.name == clientProfile.currentProgram
            let completedRecoveryWorkout = currentWorkout.category == .recovery || currentWorkout.name == "Low Energy Recovery Day"

            if completedAssignedWorkout {
                addAthleteActivityPost(
                    title: "Coach assignment complete",
                    detail: "Finished \(currentWorkout.name) from \(clientProfile.planCreatedBy)'s plan and logged it clean in Morphe.",
                    tags: [selectedSportMode.shortTitle, "Coach Assignment", "Workout Complete"],
                    comments: [
                        coachHighlightComment(
                            text: "That is the kind of follow-through that keeps the plan working. Nice job closing the loop."
                        )
                    ],
                    reactions: 10
                )
            } else if completedRecoveryWorkout {
                addAthleteActivityPost(
                    title: "Recovery day followed through",
                    detail: "Kept the momentum alive with \(currentWorkout.name) instead of forcing a heavy day that did not fit.",
                    tags: [selectedSportMode.shortTitle, "Recovery Win", "Workout Complete"],
                    comments: [
                        coachHighlightComment(
                            text: "Good call. Recovery still moves the week forward when it keeps you honest and ready."
                        )
                    ],
                    reactions: 7
                )
            } else {
                addAthleteActivityPost(
                    title: "Workout complete",
                    detail: "Finished \(currentWorkout.name) in \(currentWorkout.durationMinutes) minutes and closed the loop in Morphe.",
                    tags: [selectedSportMode.shortTitle, "Workout Complete"]
                )
            }
        }

        if partnerWorkoutEnabled, let partner = selectedWorkoutPartner, let partnerPlan = currentPartnerWorkoutPlan {
            updateXP(for: partnerPlan.xpBonus, add: true)
            recentWins.insert("Buddy workout complete with \(partner.name) - \(partnerPlan.miniChallenge)", at: 0)
            if !didShareCurrentWorkoutHighlight {
                queuePartnerSessionPostDraft(partner: partner, plan: partnerPlan)
            }
            clientConversation.append(
                ThreadMessage(
                    sender: .system,
                    senderName: "Morphe",
                    text: "\(partner.name) got your update. Buddy bonus +\(partnerPlan.xpBonus) XP.",
                    timestamp: "Now"
                )
            )
        }

        didShareCurrentWorkoutHighlight = false
        openProgress()
        showCelebration(title: "+50 XP", detail: "Workout logged", symbol: "sparkles")
        Haptics.success()
        showToast("Workout logged. Progress updated.")
    }

    func addQuickMeal(_ meal: QuickMeal) {
        nutrition.caloriesConsumed += meal.calories
        nutrition.proteinConsumed += meal.protein
        nutrition.meals.append(MealLogEntry(mealType: "Quick Add", name: meal.title, calories: meal.calories, protein: meal.protein, logged: true))
        nutrition.nutritionScore = min(nutrition.nutritionScore + 2, 100)
        showToast("Added \(meal.title).")
    }

    func addWaterCup() {
        nutrition.waterConsumed = min(nutrition.waterConsumed + 1, nutrition.waterGoal)
        showToast("Water updated.")
    }

    func setNutritionMode(_ mode: NutritionMode) {
        nutrition.mode = mode
        showToast("\(mode.rawValue) enabled.")
    }

    func performNotificationAction(_ notification: SmartNotificationItem) {
        showToast(notification.action)
    }

    func cyclePatternInsight() {
        activePatternIndex = (activePatternIndex + 1) % max(patternInsights.count, 1)
    }

    func answerQuiz(_ quiz: MiniQuiz, with index: Int) {
        // The first answer is final: the explanation reveals the correct
        // option, so wrong-then-right must not earn XP — and a completed
        // quiz can't be flipped to a wrong state afterward. A missed quiz
        // resets next launch for an honest retry.
        guard quizSelections[quiz.id] == nil else { return }
        quizSelections[quiz.id] = index

        if index == quiz.correctIndex {
            completedQuizIDs.insert(quiz.id)
            updateXP(for: quiz.rewardXP, add: true)
            showCelebration(title: "Quiz complete", detail: "+\(quiz.rewardXP) XP", symbol: "brain.head.profile")
            persistLocalProfile()
        } else {
            showToast("Good try — the explanation below has the answer.")
        }
    }

    func sendClientPrompt(_ text: String) {
        let cleanText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanText.isEmpty else { return }

        if let threadIndex = athleteMessageThreads.firstIndex(where: { $0.participant == "Morphe AI" }) {
            athleteMessageThreads[threadIndex].messages.append(
                ThreadMessage(sender: .user, senderName: clientProfile.name, text: cleanText, timestamp: "Now")
            )
            let reply = MorpheDemoContent.aiCoachReply(to: cleanText, tone: profileShowcase.coachingTone)
            athleteMessageThreads[threadIndex].messages.append(
                ThreadMessage(sender: .ai, senderName: "Morphe AI", text: reply, timestamp: "Now")
            )
            athleteMessageThreads[threadIndex].preview = reply
            selectedAthleteThreadID = athleteMessageThreads[threadIndex].id
        }

        openCommunity(.contact)
        showToast("Morphe AI replied.")
    }

    func sendTrainerMessage() {
        if let threadIndex = athleteMessageThreads.firstIndex(where: { $0.participant == clientProfile.coachName }) {
            let reply = "Absolutely. Keep today's session moderate and message me after the first round if anything feels off."
            athleteMessageThreads[threadIndex].messages.append(
                ThreadMessage(sender: .coach, senderName: clientProfile.coachName, text: reply, timestamp: "Now")
            )
            athleteMessageThreads[threadIndex].preview = reply
            selectedAthleteThreadID = athleteMessageThreads[threadIndex].id
        }
        openCommunity(.contact)
        showToast("Coach Marcus replied.")
    }

    func sendAthleteMessage(to threadID: UUID, text: String) {
        let cleanText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanText.isEmpty,
              let threadIndex = athleteMessageThreads.firstIndex(where: { $0.id == threadID })
        else {
            return
        }

        athleteMessageThreads[threadIndex].messages.append(
            ThreadMessage(sender: .user, senderName: clientProfile.name, text: cleanText, timestamp: "Now")
        )

        let reply = athleteReply(for: athleteMessageThreads[threadIndex].participant, prompt: cleanText)
        athleteMessageThreads[threadIndex].messages.append(
            ThreadMessage(sender: reply.sender, senderName: reply.name, text: reply.text, timestamp: "Now")
        )
        athleteMessageThreads[threadIndex].preview = reply.text
        athleteMessageThreads[threadIndex].isUnread = false
        selectedAthleteThreadID = athleteMessageThreads[threadIndex].id
        showToast("\(athleteMessageThreads[threadIndex].participant) replied.")
    }

    func openUniversalSearch() {
        showUniversalSearch = true
        Haptics.impact(.light)
    }

    func closeUniversalSearch() {
        showUniversalSearch = false
    }

    func openQuickAdd() {
        showQuickAdd = true
        Haptics.impact(.light)
    }

    func closeQuickAdd() {
        showQuickAdd = false
    }

    func openAIAgent() {
        showAIAgent = true
        Haptics.impact(.light)
    }

    func closeAIAgent() {
        showAIAgent = false
    }

    func openNetworkProfile(_ profile: NetworkProfilePreview) {
        selectedNetworkProfile = profile
        Haptics.impact(.light)
    }

    func openNetworkProfile(for suggestion: NetworkConnectionSuggestion) {
        openNetworkProfile(
            NetworkProfilePreview(
                name: suggestion.name,
                handle: networkHandle(for: suggestion.name),
                avatar: suggestion.avatar,
                role: suggestion.role,
                headline: suggestion.headline,
                rank: suggestion.rank,
                mutualContext: suggestion.mutualContext,
                featuredTags: [suggestion.role == .coach ? "Coach network" : "Athlete network", suggestion.rank]
            )
        )
    }

    func openCoachNetworkProfile() {
        openNetworkProfile(
            NetworkProfilePreview(
                name: coachProfile.name,
                handle: coachProfile.username,
                avatar: "🧠",
                role: .coach,
                headline: coachProfile.headline,
                rank: coachProfile.networkRank,
                mutualContext: "\(coachProfile.activeClients) active clients • \(coachProfile.specialty)",
                featuredTags: coachProfile.sports.prefix(3).map(\.rawValue)
            )
        )
    }

    func closeNetworkProfile() {
        selectedNetworkProfile = nil
    }

    func notify(_ message: String) {
        showToast(message)
    }

    func sendAIAgentPrompt(_ text: String) {
        let cleanText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanText.isEmpty else { return }

        if selectedRole == .coach {
            coachAIAgentConversation.append(ThreadMessage(sender: .user, senderName: coachProfile.name, text: cleanText, timestamp: "Now"))
            coachAIAgentConversation.append(ThreadMessage(sender: .ai, senderName: "Morphe AI", text: coachAgentReply(to: cleanText), timestamp: "Now"))
        } else {
            athleteAIAgentConversation.append(ThreadMessage(sender: .user, senderName: clientProfile.name, text: cleanText, timestamp: "Now"))
            // Actions first: if the ask maps to something Morphe AI can DO
            // (start a workout, open a screen, change a setting), do it and
            // confirm — otherwise fall back to the coaching reply.
            let reply = assistantActionReply(for: cleanText) ?? athleteAgentReply(to: cleanText)
            athleteAIAgentConversation.append(ThreadMessage(sender: .ai, senderName: "Morphe AI", text: reply, timestamp: "Now"))
        }
    }

    /// Morphe AI's action layer: understands common asks and actually performs
    /// them — navigation, session control, settings — instead of only replying
    /// with text. Returns nil when nothing actionable matched. (The
    /// conversational layer stays scripted until the real model arrives with
    /// the backend.)
    private func assistantActionReply(for text: String) -> String? {
        let lower = text.lowercased()
        func has(_ words: String...) -> Bool { words.contains { lower.contains($0) } }

        // Session control first — the most consequential intents.
        if has("discard", "cancel", "quit", "stop") && has("workout", "session", "training") {
            guard isWorkoutSessionActive else { return "There's no live session to discard right now." }
            cancelTrackedWorkoutSession()
            return "Session discarded — nothing was logged."
        }
        if has("start", "begin") && has("workout", "plan", "session", "train") {
            guard !isWorkoutSessionActive else {
                selectedClientTab = .train
                return "You're already mid-session — it's open in Train."
            }
            startTodayWorkout()
            return "Done — \(currentWorkout.name) is live in Train. Log your first set when you're ready."
        }
        if has("smaller", "easier", "tired", "low energy", "minimum win") {
            activateMinimumWinMode()
            return "Minimum Win mode is on — one small win still counts today."
        }

        // Settings.
        if has("kilogram", " kg", "to kg") {
            weightUnit = .kilograms
            return "Switched to kilograms."
        }
        if has("pound", " lb", "to lb") {
            weightUnit = .pounds
            return "Switched to pounds."
        }

        // Navigation.
        if has("progress", "score", "streak", "stronger", "records", "history") {
            openProgress()
            return "Opened Progress — your score, strength trend, and workout history are there."
        }
        if has("lesson", "quiz", "learn") {
            openMore(.learn)
            return "Opened Lessons — today's quiz is at the top."
        }
        if has("library", "exercise", "form guide", "anatomy") {
            openMore(.library)
            return "Opened the exercise library — pick a muscle group to browse form guides."
        }
        if has("profile", "settings", "avatar", "injur", "rename") {
            openClientProfile()
            return "Opened your profile — name, weight unit, training days, injuries, and avatar live here."
        }
        if has("today", "home") && has("open", "go to", "back", "show") {
            selectedClientTab = .today
            return "Back on Today."
        }

        if has("help", "what can you do", "commands") {
            return "I can start or discard your workout, turn on Minimum Win mode, open Progress, Lessons, the exercise library, or your profile, and switch lb/kg. Just ask."
        }

        return nil
    }

    func previewAIAgentReply(for text: String) -> String {
        let cleanText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanText.isEmpty else { return "" }
        return selectedRole == .coach ? coachAgentReply(to: cleanText) : athleteAgentReply(to: cleanText)
    }

    func openClientProfile() {
        showClientProfile = true
        Haptics.impact(.light)
    }

    func closeClientProfile() {
        showClientProfile = false
    }

    func openProgress() {
        selectedClientTab = .hub
        Haptics.impact(.light)
    }

    func openCommunity(_ section: ClientCommunitySection = .forYou) {
        // Networking is a v2 (multi-user) surface, hidden in v1.
        guard FeatureFlags.multiUserEnabled else { return }
        selectedCommunitySection = section
        selectedClientTab = .community
        Haptics.impact(.light)
    }

    func openWorkoutTemplate(_ template: WorkoutTemplate) {
        currentWorkoutID = template.id
        hasStartedWorkoutFlow = false
        hasCompletedWorkoutFlow = false
        isWorkoutSessionActive = false
        didShareCurrentWorkoutHighlight = false
        activeWorkoutExerciseIndex = 0
        completedWorkoutSets = [:]
        trackedSetReps = [:]
        trackedSetWeights = [:]
        trackedSetRPE = [:]
        selectedClientTab = .train
        showToast("\(template.name) ready in Train.")
    }

    func startSavedWorkout(_ item: SavedWorkoutLibraryItem) {
        guard let template = workoutTemplates.first(where: { $0.id == item.workoutTemplateID }) else {
            showToast("That saved workout is no longer available.")
            return
        }
        beginLiveWorkout(template)
    }

    func startSavedWorkoutWithBuddy(_ item: SavedWorkoutLibraryItem) {
        guard let template = workoutTemplates.first(where: { $0.id == item.workoutTemplateID }) else {
            showToast("That saved workout is no longer available.")
            return
        }
        partnerWorkoutEnabled = true
        beginLiveWorkout(template)
    }

    /// True when Morphe's readiness-based suggestion is a different workout
    /// than the one currently staged as today's.
    var recommendedWorkoutDiffers: Bool {
        currentGoodForTodayRecommendation.workoutTemplateID != currentWorkout.id
    }

    /// Adopts the readiness-based suggestion as today's workout. One workout
    /// identity everywhere — Today's hero and Train's card always show the
    /// same session; the engine's pick is a suggestion, not a second entry
    /// point with its own name.
    func applyRecommendedWorkout() {
        let recommendation = currentGoodForTodayRecommendation
        guard let template = workoutTemplates.first(where: { $0.id == recommendation.workoutTemplateID }) else {
            showToast("That workout is not available right now.")
            return
        }

        currentWorkoutID = template.id
        showToast("Today's workout is now \(template.name).")
    }

    func duplicateSavedWorkout(_ item: SavedWorkoutLibraryItem) {
        guard let template = workoutTemplates.first(where: { $0.id == item.workoutTemplateID }) else {
            showToast("That saved workout is no longer available.")
            return
        }

        var copiedTemplate = template
        copiedTemplate.id = UUID()
        copiedTemplate.name = "My Copy - \(template.name)"
        copiedTemplate.coachNote = "Personal copy built from \(item.sourceName)'s saved workout."
        workoutTemplates.insert(copiedTemplate, at: 0)

        let copyItem = SavedWorkoutLibraryItem(
            workoutTemplateID: copiedTemplate.id,
            workoutName: copiedTemplate.name,
            sport: copiedTemplate.sport,
            sourceName: profileShowcase.displayName,
            sourceRole: .client,
            sourceContext: "Built by you",
            bestFor: .customBuild,
            note: "Personal copy of \(template.name)."
        )
        savedWorkouts.insert(copyItem, at: 0)
        openWorkoutTemplate(copiedTemplate)
        showToast("Saved workout duplicated into your library.")
    }

    func removeSavedWorkout(_ item: SavedWorkoutLibraryItem) {
        savedWorkouts.removeAll { $0.id == item.id }
        persistedSavedCatalogIDs.removeAll { $0 == item.workoutTemplateID.uuidString }
        persistWorkoutLibrary()
        showToast("Removed from saved workouts.")
    }

    func togglePinnedSavedWorkout(_ item: SavedWorkoutLibraryItem) {
        guard let index = savedWorkouts.firstIndex(where: { $0.id == item.id }) else { return }

        if savedWorkouts[index].isPinned {
            savedWorkouts[index].isPinned = false
            showToast("Removed from pinned workouts.")
            return
        }

        let pinnedCount = savedWorkouts.filter(\.isPinned).count
        guard pinnedCount < 3 else {
            showToast("Pin up to 3 workouts at a time.")
            return
        }

        savedWorkouts[index].isPinned = true
        showToast("Pinned to the top of Train.")
    }

    func saveGoodForTodayRecommendation() {
        let recommendation = currentGoodForTodayRecommendation

        if let existingID = recommendation.existingSavedWorkoutID,
           let item = savedWorkouts.first(where: { $0.id == existingID }) {
            if item.isPinned {
                showToast("\(item.workoutName) is already saved for later.")
            } else {
                togglePinnedSavedWorkout(item)
            }
            return
        }

        guard let template = workoutTemplates.first(where: { $0.id == recommendation.workoutTemplateID }) else {
            showToast("That workout is not available right now.")
            return
        }

        saveWorkoutTemplate(
            template,
            sourceName: recommendation.sourceName,
            sourceRole: recommendation.sourceName == clientProfile.planCreatedBy ? .coach : .client,
            sourceContext: "Saved from Good for Today",
            bestFor: recommendation.bestFor,
            note: "Saved from Good for Today because \(recommendation.reasonTitle.lowercased())."
        )
    }

    func assignSavedWorkout(_ item: SavedWorkoutLibraryItem, to client: CoachClient, scheduledLabel: String) {
        guard let template = workoutTemplates.first(where: { $0.id == item.workoutTemplateID }) else {
            showToast("That saved workout is no longer available.")
            return
        }

        assignWorkoutTemplate(template, to: client, scheduledLabel: scheduledLabel)

        if let index = coachClients.firstIndex(where: { $0.id == client.id }) {
            coachClients[index].coachNotes += "\n• Pulled from saved library: \(item.workoutName) (\(item.sourceName))."
        }

        if client.id == clientProfile.id {
            notifications.insert(
                SmartNotificationItem(
                    type: "Saved workout assignment",
                    title: "Coach assigned a saved workout",
                    message: "\(coachProfile.name) assigned \(item.workoutName) from the saved library.",
                    priority: .medium,
                    action: "Open Train"
                ),
                at: 0
            )
        }

        showToast("Saved workout scheduled from the library.")
    }

    func savedWorkoutInsight(for item: SavedWorkoutLibraryItem) -> SavedWorkoutLibraryInsight {
        let insight = workoutTemplateInsight(for: item.workoutTemplateID)
        return SavedWorkoutLibraryInsight(
            completionCount: insight.completionCount,
            lastCompletedAt: insight.lastCompletedAt,
            lastSource: insight.lastSource,
            hasBuddyCompletion: insight.buddyCompletionCount > 0
        )
    }

    func saveWorkoutFromCurrentPlan() {
        let sourceName = clientProfile.planCreatedBy
        let template = resolveWorkoutTemplate(named: clientProfile.currentProgram, preferredSport: clientProfile.sportMode) ?? currentWorkout
        saveWorkoutTemplate(
            template,
            sourceName: sourceName,
            sourceRole: .coach,
            sourceContext: "Saved from current coach plan",
            bestFor: suggestedUseCase(for: template, context: "current coach plan"),
            note: "Current plan saved from \(sourceName)."
        )
    }

    func saveFeaturedWorkout(named title: String, sourceName: String, sourceRole: AppRole) {
        guard let template = resolveWorkoutTemplate(named: title) else {
            showToast("No reusable workout matched that feature yet.")
            return
        }

        saveWorkoutTemplate(
            template,
            sourceName: sourceName,
            sourceRole: sourceRole,
            sourceContext: "Saved from featured work",
            bestFor: suggestedUseCase(for: template, context: "featured work"),
            note: "Saved from \(sourceName)'s featured workout."
        )
    }

    func saveWorkoutFromCommunityPost(_ post: ProgressPost) {
        guard let template = recommendedTemplate(for: post) else {
            showToast("No reusable workout is attached to this post yet.")
            return
        }

        saveWorkoutTemplate(
            template,
            sourceName: post.author,
            sourceRole: post.role,
            sourceContext: "Saved from network",
            bestFor: suggestedUseCase(for: template, context: post.title + " " + post.detail),
            note: "Saved from \"\(post.title)\" in For You."
        )
    }

    func openMore(_ feature: ClientHubFeature? = nil) {
        let utilityFeature = feature.flatMap { $0 == .progress ? nil : $0 } ?? (selectedHubFeature == .progress ? nil : selectedHubFeature) ?? .scores
        selectedHubFeature = utilityFeature
        selectedClientTab = .more
        Haptics.impact(.light)
    }

    func openHub(_ feature: ClientHubFeature? = nil) {
        if feature == .progress || feature == nil {
            openProgress()
        } else {
            openMore(feature)
        }
    }

    func selectWorkoutPartner(_ partner: WorkoutPartner) {
        selectedWorkoutPartnerID = partner.id
        partnerWorkoutEnabled = true
        showToast("\(partner.name) is your partner for today.")
    }

    func saveQuickNote(_ note: String) {
        let cleanNote = note.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanNote.isEmpty else { return }

        quickCaptureNotes.insert(cleanNote, at: 0)

        if selectedRole == .coach, let athleteID = selectedClientID, let index = coachClients.firstIndex(where: { $0.id == athleteID }) {
            coachClients[index].coachNotes += "\n• \(cleanNote)"
        }

        showToast("Quick note saved.")
    }

    func shareDailyWin() {
        let detail = isWorkoutLoggedToday
            ? "Closed the loop on \(currentWorkout.name) and finished the day with momentum intact."
            : "Showing up for the plan today. Small wins still count."

        shareCommunityPost(detail, as: .client)
        openCommunity(.forYou)
    }

    func logRecoveryReset() {
        guard !didCompleteQuickCheckIn else {
            showToast("Recovery reset already saved for today.")
            return
        }

        didCompleteQuickCheckIn = true
        recovery.energy = min(recovery.energy + 1, 10)
        recovery.soreness = max(recovery.soreness - 1, 0)
        recentWins.insert("Added a quick recovery reset after training.", at: 0)
        showToast("Recovery reset saved.")
    }

    func quickAddInvitePartner() {
        if selectedWorkoutPartner == nil {
            selectedWorkoutPartnerID = workoutPartners.first(where: { $0.linkedAthleteID != nil })?.id
                ?? workoutPartners.first?.id
        }

        partnerWorkoutEnabled = true
        selectedClientTab = .train

        if let partner = selectedWorkoutPartner {
            showCelebration(title: "Partner invite ready", detail: partner.name, symbol: "person.2.fill")
        }
        showToast("Partner workout is ready in Train.")
    }

    func selectPartnerWorkoutMode(_ mode: PartnerWorkoutMode) {
        selectedPartnerWorkoutMode = mode
        showToast("\(mode.rawValue) selected.")
    }

    func togglePartnerWorkout(_ isEnabled: Bool) {
        partnerWorkoutEnabled = isEnabled

        if isEnabled {
            if selectedWorkoutPartner == nil {
                selectedWorkoutPartnerID = workoutPartners.first(where: { $0.linkedAthleteID != nil })?.id
                    ?? workoutPartners.first?.id
            }

            if let partner = selectedWorkoutPartner {
                showCelebration(title: "Partner mode on", detail: partner.name, symbol: "person.2.fill")
            }
            showToast("Partner workout is ready.")
        } else {
            showToast("Solo workout mode on.")
        }
    }

    func sendPartnerReadyCheck() {
        guard let partner = selectedWorkoutPartner else {
            showToast("Pick a workout partner first.")
            return
        }

        clientConversation.append(
            ThreadMessage(
                sender: .system,
                senderName: "Morphe",
                text: "Ready check sent to \(partner.name).",
                timestamp: "Now"
            )
        )
        showToast("Ready check sent to \(partner.name).")
    }

    func setCompactExerciseView(_ isCompact: Bool) {
        prefersCompactExerciseView = isCompact
        showToast(isCompact ? "Compact exercise view on." : "Detailed exercise cards on.")
    }

    // Selection toggles stay quiet on success — the chip itself shows the
    // state (and announces it via the .isSelected trait). Toasts only fire
    // when a tap is BLOCKED, which is the one case that needs explaining.
    func toggleOnboardingGoal(_ goal: FitnessGoalOption) {
        switch toggleSelection(goal, in: &onboardingDraft.selectedGoals) {
        case .added, .removed:
            Haptics.impact(.light)
        case .blockedMaximum:
            showToast("Pick up to \(personalizationSelectionLimit) goals.")
        case .blockedMinimum:
            showToast("Keep at least one goal selected.")
        }
    }

    func toggleOnboardingSport(_ sport: SportFocus) {
        switch toggleSelection(sport, in: &onboardingDraft.selectedSports) {
        case .added, .removed:
            Haptics.impact(.light)
        case .blockedMaximum:
            showToast("Pick up to \(personalizationSelectionLimit) sports.")
        case .blockedMinimum:
            showToast("Keep at least one sport selected.")
        }
    }

    func toggleOnboardingTrainingStyle(_ style: TrainingStyleOption) {
        switch toggleSelection(style, in: &onboardingDraft.selectedTrainingStyles) {
        case .added, .removed:
            Haptics.impact(.light)
        case .blockedMaximum:
            showToast("Pick up to \(personalizationSelectionLimit) training styles.")
        case .blockedMinimum:
            showToast("Keep at least one training style selected.")
        }
    }

    func previewOnboardingAccentPalette(_ palette: AccentPalette) {
        onboardingDraft.accentPalette = palette
        MorpheTheme.apply(accentPalette: palette)
        Haptics.impact(.light)
    }

    func updateDisplayName(_ newName: String) {
        let trimmed = String(newName.trimmingCharacters(in: .whitespacesAndNewlines).prefix(40))
        guard !trimmed.isEmpty else {
            showToast("Your name can't be empty.")
            return
        }
        clientProfile.name = trimmed
        profileShowcase.displayName = trimmed
        // The @handle follows the name — a rename must not strand the old
        // handle on every surface. (Local only; uniqueness comes with accounts.)
        let handle = trimmed.lowercased().filter { $0.isLetter || $0.isNumber }
        if !handle.isEmpty {
            profileShowcase.username = handle
        }
        persistLocalProfile()
        showToast("Name updated.")
    }

    func selectAvatarStyle(_ style: AvatarStyle) {
        profileShowcase.avatar.style = style
        persistLocalProfile()
        showCelebration(title: "Avatar updated", detail: style.rawValue, symbol: "person.crop.circle")
    }

    func toggleCoachProfileTrainingStyle(_ style: TrainingStyleOption) {
        switch toggleSelection(style, in: &coachProfile.selectedTrainingStyles) {
        case .added, .removed:
            showToast("Coach training styles updated.")
        case .blockedMaximum:
            showToast("Pick up to \(personalizationSelectionLimit) training styles.")
        case .blockedMinimum:
            showToast("Keep at least one training style selected.")
        }
    }

    func toggleCoachProfileGoal(_ goal: FitnessGoalOption) {
        switch toggleSelection(goal.rawValue, in: &coachProfile.selectedGoals) {
        case .added, .removed:
            showToast("Coach goals updated.")
        case .blockedMaximum:
            showToast("Pick up to \(personalizationSelectionLimit) goals.")
        case .blockedMinimum:
            showToast("Keep at least one goal selected.")
        }
    }

    func toggleCoachProfileSport(_ sport: SportFocus) {
        switch toggleSelection(sport, in: &coachProfile.sports) {
        case .added:
            moveToFront(sport, in: &coachProfile.sports)
        case .removed:
            break
        case .blockedMaximum:
            showToast("Pick up to \(personalizationSelectionLimit) sports.")
            return
        case .blockedMinimum:
            showToast("Keep at least one sport selected.")
            return
        }

        showToast("Coach sports updated.")
    }

    func toggleProfileTrainingStyle(_ style: TrainingStyleOption) {
        switch toggleSelection(style, in: &clientProfile.selectedTrainingStyles) {
        case .added, .removed:
            persistLocalProfile()   // was mutating without saving
            Haptics.impact(.light)
        case .blockedMaximum:
            showToast("Pick up to \(personalizationSelectionLimit) training styles.")
        case .blockedMinimum:
            showToast("Keep at least one training style selected.")
        }
    }

    func dismissWelcomeExperience() {
        showWelcomeExperience = false
    }

    func toggleProfileGoal(_ goal: FitnessGoalOption) {
        switch toggleSelection(goal.rawValue, in: &clientProfile.selectedGoals) {
        case .added:
            break
        case .removed:
            break
        case .blockedMaximum:
            showToast("Pick up to \(personalizationSelectionLimit) goals.")
            return
        case .blockedMinimum:
            showToast("Keep at least one goal selected.")
            return
        }

        clientProfile.goal = clientProfile.selectedGoals.first ?? goal.rawValue
        goalTranslation = MorpheDemoContent.goalTranslation(for: clientProfile.goal, sport: selectedSportMode)
        persistLocalProfile()
        showToast("Goals updated.")
    }

    func toggleProfileSport(_ sport: SportFocus) {
        switch toggleSelection(sport, in: &clientProfile.selectedSports) {
        case .added:
            moveToFront(sport, in: &clientProfile.selectedSports)
        case .removed:
            break
        case .blockedMaximum:
            showToast("Pick up to \(personalizationSelectionLimit) sports.")
            return
        case .blockedMinimum:
            showToast("Keep at least one sport selected.")
            return
        }

        let primarySport = clientProfile.selectedSports.first ?? sport
        applyPrimarySport(primarySport)
        goalTranslation = MorpheDemoContent.goalTranslation(for: clientProfile.goal, sport: primarySport)
        showToast("Sports updated.")
    }

    func reactToCommunityPost(_ post: ProgressPost) {
        guard let index = communityPosts.firstIndex(where: { $0.id == post.id }) else { return }
        communityPosts[index].reactions += 1
        showToast("Reaction added.")
    }

    func commentOnCommunityPost(_ post: ProgressPost) {
        guard let index = communityPosts.firstIndex(where: { $0.id == post.id }) else { return }
        let authorName = selectedRole == .coach ? coachProfile.name : clientProfile.name
        let authorAvatar = selectedRole == .coach ? "🧠" : "🔥"
        let headline = selectedRole == .coach
            ? coachProfile.headline
            : "\(clientProfile.sportMode.rawValue) athlete focused on \(clientProfile.goal.lowercased())"
        let rank = selectedRole == .coach ? coachProfile.networkRank : clientProfile.networkRank
        let text = selectedRole == .coach
            ? "Strong update. Keep the message practical and repeatable."
            : "Love this. Small wins like this are what keep the streak moving."

        communityPosts[index].comments += 1
        communityPosts[index].commentHighlights.insert(
            NetworkComment(
                author: authorName,
                avatar: authorAvatar,
                role: selectedRole,
                headline: headline,
                rank: rank,
                text: text,
                likes: 0
            ),
            at: 0
        )
        showToast("Comment added to the network.")
    }

    func connectToNetworkSuggestion(_ suggestion: NetworkConnectionSuggestion) {
        networkSuggestions.removeAll { $0.id == suggestion.id }
        showCelebration(title: "Connection added", detail: suggestion.name, symbol: "person.crop.circle.badge.plus")
    }

    /// True when the athlete has no people in their network yet — drives the
    /// "build your network" first-run state instead of a barren feed.
    var hasNetworkActivity: Bool {
        !communityPosts.isEmpty
            || !networkSuggestions.isEmpty
            || !trainingGroups.isEmpty
            || !workoutPartners.isEmpty
    }

    /// Shareable invite text for pulling a training partner into Morphe.
    /// Becomes a real deep link once accounts/Firebase are connected.
    var networkInviteMessage: String {
        let name = clientProfile.name.isEmpty ? "me" : clientProfile.name
        return "Train with \(name) on Morphe — we can share workouts, track progress, and keep each other consistent. Download it and let's go. 💪"
    }

    /// Entry point for location-based athlete discovery. Wires to a Firestore
    /// geo query when multi-user ships; for now it acknowledges the intent so
    /// the empty-state CTA is honest about being network-backed.
    func findAthletesNearby() {
        announce("Finding athletes near you… we'll surface matches as people join your area.")
    }

    // MARK: - Coach ↔ client training commerce

    /// Real payment processing (Stripe Connect / Apple Pay) lands with the
    /// backend. Until then the checkout records a real booking but the charge
    /// is deferred, so the UI is honest about money not having moved yet.
    var paymentsEnabled: Bool { false }

    /// Open bookable slots for the booking picker.
    var openAvailabilitySlots: [AvailabilitySlot] {
        availabilitySlots.filter(\.isOpen)
    }

    /// Bookings the current user made themselves (their "My Sessions").
    /// Distinguished from incoming-as-coach by an empty `clientName`.
    var myUpcomingBookings: [SessionBooking] {
        sessionBookings.filter {
            $0.clientName.isEmpty && $0.status != .cancelled && $0.status != .completed
        }
    }

    /// Bookings the current user RECEIVES as a coach (a client booked them).
    private var incomingBookings: [SessionBooking] {
        sessionBookings.filter { !$0.clientName.isEmpty }
    }

    /// Books a session: records the appointment as `requested`/`pending` and
    /// marks the chosen slot taken. The coach confirms and the real charge runs
    /// once payments are connected.
    @discardableResult
    func requestSessionBooking(package: TrainingPackage, slot: AvailabilitySlot, coachName: String) -> SessionBooking {
        if let index = availabilitySlots.firstIndex(where: { $0.id == slot.id }) {
            availabilitySlots[index].isOpen = false
        }

        let booking = SessionBooking(
            coachName: coachName,
            packageTitle: package.title,
            day: slot.day,
            time: slot.time,
            slotID: slot.id,
            priceValue: package.priceValue
        )
        sessionBookings.insert(booking, at: 0)
        showCelebration(
            title: "Session requested",
            detail: "\(package.title) · \(slot.day) \(slot.time)",
            symbol: "calendar.badge.checkmark"
        )
        return booking
    }

    func cancelBooking(_ booking: SessionBooking) {
        guard let index = sessionBookings.firstIndex(where: { $0.id == booking.id }) else { return }
        sessionBookings[index].status = .cancelled
        // Reopen exactly the slot this booking reserved (by id, not day/time,
        // which could collide with another slot at the same time).
        if let slotID = booking.slotID,
           let slotIndex = availabilitySlots.firstIndex(where: { $0.id == slotID }) {
            availabilitySlots[slotIndex].isOpen = true
        }
        announce("Booking cancelled.")
    }

    /// Coach earnings rolled up from INCOMING bookings only (a client's own
    /// outgoing request must never count as the coach's revenue).
    var coachPaidEarnings: Double {
        incomingBookings.filter { $0.paymentStatus == .paid }.reduce(0) { $0 + $1.priceValue }
    }

    var coachPendingEarnings: Double {
        incomingBookings
            .filter { $0.paymentStatus == .pending && $0.status != .cancelled }
            .reduce(0) { $0 + $1.priceValue }
    }

    /// Incoming bookings a coach needs to confirm.
    var coachBookingRequests: [SessionBooking] {
        incomingBookings.filter { $0.status == .requested }
    }

    func confirmBooking(_ booking: SessionBooking) {
        guard let index = sessionBookings.firstIndex(where: { $0.id == booking.id }) else { return }
        sessionBookings[index].status = .confirmed
        let who = booking.clientName.isEmpty ? booking.coachName : booking.clientName
        announce("Confirmed \(who)'s \(booking.packageTitle).")
    }

    func shareCommunityPost(_ text: String, as role: AppRole) {
        let cleanText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanText.isEmpty else { return }

        let title = cleanText.count > 42 ? String(cleanText.prefix(42)) + "..." : cleanText
        let post = ProgressPost(
            author: role == .coach ? coachProfile.name : clientProfile.name,
            avatar: role == .coach ? "🧠" : "🔥",
            role: role,
            headline: role == .coach ? coachProfile.headline : "\(clientProfile.sportMode.rawValue) athlete focused on \(clientProfile.goal.lowercased())",
            rank: role == .coach ? coachProfile.networkRank : clientProfile.networkRank,
            timeAgo: "Now",
            title: title,
            detail: cleanText,
            tags: role == .coach ? ["Coach Post", clientProfile.sportMode.shortTitle] : [clientProfile.sportMode.shortTitle, "Progress Update"],
            reactions: 0,
            comments: 0,
            commentHighlights: []
        )

        communityPosts.insert(post, at: 0)
        showCelebration(title: "Post shared", detail: role == .coach ? "Coach network updated" : "Athlete network updated", symbol: "bubble.left.and.exclamationmark.bubble.right.fill")
    }

    func sharePendingPartnerSessionPost() {
        guard let draft = pendingPartnerSessionPost else { return }
        publishPartnerSessionPost(draft)
        pendingPartnerSessionPost = nil
        showCelebration(title: "Partner post shared", detail: "\(draft.partnerName) is in the loop.", symbol: "person.2.wave.2.fill")
    }

    func savePendingPartnerSessionRecap() {
        guard let draft = pendingPartnerSessionPost else { return }
        savedPartnerSessionRecaps.insert(draft, at: 0)
        pendingPartnerSessionPost = nil
        showToast("Partner session recap saved for later.")
    }

    func dismissPendingPartnerSessionPost() {
        pendingPartnerSessionPost = nil
    }

    func announce(_ message: String) {
        showToast(message)
    }

    func openClientHub(_ client: CoachClient) {
        selectedClientID = client.id
    }

    func closeClientHub() {
        selectedClientID = nil
    }

    func availableSessionTemplates(for athlete: CoachClient) -> [WorkoutTemplate] {
        let matching = workoutTemplates.filter { $0.sport == athlete.sport || $0.sport == .generalFitness }
        return matching.isEmpty ? workoutTemplates : matching
    }

    func availableSessionTemplates(for event: CalendarEvent) -> [WorkoutTemplate] {
        if let athleteID = event.athleteID,
           let athlete = coachClients.first(where: { $0.id == athleteID }) {
            return availableSessionTemplates(for: athlete)
        }

        if let groupID = event.groupID,
           let group = teamGroups.first(where: { $0.id == groupID }) {
            let matching = workoutTemplates.filter { $0.sport == group.sport || $0.sport == .generalFitness }
            return matching.isEmpty ? workoutTemplates : matching
        }

        return workoutTemplates
    }

    func athleteForUpcomingSession(_ event: CalendarEvent) -> CoachClient? {
        guard let athleteID = event.athleteID else { return nil }
        return coachClients.first(where: { $0.id == athleteID })
    }

    func workoutLogs(for athleteID: UUID) -> [WorkoutLog] {
        workoutLogs
            .filter { $0.athleteID == athleteID }
            .sorted { $0.completedAt > $1.completedAt }
    }

    func canCurrentCoachManageWorkoutLogs(for athleteID: UUID) -> Bool {
        workoutAccessGrants.contains {
            $0.athleteID == athleteID && $0.coachID == coachProfile.id && $0.canAddWorkouts
        }
    }

    func canCurrentCoachEditWorkoutLogs(for athleteID: UUID) -> Bool {
        workoutAccessGrants.contains {
            $0.athleteID == athleteID && $0.coachID == coachProfile.id && $0.canEditWorkouts
        }
    }

    func canCurrentCoachApproveAIEntries(for athleteID: UUID) -> Bool {
        workoutAccessGrants.contains {
            $0.athleteID == athleteID && $0.coachID == coachProfile.id && $0.canApproveAIEntries
        }
    }

    func workoutLogSummary(for athleteID: UUID) -> WorkoutLogSummary {
        workoutLogSummary(from: workoutLogs(for: athleteID))
    }

    func partnerTrainingInsight(for athleteID: UUID) -> PartnerTrainingInsight {
        partnerTrainingInsight(
            from: workoutLogs(for: athleteID),
            athleteName: athleteName(for: athleteID)
        )
    }

    func coachNextAction(for athleteID: UUID) -> CoachNextActionRecommendation {
        let followUp = coachFollowUpRecommendation(for: athleteID)
        return CoachNextActionRecommendation(
            title: followUp.title,
            detail: followUp.detail,
            actionLabel: followUp.actionLabel,
            type: followUp.type
        )
    }

    func coachFollowUpRecommendations(limit: Int = 3) -> [CoachFollowUpRecommendation] {
        filteredCoachClients
            .map { coachFollowUpRecommendation(for: $0.id) }
            .sorted { lhs, rhs in
                if lhs.priority == rhs.priority {
                    return lhs.athleteName < rhs.athleteName
                }
                return lhs.priority > rhs.priority
            }
            .prefix(limit)
            .map { $0 }
    }

    func soloBuddyTrend(for athleteID: UUID) -> [SoloBuddyTrendPoint] {
        soloBuddyTrend(from: workoutLogs(for: athleteID))
    }

    func soloBuddyTrendSummary(for athleteID: UUID) -> String {
        let trend = soloBuddyTrend(for: athleteID)
        guard !trend.isEmpty else {
            return "No trend yet. One logged session is enough to start the pattern."
        }

        let totalSolo = trend.reduce(0) { $0 + $1.soloSessions }
        let totalBuddy = trend.reduce(0) { $0 + $1.buddySessions }
        let latest = trend.last
        let previous = trend.dropLast().last

        if totalBuddy == 0 {
            return "Your routine is still mostly solo. One shared session could add an easy accountability lift."
        }

        if let latest, let previous, latest.buddySessions > previous.buddySessions {
            return "Buddy sessions are becoming a bigger part of your routine."
        }

        if totalBuddy > totalSolo {
            return "Partner training is doing a lot of the work for consistency right now."
        }

        if let latest, latest.buddySessions > 0 {
            return "You are still mostly solo, but partner training is starting to show up more regularly."
        }

        return "Solo sessions still lead the month, with buddy workouts working best as a consistency boost."
    }

    func coachAddManualWorkoutLog(
        to athlete: CoachClient,
        template: WorkoutTemplate?,
        workoutTitle: String,
        durationMinutes: Int,
        notes: String
    ) {
        guard canCurrentCoachManageWorkoutLogs(for: athlete.id) else {
            showToast("Coach access is required to add logs for this athlete.")
            return
        }

        let cleanTitle = workoutTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        let selectedTemplate = template
        let fallbackTitle = selectedTemplate?.name ?? "\(athlete.sport.rawValue) session"
        let exercises = exerciseLogs(from: selectedTemplate)

        let log = WorkoutLog(
            athleteID: athlete.id,
            athleteName: athlete.name,
            workoutTemplateID: selectedTemplate?.id,
            workoutTitle: cleanTitle.isEmpty ? fallbackTitle : cleanTitle,
            sport: selectedTemplate?.sport ?? athlete.sport,
            completedAt: .now,
            durationMinutes: max(durationMinutes, 5),
            exercises: exercises,
            notes: notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                ? "Coach \(coachProfile.name) added this workout manually."
                : notes,
            source: .coachManual,
            enteredByUserID: coachProfile.id,
            enteredByRole: .coach,
            enteredByName: coachProfile.name,
            verificationStatus: .coachSubmitted
        )

        appendWorkoutLog(log)
        addCoachTrainingActivityPost(
            title: "Coach logged athlete session",
            detail: "Saved \(log.workoutTitle) for \(athlete.name) and kept the progress record current.",
            tags: [athlete.sport.shortTitle, "Coach Log", "Shared Progress"]
        )
        showCelebration(title: "Workout added", detail: "\(log.workoutTitle) -> \(athlete.name)", symbol: "plus.circle.fill")
        showToast("Coach workout log saved.")
    }

    func makeAIParsedWorkoutLogDraft(to athlete: CoachClient, photoLabel: String) -> WorkoutLog? {
        guard canCurrentCoachApproveAIEntries(for: athlete.id) else {
            showToast("Coach approval access is required for AI imports.")
            return nil
        }

        let template = workoutTemplates.first(where: { $0.sport == athlete.sport }) ?? workoutTemplates.first
        let cleanLabel = photoLabel.trimmingCharacters(in: .whitespacesAndNewlines)
        let parsedExercises = exerciseLogs(from: template).map { exercise in
            LoggedExercise(
                name: exercise.name,
                sets: exercise.sets,
                reps: exercise.reps,
                weight: exercise.weight.isEmpty ? "Parsed from photo" : exercise.weight,
                note: "AI extracted this entry from \(cleanLabel.isEmpty ? "a workout photo" : cleanLabel)."
            )
        }

        return WorkoutLog(
            athleteID: athlete.id,
            athleteName: athlete.name,
            workoutTemplateID: template?.id,
            workoutTitle: template?.name ?? "\(athlete.sport.rawValue) photo import",
            sport: template?.sport ?? athlete.sport,
            completedAt: .now,
            durationMinutes: template?.durationMinutes ?? 35,
            exercises: parsedExercises,
            notes: cleanLabel.isEmpty
                ? "Morphe AI parsed a workout photo. Review the sets, reps, and notes before saving."
                : "Morphe AI parsed \(cleanLabel). Review the sets, reps, and notes before saving.",
            source: .aiPhotoParsed,
            enteredByUserID: coachProfile.id,
            enteredByRole: .coach,
            enteredByName: "Morphe AI",
            verificationStatus: .aiPendingReview
        )
    }

    func confirmAIParsedWorkoutLog(_ draft: WorkoutLog) {
        guard canCurrentCoachApproveAIEntries(for: draft.athleteID) else {
            showToast("Coach approval access is required for AI imports.")
            return
        }

        var log = draft
        log.verificationStatus = .coachApproved
        log.enteredByUserID = coachProfile.id
        log.enteredByRole = .coach
        log.enteredByName = "Morphe AI + \(coachProfile.name)"

        appendWorkoutLog(log)
        addCoachTrainingActivityPost(
            title: "AI workout import reviewed",
            detail: "Reviewed \(log.workoutTitle) from a workout photo and saved it to \(log.athleteName)'s progress.",
            tags: [log.sport.shortTitle, "AI Review", "Shared Progress"]
        )
        showCelebration(title: "AI log added", detail: log.athleteName, symbol: "camera.metering.partial")
        showToast("Photo parsed into a workout log.")
    }

    func updateWorkoutLog(_ updatedLog: WorkoutLog) {
        guard canCoachModifyWorkoutLog(updatedLog) else {
            showToast("Coach edit access is required for this log.")
            return
        }

        guard let index = workoutLogs.firstIndex(where: { $0.id == updatedLog.id }) else { return }
        workoutLogs[index] = updatedLog
        workoutLogs.sort { $0.completedAt > $1.completedAt }
        refreshWorkoutLogDerivedState(for: updatedLog.athleteID)
        showToast("Workout log updated.")
    }

    func approveWorkoutLog(_ log: WorkoutLog) {
        guard canCurrentCoachApproveAIEntries(for: log.athleteID) else {
            showToast("Coach approval access is required for this log.")
            return
        }

        guard let index = workoutLogs.firstIndex(where: { $0.id == log.id }) else { return }
        workoutLogs[index].verificationStatus = .coachApproved

        if workoutLogs[index].source == .aiPhotoParsed {
            workoutLogs[index].enteredByUserID = coachProfile.id
            workoutLogs[index].enteredByRole = .coach
            workoutLogs[index].enteredByName = "Morphe AI + \(coachProfile.name)"

            if log.athleteID == clientProfile.id {
                addAthleteActivityPost(
                    title: "AI workout import approved",
                    detail: "Morphe AI and \(coachProfile.name) reviewed \(workoutLogs[index].workoutTitle) and saved it to your progress.",
                    tags: [workoutLogs[index].sport.shortTitle, "AI Review"]
                )
            }

            addCoachTrainingActivityPost(
                title: "AI workout import approved",
                detail: "Approved \(workoutLogs[index].workoutTitle) for \(workoutLogs[index].athleteName) after review.",
                tags: [workoutLogs[index].sport.shortTitle, "AI Review", "Coach Review"]
            )
        }

        refreshWorkoutLogDerivedState(for: log.athleteID)
        showToast("Workout log approved.")
    }

    func deleteWorkoutLog(_ log: WorkoutLog) {
        guard canCoachModifyWorkoutLog(log) else {
            showToast("Only coach or AI-added logs can be removed here.")
            return
        }

        workoutLogs.removeAll { $0.id == log.id }
        refreshWorkoutLogDerivedState(for: log.athleteID)
        showToast("Workout log removed.")
    }

    func contactSupport() {
        showToast("Support contact opened.")
    }

    func logoutPlaceholder() {
        showToast("Logout placeholder - connect auth before production.")
    }

    func selectCoachSportFilter(_ sport: SportFocus?) {
        coachSportFilter = sport
        showToast(sport?.rawValue ?? "All sports")
    }

    func selectThread(_ thread: MessageThread) {
        pendingCoachOutreachContext = nil
        selectedThreadID = thread.id
    }

    func openCoachThread(for athleteID: UUID, draft: String? = nil, toast: String? = nil) {
        guard let athlete = coachClients.first(where: { $0.id == athleteID }) else {
            showToast("Athlete not found.")
            return
        }

        guard let thread = messageThreads.first(where: { $0.participant == athlete.name }) else {
            showToast("No thread found for \(athlete.name).")
            return
        }

        selectedCoachTab = .messages
        selectedThreadID = thread.id
        coachThreadDraftSeed = draft
        pendingCoachOutreachContext = nil

        if let toast {
            showToast(toast)
        }
    }

    func openCoachFollowUpThread(for athleteID: UUID, action: CoachNextActionType, toast: String? = nil) {
        openCoachThread(
            for: athleteID,
            draft: coachDraftMessage(for: action, athleteID: athleteID),
            toast: toast
        )
        if let kind = coachOutreachKind(for: action) {
            pendingCoachOutreachContext = PendingCoachOutreachContext(athleteID: athleteID, kind: kind)
        }
    }

    func assignRecoveryPlan(to athleteID: UUID, scheduledLabel: String = "Tomorrow") {
        guard let athlete = coachClients.first(where: { $0.id == athleteID }) else {
            showToast("Athlete not found.")
            return
        }

        guard let template = workoutTemplates.first(where: { $0.name == "Low Energy Recovery Day" }) else {
            showToast("Recovery plan not available right now.")
            return
        }

        assignWorkoutTemplate(template, to: athlete, scheduledLabel: scheduledLabel)
    }

    func openCoachOutreachShortcut(_ shortcut: CoachOutreachShortcut, for athleteID: UUID) {
        guard let athlete = coachClients.first(where: { $0.id == athleteID }) else {
            showToast("Athlete not found.")
            return
        }

        guard let thread = messageThreads.first(where: { $0.participant == athlete.name }) else {
            showToast("No thread found for \(athlete.name).")
            return
        }

        selectedCoachTab = .messages
        selectedThreadID = thread.id
        coachThreadDraftSeed = coachDraftMessage(for: shortcut, athlete: athlete)
        pendingCoachOutreachContext = PendingCoachOutreachContext(
            athleteID: athleteID,
            kind: coachOutreachKind(for: shortcut)
        )
        showToast("\(shortcut.rawValue) ready for \(athlete.name).")
    }

    func makeCoachPraiseDraft(for athleteID: UUID) -> CoachPublicPraiseDraft? {
        guard let athlete = coachClients.first(where: { $0.id == athleteID }) else { return nil }

        let latestLog = workoutLogs(for: athleteID).first
        let lowercasedTitle = latestLog?.workoutTitle.lowercased() ?? ""
        let lowercasedNotes = latestLog?.notes.lowercased() ?? ""

        let contextLabel: String
        let title: String
        let body: String
        var tags = [athlete.sport.shortTitle, "Coach Praise"]

        if let latestLog, latestLog.workoutTitle == athlete.currentProgram {
            contextLabel = "Assignment complete"
            title = "Coach praise"
            body = "\(athlete.name) closed the loop on \(latestLog.workoutTitle) and kept the effort honest. That is the kind of consistency that keeps the whole plan moving."
            tags.append("Coach Assignment")
        } else if let latestLog, latestLog.source == .partnerShared {
            contextLabel = "Partner session"
            title = "Coach praise"
            body = "\(athlete.name) showed up for \(latestLog.workoutTitle) with a partner and kept the accountability high. That kind of shared work compounds."
            tags.append("Partner Session")
        } else if lowercasedTitle.contains("recovery") || lowercasedNotes.contains("recovery") {
            contextLabel = "Recovery follow-through"
            title = "Coach praise"
            body = "\(athlete.name) followed through on a recovery-minded session and treated it like real work instead of skipping the day. That discipline matters."
            tags.append("Recovery Win")
        } else if let latestLog {
            contextLabel = "Latest training win"
            title = "Coach praise"
            body = "\(athlete.name) put in good work on \(latestLog.workoutTitle) and kept the standard where it needed to be. Small honest sessions stack up fast."
            tags.append("Workout Complete")
        } else {
            contextLabel = "Athlete consistency"
            title = "Coach praise"
            body = "\(athlete.name) is doing the real work of building consistency one session at a time. That is what makes the bigger performance goals possible."
        }

        return CoachPublicPraiseDraft(
            athleteID: athlete.id,
            athleteName: athlete.name,
            title: title,
            body: body,
            contextLabel: contextLabel,
            tags: tags
        )
    }

    func shareCoachPraiseDraft(_ draft: CoachPublicPraiseDraft, editedText: String) {
        let cleanText = editedText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanText.isEmpty else { return }

        communityPosts.insert(
            ProgressPost(
                author: coachProfile.name,
                avatar: "🧠",
                role: .coach,
                headline: coachProfile.headline,
                rank: coachProfile.networkRank,
                timeAgo: "Now",
                title: draft.title,
                detail: cleanText,
                tags: draft.tags,
                reactions: 0,
                comments: 0,
                commentHighlights: []
            ),
            at: 0
        )

        trackCoachOutreach(
            .praise,
            athleteID: draft.athleteID,
            athleteName: draft.athleteName,
            sourceLabel: "Coach Praise"
        )
        showCelebration(title: "Coach praise shared", detail: draft.athleteName, symbol: "hands.clap.fill")
        showToast("Public praise shared.")
    }

    func selectProgramTemplate(_ template: WorkoutTemplate) {
        selectedProgramTemplateID = template.id
    }

    func createProgram(from draft: ProgramBuilderDraft) {
        guard !draft.workoutName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        let exercises = draft.exercises.isEmpty ? currentWorkout.exercises : draft.exercises
        var template = WorkoutTemplate(
            name: draft.workoutName,
            type: draft.sessionType.rawValue,
            sport: draft.sport,
            category: draft.category,
            sessionType: draft.sessionType,
            goal: draft.goal,
            difficulty: draft.difficulty,
            durationMinutes: draft.durationMinutes,
            equipment: draft.equipment,
            exercises: exercises,
            defaultSets: draft.defaultSets,
            defaultReps: draft.defaultReps,
            restTime: draft.restTime,
            notes: "\(draft.category.rawValue) builder - \(draft.coachNotes)",
            coachNote: "Custom coach-built session with RPE \(draft.rpe) and rest \(draft.restTime)."
        )

        if let selectedProgramTemplateID,
           let existingIndex = workoutTemplates.firstIndex(where: { $0.id == selectedProgramTemplateID }) {
            template.id = selectedProgramTemplateID
            workoutTemplates[existingIndex] = template
        } else {
            workoutTemplates.insert(template, at: 0)
        }
        selectedProgramTemplateID = template.id
        showToast("Workout draft saved to archive.")
    }

    func assignSelectedProgram(to client: CoachClient) {
        guard let template = selectedProgramTemplate,
              let index = coachClients.firstIndex(where: { $0.id == client.id })
        else { return }

        coachClients[index].currentProgram = template.name
        showCelebration(title: "Program assigned", detail: "\(template.name) -> \(client.name)", symbol: "checkmark.circle.fill")
        showToast("Program assigned successfully.")
    }

    func assignWorkoutTemplate(_ template: WorkoutTemplate, to client: CoachClient, scheduledLabel: String) {
        guard let index = coachClients.firstIndex(where: { $0.id == client.id }) else { return }

        coachClients[index].currentProgram = template.name
        coachClients[index].coachNotes += "\n• Assigned \(template.name) for \(scheduledLabel)."

        if client.name == clientProfile.name {
            clientProfile.currentProgram = template.name
            notifications.insert(
                SmartNotificationItem(
                    type: "Coach assignment",
                    title: "New workout assigned",
                    message: "\(coachProfile.name) assigned \(template.name) for \(scheduledLabel).",
                    priority: .medium,
                    action: "Open Train"
                ),
                at: 0
            )
        }

        addCoachTrainingActivityPost(
            title: "Workout assigned",
            detail: "Assigned \(template.name) to \(client.name) for \(scheduledLabel).",
            tags: [template.sport.shortTitle, "Coach Assignment", "Training Plan"]
        )
        showCelebration(title: "Workout assigned", detail: "\(template.name) -> \(client.name)", symbol: "calendar.badge.plus")
        showToast("Scheduled for \(scheduledLabel).")
    }

    func startCoachSession(
        for athlete: CoachClient,
        with template: WorkoutTemplate,
        sourceLabel: String,
        shouldCelebrate: Bool = true
    ) {
        guard let index = coachClients.firstIndex(where: { $0.id == athlete.id }) else { return }

        coachClients[index].currentProgram = template.name
        coachClients[index].lastWorkout = "Session started now"
        coachClients[index].coachNotes += "\n• Started \(template.name) from \(sourceLabel)."
        selectedProgramTemplateID = template.id
        selectedClientID = athlete.id

        if athlete.id == clientProfile.id {
            clientProfile.currentProgram = template.name
        }

        if shouldCelebrate {
            showCelebration(title: "Session started", detail: "\(athlete.name) • \(template.name)", symbol: "play.circle.fill")
        }
        showToast("Started \(template.name) for \(athlete.name).")
    }

    func startUpcomingSession(_ event: CalendarEvent, with template: WorkoutTemplate) {
        if let athlete = athleteForUpcomingSession(event) {
            startCoachSession(for: athlete, with: template, sourceLabel: "Upcoming Sessions", shouldCelebrate: false)
        }

        guard let eventIndex = upcomingSessions.firstIndex(where: { $0.id == event.id }) else { return }
        upcomingSessions[eventIndex].detail = "Live now: \(template.name). " + event.detail

        if let firstIndex = upcomingSessions[eventIndex].attendance.indices.first {
            upcomingSessions[eventIndex].attendance[firstIndex].status = .present
        }

        selectedProgramTemplateID = template.id
        showCelebration(title: "Session started", detail: "\(event.title) • \(template.name)", symbol: "bolt.circle.fill")
        showToast("Session started from Upcoming Sessions.")
    }

    func quickAssignProgram() {
        let targetClient = selectedCoachClient ?? coachClients.first

        guard let targetClient else {
            selectedCoachTab = .programs
            showToast("Open Build to create the next program.")
            return
        }

        assignSelectedProgram(to: targetClient)
        selectedCoachTab = .programs
    }

    func selectSession(_ session: SportSession) {
        selectedSessionID = session.id
    }

    func selectGroup(_ group: TeamGroup) {
        selectedGroupID = group.id
    }

    func sendInterventionMessage(_ intervention: CoachIntervention) {
        guard let threadIndex = messageThreads.firstIndex(where: { $0.participant == intervention.athleteName }) else {
            showToast("No thread found for \(intervention.athleteName).")
            return
        }
        selectedThreadID = messageThreads[threadIndex].id
        selectedCoachTab = .messages
        showToast("Choose a message for \(intervention.athleteName).")
    }

    func quickAddCoachLead() {
        let newLead = LeadRecord(
            name: "New Athlete Lead",
            sport: .generalFitness,
            status: .newLead,
            note: "Interested in consistency coaching and accountability.",
            aiSuggestion: "Send a warm intro and offer a short consult."
        )

        leadRecords.insert(newLead, at: 0)
        selectedCoachTab = .messages
        showCelebration(title: "Lead added", detail: newLead.name, symbol: "person.crop.circle.badge.plus")
    }

    func quickAddCoachUpdate() {
        shareCommunityPost("Coach note: this week's focus is cleaner adherence, lighter recovery work when needed, and stronger follow-through on the basics.", as: .coach)
        selectedCoachTab = .messages
    }

    func scheduleQuickCheckIn() {
        let targetClient = selectedCoachClient ?? coachClients.first
        let targetName = targetClient?.name ?? "Athlete"
        upcomingSessions.insert(
            CalendarEvent(
                day: "Friday",
                time: "4:00 PM",
                title: "\(targetName) check-in",
                detail: "Quick accountability reset and plan review.",
                type: .checkIn,
                athleteID: targetClient?.id,
                attendance: [
                    TeamMemberAttendance(athleteName: targetName, status: .present, note: "Check-in ready")
                ]
            ),
            at: 0
        )
        showToast("Check-in scheduled for \(targetName).")
    }

    func assignInterventionPlan(_ intervention: CoachIntervention) {
        guard let athleteIndex = coachClients.firstIndex(where: { $0.id == intervention.athleteID }) else {
            showToast("Athlete not found.")
            return
        }

        let updatedProgram: String
        let note: String

        if intervention.reason.localizedCaseInsensitiveContains("pain") || intervention.reason.localizedCaseInsensitiveContains("recovery") {
            updatedProgram = "Low Energy Recovery Day"
            note = "Coach assigned a lighter recovery-focused session from the intervention queue."
        } else if intervention.reason.localizedCaseInsensitiveContains("competition") || intervention.reason.localizedCaseInsensitiveContains("game") {
            updatedProgram = "Competition Taper Session"
            note = "Coach assigned a lighter taper session to protect readiness."
        } else {
            updatedProgram = "15-Minute Quick Workout"
            note = "Coach assigned a shorter reset session to rebuild momentum."
        }

        coachClients[athleteIndex].currentProgram = updatedProgram
        coachClients[athleteIndex].coachNotes = coachClients[athleteIndex].coachNotes + "\n• " + note
        selectedClientID = coachClients[athleteIndex].id

        if let index = coachInterventions.firstIndex(where: { $0.id == intervention.id }) {
            coachInterventions[index].status = "Plan assigned"
        }

        showCelebration(title: "Plan assigned", detail: "\(updatedProgram) -> \(intervention.athleteName)", symbol: "figure.run")
        showToast("Recovery-minded plan assigned.")
    }

    func assignInterventionTemplate(_ template: WorkoutTemplate, to intervention: CoachIntervention) {
        guard let athleteIndex = coachClients.firstIndex(where: { $0.id == intervention.athleteID }) else {
            showToast("Athlete not found.")
            return
        }

        coachClients[athleteIndex].currentProgram = template.name
        coachClients[athleteIndex].coachNotes += "\n• Assigned from intervention queue: \(template.name)"

        if let index = coachInterventions.firstIndex(where: { $0.id == intervention.id }) {
            coachInterventions[index].status = "Plan assigned"
        }

        showCelebration(title: "Plan assigned", detail: "\(template.name) -> \(intervention.athleteName)", symbol: "figure.run")
        showToast("Assigned \(template.name).")
    }

    func reviewIntervention(_ intervention: CoachIntervention) {
        if let index = coachInterventions.firstIndex(where: { $0.id == intervention.id }) {
            coachInterventions[index].status = "Reviewed"
        }

        selectedClientID = intervention.athleteID
        selectedCoachTab = .athletes
        showToast("Opened \(intervention.athleteName)'s profile.")
    }

    func sendOutreach(_ suggestion: OutreachSuggestion) {
        guard let threadIndex = messageThreads.firstIndex(where: { $0.participant == suggestion.clientName }) else {
            showToast("No thread found for \(suggestion.clientName).")
            return
        }

        let message = ThreadMessage(sender: .coach, senderName: coachProfile.name, text: suggestion.suggestedMessage, timestamp: "Now")
        messageThreads[threadIndex].messages.append(message)
        messageThreads[threadIndex].preview = suggestion.suggestedMessage
        messageThreads[threadIndex].isUnread = false
        selectedThreadID = messageThreads[threadIndex].id
        if let athlete = coachClients.first(where: { $0.name == suggestion.clientName }) {
            trackCoachOutreach(
                .generalCheckIn,
                athleteID: athlete.id,
                athleteName: athlete.name,
                sourceLabel: "Outreach Suggestion"
            )
        }
        showToast("Outreach sent to \(suggestion.clientName).")
    }

    func sendCoachThreadMessage(_ text: String) {
        let cleanText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanText.isEmpty,
              let selectedThreadID,
              let threadIndex = messageThreads.firstIndex(where: { $0.id == selectedThreadID })
        else { return }

        let message = ThreadMessage(sender: .coach, senderName: coachProfile.name, text: cleanText, timestamp: "Now")
        messageThreads[threadIndex].messages.append(message)
        messageThreads[threadIndex].preview = cleanText
        messageThreads[threadIndex].isUnread = false
        if let context = pendingCoachOutreachContext,
           let athlete = coachClients.first(where: { $0.id == context.athleteID }),
           messageThreads[threadIndex].participant == athlete.name {
            trackCoachOutreach(
                context.kind,
                athleteID: athlete.id,
                athleteName: athlete.name,
                sourceLabel: "Coach Inbox"
            )
        }
        pendingCoachOutreachContext = nil
        coachThreadDraftSeed = nil
        showToast("Message sent.")
    }

    func sendCoachTemplate(_ template: MessageTemplate, to intervention: CoachIntervention) {
        guard let threadIndex = messageThreads.firstIndex(where: { $0.participant == intervention.athleteName }) else {
            showToast("No thread found for \(intervention.athleteName).")
            return
        }

        let message = ThreadMessage(sender: .coach, senderName: coachProfile.name, text: template.body, timestamp: "Now")
        messageThreads[threadIndex].messages.append(message)
        messageThreads[threadIndex].preview = template.body
        messageThreads[threadIndex].isUnread = false
        selectedThreadID = messageThreads[threadIndex].id

        if let index = coachInterventions.firstIndex(where: { $0.id == intervention.id }) {
            coachInterventions[index].status = "Handled"
        }

        selectedCoachTab = .messages
        showToast("Template queued to \(intervention.athleteName).")
    }

    func rescheduleUpcomingSession(_ event: CalendarEvent, to day: String, time: String) {
        guard let index = upcomingSessions.firstIndex(where: { $0.id == event.id }) else { return }
        upcomingSessions[index].day = day
        upcomingSessions[index].time = time
        showToast("Session rescheduled.")
    }

    func completeUpcomingSession(_ event: CalendarEvent) {
        guard let index = upcomingSessions.firstIndex(where: { $0.id == event.id }) else { return }
        upcomingSessions[index].isComplete = true
        showToast("Session marked complete.")
    }

    func updateAttendance(for athleteName: String, in event: CalendarEvent, status: AttendanceStatus) {
        guard let eventIndex = upcomingSessions.firstIndex(where: { $0.id == event.id }) else { return }

        if let attendanceIndex = upcomingSessions[eventIndex].attendance.firstIndex(where: { $0.athleteName == athleteName }) {
            upcomingSessions[eventIndex].attendance[attendanceIndex].status = status
        } else {
            upcomingSessions[eventIndex].attendance.append(
                TeamMemberAttendance(athleteName: athleteName, status: status, note: "Updated from session card")
            )
        }

        if let groupID = upcomingSessions[eventIndex].groupID,
           let groupIndex = teamGroups.firstIndex(where: { $0.id == groupID }),
           let groupAttendanceIndex = teamGroups[groupIndex].attendance.firstIndex(where: { $0.athleteName == athleteName }) {
            teamGroups[groupIndex].attendance[groupAttendanceIndex].status = status
        }

        showToast("\(athleteName) marked \(status.rawValue).")
    }

    func sendTemplateMessage(_ template: MessageTemplate) {
        guard let selectedThreadID,
              let threadIndex = messageThreads.firstIndex(where: { $0.id == selectedThreadID })
        else { return }

        let message = ThreadMessage(sender: .coach, senderName: coachProfile.name, text: template.body, timestamp: "Now")
        messageThreads[threadIndex].messages.append(message)
        messageThreads[threadIndex].preview = template.body
        messageThreads[threadIndex].isUnread = false
        pendingCoachOutreachContext = nil
        showToast("Template sent.")
    }

    func queueBroadcast() {
        showToast("Broadcast message queued.")
    }

    func advanceLead(_ lead: LeadRecord) {
        guard let index = leadRecords.firstIndex(where: { $0.id == lead.id }) else { return }
        let statuses = LeadStatus.allCases
        guard let currentIndex = statuses.firstIndex(of: leadRecords[index].status) else { return }
        leadRecords[index].status = statuses[(currentIndex + 1) % statuses.count]
        showToast("\(leadRecords[index].name) moved to \(leadRecords[index].status.rawValue).")
    }

    func updateCoachNotes(for athleteID: UUID, text: String) {
        guard let index = coachClients.firstIndex(where: { $0.id == athleteID }) else { return }
        coachClients[index].coachNotes = text
        showToast("Coach notes saved.")
    }

    func updateAttendance(for athleteName: String, in group: TeamGroup, status: AttendanceStatus) {
        guard let groupIndex = teamGroups.firstIndex(where: { $0.id == group.id }),
              let athleteIndex = teamGroups[groupIndex].attendance.firstIndex(where: { $0.athleteName == athleteName })
        else { return }

        teamGroups[groupIndex].attendance[athleteIndex].status = status
        showToast("\(athleteName) marked \(status.rawValue).")
    }

    func sendGroupAnnouncement(for group: TeamGroup) {
        selectedGroupID = group.id
        showToast("Group announcement sent.")
    }

    private func setCurrentWorkout(named name: String) {
        guard let template = workoutTemplates.first(where: { $0.name == name }) else { return }
        currentWorkoutID = template.id
        isWorkoutSessionActive = false
        hasStartedWorkoutFlow = false
        hasCompletedWorkoutFlow = false
        activeWorkoutExerciseIndex = 0
        completedWorkoutSets = [:]
    }

    private func updateCurrentWorkout(_ update: (inout WorkoutTemplate) -> Void) {
        guard let index = workoutTemplates.firstIndex(where: { $0.id == currentWorkoutID }) else { return }
        update(&workoutTemplates[index])
    }

    private func markTaskCompleted(named title: String) {
        if let index = todayTasks.firstIndex(where: { $0.title == title }) {
            todayTasks[index].isCompleted = true
        }
    }

    private func updateXP(for amount: Int, add: Bool) {
        if add {
            clientProfile.level.currentXP += amount
            // Roll surplus XP into real level-ups — the bar used to clamp at
            // the target, so "Level 2" was a promise that never arrived.
            while clientProfile.level.currentXP >= clientProfile.level.targetXP {
                clientProfile.level.currentXP -= clientProfile.level.targetXP
                let nextLevel = (levelNumber(from: clientProfile.level.currentTitle) ?? 1) + 1
                clientProfile.level.currentTitle = "Level \(nextLevel)"
                clientProfile.level.nextTitle = "Level \(nextLevel + 1)"
                clientProfile.level.targetXP += 50
                showCelebration(title: "Level \(nextLevel)", detail: "Keep stacking the work.", symbol: "arrow.up.circle.fill")
            }
            Haptics.success()
        } else {
            clientProfile.level.currentXP = max(clientProfile.level.currentXP - amount, 0)
        }
        persistLocalProfile()
    }

    private func levelNumber(from title: String) -> Int? {
        Int(title.components(separatedBy: CharacterSet.decimalDigits.inverted).first { !$0.isEmpty } ?? "")
    }

    /// Quick Tools shows the user's own training rules, derived from what they
    /// actually told us — never the demo athlete's seeded list.
    private func rebuildPersonalRules() {
        let injuries = clientProfile.limitations.trimmingCharacters(in: .whitespacesAndNewlines)
        personalRules = injuries.isEmpty ? [] : [
            PersonalRule(title: "Injury & limits note", detail: injuries)
        ]
    }

    private func targetSetCount(for exercise: WorkoutExercise) -> Int {
        // First integer anywhere in the string, so "Superset x3" parses as 3
        // (not 1) even though every seeded template leads with the digit.
        let firstNumber = exercise.sets
            .components(separatedBy: CharacterSet.decimalDigits.inverted)
            .first { !$0.isEmpty }
        return Int(firstNumber ?? "") ?? 1
    }

    private func addAthleteActivityPost(
        title: String,
        detail: String,
        tags: [String],
        comments: [NetworkComment] = [],
        reactions: Int = 0
    ) {
        communityPosts.insert(
            ProgressPost(
                author: clientProfile.name,
                avatar: "🔥",
                role: .client,
                headline: "\(clientProfile.sportMode.rawValue) athlete focused on \(clientProfile.goal.lowercased())",
                rank: clientProfile.networkRank,
                timeAgo: "Now",
                title: title,
                detail: detail,
                tags: tags,
                reactions: reactions,
                comments: comments.count,
                commentHighlights: comments
            ),
            at: 0
        )
    }

    private func coachHighlightComment(text: String) -> NetworkComment {
        NetworkComment(
            author: clientProfile.coachName,
            avatar: "🧠",
            role: .coach,
            headline: coachProfile.headline,
            rank: coachProfile.networkRank,
            text: text,
            likes: 0
        )
    }

    private func coachDraftMessage(for shortcut: CoachOutreachShortcut, athlete: CoachClient) -> String {
        let logs = workoutLogs(for: athlete.id)
        let latestLogTitle = logs.first?.workoutTitle ?? athlete.currentProgram
        let partnerInsight = partnerTrainingInsight(for: athlete.id)

        switch shortcut {
        case .praise:
            return "Nice work on \(latestLogTitle). That kind of follow-through is exactly what keeps your progress moving. Keep the next session just as clean."
        case .missedSession:
            return "No stress about the missed session. Let’s reset with one smaller win today so the week doesn’t drift. If timing is tight, we can keep it short and still count it."
        case .partner:
            let partnerLine = partnerInsight.lastPartnerName.map { "with \($0)" } ?? "with a training partner"
            return "Partner sessions look like a good adherence lever for you right now. Let’s get one on the calendar \(partnerLine) this week and use it to keep momentum steady."
        case .recovery:
            return "Today is a recovery-minded day. Keep the work honest, lighter, and easy to finish so you are ready for the next real push instead of forcing extra fatigue."
        }
    }

    private func coachOutreachKind(for shortcut: CoachOutreachShortcut) -> CoachOutreachKind {
        switch shortcut {
        case .praise:
            return .praise
        case .missedSession:
            return .missedSessionNudge
        case .partner:
            return .partnerPrompt
        case .recovery:
            return .recoveryReminder
        }
    }

    private func communityFeedScore(for post: ProgressPost, perspective: AppRole) -> Double {
        let ageHours = max(Date().timeIntervalSince(post.createdAt) / 3600, 0)
        let lowercasedTags = post.tags.map { $0.lowercased() }
        let lowercasedTitle = post.title.lowercased()

        var score = 0.0

        switch ageHours {
        case ..<6:
            score += 90
        case ..<24:
            score += 72
        case ..<72:
            score += 48
        case ..<168:
            score += 24
        default:
            score += 8
        }

        func containsTag(_ text: String) -> Bool {
            lowercasedTags.contains { $0.contains(text) }
        }

        if containsTag("partner session") || lowercasedTitle.contains("partner session") {
            score += 80
        }
        if containsTag("coach praise") {
            score += 68
        }
        if containsTag("coach assignment") || lowercasedTitle.contains("assignment complete") {
            score += 72
        }
        if containsTag("workout complete") || lowercasedTitle.contains("workout complete") {
            score += 58
        }
        if containsTag("recovery win") || lowercasedTitle.contains("recovery day") {
            score += 52
        }
        if containsTag("streak save") || lowercasedTitle.contains("momentum protected") {
            score += 48
        }
        if containsTag("minimum win") {
            score += 40
        }
        if containsTag("coach support") || containsTag("coach log") {
            score += 38
        }
        if containsTag("ai review") || containsTag("ai logged") {
            score += 30
        }
        if containsTag("training plan") {
            score += 24
        }
        if containsTag("coach post") || containsTag("progress update") {
            score += 8
        }

        if perspective == .client {
            if post.role == .coach { score += 16 }
            if containsTag(selectedSportMode.shortTitle.lowercased()) || post.headline.lowercased().contains(selectedSportMode.rawValue.lowercased()) {
                score += 18
            }
        } else {
            if post.role == .client { score += 16 }
            if let selectedCoachClient {
                if post.author == selectedCoachClient.name { score += 22 }
                if containsTag(selectedCoachClient.sport.shortTitle.lowercased()) || post.headline.lowercased().contains(selectedCoachClient.sport.rawValue.lowercased()) {
                    score += 14
                }
            }
        }

        if post.commentHighlights.contains(where: { $0.role == .coach }) {
            score += 10
        }

        score += min(Double(post.comments) * 2.0, 14)
        score += min(Double(post.reactions) * 0.5, 12)

        return score
    }

    private func addCoachTrainingActivityPost(
        title: String,
        detail: String,
        tags: [String],
        comments: [NetworkComment] = [],
        reactions: Int = 0
    ) {
        communityPosts.insert(
            ProgressPost(
                author: coachProfile.name,
                avatar: "🧠",
                role: .coach,
                headline: coachProfile.headline,
                rank: coachProfile.networkRank,
                timeAgo: "Now",
                title: title,
                detail: detail,
                tags: tags,
                reactions: reactions,
                comments: comments.count,
                commentHighlights: comments
            ),
            at: 0
        )
    }

    private func queuePartnerSessionPostDraft(partner: WorkoutPartner, plan: PartnerWorkoutPlan) {
        pendingPartnerSessionPost = PartnerSessionPostDraft(
            workoutTitle: currentWorkout.name,
            sport: currentWorkout.sport,
            partnerName: partner.name,
            partnerAvatar: communityAvatar(for: partner.sport),
            partnerSport: partner.sport,
            mode: selectedPartnerWorkoutMode,
            durationMinutes: currentWorkout.durationMinutes,
            xpBonus: plan.xpBonus,
            partnerStreak: partner.streak,
            miniChallenge: plan.miniChallenge,
            detail: "Finished \(currentWorkout.name) with \(partner.name) in \(selectedPartnerWorkoutMode.rawValue.lowercased()) mode and closed the loop together.",
            tags: [selectedSportMode.shortTitle, "Partner Session", selectedPartnerWorkoutMode.rawValue]
        )
    }

    private func publishPartnerSessionPost(_ draft: PartnerSessionPostDraft) {
        communityPosts.insert(
            ProgressPost(
                author: clientProfile.name,
                avatar: "🔥",
                role: .client,
                headline: "\(clientProfile.sportMode.rawValue) athlete focused on \(clientProfile.goal.lowercased())",
                rank: clientProfile.networkRank,
                timeAgo: "Now",
                title: "Partner session complete",
                detail: draft.detail,
                tags: draft.tags,
                reactions: 18,
                comments: 1,
                commentHighlights: [
                    NetworkComment(
                        author: draft.partnerName,
                        avatar: draft.partnerAvatar,
                        role: .client,
                        headline: draft.partnerSport == draft.sport ? "\(draft.partnerSport.rawValue) Morphe partner session" : "\(draft.partnerSport.rawValue) partner crossover",
                        rank: "\(draft.partnerStreak)-day streak",
                        text: "That was clean work. Same session again soon?",
                        likes: 3
                    )
                ]
            ),
            at: 0
        )
    }

    private func applyPrimarySport(_ sport: SportFocus) {
        selectedSportMode = sport
        clientProfile.sportMode = sport
        clientProfile.welcomeMessage = motivationalGreeting(for: sport)
        clientProfile.aiTodayInsight = todayInsight(for: sport)
        // NEVER re-seed the fabricated demo sport metrics ("Mile time 6:08",
        // "Up 12%") for a real user — there is no real data source for them
        // yet, and an empty list hides the card honestly.
        if !hasCompletedOnboarding {
            sportMetrics = MorpheDemoContent.sportMetrics(for: sport)
        }
        profileShowcase.banner = bannerProfile(for: sport)
        profileShowcase.bio = profileBio(for: sport, trainingStyles: clientProfile.selectedTrainingStyles, goals: clientProfile.selectedGoals)
    }

    private func moveToFront<Value: Equatable>(_ value: Value, in selections: inout [Value]) {
        selections.removeAll { $0 == value }
        selections.insert(value, at: 0)
    }

    private enum ToggleSelectionResult {
        case added
        case removed
        case blockedMinimum
        case blockedMaximum
    }

    private func toggleSelection<Value: Equatable>(_ value: Value, in selections: inout [Value]) -> ToggleSelectionResult {
        if let index = selections.firstIndex(of: value) {
            guard selections.count > 1 else { return .blockedMinimum }
            selections.remove(at: index)
            return .removed
        }

        guard selections.count < personalizationSelectionLimit else { return .blockedMaximum }
        selections.append(value)
        return .added
    }

    private func defaultGoal(for sport: SportFocus) -> String {
        switch sport {
        case .boxing:
            return "Improve conditioning and body composition"
        case .soccer:
            return "Improve speed and match readiness"
        case .strength:
            return "Get stronger"
        case .running:
            return "Prepare for 10K"
        default:
            return "Build consistency"
        }
    }

    private func athleteAgentReply(to prompt: String) -> String {
        let lowercasedPrompt = prompt.lowercased()
        let primaryExercise = activeWorkoutExercise?.name ?? currentWorkout.exercises.first?.name ?? "your first movement"
        let firstWin = recentWins.first ?? "You kept showing up when the plan got busy."

        switch selectedClientTab {
        case .today:
            if lowercasedPrompt.contains("adjust") || lowercasedPrompt.contains("plan") || lowercasedPrompt.contains("smaller win") {
                let fallback = selectedPlanBReason?.rawValue ?? "low readiness"
                return "Today I'm looking at a readiness score of \(recovery.score) (\(recovery.status.rawValue)) and your plan for \(currentWorkout.name). Because \(fallback.lowercased()) is part of the picture, the clean move is to keep one main win, shorten the session, and protect momentum instead of chasing a perfect day."
            }

            if lowercasedPrompt.contains("readiness") || lowercasedPrompt.contains("recover") {
                return "Your readiness is \(recovery.score), which reads as \(recovery.status.rawValue). The biggest driver is \(recovery.reason.lowercased()). Treat today like a quality day, not a max-effort day."
            }

            if lowercasedPrompt.contains("week") || lowercasedPrompt.contains("summary") {
                return "This week looks steady. Your Morphe score is \(clientProfile.health.score), your streak is \(clientProfile.level.streak) days, and the best proof of progress is simple: \(firstWin)"
            }
        case .train:
            if lowercasedPrompt.contains("explain") || lowercasedPrompt.contains("exercise") || lowercasedPrompt.contains("form") {
                return "Right now the focus is \(primaryExercise). Keep the setup simple, move with control, and stop a rep early if form starts to drift. If you want, I can also help you swap it for a friendlier version."
            }

            if lowercasedPrompt.contains("swap") || lowercasedPrompt.contains("alternative") || lowercasedPrompt.contains("replace") {
                let alternative = currentWorkout.exercises.first(where: { $0.name == primaryExercise })
                    .flatMap { exercise in
                        exerciseDatabase.first(where: { $0.id == exercise.exerciseLibraryID })?.alternatives.first
                    } ?? "a simpler bodyweight version"
                return "A good swap for \(primaryExercise) today is \(alternative). It keeps the intent of the session without forcing the exact same setup."
            }

            if lowercasedPrompt.contains("pain") || lowercasedPrompt.contains("safe") {
                let saferOption = MorpheDemoContent.painAlternative(area: painArea, triggerExercise: painTriggerExercise)
                return "If \(painArea.lowercased()) discomfort shows up during \(painTriggerExercise), switch to \(saferOption.0). The goal is to keep the pattern safe, tell your coach, and move forward without forcing pain."
            }

            if lowercasedPrompt.contains("hard") || lowercasedPrompt.contains("rpe") || lowercasedPrompt.contains("feel") {
                return "This session should feel like focused work, not survival. Aim for a steady effort where reps stay clean and you could still explain what you’re doing out loud."
            }
        case .community:
            if lowercasedPrompt.contains("reply") || lowercasedPrompt.contains("coach") || lowercasedPrompt.contains("message") {
                return "Keep the message short and useful: say what you completed, what felt hard, and the one adjustment you want help with. That gets you better support faster."
            }

            if lowercasedPrompt.contains("post") || lowercasedPrompt.contains("share") {
                return "A strong network post here is simple: what you finished, what you learned, and one next step. Training updates land better than motivational essays."
            }
        case .hub:
            if lowercasedPrompt.contains("score") || lowercasedPrompt.contains("trend") || lowercasedPrompt.contains("report") {
                return "Your current Morphe score is \(clientProfile.health.score), and the trend is moving in the right direction because consistency is holding. The next improvement is less about pushing harder and more about keeping recovery and logging tighter."
            }

            if lowercasedPrompt.contains("pattern") || lowercasedPrompt.contains("fix") {
                let lead = currentPatternInsight.map { "\($0.summary) " } ?? ""
                return "\(lead)Start by solving the smallest friction point first, then let the rest of the week stay lighter and more repeatable."
            }
        case .more:
            if lowercasedPrompt.contains("nutrition") || lowercasedPrompt.contains("eat") || lowercasedPrompt.contains("meal") {
                return "Keep nutrition simple today: hit protein, drink water, and make dinner the easiest meal to win. You don’t need perfect tracking to make progress."
            }

            if lowercasedPrompt.contains("learn") || lowercasedPrompt.contains("study") || lowercasedPrompt.contains("quiz") {
                return "The best learning move right now is to pair one lesson with one action. Pick a form tip or recovery basic, then use it in your next session today."
            }
        }

        return MorpheDemoContent.aiCoachReply(to: prompt, tone: profileShowcase.coachingTone)
    }

    private func coachAgentReply(to prompt: String) -> String {
        let lowercasedPrompt = prompt.lowercased()
        let athleteName = selectedCoachClient?.name ?? coachClients.first?.name ?? "your athlete"
        let selectedProgram = selectedProgramTemplate?.name ?? "the current build"
        let selectedThreadName = selectedThread?.participant ?? athleteName

        switch selectedCoachTab {
        case .dashboard:
            if lowercasedPrompt.contains("attention") || lowercasedPrompt.contains("priority") {
                return "\(coachOverview.insight.summary) Start with the highest-friction athlete first, remove one blocker, and keep the next step easy to complete today."
            }
        case .athletes:
            if lowercasedPrompt.contains("summary") || lowercasedPrompt.contains("athlete") || lowercasedPrompt.contains("readiness") {
                let recoverySummary = selectedCoachClient?.recoveryScore.reason ?? "consistency is holding but readiness wants moderation"
                return "\(athleteName) is trending \(selectedCoachClient?.statusText.lowercased() ?? "steady"). Recovery is \(selectedCoachClient?.recoveryScore.score ?? 0) and the biggest context note is \(recoverySummary.lowercased())."
            }
        case .programs:
            if selectedCoachBuildSection == .library,
               lowercasedPrompt.contains("drill") || lowercasedPrompt.contains("warm-up") || lowercasedPrompt.contains("progression") {
                let drillName = drills.first(where: { $0.sport == (selectedCoachClient?.sport ?? .boxing) })?.name ?? drills.first?.name ?? "a simple technical drill"
                return "A strong library pull right now is \(drillName). Use it as a short primer so the athlete gets quality reps before fatigue shows up."
            }
            if lowercasedPrompt.contains("session") || lowercasedPrompt.contains("plan") || lowercasedPrompt.contains("lighter") {
                return "For \(selectedProgram), keep the structure clear: warm-up, one main focus, one support block, and a short cooldown. If readiness is low, cut volume before cutting quality."
            }
        case .network:
            if lowercasedPrompt.contains("post") || lowercasedPrompt.contains("comment") || lowercasedPrompt.contains("connect") {
                return "Keep the coach network practical. Share one lesson, one athlete win, or one cue that another coach could use today."
            }
        case .messages:
            if lowercasedPrompt.contains("reply") || lowercasedPrompt.contains("message") || lowercasedPrompt.contains("outreach") {
                return "For \(selectedThreadName), lead with the last known result, remove any guilt, and end with one very clear next step they can do today."
            }
        }

        if lowercasedPrompt.contains("summary") || lowercasedPrompt.contains("week") {
            return "This week \(athleteName) looks steady overall. The biggest leverage move is better adherence to the core plan and one lighter recovery touchpoint before the next hard session."
        }

        if lowercasedPrompt.contains("outreach") || lowercasedPrompt.contains("message") {
            return "Try a short outreach note: acknowledge the last result, remove pressure, and give one clear next step they can complete today."
        }

        if lowercasedPrompt.contains("recovery") || lowercasedPrompt.contains("lighter") || lowercasedPrompt.contains("adjust") {
            return "I’d pull back the next session slightly: reduce total volume, keep technique crisp, and protect readiness instead of chasing fatigue."
        }

        return "Here’s the clean coaching read: simplify the next step, keep the message direct, and use the smallest action that still moves the athlete forward."
    }

    private func motivationalGreeting(for sport: SportFocus) -> String {
        switch sport {
        case .boxing:
            return "You do not need to train like a champion today. You just need to build the habits that create one."
        case .soccer:
            return "Today's session builds match fitness one small win at a time."
        case .strength:
            return "Progressive overload starts with consistency. Show up, track it, improve next time."
        default:
            return "Build momentum, not perfection."
        }
    }

    private func networkHandle(for name: String) -> String {
        name.lowercased()
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: ".", with: "")
    }

    private func bannerProfile(for sport: SportFocus) -> BannerProfile {
        switch sport {
        case .boxing:
            return BannerProfile(preset: .boxing, title: "Fight Camp", subtitle: "Consistency Era")
        case .soccer:
            return BannerProfile(preset: .soccer, title: "Road to Match Fit", subtitle: "Speed Phase")
        case .basketball:
            return BannerProfile(preset: .basketball, title: "Jump Season", subtitle: "Explosive Focus")
        case .running:
            return BannerProfile(preset: .transformation, title: "Road to 10K", subtitle: "Engine Building")
        case .strength:
            return BannerProfile(preset: .strength, title: "Strength Phase", subtitle: "Builder Mode")
        default:
            return BannerProfile(preset: .minimalPremium, title: "Build Momentum", subtitle: "Consistency Era")
        }
    }

    private func bannerTitle(for preset: BannerPreset) -> String {
        switch preset {
        case .boxing: return "Fight Camp"
        case .soccer: return "Road to Match Fit"
        case .basketball: return "Comeback Season"
        case .running: return "Road to Race Day"
        case .strength: return "Strength Phase"
        case .fatLoss: return "Momentum Mode"
        case .transformation: return "Transformation Era"
        case .recovery: return "Recovery First"
        case .team: return "Team Mode"
        case .minimalPremium: return "Build Momentum"
        }
    }

    private func todayInsight(for sport: SportFocus) -> AIInsight {
        AIInsight(
            title: "Today's tip",
            summary: motivationalGreeting(for: sport),
            risk: recovery.status == .ready ? .low : .medium,
            recommendation: "Keep the session realistic, finish one useful win, and log how it felt.",
            suggestedAction: "Start today's \(sport.shortTitle.lowercased()) plan"
        )
    }

    private func profileBio(for sport: SportFocus, trainingStyles: [TrainingStyleOption], goals: [String]) -> String {
        let trainingLine = trainingStyles.prefix(2).map { $0.rawValue.lowercased() }.joined(separator: " + ")
        let goalLine = goals.prefix(2).joined(separator: " + ")
        let middle = [trainingLine, goalLine.lowercased()]
            .filter { !$0.isEmpty }
            .joined(separator: ", ")
        return "\(sport.rawValue)\(middle.isEmpty ? "" : ", \(middle)"), and small wins that stack."
    }

    private func athleteReply(for participant: String, prompt: String) -> (sender: ChatSender, name: String, text: String) {
        let lowercasedPrompt = prompt.lowercased()

        switch participant {
        case "Morphe AI":
            return (
                .ai,
                "Morphe AI",
                MorpheDemoContent.aiCoachReply(to: prompt, tone: profileShowcase.coachingTone)
            )
        case clientProfile.coachName:
            return (
                .coach,
                clientProfile.coachName,
                lowercasedPrompt.contains("pain")
                    ? "Thanks for flagging that. Keep the next round lighter, skip anything sharp, and send me an update after the warm-up."
                    : "That works. Keep the session clean, stay honest with the effort, and message me after you're done."
            )
        case "Jay":
            return (.client, "Jay", "Perfect. I’ll match your pace and keep the last round for clean volume.")
        case "Maya":
            return (.client, "Maya", "Deal. Recovery first, then we can push the next session a little harder.")
        case "Chris":
            return (.client, "Chris", "Facts. I’m keeping today simple and saving the bounce for game week.")
        default:
            return (.client, participant, "Sounds good. Let’s keep the momentum moving.")
        }
    }

    private func coachFollowUpRecommendation(for athleteID: UUID) -> CoachFollowUpRecommendation {
        let logs = workoutLogs(for: athleteID)
        let athleteName = athleteName(for: athleteID)
        let calendar = Calendar.current
        let thisWeekLogs = logs.filter { calendar.isDate($0.completedAt, equalTo: .now, toGranularity: .weekOfYear) }
        let aiPendingCount = logs.filter { $0.verificationStatus == .aiPendingReview }.count
        let buddyThisWeek = thisWeekLogs.filter { $0.source == .partnerShared }.count
        let athleteThisWeek = thisWeekLogs.filter { $0.source == .athleteManual }.count
        let coachThisWeek = thisWeekLogs.filter { $0.source == .coachManual }.count
        let latestLog = logs.first
        let partnerInsight = partnerTrainingInsight(for: athleteID)
        let athlete = coachClients.first(where: { $0.id == athleteID })
        let readinessStatus = athlete?.recoveryScore.status
        let painIntervention = coachInterventions.first {
            $0.athleteID == athleteID
                && ($0.reason.localizedCaseInsensitiveContains("pain")
                    || $0.reason.localizedCaseInsensitiveContains("recovery"))
                && $0.status != "Handled"
        }
        let openIntervention = coachInterventions.first { $0.athleteID == athleteID && $0.status != "Handled" }
        let latestLogIsRecent = latestLog.map { calendar.dateComponents([.day], from: $0.completedAt, to: .now).day ?? 99 <= 3 } ?? false
        let bestRestartOutreach = bestCoachOutreachEffectiveness(
            for: athleteID,
            among: [.missedSessionNudge, .partnerPrompt, .generalCheckIn]
        )
        let painCheckEffectiveness = coachOutreachEffectiveness(for: athleteID, kind: .painCheckIn)
        let recoveryEffectiveness = coachOutreachEffectiveness(for: athleteID, kind: .recoveryReminder)
        let praiseEffectiveness = coachOutreachEffectiveness(for: athleteID, kind: .praise)

        if aiPendingCount > 0 {
            return CoachFollowUpRecommendation(
                athleteID: athleteID,
                athleteName: athleteName,
                title: "Review AI workout imports",
                detail: aiPendingCount == 1
                    ? "\(athleteName) has 1 AI-parsed log waiting for coach review."
                    : "\(athleteName) has \(aiPendingCount) AI-parsed logs waiting for coach review.",
                actionLabel: "Show AI Logs",
                type: .reviewAI,
                priority: 100
            )
        }

        if readinessStatus == .recoveryRecommended || readinessStatus == .takeItEasy {
            return CoachFollowUpRecommendation(
                athleteID: athleteID,
                athleteName: athleteName,
                title: "Queue a lighter training day",
                detail: [ "\(athleteName) is trending toward a lower-readiness day. A recovery-focused session is the cleanest next move.",
                          recoveryEffectiveness?.insightLine ]
                    .compactMap { $0 }
                    .joined(separator: " "),
                actionLabel: "Load Recovery Plan",
                type: .assignRecovery,
                priority: 95
            )
        }

        if let painIntervention {
            return CoachFollowUpRecommendation(
                athleteID: athleteID,
                athleteName: athleteName,
                title: "Ask for a pain update",
                detail: [ "\(painIntervention.reason) A fast pain check-in is the cleanest way to decide whether to swap, lighten, or keep moving.",
                          painCheckEffectiveness?.insightLine ]
                    .compactMap { $0 }
                    .joined(separator: " "),
                actionLabel: "Draft Pain Check-In",
                type: .askPainUpdate,
                priority: 93
            )
        }

        if athleteThisWeek == 0 && coachThisWeek == 0 {
            if let bestRestartOutreach {
                switch bestRestartOutreach.kind {
                case .partnerPrompt:
                    return CoachFollowUpRecommendation(
                        athleteID: athleteID,
                        athleteName: athleteName,
                        title: "Use the accountability lever that lands",
                        detail: "There are no logged sessions yet this week. \(bestRestartOutreach.insightLine)",
                        actionLabel: "Draft Partner Prompt",
                        type: .partnerPrompt,
                        priority: 90
                    )
                case .generalCheckIn:
                    return CoachFollowUpRecommendation(
                        athleteID: athleteID,
                        athleteName: athleteName,
                        title: "Open the fastest line back in",
                        detail: "There are no logged sessions yet this week. \(bestRestartOutreach.insightLine)",
                        actionLabel: "Open Message Thread",
                        type: .messageAthlete,
                        priority: 90
                    )
                default:
                    break
                }
            }

            return CoachFollowUpRecommendation(
                athleteID: athleteID,
                athleteName: athleteName,
                title: "Nudge the week back into motion",
                detail: [ "There are no logged sessions yet this week. A quick missed-session nudge is the fastest way to restart momentum.",
                          coachOutreachEffectiveness(for: athleteID, kind: .missedSessionNudge)?.insightLine ]
                    .compactMap { $0 }
                    .joined(separator: " "),
                actionLabel: "Draft Nudge",
                type: .missedSessionNudge,
                priority: 90
            )
        }

        if athleteThisWeek == 0 && coachThisWeek > 0 {
            if let bestRestartOutreach, bestRestartOutreach.kind == .partnerPrompt {
                return CoachFollowUpRecommendation(
                    athleteID: athleteID,
                    athleteName: athleteName,
                    title: "Restart athlete ownership with a partner prompt",
                    detail: "\(athleteName) has coach-entered sessions this week, but no athlete-submitted logs yet. \(bestRestartOutreach.insightLine)",
                    actionLabel: "Draft Partner Prompt",
                    type: .partnerPrompt,
                    priority: 86
                )
            }

            return CoachFollowUpRecommendation(
                athleteID: athleteID,
                athleteName: athleteName,
                title: "Prompt athlete self-logging",
                detail: [ "\(athleteName) has coach-entered sessions this week, but no athlete-submitted logs yet.",
                          coachOutreachEffectiveness(for: athleteID, kind: .generalCheckIn)?.insightLine ]
                    .compactMap { $0 }
                    .joined(separator: " "),
                actionLabel: "Open Message Thread",
                type: .messageAthlete,
                priority: 86
            )
        }

        if partnerInsight.buddyShareLast30Days < 20,
           (athlete?.complianceScore ?? 100) < 85,
           openIntervention != nil || thisWeekLogs.isEmpty {
            return CoachFollowUpRecommendation(
                athleteID: athleteID,
                athleteName: athleteName,
                title: "Push partner accountability",
                detail: [ "Buddy sessions are not showing up much lately, and adherence could use an easier accountability lever.",
                          coachOutreachEffectiveness(for: athleteID, kind: .partnerPrompt)?.insightLine ]
                    .compactMap { $0 }
                    .joined(separator: " "),
                actionLabel: "Draft Partner Prompt",
                type: .partnerPrompt,
                priority: 82
            )
        }

        if buddyThisWeek > 0 && buddyThisWeek >= max(athleteThisWeek, 1) {
            return CoachFollowUpRecommendation(
                athleteID: athleteID,
                athleteName: athleteName,
                title: "Lean into partner accountability",
                detail: "Buddy sessions are carrying more of the adherence signal this week. Review those logs before changing the plan.",
                actionLabel: "View Buddy Logs",
                type: .reviewBuddy,
                priority: 78
            )
        }

        if latestLogIsRecent {
            return CoachFollowUpRecommendation(
                athleteID: athleteID,
                athleteName: athleteName,
                title: "Reinforce the latest win",
                detail: [
                    latestLog.map {
                        "\(athleteName) just logged \($0.workoutTitle). Use that momentum while the session still feels recent."
                    } ?? "Use the most recent workout as a conversation opener while momentum is still warm.",
                    praiseEffectiveness?.insightLine
                ]
                .compactMap { $0 }
                .joined(separator: " "),
                actionLabel: "Praise Publicly",
                type: .praisePublicly,
                priority: 70
            )
        }

        return CoachFollowUpRecommendation(
            athleteID: athleteID,
            athleteName: athleteName,
            title: "Keep the line open",
            detail: "A short coach touchpoint is the easiest way to keep \(athleteName) moving without changing the whole plan.",
            actionLabel: "Message Athlete",
            type: .messageAthlete,
            priority: 60
        )
    }

    func coachDraftMessage(for action: CoachNextActionType, athleteID: UUID) -> String? {
        guard let athlete = coachClients.first(where: { $0.id == athleteID }) else { return nil }

        switch action {
        case .missedSessionNudge:
            return coachDraftMessage(for: .missedSession, athlete: athlete)
        case .partnerPrompt:
            return coachDraftMessage(for: .partner, athlete: athlete)
        case .askPainUpdate:
            return "Quick pain check: what did the last session feel like, what movement lit it up, and where is it sitting now on a 1-10?"
        case .messageAthlete:
            return "Quick check-in: how did today land, and what is the one thing most likely to get in the way of the next session?"
        case .assignRecovery, .reviewAI, .reviewBuddy, .praisePublicly:
            return nil
        }
    }

    func coachOutreachInsight(for athleteID: UUID) -> String? {
        bestCoachOutreachEffectiveness(
            for: athleteID,
            among: CoachOutreachKind.allCases
        )?.insightLine
    }

    private func buildAthletePatternInsights() -> [AthletePatternInsight] {
        let behavior = goodForTodayBehaviorSnapshot()
        let partnerInsight = currentAthletePartnerTrainingInsight
        let outreachEffectiveness = bestCoachOutreachEffectiveness(
            for: clientProfile.id,
            among: CoachOutreachKind.allCases
        )
        let needsRecovery = recovery.status == .recoveryRecommended
            || recovery.status == .takeItEasy
            || currentPlanAdjustment.reasons.contains(.lowRecovery)
            || currentPlanAdjustment.reasons.contains(.painReported)
        let needsFallback = minimumWinModeEnabled
            || selectedConfidence == .notConfident
            || currentPlanAdjustment.reasons.contains(.notEnoughTime)

        var insights: [AthletePatternInsight] = []

        func appendInsight(
            title: String,
            detail: String,
            badge: String,
            systemImage: String
        ) {
            guard !insights.contains(where: { $0.title == title }) else { return }
            insights.append(
                AthletePatternInsight(
                    title: title,
                    detail: detail,
                    badge: badge,
                    systemImage: systemImage
                )
            )
        }

        if needsRecovery && behavior.recoveryDaysLeadToMomentum {
            appendInsight(
                title: "Reset days work for you",
                detail: "When you let a recovery-minded day do its job, you usually come back and finish the next real session more cleanly.",
                badge: "Recovery works",
                systemImage: "heart.text.square.fill"
            )
        }

        if needsFallback && behavior.coachPlanWorksAfterFallback {
            appendInsight(
                title: "Short reset days set up the plan",
                detail: "When the week gets crowded, a smaller fallback session is often what gets you back into the main coach-led work instead of drifting.",
                badge: "Rebound pattern",
                systemImage: "arrow.trianglehead.clockwise"
            )
        } else if needsFallback && behavior.fallbackDaysSaveMomentum {
            appendInsight(
                title: "Small wins keep you moving",
                detail: "You finish shorter fallback sessions more often than you skip them, and that usually keeps the week from slipping away.",
                badge: "Momentum saver",
                systemImage: "figure.walk.motion"
            )
        }

        if FeatureFlags.multiUserEnabled,
           behavior.buddyLiftIsReal || partnerInsight.buddyShareLast30Days >= 30 {
            appendInsight(
                title: "Buddy sessions help you follow through",
                detail: partnerInsight.lastPartnerName.map {
                    "Shared sessions with \($0) are doing real work for your consistency lately, especially when the week starts getting heavy."
                } ?? "Shared sessions are doing real work for your consistency lately, especially when the week starts getting heavy.",
                badge: "Partner proven",
                systemImage: "person.2.fill"
            )
        }

        if FeatureFlags.multiUserEnabled, let outreachEffectiveness {
            appendInsight(
                title: athleteFacingOutreachTitle(for: outreachEffectiveness.kind),
                detail: athleteFacingOutreachDetail(for: outreachEffectiveness),
                badge: "Coach support",
                systemImage: athleteFacingOutreachSymbol(for: outreachEffectiveness.kind)
            )
        }

        if behavior.reboundWindowIsOpen && behavior.currentPlanInsight.recentCompletionCount > 0 {
            appendInsight(
                title: "You rebound well after lighter days",
                detail: "Morphe is seeing a real pattern: once you take the pressure down for a day, you usually step back into a full session pretty quickly.",
                badge: "Bounce-back read",
                systemImage: "figure.run"
            )
        }

        if behavior.currentPlanInsight.recentCompletionCount >= 2 || behavior.coachLedSessionsAreLanding {
            appendInsight(
                title: "You do better when the plan stays simple",
                detail: "Your coach-backed sessions have been landing more reliably than random picks lately, which is a good sign that staying on the rails is working.",
                badge: "Plan lands",
                systemImage: "checkmark.circle.fill"
            )
        }

        if insights.isEmpty {
            appendInsight(
                title: "Your pattern is still taking shape",
                detail: "Every logged session teaches Morphe what actually works for you. A few more honest check-ins will sharpen the next recommendations fast.",
                badge: "Still learning",
                systemImage: "sparkles"
            )
        }

        return Array(insights.prefix(3))
    }

    private func communityAvatar(for sport: SportFocus) -> String {
        switch sport {
        case .boxing: return "🥊"
        case .soccer: return "⚽"
        case .basketball: return "🏀"
        case .running, .track: return "🏃"
        default: return "🔥"
        }
    }

    private func appendWorkoutLog(_ log: WorkoutLog) {
        workoutLogs.insert(log, at: 0)
        workoutLogs.sort { $0.completedAt > $1.completedAt }
        refreshWorkoutLogDerivedState(for: log.athleteID, latestLog: log)

        guard log.athleteID == clientProfile.id else { return }

        switch log.source {
        case .athleteManual:
            recentWins.insert("You logged \(log.workoutTitle) and kept the momentum honest.", at: 0)
        case .coachManual:
            notifications.insert(
                SmartNotificationItem(
                    type: "Coach workout log",
                    title: "Coach added a workout log",
                    message: "\(log.enteredByName) added \(log.workoutTitle) to your profile.",
                    priority: .medium,
                    action: "Open Progress"
                ),
                at: 0
            )
            recentWins.insert("\(log.enteredByName) added \(log.workoutTitle) to your training history.", at: 0)
            addAthleteActivityPost(
                title: "Coach logged a session",
                detail: "\(log.enteredByName) added \(log.workoutTitle) to your shared progress record.",
                tags: [log.sport.shortTitle, "Coach Support"]
            )
        case .aiPhotoParsed:
            notifications.insert(
                SmartNotificationItem(
                    type: "AI workout import",
                    title: "Workout parsed from photo",
                    message: "\(log.enteredByName) saved a parsed workout log to your profile.",
                    priority: .medium,
                    action: "Open Progress"
                ),
                at: 0
            )
            recentWins.insert("A workout photo was turned into a clean training log.", at: 0)
            addAthleteActivityPost(
                title: "Workout photo turned into a log",
                detail: "\(log.enteredByName) turned \(log.workoutTitle) into a clean progress entry.",
                tags: [log.sport.shortTitle, "AI Logged"]
            )
        case .partnerShared:
            notifications.insert(
                SmartNotificationItem(
                    type: "Partner session",
                    title: "Partner workout saved",
                    message: "\(log.enteredByName) completed \(log.workoutTitle) together.",
                    priority: .medium,
                    action: "Open Progress"
                ),
                at: 0
            )
            recentWins.insert("Partner session saved with \(selectedWorkoutPartner?.name ?? "your workout buddy").", at: 0)
        }
    }

    private func trackCoachOutreach(
        _ kind: CoachOutreachKind,
        athleteID: UUID,
        athleteName: String,
        sourceLabel: String
    ) {
        coachOutreachEvents.insert(
            CoachOutreachEvent(
                athleteID: athleteID,
                athleteName: athleteName,
                kind: kind,
                sentAt: .now,
                sourceLabel: sourceLabel
            ),
            at: 0
        )
        coachOutreachEvents.sort { $0.sentAt > $1.sentAt }
    }

    private func coachOutreachKind(for action: CoachNextActionType) -> CoachOutreachKind? {
        switch action {
        case .missedSessionNudge:
            return .missedSessionNudge
        case .partnerPrompt:
            return .partnerPrompt
        case .askPainUpdate:
            return .painCheckIn
        case .messageAthlete:
            return .generalCheckIn
        case .praisePublicly:
            return .praise
        case .assignRecovery, .reviewAI, .reviewBuddy:
            return nil
        }
    }

    private func coachOutreachEffectiveness(for athleteID: UUID, kind: CoachOutreachKind) -> CoachOutreachEffectiveness? {
        let events = coachOutreachEvents.filter { $0.athleteID == athleteID && $0.kind == kind }
        guard !events.isEmpty else { return nil }
        let logs = workoutLogs(for: athleteID)
        let followThroughCount = events.filter { event in
            didCoachOutreachLeadToWorkout(event, logs: logs)
        }.count
        return CoachOutreachEffectiveness(
            kind: kind,
            sentCount: events.count,
            followThroughCount: followThroughCount
        )
    }

    private func bestCoachOutreachEffectiveness(
        for athleteID: UUID,
        among kinds: [CoachOutreachKind],
        minimumSentCount: Int = 2
    ) -> CoachOutreachEffectiveness? {
        kinds
            .compactMap { coachOutreachEffectiveness(for: athleteID, kind: $0) }
            .filter { $0.sentCount >= minimumSentCount && $0.followThroughCount > 0 }
            .sorted { lhs, rhs in
                if lhs.successRate == rhs.successRate {
                    if lhs.followThroughCount == rhs.followThroughCount {
                        return lhs.sentCount > rhs.sentCount
                    }
                    return lhs.followThroughCount > rhs.followThroughCount
                }
                return lhs.successRate > rhs.successRate
            }
            .first
    }

    private func athleteFacingOutreachTitle(for kind: CoachOutreachKind) -> String {
        switch kind {
        case .praise:
            return "Recognition helps you stay engaged"
        case .missedSessionNudge:
            return "Coach nudges help you reset quickly"
        case .partnerPrompt:
            return "Partner prompts get you moving again"
        case .recoveryReminder:
            return "Recovery reminders help you stay on track"
        case .painCheckIn:
            return "Fast pain check-ins keep the week honest"
        case .generalCheckIn:
            return "Coach check-ins help the next session happen"
        }
    }

    private func athleteFacingOutreachDetail(for effectiveness: CoachOutreachEffectiveness) -> String {
        switch effectiveness.kind {
        case .praise:
            return "When your coach reinforces a good session, you usually log another workout soon after. That positive signal is doing real work for your consistency."
        case .missedSessionNudge:
            return "When the week starts to slip, a simple coach nudge tends to get you back into motion instead of letting the gap stretch."
        case .partnerPrompt:
            return "When your coach points you toward partner accountability, you are more likely to get the next session logged instead of postponing it."
        case .recoveryReminder:
            return "Recovery-minded reminders are helping you keep the week moving without turning lighter days into missed days."
        case .painCheckIn:
            return "Checking pain quickly instead of pushing through it tends to keep your training record alive and the next decision clearer."
        case .generalCheckIn:
            return "A simple coach check-in is often enough to turn intention into a real logged session for you."
        }
    }

    private func athleteFacingOutreachSymbol(for kind: CoachOutreachKind) -> String {
        switch kind {
        case .praise:
            return "hands.clap.fill"
        case .missedSessionNudge:
            return "message.badge.filled.fill"
        case .partnerPrompt:
            return "person.2.wave.2.fill"
        case .recoveryReminder:
            return "heart.text.square.fill"
        case .painCheckIn:
            return "cross.case.fill"
        case .generalCheckIn:
            return "bubble.left.and.bubble.right.fill"
        }
    }

    private func didCoachOutreachLeadToWorkout(_ event: CoachOutreachEvent, logs: [WorkoutLog], withinDays: Int = 3) -> Bool {
        guard let deadline = Calendar.current.date(byAdding: .day, value: withinDays, to: event.sentAt) else {
            return false
        }

        return logs.contains { log in
            log.completedAt > event.sentAt && log.completedAt <= deadline
        }
    }

    private static func seededCoachOutreachEvents(
        clients: [CoachClient],
        logs: [WorkoutLog]
    ) -> [CoachOutreachEvent] {
        let coachAthleteIDs = Set(clients.map(\.id))
        let athleteLogs = Dictionary(
            grouping: logs
                .filter { coachAthleteIDs.contains($0.athleteID) }
                .sorted { $0.completedAt < $1.completedAt },
            by: \.athleteID
        )
        let calendar = Calendar.current

        var events: [CoachOutreachEvent] = []

        for athlete in clients {
            let logs = athleteLogs[athlete.id] ?? []
            guard !logs.isEmpty else { continue }

            for log in logs.prefix(4) {
                let kind: CoachOutreachKind
                if log.source == .partnerShared {
                    kind = .partnerPrompt
                } else if log.workoutTitle.lowercased().contains("recovery") || log.notes.lowercased().contains("recovery") {
                    kind = .recoveryReminder
                } else {
                    kind = .missedSessionNudge
                }

                events.append(
                    CoachOutreachEvent(
                        athleteID: athlete.id,
                        athleteName: athlete.name,
                        kind: kind,
                        sentAt: calendar.date(byAdding: .hour, value: -30, to: log.completedAt) ?? log.completedAt,
                        sourceLabel: "Seeded Follow-Up"
                    )
                )
            }

            if let praiseTarget = logs.dropFirst().first {
                events.append(
                    CoachOutreachEvent(
                        athleteID: athlete.id,
                        athleteName: athlete.name,
                        kind: .praise,
                        sentAt: calendar.date(byAdding: .hour, value: -18, to: praiseTarget.completedAt) ?? praiseTarget.completedAt,
                        sourceLabel: "Seeded Praise"
                    )
                )
            }

            if let checkInTarget = logs.last {
                events.append(
                    CoachOutreachEvent(
                        athleteID: athlete.id,
                        athleteName: athlete.name,
                        kind: .generalCheckIn,
                        sentAt: calendar.date(byAdding: .hour, value: -20, to: checkInTarget.completedAt) ?? checkInTarget.completedAt,
                        sourceLabel: "Seeded Check-In"
                    )
                )
            }
        }

        return events.sorted { $0.sentAt > $1.sentAt }
    }

    private func refreshCurrentAthleteWorkoutHistory() {
        workoutHistory = workoutLogs(for: clientProfile.id).map {
            WorkoutHistoryEntry(
                title: $0.workoutTitle,
                completedOn: Self.workoutDateLabel(for: $0.completedAt),
                durationMinutes: $0.durationMinutes,
                result: "\($0.source.badgeTitle) • \($0.verificationStatus.rawValue)"
            )
        }
    }

    private func updatedWorkoutConsistencyFromCurrentLogs() -> [WeeklyWorkoutCount] {
        Self.rebuiltWorkoutConsistency(from: workoutLogs, athleteID: clientProfile.id)
    }

    private func exerciseLogs(from template: WorkoutTemplate?) -> [LoggedExercise] {
        guard let template else { return [] }
        return template.exercises.map {
            LoggedExercise(
                name: $0.name,
                sets: $0.sets,
                reps: $0.reps,
                weight: "As programmed",
                note: $0.formCue
            )
        }
    }

    private func makeLoggedExercisesFromCurrentWorkout() -> [LoggedExercise] {
        currentWorkout.exercises.map { exercise in
            let repsLogged = trackedSetReps[exercise.id, default: []]
            let weightsLogged = trackedSetWeights[exercise.id, default: []]
            let repSummary = repsLogged.isEmpty
                ? exercise.reps
                : repsLogged.map(String.init).joined(separator: ", ")
            let setSummary = repsLogged.isEmpty
                ? exercise.sets
                : "\(repsLogged.count) sets"
            // Real load: the top working weight the user entered, or Bodyweight.
            let topWeight = weightsLogged.max() ?? 0
            let weightSummary = topWeight > 0 ? weightUnit.format(topWeight) : "Bodyweight"
            let rpesLogged = trackedSetRPE[exercise.id, default: []]
            let ratedRPEs = rpesLogged.filter { $0 > 0 }
            return LoggedExercise(
                name: exercise.name,
                sets: setSummary,
                reps: repSummary,
                weight: weightSummary,
                note: exercise.formCue,
                rpe: ratedRPEs.isEmpty ? nil : ratedRPEs.map(String.init).joined(separator: ", "),
                // Keep the raw per-set arrays so strength-over-time can be
                // computed later; the strings above are display-only.
                repsPerSet: repsLogged.isEmpty ? nil : repsLogged,
                weightsPerSet: repsLogged.isEmpty ? nil : weightsLogged,
                rpePerSet: repsLogged.isEmpty ? nil : rpesLogged,
                weightUnit: repsLogged.isEmpty ? nil : weightUnit.rawValue
            )
        }
    }

    private func partnerWorkoutSessionNote() -> String {
        if let partner = selectedWorkoutPartner, partnerWorkoutEnabled {
            return "Completed with \(partner.name) in \(selectedPartnerWorkoutMode.rawValue.lowercased()) mode. \(selectedWorkoutFeedback?.rawValue ?? "Logged from the live workout flow.")"
        }
        return selectedWorkoutFeedback?.rawValue ?? "Logged from the live workout flow."
    }

    private func makeMirroredPartnerWorkoutLog(exercises: [LoggedExercise]) -> WorkoutLog? {
        guard partnerWorkoutEnabled,
              let partner = selectedWorkoutPartner,
              let linkedAthleteID = partner.linkedAthleteID
        else { return nil }

        let partnerName = coachClients.first(where: { $0.id == linkedAthleteID })?.name ?? partner.name

        return WorkoutLog(
            athleteID: linkedAthleteID,
            athleteName: partnerName,
            workoutTemplateID: currentWorkout.id,
            workoutTitle: currentWorkout.name,
            sport: currentWorkout.sport,
            completedAt: .now,
            durationMinutes: completedSessionMinutes ?? currentWorkout.durationMinutes,
            exercises: exercises,
            notes: "Shared session with \(clientProfile.name) in \(selectedPartnerWorkoutMode.rawValue.lowercased()) mode. Synced by Morphe partner workout.",
            source: .partnerShared,
            enteredByUserID: linkedAthleteID,
            enteredByRole: .client,
            enteredByName: "\(clientProfile.name) + \(partnerName)",
            verificationStatus: .athleteSubmitted
        )
    }

    static func workoutDateLabel(for date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            return "Today"
        }
        if calendar.isDateInYesterday(date) {
            return "Yesterday"
        }
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter.string(from: date)
    }

    private func canCoachModifyWorkoutLog(_ log: WorkoutLog) -> Bool {
        canCurrentCoachEditWorkoutLogs(for: log.athleteID) && log.source != .athleteManual
    }

    private func refreshWorkoutLogDerivedState(for athleteID: UUID, latestLog: WorkoutLog? = nil) {
        let logs = workoutLogs(for: athleteID)
        refreshCoachClientDerivedWorkoutState(for: athleteID, logs: logs, latestLog: latestLog ?? logs.first)

        guard athleteID == clientProfile.id else { return }
        refreshCurrentAthleteWorkoutHistory()
        workoutConsistency = updatedWorkoutConsistencyFromCurrentLogs()
        isWorkoutLoggedToday = logs.contains {
            ($0.source == .athleteManual || $0.source == .partnerShared) && Calendar.current.isDateInToday($0.completedAt)
        }
        recomputeClientMetrics(from: logs)
    }

    /// A neutral recovery baseline shown until the user does a check-in — clearly
    /// a default, not a fabricated measurement.
    static let neutralRecovery = RecoverySnapshot(
        score: 60,
        status: .moderate,
        reason: "Default starting point — do a quick check-in to personalize today.",
        sleepHours: 7.0,
        energy: 6,
        soreness: 3,
        mood: 6,
        pain: false,
        previousSessionFeedback: nil
    )

    /// Derives the user's Morphe Score, streak, and activity trend from their
    /// real logged workouts — no seeded numbers, no fake growth.
    private func recomputeClientMetrics(from logs: [WorkoutLog]) {
        let streak = Self.currentWorkoutStreak(from: logs)
        clientProfile.level.streak = streak

        if logs.isEmpty {
            clientProfile.health = HealthScoreSummary(
                score: 0,
                headline: "Getting started",
                detail: "Log your first workout to start building your Morphe Score.",
                tier: .resetMode
            )
            healthTrend = []
            return
        }

        let summary = workoutLogSummary(from: logs)
        let weekCount = summary.workoutsThisWeek
        // Score reflects recent consistency + streak, bounded 10–100.
        let score = min(100, max(10, 35 + weekCount * 10 + min(streak, 7) * 3))
        let tier = HealthTier.from(score: score)
        clientProfile.health = HealthScoreSummary(
            score: score,
            headline: tier.rawValue,
            detail: weekCount == 0
                ? "No sessions yet this week. One workout restarts your momentum."
                : "\(weekCount) session\(weekCount == 1 ? "" : "s") logged this week — keep it going.",
            tier: tier
        )
        healthTrend = Self.recentActivityTrend(from: logs)
    }

    /// A 7-day activity trend: higher on days a workout was logged.
    private static func recentActivityTrend(from logs: [WorkoutLog]) -> [DayScore] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE"
        return (0..<7).reversed().map { offset in
            let day = calendar.date(byAdding: .day, value: -offset, to: today) ?? today
            let trained = logs.contains { calendar.isDate($0.completedAt, inSameDayAs: day) }
            return DayScore(day: formatter.string(from: day), value: trained ? 80 : 25)
        }
    }

    private func refreshCoachClientDerivedWorkoutState(for athleteID: UUID, logs: [WorkoutLog], latestLog: WorkoutLog?) {
        guard let athleteIndex = coachClients.firstIndex(where: { $0.id == athleteID }) else { return }

        let baselineClient = MorpheDemoContent.coachClients.first(where: { $0.id == athleteID })
        let baselineLogCount = MorpheDemoContent.workoutLogs.filter { $0.athleteID == athleteID }.count
        let baselineCompliance = baselineClient?.complianceScore ?? coachClients[athleteIndex].complianceScore
        let baselineProgramCompliance = baselineClient?.programCompliance.score ?? coachClients[athleteIndex].programCompliance.score
        let delta = logs.count - baselineLogCount

        coachClients[athleteIndex].lastWorkout = logs.first.map { Self.workoutDateLabel(for: $0.completedAt) }
            ?? baselineClient?.lastWorkout
            ?? coachClients[athleteIndex].lastWorkout

        let logEvents = logs.prefix(3).map {
            ClientTimelineEvent(
                title: $0.workoutTitle,
                detail: "\($0.source.badgeTitle) • \($0.durationMinutes) min • \($0.verificationStatus.rawValue)"
            )
        }
        let fallbackEvents = Array((baselineClient?.timeline ?? []).prefix(max(0, 4 - logEvents.count)))
        coachClients[athleteIndex].timeline = logEvents + fallbackEvents
        coachClients[athleteIndex].complianceScore = min(max(baselineCompliance + delta, 0), 100)
        coachClients[athleteIndex].programCompliance.score = min(max(baselineProgramCompliance + delta, 0), 100)

        let summary = workoutLogSummary(from: logs)
        let partnerInsight = partnerTrainingInsight(from: logs, athleteName: coachClients[athleteIndex].name)
        coachClients[athleteIndex].programCompliance.summary = logs.isEmpty
            ? (baselineClient?.programCompliance.summary ?? coachClients[athleteIndex].programCompliance.summary)
            : "\(summary.workoutsThisWeek) logged sessions this week. Latest source: \(summary.latestEntryLabel)."
        coachClients[athleteIndex].adherenceSummary = logs.isEmpty
            ? (baselineClient?.adherenceSummary ?? coachClients[athleteIndex].adherenceSummary)
            : partnerInsight.coachSummary

        if let latestLog {
            coachClients[athleteIndex].aiSummary = "\(latestLog.athleteName) now has \(summary.totalLogs) shared workout logs. Latest entry: \(latestLog.workoutTitle) from \(latestLog.source.rawValue.lowercased())."
        }
    }

    private func workoutLogSummary(from logs: [WorkoutLog]) -> WorkoutLogSummary {
        let calendar = Calendar.current
        let thisWeekLogs = logs.filter { calendar.isDate($0.completedAt, equalTo: .now, toGranularity: .weekOfYear) }
        let totalMinutes = thisWeekLogs.reduce(0) { $0 + $1.durationMinutes }
        let averageDuration = logs.isEmpty ? 0 : logs.reduce(0) { $0 + $1.durationMinutes } / logs.count
        let athleteEntries = logs.filter { $0.source == .athleteManual }.count
        let coachEntries = logs.filter { $0.source == .coachManual }.count
        let aiEntries = logs.filter { $0.source == .aiPhotoParsed }.count
        let partnerEntries = logs.filter { $0.source == .partnerShared }.count

        let topExercises = Dictionary(grouping: logs.flatMap(\.exercises), by: \.name)
            .map { ($0.key, $0.value.count) }
            .sorted { lhs, rhs in
                if lhs.1 == rhs.1 {
                    return lhs.0 < rhs.0
                }
                return lhs.1 > rhs.1
            }
            .prefix(3)
            .map(\.0)

        let latestLog = logs.first

        return WorkoutLogSummary(
            totalLogs: logs.count,
            workoutsThisWeek: thisWeekLogs.count,
            minutesThisWeek: totalMinutes,
            averageDuration: averageDuration,
            currentStreakDays: Self.currentWorkoutStreak(from: logs),
            athleteEntries: athleteEntries,
            coachEntries: coachEntries,
            aiEntries: aiEntries,
            partnerEntries: partnerEntries,
            latestWorkoutTitle: latestLog?.workoutTitle ?? "No workouts logged yet",
            latestEntryLabel: latestLog.map { "\($0.source.badgeTitle) • \($0.enteredByName)" } ?? "Waiting for the first log",
            latestEntryDate: latestLog?.completedAt,
            topExercises: topExercises
        )
    }

    private func athleteName(for athleteID: UUID) -> String {
        if athleteID == clientProfile.id {
            return clientProfile.name
        }

        return coachClients.first(where: { $0.id == athleteID })?.name
            ?? workoutLogs.first(where: { $0.athleteID == athleteID })?.athleteName
            ?? "Athlete"
    }

    private func partnerTrainingInsight(from logs: [WorkoutLog], athleteName: String) -> PartnerTrainingInsight {
        let calendar = Calendar.current
        let thisWeekLogs = logs.filter { calendar.isDate($0.completedAt, equalTo: .now, toGranularity: .weekOfYear) }
        let buddyThisWeek = thisWeekLogs.filter { $0.source == .partnerShared }.count
        let soloThisWeek = max(thisWeekLogs.count - buddyThisWeek, 0)

        let last30DaysLogs = logs.filter {
            guard let days = calendar.dateComponents([.day], from: $0.completedAt, to: .now).day else {
                return false
            }
            return days <= 30
        }
        let buddyLast30Days = last30DaysLogs.filter { $0.source == .partnerShared }.count
        let buddyShareLast30Days = last30DaysLogs.isEmpty
            ? 0
            : Int((Double(buddyLast30Days) / Double(last30DaysLogs.count) * 100).rounded())
        let lastPartnerName = logs
            .first(where: { $0.source == .partnerShared })
            .flatMap { partnerName(from: $0, athleteName: athleteName) }

        let athleteSummary: String
        let coachSummary: String

        switch (soloThisWeek, buddyThisWeek) {
        case (0, 0):
            athleteSummary = "No sessions have landed yet this week. One partner workout is the easiest way to restart momentum."
        case (_, 0):
            athleteSummary = "You are mostly training solo this week. Adding one buddy session could make the plan easier to stick with."
        case (0, _):
            athleteSummary = "\(buddyThisWeek) partner session\(buddyThisWeek == 1 ? "" : "s") are carrying the week so far\(lastPartnerName.map { " with \($0)" } ?? "")."
        default:
            athleteSummary = buddyThisWeek >= soloThisWeek
                ? "Buddy sessions are doing a lot of the work for consistency this week\(lastPartnerName.map { ". Last partner: \($0)." } ?? ".")"
                : "Solo sessions are leading this week, with partner work adding an extra accountability bump."
        }

        if last30DaysLogs.isEmpty {
            coachSummary = "No recent workout logs yet. Start with one easy session before reading too much into adherence."
        } else if buddyLast30Days == 0 {
            coachSummary = "Mostly solo lately. A partner session could raise adherence without changing the plan itself."
        } else if buddyLast30Days > max(last30DaysLogs.count - buddyLast30Days, 0) {
            coachSummary = "Trains better with partner accountability lately. Keep shared sessions in the weekly rhythm."
        } else if buddyLast30Days >= 2 {
            coachSummary = "Balanced solo and partner work. Buddy sessions look like a useful adherence lever right now."
        } else {
            coachSummary = "Mostly solo this month, with a light partner signal. Use buddy sessions as a support tool instead of the whole plan."
        }

        return PartnerTrainingInsight(
            soloSessionsThisWeek: soloThisWeek,
            buddySessionsThisWeek: buddyThisWeek,
            totalSessionsThisWeek: thisWeekLogs.count,
            buddyShareLast30Days: buddyShareLast30Days,
            lastPartnerName: lastPartnerName,
            athleteSummary: athleteSummary,
            coachSummary: coachSummary
        )
    }

    private func soloBuddyTrend(from logs: [WorkoutLog]) -> [SoloBuddyTrendPoint] {
        let calendar = Calendar.current
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"

        let weekBuckets = Dictionary(grouping: logs) { log -> Date in
            let components = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: log.completedAt)
            return calendar.date(from: components) ?? log.completedAt
        }

        let recentWeeks = weekBuckets.keys.sorted().suffix(6)

        return recentWeeks.map { weekStart in
            let weekLogs = weekBuckets[weekStart, default: []]
            let soloSessions = weekLogs.filter { $0.source != .partnerShared }.count
            let buddySessions = weekLogs.filter { $0.source == .partnerShared }.count

            return SoloBuddyTrendPoint(
                week: formatter.string(from: weekStart),
                soloSessions: soloSessions,
                buddySessions: buddySessions
            )
        }
    }

    private func partnerName(from log: WorkoutLog, athleteName: String) -> String? {
        let participants = log.enteredByName
            .components(separatedBy: " + ")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        if let match = participants.first(where: { $0.caseInsensitiveCompare(athleteName) != .orderedSame }) {
            return match
        }

        if let range = log.notes.range(of: "with ") {
            let partnerSlice = log.notes[range.upperBound...]
            if let endIndex = partnerSlice.firstIndex(of: " ") {
                return String(partnerSlice[..<endIndex])
            }
            return String(partnerSlice)
        }

        return nil
    }

    private func athleteInboxDraft(for action: AthleteInboxQuickAction, thread: MessageThread) -> String {
        switch action {
        case .reply:
            return ""
        case .shareWorkout:
            if hasCompletedWorkoutFlow {
                return "Just finished \(currentWorkout.name). I’m about to log it now and wanted to share the update."
            }
            return "Wanted to share a quick training update: \(currentWorkout.name) is the session I’m working around today."
        case .askForSwap:
            let targetExercise = activeWorkoutExercise?.name ?? currentWorkout.exercises.first?.name ?? "today's first movement"
            if thread.participant == "Morphe AI" {
                return "Can you help me swap \(targetExercise) for something that fits better today?"
            }
            return "Can we swap \(targetExercise) for something that fits better today?"
        case .confirmTomorrow:
            return "Tomorrow still good for \(currentWorkout.name)? I want to lock it in before the day gets crowded."
        }
    }

    private func postWorkoutCoachDraft() -> String {
        if currentWorkout.name == clientProfile.currentProgram {
            return "Just finished \(currentWorkout.name). I closed the loop on the assignment and I’m about to log it now."
        }

        if currentWorkout.category == .recovery || currentWorkout.name == "Low Energy Recovery Day" {
            return "Just wrapped \(currentWorkout.name). I kept it recovery-first today and it helped me stay on track."
        }

        return "Just finished \(currentWorkout.name). I’m about to log it now and wanted to keep you in the loop."
    }

    private func postWorkoutBuddyDraft(for partner: WorkoutPartner) -> String {
        "Nice work today. Want to lock in the next \(currentWorkout.name) session together, \(partner.name)?"
    }

    private func postWorkoutHighlightText() -> String {
        if partnerWorkoutEnabled, let partner = selectedWorkoutPartner {
            return "Finished \(currentWorkout.name) with \(partner.name) and kept the pace honest from first set to last."
        }

        if currentWorkout.name == clientProfile.currentProgram {
            return "Closed the loop on \(currentWorkout.name) from \(clientProfile.planCreatedBy)'s plan and finished the work clean."
        }

        if currentWorkout.category == .recovery || currentWorkout.name == "Low Energy Recovery Day" {
            return "Followed through on \(currentWorkout.name) and kept the week moving without forcing a heavier day."
        }

        return "Finished \(currentWorkout.name) and kept the training momentum moving."
    }

    private func saveWorkoutTemplate(
        _ template: WorkoutTemplate,
        sourceName: String,
        sourceRole: AppRole,
        sourceContext: String,
        bestFor: SavedWorkoutUseCase,
        note: String
    ) {
        if savedWorkouts.contains(where: { $0.workoutTemplateID == template.id && $0.sourceName == sourceName }) {
            showToast("\(template.name) is already in your saved workouts.")
            return
        }

        savedWorkouts.insert(
            SavedWorkoutLibraryItem(
                workoutTemplateID: template.id,
                workoutName: template.name,
                sport: template.sport,
                sourceName: sourceName,
                sourceRole: sourceRole,
                sourceContext: sourceContext,
                bestFor: bestFor,
                note: note
            ),
            at: 0
        )
        showToast("Saved \(template.name) to your library.")
    }

    private func suggestedUseCase(for template: WorkoutTemplate, context: String) -> SavedWorkoutUseCase {
        let lowercasedContext = context.lowercased()
        let lowercasedName = template.name.lowercased()

        if lowercasedContext.contains("buddy") || lowercasedContext.contains("partner") {
            return .buddy
        }

        if lowercasedName.contains("quick")
            || lowercasedName.contains("recovery")
            || template.durationMinutes <= 20
            || lowercasedContext.contains("fallback")
            || lowercasedContext.contains("minimum win") {
            return .fallback
        }

        if lowercasedContext.contains("built by you") || lowercasedContext.contains("custom") {
            return .customBuild
        }

        return .solo
    }

    private func goodForTodayRecommendation() -> GoodForTodayWorkoutRecommendation {
        let behavior = goodForTodayBehaviorSnapshot()
        let needsRecovery = recovery.status == .recoveryRecommended
            || recovery.status == .takeItEasy
            || currentPlanAdjustment.reasons.contains(.lowRecovery)
            || currentPlanAdjustment.reasons.contains(.painReported)
        let needsFallback = minimumWinModeEnabled
            || selectedConfidence == .notConfident
            || currentPlanAdjustment.reasons.contains(.notEnoughTime)
        let partnerInsight = currentAthletePartnerTrainingInsight
        let shouldPushBuddy = selectedWorkoutPartner != nil
            && !needsRecovery
            && (
                partnerWorkoutEnabled
                    || behavior.buddyLiftIsReal
                    || partnerInsight.buddyShareLast30Days >= 30
                    || partnerInsight.soloSessionsThisWeek >= max(partnerInsight.buddySessionsThisWeek, 1)
            )

        if needsRecovery {
            if let savedRecovery = behavior.recoveryFavorite
                ?? bestSavedWorkout(
                    where: {
                        $0.bestFor == .fallback
                            || $0.workoutName.localizedCaseInsensitiveContains("recovery")
                            || $0.note.localizedCaseInsensitiveContains("recovery")
                    }
                ) {
                let recoveryInsight = workoutTemplateInsight(for: savedRecovery.workoutTemplateID)
                return recommendation(
                    from: savedRecovery,
                    reasonTitle: behavior.recoveryDaysLeadToMomentum
                        ? "Recovery days keep your week moving"
                        : "Recovery fits better today",
                    reasonDetail: behavior.recoveryDaysLeadToMomentum || recoveryInsight.recoveryFollowThroughCount > 0
                        ? "The last few lighter days like this helped you get back to real training cleanly, so Morphe is leaning into the pattern that keeps the week moving."
                        : "Readiness is asking for a lighter touch, so Morphe is steering you toward a session you can finish cleanly.",
                    contextChips: recommendationContextChips(
                        needsRecovery: true,
                        needsFallback: false,
                        prefersBuddy: false,
                        bestFor: savedRecovery.bestFor,
                        behavioralChips: behaviorChips(
                            for: recoveryInsight,
                            recoveryDaysLeadToMomentum: behavior.recoveryDaysLeadToMomentum
                        )
                    ),
                    confidenceNote: recommendationConfidenceNote(
                        for: recoveryInsight,
                        bestFor: savedRecovery.bestFor,
                        prefersBuddy: false,
                        recoveryDaysLeadToMomentum: behavior.recoveryDaysLeadToMomentum
                    ),
                    prefersBuddy: false
                )
            }

            if let template = resolveWorkoutTemplate(named: "Low Energy Recovery Day", preferredSport: clientProfile.sportMode) {
                return recommendation(
                    from: template,
                    sourceName: clientProfile.planCreatedBy,
                    reasonTitle: behavior.recoveryDaysLeadToMomentum
                        ? "Recovery days keep your week moving"
                        : "Recovery fits better today",
                    reasonDetail: behavior.recoveryDaysLeadToMomentum
                        ? "You tend to stay on track when you let recovery sessions do their job, so Morphe is protecting the week instead of forcing a bigger lift."
                        : "Readiness is asking for a lighter touch, so Morphe is steering you toward a session you can finish cleanly.",
                    contextChips: recommendationContextChips(
                        needsRecovery: true,
                        needsFallback: false,
                        prefersBuddy: false,
                        bestFor: .fallback,
                        behavioralChips: behaviorChips(
                            for: workoutTemplateInsight(for: template.id),
                            recoveryDaysLeadToMomentum: behavior.recoveryDaysLeadToMomentum
                        )
                    ),
                    confidenceNote: recommendationConfidenceNote(
                        for: workoutTemplateInsight(for: template.id),
                        bestFor: .fallback,
                        prefersBuddy: false,
                        recoveryDaysLeadToMomentum: behavior.recoveryDaysLeadToMomentum
                    ),
                    bestFor: .fallback,
                    prefersBuddy: false
                )
            }
        }

        if needsFallback {
            if let savedFallback = behavior.fallbackFavorite
                ?? bestSavedWorkout(where: { $0.bestFor == .fallback }) {
                let fallbackInsight = workoutTemplateInsight(for: savedFallback.workoutTemplateID)
                return recommendation(
                    from: savedFallback,
                    reasonTitle: behavior.coachPlanWorksAfterFallback
                        ? "Small wins set up the plan"
                        : (behavior.fallbackDaysSaveMomentum
                            ? "Small wins keep the week alive"
                            : (fallbackInsight.recentCompletionCount >= 2 || fallbackInsight.completionCount >= 3
                                ? "You usually finish this one cleanly"
                                : "Best for a smaller win")),
                    reasonDetail: behavior.coachPlanWorksAfterFallback
                        ? "When the week gets crowded, shorter sessions like this are usually what get you back into coach-led work within a couple of days. Morphe is leaning into the pattern that actually keeps the plan alive."
                        : (behavior.fallbackDaysSaveMomentum
                            ? "When the week gets crowded, this kind of lower-friction session is what most often keeps your momentum alive. Morphe is choosing the version of the day you still tend to close."
                            : (fallbackInsight.recentCompletionCount >= 2 || fallbackInsight.completionCount >= 3
                                ? "When time or confidence gets tight, this is the workout you actually close most often. Morphe is putting the lower-friction win in front of you."
                                : "Confidence or time looks tight today, so this one gives you the best odds of finishing without overthinking it.")),
                    contextChips: recommendationContextChips(
                        needsRecovery: false,
                        needsFallback: true,
                        prefersBuddy: false,
                        bestFor: savedFallback.bestFor,
                        behavioralChips: behaviorChips(
                            for: fallbackInsight,
                            fallbackDaysSaveMomentum: behavior.fallbackDaysSaveMomentum,
                            coachPlanWorksAfterFallback: behavior.coachPlanWorksAfterFallback
                        )
                    ),
                    confidenceNote: recommendationConfidenceNote(
                        for: fallbackInsight,
                        bestFor: savedFallback.bestFor,
                        prefersBuddy: false,
                        fallbackDaysSaveMomentum: behavior.fallbackDaysSaveMomentum,
                        coachPlanWorksAfterFallback: behavior.coachPlanWorksAfterFallback
                    ),
                    prefersBuddy: false
                )
            }

            if let template = resolveWorkoutTemplate(named: "15-Minute Quick Workout", preferredSport: clientProfile.sportMode) {
                return recommendation(
                    from: template,
                    sourceName: profileShowcase.displayName,
                    reasonTitle: behavior.coachPlanWorksAfterFallback
                        ? "Small wins set up the plan"
                        : (behavior.fallbackDaysSaveMomentum
                            ? "Small wins keep the week alive"
                            : "Best for a smaller win"),
                    reasonDetail: behavior.coachPlanWorksAfterFallback
                        ? "When the week gets crowded, shorter sessions like this are usually what get you back into coach-led work within a couple of days. Morphe is leaning into the pattern that actually keeps the plan alive."
                        : (behavior.fallbackDaysSaveMomentum
                            ? "When the week gets crowded, this kind of lower-friction session is what most often keeps your momentum alive. Morphe is choosing the version of the day you still tend to close."
                            : "Confidence or time looks tight today, so this one gives you the best odds of finishing without overthinking it."),
                    contextChips: recommendationContextChips(
                        needsRecovery: false,
                        needsFallback: true,
                        prefersBuddy: false,
                        bestFor: .fallback,
                        behavioralChips: behaviorChips(
                            for: workoutTemplateInsight(for: template.id),
                            fallbackDaysSaveMomentum: behavior.fallbackDaysSaveMomentum,
                            coachPlanWorksAfterFallback: behavior.coachPlanWorksAfterFallback
                        )
                    ),
                    confidenceNote: recommendationConfidenceNote(
                        for: workoutTemplateInsight(for: template.id),
                        bestFor: .fallback,
                        prefersBuddy: false,
                        fallbackDaysSaveMomentum: behavior.fallbackDaysSaveMomentum,
                        coachPlanWorksAfterFallback: behavior.coachPlanWorksAfterFallback
                    ),
                    bestFor: .fallback,
                    prefersBuddy: false
                )
            }
        }

        if shouldPushBuddy,
           let savedBuddy = behavior.buddyFavorite
            ?? bestSavedWorkout(where: { $0.bestFor == .buddy }) {
            let buddyInsight = workoutTemplateInsight(for: savedBuddy.workoutTemplateID)
            return recommendation(
                from: savedBuddy,
                reasonTitle: behavior.buddyLiftIsReal
                    ? "Buddy sessions are landing lately"
                    : "Buddy sessions help you stick with it",
                reasonDetail: behavior.buddyLiftIsReal || buddyInsight.buddyCompletionCount > 0
                    ? "Your shared sessions are doing more of the work for consistency lately, so Morphe is surfacing the buddy workout you actually finish."
                    : "Partner training has been a good consistency lever lately, so Morphe is surfacing a session that makes shared accountability easy.",
                contextChips: recommendationContextChips(
                    needsRecovery: false,
                    needsFallback: false,
                    prefersBuddy: true,
                    bestFor: savedBuddy.bestFor,
                    behavioralChips: behaviorChips(for: buddyInsight)
                ),
                confidenceNote: recommendationConfidenceNote(
                    for: buddyInsight,
                    bestFor: savedBuddy.bestFor,
                    prefersBuddy: true
                ),
                prefersBuddy: true
            )
        }

        if let repeatFavorite = behavior.repeatFavorite {
            let repeatInsight = workoutTemplateInsight(for: repeatFavorite.workoutTemplateID)
            let shouldPreferRepeatFavorite = repeatFavorite.workoutTemplateID != currentWorkout.id
                && (
                    repeatInsight.recentCompletionCount >= max(behavior.currentPlanInsight.recentCompletionCount + 1, 2)
                        || (behavior.currentPlanInsight.recentCompletionCount == 0 && repeatInsight.completionCount >= 2)
                )

            if shouldPreferRepeatFavorite {
                return recommendation(
                    from: repeatFavorite,
                    reasonTitle: "You usually close the loop with this one",
                    reasonDetail: "Lately this workout has been one of your most reliable follow-through sessions, so Morphe is putting the workout you actually finish in front of you.",
                    contextChips: recommendationContextChips(
                        needsRecovery: false,
                        needsFallback: false,
                        prefersBuddy: false,
                        bestFor: repeatFavorite.bestFor,
                        behavioralChips: behaviorChips(for: repeatInsight)
                    ),
                    confidenceNote: recommendationConfidenceNote(
                        for: repeatInsight,
                        bestFor: repeatFavorite.bestFor,
                        prefersBuddy: false
                    ),
                    prefersBuddy: false
                )
            }
        }

        if let currentPlanSaved = savedWorkouts.first(where: { $0.workoutTemplateID == currentWorkout.id }) {
            return recommendation(
                from: currentPlanSaved,
                reasonTitle: behavior.reboundWindowIsOpen
                    ? "Good rebound moment"
                    : (behavior.coachLedSessionsAreLanding || behavior.currentPlanInsight.recentCompletionCount >= 2
                        ? "Your current plan is landing"
                        : "Best fit for the plan you already have"),
                reasonDetail: behavior.reboundWindowIsOpen
                    ? (behavior.coachPlanWorksAfterFallback
                        ? "After shorter reset days like the one you have been leaning on, you usually get back into coach-led work cleanly. Morphe is putting the main plan back in front of you at the right moment."
                        : "You usually come back to a real training day cleanly after a lighter reset, so Morphe is opening the door for the next full step instead of another fallback.")
                    : (behavior.coachLedSessionsAreLanding
                        ? "Coach-led sessions have been getting completed more reliably than random picks lately, so Morphe is keeping the plan in front of you."
                        : behavior.currentPlanInsight.recentCompletionCount >= 2
                            ? "You have already closed this plan cleanly a couple of times lately, so the simplest move is staying on the rails."
                            : "Your current program still fits today, so the smartest move is keeping the day simple and closing the loop."),
                contextChips: recommendationContextChips(
                    needsRecovery: false,
                    needsFallback: false,
                    prefersBuddy: shouldPushBuddy && currentPlanSaved.bestFor == .buddy,
                    bestFor: currentPlanSaved.bestFor,
                    behavioralChips: behaviorChips(
                        for: behavior.currentPlanInsight,
                        coachLedSessionsAreLanding: behavior.coachLedSessionsAreLanding,
                        coachPlanWorksAfterFallback: behavior.coachPlanWorksAfterFallback,
                        reboundWindowIsOpen: behavior.reboundWindowIsOpen
                    )
                ),
                confidenceNote: recommendationConfidenceNote(
                    for: behavior.currentPlanInsight,
                    bestFor: currentPlanSaved.bestFor,
                    prefersBuddy: shouldPushBuddy && currentPlanSaved.bestFor == .buddy,
                    coachPlanWorksAfterFallback: behavior.coachPlanWorksAfterFallback && behavior.reboundWindowIsOpen,
                    recoveryDaysLeadToMomentum: behavior.recoveryDaysLeadToMomentum && behavior.reboundWindowIsOpen
                ),
                prefersBuddy: shouldPushBuddy && currentPlanSaved.bestFor == .buddy
            )
        }

        return recommendation(
            from: currentWorkout,
            sourceName: clientProfile.planCreatedBy,
            reasonTitle: shouldPushBuddy
                ? "Good moment for a shared session"
                : (behavior.reboundWindowIsOpen
                    ? "Good rebound moment"
                    : (behavior.coachLedSessionsAreLanding || behavior.currentPlanInsight.recentCompletionCount >= 2
                        ? "Your current plan is landing"
                        : "Best fit for the plan you already have")),
            reasonDetail: shouldPushBuddy
                ? "Your current workout lines up well with partner accountability, so Morphe is keeping the day simple and social."
                : (behavior.reboundWindowIsOpen
                    ? (behavior.coachPlanWorksAfterFallback
                        ? "After shorter reset days like the one you have been leaning on, you usually get back into coach-led work cleanly. Morphe is putting the main plan back in front of you at the right moment."
                        : "You usually come back to a real training day cleanly after a lighter reset, so Morphe is opening the door for the next full step instead of another fallback.")
                    : (behavior.coachLedSessionsAreLanding
                        ? "Coach-led sessions have been getting completed more reliably than random picks lately, so Morphe is keeping the plan in front of you."
                        : behavior.currentPlanInsight.recentCompletionCount >= 2
                            ? "You have already closed this plan cleanly a couple of times lately, so the simplest move is staying on the rails."
                            : "Your current program still fits today, so the smartest move is keeping the day simple and closing the loop.")),
            contextChips: recommendationContextChips(
                needsRecovery: false,
                needsFallback: false,
                prefersBuddy: shouldPushBuddy,
                bestFor: shouldPushBuddy ? .buddy : suggestedUseCase(for: currentWorkout, context: currentWorkout.name),
                behavioralChips: behaviorChips(
                    for: behavior.currentPlanInsight,
                    coachLedSessionsAreLanding: behavior.coachLedSessionsAreLanding,
                    coachPlanWorksAfterFallback: behavior.coachPlanWorksAfterFallback,
                    reboundWindowIsOpen: behavior.reboundWindowIsOpen
                )
            ),
            confidenceNote: recommendationConfidenceNote(
                for: behavior.currentPlanInsight,
                bestFor: shouldPushBuddy ? .buddy : suggestedUseCase(for: currentWorkout, context: currentWorkout.name),
                prefersBuddy: shouldPushBuddy,
                coachPlanWorksAfterFallback: behavior.coachPlanWorksAfterFallback && behavior.reboundWindowIsOpen,
                recoveryDaysLeadToMomentum: behavior.recoveryDaysLeadToMomentum && behavior.reboundWindowIsOpen
            ),
            bestFor: shouldPushBuddy ? .buddy : suggestedUseCase(for: currentWorkout, context: currentWorkout.name),
            prefersBuddy: shouldPushBuddy
        )
    }

    private func goodForTodayBehaviorSnapshot() -> GoodForTodayBehaviorSnapshot {
        let behaviorLogs = recentWorkoutLogs(days: 84)
        let recentLogs = recentWorkoutLogs(from: behaviorLogs, days: 28)
        let partnerInsight = currentAthletePartnerTrainingInsight
        let currentPlanInsight = workoutTemplateInsight(for: currentWorkout.id)
        let coachBackedTemplateIDs = Set(savedWorkouts.filter { $0.sourceRole == .coach }.map(\.workoutTemplateID))
            .union([currentWorkout.id])
        let coachBackedLog: (WorkoutLog) -> Bool = { log in
            guard let templateID = log.workoutTemplateID else { return false }
            return coachBackedTemplateIDs.contains(templateID)
        }
        let coachLedRecentCount = recentLogs.filter { log in
            coachBackedLog(log)
        }.count
        let recoveryLogs = behaviorLogs.filter(isRecoveryWorkoutLog)
        let fallbackLogs = behaviorLogs.filter(isLowFrictionWorkoutLog)
        let recoveryFollowThrough = followThroughCount(for: recoveryLogs, in: behaviorLogs)
        let fallbackFollowThrough = followThroughCount(for: fallbackLogs, in: behaviorLogs)
        let coachReboundCount = followThroughCount(
            for: fallbackLogs,
            in: behaviorLogs,
            matching: coachBackedLog
        )
        let reboundWindowIsOpen = currentAthleteWorkoutLogs.first.map { latestLog in
            guard let dayCount = Calendar.current.dateComponents([.day], from: latestLog.completedAt, to: .now).day else {
                return false
            }
            return dayCount <= 3
                && (isRecoveryWorkoutLog(latestLog) || isLowFrictionWorkoutLog(latestLog))
        } ?? false

        return GoodForTodayBehaviorSnapshot(
            fallbackFavorite: bestBehaviorSavedWorkout { item, _, template in
                item.bestFor == .fallback || isLowFrictionTemplate(template, workoutName: item.workoutName, note: item.note)
            },
            recoveryFavorite: bestBehaviorSavedWorkout { item, _, template in
                isRecoveryTemplate(template, workoutName: item.workoutName, note: item.note)
            },
            buddyFavorite: bestBehaviorSavedWorkout(
                where: { item, insight, template in
                    item.bestFor == .buddy
                        || insight.buddyCompletionCount > 0
                        || isBuddyTemplate(template, workoutName: item.workoutName, note: item.note)
                },
                preferBuddyWeight: true
            ),
            repeatFavorite: bestBehaviorSavedWorkout { item, insight, template in
                insight.recentCompletionCount > 0
                    && !isRecoveryTemplate(template, workoutName: item.workoutName, note: item.note)
                    && !isBuddyTemplate(template, workoutName: item.workoutName, note: item.note)
            },
            currentPlanInsight: currentPlanInsight,
            coachLedSessionsAreLanding: coachLedRecentCount >= 2
                && coachLedRecentCount * 2 >= max(recentLogs.count, 1),
            buddyLiftIsReal: partnerInsight.buddyShareLast30Days >= 35
                || partnerInsight.buddySessionsThisWeek >= max(partnerInsight.soloSessionsThisWeek, 1),
            recoveryDaysLeadToMomentum: hasReliableBehaviorPattern(
                successes: recoveryFollowThrough,
                opportunities: recoveryLogs.count
            ),
            fallbackDaysSaveMomentum: hasReliableBehaviorPattern(
                successes: fallbackFollowThrough,
                opportunities: fallbackLogs.count
            ),
            coachPlanWorksAfterFallback: hasReliableBehaviorPattern(
                successes: coachReboundCount,
                opportunities: fallbackLogs.count
            ),
            reboundWindowIsOpen: reboundWindowIsOpen
                && (hasReliableBehaviorPattern(
                    successes: recoveryFollowThrough,
                    opportunities: recoveryLogs.count
                ) || hasReliableBehaviorPattern(
                    successes: coachReboundCount,
                    opportunities: fallbackLogs.count
                ))
        )
    }

    private func bestSavedWorkout(where predicate: (SavedWorkoutLibraryItem) -> Bool) -> SavedWorkoutLibraryItem? {
        savedWorkouts
            .filter(predicate)
            .sorted { lhs, rhs in
                let lhsInsight = savedWorkoutInsight(for: lhs)
                let rhsInsight = savedWorkoutInsight(for: rhs)

                if lhs.isPinned != rhs.isPinned {
                    return lhs.isPinned && !rhs.isPinned
                }
                if lhsInsight.completionCount != rhsInsight.completionCount {
                    return lhsInsight.completionCount > rhsInsight.completionCount
                }
                return (lhsInsight.lastCompletedAt ?? lhs.savedAt) > (rhsInsight.lastCompletedAt ?? rhs.savedAt)
            }
            .first
    }

    private func bestBehaviorSavedWorkout(
        where predicate: (SavedWorkoutLibraryItem, WorkoutTemplateCompletionInsight, WorkoutTemplate?) -> Bool,
        preferBuddyWeight: Bool = false
    ) -> SavedWorkoutLibraryItem? {
        savedWorkouts
            .compactMap { item -> (SavedWorkoutLibraryItem, WorkoutTemplateCompletionInsight, WorkoutTemplate?)? in
                let template = savedWorkoutTemplate(for: item)
                let insight = workoutTemplateInsight(for: item.workoutTemplateID)
                guard predicate(item, insight, template) else { return nil }
                return (item, insight, template)
            }
            .sorted { lhs, rhs in
                if lhs.0.isPinned != rhs.0.isPinned {
                    return lhs.0.isPinned && !rhs.0.isPinned
                }
                if lhs.1.recentCompletionCount != rhs.1.recentCompletionCount {
                    return lhs.1.recentCompletionCount > rhs.1.recentCompletionCount
                }
                if preferBuddyWeight && lhs.1.buddyCompletionCount != rhs.1.buddyCompletionCount {
                    return lhs.1.buddyCompletionCount > rhs.1.buddyCompletionCount
                }
                if lhs.1.recoveryFollowThroughCount != rhs.1.recoveryFollowThroughCount {
                    return lhs.1.recoveryFollowThroughCount > rhs.1.recoveryFollowThroughCount
                }
                if lhs.1.completionCount != rhs.1.completionCount {
                    return lhs.1.completionCount > rhs.1.completionCount
                }
                return (lhs.1.lastCompletedAt ?? lhs.0.savedAt) > (rhs.1.lastCompletedAt ?? rhs.0.savedAt)
            }
            .first?
            .0
    }

    private func savedWorkoutTemplate(for item: SavedWorkoutLibraryItem) -> WorkoutTemplate? {
        workoutTemplates.first(where: { $0.id == item.workoutTemplateID })
            ?? resolveWorkoutTemplate(named: item.workoutName, preferredSport: item.sport)
    }

    private func workoutTemplateInsight(for templateID: UUID) -> WorkoutTemplateCompletionInsight {
        let matchingLogs = currentAthleteWorkoutLogs.filter { $0.workoutTemplateID == templateID }
        let recentLogs = recentWorkoutLogs(from: matchingLogs, days: 28)

        return WorkoutTemplateCompletionInsight(
            completionCount: matchingLogs.count,
            recentCompletionCount: recentLogs.count,
            buddyCompletionCount: matchingLogs.filter { $0.source == .partnerShared }.count,
            lastCompletedAt: matchingLogs.first?.completedAt,
            lastSource: matchingLogs.first?.source,
            recoveryFollowThroughCount: followThroughCount(for: matchingLogs, in: currentAthleteWorkoutLogs)
        )
    }

    private func recommendationContextChips(
        needsRecovery: Bool,
        needsFallback: Bool,
        prefersBuddy: Bool,
        bestFor: SavedWorkoutUseCase,
        behavioralChips: [String] = []
    ) -> [String] {
        var chips: [String] = []

        if needsRecovery {
            chips.append("Good for low energy")
            chips.append("Recovery friendly")
        } else if needsFallback {
            chips.append("Good for time crunch")
            chips.append("Easy win")
        }

        if prefersBuddy {
            chips.append("Buddy boost")
        }

        switch bestFor {
        case .fallback:
            if !chips.contains("Easy win") {
                chips.append("Fallback ready")
            }
        case .customBuild:
            chips.append("Custom build")
        case .solo:
            if !prefersBuddy {
                chips.append("Solo ready")
            }
        case .buddy:
            if !chips.contains("Buddy boost") {
                chips.append("Partner ready")
            }
        }

        for chip in behavioralChips where !chips.contains(chip) {
            chips.append(chip)
        }

        return Array(chips.prefix(4))
    }

    private func recommendationConfidenceNote(
        for insight: WorkoutTemplateCompletionInsight?,
        bestFor: SavedWorkoutUseCase,
        prefersBuddy: Bool,
        fallbackDaysSaveMomentum: Bool = false,
        coachPlanWorksAfterFallback: Bool = false,
        recoveryDaysLeadToMomentum: Bool = false
    ) -> String? {
        guard let insight else { return nil }

        if coachPlanWorksAfterFallback && !prefersBuddy {
            return "Short reset days like this usually lead you back into the plan cleanly."
        }

        if fallbackDaysSaveMomentum && bestFor == .fallback {
            return "This kind of smaller session usually keeps your week moving."
        }

        if recoveryDaysLeadToMomentum {
            return "Lighter reset days like this usually set up your next finished session."
        }

        if prefersBuddy && insight.buddyCompletionCount >= 2 {
            return "Buddy sessions with this one are landing lately."
        }

        if insight.recoveryFollowThroughCount >= 2 {
            return "Lighter days like this usually lead into another finished session."
        }

        if insight.recentCompletionCount >= 2 {
            return "You have finished this one \(insight.recentCompletionCount)x lately."
        }

        if prefersBuddy && insight.buddyCompletionCount > 0 {
            return "You have already finished this one with a buddy."
        }

        if insight.completionCount >= 3 {
            return "You usually finish this one."
        }

        if bestFor == .fallback && insight.completionCount > 0 {
            return "This one has already saved the day before."
        }

        return nil
    }

    private func behaviorChips(
        for insight: WorkoutTemplateCompletionInsight,
        coachLedSessionsAreLanding: Bool = false,
        recoveryDaysLeadToMomentum: Bool = false,
        fallbackDaysSaveMomentum: Bool = false,
        coachPlanWorksAfterFallback: Bool = false,
        reboundWindowIsOpen: Bool = false
    ) -> [String] {
        var chips: [String] = []

        if fallbackDaysSaveMomentum {
            chips.append("Crowded week saver")
        }

        if coachPlanWorksAfterFallback {
            chips.append("Coach rebound")
        }

        if reboundWindowIsOpen {
            chips.append("Ready to ramp")
        }

        if insight.recentCompletionCount >= 2 {
            chips.append("Recently reliable")
        }

        if insight.buddyCompletionCount > 0 {
            chips.append("Partner proven")
        }

        if coachLedSessionsAreLanding {
            chips.append("Coach plan lands")
        }

        if recoveryDaysLeadToMomentum || insight.recoveryFollowThroughCount > 0 {
            chips.append("Momentum builder")
        }

        return Array(chips.prefix(2))
    }

    private func hasReliableBehaviorPattern(
        successes: Int,
        opportunities: Int,
        minimumSuccesses: Int = 2
    ) -> Bool {
        guard opportunities > 0, successes >= minimumSuccesses else { return false }
        return successes * 2 >= opportunities
    }

    private func recommendation(
        from item: SavedWorkoutLibraryItem,
        reasonTitle: String,
        reasonDetail: String,
        contextChips: [String],
        confidenceNote: String?,
        prefersBuddy: Bool
    ) -> GoodForTodayWorkoutRecommendation {
        GoodForTodayWorkoutRecommendation(
            workoutTemplateID: item.workoutTemplateID,
            workoutName: item.workoutName,
            sourceName: item.sourceName,
            reasonTitle: reasonTitle,
            reasonDetail: reasonDetail,
            contextChips: contextChips,
            confidenceNote: confidenceNote,
            bestFor: item.bestFor,
            prefersBuddy: prefersBuddy,
            existingSavedWorkoutID: item.id
        )
    }

    private func recommendation(
        from template: WorkoutTemplate,
        sourceName: String,
        reasonTitle: String,
        reasonDetail: String,
        contextChips: [String],
        confidenceNote: String?,
        bestFor: SavedWorkoutUseCase,
        prefersBuddy: Bool
    ) -> GoodForTodayWorkoutRecommendation {
        GoodForTodayWorkoutRecommendation(
            workoutTemplateID: template.id,
            workoutName: template.name,
            sourceName: sourceName,
            reasonTitle: reasonTitle,
            reasonDetail: reasonDetail,
            contextChips: contextChips,
            confidenceNote: confidenceNote,
            bestFor: bestFor,
            prefersBuddy: prefersBuddy,
            existingSavedWorkoutID: savedWorkouts.first(where: { $0.workoutTemplateID == template.id })?.id
        )
    }

    private func recentWorkoutLogs(from logs: [WorkoutLog]? = nil, days: Int) -> [WorkoutLog] {
        let sourceLogs = logs ?? currentAthleteWorkoutLogs
        let calendar = Calendar.current

        return sourceLogs.filter {
            guard let dayCount = calendar.dateComponents([.day], from: $0.completedAt, to: .now).day else {
                return false
            }
            return dayCount <= days
        }
    }

    private func followThroughCount(
        for anchorLogs: [WorkoutLog],
        in allLogs: [WorkoutLog],
        withinDays: Int = 3,
        matching predicate: ((WorkoutLog) -> Bool)? = nil
    ) -> Int {
        let calendar = Calendar.current

        return anchorLogs.filter { log in
            guard let deadline = calendar.date(byAdding: .day, value: withinDays, to: log.completedAt) else {
                return false
            }

            return allLogs.contains { candidate in
                candidate.id != log.id
                    && candidate.completedAt > log.completedAt
                    && candidate.completedAt <= deadline
                    && (predicate?(candidate) ?? true)
            }
        }.count
    }

    private func isLowFrictionTemplate(_ template: WorkoutTemplate?, workoutName: String, note: String) -> Bool {
        let lowercasedText = "\(workoutName) \(note)".lowercased()

        if lowercasedText.contains("fallback")
            || lowercasedText.contains("minimum win")
            || lowercasedText.contains("quick") {
            return true
        }

        guard let template else { return false }
        return template.durationMinutes <= 20
            || template.category == .recovery
            || template.sessionType == .recoverySession
    }

    private func isRecoveryTemplate(_ template: WorkoutTemplate?, workoutName: String, note: String) -> Bool {
        let lowercasedText = "\(workoutName) \(note)".lowercased()

        if lowercasedText.contains("recovery") || lowercasedText.contains("low energy") {
            return true
        }

        guard let template else { return false }
        return template.category == .recovery || template.sessionType == .recoverySession
    }

    private func isBuddyTemplate(_ template: WorkoutTemplate?, workoutName: String, note: String) -> Bool {
        let lowercasedText = "\(workoutName) \(note)".lowercased()

        if lowercasedText.contains("buddy") || lowercasedText.contains("partner") {
            return true
        }

        guard let template else { return false }
        return template.name.localizedCaseInsensitiveContains("buddy")
            || template.coachNote.localizedCaseInsensitiveContains("partner")
    }

    private func isLowFrictionWorkoutLog(_ log: WorkoutLog) -> Bool {
        if let templateID = log.workoutTemplateID,
           let template = workoutTemplates.first(where: { $0.id == templateID }) {
            return isLowFrictionTemplate(template, workoutName: log.workoutTitle, note: log.notes)
        }

        return isLowFrictionTemplate(nil, workoutName: log.workoutTitle, note: log.notes)
    }

    private func isRecoveryWorkoutLog(_ log: WorkoutLog) -> Bool {
        if let templateID = log.workoutTemplateID,
           let template = workoutTemplates.first(where: { $0.id == templateID }) {
            return template.category == .recovery || template.sessionType == .recoverySession
        }

        let lowercasedTitle = log.workoutTitle.lowercased()
        return lowercasedTitle.contains("recovery") || lowercasedTitle.contains("low energy")
    }

    private func resolveWorkoutTemplate(named title: String, preferredSport: SportFocus? = nil) -> WorkoutTemplate? {
        let normalizedTitle = title.lowercased()

        if let exactMatch = workoutTemplates.first(where: { $0.name.lowercased() == normalizedTitle }) {
            return exactMatch
        }

        if normalizedTitle.contains("quick") || normalizedTitle.contains("fallback") || normalizedTitle.contains("streak") {
            return workoutTemplates.first(where: { $0.name == "15-Minute Quick Workout" })
        }

        if normalizedTitle.contains("recovery") || normalizedTitle.contains("low energy") {
            return workoutTemplates.first(where: { $0.name == "Low Energy Recovery Day" })
        }

        if let preferredSport,
           let sportMatch = workoutTemplates.first(where: { $0.sport == preferredSport }) {
            return sportMatch
        }

        return workoutTemplates.first(where: { normalizedTitle.contains($0.name.lowercased()) })
            ?? workoutTemplates.first(where: { $0.sport == .generalFitness })
            ?? workoutTemplates.first
    }

    private func recommendedTemplate(for post: ProgressPost) -> WorkoutTemplate? {
        let lowercasedTitle = post.title.lowercased()
        let lowercasedDetail = post.detail.lowercased()

        if lowercasedTitle.contains("streak") || lowercasedDetail.contains("minimum win") {
            return resolveWorkoutTemplate(named: "15-Minute Quick Workout")
        }

        if lowercasedTitle.contains("sprint") || post.tags.contains(where: { $0.lowercased().contains("soccer") }) {
            return resolveWorkoutTemplate(named: "Soccer Match Fitness", preferredSport: .soccer)
        }

        if lowercasedTitle.contains("jump") || post.tags.contains(where: { $0.lowercased().contains("basketball") }) {
            return resolveWorkoutTemplate(named: "Beginner Full Body Strength", preferredSport: .strength)
        }

        if post.tags.contains(where: { $0.lowercased().contains("boxing") }) {
            return resolveWorkoutTemplate(named: "Boxing Conditioning Builder", preferredSport: .boxing)
        }

        return resolveWorkoutTemplate(named: post.title, preferredSport: inferredSport(for: post))
    }

    private func inferredSport(for post: ProgressPost) -> SportFocus? {
        if let tagMatch = post.tags.first(where: { tag in
            SportFocus.allCases.contains { $0.rawValue.lowercased() == tag.lowercased() }
        }) {
            return SportFocus.allCases.first(where: { $0.rawValue.lowercased() == tagMatch.lowercased() })
        }

        switch post.author {
        case "Coach Marcus", "Lucas":
            return .boxing
        case "Maya":
            return .soccer
        case "Chris":
            return .basketball
        default:
            return nil
        }
    }

    private static func rebuiltWorkoutConsistency(from logs: [WorkoutLog], athleteID: UUID) -> [WeeklyWorkoutCount] {
        let calendar = Calendar.current
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"

        let startOfCurrentWeek = calendar.dateInterval(of: .weekOfYear, for: .now)?.start ?? .now
        let athleteLogs = logs.filter { $0.athleteID == athleteID }

        return stride(from: 3, through: 0, by: -1).map { offset in
            let weekStart = calendar.date(byAdding: .weekOfYear, value: -offset, to: startOfCurrentWeek) ?? startOfCurrentWeek
            let label: String
            switch offset {
            case 0:
                label = "This week"
            case 1:
                label = "Last week"
            default:
                label = formatter.string(from: weekStart)
            }

            let count = athleteLogs.filter {
                calendar.isDate($0.completedAt, equalTo: weekStart, toGranularity: .weekOfYear)
            }.count

            return WeeklyWorkoutCount(week: label, workouts: count)
        }
    }

    private static func currentWorkoutStreak(from logs: [WorkoutLog]) -> Int {
        let calendar = Calendar.current
        let uniqueDays = Array(Set(logs.map { calendar.startOfDay(for: $0.completedAt) })).sorted(by: >)

        guard let latestDay = uniqueDays.first else { return 0 }
        guard calendar.isDateInToday(latestDay) || calendar.isDateInYesterday(latestDay) else { return 0 }

        var streak = 1
        var expectedDay = latestDay

        for day in uniqueDays.dropFirst() {
            guard let previousDay = calendar.date(byAdding: .day, value: -1, to: expectedDay) else { break }
            if calendar.isDate(day, inSameDayAs: previousDay) {
                streak += 1
                expectedDay = day
            } else {
                break
            }
        }

        return streak
    }

    private func showCelebration(title: String, detail: String, symbol: String) {
        celebration = CelebrationMoment(title: title, detail: detail, symbol: symbol)
        Task {
            try? await Task.sleep(for: .seconds(1.5))
            if self.celebration?.title == title {
                self.celebration = nil
            }
        }
    }

    private func showToast(_ message: String) {
        toastMessage = message
        Task {
            try? await Task.sleep(for: .seconds(2))
            if self.toastMessage == message {
                self.toastMessage = nil
            }
        }
    }
}
