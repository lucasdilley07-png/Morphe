import SwiftUI

struct RootView: View {
    @EnvironmentObject private var store: MorpheAppStore

    var body: some View {
        ZStack {
            PremiumBackground()

            Group {
                if store.isShowingLaunchSequence {
                    LaunchSequenceView()
                } else if !store.hasCompletedOnboarding {
                    OnboardingFlowView()
                } else {
                    AppShell {
                        Group {
                            switch store.selectedRole {
                            case .client:
                                ClientLayout {
                                    ClientExperienceShell()
                                }
                            case .coach:
                                CoachLayout {
                                    CoachDashboardView()
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
                    .environmentObject(store)
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
                    .environmentObject(store)
            }
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
            .background(PremiumBackground())
        }
        .sheet(isPresented: $store.showClientProfile, onDismiss: {
            store.closeClientProfile()
        }) {
            NavigationStack {
                ProfileView()
                    .environmentObject(store)
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button("Done") {
                                store.closeClientProfile()
                            }
                            .foregroundStyle(.white)
                        }
                    }
            }
            .background(PremiumBackground())
        }
        .sheet(isPresented: $store.showPaywall) {
            PaywallPreviewScreen()
                .environmentObject(store)
        }
        .sheet(isPresented: $store.showUniversalSearch) {
            NavigationStack {
                UniversalSearchSheet()
                    .environmentObject(store)
            }
            .background(PremiumBackground())
        }
        .sheet(isPresented: $store.showQuickAdd) {
            NavigationStack {
                QuickAddSheet()
                    .environmentObject(store)
            }
            .background(PremiumBackground())
        }
        .sheet(isPresented: $store.showAIAgent) {
            NavigationStack {
                MorpheAIAgentSheet()
                    .environmentObject(store)
            }
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
            .background(PremiumBackground())
        }
        .sheet(isPresented: $store.showWelcomeExperience) {
            WelcomeExperienceView()
                .environmentObject(store)
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
            if !store.isShowingLaunchSequence && store.hasCompletedOnboarding && !store.showWelcomeExperience {
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
    @EnvironmentObject private var store: MorpheAppStore
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
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(MorpheTheme.panel)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8, style: .continuous)
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
    @EnvironmentObject private var store: MorpheAppStore

    var body: some View {
        TabView(selection: $store.selectedClientTab) {
            HomeView()
                .tag(ClientTab.today)

            WorkoutView()
                .tag(ClientTab.train)

            if FeatureFlags.multiUserEnabled {
                CommunityView()
                    .tag(ClientTab.community)
            }

            ProgressView()
                .tag(ClientTab.hub)

            MoreView()
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
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 8)
        }
    }
}

private struct ClientPinnedHeader: View {
    @EnvironmentObject private var store: MorpheAppStore

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

            HeaderCircleButton(systemImage: "plus") {
                store.openQuickAdd()
            }

            HeaderCircleButton(systemImage: "bubble.left.and.bubble.right.fill") {
                store.openCommunity(.contact)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(MorpheTheme.panelRaised.opacity(0.96))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(MorpheTheme.strokeStrong.opacity(0.24), lineWidth: 1)
                )
        )
        .shadow(color: MorpheTheme.glow.opacity(0.1), radius: 12, x: 0, y: 6)
    }
}

struct DemoBrandHeader: View {
    @EnvironmentObject private var store: MorpheAppStore

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

                HeaderCircleButton(systemImage: "plus") {
                    store.openQuickAdd()
                }

                HeaderCircleButton(systemImage: role == .coach ? "bubble.left.and.bubble.right.fill" : "bell.fill") {
                    if role == .coach {
                        store.selectedCoachTab = .messages
                    } else {
                        store.openCommunity(.contact)
                    }
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Morphe")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
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
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(MorpheTheme.panelRaised)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(MorpheTheme.strokeStrong.opacity(0.28), lineWidth: 1)
                        )
                        .overlay(alignment: .topLeading) {
                            Capsule(style: .continuous)
                                .fill(
                                    LinearGradient(
                                        colors: [MorpheTheme.accent.opacity(0.64), .clear],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .frame(width: 72, height: 2)
                                .padding(.top, 1)
                                .padding(.leading, 10)
                        }
                )
            }
            .buttonStyle(.plain)
        }
    }
}

