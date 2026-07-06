import SwiftUI

struct ProfileView: View {
    @Environment(MorpheAppStore.self) private var store
    @State private var isEditingName = false
    @State private var nameDraft = ""
    @State private var isEditingInjuries = false
    @State private var injuriesDraft = ""

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
            // This is a sheet — no tab bar underneath to pad around.
            .padding(.bottom, 40)
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
                            : "\(store.clientProfile.sportMode.rawValue)\(store.clientProfile.fitnessLevel.isEmpty ? "" : " • \(store.clientProfile.fitnessLevel)")")
                            .font(.caption)
                            .foregroundStyle(MorpheTheme.textMuted)
                    }
                    Spacer()
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
                            .submitLabel(.done)
                            .onSubmit { saveName() }
                        Button("Save") {
                            saveName()
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(MorpheTheme.accent)
                        .accessibilityLabel("Save name")
                        Button("Cancel") {
                            isEditingName = false
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(MorpheTheme.textMuted)
                        .accessibilityLabel("Cancel name edit")
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

                if !isCoach {
                    Divider().overlay(Color.white.opacity(0.08))

                    // Weekly target — drives the consistency denominator on
                    // Progress; was user-set in onboarding then locked forever.
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Training days per week")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(MorpheTheme.textMuted)
                        WrapStack(spacing: 8) {
                            ForEach(1...7, id: \.self) { count in
                                Button("\(count)") {
                                    store.updateTrainingDaysPerWeek(count)
                                }
                                .buttonStyle(FilterChipStyle(isSelected: store.clientProfile.trainingDaysPerWeek == count, selectedColor: MorpheTheme.accent))
                                .accessibilityLabel("\(count) days per week")
                            }
                        }
                    }

                    Divider().overlay(Color.white.opacity(0.08))

                    // Injuries are safety data — collected in onboarding and
                    // previously never editable again.
                    if isEditingInjuries {
                        VStack(alignment: .leading, spacing: 8) {
                            TextField("Injuries or limits Morphe should respect", text: $injuriesDraft, axis: .vertical)
                                .textFieldStyle(MorpheFieldStyle())
                                .lineLimit(2...4)
                            HStack(spacing: 12) {
                                Button("Save") {
                                    store.updateInjuryNote(injuriesDraft)
                                    isEditingInjuries = false
                                }
                                .buttonStyle(.plain)
                                .foregroundStyle(MorpheTheme.accent)
                                .accessibilityLabel("Save injury note")
                                Button("Cancel") {
                                    isEditingInjuries = false
                                }
                                .buttonStyle(.plain)
                                .foregroundStyle(MorpheTheme.textMuted)
                                .accessibilityLabel("Cancel injury note edit")
                            }
                        }
                    } else {
                        settingsRow(
                            "Injuries & limits",
                            value: store.clientProfile.limitations.isEmpty ? "None noted" : store.clientProfile.limitations
                        ) {
                            injuriesDraft = store.clientProfile.limitations
                            isEditingInjuries = true
                        }
                    }

                    Divider().overlay(Color.white.opacity(0.08))

                    // Wires the avatar layer back up: the onboarding avatar
                    // step was cut, which froze everyone on the default with
                    // no way to change it anywhere.
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Avatar")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(MorpheTheme.textMuted)
                        WrapStack(spacing: 8) {
                            ForEach(store.availableAvatars) { style in
                                Button(style.rawValue) {
                                    store.selectAvatarStyle(style)
                                }
                                .buttonStyle(FilterChipStyle(isSelected: store.profileShowcase.avatar.style == style, selectedColor: MorpheTheme.accentAlt))
                            }
                        }
                    }
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

    private func saveName() {
        let trimmed = nameDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        store.updateDisplayName(nameDraft)
        // Keep the editor open on an empty save so the silent-close bug
        // (old name kept, no feedback) can't recur.
        if !trimmed.isEmpty {
            isEditingName = false
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
                    .lineLimit(2)
            }
            Spacer()
            if showEdit {
                Button("Edit", action: onEdit)
                    .buttonStyle(.plain)
                    .foregroundStyle(MorpheTheme.accent)
                    .accessibilityLabel("Edit \(title.lowercased())")
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
                    if store.todayExperienceTier >= 1 {
                        HStack(spacing: 8) {
                            MetricPill(label: "Morphe Score", value: "\(store.clientProfile.health.score)")
                            // The real log-derived streak (level.streak is a
                            // legacy field that stays 0).
                            MetricPill(label: "Streak", value: "\(summary.currentStreakDays) days")
                            MetricPill(label: "This week", value: "\(summary.workoutsThisWeek) of \(max(store.clientProfile.trainingDaysPerWeek, 1))")
                        }
                    } else {
                        Text("Your score, streak, and weekly count appear after your first logged workout.")
                            .font(.subheadline)
                            .foregroundStyle(MorpheTheme.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
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

            if !store.derivedPersonalRecords.isEmpty {
                PersonalRecordsListCard(records: store.derivedPersonalRecords)
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
                Text("Recent Workouts")
                    .font(.headline)
                    .foregroundStyle(.white)

                if logs.isEmpty {
                    Text("The workouts you log land here.")
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
                                // Provenance badges ("Coach entry", "Athlete
                                // submitted") only mean something once other
                                // people can write to your log.
                                if FeatureFlags.multiUserEnabled {
                                    StatusBadge(text: log.source.badgeTitle, color: badgeColor(for: log.source))
                                }
                            }

                            if FeatureFlags.multiUserEnabled {
                                Text("\(log.enteredByName) • \(log.verificationStatus.rawValue)")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(MorpheTheme.accentAlt)
                            }
                        }
                        .padding(.vertical, 2)
                        .accessibilityElement(children: .combine)
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

