import SwiftUI

struct MoreView: View {
    @Environment(MorpheAppStore.self) private var store

    private var activeFeature: ClientHubFeature {
        let selected = store.selectedHubFeature ?? .scores
        return selected == .progress ? .scores : selected
    }

    private var personalRecords: [PersonalRecord] {
        // Real records from logged sets — the seeded showcase list is always
        // empty for real users.
        store.derivedPersonalRecords
    }

    private var featuredDrills: [DrillReference] {
        store.drills
            .filter { $0.sport == store.selectedSportMode || $0.sport == .generalFitness }
            .prefix(4)
            .map { $0 }
    }

    private var utilityFeatures: [ClientHubFeature] {
        ClientHubFeature.allCases.filter { $0 != .progress }
    }

    /// ONE quiz per calendar day — the day picks it, completion doesn't skip
    /// ahead. (The old "first uncompleted" rule let a learner chain all 16 in
    /// one sitting, then hit an empty pool with a false "tomorrow" promise.)
    private var dailyQuiz: MiniQuiz? {
        guard !store.quizzes.isEmpty else { return nil }
        let dayIndex = Calendar.current.ordinality(of: .day, in: .year, for: .now) ?? 0
        return store.quizzes[dayIndex % store.quizzes.count]
    }

    private var nutritionTargets: [(label: String, value: String, detail: String)] {
        switch store.clientProfile.goal {
        case let goal where goal.localizedCaseInsensitiveContains("weight"):
            return [
                ("Calories", "2,100", "steady deficit"),
                ("Protein", "160g", "muscle support"),
                ("Carbs", "190g", "training energy"),
                ("Vegetables", "4 servings", "recovery + fullness"),
                ("Dairy", "2 servings", "easy calcium + protein"),
                ("Water", "8 cups", "daily baseline")
            ]
        case let goal where goal.localizedCaseInsensitiveContains("conditioning"):
            return [
                ("Calories", "2,300", "fuel the work"),
                ("Protein", "165g", "recovery support"),
                ("Carbs", "240g", "session energy"),
                ("Vegetables", "4 servings", "micronutrient base"),
                ("Dairy", "2 servings", "easy add-on"),
                ("Water", "9 cups", "sweat support")
            ]
        default:
            return [
                ("Calories", "\(store.nutrition.calorieGoal)", "daily target"),
                ("Protein", "\(store.nutrition.proteinGoal)g", "consistency first"),
                ("Carbs", "220g", "steady energy"),
                ("Vegetables", "4 servings", "simple habit"),
                ("Dairy", "2 servings", "optional support"),
                ("Water", "\(store.nutrition.waterGoal) cups", "hydration baseline")
            ]
        }
    }

    private let mobilityLibrary = [
        "90/90 Hip Switch",
        "World's Greatest Stretch",
        "Thoracic Reach",
        "Ankle Rocker",
        "Child's Pose Breathing"
    ]

    // Swap Exercise was removed: it silently rewrote the current workout's
    // first exercise and yanked the user to Train — a destructive surprise
    // from a Learn tab. Swapping lives in the workout itself now.
    private let quickActions: [(TodayQuickAction, String)] = [
        (.logWorkout, "checkmark.circle"),
        (.askAI, "text.bubble")
    ]

