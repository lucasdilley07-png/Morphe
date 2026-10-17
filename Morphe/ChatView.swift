import SwiftUI
import AVFoundation
import AVKit
import Speech

struct CommunityView: View {
    @Environment(MorpheAppStore.self) private var store
    @State private var selectedStory: CommunityStoryPreview?
    @State private var showNetworkExtras = false
    @State private var showFormCamera = false
    @State private var showCalendarEditor = false
    /// Tab landing clears the floating header icons.
    var topPadding: CGFloat = MorpheTheme.Spacing.pageTopNetwork

    /// One-shot per mount: land on CHATS when messages are waiting
    /// (speed audit S2-3) — Snapchat's own default, and it cuts the reply
    /// path by a tap. Deep links (pendingThreadOpenID) still win.
    @State private var didApplyLandingPane = false

    var body: some View {
        @Bindable var store = store
        // The header rides INSIDE each pane's scroll (Lucas 2026-10-05):
        // the CHATS / BOARD / CALENDAR tabs and the Connect row scroll
        // away with the page instead of staying pinned. The swipe between
        // panes is unchanged.
        return VStack(spacing: 0) {
            // The tabs are buttons only (Lucas 2026-10-05): the horizontal
            // swipe now belongs to the main Today / Train / Discover /
            // Network / Learn pager, so the panes here no longer page.
            // Selection is the SAME store var every deep link already sets.
            // Panes stay MOUNTED (audit 33): a switch that rebuilt the
            // inbox refired its one-shot auto-open and double-fetched.
            // Only the selected pane is visible and touchable.
            ZStack {
                pane(.contact) { contactScreen }
                if FeatureFlags.socialFeedEnabled {
                    pane(.forYou) {
                        // The stack hosts the feed's author push (swipe-back).
                        // The system bar stays hidden — the HUD has its own chrome.
                        NavigationStack {
                            forYouScreen
                                .toolbar(.hidden, for: .navigationBar)
                        }
                    }
                } else {
                    // The coaches' Feed moved to Discover (Lucas 2026-10-10).
                    pane(.board) { boardScreen }
                    pane(.calendar) { calendarScreen }
                }
            }
        }
        // Chats ↔ Board ↔ Calendar by swipe (Lucas 2026-10-13).
        .inTabPageSwipe(pages: FeatureFlags.socialFeedEnabled
                            ? [ClientCommunitySection.contact, .forYou]
                            : [ClientCommunitySection.board, .contact, .calendar],
                        selection: Binding(get: { store.selectedCommunitySection },
                                           set: { store.selectedCommunitySection = $0 }))
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
                if section == .forYou { Task { await store.refreshCreatorContent() } }
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
        // Centered on the page (alive wave symmetry) — the tab group sits
        // on the center line, matching Train's header. The camera door
        // rides a trailing overlay so it never pushes the tabs off-center
        // when the feed relights.
        // Equal columns, each label centered (Lucas 2026-10-10: more
        // separated, symmetrical — same as Discover's).
        HStack(alignment: .bottom, spacing: 0) {
            if FeatureFlags.socialFeedEnabled {
                sectionTab("CHATS", .contact, badgeCount: store.networkBadgeCount)
                sectionTab("FEED", .forYou)
            } else {
                // Board · Chats · Calendar (Lucas 2026-10-17): chats in the
                // middle, the page's default. The Feed is in Discover.
                sectionTab("BOARD", .board)
                sectionTab("CHATS", .contact, badgeCount: store.networkBadgeCount)
                sectionTab("CALENDAR", .calendar)
            }
        }
        .frame(maxWidth: .infinity)
        .overlay(alignment: .bottomTrailing) {
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
                            badgeCount: Int = 0) -> some View {
        let showsBadge = badgeCount > 0
        let isActive = store.selectedCommunitySection == section
        return Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                store.selectedCommunitySection = section
            }
        } label: {
            VStack(alignment: .center, spacing: 5) {
                HStack(spacing: 5) {
                    Text(label)
                        .font(MorpheTheme.microLabel(16))
                        .tracking(1.6)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                        .foregroundStyle(isActive ? MorpheTheme.textPrimary : MorpheTheme.textMuted)
                }
                .overlay(alignment: .topTrailing) {
                    if showsBadge {
                        // The count sits top-right of the title (Lucas 2026-10-10),
                        // as an overlay so the title never shifts.
                        CountBadge(count: badgeCount)
                            .offset(x: 14, y: -8)
                    }
                }
                Rectangle()
                    .fill(isActive ? MorpheTheme.accent : .clear)
                    .frame(width: 34, height: 3)
            }
            .frame(maxWidth: .infinity, minHeight: 44, alignment: .bottom)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(showsBadge ? "\(label.capitalized), \(badgeCount) new" : label.capitalized)
        .accessibilityAddTraits(isActive ? .isSelected : [])
    }

