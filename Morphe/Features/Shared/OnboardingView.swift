import SwiftUI

struct LaunchSequenceView: View {
    @EnvironmentObject private var store: MorpheAppStore
    @State private var message = "Reading your recovery..."
    @State private var hasStarted = false

    var body: some View {
        VStack(spacing: 18) {
            Spacer()

            MorpheAvatarView(avatar: store.profileShowcase.avatar, size: 94)
                .shadow(color: MorpheTheme.accentAlt.opacity(0.28), radius: 18)

            Text("Morphe")
                .font(.system(size: 36, weight: .bold, design: .rounded))
                .foregroundStyle(.white)

            Text(message)
                .font(.headline)
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
            let messages = MorpheDemoContent.launchMessages + ["Today's plan is ready"]

            for item in messages {
                message = item
                try? await Task.sleep(for: .milliseconds(650))
            }

            store.finishLaunchSequence()
        }
    }
}

struct OnboardingFlowView: View {
    @EnvironmentObject private var store: MorpheAppStore
    @State private var stepIndex = 0
    @State private var isGeneratingPlan = false

    private var steps: [OnboardingStep] {
        let all: [OnboardingStep] = [
            .welcome,
            .name,
            .gender,
            .accountType,
            .goal,
            .equipment,
            .sport,
            .trainingStyle,
            .motivationStyle,
            .experience,
            .bodyInfo,
            .injuryPain,
            .schedule,
            .confidence,
            .obstacle,
            .theme,
            .avatar,
            .review
        ]
        // Account-type selection (athlete vs coach) is a v2 surface; v1 is
        // athlete-only, so skip that step.
        return FeatureFlags.multiUserEnabled ? all : all.filter { $0 != .accountType }
    }

    private var currentStep: OnboardingStep {
        steps[stepIndex]
    }

    private var canAdvance: Bool {
        if currentStep == .name {
            return !store.onboardingDraft.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
        return true
    }

    private var nextButtonTitle: String {
        switch currentStep {
        case .welcome:
            return "Start"
        case .review:
            return "Create My Plan"
        default:
            return "Next"
        }
    }

    var body: some View {
        Group {
            if isGeneratingPlan {
                PersonalizedPlanLoadingView()
            } else {
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 18) {
                        if currentStep != .welcome {
                            GlassCard {
                                VStack(alignment: .leading, spacing: 12) {
                                    Text("Create your profile")
                                        .font(.system(size: 28, weight: .bold, design: .rounded))
                                        .foregroundStyle(.white)

                                    Text("A few simple choices make the plan feel personal without turning setup into homework.")
                                        .font(.subheadline)
                                        .foregroundStyle(MorpheTheme.textSecondary)

                                    ProgressBarView(
                                        progress: Double(stepIndex + 1) / Double(steps.count),
                                        color: MorpheTheme.accent
                                    )

                                    Text("Step \(stepIndex + 1) of \(steps.count)")
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(MorpheTheme.textMuted)
                                }
                            }
                        }

                        stepView(for: currentStep)

                        HStack(spacing: 10) {
                            if stepIndex > 0 {
                                Button("Back") {
                                    stepIndex -= 1
                                }
                                .buttonStyle(SecondaryCTAButtonStyle())
                            }

                            Button(nextButtonTitle) {
                                if currentStep == .review {
                                    isGeneratingPlan = true
                                } else {
                                    stepIndex += 1
                                }
                            }
                            .buttonStyle(PrimaryCTAButtonStyle(accent: MorpheTheme.accent))
                            .disabled(!canAdvance)
                            .opacity(canAdvance ? 1 : 0.5)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 24)
                }
            }
        }
    }

