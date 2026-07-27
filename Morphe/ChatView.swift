import SwiftUI

struct CommunityView: View {
    @Environment(MorpheAppStore.self) private var store
    @State private var selectedStory: CommunityStoryPreview?
    @State private var showNetworkExtras = false
    /// Tab landing clears the floating header icons; sheets (the Home
    /// Messages sheet) have a nav bar instead and pass a small value.
    var topPadding: CGFloat = MorpheTheme.Spacing.pageTop

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

                if store.isRealFeedActive {
                    // The REAL feed (Firestore posts/*) replaces the demo
                    // rankedCommunityPosts list for signed-in users. The demo
                    // sections below stay intact for the flag-gated path.
                    RealFeedSection()
                } else if FeatureFlags.multiUserEnabled, store.hasNetworkActivity {
                    // Demo surfaces render ONLY under the demo flag — a real
                    // TestFlight account must never see seeded stories or
                    // suggestion cards it could mistake for real people.
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
                } else {
                    NetworkEmptyState()
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, topPadding)
            .padding(.bottom, 120)
        }
        .refreshable {
            await store.refreshFeed()
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

/// First-run network state: a real new user has zero connections, so instead
/// of a barren feed we lead with the core reason to network — finding training
/// partners and coaches — plus the actions that fill the feed.
private struct NetworkEmptyState: View {
    @Environment(MorpheAppStore.self) private var store

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            GlassCard {
                VStack(alignment: .leading, spacing: 14) {
                    Text("🤝")
                        .font(.system(size: 40))
                        .accessibilityHidden(true)

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Build your network")
                            .font(.system(.title2, design: .rounded).weight(.bold))
                            .foregroundStyle(.white)
                        Text("Morphe is better with people. Connect with athletes and coaches near you — then your feed fills with real sessions, wins, and ideas worth stealing.")
                            .font(.subheadline)
                            .foregroundStyle(MorpheTheme.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Button {
                        store.findAthletesNearby()
                    } label: {
                        Label("Find athletes near you", systemImage: "location.magnifyingglass")
                    }
                    .buttonStyle(PrimaryCTAButtonStyle())
                }
            }

            ShareLink(item: store.networkInviteMessage) {
                NetworkEmptyActionRow(
                    icon: "person.2.fill",
                    title: "Invite a training partner",
                    subtitle: "Bring a friend in and keep each other consistent."
                )
            }
            .buttonStyle(.plain)

            NetworkEmptyExpectations()
        }
    }
}

private struct NetworkEmptyActionRow: View {
    let icon: String
    let title: String
    let subtitle: String

