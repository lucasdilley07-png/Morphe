import SwiftUI
import UniformTypeIdentifiers
import PhotosUI

struct ProfileView: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(MorpheAppStore.self) private var store
    @State private var isEditingName = false
    @State private var showTermsSheet = false
    @State private var nameDraft = ""
    @State private var isEditingInjuries = false
    @State private var injuriesDraft = ""
    @State private var isEditingUsername = false
    @State private var usernameDraft = ""
    @State private var isEditingBio = false
    @State private var showIdentitySheet = false
    @State private var bioDraft = ""
    @State private var isEditingTargets = false
    @State private var physicalTargetDraft = ""
    @State private var weightTargetDraft = ""
    @State private var deadlineTargetDraft = ""
    @State private var photoPickerItem: PhotosPickerItem?
    @State private var showVerificationCamera = false
    @State private var showSignOutConfirm = false
    @State private var showUnsavedPrompt = false
    /// True while the unsaved-changes ask was raised BY the Progress row —
    /// save/discard then continues into Progress instead of just closing.
    @State private var progressAfterResolve = false
    @State private var replayAfterResolve = false
    @State private var showDeleteAccountConfirm = false
    @State private var isDeletingAccount = false
    /// The generated export file, presented in the system share sheet.
    private struct ExportFile: Identifiable {
        let url: URL
        var id: String { url.absoluteString }
    }
    @State private var exportFile: ExportFile?
    @State private var showImportPicker = false
    @State private var showCreatorStudio = false
    @State private var importPlan: MorpheAppStore.ImportPlan?
    @State private var importReading = false
    @State private var showPaywall = false
    @State private var showingCode = false



    /// Hoisted from AthleteProfileBody (audit 5, P1-5): as child @State the
    /// unsaved-edit guard couldn't see a typed-but-unsaved weight, so Done
    /// or a swipe-down silently dropped it.
    @State private var weightDraft = ""
    @State private var goalWeightDraft = ""
    @State private var ageDraft = ""
    @State private var showWeightWarning = false
    /// Instagram-style settings search: filters the grouped sections.
    @State private var settingsQuery = ""

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 16) {
                identityCard
                AthleteProfileBody(
                    store: store,
                    weightDraft: $weightDraft,
                    onOpenProgress: { requestOpenProgress() }
                ) {
                    // Level and rank, then the guide replay, above the
                    // history door (Lucas 2026-10-06 / 2026-10-10).
                    levelCard
                    replayGuideRow
                }
                // Your Details + Your Milestones live in Your account now
                // (Lucas 2026-10-10).
                settingsSections
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            // This is a sheet — no tab bar underneath to pad around.
            .padding(.bottom, 40)
        }
        .sheet(item: $exportFile) { file in
            DataExportShareSheet(url: file.url) {
                exportFile = nil
            }
            .presentationDetents([.medium, .large])
        }
        .sheet(isPresented: $showPaywall) {
            MorpheProPaywallSheet()
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
                .foregroundStyle(MorpheTheme.textPrimary)
            }
        }
        // A swipe-down can't silently eat unsaved edits either — with edits
        // pending the sheet stays put, and Done raises the save/discard ask.
        .interactiveDismissDisabled(hasUnsavedEdits)
        // (The verification camera presents from the identity page, which
        // hosts Get Verified now — a cover from here couldn't rise over it.)
        .confirmationDialog(
            "Save your profile changes?",
            isPresented: $showUnsavedPrompt,
            titleVisibility: .visible
        ) {
            Button("Save Changes") {
                saveAllEdits()
                resolveClose()
            }
            Button("Discard Changes", role: .destructive) {
                discardAllEdits()
                resolveClose()
            }
            Button("Keep Editing", role: .cancel) {
                progressAfterResolve = false
            }
        } message: {
            Text("You edited your profile but didn't save.")
        }
    }

    /// The Progress row goes through the SAME unsaved-edit guard as Done
    /// (audit 15, P1) — and through openProgress()'s queued-open, so the
    /// sheet swap is the documented pendingProgressOpen path, not a
    /// same-transaction race.
    private func requestOpenProgress() {
        if hasUnsavedEdits {
            progressAfterResolve = true
            showUnsavedPrompt = true
        } else {
            store.openProgress()
        }
    }

    /// Shared exit for the unsaved-changes dialog: continue to Progress
    /// when that's what triggered the ask, plain close otherwise.
    private func resolveClose() {
        if progressAfterResolve {
            progressAfterResolve = false
            store.openProgress()
        } else if replayAfterResolve {
            replayAfterResolve = false
            store.replayGuide()
        } else {
            store.closeClientProfile()
        }
    }

    /// The guide, on demand: the same nine-stop tour a new account gets,
    /// every stop still optional. Sits under the level card.
    private var replayGuideRow: some View {
        Button {
            requestReplayGuide()
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "map")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(MorpheTheme.accentText)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Replay the guide")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(MorpheTheme.textPrimary)
                    Text("Two minutes: Form Check, Morphe AI, Train Together, fuel, the ladder.")
                        .font(.caption)
                        .foregroundStyle(MorpheTheme.textMuted)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(MorpheTheme.textMuted)
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: MorpheTheme.radius, style: .continuous)
                    .fill(MorpheTheme.panel)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Replay the guide")
        .accessibilityHint("Closes Profile and opens the tour")
    }

    /// Replaying the guide closes the profile — an unsaved draft gets the
    /// same save/discard ask Done gives it (audit 30).
    private func requestReplayGuide() {
        if hasUnsavedEdits {
            replayAfterResolve = true
            showUnsavedPrompt = true
        } else {
            store.replayGuide()
        }
    }

    /// Edits sitting in drafts that a dismissal would otherwise drop.
    private var hasUnsavedEdits: Bool {
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
            let current = store.profileShowcase.username
            if !entered.isEmpty, entered != current { return true }
        }
        if isEditingBio,
           bioDraft.trimmingCharacters(in: .whitespacesAndNewlines) != store.profileCustomBio {
            return true
        }
        if isEditingTargets, targetsChanged {
            return true
        }
        // A typed-but-unsaved weight counts too — it feeds the Progress
        // chart and nutrition targets, so it must never vanish silently.
        // Only a PARSEABLE value counts: "abc" isn't an edit worth a save
        // prompt, and saving it would record garbage (audit 6, P2-10).
        if MorpheAppStore.parsedBodyWeightLb(weightDraft, assumedUnit: store.weightUnit) != nil {
            return true
        }
        if goalWeightChanged || ageChanged { return true }
        return false
    }

    private var goalWeightChanged: Bool {
        let clean = goalWeightDraft.trimmingCharacters(in: .whitespaces)
        return !clean.isEmpty && clean != store.clientProfile.goalWeight
            && MorpheAppStore.parsedBodyWeightLb(clean, assumedUnit: store.weightUnit) != nil
    }

    private var ageChanged: Bool {
        guard let years = Int(ageDraft.trimmingCharacters(in: .whitespaces)), years > 0 else { return false }
        return years != store.clientProfile.age
    }

    private var targetsChanged: Bool {
        physicalTargetDraft.trimmingCharacters(in: .whitespacesAndNewlines) != store.clientProfile.physicalGoalTarget
            || weightTargetDraft.trimmingCharacters(in: .whitespacesAndNewlines) != store.clientProfile.weightGoalTarget
            || deadlineTargetDraft.trimmingCharacters(in: .whitespacesAndNewlines) != store.clientProfile.goalDeadline
    }

    private func saveAllEdits() {
        if isEditingName { saveName() }
        if isEditingUsername { saveUsername() }
        if isEditingInjuries {
            store.updateInjuryNote(injuriesDraft)
            isEditingInjuries = false
        }
        if isEditingBio { saveBio() }
        if isEditingTargets {
            if targetsChanged { saveTargets() } else { isEditingTargets = false }
        }
        commitDetailsDrafts()
        editingDetails = false
    }

    /// The details box's typed-but-unsaved fields — shared by Done and the
    /// sheet-wide save so neither can drop a weight the user typed.
    private func commitDetailsDrafts() {
        let weight = weightDraft.trimmingCharacters(in: .whitespaces)
        if MorpheAppStore.parsedBodyWeightLb(weight, assumedUnit: store.weightUnit) != nil {
            store.updateBodyMetrics(height: store.clientProfile.height, weight: weight)
        }
        weightDraft = ""
        if goalWeightChanged { store.updateGoalWeight(goalWeightDraft) }
        goalWeightDraft = ""
        if ageChanged, let years = Int(ageDraft.trimmingCharacters(in: .whitespaces)) { store.updateAge(years) }
        ageDraft = ""
    }

    private func discardAllEdits() {
        isEditingName = false
        isEditingUsername = false
        isEditingInjuries = false
        isEditingBio = false
        isEditingTargets = false
        editingDetails = false
        weightDraft = ""
        goalWeightDraft = ""
        ageDraft = ""
    }

    /// Everything about the user's training identity, editable in place —
    /// onboarding stays lean, so this is where these details live.
    /// Collapsed by default (Lucas 2026-10-06): four lines of what's set,
    /// and the chip groups only when editing — they ran a full screen.
    @State private var editingDetails = false

    private var detailsSummary: [(String, String)] {
        let goals = store.clientProfile.selectedGoals
        let styles = store.clientProfile.selectedTrainingStyles.map(\.rawValue)
        let gear = Array(selectedEquipment).sorted()
        let diet = MorpheAppStore.splitJoined(store.clientProfile.diet)
        let weak = MorpheAppStore.splitJoined(store.clientProfile.weaknesses)
        func line(_ items: [String], none: String) -> String {
            items.isEmpty ? none : items.prefix(3).joined(separator: ", ") + (items.count > 3 ? " +\(items.count - 3)" : "")
        }
        return [
            ("Age", store.clientProfile.age > 0 ? "\(store.clientProfile.age)" : "Not set"),
            ("Experience", store.clientProfile.fitnessLevel.isEmpty ? "Not set" : store.clientProfile.fitnessLevel),
            ("Weight", store.weightJourneyLine),
            ("Goals", line(goals, none: "Not set")),
            ("Diet", line(diet, none: "Not set")),
            ("Styles", line(styles, none: "Not set")),
            ("Equipment", line(gear, none: "Not set")),
            ("Weakness", line(weak, none: "Not set"))
        ]
    }

    private var detailsCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Text("Your Details")
                        .font(.headline)
                        .foregroundStyle(MorpheTheme.textPrimary)
                    Spacer()
                    Button(editingDetails ? "Done" : "Edit") {
                        if editingDetails {
                            // Done commits everything typed in the box
                            // (audit 2026-10-12, P1): age, current and goal
                            // weight, and the milestones only if they changed.
                            commitDetailsDrafts()
                            if targetsChanged { saveTargets() } else { isEditingTargets = false }
                        } else {
                            physicalTargetDraft = store.clientProfile.physicalGoalTarget
                            weightTargetDraft = store.clientProfile.weightGoalTarget
                            deadlineTargetDraft = store.clientProfile.goalDeadline
                            isEditingTargets = true
                        }
                        withAnimation(.easeInOut(duration: 0.2)) { editingDetails.toggle() }
                    }
                    .accessibilityLabel(editingDetails ? "Done editing details and milestones" : "Edit details and milestones")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(MorpheTheme.accentText)
                    .frame(minWidth: 44, minHeight: 44)
                }

                if !editingDetails {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(detailsSummary, id: \.0) { row in
                            HStack(alignment: .firstTextBaseline, spacing: 10) {
                                Text(row.0.uppercased())
                                    .font(MorpheTheme.microLabel(10))
                                    .tracking(1.2)
                                    .foregroundStyle(MorpheTheme.textMuted)
                                    .frame(width: 92, alignment: .leading)
                                Text(row.1)
                                    .font(.subheadline)
                                    .foregroundStyle(MorpheTheme.textPrimary)
                                    .lineLimit(2)
                            }
                        }
                    }
                } else {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Age")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(MorpheTheme.textMuted)
                    HStack(spacing: 10) {
                        TextField(store.clientProfile.age > 0 ? "\(store.clientProfile.age)" : "Years", text: $ageDraft)
                            .textFieldStyle(MorpheFieldStyle())
                            .keyboardType(.numberPad)
                            .frame(maxWidth: 120)
                        if ageChanged {
                            Button("Save") {
                                if let years = Int(ageDraft.trimmingCharacters(in: .whitespaces)) { store.updateAge(years) }
                                ageDraft = ""
                            }
                            .buttonStyle(.plain)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(MorpheTheme.accentText)
                            .frame(minHeight: 44)
                            .accessibilityLabel("Save age")
                        }
                        Spacer(minLength: 0)
                    }
                }

                Divider().overlay(MorpheTheme.strokeSubtle)

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

                Divider().overlay(MorpheTheme.strokeSubtle)

                // Weight: current → goal (Lucas 2026-10-10). The current
                // weight is the app's only weight-entry point — it feeds the
                // Progress chart and the nutrition targets.
                VStack(alignment: .leading, spacing: 8) {
                    Text("Weight")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(MorpheTheme.textMuted)
                    HStack(alignment: .center, spacing: 10) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("CURRENT")
                                .font(MorpheTheme.microLabel(9)).tracking(1.2)
                                .foregroundStyle(MorpheTheme.textMuted)
                            TextField(store.clientProfile.bodyWeight.isEmpty
                                      ? (store.weightUnit == .kilograms ? "e.g. 77" : "e.g. 170")
                                      : store.clientProfile.bodyWeight, text: $weightDraft)
                                .textFieldStyle(MorpheFieldStyle())
                                .keyboardType(.decimalPad)
                                .onChange(of: weightDraft) { _, newValue in
                                    let clean = newValue.trimmingCharacters(in: .whitespaces)
                                    showWeightWarning = clean.count > 2
                                        && MorpheAppStore.parsedBodyWeightLb(clean, assumedUnit: store.weightUnit) == nil
                                }
                        }
                        Image(systemName: "arrow.right")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(MorpheTheme.textMuted)
                            .padding(.top, 14)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("GOAL")
                                .font(MorpheTheme.microLabel(9)).tracking(1.2)
                                .foregroundStyle(MorpheTheme.textMuted)
                            TextField(store.clientProfile.goalWeight.isEmpty
                                      ? (store.weightUnit == .kilograms ? "e.g. 72" : "e.g. 160")
                                      : store.clientProfile.goalWeight, text: $goalWeightDraft)
                                .textFieldStyle(MorpheFieldStyle())
                                .keyboardType(.decimalPad)
                        }
                    }
                    if let last = store.bodyWeightHistory.last {
                        Text("Logged \(last.date.formatted(.relative(presentation: .named))) · unit in Settings")
                            .font(.caption2)
                            .foregroundStyle(MorpheTheme.textMuted)
                    } else {
                        Text("Log it once and the Progress chart + nutrition targets personalize from it.")
                            .font(.caption2)
                            .foregroundStyle(MorpheTheme.textMuted)
                    }
                    if showWeightWarning {
                        Text("Enter a number — like \(store.weightUnit == .kilograms ? "77" : "170").")
                            .font(.caption)
                            .foregroundStyle(MorpheTheme.warning)
                    }
                    if MorpheAppStore.parsedBodyWeightLb(weightDraft, assumedUnit: store.weightUnit) != nil || goalWeightChanged {
                        Button("Save Weight") {
                            let clean = weightDraft.trimmingCharacters(in: .whitespaces)
                            if MorpheAppStore.parsedBodyWeightLb(clean, assumedUnit: store.weightUnit) != nil {
                                store.updateBodyMetrics(height: store.clientProfile.height, weight: clean)
                                weightDraft = ""
                            }
                            if goalWeightChanged {
                                store.updateGoalWeight(goalWeightDraft)
                                goalWeightDraft = ""
                            }
                            showWeightWarning = false
                        }
                        .buttonStyle(PrimaryCTAButtonStyle(accent: MorpheTheme.accent))
                    }
                }

                Divider().overlay(MorpheTheme.strokeSubtle)

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

                Divider().overlay(MorpheTheme.strokeSubtle)

                VStack(alignment: .leading, spacing: 8) {
                    Text("Diet")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(MorpheTheme.textMuted)
                    WrapStack(spacing: 8) {
                        ForEach(DietOption.allCases) { option in
                            Button(option.rawValue) {
                                store.toggleProfileDiet(option)
                            }
                            .buttonStyle(FilterChipStyle(isSelected: MorpheAppStore.splitJoined(store.clientProfile.diet).contains(option.rawValue)))
                        }
                    }
                }

                Divider().overlay(MorpheTheme.strokeSubtle)

                VStack(alignment: .leading, spacing: 8) {
                    Text("Training styles")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(MorpheTheme.textMuted)
                    WrapStack(spacing: 8) {
                        ForEach(TrainingStyleOption.allCases) { style in
                            Button(style.rawValue) {
                                store.toggleProfileTrainingStyle(style)
                            }
                            .buttonStyle(FilterChipStyle(isSelected: store.clientProfile.selectedTrainingStyles.contains(style)))
                        }
                    }
                }

                Divider().overlay(MorpheTheme.strokeSubtle)

                VStack(alignment: .leading, spacing: 8) {
                    Text("Equipment")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(MorpheTheme.textMuted)
                    WrapStack(spacing: 8) {
                        ForEach(MorpheAppStore.equipmentOptions, id: \.self) { option in
                            Button(option) {
                                toggleEquipment(option)
                            }
                            .buttonStyle(FilterChipStyle(isSelected: selectedEquipment.contains(option)))
                        }
                    }
                }

                Divider().overlay(MorpheTheme.strokeSubtle)

                VStack(alignment: .leading, spacing: 8) {
                    Text("Weakness")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(MorpheTheme.textMuted)
                    Text("Your own read. Morphe leans plans and advice toward it.")
                        .font(.caption2)
                        .foregroundStyle(MorpheTheme.textMuted)
                    WrapStack(spacing: 8) {
                        ForEach(WeaknessOption.allCases) { option in
                            Button(option.rawValue) {
                                store.toggleProfileWeakness(option)
                            }
                            .buttonStyle(FilterChipStyle(isSelected: MorpheAppStore.splitJoined(store.clientProfile.weaknesses).contains(option.rawValue)))
                        }
                    }
                }
                }

                // Your Milestones share the box (Lucas 2026-10-10): bold
                // title under the details, same left edge, one Edit.
                Divider().overlay(MorpheTheme.strokeSubtle)
                milestonesBody
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    /// Same comma-joined format onboarding writes, split back into a set.
    private var selectedEquipment: Set<String> {
        Set(store.clientProfile.equipment
            .components(separatedBy: ", ")
            .filter { !$0.isEmpty })
    }

    /// Instant-commit like the other chip sections — re-joined in canonical
    /// option order so the stored string reads cleanly everywhere.
    private func toggleEquipment(_ option: String) {
        var current = selectedEquipment
        if current.contains(option) {
            current.remove(option)
        } else {
            current.insert(option)
        }
        store.updateEquipment(
            MorpheAppStore.equipmentOptions
                .filter { current.contains($0) }
                .joined(separator: ", ")
        )
    }

    /// The 30/60/90-day targets captured in onboarding. Edit mode rides
    /// the Details card's Edit/Done; drafts ride the sheet's save/discard
    /// guard so a swipe-down can't eat half-typed goals.
    private var milestonesBody: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Your Milestones")
                .font(.headline.weight(.bold))
                .foregroundStyle(MorpheTheme.textPrimary)

            if editingDetails {
                targetField("30-day", placeholder: "Your 30-day milestone", text: $physicalTargetDraft)
                targetField("60-day", placeholder: "Your 60-day milestone", text: $weightTargetDraft)
                targetField("90-day", placeholder: "Your 90-day milestone", text: $deadlineTargetDraft)
            } else {
                targetRow("30-day", value: store.clientProfile.physicalGoalTarget)
                targetRow("60-day", value: store.clientProfile.weightGoalTarget)
                targetRow("90-day", value: store.clientProfile.goalDeadline)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func targetRow(_ label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.caption.weight(.semibold))
                .foregroundStyle(MorpheTheme.textMuted)
            Text(value.isEmpty ? "Not set" : value)
                .foregroundStyle(value.isEmpty ? MorpheTheme.textMuted : MorpheTheme.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func targetField(_ label: String, placeholder: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption.weight(.semibold))
                .foregroundStyle(MorpheTheme.textMuted)
            TextField(placeholder, text: text, axis: .vertical)
                .textFieldStyle(MorpheFieldStyle())
                .lineLimit(1...4)
        }
    }

    private func saveTargets() {
        store.updateGoalTargets(
            physical: physicalTargetDraft,
            weight: weightTargetDraft,
            deadline: deadlineTargetDraft
        )
        isEditingTargets = false
    }

    /// XP readout under the weight card. Levels climb a decade curve:
    /// 1–10 take 100 XP each, 11–20 take 200, 21–30 take 300, and so on.
    private var levelCard: some View {
        let level = store.clientProfile.level
        return GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                // The XP readout reads as ONE element; the rank row below
                // is its own button.
                VStack(alignment: .leading, spacing: 12) {
                    HStack(alignment: .lastTextBaseline) {
                        VStack(alignment: .leading, spacing: 3) {
                            Text("LEVEL")
                                .font(MorpheTheme.microLabel(10))
                                .tracking(1.4)
                                .foregroundStyle(MorpheTheme.textMuted)
                            Text("\(store.currentLevelNumber)")
                                .scaledFont(size: 34, weight: .bold, design: .monospaced)
                                .foregroundStyle(MorpheTheme.accentText)
                        }

                        Spacer()

                        VStack(alignment: .trailing, spacing: 3) {
                            Text("XP TO LEVEL \(store.currentLevelNumber + 1)")
                                .font(MorpheTheme.microLabel(10))
                                .tracking(1.4)
                                .foregroundStyle(MorpheTheme.textMuted)
                            Text("\(level.currentXP) / \(level.targetXP)")
                                .font(.system(.title3, design: .monospaced).weight(.semibold))
                                .foregroundStyle(MorpheTheme.textPrimary)
                        }
                    }

                    ProgressBarView(progress: level.progress, color: MorpheTheme.accent)

                    Text("XP comes from workouts, daily wins and quizzes.")
                        .font(.caption)
                        .foregroundStyle(MorpheTheme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Level \(store.currentLevelNumber), \(level.currentXP) of \(level.targetXP) XP to level \(store.currentLevelNumber + 1)")

                Rectangle()
                    .fill(MorpheTheme.strokeSubtle)
                    .frame(height: 1)

                rankRow
            }
        }
        .sheet(isPresented: $showingCode) {
            SpartanCodeSheet()
                .environment(store)
        }
    }

    /// The agoge rung this level stands on (Sparta's own ladder) — opens
    /// The Code, where every rung and its source is laid out.
    private var rankRow: some View {
        let rank = MorpheRank.rank(forLevel: store.currentLevelNumber)
        let nextLabel = rank.next.map { "\($0.title) at \($0.firstLevel)" }
        return Button {
            showingCode = true
        } label: {
            HStack(alignment: .center, spacing: 12) {
                // The rank's own color — metallic for the top two.
                Circle()
                    .fill(MorpheTheme.swatchStyle(for: rank.palette))
                    .frame(width: 28, height: 28)
                    .overlay(Circle().stroke(MorpheTheme.strokeSubtle, lineWidth: 1))
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 4) {
                    Text("RANK")
                        .font(MorpheTheme.microLabel())
                        .tracking(1.4)
                        .foregroundStyle(MorpheTheme.textMuted)
                    Text(rank.title)
                        .font(.headline)
                        .foregroundStyle(MorpheTheme.textPrimary)
                    Text(rank.gloss)
                        .font(.caption)
                        .foregroundStyle(MorpheTheme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                    // At accessibility sizes the next rung drops under
                    // the rank instead of fighting it for the row.
                    if dynamicTypeSize.isAccessibilitySize, let nextLabel {
                        Text(nextLabel)
                            .font(.caption)
                            .foregroundStyle(MorpheTheme.textMuted)
                    }
                }
                Spacer(minLength: 0)
                if !dynamicTypeSize.isAccessibilitySize, let nextLabel {
                    Text(nextLabel.uppercased())
                        .font(MorpheTheme.microLabel())
                        .tracking(1.4)
                        .monospacedDigit()
                        .foregroundStyle(MorpheTheme.textMuted)
                }
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(MorpheTheme.textMuted)
            }
            .frame(minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Rank: \(rank.title). \(rank.gloss) Wears \(rank.palette.rawValue).\(rank.next.map { " Next: \($0.title) at level \($0.firstLevel)." } ?? "")")
        .accessibilityHint("Opens The Code")
    }

    private var identityCard: some View {
        GlassCard(.hero) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 14) {
                    profilePhotoDisplay

                    // The whole box opens the identity page (Lucas
                    // 2026-10-10): photo, name, @username, bio, verification.
                    Button {
                        showIdentitySheet = true
                    } label: {
                        HStack(spacing: 10) {
                            VStack(alignment: .leading, spacing: 4) {
                                HStack(spacing: 6) {
                                    Text(store.profileShowcase.displayName)
                                        .font(.title2.weight(.bold))
                                        .foregroundStyle(MorpheTheme.textPrimary)
                                    if store.isVerifiedUser {
                                        // Verification blue — a universal trust signal,
                                        // deliberately outside the yellow palette.
                                        Image(systemName: "checkmark.seal.fill")
                                            .font(.subheadline)
                                            .foregroundStyle(MorpheTheme.brandBlueText)
                                            .accessibilityLabel("Verified")
                                    }
                                }
                                Text("@\(store.profileShowcase.username)")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(MorpheTheme.accentText)
                                Text("\(store.clientProfile.sportMode.rawValue)\(store.clientProfile.fitnessLevel.isEmpty ? "" : " • \(store.clientProfile.fitnessLevel)")")
                                    .font(.caption)
                                    .foregroundStyle(MorpheTheme.textMuted)
                            }
                            Spacer(minLength: 0)
                            Image(systemName: "chevron.right")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(MorpheTheme.textMuted)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(store.profileShowcase.displayName), @\(store.profileShowcase.username)")
                    .accessibilityHint("Opens your bio and verification")
                }

                if !store.profileShowcase.bio.isEmpty {
                    Text(store.profileShowcase.bio)
                        .font(.subheadline)
                        .foregroundStyle(MorpheTheme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                creatorSection
            }
        }
        // Anywhere on the box opens the page; the buttons inside (Creator
        // Studio) keep their own taps.
        .contentShape(Rectangle())
        .onTapGesture { showIdentitySheet = true }
        .sheet(isPresented: $showIdentitySheet, onDismiss: {
            // A swipe-down with a typed bio saves it — never drops it. Name
            // and username edits stay drafts (they cost a 14-day window).
            if isEditingBio, bioDraft.trimmingCharacters(in: .whitespacesAndNewlines) != store.profileCustomBio { saveBio() }
            isEditingBio = false
            isEditingName = false
            isEditingUsername = false
        }) {
            identitySheet
        }
        .onChange(of: photoPickerItem) {
            guard let item = photoPickerItem else { return }
            Task {
                if let raw = try? await item.loadTransferable(type: Data.self),
                   let jpeg = Self.processedProfilePhoto(raw) {
                    store.updateProfilePhoto(jpeg)
                }
                photoPickerItem = nil
            }
        }
    }

    private func accountStat(_ label: String, _ value: String, _ detail: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label.uppercased())
                .font(MorpheTheme.microLabel(9))
                .tracking(1.2)
                .foregroundStyle(MorpheTheme.textMuted)
            Text(value)
                .font(.title3.weight(.bold))
                .monospacedDigit()
                .foregroundStyle(MorpheTheme.textPrimary)
            Text(detail)
                .font(.caption2)
                .foregroundStyle(MorpheTheme.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: MorpheTheme.radius, style: .continuous)
                .fill(MorpheTheme.panelStrong.opacity(0.6))
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label): \(value), \(detail)")
    }

    /// Bio + verification, on their own page (Lucas 2026-10-10). Same
    /// state as the card, so the unsaved-edit guard still sees the draft.
    private var identitySheet: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(store.profileShowcase.displayName)
                            .font(.title2.weight(.bold))
                            .foregroundStyle(MorpheTheme.textPrimary)
                        Text("@\(store.profileShowcase.username)")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(MorpheTheme.accentText)
                    }
                    Spacer(minLength: 8)
                    Button("Done") {
                        if isEditingBio { saveBio() }
                        if isEditingName { saveName() }
                        if isEditingUsername { saveUsername() }
                        showIdentitySheet = false
                    }
                    .foregroundStyle(MorpheTheme.textPrimary)
                    .frame(minWidth: 44, minHeight: 44)
                }

                GlassCard {
                    VStack(alignment: .leading, spacing: 14) {
                        HStack(spacing: 14) {
                            profilePhotoView
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Photo")
                                    .font(.headline)
                                    .foregroundStyle(MorpheTheme.textPrimary)
                                Text(store.profilePhotoData == nil ? "Tap the circle to add one." : "Tap the circle to change it; hold to remove.")
                                    .font(.caption)
                                    .foregroundStyle(MorpheTheme.textMuted)
                                verificationStatusOrButton
                            }
                        }
                        Divider().overlay(MorpheTheme.strokeSubtle)
                if isEditingName {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 8) {
                            TextField("Your name", text: $nameDraft)
                                .textFieldStyle(MorpheFieldStyle())
                                .submitLabel(.done)
                                .onSubmit { saveName() }
                            Button("Save") {
                                saveName()
                            }
                            .buttonStyle(.plain)
                            .foregroundStyle(MorpheTheme.accentText)
                            .accessibilityLabel("Save name")
                            Button("Cancel") {
                                isEditingName = false
                            }
                            .buttonStyle(.plain)
                            .foregroundStyle(MorpheTheme.textMuted)
                            .accessibilityLabel("Cancel name edit")
                        }
                        // The cost is disclosed BEFORE the change burns the
                        // window, not after (launch audit).
                        Text("Names change once every 14 days — a typo locks you in, so double-check.")
                            .font(.caption)
                            .foregroundStyle(MorpheTheme.textMuted)
                    }
                } else {
                    settingsRow(
                        "Name",
                        value: store.profileShowcase.displayName
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

                        Divider().overlay(MorpheTheme.strokeSubtle)

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
                            .foregroundStyle(MorpheTheme.accentText)
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
                        value: "@\(store.profileShowcase.username)"
                    ) {
                        usernameDraft = store.profileShowcase.username
                        isEditingUsername = true
                    }
                    if let next = store.nextUsernameChangeDate {
                        Text("Usernames change once every 14 days — next change \(next.formatted(date: .abbreviated, time: .omitted)).")
                            .font(.caption)
                            .foregroundStyle(MorpheTheme.textMuted)
                    }
                }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                GlassCard {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Bio")
                            .font(.headline)
                            .foregroundStyle(MorpheTheme.textPrimary)
                        bioSection
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                GlassCard {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Verification")
                            .font(.headline)
                            .foregroundStyle(MorpheTheme.textPrimary)
                        verificationSection
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(20)
        }
        .background(PremiumBackground().ignoresSafeArea())
        // Live capture only (no library) — the selfie the Morphe team reviews
        // must come from THIS camera, not the photo roll.
        .fullScreenCover(isPresented: $showVerificationCamera) {
            VerificationSelfieCamera { image in
                showVerificationCamera = false
                guard let image,
                      let jpeg = Self.processedVerificationSelfie(image) else { return }
                Task { await store.submitVerificationRequest(selfieJPEG: jpeg, note: "") }
            }
            .ignoresSafeArea()
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(28)
        .sheetToastSurface()
    }

    /// The card's photo — display only; picking happens on the identity page.
    private var profilePhotoDisplay: some View {
        Group {
            if let data = store.profilePhotoData, let image = UIImage(data: data) {
                Image(uiImage: image).resizable().scaledToFill()
            } else {
                ZStack {
                    Circle().fill(MorpheTheme.accent.opacity(0.18))
                    Text(profileInitials)
                        .font(.title3.weight(.bold))
                        .foregroundStyle(MorpheTheme.accentText)
                }
            }
        }
        .frame(width: 72, height: 72)
        .clipShape(Circle())
        .overlay(Circle().stroke(MorpheTheme.accent.opacity(0.5), lineWidth: 1.5))
        .accessibilityHidden(true)
    }

    /// The photo circle: real photo when set, initials art otherwise. Tapping
    /// opens the system photo picker; long-press offers removal.
    private var profilePhotoView: some View {
        PhotosPicker(selection: $photoPickerItem, matching: .images) {
            ZStack(alignment: .bottomTrailing) {
                Group {
                    if let data = store.profilePhotoData, let image = UIImage(data: data) {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                    } else {
                        ZStack {
                            Circle().fill(MorpheTheme.accent.opacity(0.18))
                            Text(profileInitials)
                                .font(.title3.weight(.bold))
                                .foregroundStyle(MorpheTheme.accentText)
                        }
                    }
                }
                .frame(width: 72, height: 72)
                .clipShape(Circle())
                .overlay(Circle().stroke(MorpheTheme.accent.opacity(0.5), lineWidth: 1.5))

                Image(systemName: "camera.fill")
                    .scaledFont(size: 11, weight: .bold)
                    .foregroundStyle(MorpheTheme.onFill(MorpheTheme.accent))  // the ink follows the fill (audit 29)
                    .padding(5)
                    .background(Circle().fill(MorpheTheme.accent))
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(store.profilePhotoData == nil ? "Add profile photo" : "Change profile photo")
        .contextMenu {
            if store.profilePhotoData != nil {
                Button(role: .destructive) {
                    store.updateProfilePhoto(nil)
                } label: {
                    Label("Remove Photo", systemImage: "trash")
                }
            }
        }
    }

    private var profileInitials: String {
        let name = store.profileShowcase.displayName
        let parts = name.split(separator: " ").prefix(2)
        let initials = parts.compactMap(\.first).map(String.init).joined()
        return initials.isEmpty ? "M" : initials.uppercased()
    }

    /// Bio: shown for everyone, editable in place for athletes (a coach's
    /// Coaches get the same typed bio as athletes now — the old skip claimed
    /// their headline was "edited in the coach workspace," which had no
    /// editor anywhere (coach audit). The derived headline stays derived;
    /// this is the free-text line under it.
    @ViewBuilder
    private var bioSection: some View {
        Group {
            VStack(alignment: .leading, spacing: 8) {
                if isEditingBio {
                    TextField("Say something about your training…", text: $bioDraft, axis: .vertical)
                        .lineLimit(2...5)
                        .textFieldStyle(MorpheFieldStyle())
                    HStack(spacing: 12) {
                        Button("Save") { saveBio() }
                            .buttonStyle(.plain)
                            .foregroundStyle(MorpheTheme.accentText)
                            .accessibilityLabel("Save bio")
                        Button("Cancel") { isEditingBio = false }
                            .buttonStyle(.plain)
                            .foregroundStyle(MorpheTheme.textMuted)
                        Spacer()
                        Text("\(bioDraft.count)/220")
                            .font(.caption2)
                            .foregroundStyle(bioDraft.count > 220 ? MorpheTheme.danger : MorpheTheme.textMuted)
                    }
                } else {
                    Text(store.profileShowcase.bio)
                        .font(.subheadline)
                        .foregroundStyle(MorpheTheme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                    Button("Edit Bio") {
                        // Editing starts from the CUSTOM bio: clearing a
                        // generated one back to "" keeps the generator active.
                        bioDraft = store.profileCustomBio.isEmpty ? "" : store.profileCustomBio
                        isEditingBio = true
                    }
                    .buttonStyle(.plain)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(MorpheTheme.accentAlt)
                }
            }
        }
    }

    private func saveBio() {
        store.updateProfileBio(bioDraft)
        isEditingBio = false
    }

    /// Creator Coach (2026-10-05): the role shows here once granted; the
    /// application itself lives on the website, never in the app.
    @ViewBuilder
    private var creatorSection: some View {
        if store.isCreatorCoach {
            Divider().overlay(MorpheTheme.strokeSubtle)
            HStack(spacing: 8) {
                Image(systemName: "person.crop.rectangle.badge.plus")
                    .foregroundStyle(MorpheTheme.accentText)
                Text("Creator Coach — publishes workouts, notes and open challenges.")
                    .font(.caption)
                    .foregroundStyle(MorpheTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Button {
                showCreatorStudio = true
            } label: {
                Label("Creator Studio", systemImage: "square.and.pencil")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(PrimaryCTAButtonStyle(accent: MorpheTheme.accent))
            .sheet(isPresented: $showCreatorStudio) {
                CreatorStudioSheet()
                    .environment(store)
                    .presentationDetents([.large])
                    .presentationCornerRadius(28)
                    .sheetToastSurface()
            }
        } else if store.creatorApplicationStatus == .pending {
            Divider().overlay(MorpheTheme.strokeSubtle)
            HStack(spacing: 8) {
                Image(systemName: "hourglass")
                    .foregroundStyle(MorpheTheme.textMuted)
                Text("Creator Coach application received — a person reviews it.")
                    .font(.caption)
                    .foregroundStyle(MorpheTheme.textSecondary)
            }
        }
    }

    /// The seal lives next to the photo (Lucas 2026-10-10): the Get
    /// Verified button or the status line sits under "Tap the circle…";
    /// the Verification card below holds only the steps.
    @ViewBuilder
    private var verificationStatusOrButton: some View {
        if store.isVerifiedUser {
            HStack(spacing: 6) {
                Image(systemName: "checkmark.seal.fill")
                    .foregroundStyle(Color(red: 0.25, green: 0.56, blue: 0.96))
                Text("Verified — reviewed by the Morphe team.")
                    .font(.caption)
                    .foregroundStyle(MorpheTheme.textSecondary)
            }
        } else {
            switch store.verificationRequestStatus {
            case .pending:
                HStack(spacing: 6) {
                    Image(systemName: "hourglass")
                        .foregroundStyle(MorpheTheme.warning)
                    Text("Verification under review.")
                        .font(.caption)
                        .foregroundStyle(MorpheTheme.textSecondary)
                }
            case .none, .declined:
                VStack(alignment: .leading, spacing: 6) {
                    if store.verificationRequestStatus == .declined {
                        Text("Not approved last time — try a clearer selfie.")
                            .font(.caption)
                            .foregroundStyle(MorpheTheme.warning)
                    }
                    Button {
                        // Live capture only — without a camera the system
                        // picker silently falls back to the photo library,
                        // which would make the "live selfie" claim false.
                        if UIImagePickerController.isSourceTypeAvailable(.camera) {
                            showVerificationCamera = true
                        } else {
                            store.showToast("Verification needs a camera — try from your phone.")
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "checkmark.seal")
                            Text(store.isSubmittingVerification ? "Sending…" : "Get Verified")
                        }
                        .font(.caption.weight(.semibold))
                        .frame(minHeight: 44)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(MorpheTheme.brandBlueText)
                    .disabled(store.isSubmittingVerification)
                }
            }
        }
    }

    /// How verification actually works: the steps, honestly — a live
    /// selfie, a human review — in full, straight under the card title.
    @ViewBuilder
    private var verificationSection: some View {
        if store.isVerifiedUser {
            Text("You're verified. The blue check shows on your profile and your posts.")
                .font(.caption)
                .foregroundStyle(MorpheTheme.textSecondary)
        } else if store.verificationRequestStatus == .pending {
            Text("Your selfie is with the Morphe team. A person reviews it; the check appears once it's approved.")
                .font(.caption)
                .foregroundStyle(MorpheTheme.textSecondary)
        } else {
        VStack(alignment: .leading, spacing: 6) {
            Text("How to get verified")
                .font(.caption.weight(.semibold))
                .foregroundStyle(MorpheTheme.textPrimary)
            verificationStep(1, "Tap Get Verified next to your photo and take a live selfie in the app — the camera only, no uploads from your library.")
            verificationStep(2, "Face clear and well lit, no sunglasses or mask. The photo is used only to confirm you are a real person and is seen only by the Morphe team.")
            verificationStep(3, "A human reviews it. Your profile shows \u{201C}under review\u{201D} until then.")
            verificationStep(4, "Approved: the blue check appears on your profile and your posts. Declined: take a clearer selfie and try again.")
        }
        }
    }

    private func verificationStep(_ n: Int, _ text: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text("\(n)")
                .font(.caption2.weight(.bold))
                .monospacedDigit()
                .foregroundStyle(Color(red: 0.25, green: 0.56, blue: 0.96))
                .frame(width: 14, alignment: .trailing)
            Text(text)
                .font(.caption)
                .foregroundStyle(MorpheTheme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    /// Review selfie: 640px max, mild compression — the reviewer needs to see
    /// a face clearly; the doc still stays far under Firestore's 1MB cap.
    private static func processedVerificationSelfie(_ image: UIImage) -> Data? {
        let maxSide: CGFloat = 640
        let scale = min(1, maxSide / max(image.size.width, image.size.height))
        let size = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let renderer = UIGraphicsImageRenderer(size: size)
        let resized = renderer.image { _ in image.draw(in: CGRect(origin: .zero, size: size)) }
        return resized.jpegData(compressionQuality: 0.7)
    }

    /// Downscales to 512px max and compresses — a profile photo that rides in
    /// the cloud snapshot must stay far under Firestore's document limit.
    /// Shared with the tour (RootView) — one photo pipeline.
    static func processedProfilePhoto(_ raw: Data) -> Data? {
        guard let image = UIImage(data: raw) else { return nil }
        let maxSide: CGFloat = 512
        let scale = min(1, maxSide / max(image.size.width, image.size.height))
        let size = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let renderer = UIGraphicsImageRenderer(size: size)
        let resized = renderer.image { _ in image.draw(in: CGRect(origin: .zero, size: size)) }
        return resized.jpegData(compressionQuality: 0.75)
    }

    private func preferenceToggleRow(title: String, caption: String, glimmer: Bool = false, isOn: Binding<Bool>) -> some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                if glimmer {
                    Text(title)
                        .foregroundStyle(MorpheTheme.textPrimary)
                        .featureGlimmer()
                } else {
                    Text(title)
                        .foregroundStyle(MorpheTheme.textPrimary)
                }
                Text(caption)
                    .font(.caption)
                    .foregroundStyle(MorpheTheme.textMuted)
            }
            Spacer(minLength: 0)
            Toggle(title, isOn: isOn)
                .labelsHidden()
                .tint(MorpheTheme.accent)
        }
    }

    // MARK: - Settings and activity (Instagram-style grouping, Lucas 2026-08-26)
    //
    // The old single "Settings" card held ~20 concerns in one scroll. Now:
    // a search field, then small-caps grouped sections — same rows, same
    // logic, organized the way people already know from Instagram.

    private var settingsSearchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.subheadline)
                .foregroundStyle(MorpheTheme.textMuted)
            TextField("Search settings", text: $settingsQuery)
                .foregroundStyle(MorpheTheme.textPrimary)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
            if !settingsQuery.isEmpty {
                Button {
                    settingsQuery = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.subheadline)
                        .foregroundStyle(MorpheTheme.textMuted)
                        .frame(width: 32, height: 32)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Clear settings search")
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .background(
            RoundedRectangle(cornerRadius: MorpheTheme.radius, style: .continuous)
                .fill(MorpheTheme.panelStrong)
                .overlay(
                    RoundedRectangle(cornerRadius: MorpheTheme.radius, style: .continuous)
                        .stroke(MorpheTheme.stroke, lineWidth: 1)
                )
        )
    }

    /// Token-AND matching (audit 15, P2): every word of the query must
    /// appear somewhere in "title + keywords", so "dark mode" and "delete
    /// my account" match the way a person expects.
    private func settingsSectionMatches(title: String, keywords: String) -> Bool {
        let tokens = settingsQuery.split(separator: " ").map(String.init)
        guard !tokens.isEmpty else { return true }
        let haystack = "\(title) \(keywords)"
        return tokens.allSatisfy { haystack.localizedCaseInsensitiveContains($0) }
    }

    /// True when the current query hides every section — drives the
    /// honest empty state (audit 15, P2: a miss left a lone search field).
    private var settingsSearchIsDry: Bool {
        let sections: [(String, String)] = [
            ("Make it yours", Self.makeItYoursKeywords),
            ("What Morphe has learned", "personalization learned patterns ai adapt"),
            ("Your account", "name username handle referrals invite share"),
            ("How you train", Self.howYouTrainKeywords),
            ("Voice", "hey morphe voice speech microphone hands free wake"),
            ("Morphe Intelligence", "claude ai brain api key anthropic intelligence smart answers neural voice elevenlabs speech audio online free improve feedback"),
            ("Notifications", "reminders nudge streak recap board updates"),
            ("Who can see you", Self.whoCanSeeYouKeywords),
            ("Health", "apple health activity rings sleep sync workouts prefill check-in"),
            ("Connections", Self.connectionsKeywords),
            ("Your app", "theme accent color"),
            ("Your data", "export json download backup cloud morphe pro subscription plans"),
            ("More info and support", "about terms privacy policy contact support email version"),
            ("Login", "sign out log out delete account remove")
        ]
        return !sections.contains { settingsSectionMatches(title: $0.0, keywords: $0.1) }
    }

    /// Shared keyword strings (audit 15, P2: "auto" couldn't find "Auto
    /// rest timer"; the feed-identity rows were unfindable by their names).
    private static let makeItYoursKeywords =
        "personalization character persona sound effects pack customize voice accent communication style delivery hey morphe speech microphone hands free wake headphones airpods"
    private static let connectionsKeywords =
        "connections devices bluetooth heart rate monitor strap polar garmin wahoo apple health watch supplements stack vitamins creatine protein enhancements strava whoop oura apps"
    private static let howYouTrainKeywords =
        "training days week injuries limits auto rest timer effort rpe rir weight unit kg lb pounds kilograms"
    private static let whoCanSeeYouKeywords =
        "weekly board leaderboard privacy private public account visibility feed posts streak byline accent share blocked accounts unblock"

    /// Collapsed by default (Lucas 2026-10-06: "text heavy and
    /// unorganized"): each section is one row — icon, title, a short line
    /// of what's inside — and opens on tap. One open at a time. A search
    /// opens every matching section so the answer is on screen.
    @State private var openSection: String?

    private static let sectionMeta: [String: (icon: String, summary: String)] = [
        "Make it yours": ("paintbrush", "Sounds, character, voice, tour"),
        "What Morphe has learned": ("brain.head.profile", "What it knows about how you train"),
        "Your account": ("person.crop.circle", "Name, username, invites"),
        "How you train": ("figure.strengthtraining.traditional", "Days, limits, rest timer, units"),
        "Voice": ("waveform", "Hey Morphe, hands-free"),
        "Morphe Intelligence": ("sparkles", "Morphe AI online, your own key, neural voice"),
        "Notifications": ("bell", "Reminders"),
        "Who can see you": ("eye", FeatureFlags.socialFeedEnabled ? "Boards, feed, blocked accounts" : "Boards, blocked accounts"),
        "Health": ("heart", "Apple Health"),
        "Connections": ("antenna.radiowaves.left.and.right", "Heart-rate monitor, Health, Watch, supplements"),
        "Your app": ("paintpalette", "Accent color"),
        "Your data": ("externaldrive", PremiumGate.storefrontEnabled ? "Export, import, backup, Pro" : "Export, import, backup"),
        "More info and support": ("questionmark.circle", "About, privacy, contact"),
        "Login": ("rectangle.portrait.and.arrow.right", "Sign out, delete account")
    ]

    /// One grouped section, hidden when the search query matches neither
    /// its title nor its keywords.
    @ViewBuilder
    private func settingsSection<Content: View>(
        _ title: String, keywords: String, emphasis: CardEmphasis = .standard,
        @ViewBuilder content: () -> Content
    ) -> some View {
        if settingsSectionMatches(title: title, keywords: keywords) {
            let searching = !settingsQuery.trimmingCharacters(in: .whitespaces).isEmpty
            let open = searching || openSection == title
            let meta = Self.sectionMeta[title]
            GlassCard(emphasis) {
                VStack(alignment: .leading, spacing: 14) {
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            openSection = open ? nil : title
                        }
                        Haptics.selection()
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: meta?.icon ?? "circle")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(MorpheTheme.accentText)
                                .frame(width: 26)
                                .accessibilityHidden(true)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(title)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(MorpheTheme.textPrimary)
                                if !open, let summary = meta?.summary {
                                    Text(summary)
                                        .font(.caption)
                                        .foregroundStyle(MorpheTheme.textMuted)
                                        .lineLimit(1)
                                }
                            }
                            Spacer(minLength: 8)
                            Image(systemName: "chevron.right")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(MorpheTheme.textMuted)
                                .rotationEffect(.degrees(open ? 90 : 0))
                                .accessibilityHidden(true)
                        }
                        .frame(minHeight: 32)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .disabled(searching)
                    .accessibilityLabel(title)
                    .accessibilityValue(open ? "Open" : "Closed")
                    .accessibilityHint(open ? "Collapses the section" : "Opens the section")

                    if open {
                        content()
                    }
                }
            }
        }
    }

    /// A thin label between groups of sections. Hidden while searching —
    /// the matches speak for themselves.
    @ViewBuilder
    private func settingsGroupLabel(_ title: String) -> some View {
        if settingsQuery.trimmingCharacters(in: .whitespaces).isEmpty {
            Text(title.uppercased())
                .font(MorpheTheme.microLabel(10))
                .tracking(1.6)
                .foregroundStyle(MorpheTheme.textMuted)
                .padding(.top, 8)
        }
    }

    @ViewBuilder
    private func styleChip(title: String, detail: String, selected: Bool,
                           accessibility: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 3) {
                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(selected ? MorpheTheme.onFill(MorpheTheme.accent) : MorpheTheme.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                Text(detail)
                    .font(.caption2)
                    .foregroundStyle(selected ? MorpheTheme.onFill(MorpheTheme.accent).opacity(0.9) : MorpheTheme.textMuted)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .padding(.horizontal, 2)
            .background(
                RoundedRectangle(cornerRadius: MorpheTheme.chipRadius, style: .continuous)
                    .fill(selected ? MorpheTheme.accent : MorpheTheme.panelStrong)
            )
            .overlay(
                RoundedRectangle(cornerRadius: MorpheTheme.chipRadius, style: .continuous)
                    .stroke(selected ? MorpheTheme.stroke : MorpheTheme.strokeSubtle, lineWidth: 1)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibility)
        .accessibilityAddTraits(selected ? [.isSelected] : [])
    }

    @ViewBuilder
    private func soundPackChoice(_ pack: SoundPack) -> some View {
        let selected = (SoundPack(rawValue: store.styleProfile.soundPack) ?? .classic) == pack
        Button {
            store.setStyleChoice(soundPack: pack.rawValue)
            // Instant preview in the new voice — the choice is audible.
            SoundEffects.play(.ding)
            Haptics.selection()
        } label: {
            VStack(spacing: 3) {
                Text(pack.title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(selected ? MorpheTheme.onFill(MorpheTheme.accent) : MorpheTheme.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                Text(pack.detail)
                    .font(.caption2)
                    .foregroundStyle(selected ? MorpheTheme.onFill(MorpheTheme.accent).opacity(0.9) : MorpheTheme.textMuted)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: MorpheTheme.chipRadius, style: .continuous)
                    .fill(selected ? MorpheTheme.accent : MorpheTheme.panelStrong)
            )
            .overlay(
                RoundedRectangle(cornerRadius: MorpheTheme.chipRadius, style: .continuous)
                    .stroke(selected ? MorpheTheme.stroke : MorpheTheme.strokeSubtle, lineWidth: 1)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(pack.title) sound voice — \(pack.detail)")
        .accessibilityAddTraits(selected ? [.isSelected] : [])
    }

    @ViewBuilder
    private func learnedRow(_ symbol: String, _ text: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: symbol)
                .font(.caption.weight(.semibold))
                .foregroundStyle(MorpheTheme.accentText)
                .frame(width: 18)
            Text(text)
                .font(.subheadline)
                .foregroundStyle(MorpheTheme.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var settingsSections: some View {
        @Bindable var store = store
        return VStack(alignment: .leading, spacing: 16) {
            settingsSearchField


            if settingsSearchIsDry {
                Text("No settings match \u{201C}\(settingsQuery)\u{201D} — try another word, like \u{201C}reminders\u{201D} or \u{201C}backup\u{201D}.")
                    .font(.caption)
                    .foregroundStyle(MorpheTheme.textMuted)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 8)
            }

            settingsGroupLabel("Profile")

            // Your account leads the Profile group (Lucas 2026-10-10).
            settingsSection("Your account", keywords: "account connections workouts referrals invite share joined details age weight goal diet equipment weakness milestones targets") {
                // Your account at a glance (Lucas 2026-10-10): the numbers,
                // not the editors — name, @username, photo, bio and
                // verification live on the identity page (tap the box above).
                let joined = store.authUser?.createdAt
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                    accountStat("Connections", "\(store.connectedUids.count)", "people you're connected with")
                    accountStat("Workouts", "\(store.currentAthleteWorkoutSummary.totalLogs)", "sessions logged")
                    accountStat("Referrals", "\(store.referralCount)", "joined through you")
                    accountStat("Joined", joined.map { $0.formatted(.dateTime.month(.abbreviated).day().year()) } ?? "—", "member since")
                }
                // Referral loop, recruiter side: the server-backed count of
                // athletes who joined through this user's invite. The empty
                // state names its unlock, per the house rule.
                VStack(alignment: .leading, spacing: 8) {
                    Text("Referrals")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(MorpheTheme.textMuted)
                    HStack(alignment: .center, spacing: 12) {
                        Text(store.referralCount > 0
                            ? "\(store.referralCount) athlete\(store.referralCount == 1 ? "" : "s") joined through you."
                            : "Nobody has joined through you yet — share your invite to change that.")
                            .font(.subheadline)
                            .foregroundStyle(store.referralCount > 0 ? MorpheTheme.textPrimary : MorpheTheme.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                        Spacer(minLength: 0)
                        ShareLink(item: store.networkInviteMessage) {
                            Text("Share Invite")
                        }
                        .buttonStyle(SecondaryCTAButtonStyle())
                        .frame(width: 118)
                    }
                    Text(store.referralCount >= 1
                        ? "Recruiter accent unlocked."
                        : "The first join unlocks the Recruiter accent.")
                        .font(.caption)
                        .foregroundStyle(MorpheTheme.textMuted)
                }

                Divider().overlay(MorpheTheme.strokeSubtle)

                // Your Details + Your Milestones, one box (Lucas 2026-10-10).
                detailsCard
            }

            // Identity customization (personalization phase 2): pick
            // Morphe's persona and the app's sound voice. Writes go through
            // setStyleChoice so recomputes never clobber them.
            settingsSection("Make it yours", keywords: Self.makeItYoursKeywords) {
                VStack(alignment: .leading, spacing: 14) {
                    Text("Sound voice")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(MorpheTheme.textPrimary)
                    HStack(spacing: 10) {
                        ForEach(SoundPack.allCases) { pack in
                            soundPackChoice(pack)
                        }
                    }
                    Text("Same cues, different voice — the PR sound still means a PR.")
                        .font(.caption)
                        .foregroundStyle(MorpheTheme.textMuted)

                    Divider().overlay(MorpheTheme.strokeSubtle)

                    Text("Morphe's voice")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(MorpheTheme.textPrimary)
                    HStack(spacing: 10) {
                        ForEach(MorpheVoiceOption.all) { option in
                            styleChip(
                                title: option.title, detail: option.detail,
                                selected: MorpheVoiceOption.spec(for: store.styleProfile.voiceStyle).id == option.id,
                                accessibility: "\(option.title) voice — \(option.detail)"
                            ) {
                                store.setStyleChoice(voiceStyle: option.id)
                                Haptics.selection()
                            }
                        }
                    }
                    Text("The accent Morphe answers in — applies from the next spoken reply.")
                        .font(.caption)
                        .foregroundStyle(MorpheTheme.textMuted)

                    Divider().overlay(MorpheTheme.strokeSubtle)

                    Text("Communication style")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(MorpheTheme.textPrimary)
                    HStack(spacing: 10) {
                        ForEach(MorpheCommunicationStyle.all) { style in
                            styleChip(
                                title: style.title, detail: style.detail,
                                selected: MorpheCommunicationStyle.spec(for: store.styleProfile.communicationStyle).id == style.id,
                                accessibility: "\(style.title) style — \(style.detail)"
                            ) {
                                store.setStyleChoice(communicationStyle: style.id)
                                Haptics.selection()
                            }
                        }
                    }
                    Text("How Morphe talks in chat and voice — delivery changes, the numbers never do.")
                        .font(.caption)
                        .foregroundStyle(MorpheTheme.textMuted)

                    Divider().overlay(MorpheTheme.strokeSubtle)

                    // Hey Morphe lives here now (Lucas 2026-10-10): the
                    // voice is part of making it yours, not a training setting.
                    preferenceToggleRow(
                        title: "\u{201C}Hey Morphe\u{201D}",
                        caption: "Hands-free: say \u{201C}Hey Morphe\u{201D} to navigate or ask anything, and Morphe answers out loud \u{2014} in the app and in the background while Morphe is running (iOS shows the microphone indicator the whole time). Speech stays on this iPhone. It listens over your music too; music pauses only while Morphe is taking a request and comes back when it's done. Tap anywhere to end an exchange. Listening uses extra battery.",
                        glimmer: true,
                        isOn: Binding(
                            get: { store.heyMorpheEnabled },
                            set: { store.setHeyMorphe(enabled: $0) }
                        )
                    )
                    if store.heyMorpheEnabled {
                        Divider().overlay(MorpheTheme.strokeSubtle)
                        preferenceToggleRow(
                            title: "Listen through headphones",
                            caption: "With AirPods or a Bluetooth headset connected, Morphe hears you through their microphone when nothing else is playing. While music or other audio plays, it listens through the phone instead, so your music keeps its full quality.",
                            isOn: Binding(
                                get: { store.heyMorpheHeadsetMic },
                                set: { store.setHeyMorpheHeadsetMic($0) }
                            )
                        )
                    }
                }
            }

            // The learning loop, visible (personalization spine 2026-09):
            // Morphe says exactly what it has derived from real logs — and
            // says "still learning" instead of inventing patterns.
            // Your app (the accent picker) sits under Make it yours (Lucas 2026-10-10).
            settingsSection("Your app", keywords: "theme accent color") {
                // Accent color — picked once in onboarding, now editable
                // anytime. Gold is the brand default; the others personalize
                // the whole app's accent pair.
                VStack(alignment: .leading, spacing: 8) {
                    Text("Accent")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(MorpheTheme.textMuted)
                    // Wrapped: nine 44pt targets don't fit one row on a
                    // 393pt device — crushed dots overlapped their rings.
                    WrapStack(spacing: 8) {
                        ForEach(AccentPalette.allCases.filter { $0 != .custom }) { palette in
                            accentDot(for: palette)
                        }
                    }
                    // Locks were mute until tapped (UX test 2026-09-30):
                    // a first-timer saw five padlocks with no path.
                    Text("Every rank brings its own color, Rookie\u{2019}s dark blue through Colonel\u{2019}s platinum to General\u{2019}s gold \u{2014} tap a locked one to see its rank. Burgundy is for recruiters; Champion comes with your first finished challenge.")
                        .font(.caption2)
                        .foregroundStyle(MorpheTheme.textMuted)
                }

            }

            settingsSection("What Morphe has learned", keywords: "personalization learned patterns ai adapt") {
                if store.styleProfile.hasLearnedAnything {
                    VStack(alignment: .leading, spacing: 8) {
                        if let intensity = store.styleProfile.preferredIntensity {
                            learnedRow("gauge.with.needle", "You usually rate sessions \u{201C}\((WorkoutIntensity(rawValue: intensity)?.label ?? intensity).lowercased())\u{201D}")
                        }
                        if let rating = store.styleProfile.averageRating {
                            learnedRow("star.fill", "Average session rating \(rating.formatted(.number.precision(.fractionLength(1))))/10")
                        }
                        if !store.styleProfile.favoriteExercises.isEmpty {
                            learnedRow("dumbbell.fill", "Most-trained: \(store.styleProfile.favoriteExercises.prefix(3).joined(separator: ", "))")
                        }
                        if let hour = store.styleProfile.preferredTrainingHour {
                            learnedRow("clock.fill", "You usually train around \(MorpheAppStore.formattedHour(hour))")
                        }
                        if let cadence = store.styleProfile.weeklyCadence, cadence > 0 {
                            learnedRow("calendar", "About \(cadence.formatted(.number.precision(.fractionLength(1)))) sessions a week lately")
                        }
                        Text("Derived from your real logs and debriefs — it sharpens Morphe's answers and suggestions. Nothing here is invented.")
                            .font(.caption)
                            .foregroundStyle(MorpheTheme.textMuted)
                            .padding(.top, 2)
                    }
                } else {
                    Text("Still learning you. Log a few sessions and answer the post-workout debriefs — patterns show up here as they become real.")
                        .font(.caption)
                        .foregroundStyle(MorpheTheme.textMuted)
                }
            }

            settingsGroupLabel("Training")

            settingsSection("How you train", keywords: Self.howYouTrainKeywords) {
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

                // WHICH days (rest-day model): pick them and Today shows
                // an honest rest card on off days + the daily reminder
                // skips them. None picked = every day is a training day.
                VStack(alignment: .leading, spacing: 8) {
                    Text("Training days")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(MorpheTheme.textMuted)
                    HStack(spacing: 6) {
                        ForEach(Array(zip(1...7, ["S", "M", "T", "W", "T", "F", "S"])), id: \.0) { weekday, label in
                            Button(label) {
                                if store.trainingDays.contains(weekday) {
                                    store.trainingDays.remove(weekday)
                                } else {
                                    store.trainingDays.insert(weekday)
                                }
                            }
                            .buttonStyle(FilterChipStyle(isSelected: store.trainingDays.contains(weekday), selectedColor: MorpheTheme.accent))
                            .accessibilityLabel("\(Calendar.current.weekdaySymbols[weekday - 1])\(store.trainingDays.contains(weekday) ? ", training day" : "")")
                        }
                    }
                    Text(store.trainingDays.isEmpty
                        ? "No days picked — every day shows your workout."
                        : "Off days show a rest card and skip the reminder.")
                        .font(.caption2)
                        .foregroundStyle(MorpheTheme.textMuted)
                }


                Divider().overlay(MorpheTheme.strokeSubtle)

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
                            .foregroundStyle(MorpheTheme.accentText)
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


                Divider().overlay(MorpheTheme.strokeSubtle)

                // Live-session preferences for BOTH roles (audit 6, P1-4):
                // coaches train in the same console, so the rest timer and
                // effort scale can't be athlete-only.
                preferenceToggleRow(
                    title: "Auto rest timer",
                    caption: "Starts the rest countdown each time you log a set, using the exercise's own rest length.",
                    isOn: $store.autoRestTimerEnabled
                )


                Divider().overlay(MorpheTheme.strokeSubtle)

                preferenceToggleRow(
                    title: "Effort scale: RIR",
                    caption: "Show effort as reps in reserve instead of RPE. Your history stays the same — only the display flips.",
                    isOn: $store.effortScaleRIR
                )


                Divider().overlay(MorpheTheme.strokeSubtle)

                HStack {
                    Text("Weight unit")
                        .foregroundStyle(MorpheTheme.textPrimary)
                    Spacer()
                    Picker("Weight unit", selection: $store.weightUnit) {
                        ForEach(WeightUnit.allCases) { unit in
                            Text(unit.label).tag(unit)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 110)
                }

            }

            settingsSection("Connections", keywords: Self.connectionsKeywords) {
                ConnectionsSettings()
            }

            settingsSection("Morphe Intelligence", keywords: "claude ai brain api key anthropic intelligence smart answers neural voice elevenlabs speech audio online free improve feedback") {
                    OnlineAISettings()
                    Divider().overlay(MorpheTheme.strokeSubtle)
                    IntelligenceKeyEditor()
                    Divider().overlay(MorpheTheme.strokeSubtle)
                    NeuralVoiceKeyEditor()
            }

            settingsSection("Notifications", keywords: "reminders nudge streak recap board updates") {
                    // The audit found five reminder kinds and no off switch.
                    // One master toggle — off cancels everything pending.
                    preferenceToggleRow(
                        title: "Reminders",
                        caption: "Scheduled workouts at 5pm, appointments an hour before and at the start, a heads-up the evening a streak is about to end, the weekly recap, a Spartan saying each Wednesday morning, and board updates. Off silences all of them.",
                        isOn: $store.remindersEnabled
                    )

            }

            settingsGroupLabel("Privacy, data and support")

            settingsSection("Who can see you", keywords: Self.whoCanSeeYouKeywords) {
                    // Private / public (Lucas 2026-10-10). Nothing is deleted
                    // or recomputed — logs, boards, ranks and placings stay;
                    // the switch only changes who can see them.
                    preferenceToggleRow(
                        // Fixed title so VoiceOver reads "Private account,
                        // on/off" — a state-flipping title read backwards.
                        title: "Private account",
                        caption: store.isPrivateAccount
                            ? "On. In Morphe, your posts show only to your connections, and only connections can start a chat with you. On boards and challenges you keep your place and score as \u{201C}Private athlete\u{201D} \u{2014} your name isn't sent. Quick Add and search leave you out. Comments you leave on public posts stay visible."
                            : "Off. Members can find you in Quick Add and search, see your posts and see your name on boards. Turn it on any time \u{2014} your data and placings stay exactly as they are.",
                        isOn: Binding(
                            get: { store.isPrivateAccount },
                            set: { store.setPrivateAccount($0) }
                        )
                    )

                    Divider().overlay(MorpheTheme.strokeSubtle)

                    // The board publishes your real name — and scores post on
                    // every log in EITHER role, so the off-switch renders for
                    // both (audit 5, P1-4: a coach could never leave).
                    // Boards are groups with codes now (2026-10-10): join and
                    // leave them in Network → Board; nothing posts anywhere
                    // without a code you entered.
                    Text("Boards: your logged sets post only to boards you joined with a code (Network → Board). Leave a board there to stop.")
                        .font(.caption)
                        .foregroundStyle(MorpheTheme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)


                // Athlete-only network identity, dark with the feed. The
                // block carries its own LEADING divider so an empty block
                // can't leave doubles behind (audit 6, P2-5/P2-6).
                if FeatureFlags.socialFeedEnabled {
                    Divider().overlay(MorpheTheme.strokeSubtle)

                    preferenceToggleRow(
                        title: "Auto-share workouts",
                        caption: "Posts a real recap to the feed when you log a session. Each session shows a toggle to keep it private.",
                        isOn: $store.autoShareWorkoutsEnabled
                    )

                    Divider().overlay(MorpheTheme.strokeSubtle)

                    // Network identity: what rides YOUR posts. Subtractive
                    // only — off shares less, never invents more.
                    preferenceToggleRow(
                        title: "Streak in byline",
                        caption: "New posts carry \"\(store.clientProfile.sportMode.rawValue) · N-day streak\" under your name. Off keeps just the sport.",
                        isOn: $store.postStreakByline
                    )

                    Divider().overlay(MorpheTheme.strokeSubtle)

                    preferenceToggleRow(
                        title: "Accent on posts",
                        caption: "Your accent color tints your name and story bubble for others. Off posts in the default Spartan blue.",
                        isOn: $store.postAccentIdentity
                    )
                }


                    // Blocked accounts — only renders when there's someone
                    // to manage; blocking happens from posts/comments.
                    if !store.blockedAccounts.isEmpty {
                        Divider().overlay(MorpheTheme.strokeSubtle)

                        VStack(alignment: .leading, spacing: 8) {
                            Text("Blocked accounts")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(MorpheTheme.textMuted)
                            ForEach(store.blockedAccounts.sorted(by: { $0.value < $1.value }), id: \.key) { uid, name in
                                HStack(spacing: 10) {
                                    Text(name)
                                        .font(.subheadline)
                                        .foregroundStyle(MorpheTheme.textPrimary)
                                        .lineLimit(1)
                                    Spacer(minLength: 0)
                                    Button("Unblock") {
                                        store.unblockAccount(uid: uid)
                                    }
                                    .buttonStyle(FilterChipStyle(isSelected: false))
                                    .accessibilityLabel("Unblock \(name)")
                                }
                            }
                        }
                    }

            }


            settingsSection("Health", keywords: "apple health activity rings sleep sync workouts prefill check-in") {
                    // Enabling walks through the system Health prompt; the
                    // store refuses the flip when access isn't granted.
                    preferenceToggleRow(
                        title: "Sync to Health",
                        caption: "Saves each logged workout to Apple Health so it counts toward your Activity rings.",
                        isOn: Binding(
                            get: { store.healthSyncEnabled },
                            set: { newValue in Task { await store.setHealthSync(enabled: newValue) } }
                        )
                    )

                    // Athlete-only; moved here from "Who can see you"
                    // (audit 15, P1: it's a Health feature and the search
                    // has to find it under "sleep"/"health").
                    // Read-only and honest about its limits: Apple never
                    // reveals whether a sleep READ was granted, so this just
                    // pre-fills when data comes back and stays quiet when not.
                    Divider().overlay(MorpheTheme.strokeSubtle)

                    preferenceToggleRow(
                        title: "Sleep from Health",
                        caption: "Pre-fills the check-in's sleep slider from last night's Apple Health sleep. You can always adjust it.",
                        isOn: Binding(
                            get: { store.healthSleepEnabled },
                            set: { newValue in Task { await store.setHealthSleepPrefill(enabled: newValue) } }
                        )
                    )
            }

            // Light and dark follow the iPhone's own setting (Lucas
            // 2026-10-06) — no appearance switch here.
            settingsSection("Your data", keywords: "export json download backup cloud morphe pro subscription plans") {
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Your data")
                                .foregroundStyle(MorpheTheme.textPrimary)
                            Text("One JSON file: every logged workout, set by set, plus your weight history.")
                                .font(.caption)
                                .foregroundStyle(MorpheTheme.textMuted)
                        }
                        Spacer(minLength: 0)
                        Button("Export Data") {
                            if let url = store.exportDataFile() {
                                exportFile = ExportFile(url: url)
                            } else {
                                store.showToast("Couldn't build the export — try again.")
                            }
                        }
                        .buttonStyle(SecondaryCTAButtonStyle())
                        .frame(width: 120)
                        .accessibilityLabel("Export your data as JSON")
                    }

                    Divider().overlay(MorpheTheme.strokeSubtle)

                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Bring your history")
                                .foregroundStyle(MorpheTheme.textPrimary)
                            Text("Import the workout CSV that Hevy or Strong exports. You see what will be added before anything is saved.")
                                .font(.caption)
                                .foregroundStyle(MorpheTheme.textMuted)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        Spacer(minLength: 0)
                        Button(importReading ? "Reading…" : "Import") { showImportPicker = true }
                            .disabled(importReading)
                            .buttonStyle(SecondaryCTAButtonStyle())
                            .frame(width: 120)
                            .accessibilityLabel("Import workout history from a CSV file")
                    }
                    .fileImporter(isPresented: $showImportPicker,
                                  allowedContentTypes: [.commaSeparatedText, .plainText]) { result in
                        guard case .success(let url) = result else { return }
                        importReading = true
                        // Read and parse off the main thread — a long
                        // history is tens of thousands of rows (audit 32).
                        Task {
                            let parsed = await Task.detached(priority: .userInitiated) { () -> WorkoutImport.Parsed? in
                                let scoped = url.startAccessingSecurityScopedResource()
                                defer { if scoped { url.stopAccessingSecurityScopedResource() } }
                                guard let data = try? Data(contentsOf: url), data.count <= 20_000_000,
                                      let text = String(data: data, encoding: .utf8)
                                        ?? String(data: data, encoding: .isoLatin1) else { return nil }
                                return WorkoutImport.parse(text)
                            }.value
                            importReading = false
                            guard let parsed else {
                                store.showToast("That file doesn't read as a Hevy or Strong workout export.")
                                return
                            }
                            importPlan = store.planImport(parsed)
                        }
                    }
                    .sheet(item: $importPlan) { plan in
                        ImportReviewSheet(plan: plan)
                            .environment(store)
                            .presentationDetents([.medium, .large])
                            .presentationCornerRadius(28)
                    }


                    // Backup health — failures used to be invisible (the
                    // upload was fire-and-forget). Only rendered when a real
                    // signed-in backup target exists.
                    if store.cloudBackupActive {
                        Divider().overlay(MorpheTheme.strokeSubtle)

                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 3) {
                                switch store.logBackupState {
                                case .idle:
                                    Text("Cloud backup")
                                        .foregroundStyle(MorpheTheme.textPrimary)
                                    Text("Your history uploads after each change.")
                                        .font(.caption)
                                        .foregroundStyle(MorpheTheme.textMuted)
                                case .current(let at):
                                    Text("Cloud backup ✓")
                                        .foregroundStyle(MorpheTheme.textPrimary)
                                    Text("History backed up \(at.formatted(.relative(presentation: .named))).")
                                        .font(.caption)
                                        .foregroundStyle(MorpheTheme.textMuted)
                                case .behind:
                                    Text("Backup behind")
                                        .foregroundStyle(MorpheTheme.warning)
                                    Text("The last upload didn't land — retrying. Your data is safe on this phone.")
                                        .font(.caption)
                                        .foregroundStyle(MorpheTheme.textMuted)
                                }
                                if store.logBackupNearLimit {
                                    Text("Heads up: your history is approaching the backup size limit.")
                                        .font(.caption)
                                        .foregroundStyle(MorpheTheme.warning)
                                }
                            }
                            Spacer(minLength: 0)
                            if store.logBackupState == .behind {
                                Button("Back Up Now") {
                                    store.requestImmediateLogBackup()
                                }
                                .buttonStyle(SecondaryCTAButtonStyle())
                                .frame(width: 120)
                                .accessibilityLabel("Retry the cloud backup now")
                            }
                        }
                    }


                    // Morphe Pro — DORMANT until App Store Connect products
                    // exist; while the storefront flag is off nothing here
                    // renders and everything stays free.
                    if PremiumGate.storefrontEnabled {
                        Divider().overlay(MorpheTheme.strokeSubtle)
                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 3) {
                                Text("Morphe Pro")
                                    .foregroundStyle(MorpheTheme.textPrimary)
                                Text("Programs, advanced analytics, and more. Your data stays free forever.")
                                    .font(.caption)
                                    .foregroundStyle(MorpheTheme.textMuted)
                            }
                            Spacer(minLength: 0)
                            Button("View Plans") {
                                showPaywall = true
                            }
                            .buttonStyle(SecondaryCTAButtonStyle())
                            .frame(width: 110)
                            .accessibilityLabel("View Morphe Pro plans")
                        }
                    }

            }

            settingsSection("More info and support", keywords: "about terms privacy policy contact support email version", emphasis: .quiet) {
                // About: the terms the user agreed to, the privacy policy,
                // a human to email, and which build they're on — table
                // stakes the audit found missing entirely.
                VStack(alignment: .leading, spacing: 10) {
                    Button("Terms of Use") { showTermsSheet = true }
                        .buttonStyle(.plain)
                        .foregroundStyle(MorpheTheme.accentText)
                        .frame(minHeight: 32)
                        .sheet(isPresented: $showTermsSheet) {
                            TermsGateView(readOnly: true)
                        }

                    Link("Privacy Policy", destination: URL(string: "https://lucasdilley07-png.github.io/Morphe/privacy.html")!)
                        .foregroundStyle(MorpheTheme.accentText)
                        .frame(minHeight: 32)

                    Link("Contact Support", destination: URL(string: "mailto:lucasdilley.07@gmail.com")!)
                        .foregroundStyle(MorpheTheme.accentText)
                        .frame(minHeight: 32)

                    Text("Morphe \(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0") (\(Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"))")
                        .font(.caption)
                        .foregroundStyle(MorpheTheme.textMuted)
                }

            }

            if FeatureFlags.accountsEnabled {
                settingsSection("Login", keywords: "sign out log out delete account remove", emphasis: .quiet) {
                    Button("Sign Out") {
                        showSignOutConfirm = true
                    }
                    .buttonStyle(SecondaryCTAButtonStyle())
                    .confirmationDialog("Are you sure you want to sign out?", isPresented: $showSignOutConfirm, titleVisibility: .visible) {
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

                    // App Store 5.1.1(v): account deletion lives IN the app.
                    Button(isDeletingAccount ? "Deleting…" : "Delete Account") {
                        showDeleteAccountConfirm = true
                    }
                    .buttonStyle(SecondaryCTAButtonStyle())
                    .foregroundStyle(MorpheTheme.danger)
                    .disabled(isDeletingAccount)
                    .accessibilityLabel("Permanently delete your account")
                    .confirmationDialog("Delete your account forever?", isPresented: $showDeleteAccountConfirm, titleVisibility: .visible) {
                        Button("Delete Forever", role: .destructive) {
                            isDeletingAccount = true
                            Task {
                                defer { isDeletingAccount = false }
                                if await store.deleteAccount() {
                                    store.closeClientProfile()
                                }
                            }
                        }
                        Button("Cancel", role: .cancel) {}
                    } message: {
                        Text(FeatureFlags.socialFeedEnabled
                             ? "This deletes your sign-in, cloud backup, weight history, and @username permanently — there is no undo. Posts and comments you shared stay on the feed unless you delete them first (long-press any of yours)."
                             : "This permanently deletes your sign-in, cloud backup, weight history, @username, verification selfie, coach application, posts, connect requests, and your rows on boards and challenges — there is no undo. Messages you sent stay in the other person's chat, and comments you left on other people's posts stay until you delete them.")
                    }
                }
            }
        }
        // Referral count refresh rides the stable container (audit 15, P2:
        // on the filterable section it re-fired a Firestore read every
        // time a search keystroke toggled the section in).
        .task { await store.refreshReferralCount() }
    }

    private func saveName() {
        // The editor closes ONLY when the store confirms the change landed —
        // a cooldown rejection used to close it over the unchanged name with
        // just a toast to explain (launch audit).
        if store.updateDisplayName(nameDraft) {
            isEditingName = false
        }
    }

    private func saveUsername() {
        let entered = usernameDraft
        Task {
            // The store handles the 14-day cooldown, validation, and the
            // atomic uniqueness claim — and reports each outcome as a toast.
            // AWAITED before closing: a taken/failed claim keeps the draft
            // on screen for a retry instead of discarding the typed text.
            let changed = await store.changeUsername(to: entered)
            if changed { isEditingUsername = false }
        }
    }

    /// The dot shows the color the palette actually resolves to.
    private func accentDotColor(for palette: AccentPalette) -> Color {
        MorpheTheme.colors(for: palette).primary
    }

    private func accentDot(for palette: AccentPalette) -> some View {
        let isSelected = store.profileShowcase.accentPalette == palette
        let isUnlocked = store.isPaletteUnlocked(palette)
        return Button {
            // Store contract: sets profileShowcase.accentPalette, calls
            // MorpheTheme.apply(accentPalette:), and persists the profile
            // snapshot — the same pathway onboarding's choice rides. A
            // locked palette toasts its unlock level instead.
            store.updateAccentPalette(palette)
            Haptics.impact(.light)
        } label: {
            ZStack {
                Circle()
                    .fill(MorpheTheme.swatchStyle(for: palette))
                    .frame(width: 28, height: 28)
                    .overlay(Circle().stroke(MorpheTheme.strokeSubtle, lineWidth: 1))
                    .opacity(isUnlocked ? 1 : 0.35)
                if isSelected {
                    Circle()
                        .stroke(MorpheTheme.textPrimary, lineWidth: 2)
                        .frame(width: 36, height: 36)
                    Image(systemName: "checkmark")
                        .scaledFont(size: 12, weight: .bold)
                        .foregroundStyle(MorpheTheme.onFill(accentDotColor(for: palette)))
                } else if !isUnlocked {
                    Image(systemName: "lock.fill")
                        .scaledFont(size: 10, weight: .bold)
                        .foregroundStyle(MorpheTheme.textSecondary)
                }
            }
            .frame(width: 44, height: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isUnlocked
            ? "\(palette.rawValue) accent"
            : palette == .recruiter
                ? "Recruiter accent, unlocks when someone joins through your invite"
                : palette == .champion
                ? "Champion accent, unlocks when you finish your first challenge"
                : "\(palette.rawValue) accent, unlocks with \(palette.rank?.title ?? "rank") at level \(store.paletteUnlockLevel(palette))")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private func settingsRow(_ title: String, value: String, showEdit: Bool = true, actionLabel: String = "Edit", onEdit: @escaping () -> Void) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(MorpheTheme.textMuted)
                Text(value)
                    .foregroundStyle(MorpheTheme.textPrimary)
                    .lineLimit(2)
            }
            Spacer()
            if showEdit {
                // The action word IS the signifier — it must name the real
                // action, never a default "Edit" for a code you haven't set
                // (affordance audit 2026-09).
                Button(actionLabel, action: onEdit)
                    .buttonStyle(.plain)
                    .foregroundStyle(MorpheTheme.accentText)
                    .accessibilityLabel("\(actionLabel) \(title.lowercased())")
            }
        }
    }
}

