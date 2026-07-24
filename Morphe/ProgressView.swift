import Charts
import SwiftUI

// Named ProgressScreenView (not ProgressView) so it can't shadow SwiftUI's
// ProgressView spinner — the shadowing silently embedded this entire dashboard
// wherever a plain loading spinner was intended (onboarding, auth).
struct ProgressScreenView: View {
    @Environment(MorpheAppStore.self) private var store
    @State private var showCompete = false

    private var athleteReport: AthleteReport? {
        store.clientAthleteProfile?.reportCard
    }

    private var compliance: ProgramCompliance? {
        store.clientAthleteProfile?.programCompliance
    }

    private var logSummary: WorkoutLogSummary {
        store.currentAthleteWorkoutSummary
    }

    private var currentLogs: [WorkoutLog] {
        store.currentAthleteWorkoutLogs
    }

    /// Which of the last 7 days had a logged workout — shown as plain
    /// trained/rested days instead of a fake-looking score curve.
    private var last7TrainingDays: [TrainedDay] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE"
        return (0..<7).reversed().map { offset in
            let day = calendar.date(byAdding: .day, value: -offset, to: today) ?? today
            let trained = currentLogs.contains { calendar.isDate($0.completedAt, inSameDayAs: day) }
            return TrainedDay(label: formatter.string(from: day), trained: trained)
        }
    }

    private var partnerInsight: PartnerTrainingInsight {
        store.currentAthletePartnerTrainingInsight
    }

    private var sessionMixInsight: SessionMixInsightData {
        let resolvedLogs = currentLogs.map { log in
            (
                category: resolvedCategory(for: log),
                sessionType: resolvedSessionType(for: log)
            )
        }

        let categoryCounts = Dictionary(grouping: resolvedLogs, by: \.category)
            .map { SessionMixBucket(category: $0.key, count: $0.value.count) }
            .sorted { lhs, rhs in
                if lhs.count == rhs.count {
                    return lhs.category.rawValue < rhs.category.rawValue
                }
                return lhs.count > rhs.count
            }

        let sessionTypeCounts = Dictionary(grouping: resolvedLogs, by: \.sessionType)
            .map { ($0.key, $0.value.count) }
            .sorted { lhs, rhs in
                if lhs.1 == rhs.1 {
                    return lhs.0.rawValue < rhs.0.rawValue
                }
                return lhs.1 > rhs.1
            }

        let topCategory = categoryCounts.first?.category
        let topSessionType = sessionTypeCounts.first?.0

        let summary: String
        if let topCategory, let topSessionType {
            summary = "\(topCategory.rawValue) is showing up most often, usually through \(topSessionType.rawValue.lowercased()) sessions."
        } else {
            summary = "As more workouts land here, Morphe will start showing the session mix that is actually shaping your progress."
        }

        return SessionMixInsightData(
            categoryBuckets: Array(categoryCounts.prefix(4)),
            dominantCategory: topCategory,
            dominantSessionType: topSessionType,
            summary: summary
        )
    }

    private var soloBuddyTrend: [SoloBuddyTrendPoint] {
        store.currentAthleteSoloBuddyTrend
    }

    private var soloBuddyTrendSummary: String {
        store.currentAthleteSoloBuddyTrendSummary
    }

    private var athletePatternInsights: [AthletePatternInsight] {
        store.athletePatternInsights
    }

    private var sourceTrendInsight: SourceTrendInsightData {
        let calendar = Calendar.current
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"

        let weekBuckets = Dictionary(grouping: currentLogs) { log -> Date in
            let components = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: log.completedAt)
            return calendar.date(from: components) ?? log.completedAt
        }

        let points = weekBuckets.keys
            .sorted()
            .suffix(4)
            .map { startOfWeek in
                let logs = weekBuckets[startOfWeek] ?? []
                return SourceTrendPoint(
                    week: formatter.string(from: startOfWeek),
                    athleteCount: logs.filter { $0.source == .athleteManual }.count,
                    coachCount: logs.filter { $0.source == .coachManual }.count,
                    aiCount: logs.filter { $0.source == .aiPhotoParsed }.count,
                    buddyCount: logs.filter { $0.source == .partnerShared }.count
                )
            }

        let latestPoint = points.last
        let summary: String

        if let latestPoint {
            let dominant = [
                ("You", latestPoint.athleteCount),
                ("Coach", latestPoint.coachCount),
                ("AI", latestPoint.aiCount),
                ("Buddy", latestPoint.buddyCount)
            ]
            .max { lhs, rhs in
                if lhs.1 == rhs.1 {
                    return lhs.0 < rhs.0
                }
                return lhs.1 < rhs.1
            }?.0 ?? "You"

            summary = "Most recent logging momentum came mainly from \(dominant.lowercased()) entries."
        } else {
            summary = "As weekly logs build up, Morphe will show who is carrying the record-keeping most often."
        }

        return SourceTrendInsightData(points: points, summary: summary)
    }

    private var trainingPatternInsight: TrainingPatternInsightData {
        let logs = currentLogs
        let calendar = Calendar.current
        let totalMinutes = logs.reduce(0) { $0 + $1.durationMinutes }
        let averageDuration = logs.isEmpty ? 0 : totalMinutes / logs.count
        let sessionsLast30Days = logs.filter {
            guard let days = calendar.dateComponents([.day], from: $0.completedAt, to: .now).day else {
                return false
            }
            return days <= 30
        }.count
        let longestSession = logs.max { $0.durationMinutes < $1.durationMinutes }
        let topExercise = Dictionary(grouping: logs.flatMap(\.exercises), by: \.name)
            .max { lhs, rhs in
                if lhs.value.count == rhs.value.count {
                    return lhs.key < rhs.key
                }
                return lhs.value.count < rhs.value.count
            }?.key

        let dominantSource = [
            ("You", logSummary.athleteEntries),
            ("Coach", logSummary.coachEntries),
            ("AI", logSummary.aiEntries),
            ("Buddy", logSummary.partnerEntries)
        ]
        .max { lhs, rhs in
            if lhs.1 == rhs.1 {
                return lhs.0 < rhs.0
            }
            return lhs.1 < rhs.1
        }?.0 ?? "You"

        return TrainingPatternInsightData(
            minutesThisWeek: logSummary.minutesThisWeek,
            totalMinutesLogged: totalMinutes,
            sessionsLast30Days: sessionsLast30Days,
            averageDuration: averageDuration,
            longestSessionTitle: longestSession?.workoutTitle ?? "No long session yet",
            longestSessionMinutes: longestSession?.durationMinutes ?? 0,
            topExercises: logSummary.topExercises.isEmpty
                ? [topExercise].compactMap { $0 }
                : logSummary.topExercises,
            dominantSourceLabel: dominantSource
        )
    }

    private var recoveryBalanceInsight: RecoveryBalanceInsightData {
        let calendar = Calendar.current
        let recentLogs = currentLogs.filter {
            guard let days = calendar.dateComponents([.day], from: $0.completedAt, to: .now).day else {
                return false
            }
            return days <= 30
        }

        let recoveryFriendly = recentLogs.filter(isRecoveryFriendly)
        let highOutput = recentLogs.filter(isHighOutput)
        let steadyMiddle = max(recentLogs.count - recoveryFriendly.count - highOutput.count, 0)

        let summary: String
        if recoveryFriendly.count == 0 && highOutput.count > 0 {
            summary = "The last month has leaned hard toward output. One or two lighter sessions could make the next block easier to sustain."
        } else if recoveryFriendly.count >= highOutput.count && recentLogs.count > 0 {
            summary = "Recovery-friendly work is holding its own against the heavier sessions, which is a good sign for consistency."
        } else if highOutput.count > recoveryFriendly.count {
            summary = "High-output sessions are still leading the month, with recovery work acting more like a reset button."
        } else {
            summary = "There is not enough session variety yet to read the recovery balance clearly."
        }

        return RecoveryBalanceInsightData(
            recoveryFriendlyCount: recoveryFriendly.count,
            highOutputCount: highOutput.count,
            steadyMiddleCount: steadyMiddle,
            latestRecoveryDate: recoveryFriendly.first?.completedAt,
            summary: summary
        )
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 16) {
                SectionTitleView(
                    title: "Progress",
                    subtitle: "Your weekly story and the proof that the work is moving somewhere."
                )

                ProgressHeroStrip(
                    score: store.clientProfile.health.score,
                    consistency: logSummary.workoutsThisWeek,
                    consistencyTarget: store.clientProfile.trainingDaysPerWeek,
                    streak: logSummary.currentStreakDays,
                    latestWin: logSummary.totalLogs == 0
                        ? "Log your first workout to start your story."
                        : "\(logSummary.latestWorkoutTitle) is your latest logged session.",
                    showMetrics: store.todayExperienceTier >= 1
                )

                progressPanel
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 120)
        }
    }

    private var progressPanel: some View {
        Group {
            // Progressive disclosure, same tiers as Today: a 0-log user gets
            // the hero's honest guidance and nothing else — no wall of empty
            // widgets. Analytics unlock as real training data exists.
            if store.todayExperienceTier >= 1 {
                // "Am I getting stronger?" leads — it's the question this
                // page exists to answer.
                if !store.exerciseStrengthProgress.isEmpty {
                    StrengthProgressCard(
                        items: store.exerciseStrengthProgress,
                        weightUnit: store.weightUnit
                    )
                }

                // Honest presentation: which days you trained — not binary
                // data drawn as a dramatic score curve.
                TrainedDaysCard(days: last7TrainingDays)

                // (The old "Weekly Log Summary" card lived here — its unique
                // stats now ride in TrainingPatternInsightCard below, and its
                // this-week/streak pills already live in the hero strip.)
                WorkoutHistoryCard(logs: store.currentAthleteWorkoutLogs)
            }

            if store.todayExperienceTier >= 2 {
                AthletePatternInsightsCard(insights: athletePatternInsights)
                TrainingPatternInsightCard(insight: trainingPatternInsight)

                // Telemetry charts, all from the user's real per-set log
                // data: strength, volume, effort, body weight, records.
                // (Grouped: the tier-2 block would otherwise exceed the
                // 10-view ViewBuilder limit.)
                Group {
                    StrengthOverTimeCard(
                        exerciseOptions: store.mostLoggedExerciseNames(limit: 6),
                        weightUnit: store.weightUnit,
                        progression: { store.strengthProgression(for: $0) }
                    )
                    WeeklySetVolumeCard(points: store.weeklySetVolume(weeks: 8))
                    RPETrendCard(points: store.rpeTrendPerSession(sessions: 15))
                    BodyWeightTrendCard(
                        entries: store.bodyWeightHistory,
                        weightUnit: store.weightUnit
                    )
                    PRTimelineCard(
                        records: store.recentPersonalRecords(limit: 5),
                        weightUnit: store.weightUnit
                    )
                }

                SessionMixCard(insight: sessionMixInsight)
                // Buddy comparison, source breakdowns, and coach report cards
                // are multi-user concepts — hidden in solo v1. (Report and
                // compliance were previously hidden only by accident: they
                // read demo coach data that solo clearing happened to empty.)
                if FeatureFlags.multiUserEnabled {
                    SoloVsBuddyProgressCard(
                        insight: partnerInsight,
                        trend: soloBuddyTrend,
                        trendSummary: soloBuddyTrendSummary
                    )
                    WorkoutSourceMixCard(summary: logSummary)
                    SourceTrendCard(insight: sourceTrendInsight)

                    if let report = athleteReport {
                        WeeklyReportCard(report: report)
                    }
                    if let compliance {
                        ProgramComplianceCard(compliance: compliance)
                    }
                }
                RecoveryBalanceCard(insight: recoveryBalanceInsight)

                // Removed here on purpose (UX audit):
                // - "Weekly Consistency" chart — weekly consistency already
                //   shows in the hero "This Week" pill AND TrainedDaysCard,
                //   which answers the question better.
                // - "Weight Trend" StatCard — read demo-origin weightTrend;
                //   BodyWeightTrendCard above charts the user's REAL saved
                //   weights instead.
                // - FrictionInsightCard — near-duplicate of the athlete
                //   pattern insights card at the top of this tier.

                if !store.roadmap.isEmpty {
                    TransformationRoadmapCard(phases: store.roadmap)
                }
                if !store.profileShowcase.badges.isEmpty {
                    BadgeGridCard(badges: store.profileShowcase.badges)
                }
                if !store.recentWins.isEmpty {
                    RecentWinsCard(wins: store.recentWins)
                }
            }

            // Real multi-user competition: opt-in weekly board and
            // code-joinable challenges. Every row is fetched Firestore data
            // from real accounts — no seeded rivals, no fake ranks. Lives
            // last, behind one disclosure, so the page reads summary →
            // charts → competition and stays scannable.
            if store.todayExperienceTier >= 1 {
                ProgressExpandableSection(
                    title: "Compete",
                    subtitle: "The weekly board and code-joinable challenges — every score is a real athlete's logged sets.",
                    isExpanded: $showCompete
                ) {
                    WeeklyBoardCard()
                    ChallengesCard()
                }
            }
        }
    }

    private func resolvedTemplate(for log: WorkoutLog) -> WorkoutTemplate? {
        if let templateID = log.workoutTemplateID {
            if let template = store.workoutTemplates.first(where: { $0.id == templateID }) {
                return template
            }
            // A catalog workout logged but never saved isn't rebuilt into
            // workoutTemplates on relaunch — the bundled catalog still knows it.
            if let catalogTemplate = store.catalogWorkouts.first(where: { $0.id == templateID }) {
                return catalogTemplate
            }
        }

        return store.workoutTemplates.first {
            $0.name == log.workoutTitle && $0.sport == log.sport
        }
    }

    private func resolvedCategory(for log: WorkoutLog) -> ProgramCategory {
        if let template = resolvedTemplate(for: log) {
            return template.category
        }

        let lowercasedTitle = log.workoutTitle.lowercased()
        let lowercasedNotes = log.notes.lowercased()

        if lowercasedTitle.contains("recovery") || lowercasedNotes.contains("recovery") {
            return .recovery
        }
        if lowercasedTitle.contains("mobility") || lowercasedNotes.contains("mobility") {
            return .mobility
        }
        if lowercasedTitle.contains("strength") {
            return .strength
        }
        if lowercasedTitle.contains("speed") {
            return .speed
        }
        if lowercasedTitle.contains("skill") || lowercasedTitle.contains("drill") {
            return .skillWork
        }
        if lowercasedTitle.contains("conditioning") {
            return .conditioning
        }

        return .conditioning
    }

    private func resolvedSessionType(for log: WorkoutLog) -> SessionType {
        if let template = resolvedTemplate(for: log) {
            return template.sessionType
        }

        let category = resolvedCategory(for: log)

        switch category {
        case .recovery, .returnToTraining, .competitionTaper:
            return .recoverySession
        case .mobility:
            return .mobilitySession
        case .skillWork:
            return .skillDrillSession
        default:
            return .gymWorkout
        }
    }

    private func isRecoveryFriendly(_ log: WorkoutLog) -> Bool {
        let category = resolvedCategory(for: log)
        let sessionType = resolvedSessionType(for: log)

        return category == .recovery
            || category == .mobility
            || category == .returnToTraining
            || category == .competitionTaper
            || sessionType == .recoverySession
            || sessionType == .mobilitySession
    }

    /// True when the category came from the template or an explicit keyword —
    /// not the bare fallback. Unmatched logs are excluded from the
    /// output-vs-recovery verdict instead of being guessed as high-output.
    private func hasConfidentCategory(for log: WorkoutLog) -> Bool {
        if resolvedTemplate(for: log) != nil { return true }
        let title = log.workoutTitle.lowercased()
        let notes = log.notes.lowercased()
        return title.contains("recovery") || notes.contains("recovery")
            || title.contains("mobility") || notes.contains("mobility")
            || title.contains("strength") || title.contains("speed")
            || title.contains("skill") || title.contains("drill")
            || title.contains("conditioning")
    }

    private func isHighOutput(_ log: WorkoutLog) -> Bool {
        guard hasConfidentCategory(for: log) else { return false }
        let category = resolvedCategory(for: log)

        return category == .conditioning
            || category == .strength
            || category == .power
            || category == .endurance
            || category == .fightCamp
            || category == .speed
            || category == .agility
    }
}

