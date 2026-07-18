import SwiftUI
import Speech
import AVFoundation

/// Terms of use + liability waiver. Shown once after onboarding (and on every
/// reopen until accepted). Agree → remembered forever, locally and in the
/// cloud backup. Disagree → signed out; the gate returns on the next sign-in.
struct TermsGateView: View {
    @Environment(MorpheAppStore.self) private var store
    @State private var showDeclineConfirm = false

    private static let sections: [(title: String, body: String)] = [
        ("Not medical advice",
         "Morphe provides general fitness content and tracking tools. It is not medical advice, diagnosis, or treatment, and no part of the app creates a provider–patient relationship. Consult a physician before starting this or any exercise program, especially if you have a medical condition, injury, or are pregnant."),
        ("You assume the risk",
         "Exercise carries inherent risks, including serious injury. You are responsible for training within your own limits, using equipment safely, and stopping immediately if you feel pain, dizziness, or discomfort. You voluntarily assume all risks arising from your use of Morphe."),
        ("Limitation of liability",
         "To the maximum extent permitted by law, Morphe and its creators are not liable for any injury, loss, or damage — direct or indirect — arising from your use of the app, its workouts, its recommendations, or training sessions with other users, whether in person, virtual, or in a group."),
        ("Form Check and AI features",
         "Camera-based form feedback and AI-generated guidance are automated aids, not a substitute for qualified, in-person coaching. They can be wrong. You remain responsible for your own technique and safety."),
        ("Your data",
         "Your profile and training history are stored on your device and backed up to your account so you can restore them. Don't share your account credentials."),
        ("As is",
         "Morphe is provided \"as is\", without warranties of any kind. Features may change, break, or be removed as the app evolves.")
    ]

