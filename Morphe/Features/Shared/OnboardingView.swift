import SwiftUI

struct LaunchSequenceView: View {
    @Environment(MorpheAppStore.self) private var store
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var hasStarted = false
    @State private var revealed = false
    @State private var entering = false
    @State private var progress: CGFloat = 0
    /// 0 still · 1 activated (from three quarters on).
    @State private var loadFrame = 0
    /// The orb's box in art rows: the old helmet box (235,87)–(617,539)
    /// inside the mark, as a circle 1.22× its width.
    private static let orbBox: CGRect = {
        let helmet = CGRect(x: 40 + 235, y: 260 + 87, width: 617 - 235, height: 539 - 87)
        let side = helmet.width * 1.22
        return CGRect(x: helmet.midX - side / 2, y: helmet.midY - side / 2, width: side, height: side)
    }()

    /// The cold-open beat: long enough for the bar to fill, cold starts only.
    static let beat: Duration = .milliseconds(1400)

    /// The art is 941 × 1672; the mark layer is its (40, 260)–(901, 1340) box.
    private static let artSize = CGSize(width: 941, height: 1672)
    private static let markBox = CGRect(x: 40, y: 260, width: 861, height: 1080)
    /// Helmet, wordmark, tagline and bar at 85% of the art (Lucas 2026-10-15).
    private static let markScale: CGFloat = 0.85
    /// The field zooms 8% over the beat — entering Morphe.
    private static let enterZoom: CGFloat = 1.08
    /// Under the tagline, in art rows (its bottom is ~1265, scaled about the mark's centre).
    private static let barArtY: CGFloat = 1395

    var body: some View {
        GeometryReader { geo in
            // The art fills the screen by height on every iPhone (it is
            // wider than any phone), so art coordinates map by one scale.
            let scale = max(geo.size.height / Self.artSize.height, geo.size.width / Self.artSize.width)
            let originX = (geo.size.width - Self.artSize.width * scale) / 2
            let originY = (geo.size.height - Self.artSize.height * scale) / 2
            let markCenter = CGPoint(x: originX + Self.markBox.midX * scale, y: originY + Self.markBox.midY * scale)
            let barY = markCenter.y + (Self.barArtY - Self.markBox.midY) * scale * Self.markScale
            ZStack {
                // Same navy as the system splash (LaunchField).
                Color("LaunchField")

                // Lucas's full-frame loading art (2026-10-17): Still until
                // the bar is three quarters full, then Activated. The field
                // zooms toward the viewer over the beat.
                ZStack {
                    Image("LoadingScreenStill")
                        .resizable().interpolation(.high).scaledToFill()
                        .opacity(loadFrame == 1 ? 0 : 1)
                    Image("LoadingScreenActivated")
                        .resizable().interpolation(.high).scaledToFill()
                        .opacity(loadFrame == 1 ? 1 : 0)
                    // Layered motion over the activated art (Lucas
                    // 2026-10-17): the field breathes, the helmet and eyes
                    // glow in a pulse, the electricity shimmers. The art
                    // is one picture, so each "layer" is a masked light
                    // pass over its region. Nothing under Reduce Motion.
                    if loadFrame == 1, !reduceMotion {
                        LoadingActivatedMotion()
                    }
                }
                .frame(width: geo.size.width, height: geo.size.height)
                .scaleEffect(entering ? Self.enterZoom : 1.0)
                .clipped()
                .animation(reduceMotion ? nil : .easeInOut(duration: 0.3), value: loadFrame)

                if !reduceMotion {
                    LoadingMotes(isLight: false)
                        .blendMode(.plusLighter)
                        .scaleEffect(entering ? Self.enterZoom : 1.0)
                }

                // The live bar rides over the art's bar.
                LoadingGlassBar(progress: progress, animates: !reduceMotion, isLight: false)
                    .frame(width: geo.size.width * 0.49, height: 8)
                    .position(x: geo.size.width / 2, y: geo.size.height * 0.729 * (entering ? Self.enterZoom : 1.0) - (entering ? geo.size.height * (Self.enterZoom - 1) / 2 : 0))
            }
            // One layer for the fade: per-layer opacity showed the mark's
            // box over the half-faded field.
            .compositingGroup()
            .opacity(revealed ? 1 : 0)
            .frame(width: geo.size.width, height: geo.size.height)
            .clipped()
        }
        .ignoresSafeArea()
        .preferredColorScheme(.dark)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Morphe. \(MorpheTheme.tagline). Loading.")
        .task {
            guard !hasStarted else { return }
            hasStarted = true
            withAnimation(.easeOut(duration: reduceMotion ? 0.15 : 0.35)) { revealed = true }
            if !reduceMotion {
                // Slow at first, gathering speed — moving into the app.
                withAnimation(.easeIn(duration: 1.6)) { entering = true }
            }
            withAnimation(.easeInOut(duration: 1.25)) { progress = 1 }
            // Still until the bar reaches three quarters (the 1.25 s fill
            // → ~0.94 s), then Activated for the rest (Lucas 2026-10-17).
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(940))
                loadFrame = 1
                Haptics.impact(.light)
            }
            // One brand beat on every cold open; store init is already
            // done, so this is the only cost — never on a foreground return.
            try? await Task.sleep(for: Self.beat)
            store.finishLaunchSequence()
        }
    }
}