/// Profile → Connections (Lucas 2026-10-13): a Bluetooth heart-rate strap,
/// Apple Health and Apple Watch status, the supplement stack with today's
/// checks, a private enhancements note, and the apps that need a partner
/// agreement before Morphe can honestly connect to them.
private struct ConnectionsSettings: View {
    @Environment(MorpheAppStore.self) private var store
    @State private var newName = ""
    @State private var newDose = ""
    @State private var newTiming: SupplementTiming = .morning
    @State private var isAdding = false
    @State private var isEditingEnhancements = false
    @State private var enhancementsDraft = ""

    @State private var showAddApp = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            heartRateBlock
            Divider().overlay(MorpheTheme.strokeSubtle)
            statusRow("Apple Health", icon: "heart.fill",
                      value: store.healthSyncEnabled ? "Saving your workouts to Health" : "Saving workouts to Health: off — turn it on under Health")
            statusRow("Apple Watch", icon: "applewatch", value: watchValue)
            Divider().overlay(MorpheTheme.strokeSubtle)
            supplementsBlock
            Divider().overlay(MorpheTheme.strokeSubtle)
            enhancementsBlock
            Divider().overlay(MorpheTheme.strokeSubtle)
            otherAppsBlock
        }
    }

    // MARK: Heart rate

    private var monitor: HeartRateMonitor { store.heartRateMonitor }

    @ViewBuilder
    private var heartRateBlock: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Image(systemName: "heart.text.square")
                    .foregroundStyle(MorpheTheme.accentText)
                    .frame(width: 22)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Heart-rate monitor")
                        .foregroundStyle(MorpheTheme.textPrimary)
                    Text(heartRateCaption)
                        .font(.caption)
                        .foregroundStyle(MorpheTheme.textMuted)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 8)
                if let bpm = monitor.bpm {
                    Text("\(bpm)")
                        .font(.title3.weight(.bold).monospacedDigit())
                        .foregroundStyle(MorpheTheme.textPrimary)
                        .accessibilityLabel("\(bpm) beats per minute")
                }
            }

            switch monitor.state {
            case .off:
                Text("Bluetooth is off or not allowed. Turn it on in Settings → Morphe, then try again.")
                    .font(.caption)
                    .foregroundStyle(MorpheTheme.textMuted)
                Button("Try again") { monitor.startScan() }
                    .modifier(TextActionStyle())
            case .idle:
                WrapStack(spacing: 16) {
                    Button(monitor.rememberedName.map { "Reconnect \($0)" } ?? "Connect a monitor") {
                        monitor.startScan()
                    }
                    .modifier(TextActionStyle())
                    if monitor.rememberedName != nil {
                        Button("Find another") { monitor.scanForNew() }
                            .modifier(TextActionStyle())
                        Button("Forget") { monitor.disconnect(forget: true) }
                            .modifier(TextActionStyle(muted: true))
                            .accessibilityLabel("Forget the saved monitor")
                    }
                }
            case .scanning:
                HStack(spacing: 8) {
                    ProgressView().controlSize(.small)
                    Text("Looking for straps — wear it so it wakes up.")
                        .font(.caption)
                        .foregroundStyle(MorpheTheme.textMuted)
                    Spacer(minLength: 8)
                    Button("Stop") { monitor.disconnect(forget: false) }
                        .modifier(TextActionStyle(muted: true))
                        .accessibilityLabel("Stop looking for monitors")
                }
                ForEach(monitor.found) { device in
                    Button {
                        monitor.connect(device)
                    } label: {
                        HStack {
                            Text(device.name)
                                .foregroundStyle(MorpheTheme.textPrimary)
                            Spacer()
                            Text("Connect")
                                .foregroundStyle(MorpheTheme.accentText)
                        }
                        .frame(minHeight: 44)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Connect \(device.name)")
                }
            case .connecting(let name):
                HStack(spacing: 8) {
                    ProgressView().controlSize(.small)
                    Text("Connecting to \(name)…")
                        .font(.caption)
                        .foregroundStyle(MorpheTheme.textMuted)
                    Spacer(minLength: 8)
                    Button("Cancel") { monitor.disconnect(forget: false) }
                        .modifier(TextActionStyle(muted: true))
                        .accessibilityLabel("Cancel connecting")
                }
            case .connected:
                Button("Disconnect") { monitor.disconnect(forget: false) }
                    .modifier(TextActionStyle())
            }
        }
    }

    private var heartRateCaption: String {
        switch monitor.state {
        case .connected(let name):
            return monitor.bpm == nil ? "\(name) — waiting for a reading" : "\(name) — live during workouts"
        default:
            if let last = store.lastSessionHeartRate {
                return "Any standard Bluetooth strap (Polar, Garmin, Wahoo, Coros). Last session: avg \(last.average), peak \(last.peak) bpm."
            }
            return "Any standard Bluetooth strap (Polar, Garmin, Wahoo, Coros). Shows live in your workout."
        }
    }

    // MARK: Status rows

    private var watchValue: String {
        switch WatchBridge.shared.status {
        case .unsupported: return "Not available on this device"
        case .notPaired: return "No watch paired"
        case .paired: return "Paired — install Morphe from the Watch app"
        case .installed: return "Connected — log sets from your wrist"
        }
    }

    private func statusRow(_ title: String, icon: String, value: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .foregroundStyle(MorpheTheme.accentText)
                .frame(width: 22)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .foregroundStyle(MorpheTheme.textPrimary)
                Text(value)
                    .font(.caption)
                    .foregroundStyle(MorpheTheme.textMuted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .combine)
    }

    // MARK: Supplements

    private var supplementsBlock: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Supplements")
                        .foregroundStyle(MorpheTheme.textPrimary)
                    Text(store.supplementStack.items.isEmpty
                         ? "Your stack, with a daily check. Morphe AI sees it when Claude answers are on."
                         : "\(store.supplementsTakenTodayCount) of \(store.supplementStack.items.count) taken today")
                        .font(.caption)
                        .foregroundStyle(MorpheTheme.textMuted)
                }
                Spacer()
                if !isAdding {
                    Button("Add") { isAdding = true }
                        .modifier(TextActionStyle())
                        .accessibilityLabel("Add a supplement")
                }
            }

            ForEach(store.supplementStack.items) { item in
                let taken = store.isSupplementTakenToday(item)
                HStack(spacing: 10) {
                    Button {
                        store.toggleSupplementTaken(item)
                    } label: {
                        Image(systemName: taken ? "checkmark.circle.fill" : "circle")
                            .font(.title3)
                            .foregroundStyle(taken ? MorpheTheme.accentText : MorpheTheme.textMuted)
                            .frame(width: 44, height: 44)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(taken ? "\(item.name), taken today" : "Mark \(item.name) taken today")
                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.name)
                            .foregroundStyle(MorpheTheme.textPrimary)
                        Text([item.dose, item.timing.rawValue].filter { !$0.isEmpty }.joined(separator: " · "))
                            .font(.caption)
                            .foregroundStyle(MorpheTheme.textMuted)
                    }
                    Spacer(minLength: 0)
                    Button {
                        store.removeSupplement(item)
                    } label: {
                        Image(systemName: "minus.circle")
                            .foregroundStyle(MorpheTheme.textMuted)
                            .frame(width: 44, height: 44)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Remove \(item.name)")
                }
            }

            if isAdding {
                VStack(alignment: .leading, spacing: 8) {
                    TextField("Name (creatine, vitamin D…)", text: $newName)
                        .textFieldStyle(MorpheFieldStyle())
                    TextField("Dose (optional — 5 g, 2 caps)", text: $newDose)
                        .textFieldStyle(MorpheFieldStyle())
                    LabeledContent("When") {
                        Picker("When", selection: $newTiming) {
                            ForEach(SupplementTiming.allCases) { timing in
                                Text(timing.rawValue).tag(timing)
                            }
                        }
                        .pickerStyle(.menu)
                        .tint(MorpheTheme.accentText)
                    }
                    .foregroundStyle(MorpheTheme.textPrimary)
                    HStack(spacing: 16) {
                        Button("Save") {
                            if store.addSupplement(name: newName, dose: newDose, timing: newTiming) {
                                newName = ""
                                newDose = ""
                                isAdding = false
                            }
                        }
                        .modifier(TextActionStyle())
                        .disabled(newName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        .accessibilityLabel("Save supplement")
                        Button("Cancel") {
                            newName = ""
                            newDose = ""
                            isAdding = false
                        }
                        .modifier(TextActionStyle(muted: true))
                    }
                }
            }
        }
    }

    // MARK: Enhancements

    private var enhancementsBlock: some View {
        VStack(alignment: .leading, spacing: 8) {
            if isEditingEnhancements {
                Text("Enhancements (private)")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(MorpheTheme.textMuted)
                TextField("Anything else you take that affects training", text: $enhancementsDraft, axis: .vertical)
                    .textFieldStyle(MorpheFieldStyle())
                    .lineLimit(2...4)
                HStack(spacing: 16) {
                    Button("Save") {
                        store.updateEnhancementsNote(enhancementsDraft)
                        isEditingEnhancements = false
                    }
                    .modifier(TextActionStyle())
                    .accessibilityLabel("Save enhancements note")
                    Button("Cancel") { isEditingEnhancements = false }
                        .modifier(TextActionStyle(muted: true))
                }
            } else {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Enhancements (private)")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(MorpheTheme.textMuted)
                        Text(store.enhancementsNote.isEmpty ? "Not shared" : store.enhancementsNote)
                            .foregroundStyle(MorpheTheme.textPrimary)
                            .lineLimit(2)
                    }
                    Spacer()
                    Button(store.enhancementsNote.isEmpty ? "Add" : "Edit") {
                        enhancementsDraft = store.enhancementsNote
                        isEditingEnhancements = true
                    }
                    .modifier(TextActionStyle())
                    .accessibilityLabel(store.enhancementsNote.isEmpty ? "Add enhancements note" : "Edit enhancements note")
                }
            }
            Text("Optional and self-reported. Kept on this iPhone — never synced to your Morphe account or shown to other members — and included in your own data export. With your own Claude key, Morphe AI reads it as context and is instructed never to give dosing, sourcing or cycle advice; that conversation belongs with a doctor.")
                .font(.caption2)
                .foregroundStyle(MorpheTheme.textMuted)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: Other apps (through Apple Health)

    private var otherAppsBlock: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Image(systemName: "square.grid.2x2")
                    .foregroundStyle(MorpheTheme.accentText)
                    .frame(width: 22)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Other apps")
                        .foregroundStyle(MorpheTheme.textPrimary)
                    Text(otherAppsCaption)
                        .font(.caption)
                        .foregroundStyle(MorpheTheme.textMuted)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 8)
                Button(store.healthImport.enabled ? "Manage" : "Add an app") { showAddApp = true }
                    .modifier(TextActionStyle())
                    .accessibilityLabel(store.healthImport.enabled ? "Manage connected apps" : "Add an app")
            }
        }
        .sheet(isPresented: $showAddApp) {
            AddAppSheet()
                .environment(store)
                .presentationDetents([.medium, .large])
        }
    }

    private var otherAppsCaption: String {
        guard store.healthImport.enabled else {
            return "Bring in workouts from Strava, Garmin, WHOOP and more — automatically, through your iPhone."
        }
        if store.healthImportNeedsDevicePermission {
            return "Set up on another phone — tap Manage to allow Health on this iPhone."
        }
        if store.healthImport.sources.isEmpty {
            return "Set up — nothing from other apps yet."
        }
        return "Syncing from \(store.healthImport.sources.joined(separator: ", "))"
    }
}

