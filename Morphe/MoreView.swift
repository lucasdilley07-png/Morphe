import SwiftUI

struct MoreView: View {
    @Environment(MorpheAppStore.self) private var store
    @State private var openedQuiz: MiniQuiz?

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

    /// Quizzes unlock chronologically (90f7d48): the FIRST uncompleted quiz
    /// is today's, one attempt per calendar day (`quizAnsweredToday` blocks
    /// chaining), and after 16 the wall says all-done honestly. (This
    /// comment previously described the retired day-picks-it scheme — on
    /// the wrong declaration, claiming the opposite rule. Audit 13, P2.)
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
                subtitle: "Ask me anything about training, recovery, or eating right — short lessons live here too.",
                titleSize: 16
            )
            .padding(.horizontal, 20)

            // Centered chip row (Lucas 2026-08-16): three chips balance on
            // the page's center line, matching the app-wide symmetry.
            HStack(spacing: 10) {
                ForEach(Self.tabs) { feature in
                    Button(chipTitle(for: feature)) {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            store.selectedHubFeature = feature
                        }
                    }
                    .buttonStyle(FilterChipStyle(isSelected: activeFeature == feature))
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 20)

            // Swipe between the three panels (Lucas 2026-08-18) — same
            // pager grammar as Train's SESSION|DISCOVER and Network's panes.
            TabView(selection: Binding(
                get: { activeFeature },
                set: { store.selectedHubFeature = $0 }
            )) {
                ForEach(Self.tabs) { feature in
                    ScrollView(showsIndicators: false) {
                        VStack(alignment: .leading, spacing: 16) {
                            panel(for: feature)
                            // Once per tab, on the last page — not three
                            // copies (audit 11, P2-16).
                            if feature == Self.tabs.last {
                                ManifestoCard()
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 4)
                        .padding(.bottom, 120)
                    }
                    .tag(feature)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
        }
        .padding(.top, MorpheTheme.Spacing.pageTopCompact)
    }

    @ViewBuilder
    private func panel(for feature: ClientHubFeature) -> some View {
        switch feature {
        case .library:
            libraryPanel
        case .nutrition:
            nutritionPanel
        default:
            learningPanel
        }
    }

    private func chipTitle(for feature: ClientHubFeature) -> String {
        switch feature {
        case .library: return "Library"
        case .nutrition: return "Nutrition"
        default: return "Lessons"
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
                        .foregroundStyle(MorpheTheme.textPrimary)
                    Text("Browse by muscle group, then open the movement for beginner-friendly form help and safer alternatives.")
                        .foregroundStyle(MorpheTheme.textSecondary)

                    // Platform note (audit 11, P2-17): a drag starting on
                    // this horizontal row scrolls the chips, not the pager
                    // — standard nested-scroll behavior; the page tabs
                    // above remain the guaranteed door.
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
                                    .foregroundStyle(MorpheTheme.textPrimary)
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
                        .foregroundStyle(MorpheTheme.textPrimary)

                    ForEach(featuredDrills) { drill in
                        LibraryDrillRow(drill: drill)
                    }
                }
            }

            GlassCard {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Stretching + Mobility")
                        .font(.headline)
                        .foregroundStyle(MorpheTheme.textPrimary)

                    ForEach(mobilityLibrary, id: \.self) { item in
                        HStack(spacing: 10) {
                            Image(systemName: "figure.flexibility")
                                .font(.subheadline)
                                .foregroundStyle(MorpheTheme.accentText)
                            Text(item)
                                .foregroundStyle(MorpheTheme.textPrimary)
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
                        .foregroundStyle(MorpheTheme.textPrimary)
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
                                .foregroundStyle(MorpheTheme.accentText)
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
            // Discover-style quiz wall (Lucas 2026-08-16): every quiz is a
            // tall calling card in a two-column grid — today's card is live,
            // finished ones review, the rest honestly say when they unlock.
            VStack(spacing: 12) {
                HStack {
                    Text("Quizzes")
                        .font(.headline)
                        .foregroundStyle(MorpheTheme.textPrimary)
                    Spacer()
                    Text("\(store.completedQuizIDs.count) of \(store.quizzes.count)")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(MorpheTheme.accentAlt)
                        .accessibilityLabel("\(store.completedQuizIDs.count) of \(store.quizzes.count) quizzes complete")
                }

                Text("One new question a day — answer it right the first time to earn XP.")
                    .font(.caption)
                    .foregroundStyle(MorpheTheme.textMuted)
                    .frame(maxWidth: .infinity)
                    .multilineTextAlignment(.center)

                LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible())], spacing: 12) {
                    ForEach(Array(store.quizzes.enumerated()), id: \.element.id) { index, quiz in
                        QuizCallingCard(
                            quiz: quiz,
                            index: index,
                            state: quizTileState(for: quiz)
                        ) {
                            openedQuiz = quiz
                        }
                    }
                }
            }
            .sheet(item: $openedQuiz) { quiz in
                QuizSheet(quiz: quiz)
                    .environment(store)
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
                    .background(PremiumBackground())
            }

            GlassCard {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Lessons")
                        .font(.headline)
                        .foregroundStyle(MorpheTheme.textPrimary)
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
                    .foregroundStyle(MorpheTheme.textPrimary)
                Text(lesson.subtitle)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(MorpheTheme.accentAlt)
            }
        }
        .disclosureGroupStyle(HUDDisclosureStyle())
    }

    private func quizTileState(for quiz: MiniQuiz) -> QuizTileState {
        // Completion is authoritative (audit 10, P0-1): only a CORRECT
        // answer earns .done and its XP footer — a wrong answer is
        // .missed, honestly labeled, no seal, no claimed XP.
        if store.completedQuizIDs.contains(quiz.id) { return .done }
        if store.quizSelections[quiz.id] != nil { return .missed }
        // Chronological line: the first un-aced quiz is today's (or locked
        // until tomorrow if today's attempt is spent); the rest wait.
        if quiz.id == store.quizzes.first(where: { !store.completedQuizIDs.contains($0.id) })?.id {
            return store.quizAnsweredToday ? .lockedTomorrow : .today
        }
        return .upcoming
    }
}