    var body: some View {
        GlassCard {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.headline)
                    .foregroundStyle(MorpheTheme.accent)
                    .frame(width: 44, height: 44)
                    .background(
                        RoundedRectangle(cornerRadius: MorpheTheme.radius, style: .continuous)
                            .fill(MorpheTheme.panelStrong)
                    )

                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(MorpheTheme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(MorpheTheme.textMuted)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

private struct NetworkEmptyExpectations: View {
    private let perks: [(String, String)] = [
        ("figure.run", "Share workouts and wins with people who get it"),
        ("chart.line.uptrend.xyaxis", "Compare progress and stay accountable"),
        ("brain.head.profile", "Pick up ideas from coaches and athletes near you")
    ]

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("What you'll get")
                    .font(.headline)
                    .foregroundStyle(.white)

                ForEach(perks, id: \.0) { perk in
                    HStack(alignment: .center, spacing: 12) {
                        Image(systemName: perk.0)
                            .font(.subheadline)
                            .foregroundStyle(MorpheTheme.accentAlt)
                            .frame(width: 24)
                        Text(perk.1)
                            .font(.subheadline)
                            .foregroundStyle(MorpheTheme.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
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
                    RoundedRectangle(cornerRadius: MorpheTheme.radius, style: .continuous)
                        .fill(MorpheTheme.panelRaised)
                        .overlay(
                            RoundedRectangle(cornerRadius: MorpheTheme.radius, style: .continuous)
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

            if filteredThreads.isEmpty {
                AthleteContactEmptyState(isSearching: !searchText.trimmingCharacters(in: .whitespaces).isEmpty)
                    .padding(20)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            } else {
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

private struct AthleteContactEmptyState: View {
    let isSearching: Bool

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                Image(systemName: isSearching ? "magnifyingglass" : "tray")
                    .font(.title)
                    .foregroundStyle(MorpheTheme.accentAlt)

                Text(isSearching ? "No matches" : "No conversations yet")
                    .font(.headline)
                    .foregroundStyle(.white)

                Text(isSearching
                     ? "Nobody in your contacts matches that search."
                     : "Connect with your coach or a training partner from the Discover tab — show or scan a Morphe code under Connect.")
                    .font(.subheadline)
                    .foregroundStyle(MorpheTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
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

                Button("Ask Coach") {
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
                            RoundedRectangle(cornerRadius: MorpheTheme.radius, style: .continuous)
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
                RoundedRectangle(cornerRadius: MorpheTheme.radius, style: .continuous)
                    .fill(configuration.isPressed ? MorpheTheme.panelStrong : MorpheTheme.panel)
            )
            .overlay(
                RoundedRectangle(cornerRadius: MorpheTheme.radius, style: .continuous)
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

// MARK: - REAL community feed (Firestore posts/*, For You)
//
// Everything in this section renders the real thing — live `posts/*`
// documents from real accounts: publish, react (one per user, counted
// server-side), save, repost with commentary, delete-own. The demo feed
// types above stay untouched (flag-gated demo content).

/// The verification blue — a universal trust signal, deliberately outside
/// the yellow palette (same constant as the leaderboard/profile seals).
private let feedVerifiedSealBlue = Color(red: 0.25, green: 0.56, blue: 0.96)

/// The signed-in For You surface: section switcher, composer, Saved filter,
/// and the real post list. A stories rail would mount at the top of this
/// section — DEFERRED: it needs Firebase Storage (there is none yet, so no
/// image/video hosting) and a moderation pipeline (none yet either) before
/// user-submitted media can ship.
private struct RealFeedSection: View {
    @Environment(MorpheAppStore.self) private var store
    @State private var draft = ""
    @State private var filter: FeedFilter = .all
    @State private var repostTarget: FeedPost?
    @State private var athleteQuery = ""

    private enum FeedFilter: String, CaseIterable {
        case all = "All"
        case following = "Following"
        case saved = "Saved"
    }

    private static let postLimit = 1000

    private var visiblePosts: [FeedPost] {
        switch filter {
        case .all:
            return store.feedPosts
        case .following:
            return store.feedPosts.filter { store.followedUids.contains($0.authorUid) }
        case .saved:
            return store.feedPosts.filter { store.savedPostIds.contains($0.id) }
        }
    }

    private var cleanDraft: String {
        draft.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        @Bindable var store = store
        return VStack(alignment: .leading, spacing: 14) {
            Picker("Community Section", selection: $store.selectedCommunitySection) {
                ForEach(ClientCommunitySection.allCases) { section in
                    Text(section.rawValue).tag(section)
                }
            }
            .pickerStyle(.segmented)

            composer

            CompetitionPulseCard()

            athleteSearch

            HStack(spacing: 8) {
                ForEach(FeedFilter.allCases, id: \.self) { option in
                    Button(option.rawValue) {
                        filter = option
                    }
                    .buttonStyle(FilterChipStyle(isSelected: filter == option, selectedColor: MorpheTheme.accent))
                }

                Spacer()
            }

            if visiblePosts.isEmpty {
                emptyState
            } else {
                ForEach(visiblePosts) { post in
                    FeedPostCard(post: post) {
                        repostTarget = post
                    }
                }
            }
        }
        .sheet(item: $repostTarget) { post in
            RepostSheet(post: post)
        }
        .task {
            await store.refreshFeed()
            await store.refreshLeaderboard()
            await store.refreshChallenges()
        }
    }

    /// Username search → follow. The directory is the only thing scanned —
    /// no profiles, no suggestion engine, just "type a name, follow it".
    private var athleteSearch: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(MorpheTheme.textMuted)
                    TextField("Find athletes by @username…", text: $athleteQuery)
                        .textFieldStyle(MorpheFieldStyle())
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }

                if !store.athleteSearchResults.isEmpty {
                    ForEach(store.athleteSearchResults) { result in
                        HStack(spacing: 10) {
                            Text("@\(result.username)")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.white)
                                .lineLimit(1)

                            Spacer(minLength: 0)

                            Button(store.isFollowing(result.uid) ? "Following" : "Follow") {
                                store.toggleFollow(uid: result.uid, name: "@\(result.username)")
                            }
                            .buttonStyle(FilterChipStyle(isSelected: store.isFollowing(result.uid), selectedColor: MorpheTheme.accent))
                            .accessibilityLabel(store.isFollowing(result.uid)
                                ? "Unfollow \(result.username)" : "Follow \(result.username)")
                        }
                    }
                } else if athleteQuery.trimmingCharacters(in: .whitespaces).count >= 2 {
                    Text("No usernames match yet — names claim on sign-up.")
                        .font(.caption)
                        .foregroundStyle(MorpheTheme.textMuted)
                }
            }
        }
        // Re-query as typing settles; .task(id:) auto-cancels the stale run.
        .task(id: athleteQuery) {
            try? await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled else { return }
            await store.searchAthletes(query: athleteQuery)
        }
    }

    private var composer: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 10) {
                TextField("Share a win…", text: $draft, axis: .vertical)
                    .lineLimit(2...5)
                    .textFieldStyle(MorpheFieldStyle())

                HStack {
                    Text("\(draft.count)/\(Self.postLimit)")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(draft.count > Self.postLimit ? MorpheTheme.warning : MorpheTheme.textMuted)

                    Spacer()

                    Button("Post") {
                        let text = cleanDraft
                        draft = ""
                        Task { await store.publishPost(text: text) }
                    }
                    .buttonStyle(PrimaryCTAButtonStyle(accent: MorpheTheme.accent))
                    // Same send control as the chat composer (ThreadChatView):
                    // 84x44 primary CTA next to a MorpheFieldStyle field.
                    .frame(width: 84, height: 44)
                    .disabled(cleanDraft.isEmpty || draft.count > Self.postLimit)
                }
            }
        }
    }

    private var emptyState: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 10) {
                Image(systemName: emptyStateSymbol)
                    .font(.title2)
                    .foregroundStyle(MorpheTheme.accentAlt)

                Text(emptyStateTitle)
                    .font(.headline)
                    .foregroundStyle(.white)

                Text(emptyStateDetail)
                    .font(.subheadline)
                    .foregroundStyle(MorpheTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var emptyStateSymbol: String {
        switch filter {
        case .all: return "sparkles"
        case .following: return "person.2"
        case .saved: return "bookmark"
        }
    }

    private var emptyStateTitle: String {
        switch filter {
        case .all: return "No posts yet — share the first win"
        case .following: return store.followedUids.isEmpty ? "Nobody followed yet" : "No posts here yet"
        case .saved: return "Nothing saved yet"
        }
    }

    private var emptyStateDetail: String {
        switch filter {
        case .all:
            return "This feed is real people's real training. Your post can be the one that starts it."
        case .following:
            return store.followedUids.isEmpty
                ? "Find athletes by @username above, or tap Follow on any post — their sessions land here."
                : "The people you follow haven't posted yet — their next logged session shows up here."
        case .saved:
            return "Tap Save on any post and it lands here for later."
        }
    }
}

/// The weekly board + joined challenges, IN the real feed where signed-in
/// users actually live — the backend scored these all along; this card just
/// stops hiding them. Every number shown is a fetched Firestore row.
private struct CompetitionPulseCard: View {
    @Environment(MorpheAppStore.self) private var store

    private var topThree: [WeeklyLeaderboardEntry] {
        Array(store.weeklyLeaderboard.prefix(3))
    }

    private var selfRank: Int? {
        guard let me = store.weeklyLeaderboardSelfEntry else { return nil }
        return store.weeklyLeaderboard.firstIndex { $0.uid == me.uid }.map { $0 + 1 }
    }

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("This Week")
                        .font(.headline)
                        .foregroundStyle(.white)
                    Spacer()
                    Button("Open Progress") {
                        store.openProgress()
                    }
                    .buttonStyle(FilterChipStyle(isSelected: false, selectedColor: MorpheTheme.accent))
                    .accessibilityLabel("Open Progress for the full board")
                }

                if store.leaderboardOptIn {
                    if topThree.isEmpty {
                        Text("The board is live — the first logged workout of the week takes #1.")
                            .font(.caption)
                            .foregroundStyle(MorpheTheme.textMuted)
                    } else {
                        ForEach(Array(topThree.enumerated()), id: \.element.uid) { index, entry in
                            HStack(spacing: 8) {
                                Text("#\(index + 1)")
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(MorpheTheme.accent)
                                    .frame(width: 26, alignment: .leading)
                                Text(entry.name)
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.white)
                                    .lineLimit(1)
                                Spacer(minLength: 0)
                                Text("\(entry.score) sets")
                                    .font(.caption)
                                    .foregroundStyle(MorpheTheme.textSecondary)
                            }
                        }
                        if let me = store.weeklyLeaderboardSelfEntry {
                            Text(selfRank.map { "You're #\($0) with \(me.score) sets." }
                                 ?? "You've posted \(me.score) sets — outside the fetched top 50.")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(MorpheTheme.accentAlt)
                        }
                    }
                } else {
                    // Honest unlock: the board exists, joining is the gate.
                    Text("The weekly leaderboard is opt-in — join from Progress and your real logged sets score from Monday.")
                        .font(.caption)
                        .foregroundStyle(MorpheTheme.textMuted)
                        .fixedSize(horizontal: false, vertical: true)
                }

                if !store.activeChallenges.isEmpty {
                    Divider().overlay(Color.white.opacity(0.08))
                    ForEach(store.activeChallenges.prefix(2)) { challenge in
                        HStack(spacing: 8) {
                            Image(systemName: "flag.checkered")
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(MorpheTheme.accent)
                            Text(challenge.title)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.white)
                                .lineLimit(1)
                            Spacer(minLength: 0)
                            Text(challenge.isExpired ? "Ended" : "\(challenge.daysLeft)d left")
                                .font(.caption)
                                .foregroundStyle(challenge.isExpired ? MorpheTheme.textMuted : MorpheTheme.textSecondary)
                        }
                    }
                }
            }
        }
    }
}

