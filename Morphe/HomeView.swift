import SwiftUI

struct HomeView: View {
    @Environment(MorpheAppStore.self) private var store
    @State private var showAdjustments = false
    @State private var showSupport = false
    @State private var showAppointments = false
    @State private var showEmptyLibraryNotice = false

    private var morpheScoreTitle: String {
        switch store.clientProfile.health.score {
        case 90...100: return "Peak"
        case 75...89: return "Strong"
        case 60...74: return "Momentum"
        case 40...59: return "Building"
        case 1...39: return "Rebuilding"
        default: return "Getting Started"
        }
    }

    private var upcomingGoalText: String {
        if let athlete = store.clientAthleteProfile {
            return "\(athlete.goal) - \(athlete.competitionDate)"
        }

        // Goal + real cadence — no invented "weekly review in 3 days" promise.
        let goal = store.clientProfile.goal.isEmpty ? "Building the habit" : store.clientProfile.goal
        return "\(goal) - \(store.clientProfile.trainingDaysPerWeek) days a week"
    }

    private var todayWinText: String {
        if store.minimumWinModeEnabled {
            return "Keep the habit alive with one small win."
        }

        // Habit-only copy (audit D5): the hero owns the workout instruction;
        // this card owns the small wins around it — no more echo.
        return "Close the day strong — protein, water, and enough sleep to earn tomorrow."
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 16) {
                // Once today's session is logged, the "Today's Workout" card
                // becomes the "You're done for today" card in place — no
                // overlay, no page takeover. "Do another session" keeps the
                // second-workout path alive via the Train tab.
                // A lapsed streak gets acknowledged once, above the fold —
                // no guilt, one ramp back in. Any log or a dismissal
                // retires it (see detectStreakLapse).
                if let lapsed = store.comebackLapsedStreak, !store.isWorkoutLoggedToday {
                    ComebackCard(
                        lapsedStreak: lapsed,
                        onMinimumWin: {
                            store.activateMinimumWinMode()
                            store.dismissComebackCard()
                        },
                        onDismiss: { store.dismissComebackCard() }
                    )
                }

                if store.isWorkoutLoggedToday {
                    TodayDoneCard(
                        workoutName: store.currentWorkout.name,
                        // The tomorrow-hook (audit E3): the done-state names
                        // what's next instead of ending the relationship
                        // for the day.
                        nextUpLine: "Up next: \(store.currentWorkout.name) — see you tomorrow.",
                        onViewProgress: { store.openProgress() },
                        onTrainAgain: { store.selectedClientTab = .train }
                    )
                } else {
                    TodayNextMoveCard(
                        workout: store.currentWorkout,
                        minimumWinModeEnabled: store.minimumWinModeEnabled,
                        // Assist chips demoted to the AI pill (audit D10) —
                        // same answers, one fewer CTA pair on the hero.
                        showAssistRow: false,
                        onStart: { store.startTodayWorkout() },
                        onActivateMinimumWin: { store.activateMinimumWinMode() },
                        onSwitch: {
                            if !store.requestWorkoutSwitch() {
                                showEmptyLibraryNotice = true
                            }
                        }
                    )
                }

                // The day-7 bridge: five derived checkmarks that walk a new
                // user from first session to habit. Gone after week one.
                if let steps = store.firstWeekSteps {
                    FirstWeekCard(steps: steps)
                }

                // Progressive disclosure: a first-run user sees the hero and
                // who they are — no zero-metrics, no tools that need history.
                // Everything below is earned by logging workouts (see
                // todayExperienceTier).
                TodayStatusStrip(
                    showcase: store.profileShowcase,
                    goal: store.clientProfile.goal,
                    fitnessLevel: store.clientProfile.fitnessLevel,
                    coachName: store.clientProfile.planCreatedBy,
                    recovery: store.recovery,
                    morpheScore: store.clientProfile.health.score,
                    morpheTier: morpheScoreTitle,
                    morpheDetail: store.clientProfile.health.detail,
                    showMetrics: store.todayExperienceTier >= 1,
                    hasCheckedIn: store.didCompleteQuickCheckIn
                )

                if store.todayExperienceTier >= 2, let insight = store.primaryAthletePatternInsight {
                    HomePatternInsightCard(insight: insight) {
                        store.openProgress()
                    }
                }

                if !store.isWorkoutLoggedToday {
                    if store.minimumWinModeEnabled {
                        MinimumWinModeCard(
                            message: store.minimumWinMessage,
                            tasks: store.minimumWinTasks,
                            onToggle: { task in
                                store.toggleMinimumWinTask(task)
                            },
                            onExit: { store.deactivateMinimumWinMode() }
                        )
                    } else {
                        // Daily wins stay visible from day 0 — small
                        // checkable tasks give a brand-new user something to
                        // complete before the metrics exist.
                        TodayPlanCard(
                            todayWinText: todayWinText,
                            personalizationNote: store.taskPlanNote,
                            tasks: store.todayTasks,
                            onToggleTask: { store.toggleTask($0) }
                        )
                    }

                    // The check-in otherwise lives inside "If plans change",
                    // which is earned at tier 1 — a brand-new user had no way
                    // to reach the one input that personalizes their day.
                    if store.todayExperienceTier == 0 {
                        TierZeroCheckInCard(isComplete: store.didCompleteQuickCheckIn)
                    }
                }

                if store.todayExperienceTier >= 1 || store.minimumWinModeEnabled {
                HomeExpandableSection(
                    title: "If plans change",
                    subtitle: adjustmentSubtitle,
                    isExpanded: $showAdjustments
                ) {
                    if !store.isWorkoutLoggedToday,
                       (store.minimumWinModeEnabled || store.selectedConfidence == .notConfident || store.selectedPlanBReason != nil) {
                        SmartPlanAdjustmentCard(adjustment: store.currentPlanAdjustment)
                    }

                    // Derived from real logs/check-ins when they exist; the
                    // static tips are only the zero-data fallback (AI-6).
                    AIInsightCard(insight: store.isWorkoutLoggedToday ? store.derivedProgressInsight : store.derivedTodayInsight)

                    if !store.isWorkoutLoggedToday {
                        DailyCheckInPlannerCard(
                            isComplete: store.didCompleteQuickCheckIn,
                            selectedConfidence: store.selectedConfidence,
                            selectedReason: store.selectedPlanBReason,
                            onSelectConfidence: { store.selectConfidence($0) },
                            onSelectPlanB: { reason in
                                store.choosePlanB(reason)
                            },
                            onMinimumWin: { store.activateMinimumWinMode() },
                            onShorterWorkout: { store.applyWorkoutAdjustment(.shorter) },
                            onRecoveryWorkout: { store.applyWorkoutAdjustment(.recovery) },
                            onReschedule: { store.applyWorkoutAdjustment(.reschedule) }
                        )
                    }
                }
                }

                if store.todayExperienceTier >= 2 {
                HomeExpandableSection(
                    title: "Support & progress",
                    subtitle: supportSubtitle,
                    isExpanded: $showSupport
                ) {
                    // One context card (audit D7): plan + phase + goal in a
                    // single read instead of three look-alike link cards.
                    WorkoutPlanByCoachMiniCard(
                        profile: store.clientProfile,
                        phase: store.profileShowcase.currentPhase,
                        goalLine: upcomingGoalText
                    )

                    if FeatureFlags.multiUserEnabled {
                        PartnerWorkoutCard(
                            partners: store.workoutPartners,
                            selectedPartner: store.selectedWorkoutPartner,
                            selectedMode: store.selectedPartnerWorkoutMode,
                            isEnabled: store.partnerWorkoutEnabled,
                            plan: store.currentPartnerWorkoutPlan,
                            onSelectPartner: { store.selectWorkoutPartner($0) },
                            onSelectMode: { store.selectPartnerWorkoutMode($0) },
                            onToggleEnabled: { store.togglePartnerWorkout($0) }
                        )
                    }

                    if store.minimumWinModeEnabled || store.selectedPlanBReason != nil || store.streakProtected {
                        StreakProtectionCard(
                            isProtected: store.streakProtected,
                            options: MorpheDemoContent.streakProtectionOptions
                        ) { option in
                            store.protectStreak(with: option)
                        }
                    }

                    MorpheHubEntryCard {
                        store.openProgress()
                    } openMore: {
                        store.openMore(.scores)
                    }
                }
                }

                // REAL coach messaging: only exists once a coach link is real
                // (the athlete claimed an invite and a thread exists). An
                // athlete without a coach never sees a Coach card at all.
                // When Coach and Schedule are BOTH present they share one
                // slim two-column row so Today doesn't end in a stack of
                // look-alike link-cards.
                if store.liveThreads.isEmpty {
                    scheduleLinkCard
                } else {
                    HStack(alignment: .top, spacing: 12) {
                        HomeLinkTile(
                            systemImage: "bubble.left.and.bubble.right.fill",
                            title: "Coach",
                            detail: coachTileDetail,
                            detailIsMuted: coachTileDetailIsMuted,
                            accessibilityLabel: "Coach messages"
                        ) {
                            // Deep-link into the one messaging surface —
                            // Network → Contact auto-opens a lone thread.
                            store.openCommunity(.contact)
                        }

                        HomeLinkTile(
                            systemImage: "calendar.badge.clock",
                            title: "Schedule",
                            detail: scheduleTileDetail,
                            detailIsMuted: store.upcomingAppointments.isEmpty,
                            accessibilityLabel: "Schedule"
                        ) {
                            showAppointments = true
                        }
                    }
                }
            }
            .padding(.horizontal, 20)
            // Starts clearly BELOW the floating profile icon, matching where
            // the Progress/Learn titles sit.
            .padding(.top, MorpheTheme.Spacing.pageTopToday)
            .padding(.bottom, 120)
        }
        // The network-backed pieces of Today (coach threads, appointments)
        // refresh on pull, like Network already does.
        .refreshable {
            await store.refreshThreads()
            await store.refreshAppointments()
        }
        .animation(.easeInOut(duration: 0.25), value: store.isWorkoutLoggedToday)
        .sheet(isPresented: $showAppointments) {
            NavigationStack {
                ClientAppointmentsView()
                    .environment(store)
            }
        }
        .alert("Your library is empty", isPresented: $showEmptyLibraryNotice) {
            Button("Browse Discover") { store.showDiscoverTab() }
            Button("Got It", role: .cancel) {}
        } message: {
            Text("Save or start workouts from the Discover page, or build your own in Train under My Library.")
        }
    }

    /// Personal schedule as a full-width card — used when there is no Coach
    /// card to pair with. Real per-account data (Firestore).
    private var scheduleLinkCard: some View {
        Button {
            showAppointments = true
        } label: {
            GlassCard {
                HStack(spacing: 12) {
                    Image(systemName: "calendar.badge.clock")
                        .font(.headline)
                        .foregroundStyle(MorpheTheme.accent)
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Schedule")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.white)
                        if let next = store.upcomingAppointments.first {
                            Text("\(next.title) — \(next.date.formatted(date: .abbreviated, time: .shortened))")
                                .font(.caption)
                                .foregroundStyle(MorpheTheme.textSecondary)
                                .lineLimit(1)
                        } else {
                            Text("No appointments yet — add training sessions or check-ins.")
                                .font(.caption)
                                .foregroundStyle(MorpheTheme.textMuted)
                        }
                    }
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(MorpheTheme.textMuted)
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Schedule")
    }

    private var coachTileDetail: String {
        guard let first = store.liveThreads.first else { return "" }
        let name = first.counterpartName(for: store.authUser?.id ?? "")
        return first.lastMessage.isEmpty
            ? "\(name) — no messages yet"
            : "\(name): \(first.lastMessage)"
    }

    private var coachTileDetailIsMuted: Bool {
        store.liveThreads.first?.lastMessage.isEmpty ?? true
    }

    private var scheduleTileDetail: String {
        if let next = store.upcomingAppointments.first {
            return "\(next.title) — \(next.date.formatted(date: .abbreviated, time: .shortened))"
        }
        return "No appointments yet"
    }

    private var adjustmentSubtitle: String {
        if store.isWorkoutLoggedToday {
            return "Use this only if you want the recap or a lighter next step."
        }

        if store.selectedConfidence == .notConfident || store.selectedPlanBReason != nil || store.minimumWinModeEnabled {
            return "Open this when the original plan starts feeling too heavy."
        }

        return "Shorten it, recover, or reset the day without breaking the habit."
    }

    private var supportSubtitle: String {
        if store.partnerWorkoutEnabled, let partner = store.selectedWorkoutPartner {
            return "\(partner.name), your plan context, and your next checkpoint stay here when you want them."
        }

        return "Your plan's context and progress checkpoints stay here without crowding the top of the day."
    }
}

/// Slim half-width link tile — used when Coach and Schedule share one
/// two-column row at the bottom of Today.
private struct HomeLinkTile: View {
    let systemImage: String
    let title: String
    let detail: String
    let detailIsMuted: Bool
    let accessibilityLabel: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            GlassCard {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Image(systemName: systemImage)
                            .font(.headline)
                            .foregroundStyle(MorpheTheme.accent)
                        Spacer(minLength: 0)
                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(MorpheTheme.textMuted)
                    }

                    Text(title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                        .lineLimit(1)

                    Text(detail)
                        .font(.caption)
                        .foregroundStyle(detailIsMuted ? MorpheTheme.textMuted : MorpheTheme.textSecondary)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
    }
}

private struct HomePatternInsightCard: View {
    let insight: AthletePatternInsight
    let onOpenProgress: () -> Void

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: insight.systemImage)
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(MorpheTheme.accentAlt)
                        .frame(width: 36, height: 36)
                        .background(
                            RoundedRectangle(cornerRadius: MorpheTheme.radius, style: .continuous)
                                .fill(MorpheTheme.panelRaised)
                        )

                    VStack(alignment: .leading, spacing: 4) {
                        Text("What works for you")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(MorpheTheme.textMuted)
                        Text(insight.title)
                            .font(.headline)
                            .foregroundStyle(.white)
                    }

                    Spacer()

                    StatusBadge(text: insight.badge, color: MorpheTheme.accentAlt)
                }

                Text(insight.detail)
                    .font(.subheadline)
                    .foregroundStyle(MorpheTheme.textSecondary)

                Button("See Patterns") {
                    onOpenProgress()
                }
                .buttonStyle(SecondaryCTAButtonStyle())
                .accessibilityLabel("See more patterns in Progress")
            }
        }
    }
}

