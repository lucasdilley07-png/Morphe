import Foundation

protocol MorpheTabItem: Hashable, Identifiable {
    var title: String { get }
    var systemImage: String { get }
}

enum AppRole: String, CaseIterable, Identifiable, Codable {
    case client
    case coach

    var id: String { rawValue }

    var title: String {
        switch self {
        case .client:
            return "Athlete Account"
        case .coach:
            return "Coach Account"
        }
    }

    var subtitle: String {
        switch self {
        case .client:
            return "Your plan, progress, coach support, and daily wins."
        case .coach:
            return "CRM, athlete plans, outreach, and coaching decisions."
        }
    }
}

enum GenderOption: String, CaseIterable, Identifiable {
    case male = "Male"
    case female = "Female"
    case other = "Other"

    var id: String { rawValue }

    var shortTitle: String {
        switch self {
        case .male:
            return "M"
        case .female:
            return "F"
        case .other:
            return "O"
        }
    }
}

/// How long the coach has been coaching — asked during coach onboarding.
enum CoachTenureOption: String, CaseIterable, Identifiable {
    case new = "Just starting"
    case growing = "1-3 years"
    case seasoned = "3-10 years"
    case veteran = "10+ years"

    var id: String { rawValue }
}

/// Roster size the coach works with today — asked during coach onboarding.
enum CoachRosterOption: String, CaseIterable, Identifiable {
    case justStarting = "0-3 athletes"
    case small = "4-10 athletes"
    case team = "11-25 athletes"
    case program = "25+ athletes"

    var id: String { rawValue }
}

/// A person scanned via a Morphe connect QR code. Stored on the scanner's
/// account; mutual rosters/messaging arrive when the backend links accounts.
struct ScannedConnection: Identifiable, Hashable, Codable {
    var id: String
    var name: String
    var handle: String
    var role: String
    var scannedAt: Date
}

/// Feature gating for the solo-first v1 launch. The multi-user surfaces
/// (coach tools, networking, chat, payments) are built but hidden until the
/// v2 backend exists. Flip this to `true` to re-enable them everywhere.
enum FeatureFlags {
    /// The social feed layer (posts, stories, camera, grid, immersive
    /// viewer). Dark-flagged for launch (product audit 2026-08-11): at 300
    /// scattered users with no push, a feed has no loop — Network ships as
    /// CHATS | BOARD | CALENDAR instead. All feed code stays warm behind
    /// this flag for the relight.
    static let socialFeedEnabled = false

    static let multiUserEnabled = false
    /// Gates the new account/sign-in flow. Now backed by Firebase Auth — the app
    /// requires sign-in (or account creation) before onboarding, and each account
    /// gets its own cloud-synced profile + logs.
    static let accountsEnabled = true
}

enum ClientTab: String, CaseIterable, MorpheTabItem {
    case today
    case train
    case discover
    case community
    case hub
    case more

    var id: String { rawValue }

    /// Tabs shown in the bottom navigation. The Network (community) tab is
    /// back in v1: its For You feed is REAL now (Firestore posts/* — publish,
    /// react, save, repost). The other multi-user surfaces (coach networking,
    /// demo inbox, payments) stay individually gated on `multiUserEnabled`.
    static var visibleCases: [ClientTab] {
        // Lucas 2026-08-26: Discover is a first-class tab again and
        // Progress left the bar — it now presents from the profile's
        // "history, records, and charts" row (and every old door). The
        // .hub case survives for compatibility but never renders as a tab.
        [.today, .train, .discover, .community, .more]
    }

    var title: String {
        switch self {
        case .today: return "Today"
        case .train: return "Train"
        case .discover: return "Discover"
        case .community: return "Network"
        case .hub: return "Progress"
        case .more: return "Learn"
        }
    }

    var systemImage: String {
        switch self {
        case .today: return "house.fill"
        case .train: return "figure.run"
        case .discover: return "square.grid.2x2.fill"
        case .community: return "person.3.sequence.fill"
        case .hub: return "chart.line.uptrend.xyaxis"
        case .more: return "book.fill"
        }
    }
}

/// Discover's two halves (Lucas 2026-10-10): the workout catalog, and
/// the Feed of what Creator Coaches published.
enum DiscoverSection: String, CaseIterable, Identifiable {
    case workouts = "Workouts"
    case feed = "Feed"
    var id: String { rawValue }
}

enum ClientCommunitySection: String, CaseIterable, Identifiable {
    case forYou = "Feed"
    case contact = "Contact"
    case board = "Board"
    case calendar = "Calendar"

    var id: String { rawValue }
}

enum CoachTab: String, CaseIterable, MorpheTabItem {
    case dashboard
    case athletes
    case train
    case discover
    case programs
    case network
    case messages

    var id: String { rawValue }

    /// Coach tabs shown in the bottom nav: Home · Build · Train · Discover
    /// · Inbox. Build leads with the athlete roster, then the program builder
    /// and library. Train and Discover are the same surfaces the athlete gets.
    /// Network stays in code for v2.
    static var visibleCases: [CoachTab] {
        [.dashboard, .programs, .train, .discover, .messages]
    }

    var title: String {
        switch self {
        case .dashboard: return "Home"
        case .athletes: return "Athletes"
        case .train: return "Train"
        case .discover: return "Discover"
        case .programs: return "Build"
        case .network: return "Network"
        case .messages: return "Inbox"
        }
    }

    var systemImage: String {
        switch self {
        case .dashboard: return "waveform.path.ecg.rectangle.fill"
        case .athletes: return "person.3.fill"
        case .train: return "figure.run"
        case .discover: return "square.grid.2x2.fill"
        case .programs: return "list.bullet.clipboard.fill"
        case .network: return "person.2.wave.2.fill"
        case .messages: return "bubble.left.and.bubble.right.fill"
        }
    }
}

enum CoachBuildSection: String, CaseIterable, Identifiable {
    case builder = "Build"
    case library = "Library"

    var id: String { rawValue }
}

enum ClientHubFeature: String, CaseIterable, Identifiable {
    case progress = "Progress & Reports"
    case scores = "Scores & Levels"
    case tools = "Quick Tools"
    case library = "Exercise Library"
    case nutrition = "Nutrition Basics"
    case learn = "Lessons"

    var id: String { rawValue }

    var systemImage: String {
        switch self {
        case .progress: return "chart.line.uptrend.xyaxis"
        case .scores: return "gauge.with.dots.needle.67percent"
        case .tools: return "bolt.badge.clock"
        case .library: return "figure.strengthtraining.traditional"
        case .nutrition: return "fork.knife"
        case .learn: return "brain.head.profile"
        }
    }

    var subtitle: String {
        switch self {
        case .progress:
            return "Reports, trends, badges, and roadmap"
        case .scores:
            return "Readiness, Morphe Score, XP, and streak"
        case .tools:
            return "Quick actions, notifications, and shortcuts"
        case .library:
            return "Exercises, form help, and alternatives"
        case .nutrition:
            return "Daily targets and simple eating guidance"
        case .learn:
            return "Lessons and daily quizzes"
        }
    }
}

enum DemoDifficulty: String, CaseIterable, Identifiable {
    case recovery = "Recovery"
    case beginner = "Beginner"
    case moderate = "Moderate"
    case advanced = "Advanced"

    var id: String { rawValue }
}

enum TaskDifficulty: String, CaseIterable, Identifiable {
    case easy = "Easy"
    case steady = "Steady"
    case stretch = "Stretch"

    var id: String { rawValue }
}

enum MuscleGroup: String, CaseIterable, Identifiable {
    case chest = "Chest"
    case back = "Back"
    case legs = "Legs"
    case shoulders = "Shoulders"
    case arms = "Arms"
    case core = "Core"
    case conditioning = "Conditioning"

    var id: String { rawValue }
}

enum RiskLevel: String, CaseIterable, Identifiable {
    case low = "Low"
    case medium = "Medium"
    case high = "High"

    var id: String { rawValue }
}

enum HealthTier: String, Identifiable {
    case thriving = "Thriving"
    case strong = "Strong"
    case building = "Building"
    case atRisk = "At Risk"
    case resetMode = "Rebuilding"

    var id: String { rawValue }

    static func from(score: Int) -> HealthTier {
        switch score {
        case 90...100: return .thriving
        case 75...89: return .strong
        case 60...74: return .building
        case 40...59: return .atRisk
        default: return .resetMode
        }
    }
}

enum NutritionMode: String, CaseIterable, Identifiable {
    case simple = "Simple Mode"
    case guided = "Guided Mode"
    case detailed = "Detailed Mode"

    var id: String { rawValue }

    var description: String {
        switch self {
        case .simple: return "Habits only"
        case .guided: return "Calories + protein"
        case .detailed: return "Macros"
        }
    }
}

enum CalendarEventType: String, CaseIterable, Identifiable {
    case checkIn = "Check-in"
    case session = "Session"
    case update = "Program Update"
    case review = "Review"
    case group = "Group"
    case competition = "Competition"

    var id: String { rawValue }
}

// Button copy: 2 words max app-wide; these render directly as menu buttons.
// Raw values are display-only (never persisted), so renaming is safe.
enum WorkoutAdjustmentOption: String, CaseIterable, Identifiable {
    case easier = "Easier"
    case shorter = "Shorter"
    case home = "Home Version"
    case gym = "Gym Version"
    case recovery = "Recovery"
    case reschedule = "Reschedule"

    var id: String { rawValue }
}

enum TodayQuickAction: String, CaseIterable, Identifiable {
    case logWorkout = "Log Workout"
    case swapExercise = "Swap Exercise"
    case askAI = "Ask Morphe AI"
    case messageTrainer = "Message Trainer"

    var id: String { rawValue }
}

enum ChatSender: String, Identifiable, Codable {
    case user
    case ai
    case coach
    case client
    case system

    var id: String { rawValue }
}

enum SportFocus: String, CaseIterable, Identifiable, Codable {
    /// What the pickers offer. "Weight Loss" stays a case so existing
    /// profiles and catalog tags still decode, but it's a goal ("Lose
    /// weight"), not a sport — listing it twice confused onboarding
    /// (audit 2026-10-15).
    static var pickable: [SportFocus] { allCases.filter { $0 != .weightLoss } }

    case generalFitness = "General Fitness"
    case weightLoss = "Weight Loss"
    case strength = "Strength"
    case bodybuilding = "Bodybuilding"
    case personalTraining = "Personal Training"
    case boxing = "Boxing"
    case mma = "MMA"
    case soccer = "Soccer"
    case basketball = "Basketball"
    case football = "Football"
    case track = "Track"
    case running = "Running"
    case baseball = "Baseball"
    case tennis = "Tennis"
    case volleyball = "Volleyball"
    case wrestling = "Wrestling"
    case swimming = "Swimming"
    case hybridAthlete = "Hybrid Athlete"

    var id: String { rawValue }

    var shortTitle: String {
        switch self {
        case .generalFitness: return "General"
        case .weightLoss: return "Weight Loss"
        case .personalTraining: return "PT"
        case .hybridAthlete: return "Hybrid"
        default: return rawValue
        }
    }
}

enum RecoveryStatus: String, CaseIterable, Identifiable {
    case ready = "Ready"
    case moderate = "Moderate"
    case takeItEasy = "Take It Easy"
    case recoveryRecommended = "Recovery Recommended"
    case coachReviewNeeded = "Coach Review Needed"

    var id: String { rawValue }
}

enum WorkoutFeedbackOption: String, CaseIterable, Identifiable {
    case tooEasy = "Too easy"
    case justRight = "Just right"
    case tooHard = "Too hard"
    case pain = "I felt pain"
    case skippedParts = "I skipped parts"

    var id: String { rawValue }
}

enum PlanAdjustmentReason: String, CaseIterable, Identifiable {
    case lowRecovery = "Low recovery"
    case missedWorkout = "Missed workout"
    case painReported = "Pain reported"
    case notEnoughTime = "Not enough time"
    case workoutTooHard = "Workout too hard"
    case workoutTooEasy = "Workout too easy"
    case noEquipment = "No equipment"
    case eventApproaching = "Competition/game approaching"

    var id: String { rawValue }
}

enum ConfidenceLevel: String, CaseIterable, Identifiable {
    case notConfident = "Not confident"
    case maybe = "Maybe"
    case confident = "Confident"

    var id: String { rawValue }
}

enum PlanBReason: String, CaseIterable, Identifiable {
    case tired = "I'm tired"
    case busy = "I'm busy"
    case sore = "I'm sore"
    case unmotivated = "I'm unmotivated"
    case noEquipment = "I have no equipment"
    case pain = "I have pain"
    case traveling = "I'm traveling"
    case competitionSoon = "I have a game/competition soon"

    var id: String { rawValue }
}

enum NotificationPriority: String, CaseIterable, Identifiable {
    case low = "Low"
    case medium = "Medium"
    case high = "High"

    var id: String { rawValue }
}

enum ProgramCategory: String, CaseIterable, Identifiable {
    case strength = "Strength"
    case conditioning = "Conditioning"
    case mobility = "Mobility"
    case skillWork = "Skill Work"
    case speed = "Speed"
    case agility = "Agility"
    case power = "Power"
    case endurance = "Endurance"
    case recovery = "Recovery"
    case returnToTraining = "Return-to-Training"
    case fightCamp = "Fight Camp"
    case offSeason = "Off-Season"
    case preSeason = "Pre-Season"
    case inSeason = "In-Season"
    case competitionTaper = "Competition Taper"

    var id: String { rawValue }
}

enum SessionType: String, CaseIterable, Identifiable {
    case gymWorkout = "Gym workout"
    case fieldSession = "Field session"
    case courtSession = "Court session"
    case boxingSession = "Boxing session"
    case runningSession = "Running session"
    case mobilitySession = "Mobility session"
    case recoverySession = "Recovery session"
    case skillDrillSession = "Skill drill session"
    case testingDay = "Testing day"

    var id: String { rawValue }
}

enum TrainingPhaseType: String, CaseIterable, Identifiable {
    case assessmentWeek = "Assessment Week"
    case foundationPhase = "Foundation Phase"
    case strengthPhase = "Strength Phase"
    case powerPhase = "Power Phase"
    case conditioningPhase = "Conditioning Phase"
    case skillPhase = "Skill Phase"
    case deloadWeek = "Deload Week"
    case competitionWeek = "Competition Week"
    case recoveryPhase = "Recovery Phase"

    var id: String { rawValue }
}

enum AttendanceStatus: String, CaseIterable, Identifiable {
    case present = "Present"
    case late = "Late"
    case absent = "Absent"
    case excused = "Excused"
    case partialCompletion = "Partial Completion"

    var id: String { rawValue }
}

enum LeadStatus: String, CaseIterable, Identifiable {
    case newLead = "New Lead"
    case contacted = "Contacted"
    case consultationBooked = "Consultation Booked"
    case trialClient = "Trial Client"
    case activeClient = "Active Client"
    case pastClient = "Past Client"
    case reEngagement = "Re-Engagement"

    var id: String { rawValue }
}

enum CoachingTone: String, CaseIterable, Identifiable {
    case supportive = "Supportive"
    case direct = "Direct"
    case competitive = "Competitive"
    case calm = "Calm"
    case educational = "Educational"
    case highEnergy = "High-energy"
    case beginnerFriendly = "Beginner-friendly"

    var id: String { rawValue }

    var preview: String {
        switch self {
        case .supportive:
            return "You showed up today. That matters. Let's get one small win."
        case .direct:
            return "Focus on the next action and finish it clean."
        case .competitive:
            return "You said you wanted this. Finish today's session and prove it."
        case .calm:
            return "Stay steady, breathe, and let the day be simple."
        case .educational:
            return "Today's session builds your aerobic base, which helps you recover faster between rounds."
        case .highEnergy:
            return "Let's move. Energy follows action."
        case .beginnerFriendly:
            return "Short, clear, and doable beats confusing every time."
        }
    }
}

extension CoachingTone {
    // Voice table for Morphe's deterministic coach copy. The tone the user
    // picked changes HOW Morphe talks everywhere it talks — replies, session
    // feedback, celebrations, plan notes — not just one fallback line. This
    // is honest string work keyed off their setting, not AI.

    /// The catch-all coach reply when no keyword branch matches.
    var replyFallback: String {
        switch self {
        case .supportive:
            return "You showed up — that already counts. Pick one small action, finish it, and let the day build from there."
        case .direct:
            return "Skip the debate. Pick the next action and finish it clean."
        case .competitive:
            return "You said you wanted this. Pick the next small action and prove it."
        case .calm:
            return "Keep it steady. One small action, done well, is enough for right now."
        case .educational:
            return "Consistency works because repeatable training builds adaptation without blowing up recovery — so pick one repeatable action and do it now."
        case .highEnergy:
            return "Let's move — energy follows action. Grab the next task and go."
        case .beginnerFriendly:
            return "Short, clear, and doable: pick the smallest next step and finish it. That's a real win."
        }
    }

    /// Short lead-in prepended to the post-workout feedback response.
    var feedbackLead: String {
        switch self {
        case .supportive: return "Proud of you for logging that."
        case .direct: return "Logged."
        case .competitive: return "Noted — competitors log everything."
        case .calm: return "Thanks for checking in."
        case .educational: return "Good data point."
        case .highEnergy: return "Let's go."
        case .beginnerFriendly: return "Nice and simple."
        }
    }

    /// The celebration detail line when a workout is logged.
    var workoutCompleteDetail: String {
        switch self {
        case .supportive: return "Workout logged — another brick in the wall."
        case .direct: return "Workout logged. On to the next one."
        case .competitive: return "Workout logged — stay ahead."
        case .calm: return "Workout logged. Breathe — good work."
        case .educational: return "Workout logged — every log sharpens your plan."
        case .highEnergy: return "Workout logged. That's how it's done."
        case .beginnerFriendly: return "Workout logged — one clear step at a time."
        }
    }

    /// Short lead-in prepended to the daily task-plan note.
    var planNoteLead: String {
        switch self {
        case .supportive: return "You've got this."
        case .direct: return "No fluff:"
        case .competitive: return "Scoreboard's watching:"
        case .calm: return "Steady as ever:"
        case .educational: return "For context:"
        case .highEnergy: return "Let's go:"
        case .beginnerFriendly: return "Keep it simple:"
        }
    }
}

enum ThemePreset: String, CaseIterable, Identifiable {
    case morpheBlackBlue = "Morphe Black/Electric Blue"
    case boxingRedCharcoal = "Boxing Red/Charcoal"
    case soccerGreenWhite = "Soccer Green/White"
    case basketballOrangeBlack = "Basketball Orange/Black"
    case recoveryBlueGray = "Recovery Blue/Soft Gray"
    case strengthPurpleGraphite = "Strength Purple/Graphite"
    case minimalWhiteBlack = "Minimal White/Black"
    case goldPremium = "Gold Premium"

    var id: String { rawValue }
}

