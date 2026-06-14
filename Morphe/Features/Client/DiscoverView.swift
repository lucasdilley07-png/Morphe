import SwiftUI

struct ProfileView: View {
    @Environment(MorpheAppStore.self) private var store
    @State private var paymentExpanded = true
    @State private var attributesExpanded = true
    @State private var settingsExpanded = true

    private var isCoach: Bool {
        store.selectedRole == .coach
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 16) {
                SectionTitleView(
                    title: isCoach ? "Coach Profile" : "Athlete Profile",
                    subtitle: "Switch account type, shape your identity, and keep the workspace feeling personal, credible, and easy to manage."
                )

                AccountTypeSwitcherProfileCard(selectedRole: store.selectedRole) { role in
                    store.selectRole(role)
                }

                ProfileBannerView(banner: store.profileShowcase.banner, theme: store.profileShowcase.theme)

                GlassCard {
                    VStack(alignment: .leading, spacing: 14) {
                        HStack(spacing: 12) {
                            MorpheAvatarView(avatar: store.profileShowcase.avatar, size: 84)

                            VStack(alignment: .leading, spacing: 4) {
                                Text(isCoach ? store.coachProfile.name : store.profileShowcase.displayName)
                                    .font(.title3.weight(.bold))
                                    .foregroundStyle(.white)
                                Text("@\(isCoach ? store.coachProfile.username : store.profileShowcase.username)")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(MorpheTheme.accentAlt)
                                Text(isCoach ? store.coachProfile.headline : store.profileShowcase.bio)
                                    .font(.subheadline)
                                    .foregroundStyle(MorpheTheme.textSecondary)
                            }
                        }

                        HStack(spacing: 8) {
                            MetricPill(label: "Account", value: isCoach ? "Coach" : "Athlete")
                            MetricPill(
                                label: "Primary Sport",
                                value: isCoach
                                    ? (store.coachProfile.sports.first?.rawValue ?? "Coach")
                                    : store.clientProfile.sportMode.rawValue
                            )
                            MetricPill(
                                label: isCoach ? "Primary Goal" : "Primary Goal",
                                value: isCoach
                                    ? (store.coachProfile.selectedGoals.first ?? store.coachProfile.specialty)
                                    : store.clientProfile.goal
                            )
                        }

                        WrapStack(spacing: 8) {
                            ForEach(isCoach ? store.coachProfile.sports : store.clientProfile.selectedSports) { sport in
                                SelectionToken(text: sport.shortTitle, color: MorpheTheme.color(for: sport))
                            }

                            ForEach(isCoach ? store.coachProfile.selectedTrainingStyles : store.clientProfile.selectedTrainingStyles) { style in
                                SelectionToken(text: style.rawValue, color: MorpheTheme.warning)
                            }

                            ForEach(isCoach ? store.coachProfile.selectedGoals : store.clientProfile.selectedGoals, id: \.self) { goal in
                                SelectionToken(text: goal, color: MorpheTheme.accentAlt)
                            }
                        }
                    }
                }

                if isCoach {
                    ProfileDisclosureSection(
                        title: "Payment",
                        subtitle: "Subscription, bank details, and premium coach tools.",
                        isExpanded: $paymentExpanded
                    ) {
                        CoachPaymentSection(
                            status: store.subscriptionStatus,
                            onPreviewPlans: { store.openPaywall() }
                        )
                    }

                    ProfileDisclosureSection(
                        title: "Attributes",
                        subtitle: "Identity, CRM, network presence, and coaching proof.",
                        isExpanded: $attributesExpanded
                    ) {
                        CoachAttributesSection(store: store)
                    }

                    ProfileDisclosureSection(
                        title: "Settings",
                        subtitle: "Personalization, privacy, support, and account actions.",
                        isExpanded: $settingsExpanded
                    ) {
                        CoachSettingsSection(store: store)
                    }
                } else {
                    ProfileDisclosureSection(
                        title: "Payment",
                        subtitle: "Subscription, bank details, and premium athlete preview.",
                        isExpanded: $paymentExpanded
                    ) {
                        AthletePaymentSection(
                            status: store.subscriptionStatus,
                            onPreviewPlans: { store.openPaywall() }
                        )
                    }

                    ProfileDisclosureSection(
                        title: "Attributes",
                        subtitle: "Athletic identity, coach plan, badges, and progress proof.",
                        isExpanded: $attributesExpanded
                    ) {
                        AthleteAttributesSection(store: store)
                    }

                    ProfileDisclosureSection(
                        title: "Settings",
                        subtitle: "Personalization, privacy, support, and account actions.",
                        isExpanded: $settingsExpanded
                    ) {
                        AthleteSettingsSection(store: store)
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 120)
        }
    }
}

private struct CoachPaymentSection: View {
    let status: SubscriptionStatus
    let onPreviewPlans: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SubscriptionStatusCard(status: status)
            CoachBankDetailsCard()
            CoachPremiumPreviewCard(onPreviewPlans: onPreviewPlans)
        }
    }
}

