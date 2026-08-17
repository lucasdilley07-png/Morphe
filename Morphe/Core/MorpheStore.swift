import SwiftUI
import Observation
import UserNotifications
import WidgetKit

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
    /// Held-at-the-gate state: the cloud pull FAILED (network, not
    /// no-backup) for a signed-in account with no local profile. RootView
    /// shows a retry surface; proceeding to onboarding could overwrite a
    /// real backup with a fresh profile (launch audit P0-1).
    var cloudRestoreBlocked = false

    /// The retry the blocked surface calls.
    func retryCloudRestore() async {
        await restoreFromCloud()
    }

    var selectedCoachTab: CoachTab = .dashboard {
        didSet {
            // Clamp to MOUNTED tabs: .athletes and (flag-off) .network have
            // no page in the TabView — landing there was a blank screen
            // with no dock selection (coach audit). Athletes' roster tools
            // live in Build; social routing falls back to Messages.
            guard !CoachTab.visibleCases.contains(selectedCoachTab) else { return }
            selectedCoachTab = selectedCoachTab == .athletes ? .programs : .messages
        }
    }
    /// Light/dark appearance — device-level (not per-profile: the person
    /// holding the phone picks how it looks). Flips the whole token system.
    var appearanceIsLight = UserDefaults.standard.bool(forKey: "morphe.appearance.light") {
        didSet {
            MorpheTheme.isLight = appearanceIsLight
            UserDefaults.standard.set(appearanceIsLight, forKey: "morphe.appearance.light")
        }
    }

    var selectedAppearance: ColorScheme? { appearanceIsLight ? .light : .dark }
    var toastMessage: String?
    var celebration: CelebrationMoment?
    /// The full-screen stamp — only PRs and finished programs land here;
    /// everything else stays on the small `celebration` banner.
    var recordStamp: RecordStampMoment?

    var isShowingLaunchSequence = true
    var hasCompletedOnboarding = false
    var onboardingDraft = OnboardingDraft()
    var showWelcomeExperience = false
    var showClientProfile = false
    var showUniversalSearch = false
    var showQuickAdd = false
    /// Ask-Morphe from inside the QuickAdd sheet: the AI cover opens from
    /// the sheet's onDismiss completion, not a guessed timer.
    var pendingAIAgentOpen = false
    var showAIAgent = false
    /// Set by the coach Quick Add grid; the Build tab's client roster observes
    /// it to present AddManagedClientSheet (a real client, not a fake lead).
    var requestAddClientSheet = false
    /// Pop-up shown when Switch has nothing to rotate to (no saved workouts,
    /// or the only saved workout is already staged).
    var showSwitchNeedsSavedWorkouts = false
    var selectedNetworkProfile: NetworkProfilePreview?
    /// Set by a PR-timeline row tap: the Strength Over Time card adopts
    /// this exercise and Progress scrolls to it, then clears it. The PR
    /// list and the trend chart are the same data — they should connect.
    var focusedStrengthExercise: String?

    /// Load lifecycle for a fetched surface. Empty copy renders ONLY in a
    /// loaded state — an empty screen during a fetch is a lie, and a
    /// network failure the user can't see or retry is a dead end.
    enum FetchState: Equatable {
        case idle, loading, loaded, failed
    }
    var feedFetchState: FetchState = .idle
    var leaderboardFetchState: FetchState = .idle
    var challengesFetchState: FetchState = .idle
    // A tab named "Learn" opens to learning, not to a scoreboard.
    var selectedHubFeature: ClientHubFeature? = .learn
    var selectedCommunitySection: ClientCommunitySection = FeatureFlags.socialFeedEnabled ? .forYou : .contact
    var selectedCoachBuildSection: CoachBuildSection = .builder
    var quickCaptureNotes: [String] = []

    var clientProfile: ClientProfile
    var profileShowcase: ProfileShowcase
    var todayTasks: [TaskItem]
    var minimumWinTasks: [TaskItem]
    var minimumWinModeEnabled = false
    var minimumWinMessage = "Today does not need to be perfect. Complete one small win to keep momentum."
    var streakProtected = false
    /// Calendar-day key ("2026-07-05") of the last daily reset. Persisted so a
    /// same-day relaunch keeps today's completed tasks, and compared on every
    /// foreground so a night in the app switcher can't freeze "today".
    private(set) var lastDailyResetDay = ""
    /// Days the user protected with a minimum win instead of a full session.
    /// Persisted; these count as on-schedule days in the streak computation.
    private(set) var protectedDayKeys: Set<String> = []
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
    /// People connected via QR scan (both roles). Mutual rosters/messaging
    /// arrive when the backend links the two accounts.
    var scannedConnections: [ScannedConnection] = []
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

    /// The personalized daily-plan rotation (catalog workout ids), rebuilt
    /// deterministically from the user's level + equipment and sequenced by
    /// focus so consecutive days differ. Empty until onboarding / catalog load;
    /// staging then falls back to the seeded templates.
    var personalizedPlanIDs: [UUID] = []
    /// Which entry of the rotation is staged as today's workout. Advances each
    /// new day while the user is still following the auto-plan.
    var planDayIndex: Int = 0
    /// Saved-from-Discover ids restored from disk, reapplied after demo clears.
    private var persistedSavedCatalogIDs: [String] = []
    private var persistedSavedTemplates: [SavedTemplateSnapshot] = []
    private var persistedPinnedCatalogIDs: [String] = []
    var savedWorkouts: [SavedWorkoutLibraryItem]
    var currentWorkoutID: UUID { didSet { persistWorkoutSession() } }
    var workoutLogs: [WorkoutLog] {
        didSet {
            workoutPersistence.saveLogs(workoutLogs)
            // Mirror to the cloud only for a real, onboarded account — never the
            // pre-onboarding demo seed. Trailing-debounced (READINESS-300 R5):
            // the push uploads the FULL history doc, and a finish flow mutates
            // logs several times in a burst — one upload covers all of them.
            // The local file above is written synchronously either way, so a
            // kill inside the window loses nothing; the next mutation pushes.
            guard hasCompletedOnboarding, !suppressLogCloudPush else { return }
            logPushDebounce?.cancel()
            logPushDebounce = Task { [weak self] in
                // 60s: each flush rewrites the WHOLE history doc, and sets
                // land minutes apart mid-workout — 8s made every set its
                // own full-history upload (1000-user audit #8). Backup
                // still lands within a minute of the last change, and
                // sign-out/foreground-exit flush immediately.
                try? await Task.sleep(nanoseconds: 60_000_000_000)
                guard !Task.isCancelled, let self else { return }
                await self.flushLogBackupNow()
            }
        }
    }
    private var logPushDebounce: Task<Void, Never>?
    /// True while a cloud restore writes logs — pulled data must not echo
    /// straight back up as a fresh push.
    private var suppressLogCloudPush = false

    // MARK: Backup health (surfaced, not silent)
    //
    // The history upload used to be fire-and-forget: a failed push meant
    // cloud backup silently stopped and the user never knew. Now every
    // push reports, failures show in Profile, and a bounded retry ladder
    // (30s → 2m → 5m) runs before giving up until the next change or a
    // manual Back Up Now.

    enum LogBackupState: Equatable {
        case idle
        case current(Date)
        case behind
    }
    private(set) var logBackupState: LogBackupState = .idle
    /// Firestore's hard document cap is 1 MiB — flips at ~800 KB so the
    /// warning shows well before writes start failing outright.
    private(set) var logBackupNearLimit = false
    private var logPushRetryCount = 0

    /// A real signed-in backup target exists (inert/no-op doesn't count).
    var cloudBackupActive: Bool {
        !(cloudBackup is NoOpCloudBackup) && authUser != nil
    }

    /// Profile's "Back Up Now": skip the debounce, push immediately.
    func requestImmediateLogBackup() {
        logPushDebounce?.cancel()
        Task { await flushLogBackupNow() }
    }

    func flushLogBackupNow() async {
        guard hasCompletedOnboarding else { return }
        let logs = workoutLogs
        if let data = try? JSONEncoder().encode(logs) {
            logBackupNearLimit = data.count > 800_000
        }
        if await cloudBackup.pushLogs(logs) {
            logBackupState = cloudBackupActive ? .current(.now) : .idle
            logPushRetryCount = 0
        } else {
            logBackupState = .behind
            guard logPushRetryCount < 3 else { return }
            let delaySeconds: UInt64 = [30, 120, 300][logPushRetryCount]
            logPushRetryCount += 1
            logPushDebounce = Task { [weak self] in
                try? await Task.sleep(nanoseconds: delaySeconds * 1_000_000_000)
                guard !Task.isCancelled, let self else { return }
                await self.flushLogBackupNow()
            }
        }
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
    var activeWorkoutExerciseIndex = 0 {
        didSet {
            persistWorkoutSession()
            // Buddies watching a virtual session see the move immediately.
            publishPartyProgress()
        }
    }
    var completedWorkoutSets: [String: Int] = [:] { didSet { persistWorkoutSession() } }
    var trackedSetReps: [String: [Int]] = [:] { didSet { persistWorkoutSession() } }
    var trackedSetWeights: [String: [Double]] = [:] { didSet { persistWorkoutSession() } }
    /// Per-set RPE (6–10), parallel to trackedSetReps; 0 = not rated.
    var trackedSetRPE: [String: [Int]] = [:] { didSet { persistWorkoutSession() } }
    /// Per-set style label, parallel to trackedSetReps ("" = standard set;
    /// e.g. "Dropset 80×8 → 60×6" or "Superset + Push-Up ×12"). A superset
    /// or dropset counts as ONE set, with its sub-work described here.
    var trackedSetLabels: [String: [String]] = [:] { didSet { persistWorkoutSession() } }
    var trackedSetWarmups: [String: [Bool]] = [:] { didSet { persistWorkoutSession() } }
    /// Session-scoped superset pairs, stored BOTH directions (A1→A2 and
    /// A2→A1). The template never changes; the pairing dies with the session.
    var supersetPartners: [String: String] = [:] { didSet { persistWorkoutSession() } }
    /// Unsaved draft from the custom set logger, per exercise id — everything
    /// typed into the "More" sheet survives dismissal and app relaunch.
    var pendingSetDrafts: [String: PendingSetDraft] = [:] { didSet { persistWorkoutSession() } }
    /// When the live session actually began, so logs carry time trained —
    /// not the template's advertised length.
    var workoutSessionStartedAt: Date? { didSet { persistWorkoutSession() } }
    /// Elapsed minutes captured at finish (clamped 1min–8h); nil = no live
    /// session timing, fall back to the template's planned duration.
    var completedSessionMinutes: Int? { didSet { persistWorkoutSession() } }
    /// Optional free-text the user adds on the recap — appended to the
    /// log's notes at commit, cleared with the session either way.
    var sessionUserNote: String = ""
    var weightUnit: WeightUnit = .pounds {
        didSet {
            // The console's memoized "LAST:" lines are formatted in the
            // OLD unit — clear on switch (post-revamp audit P2-6).
            consoleHistoryCache = [:]
            topWeightCache = [:]
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
    /// Auth provider. The real app injects `FirebaseAuthService`; tests and
    /// previews fall back to the on-device `LocalAuthService` default.
    private let authService: AuthService
    /// Cloud backup for profile + logs. Real app injects `FirebaseCloudBackup`;
    /// the no-op default keeps the store offline-only for tests/previews.
    private let cloudBackup: CloudBackingUp
    /// Train Together sessions. Real app injects `FirebasePartyService`; the
    /// no-op default keeps tests/previews off the network.
    private let partyService: WorkoutPartying
    /// Global username uniqueness. Real app injects
    /// `FirebaseUsernameDirectory`; the no-op default claims everything so
    /// tests/previews stay offline.
    private let usernameDirectory: UsernameDirectoryService
    /// Coach-created client profiles + claim handoff. Real app injects
    /// `FirebaseManagedClientService`; no-op default for tests/previews.
    private let managedClientService: ManagedClientSyncing
    /// Verification requests + badge status. Real app injects
    /// `FirebaseVerificationService`; no-op default for tests/previews.
    private let verificationService: VerificationSyncing
    /// Personal appointments (one Firestore doc each). Real app injects
    /// `FirebaseAppointmentService`; no-op default for tests/previews.
    private let appointmentService: AppointmentSyncing
    private let telemetryService: TelemetrySyncing
    private let referralService: ReferralSyncing
    /// Weekly leaderboard + challenges. Resolved in `init` (injected, or
    /// inferred Firebase/no-op alongside the party service).
    private let leaderboardService: LeaderboardSyncing
    /// Real 1:1 coach↔claimed-client messaging. Resolved in `init` (injected,
    /// or inferred Firebase/no-op alongside the party service — same pattern
    /// as `leaderboardService`, so MorpheApp.swift needs no change).
    private let messagingService: MessagingSyncing
    /// Real community feed (posts, reactions, saves). Resolved in `init`
    /// (injected, or inferred Firebase/no-op alongside the party service —
    /// same pattern as `messagingService`, so MorpheApp.swift needs no change).
    private let feedService: FeedSyncing
    /// Server-granted verified badge (users/{uid}.verified) — local mirror,
    /// refreshed on launch/sign-in. The client can never set the source.
    var isVerifiedUser = false
    /// Where the user's verification request stands (drives the profile card).
    var verificationRequestStatus: VerificationRequestStatus = .none
    var isSubmittingVerification = false
    /// Client profiles this coach created for people not on Morphe yet.
    var managedClients: [ManagedClient] = []
    // MARK: Real messaging state (coach ↔ claimed client)
    /// REAL Firestore threads this account participates in (either role),
    /// newest first. Distinct from the flag-gated demo `messageThreads` /
    /// `athleteMessageThreads` on purpose. Empty = no claimed link yet, and
    /// the athlete home renders no messaging surface at all.
    var liveThreads: [MessageThreadSummary] = []
    /// The open thread's messages, streamed live while a thread is open.
    var activeThreadMessages: [ChatMessage] = []
    /// The currently open real thread, or nil when none is open.
    var activeThreadId: String?
    // MARK: Real community feed state
    /// REAL Firestore posts (newest first) as last fetched — the For You
    /// surface. Distinct from the flag-gated demo `communityPosts` on purpose.
    var feedPosts: [FeedPost] = []
    /// Post ids this account bookmarked (users/{uid}/savedPosts mirror).
    var savedPostIds: Set<String> = []
    /// Real reaction counts per post id, from server-side count() aggregation.
    var feedReactionCounts: [String: Int] = [:]
    /// Posts THIS session reacted to — tracked locally per session (kept
    /// simple on purpose: no per-post own-reaction fetch; the server doc is
    /// still one-per-uid, so honesty holds regardless).
    var myReactedPostIds: Set<String> = []
    /// Which reaction type ("heart"/"fire"/"power"/"clap") this session
    /// picked per post — presence in `myReactedPostIds` is the truth of
    /// "reacted"; this only remembers which flavor.
    var myReactionTypes: [String: String] = [:]
    /// Comments per post id, fetched on expand. A MISSING key means "not
    /// fetched yet", never "zero comments" — the UI must not fake a count.
    var postComments: [String: [PostComment]] = [:]
    /// Uids this account follows (users/{uid}/following mirror) — loaded
    /// with the feed, drives the Following filter.
    var followedUids: Set<String> = []
    /// Find Athletes search hits (username directory prefix scan).
    var athleteSearchResults: [AthleteSearchResult] = []
    /// Blocked accounts (uid → display name at block time) — mirror of
    /// users/{uid}/blocked. A blocked author never renders: their posts,
    /// comments, and search hits all filter through this set.
    var blockedAccounts: [String: String] = [:]
    var blockedUids: Set<String> { Set(blockedAccounts.keys) }
    /// The user's REAL personal schedule (kept sorted by date). Lives in
    /// memory + the Firestore offline cache only — deliberately no file
    /// persistence: each appointment is its own users/{uid}/appointments doc,
    /// so Firestore's local cache IS the offline store here, and a second
    /// on-disk copy would just be a divergence risk.
    var appointments: [Appointment] = []
    // MARK: Weekly board + challenges state
    /// This week's board as last FETCHED (top 50, score-desc) — real Firestore
    /// rows written by real accounts, never seeded. Empty until refreshed.
    var weeklyLeaderboard: [WeeklyLeaderboardEntry] = []
    /// The user's own entry as last fetched — present even when they sit
    /// outside the fetched top 50 (their honest "you posted" proof).
    var weeklyLeaderboardSelfEntry: WeeklyLeaderboardEntry?
    /// Weekly-board opt-in. Persisted in UserDefaults (documented exception —
    /// see `loadCompetitionState`).
    /// Master switch for every scheduled reminder (training nudge, streak
    /// risk, recap, board, appointments). The audit found five reminder
    /// kinds and zero ways to opt out in-app.
    var remindersEnabled = true {
        didSet {
            guard !isLoadingTrainingPreferences else { return }
            persistTrainingPreferences()
            if remindersEnabled {
                refreshDailyTrainingReminder()
            } else {
                UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
            }
        }
    }
    var leaderboardOptIn = false {
        didSet { persistCompetitionState() }
    }
    /// Auto-starts the rest countdown each time a set is logged, seeded from
    /// the exercise's own rest length. Persisted in UserDefaults (same
    /// documented exception as the competition state).
    var autoRestTimerEnabled = true {
        didSet { persistTrainingPreferences() }
    }
    /// Effort display scale: false = RPE (default), true = RIR. Stored
    /// values stay RPE internally — RIR is a view (RIR = 10 − RPE), so
    /// flipping the preference never rewrites history.
    var effortScaleRIR = false {
        didSet { persistTrainingPreferences() }
    }
    /// Network identity controls: what rides YOUR posts. Both on by
    /// default; both purely subtractive — turning them off shares less,
    /// never fabricates more.
    var postStreakByline = true {
        didSet { persistTrainingPreferences() }
    }
    var postAccentIdentity = true {
        didSet { persistTrainingPreferences() }
    }
    /// Weekday numbers (Calendar 1=Sun…7=Sat) the user plans to train.
    /// EMPTY = feature off (every day shows the workout hero, as before).
    var trainingDays: Set<Int> = [] {
        didSet { persistTrainingPreferences(); refreshDailyTrainingReminder() }
    }

    /// A planned rest day: the user picked training days and today isn't
    /// one — and nothing's logged yet (a logged rest day is a training
    /// day in every way that matters).
    func plannedRestDay(on date: Date = .now, calendar: Calendar = .current) -> Bool {
        guard !trainingDays.isEmpty else { return false }
        return !trainingDays.contains(calendar.component(.weekday, from: date))
    }
    var isPlannedRestDay: Bool { plannedRestDay() && !isWorkoutLoggedToday }
    /// Global opt-in for auto-posting finished sessions to the real feed.
    /// Off by default — publishing on the user's behalf is never a surprise.
    var autoShareWorkoutsEnabled = false {
        didSet {
            // While the feed is dark the runtime toggle is forced off, so
            // only a live-feed flip reflects real user intent worth
            // remembering (audit 5, P2: the next unrelated preference
            // write was silently erasing the stored opt-in).
            if FeatureFlags.socialFeedEnabled {
                storedAutoShareOptIn = autoShareWorkoutsEnabled
            }
            persistTrainingPreferences()
        }
    }
    /// The user's persisted auto-share opt-in as last loaded or toggled.
    /// Persisted in place of the (forced-off) runtime value while the feed
    /// is dark, so the opt-in survives until a future feed relight.
    private var storedAutoShareOptIn = false
    /// Per-session share opt-out (the toggle above Log Workout). Re-arms to
    /// true every time a session finishes; never persisted.
    var shareCompletedSessionToFeed = true
    /// Apple Health workout sync — opt-in, write-only. Enable via
    /// `setHealthSync(enabled:)` so the system prompt rides the flip.
    var healthSyncEnabled = false {
        didSet { persistTrainingPreferences() }
    }
    /// Athlete-consented coach visibility (the coachShare doc). Flip via
    /// `setCoachShare(enabled:)` so the push/revoke rides the toggle.
    var coachShareEnabled = false {
        didSet { persistTrainingPreferences() }
    }
    /// The coach this athlete is linked to (captured at claim time, adopted
    /// from the first coach thread as a fallback). Empty = no coach.
    var linkedCoachUid = "" {
        didSet { persistTrainingPreferences() }
    }
    var linkedCoachName = "" {
        didSet { persistTrainingPreferences() }
    }
    /// Coach side: claimed clients' shared summaries by athlete uid, plus
    /// which uids have been fetched (so "not sharing" is a KNOWN state,
    /// never an assumption about an unfetched one).
    var coachShareSummaries: [String: CoachShareSummary] = [:]
    var coachShareFetched: Set<String> = []
    /// Pre-fills the check-in's sleep slider from Apple Health (read-only,
    /// opt-in). Flip via `setHealthSleepPrefill(enabled:)`.
    var healthSleepEnabled = false {
        didSet { persistTrainingPreferences() }
    }
    /// When onboarding finished — drives the day-7 first-week arc, then
    /// goes silent forever.
    var firstWeekStart: Date? {
        didSet { persistTrainingPreferences() }
    }
    /// Coach side: claimed clients hidden from the roster VIEW. The docs
    /// (the athlete's history) are untouched — rules forbid touching them.
    var archivedClientCodes: Set<String> = [] {
        didSet { persistTrainingPreferences() }
    }
    /// Guards the didSets above while `loadTrainingPreferences` restores them.
    private var isLoadingTrainingPreferences = false
    /// Challenges this user hosts or joined, refreshed from Firestore by code.
    /// Membership (the codes) persists in UserDefaults; the data never does.
    var activeChallenges: [ChallengeSummary] = []
    /// Codes of joined challenges — the only competition fact stored locally.
    private var joinedChallengeCodes: [String] = [] {
        didSet { persistCompetitionState() }
    }
    /// Guards the two didSets above while `loadCompetitionState` restores them.
    private var isLoadingCompetitionState = false
    var isCompetitionBusy = false
    /// The signed-in account, or nil when signed out.
    var authUser: AppUser?
    var authErrorMessage: String?
    var isAuthBusy = false
    /// Guards `persistWorkoutSession()` so session `didSet`s triggered while we
    /// restore a saved snapshot in `init` don't immediately re-save it.
    private var isRestoringWorkoutSession = false
    /// Guards profile persistence while a saved profile is being applied at launch.
    private var isApplyingProfile = false

    // MARK: Coalesced persistence
    // One user action used to mean one full encode+atomic-write PER mutated
    // property (completeTrackedSet touches six session dictionaries = seven
    // write cycles per set logged, all on the main actor). The didSet hooks
    // now only mark dirty; a single Task per runloop turn performs the actual
    // encode+save — one write per user action.
    private var needsSessionPersist = false
    private var needsProfilePersist = false
    private var isPersistFlushScheduled = false
    /// Cloud profile pushes are rate-limited — a full Firestore snapshot per
    /// water tap is waste. At most one push per interval, trailing-edge so the
    /// last state in a burst still lands. Onboarding completion and photo
    /// changes bypass the limit via `forceNextProfileCloudPush`.
    private static let profileCloudPushInterval: TimeInterval = 30
    private var lastProfileCloudPushAt: Date = .distantPast
    private var isProfileCloudPushScheduled = false
    private var forceNextProfileCloudPush = false
    /// The live store. A second `MorpheAppStore` in one process only happens in
    /// tests simulating a relaunch — `init` flushes the previous instance's
    /// coalesced writes first, so the "relaunch" reads everything the real app
    /// would have written by that point.
    private static weak var mostRecentInstance: MorpheAppStore?

    init(authService: AuthService = LocalAuthService(),
         cloudBackup: CloudBackingUp = NoOpCloudBackup(),
         partyService: WorkoutPartying = NoOpPartyService(),
         managedClientService: ManagedClientSyncing = NoOpManagedClientService(),
         usernameDirectory: UsernameDirectoryService = NoOpUsernameDirectory(),
         verificationService: VerificationSyncing = NoOpVerificationService(),
         appointmentService: AppointmentSyncing = NoOpAppointmentService(),
         leaderboardService: LeaderboardSyncing? = nil,
         messagingService: MessagingSyncing? = nil,
         feedService: FeedSyncing? = nil,
         telemetryService: TelemetrySyncing? = nil,
         referralService: ReferralSyncing? = nil) {
        // Tests build a second store to simulate a relaunch — land the live
        // store's pending coalesced writes before this instance reads the files.
        Self.mostRecentInstance?.flushPendingPersists()
        self.authService = authService
        self.cloudBackup = cloudBackup
        self.partyService = partyService
        self.managedClientService = managedClientService
        MorpheTheme.isLight = UserDefaults.standard.bool(forKey: "morphe.appearance.light")
        self.usernameDirectory = usernameDirectory
        self.verificationService = verificationService
        self.appointmentService = appointmentService
        // MorpheApp.swift (owned by another work stream) builds the store with
        // the pre-competition parameter list, so nil infers the right service:
        // Firebase alongside a Firebase party service, no-op everywhere else
        // (tests/previews). Tests can still inject a mock explicitly.
        self.leaderboardService = leaderboardService
            ?? (partyService is FirebasePartyService
                ? FirebaseLeaderboardService()
                : NoOpLeaderboardService())
        // Same nil-infers-Firebase pattern as the leaderboard service above:
        // MorpheApp.swift keeps its existing parameter list, tests/previews
        // stay off the network, and mocks can still inject explicitly.
        self.messagingService = messagingService
            ?? (partyService is FirebasePartyService
                ? FirebaseMessagingService()
                : NoOpMessagingService())
        // Same nil-infers-Firebase pattern again for the real community feed.
        self.feedService = feedService
            ?? (partyService is FirebasePartyService
                ? FirebaseFeedService()
                : NoOpFeedService())
        // And for first-party telemetry (write-only measurement events).
        self.telemetryService = telemetryService
            ?? (partyService is FirebasePartyService
                ? FirebaseTelemetryService()
                : NoOpTelemetryService())
        // And for referral receipts (the recruiter-visible join ledger).
        self.referralService = referralService
            ?? (partyService is FirebasePartyService
                ? FirebaseReferralService()
                : NoOpReferralService())
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
        // Index once (speed audit S1-3): the per-workout linear resolve ran
        // ~61k comparisons on the main actor before the first frame.
        let exerciseIndex = WorkoutCatalog.makeIndex(MorpheDemoContent.exerciseDatabase)
        self.catalogWorkouts = WorkoutCatalog.loadBundled().compactMap {
            WorkoutCatalog.template(from: $0, index: exerciseIndex)
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
            // Honest scope: quick answers and workspace help — not "AI analysis
            // of your coaching data" the rule-based assistant can't deliver.
            ThreadMessage(sender: .ai, senderName: "Morphe AI", text: "Ask me while you coach — quick answers on training, recovery, and getting around your workspace.", timestamp: "Now")
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

        MorpheTheme.apply(accentPalette: profileShowcase.accentPalette, customHex: profileShowcase.customAccentHex)

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
        if let authUser {
            selectedRole = authUser.role.appRole
            // Keep the onboarding draft's role in sync on relaunch too, so a
            // signed-in-but-not-onboarded coach resumes the coach flow.
            onboardingDraft.accountType = authUser.role.appRole
            // Key cloud writes to the already-signed-in user so local saves this
            // session mirror up. (A full pull happens on an explicit sign-in.)
            cloudBackup.setUser(authUser.id)

            // Session survived but local state didn't (reinstall that kept the
            // keychain, storage cleanup): restore the cloud backup instead of
            // sending an existing account back through onboarding — completing
            // it again would overwrite their backup with a fresh profile.
            if !hasCompletedOnboarding {
                Task { await restoreFromCloud() }
            }

            // A returning coach's managed roster lives in the cloud — pull it
            // fresh each launch (offline keeps the Firestore cache copy).
            if selectedRole == .coach {
                Task { await refreshManagedClients() }
            }
            // The badge is server-owned; mirror it on every launch.
            Task { await refreshVerificationStatus() }
            // The schedule lives per-doc in the cloud — pull it fresh each
            // launch (offline serves the Firestore cache copy).
            Task { await refreshAppointments() }
            // Real message threads (both roles) — pull fresh each launch,
            // same pattern as the managed roster above.
            Task { await refreshThreads() }
            // The real For You feed — pull fresh each launch too.
            Task { await refreshFeed() }
            // Referral receipts are feed-independent (audit 6, P1-3): a
            // link tapped before sign-in must land even while the feed
            // fetch is gated off, so the consume can't live inside
            // refreshFeed behind the dark-feed guard.
            Task {
                await consumePendingReferral()
                await refreshReferralCount()
            }
        }

        // Same-day relaunch: no-op (daily state was just restored). New day —
        // or first launch ever — starts the daily surfaces fresh.
        handleDayRolloverIfNeeded()

        // Board opt-in + joined challenge codes for the restored profile.
        // (applyPersistedProfile also loads these — this call covers the
        // fresh-install path where no profile snapshot existed yet.)
        loadCompetitionState()
        loadTrainingPreferences()
        reloadPerProfileMirrors()
        // A relaunch on the streak's last allowed rest day re-arms tonight's
        // reminder; a launch after training today clears it. Widgets get the
        // freshest numbers on every launch too. Lapse detection runs here —
        // the one launch-time moment that already owns streak truth.
        refreshStreakRiskReminder()
        refreshWeeklyRecapReminder()
        refreshDailyTrainingReminder()
        detectStreakLapse()
        publishWidgetSnapshot()
        trackDayActiveIfNeeded()

        Self.mostRecentInstance = self
    }

    // MARK: - Auth actions

    func signUp(email: String, password: String, role: UserRole, name: String) async {
        isAuthBusy = true
        authErrorMessage = nil
        defer { isAuthBusy = false }
        do {
            let user = try await authService.signUp(email: email, password: password, role: role, displayName: name)
            applySignedIn(user)
            await restoreFromCloud()
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
            await restoreFromCloud()
        } catch {
            authErrorMessage = (error as? AuthError)?.errorDescription ?? error.localizedDescription
        }
    }

    /// Emails a password-reset link via the auth provider. Success is worded
    /// carefully — with email-enumeration protection on, "sent" only means
    /// "sent if that account exists".
    func requestPasswordReset(email: String) async {
        let trimmed = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            showToast("Enter your email first.")
            return
        }
        do {
            try await authService.sendPasswordReset(email: trimmed)
            showToast("Reset email sent — check your inbox.")
        } catch {
            showToast((error as? AuthError)?.errorDescription ?? error.localizedDescription)
        }
    }

    func signOut() {
        authService.signOut()
        cloudBackup.setUser(nil)
        authUser = nil
        // Another account on this device must never see this coach's roster.
        managedClients = []
        // Same cross-account rule for the personal schedule.
        appointments = []
        // The badge belongs to the signed-out account, not the device.
        isVerifiedUser = false
        verificationRequestStatus = .none
        // Fetched competition data belongs to the signed-out account too.
        // (Opt-in + joined codes stay in their per-profile defaults keys.)
        weeklyLeaderboard = []
        weeklyLeaderboardSelfEntry = nil
        activeChallenges = []
        // Real message threads belong to the signed-out account — stop the
        // listener and drop every trace before another account signs in.
        closeThread()
        liveThreads = []
        // The fetched feed, bookmarks, and reaction state too.
        feedPosts = []
        presencePosts = []
        savedPostIds = []
        feedReactionCounts = [:]
        myReactedPostIds = []
        reactionStateFetchedIds = []
        lastFeedRefreshAt = nil
        feedPageCursor = nil
        // Backup health belongs to the signed-out account.
        logBackupState = .idle
        logBackupNearLimit = false
        logPushRetryCount = 0
        // AI transcripts too (audit find): replies interpolate the signed-
        // out user's real score/goals — the next account must not read
        // them. Back to the seeded greeting, same as a fresh chat.
        athleteAIAgentConversation = [athleteAIAgentConversation.first].compactMap { $0 }
        coachAIAgentConversation = [coachAIAgentConversation.first].compactMap { $0 }
        // The rest of the fetched social/coach state follows the same
        // "another account must never see it" rule.
        myReactionTypes = [:]
        postComments = [:]
        followedUids = []
        blockedAccounts = [:]
        athleteSearchResults = []
        coachShareSummaries = [:]
        coachShareFetched = []
        // Session fetch gates reset with the identity.
        lastThreadsRefreshAt = nil
        lastPresenceRefreshAt = nil
        membershipSetsFetched = false
        coachAssignments = []
        lastAssignmentsFetchAt = nil
        cloudRestoreBlocked = false
        threadReadCache = nil

        // FULL local wipe (launch audit P0): sign-out must leave the device
        // as clean as account deletion does. Without this, the NEXT account
        // to sign up on this phone skipped onboarding (the flag stayed
        // true) and inherited this user's name, logs, streak, and photo —
        // then pushed them into their OWN cloud backup. The cloud copy is
        // the durable record; "signing back in restores everything" is the
        // promise, and it still holds through restoreFromCloud.
        logPushDebounce?.cancel()
        extrasPushDebounce?.cancel()
        workoutPersistence.clear()
        profilePersistence.clear()
        profilePersistence.clearPhoto()
        profilePhotoData = nil
        // Onboarding must run for whoever signs in next (a returning
        // account restores past it; a new one builds a fresh identity —
        // completeOnboarding stamps a new profile id via resetToFreshUser).
        hasCompletedOnboarding = false
        // AFTER the flag flip so the didSet mirror is a guarded no-op.
        workoutLogs = []
        for key in [trainingPreferencesDefaultsKey, competitionStateDefaultsKey,
                    bodyWeightHistoryDefaultsKey, recoverySeriesDefaultsKey,
                    nutritionSeriesDefaultsKey, activeProgramDefaultsKey,
                    programCompletionsDefaultsKey, libraryFoldersKey,
                    // Seen/read markers are per-profile too — leaving them
                    // let the NEXT account inherit this one's read state
                    // (launch audit P2-18). Cosmetic to lose on a device
                    // switch, wrong to share across accounts.
                    threadReadKey, activitySeenKey, storySeenKey,
                    lastKnownStreakKey, comebackPendingKey] {
            UserDefaults.standard.removeObject(forKey: key)
        }
        purgeConversationalDefaults()
        loadTrainingPreferences()
        loadCompetitionState()
        reloadPerProfileMirrors()
    }

    /// Permanently deletes the account (App Store 5.1.1(v)): cloud backup
    /// docs, the coachShare doc, the @username claim, the users/{uid} root
    /// doc, and the Auth user — then wipes this device's local copy and
    /// lands on the sign-in screen. Content published to SHARED surfaces
    /// (posts, comments, messages) is not mass-deleted here; the confirm
    /// dialog discloses that, and own-posts can be deleted first.
    /// Returns false when Firebase demands a fresh sign-in.
    func deleteAccount() async -> Bool {
        guard let uid = authUser?.id else { return false }

        // Server cleanup FIRST, while the auth session is still valid —
        // after user.delete() the rules see an anonymous caller.
        await cloudBackup.eraseUser()
        managedClientService.clearCoachShare(athleteUid: uid)
        let username = selectedRole == .coach ? coachProfile.username : profileShowcase.username
        if !username.isEmpty {
            await usernameDirectory.release(username, for: uid)
        }

        // Recorded BEFORE the auth user disappears — churn you can't see
        // is churn you can't learn from. Then the whole event trail is
        // erased with the account, as the policy promises. (Yes, that
        // erases this event too — the policy outranks the metric.)
        track("account_deleted")
        await telemetryService.eraseAll(uid: uid)
        // Referral receipts this account wrote into recruiters' ledgers —
        // erased with the account, same promise as telemetry.
        await referralService.eraseReceipts(
            referredUid: uid,
            recruiterUids: UserDefaults.standard.stringArray(forKey: Self.referralWrittenKey(uid)) ?? []
        )
        UserDefaults.standard.removeObject(forKey: Self.referralWrittenKey(uid))
        UserDefaults.standard.removeObject(forKey: Self.referralCountKey(uid))
        referralCount = 0
        do {
            try await authService.deleteAccount()
        } catch {
            showToast((error as? AuthError)?.errorDescription
                ?? "Couldn't delete the account — check your connection and retry.")
            return false
        }

        // Local wipe: per-profile defaults, files, and in-memory state.
        for key in [trainingPreferencesDefaultsKey, competitionStateDefaultsKey,
                    bodyWeightHistoryDefaultsKey, recoverySeriesDefaultsKey,
                    nutritionSeriesDefaultsKey, activeProgramDefaultsKey,
                    programCompletionsDefaultsKey, libraryFoldersKey,
                    Self.pendingReferralKey] {
            UserDefaults.standard.removeObject(forKey: key)
        }
        purgeConversationalDefaults()
        workoutPersistence.clear()
        profilePersistence.clear()
        // signOut BEFORE clearing logs: the workoutLogs didSet mirrors to
        // the cloud for signed-in accounts, and the account is gone.
        signOut()
        workoutLogs = []
        hasCompletedOnboarding = false
        loadTrainingPreferences()
        loadCompetitionState()
        reloadPerProfileMirrors()
        showToast("Account deleted. Everything tied to it is gone from this device.")
        return true
    }

    /// Lands on the Train surface for the CURRENT role. The coach workspace
    /// has its own Train tab — writing only the athlete tab there would
    /// navigate somewhere the coach can't see.
    func showTrainTab() {
        if selectedRole == .coach {
            selectedCoachTab = .train
        } else {
            selectedClientTab = ClientTab.train
        }
    }

    // MARK: - Tab pop-to-root

    /// Bumped per tab id every time its bottom-bar icon is tapped. Screens key
    /// their identity off this, so tapping a tab icon rebuilds that tab at its
    /// root — scrolled to the top, drill-ins closed, searches cleared.
    private(set) var tabResetCounts: [String: Int] = [:]

    func popTabToRoot(_ id: String) {
        tabResetCounts[id, default: 0] += 1
    }

    func tabResetKey(_ id: String) -> String {
        "\(id)-\(tabResetCounts[id, default: 0])"
    }

    // MARK: - Switch workout → My Library

    /// True when My Library holds anything — saved Discover workouts or
    /// workouts the user built themselves.
    var libraryHasWorkouts: Bool {
        !savedWorkouts.isEmpty || workoutTemplates.contains { isCustomWorkout($0.id) }
    }

    /// One-shot signal: Train should expand My Library and scroll to it.
    var pendingLibraryReveal = false

    /// "Switch workout" on the Today or Train hero. With workouts in the
    /// library it lands on Train's My Library; with an empty library it
    /// returns false so the caller can explain where workouts come from.
    @discardableResult
    func requestWorkoutSwitch() -> Bool {
        guard libraryHasWorkouts else { return false }
        pendingLibraryReveal = true
        showTrainTab()
        Haptics.impact(.light)
        return true
    }

    /// Lands on the Discover surface for the CURRENT role.
    enum TrainSection { case session, discover }
    /// Discover is a SEGMENT of Train now (5-tab fold) — this is the
    /// selection every old "open Discover" door routes through.
    var selectedTrainSection: TrainSection = .session

    func showDiscoverTab() {
        if selectedRole == .coach {
            selectedCoachTab = .discover
        } else {
            selectedClientTab = .train
            selectedTrainSection = .discover
        }
        Haptics.impact(.light)
    }

    // MARK: - QR connect

    /// Payload encoded into this user's Morphe connect code.
    var qrConnectPayload: String {
        var components = URLComponents()
        components.scheme = "morphe"
        components.host = "connect"
        components.queryItems = [
            URLQueryItem(name: "id", value: authUser?.id ?? clientProfile.id.uuidString),
            URLQueryItem(name: "name", value: selectedRole == .coach ? coachProfile.name : clientProfile.name),
            URLQueryItem(name: "handle", value: selectedRole == .coach ? coachProfile.username : profileShowcase.username),
            URLQueryItem(name: "role", value: selectedRole == .coach ? "coach" : "athlete")
        ]
        return components.string ?? "morphe://connect"
    }

    /// Records a scanned Morphe connect code. Returns the connection when the
    /// payload is a valid code (and not the user's own), nil otherwise.
    @discardableResult
    func recordScannedConnection(from payload: String) -> ScannedConnection? {
        guard let components = URLComponents(string: payload),
              components.scheme == "morphe", components.host == "connect" else { return nil }
        func value(_ name: String) -> String {
            components.queryItems?.first(where: { $0.name == name })?.value ?? ""
        }
        let id = value("id")
        guard !id.isEmpty else { return nil }
        let ownID = authUser?.id ?? clientProfile.id.uuidString
        guard id != ownID else { return nil }
        let connection = ScannedConnection(
            id: id,
            name: value("name").isEmpty ? "Morphe user" : value("name"),
            handle: value("handle"),
            role: value("role").isEmpty ? "athlete" : value("role"),
            scannedAt: Date()
        )
        // Re-scanning someone refreshes their entry instead of duplicating it.
        scannedConnections.removeAll { $0.id == connection.id }
        scannedConnections.insert(connection, at: 0)
        persistLocalProfile()
        Haptics.impact(.medium)
        showToast("Connected: \(connection.name)")
        return connection
    }

    // MARK: - Identity: username + name change rules, terms of use

    /// Renames are rate-limited: name and username each change at most once
    /// every 14 days.
    static let identityChangeCooldown: TimeInterval = 14 * 24 * 60 * 60

    /// Epoch seconds of the last post-onboarding change (0 = never changed,
    /// so the first edit is always free).
    var nameChangedAtEpoch: Double = 0
    var usernameChangedAtEpoch: Double = 0

    /// Terms of use: accepted once, remembered forever (locally + cloud).
    var hasAcceptedTerms = false
    /// The welcome celebration queued by onboarding waits behind the terms
    /// gate instead of racing it.
    private var welcomeAwaitsTermsAcceptance = false

    /// The terms gate shows for any signed-in, onboarded account that hasn't
    /// accepted yet — including every reopen until they do.
    var needsTermsAcceptance: Bool {
        hasCompletedOnboarding && !hasAcceptedTerms
            && (!FeatureFlags.accountsEnabled || authUser != nil)
    }

    func acceptTerms() {
        hasAcceptedTerms = true
        if welcomeAwaitsTermsAcceptance {
            welcomeAwaitsTermsAcceptance = false
            showWelcomeExperience = true
        }
        persistLocalProfile()
        Haptics.success()
    }

    /// Declining means no app: sign the account out. The gate returns on the
    /// next sign-in and keeps returning until they agree.
    func declineTerms() {
        welcomeAwaitsTermsAcceptance = false
        signOut()
        showToast("You need to accept the terms to use Morphe.")
    }

    private func nextAllowedChange(after epoch: Double) -> Date? {
        guard epoch > 0 else { return nil }
        let next = Date(timeIntervalSince1970: epoch).addingTimeInterval(Self.identityChangeCooldown)
        return next > .now ? next : nil
    }

    /// Non-nil = locked until that date.
    var nextNameChangeDate: Date? { nextAllowedChange(after: nameChangedAtEpoch) }
    var nextUsernameChangeDate: Date? { nextAllowedChange(after: usernameChangedAtEpoch) }

    /// Onboarding: validates and RESERVES the username in the directory (the
    /// availability check and the claim are one transaction, so two people
    /// racing for a name can't both pass). Returns nil on success, or the
    /// message to show.
    func checkAndReserveUsername(_ raw: String) async -> String? {
        let name = UsernameRules.normalize(raw)
        if let error = UsernameRules.validationError(name) { return error }
        let uid = authUser?.id ?? clientProfile.id.uuidString
        switch await usernameDirectory.claim(name, for: uid, releasing: nil) {
        case .claimed:
            onboardingDraft.username = name
            return nil
        case .taken:
            return "@\(name) is taken — try another."
        case .failed:
            return "Couldn't check that name — check your connection and try again."
        }
    }

    /// Profile: changes the username (cooldown + validation + atomic claim
    /// that releases the old name).
    @discardableResult
    func changeUsername(to raw: String) async -> Bool {
        if let next = nextUsernameChangeDate {
            showToast("You can change your username again on \(next.formatted(date: .abbreviated, time: .omitted)).")
            return false
        }
        let name = UsernameRules.normalize(raw)
        if let error = UsernameRules.validationError(name) {
            showToast(error)
            return false
        }
        guard name != profileShowcase.username else {
            showToast("That's already your username.")
            return false
        }
        let uid = authUser?.id ?? clientProfile.id.uuidString
        switch await usernameDirectory.claim(name, for: uid, releasing: profileShowcase.username) {
        case .claimed:
            profileShowcase.username = name
            // A coach's workspace identity carries the same handle.
            if selectedRole == .coach { coachProfile.username = name }
            usernameChangedAtEpoch = Date.now.timeIntervalSince1970
            persistLocalProfile()
            showToast("You're @\(name) now.")
            return true
        case .taken:
            showToast("@\(name) is taken — try another.")
            return false
        case .failed:
            showToast("Couldn't update your username — try again.")
            return false
        }
    }

    // MARK: - Train Together (buddy sessions)

    /// The party this user is currently in (nil = training solo).
    var activeParty: WorkoutParty?
    /// True while a create/join round-trip is in flight (drives spinners).
    var isPartyBusy = false
    /// A group class joined while still in the lobby: the workout waits here
    /// until the host starts everyone at once.
    private var pendingPartyTemplate: WorkoutTemplate?

    var isPartyHost: Bool {
        guard let party = activeParty, let uid = authUser?.id else { return false }
        return party.hostID == uid
    }

    /// Everyone in the party except this user.
    var partyBuddies: [PartyParticipant] {
        guard let party = activeParty else { return [] }
        let uid = authUser?.id
        return party.participants.filter { $0.id != uid }
    }

    /// Group-class ranking: everyone (this user included) by total sets
    /// logged. This user's own row is patched with the local live count so
    /// the leaderboard never lags behind their own logging.
    var partyLeaderboard: [PartyParticipant] {
        guard let party = activeParty else { return [] }
        let uid = authUser?.id
        return party.participants
            .map { member in
                var member = member
                if member.id == uid {
                    member.totalSetsDone = max(member.totalSetsDone, completedWorkoutSets.values.reduce(0, +))
                }
                return member
            }
            .sorted { $0.totalSetsDone != $1.totalSetsDone ? $0.totalSetsDone > $1.totalSetsDone : $0.name < $1.name }
    }

    /// Join codes avoid ambiguous characters (0/O, 1/I/L) — they get read
    /// aloud across a gym floor.
    static func makePartyCode() -> String {
        let alphabet = Array("ABCDEFGHJKMNPQRSTUVWXYZ23456789")
        return String((0..<6).map { _ in alphabet.randomElement() ?? "X" })
    }

    /// QR payload a buddy scans to join this party.
    var partyQRPayload: String? {
        guard let party = activeParty else { return nil }
        var components = URLComponents()
        components.scheme = "morphe"
        components.host = "party"
        components.queryItems = [URLQueryItem(name: "code", value: party.id)]
        return components.string
    }

    /// Extracts a join code from a scanned Morphe party QR (nil otherwise).
    static func partyCode(fromScanned payload: String) -> String? {
        guard let components = URLComponents(string: payload),
              components.scheme == "morphe", components.host == "party",
              let code = components.queryItems?.first(where: { $0.name == "code" })?.value,
              !code.isEmpty else { return nil }
        return code
    }

    private var partySelf: PartyParticipant? {
        guard let user = authUser else { return nil }
        return PartyParticipant(
            id: user.id,
            name: clientProfile.name.isEmpty ? user.displayName : clientProfile.name,
            email: user.email,
            isHost: false
        )
    }

    /// Creates a party around the current workout and shares it for joining.
    /// Buddy modes open live (the host starts their own session with the
    /// normal Start button); a group class opens in a lobby the host later
    /// starts for everyone at once.
    @discardableResult
    func startTrainTogether(mode: PartyMode, classTime: Date? = nil) async -> Bool {
        guard var me = partySelf else {
            showToast("Sign in to train together.")
            return false
        }
        guard !isPartyBusy else { return false }
        me.isHost = true
        isPartyBusy = true
        defer { isPartyBusy = false }

        let party = WorkoutParty(
            id: Self.makePartyCode(),
            mode: mode,
            hostID: me.id,
            hostName: me.name,
            workoutName: currentWorkout.name,
            status: mode == .group ? .lobby : .live,
            startsAt: mode == .group ? classTime : nil,
            participants: [me]
        )
        let snapshot = PartyWorkoutSnapshot(template: currentWorkout)
        guard await partyService.createParty(party, host: me, workout: snapshot) else {
            showToast("Couldn't start the session — check your connection.")
            return false
        }
        activeParty = party
        partyIsReadySelf = false
        listenToActiveParty()
        Haptics.success()
        return true
    }

    /// Joins an existing party by code (typed or scanned) and starts the
    /// host's workout on this phone.
    @discardableResult
    func joinParty(code rawCode: String) async -> Bool {
        guard let me = partySelf else {
            showToast("Sign in to train together.")
            return false
        }
        guard !isPartyBusy else { return false }
        let code = rawCode.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard !code.isEmpty else { return false }
        isPartyBusy = true
        defer { isPartyBusy = false }

        guard let (party, workout) = await partyService.fetchParty(code: code) else {
            showToast("No session found for code \(code).")
            return false
        }
        guard await partyService.join(partyID: party.id, participant: me) else {
            showToast("Couldn't join — check your connection.")
            return false
        }

        var joined = party
        joined.participants.removeAll { $0.id == me.id }
        joined.participants.append(me)
        activeParty = joined
        partyIsReadySelf = false
        listenToActiveParty()

        // The host's exact workout, ready to run on this phone.
        let template = workout.makeTemplate()
        if !workoutTemplates.contains(where: { $0.id == template.id }) {
            workoutTemplates.append(template)
        }

        if party.mode == .group, party.status == .lobby {
            // Class hasn't started — hold the workout until the host starts
            // everyone at once (the status listener fires it).
            pendingPartyTemplate = template
            showToast("You're in \(party.hostName)'s class — waiting for the start.")
        } else {
            beginLiveWorkout(template)
            showCelebration(title: "Joined \(party.hostName)'s session", detail: party.workoutName, symbol: "person.2.fill")
        }
        return true
    }

    /// Host-only: starts the class for everyone. Members' status listeners
    /// launch their held workout the moment the flip lands.
    func startGroupClass() {
        guard let party = activeParty, isPartyHost, party.status == .lobby else { return }
        partyService.updateStatus(partyID: party.id, status: .live)
        activeParty?.status = .live
        startTodayWorkout()
        showCelebration(title: "Class started", detail: "\(partyBuddies.count + 1) training \(party.workoutName)", symbol: "person.3.fill")
    }

    /// Leaves the party (and tells the backend, so the buddy's roster updates).
    func leaveParty() {
        guard let party = activeParty else { return }
        partyService.stopListening()
        if let uid = authUser?.id {
            let service = partyService
            Task { await service.leave(partyID: party.id, participantID: uid) }
        }
        activeParty = nil
        partyIsReadySelf = false
        pendingPartyTemplate = nil
        showToast("Left the session.")
    }

    /// Keeps the member roster (and their finish summaries) fresh.
    private func listenToActiveParty() {
        guard let party = activeParty else { return }
        partyService.listen(
            partyID: party.id,
            onStatus: { [weak self] status in
                Task { @MainActor [weak self] in
                    guard let self, self.activeParty?.id == party.id,
                          self.activeParty?.status != status else { return }
                    self.activeParty?.status = status
                    // The host started the class — launch the workout this
                    // phone has been holding since it joined the lobby.
                    if status == .live, !self.isPartyHost,
                       let template = self.pendingPartyTemplate,
                       !self.isWorkoutSessionActive {
                        self.pendingPartyTemplate = nil
                        self.beginLiveWorkout(template)
                        self.showCelebration(title: "Class started", detail: self.activeParty?.workoutName ?? "", symbol: "person.3.fill")
                    }
                }
            },
            onMembers: { [weak self] members in
                Task { @MainActor [weak self] in
                    guard let self, self.activeParty?.id == party.id else { return }
                    let known = Set(self.activeParty?.participants.map(\.id) ?? [])
                    self.activeParty?.participants = members
                    // Announce newly-joined buddies to the host.
                    for member in members where !known.contains(member.id) && member.id != self.authUser?.id {
                        self.showToast("\(member.name) joined the session.")
                        Haptics.success()
                    }
                }
            },
            onNudge: { [weak self] nudge in
                Task { @MainActor [weak self] in
                    guard let self, nudge.fromID != self.authUser?.id else { return }
                    self.showCelebration(title: nudge.emoji, detail: "\(nudge.fromName) is cheering you on", symbol: "hands.clap.fill")
                }
            }
        )
    }

    /// One-line totals published to the party when this user logs the session.
    func partySummaryLine(exercises: Int, sets: Int, minutes: Int) -> String {
        "\(exercises) exercise\(exercises == 1 ? "" : "s") · \(sets) set\(sets == 1 ? "" : "s") · \(minutes) min"
    }

    // MARK: Train Together — live sync (virtual mode)

    /// This user's ready flag, mirrored to buddies before the first set.
    var partyIsReadySelf = false

    /// The two nudges buddies can send each other mid-session.
    static let partyNudgeEmojis = ["🔥", "💪"]

    func markPartyReady() {
        guard let party = activeParty, let uid = authUser?.id else { return }
        partyIsReadySelf = true
        partyService.publishProgress(
            partyID: party.id,
            participantID: uid,
            progress: currentPartyProgress()
        )
        Haptics.success()
        showToast("Your buddy can see you're ready.")
    }

    func sendPartyNudge(_ emoji: String) {
        guard let party = activeParty, let me = partySelf else { return }
        partyService.sendNudge(partyID: party.id, from: me, emoji: emoji)
        Haptics.impact(.medium)
        showToast("Sent \(emoji)")
    }

    /// Where this user is right now, in party terms.
    private func currentPartyProgress() -> PartyProgressUpdate {
        let exercise = isWorkoutSessionActive ? activeWorkoutExercise : nil
        return PartyProgressUpdate(
            exerciseName: exercise?.name ?? "",
            setsDone: exercise.map { completedWorkoutSets[$0.id, default: 0] } ?? 0,
            totalSetsDone: completedWorkoutSets.values.reduce(0, +),
            isReady: partyIsReadySelf,
            isFinished: hasCompletedWorkoutFlow
        )
    }

    /// Mirrors live progress to the party. No-op solo or between sessions,
    /// so the set-logging path stays untouched for solo training.
    func publishPartyProgress() {
        guard let party = activeParty, let uid = authUser?.id,
              isWorkoutSessionActive || hasCompletedWorkoutFlow else { return }
        partyService.publishProgress(
            partyID: party.id,
            participantID: uid,
            progress: currentPartyProgress()
        )
    }

    private func applySignedIn(_ user: AppUser) {
        authUser = user
        cloudBackup.setUser(user.id)
        trackDayActiveIfNeeded()
        selectedRole = user.role.appRole
        // The signed-up role drives onboarding: a coach account gets the coach
        // flow and completeOnboarding stamps the coach workspace identity.
        onboardingDraft.accountType = user.role.appRole
        if !hasCompletedOnboarding, !user.displayName.isEmpty {
            onboardingDraft.name = user.displayName
        }
        if user.role == .coach {
            Task { await refreshManagedClients() }
        }
        Task { await refreshVerificationStatus() }
        Task { await refreshAppointments() }
        Task { await refreshThreads() }
        Task { await refreshCoachAssignments(force: true) }
        // Blocked set BEFORE the inbox can render (post-revamp audit
        // P2-12): the CHATS landing raced the feed's gated fetch.
        Task { [weak self] in
            guard let self, let uid = self.authUser?.id else { return }
            if let blocked = await self.feedService.fetchBlocked(uid: uid) {
                self.blockedAccounts = blocked
            }
        }
        // Forced: a fresh identity must never trust another account's page.
        Task { await refreshFeed(force: true) }
    }

    /// After sign-in, restore the account's cloud backup. A returning user
    /// (cloud holds a completed profile) is restored wholesale — which also
    /// replaces the local demo seed and prevents any cross-account bleed. A
    /// brand-new user has no cloud state and just proceeds through onboarding;
    /// their real data mirrors up afterward via the save hooks.
    private func restoreFromCloud() async {
        let cloud = await cloudBackup.pull()
        // FAILED ≠ EMPTY (launch audit P0-1): when the backend was
        // unreachable we must not proceed as if this account is new —
        // onboarding would mint a fresh profile and OVERWRITE the real
        // backup. Hold the gate; RootView shows a retry surface.
        if cloud.fetchFailed {
            cloudRestoreBlocked = true
            return
        }
        cloudRestoreBlocked = false
        guard let profile = cloud.profile, profile.hasCompletedOnboarding else { return }

        // Logs first, so the derived-state rebuild at the end of
        // applyPersistedProfile (history, streak, score) sees the restored
        // history. Setting workoutLogs also writes them to the local file.
        // The suppress flag stops the didSet from re-uploading what we
        // just downloaded (the pull→push echo, READINESS-300 R5).
        suppressLogCloudPush = true
        workoutLogs = (cloud.logs ?? []).sorted { $0.completedAt > $1.completedAt }
        suppressLogCloudPush = false
        applyPersistedProfile(profile)
        // AFTER applyPersistedProfile: the weight-history defaults key is
        // scoped by profile id, which the restore may have just changed.
        if let weightHistory = cloud.weightHistory {
            applyRestoredWeightHistory(weightHistory)
        }
        // Same ordering rule: the extras keys are profile-id-scoped too.
        if let extras = cloud.extras {
            applyRestoredExtras(extras)
        }
        // The photo rides the cloud snapshot as base64 but lives locally as
        // its own file — decode it back out and keep the local JSON photo-free.
        if !profile.profilePhotoBase64.isEmpty,
           let photo = Data(base64Encoded: profile.profilePhotoBase64) {
            profilePersistence.savePhoto(photo)
        } else {
            // A cloud identity WITHOUT a photo must not adopt whatever
            // photo file a previous account left on this disk (launch
            // audit P0): the cloud snapshot is the whole truth here.
            profilePersistence.clearPhoto()
            profilePhotoData = nil
        }
        var localProfile = profile
        localProfile.profilePhotoBase64 = ""
        profilePersistence.saveProfile(localProfile)
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

        // A returning coach gets THEIR identity in the workspace header, built
        // from the snapshot's own sports/goals (not clientProfile, which may
        // still hold the seeded demo default when the coach picked no sports).
        if selectedRole == .coach {
            let handle = snapshot.username.isEmpty
                ? snapshot.name.lowercased().filter { $0.isLetter || $0.isNumber }
                : snapshot.username
            // Round-trip the coach answers through the draft so later saves
            // don't overwrite them with defaults.
            if let tenure = CoachTenureOption(rawValue: snapshot.coachTenure) {
                onboardingDraft.coachTenure = tenure
            }
            if let roster = CoachRosterOption(rawValue: snapshot.coachRoster) {
                onboardingDraft.coachRoster = roster
            }
            applyCoachIdentity(
                name: snapshot.name,
                handle: handle,
                sports: snapshot.selectedSports.compactMap { SportFocus(rawValue: $0) },
                goals: snapshot.selectedGoals,
                tenure: snapshot.coachTenure,
                roster: snapshot.coachRoster
            )
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
        profileCustomBio = snapshot.profileBio
        if !snapshot.profileBio.isEmpty {
            profileShowcase.bio = snapshot.profileBio
        }
        // Local snapshots never carry the photo (it lives in its own file);
        // only a CLOUD snapshot still arrives with base64 — restoreFromCloud
        // writes those bytes back out to the file afterward.
        profilePhotoData = snapshot.profilePhotoBase64.isEmpty
            ? profilePersistence.loadPhoto()
            : Data(base64Encoded: snapshot.profilePhotoBase64)
        clientProfile.mealPrepHabit = snapshot.mealPrepHabit
        clientProfile.mealPrepInterested = snapshot.mealPrepInterested
        if let theme = ThemePreset(rawValue: snapshot.theme) {
            profileShowcase.theme = theme
        }
        if let accent = AccentPalette(rawValue: snapshot.accentPalette) {
            profileShowcase.accentPalette = accent
        }
        profileShowcase.customAccentHex = snapshot.customAccentHex
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
        MorpheTheme.apply(accentPalette: profileShowcase.accentPalette, customHex: profileShowcase.customAccentHex)

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

        // Durable extras that used to be memory-only: pain flags are safety
        // data, the nutrition mode and view density are lasting preferences.
        painReports = snapshot.painReports.map {
            PainReport(area: $0.area, severity: $0.severity, triggerExercise: $0.triggerExercise, alternative: $0.alternative, note: $0.note)
        }
        if let mode = NutritionMode(rawValue: snapshot.nutritionMode) {
            nutrition.mode = mode
        }
        prefersCompactExerciseView = snapshot.prefersCompactExerciseView
        scannedConnections = snapshot.scannedConnections

        rebuildPersonalRules()
        // The demo clear also wiped savedWorkouts — restore the user's own
        // Discover saves and non-catalog saves.
        rebuildSavedCatalogWorkouts()
        rebuildSavedTemplateWorkouts()

        // Same for earned learning progress: the demo clear resets Level 1 /
        // 0 XP, which must not wipe what THIS user actually earned.
        if !snapshot.levelTitle.isEmpty, snapshot.levelTargetXP > 0 {
            var levelValue = levelNumber(from: snapshot.levelTitle) ?? 1
            var xp = max(snapshot.levelXP, 0)
            // Targets come from the decade curve, not the stored value —
            // saves from the old +50-per-level curve migrate on load. If the
            // stored XP now overflows the (possibly smaller) target, roll it
            // into level-ups silently.
            while xp >= Self.xpTarget(forLevel: levelValue) {
                xp -= Self.xpTarget(forLevel: levelValue)
                levelValue += 1
            }
            clientProfile.level.currentTitle = "Level \(levelValue)"
            clientProfile.level.nextTitle = "Level \(levelValue + 1)"
            clientProfile.level.currentXP = xp
            clientProfile.level.targetXP = Self.xpTarget(forLevel: levelValue)
        }
        completedQuizIDs = Set(snapshot.completedQuizIDs)

        // Daily state: a same-day relaunch keeps today's completed tasks
        // (re-offering them unchecked was an infinite XP faucet); a new day
        // starts fresh via handleDayRolloverIfNeeded at the end of init.
        taskCompletionHistory = snapshot.taskHistory
        // Migration (audit 8, P2): records banked against the old 4-task
        // list read as "slipping" against the auto-derived denominator —
        // drop them once; the window refills from honest days.
        taskCompletionHistory.removeAll { $0.total > Self.autoDerivedTaskTitles.count }
        hasAcceptedTerms = snapshot.hasAcceptedTerms
        nameChangedAtEpoch = snapshot.nameChangedAtEpoch
        usernameChangedAtEpoch = snapshot.usernameChangedAtEpoch
        lastDailyResetDay = snapshot.dailyStateDay
        if snapshot.dailyStateDay == Self.dayKey() {
            // Same day + same dial regenerate the same personalized list, so
            // the saved completion titles land on the right rows.
            todayTasks = personalizedDailyTasks()
            minimumWinTasks = personalizedMinimumWinTasks()
            for index in todayTasks.indices {
                todayTasks[index].isCompleted =
                    snapshot.completedTaskTitlesToday.contains(todayTasks[index].title)
            }

            // Same-day Plan B / Minimum Win state. Rebuilding from the reason
            // restores the adjusted plan card and its task list; completions
            // are re-applied by title (like todayTasks above) so a same-day
            // relaunch can't re-offer already-earned minimum-win XP.
            minimumWinModeEnabled = snapshot.minimumWinModeEnabled
            if let reason = PlanBReason(rawValue: snapshot.selectedPlanBReason) {
                selectedPlanBReason = reason
                let result = MorpheDemoContent.planBResponse(for: reason)
                currentPlanAdjustment = result.0
                minimumWinTasks = result.1
                minimumWinMessage = result.2
                minimumWinModeEnabled = true
            }
            for index in minimumWinTasks.indices {
                minimumWinTasks[index].isCompleted =
                    snapshot.completedMinimumWinTitlesToday.contains(minimumWinTasks[index].title)
            }

            // Today's nutrition log (the demo clear above zeroed it).
            nutrition.caloriesConsumed = snapshot.nutritionCaloriesConsumed
            nutrition.proteinConsumed = snapshot.nutritionProteinConsumed
            nutrition.waterConsumed = snapshot.nutritionWaterConsumed
            if snapshot.nutritionScore >= 0 {
                nutrition.nutritionScore = snapshot.nutritionScore
            }
            nutrition.meals = snapshot.nutritionMeals.map {
                MealLogEntry(mealType: $0.mealType, name: $0.name, calories: $0.calories, protein: $0.protein, logged: true)
            }

            // Today's recovery check-in (score -1 = none saved today).
            didCompleteQuickCheckIn = snapshot.didCompleteQuickCheckIn
            if snapshot.recoveryScore >= 0 {
                recovery = RecoverySnapshot(
                    score: snapshot.recoveryScore,
                    status: RecoveryStatus(rawValue: snapshot.recoveryStatus) ?? .moderate,
                    reason: snapshot.recoveryReason,
                    sleepHours: snapshot.recoverySleepHours,
                    energy: snapshot.recoveryEnergy,
                    soreness: snapshot.recoverySoreness,
                    mood: snapshot.recoveryMood,
                    pain: snapshot.recoveryPain,
                    previousSessionFeedback: recovery.previousSessionFeedback
                )
            }
        } else if !snapshot.dailyStateDay.isEmpty {
            // The saved day already ended — bank its task results for the
            // dial here, because the rollover at the end of init can't (the
            // saved completion titles belong to a list that no longer exists).
            // Auto-derived tasks only (audit 7, P1-4): the tappable list
            // left with the Today's Plan card, so counting it in the
            // denominator dragged the dial down on every real training day.
            recordTaskDay(
                snapshot.dailyStateDay,
                completed: snapshot.completedTaskTitlesToday
                    .filter { Self.autoDerivedTaskTitles.contains($0) }.count,
                // The denominator the day ACTUALLY had (audit 8, P1-2):
                // the fixed count graded cold-launch days at 1/2 while
                // in-foreground rollovers scored 1/1, freezing the dial.
                // Old snapshots without the field fall back safely.
                total: snapshot.autoTaskTotalToday
                    ?? max(snapshot.completedTaskTitlesToday
                        .filter { Self.autoDerivedTaskTitles.contains($0) }.count, 1)
            )
        }
        protectedDayKeys = Set(snapshot.protectedDayKeys)
        streakProtected = protectedDayKeys.contains(Self.dayKey())

        // Rebuild the daily-plan rotation from the restored level + equipment
        // (deterministic, so the same profile yields the same plan) and restore
        // where in it the user was. Staging isn't done here — the session
        // snapshot restores the actual currentWorkout; rollover advances it.
        planDayIndex = max(0, snapshot.planDayIndex)
        rebuildPersonalizedPlan()

        // Nutrition goal numbers recomputed from the restored weight + goals
        // (goals only — today's consumed counts were restored above).
        applyNutritionTargets()

        // History/consistency/score/streak were derived in init against the seeded
        // id; rebuild them now that the user's real identity is restored.
        refreshWorkoutLogDerivedState(for: clientProfile.id)

        // The competition prefs are keyed by profile id, which this restore
        // may have just changed — re-read them for the restored identity.
        loadCompetitionState()
        loadTrainingPreferences()
        reloadPerProfileMirrors()
    }

    /// Persists the current local profile snapshot to disk.
    // MARK: - Verification (ask → human review → server-granted badge)

    /// Submits the selfie + note; the badge itself only ever arrives via
    /// `refreshVerificationStatus` after the Morphe team grants it.
    func submitVerificationRequest(selfieJPEG: Data, note: String) async {
        guard let uid = authUser?.id else {
            showToast("Sign in to request verification.")
            return
        }
        isSubmittingVerification = true
        defer { isSubmittingVerification = false }
        let ok = await verificationService.submitRequest(
            uid: uid,
            name: selectedRole == .coach ? coachProfile.name : profileShowcase.displayName,
            username: selectedRole == .coach ? coachProfile.username : profileShowcase.username,
            role: selectedRole.rawValue,
            note: String(note.trimmingCharacters(in: .whitespacesAndNewlines).prefix(300)),
            selfieJPEG: selfieJPEG
        )
        if ok {
            verificationRequestStatus = .pending
            showCelebration(
                title: "Request sent",
                detail: "The Morphe team reviews verifications — your badge appears once approved.",
                symbol: "checkmark.seal"
            )
        } else {
            showToast("Couldn't send the request — check your connection and try again.")
        }
    }

    /// Mirrors the server-owned facts (badge + request status) locally.
    func refreshVerificationStatus(force: Bool = false) async {
        guard let uid = authUser?.id else { return }
        // Daily gate (READINESS-300 R9): the badge changes rarely — one
        // check per uid per day unless something explicitly forces it.
        let checkedKey = "morphe.verify.checked.\(uid)"
        let parts = Calendar.current.dateComponents([.year, .month, .day], from: .now)
        let today = String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
        if !force, UserDefaults.standard.string(forKey: checkedKey) == today { return }
        if let status = await verificationService.fetchStatus(uid: uid) {
            UserDefaults.standard.set(today, forKey: checkedKey)
            let wasVerified = isVerifiedUser
            isVerifiedUser = status.verified
            verificationRequestStatus = status.request
            if status.verified, !wasVerified {
                showCelebration(
                    title: "You're verified",
                    detail: "The blue check now shows on your profile.",
                    symbol: "checkmark.seal.fill"
                )
            }
        }
    }

    // MARK: - Profile page extras (photo + custom bio)

    /// User-written bio; when non-empty it wins over the generated one.
    var profileCustomBio: String = ""
    /// The user's profile photo (compressed JPEG bytes). Nil = avatar art.
    var profilePhotoData: Data?

    /// Saves the user's bio. Empty text hands the bio back to the generator.
    /// The coach's own words for their public headline — persisted in the
    /// profile snapshot; empty = keep the derived one.
    var customCoachHeadline: String {
        get { UserDefaults.standard.string(forKey: "morphe.coach.headline.\(clientProfile.id.uuidString)") ?? "" }
        set {
            UserDefaults.standard.set(String(newValue.prefix(120)), forKey: "morphe.coach.headline.\(clientProfile.id.uuidString)")
        }
    }

    /// Coach headline editor (profile audit: it had NO editor anywhere).
    func updateCoachHeadline(_ text: String) {
        let clean = String(text.trimmingCharacters(in: .whitespacesAndNewlines).prefix(120))
        customCoachHeadline = clean
        if !clean.isEmpty { coachProfile.headline = clean }
        showToast(clean.isEmpty ? "Headline reset to the derived one." : "Headline updated.")
    }

    func updateProfileBio(_ text: String) {
        let clean = String(text.trimmingCharacters(in: .whitespacesAndNewlines).prefix(220))
        profileCustomBio = clean
        profileShowcase.bio = clean.isEmpty
            ? profileBio(for: clientProfile.sportMode,
                         trainingStyles: clientProfile.selectedTrainingStyles,
                         goals: clientProfile.selectedGoals)
            : clean
        persistLocalProfile()
        showToast(clean.isEmpty ? "Bio reset to the generated one." : "Bio updated.")
    }

    /// Sets (or clears, with nil) the profile photo. Caller hands over
    /// already-compressed JPEG bytes — the store stays UIKit-free. The bytes
    /// go straight to their own file (never the JSON snapshot), and the cloud
    /// mirror pushes immediately — a face change must not wait out the
    /// rate-limit window.
    func updateProfilePhoto(_ data: Data?) {
        profilePhotoData = data
        if let data {
            profilePersistence.savePhoto(data)
        } else {
            profilePersistence.clearPhoto()
        }
        forceNextProfileCloudPush = true
        persistLocalProfile()
        flushPendingPersists()
        showToast(data == nil ? "Photo removed." : "Photo updated.")
    }

    /// Marks the local profile dirty and schedules the coalesced write — same
    /// once-per-runloop-turn batching as the workout session (~40 call sites,
    /// water taps included, used to each encode the full snapshot).
    private func persistLocalProfile() {
        guard !isApplyingProfile else { return }
        needsProfilePersist = true
        schedulePersistFlush()
    }

    /// The actual profile encode+save, plus the rate-limited cloud mirror.
    private func flushProfilePersistIfNeeded() {
        guard needsProfilePersist else { return }
        needsProfilePersist = false
        let snapshot = makeProfileSnapshot()
        profilePersistence.saveProfile(snapshot)
        // Mirror to the cloud once the account is real (onboarding done).
        if hasCompletedOnboarding { pushProfileToCloud(snapshot) }
    }

    /// Builds the local snapshot. `profilePhotoBase64` stays empty here on
    /// purpose: the photo lives in its own profile-photo.jpg file, so routine
    /// profile saves stop base64-encoding JPEG bytes into JSON. Only the cloud
    /// push injects the base64 (see `pushProfileToCloud`).
    private func makeProfileSnapshot() -> LocalProfileSnapshot {
        var snapshot = LocalProfileSnapshot(
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
                customAccentHex: profileShowcase.customAccentHex,
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
                bodyWeight: clientProfile.bodyWeight,
                dailyStateDay: lastDailyResetDay,
                completedTaskTitlesToday: todayTasks.filter(\.isCompleted).map(\.title),
                protectedDayKeys: Array(protectedDayKeys),
                planDayIndex: planDayIndex,
                completedMinimumWinTitlesToday: minimumWinTasks.filter(\.isCompleted).map(\.title),
                minimumWinModeEnabled: minimumWinModeEnabled,
                selectedPlanBReason: selectedPlanBReason?.rawValue ?? "",
                nutritionCaloriesConsumed: nutrition.caloriesConsumed,
                nutritionProteinConsumed: nutrition.proteinConsumed,
                nutritionWaterConsumed: nutrition.waterConsumed,
                nutritionScore: nutrition.nutritionScore,
                nutritionMode: nutrition.mode.rawValue,
                nutritionMeals: nutrition.meals.map {
                    MealSnapshot(mealType: $0.mealType, name: $0.name, calories: $0.calories, protein: $0.protein)
                },
                didCompleteQuickCheckIn: didCompleteQuickCheckIn,
                recoveryScore: didCompleteQuickCheckIn ? recovery.score : -1,
                recoveryStatus: recovery.status.rawValue,
                recoveryReason: recovery.reason,
                recoverySleepHours: recovery.sleepHours,
                recoveryEnergy: recovery.energy,
                recoverySoreness: recovery.soreness,
                recoveryMood: recovery.mood,
                recoveryPain: recovery.pain,
                painReports: painReports.map {
                    PainReportSnapshot(area: $0.area, severity: $0.severity, triggerExercise: $0.triggerExercise, alternative: $0.alternative, note: $0.note)
                },
                prefersCompactExerciseView: prefersCompactExerciseView,
                coachTenure: onboardingDraft.coachTenure.rawValue,
                coachRoster: onboardingDraft.coachRoster.rawValue,
                scannedConnections: scannedConnections,
                taskHistory: taskCompletionHistory,
                hasAcceptedTerms: hasAcceptedTerms,
                nameChangedAtEpoch: nameChangedAtEpoch,
                usernameChangedAtEpoch: usernameChangedAtEpoch
        )
        snapshot.profileBio = profileCustomBio
        snapshot.autoTaskTotalToday = todayTasks
            .filter { Self.autoDerivedTaskTitles.contains($0.title) }.count
        snapshot.mealPrepHabit = clientProfile.mealPrepHabit
        snapshot.mealPrepInterested = clientProfile.mealPrepInterested
        return snapshot
    }

    /// Pushes the profile to Firestore at most once per
    /// `profileCloudPushInterval`, trailing-edge: a burst of edits inside the
    /// window schedules ONE later push that reads the store fresh, so the last
    /// state always lands. The photo's base64 is injected here — cloud only —
    /// so a reinstall restores the face without the local file carrying it.
    private func pushProfileToCloud(_ snapshot: LocalProfileSnapshot) {
        let now = Date.now
        if forceNextProfileCloudPush || now.timeIntervalSince(lastProfileCloudPushAt) >= Self.profileCloudPushInterval {
            forceNextProfileCloudPush = false
            lastProfileCloudPushAt = now
            var cloudSnapshot = snapshot
            cloudSnapshot.profilePhotoBase64 = profilePhotoData?.base64EncodedString() ?? ""
            cloudBackup.pushProfile(cloudSnapshot)
        } else if !isProfileCloudPushScheduled {
            isProfileCloudPushScheduled = true
            let wait = Self.profileCloudPushInterval - now.timeIntervalSince(lastProfileCloudPushAt)
            Task { @MainActor [weak self] in
                try? await Task.sleep(for: .seconds(wait))
                guard let self else { return }
                self.isProfileCloudPushScheduled = false
                guard self.hasCompletedOnboarding else { return }
                self.lastProfileCloudPushAt = .now
                var cloudSnapshot = self.makeProfileSnapshot()
                cloudSnapshot.profilePhotoBase64 = self.profilePhotoData?.base64EncodedString() ?? ""
                self.cloudBackup.pushProfile(cloudSnapshot)
            }
        }
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
    /// Names double as restore keys (session restore and saved-template
    /// rebuild both match by name), so two templates must never share one.
    private func uniqueWorkoutName(_ proposed: String) -> String {
        let base = proposed.isEmpty ? "My Workout" : proposed
        guard workoutTemplates.contains(where: { $0.name == base }) else { return base }
        var suffix = 2
        while workoutTemplates.contains(where: { $0.name == "\(base) \(suffix)" }) {
            suffix += 1
        }
        return "\(base) \(suffix)"
    }

    func createCustomWorkout(name: String, sport: SportFocus, items: [CustomWorkoutItem]) {
        let trimmed = uniqueWorkoutName(name.trimmingCharacters(in: .whitespacesAndNewlines))
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
        persistWorkoutLibrary()
        // Stage it as the current plan ONLY when nothing is lost. With a
        // finished-but-unlogged session, staging (setCurrentWorkout) would
        // silently drop that recap — and the confirm dialog can't present from
        // the builder sheet anyway. So the build just lands in Your workouts
        // and the user starts it when the current session is closed.
        if hasUnsavedSessionWork {
            showToast("\(template.name) saved to Your workouts.")
        } else {
            setCurrentWorkout(template)
            showToast("\(template.name) is ready in your Current plan.")
        }
    }

    /// Deletes one of the user's custom workouts.
    /// Deletion is confirmed at the VIEW level with delete-specific copy
    /// (the session gate's "discard and continue" wording never said the
    /// workout itself dies). This performs unconditionally.
    func deleteCustomWorkout(_ id: UUID) {
        guard customWorkoutIDs.contains(id) else { return }
        performDeleteCustomWorkout(id)
    }

    private func performDeleteCustomWorkout(_ id: UUID) {
        let name = workoutTemplates.first(where: { $0.id == id })?.name ?? "Workout"
        defer { showToast("\(name) deleted.") }
        workoutTemplates.removeAll { $0.id == id }
        customWorkoutIDs.remove(id)
        // Saved-library cards pointing at the deleted template would error on
        // Start and silently vanish on the next relaunch — remove them now.
        savedWorkouts.removeAll { $0.workoutTemplateID == id }
        if currentWorkoutID == id, let fallback = workoutTemplates.first {
            // setCurrentWorkout (not a bare id write) so live-session flags
            // can't silently reattach to an unrelated template.
            setCurrentWorkout(fallback)
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

        // Everything else the user saved persists by name (seeded template
        // ids re-mint per launch) and is rebuilt on load.
        let savedTemplates = savedWorkouts
            .filter { item in !catalogWorkouts.contains { $0.id == item.workoutTemplateID } }
            .map {
                SavedTemplateSnapshot(
                    name: $0.workoutName,
                    sourceName: $0.sourceName,
                    sourceContext: $0.sourceContext,
                    bestFor: $0.bestFor.rawValue,
                    note: $0.note,
                    isPinned: $0.isPinned
                )
            }

        let pinnedCatalogIDs = savedWorkouts
            .filter { item in item.isPinned && catalogWorkouts.contains { $0.id == item.workoutTemplateID } }
            .map { $0.workoutTemplateID.uuidString }

        workoutPersistence.saveLibrary(
            WorkoutLibrarySnapshot(
                customExercises: exerciseSnaps,
                customWorkouts: workoutSnaps,
                savedCatalogWorkoutIDs: savedCatalogIDs,
                savedTemplates: savedTemplates,
                pinnedCatalogWorkoutIDs: pinnedCatalogIDs
            )
        )
        persistedSavedTemplates = savedTemplates
        persistedPinnedCatalogIDs = pinnedCatalogIDs
    }

    /// Rebuilds the user's custom exercises and workouts from disk at launch.
    private func loadCustomWorkoutLibrary() {
        guard let snapshot = workoutPersistence.loadLibrary() else { return }
        persistedSavedCatalogIDs = snapshot.savedCatalogWorkoutIDs
        persistedSavedTemplates = snapshot.savedTemplates
        persistedPinnedCatalogIDs = snapshot.pinnedCatalogWorkoutIDs
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

        // Non-catalog saves resolve by name, so they rebuild only after the
        // custom templates above exist.
        rebuildSavedTemplateWorkouts()
    }

    /// Restores non-catalog library saves (recommendation saves, duplicated
    /// copies) by matching persisted names against the loaded templates.
    /// WARNING: names are load-bearing restore keys here — an unresolved save
    /// is silently dropped and the next persistWorkoutLibrary re-derives the
    /// snapshot without it, permanently. Never rename a seeded/custom template
    /// name without a migration, or existing users lose those saves. (Catalog
    /// saves are ID-keyed and safe to rename; f266b95 only touched those.)
    private func rebuildSavedTemplateWorkouts() {
        for snap in persistedSavedTemplates {
            guard let template = workoutTemplates.first(where: { $0.name == snap.name }),
                  !savedWorkouts.contains(where: { $0.workoutTemplateID == template.id })
            else { continue }
            savedWorkouts.append(
                SavedWorkoutLibraryItem(
                    workoutTemplateID: template.id,
                    workoutName: template.name,
                    sport: template.sport,
                    sourceName: snap.sourceName,
                    sourceRole: .client,
                    sourceContext: snap.sourceContext,
                    bestFor: SavedWorkoutUseCase(rawValue: snap.bestFor) ?? .solo,
                    note: snap.note,
                    isPinned: snap.isPinned
                )
            )
        }
    }

    /// Re-applies a saved in-progress session snapshot. Guarded so the property
    /// `didSet`s it triggers don't immediately re-persist the same snapshot.
    private func restoreWorkoutSession(from snapshot: WorkoutSessionSnapshot) {
        isRestoringWorkoutSession = true
        defer { isRestoringWorkoutSession = false }

        if let id = snapshot.currentWorkoutID {
            if workoutTemplates.contains(where: { $0.id == id }) {
                currentWorkoutID = id
            } else if let catalogTemplate = catalogWorkouts.first(where: { $0.id == id }) {
                // A Discover workout that was started but never saved exists
                // only in the bundled catalog after a relaunch — rebuild its
                // template so the live session reattaches to the right workout
                // (and its tracked-set keys resolve).
                ensureCatalogWorkoutInLibrary(catalogTemplate)
                currentWorkoutID = id
            } else if !snapshot.currentWorkoutName.isEmpty,
                      let named = workoutTemplates.first(where: { $0.name == snapshot.currentWorkoutName }) {
                // Seeded template ids re-mint every launch — the persisted
                // name recovers the user's staged pick (so the day-0
                // personalized workout survives a relaunch).
                currentWorkoutID = named.id
            } else if snapshot.isWorkoutSessionActive || snapshot.hasCompletedWorkoutFlow {
                // The session's workout no longer exists anywhere. Restoring
                // the session flags would attach the live tracker (or a
                // finished-but-unlogged recap, which "Log" would then write
                // against the wrong template) to whatever template happens to
                // be current — drop the stale session instead.
                isWorkoutLoggedToday = snapshot.isWorkoutLoggedToday
                return
            }
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
        trackedSetLabels = snapshot.trackedSetLabels
        trackedSetWarmups = snapshot.trackedSetWarmups
        supersetPartners = snapshot.supersetPartners
        pendingSetDrafts = snapshot.pendingSetDrafts
        workoutSessionStartedAt = snapshot.workoutSessionStartedAt
        completedSessionMinutes = snapshot.completedSessionMinutes
    }

    /// Marks the in-progress session dirty and schedules the coalesced write.
    /// Still the didSet hook on every session property, so nothing persists
    /// less than before — just once per runloop turn instead of once per
    /// property mutation.
    private func persistWorkoutSession() {
        guard !isRestoringWorkoutSession else { return }
        needsSessionPersist = true
        schedulePersistFlush()
    }

    /// Schedules exactly ONE flush per runloop turn; every didSet in a burst
    /// lands in that single write. `[weak self]` so a store abandoned with a
    /// flush in flight (tests) can't write stale state over a newer instance's
    /// files after it has been replaced.
    private func schedulePersistFlush() {
        guard !isPersistFlushScheduled else { return }
        isPersistFlushScheduled = true
        Task { @MainActor [weak self] in
            self?.flushPendingPersists()
        }
    }

    /// Performs any pending coalesced writes right now. The scheduled Task
    /// calls this at the end of the runloop turn; moments that must hit disk
    /// synchronously (onboarding completion, a photo change, a simulated
    /// relaunch in tests) call it directly.
    func flushPendingPersists() {
        isPersistFlushScheduled = false
        flushSessionPersistIfNeeded()
        flushProfilePersistIfNeeded()
    }

    /// The actual session encode+save — once per batch of mutations.
    private func flushSessionPersistIfNeeded() {
        guard needsSessionPersist else { return }
        needsSessionPersist = false
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
                trackedSetLabels: trackedSetLabels,
                trackedSetWarmups: trackedSetWarmups,
                supersetPartners: supersetPartners,
                pendingSetDrafts: pendingSetDrafts,
                workoutSessionStartedAt: workoutSessionStartedAt,
                completedSessionMinutes: completedSessionMinutes,
                isWorkoutLoggedToday: isWorkoutLoggedToday,
                currentWorkoutName: currentWorkout.name
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
            // Every advertised prompt gets a real answer or a real action —
            // the "Draft…" prompts pretended to a feature that doesn't exist
            // (AI-7 audit finding).
            case .dashboard:
                return ["Who needs attention today?", "Open athletes", "Summarize this week's priorities", "What can you do?"]
            case .athletes:
                return ["Summarize this athlete", "Who needs attention today?", "Open programs", "What can you do?"]
            case .train:
                return ["Start my workout", "Suggest a swap", "I'm short on time", "What can you do?"]
            case .discover:
                return ["Find a conditioning workout", "What should I assign a beginner?", "Suggest a session for game week", "Help me build a workout"]
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
        case .discover:
            return ["Start my workout", "What training type fits my goal?", "Show my progress", "What can you do?"]
        case .community:
            return ["Help me reply to my coach", "Summarize support messages", "Show my progress", "What can you do?"]
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
            case .train:
                return "Get form help, swaps, and pain-safe suggestions without breaking workout flow."
            case .discover:
                return "Find workouts worth assigning, build your own, and grow your roster."
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
        case .discover:
            return "Find the right workout across 18 training types and start it in one tap."
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
            case .train:
                return "Ask for swaps, form help, or pain-safe options..."
            case .discover:
                return "Ask for a workout to assign or help building one..."
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
        case .discover:
            return "Ask what to train today or which type fits your goal..."
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
            case .train:
                if isWorkoutSessionActive {
                    return "Active workout: \(activeWorkoutExercise?.name ?? currentWorkout.name)"
                }
                return "Train"
            case .discover:
                return "Coach Discover"
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
        case .discover:
            return "Discover: browsing \(discoverWorkouts.count) workouts"
        case .community:
            // VoiceOver announces what's ON SCREEN (audit 5, P2): the tab
            // header renders CHATS, not the section's internal rawValue.
            switch selectedCommunitySection {
            case .contact: return "Chats"
            case .forYou: return "For You"
            case .board: return "Board"
            case .calendar: return "Calendar"
            }
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

        // Newest first (profile audit): alphabetical put the A-through-B
        // exercises on top and called them "top" — recency is the honest
        // default; each row still shows that exercise's best-ever weight.
        return best
            .sorted { $0.value.date > $1.value.date }
            .map { name, entry in
                PersonalRecord(
                    title: name,
                    value: weightUnit.format(entry.weight),
                    detail: "Top set • \(Self.workoutDateLabel(for: entry.date))"
                )
            }
    }

    /// Updates the user's injury/limitations note post-onboarding — safety
    /// data must stay editable, not locked after minute one.
    func updateInjuryNote(_ note: String) {
        clientProfile.limitations = note.trimmingCharacters(in: .whitespacesAndNewlines)
        rebuildPersonalRules()
        // The one safety-relevant setting on the screen: the plan ranker
        // reads flaggedAreas(from: limitations), so a new injury must
        // re-rank TODAY, not on the next relaunch (launch audit).
        rebuildPersonalizedPlan()
        persistLocalProfile()
        showToast(clientProfile.limitations.isEmpty ? "Injury note cleared." : "Injury note updated.")
    }

    /// Updates free-text body metrics from Profile (onboarding no longer asks).
    func updateBodyMetrics(height: String, weight: String) {
        clientProfile.height = String(height.trimmingCharacters(in: .whitespacesAndNewlines).prefix(20))
        clientProfile.bodyWeight = String(weight.trimmingCharacters(in: .whitespacesAndNewlines).prefix(20))
        // Each genuinely new weight becomes a dated reading, so Progress can
        // chart a REAL history instead of faking one from a single value.
        recordBodyWeightReadingIfChanged(clientProfile.bodyWeight)
        // A new logged weight moves the nutrition goal numbers immediately.
        applyNutritionTargets()
        persistLocalProfile()
        showToast("Details saved.")
    }

    // MARK: - Body weight history

    /// One saved body-weight reading. Always stored in pounds so the series
    /// stays comparable when the display unit flips; the UI converts.
    /// Internal (not private) so the cloud backup can carry the same type.
    struct BodyWeightHistoryEntry: Codable {
        var date: Date
        var weightLb: Double
    }

    /// UserDefaults key for the weight history, scoped per profile id so a
    /// fresh-user reset or account switch never inherits another profile's
    /// readings.
    private var bodyWeightHistoryDefaultsKey: String {
        "morphe.bodyWeightHistory.\(clientProfile.id.uuidString)"
    }

    /// Deliberate persistence exception: this lives in UserDefaults
    /// (JSON-encoded) instead of LocalProfileSnapshot. ProfilePersistence is
    /// a shared file owned by other work streams, and its tolerant decoder
    /// must not grow fields casually (see the snapshot-decode gotcha) — a
    /// small append-only array capped at 200 entries is a safe fit for
    /// defaults storage.
    private func loadBodyWeightHistoryEntries() -> [BodyWeightHistoryEntry] {
        guard let data = UserDefaults.standard.data(forKey: bodyWeightHistoryDefaultsKey),
              let entries = try? JSONDecoder().decode([BodyWeightHistoryEntry].self, from: data)
        else { return [] }
        return entries
    }

    /// The user's real body-weight readings over time (in lb), oldest first —
    /// one appended each time the Profile weight is saved with a NEW value.
    /// A single reading is never charted: one point is not a trend.
    var bodyWeightHistory: [(date: Date, weightLb: Double)] {
        loadBodyWeightHistoryEntries().map { ($0.date, $0.weightLb) }
    }

    /// Appends a reading when the newly saved weight parses and actually
    /// differs from the last recorded one — re-saving "175" unchanged is
    /// not a data point.
    private func recordBodyWeightReadingIfChanged(_ weightText: String) {
        guard let weightLb = Self.parsedBodyWeightLb(weightText, assumedUnit: weightUnit) else { return }
        var entries = loadBodyWeightHistoryEntries()
        if let last = entries.last, abs(last.weightLb - weightLb) < 0.05 { return }
        entries.append(BodyWeightHistoryEntry(date: .now, weightLb: weightLb))
        if entries.count > 200 {
            entries.removeFirst(entries.count - 200)
        }
        if let data = try? JSONEncoder().encode(entries) {
            UserDefaults.standard.set(data, forKey: bodyWeightHistoryDefaultsKey)
        }
        // The series used to live ONLY in device defaults — a reinstall wiped
        // the whole trend. Now every new reading mirrors to the cloud.
        cloudBackup.pushWeightHistory(entries)
    }

    /// Cloud-restore path: adopt the fetched series when it holds more than
    /// the device does (fresh install, new phone). A shorter cloud copy never
    /// clobbers a longer local one.
    private func applyRestoredWeightHistory(_ entries: [BodyWeightHistoryEntry]) {
        guard entries.count > loadBodyWeightHistoryEntries().count,
              let data = try? JSONEncoder().encode(entries) else { return }
        UserDefaults.standard.set(data, forKey: bodyWeightHistoryDefaultsKey)
    }

    // MARK: - Structured programs (weeks × sessions, progression baked in)

    /// The starter program library — assembled from catalog sessions that
    /// already exist, so every referenced workout is real content.
    static let trainingPrograms: [TrainingProgram] = [
        TrainingProgram(
            id: "foundation-4w",
            name: "Foundation Strength",
            summary: "4 weeks of beginner linear progression — two alternating full-body days plus one conditioning finisher each week. Week 4 deloads.",
            weeks: 4,
            deloadWeek: 4,
            weeklySessionNames: [
                "Beginner Linear Progression — Day A",
                "Beginner Linear Progression — Day B",
                "Full-Body Burner Circuit"
            ]
        ),
        TrainingProgram(
            id: "ppl-6w",
            name: "Push Pull Legs",
            summary: "6 weeks of the classic split — push, pull, and leg days every week. Week 6 deloads before you test anything.",
            weeks: 6,
            deloadWeek: 6,
            weeklySessionNames: ["PPL — Push Day", "PPL — Pull Day", "PPL — Leg Day"]
        ),
        TrainingProgram(
            id: "powerbuild-6w",
            name: "Powerbuilding",
            summary: "6 weeks of heavy upper/lower work with a dedicated squat day. Week 6 deloads.",
            weeks: 6,
            deloadWeek: 6,
            weeklySessionNames: ["Powerbuilding Upper", "Powerbuilding Lower", "5x5 Lower — Squat Day"]
        )
    ]

    /// Live program progress, all derived from the completed-session COUNT —
    /// weeks advance when the work is done, never because a date passed.
    struct ProgramProgress {
        var program: TrainingProgram
        var completedSessions: Int
        var week: Int
        var sessionIndexInWeek: Int
        var isDeloadWeek: Bool
        var nextSessionName: String
        var isComplete: Bool
    }

    private var activeProgramDefaultsKey: String {
        "morphe.program.\(clientProfile.id.uuidString)"
    }

    /// Same documented UserDefaults exception as competition state: one tiny
    /// per-profile blob, never in the shared snapshot decoder.
    private func loadActiveProgramSnapshot() -> ActiveProgramSnapshot? {
        guard let data = UserDefaults.standard.data(forKey: activeProgramDefaultsKey),
              let snapshot = try? JSONDecoder().decode(ActiveProgramSnapshot.self, from: data)
        else { return nil }
        return snapshot
    }

    /// Stored, observable mirror of the persisted snapshot — programProgress
    /// used to decode UserDefaults on EVERY access, which the live console
    /// hits per exercise row per render via suggestedWorkingWeight.
    private(set) var activeProgramState: ActiveProgramSnapshot?

    private func persistActiveProgramSnapshot(_ snapshot: ActiveProgramSnapshot?) {
        activeProgramState = snapshot
        if let snapshot, let data = try? JSONEncoder().encode(snapshot) {
            UserDefaults.standard.set(data, forKey: activeProgramDefaultsKey)
        } else {
            UserDefaults.standard.removeObject(forKey: activeProgramDefaultsKey)
        }
        mirrorExtrasToCloud()
    }

    var programProgress: ProgramProgress? {
        guard let snapshot = activeProgramState,
              let program = Self.trainingPrograms.first(where: { $0.id == snapshot.programID }),
              !program.weeklySessionNames.isEmpty
        else { return nil }
        let done = min(snapshot.completedSessions, program.totalSessions)
        let perWeek = program.weeklySessionNames.count
        let week = min(done / perWeek + 1, program.weeks)
        let sessionIndex = done % perWeek
        return ProgramProgress(
            program: program,
            completedSessions: done,
            week: week,
            sessionIndexInWeek: sessionIndex,
            isDeloadWeek: program.deloadWeek == week && done < program.totalSessions,
            nextSessionName: program.weeklySessionNames[sessionIndex],
            isComplete: done >= program.totalSessions
        )
    }

    func startProgram(_ program: TrainingProgram) {
        persistActiveProgramSnapshot(ActiveProgramSnapshot(programID: program.id, startedAt: .now))
        track("program_started")
        showToast("\(program.name) started — \(program.weeks) weeks, session 1 is staged.")
        startNextProgramSession()
    }

    func leaveProgram() {
        guard let progress = programProgress else { return }
        persistActiveProgramSnapshot(nil)
        showToast("Left \(progress.program.name). Your logs keep everything you did.")
    }

    /// Stages the program's next session as today's workout. A session name
    /// missing from the catalog (content drift) skips forward honestly.
    func startNextProgramSession() {
        guard let progress = programProgress, !progress.isComplete else { return }
        guard let template = discoverWorkouts.first(where: { $0.name == progress.nextSessionName }) else {
            // Content drift: count the unresolvable slot as passed so the
            // program can't wedge, and say so.
            advanceProgram(by: 1)
            showToast("\(progress.nextSessionName) isn't in the catalog right now — skipped ahead.")
            return
        }
        startCatalogWorkout(template)
    }

    private func advanceProgram(by count: Int) {
        guard var snapshot = activeProgramState else { return }
        snapshot.completedSessions += count
        persistActiveProgramSnapshot(snapshot)
    }

    // Finished programs, per profile — the active snapshot dies when the
    // user starts the next program, so completions need their own tiny
    // record for the earned badge to stay true forever.
    private var programCompletionsDefaultsKey: String {
        "morphe.programCompletions.\(clientProfile.id.uuidString)"
    }

    private(set) var completedProgramIDs: [String] = []

    func loadProgramCompletions() {
        completedProgramIDs = UserDefaults.standard.stringArray(forKey: programCompletionsDefaultsKey) ?? []
    }

    /// Appends once per program id — re-finishing a re-run program keeps
    /// one badge, not a stack of duplicates.
    func recordProgramCompletion(_ programID: String) {
        guard !completedProgramIDs.contains(programID) else { return }
        completedProgramIDs.append(programID)
        UserDefaults.standard.set(completedProgramIDs, forKey: programCompletionsDefaultsKey)
        mirrorExtrasToCloud()
    }

    /// Called from `logWorkout`: a logged session that IS the program's next
    /// session advances it. Returns whether this log COMPLETED the program —
    /// the caller owns the celebration slot, so completion can outrank the
    /// generic one.
    @discardableResult
    private func advanceProgramIfMatches(loggedTitle: String) -> Bool {
        guard let progress = programProgress, !progress.isComplete,
              progress.nextSessionName == loggedTitle else { return false }
        advanceProgram(by: 1)
        guard let after = programProgress, after.isComplete else { return false }
        recordProgramCompletion(after.program.id)
        recentWins.insert("Finished the \(after.program.name) program.", at: 0)
        return true
    }

    /// True while the active program sits in its deload week — drives the
    /// badge on the program card.
    var isProgramDeloadWeek: Bool {
        programProgress?.isDeloadWeek == true
    }

    /// True only when the deload week applies to THIS session: the staged
    /// workout must be one of the program's own sessions. A custom workout
    /// run during a program's deload week keeps normal progression — the
    /// program has no business deloading training it doesn't own.
    var isDeloadActiveForCurrentSession: Bool {
        guard let progress = programProgress, progress.isDeloadWeek else { return false }
        return progress.program.weeklySessionNames.contains(currentWorkout.name)
    }

    // MARK: - Share card (the session's outward face)

    /// The latest logged session as share-card facts — nil before any log.
    /// PR lines come from the same derivation the PR timeline uses, filtered
    /// to records set on that session's day.
    var latestSessionShareCardData: ShareCardData? {
        guard let log = currentAthleteWorkoutLogs.first else { return nil }
        let calendar = Calendar.current
        let prNames = recentPersonalRecords(limit: 10)
            .filter { calendar.isDate($0.date, inSameDayAs: log.completedAt) }
            .map(\.exerciseName)
        return ShareCardData(
            workoutName: log.workoutTitle,
            dateLabel: log.completedAt.formatted(date: .abbreviated, time: .omitted),
            setCount: Self.loggedSetCount(of: log),
            exerciseCount: log.exercises.count,
            minutes: log.durationMinutes,
            streak: currentWorkoutStreak(from: currentAthleteWorkoutLogs),
            prNames: Array(prNames.prefix(3)),
            username: profileShowcase.username.isEmpty ? "" : "@\(profileShowcase.username)"
        )
    }

    /// Caption that rides along with the share-card image — carries the
    /// referral handle so the picture recruits.
    var shareCardCaption: String {
        // Matches networkInviteMessage's promise level (audit 5, P2): the
        // link records the referral — it doesn't "connect" anyone while
        // the social graph is dark.
        let handle = profileShowcase.username
        guard !handle.isEmpty else { return "Training on Morphe." }
        return "Training on Morphe — I'm @\(handle). After you install, open morphe://invite/\(handle)."
    }

    /// One PR as story-card facts. `previous` is only known at log time
    /// (the timeline shows standing records) — 0 hides the "up from" row
    /// rather than inventing a prior.
    func prShareCardData(exerciseName: String, weight: Double, previous: Double = 0, date: Date = .now) -> PRShareCardData {
        PRShareCardData(
            exerciseName: exerciseName,
            weightLabel: weightUnit.format(weight),
            previousLabel: previous > 0 ? weightUnit.format(previous) : "",
            dateLabel: date.formatted(date: .abbreviated, time: .omitted),
            username: profileShowcase.username.isEmpty ? "" : "@\(profileShowcase.username)"
        )
    }

    /// The current schedule-aware streak as story-card facts — nil under 2
    /// days (a 1-day "streak" isn't a brag, same bar the streak reminder uses).
    var streakShareCardData: StreakShareCardData? {
        let streak = currentWorkoutStreak(from: currentAthleteWorkoutLogs)
        guard streak >= 2 else { return nil }
        return StreakShareCardData(
            streak: streak,
            dateLabel: Date.now.formatted(date: .abbreviated, time: .omitted),
            username: profileShowcase.username.isEmpty ? "" : "@\(profileShowcase.username)"
        )
    }

    /// The most recent COMPLETED Mon–Sun week as story-card facts — nil when
    /// that week holds no logged sessions (an empty recap is not a recap).
    /// Monday-anchored via LeaderboardWeek (ISO), NOT Calendar.current —
    /// a US locale starts weeks on Sunday, which would shift the window
    /// and fire the "Monday" reminder on Sunday.
    var weeklyRecapData: WeeklyRecapData? {
        let thisWeekStart = LeaderboardWeek.start()
        return weeklyRecapData(weekStart: thisWeekStart.addingTimeInterval(-7 * 86_400),
                               weekEnd: thisWeekStart)
    }

    /// Recap facts for one [weekStart, weekEnd) window — every number is a
    /// sum over the logs actually inside it.
    private func weeklyRecapData(weekStart: Date, weekEnd: Date) -> WeeklyRecapData? {
        let logs = currentAthleteWorkoutLogs.filter {
            $0.completedAt >= weekStart && $0.completedAt < weekEnd
        }
        guard !logs.isEmpty else { return nil }
        let dayFormat = Date.FormatStyle().month(.abbreviated).day()
        let lastDay = weekEnd.addingTimeInterval(-1)
        return WeeklyRecapData(
            rangeLabel: "\(weekStart.formatted(dayFormat)) – \(lastDay.formatted(dayFormat))",
            sessions: logs.count,
            sets: logs.reduce(0) { $0 + Self.loggedSetCount(of: $1) },
            minutes: logs.reduce(0) { $0 + $1.durationMinutes },
            prCount: recentPersonalRecords(limit: 100)
                .filter { $0.date >= weekStart && $0.date < weekEnd }.count,
            streak: currentWorkoutStreak(from: currentAthleteWorkoutLogs),
            username: profileShowcase.username.isEmpty ? "" : "@\(profileShowcase.username)"
        )
    }

    // MARK: - Daily series (recovery + nutrition history)
    //
    // Same documented persistence exception as bodyWeightHistory: small
    // capped per-profile arrays in UserDefaults, never in the shared
    // snapshot decoder. Both series turn throwaway daily inputs into
    // retention surfaces — the check-in and the meal log used to be
    // captured then DISCARDED at day rollover.

    /// One completed recovery check-in. One entry per day (a re-check-in
    /// the same day replaces).
    struct DailyRecoveryEntry: Codable {
        var date: Date
        var score: Int
        var sleepHours: Double
        var energy: Int
        var soreness: Int
        var mood: Int
    }

    /// One COMPLETED nutrition day, captured at day rollover with the
    /// targets that applied that day. Days with nothing logged are absent —
    /// "didn't log" and "didn't eat" are not distinguishable, so no entry
    /// is the only honest record.
    struct DailyNutritionEntry: Codable {
        var date: Date
        var calories: Int
        var protein: Int
        var calorieTarget: Int
        var proteinTarget: Int
    }

    private var recoverySeriesDefaultsKey: String {
        "morphe.recoverySeries.\(clientProfile.id.uuidString)"
    }

    private var nutritionSeriesDefaultsKey: String {
        "morphe.nutritionSeries.\(clientProfile.id.uuidString)"
    }

    private func loadSeries<Entry: Codable>(_ key: String) -> [Entry] {
        guard let data = UserDefaults.standard.data(forKey: key),
              let entries = try? JSONDecoder().decode([Entry].self, from: data)
        else { return [] }
        return entries
    }

    private func saveSeries<Entry: Codable>(_ entries: [Entry], key: String, cap: Int = 120) {
        var trimmed = entries
        if trimmed.count > cap {
            trimmed.removeFirst(trimmed.count - cap)
        }
        if let data = try? JSONEncoder().encode(trimmed) {
            UserDefaults.standard.set(data, forKey: key)
        }
        mirrorExtrasToCloud()
    }

    // MARK: Cloud extras (the per-profile blobs the backup used to miss)
    //
    // The store copy promises "a new phone restores everything" — before
    // this, program position, check-in trends, competition state, and
    // training prefs lived only in per-profile UserDefaults and died with
    // the device. They ride state/extras as raw property-list blobs now.

    /// Logical blob name → the CURRENT profile's defaults key. Restore maps
    /// through this after the profile id has been applied, so blobs land
    /// under the restored identity.
    private var extrasKeyByName: [String: String] {
        [
            "trainingPreferences": trainingPreferencesDefaultsKey,
            "competitionState": competitionStateDefaultsKey,
            "recoverySeries": recoverySeriesDefaultsKey,
            "nutritionSeries": nutritionSeriesDefaultsKey,
            "activeProgram": activeProgramDefaultsKey,
            "programCompletions": programCompletionsDefaultsKey,
            "libraryFolders": libraryFoldersKey,
        ]
    }

    /// Raw property-list round-trip: whatever type each blob is stored as
    /// (Data, [String], …) survives byte-identical, so the same tolerant
    /// decoders read a restore exactly like a local load.
    func perProfileExtrasBlobs() -> [String: String] {
        var blobs: [String: String] = [:]
        for (name, key) in extrasKeyByName {
            guard let object = UserDefaults.standard.object(forKey: key),
                  let data = try? PropertyListSerialization.data(
                    fromPropertyList: object, format: .binary, options: 0)
            else { continue }
            blobs[name] = data.base64EncodedString()
        }
        return blobs
    }

    /// Writes restored blobs under the current profile's keys and reloads
    /// every mirror that reads them. Unknown names are skipped (an older
    /// build restoring a newer backup keeps what it understands).
    func applyRestoredExtras(_ blobs: [String: String]) {
        for (name, encoded) in blobs {
            guard let key = extrasKeyByName[name],
                  let data = Data(base64Encoded: encoded),
                  let object = try? PropertyListSerialization.propertyList(
                    from: data, options: [], format: nil)
            else { continue }
            UserDefaults.standard.set(object, forKey: key)
        }
        loadTrainingPreferences()
        loadCompetitionState()
        reloadPerProfileMirrors()
    }

    /// Fire-and-forget after any per-profile blob write — same quiet
    /// contract as every other backup push.
    private func mirrorExtrasToCloud() {
        guard hasCompletedOnboarding else { return }
        // Trailing-debounced (READINESS-300 R6): each push costs a read AND
        // a write (merge-by-name requires the current doc), and settings
        // toggles come in bursts. Local persistence already happened.
        extrasPushDebounce?.cancel()
        extrasPushDebounce = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 8_000_000_000)
            guard !Task.isCancelled, let self else { return }
            self.cloudBackup.pushExtras(self.perProfileExtrasBlobs())
        }
    }
    private var extrasPushDebounce: Task<Void, Never>?

    /// Stored mirrors of the persisted series — decoded ONCE per profile
    /// load instead of on every view-body access (firstWeekSteps reads
    /// recoverySeries on every Home render during week one), and observable
    /// so the trend cards refresh the moment a new entry lands.
    private(set) var recoverySeries: [DailyRecoveryEntry] = []
    private(set) var nutritionSeries: [DailyNutritionEntry] = []

    /// Reloads the per-profile stored mirrors (series + active program) for
    /// the CURRENT profile id — called at launch, on profile restore, and
    /// after the onboarding identity mint.
    private func reloadPerProfileMirrors() {
        // The read-stamp cache is keyed by profile id — drop it with every
        // identity change, not just sign-out (post-revamp audit P2-7).
        threadReadCache = nil
        recoverySeries = loadSeries(recoverySeriesDefaultsKey)
        nutritionSeries = loadSeries(nutritionSeriesDefaultsKey)
        activeProgramState = loadActiveProgramSnapshot()
        loadProgramCompletions()
        loadLibraryFolders()
    }

    /// Called from `submitRecoveryCheckIn` — records today's real inputs.
    private func recordRecoveryCheckInEntry() {
        var entries: [DailyRecoveryEntry] = loadSeries(recoverySeriesDefaultsKey)
        let todayKey = Self.dayKey()
        entries.removeAll { Self.dayKey(for: $0.date) == todayKey }
        entries.append(DailyRecoveryEntry(
            date: .now,
            score: recovery.score,
            sleepHours: recovery.sleepHours,
            energy: recovery.energy,
            soreness: recovery.soreness,
            mood: recovery.mood
        ))
        saveSeries(entries, key: recoverySeriesDefaultsKey)
        recoverySeries = entries
    }

    /// Called at day rollover BEFORE the daily nutrition board resets —
    /// the day that just ended becomes a history point iff anything was
    /// actually logged.
    private func recordNutritionDayIfLogged(dayKey: String) {
        guard nutrition.caloriesConsumed > 0 || nutrition.proteinConsumed > 0,
              let day = Self.date(fromDayKey: dayKey) else { return }
        let targets = nutritionTargets
        var entries: [DailyNutritionEntry] = loadSeries(nutritionSeriesDefaultsKey)
        entries.removeAll { Self.dayKey(for: $0.date) == dayKey }
        entries.append(DailyNutritionEntry(
            date: day,
            calories: nutrition.caloriesConsumed,
            protein: nutrition.proteinConsumed,
            calorieTarget: targets.calories,
            proteinTarget: targets.proteinGrams
        ))
        saveSeries(entries, key: nutritionSeriesDefaultsKey)
        nutritionSeries = entries
    }

    // MARK: - Data export

    /// One-file JSON export of everything this athlete owns — profile
    /// basics, full workout logs (per-set arrays included), body-weight
    /// series. Data portability is a trust feature: the user's numbers are
    /// theirs to take.
    func exportDataFile() -> URL? {
        struct ExportPayload: Codable {
            var exportedAt: Date
            var athleteName: String
            var weightUnit: String
            var workoutLogs: [WorkoutLog]
            var bodyWeightHistoryLb: [BodyWeightHistoryEntry]
        }
        let payload = ExportPayload(
            exportedAt: .now,
            athleteName: clientProfile.name,
            weightUnit: weightUnit.rawValue,
            workoutLogs: currentAthleteWorkoutLogs,
            bodyWeightHistoryLb: loadBodyWeightHistoryEntries()
        )
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(payload) else { return nil }
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("Morphe-Export.json")
        do {
            try data.write(to: url, options: .atomic)
            return url
        } catch {
            return nil
        }
    }

    // MARK: - Weekly board + challenges (opt-in competition, real scores only)

    /// One JSON blob in UserDefaults, keyed per profile id (same scoping as
    /// bodyWeightHistory so an account switch never inherits another
    /// profile's memberships).
    private struct CompetitionStateSnapshot: Codable {
        var optIn: Bool
        var challengeCodes: [String]
    }

    private var competitionStateDefaultsKey: String {
        "morphe.competition.\(clientProfile.id.uuidString)"
    }

    /// Deliberate persistence exception: this lives in UserDefaults instead
    /// of LocalProfileSnapshot. ProfilePersistence is a shared file owned by
    /// other work streams, and its tolerant decoder must not grow fields
    /// casually (see the snapshot-decode gotcha) — one flag plus a handful of
    /// 6-char codes is a safe fit for defaults storage, exactly like
    /// bodyWeightHistory above.
    private func loadCompetitionState() {
        isLoadingCompetitionState = true
        defer { isLoadingCompetitionState = false }
        guard let data = UserDefaults.standard.data(forKey: competitionStateDefaultsKey),
              let snapshot = try? JSONDecoder().decode(CompetitionStateSnapshot.self, from: data)
        else {
            leaderboardOptIn = false
            joinedChallengeCodes = []
            return
        }
        leaderboardOptIn = snapshot.optIn
        joinedChallengeCodes = snapshot.challengeCodes
        // Joined challenges refresh from Firestore — the codes are the only
        // locally-persisted fact; every score/member shown is fetched real.
        if !snapshot.challengeCodes.isEmpty {
            Task { await refreshChallenges() }
        }
        // Keep the Monday "new week" reminder in sync with the restored opt-in.
        refreshWeeklyBoardReminder()
    }

    private func persistCompetitionState() {
        guard !isLoadingCompetitionState else { return }
        let snapshot = CompetitionStateSnapshot(optIn: leaderboardOptIn, challengeCodes: joinedChallengeCodes)
        if let data = try? JSONEncoder().encode(snapshot) {
            UserDefaults.standard.set(data, forKey: competitionStateDefaultsKey)
            mirrorExtrasToCloud()
        }
    }

    /// Two live-session Bools, stored exactly like the competition state:
    /// one JSON blob in UserDefaults, keyed per profile id, never in the
    /// shared LocalProfileSnapshot decoder.
    private struct TrainingPreferencesSnapshot: Codable {
        var autoRestTimer: Bool
        var autoShareWorkouts: Bool
        /// Optionals so blobs written before each field decode unchanged.
        var healthSync: Bool?
        var coachShare: Bool?
        var linkedCoachUid: String?
        var linkedCoachName: String?
        var healthSleep: Bool?
        var firstWeekStart: Date?
        var archivedClientCodes: [String]?
        var effortRIR: Bool?
        var postStreakByline: Bool?
        var postAccentIdentity: Bool?
        var trainingDaysOfWeek: [Int]?
        var remindersEnabled: Bool?
    }

    private var trainingPreferencesDefaultsKey: String {
        "morphe.trainingprefs.\(clientProfile.id.uuidString)"
    }

    private func loadTrainingPreferences() {
        isLoadingTrainingPreferences = true
        defer { isLoadingTrainingPreferences = false }
        guard let data = UserDefaults.standard.data(forKey: trainingPreferencesDefaultsKey),
              let snapshot = try? JSONDecoder().decode(TrainingPreferencesSnapshot.self, from: data)
        else {
            autoRestTimerEnabled = true
            autoShareWorkoutsEnabled = false
            healthSyncEnabled = false
            coachShareEnabled = false
            linkedCoachUid = ""
            linkedCoachName = ""
            // EVERY field resets on a missing blob — a profile switch to an
            // account with no stored prefs must not inherit the previous
            // profile's sleep toggle, first-week date, or archived roster.
            healthSleepEnabled = false
            storedAutoShareOptIn = false
            firstWeekStart = nil
            archivedClientCodes = []
            effortScaleRIR = false
            postStreakByline = true
            postAccentIdentity = true
            trainingDays = []
            remindersEnabled = true
            return
        }
        autoRestTimerEnabled = snapshot.autoRestTimer
        // Forced off while the feed is dark (P0-2): a persisted true kept
        // publishing to a surface with no reader and no visible off-switch.
        // The raw opt-in is kept separately so later persists don't erase it.
        storedAutoShareOptIn = snapshot.autoShareWorkouts
        autoShareWorkoutsEnabled = FeatureFlags.socialFeedEnabled && snapshot.autoShareWorkouts
        healthSyncEnabled = snapshot.healthSync ?? false
        coachShareEnabled = snapshot.coachShare ?? false
        linkedCoachUid = snapshot.linkedCoachUid ?? ""
        linkedCoachName = snapshot.linkedCoachName ?? ""
        healthSleepEnabled = snapshot.healthSleep ?? false
        firstWeekStart = snapshot.firstWeekStart
        archivedClientCodes = Set(snapshot.archivedClientCodes ?? [])
        effortScaleRIR = snapshot.effortRIR ?? false
        postStreakByline = snapshot.postStreakByline ?? true
        postAccentIdentity = snapshot.postAccentIdentity ?? true
        trainingDays = Set(snapshot.trainingDaysOfWeek ?? [])
        remindersEnabled = snapshot.remindersEnabled ?? true
    }

    private func persistTrainingPreferences() {
        guard !isLoadingTrainingPreferences else { return }
        let snapshot = TrainingPreferencesSnapshot(
            autoRestTimer: autoRestTimerEnabled,
            autoShareWorkouts: FeatureFlags.socialFeedEnabled
                ? autoShareWorkoutsEnabled : storedAutoShareOptIn,
            healthSync: healthSyncEnabled,
            coachShare: coachShareEnabled,
            linkedCoachUid: linkedCoachUid,
            linkedCoachName: linkedCoachName,
            healthSleep: healthSleepEnabled,
            firstWeekStart: firstWeekStart,
            archivedClientCodes: Array(archivedClientCodes),
            effortRIR: effortScaleRIR,
            postStreakByline: postStreakByline,
            postAccentIdentity: postAccentIdentity,
            trainingDaysOfWeek: Array(trainingDays),
            remindersEnabled: remindersEnabled
        )
        if let data = try? JSONEncoder().encode(snapshot) {
            UserDefaults.standard.set(data, forKey: trainingPreferencesDefaultsKey)
            mirrorExtrasToCloud()
        }
    }

    /// Flips Health sync; enabling walks through the system Health prompt.
    /// The flag flips ON optimistically so the toggle doesn't visually snap
    /// back while the prompt is up — a denial reverts it with the honest toast.
    func setHealthSync(enabled: Bool) async {
        guard enabled else {
            healthSyncEnabled = false
            return
        }
        guard HealthWorkoutSync.isAvailable else {
            showToast("Health isn't available on this device.")
            return
        }
        healthSyncEnabled = true
        if await HealthWorkoutSync.requestAuthorization() {
            showToast("Workouts now save to Apple Health.")
        } else {
            healthSyncEnabled = false
            showToast("Health access is off — enable Morphe in Settings > Health.")
        }
    }

    /// The identity competition rows carry: uid + display name. Nil while
    /// signed out — no account, no board.
    private var competitionSelf: (uid: String, name: String)? {
        guard let user = authUser else { return nil }
        let name = !profileShowcase.displayName.isEmpty ? profileShowcase.displayName
            : !clientProfile.name.isEmpty ? clientProfile.name
            : user.displayName
        return (user.id, name.isEmpty ? "Athlete" : name)
    }

    /// Set count of one log — same derivation `weeklySetVolume` charts, so
    /// the board number always matches the user's own volume chart.
    private static func loggedSetCount(of log: WorkoutLog) -> Int {
        log.exercises.reduce(0) { total, exercise in
            if let reps = exercise.repsPerSet, !reps.isEmpty {
                return total + reps.count
            }
            // Older logs carry only the display string ("3 sets" / "4").
            return total + (Int(exercise.sets.prefix(while: \.isNumber)) ?? 0)
        }
    }

    /// Sets + workouts this user logged inside `interval`, from their real
    /// logs — the only place a competition score can come from.
    func competitionTotals(in interval: DateInterval) -> (sets: Int, workouts: Int) {
        var sets = 0
        var workouts = 0
        for log in currentAthleteWorkoutLogs where interval.contains(log.completedAt) {
            workouts += 1
            sets += Self.loggedSetCount(of: log)
        }
        return (sets, workouts)
    }

    /// The current Monday-anchored ISO week — the window the board scores.
    private var currentBoardWeekInterval: DateInterval {
        DateInterval(start: LeaderboardWeek.start(), duration: 7 * 86_400)
    }

    // MARK: Weekly board actions

    /// Opts in, posts the honest current score (0 is a real score), and pulls
    /// the board.
    func joinWeeklyBoard() {
        guard competitionSelf != nil else {
            showToast("Sign in to join the weekly board.")
            return
        }
        leaderboardOptIn = true
        postWeeklyBoardScore()
        // Forced: the user just joined — they must see themselves land.
        Task { await refreshLeaderboard(force: true) }
        refreshWeeklyBoardReminder()
        showToast("You're on this week's board.")
    }

    /// Stops posting. Already-posted entries for the current week remain —
    /// the rules allow no client deletes (and the opt-in copy disclosed it);
    /// the week key rolls over on Monday and the old board simply ages out.
    func leaveWeeklyBoard() {
        leaderboardOptIn = false
        weeklyLeaderboardSelfEntry = nil
        refreshWeeklyBoardReminder()
        showToast("Left the board. This week's posted entry stays until Monday.")
    }

    /// The Monday-morning "new week" moment: one repeating local
    /// notification, alive only while the user is opted into the board.
    /// The board reset itself is server truth (ISO week keys) — this only
    /// tells the user the moment happened.
    private static let weeklyBoardNotificationID = "morphe.board.week"

    private func refreshWeeklyBoardReminder() {
        guard appointmentRemindersEnabled else { return }
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [Self.weeklyBoardNotificationID])
        guard leaderboardOptIn else { return }
        // Ambient reminders never trigger the permission prompt cold — they
        // schedule only if the user already granted notifications through a
        // user-context ask (the appointment reminder path prompts).
        center.getNotificationSettings { settings in
            guard settings.authorizationStatus == .authorized
                || settings.authorizationStatus == .provisional else { return }
            let content = UNMutableNotificationContent()
            content.title = "New week on the board"
            content.body = "The weekly leaderboard reset — every set you log counts from zero."
            content.sound = .default
            var components = DateComponents()
            components.weekday = 2   // Monday, matching the board's ISO week anchor
            components.hour = 9
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
            center.add(UNNotificationRequest(
                identifier: Self.weeklyBoardNotificationID, content: content, trigger: trigger))
        }
    }

    /// Pulls the top of this week's board, plus the user's own entry (which
    /// may sit outside the fetched top — shown honestly as unranked).
    /// Within this window a non-forced board/challenge refresh reuses what's
    /// loaded (READINESS-300 R8) — each board fetch is 50 reads.
    private static let boardStalenessWindow: TimeInterval = 300
    private var lastLeaderboardRefreshAt: Date?
    private var lastChallengesRefreshAt: Date?

    func refreshLeaderboard(force: Bool = false) async {
        if !force, !weeklyLeaderboard.isEmpty, let last = lastLeaderboardRefreshAt,
           Date.now.timeIntervalSince(last) < Self.boardStalenessWindow {
            return
        }
        if leaderboardFetchState != .loaded { leaderboardFetchState = .loading }
        let weekKey = LeaderboardWeek.key()
        if let top = await leaderboardService.fetchTop(weekKey: weekKey, limit: 50) {
            withAnimation(.easeInOut(duration: 0.25)) {
                weeklyLeaderboard = top
            }
            leaderboardFetchState = .loaded
            lastLeaderboardRefreshAt = .now
        } else if weeklyLeaderboard.isEmpty {
            // Failed with nothing on screen — show it, don't fake "no
            // scores yet". A failed re-fetch keeps the standing board.
            leaderboardFetchState = .failed
        }
        if leaderboardOptIn, let me = competitionSelf {
            weeklyLeaderboardSelfEntry = await leaderboardService.fetchEntry(weekKey: weekKey, uid: me.uid)
        } else {
            weeklyLeaderboardSelfEntry = nil
        }
    }

    /// Upserts the user's own entry from their real weekly totals. Fire and
    /// forget — Firestore queues offline like every other social write.
    private func postWeeklyBoardScore() {
        guard leaderboardOptIn, let me = competitionSelf else { return }
        let totals = competitionTotals(in: currentBoardWeekInterval)
        leaderboardService.postScore(
            weekKey: LeaderboardWeek.key(),
            entry: WeeklyLeaderboardEntry(
                uid: me.uid,
                name: me.name,
                // Mirror of the server-granted badge; the rules re-check it.
                verified: isVerifiedUser,
                score: totals.sets,
                workouts: totals.workouts,
                updatedAt: nil
            )
        )
    }

    // MARK: Challenge actions

    /// The user's member row for one challenge, scored from their own logs
    /// inside the challenge window.
    private func challengeSelfMember(for challenge: ChallengeSummary) -> ChallengeMember? {
        guard let me = competitionSelf else { return nil }
        let window = DateInterval(start: challenge.startsAt, end: max(challenge.endsAt, challenge.startsAt))
        let totals = competitionTotals(in: window)
        return ChallengeMember(
            uid: me.uid,
            name: me.name,
            verified: isVerifiedUser,
            score: challenge.metric == .sets ? totals.sets : totals.workouts,
            updatedAt: nil
        )
    }

    /// Creates a code-joinable challenge (host is member #1) and returns it —
    /// the UI shows the share code from the result. Duration is clamped to
    /// the 30-day cap the rules enforce.
    @discardableResult
    func createChallenge(title: String, metric: ChallengeMetric, days: Int) async -> ChallengeSummary? {
        guard competitionSelf != nil else {
            showToast("Sign in to create a challenge.")
            return nil
        }
        let trimmed = String(title.trimmingCharacters(in: .whitespacesAndNewlines).prefix(60))
        guard !trimmed.isEmpty else {
            showToast("Give the challenge a title.")
            return nil
        }
        guard !isCompetitionBusy else { return nil }
        isCompetitionBusy = true
        defer { isCompetitionBusy = false }

        let start = Date.now
        var challenge = ChallengeSummary(
            code: Self.makePartyCode(),
            hostUid: competitionSelf?.uid ?? "",
            hostName: competitionSelf?.name ?? "",
            title: trimmed,
            metric: metric,
            startsAt: start,
            endsAt: start.addingTimeInterval(TimeInterval(min(max(days, 1), 30)) * 86_400)
        )
        guard let host = challengeSelfMember(for: challenge) else { return nil }
        guard await leaderboardService.createChallenge(challenge, host: host) else {
            showToast("Couldn't create the challenge — check your connection.")
            return nil
        }
        challenge.members = [host]
        activeChallenges.removeAll { $0.code == challenge.code }
        activeChallenges.append(challenge)
        activeChallenges.sort { $0.endsAt < $1.endsAt }
        if !joinedChallengeCodes.contains(challenge.code) {
            joinedChallengeCodes.append(challenge.code)
        }
        track("challenge_created")
        Haptics.success()
        return challenge
    }

    /// Joins a challenge by its 6-char code (typed or pasted).
    @discardableResult
    func joinChallenge(code rawCode: String) async -> Bool {
        guard competitionSelf != nil else {
            showToast("Sign in to join a challenge.")
            return false
        }
        let code = rawCode.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard !code.isEmpty else { return false }
        guard !isCompetitionBusy else { return false }
        isCompetitionBusy = true
        defer { isCompetitionBusy = false }

        if activeChallenges.contains(where: { $0.code == code }) {
            showToast("You're already in that challenge.")
            return false
        }
        // Fetch first so an expired challenge is refused honestly instead of
        // silently accepting a member who can never score.
        guard let fetched = await leaderboardService.fetchChallenge(code: code) else {
            showToast("No challenge found for code \(code).")
            return false
        }
        guard !fetched.isExpired else {
            showToast("That challenge has already ended.")
            return false
        }
        guard let member = challengeSelfMember(for: fetched),
              let joined = await leaderboardService.joinChallenge(code: code, member: member) else {
            showToast("Couldn't join — check your connection.")
            return false
        }
        activeChallenges.removeAll { $0.code == joined.code }
        activeChallenges.append(joined)
        activeChallenges.sort { $0.endsAt < $1.endsAt }
        if !joinedChallengeCodes.contains(joined.code) {
            joinedChallengeCodes.append(joined.code)
        }
        // Challenge drops are a growth loop — count the joins (first-party,
        // same disclosure as every other milestone event).
        track("challenge_joined")
        showCelebration(title: "Challenge joined", detail: joined.title, symbol: "flag.checkered")
        // Land somewhere (audit E12): the celebration was terminal — now
        // the standings you just joined are the destination.
        openProgress()
        return true
    }

    /// Re-fetches every joined challenge. A code that can't be fetched right
    /// now (offline) keeps its last-known data instead of vanishing.
    func refreshChallenges(force: Bool = false) async {
        guard !joinedChallengeCodes.isEmpty else {
            // No joined challenges IS the loaded truth, not a fetch gap.
            challengesFetchState = .loaded
            return
        }
        if !force, !activeChallenges.isEmpty, let last = lastChallengesRefreshAt,
           Date.now.timeIntervalSince(last) < Self.boardStalenessWindow {
            return
        }
        if challengesFetchState != .loaded { challengesFetchState = .loading }
        var refreshed: [ChallengeSummary] = []
        var anyFetched = false
        for code in joinedChallengeCodes {
            if let challenge = await leaderboardService.fetchChallenge(code: code) {
                refreshed.append(challenge)
                anyFetched = true
            } else if let known = activeChallenges.first(where: { $0.code == code }) {
                // Offline keeps last-known data — that's content, not failure.
                refreshed.append(known)
            }
        }
        withAnimation(.easeInOut(duration: 0.25)) {
            activeChallenges = refreshed.sorted { $0.endsAt < $1.endsAt }
        }
        challengesFetchState = (anyFetched || !refreshed.isEmpty) ? .loaded : .failed
        if anyFetched { lastChallengesRefreshAt = .now }
    }

    /// After a real log lands: mirror the new totals to the weekly board
    /// (when opted in) and to every joined, still-running challenge. Reads
    /// only the user's own logs — the score IS the training, nothing else.
    func publishCompetitionScores() {
        postWeeklyBoardScore()
        guard competitionSelf != nil else { return }
        for challenge in activeChallenges where !challenge.isExpired {
            guard let member = challengeSelfMember(for: challenge) else { continue }
            leaderboardService.postChallengeScore(code: challenge.code, member: member)
        }
    }

    /// Updates the goal targets shown on Profile (physical / weight /
    /// deadline). Free text, trimmed and capped so a pasted essay can't
    /// become a "goal".
    func updateGoalTargets(physical: String, weight: String, deadline: String) {
        func clean(_ text: String) -> String {
            String(text.trimmingCharacters(in: .whitespacesAndNewlines).prefix(120))
        }
        clientProfile.physicalGoalTarget = clean(physical)
        clientProfile.weightGoalTarget = clean(weight)
        clientProfile.goalDeadline = clean(deadline)
        persistLocalProfile()
        showToast("Goals updated.")
    }

    /// Updates the training-equipment answer post-onboarding and immediately
    /// re-ranks the plan rotation around it.
    func updateEquipment(_ text: String) {
        clientProfile.equipment = text.trimmingCharacters(in: .whitespacesAndNewlines)
        rebuildPersonalizedPlan()
        persistLocalProfile()
        showToast("Equipment updated — today's plan adjusts.")
    }

    /// The equipment choices onboarding offers — the Profile editor shows the
    /// same list so both surfaces write the same vocabulary into
    /// `clientProfile.equipment` (which `equipmentPreferenceOrder` parses).
    static let equipmentOptions: [String] = [
        "Full gym", "Dumbbells", "Barbell & rack", "Kettlebells",
        "Resistance bands", "Pull-up bar", "Cardio machines", "Pool",
        "Bodyweight only"
    ]

    // MARK: - Nutrition targets (deterministic math on the user's own data)

    /// Parses the free-text body weight ("170", "170 lb", "77 kg") into
    /// pounds. Returns nil for anything unparseable or implausible, in which
    /// case the caller keeps honest starter defaults.
    /// `assumedUnit`: the unit a BARE number means. Callers pass the user's
    /// weight-unit setting — a kg user typing "77" means 77 kg, and reading
    /// it as pounds silently corrupted their chart and nutrition targets
    /// (launch audit P0). An explicit "kg"/"lb" suffix always wins.
    static func parsedBodyWeightLb(_ text: String, assumedUnit: WeightUnit = .pounds) -> Double? {
        let lowered = text.lowercased()
        guard let numberRange = lowered.range(of: #"[0-9]+([.,][0-9]+)?"#, options: .regularExpression),
              var value = Double(lowered[numberRange].replacingOccurrences(of: ",", with: ".")),
              value > 0 else { return nil }
        let saysKg = lowered.contains("kg") || lowered.contains("kilo")
        let saysLb = lowered.contains("lb") || lowered.contains("pound")
        if saysKg || (!saysLb && assumedUnit == .kilograms) {
            value *= 2.20462262
        }
        // Outside a plausible human range the "weight" is probably a typo —
        // better generic targets than absurd personalized ones.
        guard (60...700).contains(value) else { return nil }
        return value
    }

    /// Daily nutrition goal numbers from the user's own logged weight and
    /// goal — standard per-pound coaching heuristics (protein ≈ 0.85 g/lb,
    /// water ≈ weight/20 cups, calories 13–16×lb by goal direction), not AI.
    /// Falls back to the generic starter numbers, and says so, when no
    /// parseable weight has been logged.
    var nutritionTargets: NutritionTargets {
        guard let weightLb = Self.parsedBodyWeightLb(clientProfile.bodyWeight, assumedUnit: weightUnit) else {
            return NutritionTargets(
                calories: 2200, proteinGrams: 160, waterCups: 8,
                sourceNote: "Starter targets — log your weight in Profile to personalize"
            )
        }
        let goalText = (clientProfile.selectedGoals + [clientProfile.goal])
            .joined(separator: " ").lowercased()
        // Fat-loss framing wins when goals mix (e.g. "Lose weight" + "Build
        // consistency") — overshooting calories hurts that goal the most.
        let caloriesPerLb: Double
        if goalText.contains("lose") || goalText.contains("lean") || goalText.contains("fat")
            || goalText.contains("cut") || goalText.contains("weight loss") {
            caloriesPerLb = 13
        } else if goalText.contains("build") || goalText.contains("strength")
            || goalText.contains("muscle") || goalText.contains("bulk") {
            caloriesPerLb = 16
        } else {
            caloriesPerLb = 15
        }
        return NutritionTargets(
            calories: Int(((weightLb * caloriesPerLb) / 50).rounded()) * 50,
            proteinGrams: Int(((weightLb * 0.85) / 5).rounded()) * 5,
            waterCups: min(max(Int((weightLb / 20).rounded()), 8), 16),
            sourceNote: "Based on your logged weight (\(Int(weightLb.rounded())) lb) and goal"
        )
    }

    /// Pushes the computed targets into the nutrition card's goal fields.
    /// Goals only — consumed counts are the day's real log and stay intact.
    private func applyNutritionTargets() {
        let targets = nutritionTargets
        nutrition.calorieGoal = targets.calories
        nutrition.proteinGoal = targets.proteinGrams
        nutrition.waterGoal = targets.waterCups
    }

    /// One meal-prep nudge built from the onboarding answers; nil when the
    /// user never answered, or said Never/Occasionally without interest
    /// (no unsolicited prep sermons).
    var mealPrepTip: String? {
        let habit = clientProfile.mealPrepHabit
        guard !habit.isEmpty else { return nil }
        if habit == MealPrepOption.weekly.rawValue || habit == MealPrepOption.mostMeals.rawValue {
            return "You already prep — batch one extra protein source and lunches are covered."
        }
        return clientProfile.mealPrepInterested
            ? "Start with one prepped breakfast this week — smallest possible win."
            : nil
    }

    func updateExperienceLevel(_ level: ExperienceLevelOption) {
        guard clientProfile.fitnessLevel != level.rawValue else { return }
        clientProfile.fitnessLevel = level.rawValue
        // The level drives the difficulty engine: rebuild the plan rotation
        // and today's task mix (keeping XP already earned today).
        rebuildPersonalizedPlan()
        regenerateDailyTasksPreservingCompletions()
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

    // MARK: - Progress chart data (derived from real per-set log data)

    /// Normalizes a logged weight into the current display unit. Logs keep
    /// the unit they were recorded in (`LoggedExercise.weightUnit`), so a
    /// lb-era log stays honest after the user flips the app to kg.
    private func normalizedLoggedWeight(_ value: Double, recordedUnit: String?) -> Double {
        let recorded = WeightUnit(rawValue: recordedUnit ?? "") ?? weightUnit
        guard recorded != weightUnit else { return value }
        let factor = weightUnit == .kilograms ? 0.45359237 : 2.20462262
        return ((value * factor) * 10).rounded() / 10
    }

    /// The user's most-logged exercises (sessions with real weighted sets
    /// only) — feeds the strength-over-time picker so it offers movements
    /// that can actually draw a line.
    func mostLoggedExerciseNames(limit: Int = 6) -> [String] {
        var sessionCounts: [String: Int] = [:]
        for log in currentAthleteWorkoutLogs {
            for exercise in log.exercises {
                guard let weights = exercise.weightsPerSet,
                      weights.contains(where: { $0 > 0 }) else { continue }
                sessionCounts[exercise.name, default: 0] += 1
            }
        }
        return sessionCounts
            .sorted { lhs, rhs in
                if lhs.value == rhs.value { return lhs.key < rhs.key }
                return lhs.value > rhs.value
            }
            .prefix(max(limit, 0))
            .map(\.key)
    }

    /// Top-set weight per session for one exercise, oldest first, in the
    /// current display unit. One point per session (the heaviest set), so
    /// the chart reads as progression rather than intra-session noise.
    func strengthProgression(for exerciseName: String) -> [(date: Date, topWeight: Double)] {
        currentAthleteWorkoutLogs
            .sorted { $0.completedAt < $1.completedAt }
            .compactMap { log in
                let sessionTop = log.exercises
                    .filter { $0.name == exerciseName }
                    .compactMap { exercise -> Double? in
                        guard let weights = exercise.workingWeightsPerSet,
                              let top = weights.max(), top > 0 else { return nil }
                        return normalizedLoggedWeight(top, recordedUnit: exercise.weightUnit)
                    }
                    .max()
                guard let sessionTop else { return nil }
                return (date: log.completedAt, topWeight: sessionTop)
            }
    }

    /// Estimated 1RM per session for one exercise (Epley: weight × (1 +
    /// reps/30) on each set, best set per session), oldest first, current
    /// display unit. Catches the progress a raw top-set line hides — 185×5
    /// → 185×8 is a FLAT top-set line but a rising e1RM. Pure arithmetic on
    /// logged numbers; reps cap at 15 because rep-range formulas stop
    /// meaning anything past that.
    func estimatedOneRMProgression(for exerciseName: String) -> [(date: Date, topWeight: Double)] {
        let ordered = currentAthleteWorkoutLogs.sorted { $0.completedAt < $1.completedAt }
        var points: [(date: Date, topWeight: Double)] = []
        for log in ordered {
            var sessionBest: Double = 0
            for exercise in log.exercises where exercise.name == exerciseName {
                guard let weights = exercise.weightsPerSet,
                      let reps = exercise.repsPerSet else { continue }
                let warmups = exercise.warmupPerSet ?? []
                for (index, pair) in zip(weights, reps).enumerated() where pair.0 > 0 && pair.1 > 0 {
                    // Warm-up sets never feed the e1RM estimate.
                    if warmups.indices.contains(index), warmups[index] { continue }
                    let (weight, repCount) = pair
                    let epley: Double = weight * (1 + Double(min(repCount, 15)) / 30)
                    let rounded: Double = (epley * 10).rounded() / 10
                    let normalized = normalizedLoggedWeight(rounded, recordedUnit: exercise.weightUnit)
                    sessionBest = max(sessionBest, normalized)
                }
            }
            if sessionBest > 0 {
                points.append((date: log.completedAt, topWeight: sessionBest))
            }
        }
        return points
    }

    /// Exercises that have STALLED: 4+ weighted sessions and no new top-set
    /// high in the last 3. Deterministic — a flag, not advice; the UI pairs
    /// it with the standard deload/rep-change playbook.
    var stalledExerciseNames: [String] {
        var perExercise: [String: [(date: Date, top: Double)]] = [:]
        for log in currentAthleteWorkoutLogs {
            for exercise in log.exercises {
                guard let top = exercise.weightsPerSet?.max(), top > 0 else { continue }
                let normalized = normalizedLoggedWeight(top, recordedUnit: exercise.weightUnit)
                perExercise[exercise.name, default: []].append((log.completedAt, normalized))
            }
        }
        return perExercise
            .compactMap { name, sessions -> String? in
                guard sessions.count >= 4 else { return nil }
                let ordered = sessions.sorted { $0.date < $1.date }
                let recent = ordered.suffix(3)
                let bestBefore = ordered.dropLast(3).map(\.top).max() ?? 0
                guard let bestRecent = recent.map(\.top).max(),
                      bestRecent <= bestBefore else { return nil }
                return name
            }
            .sorted()
    }

    /// Total logged sets per week for the last `weeks` weeks (current week
    /// included), oldest first. Weeks with no training report zero so the
    /// bar chart shows honest gaps instead of compressing them away.
    func weeklySetVolume(weeks: Int = 8) -> [(weekStart: Date, sets: Int)] {
        let calendar = Calendar.current
        guard weeks > 0,
              let currentWeekStart = calendar.dateInterval(of: .weekOfYear, for: .now)?.start
        else { return [] }

        var buckets: [Date: Int] = [:]
        for log in currentAthleteWorkoutLogs {
            guard let weekStart = calendar.dateInterval(of: .weekOfYear, for: log.completedAt)?.start
            else { continue }
            let sets = log.exercises.reduce(0) { total, exercise in
                if let reps = exercise.repsPerSet, !reps.isEmpty {
                    return total + reps.count
                }
                // Older logs carry only the display string ("3 sets" / "4").
                return total + (Int(exercise.sets.prefix(while: \.isNumber)) ?? 0)
            }
            buckets[weekStart, default: 0] += sets
        }

        return (0..<weeks).reversed().compactMap { offset in
            guard let weekStart = calendar.date(byAdding: .weekOfYear, value: -offset, to: currentWeekStart)
            else { return nil }
            return (weekStart: weekStart, sets: buckets[weekStart] ?? 0)
        }
    }

    /// Sets per muscle group over the last `days` days, largest first — the
    /// "am I neglecting legs?" view. Counts ONLY sets whose log carries a
    /// muscle group (recorded from Tier-3 onward); the card names that
    /// unlock instead of mislabeling older history.
    func muscleGroupSetBalance(days: Int = 7) -> [(group: String, sets: Int)] {
        let cutoff = Calendar.current.date(byAdding: .day, value: -max(days, 1), to: .now) ?? .now
        var buckets: [String: Int] = [:]
        for log in currentAthleteWorkoutLogs where log.completedAt >= cutoff {
            for exercise in log.exercises {
                guard let group = exercise.muscleGroup, !group.isEmpty else { continue }
                let sets: Int
                if let reps = exercise.repsPerSet, !reps.isEmpty {
                    sets = reps.count
                } else {
                    sets = Int(exercise.sets.prefix(while: \.isNumber)) ?? 0
                }
                if sets > 0 {
                    buckets[group, default: 0] += sets
                }
            }
        }
        return buckets
            .map { (group: $0.key, sets: $0.value) }
            .sorted { lhs, rhs in
                lhs.sets != rhs.sets ? lhs.sets > rhs.sets : lhs.group < rhs.group
            }
    }

    /// Average rated RPE per session for the last `sessions` sessions where
    /// at least one set was rated, oldest first. Unrated sets (0) are
    /// excluded rather than dragging the average toward zero.
    func rpeTrendPerSession(sessions: Int = 15) -> [(date: Date, averageRPE: Double)] {
        let points: [(date: Date, averageRPE: Double)] = currentAthleteWorkoutLogs
            .sorted { $0.completedAt < $1.completedAt }
            .compactMap { log in
                let rated = log.exercises
                    .flatMap { $0.rpePerSet ?? [] }
                    .filter { $0 > 0 }
                guard !rated.isEmpty else { return nil }
                let average = Double(rated.reduce(0, +)) / Double(rated.count)
                return (date: log.completedAt, averageRPE: (average * 10).rounded() / 10)
            }
        return Array(points.suffix(max(sessions, 0)))
    }

    /// The last `limit` personal records, newest first: for each exercise,
    /// its all-time top set and the FIRST session that hit it. Matching an
    /// existing record later is not a new PR, so the original date sticks.
    func recentPersonalRecords(limit: Int = 5) -> [(date: Date, exerciseName: String, weight: Double)] {
        var best: [String: (weight: Double, date: Date)] = [:]
        for log in currentAthleteWorkoutLogs.sorted(by: { $0.completedAt < $1.completedAt }) {
            for exercise in log.exercises {
                guard let weights = exercise.workingWeightsPerSet,
                      let top = weights.max(), top > 0 else { continue }
                let normalized = normalizedLoggedWeight(top, recordedUnit: exercise.weightUnit)
                if normalized > (best[exercise.name]?.weight ?? 0) {
                    best[exercise.name] = (normalized, log.completedAt)
                }
            }
        }
        return best
            .map { (date: $0.value.date, exerciseName: $0.key, weight: $0.value.weight) }
            .sorted { lhs, rhs in
                if lhs.date == rhs.date { return lhs.exerciseName < rhs.exerciseName }
                return lhs.date > rhs.date
            }
            .prefix(max(limit, 0))
            .map { $0 }
    }

    /// All-time top logged weight per exercise, in the current display unit —
    /// the baseline `logWorkout` diffs against to catch a PR the moment it
    /// lands (same derivation as `recentPersonalRecords`, minus the dates).
    private func personalBestTopWeights() -> [String: Double] {
        var best: [String: Double] = [:]
        for log in currentAthleteWorkoutLogs {
            for exercise in log.exercises {
                guard let top = exercise.workingWeightsPerSet?.max(), top > 0 else { continue }
                let normalized = normalizedLoggedWeight(top, recordedUnit: exercise.weightUnit)
                best[exercise.name] = max(best[exercise.name] ?? 0, normalized)
            }
        }
        return best
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
            selectedCommunitySection = FeatureFlags.socialFeedEnabled ? .forYou : .contact
        } else {
            selectedCoachTab = .dashboard
        }
        Haptics.impact(.light)
        showToast(role == .client ? "Athlete account active." : "Coach account active.")
    }

    /// Replaces the seeded demo coach identity with the real user's. Sports,
    /// goals, and specialty mirror the profile; practice stats start at zero
    /// because a new coach has no athletes, groups, or playbooks yet.
    /// Sports/goals are passed in from the authoritative source (the draft at
    /// onboarding, the snapshot at relaunch) rather than read off clientProfile
    /// — reading clientProfile stamped the seeded demo athlete's sports into a
    /// coach's specialty whenever the coach had no sports of their own.
    private func applyCoachIdentity(name: String, handle: String, sports: [SportFocus], goals: [String],
                                    tenure: String = "", roster: String = "") {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        // The workspace addresses the user as a coach: "Coach Lucas" — unless
        // they already typed the title themselves.
        coachProfile.name = trimmed.lowercased().hasPrefix("coach") ? trimmed : "Coach \(trimmed)"
        if !handle.isEmpty {
            coachProfile.username = handle
        }
        coachProfile.sports = sports
        coachProfile.specialty = sports.isEmpty
            ? "Personal coaching"
            : sports.prefix(3).map(\.rawValue).joined(separator: " / ")
        coachProfile.selectedGoals = goals
        // Honest headline from their own answers — no invented credentials.
        var headlineParts: [String] = []
        if !tenure.isEmpty { headlineParts.append("Coaching \(tenure.lowercased() == "just starting" ? "— just getting started" : "for \(tenure.lowercased())")") }
        if !roster.isEmpty { headlineParts.append("works with \(roster.lowercased())") }
        coachProfile.headline = headlineParts.isEmpty ? "Coaching on Morphe." : headlineParts.joined(separator: " · ")
        coachProfile.networkRank = "Coach"
        coachProfile.activeClients = 0
        coachProfile.groups = []
        coachProfile.playbooks = []
        // Demo training styles must NEVER render for a real coach (profile
        // audit): the seed hardcoded four styles nobody picked and no
        // editor existed. Real identity starts empty; sports carry it.
        coachProfile.selectedTrainingStyles = []
        // A headline the coach EDITED (stored custom) outranks the derived
        // one — re-derivation must not eat their words.
        if !customCoachHeadline.isEmpty {
            coachProfile.headline = customCoachHeadline
        }
    }

    func completeOnboarding() {
        let generatedPlan = MorpheDemoContent.generatedPlan(from: onboardingDraft)
        let primarySport = onboardingDraft.selectedSports.first ?? .generalFitness
        let selectedGoals = onboardingDraft.selectedGoals.map(\.rawValue)

        let trimmedName = onboardingDraft.name.trimmingCharacters(in: .whitespacesAndNewlines)
        let resolvedName = trimmedName.isEmpty ? clientProfile.name : trimmedName

        hasCompletedOnboarding = true
        // (firstWeekStart is stamped AFTER resetToFreshUser below — stamping
        // here persisted it under the SEEDED demo profile id, which the
        // minted identity never reads, so the arc vanished on relaunch.)
        // The signed-up account role is the source of truth once accounts are
        // real — the draft's default must never demote a coach to athlete.
        selectedRole = authUser?.role.appRole ?? onboardingDraft.accountType
        clientProfile.name = resolvedName
        profileShowcase.displayName = resolvedName
        // The @username the user picked (and the directory reserved) during
        // onboarding. The name-derived handle survives only as the offline
        // fallback — accounts always pass through the username step.
        let chosenUsername = UsernameRules.normalize(onboardingDraft.username)
        let handle = chosenUsername.isEmpty
            ? resolvedName.lowercased().filter { $0.isLetter || $0.isNumber }
            : chosenUsername
        if !handle.isEmpty {
            profileShowcase.username = handle
        }
        selectedClientTab = .today
        selectedCoachTab = .dashboard
        selectedCommunitySection = FeatureFlags.socialFeedEnabled ? .forYou : .contact
        selectedSportMode = primarySport
        // Gender is copied only when the user actually answered the step —
        // never the draft's silent default.
        if onboardingDraft.genderChosen {
            clientProfile.gender = onboardingDraft.gender
        }
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
        currentPlanAdjustment = Self.neutralPlanAdjustment
        goalTranslation = generatedPlan.goalTranslation
        MorpheTheme.apply(accentPalette: onboardingDraft.accentPalette)

        // Mint a fresh identity and clear all seeded demo data so the user
        // starts in THEIR OWN empty account, not the demo athlete's.
        let preMintPrefsKey = trainingPreferencesDefaultsKey
        resetToFreshUser()

        // Week one starts NOW — stamped AFTER the mint so it lands under the
        // key this profile will actually read on relaunch, then explicitly
        // persisted (no other prefs didSet is guaranteed to fire on the solo
        // path). The pre-mint blob is purged: it sits under the FIXED seeded
        // demo id, so a second account on this device would inherit it.
        if firstWeekStart == nil {
            firstWeekStart = .now
        }
        persistTrainingPreferences()
        UserDefaults.standard.removeObject(forKey: preMintPrefsKey)
        // The per-profile mirrors (series, program) follow the minted id.
        reloadPerProfileMirrors()

        // The user's own safety and setup notes — applied AFTER the reset
        // (which clears the demo athlete's) so they actually stick. These were
        // previously discarded and the demo knee complaint persisted instead.
        clientProfile.limitations = onboardingDraft.injuries.trimmingCharacters(in: .whitespacesAndNewlines)
        clientProfile.equipment = onboardingDraft.equipment.trimmingCharacters(in: .whitespacesAndNewlines)
        clientProfile.mealPrepHabit = onboardingDraft.mealPrepFrequency.rawValue
        clientProfile.mealPrepInterested = onboardingDraft.mealPrepInterested
        // Agreeing on the review step IS accepting the terms — the standalone
        // gate only appears for accounts that predate the in-flow consent.
        if onboardingDraft.agreedToTerms {
            hasAcceptedTerms = true
        }
        rebuildPersonalRules()
        // Nutrition goals framed by the goals just chosen (weight arrives
        // later via Profile; until then these stay the labeled starters).
        applyNutritionTargets()

        // A coach account is the USER's practice, not demo "Coach Marcus" —
        // stamp their identity into the workspace and zero the seeded stats.
        if selectedRole == .coach {
            applyCoachIdentity(
                name: resolvedName,
                handle: handle,
                sports: onboardingDraft.selectedSports,
                goals: selectedGoals,
                tenure: onboardingDraft.coachTenure.rawValue,
                roster: onboardingDraft.coachRoster.rawValue
            )
        }

        // Today's plan draws from the 348-workout catalog, matched to the
        // user's level and rotated by focus day to day — the plan-generation
        // step promises "matched to your sport and level," so it must actually
        // pull from real, varied content instead of the same 5 seeds. Seeded
        // templates remain the fallback when the catalog isn't available.
        rebuildPersonalizedPlan()
        planDayIndex = 0
        // Day-one tasks come from the engine too — matched to the level the
        // user just chose, not the demo defaults.
        todayTasks = personalizedDailyTasks()
        minimumWinTasks = personalizedMinimumWinTasks()
        if !stagePlanWorkout() {
            if let firstWorkout = bestFirstWorkout(sport: primarySport, level: onboardingDraft.experienceLevel) {
                currentWorkoutID = firstWorkout.id
            }
        }

        // The welcome sheet IS the completion celebration. Onboarding's
        // review step collected explicit terms consent (with the full text
        // one tap away) — honoring it here keeps ONE gate instead of
        // making users agree twice ten seconds apart. The wall still
        // catches accounts that never agreed (pre-toggle restores).
        if onboardingDraft.agreedToTerms {
            hasAcceptedTerms = true
            showWelcomeExperience = true
        } else {
            welcomeAwaitsTermsAcceptance = true
        }
        // First real save of the account — and push it to the cloud
        // immediately: the rate limit is for routine edits, not for the
        // moment the account starts existing. (The actual write happens in
        // the flush at the end of this method, after the plan is staged.)
        forceNextProfileCloudPush = true
        persistLocalProfile()

        // A coach invite code claims AFTER the reset above — the imported
        // history lands in the fresh account instead of being wiped with the
        // demo data. Athlete accounts only; a coach signing up has no coach.
        let inviteCode = onboardingDraft.coachInviteCode
            .trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        if selectedRole == .client, !inviteCode.isEmpty {
            Task { await claimCoachInvite(code: inviteCode) }
        }

        // Everything onboarding decided (profile AND the freshly staged
        // session) lands on disk before this method returns — a crash a
        // second later must not send the user through onboarding again.
        flushPendingPersists()
    }

    /// Best seeded template for a brand-new user: their sport at their level,
    /// then their sport at any level, then general fitness at their level.
    private func bestFirstWorkout(sport: SportFocus, level: ExperienceLevelOption) -> WorkoutTemplate? {
        let target: DemoDifficulty = {
            switch level {
            case .beginner: return .beginner
            case .intermediate: return .moderate
            case .advanced: return .advanced
            }
        }()
        // A first workout is a real training session: no recovery pivots, no
        // sub-20-minute fallbacks — those otherwise win on array order and
        // make a weak first impression.
        let trainable = workoutTemplates.filter {
            $0.sessionType != .recoverySession
                && $0.category != .recovery
                && $0.difficulty != .recovery
                && $0.durationMinutes >= 20
        }
        let sportMatches = trainable.filter { $0.sport == sport }
        // The chain must never dead-end: the old generalFitness-only fallback
        // was provably nil (both generalFitness seeds are short/recovery), so
        // every sport without a seeded template silently kept the default.
        return sportMatches.first(where: { $0.difficulty == target })
            ?? sportMatches.first
            ?? trainable.first(where: { $0.difficulty == target })
            ?? trainable.first
    }

    // MARK: - Personalized daily plan (catalog-backed)

    private func planTargetDifficulty(for level: String) -> DemoDifficulty {
        let l = level.lowercased()
        if l.contains("begin") { return .beginner }
        if l.contains("adv") { return .advanced }
        return .moderate
    }

    /// Soft equipment ranking from the user's free-text setup — a preference
    /// for ordering, never an exclusion (the onboarding equipment field is
    /// unstructured, so filtering on it would wrongly drop content).
    private func equipmentPreferenceOrder() -> [String] {
        let e = clientProfile.equipment.lowercased()
        if e.contains("gym") { return ["Full Gym", "Dumbbells", "Bodyweight"] }
        if e.contains("dumbbell") || e.contains("kettlebell") || e.contains("home") { return ["Dumbbells", "Bodyweight", "Full Gym"] }
        // Pool-only (or bands/bar-only) selections have no barbell access —
        // bodyweight-first is the honest ordering until the catalog carries
        // pool-specific sessions.
        if e.contains("body") || e.contains("pool") || e.contains("band") || e.isEmpty {
            return ["Bodyweight", "Dumbbells", "Full Gym"]
        }
        return ["Dumbbells", "Bodyweight", "Full Gym"]
    }

    // MARK: Plan candidate ranking (sport preference + injury down-ranking)

    /// Injury vocabulary: flag word -> body area. Extends the areas the
    /// pain-flag flow (`painAlternative`) already understands so the free-text
    /// onboarding note and the in-session pain report speak the same language.
    private static let injuryAreaKeywords: [String: String] = [
        "knee": "knee", "acl": "knee", "mcl": "knee", "meniscus": "knee", "patella": "knee",
        "shoulder": "shoulder", "rotator": "shoulder", "labrum": "shoulder",
        "back": "back", "spine": "back", "lumbar": "back", "disc": "back", "sciatica": "back",
        "hip": "hip", "groin": "hip",
        "ankle": "ankle", "achilles": "ankle",
        "wrist": "wrist",
        "elbow": "elbow"
    ]

    /// Movement words that load each flagged area (matched against exercise
    /// names, lowercased).
    private static let areaStressKeywords: [String: [String]] = [
        "knee": ["squat", "lunge", "jump", "pistol", "step-up", "step up", "bound", "wall sit", "skater"],
        "shoulder": ["press", "push-up", "push up", "pushup", "overhead", "dip", "handstand", "snatch", "jerk", "raise"],
        "back": ["deadlift", "good morning", "row", "swing", "clean", "back extension", "superman", "hyperextension"],
        "hip": ["squat", "lunge", "deadlift", "thrust", "bridge", "sprint", "kick"],
        "ankle": ["jump", "sprint", "run", "hop", "skip", "bound", "calf", "skater"],
        "wrist": ["push-up", "push up", "pushup", "plank", "handstand", "burpee", "crawl"],
        "elbow": ["curl", "extension", "dip", "press", "push-up", "push up", "pushup"]
    ]

    /// The focus bucket that concentrates work on each flagged area.
    private static let areaFocusTags: [String: String] = [
        "knee": "Legs", "hip": "Legs", "ankle": "Conditioning",
        "shoulder": "Push", "elbow": "Push", "wrist": "Push",
        "back": "Pull"
    ]

    /// Pure, explainable parse of the free-text injury note ("knee pain after
    /// squats" -> {"knee"}). Keyword table only — no guessing beyond it.
    static func flaggedAreas(from note: String) -> Set<String> {
        let lowered = note.lowercased()
        guard !lowered.isEmpty else { return [] }
        var areas: Set<String> = []
        for (keyword, area) in injuryAreaKeywords where lowered.contains(keyword) {
            areas.insert(area)
        }
        return areas
    }

    /// How hard a template leans on flagged areas: +2 when its focus bucket
    /// targets the area, +1 per exercise whose name hits a stress keyword
    /// (capped at 3 per area so one long workout can't swamp the score).
    /// A penalty only reorders — it never removes a workout.
    static func injuryPenalty(for template: WorkoutTemplate, areas: Set<String>) -> Int {
        guard !areas.isEmpty else { return 0 }
        let exerciseNames = template.exercises.map { $0.name.lowercased() }
        var penalty = 0
        for area in areas {
            if areaFocusTags[area] == template.focusTag { penalty += 2 }
            let stressWords = areaStressKeywords[area, default: []]
            let hits = exerciseNames.filter { name in stressWords.contains { name.contains($0) } }.count
            penalty += min(hits, 3)
        }
        return penalty
    }

    /// Orders plan candidates within one focus bucket. All signals are SOFT
    /// (sort keys, never filters): injury load first — safety outranks taste —
    /// then sport match, then equipment fit, then name for determinism.
    /// Sport is a preference rather than a filter because small sports have
    /// few catalog templates; excluding mismatches would starve their rotation
    /// down to a handful of repeats.
    static func rankedPlanCandidates(
        _ candidates: [WorkoutTemplate],
        sport: SportFocus,
        equipmentOrder: [String],
        flaggedAreas: Set<String>,
        trainingStyles: [TrainingStyleOption] = []
    ) -> [WorkoutTemplate] {
        // The user's chosen training styles map to catalog vocabulary — a
        // yoga/pilates/dance pick should actually surface those categories.
        // Soft preference like sport: styles reorder, never exclude. (Passed
        // in — this is a static ranking helper with no instance state.)
        let styleKeywords: [String] = trainingStyles.flatMap { style -> [String] in
            switch style {
            case .yoga: return ["yoga"]
            case .pilates: return ["pilates"]
            case .dance, .aerobics: return ["dance", "aerobics"]
            case .strength: return ["strength", "powerlifting"]
            case .hypertrophy: return ["hypertrophy", "bodybuilding"]
            case .conditioning: return ["hiit", "conditioning"]
            case .endurance, .speed: return ["cardio", "running", "sport"]
            case .mobility, .recovery: return ["mobility", "recovery"]
            case .skillWork: return ["calisthenics", "functional"]
            case .fatLoss: return ["hiit", "conditioning"]
            case .hybrid: return []
            }
        }

        func key(_ t: WorkoutTemplate) -> (Int, Int, Int, Int, String) {
            // generalFitness templates count as a match: they're the sport-
            // agnostic backbone of the catalog, not a mismatch to bury.
            let sportRank = (t.sport == sport || t.sport == .generalFitness) ? 0 : 1
            let haystack = "\(t.categoryTag) \(t.focusTag) \(t.trainingTypeTag) \(t.type)".lowercased()
            let styleRank = (styleKeywords.isEmpty
                || styleKeywords.contains(where: { haystack.contains($0) })) ? 0 : 1
            let equipmentRank = equipmentOrder.firstIndex(of: t.equipment) ?? equipmentOrder.count
            return (injuryPenalty(for: t, areas: flaggedAreas), sportRank, styleRank, equipmentRank, t.name)
        }
        return candidates.sorted { key($0) < key($1) }
    }


    /// Rebuilds the daily-plan rotation from the catalog: filtered to the
    /// user's level, ranked by injury safety + sport preference + equipment
    /// fit, and round-robined across focus (Full Body / Legs / Push / Pull /
    /// Conditioning / Core) so each day changes focus and many distinct
    /// workouts pass before any repeat.
    func rebuildPersonalizedPlan() {
        let level = planTargetDifficulty(for: clientProfile.fitnessLevel)
        let trainable = catalogWorkouts.filter {
            $0.difficulty == level && $0.durationMinutes >= 20 && $0.focusTag != "Recovery"
        }
        guard !trainable.isEmpty else { personalizedPlanIDs = []; return }

        let pref = equipmentPreferenceOrder()
        let areas = Self.flaggedAreas(from: clientProfile.limitations)

        let focusOrder = ["Full Body", "Legs", "Push", "Pull", "Conditioning", "Core"]
        let buckets: [[WorkoutTemplate]] = focusOrder
            .map { focus in
                Self.rankedPlanCandidates(
                    trainable.filter { $0.focusTag == focus },
                    sport: clientProfile.sportMode,
                    equipmentOrder: pref,
                    flaggedAreas: areas,
                    trainingStyles: clientProfile.selectedTrainingStyles
                )
            }
            .filter { !$0.isEmpty }
        guard !buckets.isEmpty else { personalizedPlanIDs = []; return }

        var sequence: [UUID] = []
        var round = 0
        let maxLength = 24
        while sequence.count < maxLength {
            var addedThisRound = false
            for bucket in buckets where round < bucket.count {
                sequence.append(bucket[round].id)
                addedThisRound = true
                if sequence.count >= maxLength { break }
            }
            if !addedThisRound { break }
            round += 1
        }

        // Adaptive difficulty: when the last sessions say push (rated easy,
        // finished fast, weekly target hit) or ease off (too hard, pain),
        // every third plan day is drawn from one difficulty step up or down
        // instead of a hard swap — progression, not whiplash.
        let bias = workoutIntensityBias
        let blendLevel = Self.shiftDifficulty(level, by: bias)
        if bias != 0, blendLevel != level {
            let blendPool = Self.rankedPlanCandidates(
                catalogWorkouts.filter { $0.difficulty == blendLevel && $0.durationMinutes >= 20 && $0.focusTag != "Recovery" },
                sport: clientProfile.sportMode,
                equipmentOrder: pref,
                flaggedAreas: areas,
                trainingStyles: clientProfile.selectedTrainingStyles
            )
            if !blendPool.isEmpty {
                var blendIndex = 0
                for position in stride(from: 2, to: sequence.count, by: 3) {
                    sequence[position] = blendPool[blendIndex % blendPool.count].id
                    blendIndex += 1
                }
            }
        }

        personalizedPlanIDs = sequence
    }

    /// Stages the plan workout at `planDayIndex` as today's workout. Returns
    /// false (a no-op) when the plan is empty so callers can fall back.
    @discardableResult
    func stagePlanWorkout() -> Bool {
        guard !personalizedPlanIDs.isEmpty else { return false }
        let idx = ((planDayIndex % personalizedPlanIDs.count) + personalizedPlanIDs.count) % personalizedPlanIDs.count
        guard let template = catalogWorkouts.first(where: { $0.id == personalizedPlanIDs[idx] }) else { return false }
        ensureCatalogWorkoutInLibrary(template)
        currentWorkoutID = template.id
        isWorkoutSessionActive = false
        hasStartedWorkoutFlow = false
        hasCompletedWorkoutFlow = false
        activeWorkoutExerciseIndex = 0
        completedWorkoutSets = [:]
        trackedSetReps = [:]
        trackedSetWeights = [:]
        trackedSetRPE = [:]
        trackedSetLabels = [:]
        trackedSetWarmups = [:]
        supersetPartners = [:]
        sessionUserNote = ""
        return true
    }

    /// On a new day, rotate today's plan to the next focus — but only while the
    /// user is still following the auto-plan (currentWorkout is a plan entry),
    /// nothing is in progress, and today isn't already logged. If they switched
    /// to a saved or custom workout, that hand-picked choice is left alone.
    private func advancePlanForNewDayIfOnPlan() {
        guard !personalizedPlanIDs.isEmpty,
              !hasUnsavedSessionWork,
              !isWorkoutLoggedToday,
              personalizedPlanIDs.contains(currentWorkoutID) else { return }
        planDayIndex = (planDayIndex + 1) % personalizedPlanIDs.count
        stagePlanWorkout()
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
        taskCompletionHistory = []
        workoutTemplates.removeAll { customWorkoutIDs.contains($0.id) }
        customWorkoutIDs = []
        customExercises = []
        // A photo file left by a previous account on this device must not
        // become the new user's face on the next relaunch.
        profilePhotoData = nil
        profilePersistence.clearPhoto()

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
        currentPlanAdjustment = Self.neutralPlanAdjustment

        // Honest guidance tips (no fabricated "improved 25%" claims, no "AI" label).
        clientProfile.aiTodayInsight = Self.rotatingDailyTip()
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
        nutrition.nutritionScore = 0
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
        // Same every-user-is-Lucas class of bug: the seeded playbooks and the
        // fabricated analytics ("94% retention") are the demo coach's record,
        // not this user's — zeroed so the UI can hide them instead of
        // flattering a brand-new coach with invented numbers.
        playbooks = []
        coachAnalytics = .empty
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

    /// The triage board derived from REAL coach data (coach audit P0): the
    /// stored `coachOverview` is demo-only and froze at all-zero the moment
    /// the demo purge ran — a coach with unread client messages was told
    /// the reply queue was empty. Every number here has a live source:
    /// roster = managed clients, reply queue = actual unread threads,
    /// sessions = the cloud-backed appointment book, at-risk = no logged
    /// session in 7 days.
    var liveCoachOverview: CoachOverview {
        let roster = visibleManagedClients
        let calendar = Calendar.current
        let weekAgo = calendar.date(byAdding: .day, value: -7, to: .now) ?? .now
        let quiet = roster.filter { ($0.lastLoggedAt ?? .distantPast) < weekAgo }
        let sessionsToday = upcomingAppointments.filter {
            calendar.isDateInToday($0.date)
        }
        let summary: String
        if roster.isEmpty {
            summary = "Add your first client to start coaching."
        } else {
            var parts = ["\(roster.count) client\(roster.count == 1 ? "" : "s")"]
            if !quiet.isEmpty { parts.append("\(quiet.count) quiet 7+ days") }
            if unreadThreadCount > 0 { parts.append("\(unreadThreadCount) unread") }
            summary = parts.joined(separator: " · ")
        }
        return CoachOverview(
            activeClients: roster.count,
            atRiskClients: quiet.count,
            checkInsNeeded: quiet.count,
            sessionsToday: sessionsToday.count,
            // No pain-flag data source exists for managed clients yet —
            // 0 here, and the dashboard hides the tile rather than claim
            // monitoring that isn't happening.
            painFlags: 0,
            messagesNeedingResponse: unreadThreadCount,
            alerts: quiet.map { "\($0.name) hasn't logged in 7+ days" },
            wins: [],
            todaySessions: sessionsToday.map {
                "\($0.title) — \($0.date.formatted(date: .omitted, time: .shortened))"
            },
            sportAlerts: [],
            weeklySummary: summary,
            insight: AIInsight(
                title: roster.isEmpty ? "Getting started" : "This week",
                summary: roster.isEmpty
                    ? "Connect your first athlete and your coaching dashboard fills in from their real activity."
                    : summary,
                risk: quiet.isEmpty ? .low : .medium,
                recommendation: quiet.isEmpty
                    ? (roster.isEmpty ? "Invite an athlete or share your coach profile." : "Roster's moving — keep the messages flowing.")
                    : "Check in with \(quiet.first?.name ?? "your quiet clients") — a message restarts more streaks than a program tweak.",
                suggestedAction: roster.isEmpty ? "Add a client" : "Open Messages"
            )
        )
    }

    /// Honest roster analytics (benchmark Tier 2 — the gap Trainerize's own
    /// users complain about). Every number names its source and appears
    /// only when the underlying data exists; completion is computed ONLY
    /// over assignments old enough to judge AND clients who share progress.
    struct LiveCoachAnalytics {
        var rosterCount = 0
        /// Clients with a session (shared or coach-logged) inside 7 days.
        var activeThisWeek = 0
        /// Clients silent 7+ days — same derivation as the triage board.
        var quietCount = 0
        /// Threads whose LAST message is the client's — the real reply queue.
        var awaitingReply = 0
        /// Confirmable assignment completion — nil when no assignment is
        /// both ≥1 day old and covered by shared progress (no invented %).
        var assignmentCompletion: (done: Int, total: Int)?
    }

    var liveCoachAnalytics: LiveCoachAnalytics {
        let roster = visibleManagedClients
        var analytics = LiveCoachAnalytics()
        analytics.rosterCount = roster.count
        guard !roster.isEmpty else { return analytics }
        let calendar = Calendar.current
        let weekAgo = calendar.date(byAdding: .day, value: -7, to: .now) ?? .now
        let myUid = authUser?.id ?? ""

        for client in roster {
            let sharedSessions = client.isClaimed
                ? (coachShareSummaries[client.claimedByUid]?.recentSessions ?? [])
                : []
            let lastActivity = max(
                client.lastLoggedAt ?? .distantPast,
                sharedSessions.map(\.completedAt).max() ?? .distantPast
            )
            if lastActivity >= weekAgo {
                analytics.activeThisWeek += 1
            } else {
                analytics.quietCount += 1
            }
            // Completion only where it can be VERIFIED: shared progress
            // exists and the assignment day has passed.
            if client.isClaimed, let summary = coachShareSummaries[client.claimedByUid] {
                for assignment in client.assignments
                where assignment.scheduledFor < calendar.startOfDay(for: .now) {
                    let done = summary.recentSessions.contains {
                        $0.title == assignment.workout.name
                            && $0.completedAt >= calendar.startOfDay(for: assignment.scheduledFor)
                    }
                    let current = analytics.assignmentCompletion ?? (0, 0)
                    analytics.assignmentCompletion = (current.done + (done ? 1 : 0), current.total + 1)
                }
            }
        }
        analytics.awaitingReply = liveThreads.filter {
            !$0.lastSender.isEmpty && $0.lastSender != myUid
        }.count
        return analytics
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
        persistLocalProfile()
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
        // Today's inputs become a history point — the check-in used to be
        // discarded at day rollover.
        recordRecoveryCheckInEntry()
        track("checkin_completed")
        Haptics.success()
        persistLocalProfile()
        // A fresh readiness read is exactly what a coach wants to see.
        pushCoachShareIfEnabled()
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
        persistLocalProfile()
        showToast("Minimum Win Mode is on.")
    }

    /// The way back OUT — audit finding: activation was a one-way door
    /// until the nightly reset, which read as losing the day's workout.
    func deactivateMinimumWinMode() {
        guard minimumWinModeEnabled else { return }
        minimumWinModeEnabled = false
        currentPlanAdjustment = Self.neutralPlanAdjustment
        persistLocalProfile()
        Haptics.impact(.light)
        showToast("Back to the full plan.")
    }

    func choosePlanB(_ reason: PlanBReason) {
        confirmDiscardingSessionWork("Switch to Plan B?") { [weak self] in
            self?.performChoosePlanB(reason)
        }
    }

    private func performChoosePlanB(_ reason: PlanBReason) {
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
        persistLocalProfile()
        showToast(reason.rawValue)
    }

    func protectStreak(with option: String) {
        streakProtected = true
        recordProtectedDay()
        // A protected day counts as training — the streak deadline moved.
        refreshStreakRiskReminder()
        showCelebration(title: "Momentum protected", detail: option, symbol: "shield.fill")
        showToast("Momentum protected.")
    }

    /// Makes streak protection REAL: the day is persisted and counts as an
    /// on-schedule day in the streak computation. ("Momentum protected" used
    /// to write a flag nothing read — the streak still showed 0 the next day.)
    private func recordProtectedDay() {
        let key = Self.dayKey()
        guard !protectedDayKeys.contains(key) else { return }
        protectedDayKeys.insert(key)
        refreshWorkoutLogDerivedState(for: clientProfile.id)
        persistLocalProfile()
    }

    // MARK: - Personalized difficulty engine
    //
    // Tasks and the workout plan scale from signals the user actually
    // produced: their experience level, which daily tasks they close, how
    // they rate finished sessions, and how fast they finish them. Nothing
    // here is invented — every adjustment is traceable to a logged action,
    // and the notes below the cards say which signal moved the dial.

    /// Rolling per-day task results (last 28 recorded days).
    var taskCompletionHistory: [TaskDayRecord] = []

    /// 0 gentle … 4 demanding. Base and ceiling come from the profile level
    /// (beginner 0…2, intermediate 1…3, advanced 3…4); weeks of consistently
    /// closed tasks raise it one step at a time, and a slipping recent close
    /// rate trims it back.
    var taskDifficultyDial: Int {
        let level = clientProfile.fitnessLevel.lowercased()
        let base: Int, cap: Int
        if level.contains("begin") { base = 0; cap = 2 }
        else if level.contains("adv") { base = 3; cap = 4 }
        else { base = 1; cap = 3 }

        // Long-arc growth: every ~10 strong days (60%+ closed) earns a step.
        let strongDays = taskCompletionHistory
            .filter { $0.total > 0 && Double($0.completed) / Double($0.total) >= 0.6 }
            .count
        var dial = base + min(strongDays / 10, 2)

        // Short-arc correction from the last two recorded weeks.
        let recent = taskCompletionHistory.suffix(14)
        if recent.count >= 4 {
            let done = recent.reduce(0) { $0 + $1.completed }
            let total = max(recent.reduce(0) { $0 + $1.total }, 1)
            let rate = Double(done) / Double(total)
            if rate >= 0.8 { dial += 1 } else if rate < 0.35 { dial -= 1 }
        }
        return min(max(dial, 0), cap)
    }

    /// The recent-two-weeks task close rate, or nil with too little history.
    private var recentTaskCloseRate: Double? {
        let recent = taskCompletionHistory.suffix(14)
        guard recent.count >= 4 else { return nil }
        let done = recent.reduce(0) { $0 + $1.completed }
        let total = recent.reduce(0) { $0 + $1.total }
        guard total > 0 else { return nil }
        return Double(done) / Double(total)
    }

    private static let easyTaskPool: [(String, Int)] = [
        ("Drink 2 cups of water", 10),
        ("Walk 10 minutes", 10),
        ("Stand up and stretch for 2 minutes", 8),
        ("Eat one protein-rich meal", 10),
        ("Get 10 minutes of daylight", 8),
        ("Do 10 slow air squats", 10)
    ]

    private static let steadyTaskPool: [(String, Int)] = [
        ("Log your workout within 24 hours", 15),
        ("Walk 20 minutes", 15),
        ("Hit your water goal", 15),
        ("Stretch for 10 minutes", 15),
        ("Prep or plan tomorrow's meals", 15),
        ("Take the stairs every chance today", 12)
    ]

    private static let stretchTaskPool: [(String, Int)] = [
        ("Hit protein goal", 20),
        ("Add one extra set to your hardest lift", 25),
        ("Walk 8,000 steps", 20),
        ("10-minute mobility flow after training", 18),
        ("Write a short reflection on today's session", 12),
        ("No missed meals today", 22)
    ]

    /// Builds today's 4-task plan around the workout anchor. The mix shifts
    /// with the dial (all-easy at 0 → mostly stretch at 4) and rotates
    /// through the pools by calendar day. Deterministic for a given day and
    /// dial, so a same-day relaunch regenerates the identical list and
    /// completions re-apply by title.
    func personalizedDailyTasks(for date: Date = .now) -> [TaskItem] {
        let mix: (easy: Int, steady: Int, stretch: Int)
        switch taskDifficultyDial {
        case 0: mix = (3, 0, 0)
        case 1: mix = (2, 1, 0)
        case 2: mix = (1, 2, 0)
        case 3: mix = (1, 1, 1)
        default: mix = (0, 1, 2)
        }

        let seed = Calendar.current.ordinality(of: .day, in: .year, for: date) ?? 0
        func take(_ pool: [(String, Int)], _ count: Int, offset: Int, _ difficulty: TaskDifficulty) -> [TaskItem] {
            (0..<count).map { i in
                let entry = pool[(seed + offset + i) % pool.count]
                return TaskItem(title: entry.0, difficulty: difficulty, isCompleted: false, xp: entry.1)
            }
        }

        var tasks = take(Self.easyTaskPool, mix.easy, offset: 0, .easy)
        // The anchor keeps its exact title: logging a session auto-completes
        // it (markTaskCompleted), and the streak copy references it.
        tasks.append(TaskItem(title: "Complete today's workout", difficulty: .steady, isCompleted: false, xp: 25))
        tasks += take(Self.steadyTaskPool, mix.steady, offset: 1, .steady)
        tasks += take(Self.stretchTaskPool, mix.stretch, offset: 2, .stretch)
        return tasks
    }

    /// Minimum-win fallbacks scale gently with the dial: a smaller win for
    /// an advanced, consistent user is still bigger than a beginner's.
    func personalizedMinimumWinTasks() -> [TaskItem] {
        switch taskDifficultyDial {
        case 0, 1:
            return MorpheDemoContent.minimumWinTasks
        case 2, 3:
            return [
                TaskItem(title: "Walk 10 minutes", difficulty: .easy, isCompleted: false, xp: 10),
                TaskItem(title: "Do 15 bodyweight squats", difficulty: .steady, isCompleted: false, xp: 12),
                TaskItem(title: "5-minute mobility flow", difficulty: .easy, isCompleted: false, xp: 8),
                TaskItem(title: "Drink water", difficulty: .easy, isCompleted: false, xp: 6),
                TaskItem(title: "Log mood", difficulty: .easy, isCompleted: false, xp: 6),
                TaskItem(title: "Watch one form tip", difficulty: .easy, isCompleted: false, xp: 6)
            ]
        default:
            return [
                TaskItem(title: "Walk 15 minutes", difficulty: .steady, isCompleted: false, xp: 12),
                TaskItem(title: "25 squats + 10 push-ups", difficulty: .steady, isCompleted: false, xp: 15),
                TaskItem(title: "10-minute mobility flow", difficulty: .steady, isCompleted: false, xp: 10),
                TaskItem(title: "Hit your water goal", difficulty: .easy, isCompleted: false, xp: 8),
                TaskItem(title: "Log mood", difficulty: .easy, isCompleted: false, xp: 6),
                TaskItem(title: "Plan tomorrow's session", difficulty: .easy, isCompleted: false, xp: 8)
            ]
        }
    }

    private var levelWord: String {
        let level = clientProfile.fitnessLevel.lowercased()
        if level.contains("begin") { return "beginner" }
        if level.contains("adv") { return "advanced" }
        return "intermediate"
    }

    /// Push/hold/ease signal from the last six logged sessions: ratings
    /// (too easy pushes up; too hard or pain pulls down), finishing well
    /// under the planned time, and hitting the weekly training target.
    var workoutIntensityBias: Int {
        let score = workoutIntensityScore
        if score >= 2 { return 1 }
        if score <= -2 { return -1 }
        return 0
    }

    private var workoutIntensityScore: Double {
        let recentLogs = workoutLogs
            .filter { $0.athleteID == clientProfile.id }
            .sorted { $0.completedAt > $1.completedAt }
            .prefix(6)
        guard !recentLogs.isEmpty else { return 0 }

        var score = 0.0
        for log in recentLogs {
            switch log.sessionFeedback.flatMap(WorkoutFeedbackOption.init(rawValue:)) {
            case .tooEasy: score += 1
            case .justRight: score += 0.25
            case .skippedParts: score -= 0.5
            case .tooHard: score -= 1
            case .pain: score -= 1.5
            case nil: break
            }
            // Per-set effort the user actually rated: a session averaging
            // RPE ≤ 6.5 had more in the tank; ≥ 9 was a grind. Unrated sets
            // (0) are ignored — no signal is not a signal.
            let ratedRPEs = log.exercises.flatMap { $0.rpePerSet ?? [] }.filter { $0 > 0 }
            if !ratedRPEs.isEmpty {
                let avgRPE = Double(ratedRPEs.reduce(0, +)) / Double(ratedRPEs.count)
                if avgRPE <= 6.5 { score += 0.5 }
                else if avgRPE >= 9 { score -= 0.5 }
            }
            // A fast clean finish (≤70% of planned time, nothing skipped)
            // reads as headroom.
            if let templateID = log.workoutTemplateID,
               let planned = (workoutTemplates.first(where: { $0.id == templateID })
                    ?? catalogWorkouts.first(where: { $0.id == templateID }))?.durationMinutes,
               planned > 0, log.durationMinutes > 0,
               Double(log.durationMinutes) <= Double(planned) * 0.7,
               log.sessionFeedback != WorkoutFeedbackOption.skippedParts.rawValue {
                score += 0.4
            }
        }

        let weekStart = Calendar.current.dateInterval(of: .weekOfYear, for: .now)?.start ?? .now
        let thisWeek = workoutLogs.filter { $0.athleteID == clientProfile.id && $0.completedAt >= weekStart }.count
        if thisWeek >= clientProfile.trainingDaysPerWeek { score += 0.5 }
        return score
    }

    /// Shown on the Today hero only when the plan is actually trending —
    /// says which logged signal moved it.
    var workoutIntensityNote: String? {
        switch workoutIntensityBias {
        case 1:
            return "Trending up: your recent sessions rated easy or finished fast, so upcoming plan days push a bit harder."
        case -1:
            return "Recent sessions ran heavy, so Morphe is easing the next few plan days."
        default:
            return nil
        }
    }

    /// One difficulty step up or down from the level's target, floored at
    /// beginner and capped at advanced.
    private static func shiftDifficulty(_ difficulty: DemoDifficulty, by bias: Int) -> DemoDifficulty {
        let ladder: [DemoDifficulty] = [.beginner, .moderate, .advanced]
        guard let index = ladder.firstIndex(of: difficulty) else { return difficulty }
        return ladder[min(max(index + bias, 0), ladder.count - 1)]
    }

    /// The two tasks the app closes ITSELF from real actions (logWorkout
    /// marks both). Since the tappable Today's Plan card was retired, these
    /// are the only tasks a user can still complete — so they're the only
    /// ones the difficulty dial is allowed to grade (audit 7, P1-4).
    static let autoDerivedTaskTitles: Set<String> = [
        "Complete today's workout",
        "Log your workout within 24 hours"
    ]

    /// Records one finished day of task results (replacing any earlier
    /// record for the same day) and trims the rolling window.
    private func recordTaskDay(_ day: String, completed: Int, total: Int) {
        guard !day.isEmpty, total > 0 else { return }
        // Never downgrade a day already banked with real completions to a
        // zero — the launch-time rollover re-reports restored days as empty.
        if completed == 0, taskCompletionHistory.contains(where: { $0.day == day }) { return }
        taskCompletionHistory.removeAll { $0.day == day }
        taskCompletionHistory.append(TaskDayRecord(day: day, completed: completed, total: total))
        taskCompletionHistory.sort { $0.day < $1.day }
        if taskCompletionHistory.count > 28 {
            taskCompletionHistory.removeFirst(taskCompletionHistory.count - 28)
        }
    }

    /// Rebuilds today's tasks (after a level edit) without dropping XP the
    /// user already earned: completions carry over by title.
    func regenerateDailyTasksPreservingCompletions() {
        let closed = Set(todayTasks.filter(\.isCompleted).map(\.title))
        todayTasks = personalizedDailyTasks().map { task in
            var task = task
            task.isCompleted = closed.contains(task.title)
            return task
        }
        let closedWins = Set(minimumWinTasks.filter(\.isCompleted).map(\.title))
        minimumWinTasks = personalizedMinimumWinTasks().map { task in
            var task = task
            task.isCompleted = closedWins.contains(task.title)
            return task
        }
    }

    // MARK: - Day rollover

    /// Calendar-day key ("2026-07-05") for daily-state comparisons.
    static func dayKey(for date: Date = .now) -> String {
        let parts = Calendar.current.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
    }

    /// Resets the daily surfaces when a calendar-day boundary passes. Runs at
    /// launch AND on every return to the foreground — an app suspended
    /// overnight used to keep yesterday's "you're done for today", completed
    /// tasks, and check-in state forever.
    func handleDayRolloverIfNeeded(now: Date = .now) {
        let today = Self.dayKey(for: now)
        guard today != lastDailyResetDay else { return }
        let previousDay = lastDailyResetDay
        lastDailyResetDay = today

        // Yesterday's results feed the difficulty dial before the board is
        // wiped — the dial only learns from days that actually ended.
        if hasCompletedOnboarding, !previousDay.isEmpty {
            // Auto-derived tasks only (audit 7, P1-4) — see the restore-path
            // call above for why the full list no longer counts.
            let auto = todayTasks.filter { Self.autoDerivedTaskTitles.contains($0.title) }
            recordTaskDay(
                previousDay,
                completed: auto.filter(\.isCompleted).count,
                total: auto.count
            )
        }

        // Fresh personalized lists, not just unchecked — the mix follows the
        // dial, and a Plan B response that ever swaps in reason-specific
        // tasks can't leak them into the next day.
        todayTasks = personalizedDailyTasks(for: now)
        minimumWinTasks = personalizedMinimumWinTasks()
        minimumWinModeEnabled = false
        streakProtected = false
        didCompleteQuickCheckIn = false
        // Yesterday's Plan B and confidence answer don't describe today.
        selectedConfidence = .maybe
        selectedPlanBReason = nil
        currentPlanAdjustment = Self.neutralPlanAdjustment
        // A new day means a new quiz — selections are per-day, earned
        // completions (completedQuizIDs, XP) are forever.
        quizSelections = [:]

        // The day that just ended becomes a nutrition history point (iff
        // anything was logged) BEFORE the board resets.
        if hasCompletedOnboarding, !previousDay.isEmpty {
            recordNutritionDayIfLogged(dayKey: previousDay)
        }

        // Yesterday's meals, water, and readiness don't describe today.
        nutrition.caloriesConsumed = 0
        nutrition.proteinConsumed = 0
        nutrition.waterConsumed = 0
        nutrition.nutritionScore = 0
        nutrition.meals = []
        recovery = Self.neutralRecovery

        // A new day gets a new tip (they used to be frozen for life).
        clientProfile.aiTodayInsight = Self.rotatingDailyTip(for: now)

        // "Logged today", streak, and score are date-derived — recompute them
        // against the new day instead of trusting launch-time values.
        refreshWorkoutLogDerivedState(for: clientProfile.id)

        // A new day = a different workout, so day 3 isn't a rerun of day 1.
        advancePlanForNewDayIfOnPlan()

        if hasCompletedOnboarding { persistLocalProfile() }
        // Rollover is an action boundary (launch/foreground) — land the new
        // day's state (profile AND the rotated session) on disk right away.
        flushPendingPersists()
        // A new day the app was OPENED counts as an active day.
        trackDayActiveIfNeeded()
    }

    /// Honest, general training tips rotated by calendar day — the same tip
    /// every launch forever read as a broken feature by week two.
    static func rotatingDailyTip(for date: Date = .now) -> AIInsight {
        let tips: [(summary: String, recommendation: String, action: String)] = [
            ("You don't need a perfect session — you need a consistent one. Show up and log it.",
             "Start moderate, protect your sleep tonight, and add some protein.",
             "Start today's workout"),
            ("The first set is the hardest part of the whole workout. Get under it and the rest follows.",
             "Commit to the warm-up only — momentum usually handles the rest.",
             "Start today's workout"),
            ("Progress hides in your logs, not in the mirror. Small weight jumps add up fast.",
             "Try adding one rep or a small amount of weight to one exercise today.",
             "Start today's workout"),
            ("Rest days are training days for recovery. If today is one, take it without guilt.",
             "On rest days, walk, stretch, or do a quick check-in instead of forcing a session.",
             "Do a quick check-in"),
            ("Form first, load second. A clean rep at lighter weight beats a grinding one every time.",
             "Open the form guide for your first exercise before you load the bar.",
             "Start today's workout"),
            ("Consistency beats intensity: three honest sessions a week outwork one heroic Saturday.",
             "Protect your scheduled days this week — even a shortened session counts.",
             "Start today's workout"),
            ("Sleep is the strongest recovery tool you own. Tonight's sleep is part of today's training.",
             "Aim for a consistent bedtime tonight, especially after a hard session.",
             "Do a quick check-in"),
            ("If today feels heavy, shrink it — a minimum win keeps the habit alive when motivation dips.",
             "One small win still counts. Say \"minimum win\" to Morphe AI if you need a lighter day.",
             "Need a smaller win?")
        ]
        let dayIndex = Calendar.current.ordinality(of: .day, in: .year, for: date) ?? 0
        let tip = tips[dayIndex % tips.count]
        return AIInsight(
            title: "Today's tip",
            summary: tip.summary,
            risk: .low,
            recommendation: tip.recommendation,
            suggestedAction: tip.action
        )
    }

    func toggleTask(_ task: TaskItem) {
        guard let index = todayTasks.firstIndex(where: { $0.id == task.id }) else { return }
        todayTasks[index].isCompleted.toggle()
        updateXP(for: todayTasks[index].xp, add: todayTasks[index].isCompleted)

        if todayTasks[index].isCompleted {
            SoundEffects.play(.star)
            showCelebration(
                title: "+\(todayTasks[index].xp) XP",
                detail: todayTasks[index].title,
                symbol: "sparkles"
            )
        }
        // Completions are persisted per-day: without this, every relaunch
        // offered the same unchecked list again — an infinite XP faucet.
        persistLocalProfile()
    }

    func toggleMinimumWinTask(_ task: TaskItem) {
        guard let index = minimumWinTasks.firstIndex(where: { $0.id == task.id }) else { return }
        minimumWinTasks[index].isCompleted.toggle()
        updateXP(for: minimumWinTasks[index].xp, add: minimumWinTasks[index].isCompleted)

        if minimumWinTasks[index].isCompleted {
            streakProtected = true
            recordProtectedDay()
            SoundEffects.play(.star)
            showCelebration(title: "Momentum protected", detail: task.title, symbol: "flame.fill")
            showToast("Momentum protected.")
        } else {
            // Retracting the last minimum win retracts the protection — the
            // day used to stay a streak day forever after an un-check.
            if !minimumWinTasks.contains(where: \.isCompleted) {
                protectedDayKeys.remove(Self.dayKey())
                streakProtected = false
                refreshWorkoutLogDerivedState(for: clientProfile.id)
            }
        }
        // Persist both directions: completions are restored by title on a
        // same-day relaunch, so an un-persisted check was an XP faucet.
        persistLocalProfile()
    }

    /// Workouts the user actually owns: library saves plus their own custom
    /// builds — what Switch rotates through.
    private var ownedWorkoutRotation: [WorkoutTemplate] {
        var seen: Set<UUID> = []
        var rotation: [WorkoutTemplate] = []
        for item in savedWorkouts {
            if let template = workoutTemplates.first(where: { $0.id == item.workoutTemplateID }),
               seen.insert(template.id).inserted {
                rotation.append(template)
            }
        }
        for template in workoutTemplates where customWorkoutIDs.contains(template.id) {
            if seen.insert(template.id).inserted {
                rotation.append(template)
            }
        }
        return rotation
    }

    func cycleWorkout() {
        // Switch rotates through the USER'S workouts (saved + custom built),
        // not the whole seeded template list — cycling 20+ templates the user
        // never chose was a slot machine.
        let rotation = ownedWorkoutRotation

        guard !rotation.isEmpty else {
            showSwitchNeedsSavedWorkouts = true
            return
        }

        if let currentIndex = rotation.firstIndex(where: { $0.id == currentWorkout.id }) {
            guard rotation.count > 1 else {
                // Their only saved workout is already staged.
                showSwitchNeedsSavedWorkouts = true
                return
            }
            let next = rotation[(currentIndex + 1) % rotation.count]
            confirmDiscardingSessionWork("Switch to \(next.name)?") { [weak self] in
                self?.setCurrentWorkout(next)
                self?.showToast("Switched to \(next.name).")
            }
        } else {
            // Current workout isn't one of theirs — enter the rotation.
            let next = rotation[0]
            confirmDiscardingSessionWork("Switch to \(next.name)?") { [weak self] in
                self?.setCurrentWorkout(next)
                self?.showToast("Switched to \(next.name).")
            }
        }
    }

    /// Returns true only when the adjustment ACTUALLY ran — false when it
    /// merely queued the session-work dialog or the template was missing
    /// (audit 8, P0-2): callers who speak about the result must check.
    @discardableResult
    func applyWorkoutAdjustment(_ option: WorkoutAdjustmentOption,
                                navigate: Bool = true,
                                announce: Bool = true) -> Bool {
        // Reschedule leaves the staged workout alone — nothing at risk.
        if option == .reschedule {
            return performWorkoutAdjustment(option, navigate: navigate, announce: announce)
        }
        if hasUnsavedSessionWork {
            // The dialog path keeps the classic behavior (navigate + toast)
            // because the user explicitly confirms there.
            confirmDiscardingSessionWork("\(option.rawValue)?") { [weak self] in
                self?.performWorkoutAdjustment(option)
            }
            return false
        }
        return performWorkoutAdjustment(option, navigate: navigate, announce: announce)
    }

    @discardableResult
    private func performWorkoutAdjustment(_ option: WorkoutAdjustmentOption,
                                          navigate: Bool = true,
                                          announce: Bool = true) -> Bool {
        // Resolve the template FIRST (audit 8, P2): a missing template must
        // fail loudly, not stage adjustment copy for a swap that never ran.
        let templateName: String?
        switch option {
        case .easier, .recovery: templateName = "Low Energy Recovery Day"
        case .shorter, .home: templateName = "15-Minute Quick Workout"
        case .gym: templateName = "Beginner Full Body Strength"
        case .reschedule: templateName = nil
        }
        if let templateName {
            guard let template = resolveWorkoutTemplate(named: templateName) else {
                showToast("That adjustment isn't available right now.")
                return false
            }
            setCurrentWorkout(template)
        }

        switch option {
        case .easier:
            currentPlanAdjustment = MorpheDemoContent.planAdjustment(for: [.workoutTooHard])
        case .shorter:
            currentPlanAdjustment = MorpheDemoContent.planAdjustment(for: [.notEnoughTime])
        case .home:
            currentPlanAdjustment = MorpheDemoContent.planAdjustment(for: [.noEquipment])
        case .gym:
            currentPlanAdjustment = MorpheDemoContent.defaultPlanAdjustment
        case .recovery:
            currentPlanAdjustment = MorpheDemoContent.planAdjustment(for: [.lowRecovery])
        case .reschedule:
            currentPlanAdjustment = PlanAdjustment(
                title: "Moved to tomorrow",
                body: "The main workout moved so you can still keep the day manageable.",
                reasons: [.notEnoughTime],
                recommendation: "Use Minimum Win Mode today and return to the full session tomorrow."
            )
        }

        // The Jarvis ask answers in place (audit 8, P1-1) — it passes
        // navigate/announce false so Today doesn't teleport to Train with
        // a cryptic one-word toast on top of the card's own reply.
        if navigate { showTrainTab() }
        if announce { showToast(option.rawValue) }
        return true
    }

    // MARK: - Session-work gate

    /// A destructive workout change awaiting user confirmation (hosted as a
    /// confirmation dialog at the root). Every path that would replace or
    /// restart today's workout while a live session — or a finished-but-
    /// unlogged recap — exists routes through here: one gate for Today,
    /// Train, Quick Add, Discover, and Morphe AI instead of per-screen
    /// confirmations.
    struct PendingWorkoutChange: Identifiable {
        let id = UUID()
        let title: String
        let action: () -> Void
    }

    var pendingWorkoutChange: PendingWorkoutChange?

    /// True when replacing today's workout would silently destroy work the
    /// user hasn't logged yet.
    var hasUnsavedSessionWork: Bool {
        // Guard only when there's WORK to lose (speed audit S0-8): an
        // accidentally-started session with zero sets doesn't earn a modal
        // claiming "logged sets will be lost."
        (isWorkoutSessionActive && trackedSetTotalCount > 0) || hasCompletedWorkoutFlow
    }

    private func confirmDiscardingSessionWork(_ title: String, then action: @escaping () -> Void) {
        if hasUnsavedSessionWork {
            pendingWorkoutChange = PendingWorkoutChange(title: title, action: action)
        } else {
            action()
        }
    }

    func confirmPendingWorkoutChange() {
        guard let change = pendingWorkoutChange else { return }
        confirmPendingWorkoutChange(change)
    }

    /// The overload the DIALOG calls (audit 8, P0-1): the isPresented
    /// binding clears the pending slot as the dialog closes, so the button
    /// passes its captured-by-value change instead of re-reading the slot.
    /// Every confirm — UI or test — must route here, never `change.action()`
    /// directly, or the finished-recap commit below silently disappears.
    func confirmPendingWorkoutChange(_ change: PendingWorkoutChange) {
        pendingWorkoutChange = nil
        // A FINISHED session's sets are real facts — replacing it must
        // never silently discard them. Commit it first (exactly what "Log
        // Workout" would have written; feedback simply goes unrecorded).
        // Mid-session discards stay discards: the user answered a dialog
        // that said so, and unfinished work is theirs to drop.
        if hasCompletedWorkoutFlow {
            logWorkout()
        }
        change.action()
    }

    func cancelPendingWorkoutChange() {
        pendingWorkoutChange = nil
    }

    func startTodayWorkout() {
        confirmDiscardingSessionWork("Restart today's workout?") { [weak self] in
            self?.performStartTodayWorkout()
        }
    }

    private func performStartTodayWorkout() {
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
        trackedSetLabels = [:]
        trackedSetWarmups = [:]
        supersetPartners = [:]
        sessionUserNote = ""
        workoutFeedbackResponse = ""
        selectedWorkoutFeedback = nil
        showTrainTab()
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
        confirmDiscardingSessionWork("Start \(template.name)?") { [weak self] in
            self?.currentWorkoutID = template.id
            self?.performStartTodayWorkout()
        }
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

    /// Everything browsable in Discover.
    var discoverWorkouts: [WorkoutTemplate] {
        // The v2 library: 112 hand-authored workouts across 10 categories,
        // each tagged with a result goal (categoryTag / goalTag). Sport
        // templates stay out of Discover — they live in Train.
        catalogWorkouts
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
                    note: template.goal,
                    isPinned: persistedPinnedCatalogIDs.contains(idString)
                )
            )
        }
    }

    /// The most recent weight logged for this exercise in the current session,
    /// used to pre-fill the tracker's inline weight field set-to-set.
    func lastSessionWeight(for exerciseID: String) -> Double? {
        trackedSetWeights[exerciseID]?.last
    }

    // MARK: - Progression (suggest more when last time felt easy)

    private func progressionIncrement() -> Double { weightUnit == .kilograms ? 2.5 : 5 }

    /// The top weight the user last logged for an exercise of this name (across
    /// prior sessions, newest first), how that session felt, and the RPE they
    /// rated on that top set (0 / nil = not rated).
    private var topWeightCache: [String: (weight: Double, unit: WeightUnit, feedback: WorkoutFeedbackOption?, topSetRPE: Int?)?] = [:]

    private func lastLoggedTopWeight(forExerciseNamed name: String)
        -> (weight: Double, unit: WeightUnit, feedback: WorkoutFeedbackOption?, topSetRPE: Int?)? {
        if let cached = topWeightCache[name] { return cached }
        let value = computeLastLoggedTopWeight(forExerciseNamed: name)
        topWeightCache[name] = value
        return value
    }

    private func computeLastLoggedTopWeight(forExerciseNamed name: String)
        -> (weight: Double, unit: WeightUnit, feedback: WorkoutFeedbackOption?, topSetRPE: Int?)? {
        for log in workoutLogs where log.athleteID == clientProfile.id {
            // Deload sessions are deliberately light — deriving the next
            // working weight from one would make the cut permanent (bench
            // 100 → deload 90 → post-program suggestions rebuild from 90).
            // The engine looks past them to the last REAL working session.
            guard !log.notes.contains("Deload week.") else { continue }
            guard let logged = log.exercises.first(where: { $0.name == name }),
                  let weights = logged.weightsPerSet,
                  let top = weights.max(), top > 0 else { continue }
            let unit = WeightUnit(rawValue: logged.weightUnit ?? "") ?? weightUnit
            let feedback = log.sessionFeedback.flatMap { WorkoutFeedbackOption(rawValue: $0) }
            // RPE rated on the top set itself (the arrays are parallel);
            // an unrated set (0) reads as no signal.
            var topSetRPE: Int?
            if let rpes = logged.rpePerSet,
               let topIndex = weights.firstIndex(of: top),
               rpes.indices.contains(topIndex), rpes[topIndex] > 0 {
                topSetRPE = rpes[topIndex]
            }
            return (top, unit, feedback, topSetRPE)
        }
        return nil
    }

    /// Suggested working weight for the next set of `exercise`: the last weight
    /// the user logged for it, plus a small bump when that session felt too
    /// easy — or when the top set itself was rated RPE ≤ 6 (same headroom
    /// signal, per-set instead of per-session). This is what finally makes
    /// "Morphe will increase your challenge" true instead of a text card.
    /// Returns nil for bodyweight / no history.
    func suggestedWorkingWeight(for exercise: WorkoutExercise) -> Double? {
        guard let last = lastLoggedTopWeight(forExerciseNamed: exercise.name) else { return nil }
        // Only bump when the logged unit matches the current one — never guess
        // a number across a lb/kg switch.
        guard last.unit == weightUnit else { return last.weight }
        // Program deload week — scoped to the program's OWN sessions: ~10%
        // off the last working weight, snapped to the plate increment.
        if isDeloadActiveForCurrentSession, last.weight > 0 {
            let step = progressionIncrement()
            let deload = ((last.weight * 0.9) / step).rounded() * step
            return max(deload, step)
        }
        if last.feedback == .tooEasy { return last.weight + progressionIncrement() }
        if let rpe = last.topSetRPE {
            if rpe <= 6 { return last.weight + progressionIncrement() }
            // A top set at RPE 10 (≥ 9.5) means hold, never load further.
            if Double(rpe) >= 9.5 { return last.weight }
        }
        return last.weight
    }

    /// A short, honest note for the tracker citing the real signal (session
    /// rating or top-set RPE) behind the suggestion; nil when there's nothing
    /// to say.
    /// Internally-stored RPE rendered in the user's chosen effort scale.
    func effortLabel(forRPE rpe: Int) -> String {
        effortScaleRIR ? "RIR \(max(0, 10 - rpe))" : "RPE \(rpe)"
    }

    func progressionNote(for exercise: WorkoutExercise) -> String? {
        guard let last = lastLoggedTopWeight(forExerciseNamed: exercise.name),
              last.unit == weightUnit, last.weight > 0 else { return nil }
        if isDeloadActiveForCurrentSession {
            return "DELOAD WEEK — about 10% off, that's the program working"
        }
        if last.feedback == .tooEasy {
            return "MORPHE SUGGESTS +\(weightUnit.format(progressionIncrement())) — last time felt easy"
        }
        if let rpe = last.topSetRPE {
            if rpe <= 6 {
                return "MORPHE SUGGESTS +\(weightUnit.format(progressionIncrement())) — last time was \(effortLabel(forRPE: rpe)), room to add"
            }
            if Double(rpe) >= 9.5 {
                return "MORPHE SUGGESTS holding — last top set was \(effortLabel(forRPE: rpe))"
            }
        }
        return nil
    }

    /// The previous session's actual work for this exercise — the console's
    /// "LAST:" line. Literal history (deloads included): the suggestion
    /// line editorializes, this one just states what happened.
    /// Per-exercise memo for the console's history lines (speed audit
    /// S1-5): these ran a filter+sort over ALL logs on every stepper tap —
    /// 25×/second during hold-repeat. Invalidated when logs change.
    private var consoleHistoryCache: [String: String?] = [:]

    func lastSessionLine(forExerciseNamed name: String) -> String? {
        if let cached = consoleHistoryCache[name] { return cached }
        let line = computeLastSessionLine(forExerciseNamed: name)
        consoleHistoryCache[name] = line
        return line
    }

    private func computeLastSessionLine(forExerciseNamed name: String) -> String? {
        for log in currentAthleteWorkoutLogs {   // newest first
            guard let exercise = log.exercises.first(where: { $0.name == name }),
                  let reps = exercise.repsPerSet, !reps.isEmpty else { continue }
            let repsText = reps.prefix(6).map(String.init).joined(separator: "/")
            let suffix = reps.count > 6 ? "…" : ""
            let top = exercise.weightsPerSet?.max() ?? 0
            guard top > 0 else { return "LAST: \(repsText)\(suffix) BW" }
            let normalized = normalizedLoggedWeight(top, recordedUnit: exercise.weightUnit)
            return "LAST: \(repsText)\(suffix) @ \(weightUnit.format(normalized))"
        }
        return nil
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
    /// Returns whether the set actually logged, so callers can gate follow-on
    /// behavior (the auto rest timer) on a real set, not a rejected tap.
    @discardableResult
    func completeTrackedSet(reps: Int, weight: Double? = nil, rpe: Int? = nil, allowExtra: Bool = false, label: String = "", isWarmup: Bool = false) -> Bool {
        guard let exercise = activeWorkoutExercise else { return false }
        let targetSets = targetSetCount(for: exercise)
        let currentCount = completedWorkoutSets[exercise.id, default: 0]

        guard allowExtra || currentCount < targetSets else {
            showToast("\(exercise.name) is already complete.")
            return false
        }

        let updatedCount = currentCount + 1
        completedWorkoutSets[exercise.id] = updatedCount
        trackedSetReps[exercise.id, default: []].append(reps)
        // Record weight per set (0 = bodyweight) so logs carry real load, not "As logged".
        trackedSetWeights[exercise.id, default: []].append(max(0, weight ?? 0))
        trackedSetRPE[exercise.id, default: []].append(rpe ?? 0)
        // A superset/dropset is ONE set — the label carries its sub-work.
        trackedSetLabels[exercise.id, default: []].append(label)
        // Warm-ups count toward the session's work but never toward PRs.
        trackedSetWarmups[exercise.id, default: []].append(isWarmup)
        // The set logged; its draft is spent.
        pendingSetDrafts[exercise.id] = nil
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
        } else if let weight, weight > 0, !isWarmup {
            // Instant strength feedback on working sets: the same Epley
            // estimate the Progress chart uses, marked as the estimate it
            // is. Warm-ups never rate one.
            let epley = weight * (1 + Double(min(reps, 15)) / 30)
            showToast("Set \(updatedCount) of \(targetSets) — est. 1RM ≈ \(weightUnit.format((epley * 10).rounded() / 10)).")
        } else {
            showToast("\(reps) reps logged for set \(updatedCount) of \(targetSets).")
        }
        publishPartyProgress()
        return true
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
        if var labelsLogged = trackedSetLabels[exerciseID], labelsLogged.indices.contains(setIndex) {
            labelsLogged.remove(at: setIndex)
            trackedSetLabels[exerciseID] = labelsLogged
        }
        if var warmupsLogged = trackedSetWarmups[exerciseID], warmupsLogged.indices.contains(setIndex) {
            warmupsLogged.remove(at: setIndex)
            trackedSetWarmups[exerciseID] = warmupsLogged
        }
        completedWorkoutSets[exerciseID] = repsLogged.count
        showToast("Set removed.")
    }

    /// Abandons the live session without logging anything.
    func cancelTrackedWorkoutSession() {
        restoreSessionTemplateBaseline()
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
        trackedSetLabels = [:]
        trackedSetWarmups = [:]
        supersetPartners = [:]
        sessionUserNote = ""
        workoutFeedbackResponse = ""
        selectedWorkoutFeedback = nil
        showToast("Workout discarded.")
    }

    func goToNextTrackedExercise() {
        guard !currentWorkout.exercises.isEmpty else { return }
        activeWorkoutExerciseIndex = min(activeWorkoutExerciseIndex + 1, currentWorkout.exercises.count - 1)
        Haptics.impact(.light)
    }

    /// The template's exercise list as it stood before the FIRST mid-session
    /// edit, restored when the session ends — "one more movement today" must
    /// never rewrite the saved template (currentWorkout is computed from the
    /// library, so session edits necessarily pass through it). In-memory
    /// only: a mid-session relaunch keeps the edit for the restored session
    /// and a fresh baseline is captured on the next edit.
    private var sessionTemplateBaseline: (templateID: UUID, exercises: [WorkoutExercise])?

    private func captureSessionBaselineIfNeeded() {
        guard sessionTemplateBaseline == nil else { return }
        sessionTemplateBaseline = (currentWorkoutID, currentWorkout.exercises)
    }

    /// Puts the template back exactly as the user saved it. Called wherever
    /// the live session ends (logged or discarded).
    private func restoreSessionTemplateBaseline() {
        guard let baseline = sessionTemplateBaseline else { return }
        sessionTemplateBaseline = nil
        guard let index = workoutTemplates.firstIndex(where: { $0.id == baseline.templateID }) else { return }
        workoutTemplates[index].exercises = baseline.exercises
    }

    /// Adds a library exercise to the LIVE session (end of the queue) —
    /// "one more movement I feel like doing" without editing the template.
    /// Refuses duplicates: the tracked-set dictionaries key by exercise id.
    func addExerciseToSession(_ reference: ExerciseReference) {
        guard isWorkoutSessionActive else { return }
        guard !currentWorkout.exercises.contains(where: { $0.id == reference.id }) else {
            showToast("\(reference.name) is already in this session.")
            return
        }
        captureSessionBaselineIfNeeded()
        updateCurrentWorkout { workout in
            workout.exercises.append(WorkoutExercise(
                id: reference.id,
                exerciseLibraryID: reference.id,
                name: reference.name,
                muscleGroup: reference.muscleGroup,
                sets: "3 sets",
                reps: "10 reps",
                difficulty: reference.difficulty,
                formCue: reference.formCue
            ))
        }
        showToast("\(reference.name) added to the session.")
        Haptics.impact(.light)
    }

    /// Moves one live-session exercise up or down the queue. The active
    /// pointer follows the exercise it was on — reordering never silently
    /// changes what the console is tracking.
    /// Drag-reorder: drop `id` at `destination` (clamped). Same baseline
    /// capture and active-index preservation as the chevron variant.
    func moveSessionExercise(id: String, toIndex destination: Int) {
        guard let from = currentWorkout.exercises.firstIndex(where: { $0.id == id }),
              from != destination else { return }
        captureSessionBaselineIfNeeded()
        let activeID = activeWorkoutExercise?.id
        updateCurrentWorkout { workout in
            var exercises = workout.exercises
            let item = exercises.remove(at: from)
            exercises.insert(item, at: min(max(destination, 0), exercises.count))
            workout.exercises = exercises
        }
        if let activeID,
           let newIndex = currentWorkout.exercises.firstIndex(where: { $0.id == activeID }) {
            activeWorkoutExerciseIndex = newIndex
        }
    }

    func moveSessionExercise(id: String, up: Bool) {
        guard let index = currentWorkout.exercises.firstIndex(where: { $0.id == id }) else { return }
        let target = up ? index - 1 : index + 1
        guard currentWorkout.exercises.indices.contains(target) else { return }
        captureSessionBaselineIfNeeded()
        let activeID = activeWorkoutExercise?.id
        updateCurrentWorkout { workout in
            workout.exercises.swapAt(index, target)
        }
        if let activeID,
           let newIndex = currentWorkout.exercises.firstIndex(where: { $0.id == activeID }) {
            activeWorkoutExerciseIndex = newIndex
        }
        Haptics.impact(.light)
    }

    /// After an exercise completes, jump to the next one that still has sets
    /// remaining (wrapping), instead of dead-ending on the last exercise.
    // MARK: Supersets (session-scoped linked pairs)

    /// Links `exercise` with the NEXT exercise in the session as a
    /// superset — or unlinks it when already paired. Session-scoped on
    /// purpose: the saved template never changes.
    func toggleSupersetLink(for exercise: WorkoutExercise) {
        if let partnerID = supersetPartners[exercise.id] {
            supersetPartners.removeValue(forKey: exercise.id)
            supersetPartners.removeValue(forKey: partnerID)
            showToast("Superset unlinked.")
            return
        }
        let exercises = currentWorkout.exercises
        guard let index = exercises.firstIndex(where: { $0.id == exercise.id }),
              index + 1 < exercises.count else {
            showToast("Nothing after \(exercise.name) to pair with.")
            return
        }
        let partner = exercises[index + 1]
        guard supersetPartners[partner.id] == nil else {
            showToast("\(partner.name) is already in a superset.")
            return
        }
        supersetPartners[exercise.id] = partner.id
        supersetPartners[partner.id] = exercise.id
        Haptics.impact(.light)
        // First link ever gets the mechanic spelled out; after that the
        // short confirmation is enough.
        let explainedKey = "morphe.superset.explained"
        if !UserDefaults.standard.bool(forKey: explainedKey) {
            UserDefaults.standard.set(true, forKey: explainedKey)
            showToast("Superset linked — the console alternates \(exercise.name) and \(partner.name); rest comes after the pair.")
        } else {
            showToast("Superset: \(exercise.name) + \(partner.name).")
        }
    }

    /// After a logged set on a paired exercise: hop the console to the
    /// partner while the partner still has sets left. Returns whether it
    /// hopped — the caller suppresses the rest timer between halves,
    /// because rest belongs after the PAIR, not inside it.
    func hopToSupersetPartnerIfNeeded(after exercise: WorkoutExercise) -> Bool {
        guard let partnerID = supersetPartners[exercise.id],
              let partnerIndex = currentWorkout.exercises.firstIndex(where: { $0.id == partnerID })
        else { return false }
        let partner = currentWorkout.exercises[partnerIndex]
        guard completedWorkoutSets[partner.id, default: 0] < targetSetCount(for: partner) else { return false }
        activeWorkoutExerciseIndex = partnerIndex
        Haptics.impact(.light)
        // Say WHY the console just swapped exercises — a silent jump reads
        // as a bug, not a superset.
        showToast("Superset → \(partner.name)")
        return true
    }

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
            showTrainTab()
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
        // Every finished session re-arms the share toggle — an opt-out is a
        // one-session decision, never a sticky hidden state.
        shareCompletedSessionToFeed = true
        // Buddies see "finished" as soon as the session wraps, not only
        // after the recap gets logged.
        publishPartyProgress()
        Haptics.success()
        SoundEffects.play(.star)
        showToast("Session finished. Add feedback before logging it.")
        return true
    }

    /// Non-nil when `exercise` can't be swapped right now because doing so
    /// would discard sets the user has logged. Only blocks during an unsaved
    /// session — a count left in the tracked dicts after logging (they aren't
    /// cleared on log) is stale and must not wall off a later swap. The swap
    /// sheet reads this to disable its button up front instead of walking the
    /// user to a toast dead-end.
    func swapBlockReason(for exercise: WorkoutExercise) -> String? {
        guard hasUnsavedSessionWork else { return nil }
        let loggedSets = max(trackedSetReps[exercise.id, default: []].count,
                             completedWorkoutSets[exercise.id, default: 0])
        guard loggedSets > 0 else { return nil }
        return "\(exercise.name) has \(loggedSets) logged set\(loggedSets == 1 ? "" : "s") this session — remove them in the tracker before swapping."
    }

    /// Library alternatives for `exercise` that actually exist — the
    /// tappable choices the swap sheet renders. (Several exercises list
    /// dangling alternative names; those are filtered, never shown.)
    func swapChoices(for exercise: WorkoutExercise) -> [ExerciseReference] {
        guard let libraryExercise = exerciseDatabase.first(where: { $0.id == exercise.exerciseLibraryID }) else { return [] }
        return libraryExercise.alternatives.compactMap { name in
            exerciseDatabase.first { $0.name == name }
        }
    }

    /// `chosen` nil = first valid alternative (the one-tap path). The swap
    /// sheet passes the user's pick — auto-deciding FOR the user was the
    /// audit's complaint.
    func swapExercise(_ exercise: WorkoutExercise, with chosen: ExerciseReference? = nil) {
        guard let replacement = chosen ?? swapChoices(for: exercise).first else {
            showToast("No swap available for \(exercise.name).")
            return
        }

        // A swapped-in exercise gets a fresh id — a stale pair pointing at
        // the old id would orphan; unlink first.
        if let pairedID = supersetPartners[exercise.id] {
            supersetPartners.removeValue(forKey: exercise.id)
            supersetPartners.removeValue(forKey: pairedID)
        }

        // A swap drops the exercise's logged sets from the recap and the log —
        // refuse only while a live/unlogged session actually holds them.
        if let reason = swapBlockReason(for: exercise) {
            showToast(reason)
            return
        }

        updateCurrentWorkout { workout in
            guard let index = workout.exercises.firstIndex(where: { $0.id == exercise.id }) else { return }
            var replacementExercise = MorpheDemoContent.makeWorkoutExercise(replacement.id, sets: exercise.sets, reps: exercise.reps)
            // Mint a unique per-slot id: reusing the raw library id can
            // collide with an exercise already in this workout (shared set
            // counts, duplicate ForEach ids). exerciseLibraryID keeps the
            // library link for form cues and future swaps.
            replacementExercise.id = "\(replacement.id)#\(UUID().uuidString.prefix(8))"
            workout.exercises[index] = replacementExercise
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
        if liveThreads.isEmpty {
            // Demo-flag path: the sample inbox thread named after the coach.
            openAthleteMessageThread(named: clientProfile.coachName)
        } else {
            // Real path: land on Contact — the inbox auto-opens a lone
            // coach thread and ThreadChatView consumes the draft seed.
            openCommunity(.contact)
        }
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
        openCommunity(FeatureFlags.socialFeedEnabled ? .forYou : .contact)
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
        workoutFeedbackResponse = MorpheDemoContent.workoutFeedbackResponse(for: option, tone: profileShowcase.coachingTone)
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
        workoutFeedbackResponse = "Pain flag saved. Morphe recommends \(result.0) until the area settles."
        clientConversation.append(ThreadMessage(sender: .system, senderName: "Morphe", text: "Pain flag saved. Safer option: \(result.1)", timestamp: "Now"))
        // Pain flags are safety data — they must survive a relaunch.
        persistLocalProfile()
        showToast("Pain flag saved.")
    }

    func quickAction(_ action: TodayQuickAction) {
        switch action {
        case .logWorkout:
            logWorkout()
        case .swapExercise:
            if let exercise = currentWorkout.exercises.first {
                swapExercise(exercise)
                showTrainTab()
            }
        case .askAI:
            openAIAgent()
        case .messageTrainer:
            openAIAgent()
        }
    }

    func logWorkout() {
        // A finished session is always loggable — including a SECOND session
        // in one day (it used to hit the "already logged" wall and sit in
        // limbo forever). Double-logging the SAME session stays impossible
        // because logging resets hasCompletedWorkoutFlow.
        guard hasCompletedWorkoutFlow else {
            if isWorkoutLoggedToday {
                openProgress()
                showToast("Today's workout is already logged.")
            } else {
                showTrainTab()
                showToast("Finish the session in Train before logging it.")
            }
            return
        }

        isWorkoutLoggedToday = true
        SoundEffects.play(.ding)
        markTaskCompleted(named: "Complete today's workout")
        markTaskCompleted(named: "Log your workout within 24 hours")
        updateXP(for: 50, add: true)
        // Morphe Score, streak, and trend are recomputed from logs in
        // appendWorkoutLog -> refreshWorkoutLogDerivedState; no manual edits here.
        // Activation = the FIRST logged workout — captured before the append
        // makes it un-first.
        let isActivation = currentAthleteWorkoutLogs.isEmpty
        // Tier changes make new Today cards appear — SAY so, or the page
        // silently rearranging reads as a glitch (audit finding).
        let tierBefore = todayExperienceTier
        let loggedExercises = makeLoggedExercisesFromCurrentWorkout()
        // PRs must be diffed against the bests BEFORE this session lands in
        // the logs — afterwards the new top IS the best and nothing is new.
        let priorBests = personalBestTopWeights()
        // A PR is pure arithmetic: this session's top logged weight beats the
        // all-time top. Both sides are in the current display unit.
        let newPRs: [(name: String, weight: Double, previous: Double)] = loggedExercises.compactMap { exercise in
            // Working sets only — a heavy warm-up single is not a record.
            guard let top = exercise.workingWeightsPerSet?.max(), top > 0 else { return nil }
            let previous = priorBests[exercise.name] ?? 0
            return top > previous ? (exercise.name, top, previous) : nil
        }
        let isBuddySession = partnerWorkoutEnabled && selectedWorkoutPartner != nil
        var sessionNotes = partnerWorkoutSessionNote()
        // Deload sessions carry a marker so the progression engine can look
        // past their deliberately light numbers when suggesting the next
        // working weight.
        if isDeloadActiveForCurrentSession {
            sessionNotes = sessionNotes.isEmpty ? "Deload week." : "\(sessionNotes) Deload week."
        }
        // The user's own words lead the note — the flow boilerplate follows.
        let userNote = sessionUserNote.trimmingCharacters(in: .whitespacesAndNewlines)
        if !userNote.isEmpty {
            sessionNotes = sessionNotes.isEmpty ? userNote : "\(userNote) \(sessionNotes)"
        }
        sessionUserNote = ""

        // Train Together: publish this user's totals to the party so buddies
        // see them in their shared recap, and stamp the log with who was there.
        if let party = activeParty {
            let buddyNames = partyBuddies.map(\.name)
            if !buddyNames.isEmpty {
                let trainedWith = "Trained with \(buddyNames.joined(separator: ", "))."
                sessionNotes = sessionNotes.isEmpty ? trainedWith : "\(sessionNotes) \(trainedWith)"
            }
            if let uid = authUser?.id {
                let setCount = loggedExercises.reduce(0) { total, exercise in
                    total + max(Int(exercise.sets.components(separatedBy: CharacterSet.decimalDigits.inverted).first { !$0.isEmpty } ?? "") ?? 0, 0)
                }
                partyService.publishSummary(
                    partyID: party.id,
                    participantID: uid,
                    summary: partySummaryLine(
                        exercises: loggedExercises.count,
                        sets: setCount,
                        minutes: completedSessionMinutes ?? currentWorkout.durationMinutes
                    )
                )
            }
        }

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
                verificationStatus: .athleteSubmitted,
                sessionFeedback: selectedWorkoutFeedback?.rawValue
            )
        )

        if let partnerLog = makeMirroredPartnerWorkoutLog(exercises: loggedExercises) {
            appendWorkoutLog(partnerLog)
        }

        // Apple Health (opt-in): the logged session, exactly as logged —
        // real minutes, ending now. Fire-and-forget like the social writes.
        if healthSyncEnabled {
            let healthTitle = currentWorkout.name
            let healthMinutes = completedSessionMinutes ?? currentWorkout.durationMinutes
            Task { await HealthWorkoutSync.save(workoutTitle: healthTitle, minutes: healthMinutes) }
        }

        // Weekly board + joined challenges: the freshly-appended log is now
        // part of the weekly totals — mirror them up (opt-in gated inside).
        publishCompetitionScores()

        if todayExperienceTier > tierBefore {
            showToast(todayExperienceTier == 1
                ? "Today unlocked new cards — your metrics and adjustment tools are live."
                : "Today unlocked pattern insights — keep logging.")
        }

        // A logged session that IS the program's next session advances the
        // program (count-based, so a missed week just resumes).
        let programJustCompleted = advanceProgramIfMatches(loggedTitle: currentWorkout.name)

        // Auto-share: one honest recap post per finished session — global
        // opt-in (Profile), per-session opt-out (the toggle above Log
        // Workout). Quiet path: a failed publish never blocks the log.
        // Structured stats ride along so the feed renders a real workout
        // card; party buddies are named so a shared session shares SHARED.
        if FeatureFlags.socialFeedEnabled, autoShareWorkoutsEnabled, shareCompletedSessionToFeed, authUser != nil {
            let buddyNames = activeParty != nil ? partyBuddies.map(\.name) : []
            let text = completedSessionPostText(exercises: loggedExercises, newPRs: newPRs, buddies: buddyNames)
            let workoutName = currentWorkout.name
            let sharedSetCount = loggedExercises.reduce(0) { $0 + ($1.repsPerSet?.count ?? 0) }
            let sharedMinutes = completedSessionMinutes ?? currentWorkout.durationMinutes
            let sharedExerciseCount = loggedExercises.count
            let sharedPRNames = newPRs.prefix(3).map(\.name)
            Task {
                await publishToRealFeed(
                    text: text,
                    workoutName: workoutName,
                    durationMinutes: sharedMinutes > 0 ? sharedMinutes : nil,
                    setCount: sharedSetCount > 0 ? sharedSetCount : nil,
                    exerciseCount: sharedExerciseCount > 0 ? sharedExerciseCount : nil,
                    prNames: Array(sharedPRNames)
                )
            }
        }

        isWorkoutSessionActive = false
        hasStartedWorkoutFlow = false
        hasCompletedWorkoutFlow = false
        // Session-scoped add/reorder dies with the session — the template
        // goes back exactly as the user saved it.
        restoreSessionTemplateBaseline()

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
        // Train Together: the session is in the books — leave the party
        // locally but keep the membership doc, so buddies still mid-workout
        // keep this user's summary in their shared recap.
        if activeParty != nil {
            partyService.stopListening()
            activeParty = nil
            partyIsReadySelf = false
        }
        // Fold the fresh rating/duration into the difficulty engine so the
        // very next plan day already reflects this session.
        rebuildPersonalizedPlan()
        // NO tab yank (audit E5): the user tapped Log in Train and stays
        // there — the celebration + Today's done-card carry the moment,
        // and Progress is one tab away when they want the charts.
        track("workout_logged")
        if isActivation {
            track("activation_first_log")
            // First log = the moment reminders become worth having (E1).
            requestNotificationPermissionIfNeeded()
        }
        // Re-aim the daily nudge past the session that just landed (E2).
        refreshDailyTrainingReminder()
        // Celebration ranking: finishing a whole PROGRAM outranks a PR,
        // which outranks the generic XP line. The top two get the
        // full-screen stamp — the app's ONE escalated moment, with the
        // share card a tap away; everything else stays on the banner.
        if programJustCompleted, let finished = programProgress {
            recordStamp = RecordStampMoment(
                kicker: "PROGRAM COMPLETE",
                headline: finished.program.name,
                valueLine: "\(finished.program.weeks) weeks",
                detailLine: "Every session logged",
                prCard: nil
            )
        } else if let pr = newPRs.first {
            let extraPRs = newPRs.count - 1
            var detail = pr.previous > 0
                ? "Up from \(weightUnit.format(pr.previous))"
                : "Your first record"
            if extraPRs > 0 {
                detail += " · +\(extraPRs) more PR\(extraPRs == 1 ? "" : "s")"
            }
            recordStamp = RecordStampMoment(
                kicker: "NEW RECORD",
                headline: pr.name,
                valueLine: weightUnit.format(pr.weight),
                detailLine: detail,
                prCard: prShareCardData(exerciseName: pr.name, weight: pr.weight, previous: pr.previous)
            )
            recentWins.insert("New PR: \(pr.name) at \(weightUnit.format(pr.weight)).", at: 0)
        } else {
            // The celebration speaks in the coaching tone the user picked.
            showCelebration(title: "+50 XP", detail: profileShowcase.coachingTone.workoutCompleteDetail, symbol: "sparkles")
        }
        Haptics.success()
        showToast("Workout logged. Progress updated.")
    }

    func addQuickMeal(_ meal: QuickMeal) {
        nutrition.caloriesConsumed += meal.calories
        nutrition.proteinConsumed += meal.protein
        nutrition.meals.append(MealLogEntry(mealType: "Quick Add", name: meal.title, calories: meal.calories, protein: meal.protein, logged: true))
        nutrition.nutritionScore = min(nutrition.nutritionScore + 2, 100)
        persistLocalProfile()
        showToast("Added \(meal.title).")
    }

    func addWaterCup() {
        nutrition.waterConsumed = min(nutrition.waterConsumed + 1, nutrition.waterGoal)
        persistLocalProfile()
        showToast("Water updated.")
    }

    func setNutritionMode(_ mode: NutritionMode) {
        nutrition.mode = mode
        persistLocalProfile()
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
            // XP is awarded once per quiz, ever — answering an already-aced
            // question again (day rotation cycles through the pool) must not
            // become a repeatable XP source.
            if !completedQuizIDs.contains(quiz.id) {
                completedQuizIDs.insert(quiz.id)
                updateXP(for: quiz.rewardXP, add: true)
                SoundEffects.play(.star)
                showCelebration(title: "Quiz complete", detail: "+\(quiz.rewardXP) XP", symbol: "brain.head.profile")
                persistLocalProfile()
            }
        } else {
            showToast("Good try — the explanation below has the answer.")
        }
    }

    // sendClientPrompt is GONE (AI-2 in docs/READINESS-300.md): it was a
    // second, dumber "Morphe AI" pipeline with zero callers, feeding the
    // demo inbox thread with no actions and no context. The pill/cover
    // action layer (sendAIAgentPrompt) is the one brain.

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
        showToast("\(clientProfile.coachName.isEmpty ? "Your coach" : clientProfile.coachName) replied.")
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
        // Demo-flag-only surface, and even here nobody "replies": the old
        // fabricated coach response was the exact class of lie the honesty
        // rules exist for (post-revamp audit). The message just sends.
        athleteMessageThreads[threadIndex].preview = cleanText
        athleteMessageThreads[threadIndex].isUnread = false
        selectedAthleteThreadID = athleteMessageThreads[threadIndex].id
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

    /// True once the user has EVER opened Morphe AI — flips the floating
    /// pill to its compact circle for good (the wide label is an intro,
    /// not furniture).
    var hasUsedAIAgent: Bool = UserDefaults.standard.bool(forKey: "morphe.ai.used")

    func openAIAgent() {
        // The pill keeps its "Morphe AI" label for the first few opens —
        // de-labeling after ONE tap left a mystery sparkle (audit finding).
        let opens = UserDefaults.standard.integer(forKey: "morphe.ai.opens") + 1
        UserDefaults.standard.set(opens, forKey: "morphe.ai.opens")
        if !hasUsedAIAgent, opens >= 3 {
            hasUsedAIAgent = true
            UserDefaults.standard.set(true, forKey: "morphe.ai.used")
        }
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

    /// Returns true when the prompt was handled by the action layer (the
    /// user is looking at the result), false when the reply is conversational
    /// and lives in the chat — callers use this to decide whether opening the
    /// chat sheet would help or just flash and close.
    @discardableResult
    func sendAIAgentPrompt(_ text: String) -> Bool {
        let cleanText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanText.isEmpty else { return false }

        if selectedRole == .coach {
            coachAIAgentConversation.append(ThreadMessage(sender: .user, senderName: coachProfile.name, text: cleanText, timestamp: "Now"))
            // Coaches get an action layer too (AI-7): navigation and a
            // real who-needs-attention answer — parity with the athlete
            // side instead of advertising actions that did nothing.
            let actionReply = coachAssistantActionReply(for: cleanText)
            let reply = actionReply ?? coachAgentReply(to: cleanText)
            coachAIAgentConversation.append(ThreadMessage(sender: .ai, senderName: "Morphe AI", text: reply, timestamp: "Now"))
            return actionReply != nil
        } else {
            athleteAIAgentConversation.append(ThreadMessage(sender: .user, senderName: clientProfile.name, text: cleanText, timestamp: "Now"))
            // Actions first: if the ask maps to something Morphe AI can DO
            // (start a workout, open a screen, change a setting), do it and
            // confirm — otherwise fall back to the coaching reply.
            let actionReply = assistantActionReply(for: cleanText)
            let reply = actionReply ?? athleteAgentReply(to: cleanText)
            athleteAIAgentConversation.append(ThreadMessage(sender: .ai, senderName: "Morphe AI", text: reply, timestamp: "Now"))
            return actionReply != nil
        }
    }

    /// "log 3x10 at 135" / "did 5x5 @ 225" → (sets, reps, weight). The
    /// weight clause is optional. Pure + static for tests.
    static func parseSetCommand(_ text: String) -> (sets: Int, reps: Int, weight: Double?)? {
        let pattern = #"(?:log|did|add)\s+(\d{1,2})\s*[x×]\s*(\d{1,3})(?:\s*(?:at|@)\s*(\d{1,4}(?:\.\d+)?))?"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]),
              let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
              let setsRange = Range(match.range(at: 1), in: text),
              let repsRange = Range(match.range(at: 2), in: text),
              let sets = Int(text[setsRange]), let reps = Int(text[repsRange]),
              sets >= 1, reps >= 1
        else { return nil }
        var weight: Double?
        if match.range(at: 3).location != NSNotFound,
           let weightRange = Range(match.range(at: 3), in: text) {
            weight = Double(text[weightRange])
        }
        return (sets, reps, weight)
    }

    /// Longest-name-first template match so "Upper Body Power" beats
    /// "Upper Body"; ≥4 chars keeps "abs" from matching inside words.
    func namedWorkoutMatch(in lower: String) -> WorkoutTemplate? {
        workoutTemplates
            .filter { $0.name.count >= 4 }
            .sorted { $0.name.count > $1.name.count }
            .first { lower.contains($0.name.lowercased()) }
    }

    /// Morphe AI's action layer: understands common asks and actually performs
    /// them — navigation, session control, settings — instead of only replying
    /// with text. Returns nil when nothing actionable matched. (The
    /// conversational layer stays scripted until the real model arrives with
    /// the backend.)
    private func assistantActionReply(for text: String) -> String? {
        let lower = text.lowercased()
        func has(_ words: String...) -> Bool { words.contains { lower.contains($0) } }

        if has("what can you do", "help me use", "commands") || lower == "help" {
            return "I can start your workout (today's or one by name, like \"start Push Day\"), log sets mid-session (\"log 3x10 at 135\"), turn on Minimum Win mode, open Discover, Progress, Lessons, the exercise library, or your profile, and switch lb/kg. Just ask."
        }

        // Questions get answers, not actions. "Should I stop training when my
        // knee hurts?" is a coaching ask — matching it as a command used to
        // silently wipe the live session.
        let questionStarts = [
            "should", "when", "what", "how", "why", "where", "who",
            "is ", "are ", "am ", "do ", "does ", "did ", "would", "could",
            "can ", "explain", "tell me"
        ]
        if lower.contains("?") || questionStarts.contains(where: { lower.hasPrefix($0) }) {
            return nil
        }

        // Start first: "stop procrastinating and start my workout" is a start.
        if has("start", "begin", "let's train", "lets train") && has("workout", "session", "training", "today's plan", "todays plan") {
            guard !isWorkoutSessionActive else {
                showTrainTab()
                closeAIAgent()
                return "You're already mid-session — it's open in Train."
            }
            // Chat never queues a destructive confirmation (same rule as
            // discard). Decline in the conversation and leave the sheet open so
            // the user actually reads the reply — closing it dropped them in
            // Train with no explanation.
            guard !hasUnsavedSessionWork else {
                return "You've got a finished session that isn't logged yet. Log it from Train first, then ask me again and I'll start the next one."
            }
            startTodayWorkout()
            closeAIAgent()
            return "Done — \(currentWorkout.name) is live in Train. Log your first set when you're ready."
        }

        // Named start: "start Push Day" — the workout IS the keyword.
        if has("start", "begin"), let named = namedWorkoutMatch(in: lower) {
            guard !isWorkoutSessionActive else {
                showTrainTab()
                closeAIAgent()
                return "You're already mid-session — finish or discard that one in Train first."
            }
            guard !hasUnsavedSessionWork else {
                return "You've got a finished session that isn't logged yet. Log it from Train first, then ask me again."
            }
            beginLiveWorkout(named)
            showTrainTab()
            closeAIAgent()
            return "Done — \(named.name) is live in Train."
        }

        // "log bench 3x10" names an exercise the parser ignores — logging
        // it against whatever's active would be a silent mis-log. Guide
        // instead of guessing.
        if has("log", "did", "add"), Self.parseSetCommand(lower) == nil,
           lower.range(of: #"(?:log|did|add)\s+[a-z][a-z ]+\d{1,2}\s*[x×]\s*\d"#,
                       options: .regularExpression) != nil {
            let active = activeWorkoutExercise?.name ?? "the active exercise"
            return "I log against \(active) — swap to the exercise you mean in Train, then say \"log 3x10 at 135\"."
        }

        // Mid-session set logging: "log 3x10 at 135". Weight omitted falls
        // back to the same suggestion the console uses — a real number from
        // this user's history, never an invention.
        if has("log", "did", "add"), let parsed = Self.parseSetCommand(lower) {
            guard isWorkoutSessionActive else {
                return "Nothing's in session yet — say \"start my workout\" first and I'll log sets straight into the console."
            }
            guard let exercise = activeWorkoutExercise else {
                return "The session has no active exercise to log against — pick one in Train."
            }
            let weight = parsed.weight
                ?? lastSessionWeight(for: exercise.id)
                ?? suggestedWorkingWeight(for: exercise)
                ?? 0
            let sets = min(parsed.sets, 10)
            for _ in 0..<sets {
                completeTrackedSet(reps: parsed.reps, weight: weight, allowExtra: true)
            }
            return "Logged \(sets)×\(parsed.reps) at \(weightUnit.format(weight)) on \(exercise.name). It's in the console — adjust any set there."
        }

        // Deliberately NOT executed from chat: logged sets are unrecoverable,
        // and the tracker's own Discard flow confirms before deleting. Chat
        // points there instead of matching its way into data loss.
        if has("discard", "cancel", "quit", "stop") && has("workout", "session", "training") {
            guard isWorkoutSessionActive else { return "There's no live session right now." }
            showTrainTab()
            closeAIAgent()
            return "I don't discard sessions from chat — logged sets can't be recovered. Use Discard at the top of Train; it double-checks first. Running low instead? Say \"minimum win\" and I'll shrink today."
        }

        // Minimum Win needs training context: bare "tired" used to flip the
        // mode on messages like "I'm tired of chicken — meal ideas?".
        if has("minimum win", "smaller win", "easier day", "easy day", "low energy", "shrink today")
            || (has("tired", "exhausted", "drained", "no energy") && has("workout", "train", "session", "today", "win")) {
            activateMinimumWinMode()
            return "Minimum Win mode is on — one small win still counts today."
        }

        // Units switch only on an explicit ask — "I lifted 100 kg today" is a
        // statement, not a settings change.
        if has("switch", "change", "prefer", "track in", "weights in", "use kg", "use kilo", "use lb", "use pound") {
            let toKG = has("to kg", "to kilo", "in kg", "in kilo")
            let toLB = has("to lb", "to pound", "in lb", "in pound")
            let wantsKG = toKG || (!toLB && has("kilogram", " kg", "kgs"))
            let wantsLB = toLB || (!toKG && has("pound", " lb", "lbs"))
            if wantsKG != wantsLB {
                weightUnit = wantsKG ? .kilograms : .pounds
                return "Weights now shown in \(wantsKG ? "kilograms" : "pounds")."
            }
        }

        // Navigation closes the chat sheet — moving tabs behind a presented
        // sheet looked like nothing happened.
        if has("progress", "score", "streak", "stronger", "records", "history") {
            openProgress()
            closeAIAgent()
            return "Opened Progress — your score, strength trend, and workout history are there."
        }
        // Library BEFORE lessons (AI-5): "learn proper form" is a form-guide
        // ask, and "learn" alone used to hijack it into Lessons.
        if has("library", "exercise", "form guide", "form", "anatomy", "technique") {
            openMore(.library)
            closeAIAgent()
            return "Opened the exercise library — pick a muscle group to browse form guides."
        }
        if has("lesson", "quiz", "learn") {
            openMore(.learn)
            closeAIAgent()
            return "Opened Lessons — today's quiz is at the top."
        }
        if has("discover", "browse workouts", "find a workout", "catalog", "new workout") {
            showDiscoverTab()
            closeAIAgent()
            return "Opened Discover — pick a training style to browse its workouts."
        }
        if has("profile", "settings", "injur", "rename", "training days") {
            // Two sheets can't co-present: dismiss the chat, then present the
            // profile once the transition has room to run.
            closeAIAgent()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { [weak self] in
                self?.openClientProfile()
            }
            return "Opening your profile — name, weight unit, training days, and injuries live there."
        }
        if has("today", "home") && has("open", "go to", "back", "show") {
            selectedClientTab = .today
            closeAIAgent()
            return "Back on Today."
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

    /// Consumed by the inbox: a deep link that wants a SPECIFIC thread
    /// open, surviving the pane's session-long mount (the local
    /// auto-open-once flag can't re-fire for later deep links).
    var pendingThreadOpenID: String?

    func openCommunity(_ section: ClientCommunitySection = .contact) {
        // Both Network sections are REAL in v1: For You is the Firestore
        // feed, Contact is the coach-thread inbox (with an honest empty
        // state naming the coach-link unlock). Contact is THE messaging
        // destination — every "message" door in the app routes here.
        if section == .contact, liveThreads.count == 1, let only = liveThreads.first {
            pendingThreadOpenID = only.id
        }
        selectedCommunitySection = section
        selectedClientTab = .community
        Haptics.impact(.light)
    }

    func openWorkoutTemplate(_ template: WorkoutTemplate) {
        confirmDiscardingSessionWork("Switch to \(template.name)?") { [weak self] in
            self?.performOpenWorkoutTemplate(template)
        }
    }

    private func performOpenWorkoutTemplate(_ template: WorkoutTemplate) {
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
        trackedSetLabels = [:]
        trackedSetWarmups = [:]
        supersetPartners = [:]
        sessionUserNote = ""
        showTrainTab()
        showToast("\(template.name) ready in Train.")
    }

    /// Queues a saved workout as TODAY's workout — staged in Train, session
    /// not started. Mirrors openWorkoutTemplate (same discard guard).
    func queueSavedWorkout(_ item: SavedWorkoutLibraryItem) {
        guard let template = workoutTemplates.first(where: { $0.id == item.workoutTemplateID }) else {
            showToast("That workout is no longer available.")
            return
        }
        openWorkoutTemplate(template)
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
        // Inside the gate: flipping partner mode before confirmation left it
        // on against the EXISTING session when the user cancelled.
        confirmDiscardingSessionWork("Start \(template.name)?") { [weak self] in
            self?.partnerWorkoutEnabled = true
            self?.currentWorkoutID = template.id
            self?.performStartTodayWorkout()
        }
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

        confirmDiscardingSessionWork("Switch to \(template.name)?") { [weak self] in
            // Through setCurrentWorkout (not a bare id write) so a stale
            // finished-session flag can't log this template as performed.
            self?.setCurrentWorkout(template)
            self?.showToast("Today's workout is now \(template.name).")
        }
    }

    func duplicateSavedWorkout(_ item: SavedWorkoutLibraryItem) {
        guard let template = workoutTemplates.first(where: { $0.id == item.workoutTemplateID }) else {
            showToast("That saved workout is no longer available.")
            return
        }

        var copiedTemplate = template
        copiedTemplate.id = UUID()
        copiedTemplate.name = uniqueWorkoutName("My Copy - \(template.name)")
        copiedTemplate.coachNote = "Personal copy built from \(item.sourceName)'s saved workout."
        workoutTemplates.insert(copiedTemplate, at: 0)
        // The copy is the user's own workout: registering it as custom makes
        // it survive relaunch AND keeps it out of the curated Discover feed
        // (which filters custom workouts).
        customWorkoutIDs.insert(copiedTemplate.id)

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
        persistWorkoutLibrary()
        openWorkoutTemplate(copiedTemplate)
        showToast("Saved workout duplicated into your library.")
    }

    /// Resolves the template a saved item should EDIT. The user's own custom
    /// workouts edit in place; catalog/coach saves first become a personal
    /// copy — the Discover catalog is never mutated by an edit.
    func editableTemplateID(for item: SavedWorkoutLibraryItem) -> UUID? {
        guard let template = workoutTemplates.first(where: { $0.id == item.workoutTemplateID }) else {
            showToast("That saved workout is no longer available.")
            return nil
        }
        if customWorkoutIDs.contains(template.id) {
            return template.id
        }

        var copy = template
        copy.id = UUID()
        copy.name = uniqueWorkoutName("My Copy - \(template.name)")
        copy.coachNote = "Personal copy built from \(item.sourceName)'s saved workout."
        workoutTemplates.insert(copy, at: 0)
        customWorkoutIDs.insert(copy.id)
        savedWorkouts.insert(
            SavedWorkoutLibraryItem(
                workoutTemplateID: copy.id,
                workoutName: copy.name,
                sport: copy.sport,
                sourceName: profileShowcase.displayName,
                sourceRole: .client,
                sourceContext: "Built by you",
                bestFor: .customBuild,
                note: "Personal copy of \(template.name)."
            ),
            at: 0
        )
        persistWorkoutLibrary()
        showToast("Editing your own copy — the original stays in Discover.")
        return copy.id
    }

    /// Applies builder edits to one of the user's custom workouts.
    func updateCustomWorkout(id: UUID, name: String, sport: SportFocus, items: [CustomWorkoutItem]) {
        guard customWorkoutIDs.contains(id),
              let index = workoutTemplates.firstIndex(where: { $0.id == id }),
              !items.isEmpty else { return }

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

        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty, trimmed != workoutTemplates[index].name {
            workoutTemplates[index].name = uniqueWorkoutName(trimmed)
        }
        workoutTemplates[index].sport = sport
        workoutTemplates[index].exercises = exercises
        workoutTemplates[index].durationMinutes = max(15, items.count * 8)

        let finalName = workoutTemplates[index].name
        for savedIndex in savedWorkouts.indices where savedWorkouts[savedIndex].workoutTemplateID == id {
            savedWorkouts[savedIndex].workoutName = finalName
            savedWorkouts[savedIndex].sport = sport
        }
        persistWorkoutLibrary()
        Haptics.impact(.light)
        showToast("\(finalName) updated.")
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
            persistWorkoutLibrary()
            showToast("Removed from pinned workouts.")
            return
        }

        let pinnedCount = savedWorkouts.filter(\.isPinned).count
        guard pinnedCount < 3 else {
            showToast("Pin up to 3 workouts at a time.")
            return
        }

        savedWorkouts[index].isPinned = true
        persistWorkoutLibrary()
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


    func logRecoveryReset() {
        guard !didCompleteQuickCheckIn else {
            showToast("Recovery reset already saved for today.")
            return
        }

        didCompleteQuickCheckIn = true
        recovery.energy = min(recovery.energy + 1, 10)
        recovery.soreness = max(recovery.soreness - 1, 0)
        recentWins.insert("Added a quick recovery reset after training.", at: 0)
        persistLocalProfile()
        showToast("Recovery reset saved.")
    }

    func quickAddInvitePartner() {
        if selectedWorkoutPartner == nil {
            selectedWorkoutPartnerID = workoutPartners.first(where: { $0.linkedAthleteID != nil })?.id
                ?? workoutPartners.first?.id
        }

        partnerWorkoutEnabled = true
        showTrainTab()

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
        persistLocalProfile()
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

    // (previewOnboardingAccentPalette lived here — dead since the onboarding
    // accent step was cut, and it bypassed the level gate. Removed.)

    /// Applies a new accent palette app-wide and persists it. Contract with
    /// the Profile appearance picker (ProfileView owns the UI only): set
    /// profileShowcase.accentPalette, call MorpheTheme.apply(accentPalette:),
    /// persist the profile.
    // MARK: Milestone unlocks (levels finally mean something)

    /// Level each accent palette unlocks at. Gold (the brand default) plus
    /// two others ship free; the rest are earned. Cosmetics ONLY — data,
    /// analytics, and safety are never gated behind progression.
    static let paletteUnlockLevels: [AccentPalette: Int] = [
        .gold: 1, .electricBlue: 1, .green: 1,
        .red: 3, .orange: 5, .purple: 8, .pink: 12
    ]

    func paletteUnlockLevel(_ palette: AccentPalette) -> Int {
        Self.paletteUnlockLevels[palette] ?? 1
    }

    /// Unlocked by level — or grandfathered: whatever is currently applied
    /// stays yours regardless (an update never revokes a choice).
    /// Recruiter is the one non-level palette: it unlocks when someone
    /// joins Morphe through this user's invite (server-backed count).
    func isPaletteUnlocked(_ palette: AccentPalette) -> Bool {
        if palette == profileShowcase.accentPalette { return true }
        if palette == .custom { return true }
        // Coaches don't ride the athlete XP ladder — an athlete gate on a
        // coach screen was a row of unearnable padlocks (coach audit).
        if selectedRole == .coach { return true }
        if palette == .recruiter { return referralCount >= 1 }
        return currentLevelNumber >= paletteUnlockLevel(palette)
    }

    // MARK: Earned badges (derived from real data, never stored)

    /// The profile badge grid — computed from logs and state on every read,
    /// so a badge can never exist without the data that backs it. This
    /// replaced the seeded showcase badges, which were demo content.
    var earnedBadges: [ProfileBadge] {
        var badges: [ProfileBadge] = []
        let logs = currentAthleteWorkoutLogs

        if let first = logs.min(by: { $0.completedAt < $1.completedAt }) {
            badges.append(ProfileBadge(
                title: "First Workout",
                detail: "\(first.workoutTitle) — \(Self.workoutDateLabel(for: first.completedAt)).",
                icon: "figure.walk"))
        }

        let records = recentPersonalRecords(limit: 500)
        if let earliest = records.min(by: { $0.date < $1.date }) {
            badges.append(ProfileBadge(
                title: "First Record",
                detail: "\(earliest.exerciseName) \(weightUnit.format(earliest.weight)) — \(Self.workoutDateLabel(for: earliest.date)).",
                icon: "trophy.fill"))
        }

        let best = bestWorkoutStreak(from: logs)
        for milestone in [7, 30, 100] where best >= milestone {
            badges.append(ProfileBadge(
                title: "\(milestone)-Day Streak",
                detail: "Best run \(best) days — schedule-aware, planned rest counted.",
                icon: "flame.fill"))
        }

        for programID in completedProgramIDs {
            guard let program = Self.trainingPrograms.first(where: { $0.id == programID }) else { continue }
            badges.append(ProfileBadge(
                title: "Program Complete",
                detail: "\(program.name) — every session of all \(program.weeks) weeks, logged.",
                icon: "checkmark.seal.fill"))
        }

        // Ended challenges where this account actually put sessions on the
        // board — score re-derived from own logs over the window, same math
        // that posted it.
        for challenge in activeChallenges where challenge.isExpired {
            let window = DateInterval(start: challenge.startsAt, end: max(challenge.endsAt, challenge.startsAt))
            let totals = competitionTotals(in: window)
            let score = challenge.metric == .sets ? totals.sets : totals.workouts
            guard score >= 1 else { continue }
            badges.append(ProfileBadge(
                title: "Challenge Run",
                detail: "\(challenge.title) — \(score) \(challenge.metric == .sets ? "sets" : "sessions") over the full window.",
                icon: "flag.checkered"))
        }

        if referralCount >= 1 {
            badges.append(ProfileBadge(
                title: "Recruiter",
                detail: "\(referralCount) athlete\(referralCount == 1 ? "" : "s") joined Morphe through you.",
                icon: "person.2.fill"))
        }

        return badges
    }

    /// Longest schedule-aware streak anywhere in the history — same gap
    /// rule as `currentWorkoutStreak`, scanned over every run instead of
    /// walking back from the latest day.
    private func bestWorkoutStreak(from logs: [WorkoutLog]) -> Int {
        let calendar = Calendar.current
        var activeDays = Set(logs.map { calendar.startOfDay(for: $0.completedAt) })
        for key in protectedDayKeys {
            if let day = Self.date(fromDayKey: key) {
                activeDays.insert(calendar.startOfDay(for: day))
            }
        }
        let sortedDays = activeDays.sorted()
        guard !sortedDays.isEmpty else { return 0 }
        let daysPerWeek = max(1, min(7, clientProfile.trainingDaysPerWeek))
        let allowedGap = max(1, 8 - daysPerWeek)
        var best = 1
        var run = 1
        for (previous, next) in zip(sortedDays, sortedDays.dropFirst()) {
            if let gap = calendar.dateComponents([.day], from: previous, to: next).day, gap <= allowedGap {
                run += 1
            } else {
                run = 1
            }
            best = max(best, run)
        }
        return best
    }

    func updateAccentPalette(_ palette: AccentPalette) {
        guard profileShowcase.accentPalette != palette else { return }
        guard isPaletteUnlocked(palette) else {
            showToast(palette == .recruiter
                ? "Recruiter unlocks when someone joins through your invite."
                : "\(palette.rawValue) unlocks at level \(paletteUnlockLevel(palette)) — keep logging.")
            return
        }
        profileShowcase.accentPalette = palette
        MorpheTheme.apply(accentPalette: palette, customHex: profileShowcase.customAccentHex)
        persistLocalProfile()
        Haptics.impact(.light)
    }

    /// The custom accent's color changed (ColorPicker). Persists the hex and
    /// re-applies live when Custom is the active palette.
    func updateCustomAccent(hex: String) {
        guard MorpheTheme.color(fromHex: hex) != nil else { return }
        profileShowcase.customAccentHex = hex
        // Always re-apply (with the CURRENT palette): the Custom dot's
        // preview swatch reads the theme's custom color, so it must track
        // the picker even while another palette is active.
        MorpheTheme.apply(accentPalette: profileShowcase.accentPalette, customHex: hex)
        persistLocalProfile()
    }

    /// Returns whether the change actually landed — the editor keeps the
    /// draft open on a rejection (cooldown/empty) instead of silently
    /// closing over an unchanged name.
    @discardableResult
    func updateDisplayName(_ newName: String) -> Bool {
        let trimmed = String(newName.trimmingCharacters(in: .whitespacesAndNewlines).prefix(40))
        guard !trimmed.isEmpty else {
            showToast("Your name can't be empty.")
            return false
        }
        guard trimmed != profileShowcase.displayName else { return true }
        // Renames are rate-limited; a no-op save above never burns the window.
        if let next = nextNameChangeDate {
            showToast("You can change your name again on \(next.formatted(date: .abbreviated, time: .omitted)).")
            return false
        }
        clientProfile.name = trimmed
        profileShowcase.displayName = trimmed
        // A coach IS this same person — their workspace name follows
        // (coach audit: the coach profile had no name editor at all).
        if !coachProfile.name.isEmpty || selectedRole == .coach {
            coachProfile.name = trimmed
        }
        // The @username is its own claimed identity now — a rename never
        // touches it (change it separately, on its own 14-day clock).
        nameChangedAtEpoch = Date.now.timeIntervalSince1970
        persistLocalProfile()
        showToast("Name updated.")
        return true
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
        // Calories/protein branch on the goal text — refresh now, not on
        // the next relaunch.
        applyNutritionTargets()
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
        // Goals and training styles persist their toggles; sports didn't —
        // the edit silently reverted on relaunch.
        persistLocalProfile()
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
        SoundEffects.play(.ding)
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
    /// Carries the sender's handle as a referral link: opening
    /// morphe://invite/<username> after install auto-follows the inviter.
    var networkInviteMessage: String {
        // Role-aware (profile audit): a coach recruiting clients shouldn't
        // send buddy-training copy.
        if selectedRole == .coach {
            let name = coachProfile.name.isEmpty ? "me" : coachProfile.name
            var message = "I coach on Morphe — join and I'll deliver your training plan straight to your phone. Ask \(name) for your invite code."
            let handle = coachProfile.username
            if !handle.isEmpty {
                message += " After you install, open morphe://invite/\(handle)."
            }
            return message
        }
        let name = clientProfile.name.isEmpty ? "me" : clientProfile.name
        var message = "Train with \(name) on Morphe — log your lifts, keep your streak, and face me on the weekly board."
        let handle = profileShowcase.username
        if !handle.isEmpty {
            message += " After you install, open morphe://invite/\(handle)."
        }
        return message + " 💪"
    }

    // MARK: Library folders (per-profile; ride the extras cloud backup)
    //
    // Keyed by workoutTemplateID — the STABLE id (library row ids re-mint
    // per launch). One blob: folder names + templateID→folder assignments.

    private var libraryFoldersKey: String { "morphe.library.folders.\(clientProfile.id.uuidString)" }

    private struct LibraryFoldersBlob: Codable {
        var folders: [String] = []
        var assignments: [String: String] = [:]
    }

    private(set) var libraryFolders: [String] = []
    private(set) var libraryFolderAssignments: [String: String] = [:]

    func loadLibraryFolders() {
        guard let data = UserDefaults.standard.data(forKey: libraryFoldersKey),
              let blob = try? JSONDecoder().decode(LibraryFoldersBlob.self, from: data) else {
            libraryFolders = []
            libraryFolderAssignments = [:]
            return
        }
        libraryFolders = blob.folders
        libraryFolderAssignments = blob.assignments
    }

    private func persistLibraryFolders() {
        let blob = LibraryFoldersBlob(folders: libraryFolders, assignments: libraryFolderAssignments)
        if let data = try? JSONEncoder().encode(blob) {
            UserDefaults.standard.set(data, forKey: libraryFoldersKey)
            mirrorExtrasToCloud()
        }
    }

    func createLibraryFolder(_ name: String) {
        let clean = String(name.trimmingCharacters(in: .whitespacesAndNewlines).prefix(24))
        guard !clean.isEmpty else { return }
        guard !libraryFolders.contains(where: { $0.caseInsensitiveCompare(clean) == .orderedSame }) else {
            showToast("\(clean) already exists.")
            return
        }
        guard libraryFolders.count < 12 else {
            showToast("Twelve folders is the cap — merge a couple first.")
            return
        }
        libraryFolders.append(clean)
        persistLibraryFolders()
        showToast("Folder \(clean) created.")
    }

    func assignLibraryWorkout(templateID: UUID, to folder: String?) {
        if let folder {
            libraryFolderAssignments[templateID.uuidString] = folder
        } else {
            libraryFolderAssignments.removeValue(forKey: templateID.uuidString)
        }
        persistLibraryFolders()
    }

    func deleteLibraryFolder(_ name: String) {
        libraryFolders.removeAll { $0 == name }
        libraryFolderAssignments = libraryFolderAssignments.filter { $0.value != name }
        persistLibraryFolders()
        showToast("Folder \(name) removed — its workouts are back in All.")
    }

    func libraryFolder(forTemplateID id: UUID) -> String? {
        libraryFolderAssignments[id.uuidString]
    }

    // MARK: Referral deep links (morphe://invite/<username>)

    private static let pendingReferralKey = "morphe.referral.pending"

    /// Athletes who joined through this user's invite — the recruiter-side
    /// count of their own receipts ledger. Cached per-uid so the Profile row
    /// is honest offline; a failed refresh keeps the cache, never fakes 0.
    var referralCount: Int = 0

    private static func referralCountKey(_ uid: String) -> String { "morphe.referrals.count.\(uid)" }
    /// Recruiter uids this account wrote receipts under — remembered so
    /// account deletion can erase exactly what it created.
    private static func referralWrittenKey(_ uid: String) -> String { "morphe.referrals.written.\(uid)" }

    /// Cache-then-network refresh of the recruiter's own ledger count.
    func refreshReferralCount() async {
        guard let uid = authUser?.id else {
            referralCount = 0
            return
        }
        referralCount = UserDefaults.standard.integer(forKey: Self.referralCountKey(uid))
        if let live = await referralService.referralCount(uid: uid) {
            referralCount = live
            UserDefaults.standard.set(live, forKey: Self.referralCountKey(uid))
        }
    }

    /// Entry point for morphe:// URLs. Registering the scheme means the iOS
    /// Camera now launches Morphe for EVERY morphe:// QR — party and connect
    /// payloads must route, not silently drop. Invite links remember WHO
    /// invited, then connect the graph as soon as a signed-in session can.
    func handleIncomingURL(_ url: URL) {
        // Universal Links (https://<domain>/invite/<handle>) parse the same
        // as morphe://invite/<handle>. iOS only delivers https URLs the
        // AASA file matched, so the handler is host-agnostic on purpose —
        // it keeps working when the domain moves. Until the Associated
        // Domains entitlement ships (paid account gate), this path simply
        // never fires. docs/UNIVERSAL-LINKS.md has the flip.
        if url.scheme == "https" {
            let parts = url.pathComponents.filter { $0 != "/" }
            if parts.count >= 2, parts[parts.count - 2] == "invite" {
                let username = UsernameRules.normalize(parts[parts.count - 1])
                guard !username.isEmpty else { return }
                UserDefaults.standard.set(username, forKey: Self.pendingReferralKey)
                if isRealFeedActive {
                    Task { await consumePendingReferral() }
                } else {
                    showToast("Invite from @\(username) saved — it's recorded when you sign in.")
                }
            }
            return
        }
        guard url.scheme == "morphe" else { return }
        switch url.host {
        case "invite":
            let username = UsernameRules.normalize(url.lastPathComponent)
            guard !username.isEmpty else { return }
            UserDefaults.standard.set(username, forKey: Self.pendingReferralKey)
            if isRealFeedActive {
                Task { await consumePendingReferral() }
            } else {
                showToast("Invite from @\(username) saved — it's recorded when you sign in.")
            }
        case "party":
            // A party QR scanned with the system Camera (the in-app scanner
            // has its own path). Join goes through the same code flow.
            guard let code = URLComponents(url: url, resolvingAgainstBaseURL: false)?
                .queryItems?.first(where: { $0.name == "code" })?.value,
                  !code.isEmpty else { return }
            Task {
                if await joinParty(code: code) == false {
                    showToast("Couldn't join that party — the session may have ended.")
                }
            }
        case "connect":
            // Connect QRs carry a profile payload the in-app scanner records;
            // from the system Camera, route to the same handler.
            recordScannedConnection(from: url.absoluteString)
        default:
            break
        }
    }

    /// Resolves the stored invite to a uid via the username directory and
    /// follows them. Exact-match only. The pending key survives failed
    /// lookups (offline = try again next feed load) and clears only on a
    /// DEFINITIVE outcome: followed, or the directory answered and the
    /// handle genuinely doesn't exist.
    func consumePendingReferral() async {
        guard isRealFeedActive,
              let username = UserDefaults.standard.string(forKey: Self.pendingReferralKey)
        else { return }
        let hits = await usernameDirectory.search(prefix: username, limit: 5)
        // Empty CAN mean offline (the NoOp/failed search returns []) — keep
        // the invite and retry on the next feed load rather than eating it.
        guard !hits.isEmpty else { return }
        UserDefaults.standard.removeObject(forKey: Self.pendingReferralKey)
        guard let hit = hits.first(where: { $0.username == username }),
              hit.uid != authUser?.id else { return }
        // The follow graph is dark with the feed (audit 5, P1-9): the
        // visible Follow button was removed for exactly this reason, so
        // the deep link doesn't get to keep the invisible write. The
        // referral receipt below still lands either way.
        if FeatureFlags.socialFeedEnabled, !followedUids.contains(hit.uid) {
            toggleFollow(uid: hit.uid, name: "@\(hit.username)")
        }
        track("referral_consumed")
        // The recruiter-visible receipt: written by THIS account into
        // the recruiter's ledger (rules pin the doc id to this uid).
        // The recruiter uid is remembered so account deletion can
        // erase the receipt this device created.
        if let myUid = authUser?.id {
            referralService.recordReferral(recruiterUid: hit.uid, referredUid: myUid)
            var written = UserDefaults.standard.stringArray(forKey: Self.referralWrittenKey(myUid)) ?? []
            if !written.contains(hit.uid) {
                written.append(hit.uid)
                UserDefaults.standard.set(written, forKey: Self.referralWrittenKey(myUid))
            }
        }
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
        SoundEffects.play(.ding)
        showCelebration(title: "Post shared", detail: role == .coach ? "Coach network updated" : "Athlete network updated", symbol: "bubble.left.and.exclamationmark.bubble.right.fill")

        // When the REAL feed is live for this signed-in account, a shared win
        // ALSO publishes to Firestore (quiet path — the celebration above
        // already fired). The demo insert stays untouched for every other
        // caller (previews, tests, the flag-gated surfaces).
        if isRealFeedActive {
            Task { await publishToRealFeed(text: cleanText) }
        }
    }

    func sharePendingPartnerSessionPost() {
        guard let draft = pendingPartnerSessionPost else { return }
        publishPartnerSessionPost(draft)
        pendingPartnerSessionPost = nil
        SoundEffects.play(.ding)
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
        // The current athlete gets the schedule-aware streak (protected days
        // count); coach-side summaries keep the strict computation because
        // another athlete's schedule and protected days aren't known here.
        workoutLogSummary(
            from: workoutLogs(for: athleteID),
            scheduleAware: athleteID == clientProfile.id
        )
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

    // MARK: - Coach-managed clients (pre-signup profiles + claim handoff)

    /// Creates a client profile for someone who isn't on Morphe yet. Returns
    /// the new client so the UI can immediately show the shareable code.
    @discardableResult
    func addManagedClient(name: String, email: String, sport: SportFocus, notes: String) -> ManagedClient? {
        guard selectedRole == .coach else { return nil }
        guard let coachUid = authUser?.id else {
            showToast("Sign in to add clients — their profile syncs to the cloud.")
            return nil
        }
        let cleanName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanName.isEmpty else {
            showToast("Give your client a name first.")
            return nil
        }

        let client = ManagedClient(
            id: Self.makePartyCode(),
            coachUid: coachUid,
            coachName: coachProfile.name,
            name: cleanName,
            email: email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(),
            sport: sport,
            notes: notes.trimmingCharacters(in: .whitespacesAndNewlines)
        )
        managedClients.insert(client, at: 0)
        managedClientService.push(client)
        showToast("\(cleanName) added — share code \(client.id) when they join Morphe.")
        return client
    }

    /// Logs a workout on a managed client's record. History lives on the
    /// client object (not in `workoutLogs`) so the coach's own training data
    /// and backup never mix with a client's.
    func logWorkoutForManagedClient(
        _ clientID: String,
        template: WorkoutTemplate?,
        workoutTitle: String,
        durationMinutes: Int,
        notes: String,
        completedAt: Date = .now
    ) {
        guard let index = managedClients.firstIndex(where: { $0.id == clientID }) else { return }
        var client = managedClients[index]
        guard !client.isClaimed else {
            showToast("\(client.name) has claimed their account — they own their log now.")
            return
        }

        let cleanTitle = workoutTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        let fallbackTitle = template?.name ?? "\(client.sport.rawValue) session"
        let log = WorkoutLog(
            athleteID: client.athleteID,
            athleteName: client.name,
            workoutTemplateID: template?.id,
            workoutTitle: cleanTitle.isEmpty ? fallbackTitle : cleanTitle,
            sport: template?.sport ?? client.sport,
            // Backdating is allowed (a coach records yesterday's session);
            // the future is not.
            completedAt: min(completedAt, .now),
            durationMinutes: max(durationMinutes, 5),
            exercises: exerciseLogs(from: template),
            notes: notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                ? "\(coachProfile.name) logged this session."
                : notes,
            source: .coachManual,
            enteredByUserID: coachProfile.id,
            enteredByRole: .coach,
            enteredByName: coachProfile.name,
            verificationStatus: .coachSubmitted
        )

        client.logs.insert(log, at: 0)
        client.logs.sort { $0.completedAt > $1.completedAt }
        managedClients[index] = client
        managedClientService.push(client)
        SoundEffects.play(.ding)
        showCelebration(title: "Workout logged", detail: "\(log.workoutTitle) -> \(client.name)", symbol: "plus.circle.fill")
    }

    /// Removes an UNCLAIMED managed client (a claimed one is the athlete's
    /// account history now — the coach can't take it back).
    func deleteManagedClient(_ clientID: String) {
        guard let index = managedClients.firstIndex(where: { $0.id == clientID }),
              !managedClients[index].isClaimed else { return }
        let removed = managedClients.remove(at: index)
        managedClientService.delete(code: removed.id)
        showToast("\(removed.name) removed.")
    }

    /// Pulls this coach's managed clients from the cloud (launch + sign-in).
    /// A nil fetch (offline, not signed in) keeps whatever is already local.
    func refreshManagedClients() async {
        guard selectedRole == .coach, let coachUid = authUser?.id else { return }
        if let fetched = await managedClientService.fetchMine(coachUid: coachUid) {
            managedClients = fetched
        }
    }

    /// Athlete side of the handoff: claims the coach-created profile and
    /// imports its history into THIS account, re-keyed to the new identity.
    /// Coach attribution on each log is preserved (`enteredByName`), so the
    /// history stays honest about who recorded it.
    func claimCoachInvite(code: String) async {
        guard let uid = authUser?.id else { return }
        let result = await managedClientService.claim(
            code: code,
            athleteUid: uid,
            athleteName: clientProfile.name
        )
        switch result {
        case .failure(let error):
            showToast(error.message)
        case .success(let claimed):
            // Remember WHO the coach is — the coachShare consent toggle and
            // the summary's named reader both key off this link.
            linkedCoachUid = claimed.coachUid
            linkedCoachName = claimed.coachName
            track("coach_claimed")
            // Programs assigned before the claim deliver immediately.
            coachAssignments = claimed.assignments.sorted { $0.scheduledFor < $1.scheduledFor }
            lastAssignmentsFetchAt = .now
            for var log in claimed.logs.sorted(by: { $0.completedAt < $1.completedAt }) {
                log.athleteID = clientProfile.id
                log.athleteName = clientProfile.name
                appendWorkoutLog(log)
            }
            if clientProfile.limitations.isEmpty, !claimed.notes.isEmpty {
                // The coach's setup notes are a head start, not gospel — they
                // only fill fields the athlete left blank.
                clientProfile.limitations = claimed.notes
            }
            persistLocalProfile()
            let count = claimed.logs.count
            showCelebration(
                title: "Welcome aboard",
                detail: count > 0
                    ? "\(claimed.coachName) already logged \(count) workout\(count == 1 ? "" : "s") for you — your history starts full."
                    : "You're connected to \(claimed.coachName)'s roster.",
                symbol: "person.2.fill"
            )
        }
    }

    // MARK: - First week arc (day-7 retention bridge)

    struct FirstWeekStep: Identifiable {
        let id: Int
        let title: String
        let done: Bool
    }

    /// Loss-framed nudge condition: the REAL streak that ends tonight
    /// without a session. Nil unless there's a streak of 2+ days, today is
    /// a training day, and nothing is logged yet — losing beats gaining in
    /// the brain, but only when the thing at stake actually exists.
    var streakOnTheLineDays: Int? {
        let streak = currentAthleteWorkoutSummary.currentStreakDays
        guard streak >= 2, selectedRole == .client else { return nil }
        guard !plannedRestDay() else { return nil }
        let loggedToday = currentAthleteWorkoutLogs.contains {
            Calendar.current.isDateInToday($0.completedAt)
        }
        return loggedToday ? nil : streak
    }

    // MARK: - Conversational voice (alive wave)
    //
    // The app talks TO the user, in second person, about THEIR real state.
    // Every line below is derived from logged facts — the voice is warm,
    // the content is never invented (TRAIN HONEST applies to tone too).

    /// First name for greetings: display name's first token, then profile
    /// name, then a neutral fallback — never an empty "Hi , ".
    var greetingName: String {
        // Client-only surface — Today never renders for the coach role.
        let source = !profileShowcase.displayName.isEmpty
            ? profileShowcase.displayName : clientProfile.name
        let first = source.split(separator: " ").first.map(String.init) ?? ""
        return first.isEmpty ? "there" : first
    }

    /// Time-aware personal greeting — the first line of Today.
    var homeGreeting: String {
        let hour = Calendar.current.component(.hour, from: .now)
        switch hour {
        case 5..<12: return "Good morning, \(greetingName)!"
        case 12..<17: return "Hi \(greetingName)!"
        case 17..<22: return "Good evening, \(greetingName)!"
        default: return "Late one, \(greetingName)?"
        }
    }

    /// The question under the greeting — context-aware, one thought, in
    /// priority order of what actually matters right now.
    var homePrompt: String {
        // Priority mirrors the Today hero chain EXACTLY (audit 7, P1-1):
        // restDay -> logged -> assignment -> streak — the voice must never
        // contradict the card rendered underneath it.
        if isPlannedRestDay {
            return "It's your rest day. Recovery is part of the program — or train anyway if you're feeling it."
        }
        if isWorkoutLoggedToday {
            return "Today's session is in the books. Want to stack another, or check your progress?"
        }
        if let assignment = dueCoachAssignment {
            let coach = assignment.coachName.isEmpty ? "Your coach" : assignment.coachName
            return "\(coach) sent you a session — ready when you are."
        }
        if let atRisk = streakOnTheLineDays {
            return "Your \(atRisk)-day streak is on the line — one session today keeps it alive."
        }
        return "What workout would you like to start today?"
    }

    // MARK: - Morphe asks (Jarvis wave)
    //
    // The app asks how you're feeling and RESHAPES the day from the answer
    // — every option maps to a real, existing adjustment, and the spoken
    // reply only claims what actually happened. One ask per day.

    enum MorpheAskMood: String, CaseIterable, Identifiable {
        case ready = "Ready to go"
        case tired = "Tired"
        case sore = "Sore"
        case short = "Short on time"

        var id: String { rawValue }

        var symbol: String {
            switch self {
            case .ready: return "bolt.fill"
            case .tired: return "moon.zzz.fill"
            case .sore: return "bandage.fill"
            case .short: return "clock.fill"
            }
        }
    }

    /// Bumped on answer so the card re-evaluates.
    private(set) var morpheAskRefresh = 0

    private static let askDayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    /// Ask replies are keyed per profile per DAY and guide markers per
    /// profile — both removed by prefix on sign-out/delete (audit 8, P2)
    /// so "everything tied to it is gone from this device" stays true.
    private func purgeConversationalDefaults() {
        let prefixes = ["morphe.ask.\(clientProfile.id.uuidString)", guideSeenKey]
        for key in UserDefaults.standard.dictionaryRepresentation().keys
        where prefixes.contains(where: { key.hasPrefix($0) }) {
            UserDefaults.standard.removeObject(forKey: key)
        }
    }

    private var morpheAskKey: String {
        "morphe.ask.\(clientProfile.id.uuidString).\(Self.askDayFormatter.string(from: .now))"
    }

    /// Today's spoken reply, if the user already answered.
    var morpheAskReplyToday: String? {
        UserDefaults.standard.string(forKey: morpheAskKey)
    }

    /// Ask only when an answer can still shape the day: client role, no
    /// session logged, not a rest day, not already answered.
    var shouldOfferMorpheAsk: Bool {
        // No ask while a coach session leads Today (audit 8, P1-3): "tired"
        // would swap the GENERIC plan while the hero says start the
        // coach's — a contradiction the user can't see.
        selectedRole == .client && !isWorkoutLoggedToday
            && !isPlannedRestDay && dueCoachAssignment == nil
            && morpheAskReplyToday == nil
    }

    /// A non-committing reply (session work pending, template missing) —
    /// shown above the chips so the user can answer again; never burns the
    /// day's ask and never gets persisted as the app's word.
    private(set) var morpheAskTransientReply: String?

    /// Applies the honest adjustment for the mood and returns what the app
    /// says back. The reply persists for the day ONLY when the adjustment
    /// actually ran (audit 8, P0-2) — a queued dialog or missing template
    /// gets a transient reply and the chips stay.
    @discardableResult
    func answerMorpheAsk(_ mood: MorpheAskMood) -> String {
        guard !hasUnsavedSessionWork else {
            let reply = "You've got unfinished session work in Train — log it or clear it first, then ask me again."
            morpheAskTransientReply = reply
            morpheAskRefresh += 1
            Haptics.selection()
            return reply
        }
        let reply: String
        switch mood {
        case .ready:
            // No plan change to claim — the session is already queued.
            reply = "Love it. Your session's queued — hit Start when you're ready."
        case .tired:
            guard applyWorkoutAdjustment(.recovery, navigate: false, announce: false) else {
                return morpheAskFellThrough()
            }
            reply = "Got it — I swapped today for lighter recovery work. Showing up tired still counts."
        case .sore:
            guard applyWorkoutAdjustment(.recovery, navigate: false, announce: false) else {
                return morpheAskFellThrough()
            }
            reply = "Noted — recovery work today. If something specific hurts, add it under Profile → Injuries and I'll respect it."
        case .short:
            guard applyWorkoutAdjustment(.shorter, navigate: false, announce: false) else {
                return morpheAskFellThrough()
            }
            reply = "No problem — I trimmed today down. A short session beats no session."
        }
        morpheAskTransientReply = nil
        UserDefaults.standard.set(reply, forKey: morpheAskKey)
        morpheAskRefresh += 1
        Haptics.selection()
        SoundEffects.play(.ding)
        return reply
    }

    private func morpheAskFellThrough() -> String {
        let reply = "I couldn't line that up just now — your current plan stands."
        morpheAskTransientReply = reply
        morpheAskRefresh += 1
        Haptics.selection()
        return reply
    }

    // MARK: - One-time guide hints (alive wave)
    //
    // The step-by-step voice: each key surface introduces itself ONCE, in
    // a dismissible line, then never nags again. Seen-state is per profile.

    /// Bumped when a guide is dismissed so views re-evaluate visibility.
    private(set) var guideRefresh = 0

    /// Per-app-session intro-animation memory (audit 8, P2): bottom-bar
    /// taps remount tab roots via the .id reset, so view-local @State
    /// one-shots replayed on every visit. Not persisted — each launch
    /// gets exactly one entrance.
    private var playedIntroKeys: Set<String> = []
    func introPlayed(_ key: String) -> Bool { playedIntroKeys.contains(key) }
    func markIntroPlayed(_ key: String) { playedIntroKeys.insert(key) }

    private var guideSeenKey: String {
        "morphe.guides.seen.\(clientProfile.id.uuidString)"
    }

    func hasSeenGuide(_ key: String) -> Bool {
        (UserDefaults.standard.stringArray(forKey: guideSeenKey) ?? []).contains(key)
    }

    func markGuideSeen(_ key: String) {
        var seen = UserDefaults.standard.stringArray(forKey: guideSeenKey) ?? []
        guard !seen.contains(key) else { return }
        seen.append(key)
        UserDefaults.standard.set(seen, forKey: guideSeenKey)
        guideRefresh += 1
    }

    /// The 7-day starter checklist, or nil once week one is over. Every
    /// step's completion is DERIVED from real state — nothing to tick, the
    /// app notices. Steps stay achievable in any order.
    var firstWeekSteps: [FirstWeekStep]? {
        guard selectedRole == .client, let start = firstWeekStart else { return nil }
        let daysIn = Calendar.current.dateComponents(
            [.day], from: Calendar.current.startOfDay(for: start), to: Calendar.current.startOfDay(for: .now)
        ).day ?? 0
        guard daysIn < 7 else { return nil }
        let logCount = currentAthleteWorkoutLogs.count
        return [
            // Goal gradient, honestly: this list only exists AFTER account +
            // plan setup, so the first tick is a real completed fact — the
            // user starts at 1/6, never a wall of empty circles.
            FirstWeekStep(id: 0, title: "Create your account and plan", done: true),
            FirstWeekStep(id: 1, title: "Log your first session", done: logCount >= 1),
            FirstWeekStep(id: 2, title: "Do a recovery check-in", done: didCompleteQuickCheckIn || !recoverySeries.isEmpty),
            FirstWeekStep(id: 3, title: "Save your weight in Profile", done: Self.parsedBodyWeightLb(clientProfile.bodyWeight, assumedUnit: weightUnit) != nil),
            FirstWeekStep(id: 4, title: "Train a second time", done: logCount >= 2),
            FirstWeekStep(id: 5, title: "Train a third time", done: logCount >= 3)
        ]
    }

    // MARK: - Coach roster archive (claimed clients)

    /// Roster minus the archived. The underlying docs are the athletes'
    /// history — rules forbid touching them, so "remove" is a view state.
    var visibleManagedClients: [ManagedClient] {
        managedClients.filter { !archivedClientCodes.contains($0.id) }
    }

    func archiveClaimedClient(_ client: ManagedClient) {
        guard client.isClaimed else { return }
        archivedClientCodes.insert(client.id)
        showToast("\(client.name) removed from your roster view. Their account and history are untouched.")
    }

    func restoreArchivedClients() {
        archivedClientCodes = []
        showToast("Hidden clients restored.")
    }

    // MARK: - Health sleep pre-fill (read-only, opt-in)

    /// Flips the sleep pre-fill. Enabling asks Health for READ access to
    /// sleep — Apple never reveals whether a read was granted, so the
    /// toggle stays on and an empty query simply pre-fills nothing.
    func setHealthSleepPrefill(enabled: Bool) async {
        guard enabled else {
            healthSleepEnabled = false
            return
        }
        guard HealthWorkoutSync.isAvailable else {
            showToast("Health isn't available on this device.")
            return
        }
        healthSleepEnabled = true
        _ = await HealthWorkoutSync.requestSleepReadAuthorization()
        showToast("Check-ins will pre-fill sleep from Health when it's there.")
    }

    /// Last night's sleep for the check-in sheet — nil when disabled, no
    /// data, or access was declined (indistinguishable by design; the
    /// sheet just shows its normal slider).
    func healthSleepHoursForCheckIn() async -> Double? {
        guard healthSleepEnabled else { return nil }
        return await HealthWorkoutSync.lastNightSleepHours()
    }

    // MARK: - Coach share (athlete-consented progress visibility)

    /// Builds the consented summary from the athlete's REAL logs — every
    /// field is derived the same way the athlete's own Progress screen
    /// derives it. Internal so tests can pin the derivations.
    func makeCoachShareSummary(coachUid: String) -> CoachShareSummary {
        let logs = currentAthleteWorkoutLogs
        let calendar = Calendar.current
        let weeklyLogs = logs.filter {
            calendar.isDate($0.completedAt, equalTo: .now, toGranularity: .weekOfYear)
        }
        let sessions = logs.prefix(10).map { log in
            CoachShareSummary.SharedSession(
                title: log.workoutTitle,
                completedAt: log.completedAt,
                sets: Self.loggedSetCount(of: log),
                minutes: log.durationMinutes,
                feedback: log.sessionFeedback ?? ""
            )
        }
        let prs = recentPersonalRecords(limit: 5).map { record in
            CoachShareSummary.SharedPR(
                name: record.exerciseName,
                weight: record.weight,
                unit: weightUnit.rawValue,
                date: record.date
            )
        }
        // Readiness only when the athlete actually checked in today —
        // score > 0 was NOT enough: the seeded default snapshot carries a
        // neutral 60, and sharing that would hand the coach a fabricated
        // signal. The check-in flag is the truth (it resets with the day).
        let readiness: String
        if didCompleteQuickCheckIn {
            readiness = "Readiness \(recovery.score)/100 — \(recovery.reason)"
        } else {
            readiness = ""
        }
        return CoachShareSummary(
            coachUid: coachUid,
            athleteName: clientProfile.name,
            streak: currentWorkoutStreak(from: logs),
            weeklySets: weeklySetVolume(weeks: 1).last?.sets ?? 0,
            weeklyWorkouts: weeklyLogs.count,
            totalWorkouts: logs.count,
            recentSessions: Array(sessions),
            recentPRs: prs,
            readinessNote: readiness
        )
    }

    /// Flips consent. On: pushes the summary immediately (and on every
    /// future log/check-in). Off: DELETES the doc — revocation is instant
    /// and server-enforced, not a client courtesy.
    func setCoachShare(enabled: Bool) {
        guard let uid = authUser?.id else {
            showToast("Sign in to share progress with your coach.")
            return
        }
        guard !linkedCoachUid.isEmpty else {
            showToast("Connect with a coach first — claim their invite code.")
            return
        }
        coachShareEnabled = enabled
        if enabled {
            managedClientService.pushCoachShare(
                makeCoachShareSummary(coachUid: linkedCoachUid), athleteUid: uid)
            showToast("\(linkedCoachName.isEmpty ? "Your coach" : linkedCoachName) now sees your progress summary.")
        } else {
            managedClientService.clearCoachShare(athleteUid: uid)
            showToast("Progress sharing is off — your coach sees nothing new.")
        }
    }

    /// Refreshes the shared doc after anything it summarizes changed.
    /// Quiet no-op unless consent is on and the link is real.
    private func pushCoachShareIfEnabled() {
        guard coachShareEnabled, !linkedCoachUid.isEmpty,
              selectedRole == .client, let uid = authUser?.id else { return }
        managedClientService.pushCoachShare(
            makeCoachShareSummary(coachUid: linkedCoachUid), athleteUid: uid)
    }

    /// Coach side: pulls one claimed client's shared summary. Marks the uid
    /// fetched either way so the UI can render "not sharing" as a KNOWN
    /// state instead of guessing.
    func loadCoachShare(for client: ManagedClient) async {
        guard client.isClaimed else { return }
        guard !client.claimedByUid.isEmpty else {
            // Legacy/corrupt claim doc with no uid: mark it fetched so the
            // sheet renders the honest not-sharing state instead of spinning
            // on "Checking…" forever.
            coachShareFetched.insert(client.claimedByUid)
            return
        }
        let summary = await managedClientService.fetchCoachShare(athleteUid: client.claimedByUid)
        coachShareFetched.insert(client.claimedByUid)
        if let summary {
            coachShareSummaries[client.claimedByUid] = summary
        } else {
            coachShareSummaries.removeValue(forKey: client.claimedByUid)
        }
    }

    // MARK: - Real 1:1 messaging (coach ↔ claimed client)

    /// Within this window a non-forced thread refresh is a no-op — the two
    /// participant queries are unbounded, and DMs made thread count grow
    /// with usage, so every ungated tab switch was a full-inbox read.
    private static let threadsStalenessWindow: TimeInterval = 300
    private var lastThreadsRefreshAt: Date?

    /// Pulls every real thread this account participates in — either role —
    /// on launch and sign-in (same pattern as `refreshManagedClients`). A nil
    /// fetch (offline, signed out, no-op service) keeps whatever is local.
    /// Soft by default (staleness-gated); force from sign-in and the
    /// moments that just CHANGED the inbox (new chat started).
    func refreshThreads(force: Bool = false) async {
        guard let uid = authUser?.id else { return }
        if !force, !liveThreads.isEmpty, let last = lastThreadsRefreshAt,
           Date.now.timeIntervalSince(last) < Self.threadsStalenessWindow {
            return
        }
        if let fetched = await messagingService.fetchThreads(for: uid) {
            lastThreadsRefreshAt = .now
            // Blocking reaches MESSAGING too (launch audit P0-2): a blocked
            // account's thread never renders, in either direction.
            liveThreads = fetched.filter { thread in
                blockedAccounts[thread.coachUid] == nil
                    && blockedAccounts[thread.athleteUid] == nil
            }
            // Fallback link capture: an athlete who claimed BEFORE the
            // linked-coach fields existed still has a coach thread — adopt
            // it so the coachShare toggle appears for them too.
            if selectedRole == .client, linkedCoachUid.isEmpty,
               let coachThread = fetched.first(where: { $0.athleteUid == uid }) {
                linkedCoachUid = coachThread.coachUid
                linkedCoachName = coachThread.coachName
            }
        }
    }

    /// Opens a thread: clears stale messages and starts the live listener.
    /// Safe to call for a thread that's already open (listener restarts).
    /// Locally-echoed sends awaiting their server copy (speed audit S0-4).
    private(set) var pendingOutgoingMessages: [ChatMessage] = []
    /// False until the open thread's listener delivers its first snapshot —
    /// gates the "No messages yet" claim (speed audit S0-5).
    private(set) var threadFirstSnapshotArrived = false

    /// What the conversation renders: confirmed messages + optimistic tail.
    var displayedThreadMessages: [ChatMessage] {
        activeThreadMessages + pendingOutgoingMessages
    }

    func openThread(_ thread: MessageThreadSummary) {
        activeThreadId = thread.id
        activeThreadMessages = []
        pendingOutgoingMessages = []
        threadFirstSnapshotArrived = false
        markThreadRead(thread.id)
        messagingService.listenMessages(threadId: thread.id) { [weak self] messages in
            Task { @MainActor [weak self] in
                guard let self, self.activeThreadId == thread.id else { return }
                self.activeThreadMessages = messages
                self.threadFirstSnapshotArrived = true
                // The server copy replaces the optimistic echo.
                self.pendingOutgoingMessages.removeAll { pending in
                    messages.contains {
                        $0.senderUid == pending.senderUid && $0.text == pending.text
                            // A HISTORIC identical message must not eat the
                            // echo (post-revamp audit P2-9).
                            && $0.sentAt >= pending.sentAt.addingTimeInterval(-120)
                    }
                }
                // Every delivery while the thread is on screen IS seen —
                // stamping here (not just open/close) means a message you
                // watched arrive can't resurface as unread after a swipe
                // that never fires onDisappear.
                self.markThreadRead(thread.id)
            }
        }
    }

    /// Stops the live listener and clears the open-thread state.
    func closeThread() {
        pendingOutgoingMessages = []
        threadFirstSnapshotArrived = false
        // Everything that streamed in while the thread was on screen was
        // seen — stamp read on the way out so a message that arrived
        // mid-conversation doesn't resurface as "unread".
        if let activeThreadId { markThreadRead(activeThreadId) }
        messagingService.stopListening()
        activeThreadId = nil
        activeThreadMessages = []
    }

    // MARK: Thread read-state (honest local lens)
    //
    // Per-profile, device-local. It claims exactly what it knows: whether
    // THIS profile opened the thread on THIS device since the last message
    // arrived — never synced, never a cross-device promise.

    private var threadReadKey: String { "morphe.threads.read.\(clientProfile.id.uuidString)" }
    /// In-memory mirror of the read-stamp plist (speed audit S1-2): the
    /// per-thread UserDefaults dictionary decode ran 8N times per coach
    /// Home frame. Loaded once, written through, dropped on profile switch.
    private var threadReadCache: [String: Double]?
    /// Bumped on every read-stamp so ring/row states refresh — UserDefaults
    /// isn't observable on its own (same trick as storySeenTick).
    private(set) var threadReadTick = 0

    private func threadLastRead(_ threadId: String) -> Date {
        if threadReadCache == nil {
            threadReadCache = UserDefaults.standard.dictionary(forKey: threadReadKey) as? [String: Double] ?? [:]
        }
        return threadReadCache?[threadId].map { Date(timeIntervalSince1970: $0) } ?? .distantPast
    }

    func markThreadRead(_ threadId: String) {
        var map = threadReadCache
            ?? UserDefaults.standard.dictionary(forKey: threadReadKey) as? [String: Double] ?? [:]
        map[threadId] = Date.now.timeIntervalSince1970
        threadReadCache = map
        UserDefaults.standard.set(map, forKey: threadReadKey)
        threadReadTick += 1
    }

    /// Unread = the newest message is the counterpart's and landed after
    /// this profile last had the thread open.
    func isThreadUnread(_ thread: MessageThreadSummary) -> Bool {
        guard let myUid = authUser?.id else { return false }
        _ = threadReadTick
        return !thread.lastMessage.isEmpty
            && thread.lastSender != myUid
            && thread.updatedAt > threadLastRead(thread.id)
    }

    var unreadThreadCount: Int { liveThreads.filter { isThreadUnread($0) }.count }

    /// Sends one immutable message into the open thread. The listener streams
    /// it back into `activeThreadMessages`; the local inbox preview rolls
    /// forward immediately so the list is honest without a refetch.
    func sendMessage(_ text: String) async {
        let clean = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return }
        guard let uid = authUser?.id, let threadId = activeThreadId else { return }
        // Optimistic echo (speed audit S0-4): the bubble renders NOW; the
        // listener's server copy replaces it on arrival.
        let pending = ChatMessage(id: "pending-\(UUID().uuidString)",
                                  senderUid: uid, text: String(clean.prefix(2000)),
                                  sentAt: .now)
        pendingOutgoingMessages.append(pending)
        guard await messagingService.send(threadId: threadId, senderUid: uid,
                                          text: String(clean.prefix(2000))) else {
            pendingOutgoingMessages.removeAll { $0.id == pending.id }
            showToast("Message didn't send — check your connection.")
            return
        }
        if let index = liveThreads.firstIndex(where: { $0.id == threadId }) {
            liveThreads[index].lastMessage = String(clean.prefix(300))
            liveThreads[index].lastSender = uid
            liveThreads[index].updatedAt = .now
            liveThreads.sort { $0.updatedAt > $1.updatedAt }
        }
    }

    /// Coach side: opens (creating if needed) the real thread with the
    /// athlete who CLAIMED this managed client, and returns it (nil when
    /// the link isn't real yet or the network said no) — the caller
    /// navigates with THIS value; looking it up in liveThreads afterward
    /// could silently miss the synthesized fallback (coach audit).
    @discardableResult
    func startThreadWithClaimedClient(_ client: ManagedClient) async -> MessageThreadSummary? {
        guard selectedRole == .coach, let coachUid = authUser?.id else { return nil }
        guard client.isClaimed, !client.claimedByUid.isEmpty else {
            showToast("\(client.name) hasn't claimed their invite yet.")
            return nil
        }
        let athleteName = client.claimedByName.isEmpty ? client.name : client.claimedByName
        guard let threadId = await messagingService.ensureThread(
            coachUid: coachUid,
            athleteUid: client.claimedByUid,
            coachName: coachProfile.name,
            athleteName: athleteName
        ) else {
            showToast("Couldn't open the conversation — check your connection.")
            return nil
        }
        await refreshThreads(force: true)
        let thread = liveThreads.first(where: { $0.id == threadId })
            ?? MessageThreadSummary(
                id: threadId,
                coachUid: coachUid,
                athleteUid: client.claimedByUid,
                coachName: coachProfile.name,
                athleteName: athleteName
            )
        openThread(thread)
        return thread
    }

    // MARK: - Real community feed (posts, reactions, saves, reposts)

    /// True when a REAL Firestore feed backs the For You surface this
    /// session — signed in with a live feed service. Drives the UI branch
    /// between the real feed and the flag-gated demo sections.
    var isRealFeedActive: Bool {
        authUser != nil && !(feedService is NoOpFeedService)
    }

    /// The display name posts publish under for the current role.
    private var feedAuthorName: String {
        let name = selectedRole == .coach ? coachProfile.name : clientProfile.name
        return name.isEmpty ? (authUser?.displayName ?? "Athlete") : name
    }

    /// The byline stamped onto posts: sport focus, plus the live workout
    /// streak only when one exists (≥2 days) AND the user shares it
    /// (postStreakByline). Derived from logged facts at publish time — a
    /// lapsed streak simply stops appearing on new posts.
    var feedAuthorHeadline: String {
        if selectedRole == .coach {
            // Real roster, real byline (benchmark Tier 2): a coach's posts
            // carry their practice size only when one exists — "Coach" alone
            // stays honest at zero.
            let roster = visibleManagedClients.count
            let specialty = coachProfile.specialty
            var parts = ["Coach"]
            if !specialty.isEmpty, specialty != "Personal coaching" { parts.append(specialty) }
            if roster > 0 { parts.append("\(roster) athlete\(roster == 1 ? "" : "s")") }
            return String(parts.joined(separator: " · ").prefix(80))
        }
        let sport = clientProfile.sportMode.rawValue
        let streak = clientProfile.level.streak
        let headline = (postStreakByline && streak >= 2)
            ? "\(sport) · \(streak)-day streak" : sport
        return String(headline.prefix(80))
    }

    /// The accent id posts carry: the custom hex when Custom is active
    /// (readable by every client via MorpheTheme.accentColor), otherwise
    /// the palette name. Empty when the user keeps identity off posts.
    var feedAuthorAccentId: String {
        guard postAccentIdentity else { return "" }
        if profileShowcase.accentPalette == .custom {
            let hex = profileShowcase.customAccentHex
            return hex.isEmpty ? AccentPalette.gold.rawValue : String(hex.prefix(24))
        }
        return profileShowcase.accentPalette.rawValue
    }

    /// One feed page (READINESS-300 R4): small enough that the per-post
    /// reaction hydration stays cheap, big enough to fill a screen twice.
    static let feedPageSize = 20
    /// Within this window a non-forced refresh is a no-op (R1) — launch
    /// and tab-visit reuse the loaded page; only pull-to-refresh forces.
    private static let feedStalenessWindow: TimeInterval = 300
    private var lastFeedRefreshAt: Date?
    /// Post ids whose reaction state (count + my own) was fetched this
    /// session (R2/R3): scrolling back over known posts costs zero reads.
    private var reactionStateFetchedIds: Set<String> = []
    /// False once a page comes back short — hides the "Load older" row.
    private(set) var feedHasOlderPosts = false
    /// Paging cursor tracked from the RAW fetched page (not the filtered
    /// render list) — a fully-filtered page still advances it, so LOAD
    /// OLDER can never stall re-fetching the same blocked page forever.
    private var feedPageCursor: Date?
    /// Presence window: every post of the last 24h, fetched independently
    /// of the paginated feed — Trained Today and Duo Streaks read this
    /// union so page size can't shrink who shows as present.
    private(set) var presencePosts: [FeedPost] = []
    /// The presence query is the most expensive fetch per byte (it repeats
    /// image-bearing posts the page already has) — hourly, not per refresh.
    private var lastPresenceRefreshAt: Date?
    /// Membership sets (blocked/saved/following) change only through THIS
    /// device's own actions, which mutate local state directly — one fetch
    /// per session hydrates them; refreshes stop re-reading whole
    /// collections (1000-user audit #8).
    private var membershipSetsFetched = false

    /// The dark-feed fetch gate as a pure function — every feed test
    /// injects a test double (which passes), so this is the only way the
    /// Firebase leg of the guard gets exercised (audit 5, P2).
    static func shouldFetchFeed(socialFeedEnabled: Bool, usesFirebaseFeed: Bool) -> Bool {
        socialFeedEnabled || !usesFirebaseFeed
    }

    /// Pulls the newest posts + their real reaction counts + this account's
    /// bookmarks. Runs on launch/sign-in and tab visits (both soft: within
    /// the staleness window they reuse the loaded page) and from
    /// pull-to-refresh (forced). A nil fetch (offline, signed out, no-op
    /// service) keeps whatever is local.
    func refreshFeed(force: Bool = false) async {
        // The feed is dark (socialFeedEnabled=false): no reader exists, so
        // no launch/sign-in fetch should pay FIREBASE for it (post-cut
        // audit P1-7). Test doubles still run — the logic stays warm.
        guard Self.shouldFetchFeed(
            socialFeedEnabled: FeatureFlags.socialFeedEnabled,
            usesFirebaseFeed: feedService is FirebaseFeedService
        ) else { return }
        guard let uid = authUser?.id else { return }
        if !force, !feedPosts.isEmpty, let last = lastFeedRefreshAt,
           Date.now.timeIntervalSince(last) < Self.feedStalenessWindow {
            return
        }
        // Loaded content stays visible through a re-fetch; only a first
        // load (or a retry after failure) shows the loading surface.
        if feedFetchState != .loaded { feedFetchState = .loading }
        // Blocks load FIRST so the post filter below always has them —
        // once per session: blocking from this device updates the local
        // set directly, so a re-read per refresh bought nothing.
        if !membershipSetsFetched, let blocked = await feedService.fetchBlocked(uid: uid) {
            blockedAccounts = blocked
        }
        if let fetched = await feedService.fetchRecent(limit: Self.feedPageSize, before: nil) {
            feedFetchState = .loaded
            lastFeedRefreshAt = .now
            // Two-layer render filter: blocked authors are the user's call;
            // the term filter is the App Store 1.2 hygiene net for content
            // other clients let through. workoutName is user-typed text too —
            // a slur in the pill is still a slur.
            // Arrivals fade in instead of popping — the shell animates,
            // the content shouldn't snap.
            let cleanPage = fetched.filter { renderableFeedPost($0) }
            withAnimation(.easeInOut(duration: 0.25)) {
                if feedPosts.isEmpty {
                    feedPosts = cleanPage
                } else {
                    // MERGE, never replace: a refresh must not delete the
                    // pages the user scrolled through (or their scroll
                    // position). New posts go on top; known posts update
                    // in place; older pages stay.
                    let pageIds = Set(cleanPage.map(\.id))
                    let kept = feedPosts.filter { !pageIds.contains($0.id) }
                    feedPosts = (cleanPage + kept).sorted { $0.createdAt > $1.createdAt }
                }
            }
            if feedPageCursor == nil || feedPosts.count <= Self.feedPageSize {
                feedPageCursor = fetched.last?.createdAt
                feedHasOlderPosts = fetched.count == Self.feedPageSize
            }
            await hydrateReactionState(for: cleanPage.map(\.id), uid: uid, force: force)
            // Presence is its own bounded query — but it re-downloads posts
            // (images included) the page already carries, so it runs at most
            // hourly (1000-user audit #4): the rail is a 24h lens, an hour
            // of staleness is invisible, and the union below keeps every
            // freshly-fetched page feeding it for free.
            if lastPresenceRefreshAt == nil
                || Date.now.timeIntervalSince(lastPresenceRefreshAt!) > 3600 {
                if let recent = await feedService.fetchSince(
                    date: Date.now.addingTimeInterval(-24 * 3600), limit: 30) {
                    presencePosts = recent.filter { renderableFeedPost($0) }
                    lastPresenceRefreshAt = .now
                }
            }
        } else if feedPosts.isEmpty {
            // Nothing fetched AND nothing on screen — that's a failure the
            // user must see, not an empty state. Existing content just
            // stays: a failed re-fetch never blanks a working feed.
            feedFetchState = .failed
        }
        if !membershipSetsFetched {
            if let saved = await feedService.fetchSavedPostIds(uid: uid) {
                savedPostIds = saved
            }
            if let following = await feedService.fetchFollowing(uid: uid) {
                followedUids = following
            }
            membershipSetsFetched = true
        }
        // Referral consume/count moved to the launch path (audit 6, P1-3):
        // this tail sits behind the dark-feed guard, which never opens in
        // the shipping configuration.
    }

    /// Appends the next page below the loaded feed. The cursor advances
    /// from the RAW page even when every row was filtered out — otherwise
    /// one fully-blocked page would stall pagination forever.
    func loadOlderFeedPosts() async {
        guard let uid = authUser?.id, feedHasOlderPosts,
              let cursor = feedPageCursor ?? feedPosts.last?.createdAt else { return }
        guard let fetched = await feedService.fetchRecent(
            limit: Self.feedPageSize, before: cursor) else { return }
        feedHasOlderPosts = fetched.count == Self.feedPageSize
        feedPageCursor = fetched.last?.createdAt ?? cursor
        let known = Set(feedPosts.map(\.id))
        let fresh = fetched.filter { !known.contains($0.id) && renderableFeedPost($0) }
        guard !fresh.isEmpty else { return }
        feedPosts.append(contentsOf: fresh)
        await hydrateReactionState(for: fresh.map(\.id), uid: uid, force: false)
    }

    // MARK: Activity diff (TIKTOK-PLAN T5) — the honest push substitute.
    //
    // Real engagement push needs FCM + Functions (Blaze-gated). Until
    // then: a per-profile baseline of engagement counts on MY posts,
    // diffed against what's currently loaded. Claims only what it can
    // see — "new since you last checked here", never "new right now".

    private var activitySeenKey: String { "morphe.activity.seen.\(clientProfile.id.uuidString)" }
    private(set) var activitySeenTick = 0

    /// Engagement on my loaded posts (reactions always; comments when
    /// loaded) minus what this profile last acknowledged.
    var unseenActivityCount: Int {
        _ = activitySeenTick
        guard let myUid = authUser?.id else { return 0 }
        let seen = UserDefaults.standard.dictionary(forKey: activitySeenKey) as? [String: Int] ?? [:]
        return feedPosts.filter { $0.authorUid == myUid }.reduce(0) { total, post in
            let current = (feedReactionCounts[post.id] ?? 0) + (postComments[post.id]?.count ?? 0)
            return total + max(0, current - (seen[post.id] ?? 0))
        }
    }

    /// The user looked — today's counts become the new baseline.
    func acknowledgeActivity() {
        guard let myUid = authUser?.id else { return }
        var seen = UserDefaults.standard.dictionary(forKey: activitySeenKey) as? [String: Int] ?? [:]
        for post in feedPosts where post.authorUid == myUid {
            seen[post.id] = (feedReactionCounts[post.id] ?? 0) + (postComments[post.id]?.count ?? 0)
        }
        if seen.count > 200 { seen = seen.filter { pair in feedPosts.contains { $0.id == pair.key } } }
        UserDefaults.standard.set(seen, forKey: activitySeenKey)
        activitySeenTick += 1
    }

    /// Ranked feed (NETWORK-TIKTOK-PLAN T2): a transparent heuristic, not
    /// a black box — recency decays over ~36h, every reaction and loaded
    /// comment counts, followed authors get a boost, and a diversity guard
    /// keeps one hot author from monopolizing the top. Pure + static so
    /// the ranking is testable and explainable in one sentence.
    static func rankFeedPosts(
        _ posts: [FeedPost],
        reactionCounts: [String: Int],
        commentCounts: [String: Int],
        followedUids: Set<String>,
        now: Date = .now
    ) -> [FeedPost] {
        func score(_ post: FeedPost) -> Double {
            let ageHours = max(0, now.timeIntervalSince(post.createdAt) / 3600)
            let recency = 100.0 * exp(-ageHours / 36.0)
            let engagement = Double(reactionCounts[post.id] ?? 0) * 6.0
                + Double(commentCounts[post.id] ?? 0) * 10.0
            let followBoost = followedUids.contains(post.authorUid) ? 25.0 : 0.0
            return recency + engagement + followBoost
        }
        // Score ONCE per post, sort on the pair (speed audit S1-1): the
        // scorer-in-comparator shape ran exp() ~2·n·log n times per call.
        let scored = posts.map { (score($0), $0) }
            .sorted { $0.0 > $1.0 }
            .map(\.1)
        // Diversity guard: demote consecutive same-author runs so a burst
        // poster can't own the whole first screen.
        var result: [FeedPost] = []
        var deferred: [FeedPost] = []
        for post in scored {
            if post.authorUid == result.last?.authorUid {
                deferred.append(post)
            } else {
                result.append(post)
            }
        }
        result.append(contentsOf: deferred)
        return result
    }

    /// The feed in ranked order, from state the store already holds.
    /// Memoized on a cheap revision key (speed audit S1-1): the ranked
    /// order only changes when posts/reactions/comments/follows do — not
    /// on every body evaluation of the app's main scroll surface.
    private var rankedFeedCache: (key: Int, posts: [FeedPost])?

    var rankedFeedPosts: [FeedPost] {
        var hasher = Hasher()
        hasher.combine(feedPosts.count)
        hasher.combine(feedPosts.first?.id)
        hasher.combine(feedPosts.last?.id)
        // Per-post, not a sum — a reaction SWAP between posts must change
        // the key (post-revamp audit P2-8).
        hasher.combine(feedReactionCounts)
        hasher.combine(postComments.values.reduce(0) { $0 + $1.count })
        hasher.combine(followedUids.count)
        let key = hasher.finalize()
        if let cached = rankedFeedCache, cached.key == key { return cached.posts }
        let ranked = Self.rankFeedPosts(
            feedPosts,
            reactionCounts: feedReactionCounts,
            commentCounts: postComments.mapValues(\.count),
            followedUids: followedUids
        )
        rankedFeedCache = (key, ranked)
        return ranked
    }

    private func renderableFeedPost(_ post: FeedPost) -> Bool {
        !blockedUids.contains(post.authorUid)
            && !ContentModeration.containsBlockedTerm(post.text)
            && !ContentModeration.containsBlockedTerm(post.workoutName)
    }

    /// Reaction counts + my own reactions, fetched only for ids not yet
    /// seen this session (forced pull refetches the given page so counts
    /// stay honest when the user explicitly asks for fresh). MERGES into
    /// the caches — hydrating a new page never blanks known state.
    private func hydrateReactionState(for ids: [String], uid: String, force: Bool) async {
        // A forced pull re-fetches THIS page's counts (that's what the user
        // asked for) but keeps the session cache for pages behind it —
        // wiping it made every pull-to-refresh re-hydrate the whole scroll
        // history one page at a time (1000-user audit #11).
        if force { reactionStateFetchedIds.subtract(ids) }
        let wanted = ids.filter { !reactionStateFetchedIds.contains($0) }
        guard !wanted.isEmpty else { return }
        let counts = await feedService.fetchReactionCounts(postIds: wanted)
        feedReactionCounts.merge(counts) { _, new in new }
        // Hydrate the filled-heart state: which of these posts THIS
        // account already reacted to (and with what type) — without
        // this, a relaunch forgets and a re-tap double-counts locally.
        if let mine = await feedService.fetchMyReactions(uid: uid, postIds: wanted) {
            for id in wanted { myReactionTypes[id] = mine[id] }
            myReactedPostIds = Set(myReactionTypes.keys)
        }
        reactionStateFetchedIds.formUnion(wanted)
    }

    // MARK: Report + block (App Store 1.2: report, block, filter)

    static let reportReasons = ["Spam", "Abuse or hate", "Nudity or sexual content", "Dangerous advice", "Other"]

    func reportPost(_ post: FeedPost, reason: String) {
        guard let uid = authUser?.id else { return }
        Task {
            let sent = await feedService.submitReport(
                reporterUid: uid, kind: "post", targetId: post.id,
                targetUid: post.authorUid, reason: reason, excerpt: post.text)
            showToast(sent ? "Report sent — a human reviews every one."
                           : "Report didn't send — check your connection.")
        }
    }

    func reportComment(_ comment: PostComment, reason: String) {
        guard let uid = authUser?.id else { return }
        Task {
            let sent = await feedService.submitReport(
                reporterUid: uid, kind: "comment",
                targetId: "\(comment.postId)/\(comment.id)",
                targetUid: comment.authorUid, reason: reason, excerpt: comment.text)
            showToast(sent ? "Report sent — a human reviews every one."
                           : "Report didn't send — check your connection.")
        }
    }

    /// Blocks one account: their posts/comments/search hits disappear now
    /// and stay gone (the block doc filters every future fetch), and any
    /// follow edge this side owns is severed.
    /// Files a kind-'user' report — the rules allowed it all along; the DM
    /// wave finally gives it a UI (launch audit P0-2).
    func reportUser(uid targetUid: String, name: String, reason: String) {
        guard let uid = authUser?.id else { return }
        Task {
            let sent = await feedService.submitReport(
                reporterUid: uid, kind: "user", targetId: targetUid,
                targetUid: targetUid, reason: reason, excerpt: name)
            showToast(sent ? "Report sent — a human reviews every one."
                           : "Report didn't send — check your connection.")
        }
    }

    func blockAccount(uid targetUid: String, name: String) {
        guard let uid = authUser?.id, targetUid != uid else { return }
        blockedAccounts[targetUid] = name
        feedService.setBlocked(uid: uid, targetUid: targetUid, name: name, on: true)
        if followedUids.contains(targetUid) {
            followedUids.remove(targetUid)
            feedService.setFollow(uid: uid, targetUid: targetUid, on: false)
        }
        feedPosts.removeAll { $0.authorUid == targetUid }
        for (postId, comments) in postComments {
            postComments[postId] = comments.filter { $0.authorUid != targetUid }
        }
        athleteSearchResults.removeAll { $0.uid == targetUid }
        // Blocking is instant in MESSAGING too (launch audit P0-2): their
        // thread leaves the inbox now, and if it's open it closes.
        if liveThreads.contains(where: {
            ($0.coachUid == targetUid || $0.athleteUid == targetUid) && $0.id == activeThreadId
        }) {
            closeThread()
        }
        liveThreads.removeAll { $0.coachUid == targetUid || $0.athleteUid == targetUid }
        showToast("Blocked \(name). Their posts and comments are gone from your feed.")
    }

    func unblockAccount(uid targetUid: String) {
        guard let uid = authUser?.id else { return }
        let name = blockedAccounts.removeValue(forKey: targetUid) ?? "Athlete"
        feedService.setBlocked(uid: uid, targetUid: targetUid, name: name, on: false)
        // Their content comes back NOW, not on the next manual refresh.
        Task { await refreshFeed(force: true) }
        showToast("Unblocked \(name).")
    }

    // MARK: Follow graph + user discovery

    func isFollowing(_ uid: String) -> Bool {
        followedUids.contains(uid)
    }

    /// Follows/unfollows one account. Optimistic like reactions — the write
    /// queues offline and the owner-only doc can't lie about anyone else.
    func toggleFollow(uid targetUid: String, name: String) {
        guard let uid = authUser?.id, targetUid != uid else { return }
        let on = !followedUids.contains(targetUid)
        if on {
            followedUids.insert(targetUid)
        } else {
            followedUids.remove(targetUid)
        }
        feedService.setFollow(uid: uid, targetUid: targetUid, on: on)
        if on { Haptics.impact(.light) }
        showToast(on ? "Following \(name)." : "Unfollowed \(name).")
    }

    /// Username prefix search (2+ chars). Results exclude this account —
    /// following yourself is noise.
    func searchAthletes(query: String) async {
        let clean = UsernameRules.normalize(query)
        guard clean.count >= 2 else {
            athleteSearchResults = []
            return
        }
        let hits = await usernameDirectory.search(prefix: clean, limit: 10)
        athleteSearchResults = hits
            .filter { $0.uid != authUser?.id && !blockedUids.contains($0.uid) }
            .map { AthleteSearchResult(username: $0.username, uid: $0.uid) }
    }

    // MARK: Comments

    /// Fetches one post's comments (on expand). Nil result (offline) keeps
    /// whatever is local rather than blanking the thread.
    func loadComments(for post: FeedPost) async {
        guard isRealFeedActive else { return }
        if let fetched = await feedService.fetchComments(postId: post.id, limit: 100) {
            postComments[post.id] = fetched.filter {
                !blockedUids.contains($0.authorUid)
                    && !ContentModeration.containsBlockedTerm($0.text)
            }
        }
    }

    /// Returns whether the comment actually posted, so the composer can put
    /// the typed text back instead of eating it on failure.
    @discardableResult
    func addComment(to post: FeedPost, text: String) async -> Bool {
        guard let uid = authUser?.id else { return false }
        let clean = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return false }
        guard !ContentModeration.containsBlockedTerm(clean) else {
            showToast(ContentModeration.refusalMessage)
            return false
        }
        let comment = PostComment(
            id: UUID().uuidString,
            postId: post.id,
            authorUid: uid,
            authorName: feedAuthorName,
            text: clean.wireClamped(300)
        )
        guard await feedService.addComment(comment) else {
            showToast("Comment didn't send — check your connection.")
            return false
        }
        postComments[post.id, default: []].append(comment)
        Haptics.impact(.light)
        return true
    }

    func deleteMyComment(_ comment: PostComment) {
        guard comment.authorUid == authUser?.id else { return }
        feedService.deleteComment(postId: comment.postId, commentId: comment.id)
        postComments[comment.postId]?.removeAll { $0.id == comment.id }
        showToast("Comment deleted.")
    }

    /// Publishes one post to the real feed and inserts it locally on success.
    /// Quiet core shared by the composer and the share-a-win rewire below.
    @discardableResult
    private func publishToRealFeed(text: String, workoutName: String = "",
                                   repostOfId: String = "", repostOfAuthor: String = "",
                                   durationMinutes: Int? = nil, setCount: Int? = nil,
                                   exerciseCount: Int? = nil, prNames: [String] = [],
                                   imageB64: String = "") async -> Bool {
        guard let uid = authUser?.id else { return false }
        let clean = text.trimmingCharacters(in: .whitespacesAndNewlines)
        // A photo IS content — captionless photo posts pass with the
        // single-space stand-in below (the rules require text.size() >= 1).
        guard !clean.isEmpty || !imageB64.isEmpty else { return false }
        // The publish-time leg of the 1.2 filter — auto-share recaps are
        // template text and sail through; typed text (including the workout
        // name, which renders as a pill on every client) gets checked.
        guard !ContentModeration.containsBlockedTerm(clean),
              !ContentModeration.containsBlockedTerm(workoutName) else {
            showToast(ContentModeration.refusalMessage)
            return false
        }
        let post = FeedPost(
            id: UUID().uuidString,
            authorUid: uid,
            authorName: feedAuthorName,
            // Honest mirror: the rules re-check this against users/{uid}.verified.
            verified: isVerifiedUser,
            text: String((clean.isEmpty ? " " : clean).prefix(1000)),
            workoutName: String(workoutName.trimmingCharacters(in: .whitespacesAndNewlines).prefix(80)),
            repostOfId: repostOfId,
            repostOfAuthor: String(repostOfAuthor.prefix(60)),
            durationMinutes: durationMinutes,
            setCount: setCount,
            exerciseCount: exerciseCount,
            prNames: Array(prNames.prefix(3)),
            // Identity rides posts on the user's terms: accent + byline are
            // both derived from real facts and both switchable off in
            // Profile → Network identity.
            authorAccent: feedAuthorAccentId,
            authorHeadline: feedAuthorHeadline,
            imageB64: imageB64
        )
        guard await feedService.publish(post: post) else { return false }
        feedPosts.insert(post, at: 0)
        feedReactionCounts[post.id] = 0
        track("post_published")
        return true
    }

    /// The auto-share recap line: only facts the session actually produced
    /// (set count, exercise count, minutes trained, logged PRs) — no
    /// applause, no adjectives the data can't back.
    private func completedSessionPostText(
        exercises: [LoggedExercise],
        newPRs: [(name: String, weight: Double, previous: Double)],
        buddies: [String] = []
    ) -> String {
        let setCount = exercises.reduce(0) { $0 + ($1.repsPerSet?.count ?? 0) }
        let minutes = completedSessionMinutes ?? currentWorkout.durationMinutes
        var facts: [String] = []
        if setCount > 0 { facts.append("\(setCount) set\(setCount == 1 ? "" : "s")") }
        if !exercises.isEmpty { facts.append("\(exercises.count) exercise\(exercises.count == 1 ? "" : "s")") }
        if minutes > 0 { facts.append("\(minutes) min") }
        var text = "Completed \(currentWorkout.name)"
        if !facts.isEmpty { text += " — " + facts.joined(separator: ", ") }
        text += "."
        if !buddies.isEmpty {
            text += " Trained with \(buddies.joined(separator: ", "))."
        }
        for pr in newPRs.prefix(3) {
            text += " New PR: \(pr.name) \(weightUnit.format(pr.weight))."
        }
        return text
    }

    /// Composer path: publish a win (optionally tagged with a workout name).
    func publishPost(text: String, workoutName: String = "") async {
        guard await publishToRealFeed(text: text, workoutName: workoutName) else {
            showToast("Post didn't publish — check your connection.")
            return
        }
        SoundEffects.play(.ding)
        showCelebration(title: "Post shared", detail: "Your win is live on the feed.", symbol: "bubble.left.and.exclamationmark.bubble.right.fill")
    }

    /// Capture-camera path: a photo post. The JPEG is already sized by the
    /// camera (720px, compressed under the 90k-char rules cap) — this just
    /// rides the same pipeline as every other post, moderation included.
    /// Photo posts allow an empty caption — a single space stands in when
    /// the user typed nothing, since `text` is required to be non-empty.
    func publishPhotoPost(caption: String, imageB64: String) async -> Bool {
        guard !imageB64.isEmpty, imageB64.count <= 90_000 else {
            showToast("That photo didn't compress small enough — try again.")
            return false
        }
        let published = await publishToRealFeed(text: caption, imageB64: imageB64)
        if published {
            SoundEffects.play(.ding)
            showCelebration(title: "Posted", detail: "Your photo is live on the feed.", symbol: "camera.fill")
        } else {
            showToast("Post didn't publish — check your connection.")
        }
        return published
    }

    // MARK: Direct chats (athlete ↔ athlete)
    //
    // The thread schema is pair-shaped, not role-shaped: coachUid/athleteUid
    // are just "participant A/B" slots. A DM claims the SAME deterministic
    // id from both ends by ordering the pair lexicographically, so two
    // people starting a chat with each other can never mint two threads.

    /// Opens (creating if needed) the direct thread with another user, and
    /// navigates to it. False when offline or the create was denied.
    @discardableResult
    func startDirectChat(with otherUid: String, name otherName: String) async -> Bool {
        guard let myUid = authUser?.id, myUid != otherUid else { return false }
        guard blockedAccounts[otherUid] == nil else {
            showToast("You've blocked this account — unblock them in Profile to message.")
            return false
        }
        let myName = feedAuthorName
        let firstIsMe = myUid < otherUid
        let threadId = await messagingService.ensureThread(
            coachUid: firstIsMe ? myUid : otherUid,
            athleteUid: firstIsMe ? otherUid : myUid,
            coachName: firstIsMe ? myName : otherName,
            athleteName: firstIsMe ? otherName : myName
        )
        guard let threadId else {
            showToast("Couldn't start the chat — check your connection.")
            return false
        }
        // Forced: this call just CHANGED the inbox on the server.
        await refreshThreads(force: true)
        // The inbox owns navigation — the pending id is the same door every
        // deep link already walks through (consumePendingThreadOpen).
        pendingThreadOpenID = threadId
        return true
    }

    /// Reaction types the picker offers, with their SF Symbols.
    // MARK: Trained Today (the last 24h as presence)
    //
    // Data-driven stories: every logged session already renders an honest
    // story-shaped card, so the presence row needs no uploads, no Storage,
    // no moderation — just a 24h lens over the loaded feed.

    struct TrainedTodayEntry: Identifiable, Hashable {
        var id: String          // author uid
        var name: String
        var verified: Bool
        /// This author's <24h posts, oldest first (the viewer's page order).
        var posts: [FeedPost]
        var hasUnseen: Bool
    }

    /// Bumped by markStorySeen so ring states refresh — UserDefaults isn't
    /// observable on its own.
    private(set) var storySeenTick = 0

    private var storySeenKey: String { "morphe.stories.seen.\(clientProfile.id.uuidString)" }

    /// Followed presence from the loaded feed: authors with sub-24h posts.
    /// Self sorts first (your bubble is the mirror), then unseen, then most
    /// recent activity.
    /// The union the presence surfaces read: the dedicated 24h query plus
    /// whatever feed pages are loaded, deduped by post id.
    private var presenceUnionPosts: [FeedPost] {
        var byId: [String: FeedPost] = [:]
        for post in feedPosts { byId[post.id] = post }
        for post in presencePosts { byId[post.id] = post }
        return Array(byId.values)
    }

    var trainedTodayEntries: [TrainedTodayEntry] {
        _ = storySeenTick
        let cutoff = Date.now.addingTimeInterval(-24 * 3600)
        let seen = Set(UserDefaults.standard.stringArray(forKey: storySeenKey) ?? [])
        let fresh = presenceUnionPosts.filter { $0.createdAt >= cutoff }
        guard !fresh.isEmpty else { return [] }
        let myUid = authUser?.id ?? ""
        return Dictionary(grouping: fresh, by: \.authorUid)
            .map { uid, posts in
                let ordered = posts.sorted { $0.createdAt < $1.createdAt }
                return TrainedTodayEntry(
                    id: uid,
                    name: ordered.last?.authorName ?? "Athlete",
                    verified: ordered.contains { $0.verified },
                    posts: ordered,
                    // Your own bubble is the mirror, not "new content you
                    // haven't watched" — it never wears the unseen ring.
                    hasUnseen: uid == myUid ? false : ordered.contains { !seen.contains($0.id) }
                )
            }
            .sorted { lhs, rhs in
                if (lhs.id == myUid) != (rhs.id == myUid) { return lhs.id == myUid }
                if lhs.hasUnseen != rhs.hasUnseen { return lhs.hasUnseen }
                return (lhs.posts.last?.createdAt ?? .distantPast)
                    > (rhs.posts.last?.createdAt ?? .distantPast)
            }
    }

    /// A story reply landed — the presence loop's engagement pulse, next
    /// to the share/referral/challenge counters in the metrics report.
    func noteStoryReplySent() {
        track("story_reply_sent")
    }

    /// A form clip left through the system share sheet — content capture
    /// as a growth signal, with zero backend surface.
    func noteFormClipCaptured() {
        track("form_clip_captured")
    }

    /// Consecutive days BOTH this account and `authorUid` posted a session,
    /// walking back from today (a live streak may not include today YET, so
    /// yesterday anchors too — same grace idea as the workout streak).
    /// Derived from the LOADED feed: the honest window we can actually see;
    /// mutual-follow status is unknowable client-side by rules design.
    func duoStreak(with authorUid: String) -> Int {
        guard let myUid = authUser?.id, authorUid != myUid else { return 0 }
        let calendar = Calendar.current
        // Window-derived (loaded pages + the 24h presence query): a long
        // streak whose posts sit past the loaded window UNDERCOUNTS —
        // never overclaims. Same honesty stance as the chat streak.
        let pool = presenceUnionPosts
        func postDays(_ uid: String) -> Set<Date> {
            Set(pool.filter { $0.authorUid == uid }
                .map { calendar.startOfDay(for: $0.createdAt) })
        }
        let both = postDays(myUid).intersection(postDays(authorUid))
        guard !both.isEmpty else { return 0 }

        var day = calendar.startOfDay(for: .now)
        if !both.contains(day) {
            guard let yesterday = calendar.date(byAdding: .day, value: -1, to: day),
                  both.contains(yesterday) else { return 0 }
            day = yesterday
        }
        var streak = 0
        while both.contains(day) {
            streak += 1
            guard let previous = calendar.date(byAdding: .day, value: -1, to: day) else { break }
            day = previous
        }
        return streak
    }

    /// Chat streak: consecutive days BOTH parties sent a message, walking
    /// back from today with the same yesterday-grace as duoStreak (a live
    /// streak may not include today yet). Computed from the loaded window
    /// (the listener delivers the newest 300 messages) — a very long,
    /// very chatty streak can UNDERCOUNT past the window, never overclaim.
    /// Static + injectable dates for tests.
    static func messageStreak(
        messages: [ChatMessage], uidA: String, uidB: String,
        today: Date = .now, calendar: Calendar = .current
    ) -> Int {
        guard uidA != uidB else { return 0 }
        func days(_ uid: String) -> Set<Date> {
            Set(messages.filter { $0.senderUid == uid }
                .map { calendar.startOfDay(for: $0.sentAt) })
        }
        let both = days(uidA).intersection(days(uidB))
        guard !both.isEmpty else { return 0 }

        var day = calendar.startOfDay(for: today)
        if !both.contains(day) {
            guard let yesterday = calendar.date(byAdding: .day, value: -1, to: day),
                  both.contains(yesterday) else { return 0 }
            day = yesterday
        }
        var streak = 0
        while both.contains(day) {
            streak += 1
            guard let previous = calendar.date(byAdding: .day, value: -1, to: day) else { break }
            day = previous
        }
        return streak
    }

    // MARK: Derived insights (AI-6) — read from real logs, never templates
    // when data exists. The static profile tips remain the honest zero-data
    // fallback.

    /// The Progress-flavored Home insight: this week's real numbers.
    var derivedProgressInsight: AIInsight {
        let logs = currentAthleteWorkoutLogs
        guard !logs.isEmpty else { return clientProfile.aiProgressInsight }
        let calendar = Calendar.current
        let thisWeek = logs.filter {
            calendar.isDate($0.completedAt, equalTo: .now, toGranularity: .weekOfYear)
        }.count
        let streak = clientProfile.level.streak
        var summary = thisWeek == 0
            ? "Nothing logged yet this week — your history is \(logs.count) session\(logs.count == 1 ? "" : "s") deep, so the next one just continues the story."
            : "\(thisWeek) session\(thisWeek == 1 ? "" : "s") logged this week."
        if streak >= 2 { summary += " Streak: \(streak) days." }
        return AIInsight(
            title: "This week, from your logs",
            summary: summary,
            risk: .low,
            recommendation: thisWeek == 0
                ? "One session today restarts the week's count."
                : "Repeatable beats perfect — same again next session.",
            suggestedAction: "Review your progress"
        )
    }

    /// The Today-flavored insight: the actual planned session + the real
    /// check-in when one exists; the rotating generic tip only before data.
    var derivedTodayInsight: AIInsight {
        guard didCompleteQuickCheckIn else { return clientProfile.aiTodayInsight }
        return AIInsight(
            title: "Today, from your check-in",
            summary: "Up: \(currentWorkout.name). Readiness \(recovery.score) from what you reported — \(recovery.score >= 70 ? "green light for the full plan" : recovery.score >= 40 ? "train, but leave a rep in the tank" : "a lighter day protects the streak better than a heroic one").",
            risk: recovery.score >= 70 ? .low : recovery.score >= 40 ? .medium : .high,
            recommendation: "The plan already reflects your check-in.",
            suggestedAction: "Start today's workout"
        )
    }

    /// Seen is per-profile and capped — a lens state, not data.
    func markStorySeen(_ post: FeedPost) {
        var seen = UserDefaults.standard.stringArray(forKey: storySeenKey) ?? []
        guard !seen.contains(post.id) else { return }
        seen.append(post.id)
        if seen.count > 400 { seen.removeFirst(seen.count - 400) }
        UserDefaults.standard.set(seen, forKey: storySeenKey)
        storySeenTick += 1
    }

    static let reactionTypes: [(type: String, symbol: String, label: String)] = [
        ("heart", "heart.fill", "Heart"),
        ("fire", "flame.fill", "Fire"),
        ("power", "bolt.fill", "Power"),
        ("clap", "hands.clap.fill", "Clap")
    ]

    /// Toggles this account's single reaction on a post (default heart). The
    /// count updates optimistically; the server doc is one-per-uid so nobody
    /// can inflate a post beyond 1 either way.
    func toggleReaction(_ post: FeedPost) {
        react(to: post, type: myReactedPostIds.contains(post.id) ? nil : "heart")
    }

    /// Sets this account's reaction to `type`, or removes it when nil.
    /// Changing type on an existing reaction rewrites the SAME one-per-uid
    /// doc — the count never moves, only the flavor.
    func react(to post: FeedPost, type: String?) {
        guard let uid = authUser?.id else { return }
        let wasOn = myReactedPostIds.contains(post.id)
        if let type {
            if !wasOn {
                myReactedPostIds.insert(post.id)
                feedReactionCounts[post.id] = (feedReactionCounts[post.id] ?? 0) + 1
            }
            myReactionTypes[post.id] = type
            feedService.react(postId: post.id, uid: uid, type: type)
            Haptics.impact(.light)
        } else {
            guard wasOn else { return }
            myReactedPostIds.remove(post.id)
            myReactionTypes.removeValue(forKey: post.id)
            feedReactionCounts[post.id] = max(0, (feedReactionCounts[post.id] ?? 0) - 1)
            feedService.react(postId: post.id, uid: uid, type: nil)
        }
    }

    /// Toggles a private bookmark (users/{uid}/savedPosts/{postId}).
    func toggleSaved(_ post: FeedPost) {
        guard let uid = authUser?.id else { return }
        let on = !savedPostIds.contains(post.id)
        if on {
            savedPostIds.insert(post.id)
        } else {
            savedPostIds.remove(post.id)
        }
        feedService.savePost(uid: uid, postId: post.id, on: on)
        showToast(on ? "Post saved." : "Removed from saved.")
    }

    /// Reposts with the reposter's own commentary. Reposting a repost points
    /// at the ORIGINAL post, so attribution never chains through middlemen.
    func repost(_ post: FeedPost, commentary: String) async {
        let originalId = post.isRepost ? post.repostOfId : post.id
        let originalAuthor = post.isRepost ? post.repostOfAuthor : post.authorName
        let clean = commentary.trimmingCharacters(in: .whitespacesAndNewlines)
        // The rules require 1..1000 chars of text — an empty commentary
        // becomes an honest default rather than a rejected write.
        let text = clean.isEmpty ? "Sharing \(originalAuthor)'s win." : clean
        // A photo post's repost carries the photo — without it, the repost
        // rendered as commentary over nothing (launch audit P2-14).
        guard await publishToRealFeed(text: text, repostOfId: originalId,
                                      repostOfAuthor: originalAuthor,
                                      imageB64: post.imageB64) else {
            showToast("Repost didn't publish — check your connection.")
            return
        }
        SoundEffects.play(.ding)
        showToast("Reposted to the feed.")
    }

    /// Deletes the user's OWN post (the rules enforce author-only server-side).
    func deleteMyPost(_ post: FeedPost) {
        guard let uid = authUser?.id, post.authorUid == uid else { return }
        feedPosts.removeAll { $0.id == post.id }
        feedReactionCounts[post.id] = nil
        feedService.delete(postId: post.id)
        showToast("Post deleted.")
    }

    // MARK: - Appointments (real personal schedule)

    /// Upcoming = still scheduled and not fully in the past. Cancelled and
    /// completed entries drop off the list rather than cluttering it.
    var upcomingAppointments: [Appointment] {
        appointments.filter { $0.isScheduled && $0.endDate >= .now }
    }

    /// One row of the appointment editor's "With" picker: every person this
    /// account actually knows — QR connections, workout partners, and (for
    /// a coach) the roster. Free-text stays possible; the picker just links
    /// the appointment to a real profile when one exists.
    struct AppointmentPersonChoice: Identifiable, Hashable {
        var id: String
        var name: String
        var detail: String
    }

    var appointmentPeopleChoices: [AppointmentPersonChoice] {
        var choices: [AppointmentPersonChoice] = []
        var seen = Set<String>()
        func add(id: String, name: String, detail: String) {
            let clean = name.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !clean.isEmpty, seen.insert(id).inserted else { return }
            choices.append(AppointmentPersonChoice(id: id, name: clean, detail: detail))
        }
        for connection in scannedConnections {
            add(id: connection.id, name: connection.name,
                detail: connection.handle.isEmpty ? connection.role.capitalized : "@\(connection.handle)")
        }
        for partner in workoutPartners {
            add(id: partner.linkedAthleteID?.uuidString ?? "partner-\(partner.id)",
                name: partner.name, detail: "Training partner")
        }
        if selectedRole == .coach {
            for client in coachClients {
                add(id: client.id.uuidString, name: client.name, detail: "Client")
            }
        }
        return choices
    }

    /// Adds a personal appointment and mirrors it to the cloud (one doc).
    /// Works signed-out too — the entry just stays local until sign-in.
    @discardableResult
    func addAppointment(
        title: String,
        date: Date,
        durationMinutes: Int,
        kind: AppointmentKind,
        withName: String,
        withUid: String? = nil,
        notes: String
    ) -> Appointment? {
        let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanTitle.isEmpty else {
            showToast("Give the appointment a title first.")
            return nil
        }
        let appointment = Appointment(
            title: cleanTitle,
            notes: notes.trimmingCharacters(in: .whitespacesAndNewlines),
            date: date,
            durationMinutes: max(durationMinutes, 5),
            kind: kind,
            withName: withName.trimmingCharacters(in: .whitespacesAndNewlines),
            withUid: withUid,
            createdByRole: selectedRole.rawValue
        )
        appointments.append(appointment)
        appointments.sort { $0.date < $1.date }
        if let uid = authUser?.id {
            appointmentService.push(appointment, uid: uid)
        }
        scheduleAppointmentReminder(appointment)
        showToast("\(cleanTitle) scheduled.")
        return appointment
    }

    /// Moves an appointment between scheduled/completed/cancelled (the
    /// `Appointment.status*` constants) and syncs the change.
    func updateAppointmentStatus(_ appointment: Appointment, to status: String) {
        guard let index = appointments.firstIndex(where: { $0.id == appointment.id }) else { return }
        appointments[index].status = status
        if let uid = authUser?.id {
            appointmentService.push(appointments[index], uid: uid)
        }
        // A cancelled or completed appointment must not still ring an hour out.
        if status != Appointment.statusScheduled {
            cancelAppointmentReminder(id: appointment.id)
        }
    }

    /// Removes an appointment locally, in the cloud, and from the reminder queue.
    func deleteAppointment(_ appointment: Appointment) {
        guard let index = appointments.firstIndex(where: { $0.id == appointment.id }) else { return }
        appointments.remove(at: index)
        if let uid = authUser?.id {
            appointmentService.delete(id: appointment.id, uid: uid)
        }
        cancelAppointmentReminder(id: appointment.id)
    }

    /// Pulls this account's appointments (launch + sign-in). A nil fetch
    /// (offline, signed out) keeps whatever is already local.
    func refreshAppointments() async {
        guard let uid = authUser?.id else { return }
        if let fetched = await appointmentService.fetchAll(uid: uid) {
            appointments = fetched.sorted { $0.date < $1.date }
        }
    }

    // Local reminders are best-effort: authorization is requested on the
    // first add, a denial is handled silently, and the in-app list stays the
    // source of truth either way. Tests/previews (NoOp service) never touch
    // the system notification center.
    private var appointmentRemindersEnabled: Bool {
        !(appointmentService is NoOpAppointmentService)
    }

    /// Schedules a local notification 60 minutes before the appointment
    /// (identifier = appointment id, so cancel/delete can revoke exactly it).
    /// The ONE permission ask (audit E1): it used to live only inside
    /// appointment scheduling, so a solo user who never booked one was
    /// never prompted — and every retention notification (streak-risk,
    /// comeback, recap, board) silently no-oped for exactly the users
    /// they exist to keep. Fired at the first workout log: the moment
    /// the user has something worth being reminded about.
    func requestNotificationPermissionIfNeeded() {
        // Unit tests run hosted inside Morphe.app and log workouts — without
        // this guard every suite run queues a REAL permission alert against
        // the simulator, which then ambushes the next manual QA session.
        guard NSClassFromString("XCTestCase") == nil else { return }
        let center = UNUserNotificationCenter.current()
        center.getNotificationSettings { settings in
            guard settings.authorizationStatus == .notDetermined else { return }
            center.requestAuthorization(options: [.alert, .sound]) { granted, _ in
                guard granted else { return }
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    // Newly granted: arm everything that was waiting.
                    self.refreshStreakRiskReminder()
                    self.refreshWeeklyRecapReminder()
                    self.refreshDailyTrainingReminder()
                }
            }
        }
    }

    /// The category-table-stakes nudge that didn't exist (audit E2): ONE
    /// pending "next session" reminder, re-aimed on every log and launch —
    /// today 5pm if nothing's logged yet (and it's early enough),
    /// otherwise tomorrow 5pm. Never repeats blindly, so a logged day
    /// never gets a nag. Off switch rides the existing reminder prefs.
    func refreshDailyTrainingReminder() {
        let id = "morphe.daily.training"
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [id])
        guard remindersEnabled, hasCompletedOnboarding, !currentWorkout.name.isEmpty else { return }
        center.getNotificationSettings { [weak self] settings in
            guard settings.authorizationStatus == .authorized
                    || settings.authorizationStatus == .provisional else { return }
            Task { @MainActor [weak self] in
                guard let self else { return }
                let calendar = Calendar.current
                var target = calendar.date(
                    bySettingHour: 17, minute: 0, second: 0, of: .now) ?? .now
                if isWorkoutLoggedToday || target <= .now {
                    target = calendar.date(byAdding: .day, value: 1, to: target) ?? target
                }
                // Planned rest days never get a training nag — advance to
                // the next picked day (bounded walk; empty set = every day).
                var hops = 0
                while plannedRestDay(on: target, calendar: calendar), hops < 7 {
                    target = calendar.date(byAdding: .day, value: 1, to: target) ?? target
                    hops += 1
                }
                let content = UNMutableNotificationContent()
                content.title = "Today's session: \(self.currentWorkout.name)"
                content.body = "One tap to start — the streak takes care of itself."
                content.sound = .default
                let trigger = UNCalendarNotificationTrigger(
                    dateMatching: calendar.dateComponents(
                        [.year, .month, .day, .hour, .minute], from: target),
                    repeats: false)
                center.add(UNNotificationRequest(identifier: id, content: content, trigger: trigger))
            }
        }
    }

    private func scheduleAppointmentReminder(_ appointment: Appointment) {
        guard appointmentRemindersEnabled else { return }
        let fireDate = appointment.date.addingTimeInterval(-60 * 60)
        guard fireDate > .now else { return }   // less than an hour out: no ghost ring

        let center = UNUserNotificationCenter.current()
        // Safe to call every time — after the first prompt it just reports
        // the existing decision.
        center.requestAuthorization(options: [.alert, .sound]) { granted, _ in
            guard granted else { return }   // denied: silent, the list is the truth
            let content = UNMutableNotificationContent()
            content.title = appointment.title
            content.body = appointment.withName.isEmpty
                ? "In 1 hour — \(appointment.kind.title.lowercased())."
                : "In 1 hour with \(appointment.withName)."
            content.sound = .default
            let trigger = UNCalendarNotificationTrigger(
                dateMatching: Calendar.current.dateComponents(
                    [.year, .month, .day, .hour, .minute], from: fireDate),
                repeats: false
            )
            center.add(UNNotificationRequest(identifier: appointment.id, content: content, trigger: trigger))
        }
    }

    private func cancelAppointmentReminder(id: String) {
        guard appointmentRemindersEnabled else { return }
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [id])
    }

    /// Shared app-group defaults the home/lock-screen widgets read. The
    /// payload is four primitives — streak, today's workout, week's sets,
    /// logged-today — refreshed at the same moments the streak reminder is.
    private static let widgetSuiteName = "group.com.morpheapp.Morphe"

    private func publishWidgetSnapshot() {
        guard let defaults = UserDefaults(suiteName: Self.widgetSuiteName) else { return }
        defaults.set(currentWorkoutStreak(from: currentAthleteWorkoutLogs), forKey: "widget.streak")
        defaults.set(currentWorkout.name, forKey: "widget.todayWorkout")
        defaults.set(weeklySetVolume(weeks: 1).last?.sets ?? 0, forKey: "widget.weekSets")
        defaults.set(isWorkoutLoggedToday, forKey: "widget.loggedToday")
        // The day this snapshot was true. The widget compares against ITS
        // render day, so "Logged today ✓" can't survive into tomorrow when
        // the app isn't opened.
        defaults.set(Self.dayKey(), forKey: "widget.day")
        WidgetCenter.shared.reloadAllTimelines()
    }

    // MARK: - First-party telemetry hooks
    //
    // Named milestone events, recorded fire-and-forget under the user's own
    // account. The event VOCABULARY is deliberately tiny and product-shaped
    // (activation, retention, growth loops) — never behavioral surveillance.

    private func track(_ name: String) {
        guard let uid = authUser?.id else { return }
        telemetryService.record(uid: uid, name: name, day: Self.dayKey())
    }

    /// One "day_active" per account per calendar day — the retention pulse
    /// D1/D7/D30 are computed from. Deduped locally per uid.
    func trackDayActiveIfNeeded() {
        guard let uid = authUser?.id else { return }
        let key = "morphe.telemetry.lastActiveDay.\(uid)"
        let today = Self.dayKey()
        guard UserDefaults.standard.string(forKey: key) != today else { return }
        UserDefaults.standard.set(today, forKey: key)
        track("day_active")
    }

    /// Which card left the app — each kind is its own telemetry event so
    /// the metrics report shows which emotional moments actually travel.
    enum ShareCardKind: String {
        case session = "share_card_shared"
        case pr = "pr_card_shared"
        case streak = "streak_card_shared"
        case recap = "recap_card_shared"
    }

    /// The share-card loop fired for real (the user completed the system
    /// share, not just opened the sheet).
    func noteShareCardShared(_ kind: ShareCardKind = .session) {
        track(kind.rawValue)
    }

    private static let streakRiskNotificationID = "morphe.streak.risk"
    private static let weeklyRecapNotificationID = "morphe.recap.week"
    private static let comebackNotificationID = "morphe.streak.comeback"

    // MARK: Comeback (the streak's honest ending)
    //
    // The streak system handled everything except dying. When a real run
    // (≥3 days) lapses, the app acknowledges it once — a no-guilt Today
    // card into Minimum Win, plus ONE gentle reminder two days later.
    // Never a nag: any log or a dismissal clears all of it.

    private var lastKnownStreakKey: String { "morphe.streak.lastKnown.\(clientProfile.id.uuidString)" }
    private var comebackPendingKey: String { "morphe.streak.comeback.\(clientProfile.id.uuidString)" }

    /// The size of the run that ended — non-nil drives the Today card.
    private(set) var comebackLapsedStreak: Int?

    /// Launch-time check: compares the last streak this profile SAW against
    /// the streak that exists now. A lapse records once and persists until
    /// the user logs or dismisses — a relaunch never re-mints it.
    func detectStreakLapse() {
        comebackLapsedStreak = UserDefaults.standard.object(forKey: comebackPendingKey) as? Int
        let current = currentWorkoutStreak(from: currentAthleteWorkoutLogs)
        if current > 0 {
            UserDefaults.standard.set(current, forKey: lastKnownStreakKey)
            clearComeback()
            return
        }
        let lastKnown = UserDefaults.standard.integer(forKey: lastKnownStreakKey)
        guard lastKnown >= 3 else { return }
        UserDefaults.standard.set(lastKnown, forKey: comebackPendingKey)
        UserDefaults.standard.removeObject(forKey: lastKnownStreakKey)
        comebackLapsedStreak = lastKnown
        scheduleComebackReminder(lapsed: lastKnown)
    }

    /// User saw the card and closed it — that's an answer, not a snooze.
    /// The pending state AND the reminder go together.
    func dismissComebackCard() {
        clearComeback()
    }

    private func clearComeback() {
        comebackLapsedStreak = nil
        UserDefaults.standard.removeObject(forKey: comebackPendingKey)
        // Same tests-never-touch-the-center gate as every other reminder.
        guard appointmentRemindersEnabled else { return }
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: [Self.comebackNotificationID])
    }

    /// One one-shot reminder, two days after the lapse at 6pm — same
    /// ambient gate as every reminder (never a cold permission prompt).
    private func scheduleComebackReminder(lapsed: Int) {
        guard appointmentRemindersEnabled else { return }
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [Self.comebackNotificationID])
        let calendar = Calendar.current
        guard let target = calendar.date(byAdding: .day, value: 2, to: .now),
              let fireDate = calendar.date(bySettingHour: 18, minute: 0, second: 0, of: target)
        else { return }
        center.getNotificationSettings { settings in
            guard settings.authorizationStatus == .authorized
                || settings.authorizationStatus == .provisional else { return }
            let content = UNMutableNotificationContent()
            content.title = "Start the next streak"
            content.body = "Your \(lapsed)-day run ended — one small session starts a new one."
            content.sound = .default
            let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: fireDate)
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            center.add(UNNotificationRequest(
                identifier: Self.comebackNotificationID, content: content, trigger: trigger))
        }
    }

    /// One-shot "week in review" for next Monday 9:05, re-derived on every
    /// log so the numbers are final by the time it fires. Honest by
    /// construction: scheduled ONLY when the ending week actually holds
    /// sessions — a week with nothing logged sends nothing. Same ambient
    /// gate as the other reminders (never a cold permission prompt).
    private func refreshWeeklyRecapReminder() {
        guard appointmentRemindersEnabled else { return }
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [Self.weeklyRecapNotificationID])

        // Same Monday anchor as the board (ISO weeks) — Calendar.current
        // would fire this on Sunday morning in a US locale.
        let calendar = Calendar.current
        let thisWeekStart = LeaderboardWeek.start()
        let nextWeekStart = thisWeekStart.addingTimeInterval(7 * 86_400)
        guard let recap = weeklyRecapData(weekStart: thisWeekStart, weekEnd: nextWeekStart),
              let fireDate = calendar.date(bySettingHour: 9, minute: 5, second: 0, of: nextWeekStart)
        else { return }

        let body = "\(recap.sessions) session\(recap.sessions == 1 ? "" : "s"), \(recap.sets) sets logged — your recap card is in Progress."
        center.getNotificationSettings { settings in
            guard settings.authorizationStatus == .authorized
                || settings.authorizationStatus == .provisional else { return }
            let content = UNMutableNotificationContent()
            content.title = "Your week in review"
            content.body = body
            content.sound = .default
            let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: fireDate)
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            center.add(UNNotificationRequest(
                identifier: Self.weeklyRecapNotificationID, content: content, trigger: trigger))
        }
    }

    /// Schedules (or clears) the one streak-at-risk reminder: 7pm on the LAST
    /// allowed rest day of the schedule-aware streak. Honest by construction —
    /// the deadline math is the same `allowedGap` the streak itself uses, so
    /// the reminder can only fire on a day the streak would truly end.
    /// Re-derived on every log/launch: training re-arms it for the next
    /// deadline; a lapsed or absent streak clears it.
    private func refreshStreakRiskReminder() {
        // Same gate as appointment reminders: tests/previews (NoOp services)
        // never touch the system notification center.
        guard appointmentRemindersEnabled else { return }
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [Self.streakRiskNotificationID])

        let logs = currentAthleteWorkoutLogs
        let streak = currentWorkoutStreak(from: logs)
        // A 1-day streak isn't a loss worth a push — nag only when there's
        // real momentum on the line.
        guard streak >= 2 else { return }

        let calendar = Calendar.current
        var activeDays = Set(logs.map { calendar.startOfDay(for: $0.completedAt) })
        for key in protectedDayKeys {
            if let day = Self.date(fromDayKey: key) {
                activeDays.insert(calendar.startOfDay(for: day))
            }
        }
        guard let latestDay = activeDays.max() else { return }

        // Mirror of currentWorkoutStreak's gap rule.
        let daysPerWeek = max(1, min(7, clientProfile.trainingDaysPerWeek))
        let allowedGap = max(1, 8 - daysPerWeek)
        guard let deadlineDay = calendar.date(byAdding: .day, value: allowedGap, to: latestDay),
              let fireDate = calendar.date(bySettingHour: 19, minute: 0, second: 0, of: deadlineDay),
              fireDate > .now   // deadline evening already passed: no ghost ring
        else { return }

        // Same polite gate as the board reminder: never a cold prompt at
        // launch — this arms itself once notifications were granted anywhere.
        center.getNotificationSettings { settings in
            guard settings.authorizationStatus == .authorized
                || settings.authorizationStatus == .provisional else { return }
            let content = UNMutableNotificationContent()
            content.title = "Your \(streak)-day streak ends tonight"
            content.body = "One session keeps it alive — even a short one counts."
            content.sound = .default
            let trigger = UNCalendarNotificationTrigger(
                dateMatching: Calendar.current.dateComponents(
                    [.year, .month, .day, .hour, .minute], from: fireDate),
                repeats: false
            )
            center.add(UNNotificationRequest(
                identifier: Self.streakRiskNotificationID, content: content, trigger: trigger))
        }
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
        SoundEffects.play(.ding)
        showCelebration(title: "Workout added", detail: "\(log.workoutTitle) -> \(athlete.name)", symbol: "plus.circle.fill")
        showToast("Coach workout log saved.")
    }

    // The "AI photo parse" pair is GONE (AI-1 in docs/READINESS-300.md):
    // it never parsed anything — it copied a template and stamped the log
    // "Morphe AI parsed a workout photo". Fabricated provenance violates
    // the house rule. Coach manual entry above is the honest path; a real
    // vision import can return when a real model reads real photos.

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
        // Legacy .aiPhotoParsed logs (pre-AI-1 demo data) just get the
        // approval stamp — no "Morphe AI + coach" provenance rewrite; the
        // fabricated-import pipeline is gone.

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

    /// Logs a PAST session after the fact: the user picks the workout, the
    /// day it happened, and what they actually did — the log lands on THAT
    /// date, so streak/PRs/score recompute from the truth instead of
    /// punishing a day they trained but didn't track. Honesty rails:
    /// back-dating caps at 14 days, never the future, and the note says it
    /// was logged after the fact.
    @discardableResult
    func logPastWorkout(
        template: WorkoutTemplate,
        on day: Date,
        durationMinutes: Int,
        entries: [(name: String, sets: Int, reps: Int, weight: Double, muscleGroup: String?)]
    ) -> Bool {
        let calendar = Calendar.current
        let dayStart = calendar.startOfDay(for: day)
        guard dayStart <= calendar.startOfDay(for: .now),
              let earliest = calendar.date(byAdding: .day, value: -14, to: calendar.startOfDay(for: .now)),
              dayStart >= earliest else {
            showToast("Old sessions can be logged up to 14 days back.")
            return false
        }
        let cleanEntries = entries.filter { $0.sets > 0 && $0.reps > 0 }
        guard !cleanEntries.isEmpty else {
            showToast("Add at least one exercise with sets and reps.")
            return false
        }

        // Noon on the chosen day: date-honest without inventing a time.
        let completedAt = calendar.date(byAdding: .hour, value: 12, to: dayStart) ?? dayStart
        let loggedExercises: [LoggedExercise] = cleanEntries.map { entry in
            let reps = Array(repeating: entry.reps, count: entry.sets)
            let weights = Array(repeating: max(0, entry.weight), count: entry.sets)
            return LoggedExercise(
                name: entry.name,
                sets: "\(entry.sets) sets",
                reps: reps.map(String.init).joined(separator: ", "),
                weight: entry.weight > 0 ? weightUnit.format(entry.weight) : "Bodyweight",
                note: "",
                rpe: nil,
                repsPerSet: reps,
                weightsPerSet: weights,
                rpePerSet: reps.map { _ in 0 },
                weightUnit: weightUnit.rawValue,
                muscleGroup: entry.muscleGroup
            )
        }

        appendWorkoutLog(
            WorkoutLog(
                athleteID: clientProfile.id,
                athleteName: clientProfile.name,
                workoutTemplateID: template.id,
                workoutTitle: template.name,
                sport: template.sport,
                completedAt: completedAt,
                durationMinutes: max(5, durationMinutes),
                exercises: loggedExercises,
                notes: "Logged after the fact on \(Self.workoutDateLabel(for: .now)).",
                source: .athleteManual,
                enteredByUserID: clientProfile.id,
                enteredByRole: .client,
                enteredByName: clientProfile.name,
                verificationStatus: .athleteSubmitted
            )
        )
        track("workout_logged")
        // The streak deadline and Monday recap just changed shape — re-arm
        // both, and hand widgets the new numbers. The board/challenge
        // mirrors re-derive from logs too: a back-dated session inside the
        // current ISO week must count there the moment it lands, not on
        // the next regular log. (Inspection find 2026-07-28.)
        publishCompetitionScores()
        refreshStreakRiskReminder()
        refreshWeeklyRecapReminder()
        detectStreakLapse()
        publishWidgetSnapshot()
        if calendar.isDateInToday(completedAt) {
            isWorkoutLoggedToday = true
        }
        Haptics.success()
        showToast("\(template.name) logged for \(Self.workoutDateLabel(for: completedAt)). Streak and stats recomputed.")
        return true
    }

    // MARK: Athlete-owned log corrections
    //
    // Your log, your call — a fat-fingered 500lb bench must not be
    // permanent, because every derived stat (PRs, e1RM, streak, score)
    // inherits the lie. Same recompute path as the coach edits; the
    // change mirrors to the cloud through the workoutLogs didSet.

    func updateOwnWorkoutLog(_ updatedLog: WorkoutLog) {
        guard updatedLog.athleteID == clientProfile.id else { return }
        guard let index = workoutLogs.firstIndex(where: { $0.id == updatedLog.id }) else { return }
        workoutLogs[index] = updatedLog
        workoutLogs.sort { $0.completedAt > $1.completedAt }
        refreshWorkoutLogDerivedState(for: updatedLog.athleteID)
        showToast("Workout updated — your stats recomputed.")
    }

    func deleteOwnWorkoutLog(_ log: WorkoutLog) {
        guard log.athleteID == clientProfile.id else { return }
        workoutLogs.removeAll { $0.id == log.id }
        refreshWorkoutLogDerivedState(for: log.athleteID)
        showToast("Workout deleted — your stats recomputed.")
    }

    func contactSupport() {
        showToast("Support contact opened.")
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
        // While the feed is dark there is NO surface where public praise
        // could land — publishing would write a real athlete's name into a
        // publicly readable doc with zero readers, then toast a lie
        // (audit 5, P0-1). The doors are flag-hidden too; this is the
        // backstop.
        guard FeatureFlags.socialFeedEnabled else {
            showToast("Public praise is off while the community feed is dark.")
            return
        }
        let cleanText = editedText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanText.isEmpty else { return }

        if isRealFeedActive {
            // The praise goes where people actually are — the REAL feed
            // (coach audit: it used to insert into the dead demo array and
            // toast "shared" over nothing).
            Task { await publishToRealFeed(text: "\(draft.title) — \(cleanText)") }
        } else {
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
        }

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

    /// REAL program delivery (Trainerize benchmark Tier 1): the FULL
    /// runnable workout rides the managed-client doc as an assignment and
    /// lands in the claimed athlete's Train tab as a scheduled session —
    /// not a note. Capped at the newest 20 so the JSON stays small.
    func assignWorkout(_ template: WorkoutTemplate, to client: ManagedClient,
                       on date: Date, scheduledLabel: String, silent: Bool = false) {
        guard let index = managedClients.firstIndex(where: { $0.id == client.id }) else {
            showToast("That client isn't on your roster anymore.")
            return
        }
        let assignment = WorkoutAssignment(
            workout: PartyWorkoutSnapshot(template: template),
            scheduledFor: date,
            scheduledLabel: scheduledLabel,
            coachName: coachProfile.name
        )
        managedClients[index].assignments.insert(assignment, at: 0)
        managedClients[index].assignments = Array(managedClients[index].assignments.prefix(20))
        // The notes line stays as the coach's own paper trail.
        let stamp = "Assigned \(template.name) for \(scheduledLabel)."
        managedClients[index].notes = managedClients[index].notes.isEmpty
            ? stamp
            : managedClients[index].notes + "\n" + stamp
        managedClientService.pushAssignments(
            code: client.id, assignments: managedClients[index].assignments)
        // Unclaimed docs still take a full push (keeps notes + count in
        // sync); claimed docs are assignments-only by rule.
        if !client.isClaimed {
            managedClientService.push(managedClients[index])
        }
        if !silent {
            // Claim state is a launch-time snapshot — word the pending case
            // as "once claimed" rather than asserting they haven't (P2-16).
            showToast("\(template.name) assigned to \(client.name) — it lands in their Train tab\(client.isClaimed ? "" : " once they claim their code").")
        }
        track("coach_assigned_workout")
    }

    /// Rule-based session generation for a client (benchmark Tier 3, the
    /// honest core of "AI builder" value): picks the best library match for
    /// the client's sport, skipping what they were just assigned. Rules,
    /// not AI — and labeled that way everywhere it surfaces.
    func generateSessionTemplate(for client: ManagedClient) -> WorkoutTemplate? {
        let recentNames = Set(client.assignments.prefix(3).map(\.workout.name))
        let sportMatches = workoutTemplates.filter { $0.sport == client.sport }
        let pool = sportMatches.isEmpty
            ? workoutTemplates.filter { $0.sport == .generalFitness }
            : sportMatches
        // Fresh-first: the first template they haven't just done; else the
        // first match; else nothing (an empty library can't generate).
        return pool.first { !recentNames.contains($0.name) } ?? pool.first
    }

    /// The default delivery slot every assign surface shares: next 17:00,
    /// rolled to tomorrow when today's has passed (speed audit S0-7).
    static func nextCoachSlot(from now: Date = .now) -> Date {
        let calendar = Calendar.current
        var slot = calendar.date(bySettingHour: 17, minute: 0, second: 0, of: now) ?? now
        if slot <= now { slot = calendar.date(byAdding: .day, value: 1, to: slot) ?? slot }
        return slot
    }

    /// One-tap generate-and-deliver from the client card: next 5pm slot,
    /// straight into their Train tab.
    func generateAndAssignSession(for client: ManagedClient) {
        guard let template = generateSessionTemplate(for: client) else {
            showToast("Your library has no workouts to pick from yet.")
            return
        }
        let slot = Self.nextCoachSlot()
        assignWorkout(template, to: client, on: slot,
                      scheduledLabel: slot.formatted(date: .abbreviated, time: .shortened),
                      silent: true)
        showToast("Picked \(template.name) for \(client.sport.rawValue) — delivered for \(slot.formatted(date: .abbreviated, time: .shortened)). Edit in Build if you want changes.")
    }

    /// Bulk assign — the same delivery, one sheet, many clients.
    func assignWorkout(_ template: WorkoutTemplate, to clients: [ManagedClient],
                       on date: Date, scheduledLabel: String) {
        for client in clients {
            assignWorkout(template, to: client, on: date, scheduledLabel: scheduledLabel)
        }
        if clients.count > 1 {
            showToast("\(template.name) assigned to \(clients.count) clients.")
        }
    }

    // MARK: Athlete side — coach-assigned programs

    /// Assignments across every claimed coach link, soonest first.
    private(set) var coachAssignments: [WorkoutAssignment] = []
    private var lastAssignmentsFetchAt: Date?

    /// Pulls the managed-client docs this athlete claimed (hourly gate —
    /// assignments change at coaching cadence, not feed cadence).
    func refreshCoachAssignments(force: Bool = false) async {
        guard let uid = authUser?.id, selectedRole == .client,
              !linkedCoachUid.isEmpty else { return }
        if !force, let last = lastAssignmentsFetchAt,
           Date.now.timeIntervalSince(last) < 3600 { return }
        guard let docs = await managedClientService.fetchClaimed(athleteUid: uid) else { return }
        lastAssignmentsFetchAt = .now
        coachAssignments = docs.flatMap(\.assignments)
            .sorted { $0.scheduledFor < $1.scheduledFor }
    }

    /// Done = a REAL log with the assignment's name on/after its scheduled
    /// day — completion is derived from what actually happened, never a
    /// checkbox the athlete (or coach) has to remember.
    func isAssignmentDone(_ assignment: WorkoutAssignment) -> Bool {
        let dayStart = Calendar.current.startOfDay(for: assignment.scheduledFor)
        return currentAthleteWorkoutLogs.contains {
            $0.workoutTitle == assignment.workout.name && $0.completedAt >= dayStart
        }
    }

    /// The assignment Today's hero should lead with: due today or overdue,
    /// not yet done (speed audit S0-2) — the coached athlete's one-tap
    /// Start must start the COACH'S session, not the generic plan.
    var dueCoachAssignment: WorkoutAssignment? {
        let endOfToday = Calendar.current.date(
            bySettingHour: 23, minute: 59, second: 59, of: .now) ?? .now
        return pendingCoachAssignments.first { $0.scheduledFor <= endOfToday }
    }

    /// What the Train tab shows: not-yet-done assignments from the last 14
    /// days plus everything upcoming — stale ones age out instead of
    /// nagging forever.
    var pendingCoachAssignments: [WorkoutAssignment] {
        let cutoff = Calendar.current.date(byAdding: .day, value: -14, to: .now) ?? .now
        // One pass over the logs builds the done-lookup (speed audit S1-6) —
        // the old shape re-scanned history per assignment per body eval.
        let calendar = Calendar.current
        let logKeys = Set(currentAthleteWorkoutLogs.map {
            "\($0.workoutTitle)|\(calendar.startOfDay(for: $0.completedAt).timeIntervalSince1970)"
        })
        let logsByTitle = Dictionary(grouping: currentAthleteWorkoutLogs, by: \.workoutTitle)
        _ = logKeys
        return coachAssignments.filter { assignment in
            guard assignment.scheduledFor >= cutoff else { return false }
            let dayStart = calendar.startOfDay(for: assignment.scheduledFor)
            let done = (logsByTitle[assignment.workout.name] ?? []).contains {
                $0.completedAt >= dayStart
            }
            return !done
        }
    }

    /// One tap from the assignment row into a live session running the
    /// coach's exact workout.
    func startAssignedWorkout(_ assignment: WorkoutAssignment) {
        let template = assignment.workout.makeTemplate(
            type: "Coach Assignment",
            notes: assignment.coachName.isEmpty
                ? "Assigned by your coach."
                : "Assigned by \(assignment.coachName)."
        )
        // Reuse the already-imported copy — currentWorkoutID must point at
        // a template that's actually in the list.
        if let existing = workoutTemplates.first(where: {
            $0.name == template.name && $0.type == "Coach Assignment"
        }) {
            beginLiveWorkout(existing)
        } else {
            workoutTemplates.append(template)
            beginLiveWorkout(template)
        }
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

    /// Quick Add → the REAL add-client flow (replaces the old fake-lead
    /// insert): lands on Build and asks the roster to present
    /// AddManagedClientSheet via `requestAddClientSheet`.
    func openAddClient() {
        selectedCoachTab = .programs
        requestAddClientSheet = true
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
        selectedCoachTab = .programs
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
        setCurrentWorkout(template)
    }

    private func setCurrentWorkout(_ template: WorkoutTemplate) {
        currentWorkoutID = template.id
        isWorkoutSessionActive = false
        hasStartedWorkoutFlow = false
        hasCompletedWorkoutFlow = false
        activeWorkoutExerciseIndex = 0
        completedWorkoutSets = [:]
        // Switching workouts abandons the old session's tracking — clear it so
        // stale per-exercise counts can't leak into the new template (slot ids
        // are shared library ids across templates) or block a swap.
        trackedSetReps = [:]
        trackedSetWeights = [:]
        trackedSetRPE = [:]
        trackedSetLabels = [:]
        trackedSetWarmups = [:]
        supersetPartners = [:]
        sessionUserNote = ""
    }

    private func updateCurrentWorkout(_ update: (inout WorkoutTemplate) -> Void) {
        guard let index = workoutTemplates.firstIndex(where: { $0.id == currentWorkoutID }) else { return }
        update(&workoutTemplates[index])
    }

    private func markTaskCompleted(named title: String) {
        // Grants the task's XP too — auto-completing used to flip the box
        // while paying nothing, so the labels advertised XP that the honest
        // path (actually training) never received.
        guard let index = todayTasks.firstIndex(where: { $0.title == title }),
              !todayTasks[index].isCompleted else { return }
        todayTasks[index].isCompleted = true
        updateXP(for: todayTasks[index].xp, add: true)
    }

    /// XP needed to clear a level, on a decade curve: levels 1–10 take
    /// 100 XP each, 11–20 take 200, 21–30 take 300, and so on.
    static func xpTarget(forLevel level: Int) -> Int {
        ((max(level, 1) - 1) / 10 + 1) * 100
    }

    /// The numeric level parsed from the level title ("Level 12" → 12).
    var currentLevelNumber: Int {
        levelNumber(from: clientProfile.level.currentTitle) ?? 1
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
                clientProfile.level.targetXP = Self.xpTarget(forLevel: nextLevel)
                // Name what this level actually unlocked — a level that
                // opens something lands harder than a bare number.
                let unlockedNames = Self.paletteUnlockLevels
                    .filter { $0.value == nextLevel }
                    .keys.map(\.rawValue).sorted()
                let levelDetail = unlockedNames.isEmpty
                    ? "Keep stacking the work."
                    : "\(unlockedNames.joined(separator: " + ")) accent unlocked — it's in Profile."
                showCelebration(title: "Level \(nextLevel)", detail: levelDetail, symbol: "arrow.up.circle.fill")
            }
            Haptics.success()
        } else {
            // Demote through level boundaries so un-checking refunds exactly
            // what was earned — the old clamp-at-zero let a level-up survive
            // the refund (free levels via boundary toggling).
            var remaining = amount
            while remaining > clientProfile.level.currentXP,
                  levelNumber(from: clientProfile.level.currentTitle) ?? 1 > 1 {
                let previousLevel = (levelNumber(from: clientProfile.level.currentTitle) ?? 2) - 1
                remaining -= clientProfile.level.currentXP
                clientProfile.level.currentTitle = "Level \(previousLevel)"
                clientProfile.level.nextTitle = "Level \(previousLevel + 1)"
                clientProfile.level.targetXP = Self.xpTarget(forLevel: previousLevel)
                clientProfile.level.currentXP = clientProfile.level.targetXP
            }
            clientProfile.level.currentXP = max(clientProfile.level.currentXP - remaining, 0)
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
        // A user-written bio survives sport changes; only the generated
        // fallback re-derives.
        profileShowcase.bio = profileCustomBio.isEmpty
            ? profileBio(for: sport, trainingStyles: clientProfile.selectedTrainingStyles, goals: clientProfile.selectedGoals)
            : profileCustomBio
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

        // Asking about goals/targets gets the user's OWN stored targets back,
        // on any tab — real data outranks tab-contextual generic advice.
        if lowercasedPrompt.contains("goal") || lowercasedPrompt.contains("target") {
            let physical = clientProfile.physicalGoalTarget.trimmingCharacters(in: .whitespacesAndNewlines)
            let weight = clientProfile.weightGoalTarget.trimmingCharacters(in: .whitespacesAndNewlines)
            let deadline = clientProfile.goalDeadline.trimmingCharacters(in: .whitespacesAndNewlines)
            let parts = [
                physical.isEmpty ? nil : "Physical target: \(physical)",
                weight.isEmpty ? nil : "Weight goal: \(weight)",
                deadline.isEmpty ? nil : "Deadline: \(deadline)"
            ].compactMap { $0 }
            if parts.isEmpty {
                return "You haven't set your goal targets yet. Add a physical target, weight goal, and deadline in Profile and I'll answer with the real numbers."
            }
            return "Here's what you're aiming at — \(parts.joined(separator: " / ")). Every logged session counts toward those."
        }

        // "What's next" reads the REAL queue — question phrasing lands here
        // (the action layer's question guard routes it), so the answer layer
        // owns it. On any tab: session truth outranks tab context.
        if lowercasedPrompt.contains("next"),
           lowercasedPrompt.contains("exercise") || lowercasedPrompt.contains("what's next")
            || lowercasedPrompt.contains("whats next") || lowercasedPrompt.contains("up next") {
            guard isWorkoutSessionActive else {
                return "No session is live. Up today: \(currentWorkout.name) — say \"start my workout\" and I'll open it."
            }
            let queue = currentWorkout.exercises
            let nextIndex = activeWorkoutExerciseIndex + 1
            let current = activeWorkoutExercise?.name ?? "your current movement"
            if queue.indices.contains(nextIndex) {
                return "You're on \(current). Up next: \(queue[nextIndex].name)."
            }
            return "You're on \(current) — it's the last one. Finish it and the session's done."
        }

        switch selectedClientTab {
        case .discover:
            if lowercasedPrompt.contains("type") || lowercasedPrompt.contains("goal") || lowercasedPrompt.contains("which") {
                return "Match the training type to the goal: strength or hypertrophy to build, HIIT or cardio to condition, mobility or recovery to feel better tomorrow. Filter by your level and the time you actually have, then start the one that fits."
            }
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
                // The narrative is gated on the actual streak — "moving in
                // the right direction" was claimed unconditionally before,
                // including while the score was falling.
                let streak = clientProfile.level.streak
                let trendLine = streak >= 2
                    ? "the trend is holding because your \(streak)-day streak is doing the work"
                    : "the fastest way to move it is simply logging the next session"
                return "Your current Morphe score is \(clientProfile.health.score), and \(trendLine). Score grows with sessions this week and your streak — nothing else feeds it."
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

        // ACCURACY over vibes: the old last resort was generic coach-tone
        // filler that pretended to answer anything. An honest assistant
        // says what it doesn't know and what it CAN do instead.
        return "I don't have a real answer for that yet — I'm a training assistant, not a general chatbot. What I can do: start your workout (today's or by name), log sets (\"log 3x10 at 135\"), tell you what's next, flip Minimum Win on, switch lb/kg, and open any part of the app. Ask about your goals, readiness, or score and I'll answer from your real data."
    }

    /// New chat (AI sheet toolbar): back to the seeded greeting. The old
    /// transcript isn't history worth keeping — it's a rule-based session.
    func resetAIAgentConversation() {
        if selectedRole == .coach {
            coachAIAgentConversation = [coachAIAgentConversation.first].compactMap { $0 }
        } else {
            athleteAIAgentConversation = [athleteAIAgentConversation.first].compactMap { $0 }
        }
        Haptics.impact(.light)
    }

    /// Coach action layer (AI-7): what it can actually DO. Everything here
    /// either navigates or answers from real store data — no drafting
    /// theater. Returns nil for conversational asks.
    private func coachAssistantActionReply(for text: String) -> String? {
        let lower = text.lowercased()
        func has(_ words: String...) -> Bool { words.contains { lower.contains($0) } }

        if has("what can you do", "help me use", "commands") || lower == "help" {
            return "I can open any workspace tab (\"open athletes\"), tell you who needs attention today — derived from your athletes' real logs — and answer coaching questions. I don't draft messages yet, and I won't pretend to."
        }

        // Real data, not vibes: quiet = no logged session this week. The
        // REAL roster is managedClients — coachClients is the demo array
        // and stays empty for a launched coach (coach audit).
        if has("who needs attention", "needs attention", "who's behind", "whos behind", "who is behind") {
            let roster = visibleManagedClients
            guard !roster.isEmpty else {
                return "No athletes on your roster yet — add one from Build's roster tools and I'll track who goes quiet."
            }
            let calendar = Calendar.current
            let quiet = roster.filter { client in
                !client.logs.contains {
                    calendar.isDate($0.completedAt, equalTo: .now, toGranularity: .weekOfYear)
                }
            }.map(\.name)
            if quiet.isEmpty {
                return "All \(roster.count) athletes have a logged session this week. Nobody's quiet — good week."
            }
            return "\(quiet.prefix(4).joined(separator: ", ")) \(quiet.count == 1 ? "hasn't" : "haven't") logged a session this week — start there."
        }

        if has("open athletes", "show athletes", "my athletes", "my roster", "open roster") {
            selectedCoachTab = .athletes; closeAIAgent(); return "Opened Athletes."
        }
        if has("open dashboard", "go to dashboard", "show dashboard") {
            selectedCoachTab = .dashboard; closeAIAgent(); return "Opened the dashboard."
        }
        if has("open programs", "go to programs", "show programs") {
            selectedCoachTab = .programs; closeAIAgent(); return "Opened Programs."
        }
        if has("open discover", "browse workouts", "find a workout") {
            selectedCoachTab = .discover; closeAIAgent(); return "Opened Discover."
        }
        if has("open train", "my training", "my own workout") {
            selectedCoachTab = .train; closeAIAgent(); return "Opened Train."
        }
        return nil
    }

    private func coachAgentReply(to prompt: String) -> String {
        let lowercasedPrompt = prompt.lowercased()
        let athleteName = selectedCoachClient?.name ?? coachClients.first?.name ?? "your athlete"
        let selectedProgram = selectedProgramTemplate?.name ?? "the current build"
        let selectedThreadName = selectedThread?.participant ?? athleteName

        switch selectedCoachTab {
        case .dashboard:
            // "priorit" catches both "priority" and "priorities" — the
            // advertised quick prompt used to miss its own branch.
            if lowercasedPrompt.contains("attention") || lowercasedPrompt.contains("priorit") {
                return "\(coachOverview.insight.summary) Start with the highest-friction athlete first, remove one blocker, and keep the next step easy to complete today."
            }
        case .athletes:
            if lowercasedPrompt.contains("summary") || lowercasedPrompt.contains("athlete") || lowercasedPrompt.contains("readiness") {
                let recoverySummary = selectedCoachClient?.recoveryScore.reason ?? "consistency is holding but readiness wants moderation"
                return "\(athleteName) is trending \(selectedCoachClient?.statusText.lowercased() ?? "steady"). Recovery is \(selectedCoachClient?.recoveryScore.score ?? 0) and the biggest context note is \(recoverySummary.lowercased())."
            }
        case .train:
            if lowercasedPrompt.contains("workout") || lowercasedPrompt.contains("start") || lowercasedPrompt.contains("session") {
                return "Your own training works exactly like an athlete's: start the staged workout, log sets in the console, and rate the session when you lock it in."
            }
        case .discover:
            if lowercasedPrompt.contains("workout") || lowercasedPrompt.contains("assign") || lowercasedPrompt.contains("find") || lowercasedPrompt.contains("build") {
                return "Search the catalog by name, goal, or training type, and bookmark anything worth assigning. For something exact, Build your own workout gives you full control over exercises, sets, and reps."
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
                actionLabel: "Show Logs",
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
                actionLabel: "Load Recovery",
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
                actionLabel: "Pain Check",
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
                        actionLabel: "Draft Prompt",
                        type: .partnerPrompt,
                        priority: 90
                    )
                case .generalCheckIn:
                    return CoachFollowUpRecommendation(
                        athleteID: athleteID,
                        athleteName: athleteName,
                        title: "Open the fastest line back in",
                        detail: "There are no logged sessions yet this week. \(bestRestartOutreach.insightLine)",
                        actionLabel: "Open Thread",
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
                    actionLabel: "Draft Prompt",
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
                actionLabel: "Open Thread",
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
                actionLabel: "Draft Prompt",
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
                actionLabel: "Buddy Logs",
                type: .reviewBuddy,
                priority: 78
            )
        }

        // Public praise only exists while the feed does — with the feed
        // dark the recommendation falls through to a direct message, the
        // honest channel that actually reaches the athlete (audit 5, P0-1).
        if latestLogIsRecent, FeatureFlags.socialFeedEnabled {
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

        // Fresh training day: the streak deadline moved — re-arm (or clear)
        // tonight's at-risk reminder against the new latest day, refresh
        // Monday's week-in-review numbers, hand the widgets the new
        // numbers, and refresh the coach's consented view. A log is also
        // THE comeback: remember the new streak and retire any lapse state.
        refreshStreakRiskReminder()
        refreshWeeklyRecapReminder()
        UserDefaults.standard.set(
            currentWorkoutStreak(from: currentAthleteWorkoutLogs),
            forKey: lastKnownStreakKey)
        clearComeback()
        publishWidgetSnapshot()
        pushCoachShareIfEnabled()

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
        // When the user tracked ANY exercise, untouched exercises were
        // skipped — logging them with their planned sets/reps would fabricate
        // work that never happened (and inflate exercise counts downstream).
        // A session finished with zero tracking keeps the planned fallback:
        // that's the deliberate "did it as written, skip the bookkeeping" path.
        let anyExerciseTracked = currentWorkout.exercises.contains { exercise in
            !trackedSetReps[exercise.id, default: []].isEmpty
                || completedWorkoutSets[exercise.id, default: 0] > 0
        }

        return currentWorkout.exercises.compactMap { exercise in
            let repsLogged = trackedSetReps[exercise.id, default: []]
            if anyExerciseTracked,
               repsLogged.isEmpty,
               completedWorkoutSets[exercise.id, default: 0] == 0 {
                return nil
            }
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
            // Superset/dropset sub-work rides in the note — each labeled set
            // spelled out so the history stays honest about what was done.
            let labelsLogged = trackedSetLabels[exercise.id, default: []]
            let labelNotes = labelsLogged.enumerated()
                .filter { !$0.element.isEmpty }
                .map { "Set \($0.offset + 1): \($0.element)" }
            let note = labelNotes.isEmpty
                ? exercise.formCue
                : labelNotes.joined(separator: " · ")
            return LoggedExercise(
                name: exercise.name,
                sets: setSummary,
                reps: repSummary,
                weight: weightSummary,
                note: note,
                rpe: ratedRPEs.isEmpty ? nil : ratedRPEs.map(String.init).joined(separator: ", "),
                // Keep the raw per-set arrays so strength-over-time can be
                // computed later; the strings above are display-only.
                repsPerSet: repsLogged.isEmpty ? nil : repsLogged,
                weightsPerSet: repsLogged.isEmpty ? nil : weightsLogged,
                rpePerSet: repsLogged.isEmpty ? nil : rpesLogged,
                weightUnit: repsLogged.isEmpty ? nil : weightUnit.rawValue,
                muscleGroup: exercise.muscleGroup.rawValue,
                warmupPerSet: repsLogged.isEmpty
                    ? nil
                    : trackedSetWarmups[exercise.id, default: []]
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
        consoleHistoryCache = [:]
        topWeightCache = [:]
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

    /// A neutral plan adjustment for a user who hasn't reported anything —
    /// the seeded default claimed "your recovery score is low and you
    /// reported soreness yesterday" for people who never reported a thing,
    /// which also steered every fresh user into the recovery recommendation.
    static let neutralPlanAdjustment = PlanAdjustment(
        title: "Your plan is set for today",
        body: "No adjustments yet — do a quick check-in or pick a Plan B if the day changes.",
        reasons: [],
        recommendation: "Start when you're ready and log how it goes."
    )

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
        let streak = currentWorkoutStreak(from: logs)
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

        let summary = workoutLogSummary(from: logs, scheduleAware: true)
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

        let summary = workoutLogSummary(from: logs, scheduleAware: false)
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

    private func workoutLogSummary(from logs: [WorkoutLog], scheduleAware: Bool) -> WorkoutLogSummary {
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
            currentStreakDays: scheduleAware
                ? currentWorkoutStreak(from: logs)
                : Self.consecutiveDayStreak(from: logs),
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
        persistWorkoutLibrary()
        SoundEffects.play(.ding)
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

    /// A different template at a similar difficulty for the same sport (or
    /// general fitness), rotated deterministically by day.
    private func nextVarietySuggestion(after current: WorkoutTemplate) -> WorkoutTemplate? {
        let candidates = workoutTemplates.filter {
            $0.id != current.id
                && $0.sessionType != .recoverySession
                && ($0.sport == clientProfile.sportMode || $0.sport == .generalFitness)
        }
        guard !candidates.isEmpty else { return nil }
        let similar = candidates.filter { $0.difficulty == current.difficulty }
        let pool = similar.isEmpty ? candidates : similar
        let dayIndex = Calendar.current.ordinality(of: .day, in: .year, for: .now) ?? 0
        return pool[dayIndex % pool.count]
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

        // Variety: if the user just finished the staged workout, the next
        // suggestion moves them forward instead of recommending the session
        // they just closed. (The old default branch recommended the current
        // workout itself, so "Today's Workout" never rotated on its own.)
        if let lastLog = workoutLogs.first(where: { $0.athleteID == clientProfile.id }),
           lastLog.workoutTemplateID == currentWorkout.id,
           let daysSince = Calendar.current.dateComponents([.day], from: lastLog.completedAt, to: .now).day,
           daysSince <= 2,
           let nextTemplate = nextVarietySuggestion(after: currentWorkout) {
            return recommendation(
                from: nextTemplate,
                sourceName: "Morphe",
                reasonTitle: "Time for the next step",
                reasonDetail: "You closed \(currentWorkout.name) recently — this keeps the week moving without repeating the same session.",
                contextChips: recommendationContextChips(
                    needsRecovery: false,
                    needsFallback: false,
                    prefersBuddy: false,
                    bestFor: suggestedUseCase(for: nextTemplate, context: nextTemplate.name),
                    behavioralChips: []
                ),
                confidenceNote: nil,
                bestFor: suggestedUseCase(for: nextTemplate, context: nextTemplate.name),
                prefersBuddy: false
            )
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

    /// Streak of on-schedule training days for the current athlete. Two rules
    /// make it honest: (1) the streak is SCHEDULE-aware — someone training the
    /// promised 3 days a week keeps their streak across rest days (the old
    /// consecutive-calendar-day rule showed a compliant user "Streak: 0" most
    /// mornings); (2) protected days (minimum wins) count as training days.
    private func currentWorkoutStreak(from logs: [WorkoutLog]) -> Int {
        let calendar = Calendar.current
        var activeDays = Set(logs.map { calendar.startOfDay(for: $0.completedAt) })
        for key in protectedDayKeys {
            if let day = Self.date(fromDayKey: key) {
                activeDays.insert(calendar.startOfDay(for: day))
            }
        }
        let sortedDays = activeDays.sorted(by: >)
        guard let latestDay = sortedDays.first else { return 0 }

        // Any weekly pattern that hits n training days has a worst-case gap
        // of 8-n days (train n consecutive days, rest the remainder) — e.g.
        // Mon–Fri (5/week) has a Fri→Mon gap of 3. ceil(7/n) was too strict
        // and reset compliant 5-day trainers every single weekend.
        let daysPerWeek = max(1, min(7, clientProfile.trainingDaysPerWeek))
        let allowedGap = max(1, 8 - daysPerWeek)

        let today = calendar.startOfDay(for: .now)
        guard let sinceLatest = calendar.dateComponents([.day], from: latestDay, to: today).day,
              sinceLatest <= allowedGap else { return 0 }

        var streak = 1
        var anchorDay = latestDay
        for day in sortedDays.dropFirst() {
            guard let gap = calendar.dateComponents([.day], from: day, to: anchorDay).day,
                  gap <= allowedGap else { break }
            streak += 1
            anchorDay = day
        }
        return streak
    }

    private static func date(fromDayKey key: String) -> Date? {
        let parts = key.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else { return nil }
        return Calendar.current.date(from: DateComponents(year: parts[0], month: parts[1], day: parts[2]))
    }

    /// Strict consecutive-day streak, used for coach-side client summaries
    /// where the athlete's schedule and protected days aren't known.
    private static func consecutiveDayStreak(from logs: [WorkoutLog]) -> Int {
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

    /// User-driven dismissal only — the stamp is a deliberate moment, not
    /// a toast, so it never times itself out.
    func dismissRecordStamp() {
        recordStamp = nil
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

    // Internal (was private): views surface their own failure states too —
    // an export that silently no-ops is worse than a view-initiated toast.
    func showToast(_ message: String) {
        toastMessage = message
        Task {
            try? await Task.sleep(for: .seconds(2))
            if self.toastMessage == message {
                self.toastMessage = nil
            }
        }
    }
}

extension CoachAnalytics {
    /// Zeroed analytics for a real coach account with no client history yet.
    /// Exists for the demo-data purge (`clearSeededDemoData`): empty strings
    /// and zeros let the UI hide the card rather than show fake performance.
    static let empty = CoachAnalytics(
        clientRetention: 0,
        averageCompliance: 0,
        averageProgress: "",
        dropOffRate: 0,
        painFlags: 0,
        messageResponseRate: 0,
        programSuccessRate: 0,
        sessionCompletion: 0,
        groupAttendance: 0,
        insight: ""
    )
}
