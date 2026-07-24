import SwiftUI

struct MoreView: View {
    @Environment(MorpheAppStore.self) private var store

    /// The three surfaces this tab actually owns. Scores/Progress duplicated
    /// the Progress tab and Quick Tools duplicated the Train tab + AI FAB, so
    /// both are gone — any stale store selection maps to Lessons.
    private static let tabs: [ClientHubFeature] = [.library, .nutrition, .learn]

    private var activeFeature: ClientHubFeature {
        let selected = store.selectedHubFeature ?? .learn
        return Self.tabs.contains(selected) ? selected : .learn
    }

    private var featuredDrills: [DrillReference] {
        store.drills
            .filter { $0.sport == store.selectedSportMode || $0.sport == .generalFitness }
            .prefix(4)
            .map { $0 }
    }

    /// ONE quiz per calendar day — the day picks it, completion doesn't skip
    /// ahead. (The old "first uncompleted" rule let a learner chain all 16 in
    /// one sitting, then hit an empty pool with a false "tomorrow" promise.)
    private var dailyQuiz: MiniQuiz? {
        guard !store.quizzes.isEmpty else { return nil }
        let dayIndex = Calendar.current.ordinality(of: .day, in: .year, for: .now) ?? 0
        return store.quizzes[dayIndex % store.quizzes.count]
    }