/// "Add an app": one tap connects every fitness app that shares into
/// Apple Health on this iPhone — no logins, no partner deals.
private struct AddAppSheet: View {
    @Environment(MorpheAppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Text("Add an app")
                        .font(.title3.weight(.bold))
                        .foregroundStyle(MorpheTheme.textPrimary)
                    Spacer()
                    Button("Done") { dismiss() }
                        .modifier(TextActionStyle())
                }
                Text("Strava, Garmin Connect, WHOOP, Oura, Peloton, Nike Run Club and most fitness apps save your workouts to Apple Health. Connect once and Morphe checks for new ones whenever you open the app — the last 90 days land in your history as imported sessions. They count toward your streak and score like any session, but earn no XP, never post, and stay off boards.")
                    .font(.subheadline)
                    .foregroundStyle(MorpheTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                if store.healthImport.enabled && !store.healthImportNeedsDevicePermission {
                    if !store.healthImport.sources.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("CONNECTED")
                                .font(MorpheTheme.microLabel(10))
                                .tracking(1.4)
                                .foregroundStyle(MorpheTheme.textMuted)
                            ForEach(store.healthImport.sources, id: \.self) { source in
                                Label(source, systemImage: "checkmark.circle.fill")
                                    .foregroundStyle(MorpheTheme.textPrimary)
                            }
                        }
                    }
                    Button {
                        Task { await store.importWorkoutsFromHealth(force: true) }
                    } label: {
                        Text(store.healthImportBusy ? "Checking…" : "Check for new workouts")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(PrimaryCTAButtonStyle())
                    .disabled(store.healthImportBusy)
                } else {
                    Button {
                        Task { await store.connectAppsThroughHealth() }
                    } label: {
                        Text(store.healthImportBusy ? "Connecting…" : "Connect through Apple Health")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(PrimaryCTAButtonStyle())
                    .disabled(store.healthImportBusy)
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("Don't see an app?")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(MorpheTheme.textPrimary)
                    Text("Turn on Apple Health in that app's own settings (often under Connected apps or Health), then come back. Allow Morphe to read Workouts in the Health prompt, or later in Settings → Health → Data Access & Devices → Morphe.")
                        .font(.caption)
                        .foregroundStyle(MorpheTheme.textMuted)
                        .fixedSize(horizontal: false, vertical: true)
                    Button("Open the Health app") {
                        if let url = URL(string: "x-apple-health://") { openURL(url) }
                    }
                    .modifier(TextActionStyle())
                }

                if store.healthImport.enabled {
                    Button("Disconnect other apps") {
                        store.disconnectAppsThroughHealth()
                        dismiss()
                    }
                    .modifier(TextActionStyle(muted: true))
                }
            }
            .padding(20)
        }
        .background(PremiumBackground().ignoresSafeArea())
    }
}