enum QuizTileState {
    case today
    case done
    case missed
    case lockedTomorrow
    case upcoming
}

/// One quiz as a tall Discover-style calling card: bold gradient plate,
/// tracked kicker, the question as the poster line, and an honest state
/// footer. Upcoming cards are visibly locked — the one-a-day cadence is
/// the product, not a dark pattern.
private struct QuizCallingCard: View {
    let quiz: MiniQuiz
    let index: Int
    let state: QuizTileState
    let onOpen: () -> Void

    /// Deliberate poster surfaces (like the share cards): fixed plates
    /// with per-plate text colors, identical in light and dark mode.
    private var plate: (fill: LinearGradient, text: Color) {
        switch index % 4 {
        case 0:
            return (LinearGradient(colors: [MorpheTheme.brandYellow, MorpheTheme.brandGold],
                                   startPoint: .topLeading, endPoint: .bottomTrailing), .black)
        case 1:
            return (LinearGradient(colors: [Color(red: 0.10, green: 0.10, blue: 0.12),
                                            Color(red: 0.16, green: 0.15, blue: 0.10)],
                                   startPoint: .topLeading, endPoint: .bottomTrailing), .white)
        case 2:
            return (LinearGradient(colors: [Color(red: 0.55, green: 0.38, blue: 0.05),
                                            Color(red: 0.35, green: 0.24, blue: 0.02)],
                                   startPoint: .topLeading, endPoint: .bottomTrailing), .white)
        default:
            return (LinearGradient(colors: [Color(red: 0.20, green: 0.20, blue: 0.24),
                                            Color(red: 0.10, green: 0.10, blue: 0.12)],
                                   startPoint: .topLeading, endPoint: .bottomTrailing), .white)
        }
    }

    private var footer: String {
        switch state {
        case .today: return "TODAY · TAP TO PLAY"
        case .done: return "ACED · +\(quiz.rewardXP) XP"
        case .missed: return "ANSWERED · NO XP"
        case .lockedTomorrow: return "UNLOCKS TOMORROW"
        case .upcoming: return "IN LINE · ONE A DAY"
        }
    }

    var body: some View {
        Button(action: onOpen) {
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Text(String(format: "QUIZ %02d", index + 1))
                        .font(MorpheTheme.microLabel(9))
                        .tracking(1.6)
                    Spacer()
                    if state == .done {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.caption.weight(.bold))
                    } else if state == .missed {
                        Image(systemName: "arrow.uturn.left")
                            .font(.caption2.weight(.bold))
                    } else if state == .upcoming || state == .lockedTomorrow {
                        Image(systemName: "lock.fill")
                            .font(.caption2.weight(.bold))
                    }
                }
                .opacity(0.75)

