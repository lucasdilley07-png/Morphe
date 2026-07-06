import SwiftUI

struct WorkoutView: View {
    @Environment(MorpheAppStore.self) private var store

    @State private var workoutFinished = false
    @State private var restSeconds = 180
    @State private var restRunning = false
    @State private var swapTarget: WorkoutExercise?
    @State private var isShowingPainFlow = false
    @State private var isShowingRepLogger = false
    @State private var pendingRepCount = 10
    @State private var pendingWeight: Double = 0
    @State private var pendingRPE: Int?
    @State private var editingSetIndex: Int?
    @State private var showDiscardConfirm = false
    @State private var showLibrary = false
    @State private var showDiscover = false
    @State private var showExerciseList = false
    @State private var showAdjustments = false
    @State private var showSessionQueue = false
    @State private var showHistory = false
    @State private var showBuilder = false

    private let painAreas = ["Knee", "Shoulder", "Back", "Hip", "Ankle", "Neck"]
    private var goodForTodayRecommendation: GoodForTodayWorkoutRecommendation {
        store.currentGoodForTodayRecommendation
    }
    private var nextTrackedExercise: WorkoutExercise? {
        let nextIndex = store.activeWorkoutExerciseIndex + 1
        guard store.currentWorkout.exercises.indices.contains(nextIndex) else { return nil }
        return store.currentWorkout.exercises[nextIndex]
    }

    var body: some View {
        Group {
            if store.isWorkoutSessionActive {
                activeWorkoutMode
            } else {
                workoutPlanningMode
            }
        }
        .sheet(item: $swapTarget) { exercise in
            ExerciseSwapFlowSheet(exercise: exercise)
                .environment(store)
        }
        .sheet(isPresented: $isShowingRepLogger) {
            SetRepLoggingSheet(reps: $pendingRepCount, weight: $pendingWeight, rpe: $pendingRPE) {
                if let editIndex = editingSetIndex, let exercise = store.activeWorkoutExercise {
                    store.updateTrackedSet(exerciseID: exercise.id, setIndex: editIndex, reps: pendingRepCount, weight: pendingWeight, rpe: pendingRPE)
                } else {
                    // Opening the full logger is an explicit action, so it may
                    // log past the planned set count ("Add extra set").
                    store.completeTrackedSet(reps: pendingRepCount, weight: pendingWeight, rpe: pendingRPE, allowExtra: true)
                }
                editingSetIndex = nil
                isShowingRepLogger = false
            }
            .environment(store)
            .presentationDetents([.height(540)])
            .onDisappear { editingSetIndex = nil }
        }
        .onChange(of: store.weightUnit) { oldUnit, newUnit in
            // Keep the inline stepper value meaning the same physical load
            // when the unit flips (the store converts the logged sets).
            guard oldUnit != newUnit, pendingWeight > 0 else { return }
            let factor = newUnit == .kilograms ? 0.45359237 : 2.20462262
            pendingWeight = ((pendingWeight * factor) * 10).rounded() / 10
        }
        .sheet(isPresented: $showBuilder) {
            WorkoutBuilderSheet()
                .environment(store)
        }
    }

    private var activeWorkoutMode: some View {
        @Bindable var store = store
        // One scroll surface for the whole live session: with the inline weight
        // row the tracker card is tall enough that a fixed header clipped the
        // console and pushed the Finish button off-screen on smaller devices.
        return ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 14) {
                LiveWorkoutConsoleCard(
                    workout: store.currentWorkout,
                    exerciseIndex: store.activeWorkoutExerciseIndex,
                    totalExercises: max(store.currentWorkout.exercises.count, 1),
                    warmupText: warmupText(for: store.currentWorkout.sport),
                    restSeconds: $restSeconds,
                    restRunning: $restRunning
                )

                if store.isTrackedWorkoutComplete {
                    WorkoutCompleteCard(
                        workoutName: store.currentWorkout.name,
                        totalSets: store.trackedSetTotalCount
                    ) {
                        if store.finishTrackedWorkoutSession() {
                            workoutFinished = true
                            restRunning = false
                        }
                    }
                }

                if let activeExercise = store.activeWorkoutExercise {
                    ActiveWorkoutTrackerCard(
                        workout: store.currentWorkout,
                        exercise: activeExercise,
                        exerciseIndex: store.activeWorkoutExerciseIndex,
                        totalExercises: store.currentWorkout.exercises.count,
                        completedSets: store.completedWorkoutSets[activeExercise.id, default: 0],
                        totalSets: targetSetCount(for: activeExercise),
                        nextExercise: nextTrackedExercise,
                        suggestedReps: suggestedRepCount(for: activeExercise),
                        quickRepOptions: quickRepOptions(for: activeExercise),
                        repsLogged: store.trackedSetReps[activeExercise.id, default: []],
                        weightsLogged: store.trackedSetWeights[activeExercise.id, default: []],
                        weight: $pendingWeight,
                        weightUnit: store.weightUnit,
                        onPrevious: { store.goToPreviousTrackedExercise() },
                        onQuickLogSet: { reps in
                            store.completeTrackedSet(reps: reps, weight: pendingWeight)
                        },
                        onOpenCustomRepLogger: {
                            pendingRepCount = suggestedRepCount(for: activeExercise)
                            pendingRPE = nil
                            isShowingRepLogger = true
                        },
                        onEditSet: { index in
                            let repsLogged = store.trackedSetReps[activeExercise.id, default: []]
                            let weightsLogged = store.trackedSetWeights[activeExercise.id, default: []]
                            let rpesLogged = store.trackedSetRPE[activeExercise.id, default: []]
                            pendingRepCount = repsLogged.indices.contains(index) ? repsLogged[index] : suggestedRepCount(for: activeExercise)
                            pendingWeight = weightsLogged.indices.contains(index) ? weightsLogged[index] : 0
                            let storedRPE = rpesLogged.indices.contains(index) ? rpesLogged[index] : 0
                            pendingRPE = storedRPE > 0 ? storedRPE : nil
                            editingSetIndex = index
                            isShowingRepLogger = true
                        },
                        onDeleteSet: { index in
                            store.removeTrackedSet(exerciseID: activeExercise.id, setIndex: index)
                        },
                        onNext: { store.goToNextTrackedExercise() },
                        onStartRest: {
                            restSeconds = 180
                            restRunning = true
                        },
                        canGoPrevious: store.activeWorkoutExerciseIndex > 0
                    )
                }

                HStack(spacing: 10) {
                    Button("Finish Session") {
                        if store.finishTrackedWorkoutSession() {
                            workoutFinished = true
                            restRunning = false
                        }
                    }
                    .buttonStyle(PrimaryCTAButtonStyle(accent: MorpheTheme.accent))

                    Button("Discard") {
                        showDiscardConfirm = true
                    }
                    .buttonStyle(SecondaryCTAButtonStyle())
                    .frame(width: 110)
                    .accessibilityLabel("Discard workout")
                }
                .confirmationDialog(
                    store.trackedSetTotalCount > 0
                        ? "Discard this workout? \(store.trackedSetTotalCount) logged set\(store.trackedSetTotalCount == 1 ? "" : "s") will be lost."
                        : "Discard this workout?",
                    isPresented: $showDiscardConfirm,
                    titleVisibility: .visible
                ) {
                    Button("Discard Workout", role: .destructive) {
                        restRunning = false
                        workoutFinished = false
                        store.cancelTrackedWorkoutSession()
                    }
                    Button("Keep Training", role: .cancel) {}
                }

                TrainExpandableSection(
                    title: "Session tools",
                    subtitle: "Queue, swaps, pain-safe adjustments, and quick tips stay here without pulling focus off the active set.",
                    isExpanded: $showSessionQueue
                ) {
                    if let activeExercise = store.activeWorkoutExercise {
                        LiveWorkoutSupportToolsCard(
                            workout: store.currentWorkout,
                            exercise: activeExercise,
                            completedSets: store.completedWorkoutSets[activeExercise.id, default: 0],
                            totalSets: targetSetCount(for: activeExercise),
                            canGoPrevious: store.activeWorkoutExerciseIndex > 0,
                            onPrevious: { store.goToPreviousTrackedExercise() },
                            onSwap: { swapTarget = activeExercise },
                            onPain: {
                                store.painTriggerExercise = activeExercise.name
                                isShowingPainFlow = true
                            },
                            onViewForm: {
                                store.showExerciseDetail(for: activeExercise)
                            }
                        )
                    }

                    FocusedWorkoutQueueCard(
                        exercises: store.currentWorkout.exercises,
                        activeExerciseID: store.activeWorkoutExercise?.id,
                        completedWorkoutSets: store.completedWorkoutSets
                    )

                    if isShowingPainFlow || store.selectedWorkoutFeedback == .pain {
                        PainFlaggingCard(
                            painArea: $store.painArea,
                            painSeverity: $store.painSeverity,
                            triggerExercise: $store.painTriggerExercise,
                            painAreas: painAreas
                        ) {
                            store.savePainFlag()
                            isShowingPainFlow = false
                        }
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 120)
        }
        .onChange(of: store.activeWorkoutExerciseIndex) { _, _ in
            // Carry the working weight forward; prefer this exercise's own
            // last logged set when it has one.
            if let exercise = store.activeWorkoutExercise {
                pendingWeight = store.lastSessionWeight(for: exercise.id) ?? pendingWeight
            }
        }
    }

