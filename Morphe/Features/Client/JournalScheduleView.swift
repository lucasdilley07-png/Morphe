import Charts
import SwiftUI

struct ExerciseDetailView: View {
    @Environment(\.dismiss) private var dismiss
    let exercise: ExerciseReference

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 16) {
                    GlassCard {
                        VStack(alignment: .leading, spacing: 12) {
                            Text(exercise.name)
                                .font(.title2.weight(.bold))
                                .foregroundStyle(.white)
                            HStack(spacing: 8) {
                                Image(systemName: "play.rectangle")
                                    .foregroundStyle(MorpheTheme.textMuted)
                                Text("Video demo coming soon")
                                    .font(.subheadline)
                                    .foregroundStyle(MorpheTheme.textMuted)
                            }

                            HStack(spacing: 8) {
                                MetricPill(label: "Muscles", value: exercise.musclesWorked)
                                MetricPill(label: "Gear", value: exercise.equipment)
                            }

                            MetricPill(label: "Difficulty", value: exercise.difficulty.rawValue)
                        }
                    }

                    GlassCard {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Step-by-step form instructions")
                                .font(.headline)
                                .foregroundStyle(.white)

                            ForEach(exercise.instructions, id: \.self) { step in
                                Text("- \(step)")
                                    .foregroundStyle(MorpheTheme.textPrimary)
                            }
                        }
                    }

                    GlassCard {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Coach Cue")
                                .font(.headline)
                                .foregroundStyle(.white)
                            Text(exercise.formCue)
                                .foregroundStyle(MorpheTheme.textPrimary)

                            Text("Common Mistake")
                                .font(.headline)
                                .foregroundStyle(.white)
                            Text(exercise.commonMistakes)
                                .foregroundStyle(MorpheTheme.textSecondary)

                            Text("Beginner Modification")
                                .font(.headline)
                                .foregroundStyle(.white)
                            Text(exercise.beginnerModification)
                                .foregroundStyle(MorpheTheme.textSecondary)
                        }
                    }

                    GlassCard {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Alternative Exercises")
                                .font(.headline)
                                .foregroundStyle(.white)

                            ForEach(exercise.alternatives, id: \.self) { option in
                                Text("- \(option)")
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
                    .foregroundStyle(.white)
                }
            }
        }
    }
}