    var body: some View {
        VStack(spacing: 0) {
            ScrollView(showsIndicators: true) {
                VStack(alignment: .leading, spacing: 16) {
                    Text("TERMS OF USE")
                        .font(MorpheTheme.microLabel())
                        .tracking(1.4)
                        .foregroundStyle(MorpheTheme.accent)
                        .padding(.top, 24)

                    Text("Before you train")
                        .font(.title.weight(.bold))
                        .foregroundStyle(.white)

                    Text("Quick but important: read and accept these terms to use Morphe.")
                        .font(.subheadline)
                        .foregroundStyle(MorpheTheme.textSecondary)

                    ForEach(Self.sections, id: \.title) { section in
                        GlassCard {
                            VStack(alignment: .leading, spacing: 8) {
                                Text(section.title)
                                    .font(.headline)
                                    .foregroundStyle(.white)
                                Text(section.body)
                                    .font(.subheadline)
                                    .foregroundStyle(MorpheTheme.textSecondary)
                            }
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 16)
            }

            VStack(spacing: 10) {
                Button("I Agree") {
                    store.acceptTerms()
                }
                .buttonStyle(PrimaryCTAButtonStyle(accent: MorpheTheme.accent))

                Button("I Disagree") {
                    showDeclineConfirm = true
                }
                .buttonStyle(SecondaryCTAButtonStyle())
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .background(.black.opacity(0.35))
        }
        .alert("Decline the terms?", isPresented: $showDeclineConfirm) {
            Button("Sign Out", role: .destructive) {
                store.declineTerms()
            }
            Button("Go Back", role: .cancel) {}
        } message: {
            Text("Morphe can't be used without accepting the terms. You'll be signed out — your data stays backed up to your account.")
        }
    }
}

struct RootView: View {
    @Environment(MorpheAppStore.self) private var store

    /// True only when the real app shell is showing — matches the routing in
    /// `body` (past the launch sequence, the auth wall, and onboarding).
    private var isInAppShell: Bool {
        if store.isShowingLaunchSequence { return false }
        if FeatureFlags.accountsEnabled && store.authUser == nil { return false }
        if !store.hasCompletedOnboarding { return false }
        if store.needsTermsAcceptance { return false }
        if store.showWelcomeExperience { return false }
        return true
    }

    var body: some View {
        @Bindable var store = store
        return ZStack {
            PremiumBackground()

            Group {
                if store.isShowingLaunchSequence {
                    LaunchSequenceView()
                } else if FeatureFlags.accountsEnabled && store.authUser == nil {
                    AuthView()
                } else if !store.hasCompletedOnboarding {
                    OnboardingFlowView()
                } else if store.needsTermsAcceptance {
                    // Terms gate: the app is unreachable until they agree, on
                    // this open and every reopen. Declining signs out.
                    TermsGateView()
                } else {
                    AppShell {
                        Group {
                            // A coach account lands in the coach workspace; everyone
                            // else gets the athlete experience. (Role comes from the
                            // signed-in account once accounts are enabled.)
                            if (FeatureFlags.accountsEnabled || FeatureFlags.multiUserEnabled),
                               store.selectedRole == .coach {
                                CoachLayout {
                                    CoachDashboardView()
                                }
                            } else {
                                ClientLayout {
                                    ClientExperienceShell()
                                }
                            }
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
            }
        }
        .preferredColorScheme(store.selectedAppearance)
        .sheet(item: $store.selectedExercise) { exercise in
            ExerciseDetailView(exercise: exercise)
        }
        .sheet(item: $store.pendingPartnerSessionPost, onDismiss: {
            store.dismissPendingPartnerSessionPost()
        }) { draft in
            NavigationStack {
                PartnerSessionPostSheet(draft: draft)
                    .environment(store)
            }
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
            .background(PremiumBackground())
        }
        .sheet(item: $store.selectedNetworkProfile, onDismiss: {
            store.closeNetworkProfile()
        }) { profile in
            NavigationStack {
                NetworkProfilePreviewSheet(profile: profile)
                    .environment(store)
            }
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
            .background(PremiumBackground())
        }
        .sheet(isPresented: $store.showClientProfile, onDismiss: {
            store.closeClientProfile()
        }) {
            NavigationStack {
                // ProfileView owns its Done button: it has to check for
                // unsaved edits (drafts live in its @State) before closing.
                ProfileView()
                    .environment(store)
            }
            .background(PremiumBackground())
            .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $store.showUniversalSearch) {
            NavigationStack {
                UniversalSearchSheet()
                    .environment(store)
            }
            .background(PremiumBackground())
        }
        .sheet(isPresented: $store.showQuickAdd) {
            NavigationStack {
                QuickAddSheet()
                    .environment(store)
            }
            .background(PremiumBackground())
        }
        .fullScreenCover(isPresented: $store.showAIAgent) {
            NavigationStack {
                MorpheAIAgentSheet()
                    .environment(store)
            }
            // Chat deliberately never queues the session-work gate (it
            // declines with an honest reply instead), so no dialog host here —
            // sheet teardown writing through the shared binding could cancel
            // a pending change.
            .background(PremiumBackground())
        }
        .sheet(isPresented: $store.showWelcomeExperience) {
            WelcomeExperienceView()
                .environment(store)
        }
        .sessionWorkGateDialog()
        .alert("Save more workouts to switch", isPresented: $store.showSwitchNeedsSavedWorkouts) {
            Button("Open Discover") {
                store.selectedClientTab = .discover
            }
            Button("OK", role: .cancel) {}
        } message: {
            Text("Switch rotates between the workouts you've saved. Save some from Discover — or build your own in Train — and they'll show up here.")
        }
        .overlay(alignment: .top) {
            VStack(spacing: 10) {
                if let toast = store.toastMessage {
                    ToastBanner(text: toast)
                        .padding(.top, 12)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }

                if let celebration = store.celebration {
                    CelebrationOverlay(moment: celebration)
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .padding(.horizontal, 20)
        }
        .overlay(alignment: .bottomTrailing) {
            // Only in the real app shell — never over the sign-in or onboarding
            // screens (a signed-out account still has hasCompletedOnboarding set).
            if isInAppShell {
                FloatingAIAgentButton()
                    .padding(.trailing, 20)
                    .padding(.bottom, 102)
                    .transition(.move(edge: .trailing).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.25), value: store.selectedRole)
        .animation(.easeInOut(duration: 0.25), value: store.selectedClientTab)
        .animation(.easeInOut(duration: 0.25), value: store.selectedCoachTab)
        .animation(.easeInOut(duration: 0.25), value: store.toastMessage)
        .animation(.easeInOut(duration: 0.25), value: store.celebration)
    }
}

private struct PartnerSessionPostSheet: View {
    @Environment(MorpheAppStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    let draft: PartnerSessionPostDraft

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 16) {
                SectionTitleView(
                    title: "Partner Session Ready",
                    subtitle: "Morphe turned your shared session into a clean post card. Share it, save it, or skip it."
                )

                GlassCard {
                    VStack(alignment: .leading, spacing: 14) {
                        HStack(alignment: .top, spacing: 12) {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("🔥 \(store.clientProfile.name)")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(.white)
                                Text("with \(draft.partnerAvatar) \(draft.partnerName)")
                                    .font(.caption)
                                    .foregroundStyle(MorpheTheme.textSecondary)
                            }

                            Spacer()

                            StatusBadge(text: "Partner Session", color: MorpheTheme.warning)
                        }

                        Text(draft.workoutTitle)
                            .font(.title3.weight(.bold))
                            .foregroundStyle(.white)

                        Text(draft.detail)
                            .font(.subheadline)
                            .foregroundStyle(MorpheTheme.textSecondary)

                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 2), spacing: 8) {
                            MetricPill(label: "Mode", value: draft.mode.rawValue)
                            MetricPill(label: "Minutes", value: "\(draft.durationMinutes)")
                            MetricPill(label: "XP bonus", value: "+\(draft.xpBonus)")
                            MetricPill(label: "Partner streak", value: "\(draft.partnerStreak) days")
                        }

                        if !draft.tags.isEmpty {
                            WrapStack(spacing: 8) {
                                ForEach(draft.tags, id: \.self) { tag in
                                    StatusBadge(text: tag, color: MorpheTheme.accentAlt)
                                }
                            }
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            Text("Shared challenge")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(MorpheTheme.textMuted)
                            Text(draft.miniChallenge)
                                .font(.subheadline)
                                .foregroundStyle(.white)
                        }
                        .padding(12)
                        .background(
                            RoundedRectangle(cornerRadius: MorpheTheme.radius, style: .continuous)
                                .fill(MorpheTheme.panel)
                                .overlay(
                                    RoundedRectangle(cornerRadius: MorpheTheme.radius, style: .continuous)
                                        .stroke(MorpheTheme.stroke.opacity(0.8), lineWidth: 1)
                                )
                        )
                    }
                }

                HStack(spacing: 12) {
                    Button("Not Now") {
                        store.dismissPendingPartnerSessionPost()
                        dismiss()
                    }
                    .buttonStyle(SecondaryCTAButtonStyle())

                    Button("Save Recap") {
                        store.savePendingPartnerSessionRecap()
                        dismiss()
                    }
                    .buttonStyle(SecondaryCTAButtonStyle())

                    Button("Share Post") {
                        store.sharePendingPartnerSessionPost()
                        dismiss()
                    }
                    .buttonStyle(PrimaryCTAButtonStyle(accent: MorpheTheme.accent))
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 40)
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Done") {
                    store.dismissPendingPartnerSessionPost()
                    dismiss()
                }
                .foregroundStyle(.white)
            }
        }
    }
}

private struct ClientExperienceShell: View {
    @Environment(MorpheAppStore.self) private var store

    var body: some View {
        @Bindable var store = store
        return TabView(selection: $store.selectedClientTab) {
            // Each screen's identity is keyed off tabResetKey, so tapping the
            // tab icon rebuilds it at its root (top of page, drill-ins
            // closed). Train is deliberately NOT keyed — a tab tap must never
            // reset a live session or running rest timer.
            HomeView()
                .id(store.tabResetKey("today"))
                .tag(ClientTab.today)

            WorkoutView()
                .tag(ClientTab.train)

            DiscoverScreenView()
                .id(store.tabResetKey("discover"))
                .tag(ClientTab.discover)

            if FeatureFlags.multiUserEnabled {
                CommunityView()
                    .tag(ClientTab.community)
            }

            ProgressScreenView()
                .id(store.tabResetKey("hub"))
                .tag(ClientTab.hub)

            MoreView()
                .id(store.tabResetKey("more"))
                .tag(ClientTab.more)
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        .safeAreaInset(edge: .top) {
            ClientPinnedHeader()
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .background(
                    ZStack {
                        PremiumBackground()
                        LinearGradient(
                            colors: [
                                MorpheTheme.ink.opacity(0.96),
                                MorpheTheme.ink.opacity(0.88),
                                .clear
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    }
                    .ignoresSafeArea()
                )
        }
        .safeAreaInset(edge: .bottom) {
            BottomTabNavigation(items: ClientTab.visibleCases, selected: store.selectedClientTab) { tab in
                store.selectedClientTab = tab
                // Tapping the icon always lands at the top of that tab's
                // first page.
                store.popTabToRoot(tab.rawValue)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 8)
        }
    }
}

private struct ClientPinnedHeader: View {
    @Environment(MorpheAppStore.self) private var store

    var body: some View {
        HStack(spacing: 12) {
            Button {
                store.openClientProfile()
            } label: {
                HStack(spacing: 10) {
                    MorpheAvatarView(avatar: store.profileShowcase.avatar, size: 40)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(store.profileShowcase.displayName)
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(.white)
                        Text("@\(store.profileShowcase.username)")
                            .font(.caption)
                            .foregroundStyle(MorpheTheme.textSecondary)
                    }
                }
            }
            .buttonStyle(.plain)

            Spacer()

            HeaderCircleButton(systemImage: "plus", label: "Quick add") {
                store.openQuickAdd()
            }

            // Messaging is a v2 (multi-user) surface, hidden in v1.
            if FeatureFlags.multiUserEnabled {
                HeaderCircleButton(systemImage: "bubble.left.and.bubble.right.fill", label: "Messages") {
                    store.openCommunity(.contact)
                }
            }
        }
        .padding(.horizontal, 2)
        .padding(.vertical, 10)
        // Flat header — the hairline below is the only chrome.
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Color.white.opacity(0.08))
                .frame(height: 1)
        }
    }
}

struct DemoBrandHeader: View {
    @Environment(MorpheAppStore.self) private var store

    private var role: AppRole { store.selectedRole }

    private var displayName: String {
        role == .coach ? store.coachProfile.name : store.profileShowcase.displayName
    }

    private var handle: String {
        role == .coach ? store.coachProfile.username : store.profileShowcase.username
    }

    private var title: String {
        role == .coach ? "Coach workspace" : "Your training OS"
    }

    private var subtitle: String {
        role == .coach ? "Inbox, athletes, and action in one clean loop." : "Simple enough to use every day, smart enough to feel personal."
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Button {
                    store.openClientProfile()
                } label: {
                    HStack(spacing: 10) {
                        MorpheAvatarView(avatar: store.profileShowcase.avatar, size: 42)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(displayName)
                                .font(.subheadline.weight(.bold))
                                .foregroundStyle(.white)
                            Text("@\(handle) • \(role == .coach ? "Coach" : "Athlete")")
                                .font(.caption)
                                .foregroundStyle(MorpheTheme.textSecondary)
                        }
                    }
                }
                .buttonStyle(.plain)

                Spacer()

                HeaderCircleButton(systemImage: "plus", label: "Quick add") {
                    store.openQuickAdd()
                }

                HeaderCircleButton(systemImage: role == .coach ? "bubble.left.and.bubble.right.fill" : "bell.fill", label: role == .coach ? "Messages" : "Notifications") {
                    if role == .coach {
                        store.selectedCoachTab = .messages
                    } else {
                        store.openCommunity(.contact)
                    }
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Morphe")
                    .font(.system(.title, design: .rounded).weight(.bold))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.white, MorpheTheme.accent.opacity(0.92)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                Text(title)
                    .font(.headline)
                    .foregroundStyle(.white)
                Text(subtitle)
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(MorpheTheme.textSecondary)
            }

            Button {
                store.openUniversalSearch()
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(MorpheTheme.textSecondary)
                    Text(role == .coach ? "Search athletes, drills, or programs" : "Search workouts, people, or network posts")
                        .font(.subheadline)
                        .foregroundStyle(MorpheTheme.textSecondary)
                    Spacer()
                    Image(systemName: "arrow.up.right")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(MorpheTheme.accent)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: MorpheTheme.radius, style: .continuous)
                        .fill(Color.white.opacity(0.04))
                        .overlay(
                            RoundedRectangle(cornerRadius: MorpheTheme.radius, style: .continuous)
                                .stroke(Color.white.opacity(0.12), lineWidth: 1)
                        )
                )
            }
            .buttonStyle(.plain)
        }
    }
}

