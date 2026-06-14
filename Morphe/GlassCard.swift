import SwiftUI

struct AppShell<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }
}

struct ClientLayout<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct CoachLayout<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct PerformancePanelBackground: View {
    var cornerRadius: CGFloat = 8
    var accentOpacity: Double = 0.18

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(MorpheTheme.HUDGradient)
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(MorpheTheme.stroke, lineWidth: 1)
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: [
                                MorpheTheme.accent.opacity(accentOpacity),
                                .clear,
                                MorpheTheme.accentAlt.opacity(accentOpacity * 0.72)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
                    .blur(radius: 0.2)
            )
            .overlay(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.10),
                                .clear
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(height: 1.2)
                    .padding(.horizontal, 1)
            }
            .overlay(alignment: .bottomTrailing) {
                Circle()
                    .fill(MorpheTheme.glowAlt.opacity(0.85))
                    .frame(width: 92, height: 92)
                    .blur(radius: 34)
                    .offset(x: 24, y: 24)
                    .allowsHitTesting(false)
            }
    }
}

struct GlassCard<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .padding(16)
            .frame(maxWidth: .infinity)
            .background(PerformancePanelBackground())
            .shadow(color: MorpheTheme.glow.opacity(0.18), radius: 18, x: 0, y: 10)
            .shadow(color: Color.black.opacity(0.28), radius: 26, x: 0, y: 14)
    }
}

struct SectionTitleView: View {
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 26, weight: .bold, design: .rounded))
                .foregroundStyle(MorpheTheme.textPrimary)
                .overlay(alignment: .bottomLeading) {
                    Capsule(style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [MorpheTheme.accent.opacity(0.88), MorpheTheme.accentAlt.opacity(0.28)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: 52, height: 3)
                        .offset(y: 8)
                }

            Text(subtitle)
                .font(.footnote.weight(.medium))
                .foregroundStyle(MorpheTheme.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.bottom, 6)
    }
}

struct MetricPill: View {
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label.uppercased())
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .tracking(0.8)
                .foregroundStyle(MorpheTheme.textMuted)
            Text(value)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(MorpheTheme.textPrimary)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(MorpheTheme.panelStrong)
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(MorpheTheme.strokeStrong.opacity(0.20), lineWidth: 1)
                )
        )
    }
}

struct StatusBadge: View {
    let text: String
    let color: Color

    var body: some View {
        Text(text)
            .font(.caption.weight(.semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(color.opacity(0.16))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(color.opacity(0.72), lineWidth: 1)
                    )
            )
            .shadow(color: color.opacity(0.18), radius: 10, x: 0, y: 4)
    }
}

struct ProgressBarView: View {
    let progress: Double
    let color: Color

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(MorpheTheme.panelStrong)

                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [color.opacity(0.96), MorpheTheme.accentAlt.opacity(0.64)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: max(proxy.size.width * progress, 8))
                    .shadow(color: color.opacity(0.28), radius: 8, x: 0, y: 2)
            }
        }
        .frame(height: 10)
        .animation(.easeInOut(duration: 0.35), value: progress)
    }
}

struct ToastBanner: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(MorpheTheme.panelRaised.opacity(0.96))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(MorpheTheme.strokeStrong.opacity(0.45), lineWidth: 1)
            )
            .shadow(color: MorpheTheme.glow.opacity(0.20), radius: 14, x: 0, y: 6)
    }
}

struct CelebrationOverlay: View {
    let moment: CelebrationMoment

    var body: some View {
        GlassCard {
            HStack(spacing: 12) {
                Image(systemName: moment.symbol)
                    .font(.title3.weight(.bold))
                    .foregroundStyle(MorpheTheme.accent)

                VStack(alignment: .leading, spacing: 4) {
                    Text(moment.title)
                        .font(.headline)
                        .foregroundStyle(.white)
                    Text(moment.detail)
                        .font(.subheadline)
                        .foregroundStyle(MorpheTheme.textSecondary)
                }

                Spacer()
            }
        }
    }
}

struct MorpheAvatarView: View {
    let avatar: AvatarProfile
    let size: CGFloat

    init(avatar: AvatarProfile, size: CGFloat = 64) {
        self.avatar = avatar
        self.size = size
    }