private struct TodayStatusStrip: View {
    let showcase: ProfileShowcase
    let goal: String
    let fitnessLevel: String
    let coachName: String
    let recovery: RecoverySnapshot
    let morpheScore: Int
    let morpheTier: String
    let morpheDetail: String
    /// False on first run: a new user has no readiness/score/energy yet, so
    /// showing three zeros would only be noise to decode.
    var showMetrics: Bool = true
    /// Readiness/energy are measurements only after a check-in — before one,
    /// the default RecoverySnapshot is a synthetic starting point and renders
    /// as an em dash instead of pretending to be data.
    var hasCheckedIn: Bool = false

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 12) {
                    MorpheAvatarView(avatar: showcase.avatar, size: 54)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(showcase.displayName)
                            .font(.headline.weight(.bold))
                            .foregroundStyle(.white)
                        Text("\(goal) • \(fitnessLevel)")
                            .font(.caption)
                            .foregroundStyle(MorpheTheme.textSecondary)
                    }

                    Spacer()

                    if showMetrics {
                        VStack(alignment: .trailing, spacing: 4) {
                            Text("Plan by \(coachName)")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(MorpheTheme.textMuted)
                            Text(morpheTier)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.white)
                        }
                    }
                }

                if showMetrics {
                    HStack(spacing: 8) {
                        MetricPill(label: "Readiness", value: hasCheckedIn ? "\(recovery.score)" : "—")
                        MetricPill(label: "Score", value: "\(morpheScore)")
                        MetricPill(label: "Energy", value: hasCheckedIn ? "\(recovery.energy)/10" : "—")
                    }

                    // "Plan by" already sits top-right in this card.
                    Text(morpheDetail)
                        .font(.caption)
                        .foregroundStyle(MorpheTheme.textSecondary)
                } else {
                    Text("Morphe Score reads your consistency (sessions + streak, 10–100), readiness comes from your check-ins, and energy is what you report. All three go live with your first logged workout.")
                        .font(.caption)
                        .foregroundStyle(MorpheTheme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }
}