private struct HeaderCircleButton: View {
    let systemImage: String
    let label: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(.subheadline).weight(.semibold))
                .foregroundStyle(.white)
                .frame(width: 38, height: 38)
                .background(
                    RoundedRectangle(cornerRadius: MorpheTheme.radius, style: .continuous)
                        .stroke(Color.white.opacity(0.16), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(label))
    }
}

private struct FloatingAIAgentButton: View {
    @Environment(MorpheAppStore.self) private var store

    private var label: String {
        store.selectedRole == .coach ? "Morphe AI" : "Morphe AI"
    }

    private var isCompact: Bool {
        store.selectedRole == .client && store.selectedClientTab == .train && store.isWorkoutSessionActive
    }

    var body: some View {
        Button {
            store.openAIAgent()
        } label: {
            Group {
                if isCompact {
                    Image(systemName: "sparkles")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(.white)
                        .frame(width: 50, height: 50)
                        .background(buttonBackground.clipShape(Circle()))
                } else {
                    HStack(spacing: 10) {
                        Image(systemName: "sparkles")
                            .font(.subheadline.weight(.bold))
                        Text(label)
                            .font(.subheadline.weight(.bold))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                    .background(buttonBackground)
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text("Open \(label)"))
        .contextMenu {
            ForEach(store.aiAgentQuickPrompts.prefix(4), id: \.self) { prompt in
                Button(prompt) {
                    // Action prompts navigate — the result IS the feedback,
                    // so no sheet. Conversational prompts open the chat so
                    // the reply is actually visible (it used to open a sheet
                    // that the action layer instantly closed).
                    if !store.sendAIAgentPrompt(prompt) {
                        store.openAIAgent()
                    }
                }
            }
        }
    }

    private var buttonBackground: some View {
        // Flat HUD capsule: solid ink so it stays legible over any scroll
        // content, one accent hairline as the identity.
        Capsule(style: .continuous)
            .fill(MorpheTheme.ink.opacity(0.97))
            .overlay(
                Capsule(style: .continuous)
                    .stroke(MorpheTheme.accent.opacity(0.55), lineWidth: 1)
            )
    }
}

private struct MorpheAIAgentSheet: View {
    @Environment(MorpheAppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var prompt = ""
    @State private var dictation = DictationEngine()
    @FocusState private var inputFocused: Bool

    private var messages: [ThreadMessage] {
        store.selectedRole == .coach ? store.coachAIAgentConversation : store.athleteAIAgentConversation
    }

    private var trimmedPrompt: String {
        prompt.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        // One full-screen chat surface: the conversation fills the page and
        // the composer is pinned to the bottom — no separate "Morphe AI" and
        // "Ask Morphe" cards.
        ScrollViewReader { proxy in
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 12) {
                    Text(store.aiAgentSubtitle)
                        .font(.caption)
                        .foregroundStyle(MorpheTheme.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .multilineTextAlignment(.center)
                        .padding(.bottom, 4)

                    ForEach(messages) { message in
                        AIAgentMessageRow(message: message)
                            .id(message.id)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 16)
            }
            .scrollDismissesKeyboard(.interactively)
            .onAppear {
                if let last = messages.last {
                    proxy.scrollTo(last.id, anchor: .bottom)
                }
            }
            .onChange(of: messages.count) {
                guard let last = messages.last else { return }
                withAnimation(.easeOut(duration: 0.2)) {
                    proxy.scrollTo(last.id, anchor: .bottom)
                }
            }
        }
        .safeAreaInset(edge: .bottom) { composerBar }
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("Morphe AI")
                    .font(.headline)
                    .foregroundStyle(.white)
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button("Done") {
                    store.closeAIAgent()
                    dismiss()
                }
                .foregroundStyle(.white)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
    }

    /// Full-width composer pinned to the bottom of the chat.
    private var composerBar: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                Text("Context".uppercased())
                    .font(MorpheTheme.microLabel(10))
                    .tracking(1.2)
                    .foregroundStyle(MorpheTheme.textMuted)
                Text(store.aiAgentContextLabel)
                    .font(.caption)
                    .foregroundStyle(MorpheTheme.textSecondary)
                    .lineLimit(1)
                Spacer()
            }

            HStack(alignment: .bottom, spacing: 10) {
                TextField(
                    store.aiAgentPlaceholder,
                    text: $prompt,
                    axis: .vertical
                )
                .lineLimit(1...4)
                .textFieldStyle(MorpheFieldStyle())
                .focused($inputFocused)

                Button {
                    toggleDictation()
                } label: {
                    Image(systemName: dictation.isRecording ? "mic.fill" : "mic")
                        .font(.system(size: 22))
                        .foregroundStyle(dictation.isRecording ? MorpheTheme.accent : MorpheTheme.textSecondary)
                        .symbolEffect(.pulse, isActive: dictation.isRecording)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(dictation.isRecording ? "Stop dictation" : "Dictate message")

                Button(action: send) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 32))
                        .foregroundStyle(trimmedPrompt.isEmpty ? MorpheTheme.textMuted : MorpheTheme.accent)
                }
                .buttonStyle(.plain)
                .disabled(trimmedPrompt.isEmpty)
                .accessibilityLabel("Send")
            }

            if let notice = dictation.notice {
                Text(notice)
                    .font(.caption2)
                    .foregroundStyle(MorpheTheme.textMuted)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 10)
        .padding(.bottom, 8)
        .background(
            MorpheTheme.ink.opacity(0.97)
                .overlay(alignment: .top) {
                    Rectangle()
                        .fill(Color.white.opacity(0.08))
                        .frame(height: 1)
                }
                .ignoresSafeArea(edges: .bottom)
        )
        .onDisappear { dictation.stop() }
    }

