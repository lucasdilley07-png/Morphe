import SwiftUI
import UIKit

struct WorkoutView: View {
    @Environment(MorpheAppStore.self) private var store

    @State private var workoutPendingDelete: WorkoutTemplate?
    @State private var restSeconds = 180
    @State private var restRunning = false
    @State private var swapTarget: WorkoutExercise?
    @State private var isShowingPainFlow = false
    /// Payload for the set logger sheet: nil editIndex = log a new/extra set.
    private struct RepLoggerContext: Identifiable {
        let id = UUID()
        var editIndex: Int?
    }
    @State private var repLoggerContext: RepLoggerContext?
    /// The user's custom workout currently open in the editor.
    private struct EditingWorkout: Identifiable { let id: UUID }
    @State private var editingWorkout: EditingWorkout?
    @State private var pendingRepCount = 10
    @State private var pendingWeight: Double = 0
    @State private var pendingRPE: Int?
    @State private var showDiscardConfirm = false
    @State private var showLibrary = false
    @State private var showExerciseList = false
    @State private var showAdjustments = false
    @State private var showSessionQueue = false
    @State private var showHistory = false
    @State private var showBuilder = false
    @State private var showFormCheck = false
    @State private var showCircuitMode = false
    @State private var showEmptyLibraryNotice = false
    @State private var showTrainTogether = false

    private var deleteWorkoutDialogTitle: String {
        guard let template = workoutPendingDelete else { return "Delete this workout?" }
        var message = "Delete \(template.name)? It's removed from your library — there's no undo."
        // Deleting the staged workout resets the session; disclose the loss.
        if store.currentWorkout.id == template.id, store.hasUnsavedSessionWork {
            message += " Your finished session hasn't been logged — deleting this discards it."
        }
        return message
    }

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
        // Each presentation lives on its own background view. SwiftUI
        // mishandles multiple sheet/cover modifiers stacked on ONE view — the
        // second sheet could fail or crash on present — so they're isolated.
        .background(
            EmptyView().sheet(item: $swapTarget) { exercise in
                ExerciseSwapFlowSheet(exercise: exercise)
                    .environment(store)
            }
        )
        .background(
            // Item-based so every tap presents atomically with its payload —
            // the Bool flavor could silently drop a present during state
            // races, which read as "the More button does nothing".
            EmptyView().sheet(item: $repLoggerContext) { context in
                SetRepLoggingSheet(
                    reps: $pendingRepCount,
                    weight: $pendingWeight,
                    rpe: $pendingRPE,
                    isEditing: context.editIndex != nil
                ) { label in
                    if let editIndex = context.editIndex, let exercise = store.activeWorkoutExercise {
                        store.updateTrackedSet(exerciseID: exercise.id, setIndex: editIndex, reps: pendingRepCount, weight: pendingWeight, rpe: pendingRPE)
                    } else {
                        // Opening the full logger is an explicit action, so it may
                        // log past the planned set count ("Add extra set").
                        store.completeTrackedSet(reps: pendingRepCount, weight: pendingWeight, rpe: pendingRPE, allowExtra: true, label: label)
                    }
                    repLoggerContext = nil
                }
                .environment(store)
                .presentationDetents([.height(620)])
            }
        )
        .onChange(of: store.weightUnit) { oldUnit, newUnit in
            // Keep the inline stepper value meaning the same physical load
            // when the unit flips (the store converts the logged sets).
            guard oldUnit != newUnit, pendingWeight > 0 else { return }
            let factor = newUnit == .kilograms ? 0.45359237 : 2.20462262
            pendingWeight = ((pendingWeight * factor) * 10).rounded() / 10
        }
        .background(
            EmptyView().sheet(isPresented: $showBuilder) {
                WorkoutBuilderSheet()
                    .environment(store)
            }
        )
        .background(
            EmptyView().sheet(isPresented: $showTrainTogether) {
                TrainTogetherSheet()
                    .environment(store)
            }
        )
        .background(
            EmptyView().sheet(item: $editingWorkout) { editing in
                WorkoutBuilderSheet(editingTemplateID: editing.id)
                    .environment(store)
            }
        )
        .background(
            EmptyView().fullScreenCover(isPresented: $showFormCheck) {
                // Match Form Check to the exercise the user is actually on.
                if let exercise = store.activeWorkoutExercise {
                    FormCheckView(
                        exerciseName: exercise.name,
                        movement: .infer(exerciseName: exercise.name, muscleGroup: exercise.muscleGroup)
                    ) { reps in
                        // Log the camera-counted reps as a set on the active
                        // exercise at the working weight (bodyweight if none).
                        guard reps > 0 else { return }
                        let weight = store.lastSessionWeight(for: exercise.id)
                            ?? store.suggestedWorkingWeight(for: exercise)
                            ?? 0
                        store.completeTrackedSet(reps: reps, weight: weight)
                    }
                } else {
                    FormCheckView()
                }
            }
        )
        .background(
            EmptyView().fullScreenCover(isPresented: $showCircuitMode) {
                CircuitModeView(exercises: store.currentWorkout.exercises)
                    .environment(store)
            }
        )
    }

    private var activeWorkoutMode: some View {
        @Bindable var store = store
        // One scroll surface for the whole live session: with the inline weight
        // row the tracker card is tall enough that a fixed header clipped the
        // console and pushed the Finish button off-screen on smaller devices.
        // The set console leads: logging is THE task mid-session, so it must
        // be on screen without scrolling past session ceremony. Finish takes
        // its place when everything is logged; timer and session context sit
        // below the work surface.
        return ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 14) {
                // Training together: buddies live in one slim strip. Solo
                // sessions never see it.
                if store.activeParty != nil {
                    PartySessionStrip()
                }

                if store.isTrackedWorkoutComplete {
                    WorkoutCompleteCard(
                        workoutName: store.currentWorkout.name,
                        totalSets: store.trackedSetTotalCount
                    ) {
                        if store.finishTrackedWorkoutSession() {
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
                        repsLogged: store.trackedSetReps[activeExercise.id, default: []],
                        weightsLogged: store.trackedSetWeights[activeExercise.id, default: []],
                        weight: $pendingWeight,
                        weightUnit: store.weightUnit,
                        onPrevious: { store.goToPreviousTrackedExercise() },
                        onQuickLogSet: { reps in
                            store.completeTrackedSet(reps: reps, weight: pendingWeight)
                        },
                        onOpenCustomRepLogger: {
                            // A saved draft wins — whatever was typed last time
                            // comes back exactly. Otherwise suggest, clamped
                            // into the stepper's range (duration-based moves
                            // can parse to values like 60 "reps").
                            if let draft = store.pendingSetDrafts[activeExercise.id] {
                                pendingRepCount = min(max(draft.reps, 1), 50)
                                pendingWeight = draft.weight
                                pendingRPE = draft.rpe
                            } else {
                                pendingRepCount = min(max(suggestedRepCount(for: activeExercise), 1), 50)
                                pendingRPE = nil
                            }
                            repLoggerContext = RepLoggerContext(editIndex: nil)
                        },
                        onEditSet: { index in
                            let repsLogged = store.trackedSetReps[activeExercise.id, default: []]
                            let weightsLogged = store.trackedSetWeights[activeExercise.id, default: []]
                            let rpesLogged = store.trackedSetRPE[activeExercise.id, default: []]
                            let reps = repsLogged.indices.contains(index) ? repsLogged[index] : suggestedRepCount(for: activeExercise)
                            pendingRepCount = min(max(reps, 1), 50)
                            pendingWeight = weightsLogged.indices.contains(index) ? weightsLogged[index] : 0
                            let storedRPE = rpesLogged.indices.contains(index) ? rpesLogged[index] : 0
                            pendingRPE = storedRPE > 0 ? storedRPE : nil
                            repLoggerContext = RepLoggerContext(editIndex: index)
                        },
                        onDeleteSet: { index in
                            store.removeTrackedSet(exerciseID: activeExercise.id, setIndex: index)
                        },
                        onNext: { store.goToNextTrackedExercise() },
                        onStartRest: {
                            restSeconds = 180
                            restRunning = true
                        },
                        onOpenFormCheck: { showFormCheck = true },
                        canGoPrevious: store.activeWorkoutExerciseIndex > 0
                    )
                }

                LiveWorkoutConsoleCard(
                    workout: store.currentWorkout,
                    exerciseIndex: store.activeWorkoutExerciseIndex,
                    totalExercises: max(store.currentWorkout.exercises.count, 1),
                    warmupText: liveWarmupText,
                    exerciseName: store.activeWorkoutExercise?.name ?? store.currentWorkout.name,
                    restSeconds: $restSeconds,
                    restRunning: $restRunning
                )

                // Once everything is logged, WorkoutCompleteCard owns Finish
                // — a second Finish/Discard row here would just compete.
                if !store.isTrackedWorkoutComplete {
                    HStack(spacing: 10) {
                        Button("Finish Session") {
                            if store.finishTrackedWorkoutSession() {
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
                            store.cancelTrackedWorkoutSession()
                        }
                        Button("Keep Training", role: .cancel) {}
                    }
                }

                // Circuit Mode: guided work/rest intervals over this session's
                // exercises — sits with the session tools, off the set-logging
                // fast path.
                Button("Circuit Mode") { showCircuitMode = true }
                    .buttonStyle(SecondaryCTAButtonStyle())
                    .accessibilityHint("Timed stations with auto-advance; only finished intervals get logged")

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
            // Carry the working weight forward: this session's own last set,
            // else the cross-session progression suggestion (last logged
            // weight, bumped when last time felt easy).
            if let exercise = store.activeWorkoutExercise {
                pendingWeight = store.lastSessionWeight(for: exercise.id)
                    ?? store.suggestedWorkingWeight(for: exercise)
                    ?? pendingWeight
            }
        }
        .onAppear {
            // A mid-session relaunch restores the session but not this view
            // state — without the reseed the next quick-log records 0 ("BW")
            // even though the session knows the working weight.
            if pendingWeight == 0, let exercise = store.activeWorkoutExercise {
                pendingWeight = store.lastSessionWeight(for: exercise.id)
                    ?? store.suggestedWorkingWeight(for: exercise)
                    ?? 0
            }
        }
    }

    /// One concrete pick each for training, stretching, and recovery — shown
    /// after today's workout is logged.
    private var trySomethingNewPicks: [(category: String, template: WorkoutTemplate)] {
        func pick(_ categories: [String]) -> WorkoutTemplate? {
            store.discoverWorkouts.first {
                categories.contains($0.categoryTag) && $0.durationMinutes <= 45
            }
        }
        var picks: [(String, WorkoutTemplate)] = []
        if let training = pick(["Strength & Powerlifting", "HIIT & Conditioning", "Kettlebell & Dumbbell"]) {
            picks.append(("Training", training))
        }
        if let stretching = pick(["Yoga, Mobility & Flexibility"]) {
            picks.append(("Stretching", stretching))
        }
        if let recovery = pick(["Recovery & Longevity"]) {
            picks.append(("Recovery", recovery))
        }
        return picks
    }

    private var workoutPlanningMode: some View {
        @Bindable var store = store
        return ScrollViewReader { proxy in
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 16) {
                SectionTitleView(
                    title: "Train",
                    subtitle: store.hasCompletedWorkoutFlow
                        ? "Session finished — review what you logged, rate it, and lock it in."
                        : "Start the session, log sets in the console, then rate it and lock it in."
                )

                // Form Check lives inside the live session now (under the rest
                // timer), matched to the exercise you're on — not here.

                // Right after a finish, reviewing and logging IS the task —
                // it leads the screen instead of hiding below planning cards.
                if store.hasCompletedWorkoutFlow {
                    SessionRecapCard(
                        items: store.sessionRecapItems,
                        weightUnit: store.weightUnit
                    )

                    // Shared recap: who trained with you and their totals
                    // (published to the party as each person logs).
                    if store.activeParty != nil, !store.partyBuddies.isEmpty {
                        PartyRecapCard(buddies: store.partyBuddies)
                    }

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

                    Button("Log Workout") {
                        store.logWorkout()
                    }
                    .accessibilityLabel("Log workout and view progress")
                    .buttonStyle(PrimaryCTAButtonStyle(accent: MorpheTheme.accent))
                }

                // ONE workout, one name: the same session the Today hero
                // shows, with Morphe's readiness-based pick demoted to an
                // inline suggestion instead of a competing second entry point.
                if store.isWorkoutLoggedToday && !store.hasCompletedWorkoutFlow {
                    // Today's session is in the books — offer something new
                    // instead of re-showing the plan they already finished.
                    TrySomethingNewCard(
                        recommendations: trySomethingNewPicks,
                        onStartPick: { template in
                            isShowingPainFlow = false
                            store.startCatalogWorkout(template)
                        },
                        onBrowse: { store.showDiscoverTab() }
                    )
                } else {
                    TodaysWorkoutCard(
                        workout: store.currentWorkout,
                        suggestion: store.recommendedWorkoutDiffers ? goodForTodayRecommendation : nil,
                        partyStatus: store.activeParty.map { party in
                            store.partyBuddies.isEmpty
                                ? "Code \(party.id) · waiting for your buddy"
                                : "Code \(party.id) · \(store.partyBuddies.count + 1) training"
                        },
                        onStart: {
                            // The store's session-work gate confirms before a
                            // live session or unlogged recap gets destroyed.
                            isShowingPainFlow = false
                            store.startTodayWorkout()
                        },
                        onUseSuggestion: {
                            store.applyRecommendedWorkout()
                        },
                        onSwitch: {
                            if !store.requestWorkoutSwitch() {
                                showEmptyLibraryNotice = true
                            }
                        },
                        onTrainTogether: { showTrainTogether = true }
                    )
                }

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
                        Label("Build Workout", systemImage: "plus.circle.fill")
                    }
                    .buttonStyle(SecondaryCTAButtonStyle())
                    .accessibilityLabel("Build your own workout")

                    let myWorkouts = store.workoutTemplates.filter { store.isCustomWorkout($0.id) }
                    if !myWorkouts.isEmpty {
                        YourWorkoutsCard(
                            workouts: myWorkouts,
                            onStart: { template in
                                isShowingPainFlow = false
                                store.beginLiveWorkout(template)
                            },
                            onQueue: { template in
                                store.openWorkoutTemplate(template)
                            },
                            onEdit: { template in
                                editingWorkout = EditingWorkout(id: template.id)
                            },
                            onDelete: { template in
                                workoutPendingDelete = template
                            }
                        )
                        .confirmationDialog(
                            deleteWorkoutDialogTitle,
                            isPresented: Binding(
                                get: { workoutPendingDelete != nil },
                                set: { if !$0 { workoutPendingDelete = nil } }
                            ),
                            titleVisibility: .visible,
                            presenting: workoutPendingDelete
                        ) { template in
                            Button("Delete Workout", role: .destructive) {
                                store.deleteCustomWorkout(template.id)
                            }
                            Button("Keep It", role: .cancel) {}
                        }
                    }

                    SavedWorkoutsLibraryCard(
                        items: store.savedWorkouts,
                        insightFor: { item in
                            store.savedWorkoutInsight(for: item)
                        },
                        onStart: { item in
                            isShowingPainFlow = false
                            store.startSavedWorkout(item)
                        },
                        onQueue: { item in
                            store.queueSavedWorkout(item)
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
                        },
                        onEdit: { item in
                            if let templateID = store.editableTemplateID(for: item) {
                                editingWorkout = EditingWorkout(id: templateID)
                            }
                        }
                    )
                }
                .id("myLibrary")

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
                            Text("Open Learn for the exercise library and beginner-friendly form help, or swap a move right from today's plan.")
                                .foregroundStyle(MorpheTheme.textSecondary)
                            HStack(spacing: 10) {
                                Button("Library") {
                                    store.openMore(.library)
                                }
                                .buttonStyle(PrimaryCTAButtonStyle(accent: MorpheTheme.accentAlt))
                                .accessibilityLabel("Open exercise library")

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
        .onAppear { revealLibraryIfRequested(proxy) }
        .onChange(of: store.pendingLibraryReveal) { _, _ in
            revealLibraryIfRequested(proxy)
        }
        .alert("Your library is empty", isPresented: $showEmptyLibraryNotice) {
            Button("Browse Discover") { store.showDiscoverTab() }
            Button("Got It", role: .cancel) {}
        } message: {
            Text("Save or start workouts from the Discover page, or build your own right here in My Library.")
        }
        }
    }

    /// Consumes the store's one-shot "Switch workout" signal: expands My
    /// Library and scrolls to it once the expansion has laid out.
    private func revealLibraryIfRequested(_ proxy: ScrollViewProxy) {
        guard store.pendingLibraryReveal else { return }
        store.pendingLibraryReveal = false
        showLibrary = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            withAnimation(.easeInOut(duration: 0.35)) {
                proxy.scrollTo("myLibrary", anchor: .top)
            }
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

    // Warm-up guidance is pre-work context: once the first set is logged
    // (or the lifter moves past exercise one) it's just scroll weight.
    private var liveWarmupText: String? {
        guard store.activeWorkoutExerciseIndex == 0,
              let firstExercise = store.currentWorkout.exercises.first,
              store.completedWorkoutSets[firstExercise.id, default: 0] == 0
        else { return nil }
        return warmupText(for: store.currentWorkout.sport)
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

/// Discover as its own destination — the catalog was buried as a collapsed
/// third section on Train; the flagship content deserves a tab. Starting a
/// workout here drops straight into the live tracker on Train.
struct DiscoverScreenView: View {
    @Environment(MorpheAppStore.self) private var store

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 16) {
                    SectionTitleView(
                        title: "Discover",
                        subtitle: store.discoverWorkouts.isEmpty
                            ? "A new workout library is on the way."
                            : "\(store.discoverWorkouts.count) workouts — pick a training style."
                    )

                    DiscoverCatalogSection(
                        onStart: { template in
                            store.startCatalogWorkout(template)
                        },
                        // Entering or leaving a style must land at the top —
                        // the in-place swap otherwise keeps the old offset and
                        // strands the user mid-list with the header off-screen.
                        onSelectionChange: {
                            proxy.scrollTo("discoverTop", anchor: .top)
                        }
                    )
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 120)
                .id("discoverTop")
            }
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
    case saveFavorite = "Save Favorite"
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
                            .font(.title3.weight(.bold))
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
                                RoundedRectangle(cornerRadius: MorpheTheme.radius, style: .continuous)
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
    // nil once the session is under way — warm-up guidance only matters
    // before the first set of the first exercise.
    let warmupText: String?
    var exerciseName: String = "Next set"
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

                if let warmupText {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Warm-up")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.white)
                        Text(warmupText)
                            .font(.subheadline)
                            .foregroundStyle(MorpheTheme.textSecondary)
                    }
                }

                WorkoutRestControlBar(seconds: $restSeconds, isRunning: $restRunning, exerciseName: exerciseName)
            }
        }
    }
}