/// Subtle life on the activated loading art (Lucas 2026-10-17). Regions
/// are fractions of the 850 × 1850 art: helmet centre (0.50, 0.387),
/// eyes at (0.388, 0.416) and (0.606, 0.416), the glow line under the
/// helmet at 0.573.
private struct LoadingActivatedMotion: View {
    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 40.0)) { context in
            let t = context.date.timeIntervalSinceReferenceDate
            let pulse = 0.5 + 0.5 * sin(t * 2 * .pi / 1.1)          // helmet glow, 1.1 s
            let eye = 0.5 + 0.5 * sin(t * 2 * .pi / 0.7 + 1.0)      // eyes, faster
            let breathe = 1 + 0.006 * sin(t * 2 * .pi / 2.4)        // field
            // Electricity: a jittery shimmer, two sines beating plus a
            // per-frame flicker so it never reads as a smooth pulse.
            let flickerSeed = Double((Int(t * 30) &* 1103515245 &+ 12345) & 0x7fff) / 32767
            let shimmer = max(0, 0.35 + 0.35 * sin(t * 13.0) + 0.3 * sin(t * 29.0) - 0.4 * flickerSeed)
            GeometryReader { geo in
                let w = geo.size.width, h = geo.size.height
                ZStack {
                    // Background: a wide, slow wash that breathes.
                    RadialGradient(colors: [MorpheTheme.brandBlue.opacity(0.18 + 0.08 * pulse), .clear], center: .center, startRadius: 0, endRadius: w * 0.9)
                        .scaleEffect(breathe)
                    // Helmet: the glow around it swells and settles.
                    Circle()
                        .fill(RadialGradient(colors: [Color(red: 0.55, green: 0.8, blue: 1).opacity(0.22 + 0.2 * pulse), .clear], center: .center, startRadius: 0, endRadius: w * 0.3))
                        .frame(width: w * 0.6, height: w * 0.6)
                        .position(x: w * 0.5, y: h * 0.387)
                        .scaleEffect(1 + 0.03 * pulse)
                    // The light line under the helmet.
                    Ellipse()
                        .fill(Color(red: 0.6, green: 0.85, blue: 1).opacity(0.18 + 0.18 * pulse))
                        .frame(width: w * 0.22, height: 6)
                        .blur(radius: 6)
                        .position(x: w * 0.5, y: h * 0.573)
                    // Eyes: twin flares, out of phase with the helmet.
                    ForEach([0.388, 0.606], id: \.self) { ex in
                        Circle()
                            .fill(Color.white.opacity(0.35 + 0.45 * eye))
                            .frame(width: w * 0.045, height: w * 0.045)
                            .blur(radius: 7)
                            .position(x: w * ex, y: h * 0.416)
                    }
                    // Electricity: a white shimmer masked to the helmet,
                    // flickering.
                    Ellipse()
                        .fill(Color.white.opacity(0.16 * shimmer))
                        .frame(width: w * 0.42, height: h * 0.34)
                        .blur(radius: 14)
                        .position(x: w * 0.5, y: h * 0.39)
                }
                .blendMode(.plusLighter)
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

/// Data motes: small electric-blue points rising and twinkling.
private struct LoadingMotes: View {
    let isLight: Bool
    private struct Mote { let x, y, speed, size, phase: Double }
    private static let motes: [Mote] = (0..<46).map { i in
        var g = SystemRandomNumberGenerator()
        _ = i
        return Mote(x: .random(in: 0...1, using: &g), y: .random(in: 0...1, using: &g),
                    speed: .random(in: 0.015...0.05, using: &g), size: .random(in: 1.2...3.2, using: &g),
                    phase: .random(in: 0...(2 * .pi), using: &g))
    }

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { timeline in
            Canvas { context, size in
                let t = timeline.date.timeIntervalSinceReferenceDate
                for mote in Self.motes {
                    let y = (mote.y - t * mote.speed).truncatingRemainder(dividingBy: 1)
                    let py = (y < 0 ? y + 1 : y) * size.height
                    let px = mote.x * size.width + sin(t * 0.6 + mote.phase) * 6
                    let twinkle = 0.35 + 0.65 * (0.5 + 0.5 * sin(t * 2.2 + mote.phase))
                    let r = mote.size
                    context.fill(Path(ellipseIn: CGRect(x: px - r * 2, y: py - r * 2, width: r * 4, height: r * 4)),
                                 with: .color(Color(red: 0.25, green: 0.5, blue: 1).opacity((isLight ? 0.12 : 0.18) * twinkle)))
                    context.fill(Path(ellipseIn: CGRect(x: px - r / 2, y: py - r / 2, width: r, height: r)),
                                 with: .color(isLight
                                    ? Color(red: 0.12, green: 0.4, blue: 0.95).opacity(0.75 * twinkle)
                                    : Color(red: 0.7, green: 0.85, blue: 1).opacity(0.9 * twinkle)))
                }
            }
        }
        .allowsHitTesting(false)
    }
}

/// A glass capsule (Liquid Glass on iOS 26) with an electric fill and a
/// bright head, as in the art.
private struct LoadingGlassBar: View {
    let progress: CGFloat
    let animates: Bool
    let isLight: Bool

    var body: some View {
        GeometryReader { geo in
            let w = max(geo.size.height, geo.size.width * progress)
            ZStack(alignment: .leading) {
                track
                Capsule()
                    .fill(LinearGradient(
                        colors: [Color(red: 0.12, green: 0.36, blue: 0.95), Color(red: 0.35, green: 0.72, blue: 1.0)],
                        startPoint: .leading, endPoint: .trailing))
                    .frame(width: w)
                    .shadow(color: Color(red: 0.3, green: 0.6, blue: 1).opacity(0.9), radius: 6)
                Circle()
                    .fill(Color.white)
                    .frame(width: geo.size.height * 0.9, height: geo.size.height * 0.9)
                    .shadow(color: isLight ? Color(red: 0.3, green: 0.6, blue: 1) : .white, radius: 4)
                    .offset(x: w - geo.size.height * 0.95)
                    .opacity(progress > 0.02 ? 1 : 0)
            }
        }
    }

    @ViewBuilder
    private var track: some View {
        if #available(iOS 26.0, *) {
            Capsule().fill(Color.white.opacity(isLight ? 0.5 : 0.04))
                .glassEffect(.regular.tint(isLight ? Color.white.opacity(0.4) : Color(red: 0.05, green: 0.12, blue: 0.4).opacity(0.5)), in: Capsule())
                .overlay(Capsule().strokeBorder(Color(red: 0.45, green: 0.6, blue: 1).opacity(0.55), lineWidth: 1))
        } else {
            Capsule().fill(.ultraThinMaterial)
                .overlay(Capsule().strokeBorder(Color(red: 0.45, green: 0.6, blue: 1).opacity(0.55), lineWidth: 1))
        }
    }
}

