import SwiftUI

struct LaunchSequenceView: View {
    @Environment(MorpheAppStore.self) private var store
    @State private var message = ""
    @State private var hasStarted = false

    /// A fresh install has no recovery, goals, or plan to "read" — claiming
    /// otherwise was the app's first lie. New users get one honest brand beat;
    /// returning users get their plan status.
    private var launchMessages: [String] {
        store.hasCompletedOnboarding
            ? ["Loading your training...", "Today's plan is ready."]
            : ["TRANSFORM. EVOLVE. BECOME."]
    }

    var body: some View {
        VStack(spacing: 18) {
            Spacer()

            MorpheAvatarView(avatar: store.profileShowcase.avatar, size: 94)

            Text("MORPHE")
                .font(.system(size: 28, design: .monospaced).weight(.bold))
                .tracking(6)
                .foregroundStyle(.white)

            Text(message.uppercased())
                .font(MorpheTheme.microLabel(12))
                .tracking(1.8)
                .foregroundStyle(MorpheTheme.textSecondary)
                .transition(.opacity)

            ProgressView()
                .tint(MorpheTheme.accent)

            Spacer()
        }
        .padding(24)
        .task {
            guard !hasStarted else { return }
            hasStarted = true

            for item in launchMessages {
                message = item
                try? await Task.sleep(for: .milliseconds(650))
            }

            store.finishLaunchSequence()
        }
    }
}

struct OnboardingFlowView: View {
    @Environment(MorpheAppStore.self) private var store
    @State private var stepIndex = 0
    @State private var isGeneratingPlan = false

    private var steps: [OnboardingStep] {
        // Lean by design: every remaining step feeds something the app
        // actually uses (name → greeting, goal/sport → plan + templates,
        // experience → level, schedule → weekly target, injuries → safety
        // notes). The steps that collected write-only data — gender, body
        // info, equipment, motivation, confidence, obstacle, theme, avatar —
        // were cut; ~2 minutes to first value.
        // A coach account (role comes from sign-up) gets its own flow: identity
        // → what they coach → how long they've coached → practice size →
        // coaching outcome → workspace review. No athlete plan questions.
        if store.onboardingDraft.accountType == .coach {
            return [
                .welcome,
                .name,
                .sport,
                .coachExperience,
                .coachPractice,
                .goal,
                .review
            ]
        }
        let solo: [OnboardingStep] = [
            .welcome,
            .name,
            .gender,
            .goal,
            .sport,
            .experience,
            .schedule,
            .injuryPain,
            .review
        ]
        guard FeatureFlags.multiUserEnabled else { return solo }
        // Multi-user adds the athlete/coach choice right after the name.
        var multiUser = solo
        multiUser.insert(.accountType, at: 2)
        return multiUser
    }

    private var isCoachFlow: Bool {
        store.onboardingDraft.accountType == .coach
    }

    private var currentStep: OnboardingStep {
        steps[stepIndex]
    }

