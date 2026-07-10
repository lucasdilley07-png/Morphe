import SwiftUI

struct CoachDashboardView: View {
    @Environment(MorpheAppStore.self) private var store

    var body: some View {
        @Bindable var store = store
        return TabView(selection: $store.selectedCoachTab) {
            CoachCommandCenterScreen()
                .tag(CoachTab.dashboard)

            CoachAthletesScreen()
                .tag(CoachTab.athletes)

            CoachDiscoverScreen()
                .tag(CoachTab.discover)

            CoachProgramsScreen()
                .tag(CoachTab.programs)

            if FeatureFlags.multiUserEnabled {
                CoachNetworkScreen()
                    .tag(CoachTab.network)
            }

            CoachMessagesScreen()
                .tag(CoachTab.messages)
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        .safeAreaInset(edge: .top) {
            CoachPinnedHeader()
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
            BottomTabNavigation(items: CoachTab.visibleCases, selected: store.selectedCoachTab) { tab in
                store.selectedCoachTab = tab
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 8)
        }
        .sheet(item: Binding(
            get: { store.selectedCoachClient },
            set: { _ in store.closeClientHub() }
        )) { athlete in
            AthleteProfileView(athlete: athlete)
        }
        .animation(.easeInOut(duration: 0.25), value: store.selectedCoachTab)
    }
}

private struct CoachPinnedHeader: View {
    @Environment(MorpheAppStore.self) private var store

    private var coachAvatarSymbol: String {
        if store.coachProfile.specialty.localizedCaseInsensitiveContains("boxing") {
            return "🥊"
        }
        if let sport = store.coachProfile.sports.first {
            switch sport {
            case .boxing: return "🥊"
            case .soccer: return "⚽"
            case .basketball: return "🏀"
            case .running, .track: return "🏃"
            case .strength: return "🏋️"
            case .weightLoss: return "🔥"
            default: return "🧠"
            }
        }

        return "🧠"
    }

    var body: some View {
        HStack(spacing: 12) {
            Button {
                store.openClientProfile()
            } label: {
                HStack(spacing: 10) {
                    Text(coachAvatarSymbol)
                        .font(.title3)
                        .frame(width: 40, height: 40)
                        .background(
                            Circle()
                                .fill(MorpheTheme.panelStrong)
                                .overlay(
                                    Circle()
                                        .stroke(MorpheTheme.strokeStrong.opacity(0.28), lineWidth: 1)
                                )
                        )

                    VStack(alignment: .leading, spacing: 2) {
                        Text(store.coachProfile.name)
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(.white)
                        Text("@\(store.coachProfile.username)")
                            .font(.caption)
                            .foregroundStyle(MorpheTheme.textSecondary)
                    }
                }
            }
            .buttonStyle(.plain)

            Spacer()

            CoachHeaderCircleButton(systemImage: "plus") {
                store.openQuickAdd()
            }

            CoachHeaderCircleButton(systemImage: "bubble.left.and.bubble.right.fill") {
                store.selectedCoachTab = .messages
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: MorpheTheme.radius, style: .continuous)
                .fill(MorpheTheme.panelRaised.opacity(0.96))
                .overlay(
                    RoundedRectangle(cornerRadius: MorpheTheme.radius, style: .continuous)
                        .stroke(MorpheTheme.strokeStrong.opacity(0.24), lineWidth: 1)
                )
        )
    }
}

private struct CoachHeaderCircleButton: View {
    let systemImage: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(.subheadline).weight(.semibold))
                .foregroundStyle(.white)
                .frame(width: 38, height: 38)
                .background(
                    RoundedRectangle(cornerRadius: MorpheTheme.radius, style: .continuous)
                        .fill(MorpheTheme.panelRaised)
                        .overlay(
                            RoundedRectangle(cornerRadius: MorpheTheme.radius, style: .continuous)
                                .stroke(MorpheTheme.strokeStrong.opacity(0.28), lineWidth: 1)
                        )
                )
        }
        .buttonStyle(.plain)
    }
}

private struct CoachCommandDisclosureSection<Content: View>: View {
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

private struct CoachCommandCenterScreen: View {
    @Environment(MorpheAppStore.self) private var store
    @State private var showOverview = false
    @State private var showTeamView = false
    @State private var showSignals = false
    @State private var sessionRequest: CoachSessionLaunchRequest?
    @State private var coachPraiseDraft: CoachPublicPraiseDraft?

    private var pendingAIReviewAthlete: CoachClient? {
        store.filteredCoachClients.first { athlete in
            store.workoutLogs(for: athlete.id).contains { $0.verificationStatus == .aiPendingReview }
        }
    }

    private var nextUpcomingSession: CalendarEvent? {
        store.upcomingSessions.first(where: { !$0.isComplete })
    }

    private var nextInterventionNeedingAction: CoachIntervention? {
        store.coachInterventions.first(where: { $0.status != "Handled" })
    }

    private var recoveryIntervention: CoachIntervention? {
        store.coachInterventions.first {
            $0.status != "Handled"
                && ($0.reason.localizedCaseInsensitiveContains("pain")
                    || $0.reason.localizedCaseInsensitiveContains("recovery"))
        }
    }

    private var messageTargetThread: MessageThread? {
        if let intervention = nextInterventionNeedingAction {
            return store.messageThreads.first(where: { $0.participant == intervention.athleteName })
        }

        return store.messageThreads.first(where: \.isUnread)
    }

    private var followUpRecommendations: [CoachFollowUpRecommendation] {
        store.coachFollowUpRecommendations(limit: 3)
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 16) {
                SectionTitleView(
                    title: "Command Center",
                    subtitle: "See who needs attention first, what changed, and the next coaching move."
                )

                CoachDashboardTriageCard(
                    coachName: store.coachProfile.name,
                    atRiskCount: store.coachOverview.atRiskClients,
                    pendingAIReviewCount: pendingAIReviewAthlete.map { athlete in
                        store.workoutLogs(for: athlete.id).filter { $0.verificationStatus == .aiPendingReview }.count
                    } ?? 0,
                    painFlagCount: store.coachOverview.painFlags,
                    replyQueueCount: store.coachOverview.messagesNeedingResponse,
                    nextSession: nextUpcomingSession,
                    nextIntervention: nextInterventionNeedingAction,
                    showsRecoveryAction: recoveryIntervention != nil,
                    onReviewAI: {
                        guard let athlete = pendingAIReviewAthlete else { return }
                        store.selectedCoachTab = .athletes
                        store.openClientHub(athlete)
                        store.announce("Opened \(athlete.name) for AI log review.")
                    },
                    onMessageAthlete: {
                        if let thread = messageTargetThread {
                            store.selectedCoachTab = .messages
                            store.selectThread(thread)
                        } else {
                            store.selectedCoachTab = .messages
                            store.announce("Inbox open for the next follow-up.")
                        }
                    },
                    onStartSession: {
                        guard let event = nextUpcomingSession else { return }
                        sessionRequest = CoachSessionLaunchRequest(
                            title: "Start Session",
                            subtitle: "Choose the workout you want to run for this session right now.",
                            preferredSport: store.athleteForUpcomingSession(event)?.sport ?? .generalFitness,
                            athleteID: event.athleteID,
                            groupID: event.groupID,
                            eventID: event.id
                        )
                    },
                    onAssignRecovery: {
                        guard let intervention = recoveryIntervention else { return }
                        store.assignInterventionPlan(intervention)
                    }
                )

                if !followUpRecommendations.isEmpty {
                    CoachFollowUpQueueCard(
                        recommendations: followUpRecommendations,
                        onOpenAthlete: { recommendation in
                            if let athlete = store.coachClients.first(where: { $0.id == recommendation.athleteID }) {
                                store.selectedCoachTab = .athletes
                                store.openClientHub(athlete)
                            }
                        },
                        onRunAction: { recommendation in
                            handleFollowUpRecommendation(recommendation)
                        }
                    )
                }

                MultiSportCoachFilter(
                    selected: store.coachSportFilter,
                    sports: store.coachFilterOptions
                ) { sport in
                    store.selectCoachSportFilter(sport)
                }

                CoachUpcomingSessionsCard(events: store.upcomingSessions)

                CoachInterventionQueueCard(interventions: store.coachInterventions)

                CoachCommandDisclosureSection(
                    title: "Overview + metrics",
                    subtitle: "Use the broader coaching summary once the urgent work is already moving.",
                    isExpanded: $showOverview
                ) {
                    CoachHeroSummaryCard(profile: store.coachProfile, overview: store.coachOverview)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            CoachMetricCard(title: "Needs Attention", value: "\(store.coachOverview.atRiskClients)")
                            CoachMetricCard(title: "Sessions Today", value: "\(store.coachOverview.sessionsToday)")
                            CoachMetricCard(title: "Reply Queue", value: "\(store.coachOverview.messagesNeedingResponse)")
                            CoachMetricCard(title: "Pain Flags", value: "\(store.coachOverview.painFlags)")
                            CoachMetricCard(title: "Check-ins", value: "\(store.coachOverview.checkInsNeeded)")
                        }
                    }
                }

                CoachCommandDisclosureSection(
                    title: "Team view",
                    subtitle: "Groups and readiness stay here when you want the broader coaching picture, not just the next action.",
                    isExpanded: $showTeamView
                ) {
                    TeamGroupCoachingCard(groups: store.teamGroups) { group in
                        store.selectGroup(group)
                        store.sendGroupAnnouncement(for: group)
                    }

                    AthleteReadinessDashboardCard(athletes: store.filteredCoachClients)
                }

                CoachCommandDisclosureSection(
                    title: "Signals + wins",
                    subtitle: "Open the wider coaching signals once the urgent work is already under control.",
                    isExpanded: $showSignals
                ) {
                    CoachBulletCard(title: "Priority Alerts", items: store.coachOverview.sportAlerts)
                    CoachBulletCard(title: "Athlete Wins", items: store.coachOverview.wins)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 120)
        }
        .sheet(item: $sessionRequest) { request in
            CoachStartSessionSheet(request: request)
                .environment(store)
        }
        .sheet(item: $coachPraiseDraft) { draft in
            CoachPublicPraiseSheet(draft: draft)
                .environment(store)
        }
    }

    private func handleFollowUpRecommendation(_ recommendation: CoachFollowUpRecommendation) {
        switch recommendation.type {
        case .reviewAI:
            if let athlete = store.coachClients.first(where: { $0.id == recommendation.athleteID }) {
                store.selectedCoachTab = .athletes
                store.openClientHub(athlete)
                store.announce("Opened \(athlete.name) for AI review.")
            }
        case .reviewBuddy:
            if let athlete = store.coachClients.first(where: { $0.id == recommendation.athleteID }) {
                store.selectedCoachTab = .athletes
                store.openClientHub(athlete)
                store.announce("Opened \(athlete.name)'s buddy-session logs.")
            }
        case .messageAthlete:
            store.openCoachFollowUpThread(
                for: recommendation.athleteID,
                action: .messageAthlete,
                toast: "Message thread ready for \(recommendation.athleteName)."
            )
        case .assignRecovery:
            store.assignRecoveryPlan(to: recommendation.athleteID)
        case .missedSessionNudge:
            store.openCoachOutreachShortcut(.missedSession, for: recommendation.athleteID)
        case .partnerPrompt:
            store.openCoachOutreachShortcut(.partner, for: recommendation.athleteID)
        case .askPainUpdate:
            store.openCoachFollowUpThread(
                for: recommendation.athleteID,
                action: .askPainUpdate,
                toast: "Pain check-in ready for \(recommendation.athleteName)."
            )
        case .praisePublicly:
            coachPraiseDraft = store.makeCoachPraiseDraft(for: recommendation.athleteID)
        }
    }
}