/// One real feed post: author (blue seal when server-verified), relative
/// time, text, optional workout pill + structured session stats, repost
/// attribution, the real action row (typed reactions via long-press,
/// comments fetched on expand), and a follow chip on others' posts. Own
/// posts delete via the context menu.
private struct FeedPostCard: View {
    @Environment(MorpheAppStore.self) private var store
    let post: FeedPost
    let onRepost: () -> Void

    @State private var showComments = false
    @State private var commentDraft = ""
    @State private var showBlockConfirm = false
    @State private var commentBlockTarget: PostComment?

    private var isMine: Bool { post.authorUid == (store.authUser?.id ?? "") }
    private var hasReacted: Bool { store.myReactedPostIds.contains(post.id) }
    private var isSaved: Bool { store.savedPostIds.contains(post.id) }
    private var reactionCount: Int { store.feedReactionCounts[post.id] ?? 0 }

    private var myReactionSymbol: String {
        guard hasReacted else { return "heart" }
        let type = store.myReactionTypes[post.id] ?? "heart"
        return MorpheAppStore.reactionTypes.first { $0.type == type }?.symbol ?? "heart.fill"
    }

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 10) {
                    Circle()
                        .fill(MorpheTheme.panelStrong)
                        .frame(width: 40, height: 40)
                        .overlay(
                            Text(String(post.authorName.prefix(1)).uppercased())
                                .font(.headline)
                                .foregroundStyle(.white)
                        )

                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 5) {
                            Text(post.authorName)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.white)
                                .lineLimit(1)

                            if post.verified {
                                Image(systemName: "checkmark.seal.fill")
                                    .font(.caption)
                                    .foregroundStyle(feedVerifiedSealBlue)
                                    .accessibilityLabel("Verified")
                            }
                        }

                        Text(post.createdAt.formatted(.relative(presentation: .named)))
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(MorpheTheme.textMuted)
                    }

                    Spacer()

                    if !isMine, store.isRealFeedActive {
                        Button(store.isFollowing(post.authorUid) ? "Following" : "Follow") {
                            store.toggleFollow(uid: post.authorUid, name: post.authorName)
                        }
                        .buttonStyle(FilterChipStyle(
                            isSelected: store.isFollowing(post.authorUid),
                            selectedColor: MorpheTheme.accent))
                        .accessibilityLabel(store.isFollowing(post.authorUid)
                            ? "Unfollow \(post.authorName)" : "Follow \(post.authorName)")
                    }
                }

                if post.isRepost {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.2.squarepath")
                            .font(.caption.weight(.semibold))
                        Text("Reposted from \(post.repostOfAuthor.isEmpty ? "the feed" : post.repostOfAuthor)")
                            .font(.caption.weight(.semibold))
                            .lineLimit(1)
                    }
                    .foregroundStyle(MorpheTheme.accentAlt)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: MorpheTheme.radius, style: .continuous)
                            .fill(MorpheTheme.panel)
                    )
                }

                Text(post.text)
                    .font(.subheadline)
                    .foregroundStyle(.white)
                    .fixedSize(horizontal: false, vertical: true)

                if !post.workoutName.isEmpty {
                    HStack(spacing: 6) {
                        Image(systemName: "figure.run")
                            .font(.caption2.weight(.semibold))
                        Text(post.workoutName)
                            .font(.caption.weight(.semibold))
                            .lineLimit(1)
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(
                        Capsule(style: .continuous)
                            .fill(MorpheTheme.panelStrong)
                    )
                }

                // Structured session stats — the rich workout card. Every
                // chip is a logged number the auto-share carried; a post
                // without stats renders exactly as before.
                if post.hasSessionStats {
                    HStack(spacing: 6) {
                        if let sets = post.setCount {
                            sessionStatChip(symbol: "square.stack.3d.up.fill", text: "\(sets) sets")
                        }
                        if let exercises = post.exerciseCount {
                            sessionStatChip(symbol: "figure.strengthtraining.traditional", text: "\(exercises) moves")
                        }
                        if let minutes = post.durationMinutes {
                            sessionStatChip(symbol: "clock.fill", text: "\(minutes) min")
                        }
                        Spacer(minLength: 0)
                    }
                }

                if !post.prNames.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(post.prNames, id: \.self) { name in
                            HStack(spacing: 6) {
                                Image(systemName: "trophy.fill")
                                    .font(.caption2.weight(.semibold))
                                    .foregroundStyle(MorpheTheme.accent)
                                Text("PR · \(name)")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.white)
                                    .lineLimit(1)
                            }
                        }
                    }
                    .padding(10)
                    .background(
                        RoundedRectangle(cornerRadius: MorpheTheme.radius, style: .continuous)
                            .stroke(MorpheTheme.accent.opacity(0.5), lineWidth: 1)
                    )
                }

                HStack(spacing: 8) {
                    // Tap toggles a heart; long-press picks the reaction type.
                    // One doc per uid either way — the count stays honest.
                    Menu {
                        ForEach(MorpheAppStore.reactionTypes, id: \.type) { option in
                            Button {
                                store.react(to: post, type: option.type)
                            } label: {
                                Label(option.label, systemImage: option.symbol)
                            }
                        }
                        if hasReacted {
                            Button(role: .destructive) {
                                store.react(to: post, type: nil)
                            } label: {
                                Label("Remove", systemImage: "xmark")
                            }
                        }
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: myReactionSymbol)
                            Text("\(reactionCount)")
                        }
                        .feedActionChrome(isActive: hasReacted, activeColor: MorpheTheme.accent)
                    } primaryAction: {
                        store.toggleReaction(post)
                    }
                    .accessibilityLabel(hasReacted ? "Remove reaction" : "React")

                    Button {
                        showComments.toggle()
                        if showComments {
                            Task { await store.loadComments(for: post) }
                        }
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: showComments ? "bubble.right.fill" : "bubble.right")
                            if let comments = store.postComments[post.id] {
                                Text("\(comments.count)")
                            } else {
                                Text("Comment")
                            }
                        }
                    }
                    .buttonStyle(FeedActionButtonStyle(isActive: showComments, activeColor: MorpheTheme.accentAlt))
                    .accessibilityLabel(showComments ? "Hide comments" : "Show comments")

                    Button {
                        store.toggleSaved(post)
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: isSaved ? "bookmark.fill" : "bookmark")
                            Text(isSaved ? "Saved" : "Save")
                        }
                    }
                    .buttonStyle(FeedActionButtonStyle(isActive: isSaved, activeColor: MorpheTheme.accentAlt))

                    Button {
                        onRepost()
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: "arrow.2.squarepath")
                            Text("Repost")
                        }
                    }
                    .buttonStyle(FeedActionButtonStyle(isActive: false, activeColor: MorpheTheme.accent))

                    Spacer()
                }

                if showComments {
                    commentsSection
                }
            }
        }
        .contextMenu {
            if isMine {
                Button(role: .destructive) {
                    store.deleteMyPost(post)
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            } else {
                Menu {
                    ForEach(MorpheAppStore.reportReasons, id: \.self) { reason in
                        Button(reason) {
                            store.reportPost(post, reason: reason)
                        }
                    }
                } label: {
                    Label("Report Post", systemImage: "flag")
                }

                Button(role: .destructive) {
                    showBlockConfirm = true
                } label: {
                    Label("Block \(post.authorName)", systemImage: "hand.raised")
                }
            }
        }
        .confirmationDialog(
            "Block \(post.authorName)? Their posts and comments disappear from your feed, and you unfollow them. You can unblock from Profile.",
            isPresented: $showBlockConfirm,
            titleVisibility: .visible
        ) {
            Button("Block \(post.authorName)", role: .destructive) {
                store.blockAccount(uid: post.authorUid, name: post.authorName)
            }
            Button("Cancel", role: .cancel) {}
        }
        .confirmationDialog(
            "Block \(commentBlockTarget?.authorName ?? "this account")? Their posts and comments disappear from your feed, and you unfollow them. You can unblock from Profile.",
            isPresented: Binding(
                get: { commentBlockTarget != nil },
                set: { if !$0 { commentBlockTarget = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Block \(commentBlockTarget?.authorName ?? "account")", role: .destructive) {
                if let target = commentBlockTarget {
                    store.blockAccount(uid: target.authorUid, name: target.authorName)
                }
                commentBlockTarget = nil
            }
            Button("Cancel", role: .cancel) { commentBlockTarget = nil }
        }
    }

    private func sessionStatChip(symbol: String, text: String) -> some View {
        HStack(spacing: 5) {
            Image(systemName: symbol)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(MorpheTheme.accentAlt)
            Text(text)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white)
                .lineLimit(1)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: MorpheTheme.radius, style: .continuous)
                .fill(MorpheTheme.panel)
        )
    }

    /// Fetched-on-expand comments plus a one-line composer. A missing fetch
    /// shows "loading", never a fake zero.
    private var commentsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let comments = store.postComments[post.id] {
                if comments.isEmpty {
                    Text("No comments yet — start it.")
                        .font(.caption)
                        .foregroundStyle(MorpheTheme.textMuted)
                }
                ForEach(comments) { comment in
                    HStack(alignment: .top, spacing: 8) {
                        VStack(alignment: .leading, spacing: 2) {
                            HStack(spacing: 6) {
                                Text(comment.authorName)
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(.white)
                                    .lineLimit(1)
                                Text(comment.createdAt.formatted(.relative(presentation: .named)))
                                    .font(.caption2)
                                    .foregroundStyle(MorpheTheme.textMuted)
                            }
                            Text(comment.text)
                                .font(.caption)
                                .foregroundStyle(MorpheTheme.textSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }

                        Spacer(minLength: 0)
                    }
                    .contextMenu {
                        if comment.authorUid == (store.authUser?.id ?? "") {
                            Button(role: .destructive) {
                                store.deleteMyComment(comment)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        } else {
                            Menu {
                                ForEach(MorpheAppStore.reportReasons, id: \.self) { reason in
                                    Button(reason) {
                                        store.reportComment(comment, reason: reason)
                                    }
                                }
                            } label: {
                                Label("Report Comment", systemImage: "flag")
                            }
                            Button(role: .destructive) {
                                // Same confirmation the post path gets —
                                // blocking is never a single accidental tap.
                                commentBlockTarget = comment
                            } label: {
                                Label("Block \(comment.authorName)", systemImage: "hand.raised")
                            }
                        }
                    }
                }
            } else {
                Text("Loading comments…")
                    .font(.caption)
                    .foregroundStyle(MorpheTheme.textMuted)
            }

            HStack(spacing: 8) {
                TextField("Add a comment…", text: $commentDraft)
                    .textFieldStyle(MorpheFieldStyle())
                Button("Send") {
                    let text = commentDraft
                    commentDraft = ""
                    Task {
                        // A failed send gives the typed text BACK — offline
                        // or refused, the words aren't the app's to eat.
                        if await !store.addComment(to: post, text: text), commentDraft.isEmpty {
                            commentDraft = text
                        }
                    }
                }
                .buttonStyle(SecondaryCTAButtonStyle())
                .frame(width: 70)
                .disabled(commentDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .accessibilityLabel("Send comment")
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: MorpheTheme.radius, style: .continuous)
                .fill(MorpheTheme.panelStrong.opacity(0.6))
        )
    }
}