private struct TrainedDay: Identifiable {
    let id = UUID()
    let label: String
    let trained: Bool
}

/// Flat HUD disclosure — same pattern as HomeExpandableSection /
/// TrainExpandableSection: tracked mono label + hairline rule + a +/-
/// indicator. No bubble — the rule IS the section boundary.
private struct ProgressExpandableSection<Content: View>: View {
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

/// Seven plain day-dots: trained or rested. Replaces the old line chart that
/// drew binary trained/rested values (80/25) as a dramatic score curve.
private struct TrainedDaysCard: View {
    let days: [TrainedDay]

    private var trainedCount: Int {
        days.filter(\.trained).count
    }

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Last 7 Days")
                        .font(.headline)
                        .foregroundStyle(.white)
                    Spacer()
                    Text("\(trainedCount) trained")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(MorpheTheme.accent)
                }

                HStack(spacing: 0) {
                    ForEach(days) { day in
                        VStack(spacing: 6) {
                            RoundedRectangle(cornerRadius: 2, style: .continuous)
                                .fill(day.trained ? MorpheTheme.accent : Color.white.opacity(0.05))
                                .frame(width: 26, height: 26)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 2, style: .continuous)
                                        .stroke(Color.white.opacity(day.trained ? 0 : 0.14), lineWidth: 1)
                                )
                            Text(day.label)
                                .font(.caption2)
                                .foregroundStyle(day.trained ? .white : MorpheTheme.textMuted)
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Trained \(trainedCount) of the last 7 days: \(days.filter(\.trained).map(\.label).joined(separator: ", "))")
    }
}