private struct CoachAthletesScreen: View {
    @Environment(MorpheAppStore.self) private var store

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 16) {
                SectionTitleView(
                    title: "Athletes",
                    subtitle: "Filter by sport, scan the risk level, and open the athlete hub for the full context."
                )

                if store.coachClients.isEmpty {
                    // A brand-new coach has no roster — say so instead of
                    // rendering a sport filter over a blank void.
                    GlassCard {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("No athletes yet")
                                .font(.headline)
                                .foregroundStyle(.white)
                            Text("Your roster starts empty. When Morphe accounts launch, athletes join with an invite code you share — their training, readiness, and messages land here.")
                                .font(.subheadline)
                                .foregroundStyle(MorpheTheme.textSecondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                } else {
                    MultiSportCoachFilter(
                        selected: store.coachSportFilter,
                        sports: store.coachFilterOptions
                    ) { sport in
                        store.selectCoachSportFilter(sport)
                    }

                    ForEach(store.filteredCoachClients) { athlete in
                        CoachAthleteCard(
                            athlete: athlete,
                            onOpenHub: { store.openClientHub(athlete) },
                            onMessage: {
                                if let thread = store.messageThreads.first(where: { $0.participant == athlete.name }) {
                                    store.selectedCoachTab = .messages
                                    store.selectThread(thread)
                                }
                            }
                        )
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 120)
        }
    }
}

private struct CoachProgramsScreen: View {
    @Environment(MorpheAppStore.self) private var store
    @State private var draft = ProgramBuilderDraft()
    @State private var selectedTemplateForAssignment: WorkoutTemplate?
    @State private var selectedSavedWorkoutForAssignment: SavedWorkoutLibraryItem?
    @State private var exerciseSearch = ""
    @State private var showSessionSetup = true
    @State private var showExerciseBuilder = false
    @State private var showArchiveTools = false

    private var workspaceSummary: String {
        if let athlete = store.selectedCoachClient {
            return "Building around \(athlete.name)'s \(athlete.goal.lowercased()) work right now."
        }

        if let sport = store.coachSportFilter {
            return "Building in \(sport.shortTitle) mode with \(store.filteredCoachClients.count) athletes in focus."
        }

        return "Building around \(store.coachProfile.specialty.lowercased()) with \(store.coachProfile.activeClients) active athletes in the system."
    }

    var body: some View {
        @Bindable var store = store
        return ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 16) {
                SectionTitleView(
                    title: "Build",
                    subtitle: "Build around your coaching style, your athletes, and the sessions you reuse the most."
                )

                Picker("Build Section", selection: $store.selectedCoachBuildSection) {
                    ForEach(CoachBuildSection.allCases) { section in
                        Text(section.rawValue).tag(section)
                    }
                }
                .pickerStyle(.segmented)

                CoachBuildWorkspaceCard(
                    coachName: store.coachProfile.name,
                    specialty: store.coachProfile.specialty,
                    summary: workspaceSummary,
                    athleteCount: store.filteredCoachClients.count,
                    savedCount: store.savedWorkouts.count,
                    playbookCount: store.playbooks.count
                )

                if store.selectedCoachBuildSection == .builder {
                    GlassCard {
                        VStack(alignment: .leading, spacing: 14) {
                            HStack(alignment: .top) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Sport Program Builder")
                                        .font(.headline)
                                        .foregroundStyle(.white)
                                    Text("Build the session, adjust the exercise stack, then save the draft straight into your archive.")
                                        .font(.subheadline)
                                        .foregroundStyle(MorpheTheme.textSecondary)
                                }

                                Spacer()

                                Button("Start Fresh") {
                                    draft = ProgramBuilderDraft()
                                    exerciseSearch = ""
                                    store.selectedProgramTemplateID = nil
                                }
                                .buttonStyle(SecondaryCTAButtonStyle())
                            }

                            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 2), spacing: 8) {
                                MetricPill(label: "Sport", value: draft.sport.shortTitle)
                                MetricPill(label: "Exercises", value: "\(draft.exercises.count)")
                                MetricPill(label: "Duration", value: "\(draft.durationMinutes) min")
                                MetricPill(label: "Rest", value: draft.restTime)
                            }
                        }
                    }

                    CoachBuilderDisclosureSection(
                        title: "Session setup",
                        subtitle: "Name it, shape it, and keep the session basics in one place.",
                        isExpanded: $showSessionSetup
                    ) {
                        GlassCard {
                            VStack(alignment: .leading, spacing: 12) {
                                TextField("Program name", text: $draft.workoutName)
                                    .textFieldStyle(MorpheFieldStyle())

                                TextField("Target / focus", text: $draft.goal)
                                    .textFieldStyle(MorpheFieldStyle())

                                TextField("Equipment", text: $draft.equipment)
                                    .textFieldStyle(MorpheFieldStyle())

                                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 2), spacing: 10) {
                                    CoachMenuField(title: "Sport") {
                                        Picker("Sport", selection: $draft.sport) {
                                            ForEach([SportFocus.boxing, .soccer, .basketball, .running, .generalFitness, .strength]) { sport in
                                                Text(sport.rawValue).tag(sport)
                                            }
                                        }
                                        .pickerStyle(.menu)
                                    }

                                    CoachMenuField(title: "Focus") {
                                        Picker("Category", selection: $draft.category) {
                                            ForEach(ProgramCategory.allCases) { category in
                                                Text(category.rawValue).tag(category)
                                            }
                                        }
                                        .pickerStyle(.menu)
                                    }

                                    CoachMenuField(title: "Session type") {
                                        Picker("Session Type", selection: $draft.sessionType) {
                                            ForEach(SessionType.allCases) { type in
                                                Text(type.rawValue).tag(type)
                                            }
                                        }
                                        .pickerStyle(.menu)
                                    }

                                    CoachMenuField(title: "Difficulty") {
                                        Picker("Difficulty", selection: $draft.difficulty) {
                                            ForEach(DemoDifficulty.allCases) { difficulty in
                                                Text(difficulty.rawValue).tag(difficulty)
                                            }
                                        }
                                        .pickerStyle(.menu)
                                    }
                                }

                                Stepper("Duration: \(draft.durationMinutes) min", value: $draft.durationMinutes, in: 15...90, step: 5)
                                    .foregroundStyle(.white)

                                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3), spacing: 8) {
                                    TextField("Sets", text: $draft.defaultSets)
                                        .textFieldStyle(MorpheFieldStyle())
                                    TextField("Reps", text: $draft.defaultReps)
                                        .textFieldStyle(MorpheFieldStyle())
                                    TextField("Rest", text: $draft.restTime)
                                        .textFieldStyle(MorpheFieldStyle())
                                }

                                TextField("Coach notes", text: $draft.coachNotes, axis: .vertical)
                                    .textFieldStyle(MorpheFieldStyle())
                            }
                        }
                    }

                    CoachBuilderDisclosureSection(
                        title: "Exercise stack",
                        subtitle: "Search, add, and tune the actual session without bouncing between separate cards.",
                        isExpanded: $showExerciseBuilder
                    ) {
                        GlassCard {
                            VStack(alignment: .leading, spacing: 12) {
                                TextField("Search exercise, gear, or muscle group", text: $exerciseSearch)
                                    .textFieldStyle(MorpheFieldStyle())

                                if builderExerciseSuggestions.isEmpty {
                                    Text("No exercises match that search yet.")
                                        .font(.caption)
                                        .foregroundStyle(MorpheTheme.textSecondary)
                                } else {
                                    ForEach(builderExerciseSuggestions) { exercise in
                                        HStack(alignment: .top, spacing: 10) {
                                            VStack(alignment: .leading, spacing: 4) {
                                                Text(exercise.name)
                                                    .font(.subheadline.weight(.semibold))
                                                    .foregroundStyle(.white)
                                                Text("\(exercise.musclesWorked) • \(exercise.equipment)")
                                                    .font(.caption)
                                                    .foregroundStyle(MorpheTheme.textSecondary)
                                                Text(exercise.formCue)
                                                    .font(.caption)
                                                    .foregroundStyle(MorpheTheme.textMuted)
                                                    .lineLimit(2)
                                            }

                                            Spacer()

                                            Button("Add") {
                                                draft.exercises.append(
                                                    MorpheDemoContent.makeWorkoutExercise(
                                                        exercise.id,
                                                        sets: draft.defaultSets,
                                                        reps: draft.defaultReps
                                                    )
                                                )
                                            }
                                            .buttonStyle(SecondaryCTAButtonStyle())
                                        }
                                        .padding(.vertical, 4)
                                    }
                                }
                            }
                        }

                        if !draft.exercises.isEmpty {
                            GlassCard {
                                VStack(alignment: .leading, spacing: 12) {
                                    HStack {
                                        Text("Current draft")
                                            .font(.headline)
                                            .foregroundStyle(.white)
                                        Spacer()
                                        Text("\(draft.exercises.count) exercises")
                                            .font(.caption.weight(.semibold))
                                            .foregroundStyle(MorpheTheme.textMuted)
                                    }

                                    ForEach(Array(draft.exercises.enumerated()), id: \.element.id) { index, exercise in
                                        VStack(alignment: .leading, spacing: 8) {
                                            HStack {
                                                Text(exercise.name)
                                                    .foregroundStyle(.white)
                                                Spacer()
                                                Button("Remove") {
                                                    draft.exercises.remove(at: index)
                                                }
                                                .buttonStyle(SecondaryCTAButtonStyle())
                                            }

                                            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3), spacing: 8) {
                                                TextField(
                                                    "Sets",
                                                    text: Binding(
                                                        get: { draft.exercises[index].sets },
                                                        set: { draft.exercises[index].sets = $0 }
                                                    )
                                                )
                                                .textFieldStyle(MorpheFieldStyle())

                                                TextField(
                                                    "Reps",
                                                    text: Binding(
                                                        get: { draft.exercises[index].reps },
                                                        set: { draft.exercises[index].reps = $0 }
                                                    )
                                                )
                                                .textFieldStyle(MorpheFieldStyle())

                                                TextField(
                                                    "Cue",
                                                    text: Binding(
                                                        get: { draft.exercises[index].formCue },
                                                        set: { draft.exercises[index].formCue = $0 }
                                                    )
                                                )
                                                .textFieldStyle(MorpheFieldStyle())
                                            }
                                        }
                                        .padding(.vertical, 4)
                                    }
                                }
                            }
                        }
                    }

                    CoachBuilderDisclosureSection(
                        title: "Save + archive",
                        subtitle: "Save the draft fast, then reopen or assign proven sessions when you need them.",
                        isExpanded: $showArchiveTools
                    ) {
                        GlassCard {
                            VStack(alignment: .leading, spacing: 12) {
                                Button("Save Draft to Archive") {
                                    store.createProgram(from: draft)
                                }
                                .buttonStyle(PrimaryCTAButtonStyle(accent: MorpheTheme.accent))

                                Text("Saved sessions stay here so you can reopen them, assign them, or keep tuning them later.")
                                    .font(.caption)
                                    .foregroundStyle(MorpheTheme.textSecondary)
                            }
                        }

                        GlassCard {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Workout archive")
                                    .font(.headline)
                                    .foregroundStyle(.white)

                                ForEach(groupedTemplates.keys.sorted(), id: \.self) { key in
                                    VStack(alignment: .leading, spacing: 10) {
                                        Text(key)
                                            .font(.subheadline.weight(.semibold))
                                            .foregroundStyle(MorpheTheme.accentAlt)

                                        ForEach(groupedTemplates[key] ?? []) { template in
                                            VStack(alignment: .leading, spacing: 10) {
                                                HStack {
                                                    VStack(alignment: .leading, spacing: 4) {
                                                        Text(template.name)
                                                            .font(.subheadline.weight(.semibold))
                                                            .foregroundStyle(.white)
                                                        Text("\(template.goal) • \(template.durationMinutes) min • \(template.equipment)")
                                                            .font(.caption)
                                                            .foregroundStyle(MorpheTheme.textSecondary)
                                                    }
                                                    Spacer()
                                                    if store.selectedProgramTemplateID == template.id {
                                                        StatusBadge(text: "Editing", color: MorpheTheme.accent)
                                                    }
                                                }

                                                HStack(spacing: 10) {
                                                    Button("Open Draft") {
                                                        draft = ProgramBuilderDraft(
                                                            workoutName: template.name,
                                                            sport: template.sport,
                                                            category: template.category,
                                                            sessionType: template.sessionType,
                                                            goal: template.goal,
                                                            difficulty: template.difficulty,
                                                            durationMinutes: template.durationMinutes,
                                                            equipment: template.equipment,
                                                            exercises: template.exercises,
                                                            defaultSets: template.defaultSets,
                                                            defaultReps: template.defaultReps,
                                                            rpe: "7",
                                                            restTime: template.restTime,
                                                            coachNotes: template.coachNote
                                                        )
                                                        store.selectProgramTemplate(template)
                                                        showSessionSetup = true
                                                        showExerciseBuilder = true
                                                    }
                                                    .buttonStyle(SecondaryCTAButtonStyle())

                                                    Button("Assign") {
                                                        selectedTemplateForAssignment = template
                                                    }
                                                    .buttonStyle(PrimaryCTAButtonStyle(accent: MorpheTheme.accentAlt))
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                } else {
                    CoachBuildLibraryPanel { item in
                        selectedSavedWorkoutForAssignment = item
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 120)
        }
        .sheet(item: $selectedTemplateForAssignment) { template in
            AssignWorkoutSheet(template: template)
                .environment(store)
        }
        .sheet(item: $selectedSavedWorkoutForAssignment) { item in
            AssignSavedWorkoutSheet(item: item)
                .environment(store)
        }
    }

    private var groupedTemplates: [String: [WorkoutTemplate]] {
        Dictionary(grouping: store.workoutTemplates) { $0.sport.rawValue }
    }

    private var builderExerciseSuggestions: [ExerciseReference] {
        let base = store.exerciseDatabase
        let query = exerciseSearch.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        guard !query.isEmpty else { return Array(base.prefix(6)) }

        return base.filter { exercise in
            exercise.name.lowercased().contains(query)
                || exercise.musclesWorked.lowercased().contains(query)
                || exercise.equipment.lowercased().contains(query)
                || exercise.movementPattern.lowercased().contains(query)
        }
        .prefix(8)
        .map { $0 }
    }
}

private struct CoachMenuField<Content: View>: View {
    let title: String
    let content: () -> Content

    init(title: String, @ViewBuilder content: @escaping () -> Content) {
        self.title = title
        self.content = content
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(MorpheTheme.textSecondary)
            content()
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
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
}

private struct CoachBuildWorkspaceCard: View {
    let coachName: String
    let specialty: String
    let summary: String
    let athleteCount: Int
    let savedCount: Int
    let playbookCount: Int

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(coachName)'s Build Workspace")
                            .font(.headline)
                            .foregroundStyle(.white)
                        Text(specialty)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(MorpheTheme.accentAlt)
                    }

                    Spacer()

                    StatusBadge(text: "Personalized", color: MorpheTheme.accent)
                }

                Text(summary)
                    .font(.subheadline)
                    .foregroundStyle(MorpheTheme.textSecondary)

                HStack(spacing: 8) {
                    MetricPill(label: "Athletes", value: "\(athleteCount)")
                    MetricPill(label: "Saved", value: "\(savedCount)")
                    MetricPill(label: "Playbooks", value: "\(playbookCount)")
                }
            }
        }
    }
}