    private var workoutPlanningMode: some View {
        @Bindable var store = store
        return ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 16) {
                SectionTitleView(
                    title: "Train",
                    subtitle: store.hasCompletedWorkoutFlow
                        ? "Session finished — review what you logged, rate it, and lock it in."
                        : "Start, track, finish, rate the session, then let Morphe adjust the next move."
                )

                // Right after a finish, reviewing and logging IS the task —
                // it leads the screen instead of hiding below planning cards.
                if store.hasCompletedWorkoutFlow {
                    SessionRecapCard(
                        items: store.sessionRecapItems,
                        weightUnit: store.weightUnit
                    )

                    WorkoutDifficultyFeedbackCard(
                        selected: store.selectedWorkoutFeedback,
                        response: store.workoutFeedbackResponse
                    ) { option in
                        store.submitWorkoutFeedback(option)
                        if option == .pain {
                            isShowingPainFlow = true
                        }
                    }

                    if isShowingPainFlow || store.selectedWorkoutFeedback == .pain {
                        PainFlaggingCard(
                            painArea: $store.painArea,
                            painSeverity: $store.painSeverity,
                            triggerExercise: $store.painTriggerExercise,
                            painAreas: painAreas
                        ) {
                            store.savePainFlag()
                            isShowingPainFlow = false
                        }
                    }

                    if let prompt = postWorkoutPrompt {
                        PostWorkoutSmartActionCard(prompt: prompt) { action in
                            handlePostWorkoutAction(action)
                        }
                    }

                    Button("Log Workout and View Progress") {
                        store.logWorkout()
                    }
                    .buttonStyle(PrimaryCTAButtonStyle(accent: MorpheTheme.accent))
                }

                // ONE workout, one name: the same session the Today hero
                // shows, with Morphe's readiness-based pick demoted to an
                // inline suggestion instead of a competing second entry point.
                TodaysWorkoutCard(
                    workout: store.currentWorkout,
                    suggestion: store.recommendedWorkoutDiffers ? goodForTodayRecommendation : nil,
                    onStart: {
                        workoutFinished = false
                        isShowingPainFlow = false
                        store.startTodayWorkout()
                    },
                    onUseSuggestion: {
                        store.applyRecommendedWorkout()
                    },
                    onSwitch: {
                        store.cycleWorkout()
                    }
                )

                if store.partnerWorkoutEnabled, let partner = store.selectedWorkoutPartner, let plan = store.currentPartnerWorkoutPlan {
                    PartnerSessionCard(
                        partner: partner,
                        mode: store.selectedPartnerWorkoutMode,
                        plan: plan
                    ) {
                        store.sendPartnerReadyCheck()
                    }
                }

                TrainExpandableSection(
                    title: "My Library",
                    subtitle: "Build your own workouts and keep favorites and saved sessions in one place.",
                    isExpanded: $showLibrary
                ) {
                    Button {
                        showBuilder = true
                    } label: {
                        Label("Build your own workout", systemImage: "plus.circle.fill")
                    }
                    .buttonStyle(SecondaryCTAButtonStyle())

                    let myWorkouts = store.workoutTemplates.filter { store.isCustomWorkout($0.id) }
                    if !myWorkouts.isEmpty {
                        YourWorkoutsCard(
                            workouts: myWorkouts,
                            onStart: { template in
                                workoutFinished = false
                                isShowingPainFlow = false
                                store.beginLiveWorkout(template)
                            },
                            onDelete: { template in
                                store.deleteCustomWorkout(template.id)
                            }
                        )
                    }

                    SavedWorkoutsLibraryCard(
                        items: store.savedWorkouts,
                        insightFor: { item in
                            store.savedWorkoutInsight(for: item)
                        },
                        onStart: { item in
                            workoutFinished = false
                            isShowingPainFlow = false
                            store.startSavedWorkout(item)
                        },
                        onWithBuddy: { item in
                            store.startSavedWorkoutWithBuddy(item)
                        },
                        onDuplicate: { item in
                            store.duplicateSavedWorkout(item)
                        },
                        onTogglePin: { item in
                            store.togglePinnedSavedWorkout(item)
                        },
                        onRemove: { item in
                            store.removeSavedWorkout(item)
                        }
                    )
                }

                if !store.catalogWorkouts.isEmpty {
                    TrainExpandableSection(
                        title: "Discover",
                        subtitle: "\(store.discoverWorkouts.count) workouts organized by training type — strength to recovery and everything between.",
                        isExpanded: $showDiscover
                    ) {
                        DiscoverCatalogSection(
                            onStart: { template in
                                workoutFinished = false
                                isShowingPainFlow = false
                                store.startCatalogWorkout(template)
                            }
                        )
                    }
                }

                TrainExpandableSection(
                    title: "Exercise list",
                    subtitle: "\(store.currentWorkout.exercises.count) moves in today's plan. Open it when you want detail, not before you need it.",
                    isExpanded: $showExerciseList
                ) {
                    TrainUtilityCard(
                        isCompact: store.prefersCompactExerciseView,
                        onSelectCompact: { isCompact in
                            store.setCompactExerciseView(isCompact)
                        }
                    )

                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(store.currentWorkout.exercises) { exercise in
                            if store.prefersCompactExerciseView {
                                ExerciseCompactRow(
                                    exercise: exercise,
                                    onViewForm: { store.showExerciseDetail(for: exercise) },
                                    onSwap: { swapTarget = exercise }
                                )
                            } else {
                                ExercisePlanCard(
                                    exercise: exercise,
                                    onViewForm: { store.showExerciseDetail(for: exercise) },
                                    onSwap: { swapTarget = exercise }
                                )
                            }
                        }
                    }
                }

                TrainExpandableSection(
                    title: "Adjust today",
                    subtitle: "Shorten it, recover, or swap the day without losing the habit.",
                    isExpanded: $showAdjustments
                ) {
                    SmartPlanAdjustmentCard(adjustment: store.currentPlanAdjustment)

                    AddSwitchWorkoutCard { option in
                        store.applyWorkoutAdjustment(option)
                        if option == .recovery || option == .shorter || option == .easier {
                            workoutFinished = false
                        }
                    }
                }

                TrainExpandableSection(
                    title: "Form help and history",
                    subtitle: "Open your library help or check recent sessions without crowding the start of the workout page.",
                    isExpanded: $showHistory
                ) {
                    GlassCard {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Need form help or substitutions?")
                                .font(.headline)
                                .foregroundStyle(.white)
                            Text("Open More for the anatomy view, exercise library, quick swaps, and beginner-friendly form help.")
                                .foregroundStyle(MorpheTheme.textSecondary)
                            HStack(spacing: 10) {
                                Button("Open Exercise Library") {
                                    store.openMore(.library)
                                }
                                .buttonStyle(PrimaryCTAButtonStyle(accent: MorpheTheme.accentAlt))

                                Button("Quick Tools") {
                                    store.openMore(.tools)
                                }
                                .buttonStyle(SecondaryCTAButtonStyle())
                            }
                        }
                    }

                    WorkoutHistoryCard(entries: store.workoutHistory)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 120)
        }
    }

    private func warmupText(for sport: SportFocus) -> String {
        switch sport {
        case .boxing:
            return "Jump rope 3 minutes, shoulder circles, ankle prep, and 1 easy shadowboxing round."
        case .soccer:
            return "Dynamic warm-up, hip openers, and 2 short acceleration buildups."
        case .basketball:
            return "Mobility flow, pogo hops, and 2 rounds of defensive slides."
        default:
            return "5 minutes of easy movement, joint prep, and one ramp-up set for the first exercise."
        }
    }

    private func targetSetCount(for exercise: WorkoutExercise) -> Int {
        // Mirrors the store's parser: first integer anywhere in the string.
        Int(
            exercise.sets
                .components(separatedBy: CharacterSet.decimalDigits.inverted)
                .first { !$0.isEmpty } ?? ""
        ) ?? 1
    }

    private func suggestedRepCount(for exercise: WorkoutExercise) -> Int {
        Int(
            exercise.reps
                .components(separatedBy: CharacterSet.decimalDigits.inverted)
                .first(where: { !$0.isEmpty }) ?? "10"
        ) ?? 10
    }

    private func quickRepOptions(for exercise: WorkoutExercise) -> [Int] {
        let suggested = suggestedRepCount(for: exercise)
        let options = [max(suggested - 2, 1), suggested, min(suggested + 2, 30)]
        return Array(NSOrderedSet(array: options)) as? [Int] ?? options
    }

    private var postWorkoutPrompt: PostWorkoutPromptConfiguration? {
        guard store.hasCompletedWorkoutFlow else { return nil }

        let isRecoverySession = store.currentWorkout.category == .recovery || store.currentWorkout.name == "Low Energy Recovery Day"
        let currentWorkoutIsPinnedFavorite = store.savedWorkouts.contains {
            $0.workoutTemplateID == store.currentWorkout.id && $0.isPinned
        }

        // Share / Message Coach / Invite Buddy are multi-user surfaces — in
        // solo v1 they dead-ended into hidden screens.
        if FeatureFlags.multiUserEnabled {
            let isBuddySession = store.partnerWorkoutEnabled && store.selectedWorkoutPartner != nil
            if isBuddySession {
                return PostWorkoutPromptConfiguration(
                    title: "Keep the shared momentum going",
                    detail: "You finished together. Share the session or lock in the next one while the accountability is still warm.",
                    actions: [.share, .inviteBuddy]
                )
            }
            if !isRecoverySession {
                return PostWorkoutPromptConfiguration(
                    title: currentWorkoutIsPinnedFavorite ? "Nice work. Keep the loop moving." : "This one is worth keeping close",
                    detail: currentWorkoutIsPinnedFavorite
                        ? "You already trust this session. Share it or send a quick note to your coach before you close the day."
                        : "If this session landed well, pin it as a favorite or share the win before you move on.",
                    actions: currentWorkoutIsPinnedFavorite ? [.share, .messageCoach] : [.saveFavorite, .share]
                )
            }
        }

        if isRecoverySession {
            return PostWorkoutPromptConfiguration(
                title: "Turn the lighter day into real momentum",
                detail: "Recovery still counts when it keeps the week honest. Save the session or log a quick reset before you move on.",
                actions: [.recoveryReset, .saveFavorite]
            )
        }

        // Solo: only offer what actually works. A pinned favorite needs
        // nothing more — no card beats a card full of dead buttons.
        guard !currentWorkoutIsPinnedFavorite else { return nil }
        return PostWorkoutPromptConfiguration(
            title: "This one is worth keeping close",
            detail: "If this session landed well, pin it as a favorite so it's one tap away next time.",
            actions: [.saveFavorite]
        )
    }

    private func handlePostWorkoutAction(_ action: PostWorkoutPromptAction) {
        switch action {
        case .messageCoach:
            store.openPostWorkoutCoachThread()
        case .share:
            store.sharePostWorkoutHighlight()
        case .inviteBuddy:
            store.openPostWorkoutBuddyThread()
        case .saveFavorite:
            store.saveCurrentWorkoutAsFavorite()
        case .recoveryReset:
            store.logRecoveryReset()
        }
    }
}

private struct PostWorkoutPromptConfiguration: Hashable {
    let title: String
    let detail: String
    let actions: [PostWorkoutPromptAction]
}

private enum PostWorkoutPromptAction: String, CaseIterable, Identifiable {
    case messageCoach = "Message Coach"
    case share = "Share"
    case inviteBuddy = "Invite Buddy"
    case saveFavorite = "Save as Favorite"
    case recoveryReset = "Recovery Reset"

    var id: String { rawValue }

