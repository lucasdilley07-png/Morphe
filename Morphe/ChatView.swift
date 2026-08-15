import SwiftUI

struct CommunityView: View {
    @Environment(MorpheAppStore.self) private var store
    @State private var selectedStory: CommunityStoryPreview?
    @State private var showNetworkExtras = false
    @State private var showFormCamera = false
    @State private var showCalendarEditor = false
    /// Tab landing clears the floating header icons.
    var topPadding: CGFloat = MorpheTheme.Spacing.pageTopStacked

    /// One-shot per mount: land on CHATS when messages are waiting
    /// (speed audit S2-3) — Snapchat's own default, and it cuts the reply
    /// path by a tap. Deep links (pendingThreadOpenID) still win.
    @State private var didApplyLandingPane = false

    var body: some View {
        @Bindable var store = store
        return VStack(spacing: 0) {
            networkHeader

            // The swipe shell: Chats on the left, the feed on the right —
            // one horizontal gesture between your people and their work.
            // Selection is the SAME store var every deep link already sets,
            // so doors keep landing exactly where they always did.
            TabView(selection: $store.selectedCommunitySection) {
                contactScreen
                    .tag(ClientCommunitySection.contact)

                if FeatureFlags.socialFeedEnabled {
                    // The stack hosts the feed's author push (swipe-back). The
                    // system bar stays hidden — the HUD has its own chrome.
                    NavigationStack {
                        forYouScreen
                            .toolbar(.hidden, for: .navigationBar)
                    }
                    .tag(ClientCommunitySection.forYou)
                } else {
                    boardScreen
                        .tag(ClientCommunitySection.board)
                    calendarScreen
                        .tag(ClientCommunitySection.calendar)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
        }
        // The paged panes stay mounted, so .task never re-fires on a
        // swipe — without this, the inbox (one-shot fetch) only updated
        // on cold launch and unread state froze.
        .onAppear {
            guard !didApplyLandingPane else { return }
            didApplyLandingPane = true
            if store.unreadThreadCount > 0, store.pendingThreadOpenID == nil {
                store.selectedCommunitySection = .contact
            }
        }
        .onChange(of: store.selectedCommunitySection) { _, section in
            if section == .contact {
                Task { await store.refreshThreads() }
            } else {
                // The paged shell keeps panes mounted, so onDisappear never
                // fires — swiping away is the close (launch audit P2-20).
                store.closeThread()
            }
        }
        .onChange(of: store.selectedClientTab) { _, tab in
            if tab != .community { store.closeThread() }
        }
        .sheet(item: $selectedStory) { story in
            StoryHighlightSheet(story: story)
        }
        .fullScreenCover(isPresented: $showFormCamera) {
            // The capture camera (Snapchat parity): photos post to the feed,
            // clips save honestly, and Form Check rides inside as a pill —
            // same hardware, both jobs, one door.
            CaptureView()
                .environment(store)
        }
    }

    /// Fixed chrome above the swipe panes: two mono section tabs with the
    /// gold page tick, plus the camera door. HUD skin, not borrowed chrome.
    private var networkHeader: some View {
        HStack(alignment: .bottom, spacing: 22) {
            sectionTab("CHATS", .contact, showsBadge: store.unreadThreadCount > 0)
            if FeatureFlags.socialFeedEnabled {
                sectionTab("FOR YOU", .forYou)
            } else {
                // Launch shape (product audit): people, standings, schedule.
                sectionTab("BOARD", .board)
                sectionTab("CALENDAR", .calendar)
            }

            Spacer()

            if FeatureFlags.socialFeedEnabled {
            Button {
                showFormCamera = true
            } label: {
                // A bare camera glyph in a social header reads as "post a
                // photo" — and now it IS one. Form Check rides inside.
                Image(systemName: "camera.fill")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(MorpheTheme.accentText)
                    .frame(width: 48, height: 48)
                    .background(Circle().fill(MorpheTheme.panelStrong))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Camera — shoot a photo or clip")
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, topPadding)
        .padding(.bottom, 6)
    }

    private func sectionTab(_ label: String, _ section: ClientCommunitySection,
                            showsBadge: Bool = false) -> some View {
        let isActive = store.selectedCommunitySection == section
        return Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                store.selectedCommunitySection = section
            }
        } label: {
            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 5) {
                    Text(label)
                        .font(MorpheTheme.microLabel(12))
                        .tracking(1.6)
                        .foregroundStyle(isActive ? MorpheTheme.textPrimary : MorpheTheme.textMuted)
                    if showsBadge {
                        Circle()
                            .fill(MorpheTheme.brandYellow)
                            .frame(width: 6, height: 6)
                    }
                }
                Rectangle()
                    .fill(isActive ? MorpheTheme.accent : .clear)
                    .frame(width: 26, height: 3)
            }
            .frame(minHeight: 44, alignment: .bottomLeading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(showsBadge ? "\(label.capitalized), new messages" : label.capitalized)
        .accessibilityAddTraits(isActive ? .isSelected : [])
    }

    private var forYouScreen: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 16) {
                // No page title here — the shell header owns the chrome, so
                // the feed opens straight onto presence (Trained Today).
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
                                    .foregroundStyle(MorpheTheme.textPrimary)
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
            .padding(.top, 6)
            .padding(.bottom, 120)
        }
        .refreshable {
            // The one surface that always hits the network — an explicit
            // pull is the user asking for fresh. The board + challenges
            // render on this page too, so they refresh with it.
            await store.refreshFeed(force: true)
            await store.refreshLeaderboard(force: true)
            await store.refreshChallenges(force: true)
        }
    }