/// Consolidated training summary — absorbed the old "Weekly Log Summary"
/// card's unique stats (this-week minutes, top-exercise list) so duration
/// numbers appear exactly once on this screen.
private struct TrainingPatternInsightData {
    let minutesThisWeek: Int
    let totalMinutesLogged: Int
    let sessionsLast30Days: Int
    let averageDuration: Int
    let longestSessionTitle: String
    let longestSessionMinutes: Int
    let topExercises: [String]
    let dominantSourceLabel: String
}

private struct SessionMixBucket: Identifiable {
    let id = UUID()
    let category: ProgramCategory
    let count: Int
}

private struct SessionMixInsightData {
    let categoryBuckets: [SessionMixBucket]
    let dominantCategory: ProgramCategory?
    let dominantSessionType: SessionType?
    let summary: String
}

private struct SourceTrendPoint: Identifiable {
    let id = UUID()
    let week: String
    let athleteCount: Int
    let coachCount: Int
    let aiCount: Int
    let buddyCount: Int
}

private struct SourceTrendInsightData {
    let points: [SourceTrendPoint]
    let summary: String
}

private struct RecoveryBalanceInsightData {
    let recoveryFriendlyCount: Int
    let highOutputCount: Int
    let steadyMiddleCount: Int
    let latestRecoveryDate: Date?
    let summary: String
}

private struct TrainingPatternInsightCard: View {
    let insight: TrainingPatternInsightData

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("Training Patterns")
                    .font(.headline)
                    .foregroundStyle(.white)

                Text("The shape of your real training record — this week and all-time.")
                    .font(.subheadline)
                    .foregroundStyle(MorpheTheme.textSecondary)

                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 2), spacing: 8) {
                    MetricPill(label: "Mins this week", value: "\(insight.minutesThisWeek)")
                    MetricPill(label: "Total mins", value: "\(insight.totalMinutesLogged)")
                    MetricPill(label: "Last 30 days", value: "\(insight.sessionsLast30Days)")
                    MetricPill(label: "Average", value: "\(insight.averageDuration) min")
                }

                if insight.longestSessionMinutes > 0 {
                    Text("Longest session: \(insight.longestSessionTitle) (\(insight.longestSessionMinutes) min)")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                }

                Text("Most often logged through: \(insight.dominantSourceLabel)")
                    .font(.caption)
                    .foregroundStyle(MorpheTheme.accentAlt)

                Text(
                    insight.topExercises.isEmpty
                    ? "As more logs land, Morphe will surface the movements showing up most in your real training history."
                    : "Most logged lately: \(insight.topExercises.joined(separator: " • "))"
                )
                .font(.caption)
                .foregroundStyle(MorpheTheme.textSecondary)
            }
        }
    }
}

private struct SessionMixCard: View {
    let insight: SessionMixInsightData

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("Session Mix")
                    .font(.headline)
                    .foregroundStyle(.white)

                Text("This shows what kind of work is actually filling your training record lately.")
                    .font(.subheadline)
                    .foregroundStyle(MorpheTheme.textSecondary)

                if insight.categoryBuckets.isEmpty {
                    Text("Log a few more workouts and Morphe will start showing the real session mix shaping your progress.")
                        .foregroundStyle(MorpheTheme.textSecondary)
                } else {
                    Chart(insight.categoryBuckets) { bucket in
                        BarMark(
                            x: .value("Category", bucket.category.rawValue),
                            y: .value("Sessions", bucket.count)
                        )
                        .foregroundStyle(color(for: bucket.category))
                    }
                    .frame(height: 170)
                    .accessibilityLabel(Text(insight.categoryBuckets
                        .map { "\($0.category.rawValue): \($0.count) sessions" }
                        .joined(separator: ", ")))

                    if let dominantCategory = insight.dominantCategory {
                        Text("Most common category: \(dominantCategory.rawValue)")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.white)
                    }

                    if let dominantSessionType = insight.dominantSessionType {
                        Text("Most common session type: \(dominantSessionType.rawValue)")
                            .font(.caption)
                            .foregroundStyle(MorpheTheme.accentAlt)
                    }