private struct HomeExpandableSection<Content: View>: View {
    let title: String
    let subtitle: String
    @Binding var isExpanded: Bool
    @ViewBuilder let content: () -> Content

    var body: some View {
        // Flat HUD disclosure: tracked mono label + hairline rule + a +/-
        // indicator. No bubble — the rule IS the section boundary.
        VStack(alignment: .leading, spacing: 12) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isExpanded.toggle()
                }
            } label: {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 10) {
                        Text(title.uppercased())
                            .font(MorpheTheme.microLabel(12))
                            .tracking(1.6)
                            .foregroundStyle(.white)
                            .lineLimit(1)
                            .layoutPriority(1)

                        Rectangle()
                            .fill(MorpheTheme.stroke)
                            .frame(height: 1)
                            .frame(maxWidth: .infinity)

                        Image(systemName: isExpanded ? "minus" : "plus")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(MorpheTheme.accent)
                    }

                    if !isExpanded {
                        Text(subtitle)
                            .font(.footnote)
                            .foregroundStyle(MorpheTheme.textMuted)
                            .multilineTextAlignment(.leading)
                    }
                }
                .padding(.vertical, 6)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if isExpanded {
                VStack(alignment: .leading, spacing: 14) {
                    content()
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }
}

/// Replaces TodayNextMoveCard in the hero slot once today's session is
/// logged — same card, new state, instead of an overlay hiding the page.
/// The streak's honest ending: names the run that ended, offers the
/// smallest way back in, and never shows again once answered.
private struct ComebackCard: View {
    let lapsedStreak: Int
    let onMinimumWin: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 10) {
                    Image(systemName: "arrow.counterclockwise.circle.fill")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(MorpheTheme.accent)
                    Text("Rebuilding starts today.")
                        .font(.title3.weight(.bold))
                        .foregroundStyle(.white)
                }

                Text("Your \(lapsedStreak)-day streak ended. That run was real — and the next one starts with one small win, not a perfect week.")
                    .foregroundStyle(MorpheTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 10) {
                    Button("Minimum Win", action: onMinimumWin)
                        .frame(maxWidth: .infinity)
                        .buttonStyle(PrimaryCTAButtonStyle(accent: MorpheTheme.accent))
                        .accessibilityLabel("Start a minimum win session")
                    Button("Dismiss", action: onDismiss)
                        .buttonStyle(SecondaryCTAButtonStyle())
                }
            }
        }
    }
}