private struct CoachBuilderDisclosureSection<Content: View>: View {
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

private struct CoachLibraryDisclosureSection<Content: View>: View {
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

private struct CoachBuildLibraryPanel: View {
    @Environment(MorpheAppStore.self) private var store
    let onAssignSavedWorkout: (SavedWorkoutLibraryItem) -> Void
    @State private var showSavedLibrary = true
    @State private var showPlaybooks = false
    @State private var showDrills = false
    @State private var showExercises = false
    @State private var showTesting = false

    private var focusedAthlete: CoachClient? {
        store.selectedCoachClient ?? store.filteredCoachClients.first ?? store.coachClients.first
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            CoachLibraryDisclosureSection(
                title: "Saved Workout Library",
                subtitle: "Pull proven workouts and assign them without rebuilding the session.",
                isExpanded: $showSavedLibrary
            ) {
                if store.savedWorkouts.isEmpty {
                    GlassCard {
                        Text("No saved workouts yet. Save useful workouts from profiles or the network and they’ll show up here.")
                            .foregroundStyle(MorpheTheme.textSecondary)
                    }
                } else {
                    ForEach(store.savedWorkouts.prefix(5)) { item in
                        let insight = store.savedWorkoutInsight(for: item)
                        GlassCard {
                            VStack(alignment: .leading, spacing: 10) {
                                HStack(alignment: .top, spacing: 12) {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(item.workoutName)
                                            .font(.subheadline.weight(.semibold))
                                            .foregroundStyle(.white)
                                        Text("\(item.sourceContext) • \(item.sourceName)")
                                            .font(.caption)
                                            .foregroundStyle(MorpheTheme.textSecondary)
                                    }

                                    Spacer()

                                    StatusBadge(
                                        text: item.sourceRole == .coach ? "Coach source" : "Athlete source",
                                        color: item.sourceRole == .coach ? MorpheTheme.accentAlt : MorpheTheme.accent
                                    )
                                }

                                HStack(spacing: 8) {
                                    MetricPill(label: "Best for", value: item.bestFor.rawValue)
                                    MetricPill(label: "Completed", value: "\(insight.completionCount)x")
                                    MetricPill(label: "Last run", value: insight.lastCompletedAt.map(MorpheAppStore.workoutDateLabel(for:)) ?? "Not yet")
                                }

                                Text(item.note)
                                    .font(.caption)
                                    .foregroundStyle(MorpheTheme.textSecondary)

                                Button("Assign From Library") {
                                    onAssignSavedWorkout(item)
                                }
                                .buttonStyle(PrimaryCTAButtonStyle(accent: MorpheTheme.accentAlt))
                            }
                        }
                    }
                }
            }

            CoachLibraryDisclosureSection(
                title: "Coach Playbooks",
                subtitle: "Open the systems you return to when you want programming consistency.",
                isExpanded: $showPlaybooks
            ) {
                ForEach(store.playbooks) { playbook in
                    CoachPlaybookCard(playbook: playbook)
                }
            }

            CoachLibraryDisclosureSection(
                title: "Skill Drill Library",
                subtitle: "Quick access to the drills that support your sport-specific work.",
                isExpanded: $showDrills
            ) {
                GlassCard {
                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(store.drills.prefix(6)) { drill in
                            SkillDrillCard(drill: drill)
                        }
                    }
                }
            }

            CoachLibraryDisclosureSection(
                title: "Exercise Library",
                subtitle: "Searchable exercise help that stays one tap away from the builder.",
                isExpanded: $showExercises
            ) {
                GlassCard {
                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(store.exerciseDatabase.prefix(6), id: \.id) { exercise in
                            HStack(alignment: .top) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(exercise.name)
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(.white)
                                    Text("\(exercise.musclesWorked) • \(exercise.equipment)")
                                        .font(.caption)
                                        .foregroundStyle(MorpheTheme.textSecondary)
                                }
                                Spacer()
                                Button("Open") {
                                    store.selectedExercise = exercise
                                }
                                .buttonStyle(SecondaryCTAButtonStyle())
                                .frame(width: 88)
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
            }

            CoachLibraryDisclosureSection(
                title: "Sport Testing Dashboard",
                subtitle: "Testing, reports, and video review stay here when you need performance context.",
                isExpanded: $showTesting
            ) {
                if let athlete = focusedAthlete {
                    SportTestingDashboardCard(tests: athlete.tests)
                    VideoReviewHubCard(clips: athlete.videoReviews)
                }

                CoachQualityAnalyticsCard(analytics: store.coachAnalytics)
            }
        }
    }
}

private struct CoachNetworkScreen: View {
    @Environment(MorpheAppStore.self) private var store
    @State private var section: CoachNetworkSection = .forYou

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 16) {
                SectionTitleView(
                    title: "Network",
                    subtitle: "Coach-facing updates, comments, and connections that still feel useful inside a serious coaching product."
                )

                CoachNetworkPresenceCard(profile: store.coachProfile, groups: store.teamGroups.count, unread: store.messageThreads.filter(\.isUnread).count)
                CoachNetworkHighlightsRail()

                Picker("Coach Network", selection: $section) {
                    ForEach(CoachNetworkSection.allCases) { item in
                        Text(item.rawValue).tag(item)
                    }
                }
                .pickerStyle(.segmented)

                switch section {
                case .forYou:
                    CommunityNetworkFeed(perspective: .coach)
                    CommunityDiscoveryCard(groups: store.trainingGroups, challenges: store.challenges, leaderboard: store.leaderboards)
                case .athletes:
                    CoachFilteredNetworkFeed(
                        title: "Athletes",
                        subtitle: "Training updates and accountability posts from the athletes in your world.",
                        posts: store.rankedCommunityPosts(for: .coach).filter { $0.role == .client }
                    )
                case .coaches:
                    CoachFilteredNetworkFeed(
                        title: "Coaches",
                        subtitle: "Practical coaching notes, systems, and athlete wins from other coaches.",
                        posts: store.rankedCommunityPosts(for: .coach).filter { $0.role == .coach }
                    )
                case .grow:
                    NetworkSuggestionsCard()
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 120)
        }
    }
}

private struct CoachFilteredNetworkFeed: View {
    @Environment(MorpheAppStore.self) private var store
    let title: String
    let subtitle: String
    let posts: [ProgressPost]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            GlassCard {
                VStack(alignment: .leading, spacing: 8) {
                    Text(title)
                        .font(.headline)
                        .foregroundStyle(.white)
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(MorpheTheme.textSecondary)
                }
            }

            ForEach(posts) { post in
                CommunityPostCard(post: post) {
                    store.reactToCommunityPost(post)
                } onComment: {
                    store.commentOnCommunityPost(post)
                } onShare: {
                    store.shareCommunityPost("Sharing \(post.author)'s update with my coaching network.", as: .coach)
                } onSaveWorkout: {
                    store.saveWorkoutFromCommunityPost(post)
                }
            }
        }
    }
}

private struct CoachRescheduleSheet: View {
    @Environment(\.dismiss) private var dismiss
    let event: CalendarEvent
    @Binding var date: Date
    let onSave: (Date) -> Void

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                Text("Reschedule \(event.title)")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(.white)