/// A text button with a full 44pt tap target (Connections, audit 2026-10-13).
private struct TextActionStyle: ViewModifier {
    var muted = false
    func body(content: Content) -> some View {
        content
            .buttonStyle(.plain)
            .foregroundStyle(muted ? MorpheTheme.textMuted : MorpheTheme.accentText)
            .frame(minHeight: 44)
            .contentShape(Rectangle())
    }
}

/// Athlete profile = strictly training: snapshot, focus, recent work, records.
private struct AthleteProfileBody<Between: View>: View {
    let store: MorpheAppStore
    /// Owned by ProfileView so its unsaved-edit guard can see it.
    @Binding var weightDraft: String
    /// Progress opens through ProfileView's unsaved-edit guard (audit 15,
    /// P1: the row's direct close silently dropped typed drafts — the
    /// exact bug the weightDraft hoist fixed for Done and swipe-down).
    let onOpenProgress: () -> Void
    /// Rendered between the weight card and the history door.
    @ViewBuilder let between: () -> Between
    var body: some View {
        Group {
            // Weight moved into Your Details (Lucas 2026-10-10): current →
            // goal, under Experience.
            between()

            // Training history lives in Progress — one door, not four
            // duplicate cards (Snapshot/Focus/Logs/PRs all re-rendered what
            // Home and Progress already own).
            Button {
                onOpenProgress()
            } label: {
                HStack {
                    Text("See your history, records, and charts")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(MorpheTheme.textPrimary)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(MorpheTheme.textMuted)
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: MorpheTheme.radius, style: .continuous)
                        .fill(MorpheTheme.panel)
                )
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Open Progress for history, records, and charts")
        }
    }

}