    var systemImage: String {
        switch self {
        case .messageCoach:
            return "message.fill"
        case .share:
            return "arrowshape.turn.up.right.fill"
        case .inviteBuddy:
            return "person.2.fill"
        case .saveFavorite:
            return "pin.fill"
        case .recoveryReset:
            return "heart.text.square.fill"
        }
    }
}

/// Shown in the live session once every planned set is logged — the loop's
/// "you're done" signal, with the finish action right there.
private struct WorkoutCompleteCard: View {
    let workoutName: String
    let totalSets: Int
    let onFinish: () -> Void

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 10) {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.title2)
                        .foregroundStyle(MorpheTheme.accent)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("All sets logged")
                            .font(.system(.title3, design: .rounded).weight(.bold))
                            .foregroundStyle(.white)
                        Text("\(workoutName) • \(totalSets) sets in the books.")
                            .font(.subheadline)
                            .foregroundStyle(MorpheTheme.textSecondary)
                    }
                }

                Button("Finish Session", action: onFinish)
                    .buttonStyle(PrimaryCTAButtonStyle(accent: MorpheTheme.accent))
            }
        }
        .accessibilityElement(children: .combine)
    }
}

/// Post-finish recap of what was actually logged, exercise by exercise, so the
/// user reviews real numbers before the session becomes a WorkoutLog.
private struct SessionRecapCard: View {
    let items: [WorkoutSetRecap]
    let weightUnit: WeightUnit

    private var totalSets: Int {
        items.reduce(0) { $0 + $1.reps.count }
    }

    private func setLine(_ item: WorkoutSetRecap) -> String {
        item.reps.indices
            .map { index in
                let weight = item.weights.indices.contains(index) ? item.weights[index] : 0
                let rpe = item.rpes.indices.contains(index) ? item.rpes[index] : 0
                var line = weight > 0 ? "\(item.reps[index]) × \(weightUnit.format(weight))" : "\(item.reps[index]) reps"
                if rpe > 0 { line += " @\(rpe)" }
                return line
            }
            .joined(separator: ", ")
    }

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Session Recap")
                        .font(.headline)
                        .foregroundStyle(.white)
                    Spacer()
                    Text("\(totalSets) sets")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(MorpheTheme.accent)
                }

                if items.isEmpty {
                    Text("No sets were logged this session.")
                        .font(.subheadline)
                        .foregroundStyle(MorpheTheme.textSecondary)
                } else {
                    ForEach(items) { item in
                        VStack(alignment: .leading, spacing: 3) {
                            Text(item.name)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.white)
                            Text(setLine(item))
                                .font(.caption)
                                .foregroundStyle(MorpheTheme.textSecondary)
                        }
                        .accessibilityElement(children: .combine)
                    }
                }
            }
        }
    }
}

private struct PostWorkoutSmartActionCard: View {
    let prompt: PostWorkoutPromptConfiguration
    let onSelect: (PostWorkoutPromptAction) -> Void

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 14) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Before you move on")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(MorpheTheme.textMuted)
                    Text(prompt.title)
                        .font(.headline)
                        .foregroundStyle(.white)
                    Text(prompt.detail)
                        .font(.subheadline)
                        .foregroundStyle(MorpheTheme.textSecondary)
                }

                VStack(spacing: 10) {
                    ForEach(prompt.actions) { action in
                        Button {
                            onSelect(action)
                        } label: {
                            HStack(spacing: 10) {
                                Image(systemName: action.systemImage)
                                    .font(.subheadline.weight(.semibold))
                                Text(action.rawValue)
                                    .font(.subheadline.weight(.semibold))
                                Spacer()
                            }
                            .foregroundStyle(.white)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 12)
                            .frame(maxWidth: .infinity)
                            .background(
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .fill(MorpheTheme.panelStrong)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }

                Text("Log the workout when you're ready and Morphe will update Progress from there.")
                    .font(.caption)
                    .foregroundStyle(MorpheTheme.textMuted)
            }
        }
    }
}

private struct LiveWorkoutConsoleCard: View {
    let workout: WorkoutTemplate
    let exerciseIndex: Int
    let totalExercises: Int
    let warmupText: String
    @Binding var restSeconds: Int
    @Binding var restRunning: Bool

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Live Session")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(MorpheTheme.textMuted)
                        Text(workout.name)
                            .font(.title3.weight(.bold))
                            .foregroundStyle(.white)
                    }

                    Spacer()

                    StatusBadge(
                        text: "Exercise \(min(exerciseIndex + 1, totalExercises)) / \(totalExercises)",
                        color: MorpheTheme.accent
                    )
                }

                WorkoutFlowChipRail(
                    workoutStarted: true,
                    workoutFinished: false,
                    isLogged: false
                )

                Text("Log the work here and let everything else wait until the session is done.")
                    .font(.caption)
                    .foregroundStyle(MorpheTheme.textSecondary)

                VStack(alignment: .leading, spacing: 8) {
                    Text("Warm-up")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                    Text(warmupText)
                        .font(.subheadline)
                        .foregroundStyle(MorpheTheme.textSecondary)
                }

                WorkoutRestControlBar(seconds: $restSeconds, isRunning: $restRunning)
            }
        }
    }
}

private struct WorkoutFlowChipRail: View {
    let workoutStarted: Bool
    let workoutFinished: Bool
    let isLogged: Bool

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                FlowStepChip(title: "Start", isActive: true)
                FlowStepChip(title: "Track", isActive: workoutStarted)
                FlowStepChip(title: "Finish", isActive: workoutFinished)
                FlowStepChip(title: "Feedback", isActive: workoutFinished)
                FlowStepChip(title: "Progress", isActive: isLogged)
            }
        }
    }
}

private struct FlowStepChip: View {
    let title: String
    let isActive: Bool

    var body: some View {
        Text(title)
            .font(.caption.weight(.semibold))
            .foregroundStyle(isActive ? .black : .white)
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(isActive ? MorpheTheme.accent : MorpheTheme.panelStrong)
            )
    }
}

private struct TrainExpandableSection<Content: View>: View {
    let title: String
    let subtitle: String
    @Binding var isExpanded: Bool
    @ViewBuilder let content: () -> Content

    var body: some View {
        // Flat HUD disclosure — tracked mono label, hairline rule, +/- state.
        VStack(alignment: .leading, spacing: 12) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isExpanded.toggle()
                }
            } label: {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 10) {
                        Text(title.uppercased())
                            .font(MorpheTheme.microLabel(12))
                            .tracking(1.6)
                            .foregroundStyle(.white)
                            .lineLimit(1)
                            .layoutPriority(1)

                        Rectangle()
                            .fill(MorpheTheme.stroke)
                            .frame(height: 1)
                            .frame(maxWidth: .infinity)

                        Image(systemName: isExpanded ? "minus" : "plus")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(MorpheTheme.accent)
                    }

                    if !isExpanded {
                        Text(subtitle)
                            .font(.footnote)
                            .foregroundStyle(MorpheTheme.textMuted)
                            .multilineTextAlignment(.leading)
                    }
                }
                .padding(.vertical, 6)
                .contentShape(Rectangle())
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

private struct ActiveWorkoutTrackerCard: View {
    let workout: WorkoutTemplate
    let exercise: WorkoutExercise
    let exerciseIndex: Int
    let totalExercises: Int
    let completedSets: Int
    let totalSets: Int
    let nextExercise: WorkoutExercise?
    let suggestedReps: Int
    let quickRepOptions: [Int]
    let repsLogged: [Int]
    let weightsLogged: [Double]
    @Binding var weight: Double
    let weightUnit: WeightUnit
    let onPrevious: () -> Void
    let onQuickLogSet: (Int) -> Void
    let onOpenCustomRepLogger: () -> Void
    let onEditSet: (Int) -> Void
    let onDeleteSet: (Int) -> Void
    let onNext: () -> Void
    let onStartRest: () -> Void
    let canGoPrevious: Bool

    private var isExerciseComplete: Bool {
        completedSets >= totalSets
    }

    private var setProgress: Double {
        guard totalSets > 0 else { return 0 }
        return min(Double(completedSets) / Double(totalSets), 1)
    }

    /// Step size that feels right per unit (5 lb / 2.5 kg).
    private var weightStep: Double {
        weightUnit == .kilograms ? 2.5 : 5
    }

