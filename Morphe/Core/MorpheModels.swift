import Foundation

protocol MorpheTabItem: Hashable, Identifiable {
    var title: String { get }
    var systemImage: String { get }
}

enum AppRole: String, CaseIterable, Identifiable {
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

    var id: String { rawValue }

    var shortTitle: String {
        switch self {
        case .male:
            return "M"
        case .female:
            return "F"
        }
    }
}

enum ClientTab: String, CaseIterable, MorpheTabItem {
    case today
    case train
    case community
    case hub
    case more

    var id: String { rawValue }

    var title: String {
        switch self {
        case .today: return "Home"
        case .train: return "Train"
        case .community: return "Network"
        case .hub: return "Progress"
        case .more: return "More"
        }
    }

    var systemImage: String {
        switch self {
        case .today: return "house.fill"
        case .train: return "figure.run"
        case .community: return "person.3.sequence.fill"
        case .hub: return "chart.line.uptrend.xyaxis"
        case .more: return "square.grid.2x2.fill"
        }
    }
}

enum ClientCommunitySection: String, CaseIterable, Identifiable {
    case forYou = "For You"
    case contact = "Contact"

    var id: String { rawValue }
}

enum CoachTab: String, CaseIterable, MorpheTabItem {
    case dashboard
    case athletes
    case programs
    case network
    case messages

    var id: String { rawValue }

    var title: String {
        switch self {
        case .dashboard: return "Home"
        case .athletes: return "Athletes"
        case .programs: return "Build"
        case .network: return "Network"
        case .messages: return "Inbox"
        }
    }

    var systemImage: String {
        switch self {
        case .dashboard: return "waveform.path.ecg.rectangle.fill"
        case .athletes: return "person.3.fill"
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
    case learn = "Learn"

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
            return "Anatomy, exercises, and form help"
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
    case resetMode = "Reset Mode"

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

enum WorkoutAdjustmentOption: String, CaseIterable, Identifiable {
    case easier = "Make it easier"
    case shorter = "Make it shorter"
    case home = "Switch to home workout"
    case gym = "Switch to gym workout"
    case recovery = "Replace with recovery session"
    case reschedule = "Move to another day"

    var id: String { rawValue }
}

enum TodayQuickAction: String, CaseIterable, Identifiable {
    case logWorkout = "Log Workout"
    case swapExercise = "Swap Exercise"
    case askAI = "Ask AI Coach"
    case messageTrainer = "Message Trainer"

    var id: String { rawValue }
}

enum ChatSender: String, Identifiable {
    case user
    case ai
    case coach
    case client
    case system

    var id: String { rawValue }
}

enum SportFocus: String, CaseIterable, Identifiable {
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
    case electricBlue = "Electric Blue"
    case green = "Green"
    case red = "Red"
    case orange = "Orange"
    case purple = "Purple"
    case pink = "Pink"
    case gold = "Gold"

    var id: String { rawValue }
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
    var exercises: [WorkoutExercise]
    var defaultSets: String = "3 sets"
    var defaultReps: String = "10 reps"
    var restTime: String = "90 sec"
    var notes: String
    var coachNote: String
}

enum SavedWorkoutLibraryFilter: String, CaseIterable, Identifiable {
    case all = "All"
    case coach = "Coach"
    case athletes = "Athletes"
    case myCopies = "My Copies"

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

enum WorkoutLogSource: String, CaseIterable, Identifiable {
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

enum WorkoutVerificationStatus: String, CaseIterable, Identifiable {
    case athleteSubmitted = "Athlete submitted"
    case coachSubmitted = "Coach submitted"
    case aiPendingReview = "AI pending review"
    case coachApproved = "Coach approved"

    var id: String { rawValue }
}

struct LoggedExercise: Identifiable, Hashable {
    var id = UUID()
    var name: String
    var sets: String
    var reps: String
    var weight: String
    var note: String
}

struct WorkoutLog: Identifiable, Hashable {
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
    var id = UUID()
    var question: String
    var options: [String]
    var correctIndex: Int
    var explanation: String
    var rewardXP: Int
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
    var id = UUID()
    var title: String
    var detail: String
    var icon: String
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

struct CelebrationMoment: Identifiable, Hashable {
    var id = UUID()
    var title: String
    var detail: String
    var symbol: String
}

struct LessonCard: Identifiable, Hashable {
    var id = UUID()
    var title: String
    var subtitle: String
    var detail: String
}

struct ProfileShowcase: Hashable {
    var displayName: String
    var username: String
    var bio: String
    var avatar: AvatarProfile
    var banner: BannerProfile
    var theme: ThemePreset
    var accentPalette: AccentPalette
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
    var accountType: AppRole = .client
    var gender: GenderOption = .male
    var age: Int = 29
    var height: String = "5'11\""
    var weight: String = "216 lbs"
    var selectedGoals: [FitnessGoalOption] = [.improveConditioning]
    var physicalGoalTarget: String = "Get leaner, move better, and build real conditioning."
    var weightGoalTarget: String = "Reach 205 lbs"
    var goalDeadline: String = "Within 12 weeks"
    var experienceLevel: ExperienceLevelOption = .beginner
    var selectedSports: [SportFocus] = [.boxing]
    var selectedTrainingStyles: [TrainingStyleOption] = [.conditioning]
    var injuries: String = "Knee discomfort during deep lunges"
    var equipment: String = "Home dumbbells, jump rope, gym twice a week"
    var trainingDaysPerWeek: Int = 3
    var preferredWorkoutLength: Int = 30
    var coachingTone: CoachingTone = .direct
    var confidence: ConfidenceLevel = .maybe
    var biggestObstacle: ObstacleOption = .time
    var theme: ThemePreset = .morpheBlackBlue
    var accentPalette: AccentPalette = .electricBlue
    var avatarStyle: AvatarStyle = .fightReady

    var goal: FitnessGoalOption {
        get { selectedGoals.first ?? .improveConditioning }
        set { selectedGoals = [newValue] }
    }

    var sport: SportFocus {
        get { selectedSports.first ?? .boxing }
        set { selectedSports = [newValue] }
    }
}

struct ClientProfile: Hashable {
    var id: UUID = UUID()
    var name: String
    var gender: GenderOption = .male
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
    var goal: String
    var selectedGoals: [String]
    var physicalGoalTarget: String
    var weightGoalTarget: String
    var goalDeadline: String
    var fitnessLevel: String
    var limitations: String
    var equipment: String
    var currentProgram: String
    var planCreatedBy: String = "Coach Marcus"
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

struct ThreadMessage: Identifiable, Hashable {
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
