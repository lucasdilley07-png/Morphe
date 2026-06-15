import SwiftUI

struct CommunityView: View {
    @Environment(MorpheAppStore.self) private var store
    @State private var selectedStory: CommunityStoryPreview?
    @State private var showNetworkExtras = false

    var body: some View {
        Group {
            switch store.selectedCommunitySection {
            case .forYou:
                forYouScreen
            case .contact:
                contactScreen
            }
        }
        .sheet(item: $selectedStory) { story in
            StoryHighlightSheet(story: story)
        }
    }

    private var forYouScreen: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 16) {
                SectionTitleView(
                    title: "Network",
                    subtitle: "For You keeps the training feed useful. Contact keeps coaches, partners, and support close."
                )

                communityHeaderControls

                CommunityNetworkFeed(perspective: .client)

                NetworkDisclosureSection(
                    title: "Grow & explore",
                    subtitle: "Suggestions, discovery, and privacy live lower so the feed can start doing its job sooner.",
                    isExpanded: $showNetworkExtras
                ) {
                    NetworkSummaryCard()
                    NetworkSuggestionsCard()
                    CommunityDiscoveryCard(groups: store.trainingGroups, challenges: store.challenges, leaderboard: store.leaderboards)

                    GlassCard {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Privacy")
                                .font(.headline)
                                .foregroundStyle(.white)
                            Text("You control what friends can see. Weight and progress photos are private by default.")
                                .foregroundStyle(MorpheTheme.textSecondary)
                        }
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 120)
        }
    }

    private var contactScreen: some View {
        VStack(alignment: .leading, spacing: 0) {
            AthleteContactInbox()
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .padding(.bottom, 120)
    }

    private var communityHeaderControls: some View {
        @Bindable var store = store
        return VStack(alignment: .leading, spacing: 14) {
            NetworkStoriesRail { story in
                selectedStory = story
            }

            Picker("Community Section", selection: $store.selectedCommunitySection) {
                ForEach(ClientCommunitySection.allCases) { section in
                    Text(section.rawValue).tag(section)
                }
            }
            .pickerStyle(.segmented)
        }
    }
}

private struct NetworkDisclosureSection<Content: View>: View {
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

private struct ContactSectionSwitcher: View {
    @Environment(MorpheAppStore.self) private var store

    var body: some View {
        @Bindable var store = store
        return Picker("Community Section", selection: $store.selectedCommunitySection) {
            ForEach(ClientCommunitySection.allCases) { section in
                Text(section.rawValue).tag(section)
            }
        }
        .pickerStyle(.segmented)
    }
}

private struct NetworkStoriesRail: View {
    @Environment(MorpheAppStore.self) private var store
    let onSelectStory: (CommunityStoryPreview) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                StoryRingCard(symbol: "🧠", title: "Coach", subtitle: store.clientProfile.coachName) {
                    onSelectStory(
                        CommunityStoryPreview(
                            symbol: "🧠",
                            title: store.clientProfile.coachName,
                            subtitle: "Coach highlights",
                            items: [
                                "Boxing Base Builder is still the right fit this week.",
                                "Keep the first round moderate and honest.",
                                "Protein and sleep matter more than extra fatigue tonight."
                            ]
                        )
                    )
                }

                ForEach(store.workoutPartners) { partner in
                    StoryRingCard(symbol: avatar(for: partner.sport), title: partner.name, subtitle: "\(partner.streak)-day streak") {
                        onSelectStory(
                            CommunityStoryPreview(
                                symbol: avatar(for: partner.sport),
                                title: partner.name,
                                subtitle: "\(partner.favoriteSession) highlights",
                                items: [
                                    "\(partner.name) protected a \(partner.streak)-day streak.",
                                    "Favorite session: \(partner.favoriteSession).",
                                    "Current vibe: \(partner.vibe)."
                                ]
                            )
                        )
                    }
                }

                StoryRingCard(symbol: "🏆", title: "Challenges", subtitle: "\(store.challenges.count) active") {
                    onSelectStory(
                        CommunityStoryPreview(
                            symbol: "🏆",
                            title: "Challenges",
                            subtitle: "Current highlights",
                            items: store.challenges.map(\.title)
                        )
                    )
                }
            }
            .padding(.vertical, 4)
        }
    }

    private func avatar(for sport: SportFocus) -> String {
        switch sport {
        case .boxing: return "🥊"
        case .soccer: return "⚽"
        case .basketball: return "🏀"
        case .running, .track: return "🏃"
        default: return "🔥"
        }
    }
}