struct AthleteProfileView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(MorpheAppStore.self) private var store
    let athlete: CoachClient
    @State private var notesDraft = ""
    @State private var manualWorkoutTitle = ""
    @State private var manualWorkoutDuration = 35
    @State private var manualWorkoutNotes = ""
    @State private var manualTemplateID: UUID?
    @State private var aiPhotoLabel = ""
    @State private var aiImportDraft: WorkoutLog?
    @State private var editingLog: WorkoutLog?
    @State private var selectedLogFilter: CoachWorkoutLogFilter = .all
    @State private var showProfileDetails = false
    @State private var showCoachNotes = false
    @State private var showWorkoutInput = false
    @State private var showPerformanceStory = false
    @State private var showContextAndTesting = false
    @State private var showingAssignWorkoutSheet = false
    @State private var coachPraiseDraft: CoachPublicPraiseDraft?
    @State private var sessionRequest: CoachSessionLaunchRequest?

    private var currentAthlete: CoachClient {
        store.coachClients.first(where: { $0.id == athlete.id }) ?? athlete
    }

    private var availableTemplates: [WorkoutTemplate] {
        let matching = store.workoutTemplates.filter { $0.sport == currentAthlete.sport || $0.sport == .generalFitness }
        return matching.isEmpty ? store.workoutTemplates : matching
    }

    private var selectedTemplate: WorkoutTemplate? {
        guard let manualTemplateID else { return nil }
        return availableTemplates.first(where: { $0.id == manualTemplateID })
    }

    private var partnerInsight: PartnerTrainingInsight {
        store.partnerTrainingInsight(for: currentAthlete.id)
    }

    private var nextAction: CoachNextActionRecommendation {
        store.coachNextAction(for: currentAthlete.id)
    }

    private var athleteLogs: [WorkoutLog] {
        store.workoutLogs(for: currentAthlete.id)
    }

    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 16) {
                        SectionTitleView(
                            title: currentAthlete.name,
                            subtitle: "Athlete profile with readiness, compliance, notes, and the next coaching decision."
                        )

                        CoachAthleteActionStrip(
                            onMessage: {
                                openMessageThread()
                            },
                            onAssign: {
                                showingAssignWorkoutSheet = true
                            },
                            onReviewLogs: {
                                selectedLogFilter = .all
                                withAnimation(.spring(response: 0.34, dampingFraction: 0.88)) {
                                    proxy.scrollTo(AthleteProfileAnchor.completedLogs, anchor: .top)
                                }
                            },
                            onStartSession: {
                                sessionRequest = CoachSessionLaunchRequest(
                                    title: "Start Session for \(currentAthlete.name)",
                                    subtitle: "Search the workout archive, pick the right session, and launch it straight from this athlete profile.",
                                    preferredSport: currentAthlete.sport,
                                    athleteID: currentAthlete.id
                                )
                            }
                        )

                        CoachOutreachShortcutStrip(insight: store.coachOutreachInsight(for: currentAthlete.id)) { shortcut in
                            store.openCoachOutreachShortcut(shortcut, for: currentAthlete.id)
                            dismiss()
                        }

                        CoachAthleteOverviewCard(athlete: currentAthlete)

                        HStack(alignment: .top, spacing: 12) {
                            ProgramComplianceCard(compliance: currentAthlete.programCompliance)
                            RecoverySnapshotMiniCard(recovery: currentAthlete.recoveryScore, complianceScore: currentAthlete.complianceScore)
                        }

                        CoachAthleteReadCard(
                            athlete: currentAthlete,
                            insight: partnerInsight,
                            recommendation: nextAction,
                            onPraise: {
                                coachPraiseDraft = store.makeCoachPraiseDraft(for: currentAthlete.id)
                            }
                        ) {
                            handleSuggestedNextAction(nextAction)
                        }

                        HStack(alignment: .top, spacing: 12) {
                            TrainingLoadCard(load: currentAthlete.trainingLoad)
                            MovementQualityScoreCard(score: currentAthlete.movementQuality)
                        }

                        CoachAthleteDisclosureSection(
                            title: "Athlete Details",
                            subtitle: "Profile context, equipment, schedule, and readiness background.",
                            isExpanded: $showProfileDetails
                        ) {
                            CoachAthleteDetailCard(athlete: currentAthlete)
                        }

                        AthleteWorkoutLogListCard(
                            selectedFilter: $selectedLogFilter,
                            logs: athleteLogs,
                            canEditLog: { log in
                                store.canCurrentCoachEditWorkoutLogs(for: log.athleteID) && log.source != .athleteManual
                            },
                            canApproveLog: { log in
                                log.verificationStatus == .aiPendingReview && store.canCurrentCoachApproveAIEntries(for: log.athleteID)
                            },
                            onEdit: { log in
                                editingLog = log
                            },
                            onApprove: { log in
                                store.approveWorkoutLog(log)
                            },
                            onDelete: { log in
                                store.deleteWorkoutLog(log)
                            }
                        )
                        .id(AthleteProfileAnchor.completedLogs)

                        CoachAthleteDisclosureSection(
                            title: "Coach Notes",
                            subtitle: "Keep the working notes and coaching reminders tucked nearby.",
                            isExpanded: $showCoachNotes
                        ) {
                            CoachNotesPanel(notesDraft: $notesDraft) {
                                store.updateCoachNotes(for: currentAthlete.id, text: notesDraft)
                            }
                        }

                        CoachAthleteDisclosureSection(
                            title: "Workout Data Input",
                            subtitle: "Manual coach entry and AI photo review stay available without crowding the profile.",
                            isExpanded: $showWorkoutInput
                        ) {
                            CoachWorkoutLogEntryCard(
                                athlete: currentAthlete,
                                availableTemplates: availableTemplates,
                                selectedTemplateID: $manualTemplateID,
                                workoutTitle: $manualWorkoutTitle,
                                durationMinutes: $manualWorkoutDuration,
                                notes: $manualWorkoutNotes,
                                aiPhotoLabel: $aiPhotoLabel,
                                onSaveManual: {
                                    store.coachAddManualWorkoutLog(
                                        to: currentAthlete,
                                        template: selectedTemplate,
                                        workoutTitle: manualWorkoutTitle,
                                        durationMinutes: manualWorkoutDuration,
                                        notes: manualWorkoutNotes
                                    )
                                    manualWorkoutNotes = ""
                                },
                                onImportPhoto: {
                                    aiImportDraft = store.makeAIParsedWorkoutLogDraft(to: currentAthlete, photoLabel: aiPhotoLabel)
                                }
                            )
                        }
                        .id(AthleteProfileAnchor.workoutInput)

                        CoachAthleteDisclosureSection(
                            title: "Performance Story",
                            subtitle: "Timeline, trends, and the current report when you want the deeper read.",
                            isExpanded: $showPerformanceStory
                        ) {
                            GlassCard {
                                VStack(alignment: .leading, spacing: 12) {
                                    Text("Timeline")
                                        .font(.headline)
                                        .foregroundStyle(.white)

                                    ForEach(currentAthlete.timeline) { event in
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(event.title)
                                                .font(.subheadline.weight(.semibold))
                                                .foregroundStyle(.white)
                                            Text(event.detail)
                                                .font(.caption)
                                                .foregroundStyle(MorpheTheme.textSecondary)
                                        }
                                    }
                                }
                            }

                            GlassCard {
                                VStack(alignment: .leading, spacing: 12) {
                                    Text("Performance Trends")
                                        .font(.headline)
                                        .foregroundStyle(.white)

                                    Chart(currentAthlete.healthTrend) { point in
                                        LineMark(
                                            x: .value("Day", point.day),
                                            y: .value("Score", point.value)
                                        )
                                        .foregroundStyle(MorpheTheme.accent)
                                    }
                                    .frame(height: 150)

                                    Chart(currentAthlete.weightTrend) { point in
                                        BarMark(
                                            x: .value("Point", point.label),
                                            y: .value("Value", point.value)
                                        )
                                        .foregroundStyle(MorpheTheme.accentAlt)
                                    }
                                    .frame(height: 150)
                                }
                            }

                            AthleteReportCardView(report: currentAthlete.reportCard)
                        }

                        CoachAthleteDisclosureSection(
                            title: "Context + Testing",
                            subtitle: "Availability, event prep, and the testing snapshot for fuller coaching context.",
                            isExpanded: $showContextAndTesting
                        ) {
                            AthleteAvailabilityConstraintsCard(availability: currentAthlete.availability)
                            EventPrepModeCard(plan: currentAthlete.eventPrep)

                            GlassCard {
                                VStack(alignment: .leading, spacing: 12) {
                                    Text("Testing Snapshot")
                                        .font(.headline)
                                        .foregroundStyle(.white)

                                    ForEach(currentAthlete.tests) { test in
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
                                            Text("\(test.result) \(test.unit)")
                                                .foregroundStyle(.white)
                                        }
                                    }
                                }
                            }
                        }
                    }
                    .padding(20)
                }
            }
            .background(PremiumBackground())
            .sheet(item: $aiImportDraft) { draft in
                WorkoutLogEditorSheet(
                    draft: draft,
                    title: "Review AI Import",
                    subtitle: "Check the workout title, duration, and parsed exercises before saving this to the athlete profile.",
                    confirmLabel: "Confirm and Save to Athlete Profile"
                ) { approvedDraft in
                    store.confirmAIParsedWorkoutLog(approvedDraft)
                    aiPhotoLabel = ""
                    aiImportDraft = nil
                }
            }
            .sheet(item: $editingLog) { log in
                WorkoutLogEditorSheet(
                    draft: log,
                    title: "Edit Shared Log",
                    subtitle: "Update the workout title, duration, notes, and exercise details before this log rolls into athlete progress.",
                    confirmLabel: "Save Log Changes"
                ) { updatedLog in
                    store.updateWorkoutLog(updatedLog)
                    editingLog = nil
                }
            }
            .sheet(item: $sessionRequest) { request in
                CoachStartSessionSheet(request: request)
                    .environment(store)
            }
            .sheet(isPresented: $showingAssignWorkoutSheet) {
                CoachAthleteAssignWorkoutSheet(
                    athlete: currentAthlete,
                    availableTemplates: availableTemplates
                )
                .environment(store)
            }
            .sheet(item: $coachPraiseDraft) { draft in
                CoachPublicPraiseSheet(draft: draft)
                    .environment(store)
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundStyle(.white)
                }
            }
            .onAppear {
                notesDraft = currentAthlete.coachNotes
                manualWorkoutTitle = currentAthlete.currentProgram
                manualTemplateID = manualTemplateID ?? availableTemplates.first?.id
            }
        }
    }

    private func openMessageThread() {
        if let thread = store.messageThreads.first(where: { $0.participant == currentAthlete.name }) {
            store.selectedCoachTab = .messages
            store.selectThread(thread)
            dismiss()
        } else {
            store.announce("No message thread found for \(currentAthlete.name).")
        }
    }

    private func handleSuggestedNextAction(_ recommendation: CoachNextActionRecommendation) {
        switch recommendation.type {
        case .reviewAI:
            selectedLogFilter = .ai
            store.announce("Showing AI-imported logs.")
        case .reviewBuddy:
            selectedLogFilter = .buddy
            store.announce("Showing buddy-session logs.")
        case .messageAthlete:
            openMessageThread()
        case .assignRecovery:
            store.assignRecoveryPlan(to: currentAthlete.id)
        case .missedSessionNudge:
            store.openCoachOutreachShortcut(.missedSession, for: currentAthlete.id)
            dismiss()
        case .partnerPrompt:
            store.openCoachOutreachShortcut(.partner, for: currentAthlete.id)
            dismiss()
        case .askPainUpdate:
            store.openCoachFollowUpThread(
                for: currentAthlete.id,
                action: .askPainUpdate,
                toast: "Pain check-in ready for \(currentAthlete.name)."
            )
            dismiss()
        case .praisePublicly:
            coachPraiseDraft = store.makeCoachPraiseDraft(for: currentAthlete.id)
        }
    }
}