                    Text(insight.summary)
                        .font(.caption)
                        .foregroundStyle(MorpheTheme.textSecondary)
                }
            }
        }
    }

    private func color(for category: ProgramCategory) -> Color {
        switch category {
        case .recovery, .mobility, .competitionTaper, .returnToTraining:
            return MorpheTheme.warning
        case .strength, .power:
            return MorpheTheme.accent
        case .skillWork, .speed, .agility:
            return MorpheTheme.lavender
        default:
            return MorpheTheme.accentAlt
        }
    }
}

private struct SoloVsBuddyProgressCard: View {
    let insight: PartnerTrainingInsight
    let trend: [SoloBuddyTrendPoint]
    let trendSummary: String

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("Solo vs Buddy")
                    .font(.headline)
                    .foregroundStyle(.white)

                Text("See how often you are getting it done on your own versus with a training partner.")
                    .font(.subheadline)
                    .foregroundStyle(MorpheTheme.textSecondary)

                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 2), spacing: 8) {
                    MetricPill(label: "Solo", value: "\(insight.soloSessionsThisWeek)")
                    MetricPill(label: "Buddy", value: "\(insight.buddySessionsThisWeek)")
                    MetricPill(label: "This week", value: "\(insight.totalSessionsThisWeek)")
                    MetricPill(label: "Buddy share", value: "\(insight.buddyShareLast30Days)%")
                }

                if !trend.isEmpty {
                    Chart {
                        ForEach(trend) { point in
                            BarMark(
                                x: .value("Week", point.week),
                                y: .value("Sessions", point.soloSessions)
                            )
                            .foregroundStyle(MorpheTheme.accent.opacity(0.9))
                            .position(by: .value("Type", "Solo"))

                            BarMark(
                                x: .value("Week", point.week),
                                y: .value("Sessions", point.buddySessions)
                            )
                            .foregroundStyle(MorpheTheme.warning.opacity(0.95))
                            .position(by: .value("Type", "Buddy"))
                        }
                    }
                    .frame(height: 170)

                    Text(trendSummary)
                        .font(.caption)
                        .foregroundStyle(MorpheTheme.textSecondary)
                }

                Text(insight.athleteSummary)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)

                if let lastPartnerName = insight.lastPartnerName {
                    Text("Last partner: \(lastPartnerName)")
                        .font(.caption)
                        .foregroundStyle(MorpheTheme.warning)
                }
            }
        }
    }
}

private struct SourceTrendCard: View {
    let insight: SourceTrendInsightData

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("Recent Log Pattern")
                    .font(.headline)
                    .foregroundStyle(.white)

                Text("See who has been carrying the logging over the last few weeks.")
                    .font(.subheadline)
                    .foregroundStyle(MorpheTheme.textSecondary)

                if insight.points.isEmpty {
                    Text("Once a few weeks of shared logs build up, Morphe will show the recent logging pattern here.")
                        .foregroundStyle(MorpheTheme.textSecondary)
                } else {
                    Chart {
                        ForEach(insight.points) { point in
                            BarMark(
                                x: .value("Week", point.week),
                                y: .value("Logs", point.athleteCount)
                            )
                            .foregroundStyle(MorpheTheme.accent)
                            .position(by: .value("Source", "You"))

                            BarMark(
                                x: .value("Week", point.week),
                                y: .value("Logs", point.coachCount)
                            )
                            .foregroundStyle(MorpheTheme.accentAlt)
                            .position(by: .value("Source", "Coach"))

                            BarMark(
                                x: .value("Week", point.week),
                                y: .value("Logs", point.aiCount)
                            )
                            .foregroundStyle(MorpheTheme.lavender)
                            .position(by: .value("Source", "AI"))

                            BarMark(
                                x: .value("Week", point.week),
                                y: .value("Logs", point.buddyCount)
                            )
                            .foregroundStyle(MorpheTheme.warning)
                            .position(by: .value("Source", "Buddy"))
                        }
                    }
                    .frame(height: 180)

                    Text(insight.summary)
                        .font(.caption)
                        .foregroundStyle(MorpheTheme.textSecondary)
                }
            }
        }
    }
}

private struct RecoveryBalanceCard: View {
    let insight: RecoveryBalanceInsightData

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("Recovery vs Output")
                    .font(.headline)
                    .foregroundStyle(.white)

                Text("Your last month should not just be hard work. This reads the balance between lighter and heavier sessions.")
                    .font(.subheadline)
                    .foregroundStyle(MorpheTheme.textSecondary)

                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3), spacing: 8) {
                    MetricPill(label: "Recovery", value: "\(insight.recoveryFriendlyCount)")
                    MetricPill(label: "High output", value: "\(insight.highOutputCount)")
                    MetricPill(label: "Steady", value: "\(insight.steadyMiddleCount)")
                }

                if let latestRecoveryDate = insight.latestRecoveryDate {
                    Text("Latest recovery-friendly session: \(MorpheAppStore.workoutDateLabel(for: latestRecoveryDate))")
                        .font(.caption)
                        .foregroundStyle(MorpheTheme.accentAlt)
                }

                Text(insight.summary)
                    .font(.caption)
                    .foregroundStyle(MorpheTheme.textSecondary)
            }
        }
    }
}

private struct AthletePatternInsightsCard: View {
    let insights: [AthletePatternInsight]

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 14) {
                Text("What Works for You")
                    .font(.headline)
                    .foregroundStyle(.white)

                Text("These are the patterns Morphe keeps seeing when your training actually lands.")
                    .font(.subheadline)
                    .foregroundStyle(MorpheTheme.textSecondary)

                ForEach(Array(insights.enumerated()), id: \.element.id) { index, insight in
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(alignment: .top, spacing: 12) {
                            Image(systemName: insight.systemImage)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(MorpheTheme.accentAlt)
                                .frame(width: 34, height: 34)
                                .background(
                                    RoundedRectangle(cornerRadius: MorpheTheme.radius, style: .continuous)
                                        .fill(MorpheTheme.panelRaised)
                                )

                            VStack(alignment: .leading, spacing: 4) {
                                Text(insight.title)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(.white)
                                Text(insight.detail)
                                    .font(.caption)
                                    .foregroundStyle(MorpheTheme.textSecondary)
                            }

                            Spacer()

                            StatusBadge(text: insight.badge, color: MorpheTheme.accentAlt)
                        }

                        if index < insights.count - 1 {
                            Divider()
                                .overlay(MorpheTheme.stroke.opacity(0.6))
                        }
                    }
                }
            }
        }
    }
}

private struct ProgressHeroStrip: View {
    let score: Int
    let consistency: Int
    /// The user's own weekly training-day goal from onboarding — not a
    /// hardcoded 5 that a 3-day plan could never satisfy.
    let consistencyTarget: Int
    let streak: Int
    let latestWin: String
    /// False on first run — same principle as Today: zeros aren't metrics.
    var showMetrics: Bool = true

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                if showMetrics {
                    HStack(spacing: 8) {
                        MetricPill(label: "Morphe Score", value: "\(score)")
                        MetricPill(label: "This Week", value: "\(consistency)/\(max(consistencyTarget, 1))")
                        MetricPill(label: "Streak", value: "\(streak) days")
                    }
                }

                Text(latestWin)
                    .font(.headline)
                    .foregroundStyle(.white)

                if !showMetrics {
                    Text("Your Morphe Score, weekly count, and streak appear here with your first log.")
                        .font(.caption)
                        .foregroundStyle(MorpheTheme.textSecondary)
                }
            }
        }
    }
}