    private var canAdvance: Bool {
        if currentStep == .name {
            return !store.onboardingDraft.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
        if currentStep == .gender {
            return store.onboardingDraft.genderChosen
        }
        return true
    }

    private var nextButtonTitle: String {
        switch currentStep {
        case .welcome:
            return "Start"
        case .review:
            return isCoachFlow ? "Create My Workspace" : "Create My Plan"
        default:
            return "Next"
        }
    }

    var body: some View {
        Group {
            if isGeneratingPlan {
                PersonalizedPlanLoadingView()
            } else {
                ScrollViewReader { proxy in
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 18) {
                        if currentStep != .welcome {
                            GlassCard {
                                VStack(alignment: .leading, spacing: 12) {
                                    Text("PROFILE SETUP")
                                        .font(MorpheTheme.microLabel())
                                        .tracking(1.4)
                                        .foregroundStyle(MorpheTheme.accent)

                                    Text(isCoachFlow ? "Create your coach profile" : "Create your profile")
                                        .font(.title2.weight(.bold))
                                        .foregroundStyle(.white)

                                    Text(isCoachFlow
                                        ? "A few quick answers set up your coaching workspace — athletes, programs, and outreach in one place."
                                        : "A few simple choices make the plan feel personal without turning setup into homework.")
                                        .font(.subheadline)
                                        .foregroundStyle(MorpheTheme.textSecondary)

                                    // Welcome is index 0 and shows no header, so
                                    // the first header a user sees is "Step 1".
                                    ProgressBarView(
                                        progress: Double(stepIndex) / Double(max(steps.count - 1, 1)),
                                        color: MorpheTheme.accent
                                    )

                                    Text("STEP \(stepIndex) / \(steps.count - 1)")
                                        .font(MorpheTheme.microLabel(10))
                                        .tracking(1.4)
                                        .foregroundStyle(MorpheTheme.textMuted)
                                }
                            }
                        }

                        stepView(for: currentStep)
                            .id(stepIndex)
                            .transition(.opacity)

                        HStack(spacing: 10) {
                            if stepIndex > 0 {
                                Button("Back") {
                                    withAnimation(.easeInOut(duration: 0.2)) {
                                        stepIndex -= 1
                                    }
                                }
                                .buttonStyle(SecondaryCTAButtonStyle())
                            }

                            Button(nextButtonTitle) {
                                if currentStep == .review {
                                    isGeneratingPlan = true
                                } else {
                                    withAnimation(.easeInOut(duration: 0.2)) {
                                        stepIndex += 1
                                    }
                                }
                            }
                            .buttonStyle(PrimaryCTAButtonStyle(accent: MorpheTheme.accent))
                            .disabled(!canAdvance)
                            .opacity(canAdvance ? 1 : 0.5)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 24)
                    .id("onboardingTop")
                }
                .scrollDismissesKeyboard(.immediately)
                // A long step scrolled to its Next button must not leave the
                // NEXT step's title off-screen.
                .onChange(of: stepIndex) { _, _ in
                    proxy.scrollTo("onboardingTop", anchor: .top)
                }
                }
            }
        }
    }

    @ViewBuilder
    private func stepView(for step: OnboardingStep) -> some View {
        @Bindable var store = store
        switch step {
        case .welcome:
            WelcomeLandingStep()
        case .name:
            NameStep(name: $store.onboardingDraft.name)
        case .gender:
            GenderStep()
        case .accountType:
            AccountTypeStep()
        case .coachExperience:
            CoachExperienceStep(selection: $store.onboardingDraft.coachTenure)
        case .coachPractice:
            CoachPracticeStep(selection: $store.onboardingDraft.coachRoster)
        case .goal:
            GoalSelectionStep()
        case .sport:
            SportSelectionStep()
        case .experience:
            ExperienceLevelStep(selection: $store.onboardingDraft.experienceLevel)
        case .schedule:
            ScheduleStep(days: $store.onboardingDraft.trainingDaysPerWeek)
        case .injuryPain:
            InjuryPainStep(text: $store.onboardingDraft.injuries)
        case .review:
            ProfileReviewStep()
        }
    }
}

private enum OnboardingStep {
    case welcome
    case name
    case gender
    case accountType
    case goal
    case sport
    case experience
    case schedule
    case injuryPain
    case coachExperience
    case coachPractice
    case review
}

private struct WelcomeLandingStep: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            ProfileBannerView(
                banner: BannerProfile(
                    preset: .minimalPremium,
                    title: "Build momentum, not perfection.",
                    subtitle: "Small wins. Real transformation."
                ),
                theme: .morpheBlackBlue
            )

            GlassCard {
                VStack(alignment: .leading, spacing: 14) {
                    Text("GETTING STARTED")
                        .font(MorpheTheme.microLabel())
                        .tracking(1.4)
                        .foregroundStyle(MorpheTheme.accent)

                    Text("Welcome to Morphe")
                        .font(.title.weight(.bold))
                        .foregroundStyle(.white)

                    Text("Morphe helps you know what to do today, why it matters, and how to keep going when life gets noisy.")
                        .font(.subheadline)
                        .foregroundStyle(MorpheTheme.textSecondary)

                    VStack(alignment: .leading, spacing: 10) {
                        LandingPoint(index: 1, text: "Create your profile")
                        LandingPoint(index: 2, text: "Pick your goal and sport")
                        LandingPoint(index: 3, text: "Set your weekly schedule")
                        LandingPoint(index: 4, text: "Morphe builds your starting plan")
                    }
                }
            }
        }
    }
}