private enum AthleteProfileAnchor: String, Hashable {
    case workoutInput
    case completedLogs
}

private struct CoachAthleteOverviewCard: View {
    let athlete: CoachClient

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("Overview")
                    .font(.headline)
                    .foregroundStyle(.white)

                HStack(spacing: 8) {
                    MetricPill(label: "Sport", value: athlete.sport.shortTitle)
                    MetricPill(label: "Goal", value: athlete.goal)
                    MetricPill(label: "Risk", value: athlete.risk.rawValue)
                }

                Text(athlete.statusText)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)

                ProfileLine(title: "Current program", value: athlete.currentProgram)
                ProfileLine(title: "Last log", value: athlete.lastWorkout)

                Text(athlete.adherenceSummary)
                    .font(.caption)
                    .foregroundStyle(MorpheTheme.textSecondary)
            }
        }
    }
}

private struct CoachAthleteReadCard: View {
    let athlete: CoachClient
    let insight: PartnerTrainingInsight
    let recommendation: CoachNextActionRecommendation
    let onPraise: () -> Void
    let onAction: () -> Void

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("Coach Read")
                    .font(.headline)
                    .foregroundStyle(.white)

                HStack(spacing: 8) {
                    MetricPill(label: "Partner", value: "\(insight.buddySessionsThisWeek)")
                    MetricPill(label: "Solo", value: "\(insight.soloSessionsThisWeek)")
                    MetricPill(label: "Readiness", value: athlete.recoveryScore.status.rawValue)
                }