private struct HeaderCircleButton: View {
    let systemImage: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 38, height: 38)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(MorpheTheme.panelRaised)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .stroke(MorpheTheme.strokeStrong.opacity(0.28), lineWidth: 1)
                        )
                )
                .shadow(color: MorpheTheme.glow.opacity(0.12), radius: 10, x: 0, y: 6)
        }
        .buttonStyle(.plain)
    }
}

private struct FloatingAIAgentButton: View {
    @EnvironmentObject private var store: MorpheAppStore

    private var label: String {
        store.selectedRole == .coach ? "Coach AI" : "Morphe AI"
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
        .contextMenu {
            ForEach(store.aiAgentQuickPrompts.prefix(4), id: \.self) { prompt in
                Button(prompt) {
                    store.openAIAgent()
                    store.sendAIAgentPrompt(prompt)
                }
            }
        }
    }

    private var buttonBackground: some View {
        Capsule(style: .continuous)
            .fill(MorpheTheme.panelRaised.opacity(0.98))
            .overlay(
                Capsule(style: .continuous)
                    .stroke(MorpheTheme.strokeStrong.opacity(0.42), lineWidth: 1)
            )
            .overlay(alignment: .topLeading) {
                Capsule(style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [MorpheTheme.accent.opacity(0.84), MorpheTheme.accentAlt.opacity(0.20), .clear],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(height: 2)
                    .padding(.horizontal, 10)
                    .padding(.top, 1)
            }
            .overlay(alignment: .leading) {
                Circle()
                    .fill(MorpheTheme.accent.opacity(0.82))
                    .frame(width: 8, height: 8)
                    .shadow(color: MorpheTheme.glow, radius: 10, x: 0, y: 0)
                    .padding(.leading, 14)
                    .opacity(isCompact ? 0 : 1)
            }
            .shadow(color: MorpheTheme.glow.opacity(0.26), radius: 18, x: 0, y: 10)
            .shadow(color: Color.black.opacity(0.24), radius: 22, x: 0, y: 14)
    }
}

private struct MorpheAIAgentSheet: View {
    @EnvironmentObject private var store: MorpheAppStore
    @Environment(\.dismiss) private var dismiss
    @State private var prompt = ""

    private var messages: [ThreadMessage] {
        store.selectedRole == .coach ? store.coachAIAgentConversation : store.athleteAIAgentConversation
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 16) {
                SectionTitleView(
                    title: store.selectedRole == .coach ? "Coach AI" : "Morphe AI",
                    subtitle: store.aiAgentSubtitle
                )

                GlassCard {
                    HStack {
                        VStack(alignment: .leading, spacing: 6) {
                        Text("Current context")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(MorpheTheme.textMuted)
                        Text(store.aiAgentContextLabel)
                            .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.white)
                        }

                        Spacer()

                        Image(systemName: store.selectedRole == .coach ? "person.2.wave.2.fill" : "sparkles")
                            .foregroundStyle(MorpheTheme.accent)
                    }
                }

                GlassCard {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Quick intents")
                            .font(.headline)
                            .foregroundStyle(.white)

                        WrapStack(spacing: 8) {
                            ForEach(store.aiAgentQuickPrompts, id: \.self) { item in
                                Button(item) {
                                    store.sendAIAgentPrompt(item)
                                }
                                .buttonStyle(FilterChipStyle(isSelected: false, selectedColor: MorpheTheme.accentAlt))
                            }
                        }
                    }
                }

