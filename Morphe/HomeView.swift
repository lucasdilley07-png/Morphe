import SwiftUI

struct HomeView: View {
    @Environment(MorpheAppStore.self) private var store
    @State private var showAdjustments = false
    @State private var showSupport = false

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

        return "\(store.profileShowcase.currentPhase) - next weekly review in 3 days"
    }

    private var todayWinText: String {
        if store.minimumWinModeEnabled {
            return "Keep the habit alive with one small win."
        }

        return "Finish \(store.currentWorkout.name) and close the day with protein and water."
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 16) {
                if store.isWorkoutLoggedToday {
                    DoneForTodayCard(
                        workoutName: store.currentWorkout.name,
                        onRecoveryReset: { store.logRecoveryReset() },
                        onViewProgress: { store.openProgress() }
                    )
                } else {
                    TodayNextMoveCard(
                        workout: store.currentWorkout,
                        minimumWinModeEnabled: store.minimumWinModeEnabled,
                        onStart: { store.startTodayWorkout() },
                        onActivateMinimumWin: { store.activateMinimumWinMode() },
                            onSwitch: { store.cycleWorkout() }
                        )
                }

                TodayStatusStrip(
                    showcase: store.profileShowcase,
                    goal: store.clientProfile.goal,
                    fitnessLevel: store.clientProfile.fitnessLevel,
                    coachName: store.clientProfile.planCreatedBy,
                    recovery: store.recovery,
                    morpheScore: store.clientProfile.health.score,
                    morpheTier: morpheScoreTitle,
                    morpheDetail: store.clientProfile.health.detail
                )

                if let insight = store.primaryAthletePatternInsight {
                    HomePatternInsightCard(insight: insight) {
                        store.openProgress()
                    }
                }

                if !store.isWorkoutLoggedToday {
                    if store.minimumWinModeEnabled {
                        MinimumWinModeCard(
                            message: store.minimumWinMessage,
                            tasks: store.minimumWinTasks
                        ) { task in
                            store.toggleMinimumWinTask(task)
                        }
                    } else {
                        TodayPlanCard(
                            todayWinText: todayWinText,
                            tasks: store.todayTasks,
                            onToggleTask: { store.toggleTask($0) }
                        )
                    }
                }

                HomeExpandableSection(
                    title: "If plans change",
                    subtitle: adjustmentSubtitle,
                    isExpanded: $showAdjustments
                ) {
                    if !store.isWorkoutLoggedToday,
                       (store.minimumWinModeEnabled || store.selectedConfidence == .notConfident || store.selectedPlanBReason != nil) {
                        SmartPlanAdjustmentCard(adjustment: store.currentPlanAdjustment)
                    }

                    AIInsightCard(insight: store.isWorkoutLoggedToday ? store.clientProfile.aiProgressInsight : store.clientProfile.aiTodayInsight)

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

                HomeExpandableSection(
                    title: "Support & progress",
                    subtitle: supportSubtitle,
                    isExpanded: $showSupport
                ) {
                    WorkoutPlanByCoachMiniCard(
                        profile: store.clientProfile,
                        phase: store.profileShowcase.currentPhase
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

                    UpcomingGoalCard(text: upcomingGoalText)
                    MorpheHubEntryCard {
                        store.openProgress()
                    } openMore: {
                        store.openMore(.scores)
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 120)
        }
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
            return "\(partner.name), your coach context, and your next checkpoint stay here when you want them."
        }

        return "Coach context, partner mode, and progress stay here without crowding the top of the day."
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
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
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

                Button("See More Patterns") {
                    onOpenProgress()
                }
                .buttonStyle(SecondaryCTAButtonStyle())
            }
        }
    }
}

private enum HomeDashboardPanel: String, CaseIterable, Identifiable {
    case plan = "Plan"
    case adjust = "Adjust"
    case support = "Support"

    var id: String { rawValue }
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