    private var weightDisplay: String {
        weight > 0 ? weightUnit.format(weight) : "Bodyweight"
    }

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Active Workout")
                            .font(.headline)
                            .foregroundStyle(.white)
                        Text("\(workout.name) • Exercise \(exerciseIndex + 1) of \(totalExercises)")
                            .foregroundStyle(MorpheTheme.textSecondary)
                    }
                    Spacer()
                    MetricPill(label: "Sets", value: "\(completedSets)/\(totalSets)")
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text(exercise.name)
                        .font(.title3.weight(.bold))
                        .foregroundStyle(.white)
                    Text("\(exercise.sets) • \(exercise.reps) • \(exercise.difficulty.rawValue)")
                        .foregroundStyle(MorpheTheme.textSecondary)
                    ProgressBarView(progress: setProgress, color: MorpheTheme.accent)
                    Text(exercise.formCue)
                        .font(.caption)
                        .foregroundStyle(MorpheTheme.textPrimary)
                }

                // Every logged set stays visible and editable — a fat-fingered
                // entry is a tap away from being fixed, not permanent.
                if !repsLogged.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(Array(repsLogged.enumerated()), id: \.offset) { index, reps in
                            HStack(spacing: 10) {
                                Text("Set \(index + 1)")
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(MorpheTheme.accentAlt)
                                    .frame(width: 44, alignment: .leading)

                                Text("\(reps) reps · \(weightUnit.format(weightsLogged.indices.contains(index) ? weightsLogged[index] : 0))")
                                    .font(.caption)
                                    .foregroundStyle(.white)

                                Spacer(minLength: 0)

                                Button {
                                    onEditSet(index)
                                } label: {
                                    Image(systemName: "pencil")
                                        .font(.caption)
                                        .frame(width: 28, height: 28)
                                        .background(Circle().fill(MorpheTheme.panelStrong))
                                }
                                .buttonStyle(.plain)
                                .foregroundStyle(.white)
                                .accessibilityLabel("Edit set \(index + 1)")

                                Button {
                                    onDeleteSet(index)
                                } label: {
                                    Image(systemName: "trash")
                                        .font(.caption)
                                        .frame(width: 28, height: 28)
                                        .background(Circle().fill(MorpheTheme.panelStrong))
                                }
                                .buttonStyle(.plain)
                                .foregroundStyle(MorpheTheme.danger)
                                .accessibilityLabel("Delete set \(index + 1)")
                            }
                        }
                    }
                    .padding(10)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(MorpheTheme.panelStrong.opacity(0.6))
                    )
                }

                HStack(spacing: 8) {
                    MetricPill(label: "Muscle", value: exercise.muscleGroup.rawValue)
                    MetricPill(label: "Target", value: exercise.reps)
                }

                if let nextExercise {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Up next")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(MorpheTheme.textMuted)
                        Text(nextExercise.name)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.white)
                        Text("\(nextExercise.sets) • \(nextExercise.reps)")
                            .font(.caption)
                            .foregroundStyle(MorpheTheme.textSecondary)
                    }
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(MorpheTheme.panelStrong)
                    )
                }

                // Inline weight for the set about to be logged. Pre-fills from
                // the last set and carries forward, so the quick-log buttons
                // capture real load (not bodyweight) without a second screen.
                HStack(spacing: 12) {
                    Text("Weight")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(MorpheTheme.textSecondary)

                    Spacer()

                    Button {
                        weight = max(0, weight - weightStep)
                    } label: {
                        Image(systemName: "minus")
                            .frame(width: 34, height: 34)
                    }
                    .buttonStyle(.plain)
                    .background(Circle().fill(MorpheTheme.panelStrong))
                    .foregroundStyle(.white)
                    .disabled(weight <= 0)
                    .accessibilityLabel("Decrease weight")

                    Text(weightDisplay)
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(minWidth: 96)
                        .accessibilityLabel("Weight \(weightDisplay)")

                    Button {
                        weight += weightStep
                    } label: {
                        Image(systemName: "plus")
                            .frame(width: 34, height: 34)
                    }
                    .buttonStyle(.plain)
                    .background(Circle().fill(MorpheTheme.panelStrong))
                    .foregroundStyle(.white)
                    .accessibilityLabel("Increase weight")
                }
                .padding(.vertical, 4)

                if isExerciseComplete {
                    HStack(spacing: 8) {
                        Button {
                            onOpenCustomRepLogger()
                        } label: {
                            Label("Add extra set", systemImage: "plus.circle")
                        }
                        .buttonStyle(SecondaryCTAButtonStyle())

                        Button("Rest", action: onStartRest)
                            .buttonStyle(SecondaryCTAButtonStyle())
                            .accessibilityLabel("Start rest timer")
                    }
                } else {
                    HStack(spacing: 8) {
                        Button("Log \(suggestedReps)", action: { onQuickLogSet(suggestedReps) })
                            .buttonStyle(PrimaryCTAButtonStyle(accent: MorpheTheme.accent))
                            .accessibilityLabel("Log set: \(suggestedReps) reps at \(weightDisplay)")

                        Button("Custom") {
                            onOpenCustomRepLogger()
                        }
                        .buttonStyle(SecondaryCTAButtonStyle())
                        .accessibilityLabel("Log a custom set")

                        Button("Rest", action: onStartRest)
                            .buttonStyle(SecondaryCTAButtonStyle())
                            .accessibilityLabel("Start rest timer")
                    }
                }

                WrapStack(spacing: 8) {
                    if !isExerciseComplete {
                        ForEach(quickRepOptions, id: \.self) { reps in
                            Button("\(reps) reps") {
                                onQuickLogSet(reps)
                            }
                            .buttonStyle(FilterChipStyle(isSelected: reps == suggestedReps, selectedColor: MorpheTheme.accent))
                        }
                    }

                    if canGoPrevious {
                        Button("Previous", action: onPrevious)
                            .buttonStyle(FilterChipStyle(isSelected: false, selectedColor: MorpheTheme.panelStrong))
                    }

                    Button("Next", action: onNext)
                        .buttonStyle(FilterChipStyle(isSelected: false, selectedColor: MorpheTheme.accentAlt))
                }
            }
        }
    }
}

private struct FocusedWorkoutQueueCard: View {
    let exercises: [WorkoutExercise]
    let activeExerciseID: String?
    let completedWorkoutSets: [String: Int]

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("Session Queue")
                    .font(.headline)
                    .foregroundStyle(.white)

                ForEach(exercises) { exercise in
                    HStack(spacing: 10) {
                        Circle()
                            .fill(activeExerciseID == exercise.id ? MorpheTheme.accent : MorpheTheme.panelStrong)
                            .frame(width: 10, height: 10)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(exercise.name)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.white)
                            Text("\(exercise.sets) • \(exercise.reps)")
                                .font(.caption)
                                .foregroundStyle(MorpheTheme.textSecondary)
                        }

                        Spacer()

                        if let loggedSets = completedWorkoutSets[exercise.id], loggedSets > 0 {
                            Text("\(loggedSets) logged")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(MorpheTheme.accentAlt)
                        }
                    }
                }
            }
        }
    }
}

private struct LiveWorkoutSupportToolsCard: View {
    @Environment(MorpheAppStore.self) private var store
    let workout: WorkoutTemplate
    let exercise: WorkoutExercise
    let completedSets: Int
    let totalSets: Int
    let canGoPrevious: Bool
    let onPrevious: () -> Void
    let onSwap: () -> Void
    let onPain: () -> Void
    let onViewForm: () -> Void
    @State private var inlineAIReply: String?
    @State private var inlineAIContextTitle = "Morphe assist"

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("Support tools")
                    .font(.headline)
                    .foregroundStyle(.white)

                Text("Use these only when you need help. The active set stays above; swaps, pain-safe changes, and Morphe guidance stay here.")
                    .font(.subheadline)
                    .foregroundStyle(MorpheTheme.textSecondary)

                WrapStack(spacing: 8) {
                    if canGoPrevious {
                        Button("Previous exercise", action: onPrevious)
                            .buttonStyle(FilterChipStyle(isSelected: false, selectedColor: MorpheTheme.panelStrong))
                    }

                    Button("Swap exercise", action: onSwap)
                        .buttonStyle(FilterChipStyle(isSelected: false, selectedColor: MorpheTheme.accentAlt))

                    // Form questions happen mid-set — the full guide (steps,
                    // mistakes, alternatives) opens right here now.
                    Button("Form guide", action: onViewForm)
                        .buttonStyle(FilterChipStyle(isSelected: false, selectedColor: MorpheTheme.accent))

                    Button("Pain flag", action: onPain)
                        .buttonStyle(FilterChipStyle(isSelected: false, selectedColor: MorpheTheme.warning))
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Morphe can help mid-session")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(MorpheTheme.textMuted)

                    WrapStack(spacing: 8) {
                        Button("Explain cue") {
                            showInlineAIReply(
                                title: "Explain cue",
                                prompt: "Explain the main cue for \(exercise.name) in one short sentence for an athlete mid-workout."
                            )
                        }
                        .buttonStyle(FilterChipStyle(isSelected: inlineAIContextTitle == "Explain cue", selectedColor: MorpheTheme.accentAlt))

                        Button("Safer option") {
                            showInlineAIReply(
                                title: "Safer option",
                                prompt: "Give me a safer option for \(exercise.name) in one short sentence without derailing the workout."
                            )
                        }
                        .buttonStyle(FilterChipStyle(isSelected: inlineAIContextTitle == "Safer option", selectedColor: MorpheTheme.warning))

                        Button("Adjust next set") {
                            showInlineAIReply(
                                title: "Adjust next set",
                                prompt: "I have completed \(completedSets) of \(totalSets) sets for \(exercise.name). Tell me how to adjust the next set in one short sentence."
                            )
                        }
                        .buttonStyle(FilterChipStyle(isSelected: inlineAIContextTitle == "Adjust next set", selectedColor: MorpheTheme.accent))

                        Button("Too easy") {
                            showInlineAIReply(
                                title: "Too easy",
                                prompt: "\(exercise.name) feels too easy. Adjust the next set in one short sentence."
                            )
                        }
                        .buttonStyle(FilterChipStyle(isSelected: inlineAIContextTitle == "Too easy", selectedColor: MorpheTheme.accent))

                        Button("Too hard") {
                            showInlineAIReply(
                                title: "Too hard",
                                prompt: "\(exercise.name) feels too hard. Give me a lighter next set in one short sentence."
                            )
                        }
                        .buttonStyle(FilterChipStyle(isSelected: inlineAIContextTitle == "Too hard", selectedColor: MorpheTheme.warning))

                        Button("Short on time") {
                            showInlineAIReply(
                                title: "Short on time",
                                prompt: "I'm short on time. Tell me how to finish the rest of \(workout.name) cleanly in one short sentence."
                            )
                        }
                        .buttonStyle(FilterChipStyle(isSelected: inlineAIContextTitle == "Short on time", selectedColor: MorpheTheme.lavender))
                    }
                }

                if let inlineAIReply {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(inlineAIContextTitle)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(MorpheTheme.accentAlt)
                        Text(inlineAIReply)
                            .font(.subheadline)
                            .foregroundStyle(MorpheTheme.textPrimary)
                    }
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(MorpheTheme.panelStrong)
                    )
                }
            }
        }
    }

    private func showInlineAIReply(title: String, prompt: String) {
        inlineAIContextTitle = title
        inlineAIReply = store.previewAIAgentReply(for: prompt)
    }
}

/// Browsable catalog of bundled Morphe Programs with faceted filters —
/// Stage A of the content pipeline (becomes the Firestore-backed feed with
/// engagement ranking once the backend lands).
private struct DiscoverCatalogSection: View {
    @Environment(MorpheAppStore.self) private var store
    let onStart: (WorkoutTemplate) -> Void

    @State private var trainingTypeFilter: String?
    @State private var collectionFilter: String?
    @State private var focusFilter: String?
    @State private var levelFilter: DemoDifficulty?
    @State private var durationFilter: String?
    @State private var equipmentFilter: String?

    /// Time filters are ranges, not exact matches — sport sessions run
    /// 15/24/36/38-min lengths, so exact chips made Time + Sport-specific
    /// always return zero results.
    private static let durationBuckets = ["Under 25 min", "25–40 min", "Over 40 min"]

    private func durationBucket(_ minutes: Int) -> String {
        if minutes < 25 { return "Under 25 min" }
        if minutes <= 40 { return "25–40 min" }
        return "Over 40 min"
    }
    @State private var visibleCount = 12

    /// The product's canonical training taxonomy, in presentation order.
    private static let trainingTypeOrder = [
        "Strength training", "Hypertrophy training", "Muscular endurance",
        "Cardiovascular endurance", "HIIT", "Power training",
        "Speed & agility training", "Mobility training", "Flexibility training",
        "Functional training", "Calisthenics", "Circuit training",
        "Cross-training", "Plyometric training", "Balance & stability training",
        "Core training", "Sport-specific training", "Recovery training"
    ]

