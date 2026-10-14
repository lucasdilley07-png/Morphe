import SwiftUI
import AVFoundation

struct MoreView: View {
    @Environment(MorpheAppStore.self) private var store
    @State private var openedQuiz: MiniQuiz?
    /// The saying the door card showed when it was tapped — The Code
    /// leads with exactly that line.
    @State private var openedSaying: LaconicSaying?
    @State private var showLessons = false
    @State private var showWhyMorphe = false
    @State private var showChart = false
    @State private var showBasics = false
    /// Which block of ten quizzes is open (nil = the one holding today's).
    @State private var quizPage: Int?
    private static let quizPageSize = 10

    private var defaultQuizPage: Int {
        let todayIndex = store.quizzes.firstIndex { !store.completedQuizIDs.contains($0.id) } ?? max(0, store.quizzes.count - 1)
        return todayIndex / Self.quizPageSize
    }
    @State private var openedLibraryPage: LearnLibraryPageKind?
    @State private var pendingExerciseOpen: ExerciseReference?
    @State private var pendingSavedWorkoutStart: SavedWorkoutLibraryItem?

    /// The three surfaces this tab actually owns. Scores/Progress duplicated
    /// the Progress tab and Quick Tools duplicated the Train tab + AI FAB, so
    /// both are gone — any stale store selection maps to Lessons.
    // Lessons first, then Nutrition, then Library (Lucas 2026-10-13).
    private static let tabs: [ClientHubFeature] = [.learn, .nutrition, .library]

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
    /// chaining), and after the last one the wall says all-done honestly. (This
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
        // The title and the chips scroll with each page (Lucas
        // 2026-10-05) — nothing stays pinned; the swipe between the three
        // panels is unchanged.
        VStack(alignment: .leading, spacing: 12) {
            // The chips are buttons only (Lucas 2026-10-05): the
            // horizontal swipe belongs to the main tab pager now.
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 16) {
                    learnHeader
                    panel(for: activeFeature)
                    // (Why Morphe folds inside the Lessons page now.)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 120)
            }
            .id(activeFeature)
        }
        .inTabPageSwipe(pages: Self.tabs, selection: Binding(
            get: { activeFeature }, set: { store.selectedHubFeature = $0 }))
        .padding(.top, MorpheTheme.Spacing.pageTopCompact)
    }

    /// Title + chip row, repeated at the top of every page's scroll.
    private var learnHeader: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionTitleView(
                title: "Learn",
                subtitle: "Lessons, the exercise library, and nutrition basics live here. Tap the Morphe bubble to ask anything.",
                titleSize: 16
            )

            // Centered chip row (Lucas 2026-08-16): three chips balance on
            // the page's center line, matching the app-wide symmetry.
            HStack(spacing: 20) {
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
        }
    }

    @ViewBuilder
    private func panel(for feature: ClientHubFeature) -> some View {
        switch feature {
        case .library:
            libraryPanel
        case .nutrition:
            nutritionPanel
        default:
            Group {
                CoachNotesCard()
                learningPanel
            }
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
            // Doors, not walls (Lucas 2026-10-10): the exercise library
            // and every saved thing open as their own slide-up page.
            LearnLibraryRow(systemImage: "figure.strengthtraining.traditional", title: "Exercise Library",
                            detail: "\(store.allExercises.count) movements by muscle group — form help and safer alternatives inside.") {
                openedLibraryPage = .exercises
            }

            VStack(alignment: .leading, spacing: 10) {
                CodeLabel(text: "Saved", color: MorpheTheme.accentText)
                LearnLibraryRow(systemImage: "bookmark", title: "Saved posts",
                                detail: store.savedPostIds.isEmpty ? "Nothing saved yet — bookmark a post from its menu." : "\(store.savedPostIds.count) saved") {
                    openedLibraryPage = .savedPosts
                }
                LearnLibraryRow(systemImage: "dumbbell", title: "Saved workouts",
                                detail: store.savedWorkouts.isEmpty ? "Nothing saved yet — save one from Discover or build one in Train." : "\(store.savedWorkouts.count) saved") {
                    openedLibraryPage = .savedWorkouts
                }
                LearnLibraryRow(systemImage: "figure.walk", title: "Saved exercises",
                                detail: store.savedExerciseIDs.isEmpty ? "Nothing saved yet — tap the bookmark on any movement." : "\(store.savedExerciseIDs.count) saved") {
                    openedLibraryPage = .savedExercises
                }
                LearnLibraryRow(systemImage: "fork.knife", title: "Saved diet plans",
                                detail: store.savedDietPlanModes.isEmpty ? "Nothing saved yet — save a plan from the chart under Nutrition." : "\(store.savedDietPlanModes.count) saved") {
                    openedLibraryPage = .savedDietPlans
                }
                LearnLibraryRow(systemImage: "text.book.closed", title: "Saved lessons",
                                detail: store.savedLessonIDs.isEmpty ? "Nothing saved yet — tap the bookmark on any lesson." : "\(store.savedLessonIDs.count) saved") {
                    openedLibraryPage = .savedLessons
                }
            }
            .sheet(item: $openedLibraryPage, onDismiss: {
                // A sheet can't present the root exercise sheet while it's
                // up — the tapped movement opens once this page is gone.
                if let exercise = pendingExerciseOpen {
                    pendingExerciseOpen = nil
                    store.selectedExercise = exercise
                }
                if let item = pendingSavedWorkoutStart {
                    pendingSavedWorkoutStart = nil
                    store.startSavedWorkout(item)
                }
            }) { page in
                LearnLibraryPage(page: page,
                                 onOpenExercise: { exercise in pendingExerciseOpen = exercise; openedLibraryPage = nil },
                                 onStartSavedWorkout: { item in pendingSavedWorkoutStart = item; openedLibraryPage = nil })
                    .environment(store)
                    .presentationDetents([.large])
                    .presentationDragIndicator(.visible)
                    .presentationCornerRadius(28)
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
            FoodCheckCard()

            FuelLogCard()

            // Drop-downs, chart first (Lucas 2026-10-10).
            LearnDisclosure(title: "The chart", subtitle: "Calories and the carb · protein · fat split for your goal, from your logged weight.", isExpanded: $showChart) {
                NutritionChartCard()
            }

            LearnDisclosure(title: "Nutrition basics", subtitle: "Calories, protein, water — the three numbers to hit before anything fancy.", isExpanded: $showBasics) {
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
            // The record's line for today (docs/SPARTAN-LORE.md) — the
            // door to The Code. One saying a day, never reshuffled.
            let todaysLine = SpartanLore.saying()
            RecordLineCard(saying: todaysLine) {
                openedSaying = todaysLine
            }
            // Only the saying (Lucas 2026-10-10): a quote pop-up that
            // changes every day — the ladder and the rest of The Code
            // stay behind the rank row on Profile.
            .sheet(item: $openedSaying) { saying in
                DailySayingSheet(saying: saying)
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
                    .presentationCornerRadius(28)
            }

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

                // Ten at a time (Lucas 2026-10-10): pages of 1–10, 11–20, …
                // sized to the real quiz count; the page holding today's
                // quiz opens first.
                let pageCount = max(1, (store.quizzes.count + Self.quizPageSize - 1) / Self.quizPageSize)
                let page = min(quizPage ?? defaultQuizPage, pageCount - 1)
                let shown = Array(store.quizzes.enumerated()).dropFirst(page * Self.quizPageSize).prefix(Self.quizPageSize)
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible())], spacing: 12) {
                    ForEach(Array(shown), id: \.element.id) { index, quiz in
                        QuizCallingCard(
                            quiz: quiz,
                            index: index,
                            state: quizTileState(for: quiz)
                        ) {
                            openedQuiz = quiz
                        }
                    }
                }

                // The 1–10 / 11–20 pager sits under the quizzes (Lucas 2026-10-10).
                if pageCount > 1 {
                    HStack(spacing: 8) {
                        ForEach(0..<pageCount, id: \.self) { index in
                            let first = index * Self.quizPageSize + 1
                            let last = min((index + 1) * Self.quizPageSize, store.quizzes.count)
                            Button("\(first)–\(last)") {
                                withAnimation(.easeInOut(duration: 0.2)) { quizPage = index }
                                Haptics.selection()
                            }
                            .buttonStyle(FilterChipStyle(isSelected: page == index))
                            .accessibilityLabel("Quizzes \(first) to \(last)")
                            .accessibilityAddTraits(page == index ? .isSelected : [])
                        }
                    }
                    .frame(maxWidth: .infinity)
                }

            }
            .sheet(item: $openedQuiz) { quiz in
                QuizSheet(quiz: quiz)
                    .environment(store)
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
                    .presentationCornerRadius(28)
                    .background(PremiumBackground())
            }

            // Drop-downs (Lucas 2026-10-10): Lessons and Why Morphe fold
            // away so the page doesn't run long.
            LearnDisclosure(title: "Lessons", subtitle: "Two-minute reads on training, recovery, and effort.", isExpanded: $showLessons) {
                VStack(alignment: .leading, spacing: 12) {
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

            LearnDisclosure(title: "Why Morphe", subtitle: "The four rules the app is built on.", isExpanded: $showWhyMorphe) {
                ManifestoCard()
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
            HStack(alignment: .top, spacing: 8) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(lesson.title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(MorpheTheme.textPrimary)
                    Text(lesson.subtitle)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(MorpheTheme.accentAlt)
                }
                Spacer(minLength: 0)
                Button {
                    store.toggleSavedLesson(lesson)
                    Haptics.impact(.light)
                } label: {
                    Image(systemName: store.savedLessonIDs.contains(lesson.id) ? "bookmark.fill" : "bookmark")
                        .font(.subheadline)
                        .foregroundStyle(MorpheTheme.accentText)
                        .frame(width: 32, height: 32)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(store.savedLessonIDs.contains(lesson.id) ? "Remove from saved lessons" : "Save lesson")
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
            return (LinearGradient(colors: [MorpheTheme.brandBlue, MorpheTheme.brandBlueDeep],
                                   startPoint: .topLeading, endPoint: .bottomTrailing), .white)
        case 1:
            return (LinearGradient(colors: [Color(red: 0.10, green: 0.10, blue: 0.12),
                                            Color(red: 0.16, green: 0.16, blue: 0.18)],
                                   startPoint: .topLeading, endPoint: .bottomTrailing), .white)
        case 2:
            // Deep blue, not the gold-era bronze (audit 30).
            return (LinearGradient(colors: [MorpheTheme.brandBlueDeep,
                                            Color(red: 0.102, green: 0.153, blue: 0.40)],
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
                    .font(MorpheTheme.microLabel(10))
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
                         ? "Correct. \(quiz.explanation)"
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

// MARK: - The Code (the Spartan record, sourced)

/// Ancient words wear a serif — the one typographic break from the HUD,
/// so the record always reads as the record and never as app copy.
private extension Font {
    static func record(_ style: Font.TextStyle, weight: Font.Weight = .semibold) -> Font {
        .system(style, design: .serif).weight(weight)
    }
}

/// The one micro-label treatment The Code uses, everywhere.
private struct CodeLabel: View {
    let text: String
    var color: Color = MorpheTheme.textMuted

    var body: some View {
        Text(text.uppercased())
            .font(MorpheTheme.microLabel())
            .tracking(1.4)
            .foregroundStyle(color)
    }
}

/// A Learn → Library door: glyph, title, one line, chevron.
struct LearnLibraryRow: View {
    let systemImage: String
    let title: String
    let detail: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            GlassCard(.quiet) {
                HStack(spacing: 12) {
                    Image(systemName: systemImage)
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(MorpheTheme.accentText)
                        .frame(width: 28)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(title)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(MorpheTheme.textPrimary)
                        Text(detail)
                            .font(.caption)
                            .foregroundStyle(MorpheTheme.textMuted)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.up")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(MorpheTheme.textMuted)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(title). \(detail)")
        .accessibilityHint("Opens a page")
    }
}

enum LearnLibraryPageKind: String, Identifiable {
    case exercises, savedPosts, savedWorkouts, savedExercises, savedDietPlans, savedLessons
    var id: String { rawValue }
    var title: String {
        switch self {
        case .exercises: return "Exercise Library"
        case .savedPosts: return "Saved posts"
        case .savedWorkouts: return "Saved workouts"
        case .savedExercises: return "Saved exercises"
        case .savedDietPlans: return "Saved diet plans"
        case .savedLessons: return "Saved lessons"
        }
    }
}

/// The slide-up page behind each library row.
struct LearnLibraryPage: View {
    @Environment(MorpheAppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let page: LearnLibraryPageKind
    let onOpenExercise: (ExerciseReference) -> Void
    let onStartSavedWorkout: (SavedWorkoutLibraryItem) -> Void

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .firstTextBaseline) {
                    Text(page.title)
                        .font(.title2.weight(.bold))
                        .foregroundStyle(MorpheTheme.textPrimary)
                    Spacer(minLength: 8)
                    Button("Done") { dismiss() }
                        .foregroundStyle(MorpheTheme.textPrimary)
                        .frame(minWidth: 44, minHeight: 44)
                }
                content
            }
            .padding(20)
        }
        .background(PremiumBackground().ignoresSafeArea())
    }

    @ViewBuilder
    private var content: some View {
        switch page {
        case .exercises:
            Text("Browse by muscle group, then open the movement for form help and safer alternatives.")
                .font(.subheadline)
                .foregroundStyle(MorpheTheme.textSecondary)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(MuscleGroup.allCases) { group in
                        Button(group.rawValue) { store.selectMuscleGroup(group) }
                            .buttonStyle(FilterChipStyle(isSelected: store.selectedMuscleGroup == group))
                    }
                }
            }
            exerciseList(store.filteredExercises)
        case .savedExercises:
            if store.savedExercises.isEmpty {
                empty("Nothing saved yet. Open any movement and tap the bookmark.")
            } else {
                exerciseList(store.savedExercises)
            }
        case .savedPosts:
            if store.savedPostIds.isEmpty {
                empty("Nothing saved yet. Bookmark a post from its menu.")
            } else if store.savedFeedPosts.isEmpty {
                empty("\(store.savedPostIds.count) saved — they show here once the feed has loaded them.")
            } else {
                ForEach(store.savedFeedPosts) { post in
                    GlassCard(.quiet) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(post.authorName)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(MorpheTheme.accentText)
                            Text(post.text)
                                .font(.subheadline)
                                .foregroundStyle(MorpheTheme.textPrimary)
                                .fixedSize(horizontal: false, vertical: true)
                            Button("Remove from saved") { store.toggleSaved(post) }
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(MorpheTheme.textMuted)
                                .buttonStyle(.plain)
                                .frame(minHeight: 32)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
        case .savedWorkouts:
            if store.savedWorkouts.isEmpty {
                empty("Nothing saved yet. Save one from Discover, or build one in Train → Build Workout.")
            } else {
                ForEach(store.savedWorkouts) { item in
                    GlassCard(.quiet) {
                        HStack(alignment: .top, spacing: 10) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(item.workoutName)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(MorpheTheme.textPrimary)
                                Text({
                                    let insight = store.savedWorkoutInsight(for: item)
                                    return insight.completionCount == 0
                                        ? "\(item.sport.rawValue) · never completed"
                                        : "\(item.sport.rawValue) · completed \(insight.completionCount)×"
                                }())
                                    .font(.caption)
                                    .foregroundStyle(MorpheTheme.textSecondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            Spacer(minLength: 0)
                            Button("Start") { onStartSavedWorkout(item) }
                                .buttonStyle(SecondaryCTAButtonStyle())
                                .frame(width: 80)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
        case .savedDietPlans:
            if store.savedDietPlans.isEmpty {
                empty("Nothing saved yet. Under Nutrition → The chart, pick a goal and tap Save this plan.")
            } else {
                ForEach(store.savedDietPlans) { mode in
                    GlassCard(.quiet) {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text(mode.rawValue)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(MorpheTheme.textPrimary)
                                Spacer()
                                Button { store.toggleSavedDietPlan(mode) } label: {
                                    Image(systemName: "bookmark.fill")
                                        .foregroundStyle(MorpheTheme.accentText)
                                        .frame(width: 32, height: 32)
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel("Remove \(mode.rawValue) plan")
                            }
                            if let plan = store.nutritionPlan(for: mode) {
                                HStack(spacing: 8) {
                                    MetricPill(label: "Calories", value: "\(plan.calories)")
                                    MetricPill(label: "Carbs", value: "\(plan.carbGrams)g")
                                    MetricPill(label: "Protein", value: "\(plan.proteinGrams)g")
                                    MetricPill(label: "Fat", value: "\(plan.fatGrams)g")
                                }
                                Text("From your logged weight (\(plan.weightLb) lb) — the numbers move when the weight does.")
                                    .font(.caption)
                                    .foregroundStyle(MorpheTheme.textMuted)
                            } else {
                                Text("Log your weight in Profile → Your Details to see the numbers.")
                                    .font(.caption)
                                    .foregroundStyle(MorpheTheme.textMuted)
                            }
                            Text(mode.rule)
                                .font(.caption)
                                .foregroundStyle(MorpheTheme.textSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
        case .savedLessons:
            if store.savedLessons.isEmpty {
                empty("Nothing saved yet. Tap the bookmark on any lesson.")
            } else {
                ForEach(store.savedLessons) { lesson in
                    GlassCard(.quiet) {
                        VStack(alignment: .leading, spacing: 6) {
                            HStack(alignment: .top) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(lesson.title)
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(MorpheTheme.textPrimary)
                                    Text(lesson.subtitle)
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(MorpheTheme.accentAlt)
                                }
                                Spacer(minLength: 0)
                                Button { store.toggleSavedLesson(lesson) } label: {
                                    Image(systemName: "bookmark.fill")
                                        .foregroundStyle(MorpheTheme.accentText)
                                        .frame(width: 32, height: 32)
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel("Remove from saved lessons")
                            }
                            Text(lesson.detail)
                                .font(.subheadline)
                                .foregroundStyle(MorpheTheme.textSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
        }
    }

    private func exerciseList(_ exercises: [ExerciseReference]) -> some View {
        VStack(spacing: 8) {
            ForEach(exercises) { exercise in
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
                    Button("Open") { onOpenExercise(exercise) }
                        .buttonStyle(SecondaryCTAButtonStyle())
                        .frame(width: 88)
                }
                .padding(.vertical, 4)
            }
        }
    }

    private func empty(_ text: String) -> some View {
        GlassCard(.quiet) {
            Text(text)
                .font(.subheadline)
                .foregroundStyle(MorpheTheme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

/// The quote pop-up (Lucas 2026-10-10): today's saying, who said it,
/// when, and where it is written — nothing else.
struct DailySayingSheet: View {
    @Environment(\.dismiss) private var dismiss
    let saying: LaconicSaying

    var body: some View {
        ScrollView(showsIndicators: false) {
        VStack(alignment: .leading, spacing: 18) {
            CodeLabel(text: "From the record · today", color: MorpheTheme.accentText)
            Text("\u{201C}\(saying.text)\u{201D}")
                .font(.record(.title2))
                .foregroundStyle(MorpheTheme.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
            VStack(alignment: .leading, spacing: 6) {
                Text(saying.speaker)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(MorpheTheme.textPrimary)
                Text(saying.context)
                    .font(.subheadline)
                    .foregroundStyle(MorpheTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                Text(saying.source)
                    .font(.caption)
                    .foregroundStyle(MorpheTheme.textMuted)
            }
            Text("A new line every day.")
                .font(.caption2)
                .foregroundStyle(MorpheTheme.textMuted)
            Button("Done") { dismiss() }
                .buttonStyle(SecondaryCTAButtonStyle())
        }
        .padding(24)
        .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(PremiumBackground().ignoresSafeArea())
    }
}

/// A folding section for Learn: tracked label, hairline, +/-; the
/// subtitle shows only while folded.
struct LearnDisclosure<Content: View>: View {
    let title: String
    let subtitle: String
    @Binding var isExpanded: Bool
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) { isExpanded.toggle() }
            } label: {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 10) {
                        Text(title.uppercased())
                            .font(MorpheTheme.microLabel(12))
                            .tracking(1.6)
                            .foregroundStyle(MorpheTheme.textPrimary)
                            .lineLimit(1)
                            .layoutPriority(1)
                        Rectangle()
                            .fill(MorpheTheme.stroke)
                            .frame(height: 1)
                            .frame(maxWidth: .infinity)
                        Image(systemName: isExpanded ? "minus" : "plus")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(MorpheTheme.accentText)
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
            .accessibilityLabel("\(title), \(isExpanded ? "expanded" : "collapsed")")
            if isExpanded {
                content()
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }
}

/// Today's saying as a slim door to the quote pop-up.
struct RecordLineCard: View {
    let saying: LaconicSaying
    let onOpen: () -> Void

    var body: some View {
        Button(action: onOpen) {
            GlassCard(.quiet) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        CodeLabel(text: "From the record", color: MorpheTheme.accentText)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(MorpheTheme.textMuted)
                    }
                    Text("\u{201C}\(saying.text)\u{201D}")
                        .font(.record(.title3))
                        .foregroundStyle(MorpheTheme.textPrimary)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                    Text("\(saying.speaker) · \(saying.source)")
                        .font(.caption)
                        .foregroundStyle(MorpheTheme.textMuted)
                        .multilineTextAlignment(.leading)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("From the record: \(saying.text) \(saying.speaker), \(saying.source)")
        .accessibilityHint("Shows today's saying")
    }
}

/// The Code: what Morphe takes from Sparta, every line with its source —
/// and, said plainly, what it leaves behind. Opened from the Learn tab
/// and from the rank on the Profile level card. The caller passes the
/// saying it showed, so the page always leads with the line that was
/// tapped (a midnight rollover can't swap it underneath).
struct SpartanCodeSheet: View {
    @Environment(\.dismiss) private var dismiss
    var saying: LaconicSaying = SpartanLore.saying()

    var body: some View {
        ScrollView(showsIndicators: false) {
            SpartanCodeContent(saying: saying, onDone: { dismiss() })
                .padding(24)
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(28)
        .background(PremiumBackground())
    }
}

/// The Code's page, separate from its scroll container so it can be laid
/// out and rendered on its own.
struct SpartanCodeContent: View {
    @Environment(MorpheAppStore.self) private var store
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    var saying: LaconicSaying = SpartanLore.saying()
    let onDone: () -> Void

    private var rank: MorpheRank { MorpheRank.rank(forLevel: store.currentLevelNumber) }

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 8) {
                    CodeLabel(text: "The Code", color: MorpheTheme.accentText)
                    Text("Nothing here is invented.")
                        .font(.title2.weight(.bold))
                        .foregroundStyle(MorpheTheme.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityAddTraits(.isHeader)
                    Text("Every line is in the ancient record. The source sits under it.")
                        .font(.subheadline)
                        .foregroundStyle(MorpheTheme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
                // The exit at the top of a long page — not only at the end.
                Button(action: onDone) {
                    Image(systemName: "xmark")
                        .font(.footnote.weight(.bold))
                        .foregroundStyle(MorpheTheme.textSecondary)
                        .frame(width: 44, height: 44)
                        .background(Circle().fill(MorpheTheme.panelStrong).frame(width: 32, height: 32))
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Close")
            }

            // The typographic moment: the day's line, large, in serif.
            // Capped below the largest accessibility sizes so the page
            // still has content under it.
            VStack(alignment: .leading, spacing: 12) {
                Text("\u{201C}\(saying.text)\u{201D}")
                    .font(.record(saying.text.count > 40 ? .title : .largeTitle, weight: .bold))
                    .foregroundStyle(MorpheTheme.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                    .dynamicTypeSize(...DynamicTypeSize.accessibility2)
                Text("\(saying.speaker). \(saying.context)")
                    .font(.subheadline)
                    .foregroundStyle(MorpheTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                sourceLine(saying.source)
            }
            .accessibilityElement(children: .combine)

            ladder

            GlassCard {
                VStack(alignment: .leading, spacing: 4) {
                    sectionLabel("The record")
                        .padding(.bottom, 4)
                    ForEach(SpartanLore.entries) { entry in
                        DisclosureGroup {
                            VStack(alignment: .leading, spacing: 8) {
                                Text(entry.body)
                                    .font(.subheadline)
                                    .foregroundStyle(MorpheTheme.textSecondary)
                                    .fixedSize(horizontal: false, vertical: true)
                                sourceLine(entry.source)
                            }
                            .padding(.bottom, 8)
                        } label: {
                            // Priority over the style's hairline, so a
                            // title only wraps when it truly has to.
                            Text(entry.title)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(MorpheTheme.textPrimary)
                                .multilineTextAlignment(.leading)
                                .layoutPriority(1)
                        }
                        .disclosureGroupStyle(HUDDisclosureStyle())
                    }
                }
            }

            GlassCard {
                VStack(alignment: .leading, spacing: 16) {
                    // The day's line already leads the page — the list
                    // is the rest of the record.
                    sectionLabel("More sayings")
                    ForEach(SpartanLore.sayings.filter { $0 != saying }) { other in
                        VStack(alignment: .leading, spacing: 4) {
                            Text("\u{201C}\(other.text)\u{201D}")
                                .font(.record(.body))
                                .foregroundStyle(MorpheTheme.textPrimary)
                                .fixedSize(horizontal: false, vertical: true)
                            Text("\(other.speaker). \(other.context)")
                                .font(.caption)
                                .foregroundStyle(MorpheTheme.textSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                            sourceLine(other.source)
                        }
                        .accessibilityElement(children: .combine)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            // ("What Morphe leaves behind" left the sheet, Lucas 2026-10-10;
            // the entry stays in SpartanLore for the AI's lore guardrail.)

            Button("Done", action: onDone)
                .buttonStyle(SecondaryCTAButtonStyle())
                .frame(maxWidth: .infinity)
        }
    }

    /// The agoge ladder as a climbed rail: the line is lit up to the
    /// user's own rung — earned from logged work only, like every other
    /// number in the app. A rail, not a column of radio buttons: nothing
    /// here is selectable.
    private var ladder: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                sectionLabel("The ladder")
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(MorpheRank.allCases) { rung in
                        ladderRow(rung)
                    }
                }
                Text("Ten ranks, climbed by level, each with its own accent color — Rookie starts in Morphe Dark Blue, Colonel earns platinum, General wears gold. Levels come from logged work and lessons — there is nothing to buy and nothing to skip.")
                    .font(.caption)
                    .foregroundStyle(MorpheTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func ladderRow(_ rung: MorpheRank) -> some View {
        let isCurrent = rung == rank
        let reached = rung.rawValue <= rank.rawValue
        let lit = MorpheTheme.accentText
        let unlit = MorpheTheme.stroke
        let levelText = isCurrent ? "You · Level \(store.currentLevelNumber)" : "Level \(rung.firstLevel)"
        return HStack(alignment: .top, spacing: 12) {
            // Rail segment + node. The segment above a node is lit when
            // the node is reached; below it, when the NEXT one is.
            VStack(spacing: 0) {
                Rectangle()
                    .fill(rung == .rookie ? Color.clear : (reached ? lit : unlit))
                    .frame(width: 2, height: 8)
                Circle()
                    .fill(reached ? lit : Color.clear)
                    .overlay(Circle().stroke(reached ? lit : unlit, lineWidth: 2))
                    .frame(width: isCurrent ? 16 : 12, height: isCurrent ? 16 : 12)
                Rectangle()
                    .fill(rung.next == nil ? Color.clear
                          : (rung.rawValue < rank.rawValue ? lit : unlit))
                    .frame(width: 2)
                    .frame(maxHeight: .infinity)
            }
            .frame(width: 16)
            .accessibilityHidden(true)

            // The rank's color, left of its name (Lucas 2026-10-10): what
            // each rung unlocks, locked until the rung is reached.
            ZStack {
                Circle()
                    .fill(MorpheTheme.swatchStyle(for: rung.palette))
                    .overlay(Circle().stroke(MorpheTheme.strokeSubtle, lineWidth: 1))
                    .opacity(reached ? 1 : 0.4)
                if !reached {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(MorpheTheme.textPrimary)
                        .shadow(color: .black.opacity(0.35), radius: 1)
                }
            }
            .frame(width: 28, height: 28)
            .padding(.top, 2)
            .accessibilityHidden(true)

            // Side by side at normal sizes; stacked once the type is
            // large enough that both columns would break mid-word.
            Group {
                if dynamicTypeSize.isAccessibilitySize {
                    VStack(alignment: .leading, spacing: 4) {
                        ladderTitle(rung, isCurrent: isCurrent)
                        CodeLabel(text: levelText, color: isCurrent ? lit : MorpheTheme.textMuted)
                    }
                } else {
                    HStack(alignment: .firstTextBaseline, spacing: 12) {
                        ladderTitle(rung, isCurrent: isCurrent)
                        Spacer(minLength: 0)
                        CodeLabel(text: levelText, color: isCurrent ? lit : MorpheTheme.textMuted)
                            .monospacedDigit()
                    }
                }
            }
            .padding(.top, 4)
            .padding(.bottom, 12)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(rung.title). \(rung.gloss) From level \(rung.firstLevel), unlocks the \(rung.palette.rawValue) accent\(reached ? "" : ", locked"). \(isCurrent ? "Your rank, level \(store.currentLevelNumber)" : (reached ? "Reached" : "Not reached yet"))")
    }

    private func ladderTitle(_ rung: MorpheRank, isCurrent: Bool) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(rung.title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(isCurrent ? MorpheTheme.accentText : MorpheTheme.textPrimary)
            Text(rung.gloss)
                .font(.caption)
                .foregroundStyle(MorpheTheme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func sectionLabel(_ text: String) -> some View {
        CodeLabel(text: text)
            .accessibilityAddTraits(.isHeader)
    }

    private func sourceLine(_ source: String) -> some View {
        Text(source)
            .font(.caption2)
            .foregroundStyle(MorpheTheme.textMuted)
            .fixedSize(horizontal: false, vertical: true)
    }
}

// MARK: - Fuel log (2026-10-04)

/// Today's food and water, logged by hand: protein, calories, cups.
/// The store has kept this day (and its history chart) since the nutrition
/// wave — this card is the door that was missing. Morphe does not estimate
/// food; every number is the user's.
struct FuelLogCard: View {
    @Environment(MorpheAppStore.self) private var store
    @State private var showSearch = false
    @State private var showCamera = false
    @State private var showManual = false
    @State private var estimate: FoodCheckRecord?
    @State private var pendingEstimate: FoodCheckRecord?
    @State private var showNeedsKey = false

    var body: some View {
        let targets = store.nutritionTargets
        let plan = store.nutritionPlan
        let day = store.nutrition

        return GlassCard {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Today's Fuel")
                        .font(.headline)
                        .foregroundStyle(MorpheTheme.textPrimary)
                    Text("Search the library or shoot the plate. Every number shows where it came from; photo numbers are estimates.")
                        .font(.caption)
                        .foregroundStyle(MorpheTheme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                // The day against the plan: calories and protein from the
                // targets, carbs and fat from the chart's split.
                VStack(spacing: 12) {
                    FuelMeter(label: "Calories", value: day.caloriesConsumed, target: targets.calories, unit: "")
                    FuelMeter(label: "Protein", value: day.proteinConsumed, target: targets.proteinGrams, unit: "g")
                    if let plan {
                        HStack(spacing: 12) {
                            FuelMeter(label: "Carbs", value: store.carbsConsumedToday, target: plan.carbGrams, unit: "g")
                            FuelMeter(label: "Fat", value: store.fatConsumedToday, target: plan.fatGrams, unit: "g")
                        }
                    } else {
                        Text("Carbs \(store.carbsConsumedToday)g · Fat \(store.fatConsumedToday)g — log your weight in Profile for targets.")
                            .font(.caption)
                            .monospacedDigit()
                            .foregroundStyle(MorpheTheme.textMuted)
                    }
                    HStack(spacing: 12) {
                        FuelMeter(label: "Water", value: day.waterConsumed, target: targets.waterCups, unit: " cups")
                        HStack(spacing: 8) {
                            stepButton("minus", label: "Remove a cup of water", disabled: day.waterConsumed == 0) {
                                store.removeWaterCup()
                            }
                            stepButton("plus", label: "Add a cup of water", disabled: false) {
                                store.addWaterCup()
                            }
                        }
                    }
                }

                // The two doors (Lucas 2026-10-10): search and camera.
                HStack(spacing: 10) {
                    Button {
                        showSearch = true
                    } label: {
                        Label("Search food", systemImage: "magnifyingglass").frame(maxWidth: .infinity)
                    }
                    .buttonStyle(PrimaryCTAButtonStyle(accent: MorpheTheme.accent))
                    Button {
                        if MorpheIntelligence.apiKey == nil { showNeedsKey = true } else { showCamera = true }
                    } label: {
                        Label("Camera", systemImage: "camera.fill").frame(maxWidth: .infinity)
                    }
                    .buttonStyle(SecondaryCTAButtonStyle())
                }
                .disabled(store.foodCheckBusy)

                if store.foodCheckBusy {
                    HStack(spacing: 10) {
                        ProgressView()
                        Text("Reading the plate…")
                            .font(.caption)
                            .foregroundStyle(MorpheTheme.textSecondary)
                    }
                }

                Button("Enter a label by hand") { showManual = true }
                    .buttonStyle(.plain)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(MorpheTheme.accentText)
                    .frame(minHeight: 32)

                loggedToday(day.meals.filter(\.logged))
            }
        }
        .sheet(isPresented: $showSearch) {
            FoodSearchSheet()
                .environment(store)
                .presentationDetents([.large])
        }
        .sheet(isPresented: $showManual) {
            ManualMealSheet()
                .environment(store)
                .presentationDetents([.medium, .large])
        }
        .fullScreenCover(isPresented: $showCamera, onDismiss: presentPendingEstimate) {
            FoodPhotoCamera { image in
                showCamera = false
                guard let image else { return }
                Task { pendingEstimate = await store.runFoodCheck(image: image, barcode: nil); presentPendingEstimate() }
            }
            .ignoresSafeArea()
        }
        .sheet(item: $estimate) { record in
            FuelEstimateSheet(record: record)
                .environment(store)
                .presentationDetents([.large])
        }
        .alert("Photo logging needs your key", isPresented: $showNeedsKey) {
            Button("Search instead") { showSearch = true }
            Button("OK", role: .cancel) {}
        } message: {
            Text("Reading a plate runs on Claude with your own Anthropic key (Profile → Morphe Intelligence). Morphe never guesses food on its own — search the library instead.")
        }
    }

    private func presentPendingEstimate() {
        guard let record = pendingEstimate, !showCamera else { return }
        pendingEstimate = nil
        estimate = record
    }

    @ViewBuilder
    private func loggedToday(_ meals: [MealLogEntry]) -> some View {
        if meals.isEmpty {
            Text("Nothing logged yet today.")
                .font(.caption)
                .foregroundStyle(MorpheTheme.textMuted)
        } else {
            VStack(alignment: .leading, spacing: 10) {
                ForEach(MealSlot.allCases) { slot in
                    let rows = meals.filter { $0.mealType == slot.rawValue }
                    if !rows.isEmpty { mealSection(slot.rawValue, rows) }
                }
                let other = meals.filter { MealSlot(rawValue: $0.mealType) == nil }
                if !other.isEmpty { mealSection("Logged", other) }
            }
        }
    }

    private func mealSection(_ title: String, _ rows: [MealLogEntry]) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title.uppercased())
                    .font(MorpheTheme.microLabel(10))
                    .tracking(1.2)
                    .foregroundStyle(MorpheTheme.textMuted)
                Spacer()
                Text("\(rows.map(\.calories).reduce(0, +)) cal")
                    .font(MorpheTheme.microLabel(10))
                    .monospacedDigit()
                    .foregroundStyle(MorpheTheme.textMuted)
            }
            ForEach(rows) { meal in
                HStack(spacing: 8) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(meal.name)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(MorpheTheme.textPrimary)
                            .lineLimit(1)
                        Text("\(meal.calories) cal · \(meal.protein)g P · \(meal.carbs)g C · \(meal.fat)g F\(meal.source.isEmpty ? "" : " · \(meal.source)")")
                            .font(.caption)
                            .monospacedDigit()
                            .foregroundStyle(MorpheTheme.textSecondary)
                            .lineLimit(1)
                    }
                    Spacer(minLength: 8)
                    Button {
                        withAnimation(.easeIn(duration: 0.16)) { store.removeMeal(meal) }
                    } label: {
                        Image(systemName: "xmark")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(MorpheTheme.textMuted)
                            .frame(width: 44, height: 44)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Remove \(meal.name)")
                }
            }
        }
    }

    private func stepButton(_ symbol: String, label: String, disabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(disabled ? MorpheTheme.textMuted : MorpheTheme.textPrimary)
                .frame(width: 44, height: 44)
                .background(Circle().fill(MorpheTheme.panelStrong))
        }
        .buttonStyle(.plain)
        .disabled(disabled)
        .accessibilityLabel(label)
    }
}

/// Search first, recents on top, two sources side by side, a portion
/// before anything lands in the log.
struct FoodSearchSheet: View {
    @Environment(MorpheAppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""
    @State private var libraryHits: [FoodLibraryItem] = []
    @State private var productHits: [FoodSearchResult] = []
    @State private var productsUnreachable = false
    @State private var searching = false
    @State private var searchTask: Task<Void, Never>?
    @State private var chosen: FoodSearchResult?
    @State private var showManual = false
    @FocusState private var focused: Bool

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 16) {
                    HStack(spacing: 8) {
                        Image(systemName: "magnifyingglass")
                            .foregroundStyle(MorpheTheme.textMuted)
                        TextField("Chicken breast, oats, Greek yogurt…", text: $query)
                            .textFieldStyle(.plain)
                            .focused($focused)
                            .autocorrectionDisabled()
                            .submitLabel(.search)
                        if !query.isEmpty {
                            Button { query = "" } label: {
                                Image(systemName: "xmark.circle.fill").foregroundStyle(MorpheTheme.textMuted)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Clear search")
                        }
                    }
                    .padding(.horizontal, 14)
                    .frame(minHeight: 48)
                    .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(MorpheTheme.panelStrong))

                    if query.trimmingCharacters(in: .whitespaces).isEmpty {
                        if store.recentFoods.isEmpty {
                            Text("Your recent foods will sit here. The library holds 1,195 whole foods from USDA; packaged products come from Open Food Facts as you type.")
                                .font(.caption)
                                .foregroundStyle(MorpheTheme.textMuted)
                                .fixedSize(horizontal: false, vertical: true)
                        } else {
                            section("Recent", store.recentFoods.map { ($0, $0.servingGrams.map { "\($0) g last time" } ?? $0.source) })
                        }
                    } else {
                        if !libraryHits.isEmpty {
                            section("Whole foods · USDA", libraryHits.map { (FoodSearchResult(library: $0), $0.cat) })
                        }
                        if searching {
                            HStack(spacing: 8) { ProgressView(); Text("Searching products…").font(.caption).foregroundStyle(MorpheTheme.textMuted) }
                        } else if productsUnreachable {
                            Text("Couldn't reach Open Food Facts — packaged products are offline right now.")
                                .font(.caption)
                                .foregroundStyle(MorpheTheme.textMuted)
                        } else if !productHits.isEmpty {
                            section("Products · Open Food Facts", productHits.map { ($0, $0.brand.isEmpty ? "Packaged" : $0.brand) })
                        }
                        if !searching, !productsUnreachable, libraryHits.isEmpty, productHits.isEmpty, query.count >= 2 {
                            Text("Nothing by that name in the library or the product database.")
                                .font(.caption)
                                .foregroundStyle(MorpheTheme.textMuted)
                        }
                    }

                    Button("Can't find it? Enter the label by hand") { showManual = true }
                        .buttonStyle(.plain)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(MorpheTheme.accentText)
                        .frame(minHeight: 44)
                }
                .padding(20)
                .padding(.bottom, 40)
            }
            .background(PremiumBackground())
            .navigationTitle("Log food")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() } } }
            .navigationDestination(item: $chosen) { food in
                FoodPortionView(food: food) { dismiss() }
                    .environment(store)
            }
            .sheet(isPresented: $showManual) {
                ManualMealSheet()
                    .environment(store)
                    .presentationDetents([.medium, .large])
            }
        }
        .onAppear { focused = true }
        .onChange(of: query) { _, text in
            let q = text.trimmingCharacters(in: .whitespaces)
            libraryHits = FoodLibrary.search(q)
            searchTask?.cancel()
            productHits = []
            guard q.count >= 2 else { searching = false; return }
            searching = true
            productsUnreachable = false
            searchTask = Task {
                // Debounce: products are a network call (Open Food Facts
                // allows ~10 searches a minute); the library is not.
                try? await Task.sleep(for: .milliseconds(800))
                guard !Task.isCancelled else { return }
                let result = await FoodCheckService.searchProducts(q)
                guard !Task.isCancelled else { return }
                switch result {
                case .hits(let hits): productHits = hits
                case .unreachable: productsUnreachable = true
                }
                searching = false
            }
        }
    }

    private func section(_ title: String, _ rows: [(FoodSearchResult, String)]) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title.uppercased())
                .font(MorpheTheme.microLabel(10))
                .tracking(1.2)
                .foregroundStyle(MorpheTheme.textMuted)
            ForEach(rows, id: \.0.id) { food, detail in
                Button { chosen = food } label: {
                    HStack(spacing: 10) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(food.name)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(MorpheTheme.textPrimary)
                                .lineLimit(2)
                            Text(detail)
                                .font(.caption)
                                .foregroundStyle(MorpheTheme.textMuted)
                                .lineLimit(1)
                        }
                        Spacer(minLength: 8)
                        Text("\(Int(food.kcal100.rounded())) cal · \(Int(food.protein100.rounded()))g P")
                            .font(.caption)
                            .monospacedDigit()
                            .foregroundStyle(MorpheTheme.textSecondary)
                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(MorpheTheme.textMuted)
                    }
                    .frame(minHeight: 48)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(food.displayName), \(Int(food.kcal100.rounded())) calories per 100 grams")
            }
        }
    }
}

/// The hardest screen in food logging: the portion. Grams, quick chips,
/// the product's listed serving, the meal slot, and the totals live.
struct FoodPortionView: View {
    @Environment(MorpheAppStore.self) private var store
    let food: FoodSearchResult
    let onLogged: () -> Void
    @State private var grams: Int
    @State private var slot: MealSlot = .suggested

    init(food: FoodSearchResult, onLogged: @escaping () -> Void) {
        self.food = food
        self.onLogged = onLogged
        _grams = State(initialValue: food.servingGrams ?? 100)
    }

    var body: some View {
        let t = food.totals(grams: grams)
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(food.name)
                        .font(.title3.weight(.bold))
                        .foregroundStyle(MorpheTheme.textPrimary)
                    Text(food.brand.isEmpty ? food.source : "\(food.brand) · \(food.source)")
                        .font(.caption)
                        .foregroundStyle(MorpheTheme.textMuted)
                }

                Picker("Meal", selection: $slot) {
                    ForEach(MealSlot.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)

                GlassCard(.quiet) {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Portion")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(MorpheTheme.textPrimary)
                            Spacer()
                            Stepper("\(grams) g", value: $grams, in: 5...2000, step: 5)
                                .font(.subheadline.monospacedDigit())
                                .foregroundStyle(MorpheTheme.textPrimary)
                                .fixedSize()
                        }
                        WrapStack(spacing: 8) {
                            ForEach([50, 100, 150, 200, 250], id: \.self) { g in
                                Button("\(g) g") { grams = g; Haptics.selection() }
                                    .buttonStyle(FilterChipStyle(isSelected: grams == g))
                            }
                            if let serving = food.servingGrams {
                                Button(food.servingLabel ?? "Serving \(serving) g") { grams = serving; Haptics.selection() }
                                    .buttonStyle(FilterChipStyle(isSelected: grams == serving))
                            }
                        }
                    }
                }

                HStack(spacing: 8) {
                    MetricPill(label: "Calories", value: "\(t.calories)")
                    MetricPill(label: "Protein", value: "\(t.protein)g")
                    MetricPill(label: "Carbs", value: "\(t.carbs)g")
                    MetricPill(label: "Fat", value: "\(t.fat)g")
                }
                Text("Per 100 g: \(Int(food.kcal100.rounded())) cal · \(food.protein100.formatted(.number.precision(.fractionLength(0...1))))g P · \(food.carbs100.formatted(.number.precision(.fractionLength(0...1))))g C · \(food.fat100.formatted(.number.precision(.fractionLength(0...1))))g F — \(food.source).")
                    .font(.caption)
                    .foregroundStyle(MorpheTheme.textMuted)
                    .fixedSize(horizontal: false, vertical: true)

                Button("Add \(grams) g to \(slot.rawValue.lowercased())") {
                    if store.logFood(food, grams: grams, slot: slot) {
                        Haptics.success()
                        onLogged()
                    }
                }
                .buttonStyle(PrimaryCTAButtonStyle(accent: MorpheTheme.accent))
            }
            .padding(20)
            .padding(.bottom, 40)
        }
        .background(PremiumBackground())
        .navigationTitle("Portion")
        .navigationBarTitleDisplayMode(.inline)
    }
}

/// A label typed by hand — the honest fallback when neither source has it.
struct ManualMealSheet: View {
    @Environment(MorpheAppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var calories = ""
    @State private var protein = ""
    @State private var carbs = ""
    @State private var fat = ""
    @State private var slot: MealSlot = .suggested
    @FocusState private var focused: Bool

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 12) {
                    Picker("Meal", selection: $slot) {
                        ForEach(MealSlot.allCases) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    TextField("What you ate", text: $name)
                        .textFieldStyle(MorpheFieldStyle())
                        .focused($focused)
                    HStack(spacing: 8) {
                        TextField("Calories", text: $calories).textFieldStyle(MorpheFieldStyle()).keyboardType(.numberPad)
                        TextField("Protein g", text: $protein).textFieldStyle(MorpheFieldStyle()).keyboardType(.numberPad)
                    }
                    HStack(spacing: 8) {
                        TextField("Carbs g", text: $carbs).textFieldStyle(MorpheFieldStyle()).keyboardType(.numberPad)
                        TextField("Fat g", text: $fat).textFieldStyle(MorpheFieldStyle()).keyboardType(.numberPad)
                    }
                    Button("Add to \(slot.rawValue.lowercased())") {
                        if store.addManualMeal(name: name, slot: slot, calories: Int(calories) ?? 0, protein: Int(protein) ?? 0,
                                               carbs: Int(carbs) ?? 0, fat: Int(fat) ?? 0) {
                            Haptics.success()
                            dismiss()
                        }
                    }
                    .buttonStyle(PrimaryCTAButtonStyle(accent: MorpheTheme.accent))
                    Text("Copy the numbers from the label. Morphe doesn't fill in what you don't type.")
                        .font(.caption)
                        .foregroundStyle(MorpheTheme.textMuted)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(20)
            }
            .background(PremiumBackground())
            .navigationTitle("Enter a label")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Cancel") { dismiss() } } }
        }
        .onAppear { focused = true }
    }
}

/// A photo's numbers, as a draft: labelled estimate, scaled by the
/// user, one tap from the full origin/processing report.
struct FuelEstimateSheet: View {
    @Environment(MorpheAppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let record: FoodCheckRecord
    @State private var multiplier = 1.0
    @State private var slot: MealSlot = .suggested
    @State private var showReport = false

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(record.displayName.isEmpty ? "Your plate" : record.displayName)
                            .font(.title3.weight(.bold))
                            .foregroundStyle(MorpheTheme.textPrimary)
                        HStack(spacing: 8) {
                            FoodProcessingBadge(processing: record.processing)
                            Text("ESTIMATE")
                                .font(MorpheTheme.microLabel(11).weight(.bold)).tracking(1.0)
                                .foregroundStyle(MorpheTheme.textPrimary)
                                .padding(.horizontal, 10).padding(.vertical, 6)
                                .background(Capsule().fill(MorpheTheme.panelStrong))
                        }
                        Text("Photo estimates tend to run low on mixed and fatty plates — an NIH metabolic-kitchen study (2026) found the leading photo apps under-counted calories by 250–345 per meal. Adjust the portion if the plate was bigger than it looks.")
                            .font(.caption)
                            .foregroundStyle(MorpheTheme.textMuted)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Picker("Meal", selection: $slot) {
                        ForEach(MealSlot.allCases) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.segmented)

                    GlassCard(.quiet) {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text("Portion")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(MorpheTheme.textPrimary)
                                Spacer()
                                Stepper("×\(multiplier.formatted(.number.precision(.fractionLength(0...2))))", value: $multiplier, in: 0.25...4, step: 0.25)
                                    .font(.subheadline.monospacedDigit())
                                    .foregroundStyle(MorpheTheme.textPrimary)
                                    .fixedSize()
                            }
                            HStack(spacing: 8) {
                                MetricPill(label: "Calories", value: scaled(record.calories))
                                MetricPill(label: "Protein", value: scaled(record.protein) + "g")
                                MetricPill(label: "Carbs", value: scaled(record.carbs) + "g")
                                MetricPill(label: "Fat", value: scaled(record.fat) + "g")
                            }
                            if !record.servingNote.isEmpty {
                                Text(record.servingNote)
                                    .font(.caption)
                                    .foregroundStyle(MorpheTheme.textMuted)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }

                    Button("Add to \(slot.rawValue.lowercased())") {
                        if store.logFoodCheckToFuel(record, multiplier: multiplier, slot: slot) {
                            Haptics.success()
                            dismiss()
                        }
                    }
                    .buttonStyle(PrimaryCTAButtonStyle(accent: MorpheTheme.accent))
                    .disabled(record.calories == nil && record.protein == nil)

                    Button("Full report — origin, processing, additives") { showReport = true }
                        .buttonStyle(SecondaryCTAButtonStyle())
                }
                .padding(20)
                .padding(.bottom, 40)
            }
            .background(PremiumBackground())
            .navigationTitle("From the photo")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Close") { dismiss() } } }
            .sheet(isPresented: $showReport) {
                FoodCheckReportSheet(record: record)
                    .environment(store)
                    .presentationDetents([.large])
            }
        }
    }

    private func scaled(_ value: Int?) -> String {
        guard let value else { return "—" }
        return "\(Int((Double(value) * multiplier).rounded()))"
    }
}

private struct FuelMeter: View {
    let label: String
    let value: Int
    let target: Int
    let unit: String

    private var fraction: Double {
        target > 0 ? min(Double(value) / Double(target), 1) : 0
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text(label)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(MorpheTheme.textPrimary)
                Spacer(minLength: 8)
                Text("\(value.formatted()) of \(target.formatted())\(unit)")
                    .font(.subheadline)
                    .monospacedDigit()
                    .contentTransition(.numericText(value: Double(value)))
                    .foregroundStyle(MorpheTheme.textSecondary)
            }
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(MorpheTheme.strokeSubtle)
                    Capsule()
                        .fill(MorpheTheme.accent)
                        .frame(width: proxy.size.width * fraction)
                }
            }
            .frame(height: 4)
            .animation(.easeOut(duration: 0.2), value: value)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(label): \(value) of \(target)\(unit)")
    }
}

// MARK: - From Coaches (2026-10-05)

/// Notes published by Creator Coaches, newest first. Each one can be
/// reported; the author's name is always on it.
struct CoachNotesCard: View {
    @Environment(MorpheAppStore.self) private var store
    @State private var expanded: Set<String> = []
    @State private var reporting: CreatorNote?

    var body: some View {
        let notes = store.creatorNotes
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("From Coaches")
                    .font(.headline)
                    .foregroundStyle(MorpheTheme.textPrimary)
                if notes.isEmpty {
                    Text(store.authUser == nil
                         ? "Sign in to read notes from Creator Coaches."
                         : "Nothing published yet. Notes from approved Creator Coaches land here.")
                        .font(.caption)
                        .foregroundStyle(MorpheTheme.textMuted)
                } else {
                    ForEach(notes.prefix(20)) { note in
                        VStack(alignment: .leading, spacing: 6) {
                            Text(note.title)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(MorpheTheme.textPrimary)
                            Text("\(note.authorName)\(note.authorHandle.isEmpty ? "" : " · @\(note.authorHandle)") · \(note.createdAt.formatted(date: .abbreviated, time: .omitted))")
                                .font(.caption)
                                .foregroundStyle(MorpheTheme.textMuted)
                            Text(note.body)
                                .font(.subheadline)
                                .foregroundStyle(MorpheTheme.textSecondary)
                                .lineLimit(expanded.contains(note.id) ? nil : 3)
                                .fixedSize(horizontal: false, vertical: true)
                            HStack(spacing: 14) {
                                if note.body.count > 160 {
                                    Button(expanded.contains(note.id) ? "Less" : "Read more") {
                                        if expanded.contains(note.id) { expanded.remove(note.id) } else { expanded.insert(note.id) }
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
                        .padding(.vertical, 4)
                        Divider().overlay(MorpheTheme.strokeSubtle)
                    }
                }
            }
        }
        .task { await store.refreshCreatorContent() }
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
    }
}


/// The whiteboard chart (Lucas 2026-10-09) as a goal picker, a macro bar,
/// and the five food columns. Numbers come from the user's logged weight
/// through NutritionPlan; without a weight the card shows the method and
/// says so.
struct NutritionChartCard: View {
    @Environment(MorpheAppStore.self) private var store
    @State private var goal: NutritionGoalMode?

    private var shownGoal: NutritionGoalMode { goal ?? store.nutritionGoalMode }

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .firstTextBaseline) {
                    Text("The Chart")
                        .font(.headline)
                        .foregroundStyle(MorpheTheme.textPrimary)
                    Spacer()
                    Text("4 · 4 · 9 CAL/G")
                        .font(MorpheTheme.microLabel(10))
                        .tracking(1.2)
                        .foregroundStyle(MorpheTheme.textMuted)
                }

                Picker("Goal", selection: Binding(
                    get: { shownGoal },
                    set: { goal = $0; Haptics.selection() }
                )) {
                    ForEach(NutritionGoalMode.allCases) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.segmented)

                if let plan = store.nutritionPlan(for: shownGoal) {
                    HStack(spacing: 8) {
                        MetricPill(label: "Calories", value: "\(plan.calories)")
                        MetricPill(label: "Carbs", value: "\(plan.carbGrams)g")
                        MetricPill(label: "Protein", value: "\(plan.proteinGrams)g")
                        MetricPill(label: "Fat", value: "\(plan.fatGrams)g")
                    }
                    Button {
                        store.toggleSavedDietPlan(shownGoal)
                        Haptics.impact(.light)
                    } label: {
                        Label(store.savedDietPlanModes.contains(shownGoal.rawValue) ? "Saved to your library" : "Save this plan",
                              systemImage: store.savedDietPlanModes.contains(shownGoal.rawValue) ? "bookmark.fill" : "bookmark")
                            .font(.caption.weight(.semibold))
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(MorpheTheme.accentText)
                    .frame(minHeight: 32)
                    Text("Body weight \(plan.weightLb) lb × \(shownGoal.caloriesPerLb.formatted()) · split \(shownGoal.splitLabel)\(plan.proteinFloorApplied ? " · protein held at the 0.85 g/lb floor" : "")")
                        .font(.caption)
                        .foregroundStyle(MorpheTheme.textMuted)
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    Text("Body weight × \(shownGoal.caloriesPerLb.formatted()) calories · split \(shownGoal.splitLabel). Log your weight in Profile for the grams.")
                        .font(.caption)
                        .foregroundStyle(MorpheTheme.textMuted)
                        .fixedSize(horizontal: false, vertical: true)
                }

                macroBar

                Text(shownGoal.rule)
                    .font(.subheadline)
                    .foregroundStyle(MorpheTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                Rectangle().fill(MorpheTheme.strokeSubtle).frame(height: 1)

                // The five columns, in the order this goal leans on them.
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(Array(shownGoal.leanOn.enumerated()), id: \.element.id) { index, group in
                        foodColumn(group, rank: index + 1)
                    }
                }
                .animation(.easeInOut(duration: 0.2), value: shownGoal)

                Text("From the founder's whiteboard. A method, not medical advice.")
                    .font(.caption2)
                    .foregroundStyle(MorpheTheme.textMuted)
            }
        }
        .accessibilityElement(children: .contain)
    }

    /// Carbs / protein / fat as one bar — the diagram.
    private var macroBar: some View {
        let split = shownGoal.split
        return VStack(alignment: .leading, spacing: 6) {
            GeometryReader { geo in
                HStack(spacing: 2) {
                    segment(width: geo.size.width * CGFloat(split.carbs) / 100, color: MorpheTheme.accent, label: "C \(split.carbs)%")
                    segment(width: geo.size.width * CGFloat(split.protein) / 100, color: MorpheTheme.accentAlt, label: "P \(split.protein)%")
                    segment(width: geo.size.width * CGFloat(split.fat) / 100, color: MorpheTheme.textMuted.opacity(0.6), label: "F \(split.fat)%")
                }
            }
            .frame(height: 28)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .animation(.spring(response: 0.4, dampingFraction: 0.85), value: shownGoal)
            .accessibilityLabel("Carbs \(split.carbs) percent, protein \(split.protein) percent, fat \(split.fat) percent")
        }
    }

    private func segment(width: CGFloat, color: Color, label: String) -> some View {
        ZStack {
            Rectangle().fill(color)
            Text(label)
                .font(.system(.caption2, design: .monospaced).weight(.semibold))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
        .frame(width: max(width - 2, 0))
    }

    private func foodColumn(_ group: NutritionFoodGroup, rank: Int) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Text("\(rank)")
                    .font(.system(.caption2, design: .monospaced).weight(.bold))
                    .foregroundStyle(MorpheTheme.accentText)
                    .frame(width: 16, height: 16)
                    .background(Circle().fill(MorpheTheme.accent.opacity(0.15)))
                Text(group.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(MorpheTheme.textPrimary)
                Text("\(group.caloriesPerGram) cal/g")
                    .font(.caption2)
                    .foregroundStyle(MorpheTheme.textMuted)
            }
            Text(group.whenToUse)
                .font(.caption)
                .foregroundStyle(MorpheTheme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
            Text(group.foods.joined(separator: " · "))
                .font(.caption)
                .foregroundStyle(MorpheTheme.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}


// MARK: - Food check (Lucas 2026-10-10)

/// Scan a barcode or photograph a meal; the report says where it comes
/// from, how it's processed, what's in it, and how sure each line is.
struct FoodCheckCard: View {
    @Environment(MorpheAppStore.self) private var store
    @State private var showScanner = false
    @State private var showCamera = false
    @State private var showPhotoNeedsKey = false
    @State private var selected: FoodCheckRecord?
    /// A report found while a scanner/camera sheet is still dismissing
    /// waits here and presents from onDismiss (audit 2026-10-10).
    @State private var pendingReport: FoodCheckRecord?

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 14) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Check a Food")
                        .font(.headline)
                        .foregroundStyle(MorpheTheme.textPrimary)
                        .featureGlimmer()
                    Text(MorpheIntelligence.apiKey == nil
                         ? "Scan a barcode for the label facts: origin, processing, additives, GMO read. Add your own key in Profile → Morphe Intelligence and Morphe reads a meal from a photo and searches the web for the supply chain."
                         : "Scan a barcode or photograph a meal. Morphe reads the label, searches the web for the brand's supply chain, and reports with sources. The photo leaves the phone only for this check.")
                        .font(.caption)
                        .foregroundStyle(MorpheTheme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                HStack(spacing: 10) {
                    Button {
                        showScanner = true
                    } label: {
                        Label("Scan barcode", systemImage: "barcode.viewfinder").frame(maxWidth: .infinity)
                    }
                    .buttonStyle(PrimaryCTAButtonStyle(accent: MorpheTheme.accent))
                    Button {
                        // Ask before the camera (fix wave 2026-10-13): the photo
                        // path needs the user's key; shooting first wasted it.
                        if MorpheIntelligence.apiKey == nil { showPhotoNeedsKey = true } else { showCamera = true }
                    } label: {
                        Label("Photo", systemImage: "camera.fill").frame(maxWidth: .infinity)
                    }
                    .buttonStyle(SecondaryCTAButtonStyle())
                }
                .disabled(store.foodCheckBusy)

                if store.foodCheckBusy {
                    HStack(spacing: 10) {
                        ProgressView()
                        Text(MorpheIntelligence.apiKey == nil ? "Reading the database…" : "Reading the label and searching the web…")
                            .font(.caption)
                            .foregroundStyle(MorpheTheme.textSecondary)
                    }
                }

                if !store.foodChecks.isEmpty {
                    Rectangle().fill(MorpheTheme.strokeSubtle).frame(height: 1)
                    VStack(alignment: .leading, spacing: 8) {
                        Text("RECENT")
                            .font(MorpheTheme.microLabel(10))
                            .tracking(1.2)
                            .foregroundStyle(MorpheTheme.textMuted)
                        ForEach(store.foodChecks.prefix(6)) { record in
                            Button { selected = record } label: {
                                HStack(spacing: 10) {
                                    FoodProcessingBadge(processing: record.processing, compact: true)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(record.displayName)
                                            .font(.subheadline.weight(.semibold))
                                            .foregroundStyle(MorpheTheme.textPrimary)
                                            .lineLimit(1)
                                        Text(record.verdict.isEmpty ? record.origin : record.verdict)
                                            .font(.caption)
                                            .foregroundStyle(MorpheTheme.textSecondary)
                                            .lineLimit(1)
                                    }
                                    Spacer()
                                    if let score = record.nutriScore {
                                        Text(score)
                                            .font(.caption.weight(.bold))
                                            .foregroundStyle(MorpheTheme.textPrimary)
                                            .frame(width: 24, height: 24)
                                            .background(Circle().fill(FoodCheckReportSheet.scoreColor(score).opacity(0.25)))
                                    }
                                    Image(systemName: "chevron.right")
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(MorpheTheme.textMuted)
                                }
                                .frame(minHeight: 44)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    if let memory = store.foodMemorySummary {
                        Text(memory)
                            .font(.caption)
                            .foregroundStyle(MorpheTheme.textMuted)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
        .alert("Meal photos need your key", isPresented: $showPhotoNeedsKey) {
            Button("Scan a barcode instead") { showScanner = true }
            Button("OK", role: .cancel) {}
        } message: {
            Text("Reading a plate runs on Claude with your own Anthropic key (Profile → Morphe Intelligence). Barcodes work without one.")
        }
        .sheet(isPresented: $showScanner, onDismiss: presentPending) {
            FoodBarcodeSheet { code in
                guard FoodCheckService.lookupCode(from: code) != nil else { return }
                showScanner = false
                Task { pendingReport = await store.runFoodCheck(image: nil, barcode: code); presentPending() }
            }
            .environment(store)
            .presentationDetents([.medium, .large])
        }
        .fullScreenCover(isPresented: $showCamera, onDismiss: presentPending) {
            FoodPhotoCamera { image in
                showCamera = false
                guard let image else { return }
                Task { pendingReport = await store.runFoodCheck(image: image, barcode: nil); presentPending() }
            }
            .ignoresSafeArea()
        }
        .sheet(item: $selected) { record in
            FoodCheckReportSheet(record: record)
                .environment(store)
                .presentationDetents([.large])
        }
    }

    /// Presents once nothing else is presented: the check can finish
    /// before the scanner's dismiss animation does.
    private func presentPending() {
        guard let record = pendingReport, !showScanner, !showCamera else { return }
        pendingReport = nil
        selected = record
    }
}

struct FoodProcessingBadge: View {
    let processing: FoodProcessingClass
    var compact = false

    private var color: Color {
        switch processing {
        case .wholeFood: return Color(red: 0.20, green: 0.70, blue: 0.40)
        case .kitchenIngredient: return MorpheTheme.accent
        case .processed: return Color(red: 0.95, green: 0.65, blue: 0.20)
        case .ultraProcessed: return MorpheTheme.danger
        case .unknown: return MorpheTheme.textMuted
        }
    }

    private var symbol: String {
        switch processing {
        case .wholeFood: return "leaf.fill"
        case .kitchenIngredient: return "drop.fill"
        case .processed: return "square.stack.3d.up.fill"
        case .ultraProcessed: return "exclamationmark.triangle.fill"
        case .unknown: return "questionmark"
        }
    }

    var body: some View {
        if compact {
            Image(systemName: symbol)
                .font(.caption.weight(.bold))
                .foregroundStyle(color)
                .frame(width: 28, height: 28)
                .background(Circle().fill(color.opacity(0.15)))
                .accessibilityLabel(processing.title)
        } else {
            HStack(spacing: 6) {
                Image(systemName: symbol)
                Text(processing.title.uppercased())
                    .tracking(1.0)
            }
            .font(MorpheTheme.microLabel(11).weight(.bold))
            .foregroundStyle(color)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Capsule().fill(color.opacity(0.14)))
        }
    }
}

/// Retail barcodes (EAN-13/8, UPC-E, Code 128) plus QR for the camera.
private struct FoodBarcodeSheet: View {
    let onScan: (String) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                QRScannerView(onScan: onScan, symbologies: [.ean13, .ean8, .upce, .code128, .qr])
                    .clipShape(RoundedRectangle(cornerRadius: MorpheTheme.radius, style: .continuous))
                Text(MorpheIntelligence.apiKey == nil
                     ? "Point at the barcode on the package. Only the number is sent — to Open Food Facts, a public product database."
                     : "Point at the barcode on the package. The number goes to Open Food Facts, and with your key the label facts go to Anthropic for the web read.")
                    .font(.caption)
                    .foregroundStyle(MorpheTheme.textSecondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(16)
            .background(PremiumBackground())
            .navigationTitle("Scan a barcode")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Close") { dismiss() } } }
        }
    }
}

private struct FoodPhotoCamera: UIViewControllerRepresentable {
    let onCapture: (UIImage?) -> Void

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        if UIImagePickerController.isSourceTypeAvailable(.camera) { picker.sourceType = .camera }
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ controller: UIImagePickerController, context: Context) {}
    func makeCoordinator() -> Coordinator { Coordinator(onCapture: onCapture) }

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let onCapture: (UIImage?) -> Void
        init(onCapture: @escaping (UIImage?) -> Void) { self.onCapture = onCapture }
        func imagePickerController(_ picker: UIImagePickerController,
                                   didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            onCapture(info[.originalImage] as? UIImage)
        }
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) { onCapture(nil) }
    }
}

/// The report: every section says how sure it is and where it came from.
struct FoodCheckReportSheet: View {
    @Environment(MorpheAppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let record: FoodCheckRecord
    @State private var logged = false
    /// Portion for per-100 g label numbers.
    @State private var grams = 100

    static func scoreColor(_ score: String) -> Color {
        switch score {
        case "A": return Color(red: 0.05, green: 0.60, blue: 0.30)
        case "B": return Color(red: 0.45, green: 0.72, blue: 0.20)
        case "C": return Color(red: 0.95, green: 0.75, blue: 0.10)
        case "D": return Color(red: 0.95, green: 0.50, blue: 0.15)
        default: return MorpheTheme.danger
        }
    }

    private var current: FoodCheckRecord {
        store.foodChecks.first { $0.id == record.id } ?? record
    }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 16) {
                    // Headline
                    VStack(alignment: .leading, spacing: 8) {
                        Text(current.displayName)
                            .font(.title3.weight(.bold))
                            .foregroundStyle(MorpheTheme.textPrimary)
                        HStack(spacing: 8) {
                            FoodProcessingBadge(processing: current.processing)
                            if let score = current.nutriScore {
                                Text("NUTRI-SCORE \(score)")
                                    .font(MorpheTheme.microLabel(11).weight(.bold))
                                    .tracking(1.0)
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 10).padding(.vertical, 6)
                                    .background(Capsule().fill(Self.scoreColor(score)))
                            }
                        }
                        if !current.verdict.isEmpty {
                            Text(current.verdict)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(MorpheTheme.textPrimary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        Text(methodLine)
                            .font(.caption)
                            .foregroundStyle(MorpheTheme.textMuted)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    section("Real or processed", current.processingReason.isEmpty ? current.processing.title : current.processingReason)
                    section("Where it comes from", current.origin, confidence: current.originConfidence)
                    section("How healthy", current.healthRead)
                    section("GMO", current.gmoRead, confidence: current.gmoLikelihood, confidenceLabel: gmoLabel)

                    // Additives
                    GlassCard(.quiet) {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("ADDITIVES")
                                .font(MorpheTheme.microLabel(10)).tracking(1.2)
                                .foregroundStyle(MorpheTheme.textMuted)
                            if current.additives.isEmpty {
                                Text(current.ingredients.isEmpty ? "No ingredient list on file." : "None listed.")
                                    .font(.subheadline)
                                    .foregroundStyle(MorpheTheme.textSecondary)
                            } else {
                                ForEach(current.additives) { additive in
                                    HStack(alignment: .top, spacing: 10) {
                                        Circle().fill(concernColor(additive.concern)).frame(width: 8, height: 8).padding(.top, 6)
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text("\(additive.name)  ·  \(additive.code)")
                                                .font(.subheadline.weight(.semibold))
                                                .foregroundStyle(MorpheTheme.textPrimary)
                                            Text(additive.note)
                                                .font(.caption)
                                                .foregroundStyle(MorpheTheme.textSecondary)
                                                .fixedSize(horizontal: false, vertical: true)
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // Numbers
                    GlassCard(.quiet) {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("NUMBERS")
                                .font(MorpheTheme.microLabel(10)).tracking(1.2)
                                .foregroundStyle(MorpheTheme.textMuted)
                            if current.calories == nil && current.protein == nil {
                                Text("No numbers on file for this one.")
                                    .font(.subheadline)
                                    .foregroundStyle(MorpheTheme.textSecondary)
                            } else {
                                HStack(spacing: 8) {
                                    MetricPill(label: "Calories", value: current.calories.map { "\($0)" } ?? "—")
                                    MetricPill(label: "Protein", value: current.protein.map { "\($0)g" } ?? "—")
                                    MetricPill(label: "Carbs", value: current.carbs.map { "\($0)g" } ?? "—")
                                    MetricPill(label: "Fat", value: current.fat.map { "\($0)g" } ?? "—")
                                }
                                HStack(spacing: 8) {
                                    MetricPill(label: "Sugar", value: current.sugar.map { "\($0)g" } ?? "—")
                                    MetricPill(label: "Fibre", value: current.fiber.map { "\($0)g" } ?? "—")
                                    MetricPill(label: "Sodium", value: current.sodiumMg.map { "\($0)mg" } ?? "—")
                                }
                            }
                            if !current.servingNote.isEmpty {
                                Text(current.servingNote)
                                    .font(.caption)
                                    .foregroundStyle(MorpheTheme.textMuted)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }

                    if !current.ingredients.isEmpty {
                        section("Ingredients", current.ingredients)
                    }

                    if !current.sources.isEmpty {
                        GlassCard(.quiet) {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("SOURCES")
                                    .font(MorpheTheme.microLabel(10)).tracking(1.2)
                                    .foregroundStyle(MorpheTheme.textMuted)
                                ForEach(current.sources) { source in
                                    if let url = URL(string: source.url) {
                                        Link(destination: url) {
                                            HStack(spacing: 6) {
                                                Image(systemName: "link")
                                                Text(source.title).lineLimit(2)
                                            }
                                            .font(.caption)
                                            .foregroundStyle(MorpheTheme.accentText)
                                            .frame(minHeight: 32, alignment: .leading)
                                        }
                                    }
                                }
                            }
                        }
                    }

                    if current.isPer100g, !(current.isLogged || logged), current.calories != nil || current.protein != nil {
                        // Label numbers are per 100 g — the portion is the
                        // user's call, never Morphe's guess.
                        HStack {
                            Text("Portion")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(MorpheTheme.textPrimary)
                            Spacer()
                            Stepper("\(grams) g", value: $grams, in: 10...1000, step: 10)
                                .font(.subheadline)
                                .foregroundStyle(MorpheTheme.textPrimary)
                                .fixedSize()
                        }
                        Text("That's about \(Int((Double(current.calories ?? 0) * Double(grams) / 100).rounded())) calories and \(Int((Double(current.protein ?? 0) * Double(grams) / 100).rounded())) g protein.")
                            .font(.caption)
                            .foregroundStyle(MorpheTheme.textMuted)
                    }

                    Button(current.isLogged || logged ? "In today's fuel" : (current.isPer100g ? "Add \(grams) g to today's fuel" : "Add to today's fuel")) {
                        if store.logFoodCheckToFuel(current, grams: current.isPer100g ? grams : nil) {
                            logged = true
                            Haptics.success()
                        }
                    }
                    .buttonStyle(PrimaryCTAButtonStyle(accent: MorpheTheme.accent))
                    .disabled(current.isLogged || logged || (current.calories == nil && current.protein == nil))

                    Button("Delete this check", role: .destructive) {
                        store.deleteFoodCheck(current)
                        dismiss()
                    }
                    .buttonStyle(.plain)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(MorpheTheme.danger)
                    .frame(maxWidth: .infinity, minHeight: 44)

                    Text("A read, not medical advice. Numbers from a photo are estimates; numbers from a barcode are the label as recorded by Open Food Facts.")
                        .font(.caption2)
                        .foregroundStyle(MorpheTheme.textMuted)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(20)
                .padding(.bottom, 40)
            }
            .background(PremiumBackground())
            .navigationTitle("Food check")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() } } }
        }
    }

    private var methodLine: String {
        var parts: [String] = []
        switch current.method {
        case .barcode: parts.append("From the barcode")
        case .photo: parts.append("From a photo")
        case .photoAndBarcode: parts.append("From a photo and the barcode")
        }
        if current.usedWebSearch { parts.append("web sources read") }
        parts.append(current.date.formatted(date: .abbreviated, time: .shortened))
        return parts.joined(separator: " · ")
    }

    private var gmoLabel: String {
        switch current.gmoLikelihood {
        case .high: return "LIKELY"
        case .medium: return "POSSIBLE"
        case .low: return "UNLIKELY"
        case .unknown: return "UNKNOWN"
        }
    }

    private func concernColor(_ concern: FoodAdditiveConcern) -> Color {
        switch concern {
        case .none: return Color(red: 0.20, green: 0.70, blue: 0.40)
        case .low: return MorpheTheme.accent
        case .moderate: return Color(red: 0.95, green: 0.65, blue: 0.20)
        case .high: return MorpheTheme.danger
        case .unknown: return MorpheTheme.textMuted
        }
    }

    private func section(_ title: String, _ body: String, confidence: FoodConfidence? = nil, confidenceLabel: String? = nil) -> some View {
        GlassCard(.quiet) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(title.uppercased())
                        .font(MorpheTheme.microLabel(10)).tracking(1.2)
                        .foregroundStyle(MorpheTheme.textMuted)
                    Spacer()
                    if let confidence {
                        Text(confidenceLabel ?? "\(confidence.rawValue.uppercased()) CONFIDENCE")
                            .font(MorpheTheme.microLabel(9)).tracking(1.0)
                            .foregroundStyle(confidence == .high ? MorpheTheme.accentText : MorpheTheme.textMuted)
                    }
                }
                Text(body.isEmpty ? "Unknown." : body)
                    .font(.subheadline)
                    .foregroundStyle(MorpheTheme.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