    private var forYouScreen: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 16) {
                networkHeader.padding(.horizontal, -20)
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
            await store.refreshBoards(force: true)
            await store.refreshChallenges(force: true)
        }
    }

    /// BOARD pane: the weekly leaderboard, same honest card Progress
    /// hosts — opt-in, real names, real logged scores only.
    private var boardScreen: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 16) {
                networkHeader.padding(.horizontal, -20)
                // One box, editable like every page (Lucas 2026-10-17).
                SectionEditorList(
                    editing: store.editingPage == .board,
                    cards: store.visiblePageCards(BoardCardID.self, page: .board),
                    hidden: store.hiddenPageCards(BoardCardID.self, page: .board),
                    title: \.title,
                    onMove: { store.movePageCards($0, page: .board) },
                    onHide: { store.hidePageCard($0, page: .board) },
                    onShow: { store.showPageCard($0, page: .board) }
                ) { _ in
                    WeeklyBoardCard()
                }
                if store.editingPage != .board {
                    EditLayoutButton(page: "Board") { store.beginEditing(.board) }
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 6)
            .padding(.bottom, 120)
        }
        .refreshable {
            await store.refreshBoards(force: true)
        }
    }

    /// CALENDAR pane: the personal schedule — upcoming appointments plus
    /// the same editor every other schedule door uses.
    private var calendarScreen: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 14) {
                networkHeader.padding(.horizontal, -20)
                SectionEditorList(
                    editing: store.editingPage == .calendar,
                    cards: store.visiblePageCards(CalendarCardID.self, page: .calendar),
                    hidden: store.hiddenPageCards(CalendarCardID.self, page: .calendar),
                    title: \.title,
                    onMove: { store.movePageCards($0, page: .calendar) },
                    onHide: { store.hidePageCard($0, page: .calendar) },
                    onShow: { store.showPageCard($0, page: .calendar) }
                ) { _ in
                    scheduleSection
                }
                if store.editingPage != .calendar {
                    EditLayoutButton(page: "Calendar") { store.beginEditing(.calendar) }
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 6)
            .padding(.bottom, 120)
        }
        .refreshable { await store.refreshAppointments() }
        .sheet(isPresented: $showCalendarEditor) {
            AppointmentEditorSheet()
                .environment(store)
        }
    }

    /// The schedule box: header, then the list or the empty-state door.
    private var scheduleSection: some View {
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
                    // The empty state IS the door (audit 2026-10-15: the only
                    // way in was a small "Add" in the corner).
                    GlassCard {
                        VStack(spacing: 12) {
                            Image(systemName: "calendar.badge.plus")
                                .font(.system(size: 34, weight: .semibold))
                                .foregroundStyle(MorpheTheme.accentText)
                                .accessibilityHidden(true)
                            Text("Nothing scheduled")
                                .font(.headline)
                                .foregroundStyle(MorpheTheme.textPrimary)
                            Text("Add a session, a coach call, or anything worth showing up for — reminders ride along automatically.")
                                .font(.subheadline)
                                .foregroundStyle(MorpheTheme.textSecondary)
                                .multilineTextAlignment(.center)
                            Button {
                                showCalendarEditor = true
                            } label: {
                                Label("Add to your schedule", systemImage: "plus")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(PrimaryCTAButtonStyle(accent: MorpheTheme.accent))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                    }
                } else {
                    ForEach(store.upcomingAppointments) { appointment in
                        AppointmentRowView(appointment: appointment)
                    }
                }
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
    }

    /// THE messaging home for real accounts: the coach-thread inbox. Every
    /// "message" door in the app (Home Coach tile, story-viewer shortcut,
    /// post-workout prompt) deep-links here instead of forking its own
    /// sheet — one destination, many doors.
    private var realContactScreen: some View {
        // The inbox always mounts now — its search bar is the new-chat door,
        // which has to exist even (especially) with zero conversations. The
        // inbox owns its own refresh and empty state.
        // The tabs and the Connect row scroll with the inbox (2026-10-05).
        AthleteInboxView(autoOpenOnlyThread: true, topContent: AnyView(
            VStack(spacing: 10) {
                networkHeader
                // (My Code / Scan moved to Quick Add, Lucas 2026-10-10.)
            }
            .padding(.bottom, 10)
        ))
    }

    /// One mounted pane: shown and interactive only while selected.
    @ViewBuilder
    private func pane<Content: View>(_ section: ClientCommunitySection, @ViewBuilder content: () -> Content) -> some View {
        let selected = store.selectedCommunitySection == section
        content()
            .opacity(selected ? 1 : 0)
            .allowsHitTesting(selected)
            .accessibilityHidden(!selected)
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
                                "Keep the first round moderate and controlled.",
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
        .pageSwipeExempt()
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

                    Button("Feed") {
                        store.openFeed()
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
                     : "Connect with a coach or a training partner: show your Morphe code or scan theirs, right above.")
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
                .pageSwipeExempt()
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
                        Text("Feed")
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
private var feedVerifiedSealBlue: Color { MorpheTheme.brandBlueText }

                // Photo posts ship as base64 inside post docs (rules-capped);
                // Firebase Storage upgrades the pipeline post-Blaze.
private struct RealFeedSection: View {
    @Environment(MorpheAppStore.self) private var store
    @State private var draft = ""
    /// Blocks double-submit and shows a spinner while the post is in flight
    /// (feedback P1 2026-09).
    @State private var isPosting = false
    /// A jump of 120+ characters in one change is a paste — the human-only
    /// notice shows (Lucas 2026-10-10); the publish checks run regardless.
    @State private var showPasteNotice = false
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
        store.boardChipLine ?? "Boards — create one or join with a code"
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
                        Text("Blue ring = sessions you haven't watched · flame = Duo Streak (days you both posted)")
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
                .swipeBack { authorTarget = nil }
        }
        .background(EmptyView().fullScreenCover(item: $storyTarget) { entry in
            StorySessionViewer(entry: entry)
                .environment(store)
        })
        .background(EmptyView().fullScreenCover(isPresented: $showBoardStory, onDismiss: {
            // The story's "Open Progress" queues; raise it here (audit 15).
            store.consumePendingProgressOpen()
        }) {
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
            await store.refreshBoards()
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
                        .onChange(of: draft) { old, new in
                            if new.count - old.count >= 120 { showPasteNotice = true }
                            if new.isEmpty { showPasteNotice = false }
                        }
                }

                if isActive {
                    // The human-only policy, once: the pledge gates the
                    // first post and is remembered on this phone.
                    if !store.humanPledgeAccepted {
                        Toggle(isOn: Binding(
                            get: { store.humanPledgeAccepted },
                            set: { if $0 { store.acceptHumanPledge() } }
                        )) {
                            Text("These are my own words and photos — no AI, no bots. Morphe is human-only.")
                                .font(.caption)
                                .foregroundStyle(MorpheTheme.textSecondary)
                        }
                        .tint(MorpheTheme.accent)
                    }
                    if showPasteNotice {
                        Label("Pasted text — Morphe only takes your own writing. AI-written posts are removed; the account may be warned, limited or closed.", systemImage: "person.fill.checkmark")
                            .font(.caption2)
                            .foregroundStyle(MorpheTheme.warning)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    HStack {
                        Text("\(draft.count)/\(Self.postLimit)")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(draft.count > Self.postLimit ? MorpheTheme.warning : MorpheTheme.textMuted)

                        Spacer()

                        Button {
                            let text = cleanDraft
                            draft = ""
                            isPosting = true
                            Task {
                                let ok = await store.publishPost(text: text)
                                isPosting = false
                                // A dead connection must give the words back
                                // (feedback P1 2026-09), never eat them.
                                if !ok { draft = text }
                            }
                        } label: {
                            if isPosting {
                                ProgressView().tint(.white)
                            } else {
                                Text("Post")
                            }
                        }
                        .buttonStyle(PrimaryCTAButtonStyle(accent: MorpheTheme.accent))
                        .disabled(isPosting)
                        // Same send control as the chat composer (ThreadChatView):
                        // 84x44 primary CTA next to a MorpheFieldStyle field.
                        .frame(width: 96)
                        .disabled(cleanDraft.isEmpty || draft.count > Self.postLimit || !store.humanPledgeAccepted)
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
                            accent: accentId.isEmpty ? MorpheTheme.textPrimary : MorpheTheme.accentInk(forPaletteId: accentId),
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
            .pageSwipeExempt()
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
        case .unseen: return MorpheTheme.accent
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
                                    .foregroundStyle(ringState == .empty ? MorpheTheme.accentText : accent)
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
                            .foregroundStyle(MorpheTheme.onFill(MorpheTheme.accent))
                            .padding(.horizontal, 4)
                            .padding(.vertical, 2)
                            .background(
                                RoundedRectangle(cornerRadius: MorpheTheme.chipRadius, style: .continuous)
                                    .fill(MorpheTheme.accent)
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
                            .fill(tick <= index ? MorpheTheme.accent : MorpheTheme.stroke)
                            .frame(height: 2)
                    }
                }

                HStack(spacing: 8) {
                    Text(entry.name.uppercased())
                        .font(MorpheTheme.microLabel(11))
                        .tracking(1.4)
                        .foregroundStyle(post.authorAccent.isEmpty
                            ? MorpheTheme.textPrimary
                            : MorpheTheme.accentInk(forPaletteId: post.authorAccent))
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
                                .foregroundStyle(isMine ? MorpheTheme.accentText : MorpheTheme.textPrimary)
                                .frame(width: 44, height: 44)
                                .background(
                                    RoundedRectangle(cornerRadius: MorpheTheme.radiusSmall, style: .continuous)
                                        .stroke(isMine ? MorpheTheme.accent.opacity(0.6) : MorpheTheme.stroke, lineWidth: 1)
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
            } else if replyDraft.isEmpty {
                replyDraft = text   // refused or offline: the words come back
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
                                .foregroundStyle(index == 0 ? MorpheTheme.accentText : MorpheTheme.textPrimary.opacity(0.55))
                                .frame(width: 44, alignment: .leading)
                            Text(entry.name)
                                .scaledFont(size: 22, weight: .black)
                                .foregroundStyle(MorpheTheme.textPrimary)
                                .lineLimit(1)
                            Spacer()
                            Text("\(entry.score) SETS")
                                .scaledFont(size: 14, weight: .bold, design: .monospaced)
                                .tracking(1.2)
                                .foregroundStyle(MorpheTheme.accentText)
                        }
                    }
                }

                Spacer()

                Button("Open Progress") {
                    // Queue, then dismiss: the cover's onDismiss raises the
                    // Progress sheet once the transition has room (audit 15,
                    // P1 — present-during-dismissal was a race).
                    store.pendingProgressOpen = true
                    dismiss()
                }
                .buttonStyle(PrimaryCTAButtonStyle(accent: MorpheTheme.accent))

                HStack {
                    Spacer()
                    Text(MorpheTheme.tagline)
                        .scaledFont(size: 11, weight: .bold, design: .monospaced)
                        .tracking(1.6)
                        .foregroundStyle(MorpheTheme.accentText)
                }
            }
            .padding(20)

            HUDCornerTicks(arm: 22, color: MorpheTheme.textPrimary.opacity(0.35))
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
        MorpheTheme.accentInk(forPaletteId: post.authorAccent)
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
                            .foregroundStyle(MorpheTheme.accentText)
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
                        .foregroundStyle(MorpheTheme.accentText)
                }
                Spacer(minLength: 0)
                if let count = store.feedReactionCounts[post.id], count > 0 {
                    Image(systemName: "heart.fill")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(MorpheTheme.accentText)
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
                    .foregroundStyle(MorpheTheme.accentText)
                    .padding(.bottom, 12)
            }

            ForEach(post.prNames.prefix(3), id: \.self) { name in
                HStack(spacing: 8) {
                    Image(systemName: "trophy.fill")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(MorpheTheme.accentText)
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
                Text(MorpheTheme.tagline)
                    .scaledFont(size: 11, weight: .bold, design: .monospaced)
                    .tracking(1.6)
                    .foregroundStyle(MorpheTheme.accentText)
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
                    .foregroundStyle(MorpheTheme.accentText)
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
                                        : MorpheTheme.accentInk(forPaletteId: accentId))
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
                    }
                }

                if !isMine, store.isRealFeedActive {
                    // The same Connect · Message · Invite · Follow bar as
                    // Quick Add's account page (Lucas 2026-10-10).
                    PersonActionBar(card: store.person(for: authorUid) ?? PersonCard(
                        uid: authorUid, name: authorName, username: "",
                        headline: authorPosts.first?.authorHeadline ?? "",
                        accentId: authorPosts.first?.authorAccent ?? "", verified: verified, isCoach: false))
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
                                            : MorpheTheme.accentInk(forPaletteId: post.authorAccent))
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
                                            .foregroundStyle(MorpheTheme.accentText)
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
                                    .foregroundStyle(MorpheTheme.accentText)
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
                                    .foregroundStyle(MorpheTheme.accentText)
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
                                .contentTransition(.symbolEffect(.replace))
                                .symbolEffect(.bounce, value: hasReacted)
                            Text("React")
                        }
                        .feedActionChrome(isActive: hasReacted, activeColor: MorpheTheme.accent)
                        .frame(maxWidth: .infinity)
                    } primaryAction: {
                        Haptics.impact(.light)
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
                                .contentTransition(.symbolEffect(.replace))
                                .symbolEffect(.bounce, value: isSaved)
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
    @State private var recorder = VoiceMemoRecorder()

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
            // Back · name centered · dots (Lucas 2026-10-17): one header for
            // every conversation. Report and block live under the dots.
            ChatPageHeader(
                title: counterpart,
                subtitle: chatStreak >= 2 ? "Streak \(chatStreak) · you've both written \(chatStreak) days running" : "Conversation",
                onBack: onBack
            ) {
                Button("Report \(counterpart)", systemImage: "flag") { showReportDialog = true }
                Button("Block \(counterpart)", systemImage: "hand.raised", role: .destructive) { showBlockConfirm = true }
            }
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
                            if let memo = VoiceMemoStore.parse(message.text) {
                                // A voice memo (Lucas 2026-10-17): the clip
                                // for its sender, the transcript for both.
                                VoiceMemoBubble(memo: memo, isMine: message.senderUid == myUid)
                                    .frame(maxWidth: .infinity, alignment: message.senderUid == myUid ? .trailing : .leading)
                                    .id(message.id)
                            } else {
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

            // Return sends (speed audit S0-3); hold the mic for a voice memo
            // (Lucas 2026-10-17). A refusal hands the words back.
            VoiceComposer(
                draft: $draft,
                placeholder: "Type a message",
                recorder: recorder,
                onSend: { text in
                    Task { if await !store.sendMessage(text), draft.isEmpty { draft = text } }
                },
                onSendMemo: { memo in
                    // Text-only wire: the memo travels as its marker +
                    // transcript; the clip plays on this phone.
                    Task { _ = await store.sendMessage(VoiceMemoStore.marker(for: memo)) }
                }
            )
            .padding(16)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .recordingEdgeGlow(recorder)
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
    /// Scrolls with the list, above the search field (the Network tabs
    /// and the Connect row). Hidden while a thread is open.
    var topContent: AnyView? = nil
    @State private var openedThread: MessageThreadSummary?
    @State private var didAutoOpen = false
    @State private var query = ""
    @State private var searchTask: Task<Void, Never>?
    @State private var startingChatUid: String?
    @State private var showNewConversation = false
    @State private var showMorpheThread = false
    @State private var lastOffset: CGFloat = 0
    @State private var pinnedSearch = false
    @FocusState private var searchFocused: Bool

    private var myUid: String { store.authUser?.id ?? "" }

    private var cleanQuery: String {
        query.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Conversations matching the query by the OTHER person's name (all of
    /// them when the query is empty).
    private var visibleThreads: [MessageThreadSummary] {
        // Newest first (Lucas 2026-10-17); Morphe sits above them all.
        let sorted = store.liveThreads.sorted { $0.updatedAt > $1.updatedAt }
        guard !cleanQuery.isEmpty else { return sorted }
        return sorted.filter {
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
            } else if showMorpheThread {
                // In place, like every conversation (Lucas 2026-10-17): no
                // slide-up sheet.
                MorpheThreadView(onBack: {
                    showMorpheThread = false
                    store.markMorpheInboxRead()
                })
            } else {
                threadList
            }
        }
        // (The Network panes stay mounted, so the list is counted by its
        // section — `chatsHaveTheStage` — not by onAppear; Board and
        // Calendar get the floating button back. Lucas 2026-10-17.)
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
            VStack(spacing: 0) {
                // People · Messages, in the user's order
                // (Lucas 2026-10-17), each hideable, at least one kept.
                SectionEditorList(
                    editing: store.editingPage == .chats,
                    cards: store.visiblePageCards(ChatsCardID.self, page: .chats),
                    hidden: store.hiddenPageCards(ChatsCardID.self, page: .chats),
                    title: \.title,
                    onMove: { store.movePageCards($0, page: .chats) },
                    onHide: { store.hidePageCard($0, page: .chats) },
                    onShow: { store.showPageCard($0, page: .chats) }
                ) { card in
                    chatsSection(card)
                }
                .padding(.horizontal, 16)
                if store.editingPage != .chats {
                    EditLayoutButton(page: "Chats") { store.beginEditing(.chats) }
                        .frame(maxWidth: .infinity)
                        .padding(.top, 12)
                }
            }
            .padding(.vertical, 4)
            // The list clears the floating button; an open conversation
            // keeps its composer just above the bar (Lucas 2026-10-17).
            .padding(.bottom, 120)
        }
        .coordinateSpace(name: "chatsScroll")
        // The search row scrolls with the list; a scroll UP slides a pinned
        // copy in at the top, a scroll DOWN takes it away, and back at the
        // top the real row takes over (Lucas 2026-10-17, same as Discover).
        .onPreferenceChange(ChatsScrollOffsetKey.self) { y in
            let pastBar = y < -40
            let movingUp = y > lastOffset + 1.5
            let movingDown = y < lastOffset - 1.5
            lastOffset = y
            let next = pastBar && (movingUp || (pinnedSearch && !movingDown))
            if next != pinnedSearch {
                withAnimation(.spring(response: 0.32, dampingFraction: 0.86)) { pinnedSearch = next }
            }
        }
        .overlay(alignment: .top) {
            if pinnedSearch {
                HStack(spacing: 10) {
                    searchField
                    Button { showNewConversation = true } label: {
                        Image(systemName: "square.and.pencil")
                            .font(.headline.weight(.semibold))
                            .foregroundStyle(MorpheTheme.accentText)
                            .frame(width: 44, height: 44)
                            .background(Circle().fill(MorpheTheme.panelStrong))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("New message")
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    Rectangle().fill(.ultraThinMaterial)
                        .overlay(Rectangle().fill(MorpheTheme.ink.opacity(0.6)))
                        .ignoresSafeArea(edges: .top)
                )
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .scrollDismissesKeyboard(.immediately)
        .refreshable { await store.refreshThreads(force: true) }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    @ViewBuilder
    private func chatsSection(_ card: ChatsCardID) -> some View {
        switch card {
        case .people:
            if let topContent {
                VStack(spacing: 8) {
                    topContent
                    GuideHint(
                        key: "network.chats",
                        text: "This is your Network — chats live here, the weekly board and your calendar are one tab over. Search a username to start a conversation."
                    )
                    .padding(.horizontal, 16)
                }
                .padding(.horizontal, -16)
            } else {
                Text("Your people land here once you connect.")
                    .font(.caption)
                    .foregroundStyle(MorpheTheme.textMuted)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        case .conversations:
            VStack(spacing: 0) {
                HStack(spacing: 10) {
                    searchField
                    // Start a new conversation (Lucas 2026-10-10): the
                    // pencil every messaging app has.
                    Button {
                        showNewConversation = true
                    } label: {
                        Image(systemName: "square.and.pencil")
                            .font(.headline.weight(.semibold))
                            .foregroundStyle(MorpheTheme.accentText)
                            .frame(width: 44, height: 44)
                            .background(Circle().fill(MorpheTheme.panelStrong))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("New message")
                }
                .padding(.bottom, 8)
                // The pinned copy reads this row's place in the scroll.
                .background(GeometryReader { geo in
                    Color.clear.preference(key: ChatsScrollOffsetKey.self, value: geo.frame(in: .named("chatsScroll")).minY)
                })
                .sheet(isPresented: $showNewConversation) {
                    NewConversationSheet()
                        .environment(store)
                        .onAppear { store.chatSurfaceDepth += 1 }
                        .onDisappear { store.chatSurfaceDepth = max(0, store.chatSurfaceDepth - 1) }
                        .presentationDetents([.large])
                        .presentationDragIndicator(.visible)
                        .presentationCornerRadius(28)
                        .sheetToastSurface()
                }

            // Morphe's own conversation, always first (Lucas 2026-10-17):
            // weekly reports, news, answers. Every account has it; a
            // search still finds it by name.
                if cleanQuery.isEmpty || "morphe".localizedCaseInsensitiveContains(cleanQuery) {
                    Button {
                        showMorpheThread = true
                    } label: {
                        MorpheThreadRow(lastItem: nil, lastTurn: store.morpheConversation.last, unread: 0)
                            .padding(.horizontal, -16)
                    }
                    .buttonStyle(.plain)
                }
                if !visibleThreads.isEmpty {
                    Divider().overlay(MorpheTheme.stroke.opacity(0.5)).padding(.leading, 56)
                }

                ForEach(Array(visibleThreads.enumerated()), id: \.element.id) { index, thread in
                    Button {
                        openedThread = thread
                    } label: {
                        LiveThreadRow(thread: thread, viewerUid: myUid,
                                      isUnread: store.isThreadUnread(thread))
                            .padding(.horizontal, -16)
                    }
                    .buttonStyle(.plain)

                    if index < visibleThreads.count - 1 {
                        Divider()
                            .overlay(MorpheTheme.stroke.opacity(0.5))
                            .padding(.leading, 56)
                    }
                }

                if cleanQuery.count >= 2 {
                    directoryResults.padding(.horizontal, -16)
                } else if store.liveThreads.isEmpty,
                          store.threadsFetchState == .loading || store.threadsFetchState == .idle {
                    // Loading — never claim "no conversations" before the
                    // fetch answers (deferred-states pass 2026-09).
                    FetchPlaceholderCard(line: "Loading your chats…")
                } else if store.liveThreads.isEmpty, store.threadsFetchState == .failed {
                    // Failed with nothing cached — a retry, not a dead-end.
                    FetchRetryCard(message: "Your chats couldn't load — check your connection.") {
                        Task { await store.refreshThreads(force: true) }
                    }
                }
                // (No "no conversations yet" card — the Morphe chat is
                // always here, Lucas 2026-10-10.)
            }
        }
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
                                ProgressView().tint(MorpheTheme.onFill(MorpheTheme.accent))
                            } else {
                                Text("CHAT")
                                    .font(MorpheTheme.microLabel(10))
                                    .tracking(1.4)
                            }
                        }
                        .foregroundStyle(MorpheTheme.onFill(MorpheTheme.accent))
                        .padding(.horizontal, 16)
                        .frame(height: 34)
                        .background(Capsule().fill(MorpheTheme.accent))
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
                            .fill(MorpheTheme.accent)
                            .frame(width: 8, height: 8)
                    }
                    Text(name)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(MorpheTheme.textPrimary)
                    Spacer()
                    Text(thread.updatedAt.formatted(.relative(presentation: .named)))
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(isUnread ? MorpheTheme.accentText : MorpheTheme.textMuted)
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

// MARK: - Creator feed (2026-10-05)

/// The pinned Morphe row in Chats.
struct MorpheThreadRow: View {
    let lastItem: MorpheInboxItem?
    /// The last turn of the shared conversation (an ask or a reply).
    var lastTurn: ThreadMessage? = nil
    let unread: Int

    var body: some View {
        HStack(spacing: 12) {
            // Morphe's avatar is the app icon's Spartan art, in a circle
            // (Lucas 2026-10-16).
            Image("MorpheAppIconArt")
                .resizable()
                .interpolation(.high)
                .scaledToFill()
                .frame(width: 44, height: 44)
                .clipShape(Circle())
                .overlay(Circle().stroke(MorpheTheme.strokeSubtle, lineWidth: 1))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    if unread > 0 {
                        Circle().fill(MorpheTheme.accent).frame(width: 8, height: 8)
                    }
                    Text("Morphe")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(MorpheTheme.textPrimary)
                        .featureGlimmer()
                    // (GUARDIAN tag retired — one name, late audit #12.)
                    Spacer()
                    if let when = lastTurn?.sentAt ?? lastItem?.date {
                        Text(when.formatted(.relative(presentation: .named)))
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(unread > 0 ? MorpheTheme.accentText : MorpheTheme.textMuted)
                    }
                }
                Text(lastTurn.map { $0.text == "\u{2026}" ? "Morphe is thinking…" : $0.text.replacingOccurrences(of: "\n", with: ": ") } ?? "Just you and Morphe. Ask anything.")
                    .font(unread > 0 ? .caption.weight(.semibold) : .caption)
                    .foregroundStyle(unread > 0 ? MorpheTheme.textPrimary : MorpheTheme.textSecondary)
                    .lineLimit(2)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel(unread > 0 ? "Morphe, \(unread) new" : "Morphe")
    }
}

/// The Morphe conversation: reports and news on the left, your questions
/// on the right, a composer that asks the same brain as the floating chat.
struct MorpheThreadView: View {
    @Environment(MorpheAppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    /// In-place back (Lucas 2026-10-17); nil when presented on its own.
    var onBack: (() -> Void)? = nil
    @State private var draft = ""
    @State private var recorder = VoiceMemoRecorder()

    var body: some View {
        VStack(spacing: 0) {
            ChatPageHeader(title: "Morphe", subtitle: "Reports · news · ask anything", onBack: onBack ?? { dismiss() }) {
                Button("Mark all read", systemImage: "checkmark.circle") { store.markMorpheInboxRead() }
                Button("Open Morphe AI", systemImage: "sparkles") { store.openAIAgent() }
            }

            ScrollViewReader { proxy in
                ScrollView(showsIndicators: false) {
                    LazyVStack(alignment: .leading, spacing: 12) {
                        if !store.morpheConversation.contains(where: { $0.sender == .user }) {
                            Text("Your first report lands on Monday after your first logged week — or ask me something now. This is the same chat as the Morphe AI bubble.")
                                .font(.subheadline)
                                .foregroundStyle(MorpheTheme.textSecondary)
                                .padding(.top, 8)
                        }
                        // One conversation (Lucas 2026-10-16): the same
                        // turns, the same rows, as the floating chat.
                        let turns = store.morpheConversation
                        ForEach(Array(turns.enumerated()), id: \.element.id) { index, message in
                            AIAgentMessageRow(message: message, isFirstInRun: index == 0 || turns[index - 1].sender != message.sender)
                                .id(message.id)
                        }
                    }
                    .padding(20)
                }
                .onAppear { if let last = store.morpheConversation.last { proxy.scrollTo(last.id, anchor: .bottom) } }
                .onChange(of: store.morpheConversation.count) { _, _ in
                    if let last = store.morpheConversation.last {
                        withAnimation(.easeOut(duration: 0.2)) { proxy.scrollTo(last.id, anchor: .bottom) }
                    }
                }
            }

            Divider().overlay(MorpheTheme.stroke.opacity(0.8))
            VoiceComposer(
                draft: $draft,
                placeholder: "Ask Morphe",
                recorder: recorder,
                onSend: { text in Task { await store.askMorpheInThread(text) } },
                onSendMemo: { memo in store.sendMorpheVoiceMemo(memo) }
            )
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
        }
        .background(PremiumBackground().ignoresSafeArea())
        .recordingEdgeGlow(recorder)
        .onAppear { store.refreshMorpheInbox() }
    }

}

/// New message (Lucas 2026-10-10): the people you can message now —
/// connected, followed, already chatting — plus a directory search for
/// anyone else. Tap a person and the conversation opens.
struct NewConversationSheet: View {
    @Environment(MorpheAppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""
    @State private var searchTask: Task<Void, Never>?
    @State private var startingUid: String?

    private var cleanQuery: String { query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }

    private var people: [PersonCard] {
        let base = store.messageablePeople
        guard !cleanQuery.isEmpty else { return base }
        var cards = base.filter { $0.name.lowercased().contains(cleanQuery) || $0.username.lowercased().contains(cleanQuery) }
        let me = store.authUser?.id ?? ""
        for hit in store.athleteSearchResults where hit.uid != me && !cards.contains(where: { $0.uid == hit.uid }) && !store.blockedUids.contains(hit.uid) {
            cards.append(store.person(for: hit.uid) ?? PersonCard(uid: hit.uid, name: "", username: hit.username, headline: "", accentId: "", verified: false, isCoach: false))
        }
        return cards
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .firstTextBaseline) {
                    Text("New message")
                        .font(.title2.weight(.bold))
                        .foregroundStyle(MorpheTheme.textPrimary)
                    Spacer(minLength: 8)
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(MorpheTheme.textPrimary)
                        .frame(minWidth: 44, minHeight: 44)
                }
                TextField("To: name or @username", text: $query)
                    .textFieldStyle(MorpheFieldStyle())
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
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

                Text((cleanQuery.isEmpty ? "People you can message" : "Results").uppercased())
                    .task { await store.refreshConnectRequests() }
                    .font(MorpheTheme.microLabel(11))
                    .tracking(1.4)
                    .foregroundStyle(MorpheTheme.textMuted)

                if people.isEmpty {
                    GlassCard(.quiet) {
                        Text(cleanQuery.isEmpty
                             ? "Nobody yet. Connect with people from Quick Add, or type a @username to find anyone on Morphe."
                             : (cleanQuery.count < 2 ? "Keep typing…" : (store.athleteSearchFailed ? "Couldn't reach the directory — check your connection." : "No one matches \u{201C}\(query.trimmingCharacters(in: .whitespacesAndNewlines))\u{201D}.")))
                            .font(.subheadline)
                            .foregroundStyle(MorpheTheme.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                } else {
                    ForEach(people) { card in
                        PersonRow(card: card, trailing: {
                            if startingUid == card.uid {
                                ProgressView().tint(MorpheTheme.accent)
                            } else {
                                Image(systemName: "chevron.right")
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(MorpheTheme.textMuted)
                            }
                        }, onOpen: {
                            guard startingUid == nil else { return }
                            startingUid = card.uid
                            Task {
                                let opened = await store.startDirectChat(with: card.uid, name: card.displayName)
                                startingUid = nil
                                if opened { dismiss() }
                            }
                        })
                    }
                }
            }
            .padding(20)
        }
        .background(PremiumBackground().ignoresSafeArea())
    }
}

/// Everything Creator Coaches have published, newest first, as a feed:
/// workouts you can start or save, notes you can read, open challenges you
/// can join. Every item carries its author; notes can be reported.
struct CreatorFeed: View {
    @Environment(MorpheAppStore.self) private var store
    @State private var expandedNotes: Set<String> = []
    @State private var expandedWorkouts: Set<String> = []
    @State private var reporting: CreatorNote?
    @State private var reportingWorkout: CreatorWorkout?
    /// Search + type filter (Lucas 2026-10-10: a LinkedIn-style stream),
    /// store-backed (Lucas 2026-10-17) so the pinned bar shares them.
    private var query: String { store.exploreQuery }
    private var filter: Filter { ExploreFilter(rawValue: store.exploreFilter) ?? .all }
    private typealias Filter = ExploreFilter

    private enum Item: Identifiable {
        case workout(CreatorWorkout)
        case note(CreatorNote)
        case challenge(OpenChallengeListing)

        var id: String {
            switch self {
            case .workout(let w): return "w-" + w.id
            case .note(let n): return "n-" + n.id
            case .challenge(let c): return "c-" + c.code
            }
        }
        var date: Date {
            switch self {
            case .workout(let w): return w.publishedAt
            case .note(let n): return n.createdAt
            case .challenge(let c): return c.endsAt.addingTimeInterval(-30 * 86_400)
            }
        }
    }

    private func section(for filter: Filter) -> ExploreCardID? { filter.section }

    /// One section's items, newest first, filtered by the search.
    private func items(in section: ExploreCardID) -> [Item] {
        let joined = Set(store.activeChallenges.map(\.code))
        var all: [Item]
        switch section {
        case .workouts: all = store.creatorWorkouts.map(Item.workout)
        case .blogs: all = store.creatorNotes.map(Item.note)
        case .challenges: all = store.openChallenges.filter { !joined.contains($0.code) }.map(Item.challenge)
        }
        all = searched(all)
        all.sort { $0.date > $1.date }
        return all
    }

    private var items: [Item] {
        var all: [Item] = []
        if let only = section(for: filter) {
            all = items(in: only)
        } else {
            for section in store.visibleExploreCards { all += items(in: section) }
        }
        all.sort { $0.date > $1.date }
        return all
    }

    private func searched(_ items: [Item]) -> [Item] {
        var all = items
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if !q.isEmpty {
            all = all.filter { item in
                let haystack: String
                switch item {
                case .workout(let w): haystack = [w.name, w.notes, w.authorName, w.authorHandle, w.equipment, w.level].joined(separator: " ")
                case .note(let n): haystack = [n.title, n.body, n.authorName, n.authorHandle].joined(separator: " ")
                case .challenge(let c): haystack = [c.title, c.hostName, c.metric.label].joined(separator: " ")
                }
                return haystack.lowercased().contains(q)
            }
        }
        return all
    }

    private var totalCount: Int {
        store.creatorWorkouts.count + store.creatorNotes.count + store.openChallenges.count
    }

    private var emptyCard: some View {
        GlassCard(.quiet) {
            Text(store.authUser == nil
                 ? "Sign in to see what coaches are publishing."
                 : (totalCount == 0
                    ? "Nothing published yet. When Creator Coaches post workouts, blogs and challenges, they land here."
                    : "Nothing matches that search."))
                .font(.subheadline)
                .foregroundStyle(MorpheTheme.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    @ViewBuilder
    private func itemCard(_ item: Item) -> some View {
        switch item {
        case .workout(let workout): workoutCard(workout)
        case .note(let note): noteCard(note)
        case .challenge(let listing): challengeCard(listing)
        }
    }

    /// One Explore section: a header line, then its stream or one honest
    /// line when nothing is published yet.
    private func sectionBlock(_ card: ExploreCardID) -> some View {
        let rows = items(in: card)
        return VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Text(card.title.uppercased())
                    .font(MorpheTheme.microLabel(10)).tracking(1.4)
                    .foregroundStyle(MorpheTheme.textMuted)
                Rectangle().fill(MorpheTheme.stroke).frame(height: 1)
            }
            if rows.isEmpty {
                Text(store.authUser == nil ? "Sign in to see what coaches are publishing." : "Nothing here yet — \(card.detail.lowercased()) land here.")
                    .font(.subheadline)
                    .foregroundStyle(MorpheTheme.textSecondary)
                    .padding(.vertical, 4)
            } else {
                ForEach(rows) { item in itemCard(item) }
            }
        }
        .padding(.vertical, 4)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Search, then the stream (Lucas 2026-10-10) — the bar is shared
            // with the pinned copy (Lucas 2026-10-17).
            ExploreSearchBar()

            if let only = section(for: filter) {
                // One chip: that section's stream, flat.
                if items.isEmpty {
                    emptyCard
                } else {
                    ForEach(items) { item in itemCard(item) }
                }
            } else {
                // All: the sections in the user's order (Lucas 2026-10-16),
                // each hideable and holdable in editor mode.
                SectionEditorList(
                    editing: false,
                    cards: store.visibleExploreCards,
                    hidden: store.exploreCardLayout.filter { store.styleProfile.exploreHiddenCards.contains($0.rawValue) },
                    title: \.title,
                    onMove: { store.setExploreLayout(order: $0.map(\.rawValue)) },
                    onHide: { card in
                        guard store.visibleExploreCards.count > 1 else { return }
                        store.setExploreLayout(hidden: store.styleProfile.exploreHiddenCards + [card.rawValue])
                    },
                    onShow: { card in
                        var set = store.styleProfile.exploreHiddenCards
                        set.removeAll { $0 == card.rawValue }
                        store.setExploreLayout(hidden: set)
                    }
                ) { card in
                    sectionBlock(card)
                }

            }
        }
        // No .task here (audit 2026-10-10): panes stay mounted, so it
        // fetched three collections the moment Network appeared. The
        // For You tab's selection refreshes instead.
        .confirmationDialog("Report this note?", isPresented: Binding(get: { reporting != nil }, set: { if !$0 { reporting = nil } }),
                            titleVisibility: .visible, presenting: reporting) { note in
            ForEach(["Spam", "Harassment", "Unsafe advice", "Other"], id: \.self) { reason in
                Button(reason) {
                    store.reportCreatorContent(kind: "creatorNote", id: note.id, authorUid: note.authorUid,
                                               excerpt: note.title + " — " + note.body, reason: reason)
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: { _ in
            Text("A person reviews every report.")
        }
        .confirmationDialog("Report this workout?", isPresented: Binding(get: { reportingWorkout != nil }, set: { if !$0 { reportingWorkout = nil } }),
                            titleVisibility: .visible, presenting: reportingWorkout) { workout in
            ForEach(["Spam", "Unsafe programming", "Misleading", "Other"], id: \.self) { reason in
                Button(reason) {
                    store.reportCreatorContent(kind: "creatorWorkout", id: workout.id, authorUid: workout.authorUid,
                                               excerpt: workout.name + " — " + workout.notes, reason: reason)
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: { _ in
            Text("A person reviews every report.")
        }
    }

    /// The post header: avatar initials, name, handle and age on the left,
    /// the content type on the right — the stream reads like a feed, not
    /// a list of cards.
    private func byline(_ name: String, _ handle: String, _ date: Date, kind: String) -> some View {
        let initials = name.split(separator: " ").prefix(2).compactMap { $0.first }.map(String.init).joined().uppercased()
        return HStack(alignment: .center, spacing: 10) {
            Text(initials.isEmpty ? "C" : initials)
                .font(.caption.weight(.bold))
                .foregroundStyle(MorpheTheme.accentText)
                .frame(width: 36, height: 36)
                .background(Circle().fill(MorpheTheme.accent.opacity(0.15)))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 1) {
                Text(name.isEmpty ? "Creator Coach" : name)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(MorpheTheme.textPrimary)
                    .lineLimit(1)
                Text("\(handle.isEmpty ? "Creator Coach" : "@\(handle)") · \(date.formatted(.relative(presentation: .named)))")
                    .font(.caption)
                    .foregroundStyle(MorpheTheme.textMuted)
                    .lineLimit(1)
            }
            Spacer(minLength: 8)
            Text(kind.uppercased())
                .font(MorpheTheme.microLabel(9))
                .tracking(1.2)
                .foregroundStyle(MorpheTheme.accentText)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Capsule().fill(MorpheTheme.accent.opacity(0.12)))
        }
    }

    @ViewBuilder
    private func workoutCard(_ workout: CreatorWorkout) -> some View {
        if let template = store.template(for: workout) {
            GlassCard {
                VStack(alignment: .leading, spacing: 10) {
                    byline(workout.authorName, workout.authorHandle, workout.publishedAt, kind: "Workout")
                    Text(workout.name)
                        .font(.headline)
                        .foregroundStyle(MorpheTheme.textPrimary)
                    Text("\(template.exercises.count) exercises · \(workout.durationMinutes) min · \(workout.equipment) · \(workout.level)")
                        .font(.caption)
                        .monospacedDigit()
                        .foregroundStyle(MorpheTheme.textSecondary)
                    if !workout.notes.isEmpty {
                        Text(workout.notes)
                            .font(.subheadline)
                            .foregroundStyle(MorpheTheme.textSecondary)
                            .lineLimit(3)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    if expandedWorkouts.contains(workout.id) {
                        ForEach(template.exercises) { exercise in
                            Text("\(exercise.name) — \(exercise.sets) × \(exercise.reps)")
                                .font(.caption)
                                .foregroundStyle(MorpheTheme.textSecondary)
                        }
                    }
                    HStack(spacing: 10) {
                        Button("Start") { store.startCatalogWorkout(template) }
                            .buttonStyle(PrimaryCTAButtonStyle(accent: MorpheTheme.accent))
                        Button(store.isCatalogWorkoutSaved(template) ? "Saved" : "Save") { store.saveCatalogWorkout(template) }
                            .buttonStyle(SecondaryCTAButtonStyle())
                            .disabled(store.isCatalogWorkoutSaved(template))
                        Spacer(minLength: 0)
                        Button(expandedWorkouts.contains(workout.id) ? "Less" : "Exercises") {
                            if expandedWorkouts.contains(workout.id) { expandedWorkouts.remove(workout.id) } else { expandedWorkouts.insert(workout.id) }
                        }
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(MorpheTheme.accentText)
                        .frame(minHeight: 44)
                        Button("Report") { reportingWorkout = workout }
                            .font(.caption)
                            .foregroundStyle(MorpheTheme.textMuted)
                            .frame(minHeight: 44)
                    }
                }
            }
        }
    }

    private func noteCard(_ note: CreatorNote) -> some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 8) {
                byline(note.authorName, note.authorHandle, note.createdAt, kind: "Blog")
                Text(note.title)
                    .font(.headline)
                    .foregroundStyle(MorpheTheme.textPrimary)
                Text(note.body)
                    .font(.subheadline)
                    .foregroundStyle(MorpheTheme.textSecondary)
                    .lineLimit(expandedNotes.contains(note.id) ? nil : 4)
                    .fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 14) {
                    if note.body.count > 200 {
                        Button(expandedNotes.contains(note.id) ? "Less" : "Read more") {
                            if expandedNotes.contains(note.id) { expandedNotes.remove(note.id) } else { expandedNotes.insert(note.id) }
                        }
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(MorpheTheme.accentText)
                    }
                    Button("Report") { reporting = note }
                        .font(.caption)
                        .foregroundStyle(MorpheTheme.textMuted)
                }
                .frame(minHeight: 32)
            }
        }
    }

    private func challengeCard(_ listing: OpenChallengeListing) -> some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 8) {
                byline(listing.hostName, "", listing.endsAt.addingTimeInterval(-30 * 86_400), kind: "Challenge")
                Text(listing.title)
                    .font(.headline)
                    .foregroundStyle(MorpheTheme.textPrimary)
                Text("\(listing.metric.label) · ends \(listing.endsAt.formatted(date: .abbreviated, time: .omitted)) · scores come from logged workouts only")
                    .font(.caption)
                    .foregroundStyle(MorpheTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                Button("Join") { Task { await store.joinChallenge(code: listing.code) } }
                    .buttonStyle(SecondaryCTAButtonStyle())
                    .disabled(store.isCompetitionBusy)
            }
        }
    }
}


/// Explore's chips (Lucas 2026-10-17: a file-scope type so the store and the
/// pinned bar can name them).
enum ExploreFilter: String, CaseIterable, Identifiable {
    case all = "All", blogs = "Blogs", workouts = "Workouts", challenges = "Challenges"
    var id: String { rawValue }
    /// The section a chip stands for (All has none).
    var section: ExploreCardID? {
        switch self {
        case .all: return nil
        case .blogs: return .blogs
        case .workouts: return .workouts
        case .challenges: return .challenges
        }
    }
}

/// Explore's search field and chips, store-backed so the page and the
/// pinned copy are one state.
struct ExploreSearchBar: View {
    @Environment(MorpheAppStore.self) private var store

    /// All plus the sections the user keeps visible.
    private var chips: [ExploreFilter] {
        ExploreFilter.allCases.filter { f in f.section.map { store.visibleExploreCards.contains($0) } ?? true }
    }

    var body: some View {
        @Bindable var store = store
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(MorpheTheme.textMuted)
                TextField("Search coaches, blogs, workouts…", text: $store.exploreQuery)
                    .textFieldStyle(.plain)
                    .autocorrectionDisabled()
                if !store.exploreQuery.isEmpty {
                    Button { store.exploreQuery = "" } label: {
                        Image(systemName: "xmark.circle.fill").foregroundStyle(MorpheTheme.textMuted)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Clear search")
                }
            }
            .padding(.horizontal, 14)
            .frame(minHeight: 46)
            .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(MorpheTheme.panelStrong))

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(chips) { f in
                        Button(f.rawValue) { store.exploreFilter = f.rawValue }
                            .buttonStyle(FilterChipStyle(isSelected: store.exploreFilter == f.rawValue))
                    }
                }
            }
            .pageSwipeExempt()
            .onChange(of: chips) { _, now in
                if !now.contains(where: { $0.rawValue == store.exploreFilter }) { store.exploreFilter = ExploreFilter.all.rawValue }
            }
        }
    }
}


/// The chats list's scroll offset, read under its search row.
struct ChatsScrollOffsetKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = nextValue() }
}