struct StoryRingCard: View {
    let symbol: String
    let title: String
    let subtitle: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [MorpheTheme.accent, MorpheTheme.accentAlt],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 62, height: 62)

                    Circle()
                        .fill(MorpheTheme.ink)
                        .frame(width: 56, height: 56)

                    Text(symbol)
                        .font(.title2)
                }

                VStack(spacing: 2) {
                    Text(title)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.white)
                    Text(subtitle)
                        .font(.caption2)
                        .foregroundStyle(MorpheTheme.textSecondary)
                        .lineLimit(1)
                }
                .frame(width: 76)
            }
        }
        .buttonStyle(.plain)
    }
}

private struct CommunityStoryPreview: Identifiable {
    let id = UUID()
    let symbol: String
    let title: String
    let subtitle: String
    let items: [String]
}

private struct StoryHighlightSheet: View {
    @Environment(\.dismiss) private var dismiss
    let story: CommunityStoryPreview

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 16) {
                    GlassCard {
                        VStack(alignment: .leading, spacing: 14) {
                            HStack(spacing: 12) {
                                Text(story.symbol)
                                    .font(.system(.largeTitle))
                                    .frame(width: 64, height: 64)
                                    .background(
                                        Circle()
                                            .fill(MorpheTheme.panelStrong)
                                    )

                                VStack(alignment: .leading, spacing: 4) {
                                    Text(story.title)
                                        .font(.title3.weight(.bold))
                                        .foregroundStyle(.white)
                                    Text(story.subtitle)
                                        .font(.subheadline)
                                        .foregroundStyle(MorpheTheme.textSecondary)
                                }
                            }

                            ForEach(story.items, id: \.self) { item in
                                Text("- \(item)")
                                    .foregroundStyle(.white)
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
                        dismiss()
                    }
                    .foregroundStyle(.white)
                }
            }
        }
    }
}

private struct AthleteContactInbox: View {
    @Environment(MorpheAppStore.self) private var store
    @State private var draft = ""
    @State private var searchText = ""

    private var selectedThread: MessageThread? {
        store.selectedAthleteThread
    }

    private var filteredThreads: [MessageThread] {
        store.athleteInboxThreads(matching: searchText)
    }

    private var urgentThreadCount: Int {
        filteredThreads.filter { store.athleteInboxContext(for: $0).priority >= 85 }.count
    }

    var body: some View {
        Group {
            if let selectedThread {
                conversationView(thread: selectedThread)
            } else {
                threadListView
            }
        }
        .onAppear {
            applyAthleteThreadDraftSeedIfNeeded()
        }
        .onChange(of: store.selectedAthleteThreadID) { _, newValue in
            if newValue == nil {
                draft = ""
            }

            if newValue != nil {
                if store.athleteThreadDraftSeed != nil {
                    applyAthleteThreadDraftSeedIfNeeded()
                } else {
                    draft = ""
                }
            }
        }
        .onChange(of: store.athleteThreadDraftSeed) { _, newValue in
            if newValue != nil, store.selectedAthleteThreadID != nil {
                applyAthleteThreadDraftSeedIfNeeded()
            }
        }
    }

    private func applyAthleteThreadDraftSeedIfNeeded() {
        guard let seed = store.athleteThreadDraftSeed, store.selectedAthleteThreadID != nil else { return }
        draft = seed
        store.athleteThreadDraftSeed = nil
    }