private struct TodayDoneCard: View {
    @Environment(MorpheAppStore.self) private var store
    let workoutName: String
    var nextUpLine: String = ""
    let onViewProgress: () -> Void
    let onTrainAgain: () -> Void

    /// The rendered story card, alive while the share sheet is up.
    private struct SharePayload: Identifiable {
        let id = UUID()
        /// Nil = render failed; the sheet shares the caption text alone.
        let image: UIImage?
        let caption: String
    }
    @State private var sharePayload: SharePayload?

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 10) {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(MorpheTheme.accent)
                    Text("You're done for today.")
                        .font(.title3.weight(.bold))
                        .foregroundStyle(.white)
                }

                Text("You closed the loop on \(workoutName). Nice work — the rest of today is yours.")
                    .foregroundStyle(MorpheTheme.textSecondary)

                if !nextUpLine.isEmpty {
                    Text(nextUpLine)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(MorpheTheme.accent)
                }

                HStack(spacing: 10) {
                    // The Strava-sticker play: a branded story IMAGE of the
                    // real session (sets/moves/minutes/PRs/streak), not a
                    // plain sentence. A failed render REALLY falls back to
                    // sharing the caption text — a button that sometimes
                    // does nothing reads as broken.
                    Button("Share Win") {
                        // Async render: the poster rasterizes off-main so
                        // this tap never hitches.
                        Task {
                            var image: UIImage?
                            if let data = store.latestSessionShareCardData {
                                image = await ShareCardRenderer.imageAsync(for: data)
                            }
                            sharePayload = SharePayload(image: image, caption: store.shareCardCaption)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .buttonStyle(PrimaryCTAButtonStyle(accent: MorpheTheme.accent))
                    .accessibilityLabel("Share a story card of this session")
                    Button("View Progress", action: onViewProgress)
                        .buttonStyle(SecondaryCTAButtonStyle())
                }
                .sheet(item: $sharePayload) { payload in
                    ImageShareSheet(image: payload.image, caption: payload.caption) { completed in
                        if completed {
                            store.noteShareCardShared()
                        }
                        sharePayload = nil
                    }
                    .presentationDetents([.medium, .large])
                }

                Button("Go Again", action: onTrainAgain)
                    .buttonStyle(SecondaryCTAButtonStyle())
                    .frame(maxWidth: .infinity)
                    .accessibilityLabel("Do another session")
            }
        }
    }
}