// MARK: - Conversation chrome (Lucas 2026-10-17)

/// Back chevron top-left, the contact's name centered, the dots top-right.
struct ChatPageHeader<MenuItems: View>: View {
    let title: String
    var subtitle: String? = nil
    var onBack: (() -> Void)? = nil
    @ViewBuilder let menu: () -> MenuItems

    var body: some View {
        ZStack {
            HStack {
                if let onBack {
                    Button(action: onBack) {
                        Image(systemName: "chevron.left")
                            .font(.headline.weight(.bold))
                            .foregroundStyle(MorpheTheme.textPrimary)
                            .frame(width: 44, height: 44)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Back")
                } else {
                    Color.clear.frame(width: 44, height: 44)
                }
                Spacer()
                Menu {
                    menu()
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.headline.weight(.bold))
                        .foregroundStyle(MorpheTheme.textPrimary)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .accessibilityLabel("Conversation options")
            }
            VStack(spacing: 2) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(MorpheTheme.textPrimary)
                    .lineLimit(1)
                if let subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(MorpheTheme.textSecondary)
                        .lineLimit(1)
                }
            }
            .padding(.horizontal, 56)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }
}

// MARK: - Voice memos (Lucas 2026-10-17)

/// One recorded clip: the file on this phone, its length, its transcript.
struct VoiceMemo: Codable, Hashable, Identifiable {
    let id: String
    var duration: TimeInterval
    var transcript: String