/// Coach profile = coaching identity + a snapshot of the REAL roster
/// (managed clients + live overview — same sources as the dashboard).

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
                RoundedRectangle(cornerRadius: MorpheTheme.chipRadius, style: .continuous)
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
                    .foregroundStyle(MorpheTheme.textPrimary)

                ForEach(records) { record in
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(record.title)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(MorpheTheme.textPrimary)
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
                    .foregroundStyle(MorpheTheme.textPrimary)

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
                                        .foregroundStyle(MorpheTheme.textPrimary)
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


// MARK: - Verification selfie capture

/// Front-camera-first UIImagePickerController wrapper. Live capture only — a
/// library photo can't stand in for "this person is at this device right now."
private struct VerificationSelfieCamera: UIViewControllerRepresentable {
    let onCapture: (UIImage?) -> Void

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        if UIImagePickerController.isSourceTypeAvailable(.camera) {
            picker.sourceType = .camera
            if UIImagePickerController.isCameraDeviceAvailable(.front) {
                picker.cameraDevice = .front
            }
        }
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ controller: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(onCapture: onCapture) }

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let onCapture: (UIImage?) -> Void
        init(onCapture: @escaping (UIImage?) -> Void) { self.onCapture = onCapture }

        func imagePickerController(_ picker: UIImagePickerController,
                                   didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            onCapture(info[.originalImage] as? UIImage)
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            onCapture(nil)
        }
    }
}