struct OnboardingFlowView: View {
    @Environment(MorpheAppStore.self) private var store
    @State private var stepIndex = 0
    /// The helmet mark travels from the opener into the name field
    /// (motion grammar 2026-10-15: one hero shape across the whole flow).
    @Namespace private var brand
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
        // FOUR steps to first value (was 13). Deferred fields keep their
        // Profile homes: gender, equipment, meal prep, injuries (chronic —
        // acute pain has the mid-session flag). Every deferred field
        // defaults safely. One account type — no role fork.
        // One decision per screen (reference audit 2026-10-16: Duolingo /
        // TikTok / Instagram ask one thing at a time behind a thin progress
        // bar). The composite .identity/.training/.week pages stay defined
        // but are no longer in the path.
        // The intro (Lucas 2026-10-16) already took the handle and the
        // birth year, and the welcome page is the intro itself.
        // The intro is the welcome (Lucas 2026-10-17); the questions start
        // at the name. Seven short screens, one decision each.
        if store.introSuppliedIdentity {
            return [.name, .goal, .sport, .experience, .schedule, .review]
        }
        return [.name, .username, .goal, .sport, .experience, .schedule, .review]
    }

    /// Get started from the intro: no questions, straight to the loading
    /// screen and the app.
    private var isQuickStart: Bool { store.introChoice == .quickStart }

    private var isCoachFlow: Bool { false }

    /// The device's status-bar/island height, read from the key window.
    static var windowTopInset: CGFloat {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first(where: \.isKeyWindow)?.safeAreaInsets.top ?? 59
    }

    private var currentStep: OnboardingStep {
        // Clamped: `steps` is computed and can shrink mid-flow (the coach
        // list is longer than the solo one), so a raw subscript can trap.
        steps[min(stepIndex, steps.count - 1)]
    }

    private var canAdvance: Bool {
        if currentStep == .name || currentStep == .identity {
            let hasName = !store.onboardingDraft.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                && store.onboardingDraft.meetsMinimumAge
            if currentStep == .name { return hasName }
            // The handle's own rules gate the button too (audit 2026-10-15:
            // "2001jl" showed "Start with a letter" under a lit Next).
            return hasName
                && UsernameRules.validationError(UsernameRules.normalize(usernameEntry)) == nil
                && !isReservingUsername
        }
        if currentStep == .username {
            return UsernameRules.validationError(UsernameRules.normalize(usernameEntry)) == nil
                && !isReservingUsername
        }
        if currentStep == .week {
            return store.onboardingDraft.agreedToTerms
        }
        // Gender advances freely — it only tunes coaching language, and a
        // hard gate for soft value is the wrong trade. "Never asked" is a
        // state the model already supports.
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
        case .review, .week:
            return isCoachFlow ? "Create Workspace" : "Create plan"
        default:
            return "Next"
        }
    }

    var body: some View {
        let advanceAllowed = canAdvance
        return Group {
            if isGeneratingPlan || isQuickStart {
                // A quiet field while the handle is reserved and the
                // profile minted; the Morphe loading screen follows.
                PremiumBackground().ignoresSafeArea()
                    .task { if isQuickStart { await store.quickStartOnboarding() } }
            } else {
                // A fresh scroll view per step (reference audit 2026-10-16):
                // the old scrollTo("top") on every step change left the
                // scroll view tracking, and the first tap on the new step
                // only stopped it — every first tap on a card was lost.
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 18) {
                        if currentStep != .welcome {
                            // Morphe asks (Lucas 2026-10-17): the small
                            // activated Spartan at the top, the question in
                            // its bubble, then the cards. No titles or
                            // subtitles on the cards themselves.
                            VStack(spacing: 4) {
                                MorpheOrbView(level: 0.12, frame: .activated)
                                    .frame(width: 96, height: 96)
                                    .accessibilityHidden(true)
                                IntroBubble(tail: true) {
                                    Text(question(for: currentStep))
                                        .font(.headline.weight(.bold))
                                        .foregroundStyle(MorpheTheme.textPrimary)
                                        .multilineTextAlignment(.center)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.top, -8)

                            // Thin bar + count, nothing else.
                            let total = steps.count
                            let answered = stepIndex + 1
                            HStack(spacing: 12) {
                                ProgressBarView(
                                    progress: Double(answered) / Double(total),
                                    color: MorpheTheme.accent
                                )
                                Text("\(answered) OF \(total)")
                                    .font(MorpheTheme.microLabel(10))
                                    .tracking(1.2)
                                    .foregroundStyle(MorpheTheme.textMuted)
                                    .fixedSize()
                            }
                            .padding(.top, 4)
                            .accessibilityElement(children: .ignore)
                            .accessibilityLabel("Step \(answered) of \(total)")
                        }

                        stepView(for: currentStep)

                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 24)
                }
                .id(stepIndex)
                .transition(.blurIn)
                .scrollDismissesKeyboard(.immediately)
                .safeAreaInset(edge: .bottom, spacing: 0) {
                    ctaBar(canAdvance: advanceAllowed)
                        .padding(.horizontal, 20)
                        .padding(.top, 14)
                        .padding(.bottom, 6)
                        // Solid under the buttons (a chip scrolling behind
                        // the outlined Back showed through it), with a
                        // short fade above so content dissolves into the bar.
                        .background(MorpheTheme.ink.ignoresSafeArea(edges: .bottom))
                        .overlay(alignment: .top) {
                            LinearGradient(
                                colors: [MorpheTheme.ink.opacity(0), MorpheTheme.ink],
                                startPoint: .top, endPoint: .bottom
                            )
                            .frame(height: 20)
                            .offset(y: -20)
                            .allowsHitTesting(false)
                        }
                }
                // Content scrolling under the Dynamic Island fades out
                // instead of colliding with the clock.
                .overlay(alignment: .top) {
                    // Solid under the clock and island, fading just below.
                    // Sized from the window's own inset: this container already
                    // reaches under the status bar, so a safe-area-relative band
                    // came out zero-height (audit 2026-10-15).
                    LinearGradient(
                        stops: [
                            .init(color: MorpheTheme.ink, location: 0),
                            .init(color: MorpheTheme.ink, location: 0.7),
                            .init(color: MorpheTheme.ink.opacity(0), location: 1)
                        ],
                        startPoint: .top, endPoint: .bottom
                    )
                    .frame(height: Self.windowTopInset + 22)
                    .ignoresSafeArea(edges: .top)
                    .allowsHitTesting(false)
                }
            }
        }
    }

    /// Back / Next, pinned above the home indicator (release audit
    /// 2026-10-15, P1): in the scroll the opener's Start sat under the
    /// indicator on a Pro Max, where a tap reads as the home gesture and
    /// nothing happens; on the long steps Next was a scroll away.
    ///
    /// `canAdvance` arrives as a value read in `body`: the inset's content
    /// is built outside the body's observation scope, so a store read in
    /// here never re-ran when the name or birth year changed — Next
    /// stayed dead on a filled form.
    private func ctaBar(canAdvance: Bool) -> some View {
        HStack(spacing: 10) {
            if stepIndex > 0 {
                Button("Back") {
                    withAnimation(.easeInOut(duration: 0.35)) {
                        stepIndex -= 1
                    }
                }
                .buttonStyle(SecondaryCTAButtonStyle())
            }

            Button(nextButtonTitle) {
                // .identity stacks name + @name on one page
                // (audit 2026-10-07, P0): it must reserve
                // too, or the handle the user typed is
                // thrown away and completeOnboarding falls
                // back to the lowercased name — unclaimed,
                // and colliding with every other "Alex".
                if currentStep == .username || currentStep == .identity {
                    // Advancing IS the claim: availability check
                    // and reservation are one transaction, so
                    // two people can never pass with one name.
                    isReservingUsername = true
                    Task {
                        let error = await store.checkAndReserveUsername(usernameEntry)
                        isReservingUsername = false
                        usernameError = error
                        if error == nil {
                            withAnimation(.easeInOut(duration: 0.35)) { stepIndex += 1 }
                        }
                    }
                } else if stepIndex >= steps.count - 1 {
                    // The LAST step finishes — solo ends on
                    // .week, coach on .review. Keying off the
                    // index (not the case) means a reordered
                    // flow can never walk past the array again.
                    // The intro's handle is reserved here (Lucas
                    // 2026-10-16); a collision falls back to the
                    // username step. Then the Morphe loading
                    // screen, then the app.
                    isGeneratingPlan = true
                    Task {
                        if store.introSuppliedIdentity {
                            if let error = await store.checkAndReserveUsername(store.onboardingDraft.username) {
                                store.onboardingDraft.username = ""
                                usernameError = error
                                isGeneratingPlan = false
                                store.showToast(error, isError: true)
                                stepIndex = min(stepIndex, steps.count - 1)
                                return
                            }
                        }
                        store.clearIntroChoice()
                        store.completeOnboarding()
                    }
                } else {
                    withAnimation(.easeInOut(duration: 0.35)) { stepIndex += 1 }
                }
            }
            .buttonStyle(PrimaryCTAButtonStyle(accent: MorpheTheme.accent))
            .disabled(!canAdvance)
            .opacity(canAdvance ? 1 : 0.5)
        }
    }

    /// What Morphe asks on each screen — one line, in its bubble.
    private func question(for step: OnboardingStep) -> String {
        switch step {
        case .name: return "What should I call you?"
        case .username: return "Pick your @handle."
        case .goal: return "What are you working toward?"
        case .sport: return "What do you train?"
        case .experience: return "How experienced are you?"
        case .schedule: return "How many days a week?"
        case .review: return "Here's your starting plan."
        case .gender: return "How should I refer to you?"
        case .equipment: return "What do you train with?"
        case .injuryPain: return "Anything I should know?"
        case .mealPrep: return "Do you meal prep?"
        case .identity: return "Who are you?"
        case .training: return "How do you train?"
        case .week: return "Your week."
        case .welcome: return ""
        }
    }

    @ViewBuilder
    private func stepView(for step: OnboardingStep) -> some View {
        @Bindable var store = store
        switch step {
        case .welcome:
            WelcomeLandingStep(namespace: brand)
        case .identity:
            VStack(alignment: .leading, spacing: 16) {
                NameStep(name: $store.onboardingDraft.name, birthYear: $store.onboardingDraft.birthYear, namespace: brand)
                UsernameStep(
                    entry: $usernameEntry,
                    isChecking: isReservingUsername,
                    error: usernameError,
                    suggestedBase: store.onboardingDraft.name
                )
            }
        case .training:
            VStack(alignment: .leading, spacing: 16) {
                GoalSelectionStep()
                SportSelectionStep()
                ExperienceLevelStep(selection: $store.onboardingDraft.experienceLevel)
            }
        case .week:
            VStack(alignment: .leading, spacing: 16) {
                ScheduleStep(days: $store.onboardingDraft.trainingDaysPerWeek)
                ProfileReviewStep()
            }
        case .name:
            NameStep(name: $store.onboardingDraft.name, birthYear: $store.onboardingDraft.birthYear, askBirthYear: !store.introSuppliedIdentity, namespace: brand)
        case .username:
            UsernameStep(
                entry: $usernameEntry,
                isChecking: isReservingUsername,
                error: usernameError,
                suggestedBase: store.onboardingDraft.name
            )
        case .gender:
            GenderStep()
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
        case .review:
            ProfileReviewStep()
        }
    }
}