/// Entry point for the camera form coach (Phase 1: framing + reps).
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
    @Environment(MorpheAppStore.self) private var store
    let workout: WorkoutTemplate
    let exercise: WorkoutExercise
    let exerciseIndex: Int
    let totalExercises: Int
    let completedSets: Int
    let totalSets: Int
    let nextExercise: WorkoutExercise?
    let suggestedReps: Int
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
    let onOpenFormCheck: () -> Void
    let canGoPrevious: Bool

    private var isExerciseComplete: Bool {
        completedSets >= totalSets
    }

    private var setProgress: Double {
        guard totalSets > 0 else { return 0 }
        return min(Double(completedSets) / Double(totalSets), 1)
    }

    @State private var repsToLog = 10

    /// Fine step (5 lb / 2.5 kg) and coarse step (25 lb / 10 kg) — a plate
    /// jump shouldn't take five taps.
    private var weightStep: Double {
        weightUnit == .kilograms ? 2.5 : 5
    }

    private var coarseWeightStep: Double {
        weightUnit == .kilograms ? 10 : 25
    }

    private var weightDisplay: String {
        weight > 0 ? weightUnit.format(weight) : "Bodyweight"
    }

    /// Short CTA — the accessibility label carries the exact reps and weight.
    private var logButtonTitle: String {
        "Log Set"
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
                    if let progression = store.progressionNote(for: exercise) {
                        Text(progression)
                            .font(MorpheTheme.microLabel(10)).tracking(1.0)
                            .foregroundStyle(MorpheTheme.accent)
                    }
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
                                        .background(RoundedRectangle(cornerRadius: MorpheTheme.radius, style: .continuous).stroke(Color.white.opacity(0.16), lineWidth: 1))
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
                                        .background(RoundedRectangle(cornerRadius: MorpheTheme.radius, style: .continuous).stroke(Color.white.opacity(0.16), lineWidth: 1))
                                }
                                .buttonStyle(.plain)
                                .foregroundStyle(MorpheTheme.danger)
                                .accessibilityLabel("Delete set \(index + 1)")
                            }
                        }
                    }
                    .padding(10)
                    .background(
                        RoundedRectangle(cornerRadius: MorpheTheme.radius, style: .continuous)
                            .fill(MorpheTheme.panelStrong.opacity(0.6))
                    )
                }

                if let nextExercise {
                    HStack(alignment: .center, spacing: 10) {
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

                        Spacer(minLength: 0)

                        // Quick jump into the camera form guide for the
                        // CURRENT exercise, right where eyes already are.
                        Button(action: onOpenFormCheck) {
                            VStack(spacing: 3) {
                                Image(systemName: "camera.viewfinder")
                                    .font(.headline)
                                Text("Form")
                                    .font(MorpheTheme.microLabel(9))
                                    .tracking(0.8)
                            }
                            .foregroundStyle(MorpheTheme.accent)
                            .frame(width: 52, height: 48)
                            .background(
                                RoundedRectangle(cornerRadius: MorpheTheme.radius, style: .continuous)
                                    .stroke(MorpheTheme.accent.opacity(0.5), lineWidth: 1)
                            )
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Open Form Check for \(exercise.name)")
                    }
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: MorpheTheme.radius, style: .continuous)
                            .fill(MorpheTheme.panelStrong)
                    )
                }

                // The set console: dial in reps and weight on two telemetry
                // rows, then ONE full-width action logs exactly what it says.
                // (The old layout split logging across a small button plus a
                // row of rep chips that did the same thing, and 5-unit weight
                // steps meant 18 taps to get from the bar to a working set.)
                if !isExerciseComplete {
                    VStack(spacing: 10) {
                        SetConsoleRow(
                            label: "Reps",
                            value: "\(repsToLog)",
                            onCoarseDown: nil,
                            onDown: { repsToLog = max(1, repsToLog - 1) },
                            onUp: { repsToLog = min(50, repsToLog + 1) },
                            onCoarseUp: nil
                        )

                        SetConsoleRow(
                            label: "Weight",
                            value: weight > 0 ? weightUnit.format(weight) : "BW",
                            coarseStep: weightUnit == .kilograms ? "10" : "25",
                            onCoarseDown: { weight = max(0, weight - coarseWeightStep) },
                            onDown: { weight = max(0, weight - weightStep) },
                            onUp: { weight += weightStep },
                            onCoarseUp: { weight += coarseWeightStep }
                        )

                        Button(logButtonTitle) {
                            onQuickLogSet(repsToLog)
                        }
                        .buttonStyle(PrimaryCTAButtonStyle(accent: MorpheTheme.accent))
                        .accessibilityLabel("Log set: \(repsToLog) reps at \(weightDisplay)")
                    }
                }

                // The same four controls for EVERY exercise — More always
                // opens the custom set logger (as an extra set once the
                // planned sets are done), and Prev disables instead of hiding
                // so the row never reshuffles.
                HStack(spacing: 8) {
                    Button("More") {
                        onOpenCustomRepLogger()
                    }
                    .buttonStyle(SecondaryCTAButtonStyle())
                    .accessibilityLabel(isExerciseComplete ? "Log an extra set" : "Log a custom set with RPE")

                    Button("Rest", action: onStartRest)
                        .buttonStyle(SecondaryCTAButtonStyle())
                        .accessibilityLabel("Start rest timer")

                    Button("Prev", action: onPrevious)
                        .buttonStyle(SecondaryCTAButtonStyle())
                        .disabled(!canGoPrevious)
                        .opacity(canGoPrevious ? 1 : 0.4)

                    Button("Next", action: onNext)
                        .buttonStyle(SecondaryCTAButtonStyle())
                }
            }
        }
        .onAppear { repsToLog = suggestedReps }
        .onChange(of: exercise.id) { _, _ in repsToLog = suggestedReps }
    }
}

/// One telemetry adjuster row: micro label, mono value, fine (and optionally
/// coarse) stepper buttons flanking it.
private struct SetConsoleRow: View {
    let label: String
    let value: String
    var coarseStep: String? = nil
    let onCoarseDown: (() -> Void)?
    let onDown: () -> Void
    let onUp: () -> Void
    let onCoarseUp: (() -> Void)?

    var body: some View {
        HStack(spacing: 8) {
            Text(label.uppercased())
                .font(MorpheTheme.microLabel(10))
                .tracking(1.2)
                .foregroundStyle(MorpheTheme.textMuted)
                .frame(width: 56, alignment: .leading)

            if let onCoarseDown, let coarseStep {
                ConsoleStepButton(title: "-\(coarseStep)", action: onCoarseDown)
            }
            ConsoleStepButton(title: "−", action: onDown)

            Text(value)
                .font(.system(.title3, design: .monospaced).weight(.bold))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .frame(maxWidth: .infinity)
                .accessibilityLabel("\(label) \(value)")

            ConsoleStepButton(title: "+", action: onUp)
            if let onCoarseUp, let coarseStep {
                ConsoleStepButton(title: "+\(coarseStep)", action: onCoarseUp)
            }
        }
    }
}

/// Drives press-and-hold auto-repeat with a ramp. Owns its Timer in a class
/// because reading SwiftUI @State inside an escaping Timer closure is stale —
/// the View struct is recreated on every update.
@MainActor
final class HoldRepeater {
    private var timer: Timer?
    private var start: Date?
    private(set) var isHolding = false

    /// Repeat cadence: ~1× (a step every 0.16s) until the button has been held
    /// for 2s, then ~4× faster (every 0.04s) so weight/reps climb quickly.
    nonisolated static func interval(heldSeconds: TimeInterval) -> TimeInterval {
        heldSeconds >= 2.0 ? 0.04 : 0.16
    }

    func begin(_ action: @escaping () -> Void) {
        guard !isHolding else { return }
        isHolding = true
        start = Date()
        action()                       // a plain tap fires exactly one step
        schedule(action, after: 0.5)   // brief delay before auto-repeat kicks in
    }

    private func schedule(_ action: @escaping () -> Void, after delay: TimeInterval) {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: delay, repeats: false) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self, self.isHolding else { return }
                action()
                let held = Date().timeIntervalSince(self.start ?? Date())
                self.schedule(action, after: Self.interval(heldSeconds: held))
            }
        }
    }

    func end() {
        isHolding = false
        timer?.invalidate()
        timer = nil
        start = nil
    }
}

private struct ConsoleStepButton: View {
    let title: String
    let action: () -> Void

    @State private var repeater = HoldRepeater()
    @State private var isPressing = false