                DatePicker("New time", selection: $date)
                    .datePickerStyle(.graphical)
                    .tint(MorpheTheme.accent)

                Button("Save New Time") {
                    onSave(date)
                    dismiss()
                }
                .buttonStyle(PrimaryCTAButtonStyle(accent: MorpheTheme.accent))

                Spacer()
            }
            .padding(20)
            .background(PremiumBackground())
        }
    }
}

private struct InterventionTemplateSheet: View {
    @Environment(MorpheAppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let intervention: CoachIntervention

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 16) {
                    GlassCard {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Message \(intervention.athleteName)")
                                .font(.headline)
                                .foregroundStyle(.white)
                            Text("Pick the template that fits this intervention instead of auto-sending a generic reply.")
                                .foregroundStyle(MorpheTheme.textSecondary)
                        }
                    }

                    ForEach(store.messageTemplates) { template in
                        GlassCard {
                            VStack(alignment: .leading, spacing: 10) {
                                Text(template.title)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(.white)
                                Text(template.body)
                                    .font(.caption)
                                    .foregroundStyle(MorpheTheme.textSecondary)
                                Button("Use Template") {
                                    store.sendCoachTemplate(template, to: intervention)
                                    dismiss()
                                }
                                .buttonStyle(PrimaryCTAButtonStyle(accent: MorpheTheme.accentAlt))
                            }
                        }
                    }
                }
                .padding(20)
            }
            .background(PremiumBackground())
        }
    }
}

private struct InterventionAssignSheet: View {
    @Environment(MorpheAppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let intervention: CoachIntervention

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 16) {
                    GlassCard {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Assign a Workout")
                                .font(.headline)
                                .foregroundStyle(.white)
                            Text("Choose the best session for \(intervention.athleteName) based on the intervention reason.")
                                .foregroundStyle(MorpheTheme.textSecondary)
                        }
                    }

                    ForEach(store.workoutTemplates) { template in
                        GlassCard {
                            VStack(alignment: .leading, spacing: 10) {
                                Text(template.name)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(.white)
                                Text("\(template.goal) • \(template.durationMinutes) min • \(template.equipment)")
                                    .font(.caption)
                                    .foregroundStyle(MorpheTheme.textSecondary)
                                Button("Assign Workout") {
                                    store.assignInterventionTemplate(template, to: intervention)
                                    dismiss()
                                }
                                .buttonStyle(PrimaryCTAButtonStyle(accent: MorpheTheme.accent))
                            }
                        }
                    }
                }
                .padding(20)
            }
            .background(PremiumBackground())
        }
    }
}

private struct AssignWorkoutSheet: View {
    @Environment(MorpheAppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let template: WorkoutTemplate
    @State private var selectedClientID: UUID?
    @State private var scheduledDate = Date()

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                Text("Assign \(template.name)")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(.white)

                Picker("Athlete", selection: $selectedClientID) {
                    ForEach(store.coachClients) { athlete in
                        Text(athlete.name).tag(Optional(athlete.id))
                    }
                }
                .pickerStyle(.menu)

                DatePicker("Day and time", selection: $scheduledDate)
                    .datePickerStyle(.graphical)
                    .tint(MorpheTheme.accent)

                Button("Assign Workout") {
                    guard let selectedClientID,
                          let athlete = store.coachClients.first(where: { $0.id == selectedClientID })
                    else { return }

                    let formatter = DateFormatter()
                    formatter.dateFormat = "EEEE h:mm a"
                    store.assignWorkoutTemplate(template, to: athlete, scheduledLabel: formatter.string(from: scheduledDate))
                    dismiss()
                }
                .buttonStyle(PrimaryCTAButtonStyle(accent: MorpheTheme.accent))

                Spacer()
            }
            .padding(20)
            .background(PremiumBackground())
            .onAppear {
                selectedClientID = selectedClientID ?? store.coachClients.first?.id
            }
        }
    }
}

private struct AssignSavedWorkoutSheet: View {
    @Environment(MorpheAppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let item: SavedWorkoutLibraryItem
    @State private var selectedClientID: UUID?
    @State private var scheduledDate = Date()

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                Text("Assign \(item.workoutName)")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(.white)

                HStack(spacing: 8) {
                    StatusBadge(
                        text: item.sourceRole == .coach ? "Coach source" : "Athlete source",
                        color: item.sourceRole == .coach ? MorpheTheme.accentAlt : MorpheTheme.accent
                    )
                    StatusBadge(
                        text: "Best for \(item.bestFor.rawValue)",
                        color: MorpheTheme.warning
                    )
                }

                Text("\(item.sourceContext) • \(item.sourceName)")
                    .font(.subheadline)
                    .foregroundStyle(MorpheTheme.textSecondary)

                Text(item.note)
                    .font(.caption)
                    .foregroundStyle(MorpheTheme.textSecondary)

                Picker("Athlete", selection: $selectedClientID) {
                    ForEach(store.coachClients) { athlete in
                        Text(athlete.name).tag(Optional(athlete.id))
                    }
                }
                .pickerStyle(.menu)

                DatePicker("Day and time", selection: $scheduledDate)
                    .datePickerStyle(.graphical)
                    .tint(MorpheTheme.accent)

                Button("Assign Saved Workout") {
                    guard let selectedClientID,
                          let athlete = store.coachClients.first(where: { $0.id == selectedClientID })
                    else { return }

                    let formatter = DateFormatter()
                    formatter.dateFormat = "EEEE h:mm a"
                    store.assignSavedWorkout(item, to: athlete, scheduledLabel: formatter.string(from: scheduledDate))
                    dismiss()
                }
                .buttonStyle(PrimaryCTAButtonStyle(accent: MorpheTheme.accent))

                Spacer()
            }
            .padding(20)
            .background(PremiumBackground())
            .onAppear {
                selectedClientID = selectedClientID ?? store.coachClients.first?.id
            }
        }
    }
}

struct CoachStartSessionSheet: View {
    @Environment(MorpheAppStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    let request: CoachSessionLaunchRequest
    @State private var searchText = ""

    private var athlete: CoachClient? {
        guard let athleteID = request.athleteID else { return nil }
        return store.coachClients.first(where: { $0.id == athleteID })
    }

    private var event: CalendarEvent? {
        guard let eventID = request.eventID else { return nil }
        return store.upcomingSessions.first(where: { $0.id == eventID })
    }

    private var templates: [WorkoutTemplate] {
        let base: [WorkoutTemplate]

        if let event {
            base = store.availableSessionTemplates(for: event)
        } else if let athlete {
            base = store.availableSessionTemplates(for: athlete)
        } else {
            base = store.workoutTemplates
        }

        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !query.isEmpty else { return base }

        return base.filter { template in
            template.name.lowercased().contains(query)
                || template.goal.lowercased().contains(query)
                || template.equipment.lowercased().contains(query)
                || template.sport.rawValue.lowercased().contains(query)
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 16) {
                    GlassCard {
                        VStack(alignment: .leading, spacing: 12) {
                            Text(request.title)
                                .font(.headline)
                                .foregroundStyle(.white)
                            Text(request.subtitle)
                                .font(.subheadline)
                                .foregroundStyle(MorpheTheme.textSecondary)

                            if let athlete {
                                HStack(spacing: 8) {
                                    MetricPill(label: "Athlete", value: athlete.name)
                                    MetricPill(label: "Sport", value: athlete.sport.shortTitle)
                                    MetricPill(label: "Current", value: athlete.currentProgram)
                                }
                            }
                        }
                    }

                    TextField("Search programs or workouts", text: $searchText)
                        .textFieldStyle(MorpheFieldStyle())

                    if templates.isEmpty {
                        GlassCard {
                            Text("No matching programs yet. Try a different search or save a few more workouts first.")
                                .foregroundStyle(MorpheTheme.textSecondary)
                        }
                    } else {
                        ForEach(templates) { template in
                            GlassCard {
                                VStack(alignment: .leading, spacing: 10) {
                                    HStack(alignment: .top) {
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(template.name)
                                                .font(.subheadline.weight(.semibold))
                                                .foregroundStyle(.white)
                                            Text("\(template.goal) • \(template.durationMinutes) min")
                                                .font(.caption)
                                                .foregroundStyle(MorpheTheme.textSecondary)
                                        }
                                        Spacer()
                                        StatusBadge(text: template.sport.shortTitle, color: MorpheTheme.color(for: template.sport))
                                    }

                                    HStack(spacing: 8) {
                                        MetricPill(label: "Type", value: template.sessionType.rawValue)
                                        MetricPill(label: "Gear", value: template.equipment)
                                    }

                                    Button("Start Session") {
                                        if let event {
                                            store.startUpcomingSession(event, with: template)
                                        } else if let athlete {
                                            store.startCoachSession(for: athlete, with: template, sourceLabel: "Athlete Profile")
                                        }
                                        dismiss()
                                    }
                                    .buttonStyle(PrimaryCTAButtonStyle(accent: MorpheTheme.accent))
                                }
                            }
                        }
                    }
                }
                .padding(20)
            }
            .background(PremiumBackground())
        }
    }
}

private struct CoachUpcomingSessionsCard: View {
    @Environment(MorpheAppStore.self) private var store
    let events: [CalendarEvent]
    @State private var selectedEvent: CalendarEvent?
    @State private var rescheduleDate = Date()
    @State private var sessionRequest: CoachSessionLaunchRequest?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Upcoming Sessions")
                .font(.headline)
                .foregroundStyle(.white)

            ForEach(events.prefix(3)) { event in
                CoachUpcomingSessionEventCard(
                    event: event,
                    athlete: store.athleteForUpcomingSession(event),
                    onUpdateAttendance: { athleteName, status in
                        store.updateAttendance(for: athleteName, in: event, status: status)
                    },
                    onStart: {
                        sessionRequest = CoachSessionLaunchRequest(
                            title: "Start Session",
                            subtitle: "Choose the workout you want to run for this session right now.",
                            preferredSport: store.athleteForUpcomingSession(event)?.sport ?? .generalFitness,
                            athleteID: event.athleteID,
                            groupID: event.groupID,
                            eventID: event.id
                        )
                    },
                    onReschedule: {
                        selectedEvent = event
                    },
                    onComplete: {
                        store.completeUpcomingSession(event)
                    }
                )
            }
        }
        .sheet(item: $selectedEvent) { event in
            CoachRescheduleSheet(event: event, date: $rescheduleDate) { date in
                let formatter = DateFormatter()
                formatter.dateFormat = "EEEE"
                let day = formatter.string(from: date)
                formatter.dateFormat = "h:mm a"
                let time = formatter.string(from: date)
                store.rescheduleUpcomingSession(event, to: day, time: time)
                selectedEvent = nil
            }
        }
        .sheet(item: $sessionRequest) { request in
            CoachStartSessionSheet(request: request)
                .environment(store)
        }
    }
}