                GlassCard {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Assistant Console")
                            .font(.headline)
                            .foregroundStyle(.white)

                        TextField(
                            store.aiAgentPlaceholder,
                            text: $prompt,
                            axis: .vertical
                        )
                        .lineLimit(2...4)
                        .textFieldStyle(MorpheFieldStyle())

                        Button("Send") {
                            store.sendAIAgentPrompt(prompt)
                            prompt = ""
                        }
                        .buttonStyle(PrimaryCTAButtonStyle(accent: MorpheTheme.accent))
                    }
                }

                GlassCard {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Conversation")
                            .font(.headline)
                            .foregroundStyle(.white)

                        ForEach(messages.suffix(8)) { message in
                            AIAgentMessageRow(message: message)
                        }
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 40)
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Done") {
                    store.closeAIAgent()
                    dismiss()
                }
                .foregroundStyle(.white)
            }
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
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(message.sender == .user ? MorpheTheme.accentAlt.opacity(0.28) : MorpheTheme.panelStrong)
                )
        }
    }
}

private struct NetworkProfilePreviewSheet: View {
    @EnvironmentObject private var store: MorpheAppStore
    @Environment(\.dismiss) private var dismiss

    let profile: NetworkProfilePreview

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 16) {
                GlassCard {
                    VStack(alignment: .leading, spacing: 14) {
                        HStack(spacing: 14) {
                            Text(profile.avatar)
                                .font(.system(size: 36))
                                .frame(width: 62, height: 62)
                                .background(
                                    Circle()
                                        .fill(MorpheTheme.panelStrong)
                                        .overlay(Circle().stroke(MorpheTheme.stroke, lineWidth: 1))
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
                                        Capsule(style: .continuous)
                                            .fill(MorpheTheme.panelStrong)
                                    )
                            }
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
            return "Open Coach Network"
        }

        return profile.role == .coach ? "Open Support" : "Open Network"
    }

    private func handlePrimaryAction() {
        if store.selectedRole == .coach {
            if let athlete = store.coachClients.first(where: { $0.name == profile.name }) {
                store.openClientHub(athlete)
                store.selectedCoachTab = .athletes
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
    @EnvironmentObject private var store: MorpheAppStore
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
    @EnvironmentObject private var store: MorpheAppStore
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
                            title: store.hasCompletedWorkoutFlow ? "Log Workout" : (store.isWorkoutSessionActive ? "Resume Workout" : "Open Workout"),
                            subtitle: store.hasCompletedWorkoutFlow ? "Close the loop now" : (store.isWorkoutSessionActive ? "Jump back into Train" : "Start today's plan in Train"),
                            systemImage: store.hasCompletedWorkoutFlow ? "checkmark.circle.fill" : "figure.run"
                        ) {
                            if store.hasCompletedWorkoutFlow {
                                store.logWorkout()
                            } else {
                                store.startTodayWorkout()
                            }
                            dismissQuickAdd()
                        },
                        QuickAddItem(title: "Share Win", subtitle: "Post today's momentum", systemImage: "sparkles") {
                            store.shareDailyWin()
                            dismissQuickAdd()
                        },
                        QuickAddItem(title: "Invite Partner", subtitle: "Turn today's plan social", systemImage: "person.2.fill") {
                            store.quickAddInvitePartner()
                            dismissQuickAdd()
                        },
                        QuickAddItem(title: "Ask Coach", subtitle: "Open support fast", systemImage: "bubble.left.and.bubble.right.fill") {
                            store.openCommunity(.contact)
                            dismissQuickAdd()
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
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(MorpheTheme.panelInteractive)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
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
    @EnvironmentObject private var store: MorpheAppStore
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
                                MetricPill(label: "Account", value: isCoach ? "Coach" : "Athlete")
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
                            Text(isCoach ? "Open Home to triage the day, use Athletes for profiles and notes, then move into Build or Inbox when you want to act." : "Start on Home for today's plan, open Train when you're ready to move, and use Progress to see the bigger picture.")
                                .foregroundStyle(MorpheTheme.textSecondary)
                            Text("You can update your account type, sports, training styles, goals, colors, and profile look anytime from Profile.")
                                .foregroundStyle(MorpheTheme.textPrimary)
                        }
                    }

                    Button(isCoach ? "Open Coach Home" : "Open My Home") {
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
                Capsule(style: .continuous)
                    .fill(color)
            )
    }
}