    var body: some View {
        Text(title)
            .font(.system(.subheadline, design: .monospaced).weight(.bold))
            .foregroundStyle(.white)
            .frame(minWidth: 40, minHeight: 40)
            .background(
                RoundedRectangle(cornerRadius: MorpheTheme.radius, style: .continuous)
                    .fill(isPressing ? Color.white.opacity(0.12) : Color.clear)
                    .overlay(
                        RoundedRectangle(cornerRadius: MorpheTheme.radius, style: .continuous)
                            .stroke(Color.white.opacity(0.16), lineWidth: 1)
                    )
            )
            .contentShape(Rectangle())
            // minimumDistance 0 makes this fire on touch-down, so a quick tap is
            // one step and a hold auto-repeats — no separate tap gesture needed.
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in
                        guard !isPressing else { return }
                        isPressing = true
                        Haptics.impact(.light)
                        repeater.begin(action)
                    }
                    .onEnded { _ in
                        isPressing = false
                        repeater.end()
                    }
            )
            .onDisappear { repeater.end() }
            .accessibilityElement()
            .accessibilityAddTraits(.isButton)
            .accessibilityLabel(Text(title == "−" ? "Decrease" : title == "+" ? "Increase" : title))
            .accessibilityHint("Double-tap to step; touch and hold to change quickly")
            .accessibilityAction { action() }
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
                        Rectangle()
                            .fill(activeExerciseID == exercise.id ? MorpheTheme.accent : MorpheTheme.panelStrong)
                            .frame(width: 8, height: 8)

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
                Text("Support Tools")
                    .font(.headline)
                    .foregroundStyle(.white)

                Text("Use these only when you need help. The active set stays above; swaps, pain-safe changes, and Morphe guidance stay here.")
                    .font(.subheadline)
                    .foregroundStyle(MorpheTheme.textSecondary)

                WrapStack(spacing: 8) {
                    if canGoPrevious {
                        Button("Previous Exercise", action: onPrevious)
                            .buttonStyle(FilterChipStyle(isSelected: false, selectedColor: MorpheTheme.panelStrong))
                    }

                    Button("Swap Exercise", action: onSwap)
                        .buttonStyle(FilterChipStyle(isSelected: false, selectedColor: MorpheTheme.accentAlt))

                    // Form questions happen mid-set — the full guide (steps,
                    // mistakes, alternatives) opens right here now.
                    Button("Form Guide", action: onViewForm)
                        .buttonStyle(FilterChipStyle(isSelected: false, selectedColor: MorpheTheme.accent))

                    Button("Pain Flag", action: onPain)
                        .buttonStyle(FilterChipStyle(isSelected: false, selectedColor: MorpheTheme.warning))
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Morphe can help mid-session")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(MorpheTheme.textMuted)

                    WrapStack(spacing: 8) {
                        Button("Explain Cue") {
                            showInlineAIReply(
                                title: "Explain Cue",
                                prompt: "Explain the main cue for \(exercise.name) in one short sentence for an athlete mid-workout."
                            )
                        }
                        .buttonStyle(FilterChipStyle(isSelected: inlineAIContextTitle == "Explain Cue", selectedColor: MorpheTheme.accentAlt))

                        Button("Safer Option") {
                            showInlineAIReply(
                                title: "Safer Option",
                                prompt: "Give me a safer option for \(exercise.name) in one short sentence without derailing the workout."
                            )
                        }
                        .buttonStyle(FilterChipStyle(isSelected: inlineAIContextTitle == "Safer Option", selectedColor: MorpheTheme.warning))

                        Button("Adjust Set") {
                            showInlineAIReply(
                                title: "Adjust Set",
                                prompt: "I have completed \(completedSets) of \(totalSets) sets for \(exercise.name). Tell me how to adjust the next set in one short sentence."
                            )
                        }
                        .buttonStyle(FilterChipStyle(isSelected: inlineAIContextTitle == "Adjust Set", selectedColor: MorpheTheme.accent))

                        Button("Too Easy") {
                            showInlineAIReply(
                                title: "Too Easy",
                                prompt: "\(exercise.name) feels too easy. Adjust the next set in one short sentence."
                            )
                        }
                        .buttonStyle(FilterChipStyle(isSelected: inlineAIContextTitle == "Too Easy", selectedColor: MorpheTheme.accent))

                        Button("Too Hard") {
                            showInlineAIReply(
                                title: "Too Hard",
                                prompt: "\(exercise.name) feels too hard. Give me a lighter next set in one short sentence."
                            )
                        }
                        .buttonStyle(FilterChipStyle(isSelected: inlineAIContextTitle == "Too Hard", selectedColor: MorpheTheme.warning))

                        Button("No Time") {
                            showInlineAIReply(
                                title: "No Time",
                                prompt: "I'm short on time. Tell me how to finish the rest of \(workout.name) cleanly in one short sentence."
                            )
                        }
                        .buttonStyle(FilterChipStyle(isSelected: inlineAIContextTitle == "No Time", selectedColor: MorpheTheme.lavender))
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
                        RoundedRectangle(cornerRadius: MorpheTheme.radius, style: .continuous)
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
/// Icon-led catalog: the landing view is a grid of training-style tiles
/// (icon + short name + count) grouped under five family headers, with a
/// featured Legends tile on top. Workout cards and filters only appear after
/// drilling into a style — the landing itself is nearly wordless.
private struct DiscoverCatalogSection: View {
    @Environment(MorpheAppStore.self) private var store
    let onStart: (WorkoutTemplate) -> Void
    var onSelectionChange: () -> Void = {}

    private enum Selection: Equatable {
        case category(String)
    }

    @State private var selection: Selection?
    @State private var searchQuery = ""
    @State private var goalFilter: String?
    @State private var levelFilter: DemoDifficulty?
    @State private var durationFilter: String?
    @State private var equipmentFilter: String?
    @State private var showQRConnect = false
    @State private var qrStartMode: QRConnectSheet.Mode = .show
    /// The workout whose exercises/sets/reps breakdown is open.
    @State private var detailTemplate: WorkoutTemplate?

    /// Time filters are ranges, not exact matches — catalog sessions run
    /// odd lengths (15/24/36/38 min), so exact chips would make most
    /// combinations return zero results.
    private static let durationBuckets = ["Under 20 min", "20–40 min", "Over 40 min"]

    private func durationBucket(_ minutes: Int) -> String {
        if minutes < 20 { return "Under 20 min" }
        if minutes <= 40 { return "20–40 min" }
        return "Over 40 min"
    }

    /// The v2 library's 13 categories, grouped into families for the grid.
    private static let families: [(name: String, categories: [String])] = [
        ("Build", ["Strength & Powerlifting", "Bodybuilding & Hypertrophy", "Calisthenics & Bodyweight", "Kettlebell & Dumbbell"]),
        ("Condition", ["HIIT & Conditioning", "Functional & CrossFit-Style", "Running & Cardio", "Boxing & Combat Conditioning", "Dance & Aerobics", "Sport Performance"]),
        ("Restore", ["Yoga, Mobility & Flexibility", "Pilates & Core Control", "Recovery & Longevity"])
    ]

    /// Tile-length names for the category tags.
    private static let shortCategoryNames: [String: String] = [
        "Strength & Powerlifting": "Powerlifting",
        "Bodybuilding & Hypertrophy": "Bodybuilding",
        "Calisthenics & Bodyweight": "Calisthenics",
        "Kettlebell & Dumbbell": "Kettlebell & DB",
        "HIIT & Conditioning": "HIIT",
        "Functional & CrossFit-Style": "Functional",
        "Running & Cardio": "Running & Cardio",
        "Boxing & Combat Conditioning": "Boxing",
        "Yoga, Mobility & Flexibility": "Yoga & Mobility",
        "Pilates & Core Control": "Pilates",
        "Dance & Aerobics": "Dance",
        "Sport Performance": "Sport Performance",
        "Recovery & Longevity": "Recovery"
    ]

    /// One pictogram per category — the tile reads by icon first. The newer
    /// activity glyphs get a runtime fallback for OS builds that lack them.
    private static let categorySymbols: [String: String] = [
        "Strength & Powerlifting": "dumbbell.fill",
        "Bodybuilding & Hypertrophy": "figure.strengthtraining.traditional",
        "Calisthenics & Bodyweight": "figure.gymnastics",
        "Kettlebell & Dumbbell": "figure.strengthtraining.functional",
        "HIIT & Conditioning": "bolt.fill",
        "Functional & CrossFit-Style": "figure.cross.training",
        "Running & Cardio": "figure.run",
        "Boxing & Combat Conditioning": "figure.boxing",
        "Yoga, Mobility & Flexibility": "figure.yoga",
        "Pilates & Core Control": availableSymbol("figure.pilates", fallback: "figure.core.training"),
        "Dance & Aerobics": availableSymbol("figure.dance", "figure.socialdance", fallback: "figure.mixed.cardio"),
        "Sport Performance": "sportscourt",
        "Recovery & Longevity": "leaf.fill"
    ]

    /// First SF Symbol name the current OS actually ships.
    private static func availableSymbol(_ candidates: String..., fallback: String) -> String {
        candidates.first { UIImage(systemName: $0) != nil } ?? fallback
    }

    /// The four result targets every v2 workout carries — the goal lens
    /// applies to the landing counts, drill-ins, and search alike.
    private static let goalOptions: [(tag: String, label: String)] = [
        ("weightLoss", "Weight Loss"),
        ("strengthBuilding", "Strength"),
        ("leanOut", "Lean Out"),
        ("recovery", "Recovery")
    ]

    static func goalDisplayName(_ tag: String) -> String? {
        goalOptions.first { $0.tag == tag }?.label
    }

    /// AND-composition of every active filter: duration bucket, equipment,
    /// goal, and difficulty all narrow together.
    private func matchesFilters(_ template: WorkoutTemplate) -> Bool {
        (goalFilter == nil || template.goalTag == goalFilter)
            && (durationFilter == nil || durationBucket(template.durationMinutes) == durationFilter)
            && (equipmentFilter == nil || template.equipment == equipmentFilter)
            && (levelFilter == nil || template.difficulty == levelFilter)
    }

    /// Everything browsable, narrowed by every active filter.
    private var filteredWorkouts: [WorkoutTemplate] {
        store.discoverWorkouts.filter { matchesFilters($0) }
    }

    private var activeFilterCount: Int {
        [goalFilter != nil, durationFilter != nil, equipmentFilter != nil, levelFilter != nil]
            .filter { $0 }
            .count
    }

    /// The three newest categories in the catalog. Hardcoded because catalog
    /// documents don't carry publish dates yet — these three genuinely ARE the
    /// newest additions. Becomes date-driven once the catalog carries a
    /// publishedAt field.
    private static let newestCategories: Set<String> = [
        "Pilates & Core Control", "Dance & Aerobics", "Sport Performance"
    ]

    private var newThisWeekPicks: [WorkoutTemplate] {
        filteredWorkouts.filter { Self.newestCategories.contains($0.categoryTag) }
    }

    /// Ranked by the USER'S OWN completion counts from their logs — an honest
    /// personal ranking, never a faked global popularity number.
    private var mostDonePicks: [(template: WorkoutTemplate, count: Int)] {
        var counts: [UUID: Int] = [:]
        for log in store.currentAthleteWorkoutLogs {
            guard let templateID = log.workoutTemplateID else { continue }
            counts[templateID, default: 0] += 1
        }
        return Array(
            filteredWorkouts
                .compactMap { template in counts[template.id].map { (template: template, count: $0) } }
                .sorted { $0.count > $1.count }
                .prefix(8)
        )
    }

    /// Fallback when nothing's been completed yet: the catalog workouts the
    /// user saved, pinned ones first — labeled as saved picks, not popularity.
    private var savedCatalogPicks: [WorkoutTemplate] {
        let ordered = store.savedWorkouts.sorted { $0.isPinned && !$1.isPinned }
        return Array(
            ordered
                .compactMap { item in filteredWorkouts.first { $0.id == item.workoutTemplateID } }
                .prefix(8)
        )
    }

    var body: some View {
        Group {
            if let selection {
                detailView(selection)
            } else {
                landingGrid
            }
        }
        .sheet(isPresented: $showQRConnect) {
            QRConnectSheet(mode: qrStartMode)
                .environment(store)
        }
        .sheet(item: $detailTemplate) { template in
            DiscoverWorkoutDetailSheet(template: template, onStart: { onStart(template) })
                .environment(store)
        }
    }

    // MARK: - Landing: icon tile grid

    /// Search matches name, category, style, focus, goal, AND the exercises
    /// inside each workout — "pallof" lands the Sport Performance days that
    /// program it. One lowercased haystack per item keeps 150 templates fast
    /// on every keystroke; active filters still narrow the pool.
    private var searchResults: [WorkoutTemplate] {
        let q = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !q.isEmpty else { return [] }
        return filteredWorkouts.filter { template in
            var haystack = "\(template.name) \(template.categoryTag) \(template.trainingTypeTag) \(template.focusTag) \(template.goal)"
            for exercise in template.exercises {
                haystack += " "
                haystack += exercise.name
            }
            return haystack.lowercased().contains(q)
        }
    }

    /// One person row in unified search results.
    private struct PersonResult: Identifiable {
        let id: String
        let name: String
        let detail: String
        let isCoach: Bool
    }

    /// Coaches & people: QR connections on this account, plus the coach's own
    /// roster. Real relationships only — a global directory arrives with
    /// account linking.
    private var peopleResults: [PersonResult] {
        let q = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return [] }
        var results: [PersonResult] = store.scannedConnections
            .filter { $0.name.localizedCaseInsensitiveContains(q) || $0.handle.localizedCaseInsensitiveContains(q) }
            .map {
                PersonResult(
                    id: "connection-\($0.id)",
                    name: $0.name,
                    detail: $0.handle.isEmpty ? $0.role.capitalized : "@\($0.handle) · \($0.role.capitalized)",
                    isCoach: $0.role == "coach"
                )
            }
        if store.selectedRole == .coach {
            results += store.coachClients
                .filter { $0.name.localizedCaseInsensitiveContains(q) }
                .map {
                    PersonResult(
                        id: "athlete-\($0.id.uuidString)",
                        name: $0.name,
                        detail: "\($0.sport.rawValue) · \($0.fitnessLevel)",
                        isCoach: false
                    )
                }
        }
        return results
    }

    private var postResults: [ProgressPost] {
        let q = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return [] }
        return store.communityPosts.filter {
            $0.title.localizedCaseInsensitiveContains(q)
                || $0.detail.localizedCaseInsensitiveContains(q)
                || $0.author.localizedCaseInsensitiveContains(q)
                || $0.tags.contains { $0.localizedCaseInsensitiveContains(q) }
        }
    }

    private var searchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.subheadline)
                .foregroundStyle(MorpheTheme.textMuted)
            TextField("Search workouts, coaches, posts", text: $searchQuery)
                .textFieldStyle(.plain)
                .foregroundStyle(.white)
                .autocorrectionDisabled()
            if !searchQuery.isEmpty {
                Button {
                    searchQuery = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(MorpheTheme.textMuted)
                }
                .accessibilityLabel("Clear search")
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: MorpheTheme.radius, style: .continuous)
                .fill(MorpheTheme.panelStrong)
                .overlay(
                    RoundedRectangle(cornerRadius: MorpheTheme.radius, style: .continuous)
                        .stroke(Color.white.opacity(0.12), lineWidth: 1)
                )
        )
    }

    @ViewBuilder
    private var searchResultsList: some View {
        let workouts = searchResults
        let people = peopleResults
        let posts = postResults

        if workouts.isEmpty && people.isEmpty && posts.isEmpty {
            GlassCard {
                Text("Nothing matches \"\(searchQuery)\" — try a workout style like strength or boxing, a coach's name, or a post topic.")
                    .font(.subheadline)
                    .foregroundStyle(MorpheTheme.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }

        if !workouts.isEmpty {
            sectionHeader(title: "Workouts", count: workouts.count)
            LazyVStack(spacing: 10) {
                ForEach(workouts.prefix(30)) { template in
                    DiscoverProgramCard(
                        template: template,
                        typeName: Self.shortCategoryNames[template.categoryTag] ?? template.categoryTag,
                        isSaved: store.isCatalogWorkoutSaved(template),
                        onStart: { onStart(template) },
                        onSave: { store.saveCatalogWorkout(template) },
                        onOpen: { detailTemplate = template }
                    )
                }
            }
            if workouts.count > 30 {
                Text("Showing the first 30 workouts — keep typing to narrow it down.")
                    .font(.caption2)
                    .foregroundStyle(MorpheTheme.textMuted)
            }
        }

        if !people.isEmpty {
            sectionHeader(title: "Coaches & people", count: people.count)
            GlassCard {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(people.prefix(10)) { person in
                        HStack(spacing: 10) {
                            Image(systemName: person.isCoach ? "figure.wave" : "figure.run")
                                .foregroundStyle(MorpheTheme.accent)
                                .frame(width: 24)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(person.name)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(.white)
                                Text(person.detail)
                                    .font(.caption)
                                    .foregroundStyle(MorpheTheme.textSecondary)
                            }
                            Spacer(minLength: 0)
                        }
                    }
                }
            }
        }

        if !posts.isEmpty {
            sectionHeader(title: "Posts", count: posts.count)
            GlassCard {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(posts.prefix(10)) { post in
                        VStack(alignment: .leading, spacing: 3) {
                            Text(post.title)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.white)
                                .lineLimit(1)
                            Text("\(post.author) · \(post.timeAgo)")
                                .font(.caption)
                                .foregroundStyle(MorpheTheme.textMuted)
                            Text(post.detail)
                                .font(.caption)
                                .foregroundStyle(MorpheTheme.textSecondary)
                                .lineLimit(2)
                        }
                        .padding(.vertical, 2)
                    }
                }
            }
        }
    }

    /// QR connect entry (moved here from the Messages empty state): show your
    /// Morphe code or scan a coach's / training partner's.
    private var connectCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("Connect")
                    .font(.headline)
                    .foregroundStyle(.white)

                Text("Train with people — show your Morphe code or scan a coach's.")
                    .font(.subheadline)
                    .foregroundStyle(MorpheTheme.textSecondary)

                HStack(spacing: 10) {
                    Button {
                        qrStartMode = .show
                        showQRConnect = true
                    } label: {
                        Label("My Code", systemImage: "qrcode")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(PrimaryCTAButtonStyle(accent: MorpheTheme.accent))

                    Button {
                        qrStartMode = .scan
                        showQRConnect = true
                    } label: {
                        Label("Scan", systemImage: "qrcode.viewfinder")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(SecondaryCTAButtonStyle())
                }

                if !store.scannedConnections.isEmpty {
                    Text("\(store.scannedConnections.count) connection\(store.scannedConnections.count == 1 ? "" : "s") saved")
                        .font(.caption)
                        .foregroundStyle(MorpheTheme.textMuted)
                }
            }
        }
    }

    private var landingGrid: some View {
        let byCategory = Dictionary(grouping: filteredWorkouts, by: \.categoryTag)

        return VStack(alignment: .leading, spacing: 20) {
            connectCard

            searchBar

            // Empty here means the bundled catalog failed to load — the v2
            // library ships in the bundle, so say so instead of a bare grid.
            if store.discoverWorkouts.isEmpty,
               searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                GlassCard {
                    VStack(alignment: .leading, spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.title3)
                            .foregroundStyle(MorpheTheme.accent)
                        Text("The workout library couldn't load")
                            .font(.headline)
                            .foregroundStyle(.white)
                        Text("Restart the app to reload it — your saved workouts and daily plan still work from Train.")
                            .font(.subheadline)
                            .foregroundStyle(MorpheTheme.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            } else {
                filterRow(scope: store.discoverWorkouts)
            }

            if !searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                searchResultsList
            } else {
            newThisWeekSection
            mostDoneSection
            ForEach(Self.families, id: \.name) { family in
                let presentCategories = family.categories.filter { !(byCategory[$0] ?? []).isEmpty }
                if !presentCategories.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        sectionHeader(
                            title: family.name,
                            count: presentCategories.reduce(0) { $0 + (byCategory[$1]?.count ?? 0) }
                        )

                        LazyVGrid(
                            columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)],
                            spacing: 10
                        ) {
                            ForEach(presentCategories, id: \.self) { category in
                                categoryTile(category, count: byCategory[category]?.count ?? 0)
                            }
                        }
                    }
                }
            }
            }
        }
    }

    // MARK: - New & trending shelves

    /// Horizontal shelf of the newest categories' workouts — see
    /// `newestCategories` for why the three names are hardcoded today.
    @ViewBuilder
    private var newThisWeekSection: some View {
        let picks = newThisWeekPicks
        if !picks.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                sectionHeader(title: "New This Week", count: picks.count)
                miniCardShelf(picks.prefix(10).map { ($0, nil) })
            }
        }
    }

    /// "Your Most Done" — the user's own completion counts. Falls back to
    /// their saved picks before anything's logged. Both labels are honest
    /// about whose data this is; there is no global popularity signal yet.
    @ViewBuilder
    private var mostDoneSection: some View {
        let done = mostDonePicks
        if !done.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                sectionHeader(title: "Your Most Done", count: done.count)
                miniCardShelf(done.map { ($0.template, "\($0.count)×") })
            }
        } else {
            let saved = savedCatalogPicks
            if !saved.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    sectionHeader(title: "Your Saved Picks", count: saved.count)
                    miniCardShelf(saved.map { ($0, nil) })
                }
            }
        }
    }

    private func miniCardShelf(_ entries: [(template: WorkoutTemplate, badge: String?)]) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(entries, id: \.template.id) { entry in
                    miniWorkoutCard(entry.template, badge: entry.badge)
                }
            }
        }
    }

    /// Compact shelf card — tap opens the preview sheet.
    private func miniWorkoutCard(_ template: WorkoutTemplate, badge: String?) -> some View {
        Button {
            detailTemplate = template
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .top) {
                    StatusBadge(text: template.difficulty.rawValue, color: MorpheTheme.accentAlt)
                    Spacer(minLength: 0)
                    if let badge {
                        Text(badge)
                            .font(.system(.caption, design: .monospaced).weight(.bold))
                            .foregroundStyle(MorpheTheme.accent)
                    }
                }

                Text(template.name)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.leading)
                    .lineLimit(2, reservesSpace: true)

                Text("\(template.durationMinutes) MIN • \((Self.shortCategoryNames[template.categoryTag] ?? template.categoryTag).uppercased())")
                    .font(MorpheTheme.microLabel(9))
                    .tracking(0.8)
                    .foregroundStyle(MorpheTheme.textMuted)
                    .lineLimit(1)
            }
            .padding(12)
            .frame(width: 190, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: MorpheTheme.radius, style: .continuous)
                    .fill(MorpheTheme.panelStrong)
                    .overlay(
                        RoundedRectangle(cornerRadius: MorpheTheme.radius, style: .continuous)
                            .stroke(Color.white.opacity(0.12), lineWidth: 1)
                    )
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Preview \(template.name), \(template.durationMinutes) minutes\(badge.map { ", completed \($0)" } ?? "")")
    }

    // MARK: - Combined filter row

    /// ONE composable filter line (AND semantics): Clear + active count,
    /// duration chips, equipment menu, goal chips, difficulty menu. `scope`
    /// feeds the equipment options so drilled-in categories only offer gear
    /// their workouts actually use.
    private func filterRow(scope: [WorkoutTemplate]) -> some View {
        let equipmentOptions = Array(Set(scope.map(\.equipment))).sorted()

        return ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                if activeFilterCount > 0 {
                    Button {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            goalFilter = nil
                            durationFilter = nil
                            equipmentFilter = nil
                            levelFilter = nil
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "xmark")
                                .font(.system(size: 9, weight: .bold))
                            Text("Clear")
                            Text("\(activeFilterCount)")
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(.black)
                                .frame(width: 16, height: 16)
                                .background(Circle().fill(MorpheTheme.accent))
                        }
                    }
                    .buttonStyle(FilterChipStyle(isSelected: false))
                    .accessibilityLabel("Clear \(activeFilterCount) active filters")
                }

                ForEach(Self.durationBuckets, id: \.self) { bucket in
                    Button(bucket) {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            durationFilter = durationFilter == bucket ? nil : bucket
                        }
                    }
                    .buttonStyle(FilterChipStyle(isSelected: durationFilter == bucket))
                    .accessibilityLabel("\(bucket) duration filter")
                }

                if equipmentOptions.count > 1 {
                    filterMenuChip("Equipment", selection: $equipmentFilter, options: equipmentOptions) { $0 }
                }

                ForEach(Self.goalOptions, id: \.tag) { option in
                    Button(option.label) {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            goalFilter = goalFilter == option.tag ? nil : option.tag
                        }
                    }
                    .buttonStyle(FilterChipStyle(isSelected: goalFilter == option.tag))
                    .accessibilityLabel("\(option.label) goal filter")
                }

                filterMenuChip(
                    "Difficulty",
                    selection: $levelFilter,
                    options: [DemoDifficulty.beginner, .moderate, .advanced, .recovery]
                ) { $0.rawValue }
            }
        }
    }

    /// Menu dressed as a filter chip — Menu labels can't take a ButtonStyle,
    /// so this mirrors FilterChipStyle's look by hand.
    private func filterMenuChip<Option: Hashable>(
        _ label: String,
        selection: Binding<Option?>,
        options: [Option],
        title: @escaping (Option) -> String
    ) -> some View {
        let isSelected = selection.wrappedValue != nil
        return Menu {
            Button("All") { selection.wrappedValue = nil }
            ForEach(options, id: \.self) { option in
                Button(title(option)) { selection.wrappedValue = option }
            }
        } label: {
            HStack(spacing: 5) {
                Text(selection.wrappedValue.map(title) ?? label)
                Image(systemName: "chevron.down")
                    .font(.system(size: 8, weight: .bold))
            }
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(isSelected ? .black : .white)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 2, style: .continuous)
                    .fill(isSelected ? MorpheTheme.accent : Color.white.opacity(0.04))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 2, style: .continuous)
                    .stroke(isSelected ? Color.clear : Color.white.opacity(0.10), lineWidth: 1)
            )
        }
        .accessibilityLabel("\(label) filter")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private func categoryTile(_ category: String, count: Int) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                selection = .category(category)
            }
            onSelectionChange()
        } label: {
            HStack(spacing: 10) {
                Image(systemName: Self.categorySymbols[category] ?? "square.grid.2x2")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(MorpheTheme.accent)
                    .frame(width: 26)

                VStack(alignment: .leading, spacing: 3) {
                    Text((Self.shortCategoryNames[category] ?? category).uppercased())
                        .font(MorpheTheme.microLabel(10))
                        .tracking(1.0)
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                    Text(String(format: "%03d", count))
                        .font(MorpheTheme.microLabel(9))
                        .tracking(1.0)
                        .foregroundStyle(MorpheTheme.accentAlt)
                }

                Spacer(minLength: 0)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: MorpheTheme.radius, style: .continuous)
                    .fill(MorpheTheme.panelStrong)
                    .overlay(
                        RoundedRectangle(cornerRadius: MorpheTheme.radius, style: .continuous)
                            .stroke(Color.white.opacity(0.12), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(Self.shortCategoryNames[category] ?? category), \(count) workouts")
    }

    // MARK: - Drill-in: one style's programs

    @ViewBuilder
    private func detailView(_ selection: Selection) -> some View {
        let all: [WorkoutTemplate] = {
            switch selection {
            case .category(let tag):
                return store.discoverWorkouts.filter { $0.categoryTag == tag }
            }
        }()
        let filtered = all.filter { matchesFilters($0) }
        let title: String = {
            switch selection {
            case .category(let tag): return Self.shortCategoryNames[tag] ?? tag
            }
        }()

        VStack(alignment: .leading, spacing: 12) {
            Button {
                // Filters survive the trip back — the combined row now lives
                // on the landing too, so what you set here stays visible.
                withAnimation(.easeInOut(duration: 0.2)) {
                    self.selection = nil
                }
                onSelectionChange()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 10, weight: .bold))
                    Text("ALL STYLES")
                        .font(MorpheTheme.microLabel(10))
                        .tracking(1.4)
                }
                .foregroundStyle(MorpheTheme.accent)
                .padding(.vertical, 6)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Back to all training styles")

            sectionHeader(title: title, count: filtered.count)

            filterRow(scope: all)

            if filtered.isEmpty {
                GlassCard {
                    Text("No programs match those filters — loosen one and try again.")
                        .font(.subheadline)
                        .foregroundStyle(MorpheTheme.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            } else {
                LazyVStack(spacing: 10) {
                    ForEach(filtered) { template in
                        DiscoverProgramCard(
                            template: template,
                            typeName: Self.shortCategoryNames[template.categoryTag] ?? template.categoryTag,
                            isSaved: store.isCatalogWorkoutSaved(template),
                            onStart: { onStart(template) },
                            onSave: { store.saveCatalogWorkout(template) },
                            onOpen: { detailTemplate = template }
                        )
                    }
                }
            }
        }
    }

    // MARK: - Shared chrome

    private func sectionHeader(title: String, count: Int) -> some View {
        HStack(spacing: 10) {
            Rectangle()
                .fill(MorpheTheme.accent)
                .frame(width: 3, height: 14)

            Text(title.uppercased())
                .font(.system(size: 14, design: .monospaced).weight(.bold))
                .tracking(2)
                .foregroundStyle(MorpheTheme.textPrimary)
                .lineLimit(1)
                .layoutPriority(1)

            Text(String(format: "%03d", count))
                .font(MorpheTheme.microLabel(10))
                .tracking(1.0)
                .foregroundStyle(MorpheTheme.accentAlt)

            Rectangle()
                .fill(MorpheTheme.stroke)
                .frame(height: 1)
                .frame(maxWidth: .infinity)
        }
    }

}

/// Compact program card for the drill-in list: level badge, two-line name,
/// one mono meta line, Start + save. The goal paragraph never renders here.
private struct DiscoverProgramCard: View {
    let template: WorkoutTemplate
    let typeName: String
    let isSaved: Bool
    let onStart: () -> Void
    let onSave: () -> Void
    /// Opens the exercises/sets/reps detail. Optional so older call sites
    /// without a detail surface keep compiling.
    var onOpen: (() -> Void)? = nil

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .top) {
                    StatusBadge(text: template.difficulty.rawValue, color: MorpheTheme.accentAlt)
                    if !template.goal.isEmpty {
                        StatusBadge(text: template.goal, color: MorpheTheme.accent)
                    }
                    Spacer()
                    Button(action: onSave) {
                        Image(systemName: isSaved ? "bookmark.fill" : "bookmark")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(isSaved ? MorpheTheme.accent : MorpheTheme.textSecondary)
                            .frame(width: 32, height: 24)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(isSaved ? "\(template.name) saved" : "Save \(template.name) to My Library")
                }

                // Tapping the body opens the exercise breakdown.
                Button {
                    onOpen?()
                } label: {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(alignment: .top, spacing: 6) {
                            Text(template.name)
                                .font(.subheadline.weight(.bold))
                                .foregroundStyle(.white)
                                .lineLimit(2)
                                .multilineTextAlignment(.leading)
                            if onOpen != nil {
                                Spacer(minLength: 0)
                                Image(systemName: "chevron.right")
                                    .font(.caption2.weight(.bold))
                                    .foregroundStyle(MorpheTheme.textMuted)
                                    .padding(.top, 3)
                            }
                        }

                        Text("\(template.durationMinutes) MIN • \(template.equipment.uppercased()) • \(typeName.uppercased())")
                            .font(MorpheTheme.microLabel(9))
                            .tracking(0.8)
                            .foregroundStyle(MorpheTheme.textMuted)
                            .lineLimit(1)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(onOpen == nil)
                .accessibilityLabel("See what \(template.name) consists of")

                Button("Start", action: onStart)
                    .buttonStyle(PrimaryCTAButtonStyle(accent: MorpheTheme.accent))
                    .accessibilityLabel("Start \(template.name)")
            }
        }
        .accessibilityElement(children: .contain)
    }
}

