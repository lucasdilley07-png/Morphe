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
        ZStack {
            // The launch beat matches the app icon: gold M on a black field.
            Color.black.ignoresSafeArea()

            VStack(spacing: 22) {
                Spacer()

                MorpheLoadingMark(size: 132)

                Text("MORPHE")
                    .font(.system(size: 28, design: .monospaced).weight(.bold))
                    .tracking(6)
                    .foregroundStyle(.white)

                Text(message.uppercased())
                    .font(MorpheTheme.microLabel(12))
                    .tracking(1.8)
                    .foregroundStyle(MorpheTheme.textSecondary)
                    .transition(.opacity)

                Spacer()
            }
            .padding(24)
        }
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

/// The app-icon M with a gold arc orbiting it — Morphe's loading spinner.
struct MorpheLoadingMark: View {
    var size: CGFloat = 132
    @State private var isSpinning = false

    var body: some View {
        ZStack {
            MorpheMarkShape()
                .fill(MorpheTheme.accent)
                .frame(width: size, height: size)

            // The spinner: a quarter-ish arc sweeping a ring around the M.
            Circle()
                .trim(from: 0, to: 0.28)
                .stroke(
                    AngularGradient(
                        colors: [MorpheTheme.accent.opacity(0), MorpheTheme.accent],
                        center: .center,
                        startAngle: .degrees(0),
                        endAngle: .degrees(100)
                    ),
                    style: StrokeStyle(lineWidth: max(size * 0.04, 3), lineCap: .round)
                )
                .frame(width: size * 1.5, height: size * 1.5)
                .rotationEffect(.degrees(isSpinning ? 360 : 0))
                .animation(.linear(duration: 1.1).repeatForever(autoreverses: false), value: isSpinning)
        }
        // Reserve the ring's full footprint so surrounding layout never jumps.
        .frame(width: size * 1.5, height: size * 1.5)
        .onAppear { isSpinning = true }
        .accessibilityLabel("Morphe is loading")
    }
}

/// The Morphe "M" mark — the same three rounded strokes as the app icon,
/// scaled from the icon's 1024-point design space (Tools/make-app-icon.swift)
/// so the launch screen and the home-screen icon are pixel-for-pixel kin.
struct MorpheMarkShape: Shape {
    // Design-space geometry, verbatim from the icon generator.
    private static let leftPanel: [CGPoint] = [
        CGPoint(x: 244, y: 293), CGPoint(x: 390, y: 253),
        CGPoint(x: 390, y: 757), CGPoint(x: 244, y: 694)
    ]
    private static let rightPanel: [CGPoint] = [
        CGPoint(x: 634, y: 253), CGPoint(x: 780, y: 293),
        CGPoint(x: 780, y: 694), CGPoint(x: 634, y: 757)
    ]
    private static let centerChevron: [CGPoint] = [
        CGPoint(x: 419, y: 373), CGPoint(x: 512, y: 464), CGPoint(x: 605, y: 373),
        CGPoint(x: 605, y: 559), CGPoint(x: 512, y: 656), CGPoint(x: 419, y: 559)
    ]
    // The mark's bounds inside the 1024 icon canvas.
    private static let designBounds = CGRect(x: 244, y: 253, width: 536, height: 504)

    func path(in rect: CGRect) -> Path {
        let design = Self.designBounds
        let scale = min(rect.width / design.width, rect.height / design.height)
        let offsetX = rect.minX + (rect.width - design.width * scale) / 2
        let offsetY = rect.minY + (rect.height - design.height * scale) / 2

        func mapped(_ point: CGPoint) -> CGPoint {
            CGPoint(
                x: offsetX + (point.x - design.minX) * scale,
                y: offsetY + (point.y - design.minY) * scale
            )
        }

        var path = Path()
        addRoundedPolygon(Self.leftPanel.map(mapped), radius: 23 * scale, to: &path)
        addRoundedPolygon(Self.rightPanel.map(mapped), radius: 23 * scale, to: &path)
        addRoundedPolygon(Self.centerChevron.map(mapped), radius: 17 * scale, to: &path)
        return path
    }

    /// Same corner-rounding as the icon generator: each vertex becomes a quad
    /// curve between points backed off along the adjoining edges.
    private func addRoundedPolygon(_ points: [CGPoint], radius: CGFloat, to path: inout Path) {
        let count = points.count
        guard count >= 3 else { return }
        for index in 0..<count {
            let previous = points[(index + count - 1) % count]
            let current = points[index]
            let next = points[(index + 1) % count]
            let incoming = CGVector(dx: current.x - previous.x, dy: current.y - previous.y)
            let outgoing = CGVector(dx: next.x - current.x, dy: next.y - current.y)
            let incomingLength = max(hypot(incoming.dx, incoming.dy), 0.001)
            let outgoingLength = max(hypot(outgoing.dx, outgoing.dy), 0.001)
            let cornerRadius = min(radius, incomingLength / 2, outgoingLength / 2)
            let entry = CGPoint(
                x: current.x - incoming.dx / incomingLength * cornerRadius,
                y: current.y - incoming.dy / incomingLength * cornerRadius
            )
            let exit = CGPoint(
                x: current.x + outgoing.dx / outgoingLength * cornerRadius,
                y: current.y + outgoing.dy / outgoingLength * cornerRadius
            )
            if index == 0 {
                path.move(to: entry)
            } else {
                path.addLine(to: entry)
            }
            path.addQuadCurve(to: exit, control: current)
        }
        path.closeSubpath()
    }
}