    var body: some View {
        ZStack {
            Circle()
                .fill(MorpheTheme.HUDGradient)
                .overlay(
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [MorpheTheme.accent.opacity(0.72), MorpheTheme.accentAlt.opacity(0.42)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .padding(4)
                )
                .overlay(
                    Circle()
                        .stroke(MorpheTheme.strokeStrong.opacity(0.42), lineWidth: 1.5)
                )
                .shadow(color: MorpheTheme.glow.opacity(0.24), radius: 18, x: 0, y: 10)

            Circle()
                .stroke(
                    LinearGradient(
                        colors: [Color.white.opacity(0.22), .clear, MorpheTheme.accent.opacity(0.35)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 3
                )
                .padding(2)

            VStack(spacing: 4) {
                Image(systemName: avatar.style.systemImage)
                    .font(.system(size: size * 0.26, weight: .bold))
                    .foregroundStyle(iconAccent)
                Text(shortTitle)
                    .font(.system(size: size * 0.12, weight: .semibold))
                    .foregroundStyle(MorpheTheme.textSecondary)
                    .lineLimit(1)
            }
            .padding(8)
        }
        .frame(width: size, height: size)
        .overlay(
            Circle()
                .stroke(Color.white.opacity(0.12), lineWidth: 1)
        )
    }

    private var shortTitle: String {
        switch avatar.style {
        case .cleanStarter:
            return "Clean"
        case .fightReady:
            return "Fight"
        case .matchFit:
            return "Match"
        case .jumpDay:
            return "Jump"
        case .roadRunner:
            return "Run"
        case .strengthBuilder:
            return "Strength"
        }
    }

    private var iconAccent: LinearGradient {
        switch avatar.style {
        case .cleanStarter:
            return LinearGradient(colors: [Color.white.opacity(0.95), MorpheTheme.accentAlt.opacity(0.75)], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .fightReady:
            return LinearGradient(colors: [Color(red: 0.98, green: 0.50, blue: 0.40), Color(red: 0.95, green: 0.26, blue: 0.30)], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .matchFit:
            return LinearGradient(colors: [Color(red: 0.54, green: 0.95, blue: 0.66), Color(red: 0.17, green: 0.72, blue: 0.41)], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .jumpDay:
            return LinearGradient(colors: [Color(red: 1.00, green: 0.78, blue: 0.46), Color(red: 0.97, green: 0.46, blue: 0.14)], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .roadRunner:
            return LinearGradient(colors: [Color(red: 0.70, green: 0.93, blue: 1.0), MorpheTheme.accent], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .strengthBuilder:
            return LinearGradient(colors: [MorpheTheme.lavender, Color(red: 0.58, green: 0.42, blue: 0.92)], startPoint: .topLeading, endPoint: .bottomTrailing)
        }
    }
}

struct ProfileBannerView: View {
    let banner: BannerProfile
    let theme: ThemePreset

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: gradientColors(for: theme),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(MorpheTheme.strokeStrong.opacity(0.28), lineWidth: 1)
                )
                .overlay(alignment: .topTrailing) {
                    Image(systemName: bannerSymbol(for: banner.preset))
                        .font(.system(size: 42, weight: .semibold))
                        .foregroundStyle(Color.white.opacity(0.12))
                        .padding(18)
                }
                .overlay(alignment: .topLeading) {
                    VStack(spacing: 7) {
                        ForEach(0..<8, id: \.self) { _ in
                            Capsule(style: .continuous)
                                .fill(Color.white.opacity(0.06))
                                .frame(width: 58, height: 1)
                        }
                    }
                    .padding(18)
                }
                .overlay(
                    LinearGradient(
                        colors: [Color.black.opacity(0.05), Color.black.opacity(0.55)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                )

            VStack(alignment: .leading, spacing: 10) {
                Text(eyebrowText(for: banner.preset))
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(Color.white.opacity(0.82))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(
                        Capsule(style: .continuous)
                            .fill(Color.white.opacity(0.12))
                    )

                Text(banner.title)
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .shadow(color: Color.black.opacity(0.35), radius: 16, x: 0, y: 10)

                Text(banner.subtitle)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.white.opacity(0.84))
            }
            .padding(18)
        }
        .frame(maxWidth: .infinity, minHeight: 148)
    }

    private func gradientColors(for theme: ThemePreset) -> [Color] {
        switch theme {
        case .boxingRedCharcoal:
            return [Color(red: 0.88, green: 0.30, blue: 0.24), Color.black.opacity(0.9)]
        case .soccerGreenWhite:
            return [Color(red: 0.18, green: 0.70, blue: 0.40), Color.white.opacity(0.18)]
        case .basketballOrangeBlack:
            return [Color(red: 0.95, green: 0.48, blue: 0.18), Color.black.opacity(0.92)]
        case .recoveryBlueGray:
            return [Color(red: 0.32, green: 0.62, blue: 0.94), Color(red: 0.42, green: 0.46, blue: 0.54)]
        case .strengthPurpleGraphite:
            return [MorpheTheme.lavender, Color(red: 0.18, green: 0.20, blue: 0.24)]
        case .minimalWhiteBlack:
            return [Color.white.opacity(0.20), Color.black.opacity(0.92)]
        case .goldPremium:
            return [Color(red: 0.92, green: 0.80, blue: 0.42), Color(red: 0.26, green: 0.22, blue: 0.12)]
        default:
            return [MorpheTheme.accentAlt, Color.black.opacity(0.88)]
        }
    }

    private func eyebrowText(for preset: BannerPreset) -> String {
        switch preset {
        case .boxing: return "MORPHE BOXING"
        case .soccer: return "MATCH READY"
        case .basketball: return "COURT FOCUS"
        case .running: return "ENDURANCE BUILD"
        case .strength: return "STRENGTH TRACK"
        case .fatLoss: return "MOMENTUM MODE"
        case .transformation: return "TRANSFORMATION"
        case .recovery: return "RECOVERY BLOCK"
        case .team: return "TEAM MODE"
        case .minimalPremium: return "MORPHE"
        }
    }

    private func bannerSymbol(for preset: BannerPreset) -> String {
        switch preset {
        case .boxing: return "figure.boxing"
        case .soccer: return "soccerball"
        case .basketball: return "basketball.fill"
        case .running: return "figure.run"
        case .strength: return "dumbbell.fill"
        case .fatLoss: return "flame.fill"
        case .transformation: return "sparkles"
        case .recovery: return "heart.text.square.fill"
        case .team: return "person.3.sequence.fill"
        case .minimalPremium: return "moon.stars.fill"
        }
    }
}

struct StatCard: View {
    let title: String
    let value: String
    let detail: String?

    init(title: String, value: String, detail: String? = nil) {
        self.title = title
        self.value = value
        self.detail = detail
    }

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 10) {
                Text(title)
                    .font(.caption.weight(.semibold))
                    .textCase(.uppercase)
                    .foregroundStyle(MorpheTheme.textSecondary)
                Text(value)
                    .font(.title3.weight(.bold))
                    .foregroundStyle(.white)

                if let detail {
                    Text(detail)
                        .font(.caption)
                        .foregroundStyle(MorpheTheme.textMuted)
                }
            }
        }
    }
}

struct NotificationCard: View {
    let item: SmartNotificationItem
    let onAction: () -> Void

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(item.title)
                        .font(.headline)
                        .foregroundStyle(.white)
                    Spacer()
                    StatusBadge(text: item.priority.rawValue, color: item.priority == .high ? MorpheTheme.warning : MorpheTheme.accentAlt)
                }

                Text(item.message)
                    .font(.subheadline)
                    .foregroundStyle(MorpheTheme.textSecondary)

                Button(item.action, action: onAction)
                    .buttonStyle(SecondaryCTAButtonStyle())
            }
        }
    }
}