private struct CoachAttributesSection: View {
    var store: MorpheAppStore

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ProfileSocialResumeCard(
                stats: store.profileShowcase.communityStats,
                isCoach: true,
                rank: store.coachProfile.networkRank
            )
            CoachIdentityCard(profile: store.coachProfile, overview: store.coachOverview)
            CoachCRMDatabaseCard(
                activeClients: store.coachProfile.activeClients,
                leads: store.leadRecords.count,
                groups: store.teamGroups.count,
                unreadThreads: store.messageThreads.filter(\.isUnread).count
            ) {
                store.selectedCoachTab = .messages
                store.closeClientProfile()
            }
            CoachCommunityRankCard(profile: store.coachProfile, groups: store.trainingGroups)
            ProfileFocusCard(
                role: store.selectedRole,
                selectedSports: store.coachProfile.sports,
                selectedTrainingStyles: store.coachProfile.selectedTrainingStyles,
                selectedGoals: store.coachProfile.selectedGoals,
                onToggleSport: { sport in
                    store.toggleCoachProfileSport(sport)
                },
                onToggleTrainingStyle: { style in
                    store.toggleCoachProfileTrainingStyle(style)
                },
                onToggleGoal: { goal in
                    store.toggleCoachProfileGoal(goal)
                }
            )
            PersonalRecordsListCard(records: store.profileShowcase.personalRecords)
            FeaturedShowcaseCard(
                workouts: store.profileShowcase.featuredWorkouts,
                videos: store.profileShowcase.featuredVideos,
                sourceName: store.coachProfile.name,
                sourceRole: .coach
            ) { workout in
                store.saveFeaturedWorkout(named: workout.title, sourceName: store.coachProfile.name, sourceRole: .coach)
            }
            BadgeGridCard(badges: store.profileShowcase.badges)
            CoachingToneStatusCard(tone: store.profileShowcase.coachingTone)
            AIPerformanceBioCard(text: store.profileShowcase.aiPerformanceBio)
            PersonalRulesCard(rules: store.personalRules)
        }
    }
}

private struct CoachSettingsSection: View {
    var store: MorpheAppStore

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            AvatarCustomizerCard(selected: store.profileShowcase.avatar.style, avatars: store.availableAvatars) { style in
                store.selectAvatarStyle(style)
            }

            BannerCustomizerCard(selected: store.profileShowcase.banner.preset, banners: store.availableBanners) { preset in
                store.selectBannerPreset(preset)
            }

            CoachingToneSelectorCard(selected: store.profileShowcase.coachingTone) { tone in
                store.selectCoachingTone(tone)
            }

            CoachShareableProfileCard(
                showcase: store.profileShowcase,
                profile: store.coachProfile
            ) {
                store.shareProfile()
            }

            ProfilePrivacyCard(
                title: "Coach profile visibility",
                isPublic: store.coachProfileIsPublic
            ) {
                store.toggleProfileVisibility(for: .coach)
            }

            ProfileSupportCard(contactSupport: {
                store.contactSupport()
            }, logout: {
                store.logoutPlaceholder()
            })
        }
    }
}

private struct AthletePaymentSection: View {
    let status: SubscriptionStatus
    let onPreviewPlans: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SubscriptionStatusCard(status: status)
            AthleteBankDetailsCard()
            AthletePremiumPreviewCard(onPreviewPlans: onPreviewPlans)
        }
    }
}

private struct AthleteAttributesSection: View {
    var store: MorpheAppStore

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ProfileSocialResumeCard(
                stats: store.profileShowcase.communityStats,
                isCoach: false,
                rank: store.clientProfile.networkRank
            )
            AthleticProfileCard(store: store)
            AthletePlanByCoachCard(profile: store.clientProfile, phase: store.profileShowcase.currentPhase) {
                store.saveWorkoutFromCurrentPlan()
            }
            CoachConnectionCard(
                coachName: store.clientProfile.coachName,
                coachStatus: store.clientProfile.coachStatus,
                coachPreview: store.clientProfile.coachPreview
            )
            ProfileFocusCard(
                role: store.selectedRole,
                selectedSports: store.clientProfile.selectedSports,
                selectedTrainingStyles: store.clientProfile.selectedTrainingStyles,
                selectedGoals: store.clientProfile.selectedGoals,
                onToggleSport: { sport in
                    store.toggleProfileSport(sport)
                },
                onToggleTrainingStyle: { style in
                    store.toggleProfileTrainingStyle(style)
                },
                onToggleGoal: { goal in
                    store.toggleProfileGoal(goal)
                }
            )
            BadgeGridCard(badges: store.profileShowcase.badges)
            PersonalRecordsListCard(records: store.profileShowcase.personalRecords)
            AthleteRecentLogsCard(logs: Array(store.currentAthleteWorkoutLogs.prefix(3)))
            FeaturedShowcaseCard(
                workouts: store.profileShowcase.featuredWorkouts,
                videos: store.profileShowcase.featuredVideos,
                sourceName: store.profileShowcase.displayName,
                sourceRole: .client
            ) { workout in
                store.saveFeaturedWorkout(named: workout.title, sourceName: store.profileShowcase.displayName, sourceRole: .client)
            }
            TransformationTimelineCard(milestones: store.profileShowcase.milestones)
            PersonalRulesCard(rules: store.personalRules)
            AIPerformanceBioCard(text: store.profileShowcase.aiPerformanceBio)
            PhotoProgressAIScanCard(snapshot: store.photoProgress)
        }
    }
}