                Spacer(minLength: 10)

                Text(quiz.question)
                    .font(.subheadline.weight(.bold))
                    .multilineTextAlignment(.leading)
                    .lineLimit(4)
                    .minimumScaleFactor(0.85)

                Spacer(minLength: 10)

                Text(footer)
                    .font(MorpheTheme.microLabel(8))
                    .tracking(1.2)
                    .opacity(0.8)
            }
            .foregroundStyle(plate.text)
            .padding(14)
            .frame(maxWidth: .infinity, minHeight: 150, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: MorpheTheme.radius, style: .continuous)
                    .fill(plate.fill)
            )
            .overlay(
                RoundedRectangle(cornerRadius: MorpheTheme.radius, style: .continuous)
                    .stroke(state == .today ? plate.text.opacity(0.9) : Color.clear, lineWidth: 2)
            )
            // Upcoming cards read locked, not broken.
            .saturation(state == .upcoming || state == .lockedTomorrow ? 0.35 : 1)
            .opacity(state == .upcoming || state == .lockedTomorrow ? 0.55 : 1)
        }
        .buttonStyle(.plain)
        .disabled(state == .upcoming || state == .lockedTomorrow)
        .accessibilityLabel({
            switch state {
            case .upcoming: return "Quiz \(index + 1), in line — one unlocks a day"
            case .lockedTomorrow: return "Quiz \(index + 1), unlocks tomorrow"
            case .done: return "Quiz \(index + 1): \(quiz.question). Completed"
            case .missed: return "Quiz \(index + 1): \(quiz.question). Answered, no XP — review the explanation"
            case .today: return "Quiz \(index + 1): \(quiz.question). Today's quiz"
            }
        }())
    }
}

/// The tapped card opens here: the existing answer flow (or a review of a
/// finished one) in a sheet — same store logic, calling-card front door.
private struct QuizSheet: View {
    @Environment(MorpheAppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let quiz: MiniQuiz

    var body: some View {
        let answeredIndex = store.quizSelections[quiz.id]
        let isComplete = store.completedQuizIDs.contains(quiz.id)

        ScrollView(showsIndicators: false) {
            VStack(spacing: 14) {
                Text(isComplete || answeredIndex != nil ? "QUIZ REVIEW" : "DAILY QUIZ")
                    .font(MorpheTheme.microLabel(10))
                    .tracking(1.6)
                    .foregroundStyle(MorpheTheme.accentText)

                Text(quiz.question)
                    .font(.title3.weight(.bold))
                    .foregroundStyle(MorpheTheme.textPrimary)
                    .multilineTextAlignment(.center)

                VStack(spacing: 8) {
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
                        .accessibilityLabel(quizAccessibilityLabel(option: option, index: index, answeredIndex: answeredIndex, isComplete: isComplete))
                    }
                }

                if let answeredIndex {
                    // "Correct/Not quite" in words, not just color.
                    Text(answeredIndex == quiz.correctIndex
                         ? "Correct! \(quiz.explanation)"
                         : "Not quite. \(quiz.explanation)")
                        .font(.subheadline)
                        .foregroundStyle(answeredIndex == quiz.correctIndex ? MorpheTheme.accentText : MorpheTheme.textSecondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                } else if isComplete {
                    Text("Already aced — the correct answer is highlighted. \(quiz.explanation)")
                        .font(.subheadline)
                        .foregroundStyle(MorpheTheme.textSecondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }

                if isComplete || answeredIndex != nil {
                    Text("+\(quiz.rewardXP) XP\(isComplete || answeredIndex == quiz.correctIndex ? " earned" : " next time")")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(MorpheTheme.accentAlt)
                }

                Button("Done") { dismiss() }
                    .buttonStyle(SecondaryCTAButtonStyle())
                    .frame(width: 160)
                    .padding(.top, 4)
            }
            .padding(24)
        }
    }

    private func quizAccessibilityLabel(option: String, index: Int, answeredIndex: Int?, isComplete: Bool) -> String {
        guard answeredIndex != nil || isComplete else { return option }
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
                    .foregroundStyle(MorpheTheme.textPrimary)
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