struct EmptyStateCard: View {
    let title: String
    let detail: String

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 10) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(.white)
                Text(detail)
                    .foregroundStyle(MorpheTheme.textSecondary)
            }
        }
    }
}

struct ScoreRing: View {
    let score: Int
    let color: Color

    var body: some View {
        ZStack {
            Circle()
                .stroke(MorpheTheme.panelStrong, lineWidth: 10)

            Circle()
                .trim(from: 0, to: Double(score) / 100.0)
                .stroke(
                    LinearGradient(
                        colors: [color, MorpheTheme.accentAlt.opacity(0.78)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    style: StrokeStyle(lineWidth: 10, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .shadow(color: color.opacity(0.28), radius: 10, x: 0, y: 4)

            VStack(spacing: 2) {
                Text("\(score)")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                Text("score")
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .tracking(0.7)
                    .foregroundStyle(MorpheTheme.textMuted)
            }
        }
        .frame(width: 88, height: 88)
        .overlay(
            Circle()
                .stroke(MorpheTheme.strokeStrong.opacity(0.22), lineWidth: 1)
        )
    }
}

struct HealthScoreCard: View {
    let health: HealthScoreSummary

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Health Score")
                            .font(.headline)
                            .foregroundStyle(.white)
                        Text(health.headline)
                            .font(.title3.weight(.bold))
                            .foregroundStyle(.white)
                        Text(health.tier.rawValue)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(MorpheTheme.color(for: health.tier))
                    }

                    Spacer()

                    ScoreRing(score: health.score, color: MorpheTheme.color(for: health.tier))
                }

                Text(health.detail)
                    .font(.subheadline)
                    .foregroundStyle(MorpheTheme.textSecondary)
            }
        }
    }
}