private struct AthleteSettingsSection: View {
    var store: MorpheAppStore

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            AvatarCustomizerCard(selected: store.profileShowcase.avatar.style, avatars: store.availableAvatars) { style in
                store.selectAvatarStyle(style)
            }

            BannerCustomizerCard(selected: store.profileShowcase.banner.preset, banners: store.availableBanners) { preset in
                store.selectBannerPreset(preset)
            }

            CoachingToneSelectorCard(selected: store.profileShowcase.coachingTone) { tone in
                store.selectCoachingTone(tone)
            }

            ShareableProfileCard(showcase: store.profileShowcase, level: store.clientProfile.level) {
                store.shareProfile()
            }

            ProfilePrivacyCard(
                title: "Athlete profile visibility",
                isPublic: store.athleteProfileIsPublic
            ) {
                store.toggleProfileVisibility(for: .client)
            }

            SmartNotificationPreviewCard(notifications: store.notifications) { item in
                store.performNotificationAction(item)
            }

            ProfileSupportCard(contactSupport: {
                store.contactSupport()
            }, logout: {
                store.logoutPlaceholder()
            })
        }
    }
}

struct PaywallPreviewScreen: View {
    @Environment(MorpheAppStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 16) {
                    SectionTitleView(
                        title: "Morphe Plans",
                        subtitle: "Premium Profile is free at launch. This preview is only for advanced coaching features."
                    )

                    SubscriptionStatusCard(status: store.subscriptionStatus)

                    ForEach(store.subscriptionPlans) { plan in
                        GlassCard {
                            VStack(alignment: .leading, spacing: 12) {
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(plan.title)
                                            .font(.headline)
                                            .foregroundStyle(.white)
                                        Text(plan.price)
                                            .font(.title3.weight(.bold))
                                            .foregroundStyle(MorpheTheme.accent)
                                    }
                                    Spacer()
                                    Text(plan.audience)
                                        .font(.caption)
                                        .foregroundStyle(MorpheTheme.textMuted)
                                }

                                ForEach(plan.features, id: \.self) { feature in
                                    Text("- \(feature)")
                                        .foregroundStyle(MorpheTheme.textPrimary)
                                }
                            }
                        }
                    }
                }
                .padding(20)
            }
            .background(PremiumBackground())
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        store.closePaywall()
                        dismiss()
                    }
                    .foregroundStyle(.white)
                }
            }
        }
    }
}

private struct SelectionToken: View {
    let text: String
    let color: Color

    var body: some View {
        Text(text)
            .font(.caption.weight(.semibold))
            .foregroundStyle(.black)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                Capsule(style: .continuous)
                    .fill(color)
            )
            .lineLimit(1)
    }
}

private struct ProfileGroupHeader: View {
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.title3.weight(.bold))
                .foregroundStyle(.white)
            Text(subtitle)
                .font(.subheadline)
                .foregroundStyle(MorpheTheme.textSecondary)
        }
    }
}

private struct ProfileDisclosureSection<Content: View>: View {
    let title: String
    let subtitle: String
    @Binding var isExpanded: Bool
    let content: Content

    init(title: String, subtitle: String, isExpanded: Binding<Bool>, @ViewBuilder content: () -> Content) {
        self.title = title
        self.subtitle = subtitle
        self._isExpanded = isExpanded
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            GlassCard {
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isExpanded.toggle()
                    }
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(title)
                                .font(.headline)
                                .foregroundStyle(.white)
                            Text(subtitle)
                                .font(.subheadline)
                                .foregroundStyle(MorpheTheme.textSecondary)
                        }
                        Spacer()
                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .foregroundStyle(.white)
                    }
                }
                .buttonStyle(.plain)
            }

            if isExpanded {
                content
            }
        }
    }
}

private struct AccountTypeSwitcherProfileCard: View {
    let selectedRole: AppRole
    let onSelect: (AppRole) -> Void

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("Account Type")
                    .font(.headline)
                    .foregroundStyle(.white)

                Text("Switch between your athlete and coach workspace here. Morphe keeps the same identity layer and changes the tools around it.")
                    .foregroundStyle(MorpheTheme.textSecondary)

                RoleSwitcher(selectedRole: selectedRole, onSelect: onSelect)
            }
        }
    }
}