// MARK: - Telemetry charts (real per-set log data, flat black + accent)

/// Per-exercise top-set progression across every logged session — the
/// long-arc "am I getting stronger?" chart. (StrengthProgressCard above
/// covers only latest-vs-previous; this draws the whole line.)
private struct StrengthOverTimeCard: View {
    let exerciseOptions: [String]
    let weightUnit: WeightUnit
    let progression: (String) -> [(date: Date, topWeight: Double)]

    @State private var selectedExercise: String?

    private var activeExercise: String? {
        if let selectedExercise, exerciseOptions.contains(selectedExercise) {
            return selectedExercise
        }
        return exerciseOptions.first
    }

    private var points: [(date: Date, topWeight: Double)] {
        guard let activeExercise else { return [] }
        return progression(activeExercise)
    }

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .firstTextBaseline) {
                    Text("Strength Over Time")
                        .font(.headline)
                        .foregroundStyle(.white)
                    Spacer()
                    if !exerciseOptions.isEmpty, let activeExercise {
                        Menu {
                            ForEach(exerciseOptions, id: \.self) { name in
                                Button(name) { selectedExercise = name }
                            }
                        } label: {
                            HStack(spacing: 4) {
                                Text(activeExercise)
                                    .lineLimit(1)
                                Image(systemName: "chevron.up.chevron.down")
                                    .font(.caption2)
                            }
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(MorpheTheme.accent)
                        }
                        .accessibilityLabel("Choose exercise, currently \(activeExercise)")
                    }
                }

                Text("Heaviest set per session for one exercise.")
                    .font(.caption)
                    .foregroundStyle(MorpheTheme.textSecondary)

                if points.count >= 2 {
                    Chart {
                        ForEach(Array(points.enumerated()), id: \.offset) { index, point in
                            LineMark(
                                x: .value("Date", point.date),
                                y: .value("Top set", point.topWeight)
                            )
                            .foregroundStyle(MorpheTheme.accent)
                            .interpolationMethod(.monotone)

                            PointMark(
                                x: .value("Date", point.date),
                                y: .value("Top set", point.topWeight)
                            )
                            .foregroundStyle(
                                index == points.count - 1
                                    ? MorpheTheme.accent
                                    : MorpheTheme.accent.opacity(0.5)
                            )
                            .symbolSize(index == points.count - 1 ? 100 : 36)
                        }

                        if let latest = points.last {
                            PointMark(
                                x: .value("Date", latest.date),
                                y: .value("Top set", latest.topWeight)
                            )
                            .foregroundStyle(MorpheTheme.accent)
                            .annotation(position: .top, alignment: .trailing) {
                                Text(weightUnit.format(latest.topWeight))
                                    .font(.caption2.weight(.bold))
                                    .foregroundStyle(MorpheTheme.accent)
                            }
                        }
                    }
                    .frame(height: 180)
                    .accessibilityLabel(Text(
                        "\(activeExercise ?? "Exercise") top set over \(points.count) sessions, latest \(weightUnit.format(points.last?.topWeight ?? 0))"
                    ))
                } else if let activeExercise {
                    Text("Log \(activeExercise) with weights one more time to draw this line — two sessions make a trend.")
                        .font(.caption)
                        .foregroundStyle(MorpheTheme.textSecondary)
                } else {
                    Text("Log 2 sessions of the same exercise with weights to see this chart.")
                        .font(.caption)
                        .foregroundStyle(MorpheTheme.textSecondary)
                }
            }
        }
    }
}

/// Total logged sets per week, last 8 weeks — the honest workload dial.
private struct WeeklySetVolumeCard: View {
    let points: [(weekStart: Date, sets: Int)]

    private var hasData: Bool {
        points.contains { $0.sets > 0 }
    }

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("Weekly Volume")
                    .font(.headline)
                    .foregroundStyle(.white)

                Text("Total sets logged per week — empty weeks stay visible.")
                    .font(.caption)
                    .foregroundStyle(MorpheTheme.textSecondary)

                if hasData {
                    Chart(points, id: \.weekStart) { point in
                        BarMark(
                            x: .value("Week", point.weekStart, unit: .weekOfYear),
                            y: .value("Sets", point.sets)
                        )
                        .foregroundStyle(point.sets > 0 ? MorpheTheme.accent : MorpheTheme.accent.opacity(0.2))
                    }
                    .frame(height: 160)
                    .accessibilityLabel(Text(
                        "Sets per week over the last \(points.count) weeks, latest week \(points.last?.sets ?? 0) sets"
                    ))
                } else {
                    Text("Log the sets inside your workouts to see weekly volume — your first logged set starts this chart.")
                        .font(.caption)
                        .foregroundStyle(MorpheTheme.textSecondary)
                }
            }
        }
    }
}

/// Average rated RPE per session — is training effort drifting up or down?
private struct RPETrendCard: View {
    let points: [(date: Date, averageRPE: Double)]

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("Effort Trend (RPE)")
                    .font(.headline)
                    .foregroundStyle(.white)

                Text("Average rated RPE per session, most recent rated sessions.")
                    .font(.caption)
                    .foregroundStyle(MorpheTheme.textSecondary)

                if points.count >= 2 {
                    Chart {
                        ForEach(Array(points.enumerated()), id: \.offset) { index, point in
                            LineMark(
                                x: .value("Date", point.date),
                                y: .value("RPE", point.averageRPE)
                            )
                            .foregroundStyle(MorpheTheme.accent)
                            .interpolationMethod(.monotone)

                            PointMark(
                                x: .value("Date", point.date),
                                y: .value("RPE", point.averageRPE)
                            )
                            .foregroundStyle(
                                index == points.count - 1
                                    ? MorpheTheme.accent
                                    : MorpheTheme.accent.opacity(0.5)
                            )
                            .symbolSize(index == points.count - 1 ? 100 : 36)
                        }
                    }
                    .chartYScale(domain: 6.0...10.0)
                    .frame(height: 160)
                    .accessibilityLabel(Text(
                        "Average session RPE over \(points.count) sessions, latest \(points.last.map { String($0.averageRPE) } ?? "unknown")"
                    ))
                } else {
                    Text("Rate RPE on your sets in at least 2 sessions to unlock this trend.")
                        .font(.caption)
                        .foregroundStyle(MorpheTheme.textSecondary)
                }
            }
        }
    }
}

/// Real body-weight history from the readings the user saves in Profile —
/// never a fake curve extrapolated from a single current value.
private struct BodyWeightTrendCard: View {
    let entries: [(date: Date, weightLb: Double)]
    let weightUnit: WeightUnit

    /// History is stored in lb; render in the user's display unit.
    private func displayWeight(_ lb: Double) -> Double {
        weightUnit == .kilograms ? ((lb * 0.45359237) * 10).rounded() / 10 : lb
    }

    private var changeText: String? {
        guard let first = entries.first, let last = entries.last, entries.count >= 2 else { return nil }
        let delta = displayWeight(last.weightLb) - displayWeight(first.weightLb)
        if abs(delta) < 0.05 { return "Held steady since your first reading." }
        let rounded = (abs(delta) * 10).rounded() / 10
        let amount = rounded.truncatingRemainder(dividingBy: 1) == 0
            ? String(Int(rounded))
            : String(rounded)
        return "\(delta > 0 ? "Up" : "Down") \(amount) \(weightUnit.label) since your first reading."
    }

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("Body Weight")
                    .font(.headline)
                    .foregroundStyle(.white)