    private var threadListView: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top, spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Messages")
                            .font(.title3.weight(.bold))
                            .foregroundStyle(.white)
                        Text("Coach, Morphe AI, your partner, and your groups all live here like a real inbox.")
                            .font(.subheadline)
                            .foregroundStyle(MorpheTheme.textSecondary)
                    }

                    Spacer()

                    Button("For You") {
                        store.selectedCommunitySection = .forYou
                    }
                    .buttonStyle(SecondaryCTAButtonStyle())
                    .frame(width: 100)
                }

                TextField("Search contacts or messages", text: $searchText)
                    .textFieldStyle(MorpheFieldStyle())

                HStack {
                    Text("\(filteredThreads.count) contacts")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(MorpheTheme.textMuted)

                    Spacer()

                    if urgentThreadCount > 0 {
                        Text("\(urgentThreadCount) need a reply")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(MorpheTheme.warning)
                    }
                }
            }
            .padding(16)

            Divider()
                .overlay(MorpheTheme.stroke.opacity(0.8))

            ScrollView(showsIndicators: false) {
                LazyVStack(spacing: 0) {
                    ForEach(Array(filteredThreads.enumerated()), id: \.element.id) { index, thread in
                        AthleteContactRow(
                            thread: thread,
                            avatar: contactAvatar(for: thread),
                            context: store.athleteInboxContext(for: thread),
                            onOpen: {
                                store.selectAthleteMessageThread(thread)
                            },
                            onQuickAction: { action in
                                store.performAthleteInboxQuickAction(action, for: thread)
                            }
                        )

                        if index < filteredThreads.count - 1 {
                            Divider()
                                .overlay(MorpheTheme.stroke.opacity(0.5))
                                .padding(.leading, 72)
                        }
                    }
                }
                .padding(.vertical, 4)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    private func conversationView(thread: MessageThread) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 12) {
                Button {
                    store.closeAthleteMessageThread()
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(.white)
                        .frame(width: 34, height: 34)
                        .background(
                            Circle()
                                .fill(MorpheTheme.panelStrong)
                        )
                }
                .buttonStyle(.plain)

                Text(contactAvatar(for: thread))
                    .font(.title2)
                    .frame(width: 42, height: 42)
                    .background(
                        Circle()
                            .fill(MorpheTheme.panelStrong)
                    )

                VStack(alignment: .leading, spacing: 4) {
                    Text(thread.participant)
                        .font(.headline)
                        .foregroundStyle(.white)
                    Text(thread.isGroupChat ? "Group chat" : "Conversation")
                        .font(.caption)
                        .foregroundStyle(MorpheTheme.textSecondary)
                }

                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)

            Divider()
                .overlay(MorpheTheme.stroke.opacity(0.8))

            VStack(spacing: 0) {
                ScrollView(showsIndicators: false) {
                    LazyVStack(alignment: .leading, spacing: 12) {
                        ForEach(thread.messages.suffix(12)) { message in
                            ClientConversationRow(message: message)
                        }
                    }
                    .padding(16)
                    .padding(.bottom, 8)
                }
                Divider()
                    .overlay(MorpheTheme.stroke.opacity(0.8))

                HStack(spacing: 10) {
                    TextField("Type a message", text: $draft, axis: .vertical)
                        .lineLimit(1...3)
                        .textFieldStyle(MorpheFieldStyle())

                    Button("Send") {
                        store.sendAthleteMessage(to: thread.id, text: draft)
                        draft = ""
                    }
                    .buttonStyle(PrimaryCTAButtonStyle(accent: MorpheTheme.accent))
                    .frame(width: 84)
                }
                .padding(16)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    private func contactAvatar(for thread: MessageThread) -> String {
        switch thread.participant {
        case "Coach Marcus":
            return "🧠"
        case "Morphe AI":
            return "✨"
        case "Jay":
            return "🥊"
        case "Maya":
            return "⚽"
        case "Chris":
            return "🏀"
        default:
            return "💬"
        }
    }
}

private struct AthleteContactRow: View {
    let thread: MessageThread
    let avatar: String
    let context: AthleteInboxThreadContext
    let onOpen: () -> Void
    let onQuickAction: (AthleteInboxQuickAction) -> Void

    private var lastTimestamp: String {
        thread.messages.last?.timestamp ?? "Now"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Button(action: onOpen) {
                HStack(spacing: 12) {
                    Text(avatar)
                        .font(.title2)
                        .frame(width: 44, height: 44)
                        .background(
                            Circle()
                                .fill(MorpheTheme.panelStrong)
                        )

                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text(thread.participant)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.white)
                            Spacer()
                            Text(lastTimestamp)
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(MorpheTheme.textMuted)
                            if thread.isUnread {
                                Circle()
                                    .fill(MorpheTheme.accent)
                                    .frame(width: 8, height: 8)
                            }
                        }

                        HStack(spacing: 8) {
                            StatusBadge(
                                text: context.badge,
                                color: context.priority >= 90 ? MorpheTheme.warning : MorpheTheme.accent
                            )

                            Text(thread.isGroupChat ? "Group" : thread.sport.shortTitle)
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(MorpheTheme.textMuted)
                        }

                        Text(context.detail)
                            .font(.caption)
                            .foregroundStyle(MorpheTheme.textSecondary)
                            .lineLimit(2)
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if !context.quickActions.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(context.quickActions.prefix(2)) { action in
                            Button {
                                onQuickAction(action)
                            } label: {
                                HStack(spacing: 6) {
                                    Image(systemName: action.systemImage)
                                        .font(.caption.weight(.semibold))
                                    Text(action.rawValue)
                                        .font(.caption.weight(.semibold))
                                }
                            }
                            .buttonStyle(FilterChipStyle(isSelected: false, selectedColor: MorpheTheme.accentAlt))
                        }
                    }
                }
                .padding(.leading, 56)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}