                Text(recommendation.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)

                Text(recommendation.detail)
                    .font(.caption)
                    .foregroundStyle(MorpheTheme.textSecondary)

                Text(insight.coachSummary)
                    .font(.caption)
                    .foregroundStyle(MorpheTheme.accentAlt)

                Text(athlete.aiSummary)
                    .font(.caption)
                    .foregroundStyle(MorpheTheme.textPrimary)
                    .lineLimit(3)

                HStack(spacing: 10) {
                    Button(recommendation.actionLabel, action: onAction)
                        .buttonStyle(PrimaryCTAButtonStyle(accent: MorpheTheme.accent))

                    Button("Praise Publicly", action: onPraise)
                        .buttonStyle(SecondaryCTAButtonStyle())
                }
            }
        }
    }
}

private struct CoachAthleteDetailCard: View {
    let athlete: CoachClient

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    MetricPill(label: "Position", value: athlete.position)
                    MetricPill(label: "Training Age", value: athlete.trainingAge)
                }

                ProfileLine(title: "Fitness level", value: athlete.fitnessLevel)
                ProfileLine(title: "Injury history", value: athlete.injuryHistory.joined(separator: ", "))
                ProfileLine(title: "Current limitations", value: athlete.limitations.joined(separator: ", "))
                ProfileLine(title: "Equipment access", value: athlete.equipment.joined(separator: ", "))
                ProfileLine(title: "Weekly schedule", value: athlete.weeklySchedule.joined(separator: " | "))
                ProfileLine(title: "Competition / event", value: athlete.competitionDate)
            }
        }
    }
}

private struct CoachAthleteActionStrip: View {
    let onMessage: () -> Void
    let onAssign: () -> Void
    let onReviewLogs: () -> Void
    let onStartSession: () -> Void

    private let columns = [
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10)
    ]

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("Coach Actions")
                    .font(.headline)
                    .foregroundStyle(.white)

                LazyVGrid(columns: columns, spacing: 10) {
                    CoachAthleteActionButton(
                        title: "Message",
                        systemImage: "bubble.left.and.bubble.right.fill",
                        tint: MorpheTheme.accentAlt,
                        action: onMessage
                    )
                    CoachAthleteActionButton(
                        title: "Assign",
                        systemImage: "calendar.badge.plus",
                        tint: MorpheTheme.accent,
                        action: onAssign
                    )
                    CoachAthleteActionButton(
                        title: "Review Logs",
                        systemImage: "list.clipboard.fill",
                        tint: MorpheTheme.warning,
                        action: onReviewLogs
                    )
                    CoachAthleteActionButton(
                        title: "Start Session",
                        systemImage: "play.circle.fill",
                        tint: MorpheTheme.lavender,
                        action: onStartSession
                    )
                }
            }
        }
    }
}

private struct CoachAthleteDisclosureSection<Content: View>: View {
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

private struct CoachAthleteActionButton: View {
    let title: String
    let systemImage: String
    let tint: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: systemImage)
                    .font(.headline)
                    .foregroundStyle(tint)
                    .frame(width: 22)

                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.white.opacity(0.05))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .strokeBorder(tint.opacity(0.24), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

private struct CoachOutreachShortcutStrip: View {
    let insight: String?
    let onSelect: (CoachOutreachShortcut) -> Void

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("Outreach Shortcuts")
                    .font(.headline)
                    .foregroundStyle(.white)

                Text("Draft the right message without leaving the coaching flow.")
                    .font(.subheadline)
                    .foregroundStyle(MorpheTheme.textSecondary)

                if let insight {
                    Text(insight)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(MorpheTheme.accentAlt)
                }

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(CoachOutreachShortcut.allCases) { shortcut in
                            Button {
                                onSelect(shortcut)
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
                                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                                        .fill(MorpheTheme.panelRaised)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                                .stroke(MorpheTheme.strokeStrong.opacity(0.22), lineWidth: 1)
                                        )
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
        }
    }
}

private struct CoachAthleteAssignWorkoutSheet: View {
    @Environment(MorpheAppStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    let athlete: CoachClient
    let availableTemplates: [WorkoutTemplate]

    @State private var searchText = ""
    @State private var scheduledDate = Date()

    private var filteredTemplates: [WorkoutTemplate] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !query.isEmpty else { return availableTemplates }

        return availableTemplates.filter { template in
            template.name.lowercased().contains(query)
                || template.goal.lowercased().contains(query)
                || template.equipment.lowercased().contains(query)
                || template.sessionType.rawValue.lowercased().contains(query)
                || template.sport.rawValue.lowercased().contains(query)
        }
    }