    var url: URL { VoiceMemoStore.directory.appendingPathComponent(id + ".m4a") }
    var hasAudio: Bool { FileManager.default.fileExists(atPath: url.path) }
    var durationLabel: String {
        let total = Int(duration.rounded())
        return String(format: "%d:%02d", total / 60, total % 60)
    }
}

/// Where memos live (Application Support/MorpheStore/VoiceMemos) and how
/// one rides a text-only message: `[voice:<id>|0:07] transcript`.
enum VoiceMemoStore {
    static var directory: URL {
        let fm = FileManager.default
        let base = (try? fm.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)) ?? fm.temporaryDirectory
        let dir = base.appendingPathComponent("MorpheStore/VoiceMemos", isDirectory: true)
        try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }
    private static let indexKey = "morphe.voicememos"

    private static func loadIndex() -> [String: VoiceMemo] {
        guard let data = UserDefaults.standard.data(forKey: indexKey),
              let memos = try? JSONDecoder().decode([String: VoiceMemo].self, from: data) else { return [:] }
        return memos
    }
    private static func saveIndex(_ memos: [String: VoiceMemo]) {
        if let data = try? JSONEncoder().encode(memos) { UserDefaults.standard.set(data, forKey: indexKey) }
    }
    static func save(_ memo: VoiceMemo) {
        var memos = loadIndex(); memos[memo.id] = memo; saveIndex(memos)
    }
    static func memo(id: String) -> VoiceMemo? { loadIndex()[id] }
    static func delete(_ memo: VoiceMemo) {
        try? FileManager.default.removeItem(at: memo.url)
        var memos = loadIndex(); memos[memo.id] = nil; saveIndex(memos)
    }

    static func marker(for memo: VoiceMemo) -> String {
        "[voice:\(memo.id)|\(memo.durationLabel)] \(memo.transcript)"
    }
    /// The memo a message carries, if any — the local one when this phone
    /// recorded it, else a transcript-only stand-in.
    static func parse(_ text: String) -> VoiceMemo? {
        guard text.hasPrefix("[voice:"), let close = text.firstIndex(of: "]") else { return nil }
        let inner = text[text.index(text.startIndex, offsetBy: 7)..<close]
        let parts = inner.split(separator: "|", maxSplits: 1).map(String.init)
        guard parts.count == 2 else { return nil }
        let id = parts[0]
        let transcript = String(text[text.index(after: close)...]).trimmingCharacters(in: .whitespaces)
        if let local = memo(id: id) { return local }
        let pieces = parts[1].split(separator: ":").compactMap { Int($0) }
        let seconds = pieces.count == 2 ? TimeInterval(pieces[0] * 60 + pieces[1]) : 0
        return VoiceMemo(id: id, duration: seconds, transcript: transcript)
    }
}