struct CommunityNetworkFeed: View {
    @Environment(MorpheAppStore.self) private var store
    let perspective: AppRole

    private var rankedPosts: [ProgressPost] {
        store.rankedCommunityPosts(for: perspective)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("For You")
                            .font(.headline)
                            .foregroundStyle(.white)
                        Text(perspective == .coach
                             ? "Athlete wins, coach insights, and useful comments in one mixed network."
                             : "Training updates, coach ideas, athlete wins, and recovery notes worth actually reading.")
                            .font(.caption)
                            .foregroundStyle(MorpheTheme.textSecondary)
                    }

                    Spacer()
                }

                TrainingHappeningNowCard(posts: Array(rankedPosts.prefix(3)))

                ForEach(rankedPosts) { post in
                    CommunityPostCard(post: post) {
                        store.reactToCommunityPost(post)
                    } onComment: {
                        store.commentOnCommunityPost(post)
                    } onShare: {
                        store.shareCommunityPost("Sharing \(post.author)'s update with my circle in Morphe.", as: perspective)
                    } onSaveWorkout: {
                        store.saveWorkoutFromCommunityPost(post)
                    }
                }
            }
        }
    }
}

private struct TrainingHappeningNowCard: View {
    let posts: [ProgressPost]

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("Training Happening Now")
                    .font(.headline)
                    .foregroundStyle(.white)

                Text("The top of your feed now favors real momentum: completions, coach involvement, partner work, and recovery follow-through.")
                    .font(.subheadline)
                    .foregroundStyle(MorpheTheme.textSecondary)

                if posts.isEmpty {
                    Text("As new training posts land here, Morphe will float the most useful ones to the top.")
                        .foregroundStyle(MorpheTheme.textSecondary)
                } else {
                    ForEach(posts) { post in
                        HStack(alignment: .top, spacing: 10) {
                            Text(post.avatar)
                                .font(.title3)

                            VStack(alignment: .leading, spacing: 4) {
                                Text(post.title)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(.white)
                                    .lineLimit(2)

                                Text("\(post.author) • \(post.timeAgo)")
                                    .font(.caption)
                                    .foregroundStyle(MorpheTheme.textSecondary)

                                if let tag = post.tags.first {
                                    Text(tag)
                                        .font(.caption2.weight(.semibold))
                                        .foregroundStyle(MorpheTheme.accentAlt)
                                }
                            }
                        }
                        .padding(.vertical, 2)
                    }
                }
            }
        }
    }
}

struct NetworkSummaryCard: View {
    @Environment(MorpheAppStore.self) private var store

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("Your Morphe Network")
                    .font(.headline)
                    .foregroundStyle(.white)

                Text("Follow athlete progress, coach thinking, group momentum, and practical comments that help people keep going.")
                    .foregroundStyle(MorpheTheme.textSecondary)

                HStack(spacing: 8) {
                    MetricPill(label: "Posts", value: "\(store.communityPosts.count)")
                    MetricPill(label: "Groups", value: "\(store.trainingGroups.count)")
                    MetricPill(label: "Challenges", value: "\(store.challenges.count)")
                    MetricPill(label: "Rank", value: store.clientProfile.networkRank)
                }
            }
        }
    }
}

struct NetworkComposerCard: View {
    @Environment(MorpheAppStore.self) private var store
    let perspective: AppRole
    @State private var draft = ""

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                Text(perspective == .coach ? "Share a coaching note" : "Share a training update")
                    .font(.headline)
                    .foregroundStyle(.white)

                TextField(
                    perspective == .coach ? "Post a coaching idea, athlete win, or cue..." : "Share a win, lesson, recovery insight, or plan update...",
                    text: $draft,
                    axis: .vertical
                )
                .lineLimit(2...4)
                .textFieldStyle(MorpheFieldStyle())