                Text("Every weight you save in Profile becomes a dated reading here.")
                    .font(.caption)
                    .foregroundStyle(MorpheTheme.textSecondary)

                if entries.count >= 2 {
                    Chart {
                        ForEach(Array(entries.enumerated()), id: \.offset) { index, entry in
                            LineMark(
                                x: .value("Date", entry.date),
                                y: .value("Weight", displayWeight(entry.weightLb))
                            )
                            .foregroundStyle(MorpheTheme.accent)
                            .interpolationMethod(.monotone)

                            PointMark(
                                x: .value("Date", entry.date),
                                y: .value("Weight", displayWeight(entry.weightLb))
                            )
                            .foregroundStyle(
                                index == entries.count - 1
                                    ? MorpheTheme.accent
                                    : MorpheTheme.accent.opacity(0.5)
                            )
                            .symbolSize(index == entries.count - 1 ? 100 : 36)
                        }
                    }
                    .frame(height: 160)
                    .accessibilityLabel(Text(
                        "Body weight over \(entries.count) readings, latest \(weightUnit.format(displayWeight(entries.last?.weightLb ?? 0)))"
                    ))

                    if let changeText {
                        Text(changeText)
                            .font(.caption)
                            .foregroundStyle(MorpheTheme.accentAlt)
                    }
                } else {
                    Text("Update your weight in Profile over time to build this chart — two saved readings draw the first line.")
                        .font(.caption)
                        .foregroundStyle(MorpheTheme.textSecondary)
                }
            }
        }
    }
}

/// The last five personal records — first session each all-time top set
/// was hit, straight from the logs.
private struct PRTimelineCard: View {
    let records: [(date: Date, exerciseName: String, weight: Double)]
    let weightUnit: WeightUnit

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("PR Timeline")
                    .font(.headline)
                    .foregroundStyle(.white)

                Text("Your latest personal records — the day each top set first landed.")
                    .font(.caption)
                    .foregroundStyle(MorpheTheme.textSecondary)

                if records.isEmpty {
                    Text("Log weighted sets to start your PR timeline — every first-time top weight lands here.")
                        .font(.caption)
                        .foregroundStyle(MorpheTheme.textSecondary)
                } else {
                    ForEach(Array(records.enumerated()), id: \.offset) { index, record in
                        HStack(alignment: .center, spacing: 10) {
                            Image(systemName: "trophy.fill")
                                .font(.caption)
                                .foregroundStyle(MorpheTheme.accent)
                                .frame(width: 24)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(record.exerciseName)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(.white)
                                Text(MorpheAppStore.workoutDateLabel(for: record.date))
                                    .font(.caption2)
                                    .foregroundStyle(MorpheTheme.textMuted)
                            }

                            Spacer(minLength: 0)

                            Text(weightUnit.format(record.weight))
                                .font(.subheadline.weight(.bold))
                                .foregroundStyle(MorpheTheme.accent)
                        }
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel(
                            "\(record.exerciseName) record: \(weightUnit.format(record.weight)), set \(MorpheAppStore.workoutDateLabel(for: record.date))"
                        )

                        if index < records.count - 1 {
                            Divider().overlay(MorpheTheme.stroke.opacity(0.5))
                        }
                    }
                }
            }
        }
    }
}

private struct WorkoutSourceMixCard: View {
    let summary: WorkoutLogSummary

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("Log Sources")
                    .font(.headline)
                    .foregroundStyle(.white)

                Text("All trusted entries end up in one progress record, whether they came from you, your coach, or Morphe AI.")
                    .font(.subheadline)
                    .foregroundStyle(MorpheTheme.textSecondary)

                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 2), spacing: 8) {
                    MetricPill(label: "You", value: "\(summary.athleteEntries)")
                    MetricPill(label: "Coach", value: "\(summary.coachEntries)")
                    MetricPill(label: "AI", value: "\(summary.aiEntries)")
                    MetricPill(label: "Buddy", value: "\(summary.partnerEntries)")
                    MetricPill(label: "Total", value: "\(summary.totalLogs)")
                }
            }
        }
    }
}

private struct WeeklyReportCard: View {
    let report: AthleteReport

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("Weekly Report")
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

                Text("Main win: \(report.mainWin)")
                    .foregroundStyle(.white)
                Text("Main issue: \(report.mainIssue)")
                    .foregroundStyle(MorpheTheme.textSecondary)
                Text("Next focus: \(report.nextFocus)")
                    .foregroundStyle(MorpheTheme.accentAlt)
            }
        }
    }
}

private struct RecentWinsCard: View {
    let wins: [String]

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("Recent Wins")
                    .font(.headline)
                    .foregroundStyle(.white)

                ForEach(wins, id: \.self) { win in
                    Text("- \(win)")
                        .foregroundStyle(MorpheTheme.textPrimary)
                }
            }
        }
    }
}

/// "Am I getting stronger?" — per-exercise top-set trend from real logs.
private struct StrengthProgressCard: View {
    let items: [ExerciseStrengthProgress]
    let weightUnit: WeightUnit

    private func deltaText(_ item: ExerciseStrengthProgress) -> String {
        if item.delta > 0 { return "+\(weightUnit.format(item.delta))" }
        if item.delta < 0 { return "-\(weightUnit.format(abs(item.delta)))" }
        return "Held"
    }

    private func deltaColor(_ item: ExerciseStrengthProgress) -> Color {
        if item.delta > 0 { return MorpheTheme.accent }
        if item.delta < 0 { return MorpheTheme.warning }
        return MorpheTheme.textMuted
    }

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("Strength Progress")
                    .font(.headline)
                    .foregroundStyle(.white)
                Text("Top set now vs. your previous session, per exercise.")
                    .font(.caption)
                    .foregroundStyle(MorpheTheme.textSecondary)

                ForEach(items.prefix(6)) { item in
                    HStack(alignment: .center, spacing: 10) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.exerciseName)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.white)
                            Text("\(item.sessionCount) sessions")
                                .font(.caption2)
                                .foregroundStyle(MorpheTheme.textMuted)
                        }

                        Spacer(minLength: 0)

                        Text(weightUnit.format(item.latestTopWeight))
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(.white)

                        Text(deltaText(item))
                            .font(.caption.weight(.bold))
                            .foregroundStyle(deltaColor(item))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(RoundedRectangle(cornerRadius: 2, style: .continuous).stroke(deltaColor(item).opacity(0.55), lineWidth: 1))
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("\(item.exerciseName): top set \(weightUnit.format(item.latestTopWeight)), \(deltaText(item)) versus previous session")
                }
            }
        }
    }
}

/// The user's own training history with the real per-set numbers inside
/// each session — not just titles and dates.
private struct WorkoutHistoryCard: View {
    let logs: [WorkoutLog]
    @State private var showAll = false

    /// The default note written by the log flow; pure filler in history.
    private static let fillerNote = "Logged from the live workout flow."

    private var visibleLogs: [WorkoutLog] {
        showAll ? logs : Array(logs.prefix(5))
    }