enum AccentPalette: String, CaseIterable, Identifiable {
    /// One color per rank (Lucas 2026-10-10): Morphe Dark Blue is the
    /// level-1 starter, every rank after it unlocks the next, General
    /// wears metallic gold. Declared in ladder order so pickers read as
    /// the climb. See MorpheRank.palette.
    case morpheDark = "Morphe Dark Blue"
    /// The bright brand blue of the 2026-10-01 rebrand — now Cadet's.
    case spartan = "Spartan Blue"
    case electricBlue = "Electric Blue"
    case green = "Green"
    case red = "Red"
    case orange = "Orange"
    case purple = "Purple"
    case pink = "Pink"
    case platinum = "Platinum"
    /// Metallic gold — General only. (Raw value kept: it was the
    /// pre-rebrand brand palette and old profiles store "Gold".)
    case gold = "Gold"
    /// Earned by referral, not level — unlocks when someone joins Morphe
    /// through this user's invite link (see `isPaletteUnlocked`).
    case recruiter = "Recruiter"
    /// Earned by finishing a first challenge or board week (2026-10-10).
    case champion = "Champion"
    /// RETIRED 2026-10-10 (Lucas: the ladder's colors are the colors).
    /// Kept so old profiles decode; hidden from the picker, never unlocks.
    case custom = "Custom"

    var id: String { rawValue }

    /// The rank this color belongs to; nil for Recruiter and Custom.
    var rank: MorpheRank? { MorpheRank.allCases.first { $0.palette == self } }

    /// Gold and silver draw with a metallic sheen (swatches, rank badges).
    var isMetallic: Bool { self == .gold || self == .platinum }
}

enum AvatarStyle: String, CaseIterable, Identifiable {
    case cleanStarter = "Clean Starter"
    case fightReady = "Fight Ready"
    case matchFit = "Match Fit"
    case jumpDay = "Jump Day"
    case roadRunner = "Road Runner"
    case strengthBuilder = "Strength Builder"

    var id: String { rawValue }

    var systemImage: String {
        switch self {
        case .cleanStarter:
            return "sparkles"
        case .fightReady:
            return "figure.boxing"
        case .matchFit:
            return "soccerball"
        case .jumpDay:
            return "basketball.fill"
        case .roadRunner:
            return "figure.run"
        case .strengthBuilder:
            return "dumbbell.fill"
        }
    }

    var starterKitLabel: String {
        switch self {
        case .cleanStarter:
            return "Clean kit"
        case .fightReady:
            return "Fight kit"
        case .matchFit:
            return "Match kit"
        case .jumpDay:
            return "Court kit"
        case .roadRunner:
            return "Run kit"
        case .strengthBuilder:
            return "Strength kit"
        }
    }
}

enum BannerPreset: String, CaseIterable, Identifiable {
    case boxing = "Boxing"
    case soccer = "Soccer"
    case basketball = "Basketball"
    case running = "Running"
    case strength = "Strength"
    case fatLoss = "Fat Loss"
    case transformation = "Transformation"
    case recovery = "Recovery"
    case team = "Team"
    case minimalPremium = "Minimal Premium"

    var id: String { rawValue }
}

enum ExperienceLevelOption: String, CaseIterable, Identifiable {
    case beginner = "Beginner"
    case intermediate = "Intermediate"
    case advanced = "Advanced"

    var id: String { rawValue }
}

enum FitnessGoalOption: String, CaseIterable, Identifiable {
    case loseWeight = "Lose weight"
    case gainMuscle = "Gain muscle"
    case improveSportPerformance = "Improve sport performance"
    case buildConsistency = "Build consistency"
    case improveConditioning = "Improve conditioning"
    case getStronger = "Get stronger"
    case returnAfterInjury = "Return after injury"
    case prepareForEvent = "Prepare for event/competition"

    var id: String { rawValue }
}

/// How the user eats (Lucas 2026-10-10: "diet" under goals). Multi-select,
/// stored comma-joined like equipment; "No restrictions" stands alone.
enum DietOption: String, CaseIterable, Identifiable {
    case noRestrictions = "No restrictions"
    case highProtein = "High protein"
    case vegetarian = "Vegetarian"
    case vegan = "Vegan"
    case pescatarian = "Pescatarian"
    case halal = "Halal"
    case kosher = "Kosher"
    case glutenFree = "Gluten-free"
    case dairyFree = "Dairy-free"
    case lowCarb = "Low carb / keto"
    case fasting = "Intermittent fasting"

    var id: String { rawValue }
}

/// What the user says they are weakest at (Lucas 2026-10-10: "weakness"
/// under equipment). Their own read, never inferred from logs.
enum WeaknessOption: String, CaseIterable, Identifiable {
    case upperBody = "Upper body"
    case lowerBody = "Lower body"
    case core = "Core"
    case cardio = "Cardio / endurance"
    case mobility = "Mobility"
    case balance = "Balance"
    case grip = "Grip"
    case explosiveness = "Explosiveness"
    case consistency = "Consistency"
    case recovery = "Sleep & recovery"
    case nutrition = "Nutrition discipline"

    var id: String { rawValue }
}

enum TrainingStyleOption: String, CaseIterable, Identifiable {
    case strength = "Strength"
    case conditioning = "Conditioning"
    case mobility = "Mobility"
    case skillWork = "Skill Work"
    case recovery = "Recovery"
    case speed = "Speed"
    case endurance = "Endurance"
    case hypertrophy = "Hypertrophy"
    case fatLoss = "Fat Loss"
    case hybrid = "Hybrid"
    case yoga = "Yoga"
    case pilates = "Pilates"
    case dance = "Dance"
    case aerobics = "Aerobics"

    var id: String { rawValue }
}

/// Meal-prep habit asked during onboarding — feeds nutrition personalization.
enum MealPrepOption: String, CaseIterable, Identifiable {
    case never = "Never"
    case occasionally = "Occasionally"
    case weekly = "Weekly"
    case mostMeals = "Most Meals"

    var id: String { rawValue }
}

enum ObstacleOption: String, CaseIterable, Identifiable {
    case time = "Time"
    case motivation = "Motivation"
    case pain = "Pain"
    case equipment = "Equipment"
    case schedule = "Schedule"

    var id: String { rawValue }
}

struct AIInsight: Identifiable, Hashable {
    var id = UUID()
    var title: String
    var summary: String
    var risk: RiskLevel
    var recommendation: String
    var suggestedAction: String
}

struct HealthScoreSummary: Hashable {
    var score: Int
    var headline: String
    var detail: String
    var tier: HealthTier
}

struct TaskItem: Identifiable, Hashable {
    var id = UUID()
    var title: String
    var difficulty: TaskDifficulty
    var isCompleted: Bool
    var xp: Int
}

struct LevelProgress: Hashable {
    var currentTitle: String
    var nextTitle: String
    var currentXP: Int
    var targetXP: Int
    var streak: Int

    var progress: Double {
        guard targetXP > 0 else { return 0 }
        return min(Double(currentXP) / Double(targetXP), 1)
    }
}

struct ExerciseReference: Identifiable, Hashable {
    var id: String
    var name: String
    var muscleGroup: MuscleGroup
    var movementPattern: String
    var musclesWorked: String
    var equipment: String
    var difficulty: DemoDifficulty
    var videoPlaceholder: String
    var instructions: [String]
    var formCue: String
    var commonMistakes: String
    var beginnerModification: String
    var alternatives: [String]
    var whyThisMatters: String
    // Technique Library wave (2026-10-04) — carried by the bundled JSON
    // exercises; the original Swift-authored entries leave them empty.
    /// The training style this entry was written for ("Olympic Weightlifting").
    var discipline: String = ""
    /// Library id of the base movement this is a variation of.
    var variationOf: String? = nil
    /// The coaching source the technique was checked against, and its page.
    var sourceName: String = ""
    var sourceURL: String = ""
}

/// One line in the workout builder: a chosen exercise with target sets/reps.
/// The questionnaire behind "Build with Morphe AI" (Lucas 2026-10-10).
/// Every answer is a chip; the profile seeds the defaults.
struct GuidedBuildRequest: Equatable {
    static let goals = ["Get stronger", "Build muscle", "Lose fat", "Conditioning", "Mobility & recovery", "Sport performance"]
    static let splits = ["Full body", "Upper body", "Lower body", "Push", "Pull", "Legs", "Core", "Conditioning"]
    static let styles = ["Strength", "Hypertrophy", "HIIT", "Circuit", "Endurance", "Boxing", "Mobility"]
    static let intensities = ["Easy", "Moderate", "Hard", "All out"]
    static let minutesOptions = [20, 30, 45, 60, 90]

    var goal = "Build muscle"
    var split = "Full body"
    var style = "Strength"
    var intensity = "Moderate"
    var level: DemoDifficulty = .moderate
    var minutes = 45
    /// From MorpheAppStore.equipmentOptions.
    var equipment: Set<String> = []
    /// Muscle groups to lean on (seeded from the profile's weakness).
    var focus: Set<MuscleGroup> = []
    /// Free text: injuries, movements to skip.
    var avoid = ""

    var summaryLine: String {
        "\(split) · \(style) · \(intensity.lowercased()) · \(minutes) min · \(level.rawValue.lowercased())"
    }
}

/// What a build produced, before it is saved: the exercises as library
/// references with sets and reps, plus where the pick came from.
struct BuiltWorkoutDraft: Equatable {
    var name: String
    var summary: String
    var items: [CustomWorkoutItem]
    /// "Morphe AI" (Claude, the user's key) or "Morphe's rules" (no key).
    var source: String
    /// Honest footnotes: exercises the model named that aren't in the
    /// library, equipment assumptions, and so on.
    var notes: [String] = []
}

struct CustomWorkoutItem: Identifiable, Hashable {
    var id = UUID()
    var exercise: ExerciseReference
    var sets: Int = 3
    var reps: Int = 10
}

struct WorkoutExercise: Identifiable, Hashable {
    var id: String
    var exerciseLibraryID: String
    var name: String
    var muscleGroup: MuscleGroup
    var sets: String
    var reps: String
    var difficulty: DemoDifficulty
    var formCue: String
    /// Prescribed effort ("80% 1RM", "RPE 8", "Zone 2") — empty for
    /// non-catalog exercises.
    var intensityLabel: String = ""
    /// Prescribed rest between sets — nil for non-catalog exercises.
    var restSeconds: Int? = nil
}

struct WorkoutTemplate: Identifiable, Hashable {
    var id = UUID()
    var name: String
    var type: String
    var sport: SportFocus
    var category: ProgramCategory = .conditioning
    var sessionType: SessionType = .gymWorkout
    var goal: String
    var difficulty: DemoDifficulty
    var durationMinutes: Int
    var equipment: String
    /// Catalog facet ("Full Body", "Push", …) — empty for non-catalog templates.
    var focusTag: String = ""
    /// Descriptive style ("Strength training", "Cardio intervals", …);
    /// empty for non-catalog templates.
    var trainingTypeTag: String = ""
    /// v2 catalog category ("Strength & Powerlifting", …) — the Discover
    /// organizing spine; empty for non-catalog templates.
    var categoryTag: String = ""
    /// Result goal (weightLoss / strengthBuilding / leanOut / recovery) —
    /// the Discover goal filter; empty for non-catalog templates.
    var goalTag: String = ""
    var exercises: [WorkoutExercise]
    var defaultSets: String = "3 sets"
    var defaultReps: String = "10 reps"
    var restTime: String = "90 sec"
    var notes: String
    var coachNote: String
}

enum SavedWorkoutLibraryFilter: String, CaseIterable, Identifiable {
    case all = "All"
    case athletes = "Partners"
    // Renamed from "My Copies": this segment now holds EVERYTHING the user
    // made — built-from-scratch workouts and edited catalog copies.
    case myCopies = "My Workouts"

    var id: String { rawValue }
}

enum SavedWorkoutUseCase: String, CaseIterable, Identifiable {
    case solo = "Solo"
    case buddy = "Buddy"
    case fallback = "Fallback"
    case customBuild = "Custom Build"

    var id: String { rawValue }
}

struct SavedWorkoutLibraryItem: Identifiable, Hashable {
    var id = UUID()
    var workoutTemplateID: UUID
    var workoutName: String
    var sport: SportFocus
    var sourceName: String
    var sourceRole: AppRole
    var sourceContext: String
    var savedAt: Date = .now
    var bestFor: SavedWorkoutUseCase
    var note: String
    var isPinned: Bool = false
}

struct SavedWorkoutLibraryInsight: Hashable {
    var completionCount: Int
    var lastCompletedAt: Date?
    var lastSource: WorkoutLogSource?
    var hasBuddyCompletion: Bool
    /// Mean of this workout's post-session debrief scores (nil = never
    /// debriefed) — the user's own 0-10 verdicts, shown in the library.
    var averageDebriefRating: Double? = nil
}

// MARK: - Post-workout debrief (Lucas 2026-08-28)
//
// Three questions in a pop-up the moment a session finishes: intensity,
// a 0-10 score, and what to change next time. Saved locally and to the
// user's backend profile (users/{uid}/debriefs) so the insight engine
// personalizes from the user's OWN verdicts instead of canned tips.

enum WorkoutIntensity: String, Codable, CaseIterable, Identifiable {
    case light
    case steady
    case hard
    case allOut

    var id: String { rawValue }

    var label: String {
        switch self {
        case .light: return "Light"
        case .steady: return "Steady"
        case .hard: return "Hard"
        case .allOut: return "All-out"
        }
    }
}

struct WorkoutDebrief: Identifiable, Codable, Hashable {
    var id = UUID()
    var completedAt: Date
    var workoutTemplateID: UUID?
    var workoutTitle: String
    var intensity: WorkoutIntensity
    /// The user's score for the session, 0...10.
    var rating: Int
    /// "Change or add anything?" — empty string means nothing asked.
    var changeRequest: String
}

/// Morphe's choosable personas (personalization phase 2). Each keeps
/// TRAIN HONEST — the register changes, the honesty doesn't. The spec is
/// static data; the chosen id lives in UserStyleProfile.characterID.
struct MorpheCharacter: Identifiable, Equatable {
    let id: String
    let name: String
    /// The single letter on the badge.
    let letter: String
    /// Badge gradient endpoints (RGB 0–1).
    let colors: [(red: Double, green: Double, blue: Double)]
    /// One line fed to the Claude brain so the voice actually changes.
    let register: String
    /// Picker subtitle — what this persona feels like.
    let vibe: String

    static func == (lhs: MorpheCharacter, rhs: MorpheCharacter) -> Bool { lhs.id == rhs.id }

    // ONE character (Lucas 2026-09): Morphe is the identity — the user
    // customizes its ACCENT and COMMUNICATION STYLE, not who it is.
    // Legacy ids (atlas/blaze/sage) resolve here via spec()'s fallback.
    static let all: [MorpheCharacter] = [
        MorpheCharacter(
            id: "morphe", name: "Morphe", letter: "M",
            colors: [(0.161, 0.341, 0.851), (0.102, 0.231, 0.639)],
            register: "You are Morphe — a steady trainer who tells the truth plainly. The accent and delivery style below are the user's choices; wear them naturally.",
            vibe: "The one and only"),
    ]

    /// Unknown/legacy ids fall back to the original — never a blank badge.
    static func spec(for id: String) -> MorpheCharacter {
        all.first { $0.id == id } ?? all[0]
    }
}

/// The reorderable units of the Today page (personalization phase 3).
/// The greeting + workout hero stay fixed — they're the state machinery
/// (rest day, streak, comeback). Everything below is the user's layout.
enum HomeCardID: String, CaseIterable, Identifiable {
    case insight
    case schedule
    /// The three glance tiles under the plan, hideable one by one
    /// (Lucas 2026-10-16).
    case goals, nutrition, progress
    case adjustments
    case support

    var id: String { rawValue }

    var title: String {
        switch self {
        case .insight: return "Pattern insight"
        case .schedule: return "Schedule & messages"
        case .goals: return "Goals"
        case .nutrition: return "Nutrition"
        case .progress: return "Progress"
        case .adjustments: return "If plans change"
        case .support: return "Support & progress"
        }
    }

    var detail: String {
        switch self {
        case .insight: return "What your logs say about how you train"
        case .schedule: return "Booked sessions and conversations"
        case .goals: return "Today's checklist tile"
        case .nutrition: return "Calories and protein tile"
        case .progress: return "Sessions this week tile"
        case .adjustments: return "Lighter days and backup plans"
        case .support: return "Plan context, partners, and your scores"
        }
    }

    /// Pinned under the plan card in this order — reorderable among the
    /// rest only in the sense of hide/show.
    var isPinnedUnderPlan: Bool {
        switch self {
        case .schedule, .goals, .nutrition, .progress: return true
        default: return false
        }
    }

    static let defaultOrder: [HomeCardID] = [.insight, .schedule, .goals, .nutrition, .progress, .adjustments, .support]

    /// Resolves a persisted order: unknown ids drop, missing ids append
    /// in default order — the page can never lose a card to bad data.
    static func resolvedOrder(from raw: [String]) -> [HomeCardID] {
        var order = raw.compactMap(HomeCardID.init(rawValue:))
        for card in defaultOrder where !order.contains(card) {
            order.append(card)
        }
        return order
    }
}

/// Train's reorderable sections (Lucas 2026-10-05) — everything under
/// the session hero. Same resolve rule as HomeCardID.
/// A page section the user can reorder or hide — Discover and Learn
/// share one editor (Lucas 2026-10-16).
protocol LayoutCard: Identifiable, Hashable, CaseIterable, RawRepresentable where RawValue == String {
    var title: String { get }
    var detail: String { get }
    static var defaultOrder: [Self] { get }
}

extension LayoutCard {
    var id: String { rawValue }
    /// Saved order first, then anything new appended in default order.
    static func resolvedOrder(from raw: [String]) -> [Self] {
        var order = raw.compactMap(Self.init(rawValue:))
        for card in defaultOrder where !order.contains(card) { order.append(card) }
        return order
    }
}

enum DiscoverCardID: String, LayoutCard {
    case coaches, newInLibrary, mostDone, families, technique

    var title: String {
        switch self {
        case .coaches: return "From Coaches"
        case .newInLibrary: return "New in the Library"
        case .mostDone: return "Your Most Done"
        case .families: return "Build · Condition · Sport · Recover"
        case .technique: return "Technique Library"
        }
    }
    var detail: String {
        switch self {
        case .coaches: return "Workouts published by approved Creator Coaches"
        case .newInLibrary: return "The newest categories, your level first"
        case .mostDone: return "Ranked by your own completions"
        case .families: return "Every category, grouped by what it's for"
        case .technique: return "Every movement's setup, cue and fault"
        }
    }
    static let defaultOrder: [DiscoverCardID] = [.coaches, .newInLibrary, .mostDone, .families, .technique]
}

enum LearnCardID: String, LayoutCard {
    case quizzes, lessons, whyMorphe, rules, coachNotes