/// The preview sheet behind every Discover card: pills, coach note, and the
/// exercise list with a form-diagram thumbnail per row.
private struct DiscoverWorkoutDetailSheet: View {
    @Environment(MorpheAppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let template: WorkoutTemplate
    let onStart: () -> Void

    /// Form diagrams keyed by exerciseLibraryID, loaded once in .task —
    /// synchronous disk reads in body are a known perf bug pattern here.
    @State private var formDiagrams: [String: UIImage] = [:]

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text(template.name)
                            .font(.title3.weight(.bold))
                            .foregroundStyle(.white)

                        // Category / goal / duration / difficulty pills.
                        FlowingPillRow(pills: pillTexts)

                        if !template.coachNote.isEmpty {
                            Text(template.coachNote)
                                .font(.caption)
                                .foregroundStyle(MorpheTheme.textMuted)
                        }
                    }

                    GlassCard {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Exercises (\(template.exercises.count))")
                                .font(.headline)
                                .foregroundStyle(.white)

                            ForEach(Array(template.exercises.enumerated()), id: \.element.id) { index, exercise in
                                HStack(alignment: .top, spacing: 10) {
                                    diagramThumbnail(for: exercise)

                                    VStack(alignment: .leading, spacing: 3) {
                                        HStack(alignment: .top) {
                                            Text("\(index + 1). \(exercise.name)")
                                                .font(.subheadline.weight(.semibold))
                                                .foregroundStyle(.white)
                                            Spacer()
                                            Text("\(exercise.sets) × \(exercise.reps)")
                                                .font(.system(.subheadline, design: .monospaced).weight(.semibold))
                                                .foregroundStyle(MorpheTheme.accent)
                                        }
                                        // Prescription line: effort + rest, when
                                        // the catalog carries them.
                                        let prescription = [
                                            exercise.intensityLabel,
                                            exercise.restSeconds.map { "rest \($0)s" } ?? ""
                                        ].filter { !$0.isEmpty }.joined(separator: " · ")
                                        Text(prescription.isEmpty
                                             ? exercise.muscleGroup.rawValue
                                             : "\(exercise.muscleGroup.rawValue) · \(prescription)")
                                            .font(.caption)
                                            .foregroundStyle(MorpheTheme.textSecondary)
                                        if !exercise.formCue.isEmpty {
                                            Text(exercise.formCue)
                                                .font(.caption)
                                                .foregroundStyle(MorpheTheme.textMuted)
                                        }
                                    }
                                }
                                if index < template.exercises.count - 1 {
                                    Divider().overlay(Color.white.opacity(0.08))
                                }
                            }
                        }
                    }

                    HStack(spacing: 10) {
                        Button("Start") {
                            dismiss()
                            onStart()
                        }
                        .buttonStyle(PrimaryCTAButtonStyle(accent: MorpheTheme.accent))
                        .accessibilityLabel("Start \(template.name) now")

                        // Queue = stage as today's workout in Train without
                        // starting the live session.
                        Button("Queue") {
                            dismiss()
                            store.openWorkoutTemplate(template)
                        }
                        .buttonStyle(SecondaryCTAButtonStyle())
                        .accessibilityLabel("Queue \(template.name) in Train")

                        Button(store.isCatalogWorkoutSaved(template) ? "Saved" : "Save") {
                            store.saveCatalogWorkout(template)
                        }
                        .buttonStyle(SecondaryCTAButtonStyle())
                        .accessibilityLabel(store.isCatalogWorkoutSaved(template) ? "\(template.name) saved" : "Save \(template.name) to My Library")
                    }
                }
                .padding(20)
            }
            .background(PremiumBackground())
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }.foregroundStyle(.white)
                }
            }
            .task {
                formDiagrams = await Self.loadDiagrams(
                    for: template.exercises.map(\.exerciseLibraryID)
                )
            }
        }
    }

    private var pillTexts: [String] {
        var pills: [String] = []
        if !template.categoryTag.isEmpty { pills.append(template.categoryTag) }
        if !template.goal.isEmpty { pills.append(template.goal) }
        pills.append("\(template.durationMinutes) min")
        pills.append(template.difficulty.rawValue)
        pills.append(template.equipment)
        return pills
    }

    @ViewBuilder
    private func diagramThumbnail(for exercise: WorkoutExercise) -> some View {
        if let image = formDiagrams[exercise.exerciseLibraryID] {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: 44, height: 44)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .accessibilityLabel("Form diagram for \(exercise.name)")
        } else {
            // Placeholder while diagrams load (or if one is missing).
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(MorpheTheme.panelStrong)
                .frame(width: 44, height: 44)
                .overlay(
                    Image(systemName: "figure.strengthtraining.traditional")
                        .font(.caption)
                        .foregroundStyle(MorpheTheme.textMuted)
                )
                .accessibilityHidden(true)
        }
    }

    /// Reads every diagram off the main actor in one pass; UIImage decode +
    /// disk IO for a dozen HEICs is exactly what .task exists for.
    nonisolated private static func loadDiagrams(for libraryIDs: [String]) async -> [String: UIImage] {
        var result: [String: UIImage] = [:]
        for id in Set(libraryIDs) {
            guard let url = Bundle.main.url(
                forResource: id,
                withExtension: "heic",
                subdirectory: "FormDiagrams"
            ), let image = UIImage(contentsOfFile: url.path) else { continue }
            result[id] = image
        }
        return result
    }
}