    private var trainingTypeOptions: [String] {
        let present = Set(store.discoverWorkouts.map(\.trainingTypeTag))
        return Self.trainingTypeOrder.filter { present.contains($0) }
    }

    private var collectionOptions: [String] {
        Array(Set(store.discoverWorkouts.map(\.type))).sorted()
    }

    private var focusOptions: [String] {
        var seen: Set<String> = []
        return store.discoverWorkouts.compactMap { template in
            guard !template.focusTag.isEmpty, !seen.contains(template.focusTag) else { return nil }
            seen.insert(template.focusTag)
            return template.focusTag
        }
    }

    private var filtered: [WorkoutTemplate] {
        store.discoverWorkouts.filter { template in
            (trainingTypeFilter == nil || template.trainingTypeTag == trainingTypeFilter)
                && (collectionFilter == nil || template.type == collectionFilter)
                && (focusFilter == nil || template.focusTag == focusFilter)
                && (levelFilter == nil || template.difficulty == levelFilter)
                && (durationFilter == nil || durationBucket(template.durationMinutes) == durationFilter)
                && (equipmentFilter == nil || template.equipment == equipmentFilter)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            GlassCard {
                VStack(alignment: .leading, spacing: 12) {
                    // Training type is the primary organizing facet.
                    filterRow("Training type", options: trainingTypeOptions, selection: $trainingTypeFilter) { $0 }
                    if collectionOptions.count > 1 {
                        filterRow("Collection", options: collectionOptions, selection: $collectionFilter) { $0 }
                    }
                    filterRow("Focus", options: focusOptions, selection: $focusFilter) { $0 }
                    filterRow("Level", options: [DemoDifficulty.beginner, .moderate, .advanced], selection: $levelFilter) { $0.rawValue }
                    filterRow("Time", options: Self.durationBuckets, selection: $durationFilter) { $0 }
                    filterRow("Equipment", options: ["Bodyweight", "Dumbbells", "Full Gym"], selection: $equipmentFilter) { $0 }

                    Text("\(filtered.count) workout\(filtered.count == 1 ? "" : "s")")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(MorpheTheme.accentAlt)
                }
            }

            if filtered.isEmpty {
                GlassCard {
                    Text("No programs match those filters — loosen one and try again.")
                        .font(.subheadline)
                        .foregroundStyle(MorpheTheme.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            } else {
                ForEach(filtered.prefix(visibleCount)) { template in
                    DiscoverWorkoutCard(
                        template: template,
                        isSaved: store.isCatalogWorkoutSaved(template),
                        onStart: { onStart(template) },
                        onSave: { store.saveCatalogWorkout(template) }
                    )
                }

                if filtered.count > visibleCount {
                    Button("Show more (\(filtered.count - visibleCount) left)") {
                        visibleCount += 12
                    }
                    .buttonStyle(SecondaryCTAButtonStyle())
                }
            }
        }
        .onChange(of: trainingTypeFilter) { _, _ in visibleCount = 12 }
        .onChange(of: collectionFilter) { _, _ in visibleCount = 12 }
        .onChange(of: focusFilter) { _, _ in visibleCount = 12 }
        .onChange(of: levelFilter) { _, _ in visibleCount = 12 }
        .onChange(of: durationFilter) { _, _ in visibleCount = 12 }
        .onChange(of: equipmentFilter) { _, _ in visibleCount = 12 }
    }

    private func filterRow<Option: Hashable>(
        _ label: String,
        options: [Option],
        selection: Binding<Option?>,
        title: @escaping (Option) -> String
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.caption.weight(.semibold))
                .foregroundStyle(MorpheTheme.textMuted)
            WrapStack(spacing: 8) {
                ForEach(options, id: \.self) { option in
                    Button(title(option)) {
                        selection.wrappedValue = selection.wrappedValue == option ? nil : option
                    }
                    .buttonStyle(FilterChipStyle(isSelected: selection.wrappedValue == option, selectedColor: MorpheTheme.accentAlt))
                }
            }
        }
    }
}

private struct DiscoverWorkoutCard: View {
    let template: WorkoutTemplate
    let isSaved: Bool
    let onStart: () -> Void
    let onSave: () -> Void

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(template.name)
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(.white)
                        Text("\(template.durationMinutes) min • \(template.equipment) • \(template.exercises.count) exercises")
                            .font(.caption)
                            .foregroundStyle(MorpheTheme.textSecondary)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 4) {
                        if template.type != "Morphe Program" {
                            StatusBadge(text: template.type, color: MorpheTheme.accent)
                        }
                        StatusBadge(text: template.focusTag, color: MorpheTheme.accentAlt)
                    }
                }

                Text(template.goal)
                    .font(.caption)
                    .foregroundStyle(MorpheTheme.textMuted)

                HStack(spacing: 8) {
                    Button("Start", action: onStart)
                        .buttonStyle(PrimaryCTAButtonStyle(accent: MorpheTheme.accent))
                        .accessibilityLabel("Start \(template.name)")

                    Button {
                        onSave()
                    } label: {
                        Image(systemName: isSaved ? "bookmark.fill" : "bookmark")
                            .frame(width: 44, height: 24)
                    }
                    .buttonStyle(SecondaryCTAButtonStyle())
                    .frame(width: 64)
                    .accessibilityLabel(isSaved ? "\(template.name) saved" : "Save \(template.name) to My Library")
                }
            }
        }
        .accessibilityElement(children: .contain)
    }
}

/// THE workout card on Train — the same session the Today hero shows, with
/// one Start. Morphe's readiness-based pick appears as an inline suggestion
/// ("use this instead"), not a competing card with its own name.
private struct TodaysWorkoutCard: View {
    let workout: WorkoutTemplate
    let suggestion: GoodForTodayWorkoutRecommendation?
    let onStart: () -> Void
    let onUseSuggestion: () -> Void
    let onSwitch: () -> Void

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("Today's Workout")
                    .font(.headline)
                    .foregroundStyle(.white)

                VStack(alignment: .leading, spacing: 4) {
                    Text(workout.name)
                        .font(.title3.weight(.bold))
                        .foregroundStyle(.white)
                    Text("\(workout.durationMinutes) min • \(workout.goal)")
                        .font(.subheadline)
                        .foregroundStyle(MorpheTheme.textSecondary)
                }

                if !workout.coachNote.isEmpty {
                    Text(workout.coachNote)
                        .font(.caption)
                        .foregroundStyle(MorpheTheme.textPrimary)
                }

                HStack(spacing: 10) {
                    Button("Start", action: onStart)
                        .buttonStyle(PrimaryCTAButtonStyle(accent: MorpheTheme.accent))
                        .accessibilityLabel("Start \(workout.name)")

                    Button("Switch", action: onSwitch)
                        .buttonStyle(SecondaryCTAButtonStyle())
                        .frame(width: 110)
                        .accessibilityLabel("Switch to a different workout")
                }

                if let suggestion {
                    Divider().overlay(Color.white.opacity(0.08))

                    VStack(alignment: .leading, spacing: 8) {
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "sparkles")
                                .font(.caption)
                                .foregroundStyle(MorpheTheme.accentAlt)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Morphe suggests: \(suggestion.workoutName)")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.white)
                                Text(suggestion.reasonTitle)
                                    .font(.caption)
                                    .foregroundStyle(MorpheTheme.textSecondary)
                            }
                            Spacer(minLength: 0)
                        }

                        Button("Use this instead", action: onUseSuggestion)
                            .buttonStyle(FilterChipStyle(isSelected: false, selectedColor: MorpheTheme.accentAlt))
                            .accessibilityLabel("Switch today's workout to \(suggestion.workoutName)")
                    }
                }
            }
        }
    }
}

private struct TrainUtilityCard: View {
    let isCompact: Bool
    let onSelectCompact: (Bool) -> Void

    var body: some View {
        GlassCard {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Workout Layout")
                        .font(.headline)
                        .foregroundStyle(.white)
                    Text("Switch between a detailed card view and a faster compact list.")
                        .foregroundStyle(MorpheTheme.textSecondary)
                }

                Spacer()

                HStack(spacing: 8) {
                    Button("Cards") {
                        onSelectCompact(false)
                    }
                    .buttonStyle(FilterChipStyle(isSelected: !isCompact, selectedColor: MorpheTheme.accent))

                    Button("Compact") {
                        onSelectCompact(true)
                    }
                    .buttonStyle(FilterChipStyle(isSelected: isCompact, selectedColor: MorpheTheme.accentAlt))
                }
            }
        }
    }
}

private struct PartnerSessionCard: View {
    let partner: WorkoutPartner
    let mode: PartnerWorkoutMode
    let plan: PartnerWorkoutPlan
    let onReadyCheck: () -> Void

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Partner Session")
                            .font(.headline)
                            .foregroundStyle(.white)
                        Text("\(partner.name) • \(mode.rawValue)")
                            .foregroundStyle(MorpheTheme.accentAlt)
                    }
                    Spacer()
                    MetricPill(label: "Buddy bonus", value: "+\(plan.xpBonus) XP")
                }

                Text(plan.detail)
                    .foregroundStyle(MorpheTheme.textSecondary)
                Text("Challenge: \(plan.miniChallenge)")
                    .font(.caption)
                    .foregroundStyle(MorpheTheme.textPrimary)

                Button("Send Ready Check", action: onReadyCheck)
                    .buttonStyle(SecondaryCTAButtonStyle())
            }
        }
    }
}

private struct WorkoutRestControlBar: View {
    @Binding var seconds: Int
    @Binding var isRunning: Bool
    @State private var countdownTask: Task<Void, Never>?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Rest Timer")
                    .font(.headline)
                    .foregroundStyle(.white)
                Spacer()
                Text(timeString)
                    .font(.system(.title, design: .rounded).weight(.bold))
                    .foregroundStyle(.white)
            }

            HStack(spacing: 8) {
                ForEach([30, 60, 120, 180], id: \.self) { preset in
                    Button("\(preset)s") {
                        seconds = preset
                    }
                    .buttonStyle(FilterChipStyle(isSelected: seconds == preset))
                }
            }

            HStack(spacing: 10) {
                Button(isRunning ? "Pause" : "Start") {
                    isRunning.toggle()
                }
                .buttonStyle(PrimaryCTAButtonStyle(accent: MorpheTheme.accentAlt))

                Button("Reset") {
                    isRunning = false
                    seconds = 180
                }
                .buttonStyle(SecondaryCTAButtonStyle())
            }
        }
        // The countdown is driven by the `isRunning` binding itself, so ANY
        // entry point (this bar's Start button or the tracker's Rest button)
        // starts the timer — not just the local toggle.
        .onChange(of: isRunning) { _, running in
            if running { startCountdown() } else { cancelCountdown() }
        }
        .onAppear {
            if isRunning { startCountdown() }
        }
        .onDisappear {
            cancelCountdown()
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Rest timer, \(timeString) remaining\(isRunning ? ", running" : "")")
    }

    private var timeString: String {
        let minutes = seconds / 60
        let remainingSeconds = seconds % 60
        return String(format: "%d:%02d", minutes, remainingSeconds)
    }

    private func startCountdown() {
        cancelCountdown()
        countdownTask = Task {
            while !Task.isCancelled && seconds > 0 {
                try? await Task.sleep(for: .seconds(1))
                if Task.isCancelled { return }
                if seconds > 0 { seconds -= 1 }
            }
            if !Task.isCancelled && seconds == 0 {
                isRunning = false
                Haptics.success()
            }
        }
    }

    private func cancelCountdown() {
        countdownTask?.cancel()
        countdownTask = nil
    }
}