    var title: String {
        switch self {
        case .quizzes: return "Quizzes"
        case .lessons: return "Lessons"
        case .whyMorphe: return "Why Morphe"
        case .rules: return "Personal rules"
        case .coachNotes: return "From Coaches"
        }
    }
    var detail: String {
        switch self {
        case .quizzes: return "One question a day, XP for a first-try answer"
        case .lessons: return "Two-minute reads on training, recovery and effort"
        case .whyMorphe: return "The four rules the app is built on"
        case .rules: return "Habits Morphe has learned from you"
        case .coachNotes: return "Notes from approved Creator Coaches"
        }
    }
    static let defaultOrder: [LearnCardID] = [.quizzes, .lessons, .whyMorphe, .rules, .coachNotes]
}

enum TrainCardID: String, CaseIterable, Identifiable {
    case program
    /// Build Workout (Lucas 2026-10-10): your own build, or one built with
    /// Morphe AI after a short questionnaire. Sits above My Library.
    case builder
    case library
    case partner
    case progress

    var id: String { rawValue }

    var title: String {
        switch self {
        case .program: return "Your program"
        case .builder: return "Build Workout"
        case .library: return "My Library"
        case .partner: return "Partner session"
        case .progress: return "Progress"
        }
    }

    var detail: String {
        switch self {
        case .program: return "The multi-week plan in flight"
        case .builder: return "Build one yourself, or with Morphe AI"
        case .library: return "Your saved workouts"
        case .partner: return "A session shared with a training partner"
        case .progress: return "History, records and charts"
        }
    }

    static let defaultOrder: [TrainCardID] = [.program, .builder, .library, .partner, .progress]

    static func resolvedOrder(from raw: [String]) -> [TrainCardID] {
        var order = raw.compactMap(TrainCardID.init(rawValue:))
        // Missing cards append — except the builder, which sits directly
        // above the library it feeds (added 2026-10-10 after orders were
        // already saved).
        for card in defaultOrder where !order.contains(card) {
            if card == .builder, let index = order.firstIndex(of: .library) {
                order.insert(card, at: index)
            } else {
                order.append(card)
            }
        }
        return order
    }
}

/// Morphe's spoken accent/voice options (Lucas 2026-09). The id is the
/// chosen value in UserStyleProfile.voiceStyle; resolution to a real
/// AVSpeechSynthesisVoice happens in HeyMorpheEngine (quality-ranked,
/// graceful fallback when a language pack isn't installed).
struct MorpheVoiceOption: Identifiable, Equatable {
    let id: String
    let title: String
    let detail: String
    /// BCP-47 language for the synthesizer voice.
    let language: String
    /// Preferred gender for the quality-ranked pick.
    let wantsMale: Bool
    /// Slightly lowered pitch keeps the male voices in the chest.
    let pitch: Float

    static func == (lhs: MorpheVoiceOption, rhs: MorpheVoiceOption) -> Bool { lhs.id == rhs.id }

    static let all: [MorpheVoiceOption] = [
        MorpheVoiceOption(id: "british", title: "British", detail: "The Jarvis original",
                          language: "en-GB", wantsMale: true, pitch: 0.92),
        MorpheVoiceOption(id: "british-female", title: "British F", detail: "Measured and warm",
                          language: "en-GB", wantsMale: false, pitch: 1.0),
        MorpheVoiceOption(id: "american", title: "American", detail: "Straight-ahead coach",
                          language: "en-US", wantsMale: true, pitch: 0.94),
        MorpheVoiceOption(id: "australian", title: "Aussie", detail: "Relaxed and up-front",
                          language: "en-AU", wantsMale: true, pitch: 0.94),
    ]

    /// Unknown/legacy ids fall back to the British original.
    static func spec(for id: String) -> MorpheVoiceOption {
        all.first { $0.id == id } ?? all[0]
    }
}

/// How Morphe talks — delivery, not personality (the character persona
/// carries personality; this carries the register the Claude brain
/// answers in). Built-in rule replies keep their fixed copy.
struct MorpheCommunicationStyle: Identifiable, Equatable {
    let id: String
    let title: String
    let detail: String
    /// The line fed to the Claude system prompt.
    let register: String

    static func == (lhs: MorpheCommunicationStyle, rhs: MorpheCommunicationStyle) -> Bool { lhs.id == rhs.id }

    static let all: [MorpheCommunicationStyle] = [
        // The Spartan register (rebrand 2026-10-01): "Direct" renamed, id
        // kept — every persisted "direct" choice becomes Laconic with no
        // migration. The register lives HERE, not in the base identity, so
        // a user who picks Encouraging actually gets warmth (audit 28, P2).
        MorpheCommunicationStyle(
            id: "direct", title: "Laconic", detail: "Few words, all true",
            register: "Delivery: laconic, the Spartan register — the fewest words that carry the full answer. Verbs first, no filler, no pep-talk padding."),
        MorpheCommunicationStyle(
            id: "encouraging", title: "Encouraging", detail: "Warm and supportive",
            register: "Delivery: encouraging — acknowledge the effort genuinely before the answer, but never invent praise the logs don't support."),
        MorpheCommunicationStyle(
            id: "drill", title: "Drill", detail: "Terse, pushy, zero fluff",
            register: "Delivery: drill-sergeant terse — clipped imperatives, push for the next rep, still straight with the numbers."),
        MorpheCommunicationStyle(
            id: "analytical", title: "Analytical", detail: "Numbers first",
            register: "Delivery: analytical — lead with the relevant numbers and trends from their data, then the takeaway."),
    ]

    /// Unknown/legacy ids fall back to direct.
    static func spec(for id: String) -> MorpheCommunicationStyle {
        all.first { $0.id == id } ?? all[0]
    }
}

// MARK: - The Spartan record (docs/SPARTAN-LORE.md)
//
// Everything here is taken from the ancient record and carries where it is
// written down. Same law as the logs: nothing invented, nothing padded. A
// line nobody can cite does not ship — and the app says plainly what it
// does NOT take from Sparta.

/// One saying, as translated, with its situation and its source.
struct LaconicSaying: Identifiable, Hashable {
    let text: String
    let speaker: String
    /// The situation, in one line — a laconic reply means nothing alone.
    let context: String
    /// Where it is written down.
    let source: String

    var id: String { text }
}

/// One short read from the record, tied to a training principle.
struct LoreEntry: Identifiable, Hashable {
    let title: String
    let body: String
    let source: String

    var id: String { title }
}

/// The rank ladder (Lucas 2026-10-10): American military-style titles,
/// climbed by level — and levels come from logged work and lessons. Titles are
/// a familiar vocabulary for standing, not a claim about any service.
enum MorpheRank: Int, CaseIterable, Identifiable {
    case rookie, cadet, privateFirst, corporal, sergeant, lieutenant, captain, major, colonel, general

    var id: Int { rawValue }

    static func rank(forLevel level: Int) -> MorpheRank {
        var current: MorpheRank = .rookie
        for rank in MorpheRank.allCases where level >= rank.firstLevel { current = rank }
        return current
    }

    /// The level this rank is reached at.
    var firstLevel: Int {
        switch self {
        case .rookie: return 1
        case .cadet: return 5
        case .privateFirst: return 10
        case .corporal: return 15
        case .sergeant: return 20
        case .lieutenant: return 26
        case .captain: return 32
        case .major: return 40
        case .colonel: return 50
        case .general: return 60
        }
    }

    var title: String {
        switch self {
        case .rookie: return "Rookie"
        case .cadet: return "Cadet"
        case .privateFirst: return "Private"
        case .corporal: return "Corporal"
        case .sergeant: return "Sergeant"
        case .lieutenant: return "Lieutenant"
        case .captain: return "Captain"
        case .major: return "Major"
        case .colonel: return "Colonel"
        case .general: return "General"
        }
    }

    /// One plain line on what the rank means here.
    var gloss: String {
        switch self {
        case .rookie: return "Day one. Everyone starts here."
        case .cadet: return "In training — the habit is forming."
        case .privateFirst: return "Enlisted. Sessions are routine now."
        case .corporal: return "First stripe. You lead yourself."
        case .sergeant: return "The work is consistent and it shows."
        case .lieutenant: return "Commissioned by the log, nothing else."
        case .captain: return "A standard others can train to."
        case .major: return "Months of logged work behind the title."
        case .colonel: return "Rare air. Earned the slow way."
        case .general: return "The top of the ladder. There is no rank above it."
        }
    }

    var next: MorpheRank? { MorpheRank(rawValue: rawValue + 1) }

    /// The accent color this rank unlocks (personalization, Lucas
    /// 2026-10-10). Rookie's is the starter everyone has.
    var palette: AccentPalette {
        switch self {
        case .rookie: return .morpheDark
        case .cadet: return .spartan
        case .privateFirst: return .electricBlue
        case .corporal: return .green
        case .sergeant: return .red
        case .lieutenant: return .orange
        case .captain: return .purple
        case .major: return .pink
        case .colonel: return .platinum
        case .general: return .gold
        }
    }
}

enum SpartanLore {
    /// Verified sayings only, each VERBATIM from a public-domain Loeb
    /// translation (Babbitt for the Sayings, Helmbold for On
    /// Talkativeness, Perrin for the Lycurgus) and fact-checked against
    /// the text (audit 29). The citation is the work and saying number,
    /// checkable by anyone. Never reword one to make it punchier.
    static let sayings: [LaconicSaying] = [
        LaconicSaying(
            text: "If.",
            speaker: "The Spartans",
            context: "Philip of Macedon wrote: if I invade Laconia, I shall turn you out.",
            source: "Plutarch, On Talkativeness 17"),
        LaconicSaying(
            text: "Add a step to it.",
            speaker: "A Spartan mother",
            context: "Her son complained that his sword was short.",
            source: "Plutarch, Sayings of Spartan Women 18"),
        LaconicSaying(
            text: "Won't it be nice, then, if we shall have shade in which to fight them?",
            speaker: "Leonidas",
            context: "Told the Persian arrows would hide the sun. Herodotus gives the reply to Dienekes (7.226).",
            source: "Plutarch, Sayings of Spartans, Leonidas 6"),
        LaconicSaying(
            text: "Because these they put on for their own sake, but the shield for the common good of the whole line.",
            speaker: "Demaratus",
            context: "Asked why losing a shield brought disgrace and losing a helmet or breastplate did not.",
            source: "Plutarch, Sayings of Spartans, Demaratus 2"),
        LaconicSaying(
            text: "The Spartans did not ask \u{2018}how many are the enemy,\u{2019} but \u{2018}where are they?\u{2019}",
            speaker: "Agis II",
            context: "As Plutarch reports his saying.",
            source: "Plutarch, Sayings of Spartans, Agis son of Archidamus 3"),
        LaconicSaying(
            text: "At every step, my child, remember your valour.",
            speaker: "A Spartan mother",
            context: "To her lame son, as she walked with him to the battlefield.",
            source: "Plutarch, Sayings of Spartan Women 13"),
        LaconicSaying(
            text: "A city will be well fortified which is surrounded by brave men and not by bricks.",
            speaker: "Lycurgus",
            context: "Asked by letter about fortifying the city.",
            source: "Plutarch, Life of Lycurgus 19"),
        LaconicSaying(
            text: "Either this or upon this.",
            speaker: "A Spartan mother",
            context: "Handing her son his shield.",
            source: "Plutarch, Sayings of Spartan Women 16"),
    ]

    /// One saying a day, no randomness: the count of local calendar days
    /// since a fixed date picks the line, so a reopen never reshuffles it.
    /// (Counted between local midnights — `ordinality(of: .day, in: .era)`
    /// rolls over at UTC midnight and changed the line mid-evening.)
    static func saying(on date: Date = .now, calendar: Calendar = .current) -> LaconicSaying {
        let anchor = calendar.date(from: DateComponents(year: 2026, month: 1, day: 1)) ?? .distantPast
        let days = calendar.dateComponents(
            [.day], from: calendar.startOfDay(for: anchor), to: calendar.startOfDay(for: date)).day ?? 0
        let count = sayings.count
        return sayings[((days % count) + count) % count]
    }

    /// The week's saying for the weekly notification: one per week, in
    /// order, so eight weeks walk the whole record before any repeats.
    static func saying(forWeekOf date: Date, calendar: Calendar = .current) -> LaconicSaying {
        let anchor = calendar.date(from: DateComponents(year: 2026, month: 1, day: 1)) ?? .distantPast
        let days = calendar.dateComponents(
            [.day], from: calendar.startOfDay(for: anchor), to: calendar.startOfDay(for: date)).day ?? 0
        let weeks = Int((Double(days) / 7).rounded(.down))
        let count = sayings.count
        return sayings[((weeks % count) + count) % count]
    }

    /// Short reads: what the record says, then what it means under a bar.
    /// The first sentence(s) are the record; the last is Morphe's reading.
    static let entries: [LoreEntry] = [
        LoreEntry(
            title: "They marched to flutes",
            body: "At Mantinea the other army came on in haste and fury. The Spartans advanced slowly to pipe-players, so the line would arrive unbroken. Pace is not weakness. A set done at a held tempo beats a rushed one.",
            source: "Thucydides 5.70"),
        LoreEntry(
            title: "The reckless return",
            body: "Aristodemus missed Thermopylae and came home to disgrace. At Plataea he broke from the line, wanting to die, and fought furiously. Sparta withheld its honors and ranked above him a man who fought well with no wish to die. Herodotus himself thought Aristodemus the bravest. After time away, come back to the work, not to prove a point.",
            source: "Herodotus 7.229–231, 9.71"),
        LoreEntry(
            title: "The thousand",
            body: "The bibasis was a Laconian jump: spring up and touch the heels to the buttocks, counted rep by rep, for prizes. A verse records a girl who reached a thousand, the most ever. Spartan girls trained too. Counted work is an old idea.",
            source: "Pollux, Onomasticon 4.102 · Aristophanes, Lysistrata 82"),
        LoreEntry(
            title: "The mess",
            body: "Every Spartan ate in a mess of about fifteen, and each member brought a fixed share every month. One vote against kept a newcomer out. Train with people who carry their share, and carry yours.",
            source: "Plutarch, Life of Lycurgus 12"),
        LoreEntry(
            title: "Before the work",
            body: "A Persian scout at Thermopylae found the Spartans exercising and combing their hair. Xerxes found it laughable. He was told it is their custom to dress their hair before risking their lives. The routine before the effort is part of the effort.",
            source: "Herodotus 7.208–209"),
        LoreEntry(
            title: "Fear had a temple",
            body: "Sparta kept a shrine to Fear, not to ward it off but because they held that fear keeps a people together. Nerves before a heavy set are not a fault. They are attention.",
            source: "Plutarch, Life of Cleomenes 9"),
    ]

    /// The honest half. Sparta is not a model society and Morphe does not
    /// pretend it was — the brand takes three things and leaves the rest.
    static let whatWeLeave = LoreEntry(
        title: "What Morphe leaves behind",
        body: "Sparta ran on the forced labor of the helots, an enslaved majority, and policed them with terror. Almost everything written about Sparta comes from outsiders, much of it centuries later; historians call the polished version the Spartan mirage. Morphe takes three things: discipline, brevity, and the line that holds together. It leaves the rest.",
        source: "Thucydides 4.80 · Plutarch, Lycurgus 28 · Ollier, Le mirage spartiate (1933)")
}

/// The personalization spine (Lucas 2026-09-09): one profile that holds
/// what Morphe has LEARNED about this user (mined from logs + debriefs,
/// never invented) and what the user has CHOSEN (identity + surface
/// customization). Every adaptive surface reads from here; every picker
/// writes here. Rides the local snapshot + cloud backup as JSON.
struct UserStyleProfile: Codable, Equatable {
    // MARK: Learned (derived — recomputed, never hand-set)

    /// Most common debrief intensity answer, once 2+ debriefs exist.
    var preferredIntensity: String?
    /// Mean debrief rating (0–10), once 2+ debriefs exist.
    var averageRating: Double?
    /// Top exercises by logged frequency (max 5), once 3+ logs exist.
    var favoriteExercises: [String] = []
    /// Median start hour (0–23) of logged sessions, once 3+ logs exist.
    var preferredTrainingHour: Int?
    /// Median logged session length, once 3+ logs exist.
    var typicalDurationMinutes: Int?
    /// Sessions per week over the last 28 days, once 3+ logs exist.
    var weeklyCadence: Double?
    /// The user's own words from recent debrief change requests (max 5,
    /// newest first). Sourced verbatim — Morphe never paraphrases them.
    var recentChangeRequests: [String] = []

    // MARK: Chosen (explicit customization — pickers write these)

    /// Sound-effect set. "classic" is today's gold-tone kit.
    var soundPack: String = "classic"
    /// Morphe's spoken voice (MorpheVoiceOption id). "british" = Jarvis.
    var voiceStyle: String = "british"
    /// Morphe's delivery register (MorpheCommunicationStyle id).
    var communicationStyle: String = "direct"
    /// Morphe's own character/persona identity on this device.
    var characterID: String = "morphe"
    /// User-arranged Today card order; empty means the default layout.
    var homeCardOrder: [String] = []
    /// Cards the user hid from Today (raw HomeCardID values).
    var homeHiddenCards: [String] = []
    /// Train's section order and hidden sections (raw TrainCardID values).
    var trainCardOrder: [String] = []
    var trainHiddenCards: [String] = []
    /// Discover's and Learn's section order / hidden sections (Lucas
    /// 2026-10-16: an edit option on every page but Network).
    var discoverCardOrder: [String] = []
    var discoverHiddenCards: [String] = []
    var learnCardOrder: [String] = []
    var learnHiddenCards: [String] = []
    /// The tab bar's order (raw ClientTab values); empty = default.
    var tabOrder: [String] = []
    /// How often each Today card gets used (learned half — feeds the
    /// suggest-then-confirm layout proposal, never silent rearranging).
    var homeCardTaps: [String: Int] = [:]
    /// Suggestion pair keys ("cardA>cardB") the user already declined —
    /// a declined proposal never re-asks.
    var declinedLayoutSuggestions: [String] = []

    var updatedAt: Date = .distantPast