/// Wrapping row of small status pills (category, goal, duration, level).
private struct FlowingPillRow: View {
    let pills: [String]

    var body: some View {
        // A simple wrapping layout via LazyVGrid would force equal cells;
        // pills vary a lot in width, so a plain wrapping HStack via
        // ScrollView keeps it one tidy line that scrolls if it must.
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(pills, id: \.self) { pill in
                    Text(pill.uppercased())
                        .font(MorpheTheme.microLabel(9))
                        .tracking(0.8)
                        .lineLimit(1)
                        .foregroundStyle(MorpheTheme.textSecondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .background(
                            Capsule()
                                .fill(MorpheTheme.panelStrong)
                                .overlay(Capsule().stroke(Color.white.opacity(0.12), lineWidth: 1))
                        )
                }
            }
        }
    }
}

/// Replaces TodaysWorkoutCard once the day's session is logged: a nudge
/// toward something NEW, with one concrete pick each for training,
/// stretching, and recovery.
private struct TrySomethingNewCard: View {
    let recommendations: [(category: String, template: WorkoutTemplate)]
    let onStartPick: (WorkoutTemplate) -> Void
    let onBrowse: () -> Void

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("Want to try something new?")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(.white)

                Text("Today's workout is done. A second session, a stretch, or an easy recovery block all count extra.")
                    .font(.subheadline)
                    .foregroundStyle(MorpheTheme.textSecondary)

                ForEach(recommendations, id: \.template.id) { rec in
                    Button {
                        onStartPick(rec.template)
                    } label: {
                        HStack(spacing: 10) {
                            Text(rec.category.uppercased())
                                .font(MorpheTheme.microLabel(10))
                                .tracking(1.2)
                                .foregroundStyle(MorpheTheme.accent)
                                .frame(width: 84, alignment: .leading)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(rec.template.name)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(.white)
                                    .lineLimit(1)
                                Text("\(rec.template.durationMinutes) min")
                                    .font(.caption)
                                    .foregroundStyle(MorpheTheme.textSecondary)
                            }
                            Spacer()
                            Image(systemName: "play.circle.fill")
                                .foregroundStyle(MorpheTheme.accent)
                        }
                        .padding(10)
                        .background(
                            RoundedRectangle(cornerRadius: MorpheTheme.radius, style: .continuous)
                                .fill(Color.white.opacity(0.04))
                        )
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Start \(rec.template.name), \(rec.category)")
                }

                Button("Browse Discover") {
                    onBrowse()
                }
                .buttonStyle(SecondaryCTAButtonStyle())
            }
        }
    }
}

/// THE workout card on Train — the same session the Today hero shows, with
/// one Start. Morphe's readiness-based pick appears as an inline suggestion
/// ("use this instead"), not a competing card with its own name.
private struct TodaysWorkoutCard: View {
    let workout: WorkoutTemplate
    let suggestion: GoodForTodayWorkoutRecommendation?
    /// Non-nil once a party exists ("Code F7KQ2M · waiting for your buddy").
    let partyStatus: String?
    let onStart: () -> Void
    let onUseSuggestion: () -> Void
    let onSwitch: () -> Void
    let onTrainTogether: () -> Void

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

                Button {
                    onTrainTogether()
                } label: {
                    Label(partyStatus ?? "Train together", systemImage: "person.2")
                }
                .buttonStyle(SecondaryCTAButtonStyle())
                .accessibilityLabel(partyStatus == nil ? "Train together with a buddy" : "Show your session code")

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

                        Button("Use This", action: onUseSuggestion)
                            .buttonStyle(FilterChipStyle(isSelected: false, selectedColor: MorpheTheme.accentAlt))
                            .accessibilityLabel("Switch today's workout to \(suggestion.workoutName)")
                    }
                }
            }
        }
    }
}

// MARK: - Train Together

/// One sheet for every way of training with someone: host a session (QR +
/// code to share) or join one (scan or type the code). Once a party exists
/// the sheet shows the roster; everything else about the session is the
/// normal workout flow.
struct TrainTogetherSheet: View {
    @Environment(MorpheAppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var joinCode = ""
    @State private var hostMode: PartyMode = .inPerson
    @State private var hasClassTime = false
    @State private var classTime = Date.now.addingTimeInterval(3600)

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 16) {
                    if store.activeParty != nil {
                        activePartyCard
                    } else {
                        hostCard
                        joinCard
                    }
                }
                .padding(20)
            }
            .background(PremiumBackground())
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Train Together").font(.headline).foregroundStyle(.white)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }.foregroundStyle(.white)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private var hostCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                Label("Host a session", systemImage: "person.2.fill")
                    .font(.headline)
                    .foregroundStyle(.white)

                Text("Train \(store.currentWorkout.name) with a buddy. They scan your code (or type it) and the exact same workout starts on their phone — everyone logs their own sets.")
                    .font(.subheadline)
                    .foregroundStyle(MorpheTheme.textSecondary)

                WrapStack(spacing: 8) {
                    Button("Same Gym") { hostMode = .inPerson }
                        .buttonStyle(FilterChipStyle(isSelected: hostMode == .inPerson, selectedColor: MorpheTheme.accent))
                    Button("Somewhere Else") { hostMode = .virtualSession }
                        .buttonStyle(FilterChipStyle(isSelected: hostMode == .virtualSession, selectedColor: MorpheTheme.accentAlt))
                    Button("Group Class") { hostMode = .group }
                        .buttonStyle(FilterChipStyle(isSelected: hostMode == .group, selectedColor: MorpheTheme.warning))
                }

                Text(hostModeCaption)
                    .font(.caption)
                    .foregroundStyle(MorpheTheme.textMuted)

                if hostMode == .group {
                    Toggle("Set a class time", isOn: $hasClassTime)
                        .font(.subheadline)
                        .foregroundStyle(.white)
                        .tint(MorpheTheme.accent)
                    if hasClassTime {
                        DatePicker("Class starts", selection: $classTime, displayedComponents: [.hourAndMinute])
                            .font(.subheadline)
                            .foregroundStyle(.white)
                            .tint(MorpheTheme.accent)
                    }
                }

                Button(store.isPartyBusy
                       ? "Starting…"
                       : (hostMode == .group ? "Open Lobby" : "Start Session")) {
                    Task {
                        await store.startTrainTogether(
                            mode: hostMode,
                            classTime: hostMode == .group && hasClassTime ? classTime : nil
                        )
                    }
                }
                .buttonStyle(PrimaryCTAButtonStyle(accent: MorpheTheme.accent))
                .disabled(store.isPartyBusy)
                .accessibilityLabel(hostMode == .group ? "Open the class lobby" : "Start a buddy session")
            }
        }
    }

    private var hostModeCaption: String {
        switch hostMode {
        case .inPerson:
            return "You're training side by side — the app stays out of the way and shares one recap at the end."
        case .virtualSession:
            return "Training apart: you'll see each other's exercise and sets live, trade nudges, and can FaceTime from the session. No video inside Morphe — FaceTime handles that."
        case .group:
            return "A class anyone can join with your code. Everyone waits in the lobby, you start the workout for the whole group at once, and the session shows a live set leaderboard."
        }
    }

    private var joinCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                Label("Join a session", systemImage: "qrcode.viewfinder")
                    .font(.headline)
                    .foregroundStyle(.white)

                QRScannerView { payload in
                    guard let code = MorpheAppStore.partyCode(fromScanned: payload) else { return }
                    Task {
                        if await store.joinParty(code: code) { dismiss() }
                    }
                }
                .frame(height: 200)
                .clipShape(RoundedRectangle(cornerRadius: MorpheTheme.radius, style: .continuous))

                HStack(spacing: 10) {
                    TextField("Or type the code (e.g. F7KQ2M)", text: $joinCode)
                        .textFieldStyle(MorpheFieldStyle())
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                    Button("Join") {
                        Task {
                            if await store.joinParty(code: joinCode) { dismiss() }
                        }
                    }
                    .buttonStyle(SecondaryCTAButtonStyle())
                    .frame(width: 80)
                    .disabled(joinCode.trimmingCharacters(in: .whitespaces).isEmpty || store.isPartyBusy)
                }
            }
        }
    }

    private var activePartyCard: some View {
        GlassCard {
            VStack(spacing: 14) {
                if let party = store.activeParty {
                    Text(party.workoutName)
                        .font(.title3.weight(.bold))
                        .foregroundStyle(.white)

                    if let payload = store.partyQRPayload,
                       let image = QRCodeRenderer.image(for: payload) {
                        Image(uiImage: image)
                            .interpolation(.none)
                            .resizable()
                            .scaledToFit()
                            .frame(maxWidth: 200)
                            .padding(10)
                            .background(
                                RoundedRectangle(cornerRadius: MorpheTheme.radius, style: .continuous)
                                    .fill(.white)
                            )
                    }

                    Text(party.id)
                        .font(.system(size: 30, design: .monospaced).weight(.bold))
                        .tracking(6)
                        .foregroundStyle(MorpheTheme.accent)

                    Text(party.mode == .group
                         ? "Anyone with this code joins your class."
                         : "Have your buddy scan this, or read them the code.")
                        .font(.caption)
                        .foregroundStyle(MorpheTheme.textMuted)
                        .multilineTextAlignment(.center)

                    if let startsAt = party.startsAt {
                        Label("Class time: \(startsAt.formatted(date: .omitted, time: .shortened))", systemImage: "clock")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(MorpheTheme.accentAlt)
                    }

                    Divider().overlay(Color.white.opacity(0.08))

                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(party.participants) { member in
                            HStack(spacing: 10) {
                                Image(systemName: member.isHost ? "star.fill" : "figure.run")
                                    .font(.caption)
                                    .foregroundStyle(MorpheTheme.accent)
                                Text(member.name)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(.white)
                                Spacer()
                                Text(memberStatus(member, party: party))
                                    .font(.caption)
                                    .foregroundStyle(MorpheTheme.textSecondary)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    if party.mode == .group, party.status == .lobby {
                        if store.isPartyHost {
                            Button("Start Class") {
                                store.startGroupClass()
                                dismiss()
                            }
                            .buttonStyle(PrimaryCTAButtonStyle(accent: MorpheTheme.accent))
                        } else {
                            Text("Waiting for \(party.hostName) to start the class — your workout launches automatically.")
                                .font(.caption)
                                .foregroundStyle(MorpheTheme.textSecondary)
                                .multilineTextAlignment(.center)
                        }
                    }

                    Button("Leave Session") {
                        store.leaveParty()
                        dismiss()
                    }
                    .buttonStyle(SecondaryCTAButtonStyle())
                }
            }
            .frame(maxWidth: .infinity)
        }
    }

    private func memberStatus(_ member: PartyParticipant, party: WorkoutParty) -> String {
        if member.isFinished { return "Finished" }
        if party.status == .lobby { return "In lobby" }
        return "In session"
    }
}

/// Slim buddy roster above the live console — names and where they are.
/// Virtual sessions add ready state, nudges, and a FaceTime handoff.
/// Only rendered while a party is active.
struct PartySessionStrip: View {
    @Environment(MorpheAppStore.self) private var store
    @Environment(\.openURL) private var openURL

    private var isVirtual: Bool { store.activeParty?.mode == .virtualSession }
    private var isGroup: Bool { store.activeParty?.mode == .group }
    /// Nudges apply whenever people train apart (virtual or class).
    private var syncsLive: Bool { isVirtual || isGroup }

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 8) {
                if let party = store.activeParty {
                    HStack {
                        Label(stripTitle, systemImage: isGroup ? "person.3.fill" : "person.2.fill")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(MorpheTheme.accent)
                        Spacer()
                        Text("Code \(party.id)")
                            .font(.caption.monospaced())
                            .foregroundStyle(MorpheTheme.textMuted)
                    }

                    if isGroup {
                        // Leaderboard: everyone in the class by sets logged.
                        ForEach(Array(store.partyLeaderboard.enumerated()), id: \.element.id) { rank, member in
                            HStack(spacing: 8) {
                                Text("\(rank + 1)")
                                    .font(.caption.monospaced().weight(.bold))
                                    .foregroundStyle(rank == 0 ? MorpheTheme.accent : MorpheTheme.textMuted)
                                    .frame(width: 18, alignment: .leading)
                                Text(member.name)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(.white)
                                Spacer()
                                Text(member.isFinished ? "Finished" : "\(member.totalSetsDone) sets")
                                    .font(.caption)
                                    .foregroundStyle(MorpheTheme.textSecondary)
                            }
                        }
                    } else if store.partyBuddies.isEmpty {
                        Text("Waiting for your buddy to join…")
                            .font(.caption)
                            .foregroundStyle(MorpheTheme.textSecondary)
                    } else {
                        ForEach(store.partyBuddies) { buddy in
                            HStack(spacing: 8) {
                                Text(buddy.name)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(.white)
                                Spacer()
                                Text(buddyStatus(buddy))
                                    .font(.caption)
                                    .foregroundStyle(MorpheTheme.textSecondary)
                            }
                        }
                    }

                    if syncsLive {
                        HStack(spacing: 8) {
                            if !store.partyIsReadySelf {
                                Button("I'm Ready") { store.markPartyReady() }
                                    .buttonStyle(FilterChipStyle(isSelected: false, selectedColor: MorpheTheme.accent))
                            }
                            ForEach(MorpheAppStore.partyNudgeEmojis, id: \.self) { emoji in
                                Button(emoji) { store.sendPartyNudge(emoji) }
                                    .buttonStyle(FilterChipStyle(isSelected: false, selectedColor: MorpheTheme.accentAlt))
                                    .accessibilityLabel("Send \(emoji) to your buddy")
                            }
                            Spacer()
                            if isVirtual,
                               let email = store.partyBuddies.first(where: { !$0.email.isEmpty })?.email,
                               let url = URL(string: "facetime://\(email)") {
                                Button {
                                    openURL(url)
                                } label: {
                                    Label("FaceTime", systemImage: "video.fill")
                                        .font(.caption.weight(.semibold))
                                }
                                .buttonStyle(FilterChipStyle(isSelected: false, selectedColor: MorpheTheme.accent))
                            }
                        }
                    }
                }
            }
        }
    }

    private var stripTitle: String {
        if isGroup { return "Class · live" }
        return isVirtual ? "Training together · virtual" : "Training together"
    }

    private func buddyStatus(_ buddy: PartyParticipant) -> String {
        if buddy.isFinished { return "Finished" }
        if !buddy.exerciseName.isEmpty {
            return "\(buddy.exerciseName) · set \(buddy.setsDone + 1)"
        }
        return buddy.isReady ? "Ready" : "Getting set up"
    }
}

