import SwiftUI
import PhotosUI

struct ProfileView: View {
    @Environment(MorpheAppStore.self) private var store
    @State private var isEditingName = false
    @State private var isEnteringCoachCode = false
    @State private var coachCodeDraft = ""
    @State private var showTermsSheet = false
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
    @State private var showSignOutConfirm = false
    @State private var showUnsavedPrompt = false
    @State private var showDeleteAccountConfirm = false
    @State private var isDeletingAccount = false
    /// The generated export file, presented in the system share sheet.
    private struct ExportFile: Identifiable {
        let url: URL
        var id: String { url.absoluteString }
    }
    @State private var exportFile: ExportFile?
    @State private var showPaywall = false

    private var isCoach: Bool {
        store.selectedRole == .coach
    }

    /// Hoisted from AthleteProfileBody (audit 5, P1-5): as child @State the
    /// unsaved-edit guard couldn't see a typed-but-unsaved weight, so Done
    /// or a swipe-down silently dropped it.
    @State private var weightDraft = ""

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 16) {
                identityCard
                if isCoach {
                    CoachProfileBody(store: store)
                } else {
                    AthleteProfileBody(store: store, weightDraft: $weightDraft)
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
        // A typed-but-unsaved weight counts too — it feeds the Progress
        // chart and nutrition targets, so it must never vanish silently.
        if !weightDraft.trimmingCharacters(in: .whitespaces).isEmpty {
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
        let weight = weightDraft.trimmingCharacters(in: .whitespaces)
        if !weight.isEmpty {
            store.updateBodyMetrics(height: store.clientProfile.height, weight: weight)
            weightDraft = ""
        }
    }

    private func discardAllEdits() {
        isEditingName = false
        isEditingUsername = false
        isEditingInjuries = false
        isEditingBio = false
        isEditingTargets = false
        weightDraft = ""
    }

    /// Everything about the user's training identity, editable in place —
    /// onboarding stays lean, so this is where these details live.
    private var detailsCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 14) {
                Text("Your Details")
                    .font(.headline)
                    .foregroundStyle(MorpheTheme.textPrimary)

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
                    .foregroundStyle(MorpheTheme.textPrimary)

                if isEditingTargets {
                    VStack(alignment: .leading, spacing: 10) {
                        targetField("30-day", placeholder: "Your 30-day goal", text: $physicalTargetDraft)
                        targetField("60-day", placeholder: "Your 60-day goal", text: $weightTargetDraft)
                        targetField("90-day", placeholder: "Your 90-day goal", text: $deadlineTargetDraft)
                        HStack(spacing: 12) {
                            Button("Save") { saveTargets() }
                                .buttonStyle(.plain)
                                .foregroundStyle(MorpheTheme.accentText)
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
                                .foregroundStyle(MorpheTheme.textPrimary)
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
                            .foregroundStyle(MorpheTheme.accentText)
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
                                .foregroundStyle(MorpheTheme.accentText)
                        }
                    }
                }
                .frame(width: 72, height: 72)
                .clipShape(Circle())
                .overlay(Circle().stroke(MorpheTheme.accent.opacity(0.5), lineWidth: 1.5))

                Image(systemName: "camera.fill")
                    .scaledFont(size: 11, weight: .bold)
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

    /// The verification strip under the identity: ask → pending → badge.
    /// Honest copy throughout — a human reviews; nothing is auto-granted.
    @ViewBuilder
    private var verificationSection: some View {
        Divider().overlay(MorpheTheme.strokeSubtle)

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

    private func preferenceToggleRow(title: String, caption: String, isOn: Binding<Bool>) -> some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .foregroundStyle(MorpheTheme.textPrimary)
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

    private var settingsCard: some View {
        @Bindable var store = store
        return GlassCard {
            VStack(alignment: .leading, spacing: 14) {
                Text("Settings")
                    .font(.headline)
                    .foregroundStyle(MorpheTheme.textPrimary)

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
                        value: isCoach ? store.coachProfile.name : store.profileShowcase.displayName
                    ) {
                        nameDraft = isCoach ? store.coachProfile.name : store.profileShowcase.displayName
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

                Divider().overlay(MorpheTheme.strokeSubtle)

                HStack {
                    Text("Appearance")
                        .foregroundStyle(MorpheTheme.textPrimary)
                    Spacer()
                    Picker("Appearance", selection: $store.appearanceIsLight) {
                        Text("Dark").tag(false)
                        Text("Light").tag(true)
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 140)
                }

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

                Divider().overlay(MorpheTheme.strokeSubtle)

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
                        ForEach(AccentPalette.allCases) { palette in
                            accentDot(for: palette)
                        }
                    }
                    // The Custom dot's editor: any color at all. Applies
                    // live and persists with the profile (cloud included).
                    if store.profileShowcase.accentPalette == .custom {
                        ColorPicker(selection: customAccentBinding, supportsOpacity: false) {
                            Text("Pick your color")
                                .font(.subheadline)
                                .foregroundStyle(MorpheTheme.textPrimary)
                        }
                    }
                }

                Divider().overlay(MorpheTheme.strokeSubtle)

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
                .task { await store.refreshReferralCount() }

                if !isCoach {
                    Divider().overlay(MorpheTheme.strokeSubtle)

                    // Live-session preferences — both persisted per profile.
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

                    if FeatureFlags.socialFeedEnabled {
                    preferenceToggleRow(
                        title: "Auto-share workouts",
                        caption: "Posts an honest recap to the feed when you log a session. Each session shows a toggle to keep it private.",
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
                        caption: "Your accent color tints your name and story bubble for others. Off posts in the default gold.",
                        isOn: $store.postAccentIdentity
                    )
                    }

                    Divider().overlay(MorpheTheme.strokeSubtle)

                }
                // Both roles from here (profile audit: coaches lost 14 rows
                // including data export): reminders, board, data, backup.
                    // The audit found five reminder kinds and no off switch.
                    // One master toggle — off cancels everything pending.
                    preferenceToggleRow(
                        title: "Reminders",
                        caption: "The 5pm session nudge, streak-risk heads-up, weekly recap, and board updates. Off silences all of them.",
                        isOn: $store.remindersEnabled
                    )

                    Divider().overlay(MorpheTheme.strokeSubtle)

                    // The board publishes your real name — and scores post on
                    // every log in EITHER role, so the off-switch renders for
                    // both (audit 5, P1-4: a coach could never leave).
                    preferenceToggleRow(
                        title: "Weekly board",
                        caption: "Ranks your logged sessions against other athletes under your name. Leaving removes your row immediately.",
                        isOn: Binding(
                            get: { store.leaderboardOptIn },
                            set: { $0 ? store.joinWeeklyBoard() : store.leaveWeeklyBoard() }
                        )
                    )

                    // A coach's invite code used to work ONLY during
                    // onboarding — existing athletes had nowhere to type it.
                    // (Athlete-only: a coach doesn't join a coach.)
                    if !isCoach, store.linkedCoachUid.isEmpty {
                        Divider().overlay(MorpheTheme.strokeSubtle)

                        if isEnteringCoachCode {
                            HStack(spacing: 8) {
                                TextField("Coach code (e.g. 7KQ4TX)", text: $coachCodeDraft)
                                    .textFieldStyle(MorpheFieldStyle())
                                    .textInputAutocapitalization(.characters)
                                    .autocorrectionDisabled()
                                Button("Join") {
                                    let code = coachCodeDraft.trimmingCharacters(in: .whitespacesAndNewlines)
                                    guard !code.isEmpty else { return }
                                    Task {
                                        await store.claimCoachInvite(code: code)
                                        coachCodeDraft = ""
                                        isEnteringCoachCode = false
                                    }
                                }
                                .buttonStyle(.plain)
                                .foregroundStyle(MorpheTheme.accentText)
                                Button("Cancel") { isEnteringCoachCode = false }
                                    .buttonStyle(.plain)
                                    .foregroundStyle(MorpheTheme.textMuted)
                            }
                        } else {
                            settingsRow("Coach code", value: "Have one? Join your coach") {
                                isEnteringCoachCode = true
                            }
                        }
                    }

                    Divider().overlay(MorpheTheme.strokeSubtle)

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

                    // Athlete-only: the check-in prefill and the coach-share
                    // summary have no coach-side surface.
                    if !isCoach {
                    Divider().overlay(MorpheTheme.strokeSubtle)

                    // Read-only and honest about its limits: Apple never
                    // reveals whether a sleep READ was granted, so this just
                    // pre-fills when data comes back and stays quiet when not.
                    preferenceToggleRow(
                        title: "Sleep from Health",
                        caption: "Pre-fills the check-in's sleep slider from last night's Apple Health sleep. You can always adjust it.",
                        isOn: Binding(
                            get: { store.healthSleepEnabled },
                            set: { newValue in Task { await store.setHealthSleepPrefill(enabled: newValue) } }
                        )
                    )

                    // Only renders once a coach link exists (claimed invite
                    // or an existing coach thread) — no dead toggle.
                    if !store.linkedCoachUid.isEmpty {
                        Divider().overlay(MorpheTheme.strokeSubtle)

                        preferenceToggleRow(
                            title: "Share with coach",
                            caption: "\(store.linkedCoachName.isEmpty ? "Your coach" : store.linkedCoachName) sees a live summary — streak, weekly volume, recent sessions, PRs, readiness. Turning it off deletes it instantly.",
                            isOn: Binding(
                                get: { store.coachShareEnabled },
                                set: { store.setCoachShare(enabled: $0) }
                            )
                        )
                    }
                    }

                    Divider().overlay(MorpheTheme.strokeSubtle)

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
                                Text("Programs, advanced analytics, coach tools. Your data stays free forever.")
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

                    // Athlete-only tail: training-day targets and injuries
                    // configure the athlete's Today/Progress surfaces.
                    if !isCoach {
                    Divider().overlay(MorpheTheme.strokeSubtle)

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

                }

                Divider().overlay(MorpheTheme.strokeSubtle)

                // About: the terms the user agreed to, the privacy policy,
                // a human to email, and which build they're on — table
                // stakes the audit found missing entirely.
                VStack(alignment: .leading, spacing: 10) {
                    Text("ABOUT")
                        .font(MorpheTheme.microLabel(10))
                        .tracking(1.6)
                        .foregroundStyle(MorpheTheme.textMuted)

                    Button("Terms of Use") { showTermsSheet = true }
                        .buttonStyle(.plain)
                        .foregroundStyle(MorpheTheme.accentText)
                        .frame(minHeight: 32)
                        .sheet(isPresented: $showTermsSheet) {
                            TermsGateView(readOnly: true)
                        }

                    Link("Privacy Policy", destination: URL(string: "https://lucasdilley07-png.github.io/Morphe/")!)
                        .foregroundStyle(MorpheTheme.accentText)
                        .frame(minHeight: 32)

                    Link("Contact Support", destination: URL(string: "mailto:lucasdilley.07@gmail.com")!)
                        .foregroundStyle(MorpheTheme.accentText)
                        .frame(minHeight: 32)

                    Text("Morphe \(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0") (\(Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"))")
                        .font(.caption)
                        .foregroundStyle(MorpheTheme.textMuted)
                }

                Divider().overlay(MorpheTheme.strokeSubtle)

                if FeatureFlags.accountsEnabled {
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
                        Text("This deletes your sign-in, cloud backup, weight history, and @username permanently — there is no undo. Posts and comments you shared stay on the feed unless you delete them first (long-press any of yours).")
                    }
                }
            }
        }
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

    /// The dot shows the color the palette actually resolves to — `.gold`
    /// means the brand-yellow pair, not the muted legacy gold swatch.
    private func accentDotColor(for palette: AccentPalette) -> Color {
        palette == .gold ? MorpheTheme.brandYellow : MorpheTheme.colors(for: palette).primary
    }

    /// ColorPicker ↔ stored hex. Setting routes through the store so the
    /// theme re-applies live and the profile snapshot persists.
    private var customAccentBinding: Binding<Color> {
        Binding(
            get: {
                MorpheTheme.color(fromHex: store.profileShowcase.customAccentHex)
                    ?? MorpheTheme.brandYellow
            },
            set: { store.updateCustomAccent(hex: MorpheTheme.hex(from: $0)) }
        )
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
                    .fill(accentDotColor(for: palette))
                    .frame(width: 28, height: 28)
                    .opacity(isUnlocked ? 1 : 0.35)
                if isSelected {
                    Circle()
                        .stroke(MorpheTheme.textPrimary, lineWidth: 2)
                        .frame(width: 36, height: 36)
                    Image(systemName: "checkmark")
                        .scaledFont(size: 12, weight: .bold)
                        .foregroundStyle(.black)
                } else if !isUnlocked {
                    Image(systemName: "lock.fill")
                        .scaledFont(size: 10, weight: .bold)
                        .foregroundStyle(.white.opacity(0.85))
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
                : "\(palette.rawValue) accent, unlocks at level \(store.paletteUnlockLevel(palette))")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private func settingsRow(_ title: String, value: String, showEdit: Bool = true, onEdit: @escaping () -> Void) -> some View {
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
                Button("Edit", action: onEdit)
                    .buttonStyle(.plain)
                    .foregroundStyle(MorpheTheme.accentText)
                    .accessibilityLabel("Edit \(title.lowercased())")
            }
        }
    }
}

