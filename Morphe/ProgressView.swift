import Charts
import SwiftUI

// Named ProgressScreenView (not ProgressView) so it can't shadow SwiftUI's
// ProgressView spinner — the shadowing silently embedded this entire dashboard
// wherever a plain loading spinner was intended (onboarding, auth).
struct ProgressScreenView: View {
    @Environment(MorpheAppStore.self) private var store

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
            totalMinutesLogged: totalMinutes,
            sessionsLast30Days: sessionsLast30Days,
            averageDuration: averageDuration,
            longestSessionTitle: longestSession?.workoutTitle ?? "No long session yet",
            longestSessionMinutes: longestSession?.durationMinutes ?? 0,
            topExercise: topExercise,
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

    private var weightChange: Int {
        guard let start = store.weightTrend.first?.value,
              let current = store.weightTrend.last?.value else { return 0 }
        return current - start
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

                LogDrivenWeeklySummaryCard(summary: logSummary)
                WorkoutHistoryCard(logs: store.currentAthleteWorkoutLogs)
            }

            if store.todayExperienceTier >= 2 {
                AthletePatternInsightsCard(insights: athletePatternInsights)
                TrainingPatternInsightCard(insight: trainingPatternInsight)
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

                SimpleChartCard(title: "Weekly Consistency") {
                    Chart(store.workoutConsistency) { point in
                        BarMark(
                            x: .value("Week", point.week),
                            y: .value("Workouts", point.workouts)
                        )
                        .foregroundStyle(MorpheTheme.accentAlt)
                    }
                    .frame(height: 160)
                    .accessibilityLabel(Text("Workouts logged per week"))
                }

                if !store.weightTrend.isEmpty {
                    StatCard(
                        title: "Weight Trend",
                        value: "\(store.weightTrend.last?.value ?? 0) \(store.weightUnit.label)",
                        detail: "Start: \(store.weightTrend.first?.value ?? 0) \(store.weightUnit.label)  •  Change: \(weightChange) \(store.weightUnit.label)"
                    )
                }

                if !store.roadmap.isEmpty {
                    TransformationRoadmapCard(phases: store.roadmap)
                }
                if let pattern = store.currentPatternInsight {
                    FrictionInsightCard(insight: pattern) {
                        store.cyclePatternInsight()
                    }
                }
                if !store.profileShowcase.badges.isEmpty {
                    BadgeGridCard(badges: store.profileShowcase.badges)
                }
                if !store.recentWins.isEmpty {
                    RecentWinsCard(wins: store.recentWins)
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

private struct TrainingPatternInsightData {
    let totalMinutesLogged: Int
    let sessionsLast30Days: Int
    let averageDuration: Int
    let longestSessionTitle: String
    let longestSessionMinutes: Int
    let topExercise: String?
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

                Text("This is the shape of your real training record, not just a weekly summary.")
                    .font(.subheadline)
                    .foregroundStyle(MorpheTheme.textSecondary)

                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 2), spacing: 8) {
                    MetricPill(label: "Logged mins", value: "\(insight.totalMinutesLogged)")
                    MetricPill(label: "Last 30 days", value: "\(insight.sessionsLast30Days)")
                    MetricPill(label: "Average", value: "\(insight.averageDuration) min")
                    MetricPill(label: "Longest", value: "\(insight.longestSessionMinutes) min")
                }

                if insight.longestSessionMinutes > 0 {
                    Text("Longest session: \(insight.longestSessionTitle)")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                }

                Text("Most often logged through: \(insight.dominantSourceLabel)")
                    .font(.caption)
                    .foregroundStyle(MorpheTheme.accentAlt)

                Text(
                    insight.topExercise.map { "Most repeated movement lately: \($0)." }
                    ?? "As more logs land, Morphe will surface the movements showing up most in your real training history."
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

private struct LogDrivenWeeklySummaryCard: View {
    let summary: WorkoutLogSummary

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("Weekly Log Summary")
                    .font(.headline)
                    .foregroundStyle(.white)

                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 2), spacing: 8) {
                    MetricPill(label: "This week", value: "\(summary.workoutsThisWeek)")
                    MetricPill(label: "Minutes", value: "\(summary.minutesThisWeek)")
                    MetricPill(label: "Average", value: "\(summary.averageDuration) min")
                    MetricPill(label: "Log streak", value: "\(summary.currentStreakDays) days")
                }

                Text(summary.latestWorkoutTitle)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)

                Text(summary.latestEntryLabel)
                    .font(.caption)
                    .foregroundStyle(MorpheTheme.accentAlt)

                if summary.topExercises.isEmpty {
                    Text("As new workouts land here, Morphe will surface the exercises and session patterns showing up most often.")
                        .font(.caption)
                        .foregroundStyle(MorpheTheme.textSecondary)
                } else {
                    Text("Most logged lately: \(summary.topExercises.joined(separator: " • "))")
                        .font(.caption)
                        .foregroundStyle(MorpheTheme.textSecondary)
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

private struct SimpleChartCard<Content: View>: View {
    let title: String
    let content: Content

    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(.white)
                content
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
                        Button(showAll ? "Show recent only" : "Show all \(logs.count)") {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                showAll.toggle()
                            }
                        }
                        .buttonStyle(SecondaryCTAButtonStyle())
                    }
                }
            }
        }
    }
}