/// End-of-session shared recap: each buddy's published totals, or a note
/// that they're still going.
private struct PartyRecapCard: View {
    let buddies: [PartyParticipant]

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 10) {
                Text("Trained with")
                    .font(.headline)
                    .foregroundStyle(.white)

                ForEach(buddies) { buddy in
                    HStack(spacing: 10) {
                        Image(systemName: "figure.run")
                            .foregroundStyle(MorpheTheme.accent)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(buddy.name)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.white)
                            Text(buddy.summary.isEmpty ? "Still training — totals land when they log." : buddy.summary)
                                .font(.caption)
                                .foregroundStyle(MorpheTheme.textSecondary)
                        }
                        Spacer()
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

                Button("Ready Check", action: onReadyCheck)
                    .buttonStyle(SecondaryCTAButtonStyle())
                    .accessibilityLabel("Send a ready check to your buddy")
            }
        }
    }
}

private struct WorkoutRestControlBar: View {
    @Binding var seconds: Int
    @Binding var isRunning: Bool
    var exerciseName: String = "Next set"
    @State private var countdownTask: Task<Void, Never>?
    /// Wall-clock end of the running countdown — the Live Activity's anchor,
    /// and the truth the in-app timer resyncs to after the app was suspended.
    @State private var countdownEndDate: Date?
    @Environment(\.scenePhase) private var scenePhase

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
                        // A mid-countdown change moves the lock-screen timer too.
                        if isRunning {
                            countdownEndDate = Date().addingTimeInterval(TimeInterval(preset))
                            RestTimerActivityController.update(secondsRemaining: preset)
                        }
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
        // The 1s loop suspends with the app; the lock-screen Live Activity
        // runs on wall clock. Coming back to the foreground, the in-app
        // number resyncs to the same wall clock so they never disagree.
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active, isRunning, let end = countdownEndDate else { return }
            seconds = max(Int(end.timeIntervalSinceNow.rounded()), 0)
            if seconds == 0 {
                isRunning = false
            }
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
        countdownEndDate = Date().addingTimeInterval(TimeInterval(seconds))
        // Mirror the countdown to the lock screen / Dynamic Island.
        RestTimerActivityController.start(exerciseName: exerciseName, secondsRemaining: seconds)
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
        countdownEndDate = nil
        RestTimerActivityController.end()
    }
}

// MARK: - Circuit Mode

/// Full-screen guided interval runner over the live session's exercises:
/// configure rounds and work/rest timing, run the stations with auto-advance,
/// then log exactly what happened back into the tracked session.
///
/// HONEST-LOGGING CONVENTION: a timed circuit interval is ONE tracked set.
/// `reps: 1` means "one finished work interval", never a rep count — the set
/// label carries the truth ("Circuit: 40s work"), the same way superset and
/// dropset sets already encode their sub-work in labels. Weight logs as 0
/// (bodyweight). Skipped or interrupted intervals are never logged.
private struct CircuitModeView: View {
    @Environment(MorpheAppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase

    /// One exercise slot in the circuit. `id` is the WorkoutExercise id so
    /// finished intervals log back to the right exercise.
    private struct Station: Identifiable {
        let id: String
        let name: String
        var workSeconds: Int
        var isEnabled = true
    }

    /// One finished work interval — the only unit the summary ever logs.
    private struct CompletedInterval {
        let stationID: String
        let workSeconds: Int
    }

    private enum Phase { case setup, running, summary }
    private enum Segment { case work, stationRest, roundRest }

    // Config
    @State private var stations: [Station]
    @State private var rounds = 3
    @State private var stationRestSeconds = 15
    @State private var roundRestSeconds = 60

    // Runner
    @State private var phase: Phase = .setup
    @State private var segment: Segment = .work
    @State private var roundIndex = 0
    @State private var stationIndex = 0
    @State private var remaining = 0
    @State private var segmentLength = 1
    @State private var isPaused = false
    @State private var endedEarly = false
    @State private var showEndConfirm = false
    @State private var completedIntervals: [CompletedInterval] = []
    /// Stations snapshotted at Start, so nothing can shift mid-run.
    @State private var runStations: [Station] = []
    /// Wall-clock end of the running segment — the truth the 1s ticker
    /// resyncs to after a suspension (same pattern as WorkoutRestControlBar).
    @State private var segmentEndDate: Date?
    @State private var tickTask: Task<Void, Never>?

    init(exercises: [WorkoutExercise]) {
        _stations = State(initialValue: exercises.map { exercise in
            Station(
                id: exercise.id,
                name: exercise.name,
                workSeconds: Self.templateWorkSeconds(from: exercise.reps) ?? 40
            )
        })
    }

    /// Reads timed work off the catalog display string ("45 sec", "3 min");
    /// rep-based moves ("8 reps") carry no template interval. Clamped to a
    /// circuit-sensible 10–120s — a "20 min" steady-state block is not a
    /// station length.
    private static func templateWorkSeconds(from repsLabel: String) -> Int? {
        let lower = repsLabel.lowercased()
        guard let value = Int(
            lower.components(separatedBy: CharacterSet.decimalDigits.inverted)
                .first(where: { !$0.isEmpty }) ?? ""
        ) else { return nil }
        if lower.contains("min") { return min(max(value * 60, 10), 120) }
        if lower.contains("sec") { return min(max(value, 10), 120) }
        return nil
    }

    var body: some View {
        ZStack {
            PremiumBackground()

            switch phase {
            case .setup: setupView
            case .running: runnerView
            case .summary: summaryView
            }
        }
        .onChange(of: phase) { _, newPhase in
            // The runner must outlast the auto-lock timeout; every other
            // phase gives the normal screen sleep straight back.
            UIApplication.shared.isIdleTimerDisabled = (newPhase == .running)
        }
        .onDisappear {
            // Defer-safe restore: however this cover exits — log, discard,
            // or the session ending underneath it — the idle timer and the
            // ticker never outlive it.
            UIApplication.shared.isIdleTimerDisabled = false
            tickTask?.cancel()
        }
        // The 1s loop suspends with the app; resync to wall clock on return
        // so the countdown never drifts. Time that fully elapsed while
        // suspended ends the segment on the next tick — the runner resumes
        // at the boundary instead of fast-forwarding through unseen work.
        .onChange(of: scenePhase) { _, newScene in
            guard newScene == .active, phase == .running, !isPaused,
                  let end = segmentEndDate else { return }
            remaining = min(max(Int(end.timeIntervalSinceNow.rounded()), 0), segmentLength)
        }
    }

    // MARK: Setup

    private var enabledStations: [Station] { stations.filter(\.isEnabled) }

    /// The work chip that matches every enabled station, if they agree.
    private var uniformWorkSeconds: Int? {
        let values = Set(enabledStations.map(\.workSeconds))
        return values.count == 1 ? values.first : nil
    }

    /// Honest plan length: all work + rests, rounded up to whole minutes.
    private var estimatedMinutes: Int {
        let work = enabledStations.reduce(0) { $0 + $1.workSeconds }
        let perRound = work + stationRestSeconds * max(enabledStations.count - 1, 0)
        let total = perRound * rounds + roundRestSeconds * max(rounds - 1, 0)
        return max(Int((Double(total) / 60).rounded(.up)), 1)
    }

    private var setupView: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 16) {
                coverHeader(
                    title: "Circuit Mode",
                    subtitle: "Timed stations over this session's exercises. Only finished work intervals get logged — one set per interval."
                )

                GlassCard {
                    VStack(alignment: .leading, spacing: 14) {
                        configLabel("Rounds")
                        SetConsoleRow(
                            label: "Rounds",
                            value: "\(rounds)",
                            onCoarseDown: nil,
                            onDown: { rounds = max(rounds - 1, 1) },
                            onUp: { rounds = min(rounds + 1, 8) },
                            onCoarseUp: nil
                        )

                        configLabel("Work")
                        secondsChipRow([20, 30, 40, 60], selected: uniformWorkSeconds) { value in
                            for index in stations.indices { stations[index].workSeconds = value }
                        }

                        configLabel("Station rest")
                        secondsChipRow([10, 15, 20, 30], selected: stationRestSeconds) { value in
                            stationRestSeconds = value
                        }

                        configLabel("Round rest")
                        secondsChipRow([30, 60, 90], selected: roundRestSeconds) { value in
                            roundRestSeconds = value
                        }
                    }
                }

                GlassCard {
                    VStack(alignment: .leading, spacing: 10) {
                        configLabel("Stations")

                        ForEach($stations) { $station in
                            Button {
                                station.isEnabled.toggle()
                            } label: {
                                HStack(spacing: 10) {
                                    Image(systemName: station.isEnabled ? "checkmark.square.fill" : "square")
                                        .foregroundStyle(station.isEnabled ? MorpheTheme.accent : MorpheTheme.textMuted)
                                    Text(station.name)
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(station.isEnabled ? .white : MorpheTheme.textMuted)
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.8)
                                    Spacer()
                                    Text("\(station.workSeconds)s")
                                        .font(.system(.subheadline, design: .monospaced).weight(.bold))
                                        .foregroundStyle(station.isEnabled ? MorpheTheme.accent : MorpheTheme.textMuted)
                                }
                                .padding(10)
                                .background(
                                    RoundedRectangle(cornerRadius: MorpheTheme.radius, style: .continuous)
                                        .fill(station.isEnabled ? MorpheTheme.panelStrong : MorpheTheme.panel)
                                )
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("\(station.name), \(station.workSeconds) seconds, \(station.isEnabled ? "included" : "excluded")")
                            .accessibilityHint("Double-tap to \(station.isEnabled ? "exclude from" : "include in") the circuit")
                        }

                        if enabledStations.isEmpty {
                            Text("Turn at least one station on to start.")
                                .font(.footnote)
                                .foregroundStyle(MorpheTheme.warning)
                        } else {
                            Text("\(rounds) round\(rounds == 1 ? "" : "s") × \(enabledStations.count) station\(enabledStations.count == 1 ? "" : "s") ≈ \(estimatedMinutes) min")
                                .font(.system(.footnote, design: .monospaced).weight(.semibold))
                                .foregroundStyle(MorpheTheme.textMuted)
                        }
                    }
                }

                Button("Start Circuit") { startCircuit() }
                    .buttonStyle(PrimaryCTAButtonStyle(accent: MorpheTheme.accent))
                    .disabled(enabledStations.isEmpty)
                    .opacity(enabledStations.isEmpty ? 0.5 : 1)
            }
            .padding(20)
        }
    }

    private func configLabel(_ text: String) -> some View {
        Text(text.uppercased())
            .font(MorpheTheme.microLabel(10))
            .tracking(1.4)
            .foregroundStyle(MorpheTheme.textMuted)
    }

    private func secondsChipRow(_ presets: [Int], selected: Int?, onPick: @escaping (Int) -> Void) -> some View {
        HStack(spacing: 8) {
            ForEach(presets, id: \.self) { preset in
                Button("\(preset)s") { onPick(preset) }
                    .buttonStyle(FilterChipStyle(isSelected: selected == preset))
            }
        }
    }

    private func coverHeader(title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title.uppercased())
                    .font(.system(size: 17, design: .monospaced).weight(.heavy))
                    .tracking(2)
                    .foregroundStyle(.white)
                Spacer()
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(.white)
                        .frame(width: 34, height: 34)
                        .background(
                            RoundedRectangle(cornerRadius: MorpheTheme.radius, style: .continuous)
                                .stroke(Color.white.opacity(0.16), lineWidth: 1)
                        )
                        .contentShape(Rectangle())
                }
                .accessibilityLabel("Close circuit mode")
            }
            Text(subtitle)
                .font(.footnote)
                .foregroundStyle(MorpheTheme.textSecondary)
        }
    }

    // MARK: Runner

    private var currentStation: Station? {
        runStations.indices.contains(stationIndex) ? runStations[stationIndex] : nil
    }

    private var segmentTitle: String {
        switch segment {
        case .work: return "Work"
        case .stationRest: return "Rest"
        case .roundRest: return "Round rest"
        }
    }

    private var segmentColor: Color {
        switch segment {
        case .work: return MorpheTheme.accent
        case .stationRest: return MorpheTheme.accentAlt
        case .roundRest: return MorpheTheme.lavender
        }
    }

    /// The huge center line: the station being worked, or the one to get
    /// ready for during a rest.
    private var displayStationName: String {
        switch segment {
        case .work:
            return currentStation?.name ?? ""
        case .stationRest:
            return runStations.indices.contains(stationIndex + 1) ? runStations[stationIndex + 1].name : ""
        case .roundRest:
            return runStations.first?.name ?? ""
        }
    }

    private var nextPreviewText: String? {
        switch segment {
        case .work:
            if runStations.indices.contains(stationIndex + 1) {
                return "Next: \(runStations[stationIndex + 1].name)"
            }
            if roundIndex + 1 < rounds { return "Next: round rest" }
            return "Last station"
        case .stationRest:
            return "Get ready"
        case .roundRest:
            return "Round \(roundIndex + 2) of \(rounds) starts next"
        }
    }

    private var ringProgress: Double {
        Double(remaining) / Double(max(segmentLength, 1))
    }

    private var runnerView: some View {
        VStack(spacing: 20) {
            HStack {
                StatusBadge(text: "Round \(roundIndex + 1) / \(rounds)", color: MorpheTheme.accent)
                StatusBadge(text: "Station \(min(stationIndex + 1, runStations.count)) / \(runStations.count)", color: MorpheTheme.lavender)
                Spacer()
                Button("End") { showEndConfirm = true }
                    .buttonStyle(FilterChipStyle(isSelected: false, selectedColor: MorpheTheme.danger))
                    .accessibilityLabel("End circuit early")
            }

            Spacer()

            // Countdown ring: hairline track, accent arc draining clockwise —
            // the MorpheLoadingMark arc language at telemetry scale.
            ZStack {
                Circle()
                    .stroke(MorpheTheme.stroke, lineWidth: 10)
                Circle()
                    .trim(from: 0, to: ringProgress)
                    .stroke(segmentColor, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    // Animate the drain, not the refill jump at segment start.
                    .animation(remaining == segmentLength ? nil : .linear(duration: 1), value: remaining)

                VStack(spacing: 8) {
                    Text(segmentTitle.uppercased())
                        .font(MorpheTheme.microLabel(12))
                        .tracking(2.2)
                        .foregroundStyle(segmentColor)
                    Text(timeString(remaining))
                        .font(.system(size: 58, design: .monospaced).weight(.heavy))
                        .foregroundStyle(.white)
                        .contentTransition(.numericText(countsDown: true))
                        .animation(.linear(duration: 0.3), value: remaining)
                    if isPaused {
                        Text("PAUSED")
                            .font(MorpheTheme.microLabel(11))
                            .tracking(2)
                            .foregroundStyle(MorpheTheme.warning)
                    }
                }
            }
            .frame(width: 250, height: 250)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(segmentTitle), \(timeString(remaining)) remaining\(isPaused ? ", paused" : "")")

            VStack(spacing: 8) {
                Text(displayStationName)
                    .font(.system(.largeTitle, design: .rounded).weight(.heavy))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.6)

                if let nextPreviewText {
                    Text(nextPreviewText)
                        .font(.subheadline)
                        .foregroundStyle(MorpheTheme.textMuted)
                }
            }

            Spacer()

            HStack(spacing: 10) {
                Button(isPaused ? "Resume" : "Pause") { togglePause() }
                    .buttonStyle(PrimaryCTAButtonStyle(accent: MorpheTheme.accentAlt))

                Button("Skip") { skipStation() }
                    .buttonStyle(SecondaryCTAButtonStyle())
                    .frame(width: 110)
                    .accessibilityLabel("Skip station")
            }
        }
        .padding(20)
        .confirmationDialog(
            completedIntervals.isEmpty
                ? "End the circuit? Nothing has been completed yet, so nothing would be logged."
                : "End the circuit early? The \(completedIntervals.count) finished interval\(completedIntervals.count == 1 ? "" : "s") can still be logged.",
            isPresented: $showEndConfirm,
            titleVisibility: .visible
        ) {
            Button("End Circuit", role: .destructive) { finishCircuit(early: true) }
            Button("Keep Going", role: .cancel) {}
        }
    }

    private func timeString(_ seconds: Int) -> String {
        String(format: "%d:%02d", seconds / 60, seconds % 60)
    }

    // MARK: Runner state machine

    private func startCircuit() {
        runStations = enabledStations
        guard !runStations.isEmpty else { return }
        completedIntervals = []
        roundIndex = 0
        stationIndex = 0
        endedEarly = false
        isPaused = false
        Haptics.impact(.medium)
        phase = .running
        beginSegment(.work)
    }

    private func beginSegment(_ newSegment: Segment) {
        segment = newSegment
        switch newSegment {
        case .work: segmentLength = max(currentStation?.workSeconds ?? 40, 1)
        case .stationRest: segmentLength = max(stationRestSeconds, 1)
        case .roundRest: segmentLength = max(roundRestSeconds, 1)
        }
        remaining = segmentLength
        startTicking()
    }

    private func startTicking() {
        tickTask?.cancel()
        segmentEndDate = Date().addingTimeInterval(TimeInterval(remaining))
        tickTask = Task {
            while !Task.isCancelled && remaining > 0 {
                try? await Task.sleep(for: .seconds(1))
                if Task.isCancelled { return }
                if remaining > 0 { remaining -= 1 }
            }
            if !Task.isCancelled && remaining <= 0 {
                segmentFinished()
            }
        }
    }

    private func stopTicking() {
        tickTask?.cancel()
        tickTask = nil
        segmentEndDate = nil
    }

    private func segmentFinished() {
        switch segment {
        case .work:
            // The interval ran to zero on the clock — that, and only that,
            // earns a logged set.
            if let station = currentStation {
                completedIntervals.append(
                    CompletedInterval(stationID: station.id, workSeconds: station.workSeconds)
                )
            }
            if stationIndex + 1 < runStations.count {
                Haptics.impact(.medium)
                beginSegment(.stationRest)
            } else if roundIndex + 1 < rounds {
                SoundEffects.play(.ding)   // round completion
                Haptics.impact(.heavy)
                beginSegment(.roundRest)
            } else {
                finishCircuit(early: false)
            }
        case .stationRest:
            Haptics.impact(.medium)
            stationIndex += 1
            beginSegment(.work)
        case .roundRest:
            Haptics.impact(.medium)
            advanceToNextRound()
        }
    }

    private func advanceToNextRound() {
        roundIndex += 1
        stationIndex = 0
        beginSegment(.work)
    }

    private func togglePause() {
        if isPaused {
            isPaused = false
            startTicking()
        } else {
            isPaused = true
            stopTicking()
        }
        Haptics.impact(.light)
    }

    /// Jumps to the next station's work. A skipped work interval is never
    /// credited; skipping during a rest just cuts the rest short.
    private func skipStation() {
        stopTicking()
        Haptics.impact(.light)
        isPaused = false
        switch segment {
        case .roundRest:
            advanceToNextRound()
        case .work, .stationRest:
            if stationIndex + 1 < runStations.count {
                stationIndex += 1
                beginSegment(.work)
            } else if roundIndex + 1 < rounds {
                advanceToNextRound()
            } else {
                finishCircuit(early: segment == .work)
            }
        }
    }

    private func finishCircuit(early: Bool) {
        stopTicking()
        isPaused = false
        endedEarly = early
        if early {
            Haptics.impact(.medium)
        } else {
            SoundEffects.play(.star)   // circuit completion
            Haptics.success()
        }
        phase = .summary
    }

    // MARK: Summary + honest logging

    private struct SummaryLine: Identifiable {
        let id: String
        let name: String
        let count: Int
        let workSeconds: Int
    }

    private var summaryLines: [SummaryLine] {
        runStations.compactMap { station in
            let count = completedIntervals.filter { $0.stationID == station.id }.count
            guard count > 0 else { return nil }
            return SummaryLine(id: station.id, name: station.name, count: count, workSeconds: station.workSeconds)
        }
    }

    private var summaryView: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 16) {
                coverHeader(
                    title: endedEarly ? "Circuit ended" : "Circuit complete",
                    subtitle: summaryLines.isEmpty
                        ? "No work intervals finished, so there is nothing to log."
                        : "This is exactly what gets recorded — nothing you didn't do."
                )

                if !summaryLines.isEmpty {
                    GlassCard {
                        VStack(alignment: .leading, spacing: 12) {
                            configLabel("Will be logged")

                            ForEach(summaryLines) { line in
                                HStack(spacing: 10) {
                                    Text(line.name)
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(.white)
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.8)
                                    Spacer()
                                    Text("\(line.count) × \(line.workSeconds)s")
                                        .font(.system(.subheadline, design: .monospaced).weight(.bold))
                                        .foregroundStyle(MorpheTheme.accent)
                                }
                            }

                            Text("Each finished interval logs as one set — reps 1 (one interval, not a rep count), weight 0 (bodyweight), labeled \"Circuit: …s work\".")
                                .font(.footnote)
                                .foregroundStyle(MorpheTheme.textMuted)
                        }
                    }
                }

                HStack(spacing: 10) {
                    if summaryLines.isEmpty {
                        Button("Close") { dismiss() }
                            .buttonStyle(SecondaryCTAButtonStyle())
                    } else {
                        Button("Log Circuit") { logCircuit() }
                            .buttonStyle(PrimaryCTAButtonStyle(accent: MorpheTheme.accent))

                        Button("Discard") { dismiss() }
                            .buttonStyle(SecondaryCTAButtonStyle())
                            .frame(width: 110)
                            .accessibilityLabel("Discard circuit without logging")
                    }
                }
            }
            .padding(20)
        }
    }

    /// Writes each finished interval into the tracked session via the same
    /// store API every other set uses (see the convention note on this view).
    /// `completeTrackedSet` targets the store's active exercise, so the index
    /// is pointed at each station's exercise first and restored after.
    private func logCircuit() {
        let originalIndex = store.activeWorkoutExerciseIndex
        for interval in completedIntervals {
            guard let index = store.currentWorkout.exercises.firstIndex(where: { $0.id == interval.stationID }) else { continue }
            store.activeWorkoutExerciseIndex = index
            store.completeTrackedSet(
                reps: 1,
                weight: 0,
                allowExtra: true,
                label: "Circuit: \(interval.workSeconds)s work"
            )
        }
        store.activeWorkoutExerciseIndex = min(originalIndex, max(store.currentWorkout.exercises.count - 1, 0))
        dismiss()
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

                Button("Save Flag", action: onSave)
                    .buttonStyle(PrimaryCTAButtonStyle(accent: MorpheTheme.warning))
                    .accessibilityLabel("Save pain flag")
            }
        }
    }
}