/// System share sheet for the JSON data export. The completion handler
/// closes the HOSTING SwiftUI sheet too — without it, finishing or
/// cancelling the share left a blank panel the user had to swipe away.
// Internal (not private): Form Clips hand their file to the same sheet.
struct DataExportShareSheet: UIViewControllerRepresentable {
    let url: URL
    let onFinish: () -> Void

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: [url], applicationActivities: nil)
        controller.completionWithItemsHandler = { _, _, _, _ in
            onFinish()
        }
        return controller
    }

    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}

/// Morphe Pro paywall — mounted ONLY while PremiumGate.storefrontEnabled.
/// Lists what Pro will gate and what it never will, then the live products.
struct MorpheProPaywallSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var premium = PremiumStore.shared

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 16) {
                Text("Morphe Pro")
                    .font(.title2.weight(.black))
                    .foregroundStyle(MorpheTheme.textPrimary)

                VStack(alignment: .leading, spacing: 10) {
                    paywallRow("calendar.badge.clock", "Structured programs — multi-week arcs with deloads built in")
                    paywallRow("chart.line.uptrend.xyaxis", "Advanced analytics — e1RM, plateaus, muscle balance, trends")
                    paywallRow("person.2.badge.gearshape", "Advanced tools — programs, analytics, and deeper insights")
                }

                Text("Your data, your export, and every safety feature stay free — always.")
                    .font(.caption)
                    .foregroundStyle(MorpheTheme.textMuted)

                if premium.hasEntitlement {
                    Text("You're Pro. Thanks for backing smarter training.")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(MorpheTheme.accentText)
                } else if premium.products.isEmpty, premium.loadState == .failed {
                    // StoreKit failed — a retry, not a forever "loading…"
                    // (deferred-states pass 2026-09).
                    FetchRetryCard(message: "Plans couldn't load — check your connection.") {
                        Task { await premium.load() }
                    }
                } else if premium.products.isEmpty, premium.loadState == .loaded {
                    // Fetch SUCCEEDED but returned nothing — unapproved or
                    // mistyped product IDs. Honest, retryable, not an
                    // eternal "Loading…" (audit 20 P1).
                    FetchRetryCard(message: "Plans aren't available right now.") {
                        Task { await premium.load() }
                    }
                } else if premium.products.isEmpty {
                    FetchPlaceholderCard(line: "Loading plans…")
                } else {
                    ForEach(premium.products, id: \.id) { product in
                        Button {
                            Task {
                                if await premium.purchase(product) { dismiss() }
                            }
                        } label: {
                            HStack {
                                Text(product.displayName)
                                Spacer()
                                Text(product.displayPrice)
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(PrimaryCTAButtonStyle(accent: MorpheTheme.accent))
                        .disabled(premium.isBusy)
                    }
                }

                Button {
                    Task { await premium.restore() }
                } label: {
                    if premium.isBusy {
                        ProgressView()
                    } else {
                        Text("Restore Purchases")
                    }
                }
                .buttonStyle(SecondaryCTAButtonStyle())
                .frame(maxWidth: .infinity)
                .disabled(premium.isBusy)
            }
            .padding(20)
        }
        .background(MorpheTheme.ink)
        .task { await premium.load() }
    }

    private func paywallRow(_ symbol: String, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: symbol)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(MorpheTheme.accentText)
                .frame(width: 24)
            Text(text)
                .font(.subheadline)
                .foregroundStyle(MorpheTheme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}