    /// Tolerant decode, same doctrine as LocalProfileSnapshot: a field
    /// added later must never throw the whole profile away and silently
    /// reset the user's chosen character/sounds (audit 21, P2).
    init() {}

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        preferredIntensity = try? c.decodeIfPresent(String.self, forKey: .preferredIntensity)
        averageRating = try? c.decodeIfPresent(Double.self, forKey: .averageRating)
        favoriteExercises = ((try? c.decodeIfPresent([String].self, forKey: .favoriteExercises)) ?? nil) ?? []
        preferredTrainingHour = try? c.decodeIfPresent(Int.self, forKey: .preferredTrainingHour)
        typicalDurationMinutes = try? c.decodeIfPresent(Int.self, forKey: .typicalDurationMinutes)
        weeklyCadence = try? c.decodeIfPresent(Double.self, forKey: .weeklyCadence)
        recentChangeRequests = ((try? c.decodeIfPresent([String].self, forKey: .recentChangeRequests)) ?? nil) ?? []
        soundPack = ((try? c.decodeIfPresent(String.self, forKey: .soundPack)) ?? nil) ?? "classic"
        voiceStyle = ((try? c.decodeIfPresent(String.self, forKey: .voiceStyle)) ?? nil) ?? "british"
        communicationStyle = ((try? c.decodeIfPresent(String.self, forKey: .communicationStyle)) ?? nil) ?? "direct"
        characterID = ((try? c.decodeIfPresent(String.self, forKey: .characterID)) ?? nil) ?? "morphe"
        homeCardOrder = ((try? c.decodeIfPresent([String].self, forKey: .homeCardOrder)) ?? nil) ?? []
        homeHiddenCards = ((try? c.decodeIfPresent([String].self, forKey: .homeHiddenCards)) ?? nil) ?? []
        trainCardOrder = ((try? c.decodeIfPresent([String].self, forKey: .trainCardOrder)) ?? nil) ?? []
        trainHiddenCards = ((try? c.decodeIfPresent([String].self, forKey: .trainHiddenCards)) ?? nil) ?? []
        discoverCardOrder = ((try? c.decodeIfPresent([String].self, forKey: .discoverCardOrder)) ?? nil) ?? []
        discoverHiddenCards = ((try? c.decodeIfPresent([String].self, forKey: .discoverHiddenCards)) ?? nil) ?? []
        learnCardOrder = ((try? c.decodeIfPresent([String].self, forKey: .learnCardOrder)) ?? nil) ?? []
        learnHiddenCards = ((try? c.decodeIfPresent([String].self, forKey: .learnHiddenCards)) ?? nil) ?? []
        tabOrder = ((try? c.decodeIfPresent([String].self, forKey: .tabOrder)) ?? nil) ?? []
        homeCardTaps = ((try? c.decodeIfPresent([String: Int].self, forKey: .homeCardTaps)) ?? nil) ?? [:]
        declinedLayoutSuggestions = ((try? c.decodeIfPresent([String].self, forKey: .declinedLayoutSuggestions)) ?? nil) ?? []
        updatedAt = ((try? c.decodeIfPresent(Date.self, forKey: .updatedAt)) ?? nil) ?? .distantPast
    }

    /// True when enough real data exists to speak about patterns at all.
    var hasLearnedAnything: Bool {
        preferredIntensity != nil || averageRating != nil
            || !favoriteExercises.isEmpty
            || preferredTrainingHour != nil || weeklyCadence != nil
    }
}

struct GoodForTodayWorkoutRecommendation: Hashable {
    var workoutTemplateID: UUID
    var workoutName: String
    var sourceName: String
    var reasonTitle: String
    var reasonDetail: String
    var contextChips: [String]
    var confidenceNote: String?
    var bestFor: SavedWorkoutUseCase
    var prefersBuddy: Bool
    var existingSavedWorkoutID: UUID?
}

enum WorkoutLogSource: String, CaseIterable, Identifiable, Codable {
    case athleteManual = "Athlete manual"
    case coachManual = "Coach manual"
    case aiPhotoParsed = "AI photo parsed"
    case partnerShared = "Partner shared"

    var id: String { rawValue }

    var badgeTitle: String {
        switch self {
        case .athleteManual:
            return "You logged this"
        case .coachManual:
            return "Coach logged this"
        case .aiPhotoParsed:
            return "AI parsed"
        case .partnerShared:
            return "Partner session"
        }
    }
}

enum WorkoutVerificationStatus: String, CaseIterable, Identifiable, Codable {
    case athleteSubmitted = "Athlete submitted"
    case coachSubmitted = "Coach submitted"
    case aiPendingReview = "AI pending review"
    case coachApproved = "Coach approved"

    var id: String { rawValue }
}

enum WeightUnit: String, CaseIterable, Identifiable, Codable {
    case pounds = "lb"
    case kilograms = "kg"

    var id: String { rawValue }
    var label: String { rawValue }

    /// Formats a stored weight value (always kept in this unit) for display.
    func format(_ value: Double) -> String {
        if value <= 0 { return "Bodyweight" }
        let rounded = (value * 10).rounded() / 10
        let text = rounded.truncatingRemainder(dividingBy: 1) == 0
            ? String(Int(rounded))
            : String(rounded)
        return "\(text) \(rawValue)"
    }
}

/// Per-exercise strength trend derived from real per-set log data — the
/// "am I getting stronger?" answer. Weights are normalized to the user's
/// current display unit.
struct ExerciseStrengthProgress: Identifiable, Hashable {
    var id: String { exerciseName }
    var exerciseName: String
    var sessionCount: Int
    var latestTopWeight: Double
    var previousTopWeight: Double
    var latestDate: Date

    var delta: Double { latestTopWeight - previousTopWeight }
}

/// One exercise's logged work in the just-finished session, for the recap.
struct WorkoutSetRecap: Identifiable, Hashable {
    var id: String          // exercise id
    var name: String
    var reps: [Int]
    var weights: [Double]   // parallel to reps; 0 = bodyweight
    var rpes: [Int] = []    // parallel to reps; 0 = not rated
}

struct LoggedExercise: Identifiable, Hashable, Codable {
    var id = UUID()
    var name: String
    var sets: String
    var reps: String
    var weight: String
    var note: String
    /// Per-set effort like "8, 9" — optional so logs saved before RPE
    /// existed still decode.
    var rpe: String?

    // Raw per-set data (parallel arrays), preserved so progress analytics can
    // compute strength-over-time. The display strings above collapse these
    // (top weight only), which made progression structurally impossible for
    // any log saved without them. All optional: older logs still decode.
    var repsPerSet: [Int]?
    var weightsPerSet: [Double]?   // 0 = bodyweight, in `weightUnit` at log time
    var rpePerSet: [Int]?          // 0 = not rated
    var weightUnit: String?        // "lb" / "kg" the weights were recorded in
    /// MuscleGroup rawValue at log time — optional so every older log still
    /// decodes; the balance chart only counts sets that carry it.
    var muscleGroup: String?
    /// Per-set warm-up flags, parallel to repsPerSet. Optional: older logs
    /// decode as all-working. Warm-ups count toward volume (work is work)
    /// but never toward PRs, e1RM, or strength trends.
    var warmupPerSet: [Bool]?
    /// Per-set "the camera counted these reps" flags, parallel to
    /// repsPerSet (TRAIN HONEST, 2026-10-04). Optional: older logs decode
    /// as hand-entered. It vouches for the REP COUNT only — the weight is
    /// still the lifter's word.
    var cameraCountedPerSet: [Bool]? = nil
    /// Per-set "this was a timed hold" flags, parallel to repsPerSet: for
    /// those sets the reps slot carries SECONDS (2026-10-15 audit — history
    /// printed "12 reps" for a 12 s hold). Optional: older logs fall back to
    /// their "Set N: Hold 12s" note.
    var timedPerSet: [Bool]? = nil

    /// True when set `index` was a hold (its reps slot holds seconds).
    func isTimedSet(_ index: Int) -> Bool {
        if let flags = timedPerSet { return flags.indices.contains(index) && flags[index] }
        return note.contains("Set \(index + 1): Hold ")
    }
}

extension LoggedExercise {
    /// Sets whose reps the camera counted.
    var cameraCountedSetCount: Int { cameraCountedPerSet?.filter { $0 }.count ?? 0 }

    /// Weights from WORKING sets only — the numbers PR/e1RM/strength
    /// derivations are allowed to read. A heavy warm-up single must never
    /// mint a record.
    var workingWeightsPerSet: [Double]? {
        guard let weights = weightsPerSet else { return nil }
        guard let flags = warmupPerSet, flags.contains(true) else { return weights }
        return weights.enumerated().compactMap { index, weight in
            (flags.indices.contains(index) && flags[index]) ? nil : weight
        }
    }
}

struct WorkoutLog: Identifiable, Hashable, Codable {
    var id = UUID()
    var athleteID: UUID
    var athleteName: String
    var workoutTemplateID: UUID?
    var workoutTitle: String
    var sport: SportFocus
    var completedAt: Date
    var durationMinutes: Int
    var exercises: [LoggedExercise]
    var notes: String
    var source: WorkoutLogSource
    var enteredByUserID: UUID
    var enteredByRole: AppRole
    var enteredByName: String
    var visibility: String = "Connected coach + athlete"
    var verificationStatus: WorkoutVerificationStatus
    /// How the session felt (WorkoutFeedbackOption raw value), captured at log
    /// time so the next session can suggest a small progression. Optional:
    /// logs saved before this existed decode with nil (= no bump).
    var sessionFeedback: String?
    /// Set on sessions brought in from another tracker: the file's own
    /// date text plus title. Optional — every native log decodes as nil.
    var importKey: String? = nil

    var isImported: Bool { importKey != nil }
}

extension WorkoutLog {
    /// Tolerant decode (in an extension so the memberwise init survives).
    /// A renamed enum case or type tweak in ONE field of ONE log used to nil
    /// the whole history array, which then fell back to seeded demo logs and
    /// overwrote the user's real file. Owner and date stay strict — a log
    /// without them is meaningless and is dropped by the per-element decoder.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        athleteID = try c.decode(UUID.self, forKey: .athleteID)
        completedAt = try c.decode(Date.self, forKey: .completedAt)
        id = ((try? c.decodeIfPresent(UUID.self, forKey: .id)) ?? nil) ?? UUID()
        athleteName = ((try? c.decodeIfPresent(String.self, forKey: .athleteName)) ?? nil) ?? ""
        workoutTemplateID = ((try? c.decodeIfPresent(UUID.self, forKey: .workoutTemplateID)) ?? nil)
        workoutTitle = ((try? c.decodeIfPresent(String.self, forKey: .workoutTitle)) ?? nil) ?? "Workout"
        sport = ((try? c.decodeIfPresent(SportFocus.self, forKey: .sport)) ?? nil) ?? .generalFitness
        durationMinutes = ((try? c.decodeIfPresent(Int.self, forKey: .durationMinutes)) ?? nil) ?? 0
        exercises = ((try? c.decodeIfPresent([LoggedExercise].self, forKey: .exercises)) ?? nil) ?? []
        notes = ((try? c.decodeIfPresent(String.self, forKey: .notes)) ?? nil) ?? ""
        source = ((try? c.decodeIfPresent(WorkoutLogSource.self, forKey: .source)) ?? nil) ?? .athleteManual
        enteredByUserID = ((try? c.decodeIfPresent(UUID.self, forKey: .enteredByUserID)) ?? nil) ?? athleteID
        enteredByRole = ((try? c.decodeIfPresent(AppRole.self, forKey: .enteredByRole)) ?? nil) ?? .client
        enteredByName = ((try? c.decodeIfPresent(String.self, forKey: .enteredByName)) ?? nil) ?? athleteName
        visibility = ((try? c.decodeIfPresent(String.self, forKey: .visibility)) ?? nil) ?? "Connected coach + athlete"
        verificationStatus = ((try? c.decodeIfPresent(WorkoutVerificationStatus.self, forKey: .verificationStatus)) ?? nil) ?? .athleteSubmitted
        sessionFeedback = ((try? c.decodeIfPresent(String.self, forKey: .sessionFeedback)) ?? nil)
        // Encoded by the synthesized keys but never read back (audit
        // 2026-10-07, P1): every relaunch stripped it, so a re-import after
        // a time-zone change duplicated the whole history.
        importKey = ((try? c.decodeIfPresent(String.self, forKey: .importKey)) ?? nil)
    }
}

struct WorkoutLogSummary: Hashable {
    var totalLogs: Int
    var workoutsThisWeek: Int
    var minutesThisWeek: Int
    var averageDuration: Int
    var currentStreakDays: Int
    var athleteEntries: Int
    var coachEntries: Int
    var aiEntries: Int
    var partnerEntries: Int
    var latestWorkoutTitle: String
    var latestEntryLabel: String
    var latestEntryDate: Date?
    var topExercises: [String]
}

struct PartnerTrainingInsight: Hashable {
    var soloSessionsThisWeek: Int
    var buddySessionsThisWeek: Int
    var totalSessionsThisWeek: Int
    var buddyShareLast30Days: Int
    var lastPartnerName: String?
    var athleteSummary: String
    var coachSummary: String
}

struct AthleteAccessGrant: Identifiable, Hashable {
    var id = UUID()
    var athleteID: UUID
    var coachID: UUID
    var canViewWorkouts: Bool
    var canAddWorkouts: Bool
    var canEditWorkouts: Bool
    var canApproveAIEntries: Bool
}

struct WorkoutHistoryEntry: Identifiable, Hashable {
    var id = UUID()
    var title: String
    var completedOn: String
    var durationMinutes: Int
    var result: String
}

struct DayScore: Identifiable, Hashable {
    var id = UUID()
    var day: String
    var value: Int
}

struct WeeklyWorkoutCount: Identifiable, Hashable {
    var id = UUID()
    var week: String
    var workouts: Int
}

struct SoloBuddyTrendPoint: Identifiable, Hashable {
    var id = UUID()
    var week: String
    var soloSessions: Int
    var buddySessions: Int
}

struct StrengthPoint: Identifiable, Hashable {
    var id = UUID()
    var week: String
    var weight: Int
}

struct WeightPoint: Identifiable, Hashable {
    var id = UUID()
    var label: String
    var value: Int
}

struct MealLogEntry: Identifiable, Hashable {
    var id = UUID()
    var mealType: String
    var name: String
    var calories: Int
    var protein: Int
    var logged: Bool
    /// Macros and provenance (fuel rebuild 2026-10-10). Older entries
    /// carry zeros and an empty source.
    var carbs: Int = 0
    var fat: Int = 0
    var grams: Int? = nil
    var source: String = ""
}

/// The order the day reads in.
enum MealSlot: String, CaseIterable, Identifiable {
    case breakfast = "Breakfast", lunch = "Lunch", dinner = "Dinner", snack = "Snack"
    var id: String { rawValue }

    /// The slot the clock suggests.
    static var suggested: MealSlot {
        switch Calendar.current.component(.hour, from: .now) {
        case ..<11: return .breakfast
        case 11..<15: return .lunch
        case 17..<22: return .dinner
        default: return .snack
        }
    }
}

/// One food in the bundled USDA library (per 100 g).
struct FoodLibraryItem: Codable, Identifiable, Hashable {
    var id: Int
    var name: String
    var cat: String
    var kcal: Int
    var protein: Double
    var carbs: Double
    var fat: Double
    var fiber: Double
    var sugar: Double
    var sodium: Double
}

/// A food the user can log: from the library, a packaged product, or
/// their own recents. Numbers are per 100 g; a listed serving rides
/// along when the product has one.
struct FoodSearchResult: Codable, Identifiable, Hashable {
    var name: String
    var brand: String = ""
    var source: String
    var kcal100: Double
    var protein100: Double
    var carbs100: Double
    var fat100: Double
    var servingGrams: Int? = nil
    var servingLabel: String? = nil
    var barcode: String? = nil

    var id: String { "\(source)|\(brand)|\(name)|\(barcode ?? "")" }
    var displayName: String { brand.isEmpty ? name : "\(name) · \(brand)" }

    init(name: String, brand: String = "", source: String, kcal100: Double, protein100: Double, carbs100: Double, fat100: Double,
         servingGrams: Int? = nil, servingLabel: String? = nil, barcode: String? = nil) {
        self.name = name; self.brand = brand; self.source = source
        self.kcal100 = kcal100; self.protein100 = protein100; self.carbs100 = carbs100; self.fat100 = fat100
        self.servingGrams = servingGrams; self.servingLabel = servingLabel; self.barcode = barcode
    }

    init(library item: FoodLibraryItem) {
        self.init(name: item.name, source: "USDA", kcal100: Double(item.kcal), protein100: item.protein,
                  carbs100: item.carbs, fat100: item.fat)
    }

    func totals(grams: Int) -> (calories: Int, protein: Int, carbs: Int, fat: Int) {
        let f = Double(grams) / 100
        return (Int((kcal100 * f).rounded()), Int((protein100 * f).rounded()), Int((carbs100 * f).rounded()), Int((fat100 * f).rounded()))
    }
}

struct QuickMeal: Identifiable, Hashable {
    var id = UUID()
    var title: String
    var calories: Int
    var protein: Int
}

struct NutritionSnapshot: Hashable {
    var calorieGoal: Int
    var caloriesConsumed: Int
    var proteinGoal: Int
    var proteinConsumed: Int
    var waterGoal: Int
    var waterConsumed: Int
    var nutritionScore: Int
    var mode: NutritionMode
    var meals: [MealLogEntry]
    var quickMeals: [QuickMeal]
    var weeklyProteinTrend: [DayScore]
}

/// Daily nutrition goal numbers plus where they came from. Computed with
/// deterministic per-pound math from the user's logged weight and goal —
/// `sourceNote` says so honestly, and says when the defaults are still
/// generic starters because no weight was logged.
struct NutritionTargets: Equatable {
    var calories: Int
    var proteinGrams: Int
    var waterCups: Int
    var sourceNote: String
    /// True until a bodyweight is logged — the numbers are generic
    /// starters, and every surface that shows them says so (evening audit
    /// 2026-10-16, #4: "0 of 2,200" sat next to "log your weight for targets").
    var isStarter = false
}

/// Lucas's whiteboard nutrition chart (2026-10-09, the photo lives at
/// Content/Nutrition/whiteboard-2026-10-09.jpg), structured by goal. The
/// three splits and the BW×15 anchor are his; the per-goal calorie
/// multipliers match the targets math the app already ran. Protein never
/// drops below 0.85 g/lb whatever the split says — the floor is the one
/// number that doesn't move with the goal.
enum NutritionGoalMode: String, CaseIterable, Identifiable {
    case leanOut = "Lean out"
    case maintain = "Maintain"
    case bulk = "Bulk"

    var id: String { rawValue }

    /// Daily calories per pound of body weight. Maintain is the board's BW×15.
    var caloriesPerLb: Double {
        switch self {
        case .leanOut: return 13
        case .maintain: return 15
        case .bulk: return 16
        }
    }

    /// Carbs / protein / fat as percent of calories — the board's three splits.
    var split: (carbs: Int, protein: Int, fat: Int) {
        switch self {
        case .leanOut: return (40, 30, 30)
        case .maintain: return (45, 30, 25)
        case .bulk: return (50, 25, 25)
        }
    }

    var splitLabel: String { "\(split.carbs)/\(split.protein)/\(split.fat)" }

    /// The one-line rule for the goal.
    var rule: String {
        switch self {
        case .leanOut:
            return "Deficit of about 2 cal per pound under maintenance. Protein stays high so the weight you lose is fat. Fill plates from the low-cal column; keep simple carbs for right around training."
        case .maintain:
            return "Body weight × 15. Carbs scale with the day's training — more on heavy days, less on rest days — and protein holds steady."
        case .bulk:
            return "Surplus of about 1 cal per pound over maintenance, mostly from complex carbs. Keep fats moderate and let the scale move about half a pound a week, not more."
        }
    }