private struct SetRepLoggingSheet: View {
    /// How this set was performed. Dropset/superset log as ONE set whose
    /// sub-work rides in the label.
    enum SetStyle: String, CaseIterable, Identifiable {
        case standard = "Standard"
        case dropset = "Dropset"
        case superset = "Superset"
        var id: String { rawValue }
    }

    /// One extra piece of work inside a dropset (lighter weight) or a
    /// superset (different movement).
    struct SubEntry: Identifiable {
        let id = UUID()
        var weightText = ""
        var name = ""
        var reps = 10
    }

    @Environment(\.dismiss) private var dismiss
    @Environment(MorpheAppStore.self) private var store
    @Binding var reps: Int
    @Binding var weight: Double
    @Binding var rpe: Int?
    var isEditing = false
    let onSave: (String) -> Void

    @State private var weightText = ""
    @State private var showRPEHelp = false
    @State private var style: SetStyle = .standard
    @State private var subEntries: [SubEntry] = []

    private var logButtonTitle: String {
        switch style {
        case .standard: return "Log Set"
        case .dropset: return "Log Dropset"
        case .superset: return "Log Superset"
        }
    }

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

                // Edits fix one already-logged set; restyling it after the
                // fact would rewrite history, so the picker hides.
                if !isEditing {
                    VStack(alignment: .leading, spacing: 6) {
                        Picker("Set style", selection: $style) {
                            ForEach(SetStyle.allCases) { option in
                                Text(option.rawValue).tag(option)
                            }
                        }
                        .pickerStyle(.segmented)

                        if style == .dropset {
                            Text("Strip weight and keep going — every drop below counts inside this ONE set.")
                                .font(.caption)
                                .foregroundStyle(MorpheTheme.textMuted)
                        } else if style == .superset {
                            Text("Pair movements back-to-back — everything below counts inside this ONE set.")
                                .font(.caption)
                                .foregroundStyle(MorpheTheme.textMuted)
                        }
                    }
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

                if style != .standard, !isEditing {
                    VStack(alignment: .leading, spacing: 10) {
                        Text(style == .dropset ? "Drops" : "Paired movements")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(MorpheTheme.textSecondary)

                        ForEach($subEntries) { $entry in
                            HStack(spacing: 10) {
                                if style == .dropset {
                                    TextField("Weight", text: $entry.weightText)
                                        .keyboardType(.decimalPad)
                                        .textFieldStyle(MorpheFieldStyle())
                                        .frame(width: 90)
                                    Text(store.weightUnit.label)
                                        .font(.caption)
                                        .foregroundStyle(MorpheTheme.textMuted)
                                } else {
                                    TextField("Exercise (e.g. Push-Up)", text: $entry.name)
                                        .textFieldStyle(MorpheFieldStyle())
                                }
                                Stepper("\(entry.reps)", value: $entry.reps, in: 1...50)
                                    .foregroundStyle(.white)
                                    .fixedSize()
                                Button {
                                    subEntries.removeAll { $0.id == entry.id }
                                } label: {
                                    Image(systemName: "minus.circle.fill")
                                        .foregroundStyle(MorpheTheme.textMuted)
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel("Remove")
                            }
                        }

                        Button {
                            subEntries.append(SubEntry())
                        } label: {
                            Label(style == .dropset ? "Add Drop" : "Add Movement", systemImage: "plus.circle")
                                .font(.subheadline.weight(.semibold))
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(MorpheTheme.accentAlt)
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
                                RoundedRectangle(cornerRadius: MorpheTheme.radius, style: .continuous)
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

                    Button(logButtonTitle) {
                        logAndDismiss()
                    }
                    .buttonStyle(PrimaryCTAButtonStyle(accent: MorpheTheme.accent))
                }

            }
            .padding(20)
            }
            .background(PremiumBackground())
            .onAppear { weightText = weight > 0 ? String(weight) : "" }
            // Everything typed here auto-saves as a draft — dismissing the
            // sheet (or getting a call mid-set) never loses the numbers.
            .onChange(of: weightText) { saveDraft() }
            .onChange(of: reps) { saveDraft() }
            .onChange(of: rpe) { saveDraft() }
        }
    }

    private func saveDraft() {
        guard !isEditing, let exercise = store.activeWorkoutExercise else { return }
        store.pendingSetDrafts[exercise.id] = PendingSetDraft(
            reps: reps,
            weight: Double(weightText.trimmingCharacters(in: .whitespaces)) ?? 0,
            rpe: rpe
        )
    }

