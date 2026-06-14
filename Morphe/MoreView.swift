import SwiftUI

struct MoreView: View {
    @Environment(MorpheAppStore.self) private var store

    private var activeFeature: ClientHubFeature {
        let selected = store.selectedHubFeature ?? .scores
        return selected == .progress ? .scores : selected
    }

    private var personalRecords: [PersonalRecord] {
        store.profileShowcase.personalRecords
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

    private var dailyQuizzes: [MiniQuiz] {
        guard !store.quizzes.isEmpty else { return [] }
        let count = min(max(5, min(store.quizzes.count, 10)), store.quizzes.count)
        let dayIndex = Calendar.current.ordinality(of: .day, in: .year, for: .now) ?? 0
        return (0..<count).map { offset in
            store.quizzes[(dayIndex + offset) % store.quizzes.count]
        }
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

    private let quickActions: [(TodayQuickAction, String)] = [
        (.logWorkout, "checkmark.circle"),
        (.swapExercise, "arrow.triangle.2.circlepath"),
        (.askAI, "sparkles"),
        (.messageTrainer, "message")
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
                    subtitle: "Anatomy, exercise help, recovery, nutrition basics, and short lessons in one clean place."
                )

                GlassCard {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Use this when you need support, not when you need noise.")
                            .font(.headline)
                            .foregroundStyle(.white)
                        Text("Progress stays focused on reports and momentum. More is where Morphe keeps the helpful extras.")
                            .foregroundStyle(MorpheTheme.textSecondary)
                    }
                }

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
            SportMetricsCard(sport: store.selectedSportMode, metrics: store.sportMetrics)
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
            PersonalRulesCard(rules: store.personalRules)
        }
    }

    private var libraryPanel: some View {
        Group {
            SportModeSelector(selected: store.selectedSportMode) { sport in
                store.selectSportMode(sport)
            }

            GlassCard {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Anatomy + Exercise Library")
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

                    Button("Add exercise to today's plan") {
                        store.notify("Exercise added to your quick list.")
                    }
                    .buttonStyle(SecondaryCTAButtonStyle())
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
                        HStack {
                            Text(item)
                                .foregroundStyle(.white)
                            Spacer()
                            Button("Add") {
                                store.notify("\(item) added to your mobility list.")
                            }
                            .buttonStyle(FilterChipStyle(isSelected: false, selectedColor: MorpheTheme.accentAlt))
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
                    Text("Start with daily targets that support your current goal. Hit the basics before trying to be perfect.")
                        .foregroundStyle(MorpheTheme.textSecondary)

                    Picker("Mode", selection: Binding(
                        get: { store.nutrition.mode },
                        set: { store.setNutritionMode($0) }
                    )) {
                        ForEach(NutritionMode.allCases) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)

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
                    Text("Mini Quizzes")
                        .font(.headline)
                        .foregroundStyle(.white)

                    Text("New questions rotate daily so the learning stays short and fresh.")
                        .foregroundStyle(MorpheTheme.textSecondary)

                    ForEach(dailyQuizzes) { quiz in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(quiz.question)
                                .foregroundStyle(.white)

                            ForEach(Array(quiz.options.enumerated()), id: \.offset) { index, option in
                                Button(option) {
                                    store.answerQuiz(quiz, with: index)
                                }
                                .buttonStyle(
                                    FilterChipStyle(
                                        isSelected: store.quizSelections[quiz.id] == index,
                                        selectedColor: index == quiz.correctIndex ? MorpheTheme.accent : MorpheTheme.warning
                                    )
                                )
                            }

                            if let selectedIndex = store.quizSelections[quiz.id] {
                                Text(selectedIndex == quiz.correctIndex ? quiz.explanation : "Not quite. \(quiz.explanation)")
                                    .font(.caption)
                                    .foregroundStyle(selectedIndex == quiz.correctIndex ? MorpheTheme.accent : MorpheTheme.textSecondary)
                            }

                            if store.completedQuizIDs.contains(quiz.id) {
                                Text("+\(quiz.rewardXP) XP earned")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(MorpheTheme.accentAlt)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            }

            GlassCard {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Learn")
                        .font(.headline)
                        .foregroundStyle(.white)

                    ForEach(store.lessons) { lesson in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(lesson.title)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.white)
                            Text(lesson.subtitle)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(MorpheTheme.accentAlt)
                            Text(lesson.detail)
                                .font(.caption)
                                .foregroundStyle(MorpheTheme.textSecondary)
                        }
                    }
                }
            }
        }
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
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(selected == feature ? MorpheTheme.panelStrong : MorpheTheme.panel)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
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

                Text("Recovery is \(recovery.status.rawValue.lowercased()) today. Adherence is \(adherence)% and the streak is still alive.")
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