private struct LandingPoint: View {
    let index: Int
    let text: String

    var body: some View {
        // Telemetry checklist row: mono index instead of a sparkle glyph.
        HStack(spacing: 12) {
            Text(String(format: "%02d", index))
                .font(MorpheTheme.microLabel(11))
                .tracking(1.2)
                .foregroundStyle(MorpheTheme.accent)
            Text(text)
                .foregroundStyle(.white)
        }
    }
}

private struct NameStep: View {
    @Binding var name: String

    var body: some View {
        OnboardingCard(
            title: "What should Morphe call you?",
            subtitle: "Your name is how Morphe greets you and signs your progress. It stays on your device."
        ) {
            VStack(alignment: .leading, spacing: 10) {
                TextField("Your first name", text: $name)
                    .textFieldStyle(MorpheFieldStyle())
                    .textContentType(.givenName)
                    .submitLabel(.done)
                    .autocorrectionDisabled()
                    .onChange(of: name) { _, newValue in
                        // The name becomes the greeting and the handle —
                        // keep it a name, not a paragraph.
                        if newValue.count > 40 {
                            name = String(newValue.prefix(40))
                        }
                    }

                Text("Example: Alex")
                    .font(.caption)
                    .foregroundStyle(MorpheTheme.textMuted)
            }
        }
    }
}

private struct GenderStep: View {
    @Environment(MorpheAppStore.self) private var store

    var body: some View {
        OnboardingCard(
            title: "What's your gender?",
            subtitle: "Keeps coaching language relevant to you. You can change it anytime from your profile."
        ) {
            VStack(alignment: .leading, spacing: 10) {
                WrapStack(spacing: 8) {
                    ForEach(GenderOption.allCases) { option in
                        Button(option.rawValue) {
                            store.onboardingDraft.gender = option
                            store.onboardingDraft.genderChosen = true
                        }
                        .buttonStyle(
                            FilterChipStyle(
                                isSelected: store.onboardingDraft.genderChosen && store.onboardingDraft.gender == option
                            )
                        )
                    }
                }

                if !store.onboardingDraft.genderChosen {
                    Text("Pick one to continue.")
                        .font(.caption)
                        .foregroundStyle(MorpheTheme.textMuted)
                }
            }
        }
    }
}

private struct CoachExperienceStep: View {
    @Binding var selection: CoachTenureOption

    var body: some View {
        OnboardingCard(
            title: "How long have you been coaching?",
            subtitle: "Sets the tone of your workspace — nothing to prove, just where you are."
        ) {
            WrapStack(spacing: 8) {
                ForEach(CoachTenureOption.allCases) { option in
                    Button(option.rawValue) {
                        selection = option
                    }
                    .buttonStyle(FilterChipStyle(isSelected: selection == option))
                }
            }
        }
    }
}

private struct CoachPracticeStep: View {
    @Binding var selection: CoachRosterOption

    var body: some View {
        OnboardingCard(
            title: "How many athletes do you work with?",
            subtitle: "Your roster here starts empty and grows as athletes connect — this just sizes the workspace to your practice."
        ) {
            WrapStack(spacing: 8) {
                ForEach(CoachRosterOption.allCases) { option in
                    Button(option.rawValue) {
                        selection = option
                    }
                    .buttonStyle(FilterChipStyle(isSelected: selection == option))
                }
            }
        }
    }
}

private struct AccountTypeStep: View {
    @Environment(MorpheAppStore.self) private var store

    var body: some View {
        OnboardingCard(
            title: "What kind of account are you creating?",
            subtitle: "Choose the workspace that fits how you'll use Morphe."
        ) {
            VStack(alignment: .leading, spacing: 14) {
                RoleSwitcher(selectedRole: store.onboardingDraft.accountType) { role in
                    store.onboardingDraft.accountType = role
                    Haptics.impact(.light)
                }

                GlassCard {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(store.onboardingDraft.accountType == .coach ? "Coach account includes athlete oversight, CRM, outreach, and program tools." : "Athlete account includes daily plans, workouts, progress, coach support, and community.")
                            .foregroundStyle(MorpheTheme.textPrimary)

                        Text("You are setting up the main identity Morphe should open into first.")
                            .font(.caption)
                            .foregroundStyle(MorpheTheme.textSecondary)
                    }
                }
            }
        }
    }
}