                HStack(spacing: 8) {
                    Button("Share Update") {
                        store.shareCommunityPost(draft, as: perspective)
                        draft = ""
                    }
                    .buttonStyle(PrimaryCTAButtonStyle(accent: MorpheTheme.accent))

                    Text("Professional-style feed, still centered on training.")
                        .font(.caption)
                        .foregroundStyle(MorpheTheme.textMuted)
                }
            }
        }
    }
}

private struct CoachChatPreviewCard: View {
    let coachName: String
    let coachStatus: String
    let preview: String
    let onMessage: () -> Void

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(coachName)
                            .font(.headline)
                            .foregroundStyle(.white)
                        Text(coachStatus)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(MorpheTheme.accent)
                    }

                    Spacer()

                    Button("Message Coach", action: onMessage)
                        .buttonStyle(SecondaryCTAButtonStyle())
                        .frame(width: 150)
                }

                Text(preview)
                    .foregroundStyle(MorpheTheme.textSecondary)
            }
        }
    }
}

private struct AICoachChatCard: View {
    @Binding var prompt: String
    let quickPrompts: [String]
    let onSend: (String) -> Void

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("Ask Morphe AI")
                    .font(.headline)
                    .foregroundStyle(.white)

                TextField(
                    "Ask Morphe anything about your workout, nutrition, or progress...",
                    text: $prompt,
                    axis: .vertical
                )
                .lineLimit(2...4)
                .textFieldStyle(MorpheFieldStyle())

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(quickPrompts, id: \.self) { item in
                            Button(item) {
                                onSend(item)
                            }
                            .buttonStyle(FilterChipStyle(isSelected: false, selectedColor: MorpheTheme.accentAlt))
                        }
                    }
                }

                Button("Send to AI Coach") {
                    onSend(prompt)
                }
                .buttonStyle(PrimaryCTAButtonStyle(accent: MorpheTheme.accentAlt))
            }
        }
    }
}

private struct MessageThreadCard: View {
    let messages: [ThreadMessage]

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("Coach + AI Thread")
                    .font(.headline)
                    .foregroundStyle(.white)

                ForEach(messages) { message in
                    ClientConversationRow(message: message)
                }
            }
        }
    }
}

struct CommunityPostCard: View {
    let post: ProgressPost
    let onLike: () -> Void
    let onComment: () -> Void
    let onShare: () -> Void
    let onSaveWorkout: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 10) {
                Text(post.avatar)
                    .font(.title2)

                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(post.author)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.white)
                        Spacer()
                        Text(post.timeAgo)
                            .font(.caption)
                            .foregroundStyle(MorpheTheme.textMuted)
                    }

                    Text(post.headline.isEmpty ? "Morphe network member" : post.headline)
                        .font(.caption)
                        .foregroundStyle(MorpheTheme.textSecondary)

                    HStack(spacing: 8) {
                        StatusBadge(text: post.role == .coach ? "Coach" : "Athlete", color: post.role == .coach ? MorpheTheme.accentAlt : MorpheTheme.accent)
                        StatusBadge(text: post.rank.isEmpty ? "Rising" : post.rank, color: MorpheTheme.warning)
                    }
                }
            }

            Text(post.title)
                .font(.headline)
                .foregroundStyle(.white)

            Text(post.detail)
                .font(.subheadline)
                .foregroundStyle(MorpheTheme.textSecondary)

            if !post.tags.isEmpty {
                WrapStack(spacing: 8) {
                    ForEach(post.tags, id: \.self) { tag in
                        CommunityTagChip(text: tag)
                    }
                }
            }

            HStack(spacing: 12) {
                Text("\(post.reactions) reactions")
                Text("\(post.comments) comments")
            }
            .font(.caption)
            .foregroundStyle(MorpheTheme.textMuted)

            HStack(spacing: 8) {
                Button("Like", action: onLike)
                    .buttonStyle(CompactCommunityActionButtonStyle())

                Button("Comment", action: onComment)
                    .buttonStyle(CompactCommunityActionButtonStyle())

                Button("Repost", action: onShare)
                    .buttonStyle(CompactCommunityActionButtonStyle())

                Button("Save", action: onSaveWorkout)
                    .buttonStyle(CompactCommunityActionButtonStyle())
            }

            if !post.commentHighlights.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(post.commentHighlights.prefix(2)) { comment in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text("\(comment.avatar) \(comment.author)")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.white)
                                Spacer()
                                Text(comment.rank)
                                    .font(.caption2)
                                    .foregroundStyle(MorpheTheme.textMuted)
                            }
                            Text(comment.text)
                                .font(.caption)
                                .foregroundStyle(MorpheTheme.textSecondary)
                        }
                        .padding(10)
                        .background(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(MorpheTheme.panel)
                        )
                    }
                }
            }

            Divider()
                .overlay(MorpheTheme.stroke)
        }
        .padding(.vertical, 10)
    }
}