private struct TodayNextMoveCard: View {
    @Environment(MorpheAppStore.self) private var store
    let workout: WorkoutTemplate
    let minimumWinModeEnabled: Bool
    /// Hidden on first run so the hero is exactly one decision: Start.
    var showAssistRow: Bool = true
    let onStart: () -> Void
    let onActivateMinimumWin: () -> Void
    let onSwitch: () -> Void
    @State private var inlineReply: String?

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 14) {
                Text(minimumWinModeEnabled ? "Today's fallback is active" : "Today's Workout")
                    .font(.headline)
                    .foregroundStyle(.white)

                if minimumWinModeEnabled {
                    Text("Momentum is the goal today. Keep the day light, protect the streak, and come back stronger tomorrow.")
                        .foregroundStyle(MorpheTheme.textSecondary)

                    HStack(spacing: 10) {
                        // The mode is already on — re-activating it did
                        // nothing, so this reads as state, not a button.
                        StatusBadge(text: "Fallback Active", color: MorpheTheme.accentAlt)
                            .accessibilityLabel("Minimum Win mode is active")

                        Button("Switch Workout", action: onSwitch)
                            .buttonStyle(SecondaryCTAButtonStyle())
                    }
                } else {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(workout.name)
                            .font(.title3.weight(.bold))
                            .foregroundStyle(.white)
                        Text("\(workout.durationMinutes) min • \(workout.goal)")
                            .foregroundStyle(MorpheTheme.textSecondary)
                        // Present only when recent ratings/finish times have
                        // actually tilted the plan — silence means holding.
                        if let intensityNote = store.workoutIntensityNote {
                            Text(intensityNote)
                                .font(.footnote)
                                .foregroundStyle(MorpheTheme.accent.opacity(0.9))
                        }
                    }

                    HStack(spacing: 10) {
                        Button("Start", action: onStart)
                            .buttonStyle(PrimaryCTAButtonStyle(accent: MorpheTheme.accent))
                            .accessibilityLabel("Start today's plan")

                        Button("Switch Workout", action: onSwitch)
                            .buttonStyle(SecondaryCTAButtonStyle())
                    }
                }

                if showAssistRow {
                    Divider()
                        .overlay(Color.white.opacity(0.08))

                    VStack(alignment: .leading, spacing: 10) {
                        Text("Morphe can help right here")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.white)

                        WrapStack(spacing: 8) {
                            Button("Why This?") {
                                inlineReply = store.previewAIAgentReply(for: "Why is this the right plan for today?")
                            }
                            .buttonStyle(FilterChipStyle(isSelected: false, selectedColor: MorpheTheme.accentAlt))
                            .accessibilityLabel("Why this plan?")

                            Button("Adjust Day") {
                                inlineReply = store.previewAIAgentReply(for: "Adjust today's plan for me")
                            }
                            .buttonStyle(FilterChipStyle(isSelected: false, selectedColor: MorpheTheme.accent))
                            .accessibilityLabel("Adjust my day")
                        }

                        if let inlineReply {
                            Text(inlineReply)
                                .font(.subheadline)
                                .foregroundStyle(MorpheTheme.textPrimary)
                                .padding(12)
                                .background(
                                    RoundedRectangle(cornerRadius: MorpheTheme.radius, style: .continuous)
                                        .fill(MorpheTheme.panelStrong)
                                )
                        }
                    }
                }
            }
        }
    }
}

/// Bottom-of-Today entry into coach + friend messaging. Morphe AI lives on the
/// floating button, not here. For a solo v1 user this opens an honest empty
/// inbox — real conversations arrive with accounts/coach linking.
private struct WorkoutPlanByCoachMiniCard: View {
    let profile: ClientProfile
    let phase: String
    /// The goal line that used to be its own look-alike card (audit D7).
    var goalLine: String = ""

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    MetricPill(label: "Plan By", value: profile.planCreatedBy)
                    MetricPill(label: "Current Phase", value: phase)
                }

                Text("\(profile.currentProgram) is your starting plan, built from your goal, sport, and schedule. Adjust anything — your check-ins shape the day-to-day suggestions.")
                    .font(.subheadline)
                    .foregroundStyle(MorpheTheme.textSecondary)

                if !goalLine.isEmpty {
                    Divider().overlay(Color.white.opacity(0.08))
                    HStack(spacing: 6) {
                        Image(systemName: "target")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(MorpheTheme.accent)
                        Text(goalLine)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.white)
                    }
                }
            }
        }
    }
}