    /// BOARD pane: the weekly leaderboard, same honest card Progress
    /// hosts — opt-in, real names, real logged scores only.
    private var boardScreen: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 16) {
                WeeklyBoardCard()
            }
            .padding(.horizontal, 20)
            .padding(.top, 6)
            .padding(.bottom, 120)
        }
        .refreshable { await store.refreshLeaderboard(force: true) }
    }

    /// CALENDAR pane: the personal schedule — upcoming appointments plus
    /// the same editor every other schedule door uses.
    private var calendarScreen: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Text("Schedule")
                        .font(.headline)
                        .foregroundStyle(MorpheTheme.textPrimary)
                    Spacer()
                    Button("Add") { showCalendarEditor = true }
                        .buttonStyle(.plain)
                        .foregroundStyle(MorpheTheme.accentText)
                        .frame(minHeight: 44)
                }

                if store.upcomingAppointments.isEmpty {
                    GlassCard {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Nothing scheduled")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(MorpheTheme.textPrimary)
                            Text("Add a session, a coach call, or anything worth showing up for — reminders ride along automatically.")
                                .font(.caption)
                                .foregroundStyle(MorpheTheme.textSecondary)
                        }
                    }
                } else {
                    ForEach(store.upcomingAppointments) { appointment in
                        AppointmentRowView(appointment: appointment)
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 6)
            .padding(.bottom, 120)
        }
        .refreshable { await store.refreshAppointments() }
        .sheet(isPresented: $showCalendarEditor) {
            AppointmentEditorSheet(nameSuggestions: store.appointmentPeopleChoices.map(\.name))
                .environment(store)
        }
    }

    private var contactScreen: some View {
        Group {
            if FeatureFlags.multiUserEnabled {
                // Demo inbox — flag-gated sample threads only. A real
                // account never sees these.
                VStack(alignment: .leading, spacing: 0) {
                    AthleteContactInbox()
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                }
            } else {
                realContactScreen
            }
        }
        .padding(.bottom, 120)
    }

    /// THE messaging home for real accounts: the coach-thread inbox. Every
    /// "message" door in the app (Home Coach tile, story-viewer shortcut,
    /// post-workout prompt) deep-links here instead of forking its own
    /// sheet — one destination, many doors.
    private var realContactScreen: some View {
        // The inbox always mounts now — its search bar is the new-chat door,
        // which has to exist even (especially) with zero conversations. The
        // inbox owns its own refresh and empty state.
        AthleteInboxView(autoOpenOnlyThread: true)
            .padding(.top, 6)
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
                            .font(.title2.weight(.bold))
                            .foregroundStyle(MorpheTheme.textPrimary)
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
                    .foregroundStyle(MorpheTheme.accentText)
                    .frame(width: 44, height: 44)
                    .background(
                        RoundedRectangle(cornerRadius: MorpheTheme.radiusSmall, style: .continuous)
                            .fill(MorpheTheme.panelStrong)
                    )

                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(MorpheTheme.textPrimary)
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
                    .foregroundStyle(MorpheTheme.textPrimary)

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
                            .foregroundStyle(MorpheTheme.textPrimary)
                        Text(subtitle)
                            .font(.subheadline)
                            .foregroundStyle(MorpheTheme.textSecondary)
                            .multilineTextAlignment(.leading)
                    }

                    Spacer()

                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(MorpheTheme.textPrimary)
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
                        .foregroundStyle(MorpheTheme.textPrimary)
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
                                        .foregroundStyle(MorpheTheme.textPrimary)
                                    Text(story.subtitle)
                                        .font(.subheadline)
                                        .foregroundStyle(MorpheTheme.textSecondary)
                                }
                            }

                            ForEach(story.items, id: \.self) { item in
                                Text("- \(item)")
                                    .foregroundStyle(MorpheTheme.textPrimary)
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
                    .foregroundStyle(MorpheTheme.textPrimary)
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
                            .foregroundStyle(MorpheTheme.textPrimary)
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
                        .foregroundStyle(MorpheTheme.textPrimary)
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
                        .foregroundStyle(MorpheTheme.textPrimary)
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
                    TextField("Type a message", text: $draft)
                        .submitLabel(.send)
                        .onSubmit {
                            store.sendAthleteMessage(to: thread.id, text: draft)
                            draft = ""
                        }
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
                    .foregroundStyle(MorpheTheme.textPrimary)

                Text(isSearching
                     ? "Nobody in your contacts matches that search."
                     : "Connect with your coach or a training partner from Train’s Discover segment — show or scan a Morphe code under Connect.")
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
                                .foregroundStyle(MorpheTheme.textPrimary)
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
                            .foregroundStyle(MorpheTheme.textPrimary)
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
                    .foregroundStyle(MorpheTheme.textPrimary)

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
                                    .foregroundStyle(MorpheTheme.textPrimary)
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
                    .foregroundStyle(MorpheTheme.textPrimary)

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
                            .foregroundStyle(MorpheTheme.textPrimary)
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
                .foregroundStyle(MorpheTheme.textPrimary)

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
                                    .foregroundStyle(MorpheTheme.textPrimary)
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
            .foregroundStyle(MorpheTheme.textPrimary)
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
            .foregroundStyle(MorpheTheme.textPrimary)
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
                    .foregroundStyle(MorpheTheme.textPrimary)
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
                    .foregroundStyle(MorpheTheme.textPrimary)

                ForEach(store.networkSuggestions) { suggestion in
                    HStack(alignment: .top, spacing: 10) {
                        Text(suggestion.avatar)
                            .font(.title3)

                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(suggestion.name)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(MorpheTheme.textPrimary)
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
                    .foregroundStyle(MorpheTheme.textPrimary)

                if !groups.isEmpty {
                    Text("Groups")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(MorpheTheme.textPrimary)
                    ForEach(groups.prefix(2)) { group in
                        TrainingGroupCard(group: group)
                    }
                }

                if !challenges.isEmpty {
                    Text("Challenges")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(MorpheTheme.textPrimary)
                    ForEach(challenges.prefix(2)) { challenge in
                        ChallengeCard(challenge: challenge)
                    }
                }

                if !leaderboard.isEmpty {
                    Text("Ranks")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(MorpheTheme.textPrimary)
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
                .foregroundStyle(MorpheTheme.textPrimary)
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
                    .foregroundStyle(MorpheTheme.textPrimary)
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

                // Photo posts ship as base64 inside post docs (rules-capped);
                // Firebase Storage upgrades the pipeline post-Blaze.
private struct RealFeedSection: View {
    @Environment(MorpheAppStore.self) private var store
    @State private var draft = ""
    @State private var filter: FeedFilter = .ranked
    @State private var repostTarget: FeedPost?
    /// The post whose author view is pushed (a real push, swipe-back works).
    @State private var authorTarget: FeedPost?
    /// The author whose <24h story cards are playing full-screen.
    @State private var storyTarget: MorpheAppStore.TrainedTodayEntry?
    @State private var showBoardStory = false
    @State private var showRailLegend = false
    @State private var showImmersive = false
    /// Grid-tile tap: opens the immersive pager AT this post.
    @State private var immersiveStartPost: FeedPost?
    @FocusState private var composerFocused: Bool

    private enum FeedFilter: String, CaseIterable {
        /// Engagement-ranked (transparent heuristic — see rankFeedPosts).
        case ranked = "For You"
        case latest = "Latest"
        case following = "Following"
        case saved = "Saved"
    }

    private static let postLimit = 1000

    private var visiblePosts: [FeedPost] {
        switch filter {
        case .ranked:
            return store.rankedFeedPosts
        case .latest:
            return store.feedPosts
        case .following:
            return store.feedPosts.filter { store.followedUids.contains($0.authorUid) }
        case .saved:
            return store.feedPosts.filter { store.savedPostIds.contains($0.id) }
        }
    }

    /// Paging works on both orderings (ranked re-sorts whatever's loaded);
    /// the filtered lenses page nothing — they're views over loaded posts.
    private var filterSupportsPaging: Bool {
        filter == .ranked || filter == .latest
    }

    private var cleanDraft: String {
        draft.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// "You're #N this week" from the REAL fetched board, or the leader's
    /// name when the viewer isn't ranked. Honest either way.
    private var boardChipLine: String {
        let myUid = store.authUser?.id ?? ""
        if let index = store.weeklyLeaderboard.firstIndex(where: { $0.uid == myUid }) {
            return "You're #\(index + 1) on this week's board"
        }
        return "This week's board — \(store.weeklyLeaderboard.first?.name ?? "open") leads"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Section switching lives in the shell header (tabs + swipe) —
            // no in-scroll picker.
            // Presence leads the page: who trained in the last 24h, gold
            // ring = unseen. (Athlete search moved to the header magnifier —
            // universal search owns account-finding now.)
            TrainedTodayRow(
                entries: store.trainedTodayEntries,
                myUid: store.authUser?.id ?? "",
                duoStreakFor: { store.duoStreak(with: $0) },
                boardLeader: store.leaderboardOptIn ? store.weeklyLeaderboard.first?.name : nil,
                onOpenBoard: { showBoardStory = true },
                onOpen: { storyTarget = $0 },
                onEmptySelf: { composerFocused = true }
            )

            // Legend on demand (audit D8): a permanent caption was one more
            // layer between the user and the feed — now it's an ⓘ tap.
            if !store.trainedTodayEntries.isEmpty {
                HStack(spacing: 6) {
                    if showRailLegend {
                        Text("Gold ring = sessions you haven't watched · flame = Duo Streak (days you both posted)")
                            .font(.caption2)
                            .foregroundStyle(MorpheTheme.textMuted)
                    }
                    Spacer(minLength: 0)
                    Button {
                        withAnimation(.easeInOut(duration: 0.15)) { showRailLegend.toggle() }
                    } label: {
                        Image(systemName: showRailLegend ? "info.circle.fill" : "info.circle")
                            .font(.caption)
                            .foregroundStyle(MorpheTheme.textMuted)
                            .frame(width: 32, height: 24)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("What the ring colors mean")
                }
            }

            composer

            // Activity pulse (TIKTOK-PLAN T5): engagement on YOUR posts
            // since you last checked — the client-side stand-in for the
            // Blaze-gated push loop. Tap acknowledges.
            if store.unseenActivityCount > 0 {
                Button {
                    store.acknowledgeActivity()
                    Haptics.impact(.light)
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "bell.badge.fill")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(MorpheTheme.accentText)
                        Text("\(store.unseenActivityCount) new reaction\(store.unseenActivityCount == 1 ? "" : "s") on your posts since you last checked")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(MorpheTheme.textPrimary)
                            .lineLimit(1)
                        Spacer()
                        Text("OK")
                            .font(MorpheTheme.microLabel(10))
                            .tracking(1.0)
                            .foregroundStyle(MorpheTheme.textMuted)
                    }
                    .padding(.horizontal, 14)
                    .frame(minHeight: 44)
                    .background(
                        RoundedRectangle(cornerRadius: MorpheTheme.radius, style: .continuous)
                            .stroke(MorpheTheme.accent.opacity(0.5), lineWidth: 1)
                    )
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(store.unseenActivityCount) new reactions on your posts — tap to dismiss")
            }

            // Slim board chip (audit E11): the full board + challenges UI
            // lives on Progress — a second full copy here made "which tab
            // was that in?" a real question. One line, one deep link.
            if store.leaderboardOptIn, !store.weeklyLeaderboard.isEmpty {
                Button {
                    store.openProgress()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "trophy.fill")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(MorpheTheme.accentText)
                        Text(boardChipLine)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(MorpheTheme.textPrimary)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(MorpheTheme.textMuted)
                    }
                    .padding(.horizontal, 14)
                    .frame(minHeight: 44)
                    .background(
                        RoundedRectangle(cornerRadius: MorpheTheme.radius, style: .continuous)
                            .fill(MorpheTheme.panelStrong)
                    )
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Weekly board — open Progress")
            }

            HStack(spacing: 8) {
                ForEach(FeedFilter.allCases, id: \.self) { option in
                    Button(option.rawValue) {
                        filter = option
                    }
                    .buttonStyle(FilterChipStyle(isSelected: filter == option, selectedColor: MorpheTheme.accent))
                }

                Spacer()

                // The full-screen door (TIKTOK-PLAN T1).
                if !visiblePosts.isEmpty {
                    Button {
                        showImmersive = true
                    } label: {
                        Image(systemName: "arrow.up.left.and.arrow.down.right")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(MorpheTheme.textSecondary)
                            .frame(width: 40, height: 36)
                            .background(
                                RoundedRectangle(cornerRadius: MorpheTheme.chipRadius, style: .continuous)
                                    .stroke(MorpheTheme.stroke, lineWidth: 1)
                            )
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Open the feed full screen")
                }
            }

            if visiblePosts.isEmpty {
                // Empty copy renders ONLY once the fetch has answered —
                // "be the first to post" during a slow load is a lie, and
                // a network failure needs a retry, not an empty state.
                switch store.feedFetchState {
                case .idle, .loading:
                    FetchPlaceholderCard(line: "Loading the feed…")
                case .failed:
                    FetchRetryCard(message: "The feed couldn't load — check your connection.") {
                        Task { await store.refreshFeed(force: true) }
                    }
                case .loaded:
                    emptyState
                }
            } else if filter == .ranked {
                // TRENDING as a browse wall (Snapchat's Spotlight grid): two
                // columns of tiles ranked by the same transparent heuristic,
                // each tap dropping into the immersive pager AT that post.
                LazyVGrid(columns: [
                    GridItem(.flexible(), spacing: 10),
                    GridItem(.flexible(), spacing: 10)
                ], spacing: 10) {
                    ForEach(visiblePosts) { post in
                        Button {
                            immersiveStartPost = post
                        } label: {
                            FeedGridTile(post: post)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Post by \(post.authorName) — open full screen")
                        // The default lens carries the full affordance set
                        // (launch audit P1-6): author, save, repost, report,
                        // block — long-press, same actions as the list cards.
                        .contextMenu {
                            Button("View \(post.authorName)", systemImage: "person") {
                                authorTarget = post
                            }
                            Button(store.savedPostIds.contains(post.id) ? "Unsave" : "Save",
                                   systemImage: store.savedPostIds.contains(post.id) ? "bookmark.fill" : "bookmark") {
                                store.toggleSaved(post)
                            }
                            Button("Repost", systemImage: "arrow.2.squarepath") {
                                repostTarget = post
                            }
                            Menu("Report Post") {
                                ForEach(MorpheAppStore.reportReasons, id: \.self) { reason in
                                    Button(reason) { store.reportPost(post, reason: reason) }
                                }
                            }
                            if post.authorUid != store.authUser?.id {
                                Button("Block \(post.authorName)", systemImage: "hand.raised", role: .destructive) {
                                    store.blockAccount(uid: post.authorUid, name: post.authorName)
                                }
                            }
                        }
                        // Infinite scroll: the last loaded tile pulls the
                        // next page in — continuation should be free.
                        .onAppear {
                            if post.id == visiblePosts.last?.id,
                               store.feedHasOlderPosts {
                                Task { await store.loadOlderFeedPosts() }
                            }
                        }
                    }
                }
            } else {
                ForEach(visiblePosts) { post in
                    FeedPostCard(
                        post: post,
                        onRepost: { repostTarget = post },
                        onAuthorTap: { authorTarget = post }
                    )
                    // Infinite scroll (TIKTOK-PLAN T8): the last loaded card
                    // pulls the next page in — continuation should be free.
                    .onAppear {
                        if post.id == visiblePosts.last?.id, filterSupportsPaging,
                           store.feedHasOlderPosts {
                            Task { await store.loadOlderFeedPosts() }
                        }
                    }
                }

                // Cursor paging (READINESS-300 R4): the feed loads one page;
                // history is a tap away instead of 50 posts of reads up front.
                if store.feedHasOlderPosts, !store.feedPosts.isEmpty {
                    if filterSupportsPaging {
                        Button {
                            Task { await store.loadOlderFeedPosts() }
                        } label: {
                            Text("Load Older")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(MorpheTheme.textSecondary)
                                .frame(maxWidth: .infinity, minHeight: 44)
                                .background(
                                    Capsule(style: .continuous)
                                        .stroke(MorpheTheme.stroke, lineWidth: 1)
                                )
                                .contentShape(Capsule())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Load older posts")
                    } else {
                        // Paging under a filter looked broken: a fetched
                        // page can contain zero matching posts, so the list
                        // "does nothing". Name the behavior instead.
                        Text("Filtering what's loaded — switch to For You or Latest to load older posts.")
                            .font(.caption2)
                            .foregroundStyle(MorpheTheme.textMuted)
                            .frame(maxWidth: .infinity)
                    }
                }
            }
        }
        // Each presentation isolated on its own background view (same rule
        // WorkoutView documents): stacking sheet/cover modifiers on ONE
        // view makes later presents silently fail or crash.
        .background(EmptyView().sheet(item: $repostTarget) { post in
            RepostSheet(post: post)
        })
        .navigationDestination(item: $authorTarget) { post in
            FeedAuthorView(authorUid: post.authorUid,
                           authorName: post.authorName,
                           verified: post.verified)
        }
        .background(EmptyView().fullScreenCover(item: $storyTarget) { entry in
            StorySessionViewer(entry: entry)
                .environment(store)
        })
        .background(EmptyView().fullScreenCover(isPresented: $showBoardStory) {
            BoardStoryView()
                .environment(store)
        })
        .background(EmptyView().fullScreenCover(isPresented: $showImmersive) {
            // Snapshot of the current lens order at open — the pager owns
            // continuation from there (it pulls pages itself).
            ImmersiveFeedViewer(posts: visiblePosts)
                .environment(store)
        })
        .background(EmptyView().fullScreenCover(item: $immersiveStartPost) { post in
            // The grid door: same pager, opened at the tapped tile.
            ImmersiveFeedViewer(posts: visiblePosts, startAt: post.id)
                .environment(store)
        })
        .task {
            await store.refreshFeed()
            await store.refreshLeaderboard()
            await store.refreshChallenges()
        }
    }

    // (athleteSearch card removed: the header magnifier's universal search
    // owns account-finding — presence took the hero slot it occupied.)

    private var composer: some View {
        // "Start a post" anatomy: your avatar leads a rounded prompt; the
        // counter + Post controls only appear once the composer is active.
        // The field stays mounted so the story rail's focus hook works.
        let isActive = composerFocused || !draft.isEmpty
        let myAccent = MorpheTheme.colors(for: store.profileShowcase.accentPalette).primary
        return GlassCard {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 10) {
                    Circle()
                        .fill(MorpheTheme.panelStrong)
                        .frame(width: 38, height: 38)
                        .overlay(
                            Text(String(store.clientProfile.name.prefix(1)).uppercased())
                                .font(.subheadline.weight(.bold))
                                .foregroundStyle(myAccent)
                        )
                        .accessibilityHidden(true)

                    TextField("Share a win…", text: $draft, axis: .vertical)
                        .lineLimit(isActive ? 2...5 : 1...1)
                        .textFieldStyle(MorpheFieldStyle())
                        .focused($composerFocused)
                }

                if isActive {
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
                        .frame(width: 96)
                        .disabled(cleanDraft.isEmpty || draft.count > Self.postLimit)
                    }
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
                    .foregroundStyle(MorpheTheme.textPrimary)

                Text(emptyStateDetail)
                    .font(.subheadline)
                    .foregroundStyle(MorpheTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var emptyStateSymbol: String {
        switch filter {
        case .ranked, .latest: return "sparkles"
        case .following: return "person.2"
        case .saved: return "bookmark"
        }
    }

    private var emptyStateTitle: String {
        switch filter {
        case .ranked, .latest: return "No posts yet — share the first win"
        case .following: return store.followedUids.isEmpty ? "Nobody followed yet" : "No posts here yet"
        case .saved: return "Nothing saved yet"
        }
    }

    private var emptyStateDetail: String {
        switch filter {
        case .ranked, .latest:
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


// MARK: - Trained Today (presence row + story viewer)
//
// Story MECHANICS in the HUD's own skin: squared gold rings, mono
// progress ticks, full-screen stat cards — never anyone else's chrome.

private struct TrainedTodayRow: View {
    let entries: [MorpheAppStore.TrainedTodayEntry]
    let myUid: String
    /// Duo Streak per author (consecutive both-posted days) — ≥2 renders
    /// the flame chip on that bubble.
    var duoStreakFor: (String) -> Int = { _ in 0 }
    /// Weekly-board leader name — non-nil adds the BOARD bubble.
    var boardLeader: String? = nil
    var onOpenBoard: () -> Void = {}
    let onOpen: (MorpheAppStore.TrainedTodayEntry) -> Void
    let onEmptySelf: () -> Void

    private var selfHasStory: Bool {
        entries.contains { $0.id == myUid }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("TRAINED TODAY")
                .font(MorpheTheme.microLabel(10))
                .tracking(1.4)
                .foregroundStyle(MorpheTheme.textMuted)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 14) {
                    if !selfHasStory {
                        // Your empty slot: the mirror. Tapping it opens the
                        // composer — your people can't see a session you
                        // didn't share.
                        StoryBubble(initial: "+", name: "You", ringState: .empty) {
                            onEmptySelf()
                        }
                        .accessibilityLabel("Share today's session")
                    }
                    ForEach(entries) { entry in
                        let duo = entry.id == myUid ? 0 : duoStreakFor(entry.id)
                        let accentId = entry.posts.first?.authorAccent ?? ""
                        StoryBubble(
                            initial: String(entry.name.prefix(1)).uppercased(),
                            name: entry.id == myUid ? "You" : entry.name,
                            ringState: entry.hasUnseen ? .unseen : .seen,
                            accent: accentId.isEmpty ? MorpheTheme.textPrimary : MorpheTheme.accentColor(forPaletteId: accentId),
                            duoStreak: duo
                        ) {
                            onOpen(entry)
                        }
                        .accessibilityLabel(
                            "\(entry.id == myUid ? "Your" : "\(entry.name)'s") sessions from the last day\(entry.hasUnseen ? ", new" : "")"
                                + (duo >= 2 ? ", \(duo)-day duo streak" : "")
                        )
                    }

                    // The board rides the row as its own tile: presence for
                    // the week's competition, not just the last 24h.
                    if let boardLeader {
                        // Named "Board", not the leader — a person's name
                        // under a presence-style bubble reads as "they
                        // posted a story", which this is not.
                        StoryBubble(initial: "#1", name: "Board", ringState: .seen) {
                            onOpenBoard()
                        }
                        .accessibilityLabel("Weekly board — \(boardLeader) leads")
                    }
                }
                .padding(.vertical, 2)
            }
        }
    }
}

private struct StoryBubble: View {
    enum RingState { case unseen, seen, empty }

    let initial: String
    let name: String
    let ringState: RingState
    /// The author's self-declared identity color; white = none declared.
    var accent: Color = .white
    /// ≥2 shows the Duo Streak flame chip (Morphe's name, Morphe's chip).
    var duoStreak: Int = 0
    let action: () -> Void

    private var ringColor: Color {
        switch ringState {
        case .unseen: return MorpheTheme.brandYellow
        case .seen: return MorpheTheme.stroke
        case .empty: return MorpheTheme.textPrimary.opacity(0.30)
        }
    }

    var body: some View {
        Button(action: action) {
            VStack(spacing: 5) {
                // Squared HUD ring — deliberately NOT a soft gradient circle.
                RoundedRectangle(cornerRadius: MorpheTheme.radius, style: .continuous)
                    .stroke(ringColor, style: StrokeStyle(
                        lineWidth: ringState == .unseen ? 2 : 1,
                        dash: ringState == .empty ? [4, 3] : []
                    ))
                    .frame(width: 58, height: 58)
                    .overlay(
                        Circle()
                            .fill(MorpheTheme.panelStrong)
                            .frame(width: 44, height: 44)
                            .overlay(
                                Text(initial)
                                    .font(.headline)
                                    .foregroundStyle(ringState == .empty ? MorpheTheme.accent : accent)
                            )
                    )
                    .overlay(alignment: .topTrailing) {
                        if duoStreak >= 2 {
                            HStack(spacing: 2) {
                                Image(systemName: "flame.fill")
                                    .font(.system(size: 8, weight: .bold))
                                Text("\(duoStreak)")
                                    .font(MorpheTheme.microLabel(9))
                            }
                            .foregroundStyle(.black)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 2)
                            .background(
                                RoundedRectangle(cornerRadius: MorpheTheme.chipRadius, style: .continuous)
                                    .fill(MorpheTheme.brandYellow)
                            )
                            .offset(x: 6, y: -6)
                        }
                    }
                Text(name)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(MorpheTheme.textSecondary)
                    .lineLimit(1)
                    .frame(width: 62)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

/// Full-screen pager over one author's <24h session cards. Mechanics:
/// tap right = next, tap left = back, swipe down = close, ~5s auto-
/// advance, mono progress ticks. Content is the HUD stat-card language —
/// every number a logged fact.
private struct StorySessionViewer: View {
    @Environment(MorpheAppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let entry: MorpheAppStore.TrainedTodayEntry

    @State private var index = 0
    @State private var replyDraft = ""
    @FocusState private var replyFocused: Bool

    private var post: FeedPost { entry.posts[min(index, entry.posts.count - 1)] }

    var body: some View {
        ZStack {
            PremiumBackground().ignoresSafeArea()

            // Tap zones: leading third = back, the rest = forward.
            HStack(spacing: 0) {
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture { step(-1) }
                    .frame(maxWidth: .infinity)
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture { step(1) }
                    .frame(maxWidth: .infinity)
            }

            VStack(spacing: 14) {
                // Mono progress ticks — thin rectangles, not rounded pills.
                HStack(spacing: 4) {
                    ForEach(entry.posts.indices, id: \.self) { tick in
                        Rectangle()
                            .fill(tick <= index ? MorpheTheme.brandYellow : MorpheTheme.stroke)
                            .frame(height: 2)
                    }
                }

                HStack(spacing: 8) {
                    Text(entry.name.uppercased())
                        .font(MorpheTheme.microLabel(11))
                        .tracking(1.4)
                        .foregroundStyle(post.authorAccent.isEmpty
                            ? MorpheTheme.textPrimary
                            : MorpheTheme.accentColor(forPaletteId: post.authorAccent))
                    if entry.verified {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.caption)
                            .foregroundStyle(feedVerifiedSealBlue)
                    }
                    Text(post.createdAt.formatted(.relative(presentation: .named)).uppercased())
                        .font(MorpheTheme.microLabel(10))
                        .tracking(1.2)
                        .foregroundStyle(MorpheTheme.textMuted)
                    Spacer()
                    // The author IS my coach: one tap to the messaging
                    // surface — a story reply sometimes wants a thread.
                    if entry.id == store.linkedCoachUid, !store.linkedCoachUid.isEmpty {
                        Button {
                            dismiss()
                            store.openCommunity(.contact)
                        } label: {
                            Image(systemName: "bubble.left.and.bubble.right.fill")
                                .font(.subheadline.weight(.bold))
                                .foregroundStyle(MorpheTheme.accentAlt)
                                .frame(width: 44, height: 44)
                                .contentShape(Rectangle())
                        }
                        .accessibilityLabel("Message your coach")
                    }
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(MorpheTheme.textPrimary)
                            .frame(width: 44, height: 44)
                            .contentShape(Rectangle())
                    }
                    .accessibilityLabel("Close stories")
                }

                Spacer()

                StoryCardView(post: post)

                Spacer()

                // The reactions, VISIBLE — no long-press discovery problem —
                // writing the same one-per-uid docs as the feed.
                HStack(spacing: 10) {
                    ForEach(MorpheAppStore.reactionTypes, id: \.type) { reaction in
                        let isMine = store.myReactionTypes[post.id] == reaction.type
                        Button {
                            store.react(to: post, type: isMine ? nil : reaction.type)
                        } label: {
                            Image(systemName: reaction.symbol)
                                .font(.subheadline.weight(.bold))
                                .foregroundStyle(isMine ? MorpheTheme.brandYellow : MorpheTheme.textPrimary)
                                .frame(width: 44, height: 44)
                                .background(
                                    RoundedRectangle(cornerRadius: MorpheTheme.radiusSmall, style: .continuous)
                                        .stroke(isMine ? MorpheTheme.brandYellow.opacity(0.6) : MorpheTheme.stroke, lineWidth: 1)
                                )
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(isMine ? "Remove \(reaction.label)" : reaction.label)
                    }

                    // "Comment" not "Reply": every story app trains people
                    // that a story reply is private. This one publishes a
                    // public comment on the post — the label must say so.
                    TextField("Comment publicly…", text: $replyDraft)
                        .textFieldStyle(MorpheFieldStyle())
                        .focused($replyFocused)
                        .onSubmit { sendReply() }
                        .submitLabel(.send)
                }
            }
            .padding(20)

            HUDCornerTicks(arm: 22, color: Color.white.opacity(0.35))
                .padding(14)
                .allowsHitTesting(false)
        }
        .gesture(
            DragGesture(minimumDistance: 40)
                .onEnded { value in
                    if value.translation.height > 60 { dismiss() }
                }
        )
        // Seen + auto-advance ride the index: each card marks itself, then
        // ~5s later steps forward (typing a reply pauses the clock).
        .task(id: index) {
            store.markStorySeen(post)
            try? await Task.sleep(for: .seconds(5))
            guard !Task.isCancelled, !replyFocused else { return }
            step(1)
        }
    }

    private func step(_ delta: Int) {
        let next = index + delta
        if next < 0 { return }
        if next >= entry.posts.count {
            dismiss()
            return
        }
        index = next
        Haptics.selection()
    }

    private func sendReply() {
        let text = replyDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        let target = post
        replyDraft = ""
        replyFocused = false
        Task {
            if await store.addComment(to: target, text: text) {
                store.noteStoryReplySent()
            }
        }
    }
}

/// The weekly board as a full-screen HUD poster — the row's competition
/// tile. Reads the fetched board only; opt-in gates the bubble upstream.
private struct BoardStoryView: View {
    @Environment(MorpheAppStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            PremiumBackground().ignoresSafeArea()

            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Text("THIS WEEK'S BOARD")
                        .font(MorpheTheme.microLabel(11))
                        .tracking(2.4)
                        .foregroundStyle(MorpheTheme.textPrimary.opacity(0.55))
                    Spacer()
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(MorpheTheme.textPrimary)
                            .frame(width: 44, height: 44)
                            .contentShape(Rectangle())
                    }
                    .accessibilityLabel("Close board")
                }

                Spacer()

                VStack(alignment: .leading, spacing: 14) {
                    ForEach(Array(store.weeklyLeaderboard.prefix(3).enumerated()), id: \.element.uid) { index, entry in
                        HStack(spacing: 12) {
                            Text("#\(index + 1)")
                                .scaledFont(size: 22, weight: .bold, design: .monospaced)
                                .foregroundStyle(index == 0 ? MorpheTheme.brandYellow : Color.white.opacity(0.55))
                                .frame(width: 44, alignment: .leading)
                            Text(entry.name)
                                .scaledFont(size: 22, weight: .black)
                                .foregroundStyle(MorpheTheme.textPrimary)
                                .lineLimit(1)
                            Spacer()
                            Text("\(entry.score) SETS")
                                .scaledFont(size: 14, weight: .bold, design: .monospaced)
                                .tracking(1.2)
                                .foregroundStyle(MorpheTheme.brandYellow)
                        }
                    }
                }

                Spacer()

                Button("Open Progress") {
                    dismiss()
                    store.openProgress()
                }
                .buttonStyle(PrimaryCTAButtonStyle(accent: MorpheTheme.brandYellow))

                HStack {
                    Spacer()
                    Text("TRAIN HONEST")
                        .scaledFont(size: 11, weight: .bold, design: .monospaced)
                        .tracking(1.6)
                        .foregroundStyle(MorpheTheme.brandYellow)
                }
            }
            .padding(20)

            HUDCornerTicks(arm: 22, color: Color.white.opacity(0.35))
                .padding(14)
                .allowsHitTesting(false)
        }
        .gesture(
            DragGesture(minimumDistance: 40)
                .onEnded { value in
                    if value.translation.height > 60 { dismiss() }
                }
        )
    }
}

/// One post as a full-screen HUD stat poster — the share-card language,
/// live in the viewer.
/// TIKTOK-PLAN T1: full-screen, one-post-per-screen vertical pager over
/// the loaded feed — TikTok's consumption pattern on Morphe's honest
/// data-driven cards. Swipe up advances; the X (or swipe-down on the
/// cover) exits. When video lands post-Blaze, it slots into these same
/// pages unchanged.
struct ImmersiveFeedViewer: View {
    @Environment(MorpheAppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let posts: [FeedPost]
    /// Post id to open on — the grid tap lands mid-feed, not at the top.
    var startAt: String? = nil
    /// The page the scroll settled on (drives honest seen-marking).
    @State private var settledPostId: String?

    var body: some View {
        ZStack(alignment: .topTrailing) {
            PremiumBackground().ignoresSafeArea()

            ScrollViewReader { proxy in
                ScrollView(.vertical, showsIndicators: false) {
                    LazyVStack(spacing: 0) {
                        ForEach(posts) { post in
                            immersivePage(post)
                                .containerRelativeFrame(.vertical)
                                .id(post.id)
                        }
                    }
                    .scrollTargetLayout()
                }
                .scrollTargetBehavior(.paging)
                // Seen = the page you actually LANDED on — pre-rendered
                // neighbors don't clear unseen rings (launch audit P2-21).
                .scrollPosition(id: $settledPostId)
                .onChange(of: settledPostId) { _, id in
                    if let id, let post = posts.first(where: { $0.id == id }) {
                        store.markStorySeen(post)
                    }
                }
                .onAppear {
                    // The opening page IS on screen — seed the settle id so
                    // it gets marked seen like every later page.
                    settledPostId = startAt ?? posts.first?.id
                    // Two-beat landing (launch audit P1-9): the immediate
                    // scrollTo can no-op while the lazy stack is still
                    // materializing — re-issue after first layout so the
                    // tapped tile is the page that shows.
                    guard let startAt else { return }
                    proxy.scrollTo(startAt, anchor: .top)
                    Task { @MainActor in
                        try? await Task.sleep(nanoseconds: 50_000_000)
                        proxy.scrollTo(startAt, anchor: .top)
                    }
                }
            }

            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(MorpheTheme.textPrimary)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Close immersive feed")
            .padding(.trailing, 8)
        }
    }

    private func immersivePage(_ post: FeedPost) -> some View {
        VStack(spacing: 14) {
            Spacer(minLength: 0)
            StoryCardView(post: post)
                .padding(.horizontal, 24)

            // One-gesture engagement: the visible react row from the story
            // viewer, plus double-tap anywhere on the page.
            HStack(spacing: 18) {
                ForEach(MorpheAppStore.reactionTypes, id: \.type) { option in
                    Button {
                        store.react(to: post, type: option.type)
                        Haptics.impact(.light)
                    } label: {
                        Image(systemName: option.symbol)
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(store.myReactionTypes[post.id] == option.type
                                ? MorpheTheme.accent : MorpheTheme.textPrimary)
                            .frame(width: 44, height: 44)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(option.label)
                }
                Spacer()
                if let count = store.feedReactionCounts[post.id], count > 0 {
                    Text("\(count)")
                        .font(.caption.weight(.bold).monospaced())
                        .foregroundStyle(MorpheTheme.textSecondary)
                }
            }
            .padding(.horizontal, 28)
            Spacer(minLength: 0)
        }
        .contentShape(Rectangle())
        .onTapGesture(count: 2) {
            store.toggleReaction(post)
            Haptics.impact(.light)
        }
        .onAppear {
            // The pager pulls the next page in before the user runs out.
            // (Seen-marking moved to the scroll-settle handler — rendering
            // a neighbor is not watching it.)
            if post.id == posts.last?.id, store.feedHasOlderPosts {
                Task { await store.loadOlderFeedPosts() }
            }
        }
    }
}

/// One trending-wall tile: the photo when the post has one, otherwise a
/// mini stat poster in the author's accent — every tile is real content,
/// never a gray placeholder. 4:5 like the feed images.
struct FeedGridTile: View {
    @Environment(MorpheAppStore.self) private var store
    let post: FeedPost

    private var accent: Color {
        MorpheTheme.accentColor(forPaletteId: post.authorAccent)
    }

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            if let image = FeedImageCache.image(for: post) {
                Color.clear
                    .aspectRatio(4 / 5, contentMode: .fit)
                    .overlay(
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                    )
                    .clipped()
                // Ink the caption strip so the name reads on any photo.
                LinearGradient(
                    colors: [.clear, .black.opacity(0.75)],
                    startPoint: .center,
                    endPoint: .bottom
                )
            } else {
                VStack(alignment: .leading, spacing: 6) {
                    Text(post.workoutName.isEmpty ? "SESSION" : post.workoutName.uppercased())
                        .font(MorpheTheme.microLabel(10))
                        .tracking(1.4)
                        .foregroundStyle(accent)
                        .lineLimit(2)
                    Text(post.text.trimmingCharacters(in: .whitespaces))
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(MorpheTheme.textPrimary)
                        .lineLimit(5)
                        .multilineTextAlignment(.leading)
                    Spacer(minLength: 0)
                    if post.hasSessionStats {
                        Text([
                            post.setCount.map { "\($0) SETS" },
                            post.durationMinutes.map { "\($0) MIN" }
                        ].compactMap(\.self).joined(separator: " · "))
                            .font(MorpheTheme.microLabel(9))
                            .tracking(1.0)
                            .foregroundStyle(MorpheTheme.brandYellow)
                    }
                }
                .padding(10)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .aspectRatio(4 / 5, contentMode: .fit)
                .background(MorpheTheme.panelStrong)
            }

            // Author + live reaction count — the "why tap this" line.
            HStack(spacing: 5) {
                Text(post.authorName)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(MorpheTheme.textPrimary)
                    .lineLimit(1)
                if post.verified {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(MorpheTheme.brandYellow)
                }
                Spacer(minLength: 0)
                if let count = store.feedReactionCounts[post.id], count > 0 {
                    Image(systemName: "heart.fill")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(MorpheTheme.brandYellow)
                    Text("\(count)")
                        .font(.caption2.weight(.bold).monospaced())
                        .foregroundStyle(MorpheTheme.textPrimary)
                }
            }
            .padding(8)
        }
        .clipShape(RoundedRectangle(cornerRadius: MorpheTheme.radius, style: .continuous))
        .contentShape(RoundedRectangle(cornerRadius: MorpheTheme.radius, style: .continuous))
    }
}

/// Decoded-once photo store: base64 → UIImage per post id. Every surface
/// (grid tile, feed card, immersive page) hits this instead of re-decoding
/// a JPEG on each scroll frame.
enum FeedImageCache {
    private static let cache: NSCache<NSString, UIImage> = {
        let cache = NSCache<NSString, UIImage>()
        // Bounded (speed audit S1-4): unbounded NSCache made eviction
        // opaque, and every eviction is a main-thread re-decode later.
        cache.countLimit = 200
        return cache
    }()

    static func image(for post: FeedPost) -> UIImage? {
        guard post.hasImage else { return nil }
        if let hit = cache.object(forKey: post.id as NSString) { return hit }
        guard let data = Data(base64Encoded: post.imageB64),
              let decoded = UIImage(data: data) else { return nil }
        // Pre-decoded bitmap: draw-time JPEG decompression was the hidden
        // cost on the scroll path.
        let prepared = decoded.preparingForDisplay() ?? decoded
        cache.setObject(prepared, forKey: post.id as NSString)
        return prepared
    }
}

private struct StoryCardView: View {
    let post: FeedPost

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Photo posts lead with the photo — the poster IS the content,
            // and the session chrome would just crowd it.
            if post.hasImage, let image = FeedImageCache.image(for: post) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(maxWidth: .infinity)
                    .aspectRatio(4 / 5, contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: MorpheTheme.radius, style: .continuous))
                    .padding(.bottom, 14)
            }

            // A pure photo post isn't a session — "SESSION / Training
            // Session" chrome on it would claim a workout that wasn't
            // attached. Session dressing renders only when session facts do.
            if !post.hasImage || post.hasSessionStats || !post.workoutName.isEmpty {
                Text("SESSION")
                    .font(MorpheTheme.microLabel(11))
                    .tracking(2.4)
                    .foregroundStyle(MorpheTheme.textPrimary.opacity(0.55))
                    .padding(.bottom, 10)

                Text(post.workoutName.isEmpty ? "Training Session" : post.workoutName)
                    .scaledFont(size: 34, weight: .black)
                    .foregroundStyle(MorpheTheme.textPrimary)
                    .lineLimit(3)
                    .minimumScaleFactor(0.6)
                    .padding(.bottom, 14)
            }

            if post.hasSessionStats {
                Text([
                    post.setCount.map { "\($0) SETS" },
                    post.exerciseCount.map { "\($0) MOVES" },
                    post.durationMinutes.map { "\($0) MIN" }
                ].compactMap(\.self).joined(separator: "   ·   "))
                    .scaledFont(size: 14, weight: .bold, design: .monospaced)
                    .tracking(1.2)
                    .foregroundStyle(MorpheTheme.brandYellow)
                    .padding(.bottom, 12)
            }

            ForEach(post.prNames.prefix(3), id: \.self) { name in
                HStack(spacing: 8) {
                    Image(systemName: "trophy.fill")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(MorpheTheme.brandYellow)
                    Text("NEW PR · \(name.uppercased())")
                        .scaledFont(size: 12, weight: .bold, design: .monospaced)
                        .tracking(1.2)
                        .foregroundStyle(MorpheTheme.textPrimary)
                }
                .padding(.bottom, 6)
            }

            if !post.text.trimmingCharacters(in: .whitespaces).isEmpty {
                Text(post.text)
                    .font(.subheadline)
                    .foregroundStyle(MorpheTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 6)
            }

            Rectangle()
                .fill(MorpheTheme.stroke)
                .frame(height: 1)
                .padding(.vertical, 14)

            HStack {
                Text(post.authorName.uppercased())
                    .scaledFont(size: 11, weight: .semibold, design: .monospaced)
                    .tracking(1.6)
                    .foregroundStyle(MorpheTheme.textPrimary.opacity(0.7))
                Spacer()
                Text("TRAIN HONEST")
                    .scaledFont(size: 11, weight: .bold, design: .monospaced)
                    .tracking(1.6)
                    .foregroundStyle(MorpheTheme.brandYellow)
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: MorpheTheme.radius, style: .continuous)
                .fill(MorpheTheme.panel)
                .overlay(
                    RoundedRectangle(cornerRadius: MorpheTheme.radius, style: .continuous)
                        .stroke(MorpheTheme.stroke, lineWidth: 1)
                )
        )
        .allowsHitTesting(false)
    }
}

/// The honest author view: name, seal, follow state, and this author's
/// posts from the currently loaded feed — nothing invented. (The richer
/// NetworkProfilePreview sheet is demo-shaped — rank/mutuals it can't
/// know for a real account — so the feed deliberately doesn't use it.)
/// Pushed, not sheeted: edge-swipe-back plus the custom back row.
private struct FeedAuthorView: View {
    @Environment(MorpheAppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let authorUid: String
    let authorName: String
    let verified: Bool

    private var authorPosts: [FeedPost] {
        store.feedPosts.filter { $0.authorUid == authorUid }
    }

    private var isMine: Bool { authorUid == (store.authUser?.id ?? "") }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 16) {
                Button {
                    dismiss()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "chevron.left")
                            .scaledFont(size: 10, weight: .bold)
                        Text("FEED")
                            .font(MorpheTheme.microLabel(10))
                            .tracking(1.4)
                    }
                    .foregroundStyle(MorpheTheme.accent)
                    .padding(.vertical, 6)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Back to the feed")

                GlassCard {
                    HStack(spacing: 14) {
                        let accentId = authorPosts.first?.authorAccent ?? ""
                        Circle()
                            .fill(MorpheTheme.panelStrong)
                            .frame(width: 56, height: 56)
                            .overlay(
                                Text(String(authorName.prefix(1)).uppercased())
                                    .font(.title2.weight(.bold))
                                    .foregroundStyle(accentId.isEmpty
                                        ? MorpheTheme.textPrimary
                                        : MorpheTheme.accentColor(forPaletteId: accentId))
                            )
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 6) {
                                Text(authorName)
                                    .font(.title3.weight(.bold))
                                    .foregroundStyle(MorpheTheme.textPrimary)
                                if verified {
                                    Image(systemName: "checkmark.seal.fill")
                                        .font(.subheadline)
                                        .foregroundStyle(feedVerifiedSealBlue)
                                        .accessibilityLabel("Verified")
                                }
                            }
                            // Byline from their newest post — publish-time
                            // facts, so it's as current as their last share.
                            if let headline = authorPosts.first?.authorHeadline, !headline.isEmpty {
                                Text(headline)
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(MorpheTheme.textSecondary)
                                    .lineLimit(1)
                            }
                            Text("\(authorPosts.count) post\(authorPosts.count == 1 ? "" : "s") in your feed")
                                .font(.caption)
                                .foregroundStyle(MorpheTheme.textSecondary)
                        }
                        Spacer()
                        if !isMine, store.isRealFeedActive {
                            Button(store.isFollowing(authorUid) ? "Following" : "Follow") {
                                store.toggleFollow(uid: authorUid, name: authorName)
                            }
                            .buttonStyle(FilterChipStyle(
                                isSelected: store.isFollowing(authorUid),
                                selectedColor: MorpheTheme.accent))
                        }
                    }
                }

                ForEach(authorPosts) { post in
                    GlassCard {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(post.createdAt.formatted(.relative(presentation: .named)))
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(MorpheTheme.textMuted)
                            // Photo posts render their photo here too — this
                            // was the one surface the field never reached
                            // (launch audit P1-7).
                            if post.hasImage, let image = FeedImageCache.image(for: post) {
                                Image(uiImage: image)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(maxWidth: .infinity)
                                    .aspectRatio(4 / 5, contentMode: .fit)
                                    .clipShape(RoundedRectangle(cornerRadius: MorpheTheme.radius, style: .continuous))
                            }
                            if !post.text.trimmingCharacters(in: .whitespaces).isEmpty {
                                Text(post.text)
                                    .font(.subheadline)
                                    .foregroundStyle(MorpheTheme.textPrimary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }
                }

                Text("Showing this athlete's posts from the feed you've loaded.")
                    .font(.caption2)
                    .foregroundStyle(MorpheTheme.textMuted)
            }
            .padding(20)
        }
        .background(PremiumBackground().ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
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
    /// Author block tap — the parent pushes the author view.
    let onAuthorTap: () -> Void

    @State private var showComments = false
    @State private var commentDraft = ""
    @State private var showBlockConfirm = false
    @State private var showDeletePostConfirm = false
    @State private var deletingComment: PostComment?
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
                    // The author block is the profile door — a feed you can't
                    // navigate out of is a dead end.
                    Button {
                        onAuthorTap()
                    } label: {
                        HStack(spacing: 10) {
                            Circle()
                                .fill(MorpheTheme.panelStrong)
                                .frame(width: 40, height: 40)
                                .overlay(
                                    Text(String(post.authorName.prefix(1)).uppercased())
                                        .font(.headline)
                                        .foregroundStyle(post.authorAccent.isEmpty
                                            ? MorpheTheme.textPrimary
                                            : MorpheTheme.accentColor(forPaletteId: post.authorAccent))
                                )

                            VStack(alignment: .leading, spacing: 2) {
                                HStack(spacing: 5) {
                                    Text(post.authorName)
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(MorpheTheme.textPrimary)
                                        .lineLimit(1)

                                    if post.verified {
                                        Image(systemName: "checkmark.seal.fill")
                                            .font(.caption)
                                            .foregroundStyle(feedVerifiedSealBlue)
                                            .accessibilityLabel("Verified")
                                    }
                                }

                                // The byline: real facts stamped at publish
                                // time (sport + streak), never typed.
                                if !post.authorHeadline.isEmpty {
                                    Text(post.authorHeadline)
                                        .font(.caption)
                                        .foregroundStyle(MorpheTheme.textSecondary)
                                        .lineLimit(1)
                                }

                                HStack(spacing: 6) {
                                    Text(post.createdAt.formatted(.relative(presentation: .named)))
                                        .font(.caption2.weight(.semibold))
                                        .foregroundStyle(MorpheTheme.textMuted)
                                    // Duo Streak: consecutive days you BOTH
                                    // posted — presence turned into a bond.
                                    if !isMine {
                                        let duo = store.duoStreak(with: post.authorUid)
                                        if duo >= 2 {
                                            HStack(spacing: 2) {
                                                Image(systemName: "flame.fill")
                                                    .font(.system(size: 8, weight: .bold))
                                                Text("DUO \(duo)")
                                                    .font(MorpheTheme.microLabel(9))
                                                    .tracking(0.5)
                                            }
                                            .foregroundStyle(MorpheTheme.brandYellow)
                                            .accessibilityLabel("\(duo)-day duo streak with \(post.authorName)")
                                        }
                                    }
                                }
                            }
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("View \(post.authorName)'s posts")

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

                // Capture-camera photo — leads the card, caption below.
                if post.hasImage, let image = FeedImageCache.image(for: post) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(maxWidth: .infinity)
                        .aspectRatio(4 / 5, contentMode: .fit)
                        .clipShape(RoundedRectangle(cornerRadius: MorpheTheme.radius, style: .continuous))
                        .accessibilityLabel("Photo by \(post.authorName)")
                }

                // Photo posts may carry the placeholder single-space caption
                // — render nothing rather than a ghost line.
                if !post.text.trimmingCharacters(in: .whitespaces).isEmpty {
                    Text(post.text)
                        .font(.subheadline)
                        .foregroundStyle(MorpheTheme.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                if !post.workoutName.isEmpty {
                    HStack(spacing: 6) {
                        Image(systemName: "figure.run")
                            .font(.caption2.weight(.semibold))
                        Text(post.workoutName)
                            .font(.caption.weight(.semibold))
                            .lineLimit(1)
                    }
                    .foregroundStyle(MorpheTheme.textPrimary)
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
                                    .foregroundStyle(MorpheTheme.textPrimary)
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

                // Social-proof line — counts live HERE (the professional-feed
                // anatomy), so the action row below stays clean labels. Only
                // counts we actually hold: reactions are bulk-fetched;
                // comment counts exist once loaded, so unknown stays silent
                // instead of showing a fake zero.
                if reactionCount > 0 || (store.postComments[post.id]?.isEmpty == false) {
                    HStack {
                        if reactionCount > 0 {
                            HStack(spacing: 4) {
                                Image(systemName: "flame.fill")
                                    .font(.caption2)
                                    .foregroundStyle(MorpheTheme.accent)
                                Text("\(reactionCount)")
                            }
                        }
                        Spacer()
                        if let comments = store.postComments[post.id], !comments.isEmpty {
                            Text("\(comments.count) comment\(comments.count == 1 ? "" : "s")")
                        }
                    }
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(MorpheTheme.textMuted)
                }

                Divider()
                    .overlay(MorpheTheme.stroke.opacity(0.6))

                // Equal-width labeled action row.
                HStack(spacing: 0) {
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
                            Text("React")
                        }
                        .feedActionChrome(isActive: hasReacted, activeColor: MorpheTheme.accent)
                        .frame(maxWidth: .infinity)
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
                            Text("Comment")
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(FeedActionButtonStyle(isActive: showComments, activeColor: MorpheTheme.accentAlt))
                    .accessibilityLabel(showComments ? "Hide comments" : "Show comments")

                    Button {
                        onRepost()
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: "arrow.2.squarepath")
                            Text("Repost")
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(FeedActionButtonStyle(isActive: false, activeColor: MorpheTheme.accent))

                    Button {
                        store.toggleSaved(post)
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: isSaved ? "bookmark.fill" : "bookmark")
                            Text(isSaved ? "Saved" : "Save")
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(FeedActionButtonStyle(isActive: isSaved, activeColor: MorpheTheme.accentAlt))
                }

                if showComments {
                    commentsSection
                }
            }
        }
        // Double-tap = react (TIKTOK-PLAN T4): system-wide muscle memory.
        // Buttons inside keep their single taps; this rides card chrome.
        .onTapGesture(count: 2) {
            store.toggleReaction(post)
            Haptics.impact(.light)
        }
        .contextMenu {
            if isMine {
                Button(role: .destructive) {
                    // Confirm first (audit G4): deleting a post is
                    // irreversible, and blocking (which IS reversible)
                    // already confirmed — the guard belonged here more.
                    showDeletePostConfirm = true
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
            "Delete this post? It disappears from the feed for everyone, and there's no undo.",
            isPresented: $showDeletePostConfirm,
            titleVisibility: .visible
        ) {
            Button("Delete Post", role: .destructive) {
                store.deleteMyPost(post)
            }
            Button("Cancel", role: .cancel) {}
        }
        .confirmationDialog(
            "Delete this comment? There's no undo.",
            isPresented: Binding(
                get: { deletingComment != nil },
                set: { if !$0 { deletingComment = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Delete Comment", role: .destructive) {
                if let comment = deletingComment { store.deleteMyComment(comment) }
                deletingComment = nil
            }
            Button("Cancel", role: .cancel) { deletingComment = nil }
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
                .foregroundStyle(MorpheTheme.textPrimary)
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
                                    .foregroundStyle(MorpheTheme.textPrimary)
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
                                deletingComment = comment
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
                // House loading idiom (audit G7) — a bare text line was one
                // of three ad-hoc loading languages.
                HStack(spacing: 8) {
                    ProgressView().tint(MorpheTheme.accent)
                    Text("Loading comments…")
                        .font(.caption)
                        .foregroundStyle(MorpheTheme.textMuted)
                }
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
            .foregroundStyle(isActive ? activeColor : MorpheTheme.textPrimary)
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
            .foregroundStyle(isActive ? activeColor : MorpheTheme.textPrimary)
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
                        .foregroundStyle(MorpheTheme.textPrimary)

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
                            if post.hasImage, let image = FeedImageCache.image(for: post) {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                            .frame(maxWidth: .infinity, maxHeight: 180)
                            .clipShape(RoundedRectangle(cornerRadius: MorpheTheme.radius, style: .continuous))
                    }
                    Text(post.text)
                                .font(.subheadline)
                                .foregroundStyle(MorpheTheme.textPrimary)
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
                    .foregroundStyle(MorpheTheme.textPrimary)
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
    @State private var showReportDialog = false
    @State private var showBlockConfirm = false
    @State private var streakExplainerVisible = false

    private var myUid: String { store.authUser?.id ?? "" }
    private var counterpart: String { thread.counterpartName(for: myUid) }
    private var counterpartUid: String {
        thread.coachUid == myUid ? thread.athleteUid : thread.coachUid
    }
    /// Consecutive days both of you messaged — exact, from full history.
    private var chatStreak: Int {
        MorpheAppStore.messageStreak(
            messages: store.displayedThreadMessages, uidA: myUid, uidB: counterpartUid)
    }

    /// Doors seed a draft before routing here; a typed draft is never
    /// clobbered, and the seed is cleared so it can't pop up stale later.
    private func consumeDraftSeedIfPresent() {
        guard let seed = store.athleteThreadDraftSeed else { return }
        if draft.isEmpty { draft = seed }
        store.athleteThreadDraftSeed = nil
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 12) {
                if let onBack {
                    // Breadcrumb grammar (audit G3): backs NAME where they
                    // go — the bare circle was one of two dialects in this
                    // same file.
                    Button {
                        onBack()
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "chevron.left")
                                .font(.subheadline.weight(.bold))
                            Text("CHATS")
                                .font(MorpheTheme.microLabel(11))
                                .tracking(1.4)
                        }
                        .foregroundStyle(MorpheTheme.textSecondary)
                        .frame(height: 44)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Back to chats")
                }

                Circle()
                    .fill(MorpheTheme.panelStrong)
                    .frame(width: 42, height: 42)
                    .overlay(
                        Text(String(counterpart.prefix(1)).uppercased())
                            .font(.headline)
                            .foregroundStyle(MorpheTheme.textPrimary)
                    )

                VStack(alignment: .leading, spacing: 4) {
                    Text(counterpart)
                        .font(.headline)
                        .foregroundStyle(MorpheTheme.textPrimary)
                    // A streak needs at least two days to be a streak; day
                    // one stays quiet instead of celebrating a single hello.
                    if chatStreak >= 2 {
                        HStack(spacing: 4) {
                            Image(systemName: "flame.fill")
                                .font(.caption2.weight(.bold))
                            Text("STREAK \(chatStreak)")
                                .font(MorpheTheme.microLabel(10))
                                .tracking(1.2)
                        }
                        .foregroundStyle(MorpheTheme.accentText)
                        .accessibilityLabel("\(chatStreak) day chat streak")
                        // The chip explains itself on tap — no glossary hunt.
                        .onTapGesture {
                            streakExplainerVisible = true
                        }
                        .alert("Chat Streak", isPresented: $streakExplainerVisible) {
                            Button("Got It", role: .cancel) {}
                        } message: {
                            Text("\(chatStreak) days in a row you've both sent a message. An unanswered morning doesn't break it — a full silent day does.")
                        }
                    } else {
                        Text("Conversation")
                            .font(.caption)
                            .foregroundStyle(MorpheTheme.textSecondary)
                    }
                }

                Spacer()

                // Safety controls IN the conversation (launch audit P0-2):
                // report and block reach messaging, not just the feed.
                Menu {
                    Button("Report \(counterpart)", systemImage: "flag") {
                        showReportDialog = true
                    }
                    Button("Block \(counterpart)", systemImage: "hand.raised", role: .destructive) {
                        showBlockConfirm = true
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(MorpheTheme.textSecondary)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .accessibilityLabel("Conversation options")
                .confirmationDialog("Report \(counterpart)?", isPresented: $showReportDialog, titleVisibility: .visible) {
                    ForEach(MorpheAppStore.reportReasons, id: \.self) { reason in
                        Button(reason) {
                            store.reportUser(uid: counterpartUid, name: counterpart, reason: reason)
                        }
                    }
                    Button("Cancel", role: .cancel) {}
                } message: {
                    Text("A human reviews every report.")
                }
                .confirmationDialog("Block \(counterpart)?", isPresented: $showBlockConfirm, titleVisibility: .visible) {
                    Button("Block", role: .destructive) {
                        store.blockAccount(uid: counterpartUid, name: counterpart)
                        onBack?()
                    }
                    Button("Cancel", role: .cancel) {}
                } message: {
                    Text("This conversation closes, their posts disappear, and they can't message you. Unblock anytime in Profile.")
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)

            Divider()
                .overlay(MorpheTheme.stroke.opacity(0.8))

            ScrollViewReader { proxy in
                ScrollView(showsIndicators: false) {
                    LazyVStack(alignment: .leading, spacing: 12) {
                        if store.displayedThreadMessages.isEmpty, !store.threadFirstSnapshotArrived {
                            // Still waiting on the listener — say so instead
                            // of silent blank (post-revamp audit P2-10).
                            SwiftUI.ProgressView()
                                .frame(maxWidth: .infinity, alignment: .center)
                                .padding(.top, 24)
                        } else if store.displayedThreadMessages.isEmpty, store.threadFirstSnapshotArrived {
                            // Gated on the first snapshot (speed audit S0-5):
                            // "no messages" is only claimed once it's checked.
                            Text("No messages yet — say hello. This conversation is private to you and \(counterpart).")
                                .font(.caption)
                                .foregroundStyle(MorpheTheme.textSecondary)
                                .frame(maxWidth: .infinity, alignment: .center)
                                .padding(.top, 24)
                        }

                        ForEach(Array(store.displayedThreadMessages.enumerated()), id: \.element.id) { index, message in
                            LiveMessageBubble(
                                message: message,
                                isMine: message.senderUid == myUid,
                                senderName: message.senderUid == myUid ? "You" : counterpart,
                                // Sender-run captions: name only where a run starts.
                                showsSender: index == 0
                                    || store.displayedThreadMessages[index - 1].senderUid != message.senderUid
                            )
                            .id(message.id)
                        }
                    }
                    .padding(16)
                    .padding(.bottom, 8)
                }
                .onChange(of: store.displayedThreadMessages.count) { _, _ in
                    if let last = store.displayedThreadMessages.last {
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
                    // Keyboard send (speed audit S0-3): the return key IS
                    // the send button; with a submit label set, return
                    // submits and long text still wraps into view.
                    .submitLabel(.send)
                    .onSubmit {
                        let text = draft
                        draft = ""
                        Task { await store.sendMessage(text) }
                    }
                    .textFieldStyle(MorpheFieldStyle())

                Button("Send") {
                    // Clear first so a slow network never eats a retype.
                    let text = draft
                    draft = ""
                    Task { await store.sendMessage(text) }
                }
                .buttonStyle(PrimaryCTAButtonStyle(accent: MorpheTheme.accent))
                .frame(width: 96)
                .disabled(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding(16)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .onAppear {
            store.openThread(thread)
            consumeDraftSeedIfPresent()
        }
        // The client shell is a TabView, so this view can already be
        // mounted when a door (post-workout Message Coach) seeds a draft
        // and routes here — onAppear won't refire, this will.
        .onChange(of: store.athleteThreadDraftSeed) { _, _ in
            consumeDraftSeedIfPresent()
        }
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
                    .foregroundStyle(MorpheTheme.textPrimary)
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
/// their coach). Lives in Network → Contact — an athlete with no claimed
/// link sees the honest empty state there instead.
struct AthleteInboxView: View {
    @Environment(MorpheAppStore.self) private var store
    /// Tab-context nicety: exactly one thread (the usual solo-athlete case)
    /// opens straight into the conversation; back still reveals the list.
    var autoOpenOnlyThread: Bool = false
    @State private var openedThread: MessageThreadSummary?
    @State private var didAutoOpen = false
    @State private var query = ""
    @State private var searchTask: Task<Void, Never>?
    @State private var startingChatUid: String?
    @FocusState private var searchFocused: Bool

    private var myUid: String { store.authUser?.id ?? "" }

    private var cleanQuery: String {
        query.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Conversations matching the query by the OTHER person's name (all of
    /// them when the query is empty).
    private var visibleThreads: [MessageThreadSummary] {
        guard !cleanQuery.isEmpty else { return store.liveThreads }
        return store.liveThreads.filter {
            $0.counterpartName(for: myUid).localizedCaseInsensitiveContains(cleanQuery)
        }
    }

    /// Directory hits that aren't me and don't already have a thread — those
    /// surface as conversations above.
    private var newPeopleHits: [AthleteSearchResult] {
        let threadUids = Set(store.liveThreads.flatMap { [$0.coachUid, $0.athleteUid] })
        return store.athleteSearchResults.filter {
            $0.uid != myUid && !threadUids.contains($0.uid)
                && store.blockedAccounts[$0.uid] == nil
        }
    }

    var body: some View {
        Group {
            if let openedThread {
                ThreadChatView(thread: openedThread, onBack: { self.openedThread = nil })
            } else {
                threadList
            }
        }
        .task {
            await store.refreshThreads()
            consumePendingThreadOpen()
            if autoOpenOnlyThread, !didAutoOpen, openedThread == nil,
               store.liveThreads.count == 1 {
                didAutoOpen = true
                openedThread = store.liveThreads.first
            }
        }
        // Deep links re-fire while the pane stays mounted — the local
        // auto-open-once flag can't serve them, the pending id can.
        .onChange(of: store.pendingThreadOpenID) { _, _ in
            consumePendingThreadOpen()
        }
        // Same debounce discipline as universal search (350ms, cancel on
        // retype) — the directory is a Firestore range scan, not free.
        .onChange(of: query) { _, text in
            searchTask?.cancel()
            let clean = text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard clean.count >= 2 else { return }
            searchTask = Task {
                try? await Task.sleep(nanoseconds: 350_000_000)
                guard !Task.isCancelled else { return }
                await store.searchAthletes(query: clean)
            }
        }
    }

    private func consumePendingThreadOpen() {
        guard let pending = store.pendingThreadOpenID,
              let thread = store.liveThreads.first(where: { $0.id == pending }) else { return }
        store.pendingThreadOpenID = nil
        openedThread = thread
    }

    private var threadList: some View {
        ScrollView(showsIndicators: false) {
            LazyVStack(spacing: 0) {
                searchField
                    .padding(.horizontal, 16)
                    .padding(.bottom, 8)

                ForEach(Array(visibleThreads.enumerated()), id: \.element.id) { index, thread in
                    Button {
                        openedThread = thread
                    } label: {
                        LiveThreadRow(thread: thread, viewerUid: myUid,
                                      isUnread: store.isThreadUnread(thread))
                    }
                    .buttonStyle(.plain)

                    if index < visibleThreads.count - 1 {
                        Divider()
                            .overlay(MorpheTheme.stroke.opacity(0.5))
                            .padding(.leading, 72)
                    }
                }

                if cleanQuery.count >= 2 {
                    directoryResults
                } else if store.liveThreads.isEmpty {
                    // The pane's only empty state now lives WITH the search
                    // that cures it.
                    VStack(alignment: .leading, spacing: 8) {
                        Text("No conversations yet")
                            .font(.headline)
                            .foregroundStyle(MorpheTheme.textPrimary)
                        Text("Search a username above to start a chat, or join a coach with their invite code and that thread appears here.")
                            .font(.subheadline)
                            .foregroundStyle(MorpheTheme.textSecondary)
                        // The code door WHERE the coach thread will appear
                        // (launch audit P1-10) — not just buried in Profile.
                        if store.linkedCoachUid.isEmpty {
                            Button("Have a coach code? Enter it here") {
                                store.openClientProfile()
                            }
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(MorpheTheme.accentText)
                            .frame(minHeight: 32)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)
                }
            }
            .padding(.vertical, 4)
        }
        .scrollDismissesKeyboard(.immediately)
        .refreshable { await store.refreshThreads(force: true) }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(MorpheTheme.textMuted)
            TextField("Search chats or find people…", text: $query)
                .font(.subheadline)
                .foregroundStyle(MorpheTheme.textPrimary)
                .focused($searchFocused)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .submitLabel(.search)
            if !query.isEmpty {
                Button {
                    query = ""
                    store.athleteSearchResults = []
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.subheadline)
                        .foregroundStyle(MorpheTheme.textMuted)
                        .frame(width: 32, height: 32)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Clear search")
            }
        }
        .padding(.horizontal, 12)
        .frame(minHeight: 44)
        .background(
            RoundedRectangle(cornerRadius: MorpheTheme.radius, style: .continuous)
                .fill(MorpheTheme.panelStrong)
        )
    }

    /// Real directory hits with a start-chat action — the "new chat" door.
    private var directoryResults: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("PEOPLE")
                .font(MorpheTheme.microLabel(10))
                .tracking(1.6)
                .foregroundStyle(MorpheTheme.textMuted)
                .padding(.horizontal, 16)
                .padding(.top, 14)
                .padding(.bottom, 6)

            if newPeopleHits.isEmpty {
                Text(visibleThreads.isEmpty
                     ? "No one found for \"\(cleanQuery)\" — usernames are exact-prefix."
                     : "No new people for \"\(cleanQuery)\".")
                    .font(.caption)
                    .foregroundStyle(MorpheTheme.textMuted)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 10)
            }

            ForEach(newPeopleHits) { hit in
                HStack(spacing: 12) {
                    Circle()
                        .fill(MorpheTheme.panelStrong)
                        .frame(width: 44, height: 44)
                        .overlay(
                            Text(String(hit.username.prefix(1)).uppercased())
                                .font(.headline)
                                .foregroundStyle(MorpheTheme.textPrimary)
                        )
                    Text("@\(hit.username)")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(MorpheTheme.textPrimary)
                    Spacer()
                    Button {
                        guard startingChatUid == nil else { return }
                        startingChatUid = hit.uid
                        Task {
                            _ = await store.startDirectChat(with: hit.uid, name: hit.username)
                            startingChatUid = nil
                            query = ""
                            store.athleteSearchResults = []
                        }
                    } label: {
                        Group {
                            if startingChatUid == hit.uid {
                                ProgressView().tint(.black)
                            } else {
                                Text("CHAT")
                                    .font(MorpheTheme.microLabel(10))
                                    .tracking(1.4)
                            }
                        }
                        .foregroundStyle(.black)
                        .padding(.horizontal, 16)
                        .frame(height: 34)
                        .background(Capsule().fill(MorpheTheme.brandYellow))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Start a chat with \(hit.username)")
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
            }
        }
    }
}

/// One real-thread inbox row: counterpart name, honest last-message preview,
/// relative time. The unread dot is an honest LOCAL lens (isThreadUnread):
/// newest message is theirs and arrived since this device last opened the
/// thread — no server-side read receipts are claimed.
struct LiveThreadRow: View {
    let thread: MessageThreadSummary
    let viewerUid: String
    /// Honest local lens: the newest message is theirs and arrived since
    /// this profile last opened the thread on this device.
    var isUnread: Bool = false

    private var name: String { thread.counterpartName(for: viewerUid) }

    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(MorpheTheme.panelStrong)
                .frame(width: 44, height: 44)
                .overlay(
                    Text(String(name.prefix(1)).uppercased())
                        .font(.headline)
                        .foregroundStyle(MorpheTheme.textPrimary)
                )

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    if isUnread {
                        Circle()
                            .fill(MorpheTheme.brandYellow)
                            .frame(width: 8, height: 8)
                    }
                    Text(name)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(MorpheTheme.textPrimary)
                    Spacer()
                    Text(thread.updatedAt.formatted(.relative(presentation: .named)))
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(isUnread ? MorpheTheme.brandYellow : MorpheTheme.textMuted)
                }

                Text(thread.lastMessage.isEmpty ? "No messages yet" : thread.lastMessage)
                    .font(isUnread ? .caption.weight(.semibold) : .caption)
                    .foregroundStyle(isUnread ? MorpheTheme.textPrimary : MorpheTheme.textSecondary)
                    .lineLimit(2)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel(isUnread ? "\(name), new message" : name)
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
                .foregroundStyle(MorpheTheme.textPrimary)
                .padding(12)
                .frame(maxWidth: .infinity, alignment: message.sender == .user ? .trailing : .leading)
                .background(
                    RoundedRectangle(cornerRadius: MorpheTheme.radius, style: .continuous)
                        .fill(backgroundColor)
                )
        }
    }
}