struct AIInsightCard: View {
    let insight: AIInsight

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text(insight.title)
                        .font(.headline)
                        .foregroundStyle(.white)

                    Spacer()

                    StatusBadge(text: insight.risk.rawValue, color: MorpheTheme.color(for: insight.risk))
                }

                Text(insight.summary)
                    .foregroundStyle(MorpheTheme.textPrimary)

                Text(insight.recommendation)
                    .font(.subheadline)
                    .foregroundStyle(MorpheTheme.textSecondary)

                Text(insight.suggestedAction)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(MorpheTheme.accent)
            }
        }
    }
}

struct RecoveryScoreCard: View {
    let recovery: RecoverySnapshot

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Recovery Score")
                            .font(.headline)
                            .foregroundStyle(.white)
                        Text(recovery.status.rawValue)
                            .font(.title3.weight(.bold))
                            .foregroundStyle(.white)
                        Text(recovery.reason)
                            .font(.subheadline)
                            .foregroundStyle(MorpheTheme.textSecondary)
                    }

                    Spacer()

                    ScoreRing(score: recovery.score, color: MorpheTheme.color(for: recovery.status))
                }

                HStack(spacing: 8) {
                    MetricPill(label: "Sleep", value: String(format: "%.1f hr", recovery.sleepHours))
                    MetricPill(label: "Energy", value: "\(recovery.energy)/10")
                    MetricPill(label: "Soreness", value: "\(recovery.soreness)/10")
                }
            }
        }
    }
}

struct ConfidenceRatingCard: View {
    let selected: ConfidenceLevel?
    let onSelect: (ConfidenceLevel) -> Void

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("How confident are you that you can complete this today?")
                    .font(.headline)
                    .foregroundStyle(.white)

                HStack(spacing: 8) {
                    ForEach(ConfidenceLevel.allCases) { level in
                        Button(level.rawValue) {
                            onSelect(level)
                        }
                        .buttonStyle(FilterChipStyle(isSelected: selected == level, selectedColor: MorpheTheme.accent))
                    }
                }

                if selected == .notConfident {
                    Text("Let's make this easier today.")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(MorpheTheme.warning)
                }
            }
        }
    }
}

struct SmartPlanAdjustmentCard: View {
    let adjustment: PlanAdjustment

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                Text(adjustment.title)
                    .font(.headline)
                    .foregroundStyle(.white)

                Text(adjustment.body)
                    .foregroundStyle(MorpheTheme.textPrimary)

                WrapStack(spacing: 8) {
                    ForEach(adjustment.reasons) { reason in
                        Text(reason.rawValue)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .fill(MorpheTheme.panelStrong)
                            )
                    }
                }

                Text(adjustment.recommendation)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(MorpheTheme.accentAlt)
            }
        }
    }
}

struct GoalTranslationCard: View {
    let translation: GoalTranslation

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("Goal Translation")
                    .font(.headline)
                    .foregroundStyle(.white)
                Text(translation.goal)
                    .font(.title3.weight(.bold))
                    .foregroundStyle(.white)

                ForEach(translation.weeklyActions, id: \.self) { action in
                    Text("- \(action)")
                        .foregroundStyle(MorpheTheme.textPrimary)
                }
            }
        }
    }
}

struct PersonalRulesCard: View {
    let rules: [PersonalRule]

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("Personal Rules")
                    .font(.headline)
                    .foregroundStyle(.white)
                Text("Morphe uses these rules to adjust your plan.")
                    .font(.subheadline)
                    .foregroundStyle(MorpheTheme.textSecondary)

                ForEach(rules) { rule in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(rule.title)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.white)
                        Text(rule.detail)
                            .font(.caption)
                            .foregroundStyle(MorpheTheme.textSecondary)
                    }
                }
            }
        }
    }
}