private struct CoachUpcomingSessionEventCard: View {
    let event: CalendarEvent
    let athlete: CoachClient?
    let onUpdateAttendance: (String, AttendanceStatus) -> Void
    let onStart: () -> Void
    let onReschedule: () -> Void
    let onComplete: () -> Void

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top, spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(event.title)
                            .font(.headline)
                            .foregroundStyle(.white)
                        Text("\(event.day) • \(event.time)")
                            .font(.subheadline)
                            .foregroundStyle(MorpheTheme.textSecondary)
                    }

                    Spacer()

                    StatusBadge(text: event.type.rawValue, color: MorpheTheme.accentAlt)
                }

                Text(event.detail)
                    .font(.subheadline)
                    .foregroundStyle(MorpheTheme.textPrimary)

                if let athlete {
                    HStack(spacing: 8) {
                        MetricPill(label: "Athlete", value: athlete.name)
                        MetricPill(label: "Program", value: athlete.currentProgram)
                    }
                }

                if !event.attendance.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Attendance + Session Check-in")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(MorpheTheme.textSecondary)

                        ForEach(event.attendance) { member in
                            VStack(alignment: .leading, spacing: 6) {
                                HStack {
                                    Text(member.athleteName)
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(.white)
                                    Spacer()
                                    StatusBadge(text: member.status.rawValue, color: MorpheTheme.accent)
                                }

                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 8) {
                                        ForEach(AttendanceStatus.allCases) { status in
                                            Button(status.rawValue) {
                                                onUpdateAttendance(member.athleteName, status)
                                            }
                                            .buttonStyle(FilterChipStyle(isSelected: member.status == status, selectedColor: MorpheTheme.accent))
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 2), spacing: 8) {
                    Button("Start Session", action: onStart)
                        .buttonStyle(PrimaryCTAButtonStyle(accent: MorpheTheme.accent))

                    Button("Reschedule", action: onReschedule)
                        .buttonStyle(SecondaryCTAButtonStyle())
                }

                Button(event.isComplete ? "Completed" : "Complete Session", action: onComplete)
                    .buttonStyle(SecondaryCTAButtonStyle())
            }
        }
    }
}

private struct CoachNetworkPresenceCard: View {
    let profile: CoachProfile
    let groups: Int
    let unread: Int

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(profile.name)
                            .font(.headline)
                            .foregroundStyle(.white)
                        Text(profile.headline)
                            .font(.caption)
                            .foregroundStyle(MorpheTheme.textSecondary)
                    }
                    Spacer()
                    StatusBadge(text: profile.networkRank, color: MorpheTheme.accentAlt)
                }

                HStack(spacing: 8) {
                    MetricPill(label: "Clients", value: "\(profile.activeClients)")
                    MetricPill(label: "Groups", value: "\(groups)")
                    MetricPill(label: "Unread", value: "\(unread)")
                }
            }
        }
    }
}

private struct CoachNetworkHighlightsRail: View {
    @Environment(MorpheAppStore.self) private var store

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                StoryRingCard(symbol: "🧠", title: "Coach", subtitle: store.coachProfile.name) {
                    store.selectedCoachTab = .messages
                }

                ForEach(store.coachClients.prefix(4)) { athlete in
                    StoryRingCard(symbol: sportSymbol(for: athlete.sport), title: athlete.name, subtitle: athlete.statusText) {
                        store.openClientHub(athlete)
                        store.selectedCoachTab = .athletes
                    }
                }

                StoryRingCard(symbol: "👥", title: "Groups", subtitle: "\(store.teamGroups.count) active") {
                    store.selectedCoachTab = .messages
                }
            }
            .padding(.vertical, 4)
        }
    }

    private func sportSymbol(for sport: SportFocus) -> String {
        switch sport {
        case .boxing: return "🥊"
        case .soccer: return "⚽"
        case .basketball: return "🏀"
        case .running, .track: return "🏃"
        default: return "🔥"
        }
    }
}

private struct CoachPerformanceScreen: View {
    @Environment(MorpheAppStore.self) private var store

    private var focusedAthlete: CoachClient? {
        store.selectedCoachClient ?? store.filteredCoachClients.first ?? store.coachClients.first
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 16) {
                SectionTitleView(
                    title: "Performance",
                    subtitle: "Sport-specific testing, readiness, report cards, and coaching quality signals."
                )

                if let athlete = focusedAthlete {
                    CoachAthleteCard(athlete: athlete, onOpenHub: {
                        store.openClientHub(athlete)
                    }, onMessage: {
                        if let thread = store.messageThreads.first(where: { $0.participant == athlete.name }) {
                            store.selectedCoachTab = .messages
                            store.selectThread(thread)
                        }
                    })

                    SportTestingDashboardCard(tests: athlete.tests)
                    AthleteReportCardView(report: athlete.reportCard)
                    TrainingLoadCard(load: athlete.trainingLoad)
                    MovementQualityScoreCard(score: athlete.movementQuality)
                    EventPrepModeCard(plan: athlete.eventPrep)
                    VideoReviewHubCard(clips: athlete.videoReviews)
                }

                CoachQualityAnalyticsCard(analytics: store.coachAnalytics)
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 120)
        }
    }
}

private struct CoachMessagesScreen: View {
    @Environment(MorpheAppStore.self) private var store
    @State private var draftMessage = ""
    @State private var searchText = ""
    @State private var showAIAgentThread = false
    @State private var coachPraiseDraft: CoachPublicPraiseDraft?

    private var selectedThread: MessageThread? {
        store.selectedThread
    }

    private var filteredAthleteThreads: [MessageThread] {
        filteredThreads.filter { !$0.isGroupChat && !$0.participant.hasPrefix("Coach ") }
    }

    private var filteredCoachThreads: [MessageThread] {
        filteredThreads.filter { !$0.isGroupChat && $0.participant.hasPrefix("Coach ") }
    }

    private var filteredGroupThreads: [MessageThread] {
        filteredThreads.filter(\.isGroupChat)
    }