    private func send() {
        let text = trimmedPrompt
        guard !text.isEmpty else { return }
        // Clear FIRST — the box must be empty the instant the arrow is hit,
        // even when the prompt triggers navigation that tears the sheet down.
        prompt = ""
        dictation.stop()
        store.sendAIAgentPrompt(text)
    }

    private func toggleDictation() {
        if dictation.isRecording {
            dictation.stop()
        } else {
            // Dictation APPENDS to whatever is already typed — switching from
            // thumbs to voice mid-thought must not eat the typed half.
            dictation.start(baseText: prompt) { prompt = $0 }
        }
    }
}

private struct AIAgentMessageRow: View {
    let message: ThreadMessage

    var body: some View {
        VStack(alignment: message.sender == .user ? .trailing : .leading, spacing: 4) {
            Text(message.senderName)
                .font(.caption.weight(.semibold))
                .foregroundStyle(MorpheTheme.textMuted)

            Text(message.text)
                .font(.subheadline)
                .foregroundStyle(.white)
                .padding(12)
                .frame(maxWidth: .infinity, alignment: message.sender == .user ? .trailing : .leading)
                .background(
                    RoundedRectangle(cornerRadius: MorpheTheme.radius, style: .continuous)
                        .fill(message.sender == .user ? MorpheTheme.accentAlt.opacity(0.28) : MorpheTheme.panelStrong)
                )
                .contextMenu {
                    Button {
                        UIPasteboard.general.string = message.text
                    } label: {
                        Label("Copy", systemImage: "doc.on.doc")
                    }
                }
        }
    }
}

// MARK: - Speech dictation (talk-to-text for the AI composer)

/// Live speech-to-text: streams partial transcriptions into the composer as
/// the user talks. On-device where the hardware supports it, so gym-floor
/// dead zones don't kill dictation.
@Observable
final class DictationEngine: NSObject {
    private(set) var isRecording = false
    /// One-line status for the composer ("Listening…", permission help). Nil
    /// when there is nothing worth saying.
    private(set) var notice: String?

    private let audioEngine = AVAudioEngine()
    private var recognizer: SFSpeechRecognizer?
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?

    /// Starts dictation, appending to `baseText`. Each partial result calls
    /// `onText` with the full combined string.
    func start(baseText: String, onText: @escaping (String) -> Void) {
        SFSpeechRecognizer.requestAuthorization { [weak self] status in
            DispatchQueue.main.async {
                guard status == .authorized else {
                    self?.notice = "Enable Speech Recognition for Morphe in Settings to dictate."
                    return
                }
                AVAudioApplication.requestRecordPermission { granted in
                    DispatchQueue.main.async {
                        guard granted else {
                            self?.notice = "Enable the Microphone for Morphe in Settings to dictate."
                            return
                        }
                        self?.beginRecognition(baseText: baseText, onText: onText)
                    }
                }
            }
        }
    }