struct OnboardingFlowView: View {
    @Environment(MorpheAppStore.self) private var store
    @State private var stepIndex = 0
    @State private var isGeneratingPlan = false
    // Username step: what's typed, the round-trip state, and the last error.
    @State private var usernameEntry = ""
    @State private var isReservingUsername = false
    @State private var usernameError: String?

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
                .username,
                .sport,
                .coachExperience,
                .coachPractice,
                .equipment,
                .goal,
                .review
            ]
        }
        let solo: [OnboardingStep] = [
            .welcome,
            .name,
            .username,
            .gender,
            .goal,
            .sport,
            .experience,
            .schedule,
            .equipment,
            .mealPrep,
            .injuryPain,
            .coachCode,
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
        if currentStep == .username {
            return UsernameRules.normalize(usernameEntry).count >= UsernameRules.minLength
                && !isReservingUsername
        }
        if currentStep == .gender {
            return store.onboardingDraft.genderChosen
        }
        if currentStep == .review {
            // Can't finish onboarding without agreeing to the terms.
            return store.onboardingDraft.agreedToTerms
        }
        return true
    }

    private var nextButtonTitle: String {
        switch currentStep {
        case .welcome:
            return "Start"
        case .review:
            return isCoachFlow ? "Create Workspace" : "Create Plan"
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
                                if currentStep == .username {
                                    // Advancing IS the claim: availability check
                                    // and reservation are one transaction, so
                                    // two people can never pass with one name.
                                    isReservingUsername = true
                                    Task {
                                        let error = await store.checkAndReserveUsername(usernameEntry)
                                        isReservingUsername = false
                                        usernameError = error
                                        if error == nil {
                                            withAnimation(.easeInOut(duration: 0.2)) {
                                                stepIndex += 1
                                            }
                                        }
                                    }
                                } else if currentStep == .review {
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
        case .username:
            UsernameStep(
                entry: $usernameEntry,
                isChecking: isReservingUsername,
                error: usernameError
            )
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
        case .equipment:
            EquipmentStep()
        case .injuryPain:
            InjuryPainStep(text: $store.onboardingDraft.injuries)
        case .mealPrep:
            MealPrepStep(
                frequency: $store.onboardingDraft.mealPrepFrequency,
                interested: $store.onboardingDraft.mealPrepInterested
            )
        case .coachCode:
            CoachCodeStep(code: $store.onboardingDraft.coachInviteCode)
        case .review:
            ProfileReviewStep()
        }
    }
}

private enum OnboardingStep {
    case welcome
    case name
    case username
    case gender
    case accountType
    case goal
    case sport
    case experience
    case schedule
    case equipment
    case mealPrep
    case injuryPain
    case coachCode
    case coachExperience
    case coachPractice
    case review
}

/// Meal-prep habit — the one nutrition question onboarding asks. When the
/// answer is "not really", a follow-up asks if they'd like to start.
private struct MealPrepStep: View {
    @Binding var frequency: MealPrepOption
    @Binding var interested: Bool

    var body: some View {
        OnboardingCard(
            title: "How often do you meal prep?",
            subtitle: "Food carries half the result. Morphe tunes its nutrition guidance to where you actually are."
        ) {
            VStack(alignment: .leading, spacing: 12) {
                WrapStack(spacing: 8) {
                    ForEach(MealPrepOption.allCases) { option in
                        Button(option.rawValue) {
                            frequency = option
                        }
                        .buttonStyle(FilterChipStyle(isSelected: frequency == option))
                    }
                }

                if frequency == .never || frequency == .occasionally {
                    Toggle(isOn: $interested) {
                        Text("I'd like to start meal prepping")
                            .font(.subheadline)
                            .foregroundStyle(.white)
                    }
                    .tint(MorpheTheme.accent)
                }
            }
        }
    }
}

/// Everyone picks a unique @username — the directory reserves it the moment
/// the step advances, so no two accounts can ever share one.
private struct UsernameStep: View {
    @Binding var entry: String
    let isChecking: Bool
    let error: String?