/// Athlete profile = strictly training: snapshot, focus, recent work, records.
private struct AthleteProfileBody: View {
    let store: MorpheAppStore
    /// Owned by ProfileView so its unsaved-edit guard can see it.
    @Binding var weightDraft: String

    var body: some View {
        Group {
            // WEIGHT leads (profile audit): the app's only weight-entry
            // point, feeding the Progress chart and nutrition targets — it
            // was a bare unlabeled field six cards down.
            GlassCard {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Weight")
                        .font(.headline)
                        .foregroundStyle(MorpheTheme.textPrimary)
                    if let last = store.bodyWeightHistory.last {
                        Text("\(store.weightUnit.format(store.weightUnit == .kilograms ? last.weightLb * 0.45359237 : last.weightLb)) · logged \(last.date.formatted(.relative(presentation: .named)))")
                            .font(.caption)
                            .foregroundStyle(MorpheTheme.textSecondary)
                    } else {
                        Text("Log it once and the Progress chart + nutrition targets personalize from it.")
                            .font(.caption)
                            .foregroundStyle(MorpheTheme.textSecondary)
                    }
                    TextField(store.weightUnit == .kilograms ? "e.g. 77" : "e.g. 170", text: $weightDraft)
                        .textFieldStyle(MorpheFieldStyle())
                        .keyboardType(.decimalPad)
                        .submitLabel(.done)
                        .onSubmit { saveWeight() }
                    if !weightDraft.trimmingCharacters(in: .whitespaces).isEmpty {
                        Button("Save Weight") { saveWeight() }
                            .buttonStyle(PrimaryCTAButtonStyle(accent: MorpheTheme.accent))
                    }
                }
            }

            // Training history lives in Progress — one door, not four
            // duplicate cards (Snapshot/Focus/Logs/PRs all re-rendered what
            // Home and Progress already own).
            Button {
                store.closeClientProfile()
                store.openProgress()
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

    private func saveWeight() {
        let clean = weightDraft.trimmingCharacters(in: .whitespaces)
        guard !clean.isEmpty else { return }
        store.updateBodyMetrics(height: store.clientProfile.height, weight: clean)
        weightDraft = ""
    }
}

/// Coach profile = coaching identity + a snapshot of the REAL roster
/// (managed clients + live overview — same sources as the dashboard).
private struct CoachProfileBody: View {
    let store: MorpheAppStore
    @State private var isEditingHeadline = false
    @State private var headlineDraft = ""

    var body: some View {
        Group {
            // PUBLIC IDENTITY first (profile audit): what a prospective
            // client sees when they look this coach up — with the headline
            // finally editable (it had no editor anywhere).
            GlassCard {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Your Coach Card")
                        .font(.headline)
                        .foregroundStyle(MorpheTheme.textPrimary)
                    Text(store.coachProfile.specialty)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(MorpheTheme.accentText)
                    if isEditingHeadline {
                        TextField("Your headline…", text: $headlineDraft, axis: .vertical)
                            .lineLimit(1...3)
                            .textFieldStyle(MorpheFieldStyle())
                        HStack(spacing: 12) {
                            Button("Save") {
                                store.updateCoachHeadline(headlineDraft)
                                isEditingHeadline = false
                            }
                            .buttonStyle(.plain)
                            .foregroundStyle(MorpheTheme.accentText)
                            Button("Cancel") { isEditingHeadline = false }
                                .buttonStyle(.plain)
                                .foregroundStyle(MorpheTheme.textMuted)
                        }
                        .frame(minHeight: 32)
                    } else {
                        Text(store.coachProfile.headline)
                            .foregroundStyle(MorpheTheme.textSecondary)
                        Button("Edit Headline") {
                            headlineDraft = store.coachProfile.headline
                            isEditingHeadline = true
                        }
                        .buttonStyle(.plain)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(MorpheTheme.accentText)
                        .frame(minHeight: 32)
                    }
                }
            }

            GlassCard {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Specialties")
                        .font(.headline)
                        .foregroundStyle(MorpheTheme.textPrimary)
                    // Sports only — the training-style tokens were demo
                    // seed data nobody picked (profile audit honesty fix);
                    // real styles return when a real editor exists.
                    WrapStack(spacing: 8) {
                        ForEach(store.coachProfile.sports) { sport in
                            SelectionToken(text: sport.shortTitle, color: MorpheTheme.color(for: sport))
                        }
                    }
                }
            }

            // The coach's OWN training, demoted below the coaching identity
            // (it led the screen before) — still real, still theirs.
            if !store.currentAthleteWorkoutLogs.isEmpty {
                AthleteRecentLogsCard(logs: Array(store.currentAthleteWorkoutLogs.prefix(3)))
            }
            // Coaching Tools prose card and the Schedule row are gone:
            // onboarding copy doesn't live in settings, and Schedule already
            // has its canonical one-tap door on the coach Home.
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
                    paywallRow("person.2.badge.gearshape", "Coach tools — rosters, programs, and client insights")
                }

                Text("Your data, your export, and every safety feature stay free — always.")
                    .font(.caption)
                    .foregroundStyle(MorpheTheme.textMuted)

                if premium.hasEntitlement {
                    Text("You're Pro. Thanks for backing honest training.")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(MorpheTheme.accentText)
                } else if premium.products.isEmpty {
                    Text("Plans are loading…")
                        .font(.caption)
                        .foregroundStyle(MorpheTheme.textMuted)
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

                Button("Restore Purchases") {
                    Task { await premium.restore() }
                }
                .buttonStyle(SecondaryCTAButtonStyle())
                .frame(maxWidth: .infinity)
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