private struct GoalSelectionStep: View {
    @Environment(MorpheAppStore.self) private var store

    private var detailTitle: String {
        store.onboardingDraft.accountType == .coach ? "What outcome are you coaching toward first?" : "What result feels realistic right now?"
    }

    var body: some View {
        @Bindable var store = store
        return OnboardingCard(
            title: store.onboardingDraft.accountType == .coach ? "What do you coach athletes toward?" : "What are you working toward?",
            subtitle: store.onboardingDraft.accountType == .coach
                ? "Pick up to 5 outcomes your coaching drives. The first becomes your workspace's primary focus."
                : "Pick up to 5 goals. Morphe will use the first one as your primary focus and keep the rest in view."
        ) {
            VStack(alignment: .leading, spacing: 12) {
                Text("\(store.onboardingDraft.selectedGoals.count) of 5 selected")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(MorpheTheme.textMuted)

                WrapStack(spacing: 10) {
                    ForEach(FitnessGoalOption.allCases) { goal in
                        Button(goal.rawValue) {
                            store.toggleOnboardingGoal(goal)
                        }
                        .buttonStyle(FilterChipStyle(isSelected: store.onboardingDraft.selectedGoals.contains(goal)))
                    }
                }

                Divider()
                    .overlay(Color.white.opacity(0.08))

                VStack(alignment: .leading, spacing: 10) {
                    Text(detailTitle)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)

                    // 30/60/90-day horizons: short placeholders that never
                    // truncate, and vertical-axis fields so anything longer
                    // wraps into view instead of getting cut off.
                    TextField(
                        "Your 30-day goal",
                        text: $store.onboardingDraft.physicalGoalTarget,
                        axis: .vertical
                    )
                    .textFieldStyle(MorpheFieldStyle())
                    .lineLimit(1...4)

                    TextField(
                        "Your 60-day goal",
                        text: $store.onboardingDraft.weightGoalTarget,
                        axis: .vertical
                    )
                    .textFieldStyle(MorpheFieldStyle())
                    .lineLimit(1...4)

                    TextField(
                        "Your 90-day goal",
                        text: $store.onboardingDraft.goalDeadline,
                        axis: .vertical
                    )
                    .textFieldStyle(MorpheFieldStyle())
                    .lineLimit(1...4)
                }
            }
        }
    }
}

private struct SportSelectionStep: View {
    @Environment(MorpheAppStore.self) private var store

    private var isCoach: Bool {
        store.onboardingDraft.accountType == .coach
    }

    var body: some View {
        OnboardingCard(
            title: isCoach ? "What do you coach?" : "What kind of training fits you best?",
            subtitle: isCoach
                ? "Pick up to 5 sports or training styles you coach. The first becomes your workspace's primary mode."
                : "Pick up to 5 sports or training styles. Morphe will make the first one your primary mode."
        ) {
            VStack(alignment: .leading, spacing: 12) {
                Text("\(store.onboardingDraft.selectedSports.count) of 5 selected")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(MorpheTheme.textMuted)

                WrapStack(spacing: 10) {
                    ForEach(SportFocus.allCases) { sport in
                        Button(sport.rawValue) {
                            store.toggleOnboardingSport(sport)
                        }
                        .buttonStyle(
                            FilterChipStyle(
                                isSelected: store.onboardingDraft.selectedSports.contains(sport),
                                selectedColor: MorpheTheme.color(for: sport)
                            )
                        )
                    }
                }
            }
        }
    }
}

private struct ExperienceLevelStep: View {
    @Binding var selection: ExperienceLevelOption

    var body: some View {
        OnboardingCard(
            title: "How experienced are you?",
            subtitle: "We keep the language and challenge level friendly to where you are now."
        ) {
            WrapStack(spacing: 8) {
                ForEach(ExperienceLevelOption.allCases) { level in
                    Button(level.rawValue) {
                        selection = level
                    }
                    .buttonStyle(FilterChipStyle(isSelected: selection == level))
                }
            }
        }
    }
}

private struct InjuryPainStep: View {
    @Binding var text: String