    private var scheduledLabel: String {
        scheduledDate.formatted(date: .abbreviated, time: .shortened)
    }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 16) {
                    GlassCard {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Assign a Workout")
                                .font(.headline)
                                .foregroundStyle(.white)

                            Text("Pick the next best session for \(athlete.name) and schedule it without leaving the athlete profile.")
                                .font(.subheadline)
                                .foregroundStyle(MorpheTheme.textSecondary)

                            HStack(spacing: 8) {
                                MetricPill(label: "Athlete", value: athlete.name)
                                MetricPill(label: "Sport", value: athlete.sport.shortTitle)
                                MetricPill(label: "Current", value: athlete.currentProgram)
                            }
                        }
                    }

                    TextField("Search workouts or programs", text: $searchText)
                        .textFieldStyle(MorpheFieldStyle())

                    GlassCard {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Schedule")
                                .font(.headline)
                                .foregroundStyle(.white)

                            DatePicker("Session time", selection: $scheduledDate)
                                .tint(MorpheTheme.accent)
                        }
                    }

                    if filteredTemplates.isEmpty {
                        GlassCard {
                            Text("No matching workouts yet. Try a different search or save a few more templates first.")
                                .foregroundStyle(MorpheTheme.textSecondary)
                        }
                    } else {
                        ForEach(filteredTemplates) { template in
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

                                        StatusBadge(
                                            text: template.sport.shortTitle,
                                            color: MorpheTheme.color(for: template.sport)
                                        )
                                    }

                                    HStack(spacing: 8) {
                                        MetricPill(label: "Type", value: template.sessionType.rawValue)
                                        MetricPill(label: "Gear", value: template.equipment)
                                    }

                                    Button("Assign for \(scheduledLabel)") {
                                        store.assignWorkoutTemplate(template, to: athlete, scheduledLabel: scheduledLabel)
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

struct CoachPublicPraiseSheet: View {
    @Environment(MorpheAppStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    let draft: CoachPublicPraiseDraft
    @State private var draftText: String

    init(draft: CoachPublicPraiseDraft) {
        self.draft = draft
        _draftText = State(initialValue: draft.body)
    }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 16) {
                    GlassCard {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Public Coach Praise")
                                .font(.headline)
                                .foregroundStyle(.white)

                            Text("Share a grounded public note tied to real training work, not a generic shoutout.")
                                .font(.subheadline)
                                .foregroundStyle(MorpheTheme.textSecondary)

                            HStack(spacing: 8) {
                                MetricPill(label: "Athlete", value: draft.athleteName)
                                MetricPill(label: "Context", value: draft.contextLabel)
                            }
                        }
                    }

                    GlassCard {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Post Draft")
                                .font(.headline)
                                .foregroundStyle(.white)

                            TextField("Coach praise", text: $draftText, axis: .vertical)
                                .textFieldStyle(MorpheFieldStyle())
                                .lineLimit(5...8)

                            WrapStack(spacing: 8) {
                                ForEach(draft.tags, id: \.self) { tag in
                                    CoachPraiseTagChip(text: tag)
                                }
                            }
                        }
                    }

                    Button("Share Praise") {
                        store.shareCoachPraiseDraft(draft, editedText: draftText)
                        dismiss()
                    }
                    .buttonStyle(PrimaryCTAButtonStyle(accent: MorpheTheme.accent))
                }
                .padding(20)
            }
            .background(PremiumBackground())
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundStyle(.white)
                }
            }
        }
    }
}

private struct CoachPraiseTagChip: View {
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

private struct CoachWorkoutLogEntryCard: View {
    let athlete: CoachClient
    let availableTemplates: [WorkoutTemplate]
    @Binding var selectedTemplateID: UUID?
    @Binding var workoutTitle: String
    @Binding var durationMinutes: Int
    @Binding var notes: String
    @Binding var aiPhotoLabel: String
    let onSaveManual: () -> Void
    let onImportPhoto: () -> Void

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("Workout Data Input")
                    .font(.headline)
                    .foregroundStyle(.white)

                Text("Add a workout for \(athlete.name) manually, or turn a workout photo into a shared log with Morphe AI.")
                    .foregroundStyle(MorpheTheme.textSecondary)

                Picker("Template", selection: $selectedTemplateID) {
                    Text("Custom entry").tag(UUID?.none)
                    ForEach(availableTemplates) { template in
                        Text(template.name).tag(UUID?.some(template.id))
                    }
                }
                .pickerStyle(.menu)

                TextField("Workout title", text: $workoutTitle)
                    .textFieldStyle(MorpheFieldStyle())

                Stepper("Duration: \(durationMinutes) min", value: $durationMinutes, in: 5...180, step: 5)
                    .foregroundStyle(.white)

                TextField("Coach notes or result summary", text: $notes, axis: .vertical)
                    .textFieldStyle(MorpheFieldStyle())
                    .lineLimit(3...5)

                Button("Save Manual Workout Log", action: onSaveManual)
                    .buttonStyle(PrimaryCTAButtonStyle(accent: MorpheTheme.accentAlt))

                Divider()
                    .overlay(Color.white.opacity(0.08))

                TextField("Photo label or screenshot note", text: $aiPhotoLabel)
                    .textFieldStyle(MorpheFieldStyle())