    @ViewBuilder
    private func stepView(for step: OnboardingStep) -> some View {
        switch step {
        case .welcome:
            WelcomeLandingStep()
        case .name:
            NameStep(name: $store.onboardingDraft.name)
        case .gender:
            GenderSelectionStep(selection: $store.onboardingDraft.gender)
        case .accountType:
            AccountTypeStep()
        case .goal:
            GoalSelectionStep()
        case .sport:
            SportSelectionStep()
        case .trainingStyle:
            TrainingStyleSelectionStep()
        case .experience:
            ExperienceLevelStep(selection: $store.onboardingDraft.experienceLevel)
        case .bodyInfo:
            BodyInfoStep(age: $store.onboardingDraft.age, height: $store.onboardingDraft.height, weight: $store.onboardingDraft.weight)
        case .injuryPain:
            InjuryPainStep(text: $store.onboardingDraft.injuries)
        case .equipment:
            EquipmentStep(text: $store.onboardingDraft.equipment)
        case .schedule:
            ScheduleStep(days: $store.onboardingDraft.trainingDaysPerWeek, duration: $store.onboardingDraft.preferredWorkoutLength)
        case .motivationStyle:
            MotivationStyleStep(selection: $store.onboardingDraft.coachingTone)
        case .confidence:
            ConfidenceStep(selection: $store.onboardingDraft.confidence)
        case .obstacle:
            ObstacleStep(selection: $store.onboardingDraft.biggestObstacle)
        case .theme:
            ThemeSelectionStep()
        case .avatar:
            AvatarStarterStep(selection: $store.onboardingDraft.avatarStyle, avatars: store.availableAvatars)
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
    case trainingStyle
    case experience
    case bodyInfo
    case injuryPain
    case equipment
    case schedule
    case motivationStyle
    case confidence
    case obstacle
    case theme
    case avatar
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
                    Text("Welcome to Morphe")
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)

                    Text("Morphe helps beginners, athletes, and coaches know what to do today, why it matters, and how to keep going when life gets noisy.")
                        .font(.subheadline)
                        .foregroundStyle(MorpheTheme.textSecondary)

                    VStack(alignment: .leading, spacing: 10) {
                        LandingPoint(text: "Create your profile")
                        LandingPoint(text: "Pick your goal, equipment, and training style")
                        LandingPoint(text: "Choose how Morphe should coach you")
                        LandingPoint(text: "Let AI build your first personalized plan")
                    }
                }
            }
        }
    }
}

private struct LandingPoint: View {
    let text: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "sparkle")
                .font(.caption.weight(.bold))
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

                Text("Example: Alex")
                    .font(.caption)
                    .foregroundStyle(MorpheTheme.textMuted)
            }
        }
    }
}

private struct GenderSelectionStep: View {
    @Binding var selection: GenderOption