                    VStack(alignment: .trailing, spacing: 4) {
                        Text("Plan by \(coachName)")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(MorpheTheme.textMuted)
                        Text(morpheTier)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.white)
                    }
                }

                HStack(spacing: 8) {
                    MetricPill(label: "Readiness", value: "\(recovery.score)")
                    MetricPill(label: "Score", value: "\(morpheScore)")
                    MetricPill(label: "Energy", value: "\(recovery.energy)/10")
                }

                Text("Plan by \(coachName) • \(morpheDetail)")
                    .font(.caption)
                    .foregroundStyle(MorpheTheme.textSecondary)
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
        VStack(alignment: .leading, spacing: 12) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack(alignment: .top, spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(title)
                            .font(.headline)
                            .foregroundStyle(.white)
                        Text(subtitle)
                            .font(.subheadline)
                            .foregroundStyle(MorpheTheme.textSecondary)
                            .multilineTextAlignment(.leading)
                    }

                    Spacer()

                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(.white)
                        .frame(width: 32, height: 32)
                        .background(
                            Circle()
                                .fill(MorpheTheme.panelStrong)
                        )
                }
                .padding(14)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(MorpheTheme.panelRaised)
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(MorpheTheme.strokeStrong.opacity(0.24), lineWidth: 1)
                        )
                )
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

private struct TodayOverviewCard: View {
    let showcase: ProfileShowcase
    let goal: String
    let fitnessLevel: String
    let coachName: String
    let recovery: RecoverySnapshot
    let morpheScore: Int
    let morpheTier: String
    let morpheDetail: String

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 12) {
                    MorpheAvatarView(avatar: showcase.avatar, size: 64)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(showcase.displayName)
                            .font(.headline.weight(.bold))
                            .foregroundStyle(.white)
                        Text("@\(showcase.username)")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(MorpheTheme.accentAlt)
                        Text("\(goal) • \(fitnessLevel)")
                            .font(.caption)
                            .foregroundStyle(MorpheTheme.textSecondary)
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 4) {
                        Text("Plan by")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(MorpheTheme.textMuted)
                        Text(coachName)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.white)
                    }
                }

                HStack(spacing: 8) {
                    MetricPill(label: "Readiness", value: "\(recovery.score)")
                    MetricPill(label: "Score", value: "\(morpheScore)")
                    MetricPill(label: "Sleep", value: String(format: "%.1f hr", recovery.sleepHours))
                    MetricPill(label: "Energy", value: "\(recovery.energy)/10")
                }

                HStack(alignment: .top, spacing: 10) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(recovery.status.rawValue)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.white)
                        Text(recovery.reason)
                            .font(.caption)
                            .foregroundStyle(MorpheTheme.textSecondary)
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 4) {
                        Text(morpheTier)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.white)
                        Text(morpheDetail)
                            .font(.caption)
                            .multilineTextAlignment(.trailing)
                            .foregroundStyle(MorpheTheme.textSecondary)
                    }
                }
            }
        }
    }
}

private struct TodayNextMoveCard: View {
    @Environment(MorpheAppStore.self) private var store
    let workout: WorkoutTemplate
    let minimumWinModeEnabled: Bool
    let onStart: () -> Void
    let onActivateMinimumWin: () -> Void
    let onSwitch: () -> Void
    @State private var inlineReply: String?

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 14) {
                Text(minimumWinModeEnabled ? "Today's fallback is active" : "Next move")
                    .font(.headline)
                    .foregroundStyle(.white)

                if minimumWinModeEnabled {
                    Text("Momentum is the goal today. Keep the day light, protect the streak, and come back stronger tomorrow.")
                        .foregroundStyle(MorpheTheme.textSecondary)

                    HStack(spacing: 10) {
                        Button("Keep Minimum Win") {
                            onActivateMinimumWin()
                        }
                        .buttonStyle(PrimaryCTAButtonStyle(accent: MorpheTheme.accentAlt))

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
                    }

                    HStack(spacing: 10) {
                        Button("Start Today's Plan", action: onStart)
                            .buttonStyle(PrimaryCTAButtonStyle(accent: MorpheTheme.accent))

                        Button("Need a smaller win?", action: onActivateMinimumWin)
                            .buttonStyle(SecondaryCTAButtonStyle())
                    }
                }

                Divider()
                    .overlay(Color.white.opacity(0.08))

                VStack(alignment: .leading, spacing: 10) {
                    Text("Morphe can help right here")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)

                    WrapStack(spacing: 8) {
                        Button("Why this plan?") {
                            inlineReply = store.previewAIAgentReply(for: "Why is this the right plan for today?")
                        }
                        .buttonStyle(FilterChipStyle(isSelected: false, selectedColor: MorpheTheme.accentAlt))

                        Button("Adjust my day") {
                            inlineReply = store.previewAIAgentReply(for: "Adjust today's plan for me")
                        }
                        .buttonStyle(FilterChipStyle(isSelected: false, selectedColor: MorpheTheme.accent))
                    }

                    if let inlineReply {
                        Text(inlineReply)
                            .font(.subheadline)
                            .foregroundStyle(MorpheTheme.textPrimary)
                            .padding(12)
                            .background(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .fill(MorpheTheme.panelStrong)
                            )
                    }
                }
            }
        }
    }
}