                Text("Morphe AI will parse the workout first, then you can review and confirm before it saves anything.")
                    .font(.caption)
                    .foregroundStyle(MorpheTheme.textSecondary)

                Button("Review Workout From Photo", action: onImportPhoto)
                    .buttonStyle(SecondaryCTAButtonStyle())
            }
        }
    }
}

private struct WorkoutLogEditorSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var draft: WorkoutLog
    let title: String
    let subtitle: String
    let confirmLabel: String
    let onConfirm: (WorkoutLog) -> Void

    init(
        draft: WorkoutLog,
        title: String,
        subtitle: String,
        confirmLabel: String,
        onConfirm: @escaping (WorkoutLog) -> Void
    ) {
        _draft = State(initialValue: draft)
        self.title = title
        self.subtitle = subtitle
        self.confirmLabel = confirmLabel
        self.onConfirm = onConfirm
    }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 16) {
                    GlassCard {
                        VStack(alignment: .leading, spacing: 12) {
                            Text(title)
                                .font(.title3.weight(.bold))
                                .foregroundStyle(.white)

                            Text(subtitle)
                                .foregroundStyle(MorpheTheme.textSecondary)

                            HStack(spacing: 8) {
                                MetricPill(label: "Athlete", value: draft.athleteName)
                                MetricPill(label: "Source", value: draft.source.rawValue)
                                MetricPill(label: "Status", value: draft.verificationStatus.rawValue)
                            }
                        }
                    }

                    GlassCard {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Workout Details")
                                .font(.headline)
                                .foregroundStyle(.white)

                            TextField("Workout title", text: $draft.workoutTitle)
                                .textFieldStyle(MorpheFieldStyle())

                            Stepper("Duration: \(draft.durationMinutes) min", value: $draft.durationMinutes, in: 5...180, step: 5)
                                .foregroundStyle(.white)

                            TextField("Review notes", text: $draft.notes, axis: .vertical)
                                .textFieldStyle(MorpheFieldStyle())
                                .lineLimit(3...5)
                        }
                    }

                    GlassCard {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Parsed Exercises")
                                .font(.headline)
                                .foregroundStyle(.white)

                            ForEach($draft.exercises) { $exercise in
                                VStack(alignment: .leading, spacing: 10) {
                                    TextField("Exercise name", text: $exercise.name)
                                        .textFieldStyle(MorpheFieldStyle())

                                    HStack(spacing: 10) {
                                        TextField("Sets", text: $exercise.sets)
                                            .textFieldStyle(MorpheFieldStyle())
                                        TextField("Reps", text: $exercise.reps)
                                            .textFieldStyle(MorpheFieldStyle())
                                        TextField("Weight", text: $exercise.weight)
                                            .textFieldStyle(MorpheFieldStyle())
                                    }

                                    TextField("Exercise note", text: $exercise.note, axis: .vertical)
                                        .textFieldStyle(MorpheFieldStyle())
                                        .lineLimit(2...4)
                                }
                                .padding(.vertical, 4)
                            }
                        }
                    }

                    Button(confirmLabel) {
                        onConfirm(draft)
                        dismiss()
                    }
                    .buttonStyle(PrimaryCTAButtonStyle(accent: MorpheTheme.accent))
                }
                .padding(20)
            }
            .background(PremiumBackground())
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundStyle(.white)
                }
            }
        }
    }
}

private struct AthleteWorkoutLogListCard: View {
    @Binding var selectedFilter: CoachWorkoutLogFilter
    let logs: [WorkoutLog]
    let canEditLog: (WorkoutLog) -> Bool
    let canApproveLog: (WorkoutLog) -> Bool
    let onEdit: (WorkoutLog) -> Void
    let onApprove: (WorkoutLog) -> Void
    let onDelete: (WorkoutLog) -> Void

    private var filteredLogs: [WorkoutLog] {
        switch selectedFilter {
        case .all:
            return logs
        case .athlete:
            return logs.filter { $0.source == .athleteManual }
        case .coach:
            return logs.filter { $0.source == .coachManual }
        case .ai:
            return logs.filter { $0.source == .aiPhotoParsed }
        case .buddy:
            return logs.filter { $0.source == .partnerShared }
        }
    }