/// Hold-to-record: AAC mono to a file, a metered level for the waveform,
/// then an on-device transcript. Hey Morphe pauses while the mic is ours.
@MainActor
@Observable
final class VoiceMemoRecorder {
    private(set) var isRecording = false
    /// 0…1 input level, ~30/s while recording.
    private(set) var level: Double = 0
    private(set) var elapsed: TimeInterval = 0
    /// One-line status for the composer (permission help).
    private(set) var notice: String?

    private var recorder: AVAudioRecorder?
    private var meter: Timer?
    private var startedAt: Date?
    private var currentID: String?

    func start() async {
        guard !isRecording else { return }
        let granted = await withCheckedContinuation { (c: CheckedContinuation<Bool, Never>) in
            AVAudioApplication.requestRecordPermission { c.resume(returning: $0) }
        }
        guard granted else { notice = "Allow the microphone in Settings to record."; return }
        HeyMorpheEngine.shared.pauseForExternalAudio()
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .allowBluetooth])
            try session.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            notice = "The microphone is busy."; HeyMorpheEngine.shared.resumeAfterExternalAudio(); return
        }
        let id = UUID().uuidString
        let url = VoiceMemoStore.directory.appendingPathComponent(id + ".m4a")
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44_100,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]
        do {
            let r = try AVAudioRecorder(url: url, settings: settings)
            r.isMeteringEnabled = true
            guard r.record() else { throw NSError(domain: "morphe.voice", code: 1) }
            recorder = r
        } catch {
            notice = "Couldn't start recording."; HeyMorpheEngine.shared.resumeAfterExternalAudio(); return
        }
        currentID = id
        startedAt = .now
        elapsed = 0
        notice = nil
        isRecording = true
        meter = Timer.scheduledTimer(withTimeInterval: 1.0 / 30.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in self?.tick() }
        }
    }

    private func tick() {
        guard let recorder, isRecording else { return }
        recorder.updateMeters()
        let db = Double(recorder.averagePower(forChannel: 0))
        // -50 dB → 0, 0 dB → 1, eased so speech moves the bars.
        let linear = max(0, min(1, (db + 50) / 50))
        level = level * 0.6 + pow(linear, 1.4) * 0.4
        elapsed = startedAt.map { Date.now.timeIntervalSince($0) } ?? 0
    }

    /// Stops, transcribes, saves. Nil when nothing usable was captured.
    func stop() async -> VoiceMemo? {
        guard isRecording, let recorder, let id = currentID else { return nil }
        meter?.invalidate(); meter = nil
        recorder.stop()
        let duration = startedAt.map { Date.now.timeIntervalSince($0) } ?? recorder.currentTime
        isRecording = false
        level = 0
        self.recorder = nil
        currentID = nil
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        HeyMorpheEngine.shared.resumeAfterExternalAudio()
        let url = VoiceMemoStore.directory.appendingPathComponent(id + ".m4a")
        guard duration >= 0.6, FileManager.default.fileExists(atPath: url.path) else {
            try? FileManager.default.removeItem(at: url)
            return nil
        }
        let transcript = await Self.transcribe(url)
        let memo = VoiceMemo(id: id, duration: duration, transcript: transcript)
        VoiceMemoStore.save(memo)
        return memo
    }

    /// On-device speech-to-text for a saved clip; empty when denied or
    /// nothing was recognized. Bounded so a stalled recognizer never hangs
    /// the composer.
    static func transcribe(_ url: URL) async -> String {
        let status = await withCheckedContinuation { (c: CheckedContinuation<SFSpeechRecognizerAuthorizationStatus, Never>) in
            SFSpeechRecognizer.requestAuthorization { c.resume(returning: $0) }
        }
        guard status == .authorized, let recognizer = SFSpeechRecognizer(), recognizer.isAvailable else { return "" }
        let request = SFSpeechURLRecognitionRequest(url: url)
        request.shouldReportPartialResults = false
        if recognizer.supportsOnDeviceRecognition { request.requiresOnDeviceRecognition = true }
        return await withTaskGroup(of: String.self) { group in
            group.addTask {
                await withCheckedContinuation { (c: CheckedContinuation<String, Never>) in
                    var done = false
                    recognizer.recognitionTask(with: request) { result, error in
                        guard !done else { return }
                        if let result, result.isFinal { done = true; c.resume(returning: result.bestTranscription.formattedString) }
                        else if error != nil { done = true; c.resume(returning: "") }
                    }
                }
            }
            group.addTask {
                try? await Task.sleep(for: .seconds(15))
                return ""
            }
            let first = await group.next() ?? ""
            group.cancelAll()
            return first
        }
    }
}