struct WhyThisMattersCard: View {
    let item: WhyThisMatters

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 10) {
                Text("Why this matters")
                    .font(.headline)
                    .foregroundStyle(.white)
                Text(item.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(MorpheTheme.accent)
                Text(item.detail)
                    .foregroundStyle(MorpheTheme.textSecondary)
            }
        }
    }
}

struct TaskRow: View {
    let task: TaskItem
    let onToggle: () -> Void

    var body: some View {
        Button(action: onToggle) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(task.isCompleted ? MorpheTheme.accent : MorpheTheme.textMuted)
                    .font(.headline)

                VStack(alignment: .leading, spacing: 4) {
                    Text(task.title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                    Text("\(task.difficulty.rawValue) - \(task.xp) XP")
                        .font(.caption)
                        .foregroundStyle(MorpheTheme.textSecondary)
                }

                Spacer()
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
    }
}

struct MinimumWinModeCard: View {
    let message: String
    let tasks: [TaskItem]
    let onToggle: (TaskItem) -> Void

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("Minimum Win Mode")
                    .font(.headline)
                    .foregroundStyle(.white)
                Text(message)
                    .foregroundStyle(MorpheTheme.textSecondary)

                ForEach(tasks) { task in
                    TaskRow(task: task) {
                        onToggle(task)
                    }
                }
            }
        }
    }
}

struct StreakProtectionCard: View {
    let isProtected: Bool
    let options: [String]
    let onSelect: (String) -> Void

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("Streak Protection")
                    .font(.headline)
                    .foregroundStyle(.white)

                if isProtected {
                    Text("Momentum protected.")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(MorpheTheme.accent)
                } else {
                    Text("You missed today's workout, but your streak is still saveable.")
                        .foregroundStyle(MorpheTheme.textSecondary)

                    WrapStack(spacing: 8) {
                        ForEach(options, id: \.self) { option in
                            Button(option) {
                                onSelect(option)
                            }
                            .buttonStyle(FilterChipStyle(isSelected: false, selectedColor: MorpheTheme.accentAlt))
                        }
                    }
                }
            }
        }
    }
}

struct WorkoutHeroCard: View {
    let workout: WorkoutTemplate
    let onStart: () -> Void
    let onSwitch: () -> Void

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Today's Workout")
                            .font(.headline)
                            .foregroundStyle(.white)
                        Text(workout.name)
                            .font(.title3.weight(.bold))
                            .foregroundStyle(.white)
                        Text(workout.goal)
                            .font(.subheadline)
                            .foregroundStyle(MorpheTheme.textSecondary)
                    }

                    Spacer()

                    MetricPill(label: "Duration", value: "\(workout.durationMinutes) min")
                }

                HStack(spacing: 8) {
                    MetricPill(label: "Difficulty", value: workout.difficulty.rawValue)
                    MetricPill(label: "Equipment", value: workout.equipment)
                }

                HStack(spacing: 10) {
                    Button("Start Workout", action: onStart)
                        .buttonStyle(PrimaryCTAButtonStyle(accent: MorpheTheme.accent))

                    Button("Switch Workout", action: onSwitch)
                        .buttonStyle(SecondaryCTAButtonStyle())
                }
            }
        }
    }
}

struct WorkoutDifficultyFeedbackCard: View {
    let selected: WorkoutFeedbackOption?
    let response: String
    let onSelect: (WorkoutFeedbackOption) -> Void

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("How did this session feel?")
                    .font(.headline)
                    .foregroundStyle(.white)

                WrapStack(spacing: 8) {
                    ForEach(WorkoutFeedbackOption.allCases) { option in
                        Button(option.rawValue) {
                            onSelect(option)
                        }
                        .buttonStyle(FilterChipStyle(isSelected: selected == option, selectedColor: MorpheTheme.accentAlt))
                    }
                }

                if !response.isEmpty {
                    Text(response)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(MorpheTheme.accent)
                }
            }
        }
    }
}

struct FrictionInsightCard: View {
    let insight: FrictionInsight
    let onNext: () -> Void

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Pattern Insights")
                        .font(.headline)
                        .foregroundStyle(.white)
                    Spacer()
                    Button("Next", action: onNext)
                        .buttonStyle(SecondaryCTAButtonStyle())
                        .frame(width: 88)
                }

                Text(insight.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(MorpheTheme.accent)

                Text(insight.summary)
                    .foregroundStyle(MorpheTheme.textPrimary)

                Text(insight.recommendation)
                    .foregroundStyle(MorpheTheme.textSecondary)
            }
        }
    }
}

