import SwiftUI

struct ProfileView: View {
    @Environment(MorpheAppStore.self) private var store
    @State private var isEditingName = false
    @State private var nameDraft = ""
    @State private var isEditingInjuries = false
    @State private var injuriesDraft = ""
    @State private var isEditingUsername = false
    @State private var usernameDraft = ""
    @State private var heightDraft = ""
    @State private var weightDraft = ""
    @State private var showSignOutConfirm = false
    @State private var showUnsavedPrompt = false

    private var isCoach: Bool {
        store.selectedRole == .coach
    }

    private var bodyMetricsChanged: Bool {
        // Compare what a save would actually store (trimmed + 20-char cap) —
        // comparing the raw draft left "Save details" stuck for long input.
        normalizedMetric(heightDraft) != store.clientProfile.height
            || normalizedMetric(weightDraft) != store.clientProfile.bodyWeight
    }

    private func normalizedMetric(_ value: String) -> String {
        String(value.trimmingCharacters(in: .whitespacesAndNewlines).prefix(20))
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 16) {
                identityCard
                if isCoach {
                    CoachProfileBody(store: store)
                } else {
                    AthleteProfileBody(store: store)
                    detailsCard
                }
                settingsCard
                if !isCoach {
                    levelCard
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            // This is a sheet — no tab bar underneath to pad around.
            .padding(.bottom, 40)
        }
        .onAppear {
            heightDraft = store.clientProfile.height
            weightDraft = store.clientProfile.bodyWeight
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Done") {
                    if hasUnsavedEdits {
                        showUnsavedPrompt = true
                    } else {
                        store.closeClientProfile()
                    }
                }
                .foregroundStyle(.white)
            }
        }
        // A swipe-down can't silently eat unsaved edits either — with edits
        // pending the sheet stays put, and Done raises the save/discard ask.
        .interactiveDismissDisabled(hasUnsavedEdits)
        .confirmationDialog(
            "Save your profile changes?",
            isPresented: $showUnsavedPrompt,
            titleVisibility: .visible
        ) {
            Button("Save Changes") {
                saveAllEdits()
                store.closeClientProfile()
            }
            Button("Discard Changes", role: .destructive) {
                discardAllEdits()
                store.closeClientProfile()
            }
            Button("Keep Editing", role: .cancel) {}
        } message: {
            Text("You edited your profile but didn't save.")
        }
    }

    /// Edits sitting in drafts that a dismissal would otherwise drop.
    private var hasUnsavedEdits: Bool {
        if bodyMetricsChanged { return true }
        if isEditingName {
            let trimmed = nameDraft.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty, trimmed != store.profileShowcase.displayName { return true }
        }
        if isEditingInjuries,
           injuriesDraft.trimmingCharacters(in: .whitespacesAndNewlines) != store.clientProfile.limitations {
            return true
        }
        if isEditingUsername {
            let entered = UsernameRules.normalize(usernameDraft)
            let current = isCoach ? store.coachProfile.username : store.profileShowcase.username
            if !entered.isEmpty, entered != current { return true }
        }
        return false
    }

    private func saveAllEdits() {
        if isEditingName { saveName() }
        if isEditingUsername { saveUsername() }
        if isEditingInjuries {
            store.updateInjuryNote(injuriesDraft)
            isEditingInjuries = false
        }
        if bodyMetricsChanged {
            store.updateBodyMetrics(height: heightDraft, weight: weightDraft)
        }
    }

    private func discardAllEdits() {
        isEditingName = false
        isEditingUsername = false
        isEditingInjuries = false
        heightDraft = store.clientProfile.height
        weightDraft = store.clientProfile.bodyWeight
    }

    /// Everything about the user's training identity, editable in place —
    /// onboarding stays lean, so this is where these details live.
    private var detailsCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 14) {
                Text("Your Details")
                    .font(.headline)
                    .foregroundStyle(.white)

                VStack(alignment: .leading, spacing: 8) {
                    Text("Experience")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(MorpheTheme.textMuted)
                    WrapStack(spacing: 8) {
                        ForEach(ExperienceLevelOption.allCases) { level in
                            Button(level.rawValue) {
                                store.updateExperienceLevel(level)
                            }
                            .buttonStyle(FilterChipStyle(isSelected: store.clientProfile.fitnessLevel == level.rawValue))
                        }
                    }
                }

                Divider().overlay(Color.white.opacity(0.08))

                VStack(alignment: .leading, spacing: 8) {
                    Text("Goals")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(MorpheTheme.textMuted)
                    WrapStack(spacing: 8) {
                        ForEach(FitnessGoalOption.allCases) { goal in
                            Button(goal.rawValue) {
                                store.toggleProfileGoal(goal)
                            }
                            .buttonStyle(FilterChipStyle(isSelected: store.clientProfile.selectedGoals.contains(goal.rawValue)))
                        }
                    }
                }

                Divider().overlay(Color.white.opacity(0.08))

                VStack(alignment: .leading, spacing: 8) {
                    Text("Training styles")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(MorpheTheme.textMuted)
                    WrapStack(spacing: 8) {
                        ForEach(TrainingStyleOption.allCases) { style in
                            Button(style.rawValue) {
                                store.toggleProfileTrainingStyle(style)
                            }
                            .buttonStyle(FilterChipStyle(isSelected: store.clientProfile.selectedTrainingStyles.contains(style), selectedColor: MorpheTheme.warning))
                        }
                    }
                }

                Divider().overlay(Color.white.opacity(0.08))

                VStack(alignment: .leading, spacing: 8) {
                    Text("Body")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(MorpheTheme.textMuted)
                    HStack(spacing: 10) {
                        TextField("Height (5'10\" or 178 cm)", text: $heightDraft)
                            .textFieldStyle(MorpheFieldStyle())
                        TextField("Weight (170 lb)", text: $weightDraft)
                            .textFieldStyle(MorpheFieldStyle())
                    }
                    if bodyMetricsChanged {
                        Button("Save details") {
                            store.updateBodyMetrics(height: heightDraft, weight: weightDraft)
                        }
                        .buttonStyle(SecondaryCTAButtonStyle())
                    }
                }
            }
        }
    }

    /// XP readout at the bottom of the page. Levels climb a decade curve:
    /// 1–10 take 100 XP each, 11–20 take 200, 21–30 take 300, and so on.
    private var levelCard: some View {
        let level = store.clientProfile.level
        return GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .lastTextBaseline) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("LEVEL")
                            .font(MorpheTheme.microLabel(10))
                            .tracking(1.4)
                            .foregroundStyle(MorpheTheme.textMuted)
                        Text("\(store.currentLevelNumber)")
                            .font(.system(size: 34, design: .monospaced).weight(.bold))
                            .foregroundStyle(MorpheTheme.accent)
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 3) {
                        Text("XP TO LEVEL \(store.currentLevelNumber + 1)")
                            .font(MorpheTheme.microLabel(10))
                            .tracking(1.4)
                            .foregroundStyle(MorpheTheme.textMuted)
                        Text("\(level.currentXP) / \(level.targetXP)")
                            .font(.system(.title3, design: .monospaced).weight(.semibold))
                            .foregroundStyle(.white)
                    }
                }

                ProgressBarView(progress: level.progress, color: MorpheTheme.accent)

                Text("Earn XP from workouts, daily wins, and quizzes. Each tier of ten levels asks a little more: 100 XP per level through 10, then 200, then 300.")
                    .font(.caption)
                    .foregroundStyle(MorpheTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Level \(store.currentLevelNumber), \(level.currentXP) of \(level.targetXP) XP to level \(store.currentLevelNumber + 1)")
    }

    private var identityCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 14) {
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
                    if let next = store.nextNameChangeDate {
                        Text("Names change once every 14 days — next change \(next.formatted(date: .abbreviated, time: .omitted)).")
                            .font(.caption)
                            .foregroundStyle(MorpheTheme.textMuted)
                    }
                }

                Divider().overlay(Color.white.opacity(0.08))

                if isEditingUsername {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 8) {
                            TextField("username", text: $usernameDraft)
                                .textFieldStyle(MorpheFieldStyle())
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                            Button("Save") {
                                saveUsername()
                            }
                            .buttonStyle(.plain)
                            .foregroundStyle(MorpheTheme.accent)
                            .accessibilityLabel("Save username")
                            Button("Cancel") {
                                isEditingUsername = false
                            }
                            .buttonStyle(.plain)
                            .foregroundStyle(MorpheTheme.textMuted)
                            .accessibilityLabel("Cancel username edit")
                        }
                        Text("Usernames are unique across Morphe and change once every 14 days.")
                            .font(.caption)
                            .foregroundStyle(MorpheTheme.textMuted)
                    }
                } else {
                    settingsRow(
                        "Username",
                        value: "@\(isCoach ? store.coachProfile.username : store.profileShowcase.username)"
                    ) {
                        usernameDraft = isCoach ? store.coachProfile.username : store.profileShowcase.username
                        isEditingUsername = true
                    }
                    if let next = store.nextUsernameChangeDate {
                        Text("Usernames change once every 14 days — next change \(next.formatted(date: .abbreviated, time: .omitted)).")
                            .font(.caption)
                            .foregroundStyle(MorpheTheme.textMuted)
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

                }

                Divider().overlay(Color.white.opacity(0.08))

                if FeatureFlags.accountsEnabled {
                    Button("Sign Out") {
                        showSignOutConfirm = true
                    }
                    .buttonStyle(SecondaryCTAButtonStyle())
                    .alert("Are you sure you want to sign out?", isPresented: $showSignOutConfirm) {
                        Button("Sign Out", role: .destructive) {
                            // Close the profile sheet first so the account
                            // screen is immediately visible underneath.
                            store.closeClientProfile()
                            store.signOut()
                        }
                        Button("Cancel", role: .cancel) {}
                    } message: {
                        Text("Your data stays backed up to your account — signing back in restores everything.")
                    }
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

    private func saveUsername() {
        let entered = usernameDraft
        isEditingUsername = false
        Task {
            // The store handles the 14-day cooldown, validation, and the
            // atomic uniqueness claim — and reports each outcome as a toast.
            await store.changeUsername(to: entered)
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
                            // Schedule-aware streak (protected days count)
                            // via workoutLogSummary's honest path.
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
                                .background(RoundedRectangle(cornerRadius: MorpheTheme.radius, style: .continuous).fill(MorpheTheme.panelStrong))
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
                RoundedRectangle(cornerRadius: 2, style: .continuous)
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