private struct TierZeroCheckInCard: View {
    @Environment(MorpheAppStore.self) private var store
    let isComplete: Bool
    @State private var showCheckIn = false

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 10) {
                Text("How ready are you today?")
                    .font(.headline)
                    .foregroundStyle(.white)
                Text(isComplete
                     ? "Readiness \(store.recovery.score) • \(store.recovery.status.rawValue). \(store.recovery.reason)"
                     : "A 30-second check-in helps Morphe size today's workout to how you actually feel.")
                    .font(.subheadline)
                    .foregroundStyle(MorpheTheme.textSecondary)
                Button(isComplete ? "Update Check-In" : "Check In") {
                    showCheckIn = true
                }
                .buttonStyle(SecondaryCTAButtonStyle())
            }
        }
        .sheet(isPresented: $showCheckIn) {
            RecoveryCheckInSheet(recovery: store.recovery)
                .environment(store)
        }
    }
}

private struct DailyCheckInPlannerCard: View {
    @Environment(MorpheAppStore.self) private var store
    let isComplete: Bool
    let selectedConfidence: ConfidenceLevel?
    let selectedReason: PlanBReason?
    let onSelectConfidence: (ConfidenceLevel) -> Void
    let onSelectPlanB: (PlanBReason) -> Void
    let onMinimumWin: () -> Void
    let onShorterWorkout: () -> Void
    let onRecoveryWorkout: () -> Void
    let onReschedule: () -> Void
    @State private var showPlanBOptions = false
    @State private var showCheckIn = false

    private var shouldShowFallbacks: Bool {
        showPlanBOptions || selectedConfidence == .notConfident || selectedReason != nil
    }

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 14) {
                Text("Adjust My Day")
                    .font(.headline)
                    .foregroundStyle(.white)

                Text(isComplete ? "Readiness \(store.recovery.score) • \(store.recovery.status.rawValue). \(store.recovery.reason)" : "A quick check-in lets Morphe read your recovery and adjust today.")
                    .foregroundStyle(MorpheTheme.textSecondary)

                Button(isComplete ? "Update Check-In" : "Check In") {
                    showCheckIn = true
                }
                .buttonStyle(PrimaryCTAButtonStyle(accent: isComplete ? MorpheTheme.accentAlt : MorpheTheme.accent))

                Divider()
                    .overlay(Color.white.opacity(0.08))

                Text("How confident are you that you can complete this today?")
                    .font(.headline)
                    .foregroundStyle(.white)

                HStack(spacing: 8) {
                    ForEach(ConfidenceLevel.allCases) { level in
                        Button(level.rawValue) {
                            onSelectConfidence(level)
                            if level == .notConfident {
                                showPlanBOptions = true
                            }
                        }
                        .buttonStyle(FilterChipStyle(isSelected: selectedConfidence == level, selectedColor: MorpheTheme.accent))
                    }
                }

                // Progressive disclosure (audit D4): the easier-options
                // layer only appears once the user has answered the
                // confidence question — 13 simultaneous controls became
                // two steps.
                if selectedConfidence != nil || shouldShowFallbacks {
                    HStack {
                        Text("Not feeling it? Easier options")
                            .font(.headline)
                            .foregroundStyle(.white)
                        Spacer()
                        Button(showPlanBOptions ? "Hide" : "Show Options") {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                showPlanBOptions.toggle()
                            }
                        }
                        .buttonStyle(SecondaryCTAButtonStyle())
                        .frame(width: 120)
                    }
                }

                if shouldShowFallbacks {
                    Text("Let's make this easier today.")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(MorpheTheme.warning)

                    WrapStack(spacing: 8) {
                        ForEach(PlanBReason.allCases) { reason in
                            Button(reason.rawValue) {
                                onSelectPlanB(reason)
                                showPlanBOptions = true
                            }
                            .buttonStyle(FilterChipStyle(isSelected: selectedReason == reason, selectedColor: MorpheTheme.accentAlt))
                        }
                    }

                    Button("Minimum Win", action: onMinimumWin)
                        .buttonStyle(PrimaryCTAButtonStyle(accent: MorpheTheme.accent))
                        .accessibilityLabel("Switch to Minimum Win mode")

                    HStack(spacing: 10) {
                        Button("Shorter Workout", action: onShorterWorkout)
                            .buttonStyle(SecondaryCTAButtonStyle())
                        Button("Recovery Session", action: onRecoveryWorkout)
                            .buttonStyle(SecondaryCTAButtonStyle())
                    }

                    Button("Tomorrow", action: onReschedule)
                        .buttonStyle(SecondaryCTAButtonStyle())
                        .accessibilityLabel("Move workout to tomorrow")
                }
            }
        }
        .sheet(isPresented: $showCheckIn) {
            RecoveryCheckInSheet(recovery: store.recovery)
                .environment(store)
        }
    }
}