    private var preview: String { UsernameRules.normalize(entry) }

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 14) {
                Text("CLAIM YOUR USERNAME")
                    .font(MorpheTheme.microLabel())
                    .tracking(1.4)
                    .foregroundStyle(MorpheTheme.accent)

                Text("Pick your @name")
                    .font(.title2.weight(.bold))
                    .foregroundStyle(.white)

                Text("This is how coaches and training partners find you. Letters, numbers, and underscores — every username is one of a kind.")
                    .font(.subheadline)
                    .foregroundStyle(MorpheTheme.textSecondary)

                TextField("username", text: $entry)
                    .textFieldStyle(MorpheFieldStyle())
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()

                if !preview.isEmpty {
                    Text("@\(preview)")
                        .font(.subheadline.weight(.semibold).monospaced())
                        .foregroundStyle(MorpheTheme.accent)
                }

                if isChecking {
                    Label("Checking availability…", systemImage: "hourglass")
                        .font(.caption)
                        .foregroundStyle(MorpheTheme.textMuted)
                } else if let error {
                    Label(error, systemImage: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundStyle(MorpheTheme.warning)
                }
            }
        }
    }
}

/// Optional step: an athlete whose coach pre-created their profile enters the
/// invite code here — the claim itself runs right after onboarding completes,
/// pulling the coach-logged history into the brand-new account.
private struct CoachCodeStep: View {
    @Binding var code: String

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 14) {
                Text("TRAIN WITH A COACH")
                    .font(MorpheTheme.microLabel())
                    .tracking(1.4)
                    .foregroundStyle(MorpheTheme.accent)

                Text("Did a coach set you up?")
                    .font(.title2.weight(.bold))
                    .foregroundStyle(.white)

                Text("If your coach already created your profile on Morphe, enter the invite code they shared — the workouts they logged for you become your training history. No code? Just tap Next.")
                    .font(.subheadline)
                    .foregroundStyle(MorpheTheme.textSecondary)

                TextField("Invite code (e.g. 7KQ4TX)", text: $code)
                    .font(.system(.title3, design: .monospaced).weight(.semibold))
                    .textInputAutocapitalization(.characters)
                    .autocorrectionDisabled()
                    .padding(14)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.white.opacity(0.06))
                    )
            }
        }
    }
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

private struct EquipmentStep: View {
    @Environment(MorpheAppStore.self) private var store

    static let options = [
        "Full gym", "Dumbbells", "Barbell & rack", "Kettlebells",
        "Resistance bands", "Pull-up bar", "Cardio machines", "Pool",
        "Bodyweight only"
    ]

    private var isCoach: Bool {
        store.onboardingDraft.accountType == .coach
    }

    private var selected: Set<String> {
        Set(store.onboardingDraft.equipment
            .components(separatedBy: ", ")
            .filter { !$0.isEmpty })
    }

    private func toggle(_ option: String) {
        var current = selected
        if current.contains(option) {
            current.remove(option)
        } else {
            current.insert(option)
        }
        // Keep the canonical option order so the summary reads cleanly.
        store.onboardingDraft.equipment = Self.options
            .filter { current.contains($0) }
            .joined(separator: ", ")
    }

    var body: some View {
        OnboardingCard(
            title: "What equipment do you have access to?",
            subtitle: isCoach
                ? "Pick everything your athletes can use — sessions you assign stay realistic."
                : "Pick everything you can use. Your plan sticks to what you actually have."
        ) {
            VStack(alignment: .leading, spacing: 10) {
                WrapStack(spacing: 8) {
                    ForEach(Self.options, id: \.self) { option in
                        Button(option) {
                            toggle(option)
                        }
                        .buttonStyle(FilterChipStyle(isSelected: selected.contains(option)))
                    }
                }

                Text("Optional — skip it and Morphe assumes bodyweight-friendly sessions.")
                    .font(.caption)
                    .foregroundStyle(MorpheTheme.textMuted)
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
            title: "Any injuries, pain, or health considerations?",
            subtitle: "Include past surgeries, implants, or medications that affect training. Morphe uses this to suggest safer options — it never replaces your doctor's advice."
        ) {
            TextField("Example: Knee surgery 2024, blood-pressure medication", text: $text, axis: .vertical)
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
        @Bindable var store = store
        return OnboardingCard(
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
                if !store.onboardingDraft.equipment.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    ProfileLine(title: "Equipment", value: store.onboardingDraft.equipment)
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
                    ? "Tap Create Workspace and Morphe will set up your coaching home."
                    : "Tap Create Plan and Morphe will turn this into your starting plan.")
                    .font(.subheadline)
                    .foregroundStyle(MorpheTheme.textSecondary)

                // Required consent — the finish button stays disabled until
                // checked, and agreeing here satisfies the terms gate too.
                Toggle(isOn: $store.onboardingDraft.agreedToTerms) {
                    Text("I agree to Morphe's Terms of Use and Privacy Policy")
                        .font(.subheadline)
                        .foregroundStyle(.white)
                }
                .tint(MorpheTheme.accent)
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