    private func setLine(for exercise: LoggedExercise) -> String {
        guard let reps = exercise.repsPerSet, !reps.isEmpty else {
            // Older logs without per-set data fall back to the summary strings.
            return "\(exercise.sets) • \(exercise.reps) • \(exercise.weight)"
        }
        let weights = exercise.weightsPerSet ?? []
        let rpes = exercise.rpePerSet ?? []
        let unit = exercise.weightUnit ?? WeightUnit.pounds.rawValue
        return reps.indices.map { index in
            let weight = weights.indices.contains(index) ? weights[index] : 0
            let rpe = rpes.indices.contains(index) ? rpes[index] : 0
            var line = weight > 0
                ? "\(reps[index])×\(weight.truncatingRemainder(dividingBy: 1) == 0 ? String(Int(weight)) : String(weight)) \(unit)"
                : "\(reps[index]) reps"
            if rpe > 0 { line += " @\(rpe)" }
            return line
        }
        .joined(separator: ", ")
    }

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Workout History")
                        .font(.headline)
                        .foregroundStyle(.white)
                    Spacer()
                    if !logs.isEmpty {
                        Text("\(logs.count)")
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(MorpheTheme.textMuted)
                    }
                }

                if logs.isEmpty {
                    Text("Every workout you log lands here with the real sets and weights.")
                        .foregroundStyle(MorpheTheme.textSecondary)
                } else {
                    ForEach(visibleLogs) { log in
                        VStack(alignment: .leading, spacing: 6) {
                            HStack(alignment: .top) {
                                Text(log.workoutTitle)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(.white)
                                Spacer()
                                Text("\(MorpheAppStore.workoutDateLabel(for: log.completedAt)) • \(log.durationMinutes) min")
                                    .font(.caption)
                                    .foregroundStyle(MorpheTheme.textSecondary)
                            }

                            ForEach(log.exercises) { exercise in
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(exercise.name)
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(MorpheTheme.textPrimary)
                                    Text(setLine(for: exercise))
                                        .font(.caption)
                                        .foregroundStyle(MorpheTheme.textSecondary)
                                }
                            }

                            if !log.notes.isEmpty && log.notes != Self.fillerNote {
                                Text(log.notes)
                                    .font(.caption)
                                    .foregroundStyle(MorpheTheme.textMuted)
                            }
                        }
                        .padding(.vertical, 4)
                        .accessibilityElement(children: .combine)

                        if log.id != visibleLogs.last?.id {
                            Divider().overlay(MorpheTheme.stroke.opacity(0.5))
                        }
                    }

                    if logs.count > 5 {
                        Button(showAll ? "Show Recent" : "Show All") {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                showAll.toggle()
                            }
                        }
                        .buttonStyle(SecondaryCTAButtonStyle())
                        .accessibilityLabel(showAll ? "Show recent workouts only" : "Show all \(logs.count) workouts")
                    }
                }
            }
        }
    }
}

// MARK: - Weekly board + challenges (real multi-user competition)

/// The blue verification seal color used app-wide (matches ProfileView).
private let verifiedSealBlue = Color(red: 0.25, green: 0.56, blue: 0.96)

/// Opt-in global weekly leaderboard. Scores are total sets logged this ISO
/// week, posted by each user's own device from their own logs — the card only
/// ever renders what was actually fetched from Firestore.
private struct WeeklyBoardCard: View {
    @Environment(MorpheAppStore.self) private var store

    private var myUid: String? { store.authUser?.id }

    /// Rows to show: the fetched top 10 (of the fetched top 50).
    private var topRows: [WeeklyLeaderboardEntry] {
        Array(store.weeklyLeaderboard.prefix(10))
    }

    /// The user's position within the FETCHED list (1-based), if present.
    /// Positions beyond what was fetched are unknowable cheaply — the card
    /// says so instead of inventing a rank.
    private var myFetchedRank: Int? {
        guard let myUid,
              let index = store.weeklyLeaderboard.firstIndex(where: { $0.uid == myUid })
        else { return nil }
        return index + 1
    }

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("Weekly Board")
                    .font(.headline)
                    .foregroundStyle(.white)

                if store.leaderboardOptIn {
                    optedInBody
                } else {
                    optInPitch
                }
            }
        }
        .task {
            await store.refreshLeaderboard()
        }
    }

    private var optInPitch: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("A global board of real Morphe athletes, reset every Monday. Your score is the sets you actually log — nothing else. Leaving stops future posts, but anything already posted stays visible for the rest of the week.")
                .font(.caption)
                .foregroundStyle(MorpheTheme.textSecondary)

            Button("Join Board") {
                store.joinWeeklyBoard()
            }
            .buttonStyle(PrimaryCTAButtonStyle(accent: MorpheTheme.accent))
        }
    }

    @ViewBuilder
    private var optedInBody: some View {
        Text("Top of the fetched board (top 50) — total sets logged this week.")
            .font(.caption)
            .foregroundStyle(MorpheTheme.textSecondary)

        if topRows.isEmpty {
            Text("No scores posted this week yet — log a workout and yours starts the board.")
                .font(.caption)
                .foregroundStyle(MorpheTheme.textSecondary)
        } else {
            VStack(spacing: 6) {
                ForEach(Array(topRows.enumerated()), id: \.element.id) { index, entry in
                    boardRow(rank: index + 1, entry: entry, isMe: entry.uid == myUid)
                }
            }

            // The user's own honest position when they're outside the top 10.
            if let myUid, !topRows.contains(where: { $0.uid == myUid }) {
                if let rank = myFetchedRank,
                   let mine = store.weeklyLeaderboard.first(where: { $0.uid == myUid }) {
                    Divider().overlay(MorpheTheme.stroke.opacity(0.5))
                    boardRow(rank: rank, entry: mine, isMe: true)
                } else if let mine = store.weeklyLeaderboardSelfEntry {
                    Divider().overlay(MorpheTheme.stroke.opacity(0.5))
                    HStack(spacing: 8) {
                        Text("You")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(MorpheTheme.accent)
                        Text("\(mine.score) sets — posted, outside the fetched top 50")
                            .font(.caption)
                            .foregroundStyle(MorpheTheme.textSecondary)
                    }
                } else {
                    Text("Not on the board this week yet — log a workout to post your score.")
                        .font(.caption)
                        .foregroundStyle(MorpheTheme.textSecondary)
                }
            }
        }

        Button("Leave Board") {
            store.leaveWeeklyBoard()
        }
        .buttonStyle(SecondaryCTAButtonStyle())
    }

    private func boardRow(rank: Int, entry: WeeklyLeaderboardEntry, isMe: Bool) -> some View {
        HStack(spacing: 8) {
            Text("\(rank)")
                .font(.caption.weight(.bold))
                .foregroundStyle(isMe ? MorpheTheme.accent : MorpheTheme.textMuted)
                .frame(width: 22, alignment: .leading)

            Text(isMe ? "\(entry.name) (you)" : entry.name)
                .font(.caption.weight(isMe ? .bold : .semibold))
                .foregroundStyle(isMe ? MorpheTheme.accent : .white)
                .lineLimit(1)

            if entry.verified {
                Image(systemName: "checkmark.seal.fill")
                    .font(.caption2)
                    .foregroundStyle(verifiedSealBlue)
                    .accessibilityLabel("Verified")
            }

            Spacer()

            Text("\(entry.score) sets")
                .font(.caption)
                .foregroundStyle(MorpheTheme.textSecondary)
        }
        .padding(.vertical, 3)
        .padding(.horizontal, 6)
        .background(
            isMe ? MorpheTheme.accent.opacity(0.10) : Color.clear,
            in: RoundedRectangle(cornerRadius: MorpheTheme.radius)
        )
        .accessibilityElement(children: .combine)
    }
}