/// The FeedActionButtonStyle look as a plain modifier, for Menu labels
/// (Menus can't take a ButtonStyle the way Buttons do).
private extension View {
    func feedActionChrome(isActive: Bool, activeColor: Color) -> some View {
        self
            .font(.caption.weight(.semibold))
            .foregroundStyle(isActive ? activeColor : .white)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                Capsule(style: .continuous)
                    .fill(MorpheTheme.panel)
            )
            .overlay(
                Capsule(style: .continuous)
                    .stroke(
                        isActive ? activeColor.opacity(0.6) : MorpheTheme.strokeStrong.opacity(0.45),
                        lineWidth: 1
                    )
            )
    }
}

private struct FeedActionButtonStyle: ButtonStyle {
    let isActive: Bool
    let activeColor: Color

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.caption.weight(.semibold))
            .foregroundStyle(isActive ? activeColor : .white)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                Capsule(style: .continuous)
                    .fill(configuration.isPressed ? MorpheTheme.panelStrong : MorpheTheme.panel)
            )
            .overlay(
                Capsule(style: .continuous)
                    .stroke(
                        isActive ? activeColor.opacity(0.6) : MorpheTheme.strokeStrong.opacity(0.45),
                        lineWidth: 1
                    )
            )
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.easeInOut(duration: 0.16), value: configuration.isPressed)
    }
}