struct TransformationRoadmapCard: View {
    let phases: [RoadmapPhase]

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("Transformation Roadmap")
                    .font(.headline)
                    .foregroundStyle(.white)

                ForEach(phases) { phase in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            HStack(spacing: 8) {
                                Image(systemName: iconName(for: phase.status))
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(color(for: phase.status))
                                Text(phase.title)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(.white)
                            }
                            Spacer()
                            Text(phase.status)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(color(for: phase.status))
                        }

                        Text(phase.focus)
                            .font(.caption)
                            .foregroundStyle(MorpheTheme.textSecondary)

                        Text("Milestone: \(phase.milestone)")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(MorpheTheme.accentAlt)
                    }
                }
            }
        }
    }

    private func color(for status: String) -> Color {
        switch status {
        case "Done":
            return Color(red: 0.40, green: 0.86, blue: 0.54)
        case "Current":
            return MorpheTheme.accent
        case "Up Next":
            return MorpheTheme.textMuted
        case "Locked":
            return MorpheTheme.danger
        default:
            return MorpheTheme.textSecondary
        }
    }

    private func iconName(for status: String) -> String {
        switch status {
        case "Done":
            return "checkmark.circle.fill"
        case "Current":
            return "largecircle.fill.circle"
        case "Up Next":
            return "circle.dashed"
        case "Locked":
            return "lock.circle.fill"
        default:
            return "circle"
        }
    }
}

struct PhotoProgressAIScanCard: View {
    let snapshot: PhotoProgressSnapshot

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("Photo Progress + AI Scan")
                    .font(.headline)
                    .foregroundStyle(.white)

                HStack(spacing: 8) {
                    PhotoSlotView(label: snapshot.frontLabel)
                    PhotoSlotView(label: snapshot.sideLabel)
                    PhotoSlotView(label: snapshot.backLabel)
                }

                Text(snapshot.reminder)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(MorpheTheme.accent)
                Text(snapshot.aiPreview)
                    .foregroundStyle(MorpheTheme.textPrimary)
                Text(snapshot.postureNote)
                    .foregroundStyle(MorpheTheme.textSecondary)
                Text(snapshot.compositionTrend)
                    .foregroundStyle(MorpheTheme.textSecondary)
                Text(snapshot.privacyNote)
                    .font(.caption)
                    .foregroundStyle(MorpheTheme.textMuted)
            }
        }
    }
}

struct SportModeSelector: View {
    let selected: SportFocus
    let onSelect: (SportFocus) -> Void

    private let featuredSports: [SportFocus] = [
        .generalFitness,
        .weightLoss,
        .boxing,
        .soccer,
        .basketball,
        .running,
        .hybridAthlete
    ]

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("Sport-Specific Mode")
                    .font(.headline)
                    .foregroundStyle(.white)
                Text("Training type changes the goals, drills, and metrics Morphe highlights.")
                    .foregroundStyle(MorpheTheme.textSecondary)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(featuredSports) { sport in
                            Button(sport.shortTitle) {
                                onSelect(sport)
                            }
                            .buttonStyle(FilterChipStyle(isSelected: selected == sport, selectedColor: MorpheTheme.color(for: sport)))
                        }
                    }
                }
            }
        }
    }
}

struct SportMetricsCard: View {
    let sport: SportFocus
    let metrics: [SportMetric]

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("\(sport.rawValue) Focus")
                        .font(.headline)
                        .foregroundStyle(.white)
                    Spacer()
                    StatusBadge(text: sport.shortTitle, color: MorpheTheme.color(for: sport))
                }

                ForEach(metrics) { metric in
                    HStack {
                        Text(metric.label)
                            .foregroundStyle(MorpheTheme.textSecondary)
                        Spacer()
                        Text(metric.value)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.white)
                    }
                }
            }
        }
    }
}

struct SmartNotificationPreviewCard: View {
    let notifications: [SmartNotificationItem]
    let onAction: (SmartNotificationItem) -> Void

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("Smart Notifications")
                    .font(.headline)
                    .foregroundStyle(.white)

                ForEach(Array(notifications.prefix(3))) { item in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text(item.title)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.white)
                            Spacer()
                            StatusBadge(text: item.priority.rawValue, color: item.priority == .high ? MorpheTheme.warning : MorpheTheme.accentAlt)
                        }
                        Text(item.message)
                            .font(.caption)
                            .foregroundStyle(MorpheTheme.textSecondary)
                        Button(item.action) {
                            onAction(item)
                        }
                        .buttonStyle(SecondaryCTAButtonStyle())
                    }
                }
            }
        }
    }
}