    private var coachInsightText: String {
        let calendar = Calendar.current
        let aiPendingCount = logs.filter { $0.verificationStatus == .aiPendingReview }.count
        let buddyCount = logs.filter { $0.source == .partnerShared }.count
        let coachCount = logs.filter { $0.source == .coachManual }.count
        let athleteCount = logs.filter { $0.source == .athleteManual }.count
        let athleteThisWeek = logs.filter {
            $0.source == .athleteManual && calendar.isDate($0.completedAt, equalTo: .now, toGranularity: .weekOfYear)
        }.count

        if aiPendingCount > 0 {
            return aiPendingCount == 1
                ? "1 AI import still needs review."
                : "\(aiPendingCount) AI imports still need review."
        }

        if buddyCount > max(athleteCount, 0) && buddyCount > 0 {
            return "Buddy sessions are driving adherence lately."
        }

        if coachCount > athleteCount && coachCount > 0 {
            return "Coach-entered logs are doing most of the work right now."
        }

        if athleteThisWeek == 0 {
            return "No athlete-submitted logs yet this week."
        }

        return "Athlete-submitted logs are showing up consistently this week."
    }

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("Completed Logs")
                    .font(.headline)
                    .foregroundStyle(.white)

                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "waveform.path.ecg.text")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(MorpheTheme.accentAlt)
                        .padding(.top, 1)

                    Text(coachInsightText)
                        .font(.caption)
                        .foregroundStyle(MorpheTheme.textSecondary)
                }

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(CoachWorkoutLogFilter.allCases) { filter in
                            Button(filter.rawValue) {
                                selectedFilter = filter
                            }
                            .buttonStyle(
                                FilterChipStyle(
                                    isSelected: selectedFilter == filter,
                                    selectedColor: filter.color
                                )
                            )
                        }
                    }
                    .padding(.vertical, 2)
                }

                if logs.isEmpty {
                    Text("No shared logs yet.")
                        .foregroundStyle(MorpheTheme.textSecondary)
                } else if filteredLogs.isEmpty {
                    Text(selectedFilter.emptyStateMessage)
                        .foregroundStyle(MorpheTheme.textSecondary)
                } else {
                    ForEach(filteredLogs) { log in
                        VStack(alignment: .leading, spacing: 6) {
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
                                HStack(spacing: 8) {
                                    if canEditLog(log) || canApproveLog(log) {
                                        Menu {
                                            if canApproveLog(log) {
                                                Button("Approve AI Log") {
                                                    onApprove(log)
                                                }
                                            }

                                            if canEditLog(log) {
                                                Button("Edit Log") {
                                                    onEdit(log)
                                                }

                                                Button("Delete Log", role: .destructive) {
                                                    onDelete(log)
                                                }
                                            }
                                        } label: {
                                            Image(systemName: "ellipsis.circle")
                                                .foregroundStyle(MorpheTheme.textSecondary)
                                        }
                                    }

                                    StatusBadge(text: log.source.badgeTitle, color: badgeColor(for: log.source))
                                }
                            }

                            Text("\(log.enteredByName) • \(log.verificationStatus.rawValue)")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(MorpheTheme.accentAlt)

                            if let firstExercise = log.exercises.first {
                                Text("First lift/drill: \(firstExercise.name) • \(firstExercise.sets) • \(firstExercise.reps)")
                                    .font(.caption)
                                    .foregroundStyle(MorpheTheme.textPrimary)
                            }

                            Text(log.notes)
                                .font(.caption)
                                .foregroundStyle(MorpheTheme.textSecondary)
                        }
                        .padding(.vertical, 4)
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

private enum CoachWorkoutLogFilter: String, CaseIterable, Identifiable {
    case all = "All"
    case athlete = "Athlete"
    case coach = "Coach"
    case ai = "AI"
    case buddy = "Buddy"

    var id: String { rawValue }

    var color: Color {
        switch self {
        case .all:
            return MorpheTheme.accent
        case .athlete:
            return MorpheTheme.accent
        case .coach:
            return MorpheTheme.accentAlt
        case .ai:
            return MorpheTheme.lavender
        case .buddy:
            return MorpheTheme.warning
        }
    }

    var emptyStateMessage: String {
        switch self {
        case .all:
            return "No shared logs yet."
        case .athlete:
            return "No athlete-entered logs yet."
        case .coach:
            return "No coach-entered logs yet."
        case .ai:
            return "No AI-imported logs yet."
        case .buddy:
            return "No buddy sessions have been logged yet."
        }
    }
}

struct ProgramComplianceCard: View {
    let compliance: ProgramCompliance

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 10) {
                Text("Program Compliance")
                    .font(.headline)
                    .foregroundStyle(.white)
                Text("\(compliance.score)%")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                Text(compliance.summary)
                    .font(.subheadline)
                    .foregroundStyle(MorpheTheme.textSecondary)
            }
        }
    }
}

struct RecoverySnapshotMiniCard: View {
    let recovery: RecoverySnapshot
    let complianceScore: Int

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 10) {
                Text("Readiness")
                    .font(.headline)
                    .foregroundStyle(.white)
                Text("\(recovery.score)")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                Text(recovery.status.rawValue)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(MorpheTheme.color(for: recovery.status))
                Text("Compliance \(complianceScore)%")
                    .font(.caption)
                    .foregroundStyle(MorpheTheme.textSecondary)
            }
        }
    }
}

struct TrainingLoadCard: View {
    let load: TrainingLoadInsight

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 10) {
                Text("Training Load")
                    .font(.headline)
                    .foregroundStyle(.white)
                Text(load.status)
                    .font(.title3.weight(.bold))
                    .foregroundStyle(.white)
                Text(load.summary)
                    .foregroundStyle(MorpheTheme.textPrimary)
                Text(load.recommendation)
                    .foregroundStyle(MorpheTheme.textSecondary)
            }
        }
    }
}

struct CoachAISummaryCard: View {
    let text: String

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 10) {
                Text("AI Summary")
                    .font(.headline)
                    .foregroundStyle(.white)
                Text(text)
                    .foregroundStyle(MorpheTheme.textPrimary)
            }
        }
    }
}