private struct AthleteBankDetailsCard: View {
    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("Bank Details")
                    .font(.headline)
                    .foregroundStyle(.white)

                HStack(spacing: 8) {
                    MetricPill(label: "Primary Method", value: "Debit •••• 2048")
                    MetricPill(label: "Billing", value: "Apple Pay")
                    MetricPill(label: "Renewal", value: "June 14")
                }

                Text("Billing details are shown here as a secure demo placeholder. In production, Morphe would let athletes review and update payment methods safely.")
                    .foregroundStyle(MorpheTheme.textSecondary)
            }
        }
    }
}

private struct AthletePremiumPreviewCard: View {
    let onPreviewPlans: () -> Void

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("Premium Preview")
                    .font(.headline)
                    .foregroundStyle(.white)
                Text("Advanced AI plans, recovery analytics, report cards, and deeper coaching tools are previewed here. Premium Profile stays free at launch.")
                    .foregroundStyle(MorpheTheme.textSecondary)
                Button("Preview plans", action: onPreviewPlans)
                    .buttonStyle(SecondaryCTAButtonStyle())
            }
        }
    }
}

private struct CoachBankDetailsCard: View {
    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("Bank Details")
                    .font(.headline)
                    .foregroundStyle(.white)

                HStack(spacing: 8) {
                    MetricPill(label: "Payout Method", value: "Checking •••• 9082")
                    MetricPill(label: "Billing", value: "Business Card")
                    MetricPill(label: "Next Payout", value: "May 31")
                }

                Text("Billing and payout details are shown here as a secure demo placeholder. In production, Morphe would let coaches manage subscriptions and payouts safely.")
                    .foregroundStyle(MorpheTheme.textSecondary)
            }
        }
    }
}

private struct CoachPremiumPreviewCard: View {
    let onPreviewPlans: () -> Void

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("Premium Preview")
                    .font(.headline)
                    .foregroundStyle(.white)
                Text("Advanced client analytics, expanded CRM, branded coach profile upgrades, and deeper review tools are previewed here. Premium Profile stays free at launch.")
                    .foregroundStyle(MorpheTheme.textSecondary)
                Button("Preview plans", action: onPreviewPlans)
                    .buttonStyle(SecondaryCTAButtonStyle())
            }
        }
    }
}

private struct ProfileSocialResumeCard: View {
    let stats: [CommunityStat]
    let isCoach: Bool
    let rank: String

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                Text(isCoach ? "Coach Resume" : "Athletic Resume")
                    .font(.headline)
                    .foregroundStyle(.white)

                HStack(spacing: 8) {
                    MetricPill(label: "Rank", value: rank)
                    MetricPill(label: "Presence", value: isCoach ? "Coach Network" : "Athlete Network")
                }

                if !stats.isEmpty {
                    HStack(spacing: 8) {
                        ForEach(stats.prefix(3)) { stat in
                            MetricPill(label: stat.label, value: stat.value)
                        }
                    }
                }

                Text(isCoach ? "This is the public-facing layer of your coaching identity: credibility, communication, and the systems you are known for." : "This is the public-facing layer of your progress story: credibility, consistency, and the wins you are building in public.")
                    .foregroundStyle(MorpheTheme.textSecondary)
            }
        }
    }
}

private struct AthleticProfileCard: View {
    var store: MorpheAppStore

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("Athletic Profile")
                    .font(.headline)
                    .foregroundStyle(.white)

                HStack(spacing: 8) {
                    MetricPill(label: "Current Program", value: store.clientProfile.currentProgram)
                    MetricPill(label: "Current Phase", value: store.profileShowcase.currentPhase)
                    MetricPill(label: "Gender", value: store.clientProfile.gender.rawValue)
                }

                HStack(spacing: 8) {
                    MetricPill(label: "Streak", value: "\(store.clientProfile.level.streak) days")
                    MetricPill(label: "Adherence", value: "\(store.clientProfile.adherence)%")
                }

                Text("Physical goal: \(store.clientProfile.physicalGoalTarget)")
                    .font(.caption)
                    .foregroundStyle(MorpheTheme.textSecondary)

                HStack(spacing: 8) {
                    MetricPill(label: "Weight Goal", value: store.clientProfile.weightGoalTarget)
                    MetricPill(label: "Deadline", value: store.clientProfile.goalDeadline)
                }

                Text("Equipment access: \(store.clientProfile.equipment)")
                    .font(.caption)
                    .foregroundStyle(MorpheTheme.textSecondary)

                Text(store.clientProfile.oneLiner)
                    .foregroundStyle(MorpheTheme.textSecondary)
            }
        }
    }
}

private struct AthletePlanByCoachCard: View {
    let profile: ClientProfile
    let phase: String
    let onSaveWorkout: () -> Void

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("Workout Plan By Coach")
                    .font(.headline)
                    .foregroundStyle(.white)