struct LevelProgressCard: View {
    let progress: LevelProgress

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("Level / Rank")
                    .font(.headline)
                    .foregroundStyle(.white)

                Text(progress.currentTitle)
                    .font(.title3.weight(.bold))
                    .foregroundStyle(.white)

                ProgressBarView(progress: progress.progress, color: MorpheTheme.accent)

                HStack {
                    Text("XP \(progress.currentXP) / \(progress.targetXP)")
                        .foregroundStyle(MorpheTheme.textSecondary)
                    Spacer()
                    Text("Streak \(progress.streak) days")
                        .foregroundStyle(MorpheTheme.textSecondary)
                }
                .font(.subheadline)

                Text("Next Level: \(progress.nextTitle)")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
            }
        }
    }
}

struct QuickActionButton: View {
    let title: String
    let systemImage: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 10) {
                Image(systemName: systemImage)
                    .font(.headline)
                    .foregroundStyle(.white)
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.leading)
            }
            .padding(14)
            .frame(maxWidth: .infinity, minHeight: 88, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(MorpheTheme.panelStrong)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(MorpheTheme.stroke, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

struct RoleSwitcher: View {
    let selectedRole: AppRole
    let onSelect: (AppRole) -> Void

    var body: some View {
        HStack(spacing: 8) {
            ForEach(AppRole.allCases) { role in
                Button {
                    onSelect(role)
                } label: {
                    VStack(spacing: 6) {
                        Text(role.title)
                            .font(.subheadline.weight(.semibold))
                        Text(role.subtitle)
                            .font(.caption2)
                            .lineLimit(2)
                            .multilineTextAlignment(.center)
                    }
                    .foregroundStyle(selectedRole == role ? .black : .white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(selectedRole == role ? MorpheTheme.accent : MorpheTheme.panelStrong)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .stroke(selectedRole == role ? Color.white.opacity(0.18) : MorpheTheme.strokeStrong.opacity(0.20), lineWidth: 1)
                            )
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }
}

struct BottomTabNavigation<Item: MorpheTabItem & CaseIterable>: View where Item.AllCases == [Item] {
    let items: [Item]
    let selected: Item
    let onSelect: (Item) -> Void

    var body: some View {
        MorpheTabBar(items: items, selected: selected, onSelect: onSelect)
    }
}

struct MorpheTabBar<Item: MorpheTabItem & CaseIterable>: View where Item.AllCases == [Item] {
    let items: [Item]
    let selected: Item
    let onSelect: (Item) -> Void

    var body: some View {
        HStack(spacing: 4) {
            ForEach(items, id: \.self) { item in
                Button {
                    onSelect(item)
                } label: {
                    VStack(spacing: 5) {
                        Image(systemName: item.systemImage)
                            .font(.system(size: 14, weight: .semibold))
                        Text(item.title)
                            .font(.caption2.weight(.bold))
                            .lineLimit(1)
                    }
                    .foregroundStyle(selected == item ? .black : .white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(selected == item ? MorpheTheme.accent : .clear)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .stroke(selected == item ? Color.white.opacity(0.18) : .clear, lineWidth: 1)
                            )
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(6)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(MorpheTheme.panelRaised.opacity(0.98))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(MorpheTheme.strokeStrong.opacity(0.28), lineWidth: 1)
                )
                .overlay(alignment: .topLeading) {
                    Capsule(style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [MorpheTheme.accent.opacity(0.64), .clear],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: 82, height: 2)
                        .padding(.top, 1)
                        .padding(.leading, 10)
                }
        )
        .shadow(color: MorpheTheme.glow.opacity(0.14), radius: 18, x: 0, y: 8)
        .shadow(color: Color.black.opacity(0.24), radius: 24, x: 0, y: 12)
    }
}

struct ClientSnapshotCard: View {
    let client: CoachClient
    let onMessage: () -> Void

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(client.name)
                            .font(.headline)
                            .foregroundStyle(.white)
                        Text(client.goal)
                            .font(.subheadline)
                            .foregroundStyle(MorpheTheme.textSecondary)
                    }

                    Spacer()

                    StatusBadge(text: client.statusText, color: MorpheTheme.color(for: client.risk))
                }

                HStack(spacing: 8) {
                    MetricPill(label: "Sport", value: client.sport.shortTitle)
                    MetricPill(label: "Recovery", value: "\(client.recoveryScore.score)")
                    MetricPill(label: "Compliance", value: "\(client.complianceScore)%")
                }

                Button("Quick Message", action: onMessage)
                    .buttonStyle(SecondaryCTAButtonStyle())
            }
        }
    }
}

struct BadgeGridCard: View {
    let badges: [ProfileBadge]

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("Badges")
                    .font(.headline)
                    .foregroundStyle(.white)

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                    ForEach(badges) { badge in
                        VStack(alignment: .leading, spacing: 8) {
                            Image(systemName: badge.icon)
                                .foregroundStyle(MorpheTheme.accent)
                            Text(badge.title)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.white)
                            Text(badge.detail)
                                .font(.caption)
                                .foregroundStyle(MorpheTheme.textSecondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(12)
                        .background(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(MorpheTheme.panelStrong)
                        )
                    }
                }
            }
        }
    }
}