    var body: some View {
        OnboardingCard(
            title: "What's your gender?",
            subtitle: "This helps personalize the demo profile and starting plan context."
        ) {
            HStack(spacing: 10) {
                ForEach(GenderOption.allCases) { gender in
                    Button {
                        selection = gender
                    } label: {
                        VStack(spacing: 8) {
                            Text(gender.shortTitle)
                                .font(.system(size: 28, weight: .bold, design: .rounded))
                            Text(gender.rawValue)
                                .font(.subheadline.weight(.semibold))
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(FilterChipStyle(isSelected: selection == gender, selectedColor: MorpheTheme.accent))
                }
            }
        }
    }
}

private struct AccountTypeStep: View {
    @EnvironmentObject private var store: MorpheAppStore

    var body: some View {
        OnboardingCard(
            title: "What kind of account are you creating?",
            subtitle: "Choose the workspace you want first. You can still switch account type later from Profile."
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
    @EnvironmentObject private var store: MorpheAppStore

    private var detailTitle: String {
        store.onboardingDraft.accountType == .coach ? "What outcome are you coaching toward first?" : "What result feels realistic right now?"
    }

    var body: some View {
        OnboardingCard(
            title: "What are you working toward?",
            subtitle: "Pick up to 5 goals. Morphe will use the first one as your primary focus and keep the rest in view."
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

                    TextField(
                        store.onboardingDraft.accountType == .coach
                            ? "Example: Help athletes get leaner, sharper, and more game ready."
                            : "Example: Lean out, move better, and build real conditioning.",
                        text: $store.onboardingDraft.physicalGoalTarget,
                        axis: .vertical
                    )
                    .textFieldStyle(MorpheFieldStyle())
                    .lineLimit(2...4)

                    TextField(
                        store.onboardingDraft.accountType == .coach
                            ? "Example: Keep athletes in their target range"
                            : "Example: Reach 205 lbs or maintain current range",
                        text: $store.onboardingDraft.weightGoalTarget
                    )
                    .textFieldStyle(MorpheFieldStyle())

                    TextField(
                        "Example: By August 15 or no hard deadline",
                        text: $store.onboardingDraft.goalDeadline
                    )
                    .textFieldStyle(MorpheFieldStyle())
                }
            }
        }
    }
}

private struct SportSelectionStep: View {
    @EnvironmentObject private var store: MorpheAppStore

    var body: some View {
        OnboardingCard(
            title: "What kind of training fits you best?",
            subtitle: "Pick up to 5 sports or training styles. Morphe will make the first one your primary mode."
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

private struct TrainingStyleSelectionStep: View {
    @EnvironmentObject private var store: MorpheAppStore

    var body: some View {
        OnboardingCard(
            title: "How do you like to train?",
            subtitle: "Pick up to 5 training styles. Morphe uses these to shape the plan and the language around it."
        ) {
            VStack(alignment: .leading, spacing: 12) {
                Text("\(store.onboardingDraft.selectedTrainingStyles.count) of 5 selected")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(MorpheTheme.textMuted)

                WrapStack(spacing: 10) {
                    ForEach(TrainingStyleOption.allCases) { style in
                        Button(style.rawValue) {
                            store.toggleOnboardingTrainingStyle(style)
                        }
                        .buttonStyle(
                            FilterChipStyle(
                                isSelected: store.onboardingDraft.selectedTrainingStyles.contains(style),
                                selectedColor: MorpheTheme.accentAlt
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
            HStack(spacing: 8) {
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

private struct BodyInfoStep: View {
    @Binding var age: Int
    @Binding var height: String
    @Binding var weight: String

    var body: some View {
        OnboardingCard(
            title: "A quick starting snapshot",
            subtitle: "This is mock-demo personalization only. It helps the plan feel grounded."
        ) {
            VStack(spacing: 12) {
                Stepper("Age: \(age)", value: $age, in: 13...80)
                    .foregroundStyle(.white)

                TextField("Height", text: $height)
                    .textFieldStyle(MorpheFieldStyle())

                TextField("Weight", text: $weight)
                    .textFieldStyle(MorpheFieldStyle())
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

private struct EquipmentStep: View {
    @Binding var text: String

    private let accessOptions: [(title: String, detail: String, inventory: [String])] = [
        ("Home Setup", "Bodyweight, dumbbells, jump rope", ["Adjustable dumbbells", "Bench", "Bands", "Jump rope"]),
        ("Planet Fitness", "Simple strength + cardio access", ["Smith machine", "Cable stack", "Leg press", "Treadmills", "Dumbbells to 75 lb"]),
        ("LA Fitness", "Full commercial gym access", ["Power rack", "Cable station", "Dumbbells", "Benches", "Turf", "Bikes"]),
        ("Boxing Gym", "Skill + conditioning equipment", ["Heavy bags", "Speed bag", "Jump ropes", "Medicine balls", "Open mat"])
    ]

    private var selectedAccess: (title: String, detail: String, inventory: [String])? {
        accessOptions.first(where: { text.contains($0.title) || text.contains($0.detail) })
    }

    var body: some View {
        OnboardingCard(
            title: "What equipment do you have access to?",
            subtitle: "Pick the setup that feels most real. Morphe can use gym access and a mock equipment database to make better swaps."
        ) {
            VStack(alignment: .leading, spacing: 14) {
                Text("Quick access")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)

                WrapStack(spacing: 10) {
                    ForEach(accessOptions, id: \.title) { option in
                        Button(option.title) {
                            text = "\(option.title) • \(option.detail)"
                        }
                        .buttonStyle(FilterChipStyle(isSelected: selectedAccess?.title == option.title, selectedColor: MorpheTheme.accent))
                    }
                }

                if let selectedAccess {
                    GlassCard {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("AI equipment view")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.white)

                            Text(selectedAccess.detail)
                                .foregroundStyle(MorpheTheme.textSecondary)

                            WrapStack(spacing: 8) {
                                ForEach(selectedAccess.inventory, id: \.self) { item in
                                    Text(item)
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(.white)
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 8)
                                        .background(
                                            Capsule(style: .continuous)
                                                .fill(MorpheTheme.panelStrong)
                                        )
                                }
                            }
                        }
                    }
                }

                TextField("Add anything else Morphe should know about your setup", text: $text, axis: .vertical)
                    .textFieldStyle(MorpheFieldStyle())
                    .lineLimit(3...5)
            }
        }
    }
}

private struct ScheduleStep: View {
    @Binding var days: Int
    @Binding var duration: Int

    var body: some View {
        OnboardingCard(
            title: "What schedule feels realistic?",
            subtitle: "We care more about repeatable momentum than perfect ambition."
        ) {
            VStack(spacing: 12) {
                Stepper("Training days per week: \(days)", value: $days, in: 1...7)
                    .foregroundStyle(.white)
                Stepper("Preferred workout length: \(duration) min", value: $duration, in: 10...90, step: 5)
                    .foregroundStyle(.white)
            }
        }
    }
}

private struct MotivationStyleStep: View {
    @Binding var selection: CoachingTone

    var body: some View {
        OnboardingCard(
            title: "How do you want Morphe to coach you?",
            subtitle: selection.preview
        ) {
            WrapStack(spacing: 10) {
                ForEach(CoachingTone.allCases) { tone in
                    Button(tone.rawValue) {
                        selection = tone
                    }
                    .buttonStyle(FilterChipStyle(isSelected: selection == tone))
                }
            }
        }
    }
}

private struct ConfidenceStep: View {
    @Binding var selection: ConfidenceLevel

    var body: some View {
        OnboardingCard(
            title: "How confident are you right now?",
            subtitle: "This helps Morphe decide how aggressive or gentle the first week should feel."
        ) {
            HStack(spacing: 8) {
                ForEach(ConfidenceLevel.allCases) { level in
                    Button(level.rawValue) {
                        selection = level
                    }
                    .buttonStyle(FilterChipStyle(isSelected: selection == level, selectedColor: MorpheTheme.accentAlt))
                }
            }
        }
    }
}

private struct ObstacleStep: View {
    @Binding var selection: ObstacleOption

    var body: some View {
        OnboardingCard(
            title: "What gets in the way most often?",
            subtitle: "Morphe uses this to pre-build a better Plan B."
        ) {
            WrapStack(spacing: 10) {
                ForEach(ObstacleOption.allCases) { obstacle in
                    Button(obstacle.rawValue) {
                        selection = obstacle
                    }
                    .buttonStyle(FilterChipStyle(isSelected: selection == obstacle, selectedColor: MorpheTheme.warning))
                }
            }
        }
    }
}

private struct ThemeSelectionStep: View {
    @EnvironmentObject private var store: MorpheAppStore

    var body: some View {
        OnboardingCard(
            title: "Pick a theme preset",
            subtitle: "Premium Profile is free at launch, so personalization starts immediately."
        ) {
            VStack(alignment: .leading, spacing: 14) {
                Text("Theme preset")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)

                WrapStack(spacing: 10) {
                    ForEach(store.availableThemes) { theme in
                        Button(theme.rawValue) {
                            store.onboardingDraft.theme = theme
                        }
                        .buttonStyle(
                            FilterChipStyle(
                                isSelected: store.onboardingDraft.theme == theme,
                                selectedColor: MorpheTheme.accent
                            )
                        )
                    }
                }

                Text("Accent color")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)

                WrapStack(spacing: 10) {
                    ForEach(store.availableAccentPalettes) { palette in
                        Button(palette.rawValue) {
                            store.previewOnboardingAccentPalette(palette)
                        }
                        .buttonStyle(
                            FilterChipStyle(
                                isSelected: store.onboardingDraft.accentPalette == palette,
                                selectedColor: MorpheTheme.colors(for: palette).primary
                            )
                        )
                    }
                }
            }
        }
    }
}

private struct AvatarStarterStep: View {
    @Binding var selection: AvatarStyle
    let avatars: [AvatarStyle]

    var body: some View {
        OnboardingCard(
            title: "Pick an avatar starter",
            subtitle: "A profile that feels like yours makes the habit easier to keep."
        ) {
            VStack(alignment: .leading, spacing: 12) {
                MorpheAvatarView(
                    avatar: AvatarProfile(
                        style: selection,
                        gear: "Starter gear",
                        outfit: "Demo kit",
                        background: "Studio",
                        badgeFrame: "Builder frame",
                        levelGlow: "Electric blue"
                    ),
                    size: 84
                )
                .frame(maxWidth: .infinity, alignment: .leading)

                Text("Choose the starter that feels closest to your vibe. You can customize the full profile later.")
                    .font(.subheadline)
                    .foregroundStyle(MorpheTheme.textSecondary)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(avatars) { avatar in
                            Button {
                                selection = avatar
                            } label: {
                                VStack(alignment: .leading, spacing: 10) {
                                    MorpheAvatarView(
                                        avatar: AvatarProfile(
                                            style: avatar,
                                            gear: "Starter gear",
                                            outfit: "Demo kit",
                                            background: "Studio",
                                            badgeFrame: "Builder frame",
                                            levelGlow: "Electric blue"
                                        ),
                                        size: 64
                                    )

                                    HStack(spacing: 8) {
                                        Image(systemName: avatar.systemImage)
                                            .font(.caption.weight(.bold))
                                            .foregroundStyle(MorpheTheme.accentAlt)
                                        Text(avatar.starterKitLabel)
                                            .font(.caption.weight(.bold))
                                            .foregroundStyle(MorpheTheme.textMuted)
                                    }

                                    Text(avatar.rawValue)
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(.white)
                                        .multilineTextAlignment(.leading)

                                    Text(avatarSubtitle(for: avatar))
                                        .font(.caption)
                                        .foregroundStyle(MorpheTheme.textSecondary)
                                        .multilineTextAlignment(.leading)
                                        .lineLimit(2)
                                }
                                .padding(14)
                                .frame(width: 172, alignment: .leading)
                                .background(
                                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                                        .fill(selection == avatar ? MorpheTheme.panelStrong : MorpheTheme.panel)
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                                        .stroke(selection == avatar ? MorpheTheme.accent : MorpheTheme.stroke, lineWidth: 1)
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
    }

    private func avatarSubtitle(for avatar: AvatarStyle) -> String {
        switch avatar {
        case .cleanStarter:
            return "Simple, clean, and focused on consistency."
        case .fightReady:
            return "Sharp, athletic, and built for combat sport energy."
        case .matchFit:
            return "Made for game shape and steady match fitness."
        case .jumpDay:
            return "Explosive, fast, and ready for court work."
        case .roadRunner:
            return "Clean pace, endurance, and calm momentum."
        case .strengthBuilder:
            return "Grounded, strong, and built around repeatable lifting."
        }
    }
}

private struct ProfileReviewStep: View {
    @EnvironmentObject private var store: MorpheAppStore

    private var generatedPlan: (phase: String, goalTranslation: GoalTranslation, firstTask: String, message: String) {
        MorpheDemoContent.generatedPlan(from: store.onboardingDraft)
    }

    private var isCoach: Bool {
        store.onboardingDraft.accountType == .coach
    }

    var body: some View {
        OnboardingCard(
            title: isCoach ? "Review your coach profile" : "Review your athlete profile",
            subtitle: isCoach ? "One last look before Morphe builds your first workspace." : "One last look before Morphe builds your first personalized plan."
        ) {
            VStack(alignment: .leading, spacing: 14) {
                ProfileBannerView(
                    banner: BannerProfile(
                        preset: store.onboardingDraft.sport == .soccer ? .soccer : store.onboardingDraft.sport == .basketball ? .basketball : store.onboardingDraft.sport == .running ? .running : .boxing,
                        title: generatedPlan.phase,
                        subtitle: store.onboardingDraft.goal.rawValue
                    ),
                    theme: store.onboardingDraft.theme
                )

                HStack(spacing: 12) {
                    MorpheAvatarView(
                        avatar: AvatarProfile(
                            style: store.onboardingDraft.avatarStyle,
                            gear: "Starter",
                            outfit: "Demo",
                            background: "Preview",
                            badgeFrame: "Builder",
                            levelGlow: "Accent"
                        ),
                        size: 72
                    )

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Starting level: \(store.onboardingDraft.experienceLevel.rawValue)")
                            .font(.headline)
                            .foregroundStyle(.white)
                        Text("Theme: \(store.onboardingDraft.theme.rawValue)")
                            .font(.subheadline)
                            .foregroundStyle(MorpheTheme.textSecondary)
                        Text("Accent: \(store.onboardingDraft.accentPalette.rawValue)")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(MorpheTheme.accentAlt)
                    }
                }

                Text(isCoach ? "What Morphe will build for you" : "What Morphe will build for you")
                    .font(.headline)
                    .foregroundStyle(.white)

                ForEach(generatedPlan.goalTranslation.weeklyActions, id: \.self) { action in
                    Text("- \(action)")
                        .foregroundStyle(MorpheTheme.textPrimary)
                }

                ProfileLine(title: "Gender", value: store.onboardingDraft.gender.rawValue)
                ProfileLine(title: "First phase", value: generatedPlan.phase)
                ProfileLine(title: "Sports selected", value: store.onboardingDraft.selectedSports.map(\.shortTitle).joined(separator: ", "))
                ProfileLine(title: "Training selected", value: store.onboardingDraft.selectedTrainingStyles.map(\.rawValue).joined(separator: ", "))
                ProfileLine(title: "Goals selected", value: store.onboardingDraft.selectedGoals.map(\.rawValue).joined(separator: ", "))
                ProfileLine(title: isCoach ? "Physical outcome" : "Physical goal", value: store.onboardingDraft.physicalGoalTarget)
                ProfileLine(title: "Weight goal", value: store.onboardingDraft.weightGoalTarget)
                ProfileLine(title: "Deadline", value: store.onboardingDraft.goalDeadline)
                ProfileLine(title: isCoach ? "Suggested structure" : "Suggested schedule", value: "\(store.onboardingDraft.trainingDaysPerWeek) training days, \(store.onboardingDraft.preferredWorkoutLength)-minute sessions")
                ProfileLine(title: isCoach ? "First action" : "Today's first task", value: generatedPlan.firstTask)
                ProfileLine(title: isCoach ? "AI workspace summary" : "AI coach summary", value: generatedPlan.message)
                Text("Tap Create My Plan and Morphe AI will turn this profile into your first personalized starting system.")
                    .font(.subheadline)
                    .foregroundStyle(MorpheTheme.textSecondary)
            }
        }
    }
}

private struct PersonalizedPlanLoadingView: View {
    @EnvironmentObject private var store: MorpheAppStore
    @State private var message = "Reading your goals..."
    @State private var hasStarted = false

    private let messages = [
        "Reading your goals...",
        "Checking your equipment...",
        "Matching your coaching style...",
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
            .shadow(color: MorpheTheme.accentAlt.opacity(0.28), radius: 18)

            Text("Morphe AI")
                .font(.system(size: 34, weight: .bold, design: .rounded))
                .foregroundStyle(.white)

            Text(store.onboardingDraft.accountType == .coach ? "Building your coach workspace..." : "Building your personalized plan...")
                .font(.headline)
                .foregroundStyle(.white)

            Text(message)
                .font(.subheadline)
                .foregroundStyle(MorpheTheme.textSecondary)
                .transition(.opacity)

            ProgressView()
                .tint(MorpheTheme.accent)

            Text("This is a demo AI handoff using your goal, equipment, training style, and coaching preferences.")
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