// MARK: - Morphe Intelligence key editor (rebuild wave, Lucas 2026-08-27)
//
// The Claude brain is opt-in behind the user's OWN Anthropic API key: the
// copy is honest about cost, the key lives in the Keychain, and removing
// it returns the app to the built-in instant replies with zero residue.
/// ElevenLabs key for the neural Morphe voice (Tier 2). Honest about
/// the boundary: answer TEXT leaves the phone to make the audio;
/// workout data does not. No key = the on-device voice, unchanged.
private struct NeuralVoiceKeyEditor: View {
    @Environment(MorpheAppStore.self) private var store
    @State private var draftKey = ""
    @State private var showSaveError = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 8) {
                    Text("Neural voice")
                        .foregroundStyle(MorpheTheme.textPrimary)
                    StatusBadge(
                        text: store.neuralVoiceEnabled ? "On" : "Off",
                        color: store.neuralVoiceEnabled ? MorpheTheme.accent : MorpheTheme.textMuted)
                }
                Text(store.neuralVoiceEnabled
                     ? "On \u{2014} Morphe speaks with an ElevenLabs neural voice on your own key. The TEXT of each spoken answer leaves your phone to make the audio; your workout data does not. Calls bill to your key."
                     : "Paste your own ElevenLabs API key and Morphe trades the on-device voice for a neural one \u{2014} the accent picks above still apply. The TEXT of spoken answers would leave your phone to make the audio; your workout data would not. Without a key, the on-device voice runs: free, private, offline.")
                    .font(.caption)
                    .foregroundStyle(MorpheTheme.textMuted)
            }
            if store.neuralVoiceEnabled {
                Button(role: .destructive) {
                    store.clearNeuralVoiceKey()
                    draftKey = ""
                    Haptics.impact(.light)
                } label: {
                    Text("Remove key")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(SecondaryCTAButtonStyle())
            } else {
                SecureField("ElevenLabs API key", text: $draftKey)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .textFieldStyle(MorpheFieldStyle())
                    .onChange(of: draftKey) { _, _ in showSaveError = false }
                Button {
                    let trimmed = draftKey.trimmingCharacters(in: .whitespacesAndNewlines)
                    // Cheap shape check: ElevenLabs keys are long hex-ish
                    // tokens — catch an obviously wrong paste (a URL, an
                    // sk-ant- key) before the first billed call fails.
                    if trimmed.count >= 20, !trimmed.hasPrefix("sk-ant-"),
                       !trimmed.hasPrefix("sk-proj-"),
                       !trimmed.contains(" "), store.setNeuralVoiceKey(trimmed) {
                        draftKey = ""
                        showSaveError = false
                        Haptics.success()
                    } else {
                        showSaveError = true
                        Haptics.error()
                    }
                } label: {
                    Text("Save key")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(SecondaryCTAButtonStyle())
                .disabled(draftKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                if showSaveError {
                    Text("That doesn't look like an ElevenLabs key \u{2014} check what you pasted and try again.")
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }
        }
    }
}

/// Morphe AI online (Lucas 2026-10-14): Morphe's own relay, no key needed.
/// The consent sheet names the company and the data before the first
/// request; the toggle refuses signed-out and under-18 members honestly.
private struct OnlineAISettings: View {
    @Environment(MorpheAppStore.self) private var store
    @State private var showConsent = false

    private var isOn: Bool { store.onlineAIEnabled }

    var body: some View {
        @Bindable var store = store
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 8) {
                        Text("Morphe AI online")
                            .foregroundStyle(MorpheTheme.textPrimary)
                        StatusBadge(
                            text: store.onlineAIEligible ? "On" : (isOn ? "Paused" : "Off"),
                            color: store.onlineAIEligible ? MorpheTheme.accent : MorpheTheme.textMuted)
                    }
                    Text(caption)
                        .font(.caption)
                        .foregroundStyle(MorpheTheme.textMuted)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
                Toggle("Morphe AI online", isOn: Binding(
                    get: { isOn },
                    set: { wanted in
                        if wanted {
                            if store.onlineAIBlockedReason == nil { showConsent = true } else { store.setOnlineAI(enabled: true) }
                        } else {
                            store.setOnlineAI(enabled: false)
                        }
                    }))
                    .labelsHidden()
                    .tint(MorpheTheme.accent)
            }
            .confirmationDialog("Send this to Anthropic through Morphe?", isPresented: $showConsent, titleVisibility: .visible) {
                Button("Agree and turn on") {
                    if store.setOnlineAI(enabled: true) {
                        UserDefaults.standard.set(Date.now.timeIntervalSince1970, forKey: "morphe.aiConsentAt")
                        Haptics.success()
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Morphe AI online sends Anthropic (the company that makes Claude), through Morphe\u{2019}s own server, what it needs to answer: your messages, your name, a summary of your logged training, the profile details you set (age, height, goals, current and goal weight, diet, equipment, weakness, injury note, sports, training styles and days), your supplement stack and today\u{2019}s checks, your private enhancements note if you wrote one, connected devices with the live heart-rate reading, your last session\u{2019}s average and peak heart rate, which apps your imported workouts come from, the five things you open most in the app, your nutrition plan and recent food names, and a meal photo only when you take one for a food check. Morphe\u{2019}s server checks your account and counts your requests (30 a day); it keeps no messages. For members 18 and older. Free, on Morphe. Turn it off any time.")
            }

            if store.intelligenceEnabled {
                Divider().overlay(MorpheTheme.strokeSubtle)
                HStack(alignment: .center, spacing: 12) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Help improve Morphe AI")
                            .foregroundStyle(MorpheTheme.textPrimary)
                        Text("Adds thumbs up and down under answers. A rated question and answer, and which door answered (Morphe\u{2019}s server or your key), are kept with your account for Lucas to read and improve Morphe AI; nothing is shared or published. Deleted with your account.")
                            .font(.caption)
                            .foregroundStyle(MorpheTheme.textMuted)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 0)
                    Toggle("Help improve Morphe AI", isOn: $store.aiImprovementOptIn)
                        .labelsHidden()
                        .tint(MorpheTheme.accent)
                }
            }
        }
    }

    private var caption: String {
        if isOn, let reason = store.onlineAIBlockedReason { return "Paused — \(reason)" }
        if isOn { return "On — open questions go to Claude on Morphe\u{2019}s key, through Morphe\u{2019}s server. 30 a day. Everything else stays instant and on-device." }
        if let reason = store.onlineAIBlockedReason { return reason }
        return "Real Claude answers in chat, out loud through \u{201C}Hey Morphe\u{201D}, in the workout builder and the food check \u{2014} free, no key, 30 a day. For members 18 and older."
    }
}