struct SubscriptionStatusCard: View {
    let status: SubscriptionStatus

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 10) {
                Text("Subscription Status")
                    .font(.headline)
                    .foregroundStyle(.white)
                Text(status.currentPlan)
                    .font(.title3.weight(.bold))
                    .foregroundStyle(.white)
                Text(status.note)
                    .font(.subheadline)
                    .foregroundStyle(MorpheTheme.textSecondary)

                if status.profileIsFree {
                    StatusBadge(text: "Premium Profile is Free", color: MorpheTheme.accent)
                }
            }
        }
    }
}

struct CalendarEventCard: View {
    let event: CalendarEvent
    let onReschedule: () -> Void
    let onComplete: () -> Void

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(event.title)
                            .font(.headline)
                            .foregroundStyle(.white)
                        Text("\(event.day) - \(event.time)")
                            .font(.subheadline)
                            .foregroundStyle(MorpheTheme.textSecondary)
                    }

                    Spacer()

                    StatusBadge(text: event.type.rawValue, color: MorpheTheme.accentAlt)
                }

                Text(event.detail)
                    .font(.subheadline)
                    .foregroundStyle(MorpheTheme.textPrimary)

                HStack(spacing: 10) {
                    Button("Reschedule", action: onReschedule)
                        .buttonStyle(SecondaryCTAButtonStyle())

                    Button(event.isComplete ? "Completed" : "Mark Complete", action: onComplete)
                        .buttonStyle(PrimaryCTAButtonStyle(accent: event.isComplete ? MorpheTheme.accentAlt : MorpheTheme.accent))
                }
            }
        }
    }
}

struct FilterChipStyle: ButtonStyle {
    let isSelected: Bool
    var selectedColor: Color = MorpheTheme.accent

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(isSelected ? .black : .white)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(isSelected ? selectedColor : (configuration.isPressed ? MorpheTheme.panelStrong : MorpheTheme.panel))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(isSelected ? Color.white.opacity(0.18) : MorpheTheme.strokeStrong.opacity(0.22), lineWidth: 1)
            )
            .shadow(color: isSelected ? selectedColor.opacity(0.22) : .clear, radius: 10, x: 0, y: 6)
    }
}

struct MorpheFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<_Label>) -> some View {
        configuration
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(MorpheTheme.panel)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(MorpheTheme.strokeStrong.opacity(0.24), lineWidth: 1)
                    )
            )
            .foregroundStyle(.white)
    }
}

private struct PhotoSlotView: View {
    let label: String

    var body: some View {
        RoundedRectangle(cornerRadius: 8, style: .continuous)
            .fill(MorpheTheme.panelStrong)
            .overlay(
                VStack(spacing: 8) {
                    Image(systemName: "photo")
                        .foregroundStyle(.white)
                    Text(label)
                        .font(.caption)
                        .foregroundStyle(MorpheTheme.textSecondary)
                        .multilineTextAlignment(.center)
                }
                .padding(8)
            )
            .frame(maxWidth: .infinity, minHeight: 100)
    }
}

struct WrapStack<Content: View>: View {
    let spacing: CGFloat
    let content: Content

    init(spacing: CGFloat = 8, @ViewBuilder content: () -> Content) {
        self.spacing = spacing
        self.content = content()
    }

    var body: some View {
        LazyVGrid(
            columns: [GridItem(.adaptive(minimum: 130), spacing: spacing, alignment: .leading)],
            alignment: .leading,
            spacing: spacing
        ) {
            content
        }
    }
}