                HStack(spacing: 8) {
                    MetricPill(label: "Coach", value: profile.planCreatedBy)
                    MetricPill(label: "Current Plan", value: profile.currentProgram)
                    MetricPill(label: "Phase", value: phase)
                }

                Text("Your current plan is built by \(profile.planCreatedBy) and tuned around \(profile.goal.lowercased()). Morphe keeps the daily actions simple, but the plan still reflects a real coaching relationship.")
                    .foregroundStyle(MorpheTheme.textSecondary)

                Button("Save Current Plan", action: onSaveWorkout)
                    .buttonStyle(SecondaryCTAButtonStyle())
            }
        }
    }
}

private struct CoachIdentityCard: View {
    let profile: CoachProfile
    let overview: CoachOverview

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("Coach Identity")
                    .font(.headline)
                    .foregroundStyle(.white)

                HStack(spacing: 8) {
                    MetricPill(label: "Rank", value: profile.networkRank)
                    MetricPill(label: "Specialty", value: profile.specialty)
                }

                HStack(spacing: 8) {
                    MetricPill(label: "Active Clients", value: "\(profile.activeClients)")
                    MetricPill(label: "Check-ins", value: "\(overview.checkInsNeeded)")
                }

                Text(profile.headline)
                    .foregroundStyle(MorpheTheme.textSecondary)
            }
        }
    }
}

private struct CoachCRMDatabaseCard: View {
    let activeClients: Int
    let leads: Int
    let groups: Int
    let unreadThreads: Int
    let onOpenCRM: () -> Void

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("Coach CRM Database")
                    .font(.headline)
                    .foregroundStyle(.white)

                HStack(spacing: 8) {
                    MetricPill(label: "Active Clients", value: "\(activeClients)")
                    MetricPill(label: "Leads", value: "\(leads)")
                    MetricPill(label: "Groups", value: "\(groups)")
                    MetricPill(label: "Unread", value: "\(unreadThreads)")
                }

                Text("Coach accounts get a lightweight CRM view for lead status, athlete follow-up, group updates, and outreach decisions.")
                    .foregroundStyle(MorpheTheme.textSecondary)

                Button("Open Coach Messages + CRM", action: onOpenCRM)
                    .buttonStyle(SecondaryCTAButtonStyle())
            }
        }
    }
}

private struct CoachCommunityRankCard: View {
    let profile: CoachProfile
    let groups: [TrainingGroupPreview]

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("Coach Network Presence")
                    .font(.headline)
                    .foregroundStyle(.white)

                HStack(spacing: 8) {
                    MetricPill(label: "Rank", value: profile.networkRank)
                    MetricPill(label: "Groups", value: "\(groups.count)")
                    MetricPill(label: "Playbooks", value: "\(profile.playbooks.count)")
                }

                Text("Share coaching systems, athlete wins, training ideas, and practical feedback with the Morphe network.")
                    .foregroundStyle(MorpheTheme.textSecondary)
            }
        }
    }
}

private struct ProfileFocusCard: View {
    let role: AppRole
    let selectedSports: [SportFocus]
    let selectedTrainingStyles: [TrainingStyleOption]
    let selectedGoals: [String]
    let onToggleSport: (SportFocus) -> Void
    let onToggleTrainingStyle: (TrainingStyleOption) -> Void
    let onToggleGoal: (FitnessGoalOption) -> Void

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("Sport + Training + Goal Mix")
                    .font(.headline)
                    .foregroundStyle(.white)

                Text(role == .coach ? "Pick up to 5 sports, training styles, and goals. Morphe uses the first ones to shape your main coaching identity and network presence." : "Pick up to 5 sports, training styles, and goals. Morphe uses the first sport and first goal as your main mode.")
                    .foregroundStyle(MorpheTheme.textSecondary)

                Text("Sports")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)

                WrapStack(spacing: 10) {
                    ForEach(SportFocus.allCases) { sport in
                        Button(sport.rawValue) {
                            onToggleSport(sport)
                        }
                        .buttonStyle(
                            FilterChipStyle(
                                isSelected: selectedSports.contains(sport),
                                selectedColor: MorpheTheme.color(for: sport)
                            )
                        )
                    }
                }

                Text("Training")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)

                WrapStack(spacing: 10) {
                    ForEach(TrainingStyleOption.allCases) { style in
                        Button(style.rawValue) {
                            onToggleTrainingStyle(style)
                        }
                        .buttonStyle(
                            FilterChipStyle(
                                isSelected: selectedTrainingStyles.contains(style),
                                selectedColor: MorpheTheme.warning
                            )
                        )
                    }
                }

                Text("Goals")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)

                WrapStack(spacing: 10) {
                    ForEach(FitnessGoalOption.allCases) { goal in
                        Button(goal.rawValue) {
                            onToggleGoal(goal)
                        }
                        .buttonStyle(
                            FilterChipStyle(
                                isSelected: selectedGoals.contains(goal.rawValue),
                                selectedColor: MorpheTheme.accentAlt
                            )
                        )
                    }
                }
            }
        }
    }
}