    private let quickActionColumns = [
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10)
    ]

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 16) {
                SectionTitleView(
                    title: "Learn",
                    subtitle: "Exercise help, recovery, nutrition basics, and short lessons in one place."
                )

                MoreFeatureGrid(features: utilityFeatures, selected: activeFeature) { feature in
                    store.selectedHubFeature = feature
                }

                featureContent
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 120)
        }
    }

    @ViewBuilder
    private var featureContent: some View {
        switch activeFeature {
        case .progress:
            scoresPanel
        case .scores:
            scoresPanel
        case .tools:
            toolsPanel
        case .library:
            libraryPanel
        case .nutrition:
            nutritionPanel
        case .learn:
            learningPanel
        }
    }

    private var scoresPanel: some View {
        Group {
            HubScoreboardCard(
                recovery: store.recovery,
                morpheScore: store.clientProfile.health.score,
                streak: store.clientProfile.level.streak,
                adherence: store.clientProfile.adherence
            )
            LevelProgressCard(progress: store.clientProfile.level)
            GoalTranslationCard(translation: store.goalTranslation)
            SportModeSelector(selected: store.selectedSportMode) { sport in
                store.selectSportMode(sport)
            }
            // Only ever non-empty in the pre-onboarding demo — a real user
            // has no fabricated sport metrics.
            if !store.sportMetrics.isEmpty {
                SportMetricsCard(sport: store.selectedSportMode, metrics: store.sportMetrics)
            }
            PersonalRecordsCard(records: personalRecords)
        }
    }

    private var toolsPanel: some View {
        Group {
            GlassCard {
                VStack(alignment: .leading, spacing: 14) {
                    Text("Quick Tools")
                        .font(.headline)
                        .foregroundStyle(.white)

                    LazyVGrid(columns: quickActionColumns, spacing: 10) {
                        ForEach(quickActions, id: \.0.id) { action, symbol in
                            QuickActionButton(title: action.rawValue, systemImage: symbol) {
                                store.quickAction(action)
                            }
                        }
                    }
                }
            }

            GoalTranslationCard(translation: store.goalTranslation)
            if !store.personalRules.isEmpty {
                PersonalRulesCard(rules: store.personalRules)
            }
        }
    }

    private var libraryPanel: some View {
        Group {
            // (SportModeSelector removed from here: browsing the library must
            // not rewrite the user's sports, goal, and persisted profile as a
            // side effect — it lives in Scores where changing sport is the point.)
            GlassCard {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Exercise Library")
                        .font(.headline)
                        .foregroundStyle(.white)
                    Text("Browse by muscle group, then open the movement for beginner-friendly form help and safer alternatives.")
                        .foregroundStyle(MorpheTheme.textSecondary)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(MuscleGroup.allCases) { group in
                                Button(group.rawValue) {
                                    store.selectMuscleGroup(group)
                                }
                                .buttonStyle(FilterChipStyle(isSelected: store.selectedMuscleGroup == group))
                            }
                        }
                    }

                    ForEach(store.filteredExercises) { exercise in
                        HStack(alignment: .top) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(exercise.name)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(.white)
                                Text(exercise.musclesWorked)
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

            GlassCard {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Skill Drill Spotlight")
                        .font(.headline)
                        .foregroundStyle(.white)

                    ForEach(featuredDrills) { drill in
                        LibraryDrillRow(drill: drill)
                    }
                }
            }

            GlassCard {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Stretching + Mobility")
                        .font(.headline)
                        .foregroundStyle(.white)

                    ForEach(mobilityLibrary, id: \.self) { item in
                        HStack(spacing: 10) {
                            Image(systemName: "figure.flexibility")
                                .font(.subheadline)
                                .foregroundStyle(MorpheTheme.accent)
                            Text(item)
                                .foregroundStyle(.white)
                            Spacer()
                        }
                    }
                }
            }
        }
    }

    private var nutritionPanel: some View {
        Group {
            GlassCard {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Nutrition Basics")
                        .font(.headline)
                        .foregroundStyle(.white)
                    // Honest framing: these are general starting points from
                    // the goal type, not personalized macros. (The old Mode
                    // picker wrote a value nothing in the app ever read.)
                    Text("General starting points for your goal type — not personalized targets. Hit the basics before trying to be perfect.")
                        .foregroundStyle(MorpheTheme.textSecondary)

                    ForEach(nutritionTargets, id: \.label) { target in
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(target.label)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(.white)
                                Text(target.detail)
                                    .font(.caption)
                                    .foregroundStyle(MorpheTheme.textSecondary)
                            }
                            Spacer()
                            Text(target.value)
                                .font(.headline)
                                .foregroundStyle(MorpheTheme.accentAlt)
                        }
                    }
                }
            }

            AIInsightCard(insight: store.nutritionInsight)
        }
    }

    private var learningPanel: some View {
        Group {
            GlassCard {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Daily Quiz")
                            .font(.headline)
                            .foregroundStyle(.white)
                        Spacer()
                        Text("\(store.completedQuizIDs.count) of \(store.quizzes.count)")
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(MorpheTheme.accentAlt)
                            .accessibilityLabel("\(store.completedQuizIDs.count) of \(store.quizzes.count) quizzes complete")
                    }

                    Text("One new question a day. Answer it right the first time to earn XP.")
                        .font(.subheadline)
                        .foregroundStyle(MorpheTheme.textSecondary)

                    if let quiz = dailyQuiz {
                        let answeredIndex = store.quizSelections[quiz.id]
                        let isComplete = store.completedQuizIDs.contains(quiz.id)

                        VStack(alignment: .leading, spacing: 8) {
                            Text(quiz.question)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.white)

                            ForEach(Array(quiz.options.enumerated()), id: \.offset) { index, option in
                                Button(option) {
                                    store.answerQuiz(quiz, with: index)
                                }
                                .buttonStyle(
                                    FilterChipStyle(
                                        isSelected: answeredIndex == index || (isComplete && index == quiz.correctIndex),
                                        selectedColor: index == quiz.correctIndex ? MorpheTheme.accent : MorpheTheme.warning
                                    )
                                )
                                .disabled(answeredIndex != nil || isComplete)
                                .accessibilityLabel(quizOptionLabel(option: option, index: index, quiz: quiz, answeredIndex: answeredIndex))
                            }

                            if let answeredIndex {
                                // "Correct/Not quite" in words, not just color.
                                Text(answeredIndex == quiz.correctIndex
                                     ? "Correct! \(quiz.explanation)"
                                     : "Not quite. \(quiz.explanation)")
                                    .font(.subheadline)
                                    .foregroundStyle(answeredIndex == quiz.correctIndex ? MorpheTheme.accent : MorpheTheme.textSecondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            } else if isComplete {
                                Text(store.completedQuizIDs.count == store.quizzes.count
                                     ? "You've aced every question — fresh material arrives with new lessons."
                                     : "Already aced — a new question lands tomorrow.")
                                    .font(.subheadline)
                                    .foregroundStyle(MorpheTheme.textSecondary)
                            }

                            if isComplete {
                                Text("+\(quiz.rewardXP) XP earned")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(MorpheTheme.accentAlt)
                            }
                        }
                    }
                }
            }

            GlassCard {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Lessons")
                        .font(.headline)
                        .foregroundStyle(.white)
                    Text("Two-minute reads on training, recovery, and effort.")
                        .font(.caption)
                        .foregroundStyle(MorpheTheme.textMuted)

                    ForEach(store.lessons) { lesson in
                        DisclosureGroup {
                            Text(lesson.detail)
                                .font(.subheadline)
                                .foregroundStyle(MorpheTheme.textSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                                .padding(.top, 4)
                        } label: {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(lesson.title)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(.white)
                                Text(lesson.subtitle)
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(MorpheTheme.accentAlt)
                            }
                        }
                        .disclosureGroupStyle(HUDDisclosureStyle())
                    }
                }
            }
        }
    }

    private func quizOptionLabel(option: String, index: Int, quiz: MiniQuiz, answeredIndex: Int?) -> String {
        guard answeredIndex != nil || store.completedQuizIDs.contains(quiz.id) else { return option }
        return index == quiz.correctIndex ? "\(option), correct answer" : option
    }
}