private struct RecoveryCheckInSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(MorpheAppStore.self) private var store

    @State private var sleepHours: Double
    @State private var energy: Int
    @State private var soreness: Int
    @State private var mood: Int
    @State private var pain: Bool
    /// The exact value Health seeded (nil = not seeded). The "from Health"
    /// label shows only while the slider still holds this value — any
    /// manual nudge makes the number the user's, not Health's.
    @State private var healthSeededSleep: Double?
    private var sleepFromHealth: Bool {
        healthSeededSleep.map { abs(sleepHours - $0) < 0.01 } ?? false
    }

    init(recovery: RecoverySnapshot) {
        _sleepHours = State(initialValue: recovery.sleepHours > 0 ? recovery.sleepHours : 7)
        _energy = State(initialValue: max(1, recovery.energy))
        _soreness = State(initialValue: recovery.soreness)
        _mood = State(initialValue: max(1, recovery.mood))
        _pain = State(initialValue: recovery.pain)
    }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 20) {
                    Text("How recovered do you feel today? Morphe uses this to set your readiness and adjust the plan.")
                        .font(.subheadline)
                        .foregroundStyle(MorpheTheme.textSecondary)
                        .task {
                            // Opt-in Health pre-fill: seeds the slider once,
                            // rounded to the slider's own 0.5 step. No data
                            // (or a declined read) changes nothing — and a
                            // user who already moved the slider while the
                            // query ran is NEVER stomped.
                            let valueBeforeQuery = sleepHours
                            if let hours = await store.healthSleepHoursForCheckIn(),
                               sleepHours == valueBeforeQuery {
                                let seeded = min(12, max(0, (hours * 2).rounded() / 2))
                                sleepHours = seeded
                                healthSeededSleep = seeded
                            }
                        }

                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Sleep last night")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.white)
                            Spacer()
                            Text(String(format: "%.1f hr", sleepHours))
                                .foregroundStyle(MorpheTheme.accent)
                        }
                        Slider(value: $sleepHours, in: 0...12, step: 0.5)
                            .tint(MorpheTheme.accent)
                        if sleepFromHealth {
                            Text("Pre-filled from Apple Health — adjust if it's off.")
                                .font(.caption2)
                                .foregroundStyle(MorpheTheme.textMuted)
                        }
                    }

                    // Anchored scales — bare 1–10 numbers left "what does a
                    // 6 mean" as guesswork (audit finding).
                    ratingRow("Energy", value: $energy, range: 1...10, anchors: "1 = drained · 10 = fully charged")
                    ratingRow("Soreness", value: $soreness, range: 0...10, anchors: "0 = fresh · 10 = can barely move")
                    ratingRow("Mood", value: $mood, range: 1...10, anchors: "1 = rough day · 10 = great")

                    Toggle(isOn: $pain) {
                        Text("Any pain or sharp discomfort?")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.white)
                    }
                    .tint(MorpheTheme.danger)

                    // The recovery lesson, at the exact moment recovery is asked.
                    if let lesson = store.lessons.first(where: { $0.title == "Recovery Basics" }) {
                        DisclosureGroup {
                            Text(lesson.detail)
                                .font(.caption)
                                .foregroundStyle(MorpheTheme.textSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                                .padding(.top, 6)
                        } label: {
                            Text("Why this check-in matters")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(MorpheTheme.accentAlt)
                        }
                        .disclosureGroupStyle(HUDDisclosureStyle())
                    }

                    Button("Save Check-In") {
                        store.submitRecoveryCheckIn(
                            sleepHours: sleepHours,
                            energy: energy,
                            soreness: soreness,
                            mood: mood,
                            pain: pain
                        )
                        dismiss()
                    }
                    .buttonStyle(PrimaryCTAButtonStyle(accent: MorpheTheme.accent))
                }
                .padding(20)
            }
            .background(PremiumBackground())
            .navigationTitle("Recovery check-in")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    private func ratingRow(_ title: String, value: Binding<Int>, range: ClosedRange<Int>, anchors: String = "") -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                Spacer()
                Stepper("\(value.wrappedValue)/\(range.upperBound)", value: value, in: range)
                    .labelsHidden()
                Text("\(value.wrappedValue)/\(range.upperBound)")
                    .foregroundStyle(MorpheTheme.accent)
                    .frame(width: 48, alignment: .trailing)
            }
            if !anchors.isEmpty {
                Text(anchors)
                    .font(.caption2)
                    .foregroundStyle(MorpheTheme.textMuted)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(title))
        .accessibilityValue(Text("\(value.wrappedValue) out of \(range.upperBound)"))
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: if value.wrappedValue < range.upperBound { value.wrappedValue += 1 }
            case .decrement: if value.wrappedValue > range.lowerBound { value.wrappedValue -= 1 }
            default: break
            }
        }
    }
}

private struct TodayPlanCard: View {
    let todayWinText: String
    let personalizationNote: String
    let tasks: [TaskItem]
    let onToggleTask: (TaskItem) -> Void

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 14) {
                Text("Today's Plan")
                    .font(.headline)
                    .foregroundStyle(.white)

                Text(todayWinText)
                    .foregroundStyle(MorpheTheme.textSecondary)

                ForEach(tasks) { task in
                    TaskRow(task: task) {
                        onToggleTask(task)
                    }
                }

                // Why THIS mix: the difficulty engine's one-line receipt.
                Text(personalizationNote)
                    .font(.footnote)
                    .foregroundStyle(MorpheTheme.accent.opacity(0.9))
            }
        }
    }
}