    private func beginRecognition(baseText: String, onText: @escaping (String) -> Void) {
        stop()

        guard let recognizer = SFSpeechRecognizer(), recognizer.isAvailable else {
            notice = "Dictation isn't available right now."
            return
        }
        self.recognizer = recognizer

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        if recognizer.supportsOnDeviceRecognition {
            request.requiresOnDeviceRecognition = true
        }
        self.request = request

        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.record, mode: .measurement, options: .duckOthers)
            try session.setActive(true, options: .notifyOthersOnDeactivation)
            let inputNode = audioEngine.inputNode
            let format = inputNode.outputFormat(forBus: 0)
            inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in
                request.append(buffer)
            }
            audioEngine.prepare()
            try audioEngine.start()
        } catch {
            notice = "Couldn't start the microphone."
            stop()
            return
        }

        isRecording = true
        notice = "Listening… tap the mic to stop."

        let prefix = baseText.trimmingCharacters(in: .whitespacesAndNewlines)
        task = recognizer.recognitionTask(with: request) { [weak self] result, error in
            DispatchQueue.main.async {
                if let result {
                    let spoken = result.bestTranscription.formattedString
                    onText(prefix.isEmpty ? spoken : "\(prefix) \(spoken)")
                }
                if error != nil || (result?.isFinal ?? false) {
                    self?.stop()
                }
            }
        }
    }

    func stop() {
        if audioEngine.isRunning {
            audioEngine.stop()
            audioEngine.inputNode.removeTap(onBus: 0)
        }
        request?.endAudio()
        task?.cancel()
        task = nil
        request = nil
        isRecording = false
        notice = nil
        // Hand the audio session back to the reward sounds' ambient setup.
        try? AVAudioSession.sharedInstance().setCategory(.ambient, options: [.mixWithOthers])
    }
}

private struct NetworkProfilePreviewSheet: View {
    @Environment(MorpheAppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var showBooking = false

    let profile: NetworkProfilePreview

    /// A client can book a coach (not another athlete, and not themselves).
    private var canBookThisCoach: Bool {
        profile.role == .coach && store.selectedRole != .coach
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 16) {
                GlassCard {
                    VStack(alignment: .leading, spacing: 14) {
                        HStack(spacing: 14) {
                            Text(profile.avatar)
                                .font(.system(.largeTitle))
                                .frame(width: 62, height: 62)
                                .background(
                                    RoundedRectangle(cornerRadius: MorpheTheme.radius, style: .continuous)
                                        .fill(MorpheTheme.panelStrong)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: MorpheTheme.radius, style: .continuous)
                                                .stroke(MorpheTheme.stroke, lineWidth: 1)
                                        )
                                )

                            VStack(alignment: .leading, spacing: 4) {
                                Text(profile.name)
                                    .font(.title3.weight(.bold))
                                    .foregroundStyle(.white)
                                Text("@\(profile.handle)")
                                    .font(.subheadline)
                                    .foregroundStyle(MorpheTheme.textSecondary)
                                Text(profile.headline)
                                    .font(.subheadline)
                                    .foregroundStyle(MorpheTheme.textPrimary)
                            }
                        }

                        HStack(spacing: 10) {
                            StatusBadge(text: profile.role == .coach ? "Coach" : "Athlete", color: MorpheTheme.accent)
                            StatusBadge(text: profile.rank, color: MorpheTheme.accentAlt)
                        }

                        Text(profile.mutualContext)
                            .font(.subheadline)
                            .foregroundStyle(MorpheTheme.textSecondary)

                        WrapStack(spacing: 8) {
                            ForEach(profile.featuredTags, id: \.self) { tag in
                                Text(tag)
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(
                                        RoundedRectangle(cornerRadius: 2, style: .continuous)
                                            .stroke(Color.white.opacity(0.14), lineWidth: 1)
                                    )
                            }
                        }
                    }
                }

                if canBookThisCoach {
                    GlassCard {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Train with \(profile.name)")
                                .font(.headline)
                                .foregroundStyle(.white)
                            Text("Book a 1-on-1 session and work directly with this coach.")
                                .font(.subheadline)
                                .foregroundStyle(MorpheTheme.textSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                            Button {
                                showBooking = true
                            } label: {
                                Label("Book", systemImage: "calendar.badge.plus")
                            }
                            .buttonStyle(PrimaryCTAButtonStyle(accent: MorpheTheme.accent))
                            .accessibilityLabel("Book a session with this coach")
                        }
                    }
                }

                GlassCard {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Quick actions")
                            .font(.headline)
                            .foregroundStyle(.white)

                        HStack(spacing: 10) {
                            Button(primaryActionTitle) {
                                handlePrimaryAction()
                                dismissProfile()
                            }
                            .buttonStyle(PrimaryCTAButtonStyle(accent: MorpheTheme.accent))

                            Button("Connect") {
                                if let suggestion = store.networkSuggestions.first(where: { $0.name == profile.name }) {
                                    store.connectToNetworkSuggestion(suggestion)
                                } else {
                                    store.notify("Connection saved for \(profile.name).")
                                }
                                dismissProfile()
                            }
                            .buttonStyle(SecondaryCTAButtonStyle())
                        }
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 40)
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Done") {
                    dismissProfile()
                }
                .foregroundStyle(.white)
            }
        }
        .sheet(isPresented: $showBooking) {
            CoachBookingSheet(coachName: profile.name)
        }
    }

    private func dismissProfile() {
        store.closeNetworkProfile()
        dismiss()
    }

    private var primaryActionTitle: String {
        if store.selectedRole == .coach {
            if store.coachClients.contains(where: { $0.name == profile.name }) {
                return "Open Athlete"
            }
            return "Open Network"
        }

        return profile.role == .coach ? "Open Support" : "Open Network"
    }

    private func handlePrimaryAction() {
        if store.selectedRole == .coach {
            if let athlete = store.coachClients.first(where: { $0.name == profile.name }) {
                store.openClientHub(athlete)
                store.selectedCoachTab = .programs
            } else {
                store.selectedCoachTab = .network
                store.notify("Opened \(profile.name)'s coach network.")
            }
            return
        }

        if profile.role == .coach {
            store.openCommunity(.contact)
        } else {
            store.openCommunity(.forYou)
        }
    }
}

private enum UniversalSearchCategory: String, CaseIterable, Identifiable {
    case accounts = "Accounts"
    case plans = "Plans"
    case library = "Library"
    case posts = "Posts"

    var id: String { rawValue }
}