    private var filteredThreads: [MessageThread] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let sortedThreads = store.messageThreads.sorted { lhs, rhs in
            threadPriority(for: lhs) > threadPriority(for: rhs)
        }
        guard !query.isEmpty else { return sortedThreads }
        return sortedThreads.filter { thread in
            thread.participant.lowercased().contains(query)
                || thread.preview.lowercased().contains(query)
                || thread.sport.rawValue.lowercased().contains(query)
                || threadContextDetail(for: thread).lowercased().contains(query)
        }
    }

    private var showsAIContact: Bool {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !query.isEmpty else { return true }

        return "morphe ai".contains(query)
            || (store.coachAIAgentConversation.last?.text.lowercased().contains(query) ?? false)
            || coachAIContextDetail.lowercased().contains(query)
            || (coachAIContextBadge?.lowercased().contains(query) ?? false)
    }

    private var contactCount: Int {
        filteredThreads.count + (showsAIContact ? 1 : 0)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionTitleView(
                title: "Inbox",
                subtitle: "Athletes, coach peers, group chats, and Morphe AI stay in one clean contact list."
            )
            .padding(.horizontal, 20)

            Group {
                if showAIAgentThread {
                    coachAIConversationView
                } else if let thread = selectedThread {
                    coachConversationView(thread: thread)
                } else {
                    coachThreadListView
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .padding(.top, 8)
        .padding(.bottom, 120)
        .onChange(of: store.selectedThreadID) { _, newValue in
            if newValue != nil {
                showAIAgentThread = false
            }
            if let seed = store.coachThreadDraftSeed, newValue != nil {
                draftMessage = seed
                store.coachThreadDraftSeed = nil
            }
        }
        .onChange(of: store.coachThreadDraftSeed) { _, newValue in
            if let newValue, store.selectedThreadID != nil {
                draftMessage = newValue
                store.coachThreadDraftSeed = nil
            }
        }
        .sheet(item: $coachPraiseDraft) { draft in
            CoachPublicPraiseSheet(draft: draft)
                .environment(store)
        }
    }

    private var coachThreadListView: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top, spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Messages")
                            .font(.title3.weight(.bold))
                            .foregroundStyle(.white)
                        Text("Athletes, coaches, group chats, and Morphe AI all live here like one clean contact list.")
                            .font(.subheadline)
                            .foregroundStyle(MorpheTheme.textSecondary)
                    }

                    Spacer()
                }

                TextField("Search athlete, coach note, or group chat", text: $searchText)
                    .textFieldStyle(MorpheFieldStyle())

                Text("\(contactCount) contacts")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(MorpheTheme.textMuted)
            }
            .padding(16)

            Divider()
                .overlay(MorpheTheme.stroke.opacity(0.8))

            ScrollView(showsIndicators: false) {
                LazyVStack(spacing: 0) {
                    if showsAIContact {
                        Button {
                            store.selectedThreadID = nil
                            showAIAgentThread = true
                        } label: {
                            CoachAIContactListRow(
                                unreadCount: max(store.coachAIAgentConversation.count - 1, 0),
                                preview: store.coachAIAgentConversation.last?.text ?? "Open Morphe AI",
                                contextBadge: coachAIContextBadge,
                                contextDetail: coachAIContextDetail
                            )
                        }
                        .buttonStyle(.plain)
                    }

                    if showsAIContact && !filteredThreads.isEmpty {
                        Divider()
                            .overlay(MorpheTheme.stroke.opacity(0.5))
                            .padding(.leading, 72)
                    }

                    ForEach(Array(filteredThreads.enumerated()), id: \.element.id) { index, thread in
                        Button {
                            showAIAgentThread = false
                            store.selectThread(thread)
                        } label: {
                            CoachContactListRow(
                                thread: thread,
                                avatar: coachThreadAvatar(for: thread),
                                contextBadge: threadContextBadge(for: thread),
                                contextDetail: threadContextDetail(for: thread)
                            )
                        }
                        .buttonStyle(.plain)

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

    private func coachThreadSection(title: String, threads: [MessageThread]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(MorpheTheme.textMuted)

            ForEach(threads) { thread in
                Button {
                    showAIAgentThread = false
                    store.selectThread(thread)
                } label: {
                    CoachInboxThreadRow(
                        thread: thread,
                        contextBadge: threadContextBadge(for: thread),
                        contextDetail: threadContextDetail(for: thread)
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func coachConversationView(thread: MessageThread) -> some View {
        let athlete = athleteForThread(thread)

        return VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 12) {
                Button {
                    store.selectedThreadID = nil
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

                Circle()
                    .fill(MorpheTheme.panelStrong)
                    .frame(width: 42, height: 42)
                    .overlay(
                        Text(thread.isGroupChat ? "👥" : String(thread.sport.shortTitle.prefix(1)))
                            .foregroundStyle(.white)
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

                StatusBadge(text: thread.isGroupChat ? "Group" : "1:1", color: thread.isGroupChat ? MorpheTheme.warning : MorpheTheme.accent)

                if let athlete {
                    Button("Praise") {
                        coachPraiseDraft = store.makeCoachPraiseDraft(for: athlete.id)
                    }
                    .buttonStyle(SecondaryCTAButtonStyle())
                    .frame(width: 96)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)

            if let athlete {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(CoachOutreachShortcut.allCases) { shortcut in
                            Button {
                                store.openCoachOutreachShortcut(shortcut, for: athlete.id)
                            } label: {
                                HStack(spacing: 8) {
                                    Image(systemName: shortcut.systemImage)
                                        .font(.caption.weight(.semibold))
                                    Text(shortcut.rawValue)
                                        .font(.caption.weight(.semibold))
                                        .lineLimit(1)
                                }
                                .foregroundStyle(.white)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 10)
                                .background(
                                    RoundedRectangle(cornerRadius: MorpheTheme.radius, style: .continuous)
                                        .fill(MorpheTheme.panelRaised)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: MorpheTheme.radius, style: .continuous)
                                                .stroke(MorpheTheme.strokeStrong.opacity(0.22), lineWidth: 1)
                                        )
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 14)
                }
            }

            Divider()
                .overlay(MorpheTheme.stroke.opacity(0.8))

            VStack(spacing: 0) {
                ScrollView(showsIndicators: false) {
                    LazyVStack(alignment: .leading, spacing: 12) {
                        ForEach(thread.messages) { message in
                            CoachMessageRow(message: message)
                        }
                    }
                    .padding(16)
                    .padding(.bottom, 8)
                }

                Divider()
                    .overlay(MorpheTheme.stroke.opacity(0.8))

                HStack(spacing: 10) {
                    TextField("Type a message", text: $draftMessage, axis: .vertical)
                        .lineLimit(1...3)
                        .textFieldStyle(MorpheFieldStyle())

                    Button("Send") {
                        store.sendCoachThreadMessage(draftMessage)
                        draftMessage = ""
                    }
                    .buttonStyle(PrimaryCTAButtonStyle(accent: MorpheTheme.accent))
                    .frame(width: 84)
                }
                .padding(16)
            }
        }
    }

    private func coachThreadAvatar(for thread: MessageThread) -> String {
        if thread.isGroupChat {
            return "👥"
        }
        if thread.participant.hasPrefix("Coach ") {
            return "🧠"
        }

        switch thread.sport {
        case .boxing: return "🥊"
        case .soccer: return "⚽"
        case .basketball: return "🏀"
        case .running, .track: return "🏃"
        case .strength: return "🏋️"
        case .weightLoss: return "🔥"
        default: return "💬"
        }
    }

    private var coachAISection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Morphe AI")
                .font(.caption.weight(.semibold))
                .foregroundStyle(MorpheTheme.textMuted)

            Button {
                store.selectedThreadID = nil
                showAIAgentThread = true
            } label: {
                CoachAIContactRow(
                    unreadCount: max(store.coachAIAgentConversation.count - 1, 0),
                    preview: store.coachAIAgentConversation.last?.text ?? "Open Morphe AI",
                    contextBadge: coachAIContextBadge,
                    contextDetail: coachAIContextDetail
                )
            }
            .buttonStyle(.plain)
        }
    }

    private var coachAIContextBadge: String? {
        let pendingCount = store.coachClients.reduce(into: 0) { result, athlete in
            result += store.workoutLogs(for: athlete.id).filter { $0.verificationStatus == .aiPendingReview }.count
        }

        if pendingCount > 0 {
            return "AI review"
        }
        if store.coachOverview.checkInsNeeded > 0 {
            return "Coach summary"
        }
        return "AI ready"
    }

    private var coachAIContextDetail: String {
        let pendingCount = store.coachClients.reduce(into: 0) { result, athlete in
            result += store.workoutLogs(for: athlete.id).filter { $0.verificationStatus == .aiPendingReview }.count
        }

        if pendingCount > 0 {
            return "\(pendingCount) AI-imported workout \(pendingCount == 1 ? "log needs" : "logs need") coach review."
        }
        if store.coachOverview.checkInsNeeded > 0 {
            return "Use Morphe AI to summarize who needs attention and draft clean outreach quickly."
        }
        return "Ask Morphe quick training questions and workspace how-tos while you coach."
    }

    private func threadPriority(for thread: MessageThread) -> Int {
        var score = 0

        if thread.isUnread { score += 40 }

        if let athlete = athleteForThread(thread) {
            let logs = store.workoutLogs(for: athlete.id)
            let pendingAIReviewCount = logs.filter { $0.verificationStatus == .aiPendingReview }.count
            let athleteSubmittedThisWeek = logs.filter {
                $0.enteredByRole == .client && Calendar.current.isDate($0.completedAt, equalTo: .now, toGranularity: .weekOfYear)
            }.count

            if store.coachInterventions.contains(where: { $0.athleteID == athlete.id }) {
                score += 100
            }
            if pendingAIReviewCount > 0 {
                score += 80
            }
            if upcomingSessionForAthlete(athlete) != nil {
                score += 70
            }
            if athleteSubmittedThisWeek == 0 {
                score += 60
            }
            if athlete.risk == .high {
                score += 50
            }
        } else if thread.isGroupChat {
            score += 20
        } else if thread.participant.hasPrefix("Coach ") {
            score += 12
        }

        return score
    }

    private func threadContextBadge(for thread: MessageThread) -> String? {
        if let athlete = athleteForThread(thread) {
            let logs = store.workoutLogs(for: athlete.id)
            let pendingAIReviewCount = logs.filter { $0.verificationStatus == .aiPendingReview }.count
            let athleteSubmittedThisWeek = logs.filter {
                $0.enteredByRole == .client && Calendar.current.isDate($0.completedAt, equalTo: .now, toGranularity: .weekOfYear)
            }.count

            if store.coachInterventions.contains(where: { $0.athleteID == athlete.id }) {
                return "Needs attention"
            }
            if pendingAIReviewCount > 0 {
                return "AI review"
            }
            if upcomingSessionForAthlete(athlete) != nil {
                return "Session today"
            }
            if athleteSubmittedThisWeek == 0 {
                return "No athlete log"
            }
            if store.partnerTrainingInsight(for: athlete.id).buddyShareLast30Days >= 30 {
                return "Buddy adherence"
            }
            if thread.isUnread {
                return "Unread"
            }
            return "Athlete update"
        }

        if thread.isGroupChat {
            return thread.isUnread ? "Group update" : "Group thread"
        }
        if thread.participant.hasPrefix("Coach ") {
            return thread.isUnread ? "Coach reply" : "Coach peer"
        }

        return thread.isUnread ? "Unread" : nil
    }

    private func threadContextDetail(for thread: MessageThread) -> String {
        if let athlete = athleteForThread(thread) {
            let logs = store.workoutLogs(for: athlete.id)
            let pendingAIReviewCount = logs.filter { $0.verificationStatus == .aiPendingReview }.count
            let athleteSubmittedThisWeek = logs.filter {
                $0.enteredByRole == .client && Calendar.current.isDate($0.completedAt, equalTo: .now, toGranularity: .weekOfYear)
            }.count

            if let intervention = store.coachInterventions.first(where: { $0.athleteID == athlete.id }) {
                return "\(intervention.reason) • \(intervention.suggestedAction)"
            }
            if pendingAIReviewCount > 0 {
                return "\(pendingAIReviewCount) AI-imported workout \(pendingAIReviewCount == 1 ? "log still needs" : "logs still need") review."
            }
            if let session = upcomingSessionForAthlete(athlete) {
                return "\(session.title) • \(session.day) at \(session.time)"
            }
            if athleteSubmittedThisWeek == 0 {
                return "No self-logged workout from \(athlete.name) yet this week."
            }

            let partnerInsight = store.partnerTrainingInsight(for: athlete.id)
            if partnerInsight.buddyShareLast30Days >= 30 {
                return partnerInsight.coachSummary
            }

            return thread.preview
        }

        if thread.isGroupChat {
            return "Use group chats for reminders, shared session timing, and momentum."
        }
        if thread.participant.hasPrefix("Coach ") {
            return "Keep peer context close for programming ideas, onboarding, and operations."
        }

        return thread.preview
    }

    private func athleteForThread(_ thread: MessageThread) -> CoachClient? {
        store.coachClients.first(where: { $0.name == thread.participant })
    }

    private func upcomingSessionForAthlete(_ athlete: CoachClient) -> CalendarEvent? {
        store.upcomingSessions.first { event in
            event.athleteID == athlete.id && !event.isComplete
        }
    }

    private var coachAIConversationView: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 12) {
                Button {
                    showAIAgentThread = false
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

                Circle()
                    .fill(MorpheTheme.panelStrong)
                    .frame(width: 42, height: 42)
                    .overlay(
                        Image(systemName: "sparkles")
                            .foregroundStyle(.white)
                    )

                VStack(alignment: .leading, spacing: 4) {
                    Text("Morphe AI")
                        .font(.headline)
                        .foregroundStyle(.white)
                    Text("Coach assistant")
                        .font(.caption)
                        .foregroundStyle(MorpheTheme.textSecondary)
                }

                Spacer()

                StatusBadge(text: "AI", color: MorpheTheme.accentAlt)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)

            Divider()
                .overlay(MorpheTheme.stroke.opacity(0.8))

            VStack(spacing: 0) {
                ScrollView(showsIndicators: false) {
                    LazyVStack(alignment: .leading, spacing: 12) {
                        ForEach(store.coachAIAgentConversation) { message in
                            CoachMessageRow(message: message)
                        }
                    }
                    .padding(16)
                    .padding(.bottom, 8)
                }

                Divider()
                    .overlay(MorpheTheme.stroke.opacity(0.8))

                HStack(spacing: 10) {
                    TextField("Ask Morphe AI", text: $draftMessage, axis: .vertical)
                        .lineLimit(1...3)
                        .textFieldStyle(MorpheFieldStyle())

                    Button("Send") {
                        store.sendAIAgentPrompt(draftMessage)
                        draftMessage = ""
                    }
                    .buttonStyle(PrimaryCTAButtonStyle(accent: MorpheTheme.accent))
                    .frame(width: 84)
                }
                .padding(16)
            }
        }
    }
}

private struct CoachInboxThreadRow: View {
    let thread: MessageThread
    let contextBadge: String?
    let contextDetail: String

    private var lastTimestamp: String {
        thread.messages.last?.timestamp ?? "Now"
    }

    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(MorpheTheme.panelStrong)
                .frame(width: 46, height: 46)
                .overlay(
                    Text(thread.isGroupChat ? "👥" : String(thread.sport.shortTitle.prefix(1)))
                        .foregroundStyle(.white)
                )

            VStack(alignment: .leading, spacing: 4) {
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

                if let contextBadge {
                    HStack(spacing: 6) {
                        StatusBadge(text: contextBadge, color: thread.isGroupChat ? MorpheTheme.warning : MorpheTheme.accentAlt)
                        Text(thread.preview)
                            .font(.caption)
                            .foregroundStyle(MorpheTheme.textSecondary)
                            .lineLimit(1)
                    }
                } else {
                    Text(thread.preview)
                        .font(.caption)
                        .foregroundStyle(MorpheTheme.textSecondary)
                        .lineLimit(1)
                }

                Text(contextDetail)
                    .font(.caption2)
                    .foregroundStyle(MorpheTheme.textMuted)
                    .lineLimit(2)
            }
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }
}

private struct CoachContactListRow: View {
    let thread: MessageThread
    let avatar: String
    let contextBadge: String?
    let contextDetail: String

    private var lastTimestamp: String {
        thread.messages.last?.timestamp ?? "Now"
    }

    private var secondaryLine: String {
        if let contextBadge {
            return "\(contextBadge) • \(thread.preview)"
        }
        return thread.preview
    }

    var body: some View {
        HStack(spacing: 12) {
            Text(avatar)
                .font(.title2)
                .frame(width: 44, height: 44)
                .background(
                    Circle()
                        .fill(MorpheTheme.panelStrong)
                )

            VStack(alignment: .leading, spacing: 4) {
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

                Text(secondaryLine)
                    .font(.caption)
                    .foregroundStyle(MorpheTheme.textSecondary)
                    .lineLimit(2)

                Text(contextDetail)
                    .font(.caption2)
                    .foregroundStyle(MorpheTheme.textMuted)
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .contentShape(Rectangle())
    }
}

private struct CoachAIContactRow: View {
    let unreadCount: Int
    let preview: String
    let contextBadge: String?
    let contextDetail: String

    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(MorpheTheme.panelStrong)
                .frame(width: 46, height: 46)
                .overlay(
                    Image(systemName: "sparkles")
                        .foregroundStyle(.white)
                )

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Morphe AI")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                    Spacer()
                    if unreadCount > 0 {
                        Circle()
                            .fill(MorpheTheme.accent)
                            .frame(width: 8, height: 8)
                    }
                }

                if let contextBadge {
                    HStack(spacing: 6) {
                        StatusBadge(text: contextBadge, color: MorpheTheme.accentAlt)
                        Text(preview)
                            .font(.caption)
                            .foregroundStyle(MorpheTheme.textSecondary)
                            .lineLimit(1)
                    }
                } else {
                    Text(preview)
                        .font(.caption)
                        .foregroundStyle(MorpheTheme.textSecondary)
                        .lineLimit(1)
                }

                Text(contextDetail)
                    .font(.caption2)
                    .foregroundStyle(MorpheTheme.textMuted)
                    .lineLimit(2)
            }
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }
}