private struct DoneForTodayCard: View {
    let workoutName: String
    let onRecoveryReset: () -> Void
    let onViewProgress: () -> Void

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 14) {
                Text("You're done for today.")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(.white)
                Text("You closed the loop on \(workoutName). Everything below is optional now: recover well, share the win, and leave the app feeling finished.")
                    .foregroundStyle(MorpheTheme.textSecondary)

                HStack(spacing: 10) {
                    ShareLink(item: "I just finished \(workoutName) on Morphe. Small wins, real transformation. 💪") {
                        Text("Share Win")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(PrimaryCTAButtonStyle(accent: MorpheTheme.accent))
                    Button("Recovery Reset", action: onRecoveryReset)
                        .buttonStyle(SecondaryCTAButtonStyle())
                }

                Button("View Progress", action: onViewProgress)
                    .buttonStyle(SecondaryCTAButtonStyle())
            }
        }
    }
}

private struct TodayPulseRail: View {
    let recovery: RecoverySnapshot
    let morpheScore: Int
    let streak: Int
    let rank: String
    let partner: String

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                PulseMiniCard(title: "Readiness", value: "\(recovery.score)", detail: recovery.status.rawValue)
                PulseMiniCard(title: "Score", value: "\(morpheScore)", detail: "This week")
                PulseMiniCard(title: "Streak", value: "\(streak) days", detail: "Momentum")
                PulseMiniCard(title: "Rank", value: rank, detail: "Network")
                PulseMiniCard(title: "Partner", value: partner, detail: "Session")
            }
        }
    }
}

private struct PulseMiniCard: View {
    let title: String
    let value: String
    let detail: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(MorpheTheme.textMuted)
            Text(value)
                .font(.headline.weight(.bold))
                .foregroundStyle(.white)
                .lineLimit(1)
            Text(detail)
                .font(.caption)
                .foregroundStyle(MorpheTheme.textSecondary)
                .lineLimit(1)
        }
        .padding(14)
        .frame(width: 136, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(MorpheTheme.panelInteractive)
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(MorpheTheme.stroke, lineWidth: 1)
                )
        )
    }
}

private struct WorkoutPlanByCoachMiniCard: View {
    let profile: ClientProfile
    let phase: String

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    MetricPill(label: "Plan By", value: profile.planCreatedBy)
                    MetricPill(label: "Current Phase", value: phase)
                }

                Text("\(profile.currentProgram) is being guided by \(profile.planCreatedBy). Morphe handles the daily decisions, but the plan still feels coached.")
                    .font(.subheadline)
                    .foregroundStyle(MorpheTheme.textSecondary)
            }
        }
    }
}

private struct TodayIdentityCard: View {
    let showcase: ProfileShowcase
    let goal: String
    let fitnessLevel: String

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 14) {
                ProfileBannerView(banner: showcase.banner, theme: showcase.theme)

                HStack(spacing: 12) {
                    MorpheAvatarView(avatar: showcase.avatar, size: 72)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(showcase.displayName)
                            .font(.title3.weight(.bold))
                            .foregroundStyle(.white)
                        Text("@\(showcase.username)")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(MorpheTheme.accentAlt)
                        Text("\(goal) - \(fitnessLevel)")
                            .font(.subheadline)
                            .foregroundStyle(MorpheTheme.textSecondary)
                    }
                }
            }
        }
    }
}