/// One player for every memo bubble; the playing id drives the icons.
@MainActor
@Observable
final class VoiceMemoPlayer: NSObject, AVAudioPlayerDelegate {
    static let shared = VoiceMemoPlayer()
    private(set) var playingID: String?
    private var player: AVAudioPlayer?

    func toggle(_ memo: VoiceMemo) {
        if playingID == memo.id { player?.stop(); player = nil; playingID = nil; return }
        player?.stop()
        guard memo.hasAudio, let p = try? AVAudioPlayer(contentsOf: memo.url) else { return }
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [.mixWithOthers])
        try? AVAudioSession.sharedInstance().setActive(true)
        p.delegate = self
        player = p
        playingID = memo.id
        p.play()
    }

    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor in self.playingID = nil; self.player = nil }
    }
}

/// The text field with the mic beside it. Return sends; holding the mic
/// records (buzz, waveform in the field, the mic lights); letting go
/// parks the clip above the field with its length and an ×, and return
/// sends it as audio.
struct VoiceComposer: View {
    @Binding var draft: String
    var placeholder: String
    var recorder: VoiceMemoRecorder
    let onSend: (String) -> Void
    let onSendMemo: (VoiceMemo) -> Void

    @State private var pendingMemo: VoiceMemo?
    @State private var holding = false
    @State private var finishing = false
    @FocusState private var focused: Bool

    var body: some View {
        VStack(alignment: .trailing, spacing: 8) {
            if let memo = pendingMemo {
                VoiceMemoBubble(memo: memo, isMine: true, onDelete: {
                    VoiceMemoStore.delete(memo)
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) { pendingMemo = nil }
                    Haptics.impact(.light)
                })
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
            if let notice = recorder.notice {
                Text(notice)
                    .font(.caption)
                    .foregroundStyle(MorpheTheme.warning)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            HStack(spacing: 10) {
                ZStack {
                    if recorder.isRecording {
                        RecordingWaveform(level: recorder.level, elapsed: recorder.elapsed)
                            .transition(.opacity)
                    } else if finishing {
                        HStack(spacing: 8) {
                            SwiftUI.ProgressView().tint(MorpheTheme.accent)
                            Text("Writing it down…")
                                .font(.subheadline)
                                .foregroundStyle(MorpheTheme.textSecondary)
                            Spacer()
                        }
                    } else {
                        TextField(pendingMemo == nil ? placeholder : "Return sends the clip", text: $draft, axis: .vertical)
                            .lineLimit(1...4)
                            .font(.subheadline)
                            .foregroundStyle(MorpheTheme.textPrimary)
                            .submitLabel(.send)
                            .onSubmit { submit() }
                            .focused($focused)
                    }
                }
                .padding(.horizontal, 14)
                .frame(minHeight: 46)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(MorpheTheme.panelStrong))
                .animation(.easeInOut(duration: 0.2), value: recorder.isRecording)

                // Dark when idle, lit while recording.
                Image(systemName: "mic.fill")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(recorder.isRecording ? MorpheTheme.onFill(MorpheTheme.accent) : MorpheTheme.textPrimary)
                    .frame(width: 46, height: 46)
                    .background(Circle().fill(recorder.isRecording ? MorpheTheme.accent : MorpheTheme.panelStrong))
                    .scaleEffect(recorder.isRecording ? 1.08 : 1)
                    .shadow(color: MorpheTheme.accent.opacity(recorder.isRecording ? 0.45 : 0), radius: 12)
                    .animation(.spring(response: 0.3, dampingFraction: 0.7), value: recorder.isRecording)
                    .contentShape(Circle())
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { _ in
                                guard !holding, !finishing else { return }
                                holding = true
                                focused = false
                                Haptics.impact(.medium)
                                Task { await recorder.start() }
                            }
                            .onEnded { _ in
                                guard holding else { return }
                                holding = false
                                finishing = true
                                Task {
                                    let memo = await recorder.stop()
                                    finishing = false
                                    if let memo {
                                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) { pendingMemo = memo }
                                        Haptics.impact(.light)
                                    }
                                }
                            }
                    )
                    .accessibilityLabel(recorder.isRecording ? "Recording — release to stop" : "Hold to record a voice memo")
            }
        }
    }

    private func submit() {
        if let memo = pendingMemo {
            onSendMemo(memo)
            withAnimation { pendingMemo = nil }
        }
        let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        draft = ""
        onSend(text)
    }
}