    /// Which columns of the board to lean on for the goal, in order.
    var leanOn: [NutritionFoodGroup] {
        switch self {
        case .leanOut: return [.proteins, .lowCalVolume, .complexCarbs, .fats, .simpleCarbs]
        case .maintain: return [.proteins, .complexCarbs, .lowCalVolume, .fats, .simpleCarbs]
        case .bulk: return [.complexCarbs, .proteins, .simpleCarbs, .fats, .lowCalVolume]
        }
    }

    /// Reads the goal from the user's own onboarding words. Fat-loss wins
    /// when goals mix — overshooting calories hurts that goal the most.
    static func infer(fromGoalText text: String) -> NutritionGoalMode {
        let goal = text.lowercased()
        if goal.contains("lose") || goal.contains("lean") || goal.contains("fat")
            || goal.contains("cut") || goal.contains("weight loss") {
            return .leanOut
        }
        if goal.contains("build") || goal.contains("strength")
            || goal.contains("muscle") || goal.contains("bulk") || goal.contains("gain") {
            return .bulk
        }
        return .maintain
    }
}

/// The five columns on the board, with their calories per gram.
enum NutritionFoodGroup: String, CaseIterable, Identifiable {
    case simpleCarbs, complexCarbs, lowCalVolume, proteins, fats

    var id: String { rawValue }

    var title: String {
        switch self {
        case .simpleCarbs: return "Simple carbs"
        case .complexCarbs: return "Complex carbs"
        case .lowCalVolume: return "Low-cal volume"
        case .proteins: return "Proteins"
        case .fats: return "Fats"
        }
    }

    var caloriesPerGram: Int { self == .fats ? 9 : 4 }

    var whenToUse: String {
        switch self {
        case .simpleCarbs: return "Fast energy — before or right after training."
        case .complexCarbs: return "The base of the plate on training days."
        case .lowCalVolume: return "Fullness for few calories — unlimited on a cut."
        case .proteins: return "Every meal. The floor that never moves."
        case .fats: return "Hormones and satiety — measured, not avoided."
        }
    }

    var foods: [String] {
        switch self {
        case .simpleCarbs:
            return ["Bananas", "Honey", "Berries", "Plain milk", "Plain yogurt", "Tomatoes", "Bell peppers"]
        case .complexCarbs:
            return ["Rice", "Oats", "Quinoa", "Beans", "Lentils", "Sweet potato", "Squash", "Peas", "Corn", "Potatoes"]
        case .lowCalVolume:
            return ["Broccoli", "Leafy greens", "Apples", "Pears", "Berries", "Watermelon", "Cucumber", "Brussels sprouts", "Cauliflower"]
        case .proteins:
            return ["Tuna", "Salmon", "Pork loin", "Sardines", "Greek yogurt", "Chicken breast", "Cod", "Flounder", "Tenderloin", "Sirloin", "Flank steak", "Cottage cheese", "Skim milk", "Whole eggs", "Egg whites"]
        case .fats:
            return ["Avocado", "Salmon", "Mackerel", "Sardines", "Tuna", "Nuts", "Seeds", "Plant oils"]
        }
    }
}

/// A day's macro plan for one body weight and goal: calories from the
/// goal's multiplier, grams from the split, with the protein floor
/// applied and carbs taking up the difference so the grams still add up
/// to the calories.
struct NutritionPlan: Equatable {
    var goal: NutritionGoalMode
    var weightLb: Int
    var calories: Int
    var carbGrams: Int
    var proteinGrams: Int
    var fatGrams: Int
    /// True when 0.85 g/lb beat the split's protein share.
    var proteinFloorApplied: Bool

    static let proteinFloorPerLb = 0.85

    static func make(weightLb: Double, goal: NutritionGoalMode) -> NutritionPlan {
        let calories = Int(((weightLb * goal.caloriesPerLb) / 50).rounded()) * 50
        let split = goal.split
        let splitProtein = Double(calories) * Double(split.protein) / 100 / 4
        let floorProtein = weightLb * proteinFloorPerLb
        let proteinFloorApplied = floorProtein > splitProtein
        let protein = Int((max(splitProtein, floorProtein) / 5).rounded()) * 5
        let fat = Int((Double(calories) * Double(split.fat) / 100 / 9 / 5).rounded()) * 5
        let carbs = max(0, Int(((Double(calories) - Double(protein * 4) - Double(fat * 9)) / 4 / 5).rounded()) * 5)
        return NutritionPlan(goal: goal, weightLb: Int(weightLb.rounded()), calories: calories,
                             carbGrams: carbs, proteinGrams: protein, fatGrams: fat,
                             proteinFloorApplied: proteinFloorApplied)
    }

    /// One spoken-ready line.
    var summary: String {
        "\(goal.rawValue): body weight \(weightLb) lb × \(goal.caloriesPerLb.formatted()) = \(calories) calories, split \(goal.splitLabel) → \(carbGrams) g carbs, \(proteinGrams) g protein, \(fatGrams) g fat."
    }
}

struct FriendActivity: Identifiable, Hashable {
    var id = UUID()
    var title: String
}

struct Challenge: Identifiable, Hashable {
    var id = UUID()
    var title: String
    var detail: String
}

struct RecoverySnapshot: Hashable {
    var score: Int
    var status: RecoveryStatus
    var reason: String
    var sleepHours: Double
    var energy: Int
    var soreness: Int
    var mood: Int
    var pain: Bool
    var previousSessionFeedback: WorkoutFeedbackOption?
}

struct PlanAdjustment: Identifiable, Hashable {
    var id = UUID()
    var title: String
    var body: String
    var reasons: [PlanAdjustmentReason]
    var recommendation: String
}

struct GoalTranslation: Identifiable, Hashable {
    var id = UUID()
    var goal: String
    var weeklyActions: [String]
}

struct PersonalRule: Identifiable, Hashable {
    var id = UUID()
    var title: String
    var detail: String
}

struct RoadmapPhase: Identifiable, Hashable {
    var id = UUID()
    var title: String
    var focus: String
    var weeklyActions: [String]
    var milestone: String
    var status: String
}

struct FrictionInsight: Identifiable, Hashable {
    var id = UUID()
    var title: String
    var summary: String
    var recommendation: String
}

struct AthletePatternInsight: Identifiable, Hashable {
    var id = UUID()
    var title: String
    var detail: String
    var badge: String
    var systemImage: String
}

struct PainReport: Identifiable, Hashable {
    var id = UUID()
    var area: String
    var severity: Int
    var triggerExercise: String
    var alternative: String
    var note: String
}

struct WhyThisMatters: Identifiable, Hashable {
    var id = UUID()
    var title: String
    var detail: String
}

struct BodyEducationTopic: Identifiable, Hashable {
    var id = UUID()
    var title: String
    var subtitle: String
    var bullets: [String]
    var icon: String
}

struct MiniQuiz: Identifiable, Hashable {
    var question: String
    var options: [String]
    var correctIndex: Int
    var explanation: String
    var rewardXP: Int

    /// Stable across launches — completion state is persisted by this id.
    /// (A per-launch UUID made saved progress impossible to reattach.)
    var id: String { question }
}

struct SmartNotificationItem: Identifiable, Hashable {
    var id = UUID()
    var type: String
    var title: String
    var message: String
    var priority: NotificationPriority
    var action: String
}

struct PhotoProgressSnapshot: Hashable {
    var frontLabel: String
    var sideLabel: String
    var backLabel: String
    var reminder: String
    var aiPreview: String
    var postureNote: String
    var compositionTrend: String
    var privacyNote: String
}

struct SportMetric: Identifiable, Hashable {
    var id = UUID()
    var label: String
    var value: String
}

struct AvatarProfile: Hashable {
    var style: AvatarStyle
    var gear: String
    var outfit: String
    var background: String
    var badgeFrame: String
    var levelGlow: String
}

struct BannerProfile: Hashable {
    var preset: BannerPreset
    var title: String
    var subtitle: String
}

struct ProfileBadge: Identifiable, Hashable {
    /// Stable identity (audit 11, P2-13): a stored UUID regenerated on
    /// every computed read handed ForEach fresh identities per render.
    /// idSuffix disambiguates same-title-same-detail twins (audit 12,
    /// P2-15 — two expired challenges with equal scores).
    var id: String { title + "|" + detail + "|" + idSuffix }
    var title: String
    var detail: String
    var icon: String
    /// False = a visible goal (Apple benchmark A3): outline style, unlock
    /// condition in `detail`, nothing pretends to be won.
    var earned: Bool = true
    var idSuffix: String = ""
}

struct PersonalRecord: Identifiable, Hashable {
    var id = UUID()
    var title: String
    var value: String
    var detail: String
}

struct TransformationMilestone: Identifiable, Hashable {
    var id = UUID()
    var title: String
    var date: String
    var detail: String
}

struct FeaturedWorkout: Identifiable, Hashable {
    var id = UUID()
    var title: String
    var subtitle: String
}

struct FeaturedVideo: Identifiable, Hashable {
    var id = UUID()
    var title: String
    var subtitle: String
}

struct CommunityStat: Identifiable, Hashable {
    var id = UUID()
    var label: String
    var value: String
}

struct ProgressPost: Identifiable, Hashable {
    var id = UUID()
    var author: String
    var avatar: String
    var role: AppRole = .client
    var createdAt: Date = .now
    var headline: String = ""
    var rank: String = ""
    var timeAgo: String = "Now"
    var title: String
    var detail: String
    var tags: [String] = []
    var reactions: Int
    var comments: Int
    var commentHighlights: [NetworkComment] = []
}

struct PartnerSessionPostDraft: Identifiable, Hashable {
    var id = UUID()
    var workoutTitle: String
    var sport: SportFocus
    var partnerName: String
    var partnerAvatar: String
    var partnerSport: SportFocus
    var mode: PartnerWorkoutMode
    var durationMinutes: Int
    var xpBonus: Int
    var partnerStreak: Int
    var miniChallenge: String
    var detail: String
    var tags: [String]
    var createdAt: Date = .now
}

struct NetworkComment: Identifiable, Hashable {
    var id = UUID()
    var author: String
    var avatar: String
    var role: AppRole
    var headline: String
    var rank: String
    var text: String
    var likes: Int
}

struct TrainingGroupPreview: Identifiable, Hashable {
    var id = UUID()
    var title: String
    var detail: String
    var memberCount: Int
}

struct NetworkConnectionSuggestion: Identifiable, Hashable {
    var id = UUID()
    var name: String
    var avatar: String
    var role: AppRole
    var headline: String
    var rank: String
    var mutualContext: String
}

struct NetworkProfilePreview: Identifiable, Hashable {
    var id = UUID()
    var name: String
    var handle: String
    var avatar: String
    var role: AppRole
    var headline: String
    var rank: String
    var mutualContext: String
    var featuredTags: [String]
}

enum PartnerWorkoutMode: String, CaseIterable, Identifiable {
    case live = "Live sync"
    case async = "Async check-in"
    case challenge = "Mini challenge"

    var id: String { rawValue }

    var subtitle: String {
        switch self {
        case .live:
            return "Start the same session together and share updates."
        case .async:
            return "Finish when you can and keep each other accountable."
        case .challenge:
            return "Add a small shared challenge on top of the workout."
        }
    }
}

struct WorkoutPartner: Identifiable, Hashable {
    var id = UUID()
    var name: String
    var sport: SportFocus
    var linkedAthleteID: UUID?
    var vibe: String
    var status: String
    var streak: Int
    var favoriteSession: String
}

struct PartnerWorkoutPlan: Hashable {
    var headline: String
    var detail: String
    var xpBonus: Int
    var miniChallenge: String
}

struct LeaderboardEntry: Identifiable, Hashable {
    var id = UUID()
    var category: String
    var leader: String
    var detail: String
}

struct SubscriptionPlan: Identifiable, Hashable {
    var id = UUID()
    var title: String
    var price: String
    var audience: String
    var features: [String]
}

struct SubscriptionStatus: Hashable {
    var currentPlan: String
    var isPremiumUnlocked: Bool
    var profileIsFree: Bool
    var note: String
}

struct UnlockableItem: Identifiable, Hashable {
    var id = UUID()
    var title: String
    var detail: String
}

// MARK: - Coach ↔ client training commerce (v2)

/// A paid training offering a coach sells — one session or a multi-session pack.
/// `priceValue` is the source of truth for earnings math; `price` is the display
/// string. Becomes a Firestore document under the coach once payments ship.
struct TrainingPackage: Identifiable, Hashable {
    var id = UUID()
    var title: String
    var summary: String
    var priceValue: Double
    var sessionCount: Int
    var minutesPerSession: Int
    var isPopular: Bool = false

    var price: String {
        let whole = priceValue.rounded()
        let text = whole == priceValue ? String(Int(whole)) : String(format: "%.2f", priceValue)
        return "$\(text)"
    }

    var perSessionLabel: String {
        guard sessionCount > 1 else { return "\(minutesPerSession) min session" }
        let each = priceValue / Double(sessionCount)
        return "\(sessionCount) sessions · $\(Int(each.rounded())) each"
    }
}

enum BookingStatus: String, Codable, CaseIterable, Identifiable {
    case requested = "Requested"
    case confirmed = "Confirmed"
    case completed = "Completed"
    case cancelled = "Cancelled"

    var id: String { rawValue }
}

enum PaymentStatus: String, Codable, CaseIterable, Identifiable {
    case unpaid = "Unpaid"
    case pending = "Pending"
    case paid = "Paid"
    case refunded = "Refunded"

    var id: String { rawValue }
}

/// A client's booked training appointment with a coach. The payment side stays
/// `pending` until the real Stripe/Apple Pay flow lands; the booking itself is
/// real so the schedule and earnings views have something true to render.
struct SessionBooking: Identifiable, Hashable {
    var id = UUID()
    /// Who is being booked (shown on the client's "My Sessions").
    var coachName: String
    /// Who booked it (shown on the coach's incoming requests). Empty for a
    /// booking the current user made themselves.
    var clientName: String = ""
    var packageTitle: String
    var day: String
    var time: String
    /// The availability slot this booking reserved, so cancelling reopens
    /// exactly that slot (not a same-day/time collision).
    var slotID: UUID? = nil
    var priceValue: Double
    var status: BookingStatus = .requested
    var paymentStatus: PaymentStatus = .pending

    var price: String {
        "$\(Int(priceValue.rounded()))"
    }
}

/// One bookable time on a coach's calendar. `isOpen == false` once taken.
struct AvailabilitySlot: Identifiable, Hashable {
    var id = UUID()
    var day: String
    var time: String
    var isOpen: Bool = true
}

/// What a personal appointment is for — drives the icon and the picker label.
enum AppointmentKind: String, Codable, CaseIterable, Identifiable {
    case session
    case checkIn
    case assessment
    case custom

    var id: String { rawValue }

    var title: String {
        switch self {
        case .session: return "Session"
        case .checkIn: return "Check-in"
        case .assessment: return "Assessment"
        case .custom: return "Custom"
        }
    }

    var systemImage: String {
        switch self {
        case .session: return "figure.strengthtraining.traditional"
        case .checkIn: return "checkmark.bubble"
        case .assessment: return "list.clipboard"
        case .custom: return "calendar"
        }
    }
}

/// A REAL personal schedule item that syncs per account (one Firestore doc
/// each under users/{uid}/appointments/{id}). Deliberately not a booking:
/// there is no live coach↔client account link yet, so this is the honest
/// scope — "my schedule", visible only to me. `withName` is free text (or a
/// managed-client name) precisely because the other person may not be a
/// Morphe account.
struct Appointment: Identifiable, Codable, Hashable {
    /// Status values — plain strings so the Firestore docs stay hand-readable.
    static let statusScheduled = "scheduled"
    static let statusCompleted = "completed"
    static let statusCancelled = "cancelled"

    var id: String = UUID().uuidString
    var title: String
    var notes: String = ""
    var date: Date
    var durationMinutes: Int = 60
    var kind: AppointmentKind = .session
    /// Who it's with — free text, or a managed client's name on the coach side.
    var withName: String = ""
    /// Linked account/connection id when the person was PICKED from known
    /// people rather than typed. Optional: older records decode as unlinked.
    var withUid: String? = nil
    /// "client"/"coach" — which role created it (AppRole rawValue).
    var createdByRole: String = ""
    var status: String = Appointment.statusScheduled

    var isScheduled: Bool { status == Appointment.statusScheduled }
    var endDate: Date { date.addingTimeInterval(TimeInterval(durationMinutes) * 60) }
}

/// The finish sequence (feedback audit 2026-10-16, F2): the publish
/// moment after a session saves — summary rises, the streak lands, PRs
/// stamp in one by one. One sequence, not a banner.
struct FinishSequenceMoment: Identifiable, Hashable {
    var id = UUID()
    var workoutName: String
    /// "2 of 5 exercises · 3 sets · 12 min"
    var statsLine: String
    var shortDay: Bool
    var streakDays: Int
    /// Real records only (a first lift is a baseline).
    var prNames: [String]
}

struct CelebrationMoment: Identifiable, Hashable {
    var id = UUID()
    var title: String
    var detail: String
    var symbol: String
}

/// The one ESCALATED moment — a full-screen stamp reserved for the facts
/// that outrank the banner (a new PR, a finished program). Same honesty
/// contract as the banner: every line is a logged fact.
struct RecordStampMoment: Identifiable, Hashable {
    var id = UUID()
    /// "NEW RECORD" / "PROGRAM COMPLETE" — the mono tracked kicker.
    var kicker: String
    /// Exercise or program name.
    var headline: String
    /// The big number line ("225 LB" / "8 WEEKS").
    var valueLine: String
    /// "UP FROM 205 LB" / "EVERY SESSION LOGGED" — "" hides the row.
    var detailLine: String
    /// Non-nil makes the stamp shareable as a PR story card.
    var prCard: PRShareCardData?
}

struct LessonCard: Identifiable, Hashable {
    var title: String
    var subtitle: String
    var detail: String

    /// Stable across launches, same reason as MiniQuiz.id.
    var id: String { title }
}

struct ProfileShowcase: Hashable {
    var displayName: String
    var username: String
    var bio: String
    var avatar: AvatarProfile
    var banner: BannerProfile
    var theme: ThemePreset
    var accentPalette: AccentPalette
    /// The hex behind AccentPalette.custom ("" = never picked → gold).
    var customAccentHex: String = ""
    var currentPhase: String
    var coachingTone: CoachingTone
    var badges: [ProfileBadge]
    var personalRecords: [PersonalRecord]
    var milestones: [TransformationMilestone]
    var communityStats: [CommunityStat]
    var featuredWorkouts: [FeaturedWorkout]
    var featuredVideos: [FeaturedVideo]
    var aiPerformanceBio: String
}