struct CoachPartnerAdherenceCard: View {
    let insight: PartnerTrainingInsight

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 10) {
                Text("Partner Adherence")
                    .font(.headline)
                    .foregroundStyle(.white)

                HStack(spacing: 8) {
                    MetricPill(label: "Solo", value: "\(insight.soloSessionsThisWeek)")
                    MetricPill(label: "Buddy", value: "\(insight.buddySessionsThisWeek)")
                    MetricPill(label: "Buddy share", value: "\(insight.buddyShareLast30Days)%")
                }

                Text(insight.coachSummary)
                    .foregroundStyle(MorpheTheme.textPrimary)

                if let lastPartnerName = insight.lastPartnerName {
                    Text("Last partner logged: \(lastPartnerName)")
                        .font(.caption)
                        .foregroundStyle(MorpheTheme.warning)
                }
            }
        }
    }
}

struct CoachSuggestedNextActionCard: View {
    let recommendation: CoachNextActionRecommendation
    let onRunAction: () -> Void

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 10) {
                Text("Suggested Next Action")
                    .font(.headline)
                    .foregroundStyle(.white)

                Text(recommendation.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(MorpheTheme.accentAlt)

                Text(recommendation.detail)
                    .foregroundStyle(MorpheTheme.textPrimary)

                Button(recommendation.actionLabel, action: onRunAction)
                    .buttonStyle(PrimaryCTAButtonStyle(accent: MorpheTheme.accent))
            }
        }
    }
}

struct CoachNotesPanel: View {
    @Binding var notesDraft: String
    let onSave: () -> Void

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("Coach Notes")
                    .font(.headline)
                    .foregroundStyle(.white)

                TextEditor(text: $notesDraft)
                    .frame(minHeight: 110)
                    .padding(8)
                    .scrollContentBackground(.hidden)
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(Color.white.opacity(0.06))
                    )
                    .foregroundStyle(.white)

                Button("Save Notes", action: onSave)
                    .buttonStyle(PrimaryCTAButtonStyle(accent: MorpheTheme.accentAlt))
            }
        }
    }
}

struct MovementQualityScoreCard: View {
    let score: MovementQualityScore

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 10) {
                Text("Movement Quality")
                    .font(.headline)
                    .foregroundStyle(.white)
                Text("\(score.score)/100")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                Text(score.summary)
                    .foregroundStyle(MorpheTheme.textSecondary)
            }
        }
    }
}

struct AthleteReportCardView: View {
    let report: AthleteReport

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 10) {
                Text("Weekly Report Card")
                    .font(.headline)
                    .foregroundStyle(.white)
                Text(report.week)
                    .font(.subheadline)
                    .foregroundStyle(MorpheTheme.textSecondary)

                HStack(spacing: 8) {
                    MetricPill(label: "Compliance", value: report.compliance)
                    MetricPill(label: "Readiness", value: report.readiness)
                    MetricPill(label: "Performance", value: report.performance)
                }

                ProfileLine(title: "Main win", value: report.mainWin)
                ProfileLine(title: "Main issue", value: report.mainIssue)
                ProfileLine(title: "Coach notes", value: report.coachNotes)
                ProfileLine(title: "AI summary", value: report.aiSummary)
                ProfileLine(title: "Next focus", value: report.nextFocus)
            }
        }
    }
}

struct AthleteAvailabilityConstraintsCard: View {
    let availability: AvailabilityConstraints

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 10) {
                Text("Availability + Constraints")
                    .font(.headline)
                    .foregroundStyle(.white)
                ProfileLine(title: "Available days", value: availability.availableDays.joined(separator: ", "))
                ProfileLine(title: "Time available", value: availability.timeAvailable)
                ProfileLine(title: "Equipment access", value: availability.equipmentAccess)
                ProfileLine(title: "Location", value: availability.location)
                ProfileLine(title: "Schedule", value: availability.schoolOrWork)
                ProfileLine(title: "Practice", value: availability.practiceSchedule)
                ProfileLine(title: "Games", value: availability.gameSchedule)
                ProfileLine(title: "Travel", value: availability.travelSchedule)
                ProfileLine(title: "Sleep", value: availability.sleepSchedule)
                ProfileLine(title: "Stress", value: availability.stressLevel)
            }
        }
    }
}

struct EventPrepModeCard: View {
    let plan: EventPrepPlan

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 10) {
                Text("Event / Competition Prep")
                    .font(.headline)
                    .foregroundStyle(.white)
                Text(plan.title)
                    .font(.title3.weight(.bold))
                    .foregroundStyle(.white)
                ProfileLine(title: "Countdown", value: plan.countdown)
                ProfileLine(title: "Weekly focus", value: plan.weeklyFocus)
                ProfileLine(title: "Readiness", value: plan.readiness)
                ProfileLine(title: "Taper", value: plan.taperPlan)
                ProfileLine(title: "Weight target", value: plan.weightTarget)
                ProfileLine(title: "Recovery priority", value: plan.recoveryPriority)
                ProfileLine(title: "Coach alert", value: plan.coachAlert)
            }
        }
    }
}

private struct ProfileLine: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(MorpheTheme.textMuted)
            Text(value)
                .font(.subheadline)
                .foregroundStyle(.white)
        }
    }
}