/// Small commentary sheet for reposting: your take rides on top, the
/// original stays attributed underneath.
private struct RepostSheet: View {
    @Environment(MorpheAppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let post: FeedPost
    @State private var commentary = ""

    private var originalAuthor: String {
        post.isRepost ? post.repostOfAuthor : post.authorName
    }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 14) {
                    Text("Repost \(originalAuthor)'s win")
                        .font(.title3.weight(.bold))
                        .foregroundStyle(.white)

                    Text("Add your take — it publishes as your post, credited to \(originalAuthor).")
                        .font(.subheadline)
                        .foregroundStyle(MorpheTheme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)

                    TextField("Say something about it…", text: $commentary, axis: .vertical)
                        .lineLimit(2...5)
                        .textFieldStyle(MorpheFieldStyle())

                    GlassCard {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(post.authorName)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(MorpheTheme.textMuted)
                            Text(post.text)
                                .font(.subheadline)
                                .foregroundStyle(.white)
                                .lineLimit(4)
                        }
                    }

                    Button("Repost") {
                        let text = commentary
                        dismiss()
                        Task { await store.repost(post, commentary: text) }
                    }
                    .buttonStyle(PrimaryCTAButtonStyle(accent: MorpheTheme.accent))
                }
                .padding(20)
            }
            .background(PremiumBackground())
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundStyle(.white)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}