struct OnboardingDraft: Hashable {
    /// Morphe is for people 13 and older (privacy policy).
    static let minimumAge = 13
    static func age(fromBirthYear year: Int, now: Date = .now) -> Int {
        Calendar.current.component(.year, from: now) - year
    }
    var birthYearIsValid: Bool {
        guard let year = birthYear else { return false }
        let current = Calendar.current.component(.year, from: .now)
        return year >= current - 110 && year <= current
    }
    var meetsMinimumAge: Bool {
        guard let year = birthYear, birthYearIsValid else { return false }
        return Self.age(fromBirthYear: year) >= Self.minimumAge
    }

    var accountType: AppRole = .client
    var name: String = ""
    /// The @username picked (and reserved in the directory) during onboarding.
    var username: String = ""
    var gender: GenderOption = .male
    /// True once the user explicitly answers the gender step — the profile only
    /// records gender when it was actually asked and answered, never a default.
    var genderChosen: Bool = false
    // Coach onboarding answers (coach accounts only).
    var coachTenure: CoachTenureOption = .growing
    var coachRoster: CoachRosterOption = .justStarting
    var age: Int = 25
    /// Asked neutrally on the first step (age gate, fix wave 2026-10-13);
    /// becomes the profile age. Nil until answered.
    var birthYear: Int? = nil
    var height: String = ""
    var weight: String = ""
    // Empty on purpose (UX test 2026-09-30): "1 of 5 selected" before
    // the user touched anything pre-answered their goals — off-brand for
    // an app whose law is nothing invented. primaryGoal still falls back.
    var selectedGoals: [FitnessGoalOption] = []
    var physicalGoalTarget: String = ""
    var weightGoalTarget: String = ""
    var goalDeadline: String = ""
    var experienceLevel: ExperienceLevelOption = .beginner
    var selectedSports: [SportFocus] = [.generalFitness]
    var selectedTrainingStyles: [TrainingStyleOption] = [.conditioning]
    var injuries: String = ""
    var equipment: String = ""
    /// Meal-prep habit + whether they'd like to start (asked when they don't
    /// prep yet). Feeds nutrition guidance.
    var mealPrepFrequency: MealPrepOption = .occasionally
    var mealPrepInterested: Bool = false
    /// Required consent on the review step — completing onboarding with this
    /// true ALSO satisfies the standalone terms gate.
    var agreedToTerms: Bool = false
    var trainingDaysPerWeek: Int = 3
    var preferredWorkoutLength: Int = 30
    var coachingTone: CoachingTone = .direct
    var confidence: ConfidenceLevel = .maybe
    var biggestObstacle: ObstacleOption = .time
    var theme: ThemePreset = .morpheBlackBlue
    var accentPalette: AccentPalette = .morpheDark
    var avatarStyle: AvatarStyle = .cleanStarter

    var goal: FitnessGoalOption {
        // No goal picked → Build consistency, which is also the first
        // phase (audit 2026-10-15: the review showed "Improve conditioning"
        // — a goal nobody chose — and promised conditioning sessions).
        get { selectedGoals.first ?? .buildConsistency }
        set { selectedGoals = [newValue] }
    }

    var sport: SportFocus {
        get { selectedSports.first ?? .generalFitness }
        set { selectedSports = [newValue] }
    }
}

struct ClientProfile: Hashable {
    var id: UUID = UUID()
    var name: String
    var gender: GenderOption = .male
    /// Meal-prep habit from onboarding ("" = never asked, pre-dates the step).
    var mealPrepHabit: String = ""
    var mealPrepInterested: Bool = false
    var welcomeMessage: String
    var oneLiner: String
    var coachName: String
    var coachStatus: String
    var coachPreview: String
    var sportMode: SportFocus
    var selectedSports: [SportFocus]
    var selectedTrainingStyles: [TrainingStyleOption]
    var health: HealthScoreSummary
    var level: LevelProgress
    var adherence: Int
    var networkRank: String = "Builder"
    /// The weekly training-day target the user chose in onboarding; drives
    /// the "Consistency x/y" denominator instead of a hardcoded 5.
    var trainingDaysPerWeek: Int = 3
    var goal: String
    var selectedGoals: [String]
    var physicalGoalTarget: String
    var weightGoalTarget: String
    var goalDeadline: String
    var fitnessLevel: String
    var limitations: String
    var equipment: String
    /// Comma-joined DietOption / WeaknessOption titles, set in Profile → Your
    /// Details ("" = not set). Both read by the AI prompt.
    var diet: String = ""
    var weaknesses: String = ""
    /// Free-text body metrics, user-editable from Profile ("5'10\"", "178 cm").
    var height: String = ""
    var bodyWeight: String = ""
    /// Goal body weight, free text like bodyWeight ("175", "80 kg"); and
    /// age in years (0 = not set). Both edited in Profile → Your Details
    /// (Lucas 2026-10-10), never defaulted.
    var goalWeight: String = ""
    var age: Int = 0
    var currentProgram: String
    // "Morphe", not "Morphe AI": the starting plan comes from deterministic
    // onboarding heuristics — calling it AI was an overclaim.
    var planCreatedBy: String = "Morphe"
    var aiTodayInsight: AIInsight
    var aiProgressInsight: AIInsight
    var aiNutritionInsight: AIInsight
}

struct CoachProfile: Hashable {
    var id = UUID()
    var name: String
    var username: String = "coachmarcus"
    var specialty: String
    var headline: String = "Consistency-first coaching for real life and real sport."
    var networkRank: String = "Coach Leader"
    var sports: [SportFocus]
    var selectedTrainingStyles: [TrainingStyleOption] = [.conditioning, .strength]
    var selectedGoals: [String] = ["Build consistency", "Improve sport performance"]
    var activeClients: Int
    var groups: [String]
    var playbooks: [String]
}

struct CoachOverview: Hashable {
    var activeClients: Int
    var atRiskClients: Int
    var checkInsNeeded: Int
    var sessionsToday: Int
    var painFlags: Int
    var messagesNeedingResponse: Int
    var alerts: [String]
    var wins: [String]
    var todaySessions: [String]
    var sportAlerts: [String]
    var weeklySummary: String
    var insight: AIInsight
}

struct ClientTimelineEvent: Identifiable, Hashable {
    var id = UUID()
    var title: String
    var detail: String
}

struct ProgramCompliance: Hashable {
    var score: Int
    var summary: String
}

struct TrainingLoadInsight: Hashable {
    var status: String
    var summary: String
    var recommendation: String
}

struct MovementQualityScore: Hashable {
    var score: Int
    var summary: String
}

struct PerformanceTest: Identifiable, Hashable {
    var id = UUID()
    var name: String
    var sport: SportFocus
    var category: String
    var result: String
    var unit: String
    var previousResult: String
    var trend: String
}

struct AthleteReport: Identifiable, Hashable {
    var id = UUID()
    var athleteID: UUID
    var week: String
    var compliance: String
    var readiness: String
    var performance: String
    var mainWin: String
    var mainIssue: String
    var coachNotes: String
    var aiSummary: String
    var nextFocus: String
}

struct VideoTimestampComment: Identifiable, Hashable {
    var id = UUID()
    var time: String
    var note: String
}

struct VideoReviewClip: Identifiable, Hashable {
    var id = UUID()
    var athleteID: UUID
    var sport: SportFocus
    var title: String
    var thumbnail: String
    var date: String
    var movementQualityScore: Int
    var timestampComments: [VideoTimestampComment]
    var aiFeedback: String
}

struct DrillReference: Identifiable, Hashable {
    var id = UUID()
    var name: String
    var sport: SportFocus
    var skillCategory: String
    var equipment: String
    var difficulty: DemoDifficulty
    var instructions: [String]
    var cues: String
    var commonMistakes: String
    var progression: String
    var regression: String
    var scoreMetric: String
    var whyThisMatters: String
}

struct SessionSection: Identifiable, Hashable {
    var id = UUID()
    var title: String
    var detail: String
    var duration: String
}

struct SportSession: Identifiable, Hashable {
    var id = UUID()
    var name: String
    var sport: SportFocus
    var type: SessionType
    var sections: [SessionSection]
    var duration: Int
    var intensity: String
    var assignedTo: [String]
}

struct TrainingBlockPhase: Identifiable, Hashable {
    var id = UUID()
    var title: String
    var weeks: String
    var focus: String
}

struct TeamMemberAttendance: Identifiable, Hashable {
    var id = UUID()
    var athleteName: String
    var status: AttendanceStatus
    var note: String
}

struct TeamGroup: Identifiable, Hashable {
    var id = UUID()
    var name: String
    var sport: SportFocus
    var programName: String
    var readinessAverage: Int
    var leaderboard: [String]
    var groupMessage: String
    var attendance: [TeamMemberAttendance]
}

struct CoachPlaybook: Identifiable, Hashable {
    var id = UUID()
    var title: String
    var philosophy: String
    var warmUps: [String]
    var drills: [String]
    var templates: [String]
    var recoveryProtocols: [String]
    var progressionRules: [String]
}

struct LeadRecord: Identifiable, Hashable {
    var id = UUID()
    var name: String
    var sport: SportFocus
    var status: LeadStatus
    var note: String
    var aiSuggestion: String
}

struct CoachAnalytics: Hashable {
    var clientRetention: Int
    var averageCompliance: Int
    var averageProgress: String
    var dropOffRate: Int
    var painFlags: Int
    var messageResponseRate: Int
    var programSuccessRate: Int
    var sessionCompletion: Int
    var groupAttendance: Int
    var insight: String
}

struct AvailabilityConstraints: Hashable {
    var availableDays: [String]
    var timeAvailable: String
    var equipmentAccess: String
    var location: String
    var schoolOrWork: String
    var practiceSchedule: String
    var gameSchedule: String
    var travelSchedule: String
    var injuryLimitations: String
    var sleepSchedule: String
    var stressLevel: String
}

struct EventPrepPlan: Hashable {
    var title: String
    var countdown: String
    var weeklyFocus: String
    var readiness: String
    var taperPlan: String
    var weightTarget: String
    var recoveryPriority: String
    var coachAlert: String
}

// MARK: - Coach-managed clients (pre-signup)

/// Lifecycle of a coach-created client profile: it starts unclaimed (the coach
/// logs training against it) and becomes claimed the moment the real person
/// signs up and enters the invite code — at which point the history transfers
/// into their own account.
enum ManagedClientStatus: String, Codable {
    case unclaimed
    case claimed
}

/// A client profile the coach created for someone who doesn't have a Morphe
/// account yet. Deliberately lean — real fields only, no invented readiness
/// scores. `id` doubles as the shareable invite code (party-code alphabet) and
/// the Firestore document id; `athleteID` is the UUID coach-entered logs are
/// keyed to, so the claim import can re-key them to the new account.
/// One coach-assigned workout riding the managed-client doc as JSON —
/// program delivery, Tier 1 of the Trainerize benchmark. The workout is the
/// full runnable snapshot (the party wire shape reused), so the athlete's
/// Train tab can start it exactly as built, offline included.
struct WorkoutAssignment: Codable, Identifiable, Hashable {
    var id: String = UUID().uuidString
    var workout: PartyWorkoutSnapshot
    var scheduledFor: Date
    var scheduledLabel: String = ""
    var assignedAt: Date = .now
    var coachName: String = ""
}

struct ManagedClient: Identifiable, Codable, Hashable {
    var id: String
    var athleteID: UUID = UUID()
    var coachUid: String
    var coachName: String
    var name: String
    var email: String = ""
    var sport: SportFocus = .generalFitness
    var notes: String = ""
    var status: ManagedClientStatus = .unclaimed
    /// The uid of the account that claimed this profile ("" while unclaimed).
    /// Stamped server-side by the claim update; the coach needs it to open a
    /// real message thread with the athlete who claimed the code.
    var claimedByUid: String = ""
    var claimedByName: String = ""
    var createdAt: Date = .now
    var logs: [WorkoutLog] = []
    /// Coach-assigned workouts, newest first — delivered to the claimed
    /// athlete's Train tab.
    var assignments: [WorkoutAssignment] = []

    var isClaimed: Bool { status == .claimed }
    var lastLoggedAt: Date? { logs.map(\.completedAt).max() }
}

// MARK: - Real 1:1 messaging (coach ↔ claimed client)

/// One REAL Firestore-backed message thread between a coach and the athlete
/// who claimed one of their managed-client codes. `id` is deterministic —
/// "{coachUid}_{athleteUid}" — mirroring the connections scheme. Distinct
/// from the flag-gated demo `MessageThread`/`ThreadMessage` types on purpose.
struct MessageThreadSummary: Identifiable, Hashable {
    var id: String
    var coachUid: String
    var athleteUid: String
    var coachName: String
    var athleteName: String
    var lastMessage: String = ""
    var lastSender: String = ""
    var updatedAt: Date = .now

    /// The OTHER person's name from the given viewer's perspective.
    func counterpartName(for uid: String) -> String {
        uid == coachUid ? athleteName : coachName
    }
}

/// One immutable sent message inside a real thread.
struct ChatMessage: Identifiable, Hashable {
    var id: String
    var senderUid: String
    var text: String
    var sentAt: Date
}

// MARK: - Real community feed

/// One REAL Firestore-backed feed post (posts/{id}) — the For You surface.
/// Distinct from the flag-gated demo `ProgressPost` on purpose. `verified`
/// is an honest mirror: the rules only accept true when the server granted
/// users/{authorUid}.verified, so the blue seal here can't be self-minted.
struct FeedPost: Identifiable, Hashable {
    var id: String
    var authorUid: String
    var authorName: String
    var verified: Bool = false
    var text: String
    /// Optional workout attached to the win ("" = none), rendered as a pill.
    var workoutName: String = ""
    /// When non-empty this post is a repost: the original post's id + author,
    /// with `text` carrying the reposter's own commentary.
    var repostOfId: String = ""
    var repostOfAuthor: String = ""
    var createdAt: Date = .now
    /// Structured session stats — filled by auto-share from the real logged
    /// session, nil/empty on plain text posts. Rendered as a rich workout
    /// card; every number is a logged fact, never typed in.
    var durationMinutes: Int?
    var setCount: Int?
    var exerciseCount: Int?
    /// Exercise names that set a PR in this session (max 3 ride the post).
    var prNames: [String] = []
    /// The author's chosen accent palette rawValue ("" = default gold) —
    /// the identity color their bubbles and rows wear across Network.
    /// Self-declared style, not a data claim.
    var authorAccent: String = ""
    /// One-line author byline stamped at publish time from REAL profile
    /// facts (sport focus, live workout streak) — "Strength · 12-day
    /// streak". Derived, never typed, so it can't claim what wasn't logged.
    var authorHeadline: String = ""
    /// Written while the author's account was private — only their
    /// connections render it (2026-10-10).
    var authorPrivate: Bool = false
    /// Base64 JPEG attached from the capture camera ("" = text post).
    /// Kept small on purpose — the rules cap it at 90k characters (~64KB)
    /// so photo posts stay inside Spark's document and egress budgets.
    var imageB64: String = ""

    var hasImage: Bool { !imageB64.isEmpty }

    var isRepost: Bool { !repostOfId.isEmpty }
    var hasSessionStats: Bool {
        durationMinutes != nil || setCount != nil || exerciseCount != nil
    }
}

/// One comment on a real feed post — posts/{postId}/comments/{id}. Fetched
/// on expand; counts come from the fetched docs themselves (no forgeable
/// denormalized counters anywhere).
struct PostComment: Identifiable, Hashable {
    var id: String
    var postId: String
    var authorUid: String
    var authorName: String
    var text: String
    var createdAt: Date = .now
}

/// A multi-week structured program: one weekly session pattern (referencing
/// Discover catalog workouts BY NAME, tolerant of missing ones) repeated for
/// `weeks`, with an optional lighter deload week. The program supplies
/// STRUCTURE and sequencing; the per-exercise progression engine supplies
/// the numbers — nothing here fabricates a load.
struct TrainingProgram: Identifiable, Hashable, Codable {
    var id: String
    var name: String
    var summary: String
    var weeks: Int
    /// 1-based week trained lighter — the progression engine suggests ~10%
    /// off and says why.
    var deloadWeek: Int?
    /// Ordered session names for ONE week, resolved against the catalog.
    var weeklySessionNames: [String]

    var totalSessions: Int { weeks * weeklySessionNames.count }
}

/// Per-profile persisted program state. Progress advances on LOGGED
/// sessions, never on the calendar — a missed week just resumes.
struct ActiveProgramSnapshot: Codable {
    var programID: String
    var startedAt: Date
    var completedSessions: Int = 0
}

/// Everything the share-card image states — every field is a logged fact
/// (the card is the outward face of honest engineering; it never claims a
/// number the log can't back).
struct ShareCardData: Hashable {
    var workoutName: String
    var dateLabel: String
    var setCount: Int
    var exerciseCount: Int
    var minutes: Int
    var streak: Int
    var prNames: [String]
    /// "@username", or "" before a handle is claimed.
    var username: String
    /// "SETS" / "ROUNDS" / "SETS AND ROUNDS" — the card's count word.
    var unitLabel: String = "SETS"
}

/// A single PR as its own story card — the log's highest-emotion fact,
/// shareable on its own instead of riding inside the session card.
struct PRShareCardData: Hashable {
    var exerciseName: String
    /// Formatted in the user's display unit ("225 lb").
    var weightLabel: String
    /// The beaten record, or "" for a first record / when the prior top
    /// isn't known (the timeline shows standing records only — the card
    /// never invents an "up from" claim).
    var previousLabel: String
    var dateLabel: String
    var username: String
}

/// The schedule-aware streak as a story card.
struct StreakShareCardData: Hashable {
    var streak: Int
    var dateLabel: String
    var username: String
}

/// One completed Mon–Sun training week as story-card facts.
struct WeeklyRecapData: Hashable {
    /// "Jul 20 – Jul 26" — rides the card header where the date sits.
    var rangeLabel: String
    var sessions: Int
    var sets: Int
    var minutes: Int
    var prCount: Int
    var streak: Int
    var username: String
}

/// The compact, athlete-CONSENTED progress packet a coach sees for a
/// claimed client — users/{athleteUid}/coachShare/summary. The athlete's
/// device builds and pushes it; consent IS the document (it names the one
/// coach allowed to read, and toggling off deletes it). Every number is
/// derived from the athlete's real logs — the coach reads, never writes.
struct CoachShareSummary: Codable, Hashable {
    var coachUid: String
    var athleteName: String
    var updatedAt: Date = .now
    var streak: Int = 0
    var weeklySets: Int = 0
    var weeklyWorkouts: Int = 0
    var totalWorkouts: Int = 0
    var recentSessions: [SharedSession] = []
    var recentPRs: [SharedPR] = []
    /// Today's readiness in words ("" when no check-in today).
    var readinessNote: String = ""