private struct TransformationTimelineCard: View {
    let milestones: [TransformationMilestone]

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("Transformation Timeline")
                    .font(.headline)
                    .foregroundStyle(.white)

                ForEach(milestones) { milestone in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(milestone.title)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.white)
                        Text(milestone.date)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(MorpheTheme.accentAlt)
                        Text(milestone.detail)
                            .font(.caption)
                            .foregroundStyle(MorpheTheme.textSecondary)
                    }
                }
            }
        }
    }
}

private struct PersonalRecordsListCard: View {
    let records: [PersonalRecord]

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("Personal Records")
                    .font(.headline)
                    .foregroundStyle(.white)

                ForEach(records) { record in
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(record.title)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.white)
                            Text(record.detail)
                                .font(.caption)
                                .foregroundStyle(MorpheTheme.textSecondary)
                        }
                        Spacer()
                        Text(record.value)
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(MorpheTheme.accentAlt)
                    }
                }
            }
        }
    }
}

private struct FeaturedShowcaseCard: View {
    let workouts: [FeaturedWorkout]
    let videos: [FeaturedVideo]
    let sourceName: String
    let sourceRole: AppRole
    let onSaveWorkout: (FeaturedWorkout) -> Void

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 14) {
                Text("Featured Work")
                    .font(.headline)
                    .foregroundStyle(.white)

                ForEach(workouts) { workout in
                    HStack(alignment: .top, spacing: 12) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(workout.title)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.white)
                            Text(workout.subtitle)
                                .font(.caption)
                                .foregroundStyle(MorpheTheme.textSecondary)
                        }

                        Spacer()

                        Button("Save") {
                            onSaveWorkout(workout)
                        }
                        .buttonStyle(SecondaryCTAButtonStyle())
                    }
                }

                Divider()
                    .overlay(Color.white.opacity(0.08))

                Text("Featured Videos")
                    .font(.headline)
                    .foregroundStyle(.white)

                ForEach(videos) { video in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(video.title)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.white)
                        Text(video.subtitle)
                            .font(.caption)
                            .foregroundStyle(MorpheTheme.textSecondary)
                    }
                }

                Text("Saved workouts remember the source, so you can track what came from \(sourceName) and what you built into your own library.")
                    .font(.caption)
                    .foregroundStyle(sourceRole == .coach ? MorpheTheme.accentAlt : MorpheTheme.textSecondary)
            }
        }
    }
}

private struct AIPerformanceBioCard: View {
    let text: String

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 10) {
                Text("AI Performance Bio")
                    .font(.headline)
                    .foregroundStyle(.white)
                Text(text)
                    .foregroundStyle(MorpheTheme.textPrimary)
            }
        }
    }
}

private struct AthleteRecentLogsCard: View {
    let logs: [WorkoutLog]

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("Recent Shared Logs")
                    .font(.headline)
                    .foregroundStyle(.white)

                if logs.isEmpty {
                    Text("Workout logs added by you, your coach, or Morphe AI will show here.")
                        .foregroundStyle(MorpheTheme.textSecondary)
                } else {
                    ForEach(logs) { log in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(alignment: .top) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(log.workoutTitle)
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(.white)
                                    Text("\(MorpheAppStore.workoutDateLabel(for: log.completedAt)) • \(log.durationMinutes) min")
                                        .font(.caption)
                                        .foregroundStyle(MorpheTheme.textSecondary)
                                }
                                Spacer()
                                StatusBadge(text: log.source.badgeTitle, color: badgeColor(for: log.source))
                            }

                            Text("\(log.enteredByName) • \(log.verificationStatus.rawValue)")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(MorpheTheme.accentAlt)
                        }
                        .padding(.vertical, 2)
                    }
                }
            }
        }
    }

    private func badgeColor(for source: WorkoutLogSource) -> Color {
        switch source {
        case .athleteManual:
            return MorpheTheme.accent
        case .coachManual:
            return MorpheTheme.accentAlt
        case .aiPhotoParsed:
            return MorpheTheme.lavender
        case .partnerShared:
            return MorpheTheme.warning
        }
    }
}

private struct CoachingToneStatusCard: View {
    let tone: CoachingTone

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 10) {
                Text("Coaching Tone")
                    .font(.headline)
                    .foregroundStyle(.white)

                HStack(spacing: 8) {
                    MetricPill(label: "Current Tone", value: tone.rawValue)
                }

                Text(tone.preview)
                    .foregroundStyle(MorpheTheme.textSecondary)
            }
        }
    }
}

private struct ProfilePrivacyCard: View {
    let title: String
    let isPublic: Bool
    let onToggle: () -> Void

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(.white)

                Text(isPublic ? "Your profile is visible across the Morphe network." : "Your profile is private and only visible inside your coaching workspace.")
                    .foregroundStyle(MorpheTheme.textSecondary)