private struct AddSwitchWorkoutCard: View {
    let onSelect: (WorkoutAdjustmentOption) -> Void

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("Need to adjust today?")
                    .font(.headline)
                    .foregroundStyle(.white)

                LazyVGrid(
                    columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)],
                    spacing: 10
                ) {
                    ForEach(WorkoutAdjustmentOption.allCases) { option in
                        Button(option.rawValue) {
                            onSelect(option)
                        }
                        .buttonStyle(SecondaryCTAButtonStyle())
                    }
                }
            }
        }
    }
}

private struct PainFlaggingCard: View {
    @Binding var painArea: String
    @Binding var painSeverity: Int
    @Binding var triggerExercise: String
    let painAreas: [String]
    let onSave: () -> Void

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("Pain / Injury Flag")
                    .font(.headline)
                    .foregroundStyle(.white)

                Menu(painArea) {
                    ForEach(painAreas, id: \.self) { area in
                        Button(area) {
                            painArea = area
                        }
                    }
                }
                .foregroundStyle(.white)

                Stepper("Severity: \(painSeverity) / 10", value: $painSeverity, in: 1...10)
                    .foregroundStyle(.white)

                TextField("Did it happen during a specific exercise or drill?", text: $triggerExercise)
                    .textFieldStyle(MorpheFieldStyle())

                Button("Save Pain Flag", action: onSave)
                    .buttonStyle(PrimaryCTAButtonStyle(accent: MorpheTheme.warning))
            }
        }
    }
}

private struct SetRepLoggingSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(MorpheAppStore.self) private var store
    @Binding var reps: Int
    @Binding var weight: Double
    @Binding var rpe: Int?
    let onSave: () -> Void

    @State private var weightText = ""
    @State private var showRPEHelp = false

    var body: some View {
        @Bindable var store = store
        return NavigationStack {
            ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 18) {
                HStack {
                    Text("Log your set")
                        .font(.title3.weight(.bold))
                        .foregroundStyle(.white)
                    Spacer()
                    Picker("Unit", selection: $store.weightUnit) {
                        ForEach(WeightUnit.allCases) { unit in
                            Text(unit.label).tag(unit)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 110)
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("Weight (\(store.weightUnit.label))")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(MorpheTheme.textSecondary)
                    HStack(spacing: 10) {
                        TextField("0", text: $weightText)
                            .keyboardType(.decimalPad)
                            .textFieldStyle(MorpheFieldStyle())
                        Text(store.weightUnit.label)
                            .font(.headline)
                            .foregroundStyle(MorpheTheme.textMuted)
                    }
                    Text("Leave at 0 for bodyweight.")
                        .font(.caption)
                        .foregroundStyle(MorpheTheme.textMuted)
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("Reps")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(MorpheTheme.textSecondary)
                    Stepper("\(reps) reps", value: $reps, in: 1...50)
                        .foregroundStyle(.white)
                    HStack(spacing: 8) {
                        ForEach([4, 6, 8, 10, 12, 15], id: \.self) { preset in
                            Button("\(preset)") {
                                reps = preset
                            }
                            .buttonStyle(FilterChipStyle(isSelected: reps == preset, selectedColor: MorpheTheme.accentAlt))
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("Effort (RPE) — optional")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(MorpheTheme.textSecondary)
                    HStack(spacing: 8) {
                        ForEach([6, 7, 8, 9, 10], id: \.self) { level in
                            Button("\(level)") {
                                rpe = (rpe == level) ? nil : level
                            }
                            .buttonStyle(FilterChipStyle(isSelected: rpe == level, selectedColor: MorpheTheme.accent))
                            .accessibilityLabel("RPE \(level)\(rpe == level ? ", selected" : "")")
                        }
                    }
                    HStack(spacing: 10) {
                        Text("10 = nothing left in the tank. Tap again to clear.")
                            .font(.caption)
                            .foregroundStyle(MorpheTheme.textMuted)

                        Spacer(minLength: 0)

                        // The RPE lesson, at the exact moment RPE is asked.
                        Button(showRPEHelp ? "Hide" : "What's RPE?") {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                showRPEHelp.toggle()
                            }
                        }
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(MorpheTheme.accentAlt)
                    }

                    if showRPEHelp,
                       let lesson = store.lessons.first(where: { $0.title == "The RPE Scale" }) {
                        Text(lesson.detail)
                            .font(.caption)
                            .foregroundStyle(MorpheTheme.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(10)
                            .background(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .fill(MorpheTheme.panelStrong.opacity(0.6))
                            )
                            .transition(.opacity)
                    }
                }

                HStack(spacing: 10) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .buttonStyle(SecondaryCTAButtonStyle())

                    Button("Log Set") {
                        weight = Double(weightText.trimmingCharacters(in: .whitespaces)) ?? 0
                        onSave()
                        dismiss()
                    }
                    .buttonStyle(PrimaryCTAButtonStyle(accent: MorpheTheme.accent))
                }

            }
            .padding(20)
            }
            .background(PremiumBackground())
            .onAppear { weightText = weight > 0 ? String(weight) : "" }
        }
    }
}

private struct WorkoutHistoryCard: View {
    let entries: [WorkoutHistoryEntry]

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("Workout History")
                    .font(.headline)
                    .foregroundStyle(.white)

                ForEach(entries) { entry in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(entry.title)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.white)
                            Spacer()
                            Text("\(entry.durationMinutes) min")
                                .font(.caption)
                                .foregroundStyle(MorpheTheme.textSecondary)
                        }

                        Text("\(entry.completedOn) - \(entry.result)")
                            .font(.caption)
                            .foregroundStyle(MorpheTheme.textSecondary)
                    }
                    .padding(.vertical, 4)
                }
            }
        }
    }
}

private struct SavedWorkoutsLibraryCard: View {
    @State private var selectedFilter: SavedWorkoutLibraryFilter = .all
    let items: [SavedWorkoutLibraryItem]
    let insightFor: (SavedWorkoutLibraryItem) -> SavedWorkoutLibraryInsight
    let onStart: (SavedWorkoutLibraryItem) -> Void
    let onWithBuddy: (SavedWorkoutLibraryItem) -> Void
    let onDuplicate: (SavedWorkoutLibraryItem) -> Void
    let onTogglePin: (SavedWorkoutLibraryItem) -> Void
    let onRemove: (SavedWorkoutLibraryItem) -> Void

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("Saved Workouts")
                    .font(.headline)
                    .foregroundStyle(.white)

                Text("Save coach and athlete workouts from around Morphe, then run them solo, with a buddy, or turn them into your own copy.")
                    .font(.subheadline)
                    .foregroundStyle(MorpheTheme.textSecondary)