private struct CoachAIContactListRow: View {
    let unreadCount: Int
    let preview: String
    let contextBadge: String?
    let contextDetail: String

    private var secondaryLine: String {
        if let contextBadge {
            return "\(contextBadge) • \(preview)"
        }
        return preview
    }

    var body: some View {
        HStack(spacing: 12) {
            Text("✨")
                .font(.title2)
                .frame(width: 44, height: 44)
                .background(
                    Circle()
                        .fill(MorpheTheme.panelStrong)
                )

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Morphe AI")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                    Spacer()
                    Text("Now")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(MorpheTheme.textMuted)
                    if unreadCount > 0 {
                        Circle()
                            .fill(MorpheTheme.accent)
                            .frame(width: 8, height: 8)
                    }
                }

                Text(secondaryLine)
                    .font(.caption)
                    .foregroundStyle(MorpheTheme.textSecondary)
                    .lineLimit(2)

                Text(contextDetail)
                    .font(.caption2)
                    .foregroundStyle(MorpheTheme.textMuted)
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .contentShape(Rectangle())
    }
}

private enum CoachNetworkSection: String, CaseIterable, Identifiable {
    case forYou = "For You"
    case athletes = "Athletes"
    case coaches = "Coaches"
    case grow = "Grow"

    var id: String { rawValue }
}

private struct CoachDashboardTriageCard: View {
    let coachName: String
    let atRiskCount: Int
    let pendingAIReviewCount: Int
    let painFlagCount: Int
    let replyQueueCount: Int
    let nextSession: CalendarEvent?
    let nextIntervention: CoachIntervention?
    let showsRecoveryAction: Bool
    let onReviewAI: () -> Void
    let onMessageAthlete: () -> Void
    let onStartSession: () -> Void
    let onAssignRecovery: () -> Void

    private var headline: String {
        if let nextIntervention {
            return "\(nextIntervention.athleteName) is the first friction point today."
        }
        if let nextSession {
            return "Your next live coaching moment is \(nextSession.title)."
        }
        if pendingAIReviewCount > 0 {
            return "AI review is the fastest way to clear the board right now."
        }
        return "The board is calm. Keep the next coaching move simple and fast."
    }

    private var supportLine: String {
        if let nextIntervention {
            return "\(nextIntervention.reason) • \(nextIntervention.suggestedAction)"
        }
        if let nextSession {
            return "\(nextSession.day) at \(nextSession.time) • \(nextSession.detail)"
        }
        if replyQueueCount > 0 {
            return "\(replyQueueCount) message\(replyQueueCount == 1 ? "" : "s") still need a clean response."
        }
        return "\(coachName), the urgent work is under control. Use the rest of the board for broader scan and planning."
    }

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text("Start Here")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(MorpheTheme.textMuted)
                        Text(headline)
                            .font(.title3.weight(.bold))
                            .foregroundStyle(.white)
                        Text(supportLine)
                            .font(.subheadline)
                            .foregroundStyle(MorpheTheme.textSecondary)
                    }

                    Spacer()

                    StatusBadge(
                        text: atRiskCount > 0 ? "\(atRiskCount) need you" : "Board clear",
                        color: atRiskCount > 0 ? MorpheTheme.warning : MorpheTheme.accent
                    )
                }

                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 2), spacing: 8) {
                    CoachTriageStatPill(label: "Needs attention", value: "\(atRiskCount)")
                    // Pain flags are real data today; "AI reviews" advertised
                    // an import workflow that doesn't exist yet.
                    CoachTriageStatPill(label: "Pain flags", value: "\(painFlagCount)")
                    CoachTriageStatPill(label: "Reply queue", value: "\(replyQueueCount)")
                    CoachTriageStatPill(label: "Next session", value: nextSession.map { "\($0.day) \($0.time)" } ?? "No live block")
                }

                VStack(spacing: 8) {
                    CoachTriageActionButton(
                        title: pendingAIReviewCount > 0 ? "Review AI logs" : "Open Messages",
                        subtitle: pendingAIReviewCount > 0
                            ? "Clear imported workout reviews before the queue gets noisy."
                            : "Use the inbox for the next clean follow-up.",
                        accent: pendingAIReviewCount > 0 ? MorpheTheme.accent : MorpheTheme.accentAlt,
                        action: pendingAIReviewCount > 0 ? onReviewAI : onMessageAthlete
                    )

                    if nextSession != nil {
                        CoachTriageActionButton(
                            title: "Start next session",
                            subtitle: "Jump straight into the next live coaching block from here.",
                            accent: MorpheTheme.accent,
                            action: onStartSession
                        )
                    } else if nextIntervention != nil {
                        CoachTriageActionButton(
                            title: "Message athlete",
                            subtitle: "Move straight into the thread that needs a fast response.",
                            accent: MorpheTheme.accent,
                            action: onMessageAthlete
                        )
                    }

                    if showsRecoveryAction {
                        CoachTriageActionButton(
                            title: "Assign recovery",
                            subtitle: "Use a lighter reset session when the issue is pain, fatigue, or overload.",
                            accent: MorpheTheme.warning,
                            action: onAssignRecovery
                        )
                    }
                }
            }
        }
    }
}

private struct CoachTriageStatPill: View {
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.caption.weight(.semibold))
                .foregroundStyle(MorpheTheme.textMuted)
            Text(value)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white)
                .lineLimit(2)
                .minimumScaleFactor(0.9)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: MorpheTheme.radius, style: .continuous)
                .fill(MorpheTheme.panelStrong)
        )
    }
}

private struct CoachTriageActionButton: View {
    let title: String
    let subtitle: String
    let accent: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(MorpheTheme.textSecondary)
                        .multilineTextAlignment(.leading)
                }

                Spacer()

                Image(systemName: "arrow.up.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.white)
                    .frame(width: 30, height: 30)
                    .background(
                        RoundedRectangle(cornerRadius: MorpheTheme.radius, style: .continuous)
                            .fill(accent.opacity(0.9))
                    )
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: MorpheTheme.radius, style: .continuous)
                    .fill(MorpheTheme.panelStrong)
                    .overlay(
                        RoundedRectangle(cornerRadius: MorpheTheme.radius, style: .continuous)
                            .stroke(accent.opacity(0.2), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

private struct CoachFollowUpQueueCard: View {
    let recommendations: [CoachFollowUpRecommendation]
    let onOpenAthlete: (CoachFollowUpRecommendation) -> Void
    let onRunAction: (CoachFollowUpRecommendation) -> Void

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("Recommended Follow-Ups")
                    .font(.headline)
                    .foregroundStyle(.white)

                Text("These are the cleanest next coaching moves based on recent logs, adherence, readiness, and partner behavior.")
                    .font(.subheadline)
                    .foregroundStyle(MorpheTheme.textSecondary)

                ForEach(recommendations) { recommendation in
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(alignment: .top, spacing: 10) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(recommendation.athleteName)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(.white)
                                Text(recommendation.title)
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(MorpheTheme.accentAlt)
                            }

                            Spacer()

                            StatusBadge(
                                text: recommendation.priority >= 90 ? "Now" : "Next",
                                color: recommendation.priority >= 90 ? MorpheTheme.warning : MorpheTheme.accent
                            )
                        }

                        Text(recommendation.detail)
                            .font(.caption)
                            .foregroundStyle(MorpheTheme.textSecondary)

                        HStack(spacing: 10) {
                            Button("Open Athlete") {
                                onOpenAthlete(recommendation)
                            }
                            .buttonStyle(SecondaryCTAButtonStyle())

                            Button(recommendation.actionLabel) {
                                onRunAction(recommendation)
                            }
                            .buttonStyle(PrimaryCTAButtonStyle(accent: MorpheTheme.accent))
                        }
                    }

                    if recommendation.id != recommendations.last?.id {
                        Divider()
                            .overlay(MorpheTheme.stroke.opacity(0.5))
                    }
                }
            }
        }
    }
}

private struct CoachHeroSummaryCard: View {
    let profile: CoachProfile
    let overview: CoachOverview

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(profile.name)
                            .font(.title3.weight(.bold))
                            .foregroundStyle(.white)
                        Text(profile.specialty)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(MorpheTheme.accentAlt)
                        Text("Groups: \(profile.groups.joined(separator: " • "))")
                            .font(.caption)
                            .foregroundStyle(MorpheTheme.textSecondary)
                    }

                    Spacer()

                    StatusBadge(text: "\(profile.activeClients) active", color: MorpheTheme.accent)
                }

                Text(overview.insight.summary)
                    .foregroundStyle(.white)
                Text(overview.insight.recommendation)
                    .font(.subheadline)
                    .foregroundStyle(MorpheTheme.textSecondary)
                Text(overview.weeklySummary)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(MorpheTheme.accent)
            }
        }
    }
}

private struct CoachMetricCard: View {
    let title: String
    let value: String

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 10) {
                Text(title)
                    .font(.subheadline)
                    .foregroundStyle(MorpheTheme.textSecondary)
                Text(value)
                    .font(.system(.title, design: .rounded).weight(.bold))
                    .foregroundStyle(.white)
            }
            .frame(width: 170, alignment: .leading)
        }
    }
}

private struct MultiSportCoachFilter: View {
    let selected: SportFocus?
    let sports: [SportFocus]
    let onSelect: (SportFocus?) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                Button("All Sports") {
                    onSelect(nil)
                }
                .buttonStyle(FilterChipStyle(isSelected: selected == nil))

                ForEach(sports) { sport in
                    Button(sport.shortTitle) {
                        onSelect(sport)
                    }
                    .buttonStyle(FilterChipStyle(isSelected: selected == sport, selectedColor: MorpheTheme.color(for: sport)))
                }
            }
        }
    }
}

private struct CoachInterventionQueueCard: View {
    @Environment(MorpheAppStore.self) private var store
    let interventions: [CoachIntervention]
    @State private var selectedInterventionForMessage: CoachIntervention?
    @State private var selectedInterventionForAssignment: CoachIntervention?

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("Coach Intervention Queue")
                    .font(.headline)
                    .foregroundStyle(.white)

