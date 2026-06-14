import Charts
import SwiftUI

struct ProgressView: View {
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
                    subtitle: "Your weekly story, your reports, and the proof that the work is moving somewhere."
                )

                ProgressHeroStrip(
                    score: store.clientProfile.health.score,
                    consistency: logSummary.workoutsThisWeek,
                    streak: logSummary.currentStreakDays,
                    latestWin: logSummary.totalLogs == 0
                        ? "Log your first workout to start your story."
                        : "\(logSummary.latestWorkoutTitle) is your latest logged session."
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
            AIInsightCard(insight: store.clientProfile.aiProgressInsight)
            LogDrivenWeeklySummaryCard(summary: logSummary)
            AthletePatternInsightsCard(insights: athletePatternInsights)
            TrainingPatternInsightCard(insight: trainingPatternInsight)
            SessionMixCard(insight: sessionMixInsight)
            // Buddy comparison and workout-source breakdowns (coach/AI imports)
            // are multi-user concepts — hidden in solo v1.
            if FeatureFlags.multiUserEnabled {
                SoloVsBuddyProgressCard(
                    insight: partnerInsight,
                    trend: soloBuddyTrend,
                    trendSummary: soloBuddyTrendSummary
                )
                WorkoutSourceMixCard(summary: logSummary)
                SourceTrendCard(insight: sourceTrendInsight)
            }
            RecoveryBalanceCard(insight: recoveryBalanceInsight)

            if let report = athleteReport {
                WeeklyReportCard(report: report)
            }

            if let compliance {
                ProgramComplianceCard(compliance: compliance)
            }

            SharedWorkoutLogsCard(logs: Array(store.currentAthleteWorkoutLogs.prefix(5)))

            if !store.healthTrend.isEmpty {
                SimpleChartCard(title: "Activity (last 7 days)") {
                    Chart(store.healthTrend) { point in
                        LineMark(
                            x: .value("Day", point.day),
                            y: .value("Score", point.value)
                        )
                        .foregroundStyle(MorpheTheme.accent)
                        .lineStyle(StrokeStyle(lineWidth: 3, lineCap: .round))
                    }
                    .frame(height: 170)
                }
            }

            SimpleChartCard(title: "Weekly Consistency") {
                Chart(store.workoutConsistency) { point in
                    BarMark(
                        x: .value("Week", point.week),
                        y: .value("Workouts", point.workouts)
                    )
                    .foregroundStyle(MorpheTheme.accentAlt)
                }
                .frame(height: 160)
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

    private func resolvedTemplate(for log: WorkoutLog) -> WorkoutTemplate? {
        if let templateID = log.workoutTemplateID,
           let template = store.workoutTemplates.first(where: { $0.id == templateID }) {
            return template
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

    private func isHighOutput(_ log: WorkoutLog) -> Bool {
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
                                    RoundedRectangle(cornerRadius: 8, style: .continuous)
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
    let streak: Int
    let latestWin: String

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    MetricPill(label: "Morphe", value: "\(score)")
                    MetricPill(label: "Consistency", value: "\(consistency)/5")
                    MetricPill(label: "Streak", value: "\(streak) days")
                }

                Text(latestWin)
                    .font(.headline)
                    .foregroundStyle(.white)

                Text("Use this page like a clean control panel: check the story first, then open the deeper tools only when you need them.")
                    .font(.subheadline)
                    .foregroundStyle(MorpheTheme.textSecondary)
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

private struct SharedWorkoutLogsCard: View {
    let logs: [WorkoutLog]

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("Shared Workout Log")
                    .font(.headline)
                    .foregroundStyle(.white)

                if logs.isEmpty {
                    Text("No workout logs yet. Athlete, coach, and AI entries will all show here once access is granted.")
                        .foregroundStyle(MorpheTheme.textSecondary)
                } else {
                    ForEach(logs) { log in
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

                                StatusBadge(
                                    text: log.source.badgeTitle,
                                    color: badgeColor(for: log.source)
                                )
                            }

                            Text("\(log.enteredByName) • \(log.verificationStatus.rawValue)")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(MorpheTheme.accentAlt)

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