                if !pinnedItems.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text("Pinned Quick Start")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.white)
                            Spacer()
                            Text("\(pinnedItems.count)/3 pinned")
                                .font(.caption)
                                .foregroundStyle(MorpheTheme.textSecondary)
                        }

                        ForEach(pinnedItems) { item in
                            let insight = insightFor(item)
                            VStack(alignment: .leading, spacing: 10) {
                                HStack(alignment: .top, spacing: 10) {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(item.workoutName)
                                            .font(.subheadline.weight(.semibold))
                                            .foregroundStyle(.white)
                                            .lineLimit(2)
                                        Text(item.sourceName)
                                            .font(.caption)
                                            .foregroundStyle(MorpheTheme.textSecondary)
                                            .lineLimit(1)
                                    }

                                    Spacer()

                                    StatusBadge(text: "Pinned", color: MorpheTheme.warning)
                                }

                                HStack(spacing: 8) {
                                    MetricPill(label: "Best for", value: item.bestFor.rawValue)
                                    MetricPill(label: "Completed", value: "\(insight.completionCount)x")
                                }

                                SavedWorkoutCompletionBadgeRow(
                                    badges: savedWorkoutBadges(for: item, insight: insight)
                                )

                                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 2), spacing: 8) {
                                    Button("Start") {
                                        onStart(item)
                                    }
                                    .buttonStyle(PrimaryCTAButtonStyle(accent: MorpheTheme.accent))

                                    if FeatureFlags.multiUserEnabled {
                                        Button("With Buddy") {
                                            onWithBuddy(item)
                                        }
                                        .buttonStyle(SecondaryCTAButtonStyle())
                                    }
                                }

                                Button("Unpin") {
                                    onTogglePin(item)
                                }
                                .buttonStyle(SecondaryCTAButtonStyle())
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
                }

                if !recentShortcutItems.isEmpty || !mostUsedShortcutItems.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        if !recentShortcutItems.isEmpty {
                            ShortcutWorkoutSection(
                                title: "Recent",
                                subtitle: "Jump back into what you ran lately.",
                                items: recentShortcutItems,
                                insightFor: insightFor,
                                onStart: onStart,
                                onWithBuddy: onWithBuddy
                            )
                        }

                        if !mostUsedShortcutItems.isEmpty {
                            ShortcutWorkoutSection(
                                title: "Most Used",
                                subtitle: "Your go-to sessions, based on real completions.",
                                items: mostUsedShortcutItems,
                                insightFor: insightFor,
                                onStart: onStart,
                                onWithBuddy: onWithBuddy
                            )
                        }
                    }
                }

                Picker("Saved workout filter", selection: $selectedFilter) {
                    ForEach(SavedWorkoutLibraryFilter.allCases) { filter in
                        Text(filter.rawValue).tag(filter)
                    }
                }
                .pickerStyle(.segmented)

                if filteredItems.isEmpty {
                    Text("Nothing saved yet. Save workouts from profiles or For You and they’ll show up here.")
                        .foregroundStyle(MorpheTheme.textSecondary)
                } else {
                    ForEach(filteredItems) { item in
                        let insight = insightFor(item)
                        VStack(alignment: .leading, spacing: 10) {
                            HStack(alignment: .top, spacing: 12) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(item.workoutName)
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(.white)
                                        .lineLimit(2)
                                    Text("\(item.sourceContext) • \(item.sourceName)")
                                        .font(.caption)
                                        .foregroundStyle(MorpheTheme.textSecondary)
                                        .lineLimit(2)
                                }

                                Spacer()

                                VStack(alignment: .trailing, spacing: 8) {
                                    StatusBadge(
                                        text: item.sourceRole == .coach ? "Coach source" : sourceBadgeText(for: item),
                                        color: sourceBadgeColor(for: item)
                                    )
                                    StatusBadge(
                                        text: "Best for \(item.bestFor.rawValue)",
                                        color: useCaseColor(for: item.bestFor)
                                    )
                                }
                            }

                            Text(item.note)
                                .font(.caption)
                                .foregroundStyle(MorpheTheme.textSecondary)
                                .lineLimit(3)

                            SavedWorkoutCompletionBadgeRow(
                                badges: savedWorkoutBadges(for: item, insight: insight)
                            )

                            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 2), spacing: 8) {
                                MetricPill(label: "Saved", value: MorpheAppStore.workoutDateLabel(for: item.savedAt))
                                MetricPill(label: "Completed", value: "\(insight.completionCount)x")
                                MetricPill(label: "Last run", value: insight.lastCompletedAt.map(MorpheAppStore.workoutDateLabel(for:)) ?? "Not yet")
                                MetricPill(label: "Mode", value: insight.hasBuddyCompletion ? "Buddy tried" : "Solo ready")
                            }

                            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 2), spacing: 8) {
                                Button("Start") {
                                    onStart(item)
                                }
                                .buttonStyle(SecondaryCTAButtonStyle())

                                if FeatureFlags.multiUserEnabled {
                                    Button("With Buddy") {
                                        onWithBuddy(item)
                                    }
                                    .buttonStyle(SecondaryCTAButtonStyle())
                                }

                                Button("Duplicate") {
                                    onDuplicate(item)
                                }
                                .buttonStyle(SecondaryCTAButtonStyle())

                                Button(item.isPinned ? "Unpin" : "Pin") {
                                    onTogglePin(item)
                                }
                                .buttonStyle(SecondaryCTAButtonStyle())
                            }

                            Button("Remove") {
                                onRemove(item)
                            }
                            .buttonStyle(SecondaryCTAButtonStyle())
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
        }
    }

    private var filteredItems: [SavedWorkoutLibraryItem] {
        let filtered: [SavedWorkoutLibraryItem]

        switch selectedFilter {
        case .all:
            filtered = items
        case .coach:
            filtered = items.filter { $0.sourceRole == .coach }
        case .athletes:
            filtered = items.filter { $0.sourceRole == .client && $0.sourceContext != "Built by you" }
        case .myCopies:
            filtered = items.filter { $0.sourceContext == "Built by you" }
        }

        return filtered.sorted { lhs, rhs in
            if lhs.isPinned != rhs.isPinned {
                return lhs.isPinned && !rhs.isPinned
            }
            return lhs.savedAt > rhs.savedAt
        }
    }

    private var pinnedItems: [SavedWorkoutLibraryItem] {
        items
            .filter(\.isPinned)
            .sorted { lhs, rhs in
                let lhsInsight = insightFor(lhs)
                let rhsInsight = insightFor(rhs)
                if lhsInsight.completionCount != rhsInsight.completionCount {
                    return lhsInsight.completionCount > rhsInsight.completionCount
                }
                return lhs.savedAt > rhs.savedAt
            }
    }

    private var recentShortcutItems: [SavedWorkoutLibraryItem] {
        items
            .filter { !$0.isPinned }
            .compactMap { item -> (SavedWorkoutLibraryItem, SavedWorkoutLibraryInsight)? in
                let insight = insightFor(item)
                guard insight.lastCompletedAt != nil else { return nil }
                return (item, insight)
            }
            .sorted { lhs, rhs in
                (lhs.1.lastCompletedAt ?? .distantPast) > (rhs.1.lastCompletedAt ?? .distantPast)
            }
            .prefix(2)
            .map(\.0)
    }

    private var mostUsedShortcutItems: [SavedWorkoutLibraryItem] {
        let recentIDs = Set(recentShortcutItems.map(\.id))
        return items
            .filter { !$0.isPinned && !recentIDs.contains($0.id) }
            .compactMap { item -> (SavedWorkoutLibraryItem, SavedWorkoutLibraryInsight)? in
                let insight = insightFor(item)
                guard insight.completionCount > 0 else { return nil }
                return (item, insight)
            }
            .sorted { lhs, rhs in
                if lhs.1.completionCount != rhs.1.completionCount {
                    return lhs.1.completionCount > rhs.1.completionCount
                }
                return (lhs.1.lastCompletedAt ?? .distantPast) > (rhs.1.lastCompletedAt ?? .distantPast)
            }
            .prefix(2)
            .map(\.0)
    }

    private func sourceBadgeText(for item: SavedWorkoutLibraryItem) -> String {
        item.sourceContext == "Built by you" ? "My copy" : "Athlete source"
    }

    private func sourceBadgeColor(for item: SavedWorkoutLibraryItem) -> Color {
        if item.sourceRole == .coach {
            return MorpheTheme.accentAlt
        }
        return item.sourceContext == "Built by you" ? MorpheTheme.warning : MorpheTheme.accent
    }

    private func useCaseColor(for useCase: SavedWorkoutUseCase) -> Color {
        switch useCase {
        case .solo:
            return MorpheTheme.accent
        case .buddy:
            return MorpheTheme.warning
        case .fallback:
            return MorpheTheme.accentAlt
        case .customBuild:
            return MorpheTheme.lavender
        }
    }

    private func savedWorkoutBadges(
        for item: SavedWorkoutLibraryItem,
        insight: SavedWorkoutLibraryInsight
    ) -> [SavedWorkoutCompletionBadgeDescriptor] {
        var badges: [SavedWorkoutCompletionBadgeDescriptor] = []

        if insight.completionCount > 0 {
            let completionTitle = insight.completionCount >= 3
                ? "\(insight.completionCount)x finished"
                : "Completed"
            badges.append(.init(title: completionTitle, color: MorpheTheme.accent))
        }

        if insight.hasBuddyCompletion {
            badges.append(.init(title: "Buddy favorite", color: MorpheTheme.warning))
        }

        if item.bestFor == .fallback && insight.completionCount > 0 {
            badges.append(.init(title: "Fallback win", color: MorpheTheme.accentAlt))
        }

        if item.sourceRole == .coach && insight.completionCount > 0 {
            badges.append(.init(title: "Coach assigned", color: MorpheTheme.lavender))
        }

        return Array(badges.prefix(3))
    }
}

private struct ShortcutWorkoutSection: View {
    let title: String
    let subtitle: String
    let items: [SavedWorkoutLibraryItem]
    let insightFor: (SavedWorkoutLibraryItem) -> SavedWorkoutLibraryInsight
    let onStart: (SavedWorkoutLibraryItem) -> Void
    let onWithBuddy: (SavedWorkoutLibraryItem) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(MorpheTheme.textSecondary)
            }

            ForEach(items) { item in
                let insight = insightFor(item)

                VStack(alignment: .leading, spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(item.workoutName)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.white)
                            .lineLimit(2)
                        Text(item.sourceName)
                            .font(.caption)
                            .foregroundStyle(MorpheTheme.textSecondary)
                            .lineLimit(1)
                        SavedWorkoutCompletionBadgeRow(
                            badges: savedWorkoutBadges(for: item, insight: insight)
                        )
                        Text(detailLine(for: item, insight: insight))
                            .font(.caption2)
                            .foregroundStyle(MorpheTheme.textMuted)
                            .lineLimit(2)
                    }

                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 2), spacing: 8) {
                        Button("Start") {
                            onStart(item)
                        }
                        .buttonStyle(SecondaryCTAButtonStyle())

                        if FeatureFlags.multiUserEnabled {
                            Button("With Buddy") {
                                onWithBuddy(item)
                            }
                            .buttonStyle(SecondaryCTAButtonStyle())
                        }
                    }
                }
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(MorpheTheme.panel)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .stroke(MorpheTheme.stroke.opacity(0.75), lineWidth: 1)
                        )
                )
            }
        }
    }

    private func detailLine(for item: SavedWorkoutLibraryItem, insight: SavedWorkoutLibraryInsight) -> String {
        let lastRun = insight.lastCompletedAt.map(MorpheAppStore.workoutDateLabel(for:)) ?? "Not yet"
        return "\(insight.completionCount)x completed • Last run \(lastRun) • Best for \(item.bestFor.rawValue)"
    }

    private func savedWorkoutBadges(
        for item: SavedWorkoutLibraryItem,
        insight: SavedWorkoutLibraryInsight
    ) -> [SavedWorkoutCompletionBadgeDescriptor] {
        var badges: [SavedWorkoutCompletionBadgeDescriptor] = []

        if insight.completionCount > 0 {
            let completionTitle = insight.completionCount >= 3
                ? "\(insight.completionCount)x finished"
                : "Completed"
            badges.append(.init(title: completionTitle, color: MorpheTheme.accent))
        }

        if insight.hasBuddyCompletion {
            badges.append(.init(title: "Buddy favorite", color: MorpheTheme.warning))
        }

        if item.bestFor == .fallback && insight.completionCount > 0 {
            badges.append(.init(title: "Fallback win", color: MorpheTheme.accentAlt))
        }

        if item.sourceRole == .coach && insight.completionCount > 0 {
            badges.append(.init(title: "Coach assigned", color: MorpheTheme.lavender))
        }

        return Array(badges.prefix(3))
    }
}

private struct SavedWorkoutCompletionBadgeDescriptor: Hashable {
    let title: String
    let color: Color
}

private struct SavedWorkoutCompletionBadgeRow: View {
    let badges: [SavedWorkoutCompletionBadgeDescriptor]

    var body: some View {
        if !badges.isEmpty {
            WrapStack(spacing: 8) {
                ForEach(Array(badges.enumerated()), id: \.offset) { _, badge in
                    StatusBadge(text: badge.title, color: badge.color)
                }
            }
        }
    }
}