/// Code-joinable challenges — the party-code pattern applied to a scoreboard.
/// Rows show the fetched top member versus the user's own fetched score; a
/// member who hasn't posted yet is told exactly what unlocks it.
private struct ChallengesCard: View {
    @Environment(MorpheAppStore.self) private var store
    @State private var joinCode = ""
    @State private var showCreateSheet = false

    private var myUid: String? { store.authUser?.id }

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("Challenges")
                    .font(.headline)
                    .foregroundStyle(.white)

                Text("Private scoreboards with people who have the code. Scores come from logged workouts only.")
                    .font(.caption)
                    .foregroundStyle(MorpheTheme.textSecondary)

                if store.activeChallenges.isEmpty {
                    Text("No challenges yet — create one and share its code, or enter a friend's code below.")
                        .font(.caption)
                        .foregroundStyle(MorpheTheme.textSecondary)
                } else {
                    VStack(spacing: 10) {
                        ForEach(store.activeChallenges) { challenge in
                            challengeRow(challenge)
                        }
                    }
                }

                Divider().overlay(MorpheTheme.stroke.opacity(0.5))

                HStack(spacing: 8) {
                    TextField("Enter code", text: $joinCode)
                        .font(.caption.monospaced())
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                        .onChange(of: joinCode) { _, newValue in
                            joinCode = String(newValue.uppercased().prefix(6))
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .background(MorpheTheme.panelStrong, in: RoundedRectangle(cornerRadius: MorpheTheme.radius))

                    Button("Join") {
                        let code = joinCode
                        joinCode = ""
                        Task { await store.joinChallenge(code: code) }
                    }
                    .buttonStyle(SecondaryCTAButtonStyle())
                    .disabled(joinCode.count != 6 || store.isCompetitionBusy)

                    Button("Create") {
                        showCreateSheet = true
                    }
                    .buttonStyle(PrimaryCTAButtonStyle(accent: MorpheTheme.accent))
                    .disabled(store.isCompetitionBusy)
                }
            }
        }
        .task {
            await store.refreshChallenges()
        }
        .sheet(isPresented: $showCreateSheet) {
            CreateChallengeSheet()
                .environment(store)
        }
    }

    private func challengeRow(_ challenge: ChallengeSummary) -> some View {
        let top = challenge.topMember
        let mine = myUid.flatMap { uid in challenge.members.first { $0.uid == uid } }

        return VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                Text(challenge.title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)

                Spacer()

                Text(challenge.isExpired ? "Ended" : "\(challenge.daysLeft)d left")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(challenge.isExpired ? MorpheTheme.textMuted : MorpheTheme.accent)
            }

            HStack(spacing: 8) {
                if let top {
                    HStack(spacing: 3) {
                        Text("Top: \(top.name)")
                            .font(.caption2)
                            .foregroundStyle(MorpheTheme.textSecondary)
                        if top.verified {
                            Image(systemName: "checkmark.seal.fill")
                                .font(.caption2)
                                .foregroundStyle(verifiedSealBlue)
                                .accessibilityLabel("Verified")
                        }
                        Text("— \(top.score) \(challenge.metric.unit)")
                            .font(.caption2)
                            .foregroundStyle(MorpheTheme.textSecondary)
                    }
                } else {
                    Text("No scores yet — the first logged workout opens the scoring.")
                        .font(.caption2)
                        .foregroundStyle(MorpheTheme.textSecondary)
                }

                Spacer()

                if let mine {
                    Text("You: \(mine.score)")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(MorpheTheme.accent)
                }
            }

            HStack(spacing: 6) {
                Text("Code \(challenge.code)")
                    .font(.caption2.monospaced())
                    .foregroundStyle(MorpheTheme.textMuted)
                ShareLink(item: "Join my \"\(challenge.title)\" challenge on Morphe — code \(challenge.code)") {
                    Image(systemName: "square.and.arrow.up")
                        .font(.caption2)
                        .foregroundStyle(MorpheTheme.textMuted)
                }
                .accessibilityLabel("Share challenge code")
            }
        }
        .padding(.vertical, 2)
    }
}

/// Host-side challenge creation: title, metric, duration (rules cap 30 days),
/// then the share code — same handoff pattern as managed-client invites.
private struct CreateChallengeSheet: View {
    @Environment(MorpheAppStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var title = ""
    @State private var metric: ChallengeMetric = .sets
    @State private var days = 7
    @State private var created: ChallengeSummary?

    private let durationOptions = [7, 14, 30]

    var body: some View {
        NavigationStack {
            ZStack {
                MorpheTheme.ink.ignoresSafeArea()

                VStack(alignment: .leading, spacing: 16) {
                    if let created {
                        createdBody(created)
                    } else {
                        formBody
                    }
                    Spacer()
                }
                .padding(20)
            }
            .navigationTitle("New Challenge")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                        .foregroundStyle(MorpheTheme.textSecondary)
                }
            }
        }
        .presentationDetents([.medium])
    }

    private var formBody: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Whoever has the code can join. Scores count only workouts logged during the challenge window.")
                .font(.caption)
                .foregroundStyle(MorpheTheme.textSecondary)

            TextField("Challenge title", text: $title)
                .font(.subheadline)
                .padding(12)
                .background(MorpheTheme.panelStrong, in: RoundedRectangle(cornerRadius: MorpheTheme.radius))

            VStack(alignment: .leading, spacing: 8) {
                Text("Scored by")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(MorpheTheme.textSecondary)
                HStack(spacing: 8) {
                    ForEach(ChallengeMetric.allCases) { option in
                        Button(option.label) { metric = option }
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(metric == option ? .black : .white)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(
                                metric == option ? MorpheTheme.accent : MorpheTheme.panelStrong,
                                in: Capsule()
                            )
                    }
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Duration")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(MorpheTheme.textSecondary)
                HStack(spacing: 8) {
                    ForEach(durationOptions, id: \.self) { option in
                        Button("\(option) days") { days = option }
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(days == option ? .black : .white)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(
                                days == option ? MorpheTheme.accent : MorpheTheme.panelStrong,
                                in: Capsule()
                            )
                    }
                }
            }

            Button(store.isCompetitionBusy ? "Creating…" : "Create") {
                Task {
                    created = await store.createChallenge(title: title, metric: metric, days: days)
                }
            }
            .buttonStyle(PrimaryCTAButtonStyle(accent: MorpheTheme.accent))
            .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || store.isCompetitionBusy)
        }
    }

    private func createdBody(_ challenge: ChallengeSummary) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(challenge.title)
                .font(.headline)
                .foregroundStyle(.white)

            Text("Share this code — anyone who enters it joins the scoreboard.")
                .font(.caption)
                .foregroundStyle(MorpheTheme.textSecondary)

            Text(challenge.code)
                .font(.system(.title, design: .monospaced).weight(.bold))
                .foregroundStyle(MorpheTheme.accent)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(MorpheTheme.panelStrong, in: RoundedRectangle(cornerRadius: MorpheTheme.radius))

            ShareLink(item: "Join my \"\(challenge.title)\" challenge on Morphe — code \(challenge.code)") {
                Text("Share Code")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(PrimaryCTAButtonStyle(accent: MorpheTheme.accent))

            Button("Done") { dismiss() }
                .buttonStyle(SecondaryCTAButtonStyle())
        }
    }
}