private struct TodayStatusDeckCard: View {
    let recovery: RecoverySnapshot
    let morpheScore: Int
    let morpheTier: String
    let morpheDetail: String

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 14) {
                Text("Today's Status")
                    .font(.headline)
                    .foregroundStyle(.white)

                HStack(alignment: .top, spacing: 12) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Readiness")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(MorpheTheme.textMuted)
                        Text("\(recovery.score) - \(recovery.status.rawValue)")
                            .font(.title3.weight(.bold))
                            .foregroundStyle(.white)
                        Text(recovery.reason)
                            .font(.caption)
                            .foregroundStyle(MorpheTheme.textSecondary)
                    }

                    Spacer(minLength: 0)

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Morphe Score")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(MorpheTheme.textMuted)
                        Text("\(morpheScore) - \(morpheTier)")
                            .font(.title3.weight(.bold))
                            .foregroundStyle(.white)
                        Text(morpheDetail)
                            .font(.caption)
                            .foregroundStyle(MorpheTheme.textSecondary)
                    }
                }

                HStack(spacing: 8) {
                    MetricPill(label: "Sleep", value: String(format: "%.1f hr", recovery.sleepHours))
                    MetricPill(label: "Energy", value: "\(recovery.energy)/10")
                    MetricPill(label: "Soreness", value: "\(recovery.soreness)/10")
                }
            }
        }
    }
}

private struct DailyMotivationCard: View {
    let text: String

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 8) {
                Text("Daily Motivation")
                    .font(.headline)
                    .foregroundStyle(.white)
                Text(text)
                    .foregroundStyle(MorpheTheme.textPrimary)
            }
        }
    }
}

private struct UpcomingGoalCard: View {
    let text: String

    var body: some View {
        StatCard(title: "Upcoming Goal / Event", value: "What this week points toward", detail: text)
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

                Button(isComplete ? "Update Check-In" : "Do Recovery Check-In") {
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

                HStack {
                    Text("Need a Plan B?")
                        .font(.headline)
                        .foregroundStyle(.white)
                    Spacer()
                    Button(showPlanBOptions ? "Hide" : "Show options") {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            showPlanBOptions.toggle()
                        }
                    }
                    .buttonStyle(SecondaryCTAButtonStyle())
                    .frame(width: 120)
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

                    Button("Minimum Win Mode", action: onMinimumWin)
                        .buttonStyle(PrimaryCTAButtonStyle(accent: MorpheTheme.accent))

                    HStack(spacing: 10) {
                        Button("Shorter workout", action: onShorterWorkout)
                            .buttonStyle(SecondaryCTAButtonStyle())
                        Button("Recovery session", action: onRecoveryWorkout)
                            .buttonStyle(SecondaryCTAButtonStyle())
                    }

                    Button("Move workout to tomorrow", action: onReschedule)
                        .buttonStyle(SecondaryCTAButtonStyle())
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
                    }

                    ratingRow("Energy", value: $energy, range: 1...10)
                    ratingRow("Soreness", value: $soreness, range: 0...10)
                    ratingRow("Mood", value: $mood, range: 1...10)

                    Toggle(isOn: $pain) {
                        Text("Any pain or sharp discomfort?")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.white)
                    }
                    .tint(MorpheTheme.danger)

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

    private func ratingRow(_ title: String, value: Binding<Int>, range: ClosedRange<Int>) -> some View {
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
            }
        }
    }
}

private struct HomeDashboardPanelSwitcher: View {
    @Binding var selectedPanel: HomeDashboardPanel

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("Keep the day simple")
                    .font(.headline)
                    .foregroundStyle(.white)

                Picker("Home Panel", selection: $selectedPanel) {
                    ForEach(HomeDashboardPanel.allCases) { panel in
                        Text(panel.rawValue).tag(panel)
                    }
                }
                .pickerStyle(.segmented)

                Text(subtitle(for: selectedPanel))
                    .font(.subheadline)
                    .foregroundStyle(MorpheTheme.textSecondary)
            }
        }
    }

    private func subtitle(for panel: HomeDashboardPanel) -> String {
        switch panel {
        case .plan:
            return "See today's tasks, your next goal, and where to go for deeper progress."
        case .adjust:
            return "Check in, adjust the load, and let Morphe keep the day realistic."
        case .support:
            return "Coach context, partner mode, and momentum protection stay here when you need them."
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
                Text("Open Progress for reports and wins, or More for scores, quick tools, exercise help, nutrition basics, and learning.")
                    .foregroundStyle(MorpheTheme.textSecondary)

                HStack(spacing: 10) {
                    Button("Open Progress", action: openProgress)
                        .buttonStyle(PrimaryCTAButtonStyle(accent: MorpheTheme.accentAlt))
                    Button("Open More", action: openMore)
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
                                    RoundedRectangle(cornerRadius: 8, style: .continuous)
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