    private let mobilityLibrary = [
        "90/90 Hip Switch",
        "World's Greatest Stretch",
        "Thoracic Reach",
        "Ankle Rocker",
        "Child's Pose Breathing"
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionTitleView(
                title: "Learn",
                subtitle: "Exercise help, recovery, nutrition basics, and short lessons in one place."
            )
            .padding(.horizontal, 20)

            // Compact chip row instead of the old 5-tile grid: one line, always
            // visible, and the selected panel renders directly beneath it.
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(Self.tabs) { feature in
                        Button(chipTitle(for: feature)) {
                            store.selectedHubFeature = feature
                        }
                        .buttonStyle(FilterChipStyle(isSelected: activeFeature == feature))
                    }
                }
                .padding(.horizontal, 20)
            }

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 16) {
                    featureContent
                }
                .padding(.horizontal, 20)
                .padding(.top, 4)
                .padding(.bottom, 120)
            }
        }
        .padding(.top, 8)
    }

    private func chipTitle(for feature: ClientHubFeature) -> String {
        switch feature {
        case .library: return "Library"
        case .nutrition: return "Nutrition"
        default: return "Lessons"
        }
    }

    @ViewBuilder
    private var featureContent: some View {
        switch activeFeature {
        case .library:
            libraryPanel
        case .nutrition:
            nutritionPanel
        default:
            learningPanel
        }
    }

    private var libraryPanel: some View {
        Group {
            // (SportModeSelector removed from here: browsing the library must
            // not rewrite the user's sports, goal, and persisted profile as a
            // side effect — changing sport lives on the plan surfaces.)
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

    // MARK: - Nutrition

    /// One goal-flavored guidance line — the numbers themselves come from
    /// store.nutritionTargets (single source of truth) and render as pills.
    private var nutritionGuidanceLine: String {
        switch store.clientProfile.goal {
        case let goal where goal.localizedCaseInsensitiveContains("weight"):
            return "Keep vegetables high and carbs moderate — fullness makes a steady deficit easier."
        case let goal where goal.localizedCaseInsensitiveContains("conditioning"):
            return "Carbs fuel your sessions — eat most of them around training."
        default:
            return "Carbs, vegetables, and a couple of dairy servings round it out — consistency beats precision."
        }
    }

    private var nutritionPanel: some View {
        Group {
            GlassCard {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Nutrition Basics")
                        .font(.headline)
                        .foregroundStyle(.white)
                    Text("Hit the basics before trying to be perfect.")
                        .foregroundStyle(MorpheTheme.textSecondary)

                    HStack(spacing: 8) {
                        MetricPill(label: "Calories", value: store.nutritionTargets.calories.formatted())
                        MetricPill(label: "Protein", value: "\(store.nutritionTargets.proteinGrams)g")
                        MetricPill(label: "Water", value: "\(store.nutritionTargets.waterCups) cups")
                    }

                    Text(nutritionGuidanceLine)
                        .font(.subheadline)
                        .foregroundStyle(MorpheTheme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)

                    // The honest label for where the numbers come from.
                    Text(store.nutritionTargets.sourceNote)
                        .font(.caption)
                        .foregroundStyle(MorpheTheme.textMuted)
                        .fixedSize(horizontal: false, vertical: true)

                    if let tip = store.mealPrepTip {
                        HStack(alignment: .top, spacing: 10) {
                            Image(systemName: "fork.knife")
                                .font(.subheadline)
                                .foregroundStyle(MorpheTheme.accent)
                            Text(tip)
                                .font(.caption)
                                .foregroundStyle(MorpheTheme.textSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            RoundedRectangle(cornerRadius: MorpheTheme.radius, style: .continuous)
                                .fill(MorpheTheme.panelStrong)
                        )
                    }
                }
            }

            AIInsightCard(insight: store.nutritionInsight)
        }
    }

    // MARK: - Lessons (personalized ordering)

    /// Keywords from the user's own onboarding answers: goal phrases, training
    /// style names, and sport mode. Short/generic words are dropped so "Build
    /// consistency" contributes "consistency", not "build". View-side only —
    /// nothing is written back to the store.
    private var lessonKeywords: [String] {
        let profile = store.clientProfile
        var phrases: [String] = profile.selectedGoals
        phrases += profile.selectedTrainingStyles.map(\.rawValue)
        phrases.append(profile.sportMode.rawValue)

        let stopWords: Set<String> = [
            "and", "the", "for", "your", "with", "improve", "build", "get",
            "more", "better", "body", "work", "general", "fitness", "personal"
        ]
        var seen = Set<String>()
        var keywords: [String] = []
        for phrase in phrases {
            for word in phrase.lowercased().split(whereSeparator: { !$0.isLetter }) {
                let token = String(word)
                guard token.count >= 4, !stopWords.contains(token), seen.insert(token).inserted else { continue }
                keywords.append(token)
            }
        }
        return keywords
    }

    /// Deterministic relevance score: +3 for a keyword in the title, +1 in the
    /// subtitle/detail, and +2 when the user reported limitations and the
    /// lesson covers recovery/pain/safety. Ties keep authored order (stable).
    private func lessonScore(_ lesson: LessonCard, keywords: [String], boostRecovery: Bool) -> Int {
        let title = lesson.title.lowercased()
        let body = "\(lesson.subtitle) \(lesson.detail)".lowercased()
        var score = 0
        for keyword in keywords {
            if title.contains(keyword) { score += 3 }
            if body.contains(keyword) { score += 1 }
        }
        if boostRecovery {
            let safetyTerms = ["recovery", "pain", "sore", "safe", "deload", "rest", "sleep", "warm-up"]
            if safetyTerms.contains(where: { title.contains($0) || body.contains($0) }) {
                score += 2
            }
        }
        return score
    }

    /// Lessons reordered so the user's world comes first. `forYou` holds up to
    /// three lessons that actually matched (score > 0); everything else keeps
    /// its original authored order in `rest`.
    private var orderedLessons: (forYou: [LessonCard], rest: [LessonCard]) {
        let keywords = lessonKeywords
        let boostRecovery = !store.clientProfile.limitations
            .trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let scored = store.lessons.enumerated().map { index, lesson in
            (lesson: lesson, score: lessonScore(lesson, keywords: keywords, boostRecovery: boostRecovery), index: index)
        }
        // Stable: equal scores fall back to the original index.
        let sorted = scored.sorted {
            $0.score != $1.score ? $0.score > $1.score : $0.index < $1.index
        }
        let forYou = sorted.prefix(3).filter { $0.score > 0 }.map(\.lesson)
        guard !forYou.isEmpty else { return ([], store.lessons) }
        let rest = sorted.dropFirst(forYou.count).map(\.lesson)
        return (forYou, rest)
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

                    let lessons = orderedLessons

                    if !lessons.forYou.isEmpty {
                        Text("For you")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(MorpheTheme.accentAlt)
                            .textCase(.uppercase)

                        ForEach(lessons.forYou) { lesson in
                            lessonRow(lesson)
                        }

                        Text("All lessons")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(MorpheTheme.textMuted)
                            .textCase(.uppercase)
                            .padding(.top, 4)
                    }

                    ForEach(lessons.rest) { lesson in
                        lessonRow(lesson)
                    }
                }
            }

            // Personal Rules lived on the deleted Quick Tools panel; the rules
            // are learned habits, so they belong with the lessons.
            if !store.personalRules.isEmpty {
                PersonalRulesCard(rules: store.personalRules)
            }
        }
    }

    private func lessonRow(_ lesson: LessonCard) -> some View {
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

    private func quizOptionLabel(option: String, index: Int, quiz: MiniQuiz, answeredIndex: Int?) -> String {
        guard answeredIndex != nil || store.completedQuizIDs.contains(quiz.id) else { return option }
        return index == quiz.correctIndex ? "\(option), correct answer" : option
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