    var body: some View {
        OnboardingCard(
            title: "Any injuries, pain, or movement concerns?",
            subtitle: "Morphe uses this to suggest safer options and clearer coaching."
        ) {
            TextField("Example: Knee discomfort during lunges", text: $text, axis: .vertical)
                .textFieldStyle(MorpheFieldStyle())
                .lineLimit(3...5)
        }
    }
}

private struct ScheduleStep: View {
    @Binding var days: Int

    var body: some View {
        OnboardingCard(
            title: "How many days a week can you train?",
            subtitle: "We care more about repeatable momentum than perfect ambition. This becomes your weekly target."
        ) {
            VStack(alignment: .leading, spacing: 12) {
                WrapStack(spacing: 8) {
                    ForEach(1...7, id: \.self) { count in
                        Button("\(count)") {
                            days = count
                        }
                        .buttonStyle(FilterChipStyle(isSelected: days == count, selectedColor: MorpheTheme.accent))
                        .accessibilityLabel("\(count) days per week")
                    }
                }

                Text("\(days) day\(days == 1 ? "" : "s") a week — you can change this anytime.")
                    .font(.caption)
                    .foregroundStyle(MorpheTheme.textMuted)
            }
        }
    }
}

private struct ProfileReviewStep: View {
    @Environment(MorpheAppStore.self) private var store

    private var generatedPlan: (phase: String, goalTranslation: GoalTranslation, firstTask: String, message: String) {
        MorpheDemoContent.generatedPlan(from: store.onboardingDraft)
    }

    private var isCoach: Bool {
        store.onboardingDraft.accountType == .coach
    }

    /// A banner that matches the chosen sport — everyone used to get boxing.
    private var bannerPreset: BannerPreset {
        switch store.onboardingDraft.sport {
        case .boxing: return .boxing
        case .soccer: return .soccer
        case .basketball: return .basketball
        case .running, .track: return .running
        case .strength: return .strength
        case .weightLoss: return .fatLoss
        default: return .minimalPremium
        }
    }

    var body: some View {
        OnboardingCard(
            title: isCoach ? "Review your coach profile" : "Review your profile",
            subtitle: isCoach ? "One last look before Morphe builds your first workspace." : "One last look before Morphe builds your starting plan."
        ) {
            VStack(alignment: .leading, spacing: 14) {
                ProfileBannerView(
                    banner: BannerProfile(
                        preset: bannerPreset,
                        title: isCoach ? "Coach Workspace" : generatedPlan.phase,
                        subtitle: store.onboardingDraft.goal.rawValue
                    ),
                    theme: store.onboardingDraft.theme
                )

                VStack(alignment: .leading, spacing: 4) {
                    Text(isCoach
                        ? "Coaching experience: \(store.onboardingDraft.coachTenure.rawValue)"
                        : "Starting level: \(store.onboardingDraft.experienceLevel.rawValue)")
                        .font(.headline)
                        .foregroundStyle(.white)
                    Text(isCoach
                        ? "Coaching focus: \(store.onboardingDraft.sport.rawValue)"
                        : "Primary focus: \(store.onboardingDraft.sport.rawValue)")
                        .font(.subheadline)
                        .foregroundStyle(MorpheTheme.textSecondary)
                }

                Text(isCoach ? "What your workspace includes" : "What Morphe will build for you")
                    .font(.headline)
                    .foregroundStyle(.white)

                if isCoach {
                    // The coach reviews a WORKSPACE, not an athlete training
                    // plan — these are the real surfaces they land in.
                    ForEach([
                        "An athlete roster that grows by QR connect",
                        "The full workout library, saves, and your own builds",
                        "An inbox for athlete outreach and follow-ups"
                    ], id: \.self) { item in
                        Text("- \(item)")
                            .foregroundStyle(MorpheTheme.textPrimary)
                    }
                } else {
                    ForEach(generatedPlan.goalTranslation.weeklyActions, id: \.self) { action in
                        Text("- \(action)")
                            .foregroundStyle(MorpheTheme.textPrimary)
                    }
                }

                if isCoach {
                    ProfileLine(title: "Practice size", value: store.onboardingDraft.coachRoster.rawValue)
                } else {
                    ProfileLine(title: "First phase", value: generatedPlan.phase)
                }
                ProfileLine(title: "Sports selected", value: store.onboardingDraft.selectedSports.map(\.shortTitle).joined(separator: ", "))
                ProfileLine(title: "Goals selected", value: store.onboardingDraft.selectedGoals.map(\.rawValue).joined(separator: ", "))
                ProfileLine(title: "30-day goal", value: store.onboardingDraft.physicalGoalTarget)
                ProfileLine(title: "60-day goal", value: store.onboardingDraft.weightGoalTarget)
                ProfileLine(title: "90-day goal", value: store.onboardingDraft.goalDeadline)
                if !isCoach {
                    // The coach flow never asks for a weekly schedule — showing
                    // the draft's default here would invent an answer.
                    ProfileLine(title: "Weekly target", value: "\(store.onboardingDraft.trainingDaysPerWeek) training days")
                }
                if !store.onboardingDraft.injuries.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    ProfileLine(title: "Injuries & limits", value: store.onboardingDraft.injuries)
                }
                if isCoach {
                    ProfileLine(title: "First action", value: "Show your Morphe code to connect your first athlete")
                    ProfileLine(title: "Workspace summary", value: "A \(store.onboardingDraft.sport.rawValue) coaching workspace sized for \(store.onboardingDraft.coachRoster.rawValue.lowercased()) — roster, library, and outreach in one place. Everything grows from the athletes you connect.")
                } else {
                    ProfileLine(title: "Today's first task", value: generatedPlan.firstTask)
                    ProfileLine(title: "Plan summary", value: generatedPlan.message)
                }
                Text(isCoach
                    ? "Tap Create My Workspace and Morphe will set up your coaching home."
                    : "Tap Create My Plan and Morphe will turn this into your starting plan.")
                    .font(.subheadline)
                    .foregroundStyle(MorpheTheme.textSecondary)
            }
        }
    }
}