private struct IntelligenceKeyEditor: View {
    @Environment(MorpheAppStore.self) private var store
    @State private var draftKey = ""

    private var hasKey: Bool { _ = store.intelligenceEnabled; return MorpheIntelligence.apiKey?.isEmpty == false }
    @State private var showAIConsent = false
    @State private var showSaveError = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 8) {
                    Text("Your own key")
                        .foregroundStyle(MorpheTheme.textPrimary)
                    // State a paragraph of prose used to carry, now
                    // readable at a glance (affordance audit 2026-09).
                    StatusBadge(
                        text: hasKey ? "On" : "Off",
                        color: hasKey ? MorpheTheme.accent : MorpheTheme.textMuted)
                }
                Text(hasKey
                     ? "On \u{2014} every Claude call runs on your own Anthropic API key and the bigger model, and bills to your key. Morphe AI online is not used while a key is set."
                     : "Optional: paste your own Anthropic API key to run Claude on your own account instead of Morphe\u{2019}s \u{2014} no daily allowance, the bigger model, billed to you.")
                    .font(.caption)
                    .foregroundStyle(MorpheTheme.textMuted)
            }
            if hasKey {
                Button(role: .destructive) {
                    store.clearIntelligenceKey()
                    draftKey = ""
                    Haptics.impact(.light)
                } label: {
                    Text("Remove key")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(SecondaryCTAButtonStyle())
            } else {
                SecureField("sk-ant-\u{2026}", text: $draftKey)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .textFieldStyle(MorpheFieldStyle())
                    .onChange(of: draftKey) { _, _ in showSaveError = false }
                Button {
                    // Cheap shape check (audit 17, P2): a pasted URL or
                    // OpenAI key "saving" fine and failing on the first
                    // billed call is the dishonest path.
                    let trimmed = draftKey.trimmingCharacters(in: .whitespacesAndNewlines)
                    if trimmed.hasPrefix("sk-ant-") {
                        // Consent first (App Store 5.1.2, fix wave 2026-10-13):
                        // name the company and the data before anything leaves.
                        showAIConsent = true
                    } else {
                        showSaveError = true
                        Haptics.error()
                    }
                } label: {
                    Text("Save key")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(SecondaryCTAButtonStyle())
                .disabled(draftKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .confirmationDialog("Send this to Anthropic?", isPresented: $showAIConsent, titleVisibility: .visible) {
                    Button("Agree and save key") {
                        let trimmed = draftKey.trimmingCharacters(in: .whitespacesAndNewlines)
                        if store.setIntelligenceKey(trimmed) {
                            UserDefaults.standard.set(Date.now.timeIntervalSince1970, forKey: "morphe.aiConsentAt")
                            draftKey = ""
                            showSaveError = false
                            Haptics.success()
                        } else {
                            showSaveError = true
                            Haptics.error()
                        }
                    }
                    Button("Cancel", role: .cancel) {}
                } message: {
                    Text("With your key, Morphe AI sends Anthropic (the company that makes Claude) what it needs to answer: your messages, your name, a summary of your logged training, the profile details you set (age, height, goals, current and goal weight, diet, equipment, weakness, injury note, sports, training styles and days), your supplement stack and today\u{2019}s checks, your private enhancements note if you wrote one, connected devices with the live heart-rate reading, your last session\u{2019}s average and peak heart rate, which apps your imported workouts come from, the five things you open most in the app, your nutrition plan and recent food names, and a meal photo only when you take one for a food check. Calls bill to your key. Remove the key any time to stop.")
                }
                if showSaveError {
                    Text("Anthropic keys start with sk-ant- \u{2014} check what you pasted and try again.")
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }
        }
    }
}

// MARK: - Import review (2026-10-04)

/// What the file holds and what would be added — the user confirms the
/// numbers (and the unit, when the file doesn't state one) before a single
/// log is written.
struct ImportReviewSheet: View {
    @Environment(MorpheAppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let plan: MorpheAppStore.ImportPlan
    @State private var unit: WeightUnit = .pounds
    @State private var seeded = false

    private static let dayFormat: Date.FormatStyle = .dateTime.month(.abbreviated).day().year()

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Import from \(plan.parsed.sourceApp)")
                        .font(.title2.weight(.bold))
                        .foregroundStyle(MorpheTheme.textPrimary)
                    if let first = plan.fresh.first?.date, let last = plan.fresh.last?.date {
                        Text("\(first.formatted(Self.dayFormat)) to \(last.formatted(Self.dayFormat))")
                            .font(.subheadline)
                            .monospacedDigit()
                            .foregroundStyle(MorpheTheme.textSecondary)
                    }
                }

                HStack(spacing: 8) {
                    MetricPill(label: "Workouts", value: plan.fresh.count.formatted())
                    MetricPill(label: "Sets", value: plan.setCount.formatted())
                }

                if plan.duplicates > 0 {
                    note("\(plan.duplicates) workout\(plan.duplicates == 1 ? " is" : "s are") already in your log and will be left alone.")
                }
                if plan.parsed.skippedRows > 0 {
                    note("\(plan.parsed.skippedRows) row\(plan.parsed.skippedRows == 1 ? "" : "s") without reps (timed or distance work, rest timers) will be skipped.")
                }

                if plan.parsed.unitInFile == nil {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("The file doesn't say which unit its weights are in.")
                            .font(.subheadline)
                            .foregroundStyle(MorpheTheme.textPrimary)
                        Picker("Weights in the file", selection: $unit) {
                            ForEach(WeightUnit.allCases) { option in
                                Text(option.label).tag(option)
                            }
                        }
                        .pickerStyle(.segmented)
                    }
                } else {
                    note("Weights in the file are in \(unit.label).")
                }

                if plan.parsed.truncated {
                    note("The file is longer than Morphe reads in one pass. Only the first 50,000 rows are included.")
                }
                note("Imported workouts count toward your history, records and charts. They earn no XP, and each carries a note saying where it came from.")

                Button(plan.fresh.isEmpty ? "Nothing New to Import" : "Import \(plan.fresh.count) Workout\(plan.fresh.count == 1 ? "" : "s")") {
                    let added = store.commitImport(plan, unit: unit)
                    Haptics.success()
                    store.showToast("\(added) workout\(added == 1 ? "" : "s") added to your history.")
                    dismiss()
                }
                .buttonStyle(PrimaryCTAButtonStyle(accent: MorpheTheme.accent))
                .disabled(plan.fresh.isEmpty)
                .opacity(plan.fresh.isEmpty ? 0.5 : 1)

                Button("Cancel") { dismiss() }
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .foregroundStyle(MorpheTheme.textSecondary)
            }
            .padding(20)
        }
        .background(PremiumBackground().ignoresSafeArea())
        .onAppear {
            guard !seeded else { return }
            seeded = true
            if let inFile = plan.parsed.unitInFile {
                unit = inFile == "kg" ? .kilograms : .pounds
            } else {
                unit = store.weightUnit
            }
        }
    }

    private func note(_ text: String) -> some View {
        Text(text)
            .font(.caption)
            .foregroundStyle(MorpheTheme.textSecondary)
            .fixedSize(horizontal: false, vertical: true)
    }
}

// MARK: - Creator Studio (2026-10-05)

/// Where an approved creator publishes. Three jobs, one sheet: workouts
/// to Discover, notes to Learn, open challenges to the board. Everything
/// shows the author's name, and anything can be taken down by its author.
struct CreatorStudioSheet: View {
    @Environment(MorpheAppStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    private enum Job: String, CaseIterable, Identifiable {
        case workouts = "Workouts", notes = "Notes", challenges = "Challenges"
        var id: String { rawValue }
    }

    @State private var job: Job = .workouts
    @State private var busy = false
    @State private var noteTitle = ""
    @State private var noteBody = ""
    @State private var challengeTitle = ""
    @State private var challengeMetric: ChallengeMetric = .sets
    @State private var challengeDays = 7
    @State private var publishing: WorkoutTemplate?

    private var publishable: [WorkoutTemplate] {
        let saved = Set(store.savedWorkouts.map(\.workoutTemplateID))
        return store.workoutTemplates.filter { store.isCustomWorkout($0.id) || saved.contains($0.id) }
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Creator Studio")
                            .font(.title2.weight(.bold))
                            .foregroundStyle(MorpheTheme.textPrimary)
                        Text("What you publish carries your name and is visible to every member.")
                            .font(.subheadline)
                            .foregroundStyle(MorpheTheme.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 8)
                    Button("Done") { dismiss() }
                        .foregroundStyle(MorpheTheme.textPrimary)
                        .frame(minWidth: 44, minHeight: 44)
                }

                Picker("Job", selection: $job) {
                    ForEach(Job.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)

                switch job {
                case .workouts: workoutsJob
                case .notes: notesJob
                case .challenges: challengesJob
                }
            }
            .padding(20)
        }
        .background(PremiumBackground().ignoresSafeArea())
        .scrollDismissesKeyboard(.interactively)
        .task { await store.refreshCreatorContent(force: true) }
        .confirmationDialog(
            publishing.map { "Publish \($0.name) to Discover?" } ?? "",
            isPresented: Binding(get: { publishing != nil }, set: { if !$0 { publishing = nil } }),
            titleVisibility: .visible,
            presenting: publishing
        ) { template in
            Button("Publish") {
                Task {
                    busy = true
                    _ = await store.publishCreatorWorkout(from: template)
                    busy = false
                }
            }
            Button("Not Now", role: .cancel) {}
        } message: { _ in
            Text("Every member can start or save it. Only exercises in the shared library travel.")
        }
    }

    // MARK: Workouts

    @ViewBuilder
    private var workoutsJob: some View {
        sectionLabel("LIVE ON DISCOVER", count: store.myCreatorWorkouts.count)
        if store.myCreatorWorkouts.isEmpty {
            quiet("Nothing published yet. Pick one of your workouts below.")
        } else {
            ForEach(store.myCreatorWorkouts) { workout in
                row(title: workout.name,
                    detail: "\(workout.exercises.count) exercises · \(workout.durationMinutes) min · published \(workout.publishedAt.formatted(date: .abbreviated, time: .omitted))",
                    action: "Remove") {
                    Task { await store.unpublishCreatorWorkout(workout) }
                }
            }
        }

        sectionLabel("YOUR WORKOUTS", count: publishable.count)
        if publishable.isEmpty {
            quiet("Build a workout in Train, or save one from Discover, and it appears here to publish.")
        } else {
            ForEach(publishable) { template in
                row(title: template.name,
                    detail: "\(template.exercises.count) exercises · \(template.durationMinutes) min",
                    action: "Publish") {
                    publishing = template
                }
            }
        }
    }

    // MARK: Notes

    @ViewBuilder
    private var notesJob: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 10) {
                Text("New note")
                    .font(.headline)
                    .foregroundStyle(MorpheTheme.textPrimary)
                TextField("Title", text: $noteTitle)
                    .textFieldStyle(MorpheFieldStyle())
                TextField("A technique point, a programming idea, a reminder. Plain words.", text: $noteBody, axis: .vertical)
                    .lineLimit(4...10)
                    .textFieldStyle(MorpheFieldStyle())
                HStack {
                    Text("\(noteBody.count)/2000")
                        .font(.caption)
                        .monospacedDigit()
                        .foregroundStyle(MorpheTheme.textMuted)
                    Spacer()
                    Button(busy ? "Publishing…" : "Publish to Learn") {
                        Task {
                            busy = true
                            if await store.publishCreatorNote(title: noteTitle, body: noteBody) {
                                noteTitle = ""; noteBody = ""
                            }
                            busy = false
                        }
                    }
                    .buttonStyle(PrimaryCTAButtonStyle(accent: MorpheTheme.accent))
                    .disabled(busy)
                }
            }
        }

        sectionLabel("YOUR NOTES", count: store.myCreatorNotes.count)
        if store.myCreatorNotes.isEmpty {
            quiet("Nothing published yet.")
        } else {
            ForEach(store.myCreatorNotes) { note in
                row(title: note.title,
                    detail: note.createdAt.formatted(date: .abbreviated, time: .omitted),
                    action: "Remove") {
                    Task { await store.deleteCreatorNote(note) }
                }
            }
        }
    }

    // MARK: Challenges

    @ViewBuilder
    private var challengesJob: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 10) {
                Text("Open challenge")
                    .font(.headline)
                    .foregroundStyle(MorpheTheme.textPrimary)
                Text("Listed on every member's board — no code needed. Scores come from logged workouts only.")
                    .font(.caption)
                    .foregroundStyle(MorpheTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                TextField("Title", text: $challengeTitle)
                    .textFieldStyle(MorpheFieldStyle())
                Picker("Metric", selection: $challengeMetric) {
                    ForEach(ChallengeMetric.allCases) { Text($0.label).tag($0) }
                }
                .pickerStyle(.segmented)
                Picker("Length", selection: $challengeDays) {
                    ForEach([7, 14, 30], id: \.self) { Text("\($0) days").tag($0) }
                }
                .pickerStyle(.segmented)
                Button(busy ? "Opening…" : "Open to Everyone") {
                    Task {
                        busy = true
                        if await store.createOpenChallenge(title: challengeTitle, metric: challengeMetric, days: challengeDays) {
                            challengeTitle = ""
                        }
                        busy = false
                    }
                }
                .buttonStyle(PrimaryCTAButtonStyle(accent: MorpheTheme.accent))
                .disabled(busy || challengeTitle.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }

        let mine = store.openChallenges.filter { $0.hostUid == store.authUser?.id }
        sectionLabel("YOUR OPEN CHALLENGES", count: mine.count)
        if mine.isEmpty {
            quiet("None open right now.")
        } else {
            ForEach(mine) { listing in
                row(title: listing.title,
                    detail: "Code \(listing.code) · ends \(listing.endsAt.formatted(date: .abbreviated, time: .omitted))",
                    action: "Delist") {
                    Task { await store.delistOpenChallenge(listing) }
                }
            }
        }
    }

    // MARK: Pieces

    private func sectionLabel(_ title: String, count: Int) -> some View {
        HStack(spacing: 8) {
            Text(title)
                .font(MorpheTheme.microLabel(10))
                .tracking(1.4)
                .foregroundStyle(MorpheTheme.textMuted)
            Text(String(format: "%03d", count))
                .font(MorpheTheme.microLabel(10))
                .monospacedDigit()
                .foregroundStyle(MorpheTheme.accentAlt)
        }
        .padding(.top, 4)
    }

    private func quiet(_ text: String) -> some View {
        Text(text)
            .font(.caption)
            .foregroundStyle(MorpheTheme.textMuted)
            .fixedSize(horizontal: false, vertical: true)
    }

    private func row(title: String, detail: String, action: String, perform: @escaping () -> Void) -> some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(MorpheTheme.textPrimary)
                    .lineLimit(2)
                Text(detail)
                    .font(.caption)
                    .monospacedDigit()
                    .foregroundStyle(MorpheTheme.textSecondary)
                    .lineLimit(2)
            }
            Spacer(minLength: 8)
            Button(action, action: perform)
                .buttonStyle(SecondaryCTAButtonStyle())
                .frame(width: 96)
                .disabled(busy)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: MorpheTheme.radius, style: .continuous)
                .fill(MorpheTheme.panelStrong)
        )
    }
}