                Button(isPublic ? "Switch to Private" : "Switch to Public", action: onToggle)
                    .buttonStyle(SecondaryCTAButtonStyle())
            }
        }
    }
}

private struct ProfileSupportCard: View {
    let contactSupport: () -> Void
    let logout: () -> Void

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("Support + Account")
                    .font(.headline)
                    .foregroundStyle(.white)

                Button("Contact Support", action: contactSupport)
                    .buttonStyle(SecondaryCTAButtonStyle())

                Button("Log Out", action: logout)
                    .buttonStyle(SecondaryCTAButtonStyle())

                Text("Account actions are still demo placeholders until real auth and support routing are connected.")
                    .font(.caption)
                    .foregroundStyle(MorpheTheme.textSecondary)
            }
        }
    }
}

private struct AvatarCustomizerCard: View {
    let selected: AvatarStyle
    let avatars: [AvatarStyle]
    let onSelect: (AvatarStyle) -> Void

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("Avatar Customizer")
                    .font(.headline)
                    .foregroundStyle(.white)
                WrapStack(spacing: 10) {
                    ForEach(avatars) { avatar in
                        Button(avatar.rawValue) {
                            onSelect(avatar)
                        }
                        .buttonStyle(FilterChipStyle(isSelected: selected == avatar, selectedColor: MorpheTheme.accentAlt))
                    }
                }
            }
        }
    }
}

private struct BannerCustomizerCard: View {
    let selected: BannerPreset
    let banners: [BannerPreset]
    let onSelect: (BannerPreset) -> Void

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("Banner Customizer")
                    .font(.headline)
                    .foregroundStyle(.white)
                WrapStack(spacing: 10) {
                    ForEach(banners) { banner in
                        Button(banner.rawValue) {
                            onSelect(banner)
                        }
                        .buttonStyle(FilterChipStyle(isSelected: selected == banner))
                    }
                }
            }
        }
    }
}

private struct ThemeSelectorCard: View {
    let selected: ThemePreset
    let themes: [ThemePreset]
    let onSelect: (ThemePreset) -> Void

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("Theme Selector")
                    .font(.headline)
                    .foregroundStyle(.white)
                WrapStack(spacing: 10) {
                    ForEach(themes) { theme in
                        Button(theme.rawValue) {
                            onSelect(theme)
                        }
                        .buttonStyle(FilterChipStyle(isSelected: selected == theme, selectedColor: MorpheTheme.accent))
                    }
                }
            }
        }
    }
}

private struct AccentPaletteSelectorCard: View {
    let selected: AccentPalette
    let palettes: [AccentPalette]
    let onSelect: (AccentPalette) -> Void

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("Accent Color")
                    .font(.headline)
                    .foregroundStyle(.white)
                Text("Swap the app energy without changing the structure.")
                    .foregroundStyle(MorpheTheme.textSecondary)

                WrapStack(spacing: 10) {
                    ForEach(palettes) { palette in
                        Button(palette.rawValue) {
                            onSelect(palette)
                        }
                        .buttonStyle(
                            FilterChipStyle(
                                isSelected: selected == palette,
                                selectedColor: MorpheTheme.colors(for: palette).primary
                            )
                        )
                    }
                }
            }
        }
    }
}

private struct CoachingToneSelectorCard: View {
    let selected: CoachingTone
    let onSelect: (CoachingTone) -> Void

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("Coaching Tone")
                    .font(.headline)
                    .foregroundStyle(.white)
                Text(selected.preview)
                    .foregroundStyle(MorpheTheme.textSecondary)

                WrapStack(spacing: 10) {
                    ForEach(CoachingTone.allCases) { tone in
                        Button(tone.rawValue) {
                            onSelect(tone)
                        }
                        .buttonStyle(FilterChipStyle(isSelected: selected == tone, selectedColor: MorpheTheme.accentAlt))
                    }
                }
            }
        }
    }
}

private struct CoachConnectionCard: View {
    let coachName: String
    let coachStatus: String
    let coachPreview: String

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 10) {
                Text("Coach Connection")
                    .font(.headline)
                    .foregroundStyle(.white)
                Text("\(coachName) • \(coachStatus)")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(MorpheTheme.accent)
                Text(coachPreview)
                    .foregroundStyle(MorpheTheme.textSecondary)
            }
        }
    }
}

private struct ShareableProfileCard: View {
    let showcase: ProfileShowcase
    let level: LevelProgress
    let onShare: () -> Void

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("Shareable Profile Card")
                    .font(.headline)
                    .foregroundStyle(.white)

                HStack(spacing: 12) {
                    MorpheAvatarView(avatar: showcase.avatar, size: 68)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(showcase.displayName)
                            .font(.title3.weight(.bold))
                            .foregroundStyle(.white)
                        Text(showcase.currentPhase)
                            .foregroundStyle(MorpheTheme.accentAlt)
                        Text(level.currentTitle)
                            .font(.caption)
                            .foregroundStyle(MorpheTheme.textSecondary)
                    }
                    Spacer()
                }

                Button("Preview Share Card", action: onShare)
                    .buttonStyle(PrimaryCTAButtonStyle(accent: MorpheTheme.accent))
            }
        }
    }
}

