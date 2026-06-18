import SwiftUI

struct ProfileView: View {
    @Environment(MorpheAppStore.self) private var store
    @State private var isEditingName = false
    @State private var nameDraft = ""

    private var isCoach: Bool {
        store.selectedRole == .coach
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 16) {
                identityCard
                if isCoach {
                    CoachProfileBody(store: store)
                } else {
                    AthleteProfileBody(store: store)
                }
                settingsCard
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 120)
        }
    }

    private var identityCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 14) {
                    MorpheAvatarView(avatar: store.profileShowcase.avatar, size: 72)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(isCoach ? store.coachProfile.name : store.profileShowcase.displayName)
                            .font(.title2.weight(.bold))
                            .foregroundStyle(.white)
                        Text("@\(isCoach ? store.coachProfile.username : store.profileShowcase.username)")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(MorpheTheme.accent)
                        Text(isCoach
                            ? "Coach"
                            : "\(store.clientProfile.sportMode.rawValue) • \(store.clientProfile.fitnessLevel)")
                            .font(.caption)
                            .foregroundStyle(MorpheTheme.textMuted)
                    }
                    Spacer()
                    StatusBadge(text: isCoach ? "Coach" : "Athlete", color: MorpheTheme.accent)
                }
            }
        }
    }

    private var settingsCard: some View {
        @Bindable var store = store
        return GlassCard {
            VStack(alignment: .leading, spacing: 14) {
                Text("Settings")
                    .font(.headline)
                    .foregroundStyle(.white)

                if isEditingName {
                    HStack(spacing: 8) {
                        TextField("Your name", text: $nameDraft)
                            .textFieldStyle(MorpheFieldStyle())
                        Button("Save") {
                            store.updateDisplayName(nameDraft)
                            isEditingName = false
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(MorpheTheme.accent)
                    }
                } else {
                    settingsRow(
                        "Name",
                        value: isCoach ? store.coachProfile.name : store.profileShowcase.displayName,
                        showEdit: !isCoach
                    ) {
                        nameDraft = store.profileShowcase.displayName
                        isEditingName = true
                    }
                }

                Divider().overlay(Color.white.opacity(0.08))

                HStack {
                    Text("Weight unit")
                        .foregroundStyle(.white)
                    Spacer()
                    Picker("Weight unit", selection: $store.weightUnit) {
                        ForEach(WeightUnit.allCases) { unit in
                            Text(unit.label).tag(unit)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 110)
                }

                Divider().overlay(Color.white.opacity(0.08))

                if FeatureFlags.accountsEnabled {
                    Button("Sign Out") {
                        store.signOut()
                    }
                    .buttonStyle(SecondaryCTAButtonStyle())
                }
            }
        }
    }

    private func settingsRow(_ title: String, value: String, showEdit: Bool = true, onEdit: @escaping () -> Void) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(MorpheTheme.textMuted)
                Text(value)
                    .foregroundStyle(.white)
            }
            Spacer()
            if showEdit {
                Button("Edit", action: onEdit)
                    .buttonStyle(.plain)
                    .foregroundStyle(MorpheTheme.accent)
            }
        }
    }
}

/// Athlete profile = strictly training: snapshot, focus, recent work, records.
private struct AthleteProfileBody: View {
    let store: MorpheAppStore

    var body: some View {
        let summary = store.workoutLogSummary(for: store.clientProfile.id)
        Group {
            GlassCard {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Training snapshot")
                        .font(.headline)
                        .foregroundStyle(.white)
                    HStack(spacing: 8) {
                        MetricPill(label: "Morphe Score", value: "\(store.clientProfile.health.score)")
                        MetricPill(label: "Streak", value: "\(store.clientProfile.level.streak) days")
                        MetricPill(label: "This week", value: "\(summary.workoutsThisWeek)")
                    }
                }
            }

            GlassCard {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Focus")
                        .font(.headline)
                        .foregroundStyle(.white)
                    Text(store.clientProfile.goal)
                        .foregroundStyle(MorpheTheme.textSecondary)
                    WrapStack(spacing: 8) {
                        ForEach(store.clientProfile.selectedSports) { sport in
                            SelectionToken(text: sport.shortTitle, color: MorpheTheme.color(for: sport))
                        }
                        ForEach(store.clientProfile.selectedTrainingStyles) { style in
                            SelectionToken(text: style.rawValue, color: MorpheTheme.warning)
                        }
                    }
                }
            }

            AthleteRecentLogsCard(logs: Array(store.currentAthleteWorkoutLogs.prefix(5)))

            if !store.profileShowcase.personalRecords.isEmpty {
                PersonalRecordsListCard(records: store.profileShowcase.personalRecords)
            }
        }
    }
}

/// Coach profile = coaching identity + client/outreach snapshot (real once the
/// backend connects; sample data for now).
private struct CoachProfileBody: View {
    let store: MorpheAppStore
    @State private var showBusiness = false

    var body: some View {
        Group {
            GlassCard {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Coaching snapshot")
                        .font(.headline)
                        .foregroundStyle(.white)
                    HStack(spacing: 8) {
                        MetricPill(label: "Clients", value: "\(store.coachClients.count)")
                        MetricPill(label: "Need check-in",
                                   value: "\(store.coachClients.filter { $0.risk == .high }.count)")
                        MetricPill(label: "Specialty", value: store.coachProfile.specialty)
                    }
                    Text(store.coachProfile.headline)
                        .foregroundStyle(MorpheTheme.textSecondary)
                }
            }

            GlassCard {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Specialties")
                        .font(.headline)
                        .foregroundStyle(.white)
                    WrapStack(spacing: 8) {
                        ForEach(store.coachProfile.sports) { sport in
                            SelectionToken(text: sport.shortTitle, color: MorpheTheme.color(for: sport))
                        }
                        ForEach(store.coachProfile.selectedTrainingStyles) { style in
                            SelectionToken(text: style.rawValue, color: MorpheTheme.warning)
                        }
                    }
                }
            }

            GlassCard {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Your coaching tools")
                        .font(.headline)
                        .foregroundStyle(.white)
                    Text("Build programs, track clients, and run outreach from the coach tabs. Connecting real clients turns on with your account backend.")
                        .font(.subheadline)
                        .foregroundStyle(MorpheTheme.textSecondary)
                }
            }

            if FeatureFlags.multiUserEnabled {
                Button {
                    showBusiness = true
                } label: {
                    GlassCard {
                        HStack(spacing: 12) {
                            Image(systemName: "banknote")
                                .font(.headline)
                                .foregroundStyle(MorpheTheme.accent)
                                .frame(width: 44, height: 44)
                                .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(MorpheTheme.panelStrong))
                            VStack(alignment: .leading, spacing: 3) {
                                Text("Training Business")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(.white)
                                Text("Set rates, take bookings, track earnings.")
                                    .font(.caption)
                                    .foregroundStyle(MorpheTheme.textSecondary)
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
            }
        }
        .sheet(isPresented: $showBusiness) {
            NavigationStack {
                CoachBusinessView()
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button("Done") { showBusiness = false }
                                .foregroundStyle(.white)
                        }
                    }
            }
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