                ForEach(interventions) { intervention in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text(intervention.athleteName)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.white)
                            Spacer()
                            StatusBadge(text: intervention.riskLevel.rawValue, color: MorpheTheme.color(for: intervention.riskLevel))
                        }

                        Text(intervention.reason)
                            .font(.caption)
                            .foregroundStyle(MorpheTheme.textSecondary)
                        Text("Suggested action: \(intervention.suggestedAction)")
                            .font(.caption)
                            .foregroundStyle(MorpheTheme.textPrimary)

                        HStack(spacing: 10) {
                            Button(intervention.status == "Handled" ? "Message Sent" : "Message") {
                                selectedInterventionForMessage = intervention
                            }
                            .buttonStyle(PrimaryCTAButtonStyle(accent: intervention.status == "Handled" ? MorpheTheme.accentAlt : MorpheTheme.accent))

                            Button("Assign Plan") {
                                selectedInterventionForAssignment = intervention
                            }
                            .buttonStyle(SecondaryCTAButtonStyle())

                            Button("Review") {
                                store.reviewIntervention(intervention)
                            }
                            .buttonStyle(SecondaryCTAButtonStyle())
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .sheet(item: $selectedInterventionForMessage) { intervention in
            InterventionTemplateSheet(intervention: intervention)
                .environment(store)
        }
        .sheet(item: $selectedInterventionForAssignment) { intervention in
            InterventionAssignSheet(intervention: intervention)
                .environment(store)
        }
    }
}

private struct AthleteReadinessDashboardCard: View {
    let athletes: [CoachClient]

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("Athlete Readiness Dashboard")
                    .font(.headline)
                    .foregroundStyle(.white)

                ForEach(athletes) { athlete in
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(athlete.name)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.white)
                            Text(athlete.recoveryScore.reason)
                                .font(.caption)
                                .foregroundStyle(MorpheTheme.textSecondary)
                        }
                        Spacer()
                        StatusBadge(text: athlete.recoveryScore.status.rawValue, color: MorpheTheme.color(for: athlete.recoveryScore.status))
                    }
                }
            }
        }
    }
}

private struct CoachBulletCard: View {
    let title: String
    let items: [String]

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(.white)

                ForEach(items, id: \.self) { item in
                    Text("- \(item)")
                        .foregroundStyle(MorpheTheme.textPrimary)
                }
            }
        }
    }
}

private struct CoachAthleteCard: View {
    let athlete: CoachClient
    let onOpenHub: () -> Void
    let onMessage: () -> Void

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(athlete.name)
                            .font(.headline)
                            .foregroundStyle(.white)
                        Text("\(athlete.sport.rawValue) - \(athlete.goal)")
                            .font(.subheadline)
                            .foregroundStyle(MorpheTheme.textSecondary)
                    }
                    Spacer()
                    StatusBadge(text: athlete.statusText, color: MorpheTheme.color(for: athlete.risk))
                }

                HStack(spacing: 8) {
                    MetricPill(label: "Recovery", value: "\(athlete.recoveryScore.score)")
                    MetricPill(label: "Compliance", value: "\(athlete.complianceScore)%")
                    MetricPill(label: "Last", value: athlete.lastWorkout)
                }

                Text(athlete.aiSummary)
                    .font(.subheadline)
                    .foregroundStyle(MorpheTheme.textPrimary)

                HStack(spacing: 10) {
                    Button("Open Profile", action: onOpenHub)
                        .buttonStyle(PrimaryCTAButtonStyle(accent: MorpheTheme.accentAlt))

                    Button("Quick Message", action: onMessage)
                        .buttonStyle(SecondaryCTAButtonStyle())
                }
            }
        }
    }
}

private struct CoachMessageRow: View {
    let message: ThreadMessage

    var body: some View {
        VStack(alignment: message.sender == .coach ? .trailing : .leading, spacing: 4) {
            Text(message.senderName)
                .font(.caption.weight(.semibold))
                .foregroundStyle(MorpheTheme.textMuted)

            Text(message.text)
                .font(.subheadline)
                .foregroundStyle(.white)
                .padding(12)
                .frame(maxWidth: .infinity, alignment: message.sender == .coach ? .trailing : .leading)
                .background(
                    RoundedRectangle(cornerRadius: MorpheTheme.radius, style: .continuous)
                        .fill(message.sender == .coach ? MorpheTheme.accentAlt.opacity(0.28) : MorpheTheme.panelStrong)
                )
        }
    }
}

private struct SportTestingDashboardCard: View {
    let tests: [PerformanceTest]

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("Sport Testing Dashboard")
                    .font(.headline)
                    .foregroundStyle(.white)

                ForEach(tests) { test in
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(test.name)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.white)
                            Text(test.category)
                                .font(.caption)
                                .foregroundStyle(MorpheTheme.textSecondary)
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 4) {
                            Text("\(test.result) \(test.unit)")
                                .foregroundStyle(.white)
                            Text("Prev \(test.previousResult)")
                                .font(.caption)
                                .foregroundStyle(MorpheTheme.textSecondary)
                        }
                    }
                }
            }
        }
    }
}

private struct CoachPlaybookCard: View {
    let playbook: CoachPlaybook

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(playbook.title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white)
            Text(playbook.philosophy)
                .font(.caption)
                .foregroundStyle(MorpheTheme.textSecondary)
            Text("Warm-ups: \(playbook.warmUps.joined(separator: ", "))")
                .font(.caption)
                .foregroundStyle(MorpheTheme.textPrimary)
            Text("Templates: \(playbook.templates.joined(separator: ", "))")
                .font(.caption)
                .foregroundStyle(MorpheTheme.textPrimary)
        }
        .padding(.vertical, 4)
    }
}

private struct CoachOutreachCRMCard: View {
    let leads: [LeadRecord]
    let onAdvance: (LeadRecord) -> Void

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("Coach Outreach CRM")
                    .font(.headline)
                    .foregroundStyle(.white)

                ForEach(leads) { lead in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text(lead.name)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.white)
                            Spacer()
                            StatusBadge(text: lead.status.rawValue, color: MorpheTheme.accentAlt)
                        }
                        Text(lead.note)
                            .font(.caption)
                            .foregroundStyle(MorpheTheme.textSecondary)
                        Text(lead.aiSuggestion)
                            .font(.caption)
                            .foregroundStyle(MorpheTheme.textPrimary)
                        Button("Advance Status") {
                            onAdvance(lead)
                        }
                        .buttonStyle(SecondaryCTAButtonStyle())
                    }
                    .padding(.vertical, 4)
                }
            }
        }
    }
}

private struct TeamGroupCoachingCard: View {
    let groups: [TeamGroup]
    let onSendAnnouncement: (TeamGroup) -> Void

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("Team / Group Coaching")
                    .font(.headline)
                    .foregroundStyle(.white)

                ForEach(groups) { group in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text(group.name)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.white)
                            Spacer()
                            MetricPill(label: "Avg readiness", value: "\(group.readinessAverage)")
                        }
                        Text(group.programName)
                            .font(.caption)
                            .foregroundStyle(MorpheTheme.textSecondary)
                        Text("Leaderboard: \(group.leaderboard.joined(separator: " | "))")
                            .font(.caption)
                            .foregroundStyle(MorpheTheme.textPrimary)
                        Text(group.groupMessage)
                            .font(.caption)
                            .foregroundStyle(MorpheTheme.textSecondary)
                        Button("Send Group Announcement") {
                            onSendAnnouncement(group)
                        }
                        .buttonStyle(PrimaryCTAButtonStyle(accent: MorpheTheme.accent))
                    }
                    .padding(.vertical, 4)
                }
            }
        }
    }
}

private struct AttendanceTrackerCard: View {
    let group: TeamGroup
    let onUpdate: (String, AttendanceStatus) -> Void

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("Attendance + Session Check-in")
                    .font(.headline)
                    .foregroundStyle(.white)
                Text("\(group.name) - \(group.programName)")
                    .font(.subheadline)
                    .foregroundStyle(MorpheTheme.textSecondary)

                ForEach(group.attendance) { member in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text(member.athleteName)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.white)
                            Spacer()
                            StatusBadge(text: member.status.rawValue, color: MorpheTheme.accentAlt)
                        }
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(AttendanceStatus.allCases) { status in
                                    Button(status.rawValue) {
                                        onUpdate(member.athleteName, status)
                                    }
                                    .buttonStyle(FilterChipStyle(isSelected: member.status == status, selectedColor: MorpheTheme.accent))
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}

private struct VideoReviewHubCard: View {
    let clips: [VideoReviewClip]

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("Video Review Hub")
                    .font(.headline)
                    .foregroundStyle(.white)

                ForEach(clips) { clip in
                    VStack(alignment: .leading, spacing: 10) {
                        RoundedRectangle(cornerRadius: MorpheTheme.radius, style: .continuous)
                            .fill(MorpheTheme.panelStrong)
                            .overlay(
                                VStack(spacing: 8) {
                                    Image(systemName: "play.rectangle")
                                        .foregroundStyle(.white)
                                    Text(clip.thumbnail)
                                        .font(.caption)
                                        .foregroundStyle(MorpheTheme.textSecondary)
                                }
                            )
                            .frame(height: 120)

                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(clip.title)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(.white)
                                Text("\(clip.sport.rawValue) - \(clip.date)")
                                    .font(.caption)
                                    .foregroundStyle(MorpheTheme.textSecondary)
                            }
                            Spacer()
                            MetricPill(label: "MQ", value: "\(clip.movementQualityScore)")
                        }

                        ForEach(clip.timestampComments) { comment in
                            Text("\(comment.time) - \(comment.note)")
                                .font(.caption)
                                .foregroundStyle(MorpheTheme.textPrimary)
                        }

                        Text(clip.aiFeedback)
                            .font(.caption)
                            .foregroundStyle(MorpheTheme.textSecondary)
                    }
                    .padding(.vertical, 4)
                }
            }
        }
    }
}

private struct SkillDrillCard: View {
    let drill: DrillReference

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(drill.name)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                Spacer()
                StatusBadge(text: drill.sport.shortTitle, color: MorpheTheme.color(for: drill.sport))
            }
            Text("\(drill.skillCategory) - \(drill.equipment) - \(drill.difficulty.rawValue)")
                .font(.caption)
                .foregroundStyle(MorpheTheme.textSecondary)
            Text("Cue: \(drill.cues)")
                .font(.caption)
                .foregroundStyle(MorpheTheme.textPrimary)
            Text("Common mistake: \(drill.commonMistakes)")
                .font(.caption)
                .foregroundStyle(MorpheTheme.textSecondary)
            Text("Progression: \(drill.progression)")
                .font(.caption)
                .foregroundStyle(MorpheTheme.textPrimary)
            Text("Score: \(drill.scoreMetric)")
                .font(.caption)
                .foregroundStyle(MorpheTheme.accentAlt)
        }
        .padding(.vertical, 4)
    }
}

private struct CoachQualityAnalyticsCard: View {
    let analytics: CoachAnalytics

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("Coach Quality Analytics")
                    .font(.headline)
                    .foregroundStyle(.white)

                LazyVGrid(
                    columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)],
                    spacing: 8
                ) {
                    MetricPill(label: "Retention", value: "\(analytics.clientRetention)%")
                    MetricPill(label: "Avg compliance", value: "\(analytics.averageCompliance)%")
                    MetricPill(label: "Drop-off", value: "\(analytics.dropOffRate)%")
                    MetricPill(label: "Pain flags", value: "\(analytics.painFlags)")
                    MetricPill(label: "Response", value: "\(analytics.messageResponseRate)%")
                    MetricPill(label: "Program success", value: "\(analytics.programSuccessRate)%")
                    MetricPill(label: "Completion", value: "\(analytics.sessionCompletion)%")
                    MetricPill(label: "Attendance", value: "\(analytics.groupAttendance)%")
                }

                Text(analytics.insight)
                    .font(.subheadline)
                    .foregroundStyle(MorpheTheme.textSecondary)
            }
        }
    }
}