    struct SharedSession: Codable, Hashable {
        var title: String
        var completedAt: Date
        var sets: Int
        var minutes: Int
        var feedback: String
    }

    struct SharedPR: Codable, Hashable {
        var name: String
        var weight: Double
        var unit: String
        var date: Date
    }
}

/// One row of the Find Athletes username search — a directory hit, nothing
/// more (profiles stay private until people choose to post).
/// One line in the Morphe chat (Lucas 2026-10-10): every account has a
/// conversation with Morphe — weekly reports from the user's own logs,
/// news about what shipped, and answers to questions. Stored per
/// profile, cloud-backed.
struct MorpheInboxItem: Identifiable, Hashable, Codable {
    enum Kind: String, Codable { case weeklyReport, news, question, answer }
    var id: String
    var kind: Kind
    var date: Date
    var title: String
    var body: String

    var isFromMorphe: Bool { kind != .question }
}

/// What shipped, in Morphe's voice, dated — every entry is a real build
/// (sourcing law). Newest first. Delivered once per entry.
enum MorpheNews {
    static let entries: [MorpheInboxItem] = [
        MorpheInboxItem(id: "news-2026-10-10-private", kind: .news, date: day(2026, 10, 10),
                        title: "Private or public — your call",
                        body: "Profile → Who can see you now has a private switch. Private means only your connections see your posts and can message you; on boards and challenges you keep your place and score, shown as \u{201C}Private athlete\u{201D}. Nothing is deleted or recomputed when you switch either way."),
        MorpheInboxItem(id: "news-2026-10-10-chat", kind: .news, date: day(2026, 10, 10),
                        title: "This chat",
                        body: "Every account has this conversation with me now. Each Monday I send your week in review from your own logs. I'll tell you here when something new ships. And you can ask me anything, any time."),
        MorpheInboxItem(id: "news-2026-10-10-build", kind: .news, date: day(2026, 10, 10),
                        title: "Build Workout",
                        body: "Train has a Build Workout card: build one yourself, answer a few questions and I build it with you from the library, or start a multi-week program."),
        MorpheInboxItem(id: "news-2026-10-10-people", kind: .news, date: day(2026, 10, 10),
                        title: "Quick Add and connect",
                        body: "The person-plus button is people: coaches and members on Morphe. Open an account, request to connect, message, or hide. Chats has a New message button. Humans only — no bots, no spam, no AI-written posts."),
        MorpheInboxItem(id: "news-2026-10-10-fuel", kind: .news, date: day(2026, 10, 10),
                        title: "Food check and the chart",
                        body: "Learn → Nutrition: scan a barcode or photograph a meal and I report where it comes from, how processed it is and what's in it, with sources. The chart shows your calories and split for lean out, maintain or bulk."),
        MorpheInboxItem(id: "news-2026-10-10-ranks", kind: .news, date: day(2026, 10, 10),
                        title: "Ranks and colors",
                        body: "Ten ranks, Rookie to General, climbed only by logged work. Each rank unlocks its own accent color — Morphe Dark Blue to start, platinum at Colonel, gold at General. The ladder is in Learn → The Code.")
    ]

    private static func day(_ y: Int, _ m: Int, _ d: Int) -> Date {
        Calendar(identifier: .gregorian).date(from: DateComponents(year: y, month: m, day: d, hour: 9)) ?? .now
    }
}

/// A connect request between two members (LinkedIn shape, Lucas
/// 2026-10-10): connectRequests/{fromUid_toUid}. Accepted = connected.
struct ConnectRequest: Identifiable, Hashable {
    var id: String
    var fromUid: String
    var toUid: String
    var fromName: String
    var toName: String
    /// pending · accepted · declined · removed
    var status: String
    var createdAt: Date

    func other(than uid: String) -> (uid: String, name: String) {
        uid == fromUid ? (toUid, toName) : (fromUid, fromName)
    }
}

/// One person on Quick Add: what the app really knows about them, merged
/// from the username directory, feed posts and creator content.
struct PersonCard: Identifiable, Hashable {
    var uid: String
    var name: String
    var username: String
    var headline: String
    var accentId: String
    var verified: Bool
    var isCoach: Bool
    /// Private account: only connections see posts, boards show no name.
    var isPrivate: Bool = false
    var id: String { uid }

    var displayName: String { name.isEmpty ? (username.isEmpty ? "Member" : "@\(username)") : name }
    var initial: String { String(displayName.trimmingCharacters(in: CharacterSet(charactersIn: "@")).prefix(1)).uppercased() }
}

struct AthleteSearchResult: Identifiable, Hashable {
    var username: String
    var uid: String
    var isPrivate: Bool = false

    var id: String { uid }
}

struct CoachClient: Identifiable, Hashable {
    var id = UUID()
    var name: String
    var age: Int
    var sport: SportFocus
    var position: String
    var goal: String
    var fitnessLevel: String
    var trainingAge: String
    var injuryHistory: [String]
    var limitations: [String]
    var equipment: [String]
    var weeklySchedule: [String]
    var competitionDate: String
    var recoveryScore: RecoverySnapshot
    var healthScore: Int
    var complianceScore: Int
    var readinessStatus: RecoveryStatus
    var risk: RiskLevel
    var statusText: String
    var currentProgram: String
    var notes: [String]
    var aiSummary: String
    var lastWorkout: String
    var coachNotes: String
    var nutritionNotes: String
    var adherenceSummary: String
    var timeline: [ClientTimelineEvent]
    var healthTrend: [DayScore]
    var weightTrend: [WeightPoint]
    var tests: [PerformanceTest]
    var reportCard: AthleteReport
    var movementQuality: MovementQualityScore
    var trainingLoad: TrainingLoadInsight
    var availability: AvailabilityConstraints
    var eventPrep: EventPrepPlan
    var programCompliance: ProgramCompliance
    var videoReviews: [VideoReviewClip]
}

struct CoachIntervention: Identifiable, Hashable {
    var id = UUID()
    var athleteID: UUID
    var athleteName: String
    var reason: String
    var riskLevel: RiskLevel
    var suggestedAction: String
    var status: String
}

enum CoachNextActionType: String, Hashable {
    case reviewAI
    case reviewBuddy
    case messageAthlete
    case assignRecovery
    case missedSessionNudge
    case partnerPrompt
    case askPainUpdate
    case praisePublicly
}

struct CoachNextActionRecommendation: Hashable {
    var title: String
    var detail: String
    var actionLabel: String
    var type: CoachNextActionType
}

struct CoachFollowUpRecommendation: Identifiable, Hashable {
    var id = UUID()
    var athleteID: UUID
    var athleteName: String
    var title: String
    var detail: String
    var actionLabel: String
    var type: CoachNextActionType
    var priority: Int
}

struct ProgramBuilderDraft: Hashable {
    var workoutName: String = "Custom Builder Session"
    var sport: SportFocus = .boxing
    var category: ProgramCategory = .conditioning
    var sessionType: SessionType = .boxingSession
    var goal: String = "Conditioning + skill quality"
    var difficulty: DemoDifficulty = .moderate
    var durationMinutes: Int = 40
    var equipment: String = "Gloves, timer, dumbbells"
    var exercises: [WorkoutExercise] = []
    var defaultSets: String = "3 sets"
    var defaultReps: String = "10 reps"
    var rpe: String = "7"
    var restTime: String = "90 sec"
    var coachNotes: String = "Keep instructions direct, calm, and easy to execute."
}

struct ThreadMessage: Identifiable, Hashable, Codable {
    var id = UUID()
    var sender: ChatSender
    var senderName: String
    var text: String
    var timestamp: String
}

struct MessageThread: Identifiable, Hashable {
    var id = UUID()
    var participant: String
    var sport: SportFocus
    var preview: String
    var isUnread: Bool
    var isGroupChat: Bool = false
    var messages: [ThreadMessage]
}

enum AthleteInboxQuickAction: String, CaseIterable, Identifiable {
    case reply = "Reply"
    case shareWorkout = "Share Workout"
    case askForSwap = "Ask for Swap"
    case confirmTomorrow = "Confirm Tomorrow"

    var id: String { rawValue }

    var systemImage: String {
        switch self {
        case .reply:
            return "arrowshape.turn.up.left.fill"
        case .shareWorkout:
            return "arrowshape.turn.up.right.fill"
        case .askForSwap:
            return "figure.strengthtraining.traditional"
        case .confirmTomorrow:
            return "calendar.badge.checkmark"
        }
    }
}

struct AthleteInboxThreadContext: Hashable {
    var badge: String
    var detail: String
    var priority: Int
    var quickActions: [AthleteInboxQuickAction]
}

struct OutreachSuggestion: Identifiable, Hashable {
    var id = UUID()
    var clientName: String
    var summary: String
    var suggestedMessage: String
}

struct MessageTemplate: Identifiable, Hashable {
    var id = UUID()
    var title: String
    var body: String
}

struct CoachPublicPraiseDraft: Identifiable, Hashable {
    var id = UUID()
    var athleteID: UUID
    var athleteName: String
    var title: String
    var body: String
    var contextLabel: String
    var tags: [String]
}

enum CoachOutreachShortcut: String, CaseIterable, Identifiable {
    case praise = "Quick Praise"
    case missedSession = "Missed-Session Nudge"
    case partner = "Partner Prompt"
    case recovery = "Recovery Reminder"

    var id: String { rawValue }

    var systemImage: String {
        switch self {
        case .praise:
            return "hands.clap.fill"
        case .missedSession:
            return "arrow.clockwise.circle.fill"
        case .partner:
            return "person.2.fill"
        case .recovery:
            return "heart.text.square.fill"
        }
    }
}

struct CalendarEvent: Identifiable, Hashable {
    var id = UUID()
    var day: String
    var time: String
    var title: String
    var detail: String
    var type: CalendarEventType
    var athleteID: UUID? = nil
    var groupID: UUID? = nil
    var attendance: [TeamMemberAttendance] = []
    var isComplete: Bool = false
}

struct CoachSessionLaunchRequest: Identifiable, Hashable {
    var id = UUID()
    var title: String
    var subtitle: String
    var preferredSport: SportFocus
    var athleteID: UUID? = nil
    var groupID: UUID? = nil
    var eventID: UUID? = nil
}

// MARK: - Weekly leaderboard + challenges (real multi-user competition)
//
// Every value here renders from real Firestore data written by real signed-in
// accounts — no seeded rows, no fabricated ranks. (The older `LeaderboardEntry`
// and `Challenge` structs above are demo-content types used by the community
// discovery mock cards; these are the live-backend replacements and keep
// distinct names so the demo surfaces stay untouched.)

/// One user's row on a weekly board — Firestore
/// leaderboards/{weekKey}/entries/{uid}. `verified` mirrors the server-granted
/// badge (users/{uid}.verified) as an honest trust signal; the rules refuse a
/// claimed badge the server never granted.
/// A board (Lucas 2026-10-10): a named group with its own 6-char code,
/// required to join — knowing the code is the invite, like parties and
/// challenges. Standings reset every ISO week under boards/{code}/weeks.
struct BoardGroup: Identifiable, Hashable, Codable {
    var code: String
    var name: String
    var hostUid: String
    var hostName: String
    var createdAt: Date
    var id: String { code }
}

struct WeeklyLeaderboardEntry: Identifiable, Hashable, Codable {
    var uid: String
    var name: String
    var verified: Bool
    /// Total sets logged this ISO week, derived from the user's own logs.
    var score: Int
    /// Workouts logged this ISO week.
    var workouts: Int
    var updatedAt: Date?
    /// Private account (2026-10-10): the row keeps its place and score;
    /// other members see "Private athlete" instead of the name. Optional
    /// so cached rows from before the flag still decode.
    var privateFlag: Bool? = nil

    var id: String { uid }
    var isPrivate: Bool { privateFlag ?? false }
}

/// What a challenge counts. Raw values are the Firestore wire strings.
enum ChallengeMetric: String, Codable, CaseIterable, Identifiable {
    case sets
    case workouts

    var id: String { rawValue }

    var label: String {
        switch self {
        case .sets: return "Sets"
        case .workouts: return "Workouts"
        }
    }

    /// Unit word for score lines ("Top: 41 sets").
    var unit: String { rawValue }
}

/// One member of a challenge — challenges/{code}/members/{uid}.
struct ChallengeMember: Identifiable, Hashable, Codable {
    var uid: String
    var name: String
    var verified: Bool
    var score: Int
    var updatedAt: Date?
    var privateFlag: Bool? = nil

    var id: String { uid }
    var isPrivate: Bool { privateFlag ?? false }
}

/// A code-joinable challenge — challenges/{code} plus its members
/// subcollection. The 6-char code doubles as the Firestore document id,
/// exactly like party join codes.
struct ChallengeSummary: Identifiable, Hashable, Codable {
    var code: String
    var hostUid: String
    var hostName: String
    var title: String
    var metric: ChallengeMetric
    var startsAt: Date
    var endsAt: Date
    var members: [ChallengeMember] = []

    var id: String { code }

    var isExpired: Bool { Date.now > endsAt }

    /// Whole days remaining, floored at zero — shown as "N days left".
    var daysLeft: Int {
        max(0, Int(ceil(endsAt.timeIntervalSince(.now) / 86_400)))
    }

    /// Highest member score, or nil while nobody has posted — the UI names
    /// the unlock instead of showing a fake zero-leader.
    var topMember: ChallengeMember? {
        members.max { lhs, rhs in
            lhs.score != rhs.score ? lhs.score < rhs.score : lhs.name > rhs.name
        }
    }
}

// MARK: - Creator Coach (2026-10-05)
//
// A free account type granted by hand: the person applies on the Morphe
// website, Lucas approves or declines, and users/{uid}.creator flips on the
// server. Nothing in the app can mint it (rules: keepsVerifiedHonest). An
// approved creator publishes workouts, coach notes and open challenges that
// every signed-in member can see; everything carries the author's name.

enum CreatorApplicationStatus: String {
    case none
    case pending
    case approved
    case declined
}

/// One exercise line of a published workout — library id plus the
/// prescription, so any member's app rebuilds it against its own library.
struct CreatorExercise: Hashable, Codable {
    var libraryID: String
    var name: String
    var sets: Int
    var reps: Int
    var restSeconds: Int?
}

/// A workout a creator published to Discover's "From Coaches" shelf.
struct CreatorWorkout: Identifiable, Hashable, Codable {
    var id: String
    var authorUid: String
    var authorName: String
    var authorHandle: String
    var name: String
    var focus: String
    var level: String
    var durationMinutes: Int
    var equipment: String
    var notes: String
    var exercises: [CreatorExercise]
    var publishedAt: Date
}

/// A short written piece from a creator — a technique note, a programming
/// idea, a reminder. Shown in Learn under "From Coaches".
struct CreatorNote: Identifiable, Hashable, Codable {
    var id: String
    var authorUid: String
    var authorName: String
    var authorHandle: String
    var title: String
    var body: String
    var createdAt: Date
}

/// A challenge a creator opened to everyone — the listing points at the
/// ordinary challenge doc; joining uses the same code path as a private one.
struct OpenChallengeListing: Identifiable, Hashable {
    var code: String
    var title: String
    var hostUid: String
    var hostName: String
    var metric: ChallengeMetric
    var endsAt: Date

    var id: String { code }
    var isExpired: Bool { Date.now > endsAt }
}

// MARK: - Food check (Lucas 2026-10-10)

/// NOVA processing groups, in the user's words. Group 2 is "culinary
/// ingredients" (oil, sugar, salt) — a kitchen ingredient, not a meal.
enum FoodProcessingClass: String, Codable, CaseIterable {
    case wholeFood, kitchenIngredient, processed, ultraProcessed, unknown

    init(nova: Int?) {
        switch nova {
        case 1: self = .wholeFood
        case 2: self = .kitchenIngredient
        case 3: self = .processed
        case 4: self = .ultraProcessed
        default: self = .unknown
        }
    }

    var title: String {
        switch self {
        case .wholeFood: return "Real food"
        case .kitchenIngredient: return "Kitchen ingredient"
        case .processed: return "Processed"
        case .ultraProcessed: return "Ultra-processed"
        case .unknown: return "Unknown"
        }
    }

    var novaGroup: Int? {
        switch self {
        case .wholeFood: return 1
        case .kitchenIngredient: return 2
        case .processed: return 3
        case .ultraProcessed: return 4
        case .unknown: return nil
        }
    }
}

enum FoodConfidence: String, Codable {
    case high, medium, low, unknown
}

enum FoodAdditiveConcern: String, Codable {
    case none, low, moderate, high, unknown
}

struct FoodAdditive: Codable, Equatable, Identifiable {
    var code: String
    var name: String
    var note: String
    var concern: FoodAdditiveConcern
    var id: String { code }
}

struct FoodSourceLink: Codable, Equatable, Identifiable {
    var title: String
    var url: String
    var id: String { url }
}

enum FoodCheckMethod: String, Codable {
    case barcode, photo, photoAndBarcode
}

/// One checked food: where it comes from, what's in it, how it's
/// processed, and the numbers — every field says how sure it is and
/// where it came from. Tolerant decoding so an older record never
/// breaks a newer build.
/// One thing on the plate as the photo read it (AI rebuild Wave 3,
/// 2026-10-15): a name, a portion RANGE in grams, and — once matched — a
/// row from the USDA library or Open Food Facts whose numbers replace
/// the model's guess. The user confirms the grams before anything logs.
struct FoodCheckItem: Codable, Equatable, Identifiable {
    var id = UUID()
    var name: String
    var gramsLow: Int
    var gramsHigh: Int
    var confidence: FoodConfidence = .unknown
    /// The model's own calorie range for its mid portion — used only
    /// when no database row matched, and always labelled an estimate.
    var kcalLow: Int?
    var kcalHigh: Int?
    /// The matched source row, when one was found.
    var matchName: String?
    var matchSource: String?
    var kcal100: Double?
    var protein100: Double?
    var carbs100: Double?
    var fat100: Double?

    init(id: UUID = UUID(), name: String, gramsLow: Int, gramsHigh: Int, confidence: FoodConfidence = .unknown) {
        self.id = id; self.name = name; self.gramsLow = gramsLow; self.gramsHigh = gramsHigh; self.confidence = confidence
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = (try? c.decodeIfPresent(UUID.self, forKey: .id)) ?? UUID()
        name = (try? c.decodeIfPresent(String.self, forKey: .name)) ?? ""
        gramsLow = (try? c.decodeIfPresent(Int.self, forKey: .gramsLow)) ?? 0
        gramsHigh = (try? c.decodeIfPresent(Int.self, forKey: .gramsHigh)) ?? 0
        confidence = (try? c.decodeIfPresent(FoodConfidence.self, forKey: .confidence)) ?? .unknown
        kcalLow = try? c.decodeIfPresent(Int.self, forKey: .kcalLow)
        kcalHigh = try? c.decodeIfPresent(Int.self, forKey: .kcalHigh)
        matchName = try? c.decodeIfPresent(String.self, forKey: .matchName)
        matchSource = try? c.decodeIfPresent(String.self, forKey: .matchSource)
        kcal100 = try? c.decodeIfPresent(Double.self, forKey: .kcal100)
        protein100 = try? c.decodeIfPresent(Double.self, forKey: .protein100)
        carbs100 = try? c.decodeIfPresent(Double.self, forKey: .carbs100)
        fat100 = try? c.decodeIfPresent(Double.self, forKey: .fat100)
    }