private struct CoachShareableProfileCard: View {
    let showcase: ProfileShowcase
    let profile: CoachProfile
    let onShare: () -> Void

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("Shareable Profile Card")
                    .font(.headline)
                    .foregroundStyle(.white)

                HStack(spacing: 12) {
                    MorpheAvatarView(avatar: showcase.avatar, size: 68)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(profile.name)
                            .font(.title3.weight(.bold))
                            .foregroundStyle(.white)
                        Text(profile.headline)
                            .foregroundStyle(MorpheTheme.accentAlt)
                            .lineLimit(2)
                        Text(profile.networkRank)
                            .font(.caption)
                            .foregroundStyle(MorpheTheme.textSecondary)
                    }
                    Spacer()
                }

                Button("Preview Share Card", action: onShare)
                    .buttonStyle(PrimaryCTAButtonStyle(accent: MorpheTheme.accent))
            }
        }
    }
}

private struct NutritionSummarySection: View {
    let nutrition: NutritionSnapshot
    let insight: AIInsight

    private var proteinProgress: Double {
        min(Double(nutrition.proteinConsumed) / Double(max(nutrition.proteinGoal, 1)), 1)
    }

    private var calorieProgress: Double {
        min(Double(nutrition.caloriesConsumed) / Double(max(nutrition.calorieGoal, 1)), 1)
    }

    private var waterProgress: Double {
        min(Double(nutrition.waterConsumed) / Double(max(nutrition.waterGoal, 1)), 1)
    }

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("Nutrition Basics")
                    .font(.headline)
                    .foregroundStyle(.white)

                NutritionMeter(title: "Calories", consumed: nutrition.caloriesConsumed, goal: nutrition.calorieGoal, unit: "")
                NutritionMeter(title: "Protein", consumed: nutrition.proteinConsumed, goal: nutrition.proteinGoal, unit: "g")
                NutritionMeter(title: "Water", consumed: nutrition.waterConsumed, goal: nutrition.waterGoal, unit: " cups")

                Text(insight.summary)
                    .font(.subheadline)
                    .foregroundStyle(MorpheTheme.textSecondary)
            }
        }
    }
}

private struct LearningSection: View {
    @Environment(MorpheAppStore.self) private var store
    let lessons: [LessonCard]
    let quizzes: [MiniQuiz]

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("Learn")
                    .font(.headline)
                    .foregroundStyle(.white)

                ForEach(lessons) { lesson in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(lesson.title)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.white)
                        Text(lesson.subtitle)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(MorpheTheme.accentAlt)
                        Text(lesson.detail)
                            .font(.caption)
                            .foregroundStyle(MorpheTheme.textSecondary)
                    }
                }

                if !quizzes.isEmpty {
                    Divider()
                        .overlay(Color.white.opacity(0.08))
                    Text("Mini Quizzes")
                        .font(.headline)
                        .foregroundStyle(.white)

                    ForEach(quizzes) { quiz in
                        VStack(alignment: .leading, spacing: 10) {
                            Text(quiz.question)
                                .foregroundStyle(.white)

                            ForEach(Array(quiz.options.enumerated()), id: \.offset) { index, option in
                                Button(option) {
                                    store.answerQuiz(quiz, with: index)
                                }
                                .buttonStyle(
                                    FilterChipStyle(
                                        isSelected: store.quizSelections[quiz.id] == index,
                                        selectedColor: index == quiz.correctIndex ? MorpheTheme.accent : MorpheTheme.warning
                                    )
                                )
                            }

                            if let selectedIndex = store.quizSelections[quiz.id] {
                                Text(selectedIndex == quiz.correctIndex ? quiz.explanation : "Not quite. \(quiz.explanation)")
                                    .font(.caption)
                                    .foregroundStyle(selectedIndex == quiz.correctIndex ? MorpheTheme.accent : MorpheTheme.textSecondary)
                            }

                            if store.completedQuizIDs.contains(quiz.id) {
                                Text("+\(quiz.rewardXP) XP earned")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(MorpheTheme.accentAlt)
                            }
                        }
                    }
                }
            }
        }
    }
}

private struct NutritionMeter: View {
    let title: String
    let consumed: Int
    let goal: Int
    let unit: String

    private var progress: Double {
        guard goal > 0 else { return 0 }
        return min(Double(consumed) / Double(goal), 1)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title)
                    .foregroundStyle(.white)
                Spacer()
                Text("\(consumed)\(unit) / \(goal)\(unit)")
                    .foregroundStyle(MorpheTheme.textSecondary)
            }
            ProgressBarView(progress: progress, color: MorpheTheme.accent)
        }
    }
}