private enum OnboardingStep {
    case welcome
    /// Composite steps (13→4 cut): each stacks existing step views —
    /// nothing collected here was deleted, the rest moved to Profile.
    case identity
    case training
    case week
    case name
    case username
    case gender
    case goal
    case sport
    case experience
    case schedule
    case equipment
    case mealPrep
    case injuryPain
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
                            .foregroundStyle(MorpheTheme.textPrimary)
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
    /// Prefill seed (the user's name) — the step suggests a handle instead
    /// of demanding invention; it stays fully editable.
    var suggestedBase: String = ""
    /// Stable digits + the last value WE wrote, so live re-suggestion can
    /// tell "untouched" apart from "user edited".
    @State private var suggestionDigits = Int.random(in: 10...99)
    @State private var lastSuggestion = ""

    private var preview: String { UsernameRules.normalize(entry) }

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 14) {
                Text("Keep it, tweak it, or replace it.")
                    .font(.subheadline)
                    .foregroundStyle(MorpheTheme.textSecondary)

                TextField("username", text: $entry)
                    .textFieldStyle(MorpheFieldStyle())
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    // What you type is what you claim (audit 2026-10-15: the
                    // field took 26 characters, the handle kept 20).
                    .onChange(of: entry) { _, value in
                        if value.count > UsernameRules.maxLength { entry = String(value.prefix(UsernameRules.maxLength)) }
                    }
                    .onAppear {
                        guard entry.isEmpty else { return }
                        let base = String(UsernameRules.normalize(suggestedBase).prefix(UsernameRules.maxLength - 2))
                        guard !base.isEmpty else { return }
                        entry = "\(base)\(Int.random(in: 10...99))"
                    }
                    // The identity step stacks name ABOVE username, so the
                    // name usually lands after this field appears — keep
                    // suggesting while the field is untouched (empty or
                    // still exactly our last suggestion), stop the moment
                    // the user edits it.
                    .onChange(of: suggestedBase) { _, base in
                        guard entry.isEmpty || entry == lastSuggestion else { return }
                        let clean = String(UsernameRules.normalize(base).prefix(UsernameRules.maxLength - 2))
                        guard !clean.isEmpty else { return }
                        lastSuggestion = "\(clean)\(suggestionDigits)"
                        entry = lastSuggestion
                    }

                if !preview.isEmpty {
                    Text("@\(preview)")
                        .font(.subheadline.weight(.semibold).monospaced())
                        .foregroundStyle(MorpheTheme.accentText)
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


/// The opener (reverse-engineered from the reference Shorts, 2026-10-15):
/// the helmet mark morphs in with a ring growing past the edge, "Meet"
/// + the wordmark + the tagline rise in one beat apart, then the honest
/// four-step promise and the manifesto blur in. The mark itself carries
/// on into the name field on the next step.
private struct WelcomeLandingStep: View {
    let namespace: Namespace.ID
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var markShown = false

    static let tagline = MorpheTheme.tagline

    var body: some View {
        BeatSequence(delays: [0.35, 0.65, 0.95, 1.5, 1.65, 1.8, 1.95, 2.4]) { beat in
            VStack(alignment: .leading, spacing: 18) {
                VStack(spacing: 10) {
                    ZStack {
                        RingPulse(color: MorpheTheme.accent, from: 0.4, to: 2.2, duration: 1.3, delay: 0.1)
                            .frame(width: 96, height: 96)
                        MorpheHelmetMark(glowRadius: 10)
                            .frame(width: 96, height: 96)
                            .matchedGeometryEffect(id: "brandMark", in: namespace, isSource: true)
                            .scaleEffect(markShown || reduceMotion ? 1 : 0.55)
                            .opacity(markShown || reduceMotion ? 1 : 0)
                            .blur(radius: markShown || reduceMotion ? 0 : 10)
                    }
                    .frame(height: 110)
                    .onAppear {
                        withAnimation(.spring(response: 0.55, dampingFraction: 0.72)) { markShown = true }
                    }

                    if beat[0] {
                        Text("Meet")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(MorpheTheme.textSecondary)
                            .transition(.blurIn)
                    }
                    if beat[1] {
                        MorpheWordmark(height: 34)
                            .foregroundStyle(MorpheTheme.textPrimary)
                            .transition(.blurIn)
                    }
                    if beat[2] {
                        Text(Self.tagline)
                            .font(MorpheTheme.microLabel(13))
                            .tracking(3)
                            .foregroundStyle(MorpheTheme.accentText)
                            .transition(.blurIn)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 8)
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Meet Morphe. \(Self.tagline)")

                if beat[3] {
                    GlassCard {
                        VStack(alignment: .leading, spacing: 14) {
                            Text("GETTING STARTED")
                                .font(MorpheTheme.microLabel())
                                .tracking(1.4)
                                .foregroundStyle(MorpheTheme.accentText)

                            Text("You bring accurate answers and honest sets. Morphe does the heavy lifting: it builds the program, picks the weights, runs the timers and tracks every rep.")
                                .font(.subheadline)
                                .foregroundStyle(MorpheTheme.textSecondary)

                            Text("Seven quick questions, about a minute. The more accurate your answers, the sharper your program.")
                                .font(.caption)
                                .foregroundStyle(MorpheTheme.textMuted)
                        }
                    }
                    .transition(.blurIn)
                }

                if beat[7] {
                    ManifestoCard()
                        .transition(.blurIn)
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
                .foregroundStyle(MorpheTheme.accentText)
            Text(text)
                .foregroundStyle(MorpheTheme.textPrimary)
        }
    }
}

private struct NameStep: View {
    @Binding var name: String
    @Binding var birthYear: Int?
    /// The intro already took the birthday (Lucas 2026-10-17): no second ask.
    var askBirthYear: Bool = true
    let namespace: Namespace.ID
    @State private var yearText = ""

    private var yearMessage: String? {
        guard yearText.count == 4 else { return nil }
        var draft = OnboardingDraft(); draft.birthYear = Int(yearText)
        if !draft.birthYearIsValid { return "Check the year." }
        if !draft.meetsMinimumAge { return "Morphe is for people 13 and older." }
        return nil
    }

    var body: some View {
        OnboardingCard(
            title: "What should Morphe call you?",
            subtitle: askBirthYear
                ? "Morphe greets you by name. Your birth year confirms you can train with Morphe — it isn't shown to anyone."
                : "Morphe greets you by name — first name is enough."
        ) {
            VStack(alignment: .leading, spacing: 10) {
                // The opener's mark lands here, small, beside the field.
                HStack(spacing: 10) {
                    MorpheHelmetMark(glowRadius: 4)
                        .frame(width: 28, height: 28)
                        .matchedGeometryEffect(id: "brandMark", in: namespace, isSource: false)
                        .accessibilityHidden(true)
                    TextField("First name", text: $name)
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
                }

                // Age gate (fix wave 2026-10-13): asked neutrally, no hint
                // at the cutoff, and it becomes the profile age.
                if askBirthYear {
                TextField("Birth year", text: $yearText)
                    .textFieldStyle(MorpheFieldStyle())
                    .keyboardType(.numberPad)
                    .onAppear { if let birthYear { yearText = String(birthYear) } }
                    .onChange(of: yearText) { _, newValue in
                        let digits = String(newValue.filter(\.isNumber).prefix(4))
                        if digits != newValue { yearText = digits }
                        birthYear = digits.count == 4 ? Int(digits) : nil
                    }
                    .accessibilityLabel("Year you were born")
                }
                if askBirthYear, let yearMessage {
                    Text(yearMessage)
                        .font(.caption)
                        .foregroundStyle(MorpheTheme.warning)
                }
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




private struct GoalSelectionStep: View {
    @Environment(MorpheAppStore.self) private var store
    /// Free-text milestones stay folded until asked for — the default step
    /// is all taps, no writing.
    @State private var showMilestones = false

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
                    // Back-navigation must never hide text the user already
                    // wrote behind a collapsed disclosure.
                    .onAppear {
                        if !store.onboardingDraft.physicalGoalTarget.isEmpty
                            || !store.onboardingDraft.weightGoalTarget.isEmpty
                            || !store.onboardingDraft.goalDeadline.isEmpty {
                            showMilestones = true
                        }
                    }

                // Icon cards, one per row (reference audit 2026-10-16:
                // Duolingo's single-select list, TikTok's interest cards).
                VStack(spacing: 8) {
                    ForEach(FitnessGoalOption.allCases) { goal in
                        ChoiceCard(
                            symbol: goal.symbol,
                            title: goal.rawValue,
                            isSelected: store.onboardingDraft.selectedGoals.contains(goal),
                            multi: true
                        ) { store.toggleOnboardingGoal(goal) }
                    }
                }

                Divider()
                    .overlay(MorpheTheme.strokeSubtle)

                // Zero visible writing by default: taps carry the whole
                // step, and the free-text milestones live behind one
                // disclosure for the users who want them. (Three text
                // boxes — even optional ones — read as homework.)
                if showMilestones {
                    VStack(alignment: .leading, spacing: 10) {
                        Text(detailTitle)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(MorpheTheme.textPrimary)

                        Text("All optional — skip these and set them later in Profile.")
                            .font(.caption)
                            .foregroundStyle(MorpheTheme.textMuted)

                        // 30/60/90-day horizons: short placeholders that never
                        // truncate, and vertical-axis fields so anything longer
                        // wraps into view instead of getting cut off.
                        TextField(
                            "30 days — e.g. \"train 3x a week\"",
                            text: $store.onboardingDraft.physicalGoalTarget,
                            axis: .vertical
                        )
                        .textFieldStyle(MorpheFieldStyle())
                        .lineLimit(1...4)

                        TextField(
                            "60 days — e.g. \"down 5 lb, stronger squat\"",
                            text: $store.onboardingDraft.weightGoalTarget,
                            axis: .vertical
                        )
                        .textFieldStyle(MorpheFieldStyle())
                        .lineLimit(1...4)

                        TextField(
                            "90 days — e.g. \"first 5K\" or a date",
                            text: $store.onboardingDraft.goalDeadline,
                            axis: .vertical
                        )
                        .textFieldStyle(MorpheFieldStyle())
                        .lineLimit(1...4)
                    }
                } else {
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) { showMilestones = true }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "plus.circle")
                                .font(.caption.weight(.bold))
                            Text("Add 30/60/90-day milestones (optional)")
                                .font(.caption.weight(.semibold))
                            Spacer(minLength: 0)
                        }
                        .foregroundStyle(MorpheTheme.textSecondary)
                        .frame(minHeight: 44)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Add optional 30, 60, and 90 day milestones")
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

                // The interest picker (reference audit 2026-10-16: TikTok's
                // two-column icon grid).
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)], spacing: 8) {
                    ForEach(SportFocus.pickable) { sport in
                        ChoiceCard(
                            symbol: sport.symbol,
                            title: sport.rawValue,
                            isSelected: store.onboardingDraft.selectedSports.contains(sport),
                            multi: true,
                            compact: true
                        ) { store.toggleOnboardingSport(sport) }
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
            VStack(spacing: 8) {
                ForEach(ExperienceLevelOption.allCases) { level in
                    ChoiceCard(
                        symbol: level.symbol,
                        title: level.rawValue,
                        detail: level.detail,
                        isSelected: selection == level,
                        multi: false
                    ) { selection = level }
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
            subtitle: "Optional — share only what you're comfortable with. It stays in your profile (on your device + your own backup) and only shapes safer workout suggestions. Never a substitute for your doctor's advice."
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
                // One even row of seven (audit 2026-10-15: the wrap put
                // tiny chips in two columns with wide gaps).
                HStack(spacing: 6) {
                    ForEach(1...7, id: \.self) { count in
                        Button {
                            days = count
                        } label: {
                            Text("\(count)")
                                .frame(maxWidth: .infinity, minHeight: 32)
                        }
                        .buttonStyle(FilterChipStyle(isSelected: days == count, selectedColor: MorpheTheme.accent))
                        .accessibilityLabel("\(count) days per week")
                    }
                }

                Text("\(days) day\(days == 1 ? "" : "s") a week. Change it anytime.")
                    .font(.caption)
                    .foregroundStyle(MorpheTheme.textMuted)
            }
        }
    }
}

private struct ProfileReviewStep: View {
    @Environment(MorpheAppStore.self) private var store
    @State private var showFullTerms = false

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
                        .foregroundStyle(MorpheTheme.textPrimary)
                    Text(isCoach
                        ? "Coaching focus: \(store.onboardingDraft.sport.rawValue)"
                        : "Primary focus: \(store.onboardingDraft.sport.rawValue)")
                        .font(.subheadline)
                        .foregroundStyle(MorpheTheme.textSecondary)
                }

                Text(isCoach ? "What your workspace includes" : "What Morphe handles for you")
                    .font(.headline)
                    .foregroundStyle(MorpheTheme.textPrimary)

                if isCoach {
                    // The coach reviews a WORKSPACE, not an athlete training
                    // plan — these are the real surfaces they land in.
                    ForEach([
                        "An athlete roster that grows by invite codes",
                        "The full workout library, saves, and your own builds",
                        "An inbox for athlete outreach and follow-ups"
                    ], id: \.self) { item in
                        Text("•  \(item)")
                            .foregroundStyle(MorpheTheme.textPrimary)
                    }
                } else {
                    ForEach(generatedPlan.goalTranslation.weeklyActions, id: \.self) { action in
                        Text("•  \(action)")
                            .foregroundStyle(MorpheTheme.textPrimary)
                    }
                }

                // Only what the banner and bullets don't already say
                // (simplification wave 2026-10-15).
                if isCoach {
                    ProfileLine(title: "Practice size", value: store.onboardingDraft.coachRoster.rawValue)
                    ProfileLine(title: "Sports selected", value: store.onboardingDraft.selectedSports.map(\.shortTitle).joined(separator: ", "))
                }
                ProfileLine(title: "Goals", value: store.onboardingDraft.selectedGoals.map(\.rawValue).joined(separator: ", "))
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
                    ProfileLine(title: "First action", value: "Add your first client and share their invite code")
                    ProfileLine(title: "Workspace summary", value: "A \(store.onboardingDraft.sport.rawValue) coaching workspace sized for \(store.onboardingDraft.coachRoster.rawValue.lowercased()) — roster, library, and outreach in one place. Everything grows from the athletes you connect.")
                }
                // Required consent — the finish button stays disabled until
                // checked, and agreeing here satisfies the terms gate too.
                // The whole row is the target (audit 2026-10-15: taps on the
                // bare switch were missed, leaving Create Plan dead).
                Button {
                    store.onboardingDraft.agreedToTerms.toggle()
                } label: {
                    HStack(spacing: 12) {
                        Text("I agree to Morphe's Terms of Use")
                            .font(.subheadline)
                            .foregroundStyle(MorpheTheme.textPrimary)
                            .multilineTextAlignment(.leading)
                        Spacer(minLength: 8)
                        Toggle("", isOn: .constant(store.onboardingDraft.agreedToTerms))
                            .labelsHidden()
                            .tint(MorpheTheme.accent)
                            .allowsHitTesting(false)
                    }
                    .frame(minHeight: 44)
                    .contentShape(Rectangle())
                }
                .sensoryFeedback(.selection, trigger: store.onboardingDraft.agreedToTerms)
                .buttonStyle(.plain)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("I agree to Morphe's Terms of Use")
                .accessibilityValue(store.onboardingDraft.agreedToTerms ? "On" : "Off")
                .accessibilityAddTraits(.isToggle)

                // The document the toggle refers to, one tap away — agreeing
                // to invisible terms was an audit (and App Store) problem.
                Button("Read the full terms") {
                    showFullTerms = true
                }
                .font(.caption.weight(.semibold))
                .foregroundStyle(MorpheTheme.accentAlt)
                .sheet(isPresented: $showFullTerms) {
                    // A visible way out (audit 2026-10-07): read-only hides
                    // the agree/disagree bar, and nothing hinted at the swipe.
                    NavigationStack {
                        TermsGateView(readOnly: true)
                            .environment(store)
                            .background(PremiumBackground().ignoresSafeArea())
                            .toolbar {
                                ToolbarItem(placement: .topBarTrailing) {
                                    Button("Done") { showFullTerms = false }
                                        .font(.subheadline.weight(.semibold))
                                }
                            }
                    }
                }

                // App Store 1.2: consenting users must know abusive content
                // has zero tolerance and gets people removed.
                Text("Morphe has zero tolerance for abusive or objectionable content. Posts can be reported, accounts can be blocked, and repeat abuse ends the account.")
                    .font(.caption)
                    .foregroundStyle(MorpheTheme.textMuted)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

private struct PersonalizedPlanLoadingView: View {
    @Environment(MorpheAppStore.self) private var store
    @State private var message = "Reading your goals..."
    @State private var hasStarted = false
    /// How many lines have landed (each ticks to a check as it completes).
    @State private var done = -1

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

            MorpheWordmark(height: 30)
                .foregroundStyle(MorpheTheme.textPrimary)

            Text(store.onboardingDraft.accountType == .coach ? "Building your coach workspace..." : "Building your personalized plan...")
                .font(.headline)
                .foregroundStyle(MorpheTheme.textPrimary)

            VStack(alignment: .leading, spacing: 10) {
                ForEach(Array(messages.enumerated()), id: \.offset) { index, line in
                    HStack(spacing: 10) {
                        if index < done {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(MorpheTheme.accentText)
                        } else if index == done {
                            ProgressView().tint(MorpheTheme.accent).controlSize(.small)
                        } else {
                            Image(systemName: "circle")
                                .foregroundStyle(MorpheTheme.textMuted)
                        }
                        Text(line.replacingOccurrences(of: "...", with: ""))
                            .font(.subheadline.weight(index <= done ? .semibold : .regular))
                            .foregroundStyle(index <= done ? MorpheTheme.textPrimary : MorpheTheme.textMuted)
                    }
                    .animation(.easeInOut(duration: 0.25), value: done)
                }
            }
            .padding(.top, 4)

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

            // One short beat, not theater: the plan derivation is instant,
            // and 2.1s of scripted fake progress was a gate between the
            // user and their first real screen (UX audit P1-12).
            // The work is real (goals → catalog → week); showing it land
            // line by line is the "building your plan" beat every reference
            // app earns reciprocity with (audit 2026-10-16). ~2.4 s total.
            for (index, line) in messages.enumerated() {
                withAnimation(.easeInOut(duration: 0.25)) { message = line; done = index }
                try? await Task.sleep(for: .milliseconds(index == messages.count - 1 ? 900 : 750))
            }
            withAnimation(.easeInOut(duration: 0.25)) { done = messages.count }
            try? await Task.sleep(for: .milliseconds(350))

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
        // The question lives in Morphe's bubble above (Lucas 2026-10-17);
        // the title and subtitle are kept for accessibility only.
        GlassCard {
            VStack(alignment: .leading, spacing: 14) {
                content
            }
        }
        .accessibilityLabel(Text(title))
        .accessibilityHint(Text(subtitle))
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
                    .foregroundStyle(MorpheTheme.textPrimary)
            }
        }
    }
}


// MARK: - Choice cards (reference audit 2026-10-16)

/// The selectable card every question uses: symbol, title, optional
/// detail, a check when chosen. Full-width rows for single lists,
/// `compact` for the two-column interest grid.
private struct ChoiceCard: View {
    let symbol: String
    let title: String
    var detail: String? = nil
    let isSelected: Bool
    var multi: Bool = false
    var compact: Bool = false
    let action: () -> Void

    var body: some View {
        Button {
            Haptics.selection()
            action()
        } label: {
            HStack(spacing: compact ? 10 : 14) {
                Image(systemName: symbol)
                    .font(.system(size: compact ? 18 : 22, weight: .medium))
                    .foregroundStyle(isSelected ? MorpheTheme.onFill(MorpheTheme.accent) : MorpheTheme.accentText)
                    .frame(width: compact ? 24 : 32)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(compact ? .subheadline.weight(.semibold) : .body.weight(.semibold))
                        .foregroundStyle(isSelected ? MorpheTheme.onFill(MorpheTheme.accent) : MorpheTheme.textPrimary)
                        .lineLimit(compact ? 2 : 1)
                        .minimumScaleFactor(0.85)
                        .multilineTextAlignment(.leading)
                    if let detail {
                        Text(detail)
                            .font(.caption)
                            .foregroundStyle(isSelected ? MorpheTheme.onFill(MorpheTheme.accent).opacity(0.85) : MorpheTheme.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                Spacer(minLength: 4)
                if !compact {
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .font(.title3)
                        .foregroundStyle(isSelected ? MorpheTheme.onFill(MorpheTheme.accent) : MorpheTheme.textMuted)
                }
            }
            .padding(.horizontal, compact ? 12 : 16)
            .padding(.vertical, compact ? 12 : 14)
            .frame(maxWidth: .infinity, minHeight: compact ? 56 : 60, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: MorpheTheme.radius, style: .continuous)
                    .fill(isSelected ? MorpheTheme.accent : MorpheTheme.panel)
            )
            .overlay(
                RoundedRectangle(cornerRadius: MorpheTheme.radius, style: .continuous)
                    .stroke(isSelected ? Color.clear : MorpheTheme.stroke, lineWidth: 1)
            )
            .contentShape(RoundedRectangle(cornerRadius: MorpheTheme.radius, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(detail.map { "\(title), \($0)" } ?? title)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }
}

private extension FitnessGoalOption {
    var symbol: String {
        switch self {
        case .loseWeight: return "flame.fill"
        case .gainMuscle: return "figure.strengthtraining.traditional"
        case .improveSportPerformance: return "sportscourt.fill"
        case .buildConsistency: return "calendar.badge.checkmark"
        case .improveConditioning: return "heart.fill"
        case .getStronger: return "dumbbell.fill"
        case .returnAfterInjury: return "bandage.fill"
        case .prepareForEvent: return "flag.checkered"
        }
    }
}

private extension ExperienceLevelOption {
    var symbol: String {
        switch self {
        case .beginner: return "leaf.fill"
        case .intermediate: return "figure.walk.motion"
        case .advanced: return "bolt.fill"
        }
    }
    var detail: String {
        switch self {
        case .beginner: return "New, or coming back. Light loads, clear cues."
        case .intermediate: return "A year or more of steady training."
        case .advanced: return "Years in — you know your numbers."
        }
    }
}

private extension SportFocus {
    var symbol: String {
        switch self {
        case .generalFitness: return "figure.mixed.cardio"
        case .weightLoss: return "flame.fill"
        case .strength: return "dumbbell.fill"
        case .bodybuilding: return "figure.strengthtraining.traditional"
        case .personalTraining: return "figure.strengthtraining.functional"
        case .boxing: return "figure.boxing"
        case .mma: return "figure.martial.arts"
        case .soccer: return "soccerball"
        case .basketball: return "basketball.fill"
        case .football: return "football.fill"
        case .track: return "figure.track.and.field"
        case .running: return "figure.run"
        case .baseball: return "baseball.fill"
        case .tennis: return "tennis.racket"
        case .volleyball: return "volleyball.fill"
        case .wrestling: return "figure.wrestling"
        case .swimming: return "figure.pool.swim"
        case .hybridAthlete: return "figure.cross.training"
        }
    }
}



/// First run, before the account exists (Lucas 2026-10-16): a black
/// screen with [ TAP TO BEGIN ] slowly flashing; a tap turns the light on
/// from the center; the Spartan orb fades on with a bubble that says
/// hello, asks for a username and a birthday, and offers two doors —
/// **Build my profile** (the onboarding questions, highlighted) or
/// **Get started** (straight in, subtle). Shown once per install.
struct IntroView: View {
    @Environment(MorpheAppStore.self) private var store
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// tap → the light comes up on the Still Spartan ([ INACTIVE ]
    /// flickering under it) → a second tap anywhere: [ ACTIVE ], one
    /// second → morphe (the wake). Lucas 2026-10-17.
    private enum Phase { case tap, light, active, morphe }

    @State private var phase: Phase = .tap
    @State private var flash = false
    /// The dark over the Spartan in the light phase: 1 → 0 as the screen
    /// comes up, so it reads as lit, not as appearing.
    @State private var dark: Double = 1
    @State private var inactiveGlow = false
    @State private var lightScale: CGFloat = 0.01
    @State private var orbIn = false
    @State private var awake = false
    /// Morphe's beats after the wake (Lucas 2026-10-17): 1 "Hello there."
    /// · 2 "I am Morphe." · 3 what it was built for · 4 the bubbles leave
    /// and the orb shrinks to the top · 5 the question and the two doors.
    @State private var beat = 0
    @State private var chosen = false

    var body: some View {
        ZStack {
            // The dark before the light.
            Color.black.ignoresSafeArea()

            // The light turning on: a white disc growing from the center
            // until it is the screen.
            if phase != .tap {
                Circle()
                    .fill(Color.white)
                    .frame(width: 200, height: 200)
                    .scaleEffect(lightScale)
                    .ignoresSafeArea()
            }

            if phase == .light || phase == .active {
                revealed
                    .transition(.opacity)
            }

            if phase == .tap {
                Text("[ TAP TO BEGIN ]")
                    .font(MorpheTheme.microLabel(15))
                    .tracking(3)
                    .foregroundStyle(.white)
                    .opacity(flash ? 1 : 0.25)
                    .accessibilityAddTraits(.isButton)
                    .accessibilityHint("Starts Morphe")
                    .transition(.opacity)
            }

            if phase == .morphe {
                morphe
                    .transition(.opacity)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            switch phase {
            case .tap: begin()
            case .light: activate()
            default: break
            }
        }
        // `-MorpheIntroPreview`: both taps happen on their own, so the
        // simulator can capture the reveal and the wake (Lucas 2026-10-17).
        .task {
            guard ProcessInfo.processInfo.arguments.contains("-MorpheIntroPreview") else { return }
            try? await Task.sleep(for: .seconds(1))
            if phase == .tap { begin() }
            try? await Task.sleep(for: .milliseconds(2600))
            if phase == .light { activate() }
        }
        .onAppear {
            guard !reduceMotion else { flash = true; return }
            withAnimation(.easeInOut(duration: 1.4).repeatForever(autoreverses: true)) { flash = true }
        }
        .preferredColorScheme(.light)
        .statusBarHidden(phase == .tap)
    }

    // MARK: Beats

    private func begin() {
        Haptics.impact(.medium)
        withAnimation(.easeOut(duration: 0.25)) { phase = .light }
        // The light: fast at first, then it fills (an easeOut over 0.8 s).
        withAnimation(reduceMotion ? .easeInOut(duration: 0.3) : .easeOut(duration: 0.8)) { lightScale = 12 }
        // The Spartan was there in the dark: the shade over it lifts with
        // the light, a touch behind it.
        withAnimation(reduceMotion ? .easeInOut(duration: 0.3) : .easeOut(duration: 1.1).delay(0.15)) { dark = 0 }
        guard !reduceMotion else { inactiveGlow = true; return }
        withAnimation(.easeInOut(duration: 0.55).repeatForever(autoreverses: true).delay(0.6)) { inactiveGlow = true }
    }

    /// The second tap: [ ACTIVE ], one second, then the wake.
    private func activate() {
        Haptics.impact(.light)
        withAnimation(.easeOut(duration: 0.2)) { phase = .active }
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(1))
            orbIn = true
            withAnimation(.easeOut(duration: 0.3)) { phase = .morphe }
        }
    }

    /// Runs once the wake has settled on activated.
    private func speak() {
        let quick = reduceMotion
        Task { @MainActor in
            let bubble = Animation.spring(response: 0.45, dampingFraction: 0.78)
            try? await Task.sleep(for: .milliseconds(quick ? 100 : 400))
            withAnimation(bubble) { beat = 1 }                       // Hello there.
            try? await Task.sleep(for: .milliseconds(quick ? 200 : 1500))
            withAnimation(bubble) { beat = 2 }                       // I am Morphe.
            try? await Task.sleep(for: .milliseconds(quick ? 200 : 1500))
            withAnimation(bubble) { beat = 3 }                       // what I was built for
            try? await Task.sleep(for: .milliseconds(quick ? 300 : 4200))
            withAnimation(.easeInOut(duration: 0.3)) { beat = 4 }    // bubbles leave
            try? await Task.sleep(for: .milliseconds(quick ? 100 : 350))
            // The orb shrinks 35% and settles at the top — a fluid, slightly
            // magnetic spring.
            withAnimation(.spring(response: 0.75, dampingFraction: 0.62)) { orbTop = true }
            try? await Task.sleep(for: .milliseconds(quick ? 100 : 700))
            withAnimation(bubble) { beat = 5 }                       // the question
            try? await Task.sleep(for: .milliseconds(quick ? 100 : 600))
            withAnimation(.easeOut(duration: 0.4)) { doorsIn = true } // the two doors
        }
    }
    @State private var orbTop = false
    @State private var doorsIn = false

    private func choose(_ choice: MorpheAppStore.IntroChoice) {
        guard !chosen else { return }
        chosen = true
        Haptics.impact(.light)
        SoundEffects.play(.star)
        store.completeIntro(choice: choice)
    }

    // MARK: The reveal

    /// The No Power Spartan where the live orb will sit, under a shade
    /// that lifts with the light, and the state label beneath it. It holds
    /// until [ ACTIVE ]; one second later the wake we had before runs.
    private var revealed: some View {
        VStack(spacing: 18) {
            Image(SpartanFrame.noPower.imageName)
                .resizable().interpolation(.high).scaledToFit()
                .frame(width: 170, height: 170)
                .overlay(Color.black.opacity(dark))
                .clipShape(Circle())
                .accessibilityHidden(true)
            let lit = inactiveGlow || phase != .light
            // The word swaps in one frame (no crossfade — two labels
            // overlapping read as a glitch).
            Text(phase == .light ? "[ INACTIVE ]" : "[ ACTIVE ]")
                .transaction { $0.animation = nil }
                .foregroundStyle(lit ? MorpheTheme.brandBlue : MorpheTheme.brandBlueDeep)
                .shadow(color: MorpheTheme.brandBlue.opacity(lit ? 0.9 : 0), radius: lit ? 10 : 0)
            .font(MorpheTheme.microLabel(15))
            .tracking(3)
            .opacity(1 - dark)
            .accessibilityLabel(phase == .light ? "Inactive. Tap anywhere to activate Morphe." : "Active")
            .accessibilityAddTraits(phase == .light ? .isButton : [])
        }
        .padding(.top, 24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    // MARK: Morphe

    private var orbSide: CGFloat { orbTop ? 110 : 170 }   // −35% at the top

    private var morphe: some View {
        VStack(spacing: 0) {
            // The Spartan wakes after the tap (Lucas 2026-10-17), then the
            // live orb takes over — activated through all of onboarding.
            ZStack {
                if awake {
                    MorpheOrbView(level: 0.18, speaking: beat >= 1 && beat <= 3, frame: .activated)
                        .transition(.opacity)
                } else {
                    SpartanWakeView(duration: 1.3, superWake: true) {
                        withAnimation(.easeInOut(duration: 0.3)) { awake = true }
                        speak()
                    }
                }
            }
            .frame(width: orbSide, height: orbSide)
            .padding(.top, orbTop ? 8 : 24)
            .opacity(orbIn ? 1 : 0)
            .scaleEffect(orbIn || reduceMotion ? 1 : 0.9)
            .accessibilityHidden(true)

            // Morphe's lines, one bubble each, stacked as they land. The
            // words are Lucas's (2026-10-17).
            if beat >= 1 && beat <= 3 {
                VStack(spacing: 10) {
                    IntroBubble(tail: true) { line("Hello there.", bold: true) }
                    if beat >= 2 { IntroBubble(tail: false) { line("I am Morphe.", bold: true) } }
                    if beat >= 3 {
                        IntroBubble(tail: false) {
                            line("I was built to help strengthen your habits and fix your training so you can finally reach those goals you're always talking about.", bold: false)
                        }
                    }
                }
                .padding(.top, -6)
                .transition(.opacity.combined(with: .scale(scale: 0.92, anchor: .top)))
            }

            if beat >= 5 {
                VStack(spacing: 18) {
                    IntroBubble(tail: true) {
                        line("Do you have your profile set up already? Or do you need to build one now?", bold: true)
                    }
                    VStack(spacing: 12) {
                        Button {
                            choose(.buildProfile)
                        } label: {
                            Label("Build one now", systemImage: "person.crop.circle.badge.plus")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(PrimaryCTAButtonStyle(accent: MorpheTheme.accent))
                        .shadow(color: MorpheTheme.accent.opacity(0.35), radius: 14, y: 6)

                        Button {
                            choose(.signIn)
                        } label: {
                            Label("I have a profile", systemImage: "person.crop.circle.badge.checkmark")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(SecondaryCTAButtonStyle())
                    }
                    .opacity(doorsIn ? 1 : 0)
                    .offset(y: doorsIn || reduceMotion ? 0 : 10)

                    Text("Continuing agrees to the Terms and the Privacy Policy.")
                        .font(.caption2)
                        .foregroundStyle(MorpheTheme.textMuted)
                        .multilineTextAlignment(.center)
                        .opacity(doorsIn ? 1 : 0)
                }
                .padding(.top, -6)
                .transition(.opacity.combined(with: .scale(scale: 0.92, anchor: .top)))
            }

            Spacer(minLength: 24)
        }
        .frame(maxWidth: 360)
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 24)
    }

    private func line(_ text: String, bold: Bool) -> some View {
        Text(text)
            .font(bold ? .headline.weight(.bold) : .subheadline)
            .foregroundStyle(bold ? MorpheTheme.textPrimary : MorpheTheme.textSecondary)
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
    }
}

/// One of Morphe's bubbles (Lucas 2026-10-17): the first in a run carries
/// the tail up toward the orb, the rest are plain. Solid, like the pop-up's.
struct IntroBubble<Content: View>: View {
    var tail: Bool
    @ViewBuilder var content: () -> Content

    private var fill: Color {
        MorpheTheme.isLight
            ? Color(red: 0.96, green: 0.96, blue: 0.965)
            : Color(red: 0.125, green: 0.125, blue: 0.135)
    }

    var body: some View {
        VStack(spacing: 0) {
            if tail {
                Triangle()
                    .fill(fill)
                    .frame(width: 22, height: 11)
            }
            content()
                .padding(.horizontal, 18)
                .padding(.vertical, 14)
                .frame(maxWidth: 340)
                .background(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(fill)
                        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(MorpheTheme.stroke, lineWidth: 1))
                        .shadow(color: .black.opacity(0.14), radius: 4, y: 3)
                        .shadow(color: .black.opacity(0.14), radius: 26, y: 14)
                )
        }
    }
}