private struct MorpheHubEntryCard: View {
    let openProgress: () -> Void
    let openMore: () -> Void

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 14) {
                Text("Need more than today's plan?")
                    .font(.headline)
                    .foregroundStyle(.white)
                Text("Open Progress for reports and wins, or Learn for lessons, the daily quiz, exercise help, and nutrition basics.")
                    .foregroundStyle(MorpheTheme.textSecondary)

                HStack(spacing: 10) {
                    Button("Open Progress", action: openProgress)
                        .buttonStyle(PrimaryCTAButtonStyle(accent: MorpheTheme.accentAlt))
                    // The tab is named Learn — a button named "More" pointed
                    // at a tab that doesn't exist.
                    Button("Open Learn", action: openMore)
                        .buttonStyle(SecondaryCTAButtonStyle())
                }
            }
        }
    }
}

private struct PartnerWorkoutCard: View {
    let partners: [WorkoutPartner]
    let selectedPartner: WorkoutPartner?
    let selectedMode: PartnerWorkoutMode
    let isEnabled: Bool
    let plan: PartnerWorkoutPlan?
    let onSelectPartner: (WorkoutPartner) -> Void
    let onSelectMode: (PartnerWorkoutMode) -> Void
    let onToggleEnabled: (Bool) -> Void

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Train With a Partner")
                            .font(.headline)
                            .foregroundStyle(.white)
                        Text("Make the plan feel more social without losing the structure.")
                            .foregroundStyle(MorpheTheme.textSecondary)
                    }

                    Spacer()

                    Toggle("", isOn: Binding(get: { isEnabled }, set: onToggleEnabled))
                        .labelsHidden()
                        .tint(MorpheTheme.accent)
                }

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(partners) { partner in
                            Button {
                                onSelectPartner(partner)
                            } label: {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text(partner.name)
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(selectedPartner?.id == partner.id ? .black : .white)
                                    Text(partner.sport.shortTitle)
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(selectedPartner?.id == partner.id ? .black.opacity(0.75) : MorpheTheme.textSecondary)
                                    Text(partner.status)
                                        .font(.caption2)
                                        .foregroundStyle(selectedPartner?.id == partner.id ? .black.opacity(0.7) : MorpheTheme.textMuted)
                                }
                                .padding(12)
                                .frame(width: 150, alignment: .leading)
                                .background(
                                    RoundedRectangle(cornerRadius: MorpheTheme.radius, style: .continuous)
                                        .fill(selectedPartner?.id == partner.id ? MorpheTheme.accent : MorpheTheme.panelStrong)
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                WrapStack(spacing: 8) {
                    ForEach(PartnerWorkoutMode.allCases) { mode in
                        Button(mode.rawValue) {
                            onSelectMode(mode)
                        }
                        .buttonStyle(
                            FilterChipStyle(
                                isSelected: selectedMode == mode,
                                selectedColor: MorpheTheme.accentAlt
                            )
                        )
                    }
                }

                if let selectedPartner, let plan, isEnabled {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 8) {
                            MetricPill(label: "Partner", value: selectedPartner.name)
                            MetricPill(label: "Vibe", value: selectedPartner.vibe)
                            MetricPill(label: "Bonus", value: "+\(plan.xpBonus) XP")
                        }

                        Text(plan.headline)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.white)
                        Text(plan.detail)
                            .foregroundStyle(MorpheTheme.textSecondary)
                        Text("Mini challenge: \(plan.miniChallenge)")
                            .font(.caption)
                            .foregroundStyle(MorpheTheme.accentAlt)
                    }
                }
            }
        }
    }
}

/// Week-one starter checklist — every checkmark is DERIVED from real state
/// (logs, check-ins, profile weight); there is nothing to tick manually,
/// the app just notices. Disappears after day 7, complete or not.
private struct FirstWeekCard: View {
    let steps: [MorpheAppStore.FirstWeekStep]

    private var doneCount: Int { steps.filter(\.done).count }

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Your First Week")
                        .font(.headline)
                        .foregroundStyle(.white)
                    Spacer()
                    StatusBadge(
                        text: doneCount == steps.count ? "Complete" : "\(doneCount)/\(steps.count)",
                        color: MorpheTheme.accent
                    )
                }

                Text(doneCount == steps.count
                     ? "Week one locked in — this is how habits start."
                     : "Five small wins make the habit real. The app checks them off as they happen.")
                    .font(.caption)
                    .foregroundStyle(MorpheTheme.textSecondary)

                ForEach(steps) { step in
                    HStack(spacing: 10) {
                        Image(systemName: step.done ? "checkmark.circle.fill" : "circle")
                            .font(.subheadline)
                            .foregroundStyle(step.done ? MorpheTheme.accent : MorpheTheme.textMuted)
                        Text(step.title)
                            .font(.subheadline)
                            .foregroundStyle(step.done ? MorpheTheme.textMuted : .white)
                            .strikethrough(step.done, color: MorpheTheme.textMuted)
                        Spacer(minLength: 0)
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("\(step.title): \(step.done ? "done" : "not yet")")
                }
            }
        }
    }
}
