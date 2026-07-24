import SwiftUI
import PhotosUI

struct ProfileView: View {
    @Environment(MorpheAppStore.self) private var store
    @State private var isEditingName = false
    @State private var nameDraft = ""
    @State private var isEditingInjuries = false
    @State private var injuriesDraft = ""
    @State private var isEditingUsername = false
    @State private var usernameDraft = ""
    @State private var isEditingBio = false
    @State private var bioDraft = ""
    @State private var isEditingTargets = false
    @State private var physicalTargetDraft = ""
    @State private var weightTargetDraft = ""
    @State private var deadlineTargetDraft = ""
    @State private var photoPickerItem: PhotosPickerItem?
    @State private var showVerificationCamera = false
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
                    targetsCard
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
        if isEditingBio,
           bioDraft.trimmingCharacters(in: .whitespacesAndNewlines) != store.profileCustomBio {
            return true
        }
        if isEditingTargets, targetsChanged {
            return true
        }
        return false
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
        if isEditingTargets { saveTargets() }
        if bodyMetricsChanged {
            store.updateBodyMetrics(height: heightDraft, weight: weightDraft)
        }
    }

    private func discardAllEdits() {
        isEditingName = false
        isEditingUsername = false
        isEditingInjuries = false
        isEditingBio = false
        isEditingTargets = false
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

    /// The 30/60/90-day targets captured in onboarding, editable in place.
    /// Drafts ride the sheet's save/discard guard so a swipe-down can't eat
    /// half-typed goals.
    private var targetsCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 14) {
                Text("Your Targets")
                    .font(.headline)
                    .foregroundStyle(.white)

                if isEditingTargets {
                    VStack(alignment: .leading, spacing: 10) {
                        targetField("30-day", placeholder: "Your 30-day goal", text: $physicalTargetDraft)
                        targetField("60-day", placeholder: "Your 60-day goal", text: $weightTargetDraft)
                        targetField("90-day", placeholder: "Your 90-day goal", text: $deadlineTargetDraft)
                        HStack(spacing: 12) {
                            Button("Save") { saveTargets() }
                                .buttonStyle(.plain)
                                .foregroundStyle(MorpheTheme.accent)
                                .accessibilityLabel("Save targets")
                            Button("Cancel") { isEditingTargets = false }
                                .buttonStyle(.plain)
                                .foregroundStyle(MorpheTheme.textMuted)
                                .accessibilityLabel("Cancel target edits")
                            Spacer()
                        }
                    }
                } else {
                    targetRow("30-day", value: store.clientProfile.physicalGoalTarget)
                    targetRow("60-day", value: store.clientProfile.weightGoalTarget)
                    targetRow("90-day", value: store.clientProfile.goalDeadline)
                    Button("Edit Targets") {
                        physicalTargetDraft = store.clientProfile.physicalGoalTarget
                        weightTargetDraft = store.clientProfile.weightGoalTarget
                        deadlineTargetDraft = store.clientProfile.goalDeadline
                        isEditingTargets = true
                    }
                    .buttonStyle(.plain)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(MorpheTheme.accentAlt)
                }
            }
        }
    }

    private func targetRow(_ label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.caption.weight(.semibold))
                .foregroundStyle(MorpheTheme.textMuted)
            Text(value.isEmpty ? "Not set" : value)
                .foregroundStyle(value.isEmpty ? MorpheTheme.textMuted : .white)
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
                    profilePhotoView

                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 6) {
                            Text(isCoach ? store.coachProfile.name : store.profileShowcase.displayName)
                                .font(.title2.weight(.bold))
                                .foregroundStyle(.white)
                            if store.isVerifiedUser {
                                // Verification blue — a universal trust signal,
                                // deliberately outside the yellow palette.
                                Image(systemName: "checkmark.seal.fill")
                                    .font(.subheadline)
                                    .foregroundStyle(Color(red: 0.25, green: 0.56, blue: 0.96))
                                    .accessibilityLabel("Verified")
                            }
                        }
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

                bioSection

                verificationSection
            }
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
                                .foregroundStyle(MorpheTheme.accent)
                        }
                    }
                }
                .frame(width: 72, height: 72)
                .clipShape(Circle())
                .overlay(Circle().stroke(MorpheTheme.accent.opacity(0.5), lineWidth: 1.5))

                Image(systemName: "camera.fill")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.black)
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
        let name = isCoach ? store.coachProfile.name : store.profileShowcase.displayName
        let parts = name.split(separator: " ").prefix(2)
        let initials = parts.compactMap(\.first).map(String.init).joined()
        return initials.isEmpty ? "M" : initials.uppercased()
    }

    /// Bio: shown for everyone, editable in place for athletes (a coach's
    /// public blurb is their headline, edited in the coach workspace).
    @ViewBuilder
    private var bioSection: some View {
        if !isCoach {
            VStack(alignment: .leading, spacing: 8) {
                if isEditingBio {
                    TextField("Say something about your training…", text: $bioDraft, axis: .vertical)
                        .lineLimit(2...5)
                        .textFieldStyle(MorpheFieldStyle())
                    HStack(spacing: 12) {
                        Button("Save") { saveBio() }
                            .buttonStyle(.plain)
                            .foregroundStyle(MorpheTheme.accent)
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

    /// The verification strip under the identity: ask → pending → badge.
    /// Honest copy throughout — a human reviews; nothing is auto-granted.
    @ViewBuilder
    private var verificationSection: some View {
        Divider().overlay(Color.white.opacity(0.08))

        if store.isVerifiedUser {
            HStack(spacing: 8) {
                Image(systemName: "checkmark.seal.fill")
                    .foregroundStyle(Color(red: 0.25, green: 0.56, blue: 0.96))
                Text("Verified — reviewed by the Morphe team.")
                    .font(.caption)
                    .foregroundStyle(MorpheTheme.textSecondary)
            }
        } else {
            switch store.verificationRequestStatus {
            case .pending:
                HStack(spacing: 8) {
                    Image(systemName: "hourglass")
                        .foregroundStyle(MorpheTheme.warning)
                    Text("Verification under review — your badge appears once the Morphe team approves it.")
                        .font(.caption)
                        .foregroundStyle(MorpheTheme.textSecondary)
                }
            case .none, .declined:
                VStack(alignment: .leading, spacing: 8) {
                    if store.verificationRequestStatus == .declined {
                        Text("Your last request wasn't approved. You can try again with a clearer selfie.")
                            .font(.caption)
                            .foregroundStyle(MorpheTheme.warning)
                    }
                    Text("Get the blue check: take a quick selfie and the Morphe team confirms you're a real person — not a bot.")
                        .font(.caption)
                        .foregroundStyle(MorpheTheme.textSecondary)
                    Button {
                        showVerificationCamera = true
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "checkmark.seal")
                            Text(store.isSubmittingVerification ? "Sending…" : "Get Verified")
                        }
                        .font(.caption.weight(.semibold))
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(Color(red: 0.25, green: 0.56, blue: 0.96))
                    .disabled(store.isSubmittingVerification)
                }
            }
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
    private static func processedProfilePhoto(_ raw: Data) -> Data? {
        guard let image = UIImage(data: raw) else { return nil }
        let maxSide: CGFloat = 512
        let scale = min(1, maxSide / max(image.size.width, image.size.height))
        let size = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let renderer = UIGraphicsImageRenderer(size: size)
        let resized = renderer.image { _ in image.draw(in: CGRect(origin: .zero, size: size)) }
        return resized.jpegData(compressionQuality: 0.75)
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

                Divider().overlay(Color.white.opacity(0.08))

                // Accent color — picked once in onboarding, now editable
                // anytime. Gold is the brand default; the others personalize
                // the whole app's accent pair.
                VStack(alignment: .leading, spacing: 8) {
                    Text("Accent")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(MorpheTheme.textMuted)
                    HStack(spacing: 0) {
                        ForEach(AccentPalette.allCases) { palette in
                            accentDot(for: palette)
                                .frame(maxWidth: .infinity)
                        }
                    }
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

    /// The dot shows the color the palette actually resolves to — `.gold`
    /// means the brand-yellow pair, not the muted legacy gold swatch.
    private func accentDotColor(for palette: AccentPalette) -> Color {
        palette == .gold ? MorpheTheme.brandYellow : MorpheTheme.colors(for: palette).primary
    }

    private func accentDot(for palette: AccentPalette) -> some View {
        let isSelected = store.profileShowcase.accentPalette == palette
        return Button {
            // Store contract: sets profileShowcase.accentPalette, calls
            // MorpheTheme.apply(accentPalette:), and persists the profile
            // snapshot — the same pathway onboarding's choice rides.
            store.updateAccentPalette(palette)
            Haptics.impact(.light)
        } label: {
            ZStack {
                Circle()
                    .fill(accentDotColor(for: palette))
                    .frame(width: 28, height: 28)
                if isSelected {
                    Circle()
                        .stroke(.white, lineWidth: 2)
                        .frame(width: 36, height: 36)
                    Image(systemName: "checkmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.black)
                }
            }
            .frame(width: 44, height: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(palette.rawValue) accent")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
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
                    Text("Training Snapshot")
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
                    Text("Coaching Snapshot")
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
                    Text("Your Coaching Tools")
                        .font(.headline)
                        .foregroundStyle(.white)
                    Text("Build programs, track clients, and run outreach from the coach tabs. Connecting real clients turns on with your account backend.")
                        .font(.subheadline)
                        .foregroundStyle(MorpheTheme.textSecondary)
                }
            }

            // Un-gated in v1: the business view now leads with REAL
            // appointments and hides its demo commerce internally behind
            // the multi-user flag — the schedule must be reachable today.
            Button {
                    showBusiness = true
                } label: {
                    GlassCard {
                        HStack(spacing: 12) {
                            Image(systemName: "calendar.badge.clock")
                                .font(.headline)
                                .foregroundStyle(MorpheTheme.accent)
                                .frame(width: 44, height: 44)
                                .background(RoundedRectangle(cornerRadius: MorpheTheme.radius, style: .continuous).fill(MorpheTheme.panelStrong))
                            VStack(alignment: .leading, spacing: 3) {
                                Text("Schedule")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(.white)
                                Text("Appointments with your clients — bookings and rates arrive with payments.")
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