    private func logAndDismiss() {
        let mainWeight = Double(weightText.trimmingCharacters(in: .whitespaces)) ?? 0
        let unit = store.weightUnit.label

        func fmt(_ value: Double) -> String {
            value == value.rounded() ? String(Int(value)) : String(value)
        }

        var label = ""
        switch style {
        case .standard:
            weight = mainWeight
        case .dropset:
            let drops = subEntries.compactMap { entry -> (Double, Int)? in
                let w = Double(entry.weightText.trimmingCharacters(in: .whitespaces)) ?? 0
                return entry.reps > 0 ? (w, entry.reps) : nil
            }
            let chain = ([(mainWeight, reps)] + drops)
                .map { "\(fmt($0.0))×\($0.1)" }
                .joined(separator: " → ")
            label = drops.isEmpty ? "" : "Dropset \(chain) \(unit)"
            // One set, honest totals: all reps counted, top weight carried.
            reps += drops.reduce(0) { $0 + $1.1 }
            weight = max(mainWeight, drops.map(\.0).max() ?? 0)
        case .superset:
            let partners = subEntries.filter { !$0.name.trimmingCharacters(in: .whitespaces).isEmpty }
            label = partners.isEmpty ? "" : "Superset " + partners
                .map { "+ \($0.name.trimmingCharacters(in: .whitespaces)) ×\($0.reps)" }
                .joined(separator: " ")
            reps += partners.reduce(0) { $0 + $1.reps }
            weight = mainWeight
        }

        onSave(label)
        dismiss()
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
    // Remove is destructive from the menu's point of view — same
    // confirm-first pattern as deleting a custom workout.
    @State private var pendingRemoval: SavedWorkoutLibraryItem?
    let items: [SavedWorkoutLibraryItem]
    let insightFor: (SavedWorkoutLibraryItem) -> SavedWorkoutLibraryInsight
    let onStart: (SavedWorkoutLibraryItem) -> Void
    let onQueue: (SavedWorkoutLibraryItem) -> Void
    let onWithBuddy: (SavedWorkoutLibraryItem) -> Void
    let onDuplicate: (SavedWorkoutLibraryItem) -> Void
    let onTogglePin: (SavedWorkoutLibraryItem) -> Void
    let onRemove: (SavedWorkoutLibraryItem) -> Void
    let onEdit: (SavedWorkoutLibraryItem) -> Void

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("Saved Workouts")
                    .font(.headline)
                    .foregroundStyle(.white)

                Text(FeatureFlags.multiUserEnabled
                    ? "Save coach and athlete workouts from around Morphe, then run them solo, with a buddy, or turn them into your own copy."
                    : "Save workouts from Discover — or your own builds — then run them or turn them into a copy you can edit.")
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
                    Text("Nothing saved yet. Save workouts from Discover — or build your own in Train — and they’ll show up here.")
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
                                if FeatureFlags.multiUserEnabled {
                                    MetricPill(label: "Mode", value: insight.hasBuddyCompletion ? "Buddy tried" : "Solo ready")
                                }
                            }

                            // Start is THE action on a saved workout; the
                            // long tail lives behind one ellipsis instead of
                            // a grid of seven equal buttons.
                            HStack(spacing: 8) {
                                Button("Start") {
                                    onStart(item)
                                }
                                .buttonStyle(SecondaryCTAButtonStyle())

                                Spacer()

                                Menu {
                                    // Queue = make it today's workout, staged
                                    // in Train without starting the session.
                                    Button("Queue") {
                                        onQueue(item)
                                    }

                                    if FeatureFlags.multiUserEnabled {
                                        Button("With Buddy") {
                                            onWithBuddy(item)
                                        }
                                    }

                                    Button("Duplicate") {
                                        onDuplicate(item)
                                    }

                                    Button(item.isPinned ? "Unpin" : "Pin") {
                                        onTogglePin(item)
                                    }

                                    // Edits touch only the user's copy — a
                                    // catalog save becomes "My Copy" first.
                                    Button("Edit") {
                                        onEdit(item)
                                    }

                                    Button("Remove", role: .destructive) {
                                        pendingRemoval = item
                                    }
                                } label: {
                                    Image(systemName: "ellipsis.circle")
                                        .font(.title3)
                                        .foregroundStyle(MorpheTheme.textSecondary)
                                        .frame(width: 44, height: 44)
                                        .contentShape(Rectangle())
                                }
                                .accessibilityLabel("More actions for \(item.workoutName)")
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
        }
        .confirmationDialog(
            removeWorkoutDialogTitle,
            isPresented: Binding(
                get: { pendingRemoval != nil },
                set: { if !$0 { pendingRemoval = nil } }
            ),
            titleVisibility: .visible,
            presenting: pendingRemoval
        ) { item in
            Button("Remove Workout", role: .destructive) {
                onRemove(item)
            }
            Button("Keep It", role: .cancel) {}
        }
    }

    private var removeWorkoutDialogTitle: String {
        guard let item = pendingRemoval else { return "Remove this workout from your library?" }
        return "Remove \(item.workoutName) from your library?"
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
        if item.sourceContext == "Built by you" { return "My copy" }
        // Catalog and Morphe-recommended saves aren't from a person.
        // ("Morphe AI" survives in saves persisted before the honest rename.)
        if item.sourceName == "Morphe Programs" { return "Morphe Program" }
        if item.sourceName == "Morphe" || item.sourceName == "Morphe AI" { return "Morphe" }
        return item.sourceRole == .coach ? "Coach source" : "Athlete source"
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
                    RoundedRectangle(cornerRadius: MorpheTheme.radius, style: .continuous)
                        .fill(MorpheTheme.panel)
                        .overlay(
                            RoundedRectangle(cornerRadius: MorpheTheme.radius, style: .continuous)
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
                                Text("Suggested Alternatives")
                                    .font(.headline)
                                    .foregroundStyle(.white)

                                Text(reasonDescription(for: selectedReason))
                                    .foregroundStyle(MorpheTheme.textSecondary)

                                ForEach(libraryExercise.alternatives, id: \.self) { option in
                                    Text("- \(option)")
                                        .foregroundStyle(.white)
                                }

                                if let blockReason = store.swapBlockReason(for: exercise) {
                                    // Surface the refusal up front instead of
                                    // walking the user to a toast dead-end.
                                    Text(blockReason)
                                        .font(.caption)
                                        .foregroundStyle(MorpheTheme.warning)
                                }

                                Button("Swap Exercise") {
                                    store.swapExercise(exercise)
                                    dismiss()
                                }
                                .buttonStyle(PrimaryCTAButtonStyle(accent: MorpheTheme.accent))
                                .disabled(store.swapBlockReason(for: exercise) != nil)
                                .opacity(store.swapBlockReason(for: exercise) != nil ? 0.5 : 1)
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
    let onQueue: (WorkoutTemplate) -> Void
    let onEdit: (WorkoutTemplate) -> Void
    let onDelete: (WorkoutTemplate) -> Void

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("Your Workouts")
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
                        // Queue = stage as today's workout without starting.
                        Button {
                            onQueue(workout)
                        } label: {
                            Image(systemName: "calendar.badge.plus")
                                .foregroundStyle(MorpheTheme.accentAlt)
                        }
                        .accessibilityLabel("Queue \(workout.name) as today's workout")
                        Button {
                            onEdit(workout)
                        } label: {
                            Image(systemName: "pencil")
                                .foregroundStyle(MorpheTheme.accent)
                        }
                        .accessibilityLabel("Edit \(workout.name)")
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

// Shared with the coach Discover tab, so not private.
struct WorkoutBuilderSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(MorpheAppStore.self) private var store

    /// When set, the builder edits this custom workout in place instead of
    /// creating a new one. Edits touch only the user's copy — never Discover.
    var editingTemplateID: UUID? = nil

    @State private var name = ""
    @State private var sport: SportFocus = .generalFitness
    @State private var items: [CustomWorkoutItem] = []
    @State private var showExercisePicker = false
    @State private var didPrefill = false

    private var isEditing: Bool { editingTemplateID != nil }

    /// Rebuilds builder rows from the edited template's exercises.
    private func prefillIfNeeded() {
        guard !didPrefill, let id = editingTemplateID,
              let template = store.workoutTemplates.first(where: { $0.id == id }) else { return }
        didPrefill = true
        name = template.name
        sport = template.sport
        items = template.exercises.map { exercise in
            CustomWorkoutItem(
                exercise: resolveReference(for: exercise),
                sets: min(max(firstInt(in: exercise.sets) ?? 3, 1), 10),
                reps: min(max(firstInt(in: exercise.reps) ?? 10, 1), 50)
            )
        }
    }

    private func firstInt(in text: String) -> Int? {
        Int(text.components(separatedBy: CharacterSet.decimalDigits.inverted)
            .first(where: { !$0.isEmpty }) ?? "")
    }

    private func resolveReference(for exercise: WorkoutExercise) -> ExerciseReference {
        if let match = store.allExercises.first(where: { $0.id == exercise.exerciseLibraryID })
            ?? store.allExercises.first(where: { $0.name == exercise.name }) {
            return match
        }
        // Not in the library (e.g. catalog-only movement): carry it through
        // as-is so an edit never drops an exercise.
        return ExerciseReference(
            id: exercise.exerciseLibraryID.isEmpty ? exercise.name : exercise.exerciseLibraryID,
            name: exercise.name,
            muscleGroup: exercise.muscleGroup,
            movementPattern: "",
            musclesWorked: "",
            equipment: "",
            difficulty: exercise.difficulty,
            videoPlaceholder: "",
            instructions: [],
            formCue: exercise.formCue,
            commonMistakes: "",
            beginnerModification: "",
            alternatives: [],
            whyThisMatters: ""
        )
    }

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

                    Button(isEditing ? "Save Changes" : "Create Workout") {
                        if let editingTemplateID {
                            store.updateCustomWorkout(id: editingTemplateID, name: name, sport: sport, items: items)
                        } else {
                            store.createCustomWorkout(name: name, sport: sport, items: items)
                        }
                        dismiss()
                    }
                    .buttonStyle(PrimaryCTAButtonStyle(accent: MorpheTheme.accent))
                    .disabled(items.isEmpty)
                    .opacity(items.isEmpty ? 0.5 : 1)
                }
                .padding(20)
            }
            .background(PremiumBackground())
            .navigationTitle(isEditing ? "Edit workout" : "Build a workout")
            .onAppear { prefillIfNeeded() }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .sheet(isPresented: $showExercisePicker) {
                ExercisePickerSheet(items: $items)
                    .environment(store)
            }
        }
    }
}

private struct ExercisePickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(MorpheAppStore.self) private var store
    @Binding var items: [CustomWorkoutItem]

    @State private var query = ""
    @State private var groupFilter: MuscleGroup?
    @State private var showCustomForm = false
    @State private var customName = ""
    @State private var customMuscle: MuscleGroup = .core

    /// Picks stay in the sheet: tapping adds (or removes) without dismissing,
    /// so building a 6-exercise workout is one visit, not six.
    private var addedIDs: Set<String> { Set(items.map(\.exercise.id)) }

    private var filtered: [ExerciseReference] {
        var all = store.allExercises
        if let groupFilter { all = all.filter { $0.muscleGroup == groupFilter } }
        let q = query.trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty else { return all }
        return all.filter {
            $0.name.localizedCaseInsensitiveContains(q)
                || $0.muscleGroup.rawValue.localizedCaseInsensitiveContains(q)
        }
    }

    /// Grouped by muscle for browsing; a search or chip filter flattens it.
    private var grouped: [(group: MuscleGroup, exercises: [ExerciseReference])] {
        MuscleGroup.allCases.compactMap { group in
            let members = filtered.filter { $0.muscleGroup == group }
            return members.isEmpty ? nil : (group, members)
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    // Own search field — always visible, never hijacks the nav
                    // bar (the old .searchable hid the Done button mid-search).
                    HStack(spacing: 8) {
                        Image(systemName: "magnifyingglass")
                            .font(.subheadline)
                            .foregroundStyle(MorpheTheme.textMuted)
                        TextField("Search exercises", text: $query)
                            .textFieldStyle(.plain)
                            .foregroundStyle(.white)
                            .autocorrectionDisabled()
                        if !query.isEmpty {
                            Button {
                                query = ""
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(MorpheTheme.textMuted)
                            }
                            .accessibilityLabel("Clear search")
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: MorpheTheme.radius, style: .continuous)
                            .fill(MorpheTheme.panelStrong)
                            .overlay(
                                RoundedRectangle(cornerRadius: MorpheTheme.radius, style: .continuous)
                                    .stroke(Color.white.opacity(0.12), lineWidth: 1)
                            )
                    )

                    // Muscle-group chips.
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(MuscleGroup.allCases) { group in
                                Button(group.rawValue) {
                                    groupFilter = groupFilter == group ? nil : group
                                }
                                .buttonStyle(FilterChipStyle(isSelected: groupFilter == group, selectedColor: MorpheTheme.accentAlt))
                            }
                        }
                    }

                    Button {
                        withAnimation { showCustomForm.toggle() }
                    } label: {
                        Label("Create Exercise", systemImage: "plus.circle")
                    }
                    .buttonStyle(SecondaryCTAButtonStyle())
                    .accessibilityLabel("Create custom exercise")

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
                                Button("Add Exercise") {
                                    let created = store.addCustomExercise(name: customName, muscleGroup: customMuscle)
                                    items.append(CustomWorkoutItem(exercise: created))
                                    customName = ""
                                    withAnimation { showCustomForm = false }
                                }
                                .buttonStyle(PrimaryCTAButtonStyle(accent: MorpheTheme.accent))
                                .disabled(customName.trimmingCharacters(in: .whitespaces).isEmpty)
                            }
                        }
                    }

                    ForEach(grouped, id: \.group) { section in
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(spacing: 10) {
                                Rectangle()
                                    .fill(MorpheTheme.accent)
                                    .frame(width: 3, height: 12)
                                Text(section.group.rawValue.uppercased())
                                    .font(MorpheTheme.microLabel(11)).tracking(1.6)
                                    .foregroundStyle(MorpheTheme.textPrimary)
                                Text(String(format: "%02d", section.exercises.count))
                                    .font(MorpheTheme.microLabel(10))
                                    .foregroundStyle(MorpheTheme.accentAlt)
                                Rectangle()
                                    .fill(MorpheTheme.stroke)
                                    .frame(height: 1)
                                    .frame(maxWidth: .infinity)
                            }
                            .padding(.top, 4)

                            ForEach(section.exercises) { exercise in
                                exerciseRow(exercise)
                            }
                        }
                    }

                    if grouped.isEmpty {
                        Text("No exercises match — try another word, or create a custom one above.")
                            .font(.subheadline)
                            .foregroundStyle(MorpheTheme.textSecondary)
                    }
                }
                .padding(20)
            }
            .background(PremiumBackground())
            .navigationTitle("Add exercises")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(items.isEmpty ? "Done" : "Done (\(items.count))") { dismiss() }
                        .foregroundStyle(MorpheTheme.accent)
                }
            }
        }
    }

    private func exerciseRow(_ exercise: ExerciseReference) -> some View {
        let isAdded = addedIDs.contains(exercise.id)
        return Button {
            if isAdded {
                items.removeAll { $0.exercise.id == exercise.id }
            } else {
                items.append(CustomWorkoutItem(exercise: exercise))
                Haptics.impact(.light)
            }
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(exercise.name)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                    Text(exercise.equipment)
                        .font(.caption)
                        .foregroundStyle(MorpheTheme.textMuted)
                }
                Spacer()
                Image(systemName: isAdded ? "checkmark.circle.fill" : "plus")
                    .foregroundStyle(isAdded ? Color(red: 0.30, green: 0.85, blue: 0.45) : MorpheTheme.accent)
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: MorpheTheme.radius, style: .continuous)
                    .fill(MorpheTheme.panel)
                    .overlay(
                        RoundedRectangle(cornerRadius: MorpheTheme.radius, style: .continuous)
                            .stroke(isAdded ? MorpheTheme.accent.opacity(0.5) : Color.clear, lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(exercise.name)\(isAdded ? ", added" : "")")
        .accessibilityHint(isAdded ? "Removes it from your workout" : "Adds it to your workout")
    }
}