// MARK: - REAL messaging (coach ↔ claimed client, Firestore-backed)
//
// Everything below is the real thing — live `threads/*` documents between a
// coach and the athlete who claimed one of their invite codes. The demo
// inbox types above stay untouched (flag-gated demo content).

/// The shared 1:1 chat screen — the SAME view serves the coach (from the
/// Inbox / client detail) and the athlete (from the home Coach card). Opens
/// the live listener on appear and closes it on disappear via the store.
struct ThreadChatView: View {
    @Environment(MorpheAppStore.self) private var store
    let thread: MessageThreadSummary
    /// In-place back navigation (list ↔ conversation swaps); nil hides the
    /// chevron when the view is presented on its own (single-thread sheet).
    var onBack: (() -> Void)? = nil
    @State private var draft = ""

    private var myUid: String { store.authUser?.id ?? "" }
    private var counterpart: String { thread.counterpartName(for: myUid) }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 12) {
                if let onBack {
                    Button {
                        onBack()
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(.white)
                            .frame(width: 44, height: 44)
                            .background(Circle().fill(MorpheTheme.panelStrong))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Back")
                }

                Circle()
                    .fill(MorpheTheme.panelStrong)
                    .frame(width: 42, height: 42)
                    .overlay(
                        Text(String(counterpart.prefix(1)).uppercased())
                            .font(.headline)
                            .foregroundStyle(.white)
                    )

                VStack(alignment: .leading, spacing: 4) {
                    Text(counterpart)
                        .font(.headline)
                        .foregroundStyle(.white)
                    Text("Conversation")
                        .font(.caption)
                        .foregroundStyle(MorpheTheme.textSecondary)
                }

                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)

            Divider()
                .overlay(MorpheTheme.stroke.opacity(0.8))

            ScrollViewReader { proxy in
                ScrollView(showsIndicators: false) {
                    LazyVStack(alignment: .leading, spacing: 12) {
                        if store.activeThreadMessages.isEmpty {
                            Text("No messages yet — say hello. This conversation is private to you and \(counterpart).")
                                .font(.caption)
                                .foregroundStyle(MorpheTheme.textSecondary)
                                .frame(maxWidth: .infinity, alignment: .center)
                                .padding(.top, 24)
                        }

                        ForEach(Array(store.activeThreadMessages.enumerated()), id: \.element.id) { index, message in
                            LiveMessageBubble(
                                message: message,
                                isMine: message.senderUid == myUid,
                                senderName: message.senderUid == myUid ? "You" : counterpart,
                                // Sender-run captions: name only where a run starts.
                                showsSender: index == 0
                                    || store.activeThreadMessages[index - 1].senderUid != message.senderUid
                            )
                            .id(message.id)
                        }
                    }
                    .padding(16)
                    .padding(.bottom, 8)
                }
                .onChange(of: store.activeThreadMessages.count) { _, _ in
                    if let last = store.activeThreadMessages.last {
                        withAnimation(.easeOut(duration: 0.2)) {
                            proxy.scrollTo(last.id, anchor: .bottom)
                        }
                    }
                }
            }

            Divider()
                .overlay(MorpheTheme.stroke.opacity(0.8))

            HStack(spacing: 10) {
                TextField("Type a message", text: $draft, axis: .vertical)
                    .lineLimit(1...3)
                    .textFieldStyle(MorpheFieldStyle())

                Button("Send") {
                    // Clear first so a slow network never eats a retype.
                    let text = draft
                    draft = ""
                    Task { await store.sendMessage(text) }
                }
                .buttonStyle(PrimaryCTAButtonStyle(accent: MorpheTheme.accent))
                .frame(width: 84, height: 44)
                .disabled(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding(16)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .onAppear { store.openThread(thread) }
        .onDisappear { store.closeThread() }
    }
}

/// One real chat bubble: content-hugging, capped at ~75% of the row, pushed
/// to the sender's edge — the same visual language as the demo chat rows.
private struct LiveMessageBubble: View {
    let message: ChatMessage
    let isMine: Bool
    let senderName: String
    let showsSender: Bool

    var body: some View {
        HStack(spacing: 0) {
            if isMine { Spacer(minLength: 40) }

            VStack(alignment: isMine ? .trailing : .leading, spacing: 4) {
                if showsSender {
                    Text(senderName)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(MorpheTheme.textMuted)
                }

                Text(message.text)
                    .font(.subheadline)
                    .foregroundStyle(.white)
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: MorpheTheme.radius, style: .continuous)
                            .fill(isMine ? MorpheTheme.accentAlt.opacity(0.28) : MorpheTheme.panelStrong)
                    )
                    .contextMenu {
                        Button {
                            UIPasteboard.general.string = message.text
                        } label: {
                            Label("Copy", systemImage: "doc.on.doc")
                        }
                    }
            }
            .frame(maxWidth: 300, alignment: isMine ? .trailing : .leading)

            if !isMine { Spacer(minLength: 40) }
        }
        .frame(maxWidth: .infinity, alignment: isMine ? .trailing : .leading)
    }
}