private struct CompactCommunityActionButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.caption.weight(.semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 10)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(configuration.isPressed ? MorpheTheme.panelStrong : MorpheTheme.panel)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(MorpheTheme.strokeStrong.opacity(configuration.isPressed ? 0.8 : 0.45), lineWidth: 1)
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeInOut(duration: 0.16), value: configuration.isPressed)
    }
}

private struct CommunityTagChip: View {
    let text: String

    var body: some View {
        Text(text)
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

private struct TrainingGroupCard: View {
    let group: TrainingGroupPreview

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(group.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                Spacer()
                Text("\(group.memberCount) members")
                    .font(.caption)
                    .foregroundStyle(MorpheTheme.textSecondary)
            }

            Text(group.detail)
                .font(.caption)
                .foregroundStyle(MorpheTheme.textSecondary)
        }
        .padding(.vertical, 4)
    }
}

struct NetworkSuggestionsCard: View {
    @Environment(MorpheAppStore.self) private var store

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("Grow Your Network")
                    .font(.headline)
                    .foregroundStyle(.white)

                ForEach(store.networkSuggestions) { suggestion in
                    HStack(alignment: .top, spacing: 10) {
                        Text(suggestion.avatar)
                            .font(.title3)

                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(suggestion.name)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(.white)
                                Spacer()
                                StatusBadge(text: suggestion.rank, color: suggestion.role == .coach ? MorpheTheme.accentAlt : MorpheTheme.warning)
                            }

                            Text(suggestion.headline)
                                .font(.caption)
                                .foregroundStyle(MorpheTheme.textSecondary)
                            Text(suggestion.mutualContext)
                                .font(.caption2)
                                .foregroundStyle(MorpheTheme.textMuted)
                        }

                        Button("Connect") {
                            store.connectToNetworkSuggestion(suggestion)
                        }
                        .buttonStyle(CompactCommunityActionButtonStyle())
                        .frame(width: 92)
                    }
                    .padding(.vertical, 4)
                }
            }
        }
    }
}

struct CommunityDiscoveryCard: View {
    let groups: [TrainingGroupPreview]
    let challenges: [Challenge]
    let leaderboard: [LeaderboardEntry]

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 14) {
                Text("Groups, Challenges, and Ranks")
                    .font(.headline)
                    .foregroundStyle(.white)

                if !groups.isEmpty {
                    Text("Groups")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                    ForEach(groups.prefix(2)) { group in
                        TrainingGroupCard(group: group)
                    }
                }

                if !challenges.isEmpty {
                    Text("Challenges")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                    ForEach(challenges.prefix(2)) { challenge in
                        ChallengeCard(challenge: challenge)
                    }
                }

                if !leaderboard.isEmpty {
                    Text("Ranks")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                    ForEach(leaderboard.prefix(3)) { entry in
                        LeaderboardCard(entry: entry)
                    }
                }
            }
        }
    }
}

private struct ChallengeCard: View {
    let challenge: Challenge

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(challenge.title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white)
            Text(challenge.detail)
                .font(.caption)
                .foregroundStyle(MorpheTheme.textSecondary)
        }
        .padding(.vertical, 4)
    }
}

private struct LeaderboardCard: View {
    let entry: LeaderboardEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(entry.category)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                Spacer()
                Text(entry.leader)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(MorpheTheme.accentAlt)
            }
            Text(entry.detail)
                .font(.caption)
                .foregroundStyle(MorpheTheme.textSecondary)
        }
        .padding(.vertical, 4)
    }
}

private struct ClientConversationRow: View {
    let message: ThreadMessage

    private var alignment: HorizontalAlignment {
        switch message.sender {
        case .user:
            return .trailing
        default:
            return .leading
        }
    }

    private var backgroundColor: Color {
        switch message.sender {
        case .user:
            return MorpheTheme.accentAlt.opacity(0.3)
        case .coach:
            return MorpheTheme.panelStrong
        case .ai:
            return MorpheTheme.panel
        case .client, .system:
            return MorpheTheme.panel
        }
    }

    var body: some View {
        VStack(alignment: alignment, spacing: 4) {
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
                        .fill(backgroundColor)
                )
        }
    }
}