private struct ExercisePlanCard: View {
    let exercise: WorkoutExercise
    let onViewForm: () -> Void
    let onSwap: () -> Void

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(exercise.name)
                            .font(.headline)
                            .foregroundStyle(.white)
                        Text(exercise.muscleGroup.rawValue)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(MorpheTheme.accentAlt)
                    }

                    Spacer()

                    MetricPill(label: "Difficulty", value: exercise.difficulty.rawValue)
                }

                HStack(spacing: 8) {
                    MetricPill(label: "Sets", value: exercise.sets)
                    MetricPill(label: "Reps", value: exercise.reps)
                }

                Text("Coach cue: \(exercise.formCue)")
                    .font(.subheadline)
                    .foregroundStyle(MorpheTheme.textSecondary)

                HStack(spacing: 10) {
                    Button("View Form", action: onViewForm)
                        .buttonStyle(SecondaryCTAButtonStyle())

                    Button("Swap", action: onSwap)
                        .buttonStyle(PrimaryCTAButtonStyle(accent: MorpheTheme.accentAlt))
                }
            }
        }
    }
}

private struct ExerciseCompactRow: View {
    let exercise: WorkoutExercise
    let onViewForm: () -> Void
    let onSwap: () -> Void

    var body: some View {
        GlassCard {
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(exercise.name)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                    Text("\(exercise.sets) • \(exercise.reps)")
                        .font(.caption)
                        .foregroundStyle(MorpheTheme.textSecondary)
                    Text(exercise.formCue)
                        .font(.caption)
                        .foregroundStyle(MorpheTheme.textMuted)
                        .lineLimit(2)
                }

                Spacer()

                VStack(spacing: 8) {
                    Button("Form", action: onViewForm)
                        .buttonStyle(FilterChipStyle(isSelected: false, selectedColor: MorpheTheme.accentAlt))
                    Button("Swap", action: onSwap)
                        .buttonStyle(FilterChipStyle(isSelected: false, selectedColor: MorpheTheme.accent))
                }
            }
        }
    }
}

private struct ExerciseSwapFlowSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(MorpheAppStore.self) private var store
    let exercise: WorkoutExercise
    @State private var selectedReason: ExerciseSwapReason?

    private var libraryExercise: ExerciseReference? {
        store.exerciseDatabase.first(where: { $0.id == exercise.exerciseLibraryID })
    }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 16) {
                    GlassCard {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Swap \(exercise.name)")
                                .font(.title3.weight(.bold))
                                .foregroundStyle(.white)
                            Text("Why do you want to swap this?")
                                .foregroundStyle(MorpheTheme.textSecondary)

                            WrapStack(spacing: 8) {
                                ForEach(ExerciseSwapReason.allCases) { reason in
                                    Button(reason.rawValue) {
                                        selectedReason = reason
                                    }
                                    .buttonStyle(FilterChipStyle(isSelected: selectedReason == reason, selectedColor: MorpheTheme.accentAlt))
                                }
                            }
                        }
                    }

                    if let selectedReason, let libraryExercise {
                        GlassCard {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Suggested alternatives")
                                    .font(.headline)
                                    .foregroundStyle(.white)

                                Text(reasonDescription(for: selectedReason))
                                    .foregroundStyle(MorpheTheme.textSecondary)

                                ForEach(libraryExercise.alternatives, id: \.self) { option in
                                    Text("- \(option)")
                                        .foregroundStyle(.white)
                                }

                                Button("Swap Exercise") {
                                    store.swapExercise(exercise)
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

    private func reasonDescription(for reason: ExerciseSwapReason) -> String {
        switch reason {
        case .equipmentUnavailable:
            return "Morphe is looking for an equivalent option with less gear."
        case .tooHard:
            return "A slightly easier pattern keeps the session moving without killing momentum."
        case .painDiscomfort:
            return "Let's bias the safer variation and reduce joint irritation."
        case .dontKnowHow:
            return "Start with the clearer version you can execute well."
        case .gymCrowded:
            return "A flexible backup keeps the session from stalling."
        case .wantHomeVersion:
            return "Home-friendly options still move the goal forward."
        }
    }
}

private enum ExerciseSwapReason: String, CaseIterable, Identifiable {
    case equipmentUnavailable = "Equipment unavailable"
    case tooHard = "Too hard"
    case painDiscomfort = "Pain/discomfort"
    case dontKnowHow = "Don't know how to do it"
    case gymCrowded = "Gym is crowded"
    case wantHomeVersion = "Want home version"

    var id: String { rawValue }
}

// MARK: - Workout builder

private struct YourWorkoutsCard: View {
    let workouts: [WorkoutTemplate]
    let onStart: (WorkoutTemplate) -> Void
    let onDelete: (WorkoutTemplate) -> Void

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("Your workouts")
                    .font(.headline)
                    .foregroundStyle(.white)

                ForEach(workouts) { workout in
                    HStack(spacing: 10) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(workout.name)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.white)
                            Text("\(workout.exercises.count) exercises • \(workout.durationMinutes) min")
                                .font(.caption)
                                .foregroundStyle(MorpheTheme.textMuted)
                        }
                        Spacer()
                        Button("Start") { onStart(workout) }
                            .buttonStyle(PrimaryCTAButtonStyle(accent: MorpheTheme.accent))
                            .frame(width: 92)
                        Button {
                            onDelete(workout)
                        } label: {
                            Image(systemName: "trash")
                                .foregroundStyle(MorpheTheme.danger)
                        }
                        .accessibilityLabel("Delete \(workout.name)")
                    }
                    .padding(.vertical, 4)
                }
            }
        }
    }
}

private struct WorkoutBuilderSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(MorpheAppStore.self) private var store

    @State private var name = ""
    @State private var sport: SportFocus = .generalFitness
    @State private var items: [CustomWorkoutItem] = []
    @State private var showExercisePicker = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Workout name")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(MorpheTheme.textSecondary)
                        TextField("e.g. Push Day", text: $name)
                            .textFieldStyle(MorpheFieldStyle())
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Focus")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(MorpheTheme.textSecondary)
                        Picker("Focus", selection: $sport) {
                            ForEach(SportFocus.allCases) { option in
                                Text(option.rawValue).tag(option)
                            }
                        }
                        .pickerStyle(.menu)
                        .tint(MorpheTheme.accent)
                    }

                    HStack {
                        Text("Exercises (\(items.count))")
                            .font(.headline)
                            .foregroundStyle(.white)
                        Spacer()
                        Button {
                            showExercisePicker = true
                        } label: {
                            Label("Add", systemImage: "plus")
                                .font(.subheadline.weight(.semibold))
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(MorpheTheme.accent)
                    }

                    if items.isEmpty {
                        Text("Add exercises from the library or create your own.")
                            .font(.subheadline)
                            .foregroundStyle(MorpheTheme.textMuted)
                    }

                    ForEach($items) { $item in
                        GlassCard {
                            VStack(alignment: .leading, spacing: 10) {
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(item.exercise.name)
                                            .font(.subheadline.weight(.bold))
                                            .foregroundStyle(.white)
                                        Text(item.exercise.muscleGroup.rawValue)
                                            .font(.caption)
                                            .foregroundStyle(MorpheTheme.textMuted)
                                    }
                                    Spacer()
                                    Button {
                                        items.removeAll { $0.id == item.id }
                                    } label: {
                                        Image(systemName: "trash")
                                            .foregroundStyle(MorpheTheme.danger)
                                    }
                                    .accessibilityLabel("Remove \(item.exercise.name)")
                                }
                                Stepper("Sets: \(item.sets)", value: $item.sets, in: 1...10)
                                    .foregroundStyle(.white)
                                Stepper("Reps: \(item.reps)", value: $item.reps, in: 1...50)
                                    .foregroundStyle(.white)
                            }
                        }
                    }

                    Button("Create Workout") {
                        store.createCustomWorkout(name: name, sport: sport, items: items)
                        dismiss()
                    }
                    .buttonStyle(PrimaryCTAButtonStyle(accent: MorpheTheme.accent))
                    .disabled(items.isEmpty)
                    .opacity(items.isEmpty ? 0.5 : 1)
                }
                .padding(20)
            }
            .background(PremiumBackground())
            .navigationTitle("Build a workout")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .sheet(isPresented: $showExercisePicker) {
                ExercisePickerSheet { exercise in
                    items.append(CustomWorkoutItem(exercise: exercise))
                }
                .environment(store)
            }
        }
    }
}

private struct ExercisePickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(MorpheAppStore.self) private var store
    let onPick: (ExerciseReference) -> Void

    @State private var query = ""
    @State private var showCustomForm = false
    @State private var customName = ""
    @State private var customMuscle: MuscleGroup = .core

    private var filtered: [ExerciseReference] {
        let all = store.allExercises
        guard !query.isEmpty else { return all }
        return all.filter {
            $0.name.localizedCaseInsensitiveContains(query)
                || $0.muscleGroup.rawValue.localizedCaseInsensitiveContains(query)
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    Button {
                        withAnimation { showCustomForm.toggle() }
                    } label: {
                        Label("Create custom exercise", systemImage: "plus.circle")
                    }
                    .buttonStyle(SecondaryCTAButtonStyle())

                    if showCustomForm {
                        GlassCard {
                            VStack(alignment: .leading, spacing: 10) {
                                TextField("Exercise name", text: $customName)
                                    .textFieldStyle(MorpheFieldStyle())
                                Picker("Muscle group", selection: $customMuscle) {
                                    ForEach(MuscleGroup.allCases) { group in
                                        Text(group.rawValue).tag(group)
                                    }
                                }
                                .pickerStyle(.menu)
                                .tint(MorpheTheme.accent)
                                Button("Add custom exercise") {
                                    let created = store.addCustomExercise(name: customName, muscleGroup: customMuscle)
                                    onPick(created)
                                    dismiss()
                                }
                                .buttonStyle(PrimaryCTAButtonStyle(accent: MorpheTheme.accent))
                                .disabled(customName.trimmingCharacters(in: .whitespaces).isEmpty)
                            }
                        }
                    }

                    ForEach(filtered) { exercise in
                        Button {
                            onPick(exercise)
                            dismiss()
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(exercise.name)
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(.white)
                                    Text(exercise.muscleGroup.rawValue)
                                        .font(.caption)
                                        .foregroundStyle(MorpheTheme.textMuted)
                                }
                                Spacer()
                                Image(systemName: "plus")
                                    .foregroundStyle(MorpheTheme.accent)
                            }
                            .padding(12)
                            .background(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .fill(MorpheTheme.panel)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(20)
            }
            .background(PremiumBackground())
            .navigationTitle("Add exercise")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $query)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