private struct UniversalSearchSheet: View {
    @Environment(MorpheAppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""
    @State private var category: UniversalSearchCategory = .accounts

    private var normalizedQuery: String {
        query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private var filteredSuggestions: [NetworkConnectionSuggestion] {
        let suggestions = store.networkSuggestions.filter { suggestion in
            normalizedQuery.isEmpty ||
            suggestion.name.lowercased().contains(normalizedQuery) ||
            suggestion.headline.lowercased().contains(normalizedQuery) ||
            suggestion.mutualContext.lowercased().contains(normalizedQuery)
        }

        return Array(suggestions.prefix(6))
    }

    private var filteredCoachClients: [CoachClient] {
        let clients = store.coachClients.filter { athlete in
            normalizedQuery.isEmpty ||
            athlete.name.lowercased().contains(normalizedQuery) ||
            athlete.goal.lowercased().contains(normalizedQuery) ||
            athlete.sport.rawValue.lowercased().contains(normalizedQuery)
        }

        return Array(clients.prefix(8))
    }

    private var filteredWorkouts: [WorkoutTemplate] {
        let workouts = store.workoutTemplates.filter { workout in
            normalizedQuery.isEmpty ||
            workout.name.lowercased().contains(normalizedQuery) ||
            workout.goal.lowercased().contains(normalizedQuery) ||
            workout.sport.rawValue.lowercased().contains(normalizedQuery)
        }

        return Array(workouts.prefix(8))
    }

    private var filteredExercises: [ExerciseReference] {
        let exercises = store.exerciseDatabase.filter { exercise in
            normalizedQuery.isEmpty ||
            exercise.name.lowercased().contains(normalizedQuery) ||
            exercise.musclesWorked.lowercased().contains(normalizedQuery) ||
            exercise.whyThisMatters.lowercased().contains(normalizedQuery)
        }

        return Array(exercises.prefix(8))
    }

    private var filteredDrills: [DrillReference] {
        let drills = store.drills.filter { drill in
            normalizedQuery.isEmpty ||
            drill.name.lowercased().contains(normalizedQuery) ||
            drill.skillCategory.lowercased().contains(normalizedQuery) ||
            drill.sport.rawValue.lowercased().contains(normalizedQuery)
        }

        return Array(drills.prefix(8))
    }

    private var filteredPosts: [ProgressPost] {
        let posts = store.communityPosts.filter { post in
            normalizedQuery.isEmpty ||
            post.author.lowercased().contains(normalizedQuery) ||
            post.title.lowercased().contains(normalizedQuery) ||
            post.detail.lowercased().contains(normalizedQuery) ||
            post.tags.joined(separator: " ").lowercased().contains(normalizedQuery)
        }

        return Array(posts.prefix(8))
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 16) {
                SectionTitleView(
                    title: "Search",
                    subtitle: store.selectedRole == .coach
                        ? "Athletes, plans, drills, and community posts in one fast search."
                        : "Accounts, workouts, exercises, and network posts without leaving the flow."
                )

                TextField("Search accounts, workouts, exercises, posts...", text: $query)
                    .textFieldStyle(MorpheFieldStyle())

                Picker("Search Category", selection: $category) {
                    ForEach(UniversalSearchCategory.allCases) { item in
                        Text(item.rawValue).tag(item)
                    }
                }
                .pickerStyle(.segmented)

                switch category {
                case .accounts:
                    accountsResults
                case .plans:
                    plansResults
                case .library:
                    libraryResults
                case .posts:
                    postResults
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 120)
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Done") {
                    store.closeUniversalSearch()
                    dismiss()
                }
                .foregroundStyle(.white)
            }
        }
    }

    @ViewBuilder
    private var accountsResults: some View {
        if store.selectedRole == .coach {
            GlassCard {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Athlete Accounts")
                        .font(.headline)
                        .foregroundStyle(.white)

                    ForEach(filteredCoachClients) { athlete in
                        SearchResultRow(
                            title: athlete.name,
                            subtitle: "\(athlete.sport.rawValue) • \(athlete.goal)",
                            detail: "Recovery \(athlete.recoveryScore.score) • Compliance \(athlete.complianceScore)%"
                        ) {
                            store.openClientHub(athlete)
                            store.closeUniversalSearch()
                            dismiss()
                        }
                    }

                    if !filteredSuggestions.isEmpty {
                        Divider()
                            .overlay(MorpheTheme.stroke)

                        Text("Suggested Connections")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(MorpheTheme.textSecondary)

                        ForEach(filteredSuggestions) { suggestion in
                            SearchResultRow(
                                title: suggestion.name,
                                subtitle: suggestion.headline,
                                detail: suggestion.mutualContext
                            ) {
                                store.openNetworkProfile(for: suggestion)
                                store.closeUniversalSearch()
                                dismiss()
                            }
                        }
                    }
                }
            }
        } else {
            GlassCard {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Recommended Connections")
                        .font(.headline)
                        .foregroundStyle(.white)

                    SearchResultRow(
                        title: store.coachProfile.name,
                        subtitle: store.coachProfile.headline,
                        detail: store.coachProfile.networkRank
                    ) {
                        store.openCoachNetworkProfile()
                        store.closeUniversalSearch()
                        dismiss()
                    }

                    ForEach(filteredSuggestions) { suggestion in
                        SearchResultRow(
                            title: suggestion.name,
                            subtitle: suggestion.headline,
                            detail: suggestion.mutualContext
                        ) {
                            store.openNetworkProfile(for: suggestion)
                            store.closeUniversalSearch()
                            dismiss()
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var plansResults: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                Text(store.selectedRole == .coach ? "Programs + Playbooks" : "Workout Plans")
                    .font(.headline)
                    .foregroundStyle(.white)

                ForEach(filteredWorkouts) { workout in
                    SearchResultRow(
                        title: workout.name,
                        subtitle: "\(workout.sport.rawValue) • \(workout.goal)",
                        detail: "\(workout.durationMinutes) min • \(workout.difficulty.rawValue)"
                    ) {
                        if store.selectedRole == .coach {
                            store.selectProgramTemplate(workout)
                            store.selectedCoachTab = .programs
                        } else {
                            store.openWorkoutTemplate(workout)
                        }
                        store.closeUniversalSearch()
                        dismiss()
                    }
                }

                if store.selectedRole == .coach {
                    ForEach(store.playbooks.filter { normalizedQuery.isEmpty || $0.title.lowercased().contains(normalizedQuery) || $0.philosophy.lowercased().contains(normalizedQuery) }.prefix(4)) { playbook in
                        SearchResultRow(
                            title: playbook.title,
                            subtitle: playbook.philosophy,
                            detail: "\(playbook.templates.count) templates • \(playbook.drills.count) drills"
                        ) {
                            store.selectedCoachTab = .programs
                            store.selectedCoachBuildSection = .library
                            store.notify("\(playbook.title) is ready in Build Library.")
                            store.closeUniversalSearch()
                            dismiss()
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var libraryResults: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("Exercise + Drill Library")
                    .font(.headline)
                    .foregroundStyle(.white)

                ForEach(filteredExercises) { exercise in
                    SearchResultRow(
                        title: exercise.name,
                        subtitle: exercise.musclesWorked,
                        detail: exercise.whyThisMatters
                    ) {
                        if store.selectedRole == .coach {
                            store.selectedCoachTab = .programs
                            store.selectedCoachBuildSection = .library
                            store.notify("\(exercise.name) is ready in Build Library.")
                        } else {
                            store.openMore(.library)
                            store.selectedExercise = exercise
                        }
                        store.closeUniversalSearch()
                        dismiss()
                    }
                }

                ForEach(filteredDrills) { drill in
                    SearchResultRow(
                        title: drill.name,
                        subtitle: "\(drill.sport.rawValue) • \(drill.skillCategory)",
                        detail: drill.whyThisMatters
                    ) {
                        if store.selectedRole == .coach {
                            store.selectedCoachTab = .programs
                            store.selectedCoachBuildSection = .library
                            store.notify("\(drill.name) is ready in Build Library.")
                        } else {
                            store.openMore(.library)
                            store.notify("\(drill.name) opened from the library.")
                        }
                        store.closeUniversalSearch()
                        dismiss()
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var postResults: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("Network Posts")
                    .font(.headline)
                    .foregroundStyle(.white)

                ForEach(filteredPosts) { post in
                    SearchResultRow(
                        title: post.title,
                        subtitle: "\(post.author) • \(post.rank)",
                        detail: post.detail
                    ) {
                        if store.selectedRole == .coach {
                            store.selectedCoachTab = .network
                        } else {
                            store.openCommunity(.forYou)
                        }
                        store.notify("Opened \(post.author)'s post.")
                        store.closeUniversalSearch()
                        dismiss()
                    }
                }
            }
        }
    }
}

private struct QuickAddSheet: View {
    @Environment(MorpheAppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var quickNote = ""

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 16) {
                SectionTitleView(
                    title: "Quick Add",
                    subtitle: store.selectedRole == .coach
                        ? "Capture the next coaching move fast."
                        : "Log the moment, ask for help, or keep momentum moving."
                )

                if store.selectedRole == .coach {
                    QuickAddGridCard(items: [
                        QuickAddItem(title: "Add Lead", subtitle: "Drop a new athlete into CRM", systemImage: "person.crop.circle.badge.plus") {
                            store.quickAddCoachLead()
                            dismissQuickAdd()
                        },
                        QuickAddItem(title: "Assign Plan", subtitle: "Push the current program fast", systemImage: "checklist") {
                            store.quickAssignProgram()
                            dismissQuickAdd()
                        },
                        QuickAddItem(title: "Post Update", subtitle: "Share a coach note to the network", systemImage: "megaphone.fill") {
                            store.quickAddCoachUpdate()
                            dismissQuickAdd()
                        },
                        QuickAddItem(title: "Schedule Check-In", subtitle: "Add a touchpoint to the calendar", systemImage: "calendar.badge.plus") {
                            store.scheduleQuickCheckIn()
                            dismissQuickAdd()
                        }
                    ])
                } else {
                    QuickAddGridCard(items: [
                        QuickAddItem(
                            title: store.hasCompletedWorkoutFlow
                                ? "Log Workout"
                                : (store.isWorkoutSessionActive
                                    ? "Resume Workout"
                                    : (store.isWorkoutLoggedToday ? "New Workout" : "Open Workout")),
                            subtitle: store.hasCompletedWorkoutFlow
                                ? "Close the loop now"
                                : (store.isWorkoutSessionActive
                                    ? "Jump back into Train"
                                    : (store.isWorkoutLoggedToday ? "Today's done — browse Discover" : "Start today's plan in Train")),
                            systemImage: store.hasCompletedWorkoutFlow
                                ? "checkmark.circle.fill"
                                : (store.isWorkoutLoggedToday && !store.isWorkoutSessionActive ? "square.grid.2x2.fill" : "figure.run")
                        ) {
                            if store.hasCompletedWorkoutFlow {
                                store.logWorkout()
                            } else if store.isWorkoutSessionActive {
                                // Resume = return to the live console. The old
                                // path restarted the session and wiped every
                                // logged set.
                                store.selectedClientTab = .train
                            } else if store.isWorkoutLoggedToday {
                                // Today's workout is already in the books —
                                // offer something new instead of a re-run.
                                store.selectedClientTab = .discover
                            } else {
                                store.startTodayWorkout()
                            }
                            dismissQuickAdd()
                        },
                        QuickAddItem(title: "Browse Exercises", subtitle: "Open the exercise library", systemImage: "books.vertical.fill") {
                            // openMore selects the library panel — setting the
                            // tab alone landed on whatever panel was last open.
                            store.openMore(.library)
                            dismissQuickAdd()
                        },
                        QuickAddItem(title: "Ask Morphe", subtitle: "Quick tips and answers", systemImage: "sparkles") {
                            // Two sheets can't co-present: dismiss this one,
                            // then open the chat once the transition has room.
                            dismissQuickAdd()
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                                store.openAIAgent()
                            }
                        }
                    ])
                }

                GlassCard {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Quick Note")
                            .font(.headline)
                            .foregroundStyle(.white)
                        Text(store.selectedRole == .coach ? "Save a note against the selected athlete or your own coaching flow." : "Capture how you feel, what worked, or what to tell your coach later.")
                            .foregroundStyle(MorpheTheme.textSecondary)

                        TextField("Type a quick note...", text: $quickNote)
                            .textFieldStyle(MorpheFieldStyle())

                        Button("Save Note") {
                            let fallback = store.selectedRole == .coach
                                ? "Needs a lighter session next time."
                                : "Session felt clean and manageable today."
                            store.saveQuickNote(quickNote.isEmpty ? fallback : quickNote)
                            quickNote = ""
                            dismissQuickAdd()
                        }
                        .buttonStyle(PrimaryCTAButtonStyle(accent: MorpheTheme.accent))
                    }
                }

                if !store.quickCaptureNotes.isEmpty {
                    GlassCard {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Recent Notes")
                                .font(.headline)
                                .foregroundStyle(.white)

                            ForEach(Array(store.quickCaptureNotes.prefix(3)), id: \.self) { note in
                                Text("• \(note)")
                                    .foregroundStyle(MorpheTheme.textPrimary)
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 120)
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Done") {
                    dismissQuickAdd()
                }
                .foregroundStyle(.white)
            }
        }
    }

    private func dismissQuickAdd() {
        store.closeQuickAdd()
        dismiss()
    }
}

private struct QuickAddItem: Identifiable {
    let id = UUID()
    let title: String
    let subtitle: String
    let systemImage: String
    let action: () -> Void
}

private struct QuickAddGridCard: View {
    let items: [QuickAddItem]

    private let columns = [
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10)
    ]

    var body: some View {
        GlassCard {
            LazyVGrid(columns: columns, spacing: 10) {
                ForEach(items) { item in
                    Button(action: item.action) {
                        VStack(alignment: .leading, spacing: 10) {
                            Image(systemName: item.systemImage)
                                .font(.headline)
                                .foregroundStyle(MorpheTheme.accent)
                            Text(item.title)
                                .font(.subheadline.weight(.bold))
                                .foregroundStyle(.white)
                            Text(item.subtitle)
                                .font(.caption)
                                .foregroundStyle(MorpheTheme.textSecondary)
                                .multilineTextAlignment(.leading)
                        }
                        .frame(maxWidth: .infinity, minHeight: 110, alignment: .leading)
                        .padding(14)
                        .background(
                            RoundedRectangle(cornerRadius: MorpheTheme.radius, style: .continuous)
                                .fill(MorpheTheme.panelInteractive)
                                .overlay(
                                    RoundedRectangle(cornerRadius: MorpheTheme.radius, style: .continuous)
                                        .stroke(MorpheTheme.stroke, lineWidth: 1)
                                )
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

private struct SearchResultRow: View {
    let title: String
    let subtitle: String
    let detail: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                Text(subtitle)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(MorpheTheme.accentAlt)
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(MorpheTheme.textSecondary)
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
    }
}

private struct WelcomeExperienceView: View {
    @Environment(MorpheAppStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    private var isCoach: Bool {
        store.selectedRole == .coach
    }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 16) {
                    ProfileBannerView(banner: store.profileShowcase.banner, theme: store.profileShowcase.theme)

                    GlassCard {
                        VStack(alignment: .leading, spacing: 14) {
                            HStack(spacing: 12) {
                                MorpheAvatarView(avatar: store.profileShowcase.avatar, size: 84)
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Welcome to Morphe, \(isCoach ? store.coachProfile.name : store.clientProfile.name)")
                                        .font(.title3.weight(.bold))
                                        .foregroundStyle(.white)
                                    Text(isCoach ? "Your coach workspace is live and your first command center is ready." : "Your profile is live and your first plan is ready.")
                                        .foregroundStyle(MorpheTheme.textSecondary)
                                }
                            }

                            Text(isCoach ? "Your coaching system is live. Start with the athletes who need you most, then move into programs and outreach." : store.clientProfile.welcomeMessage)
                                .font(.headline)
                                .foregroundStyle(.white)

                            HStack(spacing: 8) {
                                if FeatureFlags.multiUserEnabled {
                                    MetricPill(label: "Account", value: isCoach ? "Coach" : "Athlete")
                                }
                                MetricPill(label: "Primary Sport", value: store.clientProfile.sportMode.rawValue)
                                MetricPill(label: "Primary Goal", value: store.clientProfile.goal)
                            }

                            WrapStack(spacing: 8) {
                                ForEach(store.clientProfile.selectedSports) { sport in
                                    WelcomeTag(text: sport.shortTitle, color: MorpheTheme.color(for: sport))
                                }
                                ForEach(store.clientProfile.selectedTrainingStyles) { style in
                                    WelcomeTag(text: style.rawValue, color: MorpheTheme.warning)
                                }
                                ForEach(store.clientProfile.selectedGoals, id: \.self) { goal in
                                    WelcomeTag(text: goal, color: MorpheTheme.accentAlt)
                                }
                            }
                        }
                    }

                    GlassCard {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("What happens next")
                                .font(.headline)
                                .foregroundStyle(.white)
                            // Names the tabs that actually exist, and promises
                            // only what tier 0 shows: one workout to start.
                            Text(isCoach ? "Open Home to triage the day, use Athletes for profiles and notes, then move into Build or Inbox when you want to act." : "Today has your first workout ready. Open Train when you're ready to move — and everything else in Morphe grows from the workouts you log.")
                                .foregroundStyle(MorpheTheme.textSecondary)
                            Text("You can update your name and weight unit anytime from your profile.")
                                .foregroundStyle(MorpheTheme.textPrimary)
                        }
                    }

                    Button(isCoach ? "Open Home" : "Start Training") {
                        store.dismissWelcomeExperience()
                        dismiss()
                    }
                    .buttonStyle(PrimaryCTAButtonStyle(accent: MorpheTheme.accent))
                }
                .padding(20)
            }
            .background(PremiumBackground())
        }
    }
}

private struct WelcomeTag: View {
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
    }
}

/// Hosts the store's session-work gate as a destructive confirmation dialog.
/// Attached at the root and on any sheet whose actions can hit the gate.
private struct SessionWorkGateDialog: ViewModifier {
    @Environment(MorpheAppStore.self) private var store

    func body(content: Content) -> some View {
        content.confirmationDialog(
            store.pendingWorkoutChange?.title ?? "Replace today's workout?",
            isPresented: Binding(
                get: { store.pendingWorkoutChange != nil },
                set: { if !$0 { store.cancelPendingWorkoutChange() } }
            ),
            titleVisibility: .visible,
            presenting: store.pendingWorkoutChange
        ) { change in
            // `change` is captured by value, so the confirmed action survives
            // the isPresented binding clearing the store's pending slot.
            Button(
                store.isWorkoutSessionActive
                    ? "Discard Session"
                    : "Discard Recap",
                role: .destructive
            ) {
                change.action()
            }
            Button("Keep Current", role: .cancel) {}
        } message: { _ in
            Text(store.isWorkoutSessionActive
                ? "Your workout is in progress — its logged sets will be lost."
                : "Your finished session hasn't been logged — its sets will be lost.")
        }
    }
}

extension View {
    func sessionWorkGateDialog() -> some View {
        modifier(SessionWorkGateDialog())
    }
}