    var isMatched: Bool { kcal100 != nil }
    /// The middle of the portion range — the default the user adjusts.
    var gramsMid: Int { max(1, (gramsLow + gramsHigh) / 2) }

    /// Calories, protein, carbs, fat for a portion: from the matched row
    /// when there is one, else the model's mid estimate scaled to the
    /// grams (calories only — macros unknown).
    func totals(grams: Int) -> (calories: Int, protein: Int, carbs: Int, fat: Int)? {
        let f = Double(grams) / 100
        if let kcal100 {
            return (Int((kcal100 * f).rounded()), Int(((protein100 ?? 0) * f).rounded()),
                    Int(((carbs100 ?? 0) * f).rounded()), Int(((fat100 ?? 0) * f).rounded()))
        }
        guard let kcalLow, let kcalHigh, gramsMid > 0 else { return nil }
        let perGram = Double(kcalLow + kcalHigh) / 2 / Double(gramsMid)
        return (Int((perGram * Double(grams)).rounded()), 0, 0, 0)
    }
}

struct FoodCheckRecord: Codable, Equatable, Identifiable {
    var id = UUID()
    var date = Date()
    var method: FoodCheckMethod = .barcode
    /// What the model saw: food, drink, package, notFood, unrecognized
    /// (empty on label-only and older records).
    var subject = ""
    var name = ""
    var brand = ""
    var barcode: String?
    var processing: FoodProcessingClass = .unknown
    var processingReason = ""
    var origin = ""
    var originConfidence: FoodConfidence = .unknown
    var healthRead = ""
    var nutriScore: String?
    var additives: [FoodAdditive] = []
    var gmoRead = ""
    /// high = likely GM-derived, low = unlikely, unknown = no basis.
    var gmoLikelihood: FoodConfidence = .unknown
    var ingredients = ""
    var calories: Int?
    var protein: Int?
    var carbs: Int?
    var fat: Int?
    var sugar: Int?
    var fiber: Int?
    var sodiumMg: Int?
    var servingNote = ""
    var sources: [FoodSourceLink] = []
    var verdict = ""
    var usedWebSearch = false
    var usedPhoto = false
    var loggedMealID: UUID?
    /// Photo reads (Wave 3): what was on the plate, each with a portion
    /// range and, when matched, a database row. Empty for label reads.
    var items: [FoodCheckItem] = []
    /// The honest spread for a plate estimate; nil for label numbers.
    var caloriesLow: Int?
    var caloriesHigh: Int?

    init() {}

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = (try? c.decodeIfPresent(UUID.self, forKey: .id)) ?? UUID()
        date = (try? c.decodeIfPresent(Date.self, forKey: .date)) ?? Date()
        method = (try? c.decodeIfPresent(FoodCheckMethod.self, forKey: .method)) ?? .barcode
        subject = (try? c.decodeIfPresent(String.self, forKey: .subject)) ?? ""
        name = (try? c.decodeIfPresent(String.self, forKey: .name)) ?? ""
        brand = (try? c.decodeIfPresent(String.self, forKey: .brand)) ?? ""
        barcode = try? c.decodeIfPresent(String.self, forKey: .barcode)
        processing = (try? c.decodeIfPresent(FoodProcessingClass.self, forKey: .processing)) ?? .unknown
        processingReason = (try? c.decodeIfPresent(String.self, forKey: .processingReason)) ?? ""
        origin = (try? c.decodeIfPresent(String.self, forKey: .origin)) ?? ""
        originConfidence = (try? c.decodeIfPresent(FoodConfidence.self, forKey: .originConfidence)) ?? .unknown
        healthRead = (try? c.decodeIfPresent(String.self, forKey: .healthRead)) ?? ""
        nutriScore = try? c.decodeIfPresent(String.self, forKey: .nutriScore)
        additives = (try? c.decodeIfPresent([FoodAdditive].self, forKey: .additives)) ?? []
        gmoRead = (try? c.decodeIfPresent(String.self, forKey: .gmoRead)) ?? ""
        gmoLikelihood = (try? c.decodeIfPresent(FoodConfidence.self, forKey: .gmoLikelihood)) ?? .unknown
        ingredients = (try? c.decodeIfPresent(String.self, forKey: .ingredients)) ?? ""
        calories = try? c.decodeIfPresent(Int.self, forKey: .calories)
        protein = try? c.decodeIfPresent(Int.self, forKey: .protein)
        carbs = try? c.decodeIfPresent(Int.self, forKey: .carbs)
        fat = try? c.decodeIfPresent(Int.self, forKey: .fat)
        sugar = try? c.decodeIfPresent(Int.self, forKey: .sugar)
        fiber = try? c.decodeIfPresent(Int.self, forKey: .fiber)
        sodiumMg = try? c.decodeIfPresent(Int.self, forKey: .sodiumMg)
        servingNote = (try? c.decodeIfPresent(String.self, forKey: .servingNote)) ?? ""
        items = (try? c.decodeIfPresent([FoodCheckItem].self, forKey: .items)) ?? []
        caloriesLow = try? c.decodeIfPresent(Int.self, forKey: .caloriesLow)
        caloriesHigh = try? c.decodeIfPresent(Int.self, forKey: .caloriesHigh)
        sources = (try? c.decodeIfPresent([FoodSourceLink].self, forKey: .sources)) ?? []
        verdict = (try? c.decodeIfPresent(String.self, forKey: .verdict)) ?? ""
        usedWebSearch = (try? c.decodeIfPresent(Bool.self, forKey: .usedWebSearch)) ?? false
        usedPhoto = (try? c.decodeIfPresent(Bool.self, forKey: .usedPhoto)) ?? false
        loggedMealID = try? c.decodeIfPresent(UUID.self, forKey: .loggedMealID)
    }

    var displayName: String { brand.isEmpty ? name : "\(brand) \(name)" }
    var isLogged: Bool { loggedMealID != nil }
    /// Label numbers from the database are per 100 g, not a portion.
    var isPer100g: Bool { servingNote.lowercased().hasPrefix("per 100 g") }
}

// MARK: - Connections (Profile → Connections, Lucas 2026-10-13)

enum SupplementTiming: String, Codable, CaseIterable, Identifiable {
    case morning = "Morning"
    case preWorkout = "Pre-workout"
    case postWorkout = "Post-workout"
    case withMeals = "With meals"
    case evening = "Evening"
    case anytime = "Any time"

    var id: String { rawValue }
}

struct SupplementItem: Codable, Identifiable, Hashable {
    var id = UUID()
    var name: String
    /// Free text as the user writes it ("5 g", "2 caps"); "" = not given.
    var dose: String
    var timing: SupplementTiming

    init(id: UUID = UUID(), name: String, dose: String, timing: SupplementTiming) {
        self.id = id
        self.name = name
        self.dose = dose
        self.timing = timing
    }

    // Tolerant decode: an unknown timing from a newer build reads as "Any time".
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = (try? c.decode(UUID.self, forKey: .id)) ?? UUID()
        name = (try? c.decode(String.self, forKey: .name)) ?? ""
        dose = (try? c.decode(String.self, forKey: .dose)) ?? ""
        timing = (try? c.decode(SupplementTiming.self, forKey: .timing)) ?? .anytime
    }
}

/// The user's stack plus which items were checked off on which day
/// (day key "yyyy-MM-dd" → item ids).
struct SupplementStack: Codable, Equatable {
    var items: [SupplementItem] = []
    var takenByDay: [String: [UUID]] = [:]

    init() {}

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        items = (try? c.decode([SupplementItem].self, forKey: .items)) ?? []
        takenByDay = (try? c.decode([String: [UUID]].self, forKey: .takenByDay)) ?? [:]
    }
}

/// A finished session's heart rate from a connected strap.
struct SessionHeartRate: Codable, Equatable {
    var date: Date
    var average: Int
    var peak: Int
}

// MARK: - Morphe remembers (AI rebuild Wave 4, 2026-10-15)

/// One durable thing Morphe keeps about the athlete, written after a
/// conversation (source "chat") or by the athlete ("you"). Shown, editable
/// and deletable in Profile; injected into every answer while the
/// "Morphe remembers" toggle is on. Never a model trained on the user —
/// a short file of facts in their own words.
struct AIMemoryItem: Codable, Equatable, Identifiable {
    enum Kind: String, Codable, CaseIterable {
        case fact, preference, injury, goal, worked, didnt
        var label: String {
            switch self {
            case .fact: return "Fact"
            case .preference: return "Preference"
            case .injury: return "Injury"
            case .goal: return "Goal"
            case .worked: return "What worked"
            case .didnt: return "What didn't"
            }
        }
    }
    var id = UUID()
    var kind: Kind = .fact
    var text: String
    var source: String = "chat"
    var date = Date()
    /// Written or edited by the athlete — extraction may never overwrite it.
    var userEdited = false

    init(id: UUID = UUID(), kind: Kind = .fact, text: String, source: String = "chat", date: Date = Date(), userEdited: Bool = false) {
        self.id = id; self.kind = kind; self.text = text; self.source = source; self.date = date; self.userEdited = userEdited
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = (try? c.decodeIfPresent(UUID.self, forKey: .id)) ?? UUID()
        kind = (try? c.decodeIfPresent(Kind.self, forKey: .kind)) ?? .fact
        text = (try? c.decodeIfPresent(String.self, forKey: .text)) ?? ""
        source = (try? c.decodeIfPresent(String.self, forKey: .source)) ?? "chat"
        date = (try? c.decodeIfPresent(Date.self, forKey: .date)) ?? Date()
        userEdited = (try? c.decodeIfPresent(Bool.self, forKey: .userEdited)) ?? false
    }
}

struct AIMemory: Codable, Equatable {
    static let capacity = 40
    var items: [AIMemoryItem] = []
    var updatedAt: Date?

    init() {}

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        items = (try? c.decodeIfPresent([AIMemoryItem].self, forKey: .items)) ?? []
        updatedAt = try? c.decodeIfPresent(Date.self, forKey: .updatedAt)
    }

    /// Applies an extraction: new items are added (duplicates by text are
    /// skipped), retired ids are removed unless the athlete wrote them,
    /// and the oldest non-user items go first when over capacity.
    mutating func apply(adding: [AIMemoryItem], retiring: [UUID]) {
        let retire = Set(retiring)
        items.removeAll { retire.contains($0.id) && !$0.userEdited }
        var existing = Set(items.map { $0.text.lowercased() })
        for item in adding where !item.text.isEmpty && !existing.contains(item.text.lowercased()) {
            items.append(item)
            existing.insert(item.text.lowercased())
        }
        while items.count > Self.capacity, let index = items.firstIndex(where: { !$0.userEdited }) {
            items.remove(at: index)
        }
        if items.count > Self.capacity { items.removeFirst(items.count - Self.capacity) }
        updatedAt = Date()
    }

    /// A short, launch-stable fingerprint so a rating can say which memory
    /// it was answered with (Swift's hashValue is seeded per process — an
    /// FNV-1a over the ids is the same on every launch).
    var fingerprint: String {
        var hash: UInt64 = 0xcbf29ce484222325
        for byte in items.map({ $0.id.uuidString }).joined().utf8 {
            hash ^= UInt64(byte)
            hash = hash &* 0x100000001b3
        }
        return String(hash, radix: 16)
    }
}

// MARK: - Work units (Lucas 2026-10-16)
//
// Cardio, combat and sport work is rounds, runs, intervals and laps with a
// clock — not "sets × reps". The console, the toasts and history all speak
// the exercise's own unit.
enum WorkUnit: String {
    case set, round, run, interval, lap, hold, flow

    var singular: String {
        switch self {
        case .set: return "Set"
        case .round: return "Round"
        case .run: return "Run"
        case .interval: return "Interval"
        case .lap: return "Lap"
        case .hold: return "Hold"
        case .flow: return "Flow"
        }
    }
    var plural: String { singular + "s" }
    /// Timed units run a countdown; a hold or a flow counts up.
    var countsDown: Bool { self != .set && self != .hold && self != .flow }
    var isTimed: Bool { self != .set }

    /// The unit for an exercise, from its name, its workout's catalog
    /// category, and whether the prescription is in seconds/minutes.
    static func infer(exerciseName: String, category: String, isTimed: Bool, seconds: Int) -> WorkUnit {
        let name = exerciseName.lowercased()
        let cat = category.lowercased()
        guard isTimed else { return .set }
        // Warm-ups, mobility and stretches are timed holds whatever the
        // workout's category (evening audit 2026-10-16, #5: "Arm Swings &
        // Circles" opened as "Round 1").
        // Mobility work moves — it's a flow, not a hold (night audit
        // 2026-10-16, #6); stretches and static positions stay holds.
        if ["arm swing", "arm circle", "leg swing", "hip circle", "mobility", "warm-up", "warm up", "foam roll",
            "cat-cow", "cat cow", "reset", "breathing", "shoulder circle", "ankle circle", "inchworm",
            "world's greatest", "flow"].contains(where: name.contains) { return .flow }
        if name.contains("stretch") { return .hold }
        // Machines first: "Bike: Sprint" is an interval, not a run.
        if ["bike", "spin", "cycl", "row", "erg", "ski", "elliptical", "cross-trainer", "stair"].contains(where: name.contains)
            && !["dumbbell row", "barbell row", "cable row", "bent-over", "bent over", "inverted"].contains(where: name.contains) { return .interval }
        if ["treadmill", "run", "jog", "sprint", "stride", "tempo", "walk"].contains(where: name.contains)
            && !name.contains("plank") { return .run }
        if ["swim", "pool", "lap"].contains(where: name.contains) { return .lap }
        let holdWords = ["plank", "hold", "wall sit", "dead hang", "grip hang", "carry", "hollow", "l-sit", "l sit",
                         "isometric", "handstand", "chair pose", "superman", "stretch", "bridge", "pose"]
        if holdWords.contains(where: name.contains) { return .hold }
        let roundCategories = ["boxing", "combat", "hiit", "conditioning", "functional", "crossfit", "dance", "aerobic",
                               "sport performance", "kettlebell", "calisthenics"]
        let roundWords = ["round", "bag", "shadow", "jump rope", "skip", "burpee", "battle", "sled", "mountain climber",
                          "box jump", "swing", "circuit", "metcon", "amrap", "emom", "tabata", "sparring", "pad", "drill", "agility", "ladder"]
        if roundCategories.contains(where: cat.contains) || roundWords.contains(where: name.contains) { return .round }
        return seconds >= 60 ? .round : .hold
    }

    /// "Round 3:00" / "Run 1:00" / "Hold 45s" — the stored per-set label.
    func label(seconds: Int) -> String {
        switch self {
        case .hold: return "Hold \(seconds)s"
        case .flow: return "Flow \(seconds)s"
        case .set: return ""
        default:
            return seconds >= 60 ? "\(singular) \(seconds / 60):\(String(format: "%02d", seconds % 60))" : "\(singular) \(seconds)s"
        }
    }

    /// Seconds the plan prescribes for a timed exercise ("3 min" → 180,
    /// "45 sec" → 45); 30 when it doesn't say.
    static func prescribedSeconds(for exercise: WorkoutExercise) -> Int {
        let text = exercise.reps.lowercased()
        if let range = text.range(of: #"(\d+)\s*min"#, options: .regularExpression),
           let minutes = Int(text[range].filter(\.isNumber)) { return min(max(minutes * 60, 5), 600) }
        let numbers = text.split(whereSeparator: { !$0.isNumber }).compactMap { Int($0) }
        if let last = numbers.last, last >= 5 { return min(last, 600) }
        return 30
    }

    /// The unit a stored label names ("Round 3:00" → .round); nil for a
    /// plain set.
    static func unit(ofLabel label: String) -> WorkUnit? {
        guard let first = label.split(separator: " ").first else { return nil }
        return WorkUnit(rawValue: String(first).lowercased())
    }

    /// "sets", "rounds", "runs", or "sets and rounds" for a mix — the word
    /// for a session's logged work, from its per-set labels.
    static func word(forLabels labels: [String]) -> String {
        let units = Set(labels.map { unit(ofLabel: $0) ?? .set }).map { ($0 == .hold || $0 == .flow) ? .set : $0 }
        let distinct = Array(Set(units))
        if distinct.isEmpty { return "sets" }
        if distinct.count == 1 { return distinct[0].plural.lowercased() }
        let names = distinct.sorted { $0.rawValue < $1.rawValue }.map { $0.plural.lowercased() }
        return names.dropLast().joined(separator: ", ") + " and " + names.last!
    }

    /// The same word for logged exercises, read from their "Set N: Round
    /// 3:00" notes.
    static func word(forLogged exercises: [LoggedExercise]) -> String {
        var labels: [String] = []
        for exercise in exercises {
            let count = exercise.repsPerSet?.count ?? 0
            for index in 0..<count {
                let marker = "Set \(index + 1): "
                let stored = exercise.note.components(separatedBy: " · ").first { $0.hasPrefix(marker) }
                    .map { String($0.dropFirst(marker.count)) } ?? ""
                labels.append(isTimedLabel(stored) ? stored : "")
            }
        }
        return word(forLabels: labels)
    }

    /// True for any stored label that means "the reps slot holds seconds".
    static func isTimedLabel(_ label: String) -> Bool {
        ["Hold ", "Flow ", "Round ", "Run ", "Interval ", "Lap "].contains(where: label.hasPrefix)
    }

    /// "5 sets" → "5 rounds", "1 sets" → "1 round" for the summary lines.
    func rewriteSetsText(_ text: String) -> String {
        guard self != .set else { return text }
        let count = Int(text.prefix(while: \.isNumber)) ?? 0
        let noun = count == 1 ? singular.lowercased() : plural.lowercased()
        return text.replacingOccurrences(of: "sets", with: noun)
            .replacingOccurrences(of: "set", with: noun)
    }

    /// The unit for a planned exercise, from its own prescription text.
    static func infer(for exercise: WorkoutExercise, category: String) -> WorkUnit {
        let reps = exercise.reps.lowercased()
        let timed = reps.contains("sec") || reps.contains("min") || reps.range(of: #"\d+\s*s\b"#, options: .regularExpression) != nil
        let numbers = reps.split(whereSeparator: { !$0.isNumber }).compactMap { Int($0) }
        let seconds = reps.contains("min") ? (numbers.first ?? 1) * 60 : (numbers.last ?? 0)
        return infer(exerciseName: exercise.name, category: category, isTimed: timed, seconds: seconds)
    }
}