private struct MoreFeatureGrid: View {
    let features: [ClientHubFeature]
    let selected: ClientHubFeature
    let onSelect: (ClientHubFeature) -> Void

    private let columns = [
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10)
    ]

    var body: some View {
        LazyVGrid(columns: columns, spacing: 10) {
            ForEach(features) { feature in
                Button {
                    onSelect(feature)
                } label: {
                    VStack(alignment: .leading, spacing: 10) {
                        Image(systemName: feature.systemImage)
                            .font(.headline)
                            .foregroundStyle(.white)
                        Text(feature.rawValue)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.white)
                        Text(feature.subtitle)
                            .font(.caption)
                            .foregroundStyle(MorpheTheme.textSecondary)
                            .multilineTextAlignment(.leading)
                    }
                    .padding(14)
                    .frame(maxWidth: .infinity, minHeight: 124, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: MorpheTheme.radius, style: .continuous)
                            .fill(selected == feature ? MorpheTheme.panelStrong : MorpheTheme.panel)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: MorpheTheme.radius, style: .continuous)
                            .stroke(selected == feature ? MorpheTheme.accent : MorpheTheme.stroke, lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }
}

private struct HubScoreboardCard: View {
    let recovery: RecoverySnapshot
    let morpheScore: Int
    let streak: Int
    let adherence: Int

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("Scores + Levels")
                    .font(.headline)
                    .foregroundStyle(.white)

                HStack(spacing: 8) {
                    MetricPill(label: "Readiness", value: "\(recovery.score)")
                    MetricPill(label: "Morphe Score", value: "\(morpheScore)")
                    MetricPill(label: "Streak", value: "\(streak) days")
                }

                Text(streak > 0
                    ? "Recovery is \(recovery.status.rawValue.lowercased()) today. You're on a \(streak)-day streak — keep it going."
                    : "Recovery is \(recovery.status.rawValue.lowercased()) today. Log a workout to start your streak.")
                    .foregroundStyle(MorpheTheme.textSecondary)
            }
        }
    }
}

private struct PersonalRecordsCard: View {
    let records: [PersonalRecord]

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("Personal Records")
                    .font(.headline)
                    .foregroundStyle(.white)

                if records.isEmpty {
                    Text("Your records build themselves from the workouts you log — the first one lands with your first big set.")
                        .font(.subheadline)
                        .foregroundStyle(MorpheTheme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                ForEach(records) { record in
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(record.title)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.white)
                            Text(record.detail)
                                .font(.caption)
                                .foregroundStyle(MorpheTheme.textSecondary)
                        }
                        Spacer()
                        Text(record.value)
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(MorpheTheme.accentAlt)
                    }
                }
            }
        }
    }
}

private struct LibraryDrillRow: View {
    let drill: DrillReference

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(drill.name)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                Spacer()
                StatusBadge(text: drill.sport.shortTitle, color: MorpheTheme.color(for: drill.sport))
            }
            Text("\(drill.skillCategory) • \(drill.scoreMetric)")
                .font(.caption.weight(.semibold))
                .foregroundStyle(MorpheTheme.accentAlt)
            Text(drill.cues)
                .font(.caption)
                .foregroundStyle(MorpheTheme.textSecondary)
        }
        .padding(.vertical, 4)
    }
}

private struct NutritionMeter: View {
    let title: String
    let consumed: Int
    let goal: Int
    let unit: String

    private var progress: Double {
        guard goal > 0 else { return 0 }
        return min(Double(consumed) / Double(goal), 1)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title)
                    .foregroundStyle(.white)
                Spacer()
                Text("\(consumed)\(unit) / \(goal)\(unit)")
                    .foregroundStyle(MorpheTheme.textSecondary)
            }
            ProgressBarView(progress: progress, color: MorpheTheme.accent)
        }
    }
}