/// Athlete inbox: the real threads this account participates in (in practice
/// their coach). Mounted from the home "Coach" card — an athlete with no
/// claimed link never sees this surface at all.
struct AthleteInboxView: View {
    @Environment(MorpheAppStore.self) private var store
    @State private var openedThread: MessageThreadSummary?

    private var myUid: String { store.authUser?.id ?? "" }

    var body: some View {
        Group {
            if let openedThread {
                ThreadChatView(thread: openedThread, onBack: { self.openedThread = nil })
            } else {
                threadList
            }
        }
        .task { await store.refreshThreads() }
    }

    private var threadList: some View {
        ScrollView(showsIndicators: false) {
            LazyVStack(spacing: 0) {
                ForEach(Array(store.liveThreads.enumerated()), id: \.element.id) { index, thread in
                    Button {
                        openedThread = thread
                    } label: {
                        LiveThreadRow(thread: thread, viewerUid: myUid)
                    }
                    .buttonStyle(.plain)

                    if index < store.liveThreads.count - 1 {
                        Divider()
                            .overlay(MorpheTheme.stroke.opacity(0.5))
                            .padding(.leading, 72)
                    }
                }
            }
            .padding(.vertical, 4)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }
}

/// One real-thread inbox row: counterpart name, honest last-message preview,
/// relative time. No unread badges — Morphe doesn't track read state, so it
/// doesn't pretend to.
struct LiveThreadRow: View {
    let thread: MessageThreadSummary
    let viewerUid: String

    private var name: String { thread.counterpartName(for: viewerUid) }

    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(MorpheTheme.panelStrong)
                .frame(width: 44, height: 44)
                .overlay(
                    Text(String(name.prefix(1)).uppercased())
                        .font(.headline)
                        .foregroundStyle(.white)
                )

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(name)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                    Spacer()
                    Text(thread.updatedAt.formatted(.relative(presentation: .named)))
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(MorpheTheme.textMuted)
                }

                Text(thread.lastMessage.isEmpty ? "No messages yet" : thread.lastMessage)
                    .font(.caption)
                    .foregroundStyle(MorpheTheme.textSecondary)
                    .lineLimit(2)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .contentShape(Rectangle())
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
                    RoundedRectangle(cornerRadius: MorpheTheme.radius, style: .continuous)
                        .fill(backgroundColor)
                )
        }
    }
}