/// The bars that move with the voice while a memo records.
struct RecordingWaveform: View {
    var level: Double
    var elapsed: TimeInterval
    @State private var history: [Double] = Array(repeating: 0.08, count: 28)

    var body: some View {
        HStack(spacing: 10) {
            Circle().fill(Color.red).frame(width: 8, height: 8)
                .opacity(Int(elapsed * 2) % 2 == 0 ? 1 : 0.3)
            HStack(spacing: 3) {
                ForEach(Array(history.enumerated()), id: \.offset) { _, h in
                    Capsule()
                        .fill(MorpheTheme.accent)
                        .frame(width: 3, height: 4 + 22 * h)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Text(String(format: "%d:%02d", Int(elapsed) / 60, Int(elapsed) % 60))
                .font(MorpheTheme.microLabel(11)).monospacedDigit()
                .foregroundStyle(MorpheTheme.textSecondary)
        }
        .onChange(of: level) { _, now in
            history.removeFirst()
            history.append(max(0.08, now))
        }
    }
}

/// A sent (or pending) clip: play, a still waveform, the length bottom-left;
/// an × top-right while pending; a subtle chevron bottom-right that opens
/// the transcript.
struct VoiceMemoBubble: View {
    let memo: VoiceMemo
    var isMine: Bool
    /// Inside another bubble's chrome (the Morphe AI row) — no padding or
    /// background of its own.
    var inline: Bool = false
    var onDelete: (() -> Void)? = nil
    @State private var showTranscript = false
    private var player: VoiceMemoPlayer { VoiceMemoPlayer.shared }

    /// A still waveform shaped by the id, so the same clip always looks the same.
    private var bars: [CGFloat] {
        var seed = memo.id.unicodeScalars.reduce(UInt64(1469598103934665603)) { ($0 ^ UInt64($1.value)) &* 1099511628211 }
        return (0..<22).map { _ in
            seed = seed &* 6364136223846793005 &+ 1442695040888963407
            return 0.25 + CGFloat((seed >> 33) % 100) / 100 * 0.75
        }
    }

    var body: some View {
        let content = VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Button {
                    player.toggle(memo)
                } label: {
                    Image(systemName: player.playingID == memo.id ? "pause.circle.fill" : "play.circle.fill")
                        .font(.title2)
                        .foregroundStyle(memo.hasAudio ? MorpheTheme.accent : MorpheTheme.textMuted)
                }
                .buttonStyle(.plain)
                .disabled(!memo.hasAudio)
                .accessibilityLabel(player.playingID == memo.id ? "Pause voice memo" : "Play voice memo")
                HStack(spacing: 2) {
                    ForEach(Array(bars.enumerated()), id: \.offset) { _, h in
                        Capsule().fill(MorpheTheme.accent.opacity(0.7)).frame(width: 3, height: 6 + 18 * h)
                    }
                }
            }
            if showTranscript {
                Text(memo.transcript.isEmpty ? "No words were recognized in this clip." : memo.transcript)
                    .font(.caption)
                    .foregroundStyle(MorpheTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .transition(.opacity)
            }
            HStack {
                Text(memo.durationLabel)
                    .font(MorpheTheme.microLabel(10)).monospacedDigit()
                    .foregroundStyle(MorpheTheme.textMuted)
                Spacer(minLength: 24)
            }
        }
        .frame(minWidth: 160, alignment: .leading)

        Group {
            if inline {
                content
            } else {
                content
                    .padding(12)
                    .padding(.trailing, 8)
                    .background(
                        RoundedRectangle(cornerRadius: MorpheTheme.radius, style: .continuous)
                            .fill(isMine ? MorpheTheme.accentAlt.opacity(0.28) : MorpheTheme.panelStrong)
                    )
            }
        }
        .overlay(alignment: .bottomTrailing) {
            // The subtle door to the words.
            Button {
                withAnimation(.easeInOut(duration: 0.2)) { showTranscript.toggle() }
            } label: {
                Image(systemName: "chevron.down")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(MorpheTheme.textMuted)
                    .rotationEffect(.degrees(showTranscript ? 180 : 0))
                    .frame(width: 28, height: 28)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .padding(2)
            .accessibilityLabel(showTranscript ? "Hide transcript" : "Show transcript")
        }
        .overlay(alignment: .topTrailing) {
            if let onDelete {
                Button(action: onDelete) {
                    Image(systemName: "xmark")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(MorpheTheme.onFill(MorpheTheme.accent))
                        .frame(width: 24, height: 24)
                        .background(Circle().fill(MorpheTheme.accent))
                }
                .buttonStyle(.plain)
                .offset(x: 8, y: -8)
                .accessibilityLabel("Delete the recording")
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Voice memo, \(memo.durationLabel)")
    }
}

/// The screen's edge lights while a memo records (the Hey Morphe cue
/// without the Spartan or the bubbles).
struct RecordingEdgeGlowModifier: ViewModifier {
    var recorder: VoiceMemoRecorder
    func body(content: Content) -> some View {
        content.overlay {
            if recorder.isRecording {
                VoiceEdgeGlow(level: recorder.level)
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.25), value: recorder.isRecording)
    }
}

extension View {
    func recordingEdgeGlow(_ recorder: VoiceMemoRecorder) -> some View {
        modifier(RecordingEdgeGlowModifier(recorder: recorder))
    }
}


// MARK: - Explore grid + viewer (Lucas 2026-10-17)

/// One tile in Explore: a reel, a set of images, or a thread (a post or a
/// coach's blog with its replies).
struct ExploreItem: Identifiable, Hashable {
    enum Kind: Hashable {
        case reel(URL)
        case images([String])   // base64 JPEGs
        case thread
    }
    let id: String
    let kind: Kind
    let title: String
    let body: String
    let authorName: String
    let date: Date
    /// The real feed post behind the tile (likes, saves, comments); nil
    /// for a coach's blog note.
    let post: FeedPost?
    let note: CreatorNote?

    var isCarousel: Bool { if case .images(let a) = kind { return a.count > 1 }; return false }
}

extension MorpheAppStore {
    /// Explore's stream: photo posts as media, text posts and coach blogs
    /// as threads, newest first. Empty until the community publishes.
    var exploreItems: [ExploreItem] {
        var items: [ExploreItem] = []
        for post in feedPosts where !post.authorPrivate || followedUids.contains(post.authorUid) || post.authorUid == authUser?.id {
            let kind: ExploreItem.Kind = post.hasImage ? .images([post.imageB64]) : .thread
            items.append(ExploreItem(id: "p-" + post.id, kind: kind, title: post.workoutName, body: post.text,
                                     authorName: post.authorName, date: post.createdAt, post: post, note: nil))
        }
        for note in creatorNotes {
            items.append(ExploreItem(id: "n-" + note.id, kind: .thread, title: note.title, body: note.body,
                                     authorName: note.authorName, date: note.createdAt, post: nil, note: note))
        }
        // Morphe's own reports and news seed the grid (persona audit #11):
        // day one is never a blank wall.
        for item in morpheInbox where item.kind == .weeklyReport || item.kind == .news {
            items.append(ExploreItem(id: "m-" + item.id, kind: .thread, title: item.title, body: item.body,
                                     authorName: "Morphe", date: item.date, post: nil, note: nil))
        }
        return items.sorted { $0.date > $1.date }
    }
}

/// The three-column grid (4:5 tiles) under Explore's search and chips.
struct ExploreGrid: View {
    @Environment(MorpheAppStore.self) private var store
    @State private var opened: ExploreItem?

    private var filtered: [ExploreItem] {
        let q = store.exploreQuery.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let chip = ExploreFilter(rawValue: store.exploreFilter) ?? .all
        return store.exploreItems.filter { item in
            let kindOK: Bool
            switch chip {
            case .all: kindOK = true
            case .blogs: kindOK = item.kind == .thread
            case .workouts: kindOK = item.post?.hasSessionStats == true || !(item.post?.workoutName.isEmpty ?? true)
            case .challenges: kindOK = false
            }
            guard kindOK else { return false }
            guard !q.isEmpty else { return true }
            return [item.title, item.body, item.authorName].joined(separator: " ").lowercased().contains(q)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ExploreSearchBar()
            if filtered.isEmpty {
                GlassCard(.quiet) {
                    Text(store.authUser == nil
                         ? "Sign in to see what the community is sharing."
                         : (store.exploreItems.isEmpty
                            ? "Nothing here yet. Photos, reels and threads from the community land here."
                            : "Nothing matches that search."))
                        .font(.subheadline)
                        .foregroundStyle(MorpheTheme.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            } else {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 2), count: 3), spacing: 2) {
                    ForEach(filtered) { item in
                        Button { opened = item } label: {
                            ExploreTile(item: item)
                                .aspectRatio(4 / 5, contentMode: .fit)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("\(item.authorName): \(item.title.isEmpty ? item.body : item.title)")
                    }
                }
                .padding(.horizontal, -20)
            }
        }
        .fullScreenCover(item: $opened) { item in
            ExploreViewer(items: filtered, startAt: item) { opened = nil }
                .environment(store)
        }
    }
}

/// A grid tile: the photo, or a type-set thread card.
struct ExploreTile: View {
    let item: ExploreItem

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            switch item.kind {
            case .images(let b64s):
                if let first = b64s.first, let data = Data(base64Encoded: first), let ui = UIImage(data: data) {
                    Color.clear.overlay(Image(uiImage: ui).resizable().scaledToFill()).clipped()
                } else {
                    MorpheTheme.panelStrong
                }
            case .reel:
                MorpheTheme.ink
                Image(systemName: "play.fill").font(.title2).foregroundStyle(.white).frame(maxWidth: .infinity, maxHeight: .infinity)
            case .thread:
                MorpheTheme.panelStrong
                VStack(alignment: .leading, spacing: 6) {
                    Text(item.title.isEmpty ? item.body : item.title)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(MorpheTheme.textPrimary)
                        .lineLimit(5)
                    Spacer(minLength: 0)
                    Text(item.authorName)
                        .font(MorpheTheme.microLabel(9))
                        .foregroundStyle(MorpheTheme.textMuted)
                        .lineLimit(1)
                }
                .padding(8)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
            if item.isCarousel {
                Image(systemName: "square.on.square")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.white)
                    .shadow(radius: 2)
                    .padding(6)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
            }
        }
        .contentShape(Rectangle())
    }
}

/// Full-screen: the posts page vertically (up = next, down = previous, a
/// pull past the first refreshes); back top-left, dots top-right, the
/// engagement stack lower-right; a right swipe returns (on a carousel,
/// only from its first image). The tab bar is hidden by the cover.
struct ExploreViewer: View {
    @Environment(MorpheAppStore.self) private var store
    let items: [ExploreItem]
    let startAt: ExploreItem
    let onClose: () -> Void
    @State private var current: String = ""
    @State private var carouselIndex: [String: Int] = [:]
    @State private var refreshing = false
    @State private var showReport = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            // Native vertical paging (the rotated TabView clipped and
            // shifted every page, 2026-10-17): one post per screen, up =
            // next, down = previous.
            ScrollView(.vertical, showsIndicators: false) {
                LazyVStack(spacing: 0) {
                    ForEach(items) { item in
                        ExplorePostPage(item: item, carouselIndex: binding(for: item.id))
                            .containerRelativeFrame([.horizontal, .vertical])
                            .id(item.id)
                    }
                }
                .scrollTargetLayout()
            }
            .scrollTargetBehavior(.paging)
            .scrollPosition(id: Binding(get: { Optional(current) }, set: { if let id = $0 { current = id } }))
            .ignoresSafeArea()
            .sensoryFeedback(.selection, trigger: current)

            // Chrome
            VStack {
                HStack {
                    Button(action: onClose) {
                        Image(systemName: "chevron.left")
                            .font(.headline.weight(.bold))
                            .foregroundStyle(.white)
                            .frame(width: 44, height: 44)
                            .background(Circle().fill(.black.opacity(0.35)))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Back to Explore")
                    Spacer()
                    Menu {
                        if let post = currentItem?.post {
                            Button("Report", systemImage: "flag") { showReport = true }
                            if post.authorUid != store.authUser?.id {
                                Button("Block \(post.authorName)", systemImage: "hand.raised", role: .destructive) {
                                    store.blockAccount(uid: post.authorUid, name: post.authorName)
                                    onClose()
                                }
                            }
                        } else if currentItem?.note != nil {
                            Button("Report", systemImage: "flag") { showReport = true }
                        }
                    } label: {
                        Image(systemName: "ellipsis")
                            .font(.headline.weight(.bold))
                            .foregroundStyle(.white)
                            .frame(width: 44, height: 44)
                            .background(Circle().fill(.black.opacity(0.35)))
                    }
                    .accessibilityLabel("Post options")
                }
                .padding(.horizontal, 12)
                Spacer()
                HStack(alignment: .bottom) {
                    if let item = currentItem {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(item.authorName)
                                .font(.subheadline.weight(.bold))
                            if item.kind != .thread {
                                Text(item.body)
                                    .font(.subheadline)
                                    .lineLimit(3)
                            }
                        }
                        .foregroundStyle(.white)
                        .shadow(radius: 4)
                        .padding(.leading, 16)
                        .padding(.trailing, 72)
                    }
                    Spacer()
                }
                .padding(.bottom, 28)
            }
            .allowsHitTesting(true)

            if let item = currentItem {
                EngagementStack(item: item)
                    .padding(.trailing, 12)
                    .padding(.bottom, 110)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
            }

            if refreshing {
                SwiftUI.ProgressView().tint(.white)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                    .padding(.top, 60)
            }
        }
        .onAppear { current = startAt.id }
        .preferredColorScheme(.dark)
        .statusBarHidden(true)
        // Right swipe returns — from a carousel only on its first image.
        .simultaneousGesture(
            DragGesture(minimumDistance: 30)
                .onEnded { value in
                    let dx = value.translation.width, dy = value.translation.height
                    guard dx > 80, dx > abs(dy) * 1.5 else { return }
                    if let item = currentItem, item.isCarousel, (carouselIndex[item.id] ?? 0) > 0 { return }
                    onClose()
                }
        )
        // A pull down past the first post refreshes the feed.
        .simultaneousGesture(
            DragGesture(minimumDistance: 40)
                .onEnded { value in
                    guard value.translation.height > 120, current == items.first?.id, !refreshing else { return }
                    refreshing = true
                    Task { await store.refreshFeed(force: true); await store.refreshCreatorContent(force: true); refreshing = false }
                }
        )
        .confirmationDialog("Report this?", isPresented: $showReport, titleVisibility: .visible) {
            ForEach(MorpheAppStore.reportReasons, id: \.self) { reason in
                Button(reason) {
                    if let post = currentItem?.post { store.reportPost(post, reason: reason) }
                    else if let note = currentItem?.note {
                        store.reportCreatorContent(kind: "creatorNote", id: note.id, authorUid: note.authorUid, excerpt: note.title + " — " + note.body, reason: reason)
                    }
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: { Text("A person reviews every report.") }
    }

    private var currentItem: ExploreItem? { items.first { $0.id == current } ?? startAt }
    private func binding(for id: String) -> Binding<Int> {
        Binding(get: { carouselIndex[id] ?? 0 }, set: { carouselIndex[id] = $0 })
    }
}

/// One post, full screen: the reel, the carousel, or the thread.
struct ExplorePostPage: View {
    @Environment(MorpheAppStore.self) private var store
    let item: ExploreItem
    @Binding var carouselIndex: Int
    @State private var reply = ""

    var body: some View {
        switch item.kind {
        case .reel(let url):
            ReelPlayer(url: url)
        case .images(let b64s):
            TabView(selection: $carouselIndex) {
                ForEach(Array(b64s.enumerated()), id: \.offset) { index, b64 in
                    Group {
                        if let data = Data(base64Encoded: b64), let ui = UIImage(data: data) {
                            Image(uiImage: ui).resizable().scaledToFit()
                        } else {
                            Color.gray
                        }
                    }
                    .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: b64s.count > 1 ? .automatic : .never))
        case .thread:
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 14) {
                    // Clear the back / dots chrome (the pager ignores the
                    // safe area; the status bar is hidden here).
                    Spacer(minLength: 128)
                    if !item.title.isEmpty {
                        Text(item.title).font(.title2.weight(.bold)).foregroundStyle(.white)
                    }
                    Text(item.body).font(.body).foregroundStyle(.white.opacity(0.92))
                        .fixedSize(horizontal: false, vertical: true)
                    Text("\(item.authorName) · \(item.date.formatted(.relative(presentation: .named)))")
                        .font(.caption).foregroundStyle(.white.opacity(0.6))
                    if let post = item.post {
                        Divider().overlay(.white.opacity(0.2))
                        let comments = store.postComments[post.id] ?? []
                        Text(comments.isEmpty ? "No replies yet." : "\(comments.count) replies")
                            .font(MorpheTheme.microLabel(10)).tracking(1.2).foregroundStyle(.white.opacity(0.6))
                        ForEach(comments) { c in
                            VStack(alignment: .leading, spacing: 2) {
                                Text(c.authorName).font(.caption.weight(.semibold)).foregroundStyle(.white)
                                Text(c.text).font(.subheadline).foregroundStyle(.white.opacity(0.9))
                            }
                        }
                        HStack(spacing: 8) {
                            TextField("Reply…", text: $reply)
                                .textFieldStyle(.plain)
                                .foregroundStyle(.white)
                                .submitLabel(.send)
                                .onSubmit {
                                    let t = reply; reply = ""
                                    Task { _ = await store.addComment(to: post, text: t) }
                                }
                        }
                        .padding(.horizontal, 14).frame(minHeight: 44)
                        .background(Capsule().fill(.white.opacity(0.12)))
                        .task { await store.loadComments(for: post) }
                    }
                    Spacer(minLength: 160)
                }
                .padding(.horizontal, 20)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .scrollDismissesKeyboard(.interactively)
        }
    }
}

/// Like · reply · share · save, stacked lower-right.
struct EngagementStack: View {
    @Environment(MorpheAppStore.self) private var store
    let item: ExploreItem

    var body: some View {
        VStack(spacing: 18) {
            if let post = item.post {
                button(store.myReactedPostIds.contains(post.id) ? "heart.fill" : "heart",
                       label: "\(store.feedReactionCounts[post.id] ?? 0)",
                       tint: store.myReactedPostIds.contains(post.id) ? .red : .white) { store.toggleReaction(post); Haptics.impact(.light) }
                button("bubble.right", label: "\((store.postComments[post.id] ?? []).count)", tint: .white) {}
                ShareLink(item: item.body) { glyph("square.and.arrow.up", label: "Share", tint: .white) }
                button(store.savedPostIds.contains(post.id) ? "bookmark.fill" : "bookmark", label: "Save", tint: .white) { store.toggleSaved(post); Haptics.impact(.light) }
            } else {
                ShareLink(item: item.title + "\n" + item.body) { glyph("square.and.arrow.up", label: "Share", tint: .white) }
            }
        }
    }

    private func button(_ symbol: String, label: String, tint: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) { glyph(symbol, label: label, tint: tint) }.buttonStyle(.plain)
    }
    private func glyph(_ symbol: String, label: String, tint: Color) -> some View {
        VStack(spacing: 4) {
            Image(systemName: symbol).font(.title2.weight(.semibold)).foregroundStyle(tint).shadow(radius: 3)
            Text(label).font(.caption2.weight(.semibold)).foregroundStyle(.white).shadow(radius: 2)
        }
        .frame(width: 48)
        .contentShape(Rectangle())
    }
}

/// A looping reel.
struct ReelPlayer: View {
    let url: URL
    @State private var player: AVPlayer?
    var body: some View {
        Group {
            if let player { VideoPlayer(player: player).ignoresSafeArea() } else { Color.black }
        }
        .onAppear {
            let p = AVPlayer(url: url); p.isMuted = false; p.play()
            NotificationCenter.default.addObserver(forName: .AVPlayerItemDidPlayToEndTime, object: p.currentItem, queue: .main) { _ in p.seek(to: .zero); p.play() }
            player = p
        }
        .onDisappear { player?.pause(); player = nil }
    }
}