private struct PersonalizedPlanLoadingView: View {
    @Environment(MorpheAppStore.self) private var store
    @State private var message = "Reading your goals..."
    @State private var hasStarted = false

    // Only inputs the plan actually reads (equipment/coaching-style steps
    // no longer exist).
    private let messages = [
        "Reading your goals...",
        "Matching your sport and level...",
        "Building your first week..."
    ]

    var body: some View {
        VStack(spacing: 18) {
            Spacer()

            MorpheAvatarView(
                avatar: AvatarProfile(
                    style: store.onboardingDraft.avatarStyle,
                    gear: "Starter",
                    outfit: "Demo",
                    background: "Preview",
                    badgeFrame: "Builder",
                    levelGlow: "Accent"
                ),
                size: 94
            )

            Text("MORPHE")
                .font(.system(size: 28, design: .monospaced).weight(.bold))
                .tracking(6)
                .foregroundStyle(.white)

            Text(store.onboardingDraft.accountType == .coach ? "Building your coach workspace..." : "Building your personalized plan...")
                .font(.headline)
                .foregroundStyle(.white)

            Text(message.uppercased())
                .font(MorpheTheme.microLabel(11))
                .tracking(1.6)
                .foregroundStyle(MorpheTheme.textSecondary)
                .transition(.opacity)

            ProgressView()
                .tint(MorpheTheme.accent)

            Text("Morphe is shaping your starting plan from your goal, sport, experience, and weekly schedule.")
                .font(.caption)
                .foregroundStyle(MorpheTheme.textMuted)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Spacer()
        }
        .padding(24)
        .task {
            guard !hasStarted else { return }
            hasStarted = true

            for item in messages {
                message = item
                try? await Task.sleep(for: .milliseconds(700))
            }

            store.completeOnboarding()
        }
    }
}

private struct OnboardingCard<Content: View>: View {
    let title: String
    let subtitle: String
    let content: Content

    init(title: String, subtitle: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.subtitle = subtitle
        self.content = content()
    }

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 14) {
                Text(title)
                    .font(.title3.weight(.bold))
                    .foregroundStyle(.white)
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(MorpheTheme.textSecondary)
                content
            }
        }
    }
}

private struct ProfileLine: View {
    let title: String
    let value: String

    var body: some View {
        // Optional fields the user left blank are simply omitted.
        if !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(MorpheTheme.textMuted)
                Text(value)
                    .font(.subheadline)
                    .foregroundStyle(.white)
            }
        }
    }
}
